.class public final Lzv/ZvWifi;
.super Ljava/lang/Object;
.source "ZvWifi.java"

# Wi-Fi measurement helper for debug builds (logcat tag ZVPATCH): SSDP device description URLs,
# the DID.xml fields that gate the one-time Wi-Fi connection, PTP-IP requests and HTTP live view.


.field public static lvFrames:I

.field public static lvLastProp:J


.method public static lvSet(Ljava/lang/Object;Ljava/lang/String;)V
    .locals 2

    const/4 v0, 0x0

    sput v0, Lzv/ZvWifi;->lvFrames:I

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "LV setCallback cb="

    invoke-static {v0, v1, p0}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v1, " url="

    invoke-static {v0, v1, p1}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lzv/ZvLog;->m(Ljava/lang/String;)V

    return-void
.end method

.method public static lvHttp(Ljp/co/sony/ips/portalapp/ptpip/liveview/http/AbstractEeImageDownloader;)V
    .locals 2

    const-string v0, "LV http startup url="

    iget-object v1, p0, Ljp/co/sony/ips/portalapp/ptpip/liveview/http/AbstractEeImageDownloader;->mUrl:Ljava/lang/String;

    invoke-static {v0, v1}, Lzv/ZvLog;->w(Ljava/lang/String;Ljava/lang/Object;)V

    return-void
.end method

.method public static lvFrame()V
    .locals 2

    sget v0, Lzv/ZvWifi;->lvFrames:I

    add-int/lit8 v0, v0, 0x1

    sput v0, Lzv/ZvWifi;->lvFrames:I

    const/4 v1, 0x1

    if-eq v0, v1, :zv_log

    rem-int/lit16 v1, v0, 0x12c

    if-eqz v1, :zv_log

    return-void

    :zv_log
    const-string v1, "LV frames="

    invoke-static {v0}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v0

    invoke-static {v1, v0}, Lzv/ZvLog;->w(Ljava/lang/String;Ljava/lang/Object;)V

    return-void
.end method

.method public static lvState(Ljp/co/sony/ips/portalapp/camera/PtpIpCamera;Ljava/lang/String;)V
    .locals 3

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "LV "

    invoke-static {v0, v1, p1}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v1, " started="

    iget-object v2, p0, Ljp/co/sony/ips/portalapp/camera/PtpIpCamera;->mIsLiveViewStarted:Ljava/util/concurrent/atomic/AtomicBoolean;

    invoke-static {v0, v1, v2}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v1, " url="

    iget-object v2, p0, Ljp/co/sony/ips/portalapp/camera/PtpIpCamera;->mLiveviewUrl:Ljava/lang/String;

    invoke-static {v0, v1, v2}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lzv/ZvLog;->m(Ljava/lang/String;)V

    return-void
.end method

.method public static lvSetCb(Ljp/co/sony/ips/portalapp/camera/PtpIpCamera;)V
    .locals 1

    const-string v0, "setLiveViewStreamCallback"

    invoke-static {p0, v0}, Lzv/ZvWifi;->lvState(Ljp/co/sony/ips/portalapp/camera/PtpIpCamera;Ljava/lang/String;)V

    return-void
.end method

.method public static lvNeed(Ljp/co/sony/ips/portalapp/camera/PtpIpCamera;)V
    .locals 1

    const-string v0, "isNeedToStartLiveView"

    invoke-static {p0, v0}, Lzv/ZvWifi;->lvState(Ljp/co/sony/ips/portalapp/camera/PtpIpCamera;Ljava/lang/String;)V

    return-void
.end method

.method public static lvStop(Ljp/co/sony/ips/portalapp/camera/PtpIpCamera;)V
    .locals 3

    const-wide/16 v1, -0x1

    sput-wide v1, Lzv/ZvWifi;->lvLastProp:J

    const-string v0, "stopLiveView"

    invoke-static {p0, v0}, Lzv/ZvWifi;->lvState(Ljp/co/sony/ips/portalapp/camera/PtpIpCamera;Ljava/lang/String;)V

    return-void
.end method

.method public static lvProp(Ljp/co/sony/ips/portalapp/ptpip/property/dataset/DevicePropInfoDataset;)V
    .locals 7

    if-nez p0, :zv_have

    return-void

    :zv_have
    iget-wide v0, p0, Ljp/co/sony/ips/portalapp/ptpip/property/dataset/DevicePropInfoDataset;->mCurrentValue:J

    sget-wide v2, Lzv/ZvWifi;->lvLastProp:J

    cmp-long v4, v0, v2

    if-nez v4, :zv_changed

    return-void

    :zv_changed
    sput-wide v0, Lzv/ZvWifi;->lvLastProp:J

    new-instance v4, Ljava/lang/StringBuilder;

    invoke-direct {v4}, Ljava/lang/StringBuilder;-><init>()V

    const-string v5, "LV status value="

    invoke-static {v0, v1}, Ljava/lang/Long;->valueOf(J)Ljava/lang/Long;

    move-result-object v6

    invoke-static {v4, v5, v6}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v5, " enable="

    iget-object v6, p0, Ljp/co/sony/ips/portalapp/ptpip/property/dataset/DevicePropInfoDataset;->mIsEnable:Ljp/co/sony/ips/portalapp/ptpip/property/dataset/EnumIsEnable;

    invoke-static {v4, v5, v6}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v4

    invoke-static {v4}, Lzv/ZvLog;->m(Ljava/lang/String;)V

    return-void
