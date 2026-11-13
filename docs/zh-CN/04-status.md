# 4. 现状与限制

> 3.6.0 / 3.6.1 的构建状态与限制见[构建说明](05-building.md)。下文真机结果仅针对 3.5.0。


测试环境：App 3.5.0（地区选中国香港），ZV-E10 固件 2.03，Android 16（一加，ColorOS）。

## 可用

| | USB<br>（电脑遥控） | Wi-Fi<br>（电脑遥控） | Wi-Fi<br>（智能手机连接） |
|---|---|---|---|
| 连接 | ✅ | ✅ | ✅ |
| 实时画面、曝光模式、曝光补偿、ISO | ✅ | ✅ | ✅ |
| 拍照 | ✅ | ✅ | ✅ |
| 照片自动传输到 `DCIM/CA_IMAGES/` | ✅ | ✅ | ✅ |
| 录像 | ✅ | ✅ | ✅ |
| 相机端：发送到智能手机 | ❌ | ❌ | ✅ |
| 手机端：浏览相册并导入 | ❌ | ❌ | ✅ |
| 退出远程拍摄、切换标签页后再进入 | ✅ | ✅ | ✅ |

- **连接方式**：电脑遥控支持 USB、Wi-Fi Direct 和接入点；智能手机连接仅支持 Wi-Fi Direct，与*发送到智能手机功能*共用同一套服务。
- **自动传输的文件**：电脑遥控下为 RAW+JPEG，智能手机连接下取决于*遥控拍摄设置*，实测为仅 JPEG。两者都由相机的设置决定。
- **导入的文件类型**：JPEG、RAW、视频均已实测可用。

## 不可用

| 功能 | 原因 |
|---|---|
| 电脑遥控模式下的传输 | 该模式下相机不开放存储：`GetStorageIDs` 回复 `StoreNotAvailable`，USB 和 Wi-Fi 都一样。USB 卡片上的导入按钮已隐藏（[P6](02-patches.md#p6--隐藏-usb-卡片上的导入按钮)），Wi-Fi 卡片由 App 自己置灰 |
| 电脑遥控开着时发送影像 | 相机拒绝，屏幕提示*"该操作或设定无法如下进行"* |
| 录完的视频自动传到手机 | 相机的保存目的地设置只管静态影像；请在相机上发送，或用导入 |
| 蓝牙配对 | App 的配对流程需要读取相机的固件版本、开启 Wi-Fi、状态通知等数据项，ZV-E10 的蓝牙服务没有这些，配对成功后随即失败 |
| 读取维修日志 | 被 [P4](02-patches.md#p4--could-not-perform实时画面转圈) 和 [P7](02-patches.md#p7--wi-fi-下相机不会出现在列表里) 跳过 |

未研究：云端功能、相机设置备份、固件升级、其它手机和固件版本。

## 注意

- **首次启动时地区选中国香港。** 选中国大陆的话，连接相机前需要登录 Creators' Cloud 账号（`CNApi.isNeedSignInForCameraConnect()`）。
- **把保存目的地设为*电脑+拍摄装置* / *手机+拍摄装置***，遥控拍下的照片才会同时留在存储卡上。
- **智能手机连接下退出远程拍摄要等约三秒**：App 正在把会话改回传输模式，这样相机随后的*发送到智能手机*才能生效。
- **USB 连接时，别的 App 申请访问相机要点取消**，否则实时画面停止，要重新插拔数据线。
- `DCIM/CA_IMAGES/` 里已有同名文件时不会被覆盖，新文件加 `_1`、`_2` 后缀。
- 显示刚拍的照片时，App 高频查询 `GetObjectInfo(0xFFFFC001)`（实测 10 秒约 1100 次），没有发现功能影响。

## 其它相机和 App 版本

- **新 App 版本**：按类名重新定位 `UsbSupportedCameraManager`、`UsbInsertedState`、`FunctionModeController.onResume`、`Ptp{Usb,Ip}Client.getDeviceLog`、`Ptp{Usb,Ip}Camera.initialize` / `switchFunctionMode`、`UsbCameraConnectionController`、`DeviceDescription.getControlModel`、`SearchedDeviceListController`、`DeviceInfo.isUxpSupported`、`LiveviewScreenController`。补丁工具默认拒绝其它 base APK（`ZVPATCH_SKIP_HASH=1` 可跳过），锚点对不上时会中止。
- **其它相机**：从 P1 开始，用调试版对比 DeviceInfo 命令列表和追踪日志，找第一条 `PTP FAIL`。
- **对官方支持机型的影响**：P1、P3、P7、P8 只在相机自报型号为 ZV-E10 时改变行为，或者只影响 App 对所有相机一视同仁的 USB 会话处理；P4、P7 使所有相机都不再读取维修日志；P5、P6 会让 USB 下本来支持内容传输的相机失去导入功能。
