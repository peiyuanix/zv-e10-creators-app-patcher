.class public final Lzv/ZvWifiCompat;
.super Ljava/lang/Object;
.source "ZvWifiCompat.java"

# ZV-E10 over Wi-Fi. The camera's DID.xml reports X_ServerVersion 3.00, which Creators' App treats as
# "not a supported camera". In PC Remote mode it also reports MediaServerSupport DISABLE and exposes no
# storage; in Send to Smartphone mode it reports ENABLE and pushes camera-selected images. These
# helpers recognise the ZV-E10 (model name + PTP versions present), let the one-time Wi-Fi path accept
# it, and keep a PC Remote session in remote-control mode.


.method public static isPcRemote(Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;)Z
    .locals 2

    invoke-static {p0}, Lzv/ZvWifiCompat;->isZvE10(Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;)Z

    move-result v0

    if-eqz v0, :zv_no

    iget-object v0, p0, Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;->mDidXml:Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;

    iget-object v0, v0, Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;->mMediaServerSupport:Ljp/co/sony/ips/portalapp/common/device/did/EnumMediaServerSupport;

    sget-object v1, Ljp/co/sony/ips/portalapp/common/device/did/EnumMediaServerSupport;->ENABLE:Ljp/co/sony/ips/portalapp/common/device/did/EnumMediaServerSupport;

    if-eq v0, v1, :zv_no

    const/4 v0, 0x1

    return v0

    :zv_no
    const/4 v0, 0x0

    return v0
.end method

# Device tab onResume: true = keep the open session's mode instead of switching it to contents
# transfer. USB sessions always keep it (PC Remote over USB exposes no storage); Wi-Fi sessions keep it
# only for a ZV-E10 in PC Remote mode.
.method public static keepSessionMode(Ljp/co/sony/ips/portalapp/camera/BaseCamera;)Z
    .locals 1

    instance-of v0, p0, Ljp/co/sony/ips/portalapp/camera/PtpUsbCamera;

    if-eqz v0, :zv_not_usb

    return v0

    :zv_not_usb
    instance-of v0, p0, Ljp/co/sony/ips/portalapp/camera/PtpIpCamera;

    if-eqz v0, :zv_no

    iget-object v0, p0, Ljp/co/sony/ips/portalapp/camera/BaseCamera;->mDdXml:Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;

    invoke-static {v0}, Lzv/ZvWifiCompat;->isPcRemote(Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;)Z

    move-result v0

    return v0

    :zv_no
    const/4 v0, 0x0

    return v0
.end method


.method public static isZvE10(Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;)Z
    .locals 2

    const/4 v0, 0x0

    if-eqz p0, :zv_no

    iget-object v1, p0, Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;->mPtpVersions:Ljava/lang/String;

    invoke-static {v1}, Landroid/text/TextUtils;->isEmpty(Ljava/lang/CharSequence;)Z

    move-result v1

    if-nez v1, :zv_no

    iget-object p0, p0, Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;->mDeviceInfo:Ljp/co/sony/ips/portalapp/common/device/did/DeviceInfo;

    if-eqz p0, :zv_no

    iget-object p0, p0, Ljp/co/sony/ips/portalapp/common/device/did/DeviceInfo;->mModelName:Ljava/lang/String;

    const-string v1, "ZV-E10"

    invoke-virtual {v1, p0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v0

    :zv_no
    return v0
.end method

.method public static isZvE10(Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;)Z
    .locals 1

    const/4 v0, 0x0

    if-eqz p0, :zv_no

    iget-object p0, p0, Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;->mDidXml:Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;

    invoke-static {p0}, Lzv/ZvWifiCompat;->isZvE10(Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;)Z

    move-result v0

    :zv_no
    return v0
.end method

.method public static isUxpSupported(Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;)Z
    .locals 1

    invoke-static {p0}, Lzv/ZvWifiCompat;->isZvE10(Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;)Z

    move-result v0

    if-eqz v0, :zv_other

    return v0

    :zv_other
    iget-object p0, p0, Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;->mDeviceInfo:Ljp/co/sony/ips/portalapp/common/device/did/DeviceInfo;

    invoke-virtual {p0}, Ljp/co/sony/ips/portalapp/common/device/did/DeviceInfo;->isUxpSupported()Z

    move-result v0

    return v0
.end method

.method public static isContentsTransferAvailable(Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;)Z
    .locals 1

    invoke-static {p0}, Lzv/ZvWifiCompat;->isZvE10(Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;)Z

    move-result v0

    if-eqz v0, :zv_other

    return v0

    :zv_other
    invoke-virtual {p0}, Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;->isContentsTransferAvailable()Z

    move-result v0

    return v0
.end method

.method public static functionMode(Ljp/co/sony/ips/portalapp/camera/BaseCamera;Ljp/co/sony/ips/portalapp/ptpip/base/transaction/EnumFunctionMode;)Ljp/co/sony/ips/portalapp/ptpip/base/transaction/EnumFunctionMode;
    .locals 1

    iget-object v0, p0, Ljp/co/sony/ips/portalapp/camera/BaseCamera;->mDdXml:Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;

    invoke-static {v0}, Lzv/ZvWifiCompat;->isPcRemote(Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;)Z

    move-result v0

    if-eqz v0, :zv_other

    sget-object p1, Ljp/co/sony/ips/portalapp/ptpip/base/transaction/EnumFunctionMode;->REMOTE_CONTROL_MODE:Ljp/co/sony/ips/portalapp/ptpip/base/transaction/EnumFunctionMode$REMOTE_CONTROL_MODE;

    :zv_other
    return-object p1
.end method

.method public static refuseSwitch(Ljp/co/sony/ips/portalapp/camera/BaseCamera;Ljp/co/sony/ips/portalapp/ptpip/base/transaction/EnumFunctionMode;)Z
    .locals 1

    iget-object v0, p0, Ljp/co/sony/ips/portalapp/camera/BaseCamera;->mDdXml:Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;

    invoke-static {v0}, Lzv/ZvWifiCompat;->isPcRemote(Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;)Z

    move-result v0

    if-eqz v0, :zv_allow

    sget-object v0, Ljp/co/sony/ips/portalapp/ptpip/base/transaction/EnumFunctionMode;->REMOTE_CONTROL_MODE:Ljp/co/sony/ips/portalapp/ptpip/base/transaction/EnumFunctionMode$REMOTE_CONTROL_MODE;

    if-eq p1, v0, :zv_allow

    const/4 v0, 0x1

    return v0

    :zv_allow
    const/4 v0, 0x0

    return v0
.end method
