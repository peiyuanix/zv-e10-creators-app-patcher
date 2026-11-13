# 2. 问题与补丁

所有补丁针对 3.5.0 版、用 `apktool d -r` 反编译出的代码。实现见 [`patcher/zvpatch.py`](../../patcher/3.5/zvpatch.py)：每个补丁按类描述符定位，锚点必须恰好匹配一次，否则中止。日志片段来自调试版（[D1–D3](#仅调试版)），有删减。

P1–P6 解决 USB 连接，P7–P9 解决 Wi-Fi 和传输功能。其中两个补丁会加入一个小的辅助类 `zv/ZvWifiCompat`，它通过读取相机自己的 DID 来回答两个问题："这是不是 ZV-E10"、"当前会话是不是电脑遥控"。

## P1 —— 不在支持机型列表里

- **原因**：`usb/UsbSupportedCameraManager` 在支持机型列表里找不到 `ZV-E10`，返回 `NOT_SUPPORTED_CAMERA_FAIL`。内置列表和服务器列表里都只有 ZV-E10 II（`ZV-E10M2`）。
- **改动**：在 `…$set$deviceInfoUpdaterListener$1.onDeviceInfoChanged()` 里，往它持有的列表副本中加入 `modelName = "ZV-E10"`。服务器更新列表不会覆盖这个改动。

## P2 —— 插上相机后一直转圈

- **原因**：`usb/statemachine/UsbInsertedState.onEnter()` 用 `CONTENTS_TRANSFER_PULL` 自动连接，相机拒绝存储相关请求，会话无声结束：
  ```
  PTP req  op=SDIO_OpenSession params=[1, 1]
  PTP FAIL op=GetStorageIDs code=StoreNotAvailable
  PTP FAIL op=GetObjectPropsSupported code=OperationNotSupported
  ```
- **改动**：`UsbInsertedState` 和 `UsbInsertedState$onEnter$1$1` 里的三处改为 `REMOTE_CONTROL`。

## P3 —— "Could not connect to your camera via USB."

- **原因**：相机页显示时，`FunctionModeController.onResume()` 把刚建立的遥控会话切到传输模式——也就是关闭会话、以相机在电脑遥控模式下拒绝的模式重开：
  ```
  SWITCH function mode to=CONTENTS_TRANSFER_MODE
      at camera.CameraConnector.switchFunctionMode
      at toppage.devicetab.controller.FunctionModeController.onResume
  ```
- **改动**：先问 `zv/ZvWifiCompat.keepSessionMode()`。USB 会话，以及 DID 声明没有媒体服务的 Wi-Fi 会话（电脑遥控），回答"保持当前模式"；智能手机连接下仍走原版逻辑——正是这一步让你退出远程拍摄后相机还能继续发送影像。

## P4 —— "Could not perform."、实时画面转圈

- **原因**：会话打开后，相机对象调用 `getDeviceLog()` 读取维修日志。ZV-E10 的命令列表里没有 `SDIO_GetDeviceLog`，拒绝之后，这个会话上的所有命令都会失败：
  ```
  PTP FAIL op=SDIO_GetDeviceLog code=InvalidParameter
  PTP FAIL op=SDIO_GetAllExtDevicePropInfo code=GeneralError
  PTP FAIL op=SDIO_ControlDevice code=GeneralError
  ```
- **改动**：`ptpip/PtpUsbClient.getDeviceLog()` 直接返回（P7 对 `PtpIpClient` 做同样处理）。维修日志不再读取，它只供索尼售后使用。

## P5 —— 去过别的标签页后连接再次失败

- **原因**：首页、图库、社区页会断开相机；回到相机页重连时，新的相机对象又以传输模式打开会话，初始化失败（`SDIO_OpenSession params=[1, 1]` → `INIT FAILED code=GeneralError`）。P2、P3 改的是调用方，覆盖不到这条路径。
- **改动**：在 `camera/PtpUsbCamera` 内部处理：`initialize()` 始终使用 `REMOTE_CONTROL_MODE`，`switchFunctionMode()` 对其它模式返回 `false`。

## P6 —— 隐藏 USB 卡片上的导入按钮

- **原因**：USB 下相机不发布 DID，App 无从判断能否传输内容，于是把 Import 显示为可用。点下去只会以*"Failed to access storage on the camera"* 收场：ZV-E10 接受 `SDIO_SetContentsTransferMode(2, 1, 0)`，但 `GetStorageIDs` 始终回复 `StoreNotAvailable`。
- **改动**：`toppage/devicetab/controller/UsbCameraConnectionController` 绑定卡片时，把 Import（`0x7f0a0494`）设为 `View.GONE`，Remote Shooting 占满整行。Wi-Fi 卡片无需改动：App 自己会在电脑遥控模式下置灰、在智能手机连接下启用。

## P7 —— Wi-Fi 下相机不会出现在列表里

- **原因**：`DeviceDescription.getControlModel()` 要求 DID 版本至少 3.0，并且要么声明媒体服务、要么版本达到 4.0，否则返回 `Unknown`。ZV-E10 在电脑遥控模式下报 3.00 且没有媒体服务，于是被 `SsdpUtil` 拉黑，搜索界面一直停在 *Searching a camera…*。即使能选中，`toppage/devicetab/wificonnect/SearchedDeviceListController$selectedConnectDevice$1` 里还有同样的检查。
  ```
  SSDP DD.xml url=http://192.168.1.20:64321/dd.xml
  DID name=ZV-E10 serverVersion=3.00 ptpVersions=3.00 mediaServer=DISABLE remoteControl=ENABLE
  ```
- **改动**：四处，都由 `zv/ZvWifiCompat` 判断：
  - `getControlModel()` 对 ZV-E10 返回 `SelectFunction`，相机因此能出现在列表里；
  - `selectedConnectDevice$1` 里的内容传输检查放行，电脑遥控模式才能被选中；
  - `camera/PtpIpCamera.initialize()` 和 `switchFunctionMode()` 让**电脑遥控**会话保持在 `REMOTE_CONTROL_MODE`，智能手机连接下维持原样；
  - `ptpip/PtpIpClient.getDeviceLog()` 直接返回，同 P4。

## P8 —— 相机发送影像时没反应，导入也用不了

- **原因**：两条传输路径都受 `DeviceInfo.isUxpSupported()` 控制，即要求 DID 版本 ≥ 3.01。`ContentsPushController` 只在它为真时才启动自动下载，所以相机执行*发送到智能手机*后一直等待；导入界面也不会去请求相机开放存储卡。
- **改动**：机型名为 `ZV-E10` 时 `isUxpSupported()` 返回 `true`，其它相机维持原版判断。改完后，相机主动发送是这样的：
  ```
  STORAGE ids=[VIRTUAL_MEDIA_1]
  PTPIP req op=SDIO_SetContentsTransferMode params=[1, 1, 0]
  PTPIP req op=GetObjectHandles params=[15794177, 0, 16]
  PTPIP req op=SDIO_GetPartialLargeObject params=[33, 0, 0, 3145728]
  ```
  导入则能拿到存储卡：
  ```
  PTPIP req op=SDIO_SetContentsTransferMode params=[2, 1, 0]
  STORAGE ids=[STORAGE_MEDIA_1]
  PTPIP req op=GetObjectHandles params=[65537, 0, 1073742000]
  ```

## P9 —— 远程拍摄页面黑屏

- **原因**：实时画面流的启动时机，是相机**上报状态发生变化**，或走已注册相机的连接流程。如果会话建立时相机的实时画面已经开着——比如刚被别的 App 用过，或者会话是重开的——就等不到这个变化，没有人去启动画面流：
  ```
  INIT OK mode=REMOTE_CONTROL_MODE
  LV status value=1 enable=True          <- 实时画面本来就是开的
  （没有 "LV setLiveViewStreamCallback"，也没有帧）
  ```
- **改动**：`ptp/remotecontrol/controller/liveview/LiveviewScreenController` 的构造函数本来就会把自己注册为画面接收方，现在同时调用 `BaseCamera.setLiveViewStreamCallback()`。该方法会重新检查相机的实时画面状态和"是否已启动"标志，所以画面没开或已经在传时，这次调用不做任何事。

## 仅调试版

- **D1**：加入 `zv/ZvLog`，在 USB 的 `TransactionExecutor` 里记录请求、成功、失败（日志标签 `ZVPATCH`），另外记录事务超时和初始化结果。实时画面的轮询只在失败且不是 `AccessDenied` 时记录。
- **D2**：在 `BasePtpManager.terminatePtpCommunication()`、`PtpUsbClient.switchFunctionMode()`、`PtpUsbCamera.disconnect()` 打印调用栈，用来确认是谁关闭了会话。
- **D3**：加入 `zv/ZvWifi`，记录 Wi-Fi 侧的信息：发现的每个 `dd.xml` 及决定能否连接的 DID 字段、每一次 PTP-IP 事务、传输会话暴露的存储、以及实时画面流（回调设置、HTTP 流启动、帧计数、失败）。

## 签名

XAPK 里的所有 APK（基础包和各个 split）必须用同一把密钥、以 v2/v3 方式签名（先 `zipalign -p 4`，再 `apksigner`）。用你的密钥签出来的包，无法覆盖安装用其它密钥签名的版本。
