; ================================================================
;  鼠标增强脚本 MouseHelper  (AutoHotkey v2)
; ----------------------------------------------------------------
;  功能 1 : 滚轮实现左右按键/横向滚动
;            - 切换滚轮模式: 按住右键时点一下左键 (即左键+右键同时按下)
;              4 态循环: 左右按键(按住右键) → 横向滚动(按住右键)
;                        → 左右按键(无需右键) → 横向滚动(无需右键) → 循环
;              注：左右按键(按住右键)/横向滚动(按住右键)模式下，没同时操作右键，滚轮保持原始功能
;            - 操作方式：
;              左右按键(按住右键)/横向滚动(按住右键)：长按【右键】+ 滚动滚轮
;              左右按键(无需右键)/横向滚动(无需右键)：滚动滚轮
;            - 映射说明：
;              左右按键模式: 滚轮上 = ←(Left)   滚轮下 = →(Right)
;              横向滚动模式: 滚轮上 = 横向左滚   滚轮下 = 横向右滚
;              倾斜滚轮同样生效 (向左 = 左, 向右 = 右)
;            - 滚动时在光标右下方用 ToolTip 显示 ← 或 → 方向箭头 (同一时间只显示一个)
;  误触逻辑 :
;            - 单纯按下松开右键(没移动、没用任何功能) = 普通右键菜单
;              菜单延迟 DblClickMs(默认500ms)补发: 期间再次单击右键 = 双击
;              → 切换侧键模式且两次都不弹菜单 (消耗右键默认行为)
;            - 按住期间使用过滚轮/侧键/左键 = 松开时不弹菜单,
;              并进入宽限期(默认150ms, 期内滚轮仍映射 ←/→, 便于收尾滚动)
;            - 按住期间鼠标移动超过阈值(默认5px)且没用功能 =
;              视为"右键拖拽": 自动补发右键按下, 松开时补发右键松开
;  功能 2 : 侧键实现复制/粘贴功能
;            - 切换侧键模式：双击右键切换侧键功能
;              2 态循环：默认模式(按住右键) → 复制/粘贴(无需右键) → 循环
;              注: 双击判定期间消耗右键默认行为: 两次点击均不弹系统右键菜单
;                  按住右键时, 侧键始终为复制/粘贴, 不受该切换影响
;                  默认模式下，没同时操作右键，侧键保持原始功能 (浏览器后退/前进等)
;            - 操作方式：
;              默认模式：长按【右键】+ 鼠标侧键
;              复制/粘贴：鼠标侧键
;            - 映射说明：
;              XButton1(后侧键) = 复制 (Ctrl+C, 用 ToolTip 显示成功/失败)
;              XButton2(前侧键) = 粘贴 (Ctrl+V, 用 ToolTip 显示成功/失败)
;  功能 3 : 按 Ctrl+Alt+Q, 弹出提示后立即退出脚本 (无需确认)
; ----------------------------------------------------------------
;  使用方法:
;   1. 安装 AutoHotkey v2: https://www.autohotkey.com/
;   2. 双击运行本脚本, 托盘出现图标并弹出右下角提示即生效
;   3. 退出: 按 Ctrl+Alt+Q 直接退出, 或右键托盘图标选择 Exit
;  备注:
;   - 个别程序不响应注入的横向滚动, 可把 WheelAction 里的 Send 改为 SendEvent
; ================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn
SendMode "Input"
CoordMode "Mouse", "Screen"

; ================================================================
;  配置区 (按需修改)
; ================================================================
ScrollMode := "keys"   ; 初始模式: "keys"=左右按键(按住右键)  "hscroll"=横向滚动(按住右键)
                       ;           "keys_always"=左右按键(无需右键)  "hscroll_always"=横向滚动(无需右键)

