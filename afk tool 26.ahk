#Requires AutoHotkey v2.0
SetWorkingDir A_ScriptDir
CoordMode("Mouse", "Client")
SetTitleMatchMode(2)
SetControlDelay(1)
SetWinDelay(50)
SetKeyDelay(-1)
SetMouseDelay(10)

; ====================== USER CONFIGURATION ======================
; Edit these values directly to customize behavior

; --- Window Detection ---
global WEB_ENABLED := true          ; Include web Roblox windows (RobloxPlayerBeta.exe)
global UWP_ENABLED := false         ; Include UWP Roblox windows (Microsoft Store version)

; --- Default Actions ---
global DEFAULT_KEYS := "wait 1000,click 410 460,r,1,k,2,3,m,r,m,r,m,r,m,r,l,click 410 460,wait 1000"          ; Default actions to send (comma-separated)

; --- Sleep Duration ---
global SLEEP_DURATION := 120000     ; Time between cycles in milliseconds (120000 = 2 minutes)
                                    ; Options: 0, 120000 (2 min), 300000 (5 min), 600000 (10 min)

; --- Window Behavior ---
global MINIMIZE_AFTER_ACTIONS := false  ; Minimize windows after running actions
global DEBUG_CLICKS := true             ; Show click position indicator

; --- Layout Settings ---
global GRID_TIGHTNESS := 1.2        ; Grid layout density (lower = more rows, higher = more columns)
global EDGE_NUDGE := 8              ; Pixels to nudge windows from screen edge

; --- Waterfall Settings ---
global WATERFALL_OFFSET_X := 30     ; Horizontal spacing between cascaded windows
global WATERFALL_OFFSET_Y := 30     ; Vertical spacing between cascaded windows
global WATERFALL_WIDTH := 480       ; Width of cascaded windows
global WATERFALL_HEIGHT := 360      ; Height of cascaded windows

; --- Tile Settings ---
global TILE_WIDTH_OFFSET := 240     ; Reduce usable width by this amount for tiling
global TILE_HEIGHT_OFFSET := 224    ; Reduce usable height by this amount for tiling

; --- Stack Settings ---
global STACK_WINDOW_WIDTH := 100    ; Width of stacked windows
global STACK_WINDOW_HEIGHT := 80    ; Height of stacked windows

; ==================== TECHNICAL CONSTANTS ====================
; Don't change these unless you know what you're doing

global WINDOW_RESTORE_DELAY := 50
global WINDOW_MOVE_DELAY := 15
global WINDOW_MOVE_VERIFY_DELAY := 15
global ACTIVATION_RETRY_MAX := 20
global ACTIVATION_RETRY_DELAY := 100
global KEY_SEND_DELAY := 100
global CLICK_PRE_DELAY  := 150  ; ms between MouseMove and Click
global CLICK_POST_DELAY := 150  ; ms after Click before next command
global TOOLTIP_DURATION := 700

; ====================== END CONFIGURATION ======================

; ---------------------- Application State ----------------------
class AppStateManager {
    __New() {
        this.isRunning := false
        this.activeWindows := []
        this.excludedWindows := Map()
        this.selectionMade := false
    }
}

; ---------------------- Globals ----------------------
global sleepOptions := Map("00 Sec", 0, "02 Min", 120000, "05 Min", 300000, "10 Min", 600000)

global mainGui, statusField, keysInput
global appState

; ---------------------- Utility Functions ----------------------
LogError(context, errorObj) {
    try {
        timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        msg := Format("[{}] {} - {}`n", timestamp, context, errorObj.Message)
        FileAppend(msg, "error_log.txt", "UTF-8")
    }
}

ShowTooltipTimed(msg, dur := 0) {
    if (dur = 0)
        dur := TOOLTIP_DURATION
    ToolTip(msg)
    SetTimer(() => ToolTip(), -dur)
}

