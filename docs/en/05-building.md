# Building and repository layout

The recommended entry point is `python3 tools/build.py <original.apkm>`. See the root README for
requirements and options (`--help` lists them). The default output is a release APK containing only
arm64-v8a native libraries, with all available language and density resources.

| Path | Purpose |
|---|---|
| `tools/build.py` | APKM verification, decode, patch, merge, alignment, signing and verification |
| `patcher/versions.json` | Accepted 3.6.x versions, original base hashes and patcher selection |
| `patcher/3.5/` | Original 3.5.0 patcher, compatibility helper and debug helpers |
| `patcher/3.6/` | Shared 3.6.0 / 3.6.1 P1–P9 patcher and helpers |
| `patcher/zvpatch.py` | Compatibility entry point for the old 3.5.0 command |
| `patcher/patch.sh` | Legacy macOS 3.5.0 XAPK workflow |
| `patcher/build-3.6.ps1` | Legacy Windows 3.6.0 split-bundle workflow |
| `inputs/` (optional, ignored) | Locally supplied original packages |
| `out/` (ignored) | Local tools, SDK, APKs, checksums, reports and signing material |
| `docs/en/`, `docs/zh-CN/` | Protocol notes, patches, debugging, status and build guide |

No original packages, built APKs, tool JARs or signing secrets are committed. Existing local files
remain usable; originals may also stay outside `inputs/` because package extensions are ignored.

## Supported inputs and validation

3.6.0 base SHA-256: `0ccd19a3d391218650d6013cf2b04e5b8e8644438f83a52e8d55302553708777`.

3.6.1 base SHA-256: `71989a7ce1a1da0bb3072f516ce0f27ff3d6ac54e9e7a63afdf3a2cb39d9833f`.

Both use `patcher/3.6/zvpatch.py` without bypassing anchors. The 3.6.1 version code is `361611060`.
All P1–P9 anchors match and the APK builds; this is not evidence of camera functionality.
3.6.1 has not been device-tested. The 3.6.0 upstream report covers Wi-Fi Smartphone Connect,
live view and still capture on one device. USB and Import remain untested in 3.6.x.

The builder checks the input hash, every patch anchor, unchanged patched DEX after merge, native ABI,
ZIP CRC, v2/v3 signatures and 16 KiB ZIP alignment. It writes a build report and SHA-256 sidecar.
16 KiB ZIP alignment does not validate the ELF alignment or runtime behavior of Sony's native libraries.

## Signing and installation

Keep `zvpatch-signing.jks` and `zvpatch-signing.pass` private and backed up. The default alias is
`zvpatch`; use `--key-alias` for another alias. A missing half of the pair aborts the build.
Custom signing files must already exist. Their key password must match the store password.

When changing output directories while retaining update compatibility:

```bash
python3 tools/build.py inputs/3.6.1.apkm --out out/rebuild \
  --keystore out/zvpatch-signing.jks --password-file out/zvpatch-signing.pass
```

Install with `adb install -r out/rebuild/CreatorsApp_3.6.1_ZV-E10_release-arm64-v8a.apk`.
A differently signed installation must be removed first. Choose Hong Kong on first launch.
Build dependencies are not downloaded automatically. Temporary build files are cleaned on success or failure.
