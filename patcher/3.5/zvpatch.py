#!/usr/bin/env python3
"""Apply the ZV-E10 patches to an apktool-decoded (`apktool d -r`) Creators' App base APK.

Usage: zvpatch.py <decoded-dir> <release|debug>

Every patch locates its target by class descriptor (not by file path, because apktool renames
classes that collide on case-insensitive file systems) and by a short anchor that must match
exactly once. If an anchor is missing the script aborts instead of producing a broken build.
See docs/en/02-patches.md for what each patch does and why.
"""

import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
APP = 'Ljp/co/sony/ips/portalapp'
MODE = f'{APP}/ptpip/base/transaction/EnumFunctionMode'
OPCODE = f'{APP}/ptpip/base/packet/EnumOperationCode'
RESPONSE = f'{APP}/ptpip/base/packet/EnumResponseCode'
DD = f'{APP}/common/device/DeviceDescription'
DID = f'{APP}/common/device/did/DigitalImagingDescription'
CAMERA = f'{APP}/camera/BaseCamera'
COMPAT = 'Lzv/ZvWifiCompat'


class PatchError(Exception):
    pass


class Smali:
    def __init__(self, root):
        self.root = root
        self.index = {}
        for top in sorted(os.listdir(root)):
            if not top.startswith('smali'):
                continue
            for dirpath, _, files in os.walk(os.path.join(root, top)):
                for name in files:
                    if not name.endswith('.smali'):
                        continue
                    path = os.path.join(dirpath, name)
                    with open(path, encoding='utf-8') as fh:
                        first = fh.readline().split()
                    if first and first[0] == '.class':
                        self.index[first[-1]] = path

    def path(self, descriptor):
        if descriptor not in self.index:
            raise PatchError(f'class {descriptor} not found')
        return self.index[descriptor]

    def read(self, descriptor):
        with open(self.path(descriptor), encoding='utf-8') as fh:
            return fh.read()

    def write(self, descriptor, text):
        with open(self.path(descriptor), 'w', encoding='utf-8') as fh:
            fh.write(text)

    def insert_after(self, descriptor, anchor, code):
        text = self.read(descriptor)
        count = text.count(anchor)
        if count != 1:
            raise PatchError(f'{descriptor}: anchor matched {count} times, expected 1:\n{anchor}')
        self.write(descriptor, text.replace(anchor, anchor + code))

    def insert_before(self, descriptor, anchor, code):
        text = self.read(descriptor)
        count = text.count(anchor)
        if count != 1:
            raise PatchError(f'{descriptor}: anchor matched {count} times, expected 1:\n{anchor}')
        self.write(descriptor, text.replace(anchor, code + anchor))

    def replace_count(self, descriptor, old, new, expected):
        text = self.read(descriptor)
        count = text.count(old)
        if count != expected:
            raise PatchError(f'{descriptor}: anchor matched {count} times, expected {expected}:\n{old}')
        self.write(descriptor, text.replace(old, new))

    def insert_at_body_start(self, descriptor, header, code):
        """Insert `code` before a method's first instruction (after .locals/.param/.annotation)."""
        text = self.read(descriptor)
        if text.count(header + '\n') != 1:
            raise PatchError(f'{descriptor}: method header not found exactly once:\n{header}')
        start = text.index(header + '\n')
        lines = text[start:].split('\n')
        i = 1
        if not lines[i].strip().startswith('.locals'):
            raise PatchError(f'{descriptor}: no .locals after\n{header}')
        i += 1
        while True:
            line = lines[i].strip()
            if line == '':
                i += 1
            elif line.startswith('.param'):
                if lines[i + 1].strip().startswith('.annotation'):
                    while lines[i].strip() != '.end param':
                        i += 1
                i += 1
            elif line.startswith('.annotation'):
                while lines[i].strip() != '.end annotation':
                    i += 1
                i += 1
            else:
                break
        pos = start + len('\n'.join(lines[:i])) + 1
        self.write(descriptor, text[:pos] + code + text[pos:])

    def method_span(self, descriptor, header):
        text = self.read(descriptor)
        if text.count(header) != 1:
            raise PatchError(f'{descriptor}: method header not found exactly once:\n{header}')
        start = text.index(header)
        end = text.index('.end method', start)
        return text, start, end