DragThreshold := 5     ; 右键拖拽判定阈值(像素): 按住右键移动超过该值视为拖拽
GracePeriodMs := 150   ; 使用功能后松开右键的宽限期(毫秒), 期内滚轮仍映射 ←/→
HudOffsetX := 16       ; 箭头/操作提示相对光标右下角的水平偏移 (越大离光标越远)
HudOffsetY := 16       ; 箭头/操作提示相对光标右下角的垂直偏移 (越大离光标越远)
HudHideMs  := 400      ; 滚动停止后箭头停留的毫秒数
HScrollStep := 1       ; 横向滚动模式每次滚动格数(可调大加快)
ActionTipHideMs := 2500 ; 复制/粘贴 ToolTip 提示停留的毫秒数
DblClickMs := 500       ; 右键双击判定间隔(毫秒), 500 = Windows 默认双击速度 (按需调整)

; ================================================================
;  内部状态 (无需修改)
; ================================================================
GestureUsed          := false ; 本次右键按压是否使用过功能(滚轮/侧键/切模式)
isDragActive         := false ; 本次右键按压是否已判定为拖拽
isGracePeriodActive  := false ; 是否处于松开右键后的宽限期
startX := 0                   ; 右键按下时的鼠标位置
startY := 0
SideBtnMode := "default"      ; 侧键模式: "default"=原始功能  "copy"=复制/粘贴 (双击右键切换)
lastRClickTime := 0           ; 上次普通右键点击松开的时间戳 (用于双击判定)

; ================================================================
;  方向箭头悬浮提示 (基于 ToolTip, 跟随光标, 同一时间只显示一个箭头)
; ================================================================
; 显示方向箭头: L = ←(左/上)   R = →(右/下)
ShowArrow(side) {
    global HudOffsetX, HudOffsetY, HudHideMs
    MouseGetPos &mx, &my
    ToolTip(side = "L" ? "←" : "→", mx + HudOffsetX, my + HudOffsetY, 1)
    SetTimer HideArrowHUD, -HudHideMs
}

; 由 SetTimer 调用的隐藏函数 (命名函数确保定时器只保留一个, 不会提前隐藏)
HideArrowHUD() {
    ToolTip(, , , 1)
}

; ================================================================
;  基础函数
; ================================================================
; 右下角弹出提示
Notify(title, text) {
    TrayTip title, text, 1
}

; 当前滚轮模式名称
ScrollModeName() {
    global ScrollMode
    return (ScrollMode = "keys") ? "左右按键(按住右键)"
         : (ScrollMode = "hscroll") ? "横向滚动(按住右键)"
         : (ScrollMode = "keys_always") ? "左右按键(无需右键)"
         : "横向滚动(无需右键)"
}

; 当前侧键模式名称
SideBtnModeName() {
    global SideBtnMode
    return (SideBtnMode = "copy") ? "复制/粘贴(无需右键)" : "默认(后退/前进)"
}

; 获取ModeTip
ModeTip() {
    global ScrollMode, SideBtnMode
    wMode := (ScrollMode = "keys" or ScrollMode = "keys_always") ? "左右按键" : "横向滚动"
    wCond := (ScrollMode = "keys" or ScrollMode = "hscroll") ? "(按住右键)" : "(无需右键)"
    return "滚轮：" . wMode . wCond . " | 侧键：" . ((SideBtnMode = "copy") ? "复制/粘贴" : "默认")
}

; 获取IconTip
IconTip() {
    return "鼠标增强 - " . ModeTip()
}

; 标记"本次右键按压已使用功能": 置位标记, 并停止拖拽检测
MarkGestureUsed() {
    global GestureUsed
    GestureUsed := true
    SetTimer CheckForDrag, 0
}

; 切换滚轮模式 (按住右键时点左键): 4 态循环
; keys → hscroll → keys_always → hscroll_always → keys → ...
ToggleScrollMode() {
    global ScrollMode
    MarkGestureUsed()
    ScrollMode := (ScrollMode = "keys") ? "hscroll"
                : (ScrollMode = "hscroll") ? "keys_always"
                : (ScrollMode = "keys_always") ? "hscroll_always"
                : "keys"
    A_IconTip := IconTip()
    Notify("鼠标增强 · 滚轮模式切换", "滚轮模式：" . ScrollModeName())
}

