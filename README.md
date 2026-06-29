# Roblox Multi-Window Manager — AutoHotkey v2

A small AutoHotkey v2 utility that detects multiple Roblox windows, arranges them on screen, and periodically runs a configurable sequence of mouse/keyboard actions on selected windows using a simple GUI.

The script operates entirely at the desktop/OS level: it moves and activates windows and sends normal input events (clicks and keystrokes) to them. It does not modify any program files or memory.

-----------------------------------------------------------------------

## Features

**Multi-Window Detection**
- Detects Roblox windows by process name and title.
- Supports:
  - Web/desktop Roblox (`RobloxPlayerBeta.exe`)
  - Optional UWP (Microsoft Store) Roblox windows.

**Configurable Action Sequences**
- Runs a user-defined sequence of commands (clicks, waits, key presses, key holds) on each selected window.
- Actions are defined in a single comma-separated string and can be edited at runtime via a GUI "Edit" panel with named presets.
- Mouse clicks use a natural multi-step approach before landing on the target for reliability.

**Cycle Timer**
- Repeats the action sequence in cycles with a configurable delay between passes.
- Preset options: 0 seconds, 2 minutes, 5 minutes, 10 minutes.

**Window Layout Modes**
- **Stack:** Shrinks and stacks all windows in a small region.
- **Tile:** Arranges windows into a grid layout.
- **Waterfall:** Cascades windows diagonally across the screen.
- Layout operations respect any active window selection.

**Window Selection**
- Settings dialog lets you pick exactly which Roblox windows are included in the action loop.
- Buttons to activate individual windows for identification, select all, or select none.

**Settings Dialog**
- Web / UWP window type toggles.
- Minimize after actions toggle.
- Click delay (ms) — adjustable for slow machines.
- Debug clicks toggle (also F9) — shows a red indicator at each click position before firing.

**Responsive Pause**
- F6 stops the loop within ~250ms regardless of how long the current wait or key hold is.

**Hotkeys**

| Key | Action |
|-----|--------|
| F7 | Start loop |
| F6 | Stop / pause loop |
| F8 | Exit (with confirmation) |
| F9 | Toggle debug click indicators |
| F10 | Move GUI to corner |
| Alt+S | Stack windows |
| Alt+T | Tile windows |
| Alt+C | Waterfall windows |
| Alt+W | Open Settings |

**Error Logging**
- Logs errors to `error_log.txt` with timestamp and context.

-----------------------------------------------------------------------

## User Configuration

These values are defined at the top of the script under `USER CONFIGURATION`.

**Window Detection**
```
global WEB_ENABLED := true       ; Desktop Roblox (RobloxPlayerBeta.exe)
global UWP_ENABLED := false      ; Microsoft Store Roblox
```

**Default Actions**
```
global DEFAULT_KEYS := "wait 1000,click 410 460,..."
```

**Cycle Duration**
```
global SLEEP_DURATION := 120000  ; ms between cycles (120000 = 2 min)
```

**Window Behavior**
```
global MINIMIZE_AFTER_ACTIONS := false
global DEBUG_CLICKS := true
```

**Layout Settings**
```
global GRID_TIGHTNESS := 1.2       ; Tile grid density
global EDGE_NUDGE := 8             ; Pixel offset from screen edges
global WATERFALL_OFFSET_X := 30
global WATERFALL_OFFSET_Y := 30
global WATERFALL_WIDTH := 480
global WATERFALL_HEIGHT := 360
global TILE_WIDTH_OFFSET := 240
global TILE_HEIGHT_OFFSET := 224
global STACK_WINDOW_WIDTH := 100
global STACK_WINDOW_HEIGHT := 80
```

**Technical Constants**
```
global ACTIVATION_RETRY_MAX := 20
global ACTIVATION_RETRY_DELAY := 200  ; ms per retry
global KEY_SEND_DELAY := 100
global CLICK_PRE_DELAY := 200          ; ms between mouse move and click
global CLICK_POST_DELAY := 200         ; ms after click before next command
```

-----------------------------------------------------------------------

## Action Command Syntax

Actions are defined as a comma-separated string in the Edit dialog or `DEFAULT_KEYS`.

| Command | Example | Description |
|---------|---------|-------------|
| `wait N` | `wait 1000` | Sleep N milliseconds |
| `click X Y` | `click 410 460` | Move to (X, Y) in client coords and click |
| `hold KEY MS` | `hold w 6000` | Hold key down for N ms then release |
| any key | `r`, `space`, `enter` | Send that key |

Coordinates for `click` are **client coordinates** — use the "Client" values from AHK Window Spy, not Screen.

Example sequences:
```
r,1,k,2,3,m
wait 1000,click 410 460,wait 1000
hold e 500,hold e 500,hold e 500
wait 2000,click 180 517,wait 15000,click 104 212,wait 2000,click 660 212
```

-----------------------------------------------------------------------

## GUI Overview

**Main GUI** (`F7, F6, F8`)
- **Edit** — opens the action editor with presets and cycle timer.
- **Stack / Tile / Waterfall** — window layout operations.
- **Settings** — opens the settings dialog (window selection, Web/UWP, minimize, click delay, debug).
- Status line shows current state, active command, window counter, and countdown between cycles.

**Edit Dialog**
- Text box for the action command string.
- Cycle timer dropdown (00 Sec, 02 Min, 05 Min, 10 Min).
- Named preset buttons (Zone, Eggs, Hatch, Rcu, Key, Orbs).
- Save / Close.

**Settings Dialog**
- Window list with checkboxes — select which windows participate in the loop.
- Save / All / None selection buttons.
- Web / UWP toggles.
- Minimize after actions.
- Debug clicks (F9).
- Click delay (ms) input.

-----------------------------------------------------------------------

## Main Loop Behavior

When started (F7):

1. Detects all Roblox windows per Web/UWP settings.
2. Maintains an active window list — auto-adds new windows unless explicitly excluded.
3. For each window:
   - Restores if minimized, activates, waits for foreground focus (with retries).
   - Runs the action sequence on active windows; sends a keep-alive key (`m`) to others.
   - Optionally minimizes after actions.
4. Counts down the configured sleep duration in the status bar.
5. Repeats until F6 or F8.

-----------------------------------------------------------------------

## Requirements

- AutoHotkey v2.0 or later.
- Windows OS with Roblox desktop or UWP client.

## Installation

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Save `afk tool 26.ahk` anywhere on your machine.
3. Double-click the `.ahk` file to run.
4. Press F7 to start, F6 to stop, F8 to exit.

Optionally compile to a standalone `.exe` with the AutoHotkey compiler.

-----------------------------------------------------------------------

## Disclaimer

This script runs purely at the desktop input and window-management level.  
It activates windows, moves/resizes them, and sends normal mouse/keyboard input.  
It does not modify, inspect, or hook into Roblox or any other application's memory or files.  
Use responsibly and in accordance with the terms of service of any software you run it with.

-----------------------------------------------------------------------

## License

MIT License
