# 构建与项目结构

推荐入口为 `python3 tools/build.py <原版.apkm>`，依赖和命令见根目录 README，所有参数可用 `--help` 查看。
默认输出 release 单 APK，仅包含 arm64-v8a 原生库，保留全部语言及屏幕密度资源。

| 路径 | 用途 |
|---|---|
| `tools/build.py` | APKM 校验、反编译、补丁、合并、对齐、签名和验证 |
| `patcher/versions.json` | 支持的 3.6.x 版本、原版基础包哈希和补丁选择 |
| `patcher/3.5/` | 原 3.5.0 补丁及兼容、调试辅助类 |
| `patcher/3.6/` | 3.6.0 / 3.6.1 共用的 P1–P9 补丁及辅助类 |
| `patcher/zvpatch.py` | 旧 3.5.0 命令的兼容入口 |
| `patcher/patch.sh` | 旧 macOS 3.5.0 XAPK 流程 |
| `patcher/build-3.6.ps1` | 旧 Windows 3.6.0 分包流程 |
| `inputs/`（可选，忽略） | 用户自行提供的原版安装包 |
| `out/`（忽略） | 本地工具、SDK、产物、校验文件、报告和签名文件 |
| `docs/en/`、`docs/zh-CN/` | 通信原理、补丁、调试、状态及构建文档 |

不提交原版包、构建 APK、工具 JAR 或签名秘密。已有本地文件保留可用，原版包也可继续放在根目录，
`.gitignore` 会按扩展名排除。所有架构的原生库合入单 APK 会显著增大体积，因此新入口仅保留 arm64-v8a。

## 支持的输入与验证范围

3.6.0 基础包 SHA-256：`0ccd19a3d391218650d6013cf2b04e5b8e8644438f83a52e8d55302553708777`。

3.6.1 基础包 SHA-256：`71989a7ce1a1da0bb3072f516ce0f27ff3d6ac54e9e7a63afdf3a2cb39d9833f`。

两者均用 `patcher/3.6/zvpatch.py`，不跳过锚点校验。3.6.1 的 version code 是 `361611060`。
P1–P9 全部锚点匹配并成功构建，不代表已验证相机功能。3.6.1 尚未真机测试。
3.6.0 上游仅报告一台设备的 Wi-Fi 智能手机连接、实时画面及拍照可用；3.6.x 的 USB、Import 未验证。

构建器检查输入哈希、补丁锚点、合并后补丁 DEX 不变、原生库架构、ZIP CRC、v2/v3 签名及 16 KiB ZIP 对齐，
输出构建报告和 SHA-256 文件。ZIP 对齐不能证明索尼原生库的 ELF 对齐或运行时行为兼容 16 KiB 内存页。

## 签名和安装

私下备份 `zvpatch-signing.jks` 和 `zvpatch-signing.pass`。默认别名 `zvpatch`，可用 `--key-alias` 指定。
密钥和密码文件缺少任意一项时构建会中止，自定义签名文件必须已存在，密钥密码必须与存储密码相同。
更换输出目录时可复用原签名：

```bash
python3 tools/build.py inputs/3.6.1.apkm --out out/rebuild \
  --keystore out/zvpatch-signing.jks --password-file out/zvpatch-signing.pass
```

直接在手机安装 APK，或使用：

```bash
adb install -r out/rebuild/CreatorsApp_3.6.1_ZV-E10_release-arm64-v8a.apk
```

签名冲突时先卸载旧版。首次启动地区选“中国香港”。构建工具不自动下载，临时目录在成功或失败后自动清理。