InArray(arr, val) {
    for v in arr
        if (v = val)
            return true
    return false
}

SortNumericArray(arr) {
    for i, _ in arr
        for j, _ in arr
            if (arr[i] > arr[j]) {
                temp := arr[i]
                arr[i] := arr[j]
                arr[j] := temp
            }
    return arr
}

; ---------------------- Window Detection ----------------------
IsRobloxWindow(id) {
    try {
        title := WinGetTitle("ahk_id " . id)
        processName := WinGetProcessName("ahk_id " . id)
        
        if InStr(title, "Roblox Account Manager")
            return false
            
        if (processName = "RobloxPlayerBeta.exe")
            return true
            
        if (InStr(title, "Roblox") && StrLen(title) > 6 && !InStr(title, "Microsoft Store"))
            return true
            
        return false
    } catch as err {
        LogError("IsRobloxWindow", err)
        return false
    }
}

GetRobloxWindows() {
    allWindows := []
    seenIDs := Map()

    if (WEB_ENABLED) {
        try {
            regularWindows := WinGetList("ahk_exe RobloxPlayerBeta.exe")
            for id in regularWindows {
                if IsRobloxWindow(id) && !seenIDs.Has(id) {
                    allWindows.Push(id)
                    seenIDs[id] := true
                }
            }
        } catch as err {
            LogError("GetRobloxWindows-Web", err)
        }
    }

    if (UWP_ENABLED) {
        try {
            uwpWindows := WinGetList("Roblox")
            for id in uwpWindows {
                if IsRobloxWindow(id) && !seenIDs.Has(id) {
                    allWindows.Push(id)
                    seenIDs[id] := true
                }
            }
        } catch as err {
            LogError("GetRobloxWindows-UWP", err)
        }
    }

    return allWindows
}

GetWindowType(id) {
    try {
        if (WinGetProcessName("ahk_id " . id) = "RobloxPlayerBeta.exe")
            return "Regular"
        else
            return "UWP"
    } catch as err {
        LogError("GetWindowType", err)
        return "Unknown"
    }
}

GetWorkArea(monitor := 1) {
    MonitorGetWorkArea(monitor, &l, &t, &r, &b)
    return { left: l, top: t, width: r - l, height: b - t }
}

MoveExact(id, x, y, w, h, nudgeX := 0) {
    win := "ahk_id " . id
    try {
        WinMove(x, y, w, h, win)
        Sleep(WINDOW_MOVE_VERIFY_DELAY)
        WinGetPos(&ax, &ay, &aw, &ah, win)
        dx := x - ax, dy := y - ay
        if (dx || dy)
            WinMove(x + dx, y + dy, w, h, win)
        if (nudgeX)
            WinMove(ax - nudgeX, ay, w, h, win)
    } catch as err {
        LogError("MoveExact", err)
    }
}

