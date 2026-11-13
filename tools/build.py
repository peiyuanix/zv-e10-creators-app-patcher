#!/usr/bin/env python3
"""Build a signed, arm64-v8a-only release APK from a supported APKMirror APKM."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "jp.co.sony.ips.portalapp"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def run(*args, capture=False):
    return subprocess.run([str(a) for a in args], check=True, text=True,
                          stdout=subprocess.PIPE if capture else None).stdout


def select_splits(names):
    """Keep all resource splits and only the arm64 native-code split."""
    excluded = {"split_config.armeabi_v7a.apk", "split_config.x86.apk", "split_config.x86_64.apk"}
    return sorted(n for n in names if n.startswith("split_config.")
                  and n.endswith(".apk") and "/" not in n and n not in excluded)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="original 3.6.0 or 3.6.1 .apkm")
    parser.add_argument("--out", type=Path, default=ROOT / "out")
    parser.add_argument("--build-tools", type=Path,
                        default=ROOT / "out/android-sdk/build-tools/35.0.0")
    parser.add_argument("--apkeditor", type=Path, default=ROOT / "out/APKEditor-1.4.9.jar")
    parser.add_argument("--apktool-jar", type=Path, help="otherwise use apktool on PATH")
    parser.add_argument("--keystore", type=Path, help="default: <out>/zvpatch-signing.jks")
    parser.add_argument("--password-file", type=Path, help="default: <out>/zvpatch-signing.pass")
    parser.add_argument("--key-alias", default="zvpatch")
    args = parser.parse_args()
    out = args.out.resolve()
    bt = args.build_tools.resolve()
    editor = args.apkeditor.resolve()
    zipalign = bt / ("zipalign.exe" if os.name == "nt" else "zipalign")
    signer = bt / "lib/apksigner.jar"
    for path in (args.input, editor, zipalign, signer):
        if not path.is_file():
            parser.error(f"file not found: {path}")
    apktool = ["java", "-jar", args.apktool_jar.resolve()] if args.apktool_jar else ["apktool"]
    versions = json.loads((ROOT / "patcher/versions.json").read_text())
    out.mkdir(parents=True, exist_ok=True)
    ks = (args.keystore or out / "zvpatch-signing.jks").resolve()
    password = (args.password_file or out / "zvpatch-signing.pass").resolve()
    with tempfile.TemporaryDirectory(prefix="zvpatch-") as temporary:
        work = Path(temporary)
        stage = work / "splits"
        stage.mkdir()
        with zipfile.ZipFile(args.input) as archive:
            info = json.loads(archive.read("info.json"))
            version = info["release_version"]
            if info["pname"] != PACKAGE or version not in versions:
                parser.error(f"unsupported package/version: {info['pname']} {version}")
            config = versions[version]
            target = out / f"CreatorsApp_{version}_ZV-E10_release-arm64-v8a.apk"
            if target.exists():
                parser.error(f"output already exists: {target}; choose another --out directory")
            base = work / "base.apk"
            base.write_bytes(archive.read("base.apk"))
            base_hash = digest(base)
            if base_hash != config["base_sha256"]:
                parser.error(f"base SHA-256 mismatch: {base_hash}")
            selected = select_splits(archive.namelist())
            if "split_config.arm64_v8a.apk" not in selected:
                parser.error("arm64-v8a split is missing")
            for name in selected:
                (stage / name).write_bytes(archive.read(name))
        print(f"Building {version}: P1–P9 release, arm64-v8a", flush=True)
        decoded = work / "decoded"
        framework = work / "framework"
        run(*apktool, "d", "-r", "-f", "-p", framework, "-o", decoded, base)
        run(sys.executable, "-I", ROOT / "patcher" / config["patcher"], decoded, "release")
        patched = stage / "base.apk"
        run(*apktool, "b", "-p", framework, "-o", patched, decoded)
        merged = work / "merged.apk"
        run("java", "-jar", editor, "m", "-i", stage, "-o", merged,
            "-clean-meta", "-validate-modules")
        with zipfile.ZipFile(merged) as archive, zipfile.ZipFile(patched) as original:
            abis = {n.split("/")[1] for n in archive.namelist() if n.startswith("lib/")}
            if abis != {"arm64-v8a"}:
                raise ValueError(f"unexpected native library architectures: {abis}")
            for name in original.namelist():
                if name.endswith(".dex") and archive.read(name) != original.read(name):
                    raise ValueError(f"merge changed patched DEX: {name}")
            if archive.testzip() is not None:
                raise ValueError("merged APK failed CRC verification")
        if ks.exists() != password.exists():
            parser.error("keystore/password pair incomplete; restore the missing file")
        if not ks.exists():
            if args.keystore or args.password_file:
                parser.error("custom signing files must already exist")
            password.write_text(secrets.token_hex(16) + "\n")
            password.chmod(0o600)
            run("keytool", "-genkeypair", "-keystore", ks, "-storepass:file", password,
                "-keypass:file", password, "-alias", args.key_alias, "-keyalg", "RSA",
                "-keysize", "2048", "-validity", "10000", "-dname", "CN=zvpatch local build")
        aligned = work / "aligned.apk"
        signed = work / "signed.apk"
        run(zipalign, "-f", "-P", "16", "4", merged, aligned)
        run("java", "-jar", signer, "sign", "--ks", ks, "--ks-pass", f"file:{password}",
            "--ks-key-alias", args.key_alias, "--v2-signing-enabled", "true",
            "--v3-signing-enabled", "true", "--v4-signing-enabled", "false",
            "--out", signed, aligned)
        verification = run("java", "-jar", signer, "verify", "--min-sdk-version", "24",
                           "--verbose", "--print-certs", signed, capture=True)
        for scheme in ("v2", "v3"):
            if f"Verified using {scheme} scheme (APK Signature Scheme {scheme}): true" not in verification:
                raise ValueError(f"missing {scheme} signature")
        run(zipalign, "-c", "-P", "16", "4", signed)
        shutil.copyfile(signed, target)
        sha = digest(target)
        target.with_suffix(".apk.sha256").write_text(f"{sha}  {target.name}\n")
        report = {"version": version, "base_sha256": base_hash, "patcher": config["patcher"],
                  "patches": "P1-P9 release", "abi": "arm64-v8a", "output_sha256": sha,
                  "output_bytes": target.stat().st_size, "signature_verification": verification,
                  "device_tested": False}
        target.with_suffix(".build.json").write_text(json.dumps(report, indent=2) + "\n")
        print(f"Done: {target} ({target.stat().st_size / 2**20:.1f} MiB)")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        sys.exit(f"Build failed: {error}")
