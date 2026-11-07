# Build a ZV-E10 patched Creators' App 3.6.0 split bundle from an APKMirror .apkm.
# Usage: powershell -ExecutionPolicy Bypass -File build-3.6.ps1 [-Apkm <file.apkm>] [-Out .\out] [-Apktool <apktool.jar>]
param(
    [string]$Apkm = (Get-ChildItem $PWD -Filter 'jp.co.sony.ips.portalapp_3.6*.apkm' | Select-Object -First 1 -ExpandProperty FullName),
    [string]$Out = "$PWD\out",
    [string]$Apktool = $(if ($env:APKTOOL_JAR) { $env:APKTOOL_JAR } else { "$PWD\apktool.jar" })
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Patcher  = "$PSScriptRoot\3.6\zvpatch.py"
$Python   = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
$Jbr      = 'C:\Program Files\Android\Android Studio\jbr'
$BT       = "$env:LOCALAPPDATA\Android\Sdk\build-tools\35.0.0"
$Pkg      = 'jp.co.sony.ips.portalapp'
$Variant  = 'release'

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Run($exe, [string[]]$a) {
    & $exe @a | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "failed ($LASTEXITCODE): $exe $($a -join ' ')" }
}

if (-not $Apkm -or -not (Test-Path $Apkm)) { throw "apkm not found: $Apkm" }
foreach ($p in $Apktool, $Patcher, $Python, "$Jbr\bin\keytool.exe", "$BT\apksigner.bat", "$BT\zipalign.exe") {
    if (-not (Test-Path $p)) { throw "missing: $p" }
}
$env:JAVA_HOME = $Jbr
$env:PATH = "$Jbr\bin;$env:PATH"
New-Item -ItemType Directory -Force $Out | Out-Null

# --- signing key (reused across builds so updates install over each other) ------------------
$Ks = "$Out\zvpatch-signing.jks"; $PassFile = "$Out\zvpatch-signing.pass"
if (-not (Test-Path $Ks)) {
    Step "Generating signing key"
    $pass = -join ((1..32) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
    Run "$Jbr\bin\keytool.exe" @('-genkeypair','-keystore',$Ks,'-storepass',$pass,'-keypass',$pass,'-alias','zvpatch',
        '-keyalg','RSA','-keysize','2048','-validity','10000','-dname','CN=zvpatch local build')
    Set-Content -Path $PassFile -Value $pass -NoNewline -Encoding ascii
}
$KsPass = (Get-Content $PassFile -Raw).Trim()

function Sign($in, $out) {
    $al = "$out.aligned"
    Run "$BT\zipalign.exe" @('-f','-p','4',$in,$al)
    Run "$BT\apksigner.bat" @('sign','--ks',$Ks,'--ks-pass',"pass:$KsPass",'--key-pass',"pass:$KsPass",'--ks-key-alias','zvpatch','--out',$out,$al)
    Remove-Item $al, "$out.idsig" -Force -ErrorAction SilentlyContinue
    Run "$BT\apksigner.bat" @('verify',$out)
}

$WorkBase = "$env:SystemDrive\zvw"   # short path: smali file names exceed MAX_PATH otherwise
$Work = "$WorkBase\" + (Get-Date -Format 'HHmmss')
New-Item -ItemType Directory -Force $Work | Out-Null

Step "Extracting $Apkm"
[System.IO.Compression.ZipFile]::ExtractToDirectory($Apkm, "$Work\bundle")
$info = Get-Content "$Work\bundle\info.json" -Raw | ConvertFrom-Json
if ($info.pname -ne $Pkg) { throw "unexpected package $($info.pname)" }
$Version = $info.release_version
Write-Host "  $($info.pname) $Version (code $($info.versioncode))"

Step "Decoding base.apk (apktool d -r)"
Run 'java' @('-jar',$Apktool,'d','-r','-f','-o',"$Work\decoded","$Work\bundle\base.apk")

Step "Patching ($Variant)"
& $Python -I $Patcher "$Work\decoded" $Variant
if ($LASTEXITCODE -ne 0) { throw 'patcher failed (see the error above: an anchor mismatch means this app version differs from what the patches expect)' }

Step "Building"
Run 'java' @('-jar',$Apktool,'b','-o',"$Work\unsigned.apk","$Work\decoded")

Step "Signing base + splits"
$Stage = "$Work\stage"; New-Item -ItemType Directory -Force $Stage | Out-Null
Sign "$Work\unsigned.apk" "$Stage\$Pkg.apk"
Get-ChildItem "$Work\bundle" -Filter 'split_config.*.apk' | ForEach-Object {
    Sign $_.FullName "$Stage\$($_.Name)"
}

# --- bundle outputs -------------------------------------------------------------------------
Step "Packaging"
$splits = @(@{ file = "$Pkg.apk"; id = 'base' })
Get-ChildItem $Stage -Filter 'split_config.*.apk' | Sort-Object Name | ForEach-Object {
    $splits += @{ file = $_.Name; id = ($_.BaseName -replace '^split_', '') }
}
$manifest = [ordered]@{
    xapk_version    = 2
    package_name    = $Pkg
    name            = "Creators' App (ZV-E10 patch)"
    version_code    = "$($info.versioncode)"
    version_name    = $Version
    min_sdk_version = "$($info.min_api)"
    split_apks      = $splits
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content "$Stage\manifest.json" -Encoding utf8

$Target = "$Out\CreatorsApp_${Version}_ZV-E10_$Variant.xapk"
Remove-Item $Target -Force -ErrorAction SilentlyContinue
[System.IO.Compression.ZipFile]::CreateFromDirectory($Stage, $Target, [System.IO.Compression.CompressionLevel]::NoCompression, $false)

$ApkDir = "$Out\apks_${Version}_$Variant"
if (Test-Path $ApkDir) { Remove-Item $ApkDir -Recurse -Force }
New-Item -ItemType Directory -Force $ApkDir | Out-Null
Get-ChildItem $Stage -Filter '*.apk' | Copy-Item -Destination $ApkDir

Step "Cleaning up"
$empty = "$WorkBase\_empty"; New-Item -ItemType Directory -Force $empty | Out-Null
robocopy $empty $Work /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue

Step "Done"
Write-Host "  bundle : $Target"
Write-Host "  apks   : $ApkDir"
Write-Host "  install (PowerShell): adb install-multiple -r (Get-ChildItem '$ApkDir\*.apk').FullName   (uninstall the original app first: different signature)"