; ---------------------- Command Processing ----------------------
ProcessCommand(cmd, winId := 0) {
    if RegExMatch(cmd, "^wait\s+(\d+)$", &m) {
        remaining := Integer(m[1])
        while (remaining > 0 && appState.isRunning) {
            chunk := Min(remaining, 250)
            Sleep(chunk)
            remaining -= chunk
        }
        return true
    }

    if RegExMatch(cmd, "^click\s+(\d+)[\s,]+(\d+)$", &m) {
        x := Integer(m[1]), y := Integer(m[2])

        if (x < 0 || y < 0 || x > 5000 || y > 5000) {
            LogError("ValidateCoordinates", {Message: "Invalid window coords: " . x . "," . y})
            return false
        }

        if (winId && !WinActive("ahk_id " . winId)) {
            if (WinGetMinMax("ahk_id " . winId) = -1)
                WinRestore("ahk_id " . winId)
            WinActivate("ahk_id " . winId)
            tries := 0
            while (!WinActive("ahk_id " . winId) && tries < ACTIVATION_RETRY_MAX) {
                Sleep(ACTIVATION_RETRY_DELAY)
                tries++
            }
        }

        if (DEBUG_CLICKS) {
            if (winId) {
                WinGetClientPos(&wx, &wy, , , "ahk_id " . winId)
                d := ShowClickIndicator(wx + x, wy + y)
                Sleep(600)
                try d.Destroy()
            }
        }

        MouseMove(x + Random(-35, 35), y + Random(-35, 35), 4)
        Sleep(40)
        MouseMove(x + Random(-10, 10), y + Random(-10, 10), 3)
        Sleep(30)
        MouseMove(x, y, 2)
        Sleep(CLICK_PRE_DELAY)
        Click()
        Sleep(CLICK_POST_DELAY)

        return true
    }
    
    if RegExMatch(cmd, "^hold\s+(\S+)\s+(\d+)$", &m) {
        key := Trim(m[1]), duration := Integer(m[2])
        Send("{" . key . " Down}")
        remaining := duration
        while (remaining > 0 && appState.isRunning) {
            chunk := Min(remaining, 250)
            Sleep(chunk)
            remaining -= chunk
        }
        Send("{" . key . " Up}")
        Sleep(KEY_SEND_DELAY)
        return true
    }
    
    key := StrLower(cmd)
    switch key {
        case "space": Send("{Space}")
        case "enter": Send("{Enter}")
        case "tab":   Send("{Tab}")
        case "shift": Send("{Shift}")
        case "ctrl":  Send("{Ctrl}")
        case "alt":   Send("{Alt}")
        default:      Send("{" . key . "}")
    }
    Sleep(KEY_SEND_DELAY)
    return true
}

SendCustomKeys(winId := 0, winIndex := 0, winTotal := 0) {
    global keysInput, statusField

    try {
        keysText := Trim(keysInput.Text)
        if (keysText = "")
            keysText := DEFAULT_KEYS

        keys := StrSplit(keysText, ",")
        successCount := 0

        for index, raw in keys {
            cmd := Trim(raw)
            if (cmd = "")
                continue

            try {
                label := (StrLen(cmd) > 12) ? SubStr(cmd, 1, 10) . ".." : cmd
                winPart := (winIndex && winTotal) ? "Window: " . winIndex . "/" . winTotal . ", " : ""
                statusField.Text := winPart . label
                if !ProcessCommand(cmd, winId) {
                    statusField.Text := "Warning: Invalid command at position " . index
                    LogError("SendCustomKeys", {Message: "Invalid command: " . cmd})
                } else {
                    successCount++
                }
            } catch as err {
                LogError("SendKeys command: " . cmd, err)
            }
        }
        
        return successCount
    } catch as err {
        LogError("SendCustomKeys", err)
        return 0
    }
}

CalculateGridDimensions(n) {
    if (n <= 0)
        return {cols: 1, rows: 1}
    cols := Ceil(Sqrt(Max(n * GRID_TIGHTNESS, 1)))
    rows := Ceil(n / cols)
    return {cols: cols, rows: rows}
}

SetDebugClicks(val) {
    global DEBUG_CLICKS
    DEBUG_CLICKS := !!val
}

ShowClickIndicator(sx, sy) {
    d := Gui("-Caption +AlwaysOnTop +ToolWindow")
    d.BackColor := "FF3300"
    d.Show("x" . (sx - 10) . " y" . (sy - 10) . " w20 h20 NoActivate")
    return d
}


SetWebEnabled(val) {
    global WEB_ENABLED
    WEB_ENABLED := !!val
    UpdateCheckboxStatus()
}
SetUwpEnabled(val) {
    global UWP_ENABLED
    UWP_ENABLED := !!val
    UpdateCheckboxStatus()
}
SetMinimize(val) {
    global MINIMIZE_AFTER_ACTIONS
    MINIMIZE_AFTER_ACTIONS := !!val
}