; 切换侧键模式 (双击右键, 仅对普通右键点击生效)
ToggleSideBtnMode() {
    global SideBtnMode
    SideBtnMode := (SideBtnMode = "default") ? "copy" : "default"
    A_IconTip := IconTip()
    Notify("鼠标增强 · 侧键模式切换", "侧键模式：" . SideBtnModeName())
}

; 长按右键 + 滚轮的映射动作
WheelAction(dir) {
    global ScrollMode, HScrollStep, isGracePeriodActive, GracePeriodMs
    MarkGestureUsed()
    if isGracePeriodActive
        SetTimer EndGracePeriod, -GracePeriodMs   ; 宽限期内继续滚动则延长宽限期
    if (ScrollMode = "keys" or ScrollMode = "keys_always") {
        if (dir = "up" or dir = "left")
            Send "{Left}"
        else
            Send "{Right}"
    } else {
        if (dir = "up" or dir = "left")
            Send "{WheelLeft " HScrollStep "}"
        else
            Send "{WheelRight " HScrollStep "}"
    }
    ShowArrow(dir = "up" or dir = "left" ? "L" : "R")
}

; ================================================================
;  热键定义
; ================================================================
; 提高本脚本热键的输入级别: 脚本自身 Send 的事件(级别0)不会再次
; 触发本脚本的热键, 避免透传侧键/还原右键/补发拖拽事件时产生递归
#InputLevel 1

; 右键按下: 重置状态, 记录起点, 启动拖拽检测
*RButton:: {
    global GestureUsed, isDragActive, isGracePeriodActive, startX, startY
    GestureUsed := false
    isDragActive := false
    isGracePeriodActive := false
    SetTimer RestoreRClickMenu, 0   ; 取消待定的右键菜单还原(双击时第一次点击不弹菜单)
    MouseGetPos &startX, &startY
    SetTimer CheckForDrag, 10
}

; 右键松开 (误触逻辑, 参照 WheelLR.ahk):
;  - 已判定拖拽            → 补发右键松开, 完成拖拽 (不弹菜单)
;  - 使用过功能(滚轮/侧键) → 进入宽限期, 不弹菜单
;  - 均未发生(误触/普通右键) → 补发右键, 还原右键菜单
RButton Up:: {
    global GestureUsed, isDragActive, isGracePeriodActive, GracePeriodMs, lastRClickTime, DblClickMs
    SetTimer CheckForDrag, 0
    if isDragActive
        Send "{RButton Up}"
    if GestureUsed {
        isGracePeriodActive := true
        SetTimer EndGracePeriod, -GracePeriodMs
    } else if !isDragActive {
        ; 普通右键点击: 与前一次普通点击构成双击 → 切换侧键模式(两次均不弹菜单);
        ; 否则延迟 DblClickMs 后补发右键还原菜单(期间再次按下右键会自动取消)
        now := A_TickCount
        if (now - lastRClickTime <= DblClickMs)
            ToggleSideBtnMode()
        else
            SetTimer RestoreRClickMenu, -DblClickMs
        lastRClickTime := now
    }
    GestureUsed := false
    isDragActive := false
}

; 延迟补发右键, 还原系统右键菜单 (双击切换时已被取消, 不会执行)
RestoreRClickMenu() {
    Send "{RButton}"
}

; 拖拽检测: 按住右键期间每 10ms 检查鼠标是否移动超过阈值
CheckForDrag() {
    global isDragActive, DragThreshold, startX, startY
    if !GetKeyState("RButton", "P") {
        SetTimer CheckForDrag, 0
        return
    }
    MouseGetPos &currentX, &currentY
    if (Abs(currentX - startX) > DragThreshold or Abs(currentY - startY) > DragThreshold) {
        SetTimer CheckForDrag, 0
        isDragActive := true
        BlockInput true
        try {
            MouseMove startX, startY, 0
            Sleep 10
            Send "{RButton Down}"
        } finally {
            BlockInput false
        }
    }
}

