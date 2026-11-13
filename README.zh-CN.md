# ZV-E10 × Creators' App

为索尼 **Creators' App** 安卓版（3.5.0、3.6.0 和 3.6.1）提供补丁，使其支持初代 **ZV-E10**，USB 和 Wi-Fi 连接均可：实时画面与遥控操作、拍照与录像、拍摄的照片自动传输到手机、接收相机发送的影像、在手机上浏览存储卡并导入。

[English](README.md)

> 非官方项目，与索尼无关。仓库不含索尼的代码或二进制文件：原版 App 由你自己提供，补丁工具在本地修改，风险自负。

## 兼容性

Creators' App 的支持机型列表里有 ZV-E10 II，没有初代 ZV-E10，下面的功能都是本项目新适配的，均为打补丁后实测。

相机提供两套能力不同的 Wi-Fi 服务：*电脑遥控功能*用于遥控拍摄，*智能手机连接功能* / *发送到智能手机功能*用于传输文件。

| 功能 | USB<br>（电脑遥控） | Wi-Fi<br>（电脑遥控） | Wi-Fi<br>（智能手机连接） |
|---|---|---|---|
| 连接 | ✅ | ✅ | ✅ |
| 实时画面、曝光控制 | ✅ | ✅ | ✅ |
| 拍照 | ✅ | ✅ | ✅ |
| 照片自动传输到手机 | ✅ | ✅ | ✅ |
| 录像 | ✅ | ✅ | ✅ |
| 相机端：发送到智能手机 | ❌ | ❌ | ✅ |
| 手机端：浏览相册并导入 | ❌ | ❌ | ✅ |

- **连接方式**：电脑遥控支持 USB、Wi-Fi Direct 和接入点（相机接入路由器）；智能手机连接仅支持 Wi-Fi Direct。
- **传输**：电脑遥控模式下相机不开放存储，也拒绝发送影像，因此两项传输功能都不可用。录制完成的视频不会自动传输到手机，保存目的地设置只对静态影像生效。

测试环境：App 3.5.0，ZV-E10 固件 2.03，Android 16。

## 原版 App 为什么不能直接使用

1. USB 下，App 按**支持机型列表**检查型号并拒绝 ZV-E10，提示连接失败。→ **P1**
2. 插上相机后用**传输内容**模式打开会话，电脑遥控模式下相机不接受，界面一直转圈。→ **P2**
3. 相机页每次显示都会**把会话改成传输内容模式**，远程拍摄提示 *"Could not connect to your camera via USB."*。→ **P3**
4. 会话打开后 App 索取相机的**服务日志**，ZV-E10 没有这条命令，报错后整个会话失效：画面转圈、提示 *"Could not perform."*。→ **P4**、**P7**
5. 离开相机页再回来，又会以传输内容模式重连。→ **P5**
6. Wi-Fi 下相机**根本不会出现在列表里**：App 要求协议版本 3.01 并声明媒体服务，ZV-E10 都不满足。→ **P7**
7. 同一道版本检查还挡住了**导入**和**自动接收相机发来的影像**。→ **P8**
8. 相机上的实时画面已经开着时（比如刚用过别的 App），进远程拍摄会**一直黑屏转圈**。→ **P9**

详见[问题与补丁](docs/zh-CN/02-patches.md)。

## 文档

1. [App 如何与相机通信](docs/zh-CN/01-how-it-works.md)
2. [问题与补丁](docs/zh-CN/02-patches.md)
3. [调试方法](docs/zh-CN/03-debugging.md)
4. [现状与限制](docs/zh-CN/04-status.md)
5. [构建与项目结构](docs/zh-CN/05-building.md)

## 打补丁（3.6.0 / 3.6.1，推荐）

新构建入口默认只生成 **arm64-v8a 单 APK**，保留全部语言与屏幕密度资源，复用本地签名密钥。
依赖 Python 3.11+、JDK、apktool 3.0.3、Android build-tools 35.0.0 和 APKEditor 1.4.9；工具需自行下载。

```bash
python3 tools/build.py "3.6.1.apkm" \
  --build-tools out/android-sdk/build-tools/35.0.0 \
  --apkeditor out/APKEditor-1.4.9.jar
```

Windows 可用 `python`，未配置 apktool 命令时添加 `--apktool-jar C:\path\apktool.jar`。
同一命令支持仓库版本表中的 3.6.0 APKM。脚本会检查包名、版本、基础包 SHA-256，以及全部 P1–P9 锚点；
不接受未知输入。3.6.x 仅支持 release，D1–D3 调试补丁尚未适配。

3.6.1 输出：

