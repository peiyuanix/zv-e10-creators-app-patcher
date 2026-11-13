#!/bin/zsh
# Build ZV-E10 compatible Creators' App packages from your own copy of the original app.
#
# Usage:
#   ./patch.sh <Creators' App 3.5.0 .xapk> [output-dir]
#
# Environment (all optional):
#   ZVPATCH_VARIANTS   "release debug" (default), "release" or "debug"
#   ZVPATCH_KEYSTORE   signing keystore to use instead of the generated one
#   ZVPATCH_KS_PASS    its store/key password
#   ZVPATCH_KEY_ALIAS  its key alias
#   ZVPATCH_SKIP_HASH  set to 1 to accept a base APK whose SHA-256 differs from the tested one
#
# Tested on macOS with Homebrew openjdk, apktool 3.0.3 and Android build-tools 35.0.0.
set -euo pipefail

SCRIPT_DIR=${0:a:h}
PKG=jp.co.sony.ips.portalapp
VERSION=3.5.0
TESTED_BASE_SHA256=b0716bf5b02b7c723d54d670d97c1c6c6daf0519a5ded5330fc4d9f3ff443f09
VARIANTS=(${=ZVPATCH_VARIANTS:-release debug})

die() { print -u2 "error: $*"; exit 1; }
step() { print "\n==> $*"; }

[[ $# -ge 1 ]] || die "usage: $0 <input.xapk> [output-dir]"
INPUT=${1:A}
OUT=${${2:-$PWD/out}:A}
[[ -f $INPUT ]] || die "input not found: $INPUT"

# --- toolchain --------------------------------------------------------------------------------
if [[ -z ${JAVA_HOME:-} ]]; then
  for candidate in /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
                   /usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home; do
    [[ -x $candidate/bin/java ]] && JAVA_HOME=$candidate && break
  done
  [[ -z ${JAVA_HOME:-} ]] && JAVA_HOME=$(/usr/libexec/java_home 2>/dev/null || true)
fi
[[ -n ${JAVA_HOME:-} && -x $JAVA_HOME/bin/java ]] || die "no JDK found (brew install openjdk)"
export JAVA_HOME PATH="$JAVA_HOME/bin:$PATH"

command -v apktool >/dev/null || die "apktool not found (brew install apktool)"
command -v python3 >/dev/null || die "python3 not found (xcode-select --install)"

BUILD_TOOLS=""
for sdk in ${ANDROID_HOME:-} ${ANDROID_SDK_ROOT:-} /opt/homebrew/share/android-commandlinetools \
           /usr/local/share/android-commandlinetools $HOME/Library/Android/sdk; do
  [[ -d $sdk/build-tools ]] || continue
  latest=$(ls -1 $sdk/build-tools | sort -V | tail -1)
  [[ -n $latest && -x $sdk/build-tools/$latest/apksigner ]] && BUILD_TOOLS=$sdk/build-tools/$latest && break
done
[[ -n $BUILD_TOOLS ]] || die "Android build-tools not found (see docs/en/03-debugging.md#tools)"
ZIPALIGN=$BUILD_TOOLS/zipalign
APKSIGNER=$BUILD_TOOLS/apksigner

# --- unpack and verify input ------------------------------------------------------------------
WORK=$(mktemp -d "${TMPDIR:-/tmp}/zvpatch.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

step "Unpacking $INPUT"
unzip -q "$INPUT" -d "$WORK/xapk"
BASE=$WORK/xapk/$PKG.apk
[[ -f $BASE ]] || die "$PKG.apk not found inside the XAPK"
SPLITS=("$WORK"/xapk/*.apk(N))
SPLITS=(${SPLITS:#$BASE})

sha=$(shasum -a 256 "$BASE" | cut -d' ' -f1)
if [[ $sha != $TESTED_BASE_SHA256 ]]; then
  [[ ${ZVPATCH_SKIP_HASH:-0} == 1 ]] || die "base APK SHA-256 is $sha, expected $TESTED_BASE_SHA256 (Creators' App $VERSION). Set ZVPATCH_SKIP_HASH=1 to try anyway."
  print "warning: base APK hash differs from the tested build; patch anchors will still be verified"
fi

# --- signing key ------------------------------------------------------------------------------
if [[ -n ${ZVPATCH_KEYSTORE:-} ]]; then
  KEYSTORE=${ZVPATCH_KEYSTORE:A}
  KS_PASS=${ZVPATCH_KS_PASS:?ZVPATCH_KS_PASS is required with ZVPATCH_KEYSTORE}
  KEY_ALIAS=${ZVPATCH_KEY_ALIAS:?ZVPATCH_KEY_ALIAS is required with ZVPATCH_KEYSTORE}
else
  KEYSTORE=$OUT/zvpatch-signing.jks
  KEY_ALIAS=zvpatch
  if [[ -f $OUT/zvpatch-signing.pass ]]; then
    KS_PASS=$(<"$OUT/zvpatch-signing.pass")
  else
    step "Generating a signing key (keep $KEYSTORE to install future updates over this build)"
    KS_PASS=$(openssl rand -hex 16)
    keytool -genkeypair -keystore "$KEYSTORE" -storepass "$KS_PASS" -keypass "$KS_PASS" \
      -alias "$KEY_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
      -dname "CN=zvpatch local build" >/dev/null 2>&1
    print -r -- "$KS_PASS" > "$OUT/zvpatch-signing.pass"
    chmod 600 "$OUT/zvpatch-signing.pass"
  fi
fi

sign() {  # sign <in.apk> <out.apk>
  "$ZIPALIGN" -f -p 4 "$1" "$2.aligned"
  "$APKSIGNER" sign --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" --key-pass "pass:$KS_PASS" \
    --ks-key-alias "$KEY_ALIAS" --out "$2" "$2.aligned" 2>/dev/null
  rm -f "$2.aligned" "$2.idsig"
  "$APKSIGNER" verify "$2" 2>/dev/null || die "signature verification failed: $2"
}

# --- decode once (code only: resources stay byte-identical, see docs) ------------------------
step "Decoding base APK (apktool d -r)"
apktool d -r -f -o "$WORK/decoded" "$BASE" >/dev/null

for variant in $VARIANTS; do
  step "Building $variant"
  rm -rf "$WORK/$variant"
  cp -R "$WORK/decoded" "$WORK/$variant"
  python3 "$SCRIPT_DIR/3.5/zvpatch.py" "$WORK/$variant" "$variant"

  apktool b -o "$WORK/$variant-unsigned.apk" "$WORK/$variant" >/dev/null
  stage=$WORK/$variant-stage
  mkdir -p "$stage"
  sign "$WORK/$variant-unsigned.apk" "$stage/$PKG.apk"
  for split in $SPLITS; do
    sign "$split" "$stage/${split:t}"
  done
  [[ -f $WORK/xapk/manifest.json ]] && cp "$WORK/xapk/manifest.json" "$stage/"

  target=$OUT/CreatorsApp_${VERSION}_ZV-E10_$variant.xapk
  rm -f "$target"
  (cd "$stage" && zip -0 -q -r "$target" .)
  print "  -> $target"
done

step "Done"
print "Uninstall any copy of Creators' App signed with a different key before installing."