def log_line(debug, register, message):
    """Smali that logs `message` through zv/ZvLog when building the debug variant."""
    if not debug:
        return ''
    return (f'    const-string {register}, "{message}"\n\n'
            f'    invoke-static {{{register}}}, Lzv/ZvLog;->m(Ljava/lang/String;)V\n\n')


# --------------------------------------------------------------------------------------------
# Functional patches (release and debug)
# --------------------------------------------------------------------------------------------

def p1_usb_model_whitelist(s, debug):
    """Accept the ZV-E10 in the USB supported-model check."""
    # UsbSupportedCameraManager compares the model from GetDeviceInfo with a copy of the supported
    # camera list (assets/camera_guide.json, replaced by a server download every 24 h). The entry is
    # appended to that local copy only, so the list shown elsewhere in the app is unchanged.
    s.insert_after(
        f'{APP}/usb/UsbSupportedCameraManager$set$deviceInfoUpdaterListener$1;',
        f'    invoke-static {{}}, {APP}/database/CloudInfoDb;->getSupportedCameraObject()Ljava/util/ArrayList;\n\n'
        '    .line 46\n'
        '    .line 47\n'
        '    .line 48\n'
        '    move-result-object v3\n\n'
        '    .line 49\n'
        '    invoke-direct {v2, v3}, Ljava/util/ArrayList;-><init>(Ljava/util/Collection;)V\n',
        '\n    # ZVPATCH P1: treat the ZV-E10 as a USB-supported model\n'
        f'    new-instance v3, {APP}/database/realm/SupportedCameraObject;\n\n'
        f'    invoke-direct {{v3}}, {APP}/database/realm/SupportedCameraObject;-><init>()V\n\n'
        '    const-string v4, "ZV-E10"\n\n'
        f'    invoke-virtual {{v3, v4}}, {APP}/database/realm/SupportedCameraObject;->realmSet$modelName(Ljava/lang/String;)V\n\n'
        '    invoke-virtual {v2, v3}, Ljava/util/ArrayList;->add(Ljava/lang/Object;)Z\n\n'
        + log_line(debug, 'v3', 'P1 ZV-E10 appended to the USB supported-model list'))


def p2_usb_autoconnect_remote_control(s, debug):
    """Open the automatic session on plug-in in remote-control mode instead of contents transfer."""
    old = (f'sget-object v1, {APP}/camera/CameraConnector$EnumFunction;->CONTENTS_TRANSFER_PULL:'
           f'{APP}/camera/CameraConnector$EnumFunction;')
    new = (f'sget-object v1, {APP}/camera/CameraConnector$EnumFunction;->REMOTE_CONTROL:'
           f'{APP}/camera/CameraConnector$EnumFunction;')
    s.replace_count(f'{APP}/usb/statemachine/UsbInsertedState;', old, new, 1)
    s.replace_count(f'{APP}/usb/statemachine/UsbInsertedState$onEnter$1$1;', old, new, 2)