SetClickPreDelay(val) {
    global CLICK_PRE_DELAY
    n := Integer(val)
    if (n >= 0)
        CLICK_PRE_DELAY := n
}

; ---------------------- Checkbox Status ----------------------
UpdateCheckboxStatus(*) {
    global statusField
    if (!WEB_ENABLED && !UWP_ENABLED)
        statusField.Text := "⚠ None"
    else if (WEB_ENABLED && UWP_ENABLED)
        statusField.Text := "Web+UWP"
    else if (WEB_ENABLED)
        statusField.Text := "Web"
    else
        statusField.Text := "UWP"
}

; ---------------------- Window Operations ----------------------
GetLayoutWindows() {
    global appState
    if (appState.selectionMade && appState.activeWindows.Length > 0) {
        valid := []
        for id in appState.activeWindows
            if (WinExist("ahk_id " . id))
                valid.Push(id)
        if (valid.Length > 0)
            return valid
    }
    return GetRobloxWindows()
}

TileWindows() {
    global statusField
    statusField.Text := "Tiling windows..."

    idList := GetLayoutWindows()
    if (idList.Length = 0) {
        statusField.Text := "No Roblox windows found to tile."
        return
    }
    
    valid := idList

    if (valid.Length = 0) {
        statusField.Text := "No valid windows found to tile."
        return
    }
    
    wa := GetWorkArea(1)
    left := wa.left
    top := wa.top
    width := wa.width - TILE_WIDTH_OFFSET
    height := wa.height - TILE_HEIGHT_OFFSET
    
    grid := CalculateGridDimensions(valid.Length)
    cellW := Floor(width / grid.cols)
    cellH := Floor(height / grid.rows)
    
    r := 0, c := 0
    for i, id in valid {
        try {
            x := left + (c * cellW)
            y := top + (r * cellH)
            WinRestore("ahk_id " . id)
            Sleep(WINDOW_RESTORE_DELAY)
            MoveExact(id, x, y, cellW, cellH, EDGE_NUDGE)
            statusField.Text := "Tiling window " . i . " of " . valid.Length . "..."
            Sleep(60)
            c++
            if (c >= grid.cols)
                c := 0, r++
        } catch as err {
            statusField.Text := "Error tiling window " . i
            LogError("TileWindows", err)
            Sleep(200)
        }
    }
    
    statusField.Text := "Tiled " . valid.Length . " windows in " . grid.cols . "x" . grid.rows . " grid"
}

ResizeAllWindows() {
    global statusField
    statusField.Text := "Stacking windows..."

    idList := GetLayoutWindows()
    if (idList.Length = 0) {
        statusField.Text := "No Roblox windows found to resize."
        return
    }
    
    wa := GetWorkArea(1)
    baseX := wa.left, baseY := wa.top
    stacked := 0
    
    for id in idList {
        if (!WinExist("ahk_id " . id))
            continue
        
        try {
            WinRestore("ahk_id " . id)
            Sleep(80)
            MoveExact(id, baseX, baseY, STACK_WINDOW_WIDTH, STACK_WINDOW_HEIGHT, EDGE_NUDGE)
            stacked++
            wt := GetWindowType(id)
            statusField.Text := "Stacked " . wt . " window " . stacked . "..."
            Sleep(120)
        } catch as err {
            statusField.Text := "Error stacking window " . (stacked + 1)
            LogError("ResizeAllWindows", err)
            Sleep(250)
        }
    }
    
    statusField.Text := stacked
        ? "Stacked " . stacked . " windows at " . STACK_WINDOW_WIDTH . "x" . STACK_WINDOW_HEIGHT
        : "No windows found to stack (check Web/UWP settings)"
}

