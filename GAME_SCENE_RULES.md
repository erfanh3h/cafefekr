# Cafe Fekr — Game Scene Architecture & Implementation Rules
> **Version:** 2.0  
> **Target Engine:** Godot 4.x (GDScript)  
> **Scope:** General UI, 3D Environment, Game Logic, Socket Networking, and Porting Standards for ALL present and future Cafe Fekr games (TicTacToe, Chess, FekrBekr, Checkers, Backgammon, Four-in-a-Row, Othello, Mill, DotBox, Battleship, Sudoku, Yatzy, etc.).

---

## 🛡️ CRITICAL MANDATORY DIRECTIVE: ZERO CROSS-GAME REGRESSIONS & STRICT GAME ISOLATION

> [!CAUTION]
> ### 🚨 NEVER BREAK EXISTING GAMES WHEN ADDING OR IMPROVING A GAME!
> **Every game in Cafe Fekr must remain completely independent, modular, encapsulated, and strictly follow clean object-oriented inheritance:**
>
> 1. **Zero Collateral Impact**:
>    - Adding a new game (e.g. FekrBekr, Checkers, Backgammon) or improving/polishing an existing game must **NEVER** break, regress, or alter the logic, visuals, timing, or flow of ANY other game (TicTacToe, Chess, etc.).
> 2. **Strict Encapsulation & Inheritance Hierarchy**:
>    - Every game board MUST extend and inherit from `BaseGameBoard` (`res://scripts/games/base_game_board.gd`).
>    - Every specialized top header MUST extend and inherit from `BaseTopHeader` (`res://scenes/games/base/base_top_header.gd`).
>    - Game-specific phases (e.g. FekrBekr secret code placement phase vs guess phase), custom side action buttons, dedicated dual board views, or specialized piece models **MUST** be encapsulated entirely inside that game's own scene and script folder (`res://scenes/games/<game>/`).
> 3. **NO Game-Specific Hacks in Core / Shared Singletons or Base Classes**:
>    - **NEVER** add ad-hoc hardcoded conditional branches (e.g., `if GameManager.current_game_type == ...`) inside core shared systems (`GameManager`, `SocketService`, `BaseGameBoard`, `BaseGameHUD`, `CafeTable`, `NetworkManager`) unless architecting a generic, cleanly documented virtual method or signal hook intended for all games.
>    - Changes to shared base classes MUST be backwards-compatible, default-safe, and must NEVER invert or change default behaviors expected by other games (e.g., do not prematurely show turn HUDs, do not force-change camera parameters, do not alter turn timer logic).
> 4. **Mandatory Multi-Game Regression Testing**:
>    - Whenever changes are made to shared autoloads, HUD, table, or base classes, you MUST verify that existing games (TicTacToe, Chess, FekrBekr, etc.) continue to run, start, transition rounds, and display dialogs flawlessly without side effects.

---

## ⚠️ THE GOLDEN PRINCIPLE: FLUTTER & BACKEND ARE THE ABSOLUTE SOURCES OF TRUTH

