# 4. Status and limitations

> 3.6.0 / 3.6.1 build status and limitations: [build guide](05-building.md). The device results below are for 3.5.0.


Tested with app 3.5.0 (region: Hong Kong), ZV-E10 firmware 2.03, Android 16 (OnePlus, ColorOS).

## Works

| | USB<br>(PC Remote) | Wi-Fi<br>(PC Remote) | Wi-Fi<br>(Smartphone Connect) |
|---|---|---|---|
| Connection | ✅ | ✅ | ✅ |
| Live view, exposure mode, exposure compensation, ISO | ✅ | ✅ | ✅ |
| Photo capture | ✅ | ✅ | ✅ |
| Photos copied to `DCIM/CA_IMAGES/` | ✅ | ✅ | ✅ |
| Movie recording | ✅ | ✅ | ✅ |
| Camera side: Send to Smartphone | ❌ | ❌ | ✅ |
| Phone side: browse the card and import | ❌ | ❌ | ✅ |
| Leaving Remote Shooting, switching tabs and coming back | ✅ | ✅ | ✅ |

- **Connection methods.** PC Remote supports USB, Wi-Fi Direct and an access point; Smartphone Connect supports
  Wi-Fi Direct only and shares its service with *Send to Smartphone Func.*
- **Files copied automatically.** RAW+JPEG under PC Remote; under Smartphone Connect it follows *Remote Shoot
  Setting* (JPEG only as tested). Both are camera settings.
- **File types imported.** JPEG, RAW and movies were all tested.

## Not available

| Feature | Reason |
|---|---|
| Transfer in PC Remote mode | The camera exposes no storage there: `GetStorageIDs` → `StoreNotAvailable`, over USB and over Wi-Fi. Import is hidden on the USB card ([P6](02-patches.md#p6--hide-import-on-the-usb-card)) and greyed out by the app itself on the Wi-Fi card |
| Sending images while PC Remote is on | The camera refuses: *"The operation or setting cannot be performed"* |
| Automatic copy of a movie you just recorded | The camera's save-destination setting covers still images only; send the movie from the camera or use Import |
| Bluetooth pairing | The app's pairing flow needs camera characteristics (firmware version, "turn Wi-Fi on", status notifications) that the ZV-E10's Bluetooth service does not have; it stops right after bonding |
| Reading the service log | Skipped by [P4](02-patches.md#p4--could-not-perform-spinning-live-view) and [P7](02-patches.md#p7--the-camera-is-never-listed-over-wi-fi) |

Not investigated: cloud features, camera settings backup, firmware update, other phones and firmware versions.

## Notes

- **Choose Hong Kong as the region on first launch.** With mainland China the app requires a Creators' Cloud
  sign-in before connecting a camera (`CNApi.isNeedSignInForCameraConnect()`).
- **Set the save destination to *PC+Camera* / *Phone+Camera*** so photos taken remotely also stay on the card.
- **Leaving Remote Shooting under Smartphone Connect takes about three seconds** — the app reopens the session for
  transfer, which is what makes the camera's *Send to Smartphone* work right afterwards.
- **Tap Cancel when another app asks for access to the camera over USB**; otherwise live view stops until the cable
  is reconnected.
- A file that already exists in `DCIM/CA_IMAGES/` is kept: the new copy gets a `_1`, `_2`, … suffix.
- While showing the photo just taken, the app polls `GetObjectInfo(0xFFFFC001)` heavily (~1100 times in 10 s); no
  functional impact was seen.

## Other cameras and app versions

- **New app version:** relocate the patches by class name: `UsbSupportedCameraManager`, `UsbInsertedState`,
  `FunctionModeController.onResume`, `Ptp{Usb,Ip}Client.getDeviceLog`, `Ptp{Usb,Ip}Camera.initialize` /
  `switchFunctionMode`, `UsbCameraConnectionController`, `DeviceDescription.getControlModel`,
  `SearchedDeviceListController`, `DeviceInfo.isUxpSupported`, `LiveviewScreenController`. The patcher refuses other
  base APKs unless `ZVPATCH_SKIP_HASH=1`, and aborts when an anchor does not match.
- **Other cameras:** start from P1 and use the debug build to compare the DeviceInfo operation list with the trace;
  find the first `PTP FAIL`.
- **Effect on supported cameras:** P1, P3, P7 and P8 only change behaviour for a camera that identifies itself as
  ZV-E10, or for the USB session handling the app applies to any camera. P4 and P7 stop the service log from being
  read for every camera, and P5 and P6 remove contents transfer over USB, which a camera that supports it would
  otherwise offer.