def p3_device_tab_keep_session_mode(s, debug):
    """Keep an open session in its current mode when the camera cannot transfer contents."""
    # Whenever the Cameras tab resumes, the app reopens the session in contents-transfer mode so the
    # camera can push images. That is right for the smartphone service, but in PC Remote mode the
    # ZV-E10 rejects contents transfer and the session is lost, so [Remote Shooting] then fails.
    # zv.ZvWifiCompat.keepSessionMode() answers "keep it" for USB sessions and for a Wi-Fi session
    # whose DID.xml reports no media server (PC Remote); every other camera keeps the stock path.
    descriptor = f'{APP}/toppage/devicetab/controller/FunctionModeController;'
    text, start, end = s.method_span(descriptor, '.method public final onResume()V\n')
    body = text[start:end]
    branch = '    if-eqz v1, :cond_0\n'
    call = f'{APP}/camera/CameraConnector$EnumFunction;->CONTENTS_TRANSFER_PUSH:'
    if body.count(call) != 1 or not 0 <= body.find(branch) < body.find(call):
        raise PatchError(f'{descriptor}->onResume(): unexpected body')
    body = body.replace(
        branch,
        '    if-eqz v1, :cond_0\n\n'
        '    # ZVPATCH P3: keep the session mode when the camera cannot transfer contents\n'
        f'    invoke-static {{v0}}, {COMPAT};->keepSessionMode({CAMERA};)Z\n\n'
        '    move-result v1\n\n'
        '    if-nez v1, :cond_0\n', 1)
    s.write(descriptor, text[:start] + body + text[end:])


def p4_usb_skip_device_log(s, debug):
    """Never send SDIO_GetDeviceLog, which the ZV-E10 does not implement."""
    s.insert_after(
        f'{APP}/ptpip/PtpUsbClient;',
        f'.method public final getDeviceLog({APP}/ptpip/base/transaction/EnumDeviceLogType;'
        f'{APP}/ptpip/mtp/DeviceLogGetter$IDeviceLogCallback;)V\n    .locals 1\n',
        '\n    # ZVPATCH P4: the ZV-E10 breaks the session on SDIO_GetDeviceLog\n'
        + log_line(debug, 'v0', 'P4 SDIO_GetDeviceLog skipped') +
        '    return-void\n')


def p5_usb_camera_remote_control_only(s, debug):
    """Keep every USB PTP session of the camera object in remote-control mode."""
    camera = f'{APP}/camera/PtpUsbCamera;'
    remote = f'{MODE};->REMOTE_CONTROL_MODE:{MODE}$REMOTE_CONTROL_MODE;'
    s.insert_after(
        camera,
        f'.method public final initialize({MODE};Ljava/lang/Runnable;)V\n    .locals 3\n',
        '\n    # ZVPATCH P5: USB sessions always use remote-control mode\n'
        f'    sget-object p1, {remote}\n\n')
    s.insert_after(
        camera,
        f'.method public final declared-synchronized switchFunctionMode({MODE};)Z\n    .locals 8\n',
        '\n    # ZVPATCH P5: never leave remote-control mode on USB\n'
        f'    sget-object v0, {remote}\n\n'
        '    if-eq p1, v0, :zv_remote\n\n'
        + log_line(debug, 'v0', 'P5 refused switching the USB session out of remote-control mode') +
        '    const/4 v0, 0x0\n\n'
        '    return v0\n\n'
        '    :zv_remote\n')


def p6_hide_import(s, debug):
    """Hide the [Import] button on the USB camera card."""
    descriptor = f'{APP}/toppage/devicetab/controller/UsbCameraConnectionController;'
    text = s.read(descriptor)
    lookup = '    const v1, 0x7f0a0494\n'   # R.id.not_registered_usb_content_viewer
    listener = (f'    new-instance v3, {APP}/toppage/devicetab/controller/'
                'UsbCameraConnectionController$bindView$1$2$1;\n')
    if text.count(lookup) != 1 or text.count(listener) != 1 or \
            not 0 < text.index(listener) - text.index(lookup) < 600:
        raise PatchError(f'{descriptor}: Import button binding not found')
    s.insert_before(
        descriptor, listener,
        '    # ZVPATCH P6: hide [Import]; the ZV-E10 does not expose its storage in PC Remote mode\n'
        '    const/16 v3, 0x8\n\n'
        '    invoke-virtual {v1, v3}, Landroid/view/View;->setVisibility(I)V\n\n')