WaterfallWindows() {
    global statusField
    statusField.Text := "Waterfalling windows..."

    valid := GetLayoutWindows()
    if (valid.Length = 0) {
        statusField.Text := "No Roblox windows found to waterfall."
        return
    }
    
    wa := GetWorkArea(1)
    left := wa.left, top := wa.top
    i := 0
    
    for id in valid {
        try {
            WinRestore("ahk_id " . id)
            Sleep(40)
            x := left + (i * WATERFALL_OFFSET_X)
            y := top + (i * WATERFALL_OFFSET_Y)
            
            if (x + WATERFALL_WIDTH > wa.left + wa.width) {
                x := left
                top += 60
            }
            
            MoveExact(id, x, y, WATERFALL_WIDTH, WATERFALL_HEIGHT, EDGE_NUDGE)
            statusField.Text := "Waterfalled window " . (i + 1) . " of " . valid.Length . "..."
            Sleep(60)
            i++
        } catch as err {
            statusField.Text := "Error waterfalling window " . (i + 1)
            LogError("WaterfallWindows", err)
            Sleep(200)
        }
    }
    
    statusField.Text := "Waterfalled " . valid.Length . " windows at " 
        . WATERFALL_WIDTH . "x" . WATERFALL_HEIGHT
}

; ---------------------- Window Selector ----------------------
SaveSelection(selector, checkboxes, *) {
    global appState, statusField
    
    appState.activeWindows := []
    appState.excludedWindows := Map()

    for id, cb in checkboxes {
        if cb.Value
            appState.activeWindows.Push(id)
        else
            appState.excludedWindows[id] := true
    }

    appState.activeWindows := appState.activeWindows.Clone()
    appState.selectionMade := true
    
    statusField.Text := "Selected " . appState.activeWindows.Length . " windows for this session."
    selector.Destroy()
}

CloseSelector(selector, *) {
    selector.Destroy()
}

TryActivateWindow(id, label := "", *) {
    try {
        WinActivate("ahk_id " . id)
        ok := WinActive("ahk_id " . id)
        ShowTooltipTimed((ok ? "Activated " : "Failed ") . label)
    } catch as err {
        ShowTooltipTimed("Error activating " . label, 800)
        LogError("TryActivateWindow", err)
    }
}

SelectAllBound(checkboxes, *) {
    for _, cb in checkboxes
        cb.Value := true
}

SelectNoneBound(checkboxes, *) {
    for _, cb in checkboxes
        cb.Value := false
}

