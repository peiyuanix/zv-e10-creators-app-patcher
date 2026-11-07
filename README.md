# ZV-E10 × Creators' App

Patches for Sony's **Creators' App** for Android (3.5.0) that add support for the original **ZV-E10** over USB and
Wi-Fi: live view and remote control, still and movie shooting, automatic copy of captured photos, transfer of images
sent from the camera, and browsing the memory card from the phone.

[中文说明](README.zh-CN.md)

> Unofficial, not affiliated with Sony. No Sony code or binaries are included: you supply the original app and
> the patcher modifies it locally, at your own risk.

## Compatibility

Creators' App's supported camera list includes the ZV-E10 II but not the original ZV-E10; everything below was
adapted by this project and tested with the patched app.

The camera provides two Wi-Fi services with different capabilities: *PC Remote Function* for remote control, and
*Smartphone Connect Function* / *Send to Smartphone Func.* for file transfer.

| Feature | USB<br>(PC Remote) | Wi-Fi<br>(PC Remote) | Wi-Fi<br>(Smartphone Connect) |
|---|---|---|---|
| Connection | ✅ | ✅ | ✅ |
| Live view, exposure controls | ✅ | ✅ | ✅ |
| Photo capture | ✅ | ✅ | ✅ |
| Photos copied to the phone automatically | ✅ | ✅ | ✅ |
| Movie recording | ✅ | ✅ | ✅ |
| Camera side: Send to Smartphone | ❌ | ❌ | ✅ |
| Phone side: browse the card and import | ❌ | ❌ | ✅ |

- **Connection methods.** PC Remote supports USB, Wi-Fi Direct and an access point (the camera joins your router).
  Smartphone Connect supports Wi-Fi Direct only.
- **Transfer.** In PC Remote mode the camera exposes no storage and refuses to send images, so both transfer rows
  are unavailable there. Movies are never copied automatically after recording: the save-destination setting covers
  still images only.

Tested: app 3.5.0, ZV-E10 firmware 2.03, Android 16.

## Why the unpatched app cannot be used

1. Over USB the app checks the model against its **supported camera list** and rejects the ZV-E10 → *"Connection
   failed"*. → **P1**
2. On plug-in it opens a **contents-transfer** session, which the camera refuses in PC Remote mode → endless
   spinner. → **P2**
3. Every time the Cameras tab appears it **reopens the session for contents transfer**, so Remote Shooting says
   *"Could not connect to your camera via USB."* → **P3**
4. Right after the session opens it asks for the camera's **service log**, an operation the ZV-E10 does not
   implement; the error poisons the session → spinning live view, *"Could not perform."* → **P4**, **P7**
5. Leaving the Cameras tab and coming back reconnects in contents-transfer mode again. → **P5**
6. Over Wi-Fi the camera is **never listed**: the app requires protocol version 3.01 and a media-server flag that
   the ZV-E10 does not report. → **P7**
7. The same version check blocks **Import** and the automatic copy of images the camera sends. → **P8**
8. Remote Shooting can open with a **black screen** when live view is already running on the camera (for example
   after another app used it). → **P9**

Details: [problems and patches](docs/en/02-patches.md).

## Documentation

1. [How the app talks to the camera](docs/en/01-how-it-works.md)
2. [Problems and patches](docs/en/02-patches.md)
3. [Debugging workflow](docs/en/03-debugging.md)
4. [Status and limitations](docs/en/04-status.md)

## Patching (macOS)

```bash
brew install openjdk apktool
brew install --cask android-commandlinetools
sdkmanager "build-tools;35.0.0"

./patcher/patch.sh "Creators' App_3.5.0.xapk" out/
```

The input XAPK must contain a base APK with SHA-256
`b0716bf5b02b7c723d54d670d97c1c6c6daf0519a5ded5330fc4d9f3ff443f09`. Output:

- `CreatorsApp_3.5.0_ZV-E10_release.xapk` — the patched app
- `CreatorsApp_3.5.0_ZV-E10_debug.xapk` — same, with PTP tracing for bug reports
- `zvpatch-signing.jks` / `.pass` — your signing key; keep it to install future builds as updates

Uninstall the original app first (different signature), then install the XAPK with an XAPK installer.

### Creators' App 3.6.0 (Windows, experimental)

`patcher/3.6/` holds the same patches (P1–P9) re-anchored for 3.6.0, and `patcher/build-3.6.ps1`
builds, aligns and signs a split bundle from an APKMirror `.apkm` (base SHA-256
`0ccd19a3d391218650d6013cf2b04e5b8e8644438f83a52e8d55302553708777`). Requirements: JDK, Python 3,
[apktool](https://apktool.org) 3.0.3 and Android build-tools 35.0.0.

```powershell
powershell -ExecutionPolicy Bypass -File patcher\build-3.6.ps1 -Apkm "<file>.apkm" -Apktool C:\path\apktool.jar -Out out
adb install-multiple -r (Get-ChildItem out\apks_3.6.0_release\*.apk).FullName
```

Only the release variant is ported; the debug patches (D1–D3) are untouched. Tested on one device over
Wi-Fi (Smartphone Connect): connection, live view and still capture work. USB and Import are untested.
The 3.5.0 patcher above is unchanged.

## Use

On first launch, choose **Hong Kong** as the region: with mainland China the app requires a Creators' Cloud sign-in
before it connects to a camera. Camera menu names below follow the camera's English menus.

**USB** — *Network → PC Remote Function*: *PC Remote: On*, *PC Remote Cnct Method: USB*. Connect the cable and allow
USB access for Creators' App. The **Cameras** tab shows the camera with a **Remote Shooting** button.

**Wi-Fi, remote control** — *PC Remote Function*: *PC Remote: On*, *PC Remote Cnct Method: Wi-Fi Access Point* (the
camera joins your router; *Wi-Fi Settings* sets it up) or *Wi-Fi Direct* (the camera opens a hotspot, connect the
phone to it). In the app: **Cameras → gear icon → Connect only via Wi-Fi**, then pick the camera. Access-point mode
asks for a one-time pairing on the camera the first time.

**Wi-Fi, transfer** — turn *PC Remote* **off** first; the camera refuses to send images while it is on. Then either
*Network → Send to Smartphone Func. → Send to Smartphone* (pick the images on the camera) or *Network → Smartphone
Connect Function → Connection*. Connect the phone to the `DIRECT-…` hotspot the camera shows, then use
**Connect only via Wi-Fi** in the app.

- Images you selected on the camera arrive by themselves once the app has connected; confirm the notice dialog.
- With nothing selected on the camera, **Import** browses the whole card and downloads what you pick.
- What arrives (original or reduced size, RAW+JPEG or JPEG only) follows the camera's own settings under *Send to
  Smartphone Func.* and *Smartphone Connect Function → Remote Shoot Setting*.

**Notes**

- Set *Still Img. Save Dest.* to *PC+Camera* (PC Remote) or *Phone+Camera* (Remote Shoot Setting) so photos also
  stay on the memory card.
- Leaving Remote Shooting under Smartphone Connect takes a few seconds: the app reopens the session so the camera
  can send images again.
- While the camera is connected over USB, tap **Cancel** if another app (for example the Gallery) asks for access.

## Disclaimer

Sony, ZV-E10 and Creators' App are trademarks of Sony Group Corporation, used only to describe compatibility.
The patches change the camera model check, the session handling and one button only; they do not touch accounts,
sign-in, subscriptions or network services. Provided as-is, without warranty.

## License

[MIT](LICENSE)