def p7_wifi_support(s, debug):
    """Let the ZV-E10 be found, listed and connected over Wi-Fi."""
    # The camera publishes X_ServerVersion 3.00, which the app treats as "not a Sony imaging device",
    # so the camera never reaches the search list. Its PC Remote service additionally reports no media
    # server; the session must therefore stay in remote-control mode there, while the smartphone
    # service (Send to Smartphone / Connect) keeps the stock behaviour and supports Import and
    # camera-initiated transfer. zv.ZvWifiCompat holds both tests.
    s.insert_after(
        f'{DD};',
        f'.method public final getControlModel(){APP}/camera/EnumControlModel;\n    .locals 5\n',
        '\n    # ZVPATCH P7: list the ZV-E10 (it reports ServerVersion 3.00)\n'
        f'    invoke-static {{p0}}, {COMPAT};->isZvE10({DD};)Z\n\n'
        '    move-result v0\n\n'
        '    if-eqz v0, :zv_not_zve10\n\n'
        f'    sget-object v0, {APP}/camera/EnumControlModel;->SelectFunction:{APP}/camera/EnumControlModel;\n\n'
        + log_line(debug, 'v1', 'P7 ZV-E10 accepted as a supported Wi-Fi camera') +
        '    return-object v0\n\n'
        '    :zv_not_zve10\n')
    s.replace_count(
        f'{APP}/toppage/devicetab/wificonnect/SearchedDeviceListController$selectedConnectDevice$1;',
        f'    invoke-virtual {{v0}}, {DID};->isContentsTransferAvailable()Z\n',
        '    # ZVPATCH P7: in PC Remote mode the ZV-E10 reports no media server\n'
        f'    invoke-static {{v0}}, {COMPAT};->isContentsTransferAvailable({DID};)Z\n', 1)
    camera = f'{APP}/camera/PtpIpCamera;'
    s.insert_at_body_start(
        camera,
        f'.method public initialize({MODE};Ljava/lang/Runnable;)V',
        '    # ZVPATCH P7: a PC Remote session always uses remote-control mode\n'
        f'    invoke-static {{p0, p1}}, {COMPAT};->functionMode({CAMERA};{MODE};){MODE};\n\n'
        '    move-result-object p1\n\n')
    s.insert_after(
        camera,
        f'.method public final declared-synchronized switchFunctionMode({MODE};)Z\n    .locals 7\n',
        '\n    # ZVPATCH P7: a PC Remote session never leaves remote-control mode\n'
        f'    invoke-static {{p0, p1}}, {COMPAT};->refuseSwitch({CAMERA};{MODE};)Z\n\n'
        '    move-result v0\n\n'
        '    if-eqz v0, :zv_switch_allowed\n\n'
        + log_line(debug, 'v0', 'P7 refused switching the PC Remote session out of remote-control mode') +
        '    const/4 v0, 0x0\n\n'
        '    return v0\n\n'
        '    :zv_switch_allowed\n')
    s.insert_after(
        f'{APP}/ptpip/PtpIpClient;',
        f'.method public final getDeviceLog({APP}/ptpip/base/transaction/EnumDeviceLogType;'
        f'{APP}/ptpip/mtp/DeviceLogGetter$IDeviceLogCallback;)V\n    .locals 1\n',
        '\n    # ZVPATCH P7: the ZV-E10 breaks the session on SDIO_GetDeviceLog\n'
        + log_line(debug, 'v0', 'P7 SDIO_GetDeviceLog skipped') +
        '    return-void\n')


def p8_camera_initiated_transfer(s, debug):
    """Accept the camera's protocol version for the transfer paths."""
    # Import and the automatic copy of images sent from the camera are gated on X_ServerVersion >=
    # 3.01; the ZV-E10 reports 3.00 but speaks the same transfer protocol. Only this model is
    # answered "supported"; every other camera keeps the stock version check.
    s.insert_after(
        f'{APP}/common/device/did/DeviceInfo;',
        '.method public final isUxpSupported()Z\n    .locals 5\n',
        '\n    # ZVPATCH P8: the ZV-E10 reports ServerVersion 3.00\n'
        f'    iget-object v0, p0, {APP}/common/device/did/DeviceInfo;->mModelName:Ljava/lang/String;\n\n'
        '    const-string v1, "ZV-E10"\n\n'
        '    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z\n\n'
        '    move-result v0\n\n'
        '    if-eqz v0, :zv_not_zve10\n\n'
        + log_line(debug, 'v1', 'P8 ZV-E10 accepted for contents transfer') +
        '    return v0\n\n'
        '    :zv_not_zve10\n')