- `out/CreatorsApp_3.6.1_ZV-E10_release-arm64-v8a.apk`，约 135.5 MiB，可直接安装。
- 相邻 `.apk.sha256` 与 `.build.json`：校验和及构建验证记录。
- `out/zvpatch-signing.jks` / `.pass`：复用或新建的签名文件，请私下备份两者。

脚本拒绝覆盖现有 APK。另选 `--out` 时，可用 `--keystore` 和 `--password-file` 指向原密钥，保持签名一致。
要求 Android 13+、arm64-v8a 手机；签名冲突时先卸载官方版。首次启动地区选“中国香港”。

**3.6.1 已通过构建验证，尚未真机测试。** 验证包含 P1–P9、合并后补丁 DEX 不变、仅 arm64 原生库、
v2/v3 签名、ZIP 完整性及 16 KiB ZIP 对齐。ZIP 对齐不代表原生库已验证兼容 16 KiB 内存页。
3.6.0 上游仅报告一台设备的 Wi-Fi 智能手机连接、实时画面和拍照可用，USB、Import 未测试。
详细步骤与目录说明见[构建说明](docs/zh-CN/05-building.md)。

旧 `patcher/build-3.6.ps1` 保留为 Windows 全架构分包 XAPK 流程；arm64 单 APK 请使用新入口。

## 打补丁（3.5.0，macOS 旧流程）


```bash
brew install openjdk apktool
brew install --cask android-commandlinetools
sdkmanager "build-tools;35.0.0"

./patcher/patch.sh "Creators' App_3.5.0.xapk" out/
```

输入的 XAPK 里，基础 APK 的 SHA-256 必须是
`b0716bf5b02b7c723d54d670d97c1c6c6daf0519a5ded5330fc4d9f3ff443f09`。产物：

- `CreatorsApp_3.5.0_ZV-E10_release.xapk`：打好补丁的 App
- `CreatorsApp_3.5.0_ZV-E10_debug.xapk`：同上，附带 PTP 追踪日志，用于反馈问题
- `zvpatch-signing.jks` / `.pass`：你的签名密钥，保留它才能覆盖安装以后的版本

安装前先卸载原版 App（签名不同），然后用 XAPK 安装器安装。

## 使用

首次启动时地区选 **Hong Kong**：选中国大陆的话，App 要求先登录 Creators' Cloud 才能连相机。下面的相机菜单名以中文机身菜单为准。

**USB** —— 相机：*网络 → 电脑遥控功能*，*电脑遥控：开*、*电脑遥控连接方式：USB*。插上线并允许 Creators' App 访问 USB 设备，**Cameras** 页会出现相机和 **Remote Shooting** 按钮。

**Wi-Fi 遥控** —— 相机：*电脑遥控：开*，连接方式选 *Wi-Fi 接入点连接*（相机接入你的路由器，用 *Wi-Fi 设置* 配置）或 *Wi-Fi Direct*（相机开热点，手机连上去）。App 里点 **Cameras → 右上角齿轮 → Connect only via Wi-Fi**，再选相机。接入点方式首次连接需要在相机上确认配对。

**Wi-Fi 传文件** —— 先把*电脑遥控*关掉，开着时相机会拒绝发送。然后用 *网络 → 发送到智能手机功能 → 发送到智能手机*（在相机上挑照片），或 *网络 → 智能手机连接功能 → 连接*。手机连上相机显示的 `DIRECT-…` 热点，再在 App 里用 **Connect only via Wi-Fi** 连接。

- 在相机上选好的影像，App 连上后会自动接收，中途的提示框点确认即可。
- 相机上没有待发送影像时，点 **Import** 可以浏览整张卡并下载选中的文件。
- 传过来的是原始尺寸还是缩小尺寸、RAW+JPEG 还是仅 JPEG，由相机里*发送到智能手机功能*和*智能手机连接功能 → 遥控拍摄设置*的设置决定。

**注意**

- 把*静态影像保存目的地*设为*电脑+拍摄装置*（电脑遥控）或*手机+拍摄装置*（遥控拍摄设置），照片才会同时留在存储卡上。
- 智能手机模式下退出远程拍摄会等几秒：App 正在把会话改回传输模式，这样相机才能继续发送影像。
- USB 连接期间，如果别的 App（例如相册）请求访问相机，请点**取消**。

## 免责声明

Sony、ZV-E10、Creators' App 是索尼集团的商标，此处仅用于说明兼容性。补丁只改动机型检查、会话处理和一个按钮，不涉及账号、登录、订阅或网络服务。按现状提供，不作任何担保。

## 许可

[MIT](LICENSE)