> [!IMPORTANT]
> **MANDATORY INSTRUCTION FOR ALL FUTURE AGENTS & DEVELOPERS:**  
> Every single game in Cafe Fekr has already been fully designed, programmed, balanced, and battle-tested in the Flutter mobile application (`d:\game\flutter-code`) and the Python WebSocket backend (`d:\game\kafehfekrbackend`).
>
> When starting work on ANY game in future conversations:
> 1. **DO NOT invent, guess, or approximate game rules, piece movement, board representation, or state logic.**
> 2. **DO NOT invent custom socket payloads or command sequences.**
> 3. **YOU MUST directly inspect and port the exact logic from the Flutter controller/models and the Python backend:**
>    - **Flutter Controller:** `d:\game\flutter-code\lib\Games\<GameName>\Controllers\<game>_controller.dart` (exact tap checks, turn checks, move validation, animations, round resets).
>    - **Flutter Models & Widgets:** `d:\game\flutter-code\lib\Games\<GameName>\Models\` and `Widgets\` (cell indexing, piece states, status enums).
>    - **Backend Session:** `d:\game\kafehfekrbackend\Controllers\GameSession\<game>_game_session.py` (exact command names, timers, round switching, win detection).
>    - **Backend Game Logic:** `d:\game\kafehfekrbackend\Entities\Games\<GameName>\` (board matrix structure, authority checking, win conditions).
> 4. **Create the UI and 3D visual presentation strictly following the unified rules below in this document.**

---

## 1. Architectural Philosophy

In Cafe Fekr, **the in-game experience is shared across ALL board games**:
1. **The 3D Cafe Environment is Constant**: The wooden cafe table, cozy warm lighting, candlelight, realistic animated hands, and camera orbit/zoom system (`scenes/environment/cafe_table.tscn`) remain identical for every game.
2. **The 2D In-Game HUD is Constant**: The top player cards, round count, turn banner, turn timer bar, 7-button bottom control bar, toast hints, reaction bubbles, pause/disconnect dialogs, and match result dialogs (`scenes/games/base/base_game_hud.tscn`) are unified and shared.
3. **Only the Board Changes**: Each game provides its own 3D board scene that is spawned dynamically inside `cafe_table`'s `BoardContainer`. Every board inherits from `BaseGameBoard` (`scripts/games/base_game_board.gd`).
4. **Header Inheritance for Special Game Elements**: If a game has specific UI elements not present in all games (e.g. Chess has AFK missed turns strikes, whereas TicTacToe does not), its header MUST inherit from `BaseTopHeader` (`scenes/games/base/base_top_header.gd`).

```
+-----------------------------------------------------------------------------------+
|                                  MAIN SCENE                                       |
|                                                                                   |
|  +-----------------------------------------------------------------------------+  |
|  | [3D Environment] CafeTable (scenes/environment/cafe_table.tscn)              |  |
|  |   |- Camera3D (Damped Orbit, Tilt, Zoom, 2D Top-Down Toggle)                |  |
|  |   |- Environment Lighting (OmniLight3D Lamp + Candlelight Flicker)           |  |
|  |   |- Realistic Hands (Player Hand + Opponent Hand with dynamic sleeve color)|  |
|  |   |- BoardContainer (Node3D)                                                 |  |
|  |        \--> [Spawned Game Board] (e.g. TicTacToe3D, Chess3D, FekrBekr3D)     |  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
|  +-----------------------------------------------------------------------------+  |
|  | [2D CanvasLayer] BaseGameHUD (scenes/games/base/base_game_hud.tscn)         |  |
|  |   |- Dynamic TopHeaderSlot (Loads BaseTopHeader or specialized child header)|  |
|  |   |- MatchDetailsBox (Round label, Turn Banner, Countdown, TurnTimerBar)    |  |
|  |   |- ToastHint (Bottom-center notification pill, Font size 32)              |  |
|  |   |- BottomBar (7 Buttons: 4 Camera Controls + 3 Match Controls)            |  |
|  |   |- DisconnectPauseDialog (45s Opponent Disconnect Countdown & Progress)   |  |
|  |   |- Dialogs (StartGameOverlay, RoundFinishBanner, GameResultDialog)        |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```

---

## 2. Universal In-Game UI Rules (`BaseGameHUD`)

### 2.1. Top Header Architecture & Inheritance (`TopHeaderSlot`)
- All games share the top player status area, but some games require unique elements (e.g. Chess displays AFK missed-turn strikes).
- **Base Header (`scenes/games/base/base_top_header.tscn` / `base_top_header.gd`):**
  - Displays P1 Card (Red theme `Color(1.0, 0.32, 0.35)`) and P2 Card (Blue theme `Color(0.25, 0.65, 1.0)`).
  - Tapping either avatar emits `p1_profile_clicked` / `p2_profile_clicked` to open `UserProfileDialog`.
  - Role indicator is a clean color dot: `🔴` or `🔵` (never use textual "X", "O", or piece letters in role tags).
  - Active turn card has a radiant glowing border and gentle spring juice; inactive card is dimmed.
- **Game-Specific Header Specialization Rule:**
  - When a game has extra header requirements (e.g. `ChessTopHeader`), it **MUST inherit from `BaseTopHeader`**.
  - Declare the scene inheritance in Godot (`scenes/games/<game>/<game>_top_header.tscn` inheriting `base_top_header.tscn`).
  - Register the scene in `GameRegistry` under `"top_header_scene"`.
  - Do NOT modify the base header to hardcode one game's features; use the inheritance pattern.

### 2.2. Match Details Box (`MatchDetailsBox`)
Located directly beneath the player cards at the top center:
- **Round Number (`LblRound`):**
  - Displays `"راند X از Y"` (e.g. `راند ۱ از ۵`).
  - Floats cleanly with soft text shadow and outline (`font_size = 32`).
- **Turn Banner (`TurnBanner`):**
  - Clearly announces whose turn it is in Persian:
    - My turn (Red): `"🔴 نوبت شماست (قرمز)! حرکت خود را انجام دهید"`
    - My turn (Blue): `"🔵 نوبت شماست (آبی)! حرکت خود را انجام دهید"`
    - Opponent turn: `"نوبت حریف است (قرمز/آبی)..."`
- **Turn Countdown Label (`LblTimer`):**
  - Shows remaining turn time: `"XX ثانیه"`.
  - When `time_left > 3.0s`: Warm golden color (`Color(1.0, 0.88, 0.3)`).
  - When `time_left <= 3.0s`: Warning red (`Color(1.0, 0.35, 0.35)`), urgency bounce scale animation (`1.25 -> 1.0`), and audio heartbeat ticking (`AudioManager.play_sound("time")`).
- **Turn Timer Bar (`TurnTimerBar`):**
  - **Background (`StyleBoxFlat_turn_timer_bg`):**
    - Inset groove styling: Deep dark espresso/chocolate color `Color(0.06, 0.04, 0.03, 0.9)`.
    - 2px golden-bronze border `Color(0.48, 0.36, 0.2, 0.75)`, pill capsule shape (`corner_radius = 10`), content margin padding of `3px`.
  - **Fill Bar (`StyleBoxFlat_timer_fill`):**
    - `corner_radius = 7` (concentric with the 10px outer radius minus 3px padding).
    - Color matches current turn: Red for P1, Blue for P2, Urgent Red for `<= 3s`.
  - **Dimensions:** Width `440px`, Height `20px`. Placed with 16px bottom margin inside `MatchDetailsBox`.

### 2.3. Bottom Action Bar (`BottomBar`)
Contains exactly **7 buttons** arranged horizontally at the bottom of the screen. All buttons are `96x96px`, wood-framed, tactile KenneyUI-styled with **white icons**:
- **Left Group (Camera & View Controls):**
  1. `BtnZoomIn`: Zoom In (`zoom_in_white.png`)
  2. `BtnZoomOut`: Zoom Out (`zoom_out_white.png`)
  3. `BtnCamTop`: 2D / 3D Toggle. Displays label text `"2D"` in 3D mode, and `"3D"` in top-down mode.
  4. `BtnCamReset`: Reset Camera View (`refresh.png`). Restores default orbit distance, yaw, and tilt.
- **Right Group (Match & Social Controls):**
  5. `BtnSurrender`: White surrender flag (`flag_surrender_white.png`). Opens confirmation dialog.
  6. `BtnReactions`: Kori / Emoji picker button (`kori.png`). Opens reaction grid.
  7. `BtnAudio`: White sound toggle (`soundOn_white.png` / `soundOff_white.png`). Toggles SFX & Music.

### 2.4. Floating Toast Notification (`ToastHint`)
Used for quick feedback messages (e.g. `"نوبتت نیست!"`, `"این خانه قبلاً انتخاب شده است!"`, `"زاویه دوربین بازگشت"`, `"راند ۲ آغاز شد!"`):
- **Position:** Anchored at **bottom-center** (`anchor_left = 0.5, anchor_right = 0.5, anchor_top = 1.0, anchor_bottom = 1.0`).
- **Offsets:** Symmetrically centered (`offset_left = -half_w, offset_right = half_w`, `offset_top = -240.0, offset_bottom = -165.0`).
- **Typography:** `font_size = 32`, centered alignment, golden font color with drop shadow.
- **Animation:** Chained Tween pop-in (`scale 0.85 -> 1.0`), 2.2s visible display, and smooth fade-out.
- **Implementation Note:** Never call `toast_hint.reset_size()` directly without resetting symmetric offsets, or the box will shift horizontally!

### 2.5. Disconnect Pause Dialog (`DisconnectPauseDialog`)
Matches Flutter's `DialogComponent().showTimerDialog` and backend `UserDisconnectTimerClass`:
- **Trigger:** Server sends `Commands.User_Disconnected` with `{"user_id": ..., "time": 45}`.
- **Behavior:**
  - Game timer is paused; board input is locked (`board.set_board_locked(true)`).
  - Dialog opens with blurred dark dimmer, displaying:
    - Title: `"اتصال حریف قطع شد"`
    - Description: `"بازیکن مقابل از مسابقه قطع شده است.\nدر انتظار بازگشت به بازی..."`
    - Live countdown label: `"مهلت اتصال مجدد: %d ثانیه"`
    - Animated progress bar counting down smoothly.
- **Reconnection:** If opponent reconnects (`Commands.User_Reconnected`), `hide_pause_dialog()` is called, game unpauses, board unlocks, and a green toast appears: `"✅ حریف مجدداً متصل شد! بازی از سر گرفته شد."`
- **Timeout:** If countdown reaches 0 or server sends `Commands.Finish_Reconnect_Time`:
  - `hide_pause_dialog()` is called immediately.
  - The remaining player is awarded the win. Result dialog opens with victory celebration.

### 2.6. Surrender & Match Result Dialog (`GameResultDialog`)
- **Surrender Confirmation:**
  - Clicking `BtnSurrender` opens a confirmation modal (`"آیا مطمئن هستید که می‌خواهید تسلیم شوید؟"`).
  - Confirming sends `Commands.Surrender` to backend and locks board immediately.
  - The confirmation modal is hidden immediately with `visible = false` and `mouse_filter = IGNORE` (no lingering asynchronous tweens).
- **Result Dialog Visibility Guarantee:**
  - In `show_result(...)`, always ensure `panel.visible = true`, `panel.modulate.a = 1.0`, `panel.mouse_filter = Control.MOUSE_FILTER_STOP`, and `btn_return.disabled = false`.
  - **CRITICAL:** Because `close()` and `close_immediate()` set `panel.visible = false`, `show_result()` MUST explicitly re-enable `panel.visible = true`, otherwise only the dark background DimOverlay will display and trap the user in a black screen!
- **Return to Menu:** Clicking `"خروج از بازی"` (`BtnReturn`) emits `return_to_menu_requested`, which triggers `leave_game_requested` on HUD, clearing board caches and smoothly returning to the main menu.

---

## 3. 3D Cafe Environment & Camera Rules (`CafeTable`)

The 3D environment represents a cozy, nostalgic board game cafe:
- **Target Focus:** `Vector3(0.0, 0.08, -0.04)` (the exact center of the table board).
- **Orbit View (3D Mode):**
  - **Distance / Zoom Boundaries:** Strictly bounded to `2.20m` (min zoom) and `3.55m` (max zoom). Default is `3.20m`.
  - **Yaw (Horizontal Orbit):** Strictly bounded to `[-31.5°, +31.5°]` (`[-0.55 rad, +0.55 rad]`).
  - **Pitch (Vertical Tilt):** Strictly bounded to `[-63.0°, -33.2°]` (`[-1.10 rad, -0.58 rad]`). Default is `-42.0°`.
  - **Privacy Rule:** The camera must NEVER zoom out or pan so far that character bodies, faces, or empty chairs become visible. Only the hands across the table should be seen.
- **Top-Down View (2D Mode):**
  - Camera pitch is locked to `-90.0°` (straight down looking at the board).
  - Heights: Min `2.75m` (full board visible with safe margin), Default `3.60m`, Max `5.20m` (wide view of table and mugs).
- **Lighting & Atmosphere:**
  - Table lamp omni-light: Energy `0.65 - 0.9` (prevents overexposed glare on game boards).
  - Candlelight: Subtle warm flicker at `5.5Hz` with sine modulation.
- **Realistic Hands System (`RealisticHand`):**
  - `PlayerHand` (enters from bottom) and `EnemyHand` (enters from top) place pieces with physical kinematics.
  - Sleeve color MUST match the player's role: Crimson Red (`Color(0.85, 0.15, 0.2)`) for P1, Sapphire Blue (`Color(0.15, 0.35, 0.85)`) for P2.

---

## 4. Game Board Implementation Standards (`BaseGameBoard`)

### 4.1. Class Structure & Lifecycle
Every game board MUST extend `BaseGameBoard`:
```gdscript
class_name MyGame3D
extends "res://scripts/games/base_game_board.gd"
```

Lifecycle hooks provided by `BaseGameBoard`:

| Hook Method | Description |
| :--- | :--- |
| `setup_board(game_data: Dictionary)` | Initializes board state from server payload upon match start. |
| `on_turn_changed(turn: int, is_my_turn: bool)` | Called when turn changes. Updates valid moves, unlocks inputs. |
| `on_piece_selected(user_id: int, target_peace: int, extra: Dictionary)` | Called when server broadcasts a move. Spawns piece and triggers drop VFX/SFX. |
| `on_round_finished(payload: Variant)` | Called when round ends. Locks board, highlights winning line/state. |
| `on_new_round(round_num: int)` | Resets board and state arrays for next round. |
| `on_reconnect_data(payload: Dictionary)` | Re-synchronizes board after player reconnects. |
| `sync_board_state(board_state: Variant)` | Reconstructs physical pieces from server board array. |
| `reset_board()` | Clears pieces, resets state arrays and variables. |
| `cleanup_board()` | Frees materials, nodes, tweens, and caches on exit. |

### 4.2. Input Handling & Race Condition Prevention Rule
To avoid duplicate input triggers (such as false *"این خانه قبلاً انتخاب شده است!"* errors):
1. **Single Source of Input:**
   - Use **Camera Raycasting** in `_unhandled_input` as the primary, rock-solid click/tap detector.
   - Do NOT bind click handlers to physics `Area3D.input_event` simultaneously! Use `Area3D` strictly for mouse hover visual feedback (`mouse_entered` / `mouse_exited`).
2. **Strict Validation Order in `_attempt_move` (Mirroring Flutter `canSelectPeace`):**
   ```gdscript
   func _attempt_move(target_idx: int) -> void:
       if not GameManager.is_game_active:
           return
       if target_idx < 0 or target_idx >= MAX_CELLS:
           return
           
       # 1. Silently ignore clicks if board is locked (waiting for server ACK or animating)
       if is_board_locked:
           return
           
       # 2. Check turn authority first
       if not is_my_turn:
           show_hint("نوبتت نیست!")
           AudioManager.play_sound("miss_turn")
           return
           
       # 3. Check cell occupancy / move validity
       if board_state[target_idx] != 0:
           show_hint("این خانه قبلاً انتخاب شده است!")
           AudioManager.play_sound("miss_turn")
           return
           
       # 4. Immediately lock board locally to drop subsequent rapid clicks
       set_board_locked(true)
       is_my_turn = false
       last_click_time = Time.get_ticks_msec() / 1000.0
       
       # 5. Dispatch move to server
       send_move(Commands.Select_Peace, target_idx)
   ```

### 4.3. Cache & Memory Cleanup Rule
Whenever a match concludes and the user returns to the lobby or main menu:
- `cafe_table.clear_board()` is called, which executes `cleanup_board()` on the current board node and calls `queue_free()`.
- Boards MUST implement `cleanup_board()` to cleanly kill running tweens, free piece nodes, and reset internal state arrays.
- Memory from the previous game must NEVER bleed into the next game (e.g. previous board state, piece positions, camera modes, or AFK strikes).

### 4.4. Audio Conventions (`AudioManager`)
Always use the standardized sound keys:
- Piece placed / dropped: `AudioManager.play_sound("add_peace")`
- Piece moved / slid: `AudioManager.play_sound("move_peace")`
- Piece captured: `AudioManager.play_sound("remove_peace")`
- Turn started: `AudioManager.play_sound("start_turn")`
- Round won: `AudioManager.play_sound("win")`
- Round lost: `AudioManager.play_sound("lose")`
- Round tied: `AudioManager.play_sound("draw")`
- Button click: `AudioManager.sfx_tap()` or `AudioManager.sfx_button()`
- Turn urgency heartbeat: `AudioManager.play_sound("time")`
- Missed turn / Warning: `AudioManager.play_sound("miss_turn")`

---

## 5. Step-by-Step Guide: Porting a New Game to Cafe Fekr

Whenever you are tasked with adding a new game (e.g. Checkers, Backgammon, Four-in-a-Row, Othello, Mill, etc.):

### Step 0: Study the Flutter & Backend References
Before writing any Godot code, open and read:
1. `d:\game\flutter-code\lib\Games\<GameName>\Controllers\<game>_controller.dart`
2. `d:\game\flutter-code\lib\Games\<GameName>\Models\`
3. `d:\game\kafehfekrbackend\Controllers\GameSession\<game>_game_session.py`
4. `d:\game\kafehfekrbackend\Entities\Games\<GameName>\`
Extract:
- Board size & indexing layout (e.g. 1D array of 64 cells, 24 points, etc.).
- Move commands (e.g. `Select_Peace`, `Move_Peace`, `Roll_Dice`, etc.) and payload structure.
- Win conditions and round count.

### Step 1: Register Game in Types & Registry
1. Add constant to `scripts/network/game_types.gd`:
   ```gdscript
   const NEW_GAME = "NewGame"
   ```
2. Add metadata in `scripts/games/game_registry.gd`:
   ```gdscript
   GameTypes.NEW_GAME: {
       "id": GameTypes.NEW_GAME,
       "name_fa": "نام بازی",
       "board_scene": "res://scenes/games/<new_game>/<new_game>_3d.tscn",
       "max_rounds": 3,
       "turn_time": 20.0,
       "icon": "res://assets/images/games/<new_game>.jpg",
       "min_players": 2,
       "max_players": 2,
       "is_3d": true
   }
   ```

### Step 2: Top Header Customization (If Required)
If the game requires extra elements in the top header (like AFK strikes or capture counters):
1. Create `scenes/games/<new_game>/<new_game>_top_header.tscn` inheriting from `base_top_header.tscn`.
2. Add script extending `BaseTopHeaderClass`.
3. Register `"top_header_scene"` in `game_registry.gd`.

### Step 3: Create 3D Physical Board
1. Create directory `scenes/games/<new_game>/`.
2. Build `<new_game>_3d.tscn` (Root: Node3D, script extending `BaseGameBoard`).
3. Size footprint: Board width/length between `0.90m` and `1.25m` to rest naturally on the cafe table.
4. Implement realistic physical meshes (warm woods, brass, polished lacquer, gemstone inlays matching Cafe Fekr aesthetics).
5. Implement physical piece drop and slide animations (calling `cafe_table.animate_place_piece` or `ActionVFXManager.animate_piece_drop`).

### Step 4: Wire `BaseGameBoard` Hooks
Implement `setup_board`, `on_turn_changed`, `on_piece_selected`, `sync_board_state`, `reset_board`, and `cleanup_board`.

### Step 5: Verification & Automated Testing
Always test headless compilation and automated logic via Godot console:
```powershell
& "D:\Games\Godot_v4.7.2-stable_win64_console.exe" --headless --path d:\game\cafefekr --quit
```

---

## 6. Checklist & Prohibitions

| Item | Rule |
| :--- | :--- |
| ❌ **No Cross-Game Regressions** | Never alter core shared code in a way that breaks, regresses, or alters behavior for existing games. |
| ❌ **No Game Hacks in Shared Systems** | Game-specific mechanics must live in the inherited board/header, not inside `GameManager` or `BaseGameBoard`. |
| ❌ **No Tight Coupling** | All games must be fully separate and pluggable through `GameRegistry` and standard `BaseGameBoard` lifecycle hooks. |
| ❌ **No Guessing Logics** | Never guess game rules; port them directly from `flutter-code` and `kafehfekrbackend`. |
| ❌ **No Custom HUDs** | Never build a standalone HUD per game. Always use `BaseGameHUD`. |
| ❌ **No Duplicate Input Listeners** | Do not bind click handlers to both `Area3D` and `_unhandled_input`. |
| ❌ **No Hidden Result Panels** | Always ensure `panel.visible = true` in `GameResultDialog.show_result()`. |
| ❌ **No Premature Game Finish** | Never set `is_game_finished = true` inside `stop_timer()`. |
| ❌ **No Endless Heartbeat** | Always call `AudioManager.stop_sound("time")` when a round or match ends. |
| ❌ **No Hardcoded Player Colors** | P1 is always Red, P2 is always Blue. Sleeves and piece highlights must reflect this. |
| ❌ **No Unbounded Cameras** | Do not zoom out to show full character models; maintain the cozy table view. |