def p9_start_live_view(s, debug):
    """Start the live view stream when the remote shooting screen opens."""
    # The stream is started when the camera reports a change of its live view status, or by the
    # connection paths used for registered cameras. If live view is already on when the session opens
    # (for example after another app used the camera), no change arrives and the screen waits
    # forever. The screen controller registers itself for frames here, so it also asks for the
    # stream; BaseCamera.setLiveViewStreamCallback() re-checks the camera status and the
    # already-started flag, so the call does nothing when live view is off or already running.
    s.insert_after(
        f'{APP}/ptp/remotecontrol/controller/liveview/LiveviewScreenController;',
        f'    invoke-virtual {{p1, p0}}, {CAMERA};->addLiveViewStreamCallback('
        f'{APP}/ptp/remotecontrol/controller/liveview/LiveviewScreenController;)V\n',
        '\n    # ZVPATCH P9: also start the stream, nothing else does after a reconnect\n'
        f'    invoke-virtual {{p1}}, {CAMERA};->setLiveViewStreamCallback()V\n')


# --------------------------------------------------------------------------------------------
# Diagnostics (debug only)
# --------------------------------------------------------------------------------------------

def d1_ptp_transaction_trace(s):
    """Log every USB PTP request, its result, transaction timeouts and the initialisation result."""
    executor = f'{APP}/ptpip/ptpusb/base/transaction/TransactionExecutor;'
    s.insert_after(
        executor,
        '.method public final executeTransaction$1()V\n    .locals 10\n',
        f'\n    # ZVPATCH D1\n    invoke-static {{p0}}, Lzv/ZvLog;->req({executor})V\n')
    s.insert_after(
        executor,
        f'.method public final declared-synchronized onOperationRequestFailed({OPCODE};{RESPONSE};)V\n'
        '    .locals 1\n',
        '\n    # ZVPATCH D1\n    invoke-static {p1, p2}, Lzv/ZvLog;->fail(Ljava/lang/Object;Ljava/lang/Object;)V\n')
    s.insert_after(
        executor,
        f'.method public final onOperationRequested({OPCODE};Ljava/util/List;)V\n'
        '    .locals 1\n'
        '    .annotation system Ldalvik/annotation/Signature;\n'
        '        value = {\n'
        '            "(",\n'
        f'            "{OPCODE};",\n'
        '            "Ljava/util/List<",\n'
        '            "Ljava/lang/Integer;",\n'
        '            ">;)V"\n'
        '        }\n'
        '    .end annotation\n',
        '\n    # ZVPATCH D1\n    invoke-static {p1, p2}, Lzv/ZvLog;->ok(Ljava/lang/Object;Ljava/lang/Object;)V\n')
    s.insert_after(
        f'{APP}/ptpip/PtpUsbManager$1;',
        f'.method public final onTransactionTimeout({OPCODE};)V\n    .locals 1\n',
        '\n    # ZVPATCH D1\n    invoke-static {p1}, Lzv/ZvLog;->timeout(Ljava/lang/Object;)V\n')
    initializer = f'{APP}/ptpip/BasePtpManager$initializerCallback$1;'
    s.insert_after(
        initializer,
        f'.method public final onInitializationFailed({RESPONSE};)V\n    .locals 2\n',
        '\n    # ZVPATCH D1\n    invoke-static {p1}, Lzv/ZvLog;->initFailed(Ljava/lang/Object;)V\n')
    s.insert_after(
        initializer,
        f'.method public final declared-synchronized onInitialized({APP}/ptpip/initialization/SDIExtDeviceInfoDataset;'
        f'I{MODE};)V\n    .locals 5\n',
        '\n    # ZVPATCH D1\n    invoke-static {p3}, Lzv/ZvLog;->initOk(Ljava/lang/Object;)V\n')