.end method

.method public static lvFail(Ljava/lang/Object;)V
    .locals 1

    const-string v0, "LV download failed code="

    invoke-static {v0, p0}, Lzv/ZvLog;->w(Ljava/lang/String;Ljava/lang/Object;)V

    return-void
.end method


.method public static dd(Ljava/lang/String;)V
    .locals 1

    const-string v0, "SSDP DD.xml url="

    invoke-static {v0, p0}, Lzv/ZvLog;->w(Ljava/lang/String;Ljava/lang/Object;)V

    return-void
.end method

.method public static add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V
    .locals 0

    invoke-virtual {p0, p1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {p0, p2}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;

    return-void
.end method

.method public static did(Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;)V
    .locals 5

    iget-object v0, p0, Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;->mDidXml:Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;

    iget-object v1, v0, Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;->mDeviceInfo:Ljp/co/sony/ips/portalapp/common/device/did/DeviceInfo;

    new-instance v2, Ljava/lang/StringBuilder;

    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V

    const-string v3, "DID name="

    iget-object v4, p0, Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;->mFriendlyName:Ljava/lang/String;

    invoke-static {v2, v3, v4}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v3, " url="

    iget-object v4, p0, Ljp/co/sony/ips/portalapp/common/device/DeviceDescription;->mDDUrl:Ljava/lang/String;

    invoke-static {v2, v3, v4}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v3, " model="

    iget-object v4, v1, Ljp/co/sony/ips/portalapp/common/device/did/DeviceInfo;->mModelName:Ljava/lang/String;

    invoke-static {v2, v3, v4}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v3, " fw="

    iget-object v4, v1, Ljp/co/sony/ips/portalapp/common/device/did/DeviceInfo;->mFirmwareVersion:Ljava/lang/String;

    invoke-static {v2, v3, v4}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v3, " category="

    iget-object v4, v1, Ljp/co/sony/ips/portalapp/common/device/did/DeviceInfo;->mCategory:Ljava/lang/String;

    invoke-static {v2, v3, v4}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v3, " serverVersion="

    iget-object v4, v1, Ljp/co/sony/ips/portalapp/common/device/did/DeviceInfo;->mServerVersion:Ljava/lang/String;

    invoke-static {v2, v3, v4}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v3, " didAvailable="

    iget-boolean v4, v0, Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;->mIsAvailable:Z

    invoke-static {v4}, Ljava/lang/Boolean;->valueOf(Z)Ljava/lang/Boolean;

    move-result-object v4

    invoke-static {v2, v3, v4}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v3, " ptpVersions="

    iget-object v4, v0, Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;->mPtpVersions:Ljava/lang/String;

    invoke-static {v2, v3, v4}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v3, " mediaServer="

    iget-object v4, v0, Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;->mMediaServerSupport:Ljp/co/sony/ips/portalapp/common/device/did/EnumMediaServerSupport;

    invoke-static {v2, v3, v4}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v3, " contentsTransfer="

    iget-object v4, v0, Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;->mContentsTransferSupport:Ljp/co/sony/ips/portalapp/common/device/did/EnumContentsTransferSupport;

    invoke-static {v2, v3, v4}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v3, " remoteControl="

    iget-object v4, v0, Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;->mRemoteControlSupport:Ljp/co/sony/ips/portalapp/common/device/did/EnumRemoteControlSupport;

    invoke-static {v2, v3, v4}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v3, " pairing="

    iget-object v4, v0, Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;->mPairingNecessity:Ljp/co/sony/ips/portalapp/common/device/did/EnumPairingNecessity;

    invoke-static {v2, v3, v4}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v3, " ssh="

    iget-object v4, v0, Ljp/co/sony/ips/portalapp/common/device/did/DigitalImagingDescription;->mSshSupport:Ljp/co/sony/ips/portalapp/common/device/did/EnumSshSupport;

    invoke-static {v2, v3, v4}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v2

    invoke-static {v2}, Lzv/ZvLog;->m(Ljava/lang/String;)V

    return-void
.end method

.method public static req(Ljp/co/sony/ips/portalapp/ptpip/ptpip/base/transaction/TransactionExecutor;)V
    .locals 3

    iget-object v0, p0, Ljp/co/sony/ips/portalapp/ptpip/ptpip/base/transaction/TransactionExecutor;->mCurrentTransaction:Ljp/co/sony/ips/portalapp/ptpip/base/transaction/AbstractTransaction;

    if-nez v0, :zv_has

    return-void

    :zv_has
    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    const-string v2, "PTPIP req op="

    iget-object p0, v0, Ljp/co/sony/ips/portalapp/ptpip/base/transaction/AbstractTransaction;->mOperationCode:Ljp/co/sony/ips/portalapp/ptpip/base/packet/EnumOperationCode;

    invoke-static {v1, v2, p0}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    const-string v2, " params="

    iget-object p0, v0, Ljp/co/sony/ips/portalapp/ptpip/base/transaction/AbstractTransaction;->mParameters:[I

    invoke-static {p0}, Ljava/util/Arrays;->toString([I)Ljava/lang/String;

    move-result-object p0

    invoke-static {v1, v2, p0}, Lzv/ZvWifi;->add(Ljava/lang/StringBuilder;Ljava/lang/String;Ljava/lang/Object;)V

    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v1

    invoke-static {v1}, Lzv/ZvLog;->m(Ljava/lang/String;)V

    return-void
.end method
