# 2. Problems and patches

All patches target app 3.5.0 decoded with `apktool d -r`. The implementation is
[`patcher/zvpatch.py`](../../patcher/3.5/zvpatch.py); each patch finds its target by class descriptor and aborts if its
anchor does not match exactly once. Logs come from the debug build ([D1–D3](#debug-build-only)), shortened.

P1–P6 are about the USB connection, P7–P9 about Wi-Fi and the transfer paths. Two of them add a small helper class,
`zv/ZvWifiCompat`, which answers "is this a ZV-E10" and "is this session a PC Remote session" by reading the
camera's own DID.

## P1 — Not in the supported camera list

- **Cause:** `usb/UsbSupportedCameraManager` does not find `ZV-E10` in the supported camera list →
  `NOT_SUPPORTED_CAMERA_FAIL`. Both the bundled and the server-provided list contain the ZV-E10 II (`ZV-E10M2`), not
  the original model.
- **Change:** `…$set$deviceInfoUpdaterListener$1.onDeviceInfoChanged()` adds an entry with `modelName = "ZV-E10"` to
  its copy of the list. Server updates to the list do not undo this.

## P2 — Endless spinner after plugging in

- **Cause:** `usb/statemachine/UsbInsertedState.onEnter()` auto-connects with `CONTENTS_TRANSFER_PULL`; the camera
  refuses the storage requests and the session ends silently:
  ```
  PTP req  op=SDIO_OpenSession params=[1, 1]
  PTP FAIL op=GetStorageIDs code=StoreNotAvailable
  PTP FAIL op=GetObjectPropsSupported code=OperationNotSupported
  ```
- **Change:** the three uses in `UsbInsertedState` and `UsbInsertedState$onEnter$1$1` become `REMOTE_CONTROL`.

## P3 — "Could not connect to your camera via USB."

- **Cause:** when the Cameras tab is shown, `FunctionModeController.onResume()` switches the freshly opened remote
  session to contents transfer, i.e. closes it and reopens it in a mode the camera refuses in PC Remote mode:
  ```
  SWITCH function mode to=CONTENTS_TRANSFER_MODE
      at camera.CameraConnector.switchFunctionMode
      at toppage.devicetab.controller.FunctionModeController.onResume
  ```
- **Change:** ask `zv/ZvWifiCompat.keepSessionMode()` first. It answers "keep the current mode" for USB sessions and
  for a Wi-Fi session whose DID reports no media server (PC Remote). Under Smartphone Connect the stock switch
  still runs — that is what lets the camera send images after you leave Remote Shooting.

## P4 — "Could not perform.", spinning live view

- **Cause:** after the session opens, the camera object calls `getDeviceLog()` to read the service log. The ZV-E10
  does not list `SDIO_GetDeviceLog`; after rejecting it, every command on the session fails:
  ```
  PTP FAIL op=SDIO_GetDeviceLog code=InvalidParameter
  PTP FAIL op=SDIO_GetAllExtDevicePropInfo code=GeneralError
  PTP FAIL op=SDIO_ControlDevice code=GeneralError
  ```
- **Change:** `ptpip/PtpUsbClient.getDeviceLog()` returns immediately (P7 does the same for `PtpIpClient`). The
  service log is no longer read; it is only used for Sony's support tooling.

## P5 — Connection fails again after visiting another tab

- **Cause:** the Home, Library and Community tabs disconnect the camera; when the Cameras tab reconnects, the new
  camera object opens the session in contents-transfer mode again and initialisation fails
  (`SDIO_OpenSession params=[1, 1]` → `INIT FAILED code=GeneralError`). P2 and P3 patch callers and do not cover
  this path.
- **Change:** handle it in `camera/PtpUsbCamera`: `initialize()` always uses `REMOTE_CONTROL_MODE`, and
  `switchFunctionMode()` returns `false` for any other mode.

## P6 — Hide Import on the USB card

- **Cause:** over USB the camera publishes no DID, so the app cannot tell that contents transfer is unavailable and
  shows Import as enabled. Tapping it can only end in *"Failed to access storage on the camera"*: the ZV-E10 accepts
  `SDIO_SetContentsTransferMode(2, 1, 0)` but keeps answering `GetStorageIDs` with `StoreNotAvailable`.
- **Change:** when `toppage/devicetab/controller/UsbCameraConnectionController` binds the card, Import (`0x7f0a0494`)
  is set to `View.GONE`; Remote Shooting fills the row. On the Wi-Fi card no change is needed: the app greys Import
  out by itself in PC Remote mode and enables it under Smartphone Connect.

## P7 — The camera is never listed over Wi-Fi

- **Cause:** `DeviceDescription.getControlModel()` returns `Unknown` unless the DID reports a version of at least
  3.0 **and** either a media server or version 4.0. The ZV-E10 reports 3.00 without a media server in PC Remote
  mode, so `SsdpUtil` blacklists it and the search screen keeps saying *Searching a camera…*. Selecting the camera
  would then hit the same check again in
  `toppage/devicetab/wificonnect/SearchedDeviceListController$selectedConnectDevice$1`.
  ```
  SSDP DD.xml url=http://192.168.1.20:64321/dd.xml
  DID name=ZV-E10 serverVersion=3.00 ptpVersions=3.00 mediaServer=DISABLE remoteControl=ENABLE
  ```
- **Change:** four edits, all guarded by `zv/ZvWifiCompat`:
  - `getControlModel()` returns `SelectFunction` for the ZV-E10, so it is listed;
  - the contents-transfer check in `selectedConnectDevice$1` accepts it, so PC Remote mode can be selected;
  - `camera/PtpIpCamera.initialize()` and `switchFunctionMode()` keep a **PC Remote** session in
    `REMOTE_CONTROL_MODE`; under Smartphone Connect both behave as before;
  - `ptpip/PtpIpClient.getDeviceLog()` returns immediately, as in P4.

## P8 — Nothing happens when the camera sends images, Import stays unusable

- **Cause:** both transfer paths are gated on `DeviceInfo.isUxpSupported()`, i.e. DID version ≥ 3.01.
  `ContentsPushController` only starts the automatic copy when it is true, so the camera waits forever after *Send
  to Smartphone*, and the Import screen never asks the camera to expose the card.
- **Change:** `isUxpSupported()` answers `true` when the model name is `ZV-E10`; every other camera keeps the stock
  version check. With that, a camera-initiated transfer looks like this:
  ```
  STORAGE ids=[VIRTUAL_MEDIA_1]
  PTPIP req op=SDIO_SetContentsTransferMode params=[1, 1, 0]
  PTPIP req op=GetObjectHandles params=[15794177, 0, 16]
  PTPIP req op=SDIO_GetPartialLargeObject params=[33, 0, 0, 3145728]
  ```
  and Import exposes the card:
  ```
  PTPIP req op=SDIO_SetContentsTransferMode params=[2, 1, 0]
  STORAGE ids=[STORAGE_MEDIA_1]
  PTPIP req op=GetObjectHandles params=[65537, 0, 1073742000]
  ```

## P9 — Black Remote Shooting screen

- **Cause:** the live-view stream is started when the camera *reports a change* of its live-view status, or by the
  connection paths used for registered cameras. If live view is already enabled when the session opens — after
  another app used the camera, or after the session is reopened — no change arrives and nothing starts the stream:
  ```
  INIT OK mode=REMOTE_CONTROL_MODE
  LV status value=1 enable=True          <- live view already on
  (no "LV setLiveViewStreamCallback", no frames)
  ```
- **Change:** `ptp/remotecontrol/controller/liveview/LiveviewScreenController`'s constructor already registers
  itself for frames; it now also calls `BaseCamera.setLiveViewStreamCallback()`. That method re-checks the camera's
  live-view status and the "already started" flag, so the call does nothing when live view is off or already
  running.

## Debug build only

- **D1:** adds `zv/ZvLog` and logs (tag `ZVPATCH`) request, success and failure in the USB `TransactionExecutor`,
  plus transaction timeouts and the initialisation result. Live-view polling logs only failures other than
  `AccessDenied`.
- **D2:** prints a stack trace in `BasePtpManager.terminatePtpCommunication()`, `PtpUsbClient.switchFunctionMode()`
  and `PtpUsbCamera.disconnect()` to show who closed the session.
- **D3:** adds `zv/ZvWifi` for the Wi-Fi side: every `dd.xml` found and the DID fields that gate the connection,
  every PTP-IP transaction, the storages a contents-transfer session exposes, and the live-view stream (callback,
  HTTP stream start, frame count, failures).

## Signing

All APKs in the XAPK (base and splits) must be signed with the same key using v2/v3 signatures (`zipalign -p 4`
first, then `apksigner`). A build signed with your key cannot be installed over one signed with another key.