ShowSettingsGUI() {
    global appState, statusField, CLICK_PRE_DELAY

    sg := Gui("+AlwaysOnTop +Caption +Border", "Settings")
    sg.SetFont("s8", "Segoe UI")

    ; --- Windows section ---
    sg.Add("Text", "x10 y10 w180 h14 +0x10", "Windows")

    idList := GetRobloxWindows()
    checkboxes := Map()
    y := 32, n := 1

    if (idList.Length = 0) {
        sg.Add("Text", "x10 y" . y . " w180", "No Roblox windows found.")
        y += 20
    } else {
        for , id in idList {
            name := "Win " . n, n++
            isChecked := !appState.selectionMade || InArray(appState.activeWindows, id)
            cb := sg.Add("CheckBox", "x10 y" . y . " w18 h18" . (isChecked ? " Checked" : ""), "")
            checkboxes[id] := cb
            btn := sg.Add("Button", "x30 y" . (y - 2) . " w160 h20", name)
            btn.OnEvent("Click", TryActivateWindow.Bind(id, name))
            y += 22
        }
    }

    saveBtn  := sg.Add("Button", "x10 y" . (y + 6) . " w55 h20", "Save")
    allBtn   := sg.Add("Button", "x70 y" . (y + 6) . " w55 h20", "All")
    noneBtn  := sg.Add("Button", "x130 y" . (y + 6) . " w60 h20", "None")
    saveBtn.OnEvent("Click", SaveSelection.Bind(sg, checkboxes))
    allBtn.OnEvent("Click", SelectAllBound.Bind(checkboxes))
    noneBtn.OnEvent("Click", SelectNoneBound.Bind(checkboxes))
    y += 34

    ; --- Behavior section ---
    sg.Add("Text", "x10 y" . (y + 8) . " w180 h14 +0x10", "Behavior")
    y += 28

    webCb := sg.Add("CheckBox", "x10 y" . y . " w85" . (WEB_ENABLED ? " Checked" : ""), "Web")
    uwpCb := sg.Add("CheckBox", "x100 y" . y . " w90" . (UWP_ENABLED ? " Checked" : ""), "UWP")
    webCb.OnEvent("Click", (*) => SetWebEnabled(webCb.Value))
    uwpCb.OnEvent("Click", (*) => SetUwpEnabled(uwpCb.Value))
    y += 26

    minCb := sg.Add("CheckBox", "x10 y" . y . " w180" . (MINIMIZE_AFTER_ACTIONS ? " Checked" : ""), "Minimize after actions")
    minCb.OnEvent("Click", (*) => SetMinimize(minCb.Value))
    y += 24

    dbgCb := sg.Add("CheckBox", "x10 y" . y . " w180" . (DEBUG_CLICKS ? " Checked" : ""), "Debug clicks (F9)")
    dbgCb.OnEvent("Click", (*) => SetDebugClicks(dbgCb.Value))
    y += 26

    sg.Add("Text", "x10 y" . (y + 3) . " w80", "Click delay (ms):")
    delayEdit := sg.Add("Edit", "x100 y" . y . " w80 h20 +Number", CLICK_PRE_DELAY)
    delayEdit.OnEvent("Change", (*) => SetClickPreDelay(delayEdit.Text))
    y += 30

    closeBtn := sg.Add("Button", "x10 y" . y . " w180 h22", "Close")
    closeBtn.OnEvent("Click", (*) => sg.Destroy())

    sg.Show("w200 h" . (y + 32))
}

; ---------------------- Keys Preset GUI ----------------------
ShowKeysPresetGUI() {
    global keysInput, statusField, sleepOptions, SLEEP_DURATION

    presetGui := Gui("+AlwaysOnTop +Caption +Border", "Default Actions")
    presetGui.SetFont("s8", "Segoe UI")

    txt := presetGui.Add("Edit", "x10 y10 w240 h60", keysInput.Text)

    presetGui.Add("Text", "x10 y77 w40", "Cycle:")
    cycleKeys := []
    for k in sleepOptions
        cycleKeys.Push(k)
    cycleDdl := presetGui.Add("DropDownList", "x60 y74 w180", cycleKeys)
    for index, key in cycleKeys
        if (sleepOptions[key] = SLEEP_DURATION)
            cycleDdl.Choose(index)
    cycleDdl.OnEvent("Change", (*) => UpdateSleepTime(cycleDdl.Text))

    presets := Map(
        "Zone", "wait 1000,click 410 460,r,1,k,2,3,m,r,m,r,m,r,m,r,l,click 410 460,wait 1000",
        "Eggs", "hold e 500,hold e 500,hold e 500,hold e 500,hold e 500,hold e 500",
        "Hatch", "e,e,click 540 430,click 540 430,click 540 430",
        "Rcu", "wait 1000,1,p,1,1,wait 1000",
        "Key", "m",
        "Orbs", "wait 2000,click 10 10,wait 500,click 180 517,wait 15000,click 104 212,wait 2000,click 660 212,wait 6000,q,wait 2000,hold w 6000,wait 500,click 180 517,wait 2000"
    )

    x1 := 10, x2 := 130, y := 108, w := 110, h := 22, pad := 6
    i := 0
    for name, cmd in presets {
        row := Floor(i / 2)
        col := Mod(i, 2)
        x := (col = 0) ? x1 : x2
        yPos := y + row * (h + pad)
        btn := presetGui.Add("Button", Format("x{} y{} w{} h{}", x, yPos, w, h), name)
        btn.OnEvent("Click", SetPreset.Bind(txt, cmd))
        i++
    }

    totalRows := Ceil(presets.Count / 2)
    btnY := y + totalRows * (h + pad) + 5
    save := presetGui.Add("Button", Format("x{} y{} w{} h{}", x1, btnY, w, h), "Save")
    close := presetGui.Add("Button", Format("x{} y{} w{} h{}", x2, btnY, w, h), "Close")

    save.OnEvent("Click", (*) => (
        keysInput.Text := txt.Text,
        statusField.Text := "Keys: " . txt.Text,
        presetGui.Destroy()
    ))
    close.OnEvent("Click", (*) => presetGui.Destroy())

    presetGui.Show(Format("w260 h{}", btnY + h + 10))
}