def d2_session_teardown_trace(s):
    """Log who closes, disconnects or switches the USB session, with a Java stack trace."""
    s.insert_after(
        f'{APP}/ptpip/BasePtpManager;',
        '.method public final terminatePtpCommunication()V\n    .locals 2\n',
        '\n    # ZVPATCH D2\n    invoke-static {p0}, Lzv/ZvLog;->term(Ljava/lang/Object;)V\n')
    s.insert_after(
        f'{APP}/ptpip/PtpUsbClient;',
        f'.method public final declared-synchronized switchFunctionMode({MODE};)V\n    .locals 1\n',
        '\n    # ZVPATCH D2\n    invoke-static {p1}, Lzv/ZvLog;->sw(Ljava/lang/Object;)V\n')
    s.insert_after(
        f'{APP}/camera/PtpUsbCamera;',
        f'.method public final declared-synchronized disconnect({APP}/camera/BaseCamera$EnumCameraError;)V\n'
        '    .locals 1\n',
        '\n    # ZVPATCH D2\n    invoke-static {p1}, Lzv/ZvLog;->disc(Ljava/lang/Object;)V\n')


def d3_wifi_trace(s):
    """Log the Wi-Fi discovery result, every PTP-IP transaction, the storages and the live view."""
    s.insert_at_body_start(
        f'{DD};', '.method public constructor <init>(Ljava/lang/String;)V',
        '    # ZVPATCH D3\n    invoke-static {p1}, Lzv/ZvWifi;->dd(Ljava/lang/String;)V\n\n')
    s.insert_at_body_start(
        f'{DD};', f'.method public final getControlModel(){APP}/camera/EnumControlModel;',
        f'    # ZVPATCH D3\n    invoke-static {{p0}}, Lzv/ZvWifi;->did({DD};)V\n\n')
    executor = f'{APP}/ptpip/ptpip/base/transaction/TransactionExecutor;'
    s.insert_at_body_start(
        executor, '.method public final executeTransaction()V',
        f'    # ZVPATCH D3\n    invoke-static {{p0}}, Lzv/ZvWifi;->req({executor})V\n\n')
    s.insert_at_body_start(
        executor,
        f'.method public final declared-synchronized onOperationRequestFailed({OPCODE};{RESPONSE};Ljava/util/List;)V',
        '    # ZVPATCH D3\n    invoke-static {p1, p2}, Lzv/ZvLog;->fail(Ljava/lang/Object;Ljava/lang/Object;)V\n\n')
    s.insert_at_body_start(
        executor,
        f'.method public final declared-synchronized onOperationRequested({OPCODE};Ljava/util/List;)V',
        '    # ZVPATCH D3\n    invoke-static {p1, p2}, Lzv/ZvLog;->ok(Ljava/lang/Object;Ljava/lang/Object;)V\n\n')
    # Which storages the camera exposes: none, the images selected on the camera, or the card.
    storage = f'{APP}/ptpip/mtp/StorageIDs;'
    header = '.method public constructor <init>(Ljava/util/EnumSet;)V\n    .locals 0\n'
    text = s.read(storage)
    if text.count(header) != 1:
        raise PatchError(f'{storage}: constructor not found')
    s.write(storage, text.replace(header, header.replace('.locals 0', '.locals 1'), 1))
    s.insert_at_body_start(
        storage, '.method public constructor <init>(Ljava/util/EnumSet;)V',
        '    # ZVPATCH D3\n    const-string v0, "STORAGE ids="\n\n'
        '    invoke-static {v0, p1}, Lzv/ZvLog;->w(Ljava/lang/String;Ljava/lang/Object;)V\n\n')
    camera = f'{APP}/camera/PtpIpCamera;'
    for header, call in (
        (f'.method public declared-synchronized disconnect({APP}/camera/BaseCamera$EnumCameraError;)V',
         'invoke-static {p1}, Lzv/ZvLog;->disc(Ljava/lang/Object;)V'),
        (f'.method public final declared-synchronized switchFunctionMode({MODE};)Z',
         'invoke-static {p1}, Lzv/ZvLog;->sw(Ljava/lang/Object;)V'),
        (f'.method public final onLiveviewDownloaded({APP}/ptpip/liveview/dataset/LiveViewDataset;)V',
         'invoke-static {}, Lzv/ZvWifi;->lvFrame()V'),
        (f'.method public final onLiveviewDownloadFailed({RESPONSE};)V',
         'invoke-static {p1}, Lzv/ZvWifi;->lvFail(Ljava/lang/Object;)V'),
        ('.method public final setLiveViewStreamCallback()V',
         f'invoke-static {{p0}}, Lzv/ZvWifi;->lvSetCb({camera[:-1]};)V'),
        ('.method public final isNeedToStartLiveView()Z',
         f'invoke-static {{p0}}, Lzv/ZvWifi;->lvNeed({camera[:-1]};)V'),
        ('.method public final stopLiveView()V',
         f'invoke-static {{p0}}, Lzv/ZvWifi;->lvStop({camera[:-1]};)V'),
        (f'.method public static canGetLiveView({APP}/ptpip/property/dataset/DevicePropInfoDataset;)Z',
         f'invoke-static {{p0}}, Lzv/ZvWifi;->lvProp({APP}/ptpip/property/dataset/DevicePropInfoDataset;)V'),
    ):
        s.insert_at_body_start(camera, header, f'    # ZVPATCH D3\n    {call}\n\n')
    s.insert_at_body_start(
        f'{APP}/ptpip/PtpIpClient;',
        f'.method public final setLiveViewStreamCallback({APP}/ptpip/liveview/LiveViewStream$ILiveViewStreamCallback;'
        'Ljava/lang/String;)V',
        '    # ZVPATCH D3\n    invoke-static {p1, p2}, Lzv/ZvWifi;->lvSet(Ljava/lang/Object;Ljava/lang/String;)V\n\n')
    downloader = f'{APP}/ptpip/liveview/http/AbstractEeImageDownloader;'
    s.insert_at_body_start(
        downloader, '.method public final declared-synchronized startup()V',
        f'    # ZVPATCH D3\n    invoke-static {{p0}}, Lzv/ZvWifi;->lvHttp({downloader})V\n\n')


