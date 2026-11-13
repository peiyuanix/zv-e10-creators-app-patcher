.class public final Lzv/ZvLog;
.super Ljava/lang/Object;
.source "ZvLog.java"

# Diagnostic helper added to the debug build only. Everything goes to logcat with tag ZVPATCH.
#   m / w          plain messages (patch markers)
#   req / ok / fail every USB PTP transaction (D1). Live view polling (object handle 0xFFFFC002) is
#                  skipped, except for failures other than AccessDenied ("no new frame yet").
#   timeout, initOk, initFailed  transaction timeout and initialisation result (D1)
#   term / sw / disc  session teardown, mode switch and disconnect, each with a stack trace (D2)


.field public static lv:Z


.method public static m(Ljava/lang/String;)V
    .locals 1

    const-string v0, "ZVPATCH"

    invoke-static {v0, p0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;)I

    return-void
.end method

.method public static w(Ljava/lang/String;Ljava/lang/Object;)V
    .locals 1

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0, p1}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lzv/ZvLog;->m(Ljava/lang/String;)V

    return-void
.end method

.method public static req(Ljp/co/sony/ips/portalapp/ptpip/ptpusb/base/transaction/TransactionExecutor;)V
    .locals 4

    iget-object v0, p0, Ljp/co/sony/ips/portalapp/ptpip/ptpusb/base/transaction/TransactionExecutor;->currentTransaction:Ljp/co/sony/ips/portalapp/ptpip/base/transaction/AbstractTransaction;

    if-nez v0, :zv_has

    return-void

    :zv_has
    iget-object v1, v0, Ljp/co/sony/ips/portalapp/ptpip/base/transaction/AbstractTransaction;->mOperationCode:Ljp/co/sony/ips/portalapp/ptpip/base/packet/EnumOperationCode;

    iget-object v2, v0, Ljp/co/sony/ips/portalapp/ptpip/base/transaction/AbstractTransaction;->mParameters:[I

    const/4 v3, 0x0

    sput-boolean v3, Lzv/ZvLog;->lv:Z

    if-eqz v2, :zv_log

    array-length v3, v2

    if-eqz v3, :zv_log

    const/4 v3, 0x0

    aget v3, v2, v3

    const/16 v0, -0x3ffe

    if-ne v3, v0, :zv_log

    const/4 v3, 0x1

    sput-boolean v3, Lzv/ZvLog;->lv:Z

    return-void

    :zv_log
    new-instance v3, Ljava/lang/StringBuilder;

    invoke-direct {v3}, Ljava/lang/StringBuilder;-><init>()V

    const-string v0, "PTP req  op="

    invoke-virtual {v3, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v3, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;

    const-string v0, " params="

    invoke-virtual {v3, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-static {v2}, Ljava/util/Arrays;->toString([I)Ljava/lang/String;

    move-result-object v0

    invoke-virtual {v3, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v3}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lzv/ZvLog;->m(Ljava/lang/String;)V

    return-void
.end method

.method public static ok(Ljava/lang/Object;Ljava/lang/Object;)V
    .locals 2

    sget-boolean v0, Lzv/ZvLog;->lv:Z

    if-eqz v0, :zv_log

    return-void

    :zv_log
    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "PTP ok   op="

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;

    const-string v1, " resp="

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0, p1}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lzv/ZvLog;->m(Ljava/lang/String;)V

    return-void
.end method

.method public static fail(Ljava/lang/Object;Ljava/lang/Object;)V
    .locals 2

    sget-boolean v0, Lzv/ZvLog;->lv:Z

    if-eqz v0, :zv_log

    invoke-static {p1}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v0

    const-string v1, "AccessDenied"

    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v0

    if-eqz v0, :zv_log

    return-void

    :zv_log
    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "PTP FAIL op="

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;

    const-string v1, " code="

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0, p1}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lzv/ZvLog;->m(Ljava/lang/String;)V

    return-void
.end method

.method public static timeout(Ljava/lang/Object;)V
    .locals 1

    const-string v0, "PTP TIMEOUT op="

    invoke-static {v0, p0}, Lzv/ZvLog;->w(Ljava/lang/String;Ljava/lang/Object;)V

    return-void
.end method

.method public static initFailed(Ljava/lang/Object;)V
    .locals 1

    const-string v0, "INIT FAILED code="

    invoke-static {v0, p0}, Lzv/ZvLog;->w(Ljava/lang/String;Ljava/lang/Object;)V

    return-void
.end method

.method public static st(Ljava/lang/String;Ljava/lang/Object;)V
    .locals 3

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0, p1}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    const-string v1, "ZVPATCH"

    new-instance v2, Ljava/lang/Throwable;

    invoke-direct {v2}, Ljava/lang/Throwable;-><init>()V

    invoke-static {v1, v0, v2}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    return-void
.end method

.method public static term(Ljava/lang/Object;)V
    .locals 1

    const-string v0, "TERMINATE ptp manager="

    invoke-static {v0, p0}, Lzv/ZvLog;->st(Ljava/lang/String;Ljava/lang/Object;)V

    return-void
.end method

.method public static disc(Ljava/lang/Object;)V
    .locals 1

    const-string v0, "DISCONNECT usb camera error="

    invoke-static {v0, p0}, Lzv/ZvLog;->st(Ljava/lang/String;Ljava/lang/Object;)V

    return-void
.end method

.method public static sw(Ljava/lang/Object;)V
    .locals 1

    const-string v0, "SWITCH function mode to="

    invoke-static {v0, p0}, Lzv/ZvLog;->st(Ljava/lang/String;Ljava/lang/Object;)V

    return-void
.end method

.method public static initOk(Ljava/lang/Object;)V
    .locals 1

    const-string v0, "INIT OK mode="

    invoke-static {v0, p0}, Lzv/ZvLog;->w(Ljava/lang/String;Ljava/lang/Object;)V

    return-void
.end method
