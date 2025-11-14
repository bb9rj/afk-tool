# Roblox Multi-Window Manager — AutoHotkey v2

A small AutoHotkey v2 utility that detects multiple Roblox windows, arranges them on screen, and periodically runs a configurable sequence of mouse/keyboard actions on selected windows using a simple GUI.

The script operates entirely at the desktop/OS level: it moves and activates windows and sends normal input events (clicks and keystrokes) to them. It does not modify any program files or memory.

-----------------------------------------------------------------------

## Features

Multi-Window Detection
- Detects Roblox windows by process name and title.
- Supports:
  - Web/desktop Roblox (`RobloxPlayerBeta.exe`)
  - Optional UWP (Microsoft Store) Roblox windows.

Configurable Action Sequences
- Runs a user-defined sequence of commands (clicks, waits, key presses, key holds) on each selected window.
- Actions are defined in a single comma-separated string and can be edited at runtime via a GUI “Edit” panel with presets.

Cycle Timer
- Repeats the action sequence in cycles with a configurable delay between passes.
- Preset options:
  - 0 seconds
  - 2 minutes
  - 5 minutes
  - 10 minutes

Window Minimization
- Optional setting to minimize each window after actions have been executed.
- Minimization can also apply to “keep-alive” windows.

Window Layout Modes
- Stack: Shrinks and stacks windows in a small region.
- Tile: Arranges windows into a grid layout.
- Waterfall: Cascades windows diagonally across the screen.

Window Selection GUI
- Dedicated selector window to pick exactly which Roblox windows should be part of the main action loop.
- Buttons to:
  - Activate individual windows
  - Select all
  - Select none
  - Save selection

Hotkeys
- F7 → Start main loop
- F6 → Stop/pause loop
- F8 → Exit script
- F10 → Bring main GUI back into view

Error Logging
- Logs errors to `error_log.txt` with a timestamp and context for troubleshooting.

-----------------------------------------------------------------------

## User Configuration (Editable at Top of Script)

These values are defined in the “USER CONFIGURATION” section and can be changed directly in the script.

Window Detection
- WEB_ENABLED  
  Include the standard desktop Roblox windows (`RobloxPlayerBeta.exe`):
    global WEB_ENABLED := true

- UWP_ENABLED  
  Include UWP / Microsoft Store Roblox windows:
    global UWP_ENABLED := false

Default Actions
- DEFAULT_KEYS  
  Comma-separated list of commands that define the default action sequence:
    global DEFAULT_KEYS := "wait 1000,click 410 460,r,1,k,2,3,m,r,m,r,m,r,m,r,l,click 410 460,wait 1000"

Cycle Duration
- SLEEP_DURATION  
  Time between cycles in milliseconds:
    global SLEEP_DURATION := 120000

  Typical values:
  - 0        = no wait between cycles
  - 120000   = 2 minutes
  - 300000   = 5 minutes
  - 600000   = 10 minutes

Window Behavior
- MINIMIZE_AFTER_ACTIONS  
  Minimize each window after actions run:
    global MINIMIZE_AFTER_ACTIONS := true

Layout Settings (Tile / Stack / Waterfall)
- GRID_TIGHTNESS  
  Controls how dense the tiling grid is:
    global GRID_TIGHTNESS := 1.2

- EDGE_NUDGE  
  Small offset from the screen edges:
    global EDGE_NUDGE := 8

Waterfall Layout
- WATERFALL_OFFSET_X / WATERFALL_OFFSET_Y  
  Spacing between cascaded windows:
    global WATERFALL_OFFSET_X := 30  
    global WATERFALL_OFFSET_Y := 30

- WATERFALL_WIDTH / WATERFALL_HEIGHT  
  Window size for waterfall layout:
    global WATERFALL_WIDTH := 480  
    global WATERFALL_HEIGHT := 360

Tile Layout
- TILE_WIDTH_OFFSET / TILE_HEIGHT_OFFSET  
  Reduce usable work area by these amounts when tiling:
    global TILE_WIDTH_OFFSET := 240  
    global TILE_HEIGHT_OFFSET := 224

Stack Layout
- STACK_WINDOW_WIDTH / STACK_WINDOW_HEIGHT  
  Window size when stacking:
    global STACK_WINDOW_WIDTH := 100  
    global STACK_WINDOW_HEIGHT := 80

Technical Constants
- WINDOW_RESTORE_DELAY, WINDOW_MOVE_DELAY, ACTIVATION_RETRY_MAX, ACTIVATION_RETRY_DELAY, KEY_SEND_DELAY, TOOLTIP_DURATION  
  These control internal timing and retries for window activation and movement. They are pre-tuned and usually should not be changed.