def main():
    if len(sys.argv) != 3 or sys.argv[2] not in ('release', 'debug'):
        sys.exit(__doc__)
    root, variant = sys.argv[1], sys.argv[2]
    debug = variant == 'debug'

    dest = os.path.join(root, 'smali_classes3', 'zv')
    os.makedirs(dest, exist_ok=True)
    shutil.copyfile(os.path.join(HERE, 'compat', 'ZvWifiCompat.smali'),
                    os.path.join(dest, 'ZvWifiCompat.smali'))
    if debug:
        for name in ('ZvLog.smali', 'ZvWifi.smali'):
            shutil.copyfile(os.path.join(HERE, 'debug', name), os.path.join(dest, name))
    smali = Smali(root)

    functional = [p1_usb_model_whitelist, p2_usb_autoconnect_remote_control, p3_device_tab_keep_session_mode,
                  p4_usb_skip_device_log, p5_usb_camera_remote_control_only, p6_hide_import,
                  p7_wifi_support, p8_camera_initiated_transfer, p9_start_live_view]
    try:
        for patch in functional:
            patch(smali, debug)
            print(f'  [ok] {patch.__name__}')
        if debug:
            for diagnostic in (d1_ptp_transaction_trace, d2_session_teardown_trace, d3_wifi_trace):
                diagnostic(smali)
                print(f'  [ok] {diagnostic.__name__}')
    except PatchError as exc:
        sys.exit(f'  [failed] {exc}')


if __name__ == '__main__':
    main()