SetPreset(txtEdit, cmd, *) {
    txtEdit.Text := cmd
}

; ---------------------- Main GUI ----------------------
LoadGUI() {
    global mainGui, statusField, keysInput

    mainGui := Gui("+AlwaysOnTop +Caption +E0x200 +Border", "F7, F6, F8")
    mainGui.SetFont("s9", "Segoe UI")

    ; --- Actions row ---
    mainGui.Add("Text", "x10 y13 w50", "Actions:")
    keysInput := { Text: DEFAULT_KEYS }
    presetButton := mainGui.Add("Button", "x63 y10 w157 h22", "Edit")
    presetButton.OnEvent("Click", (*) => ShowKeysPresetGUI())

    ; --- Buttons grid ---
    stackButton := mainGui.Add("Button", "x10 y40 w100 h24", "Stack")
    stackButton.OnEvent("Click", (*) => ResizeAllWindows())
    tileButton := mainGui.Add("Button", "x120 y40 w100 h24", "Tile")
    tileButton.OnEvent("Click", (*) => TileWindows())

    waterfallButton := mainGui.Add("Button", "x10 y68 w100 h24", "Waterfall")
    waterfallButton.OnEvent("Click", (*) => WaterfallWindows())
    settingsButton := mainGui.Add("Button", "x120 y68 w100 h24", "Settings")
    settingsButton.OnEvent("Click", (*) => ShowSettingsGUI())

    ; --- Status line ---
    statusField := mainGui.Add("Text", "x10 y98 w210 h18", "Ready")

    UpdateCheckboxStatus()
    mainGui.OnEvent("Close", (*) => CleanupAndExit())
    mainGui.Show("x840 y476 w240 h122")
}

UpdateSleepTime(selected) {
    global sleepOptions, statusField
    if (sleepOptions.Has(selected)) {
        global SLEEP_DURATION := sleepOptions[selected]
        if (appState.isRunning)
            statusField.Text := "Sleep updated: " . selected . " (next cycle)"
        else
            statusField.Text := "Sleep set: " . selected
    }
}