; 宽限期结束
EndGracePeriod() {
    global isGracePeriodActive
    isGracePeriodActive := false
}

; 滚轮映射条件:
;  - "keys"/"hscroll"(按住右键模式): 仅在长按右键且非拖拽, 或宽限期内映射
;    (拖拽过程中滚轮保持原生行为; 宽限期用于滚动收尾)
;  - "keys_always"/"hscroll_always"(无需右键模式): 任何时刻均映射
#HotIf (ScrollMode = "keys_always" or ScrollMode = "hscroll_always") or ((GetKeyState("RButton", "P") and !isDragActive) or isGracePeriodActive)
WheelUp::WheelAction("up")
WheelDown::WheelAction("down")
WheelLeft::WheelAction("left")
WheelRight::WheelAction("right")
#HotIf

; 按住右键(且非拖拽)时, 左键 = 切换模式
#HotIf GetKeyState("RButton", "P") and !isDragActive
LButton::ToggleScrollMode()
#HotIf

; 侧键: 按住右键 = 始终复制/粘贴; 不按右键时 = 按侧键模式(默认/复制粘贴)
XButton1::
{
    global SideBtnMode
    if GetKeyState("RButton", "P") or SideBtnMode = "copy"
        CopyAction()
    else
        Send "{XButton1}"
}

XButton2::
{
    global SideBtnMode
    if GetKeyState("RButton", "P") or SideBtnMode = "copy"
        PasteAction()
    else
        Send "{XButton2}"
}

; ================================================================
;  复制 / 粘贴
; ================================================================
; 复制/粘贴结果提示 (ToolTip, 独立 ID=2, 与方向箭头 ID=1 互不干扰)
ShowActionTip(title, text) {
    global ActionTipHideMs, HudOffsetX, HudOffsetY
    MouseGetPos &mx, &my
    ToolTip(title . "`n" . text, mx + HudOffsetX, my + HudOffsetY, 2)
    SetTimer HideActionTip, -ActionTipHideMs
}

HideActionTip() {
    ToolTip(, , , 2)
}

; 复制: 发送 Ctrl+C, 用剪贴板序号变化判断是否真正复制成功
CopyAction() {
    MarkGestureUsed()
    seq := DllCall("user32.dll\GetClipboardSequenceNumber")
    Send "^c"
    Loop 10 {
        Sleep 50
        if (DllCall("user32.dll\GetClipboardSequenceNumber") != seq)
            break
    }
    if (DllCall("user32.dll\GetClipboardSequenceNumber") != seq)
        ShowActionTip("鼠标增强 · 复制", "✓ 已复制")
    else
        ShowActionTip("鼠标增强 · 复制", "✗ 复制失败, 请先选中内容")
}

; 粘贴: 先检查剪贴板是否有内容
PasteAction() {
    MarkGestureUsed()
    if (A_Clipboard = "") {
        ShowActionTip("鼠标增强 · 粘贴", "✗ 剪贴板为空, 请先复制")
        return
    }
    Send "^v"
    ShowActionTip("鼠标增强 · 粘贴", "✓ 已粘贴")
}

; ================================================================
;  退出 & 启动提示
; ================================================================
; Ctrl+Alt+Q: 弹出提示后立即退出脚本 (无需确认)
^!q:: {
    Notify("鼠标增强", "正在退出脚本...")
    ; Sleep 1000   ; 让提示短暂可见后立即结束脚本
    ExitApp
}

A_IconTip := IconTip()
Notify("鼠标增强工具已启动~Ctrl+Alt+Q(关闭)", ModeTip() . "`n长按右键+滚轮/侧键/左键 | 双击右键")