-----------------------------------------------------------------------

## Action Command Syntax

Actions are defined in a single comma-separated string (DEFAULT_KEYS or the GUI “Actions” field).

Supported commands include:

wait N
- Example: `wait 1000`
- Sleeps for N milliseconds before continuing.

click X Y
- Example: `click 410 460`
- Moves the mouse to (X, Y) relative to the active window and performs a click.
- Includes internal validation to avoid obviously invalid coordinates.

hold KEY DURATION
- Example: `hold e 500`
- Holds the specified key down for DURATION milliseconds, then releases it.

Single Keys / Specials
- Any token that is not “wait”, “click”, or “hold” is treated as a key.
- Some special mappings:
  - `space`  → Spacebar
  - `enter`  → Enter
  - `tab`    → Tab
  - `shift`  → Shift
  - `ctrl`   → Ctrl
  - `alt`    → Alt
- Any other value is sent as `{key}` (e.g. `r`, `1`, `k`, etc.).

Example sequences:
- `r,1,k,2,3,m`
- `wait 1000,click 410 460,wait 1000`
- `hold e 500,hold e 500,hold e 500`

-----------------------------------------------------------------------

## GUI Overview

Main GUI (caption: “F7, F6, F8”) provides:

- Cycle dropdown:
  - 00 Sec, 02 Min, 05 Min, 10 Min
- Web / UWP checkboxes:
  - Choose which Roblox window types to include.
- Actions section:
  - “Edit” button opens a preset GUI to pick or edit the command string.
- “Minimize after actions” checkbox:
  - Toggles whether windows are minimized after actions run.
- Buttons:
  - Stack: Shrink and stack all detected windows.
  - Tile: Arrange all detected windows in a grid.
  - Waterfall: Cascade windows diagonally.
  - Windows: Open the window selector to pick which windows are “active.”
- Status line:
  - Shows current state, errors, and countdown between cycles.

Window Selector GUI (“Pick Windows”):

- Lists all detected Roblox windows with:
  - Checkbox to include/exclude each one.
  - Button to activate each window for visual identification.
- Buttons:
  - Save: Store current selection into the app state.
  - All: Select all windows.
  - None: Deselect all windows.
  - Close: Close the selector.

Presets GUI (“Default Actions”):

- Edit box for the action string.
- Buttons for named presets (Zone, Eggs, Hatch, Rcu, Key).
- Save: Apply changes to the main GUI.
- Close: Close the dialog without saving.

-----------------------------------------------------------------------

## Main Loop Behavior

When started (F7):

1. Detects all Roblox windows according to Web/UWP settings.
2. Builds and maintains a list of “active” windows:
   - If no manual selection has been made, all detected windows are included.
   - If selection is made, new windows are added automatically unless explicitly excluded.
3. For each window:
   - Activates it and waits until it becomes the foreground window (with retries).
   - Runs the configured action sequence on “main” windows.
   - Sends a simple keep-alive key (“m”) to other windows.
   - Optionally minimizes windows after actions or keep-alive, depending on the checkbox.
4. After finishing all windows in a cycle:
   - Waits for the configured SLEEP_DURATION using a second-by-second countdown in the status bar.
5. Repeats until stopped (F6) or the script exits (F8).

-----------------------------------------------------------------------

## Requirements

- AutoHotkey v2.0 or later.
- Windows OS with Roblox desktop or UWP client.
- Script must be saved as `.ahk` and run with AutoHotkey v2.

-----------------------------------------------------------------------

## Installation and Running

1. Install AutoHotkey v2 from the official site.
2. Save the script as:
   RobloxMultiWindowManager.ahk
3. Double-click the `.ahk` file to run it with AutoHotkey v2.
4. The main GUI will appear:
   - Configure cycle time, window types, and actions.
   - Press F7 to start, F6 to stop, F8 to exit.

<img width="755" height="379" alt="image" src="https://github.com/user-attachments/assets/c67d3f06-aa98-4b4c-9e11-a644872bc75d" />

(Optionally, you can compile the script with the AutoHotkey compiler to produce a standalone `.exe` if desired.)

-----------------------------------------------------------------------

## Disclaimer

This script runs purely at the desktop input and window-management level.  
It activates windows, moves/resizes them, and sends normal mouse/keyboard input.  
It does not modify, inspect, or hook into Roblox or any other application’s memory or files.  
Use responsibly and in accordance with the terms of service of any software you run it with.

-----------------------------------------------------------------------

## License

MIT License