; ---------------------- Main Loop ----------------------
StartLoop() {
    global statusField, appState

    if (!WEB_ENABLED && !UWP_ENABLED) {
        statusField.Text := "Error: Enable at least one window type!"
        return
    }

    appState.isRunning := true
    statusField.Text := "Status: Running..."

    while appState.isRunning {
        allWindows := GetRobloxWindows()

        ; Auto-detect new windows and add them to active list
        if (!appState.selectionMade) {
            for id in allWindows {
                if (!InArray(appState.activeWindows, id)) {
                    appState.activeWindows.Push(id)
                }
            }
        } else {
            ; If selection was made, check for new windows and add them automatically
            for id in allWindows {
                if (!InArray(appState.activeWindows, id) && !appState.excludedWindows.Has(id)) {
                    appState.activeWindows.Push(id)
                    statusField.Text := "New window detected and added!"
                    Sleep(500)
                }
            }
        }

        ; Remove closed windows from active list
        cleanedActive := []
        for id in appState.activeWindows {
            if (WinExist("ahk_id " . id))
                cleanedActive.Push(id)
        }
        appState.activeWindows := cleanedActive

        mainWindows := appState.activeWindows.Clone()
        total := allWindows.Length
        activeCount := mainWindows.Length

        for i, id in allWindows {
            if (!appState.isRunning)
                break
            if (!WinExist("ahk_id " . id))
                continue
                
            wt := GetWindowType(id)
            
            try {
                if (WinGetMinMax("ahk_id " . id) = -1)
                    WinRestore("ahk_id " . id)
                WinActivate("ahk_id " . id)
                tries := 0
                while (!WinActive("ahk_id " . id) && tries < ACTIVATION_RETRY_MAX) {
                    Sleep(ACTIVATION_RETRY_DELAY)
                    tries++
                }

                if WinActive("ahk_id " . id) {
                    if InArray(mainWindows, id) {
                        statusField.Text := "Running actions on " . i . "/" . total . " (" . wt . ")"
                        Sleep(100)
                        SendCustomKeys(id, i, total)
                        
                        if (MINIMIZE_AFTER_ACTIONS) {
                            try {
                                WinMinimize("ahk_id " . id)
                                Sleep(50)
                            } catch as err {
                                LogError("MinimizeWindow", err)
                            }
                        }
                    } else {
                        statusField.Text := "Keeping alive window " . i . "/" . total
                        Send("m")
                        Sleep(100)

                        if (MINIMIZE_AFTER_ACTIONS) {
                            try {
                                WinMinimize("ahk_id " . id)
                                Sleep(50)
                            } catch as err {
                                LogError("MinimizeWindow", err)
                            }
                        }
                    }
                } else {
                    statusField.Text := "Failed to activate window " . i
                    LogError("StartLoop-Activation", {Message: "Failed for ID " . id})
                }
            } catch as err {
                LogError("StartLoop-WindowProcess", err)
            }
        }

        if (!appState.isRunning)
            break
        ShowCountdown(SLEEP_DURATION, activeCount, total)
    }
    
    statusField.Text := "Status: Paused"
}

ShowCountdown(dur, winCount, total) {
    global statusField, appState
    start := A_TickCount
    
    while ((A_TickCount - start) < dur && appState.isRunning) {
        remain := (dur - (A_TickCount - start)) // 1000
        mins := Floor(remain / 60)
        secs := Mod(remain, 60)
        statusField.Text := Format("Processed {:d}/{:d} — waiting {:02d}:{:02d}", winCount, total, mins, secs)
        Sleep(1000)
    }
}

StopLoop() {
    global appState, statusField
    appState.isRunning := false
    statusField.Text := "Status: Paused"
}

CleanupAndExit() {
    global appState

    if (MsgBox("Exit the AFK tool?", "Exit", "YesNo Owner" . mainGui.Hwnd) != "Yes")
        return

    appState.isRunning := false

    try ToolTip()

    ExitApp()
}

; ---------------------- Hotkeys ----------------------
F6::StopLoop()
F7::StartLoop()
F8::CleanupAndExit()
F9::SetDebugClicks(!DEBUG_CLICKS)
F10::mainGui.Show("x1650 y836 w240 h122")

#HotIf WinActive("F7, F6, F8")
!s::ResizeAllWindows()      ; Alt+S → Stack
!t::TileWindows()           ; Alt+T → Tile
!c::WaterfallWindows()      ; Alt+C → Cascade
!w::ShowSettingsGUI()       ; Alt+W → Settings
#HotIf

; ---------------------- Run ----------------------
appState := AppStateManager()
LoadGUI()

; ------------------------------------------------------------
; KEYS TO SEND — SYNTAX REFERENCE
; ------------------------------------------------------------
; You can mix keys, waits, clicks, and holds in any order.
; Separate each command with a comma.
;
; EXAMPLES:
;
; r,l,k
;     → Presses r, then l, then k
;
; e,e,click 540 430,click 540 430,click 540 430
;     → Presses E x2, clicks at (540 430) x3