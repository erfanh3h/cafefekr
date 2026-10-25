# Cafe Fekr — Game Scene Architecture & Implementation Rules
> **Version:** 2.1  
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
>    - Whenever changes are made to shared autoloads, HUD, table, or base classes, you MUST verify that existing games (TicTacToe, Chess, FekrBekr, etc.) continue to run, start, transition rounds, reconnect, and display dialogs flawlessly without side effects.

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
2. **The 2D In-Game HUD is Constant**: The top player cards, round count, turn banner, turn timer bar, 8-button bottom control bar, toast hints, reaction bubbles, pause/disconnect dialogs, and match result dialogs (`scenes/games/base/base_game_hud.tscn`) are unified and shared.
3. **Only the Board Changes**: Each game provides its own 3D board scene that is spawned dynamically inside `cafe_table`'s `BoardContainer`. Every board inherits from `BaseGameBoard` (`scripts/games/base_game_board.gd`).
4. **Header Inheritance for Special Game Elements**: If a game has specific UI elements not present in all games (e.g. Chess has AFK missed turns strikes, whereas TicTacToe does not), its header MUST inherit from `BaseTopHeader` (`scenes/games/base/base_top_header.gd`).

```
+-----------------------------------------------------------------------------------+
|                                  MAIN SCENE                                       |
|                                                                                   |
|  +-----------------------------------------------------------------------------+  |
|  | [3D Environment] CafeTable (scenes/environment/cafe_table.tscn)              |  |
|  |   |- Camera3D (Damped Orbit, Tilt, Zoom, 2D Top-Down Toggle, Drag Lock)     |  |
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
|  |   |- BottomBar (8 Buttons: 4 Camera Controls + 4 Match Controls)            |  |
|  |   |- DisconnectPauseDialog (45s Opponent Disconnect Countdown & Progress)   |  |
|  |   |- Dialogs (StartGameOverlay, RoundFinishBanner, GameResultDialog)        |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```

---

## 2. Universal In-Game UI Rules (`BaseGameHUD`)

### 2.1. Top Header Architecture, Royal Player Plaques & Score Badges (`TopHeaderSlot`)
- All games share the top player status area, while games requiring extra widgets (e.g. Chess AFK missed-turn strikes) specialize `BaseTopHeader`.
- **Base Header (`scenes/games/base/base_top_header.tscn` / `base_top_header.gd`):**
  - **Royal Player Plaques (`P1Card` & `P2Card`):**
    - P1 Card uses a Royal Crimson-Gold illuminated plaque when active (`Color(1.0, 0.42, 0.38)` border) and P2 Card uses a Royal Sapphire-Gold illuminated plaque when active (`Color(0.32, 0.76, 1.0)` border); inactive cards use carved dark walnut with warm brass trim.
    - Each card features a circular gold/player-tinted **Avatar Medallion Frame** (`_p1_avatar_frame` / `_p2_avatar_frame`), a bottom **"شما" / "حریف" pill tag**, and a styled **Role Badge pill** (`"🔴 مهره قرمز"` / `"🔵 مهره آبی"`, `"🔴 ارتش قرمز"` / `"🔵 ارتش آبی"` in Chess, or `"🔐 کدشکن"` in FekrBekr).
    - Tapping either avatar emits `p1_profile_clicked` / `p2_profile_clicked` to open `UserProfileDialog`.
  - **Score Badge Visibility Rule (`GameRegistry.has_round_score`):**
    - In games that do **not** have round scores (e.g. `Chess` and `FekrBekr`, where `GameRegistry.has_round_score(game_type)` is `false`), `ScoreBadge` (`_p1_score_badge` and `_p2_score_badge`) **MUST be hidden** (`visible = false`).
    - Only score-based games (such as `TicTacToe` for round wins and `Yatzy` for cumulative points) display the score badge inside the player cards.
  - **Score Badge Persian Typography & Single-Child Rule:**
    - `Score` inside `ScoreBadge` **MUST** use the Persian game font (`res://assets/fonts/hekayat.ttf`, `font_size = 40`, `outline_size = 3`) and Persian numerals (`_fa_digits(score)` -> `"۰"`, `"۱"`, `"۲"`, `"۳"`), matching the Persian numeral styling on the `FekrBekr` 3D board.
    - **NEVER** add extra child `Label` nodes (such as a `"🏆"` crown tag) directly inside `ScoreBadge` (`PanelContainer`), because `PanelContainer` stacks all direct children in the same rect and causes overlapping glyphs.
  - **No Floating Center Sword / VS Icon:**
    - Do **NOT** spawn any floating `⚔️` / VS emblem between `P1Card` and `P2Card`; it stacks over the pre-game `StartGameOverlay` dialog and clutters the top header.
- **Game-Specific Header Specialization Rule:**
  - When a game has extra header requirements (e.g. `ChessTopHeader`), it **MUST inherit from `BaseTopHeader`**.
  - Declare the scene inheritance in Godot (`scenes/games/<game>/<game>_top_header.tscn` inheriting `base_top_header.tscn`).
  - Register the scene in `GameRegistry` under `"top_header_scene"`.
  - Do NOT modify the base header to hardcode one game's features; use the inheritance pattern.

### 2.2. Compact 2-Row Match Details Box (`MatchDetailsBox`) & Real-Time Timer Bar VFX
Located directly beneath the player cards at the top center:
- **Compact 2-Row Console Structure (`540 × 101 px` — Full Font Sizes Preserved):**
  - Instead of stacking 4 tall vertical rows, `MatchDetailsBox` is structured as a sleek 2-row console (`custom_minimum_size = Vector2(540, 0)`, `corner_radius = 18`):
    1. **Row 1 (`TopStatusRow`):** Horizontal `HBoxContainer` combining:
       - **Round Pill (`RoundPanel` / `LblRound`):** Displays `"راند ۱ از ۵"` in multi-round games (or the Persian game title in single-round games) at `font_size = 28` using Persian digits (`_fa_digits`).
       - **Turn Banner (`TurnBanner`):** Expanding center status text at `font_size = 28`:
         - Pre-game waiting state: `"بازی درحال آغاز است"` (`Color(1.0, 0.88, 0.45)`).
         - My turn: `"🔴 نوبت شماست (قرمز)"` / `"🔵 نوبت شماست (آبی)"`.
         - Opponent turn: `"⏳ نوبت <نام حریف>"`.
       - **Timer Pill (`TimerRow` / `LblTimer`):** Stopwatch icon (`time.png`) + remaining time pill `"۱۰ ثانیه"` (`font_size = 26`) using Persian digits (`_fa_digits`).
    2. **Row 2 (`TurnTimerBar`):** Full-width recessed capsule bar (`504 × 22 px`, `corner_radius = 11`) with `TimerBarVFXOverlay`.
- **Real-Time Procedural Timer Bar VFX (`TimerBarVFXOverlay`):**
  - `TurnTimerBar` hosts a custom `Control` overlay (`TimerBarVFXOverlay`) that renders 60fps procedural VFX in `_draw()`:
    - **Normal Turn State (`remaining_sec > 4.0s`):**
      - Smooth traveling energy shimmer bands sweeping across the filled portion of the bar.
      - Glowing leading-edge comet/fuse head at the bar tip with a rotating 4-ray star flare and gentle floating sparkles tinted to the active player's color (Red for P1, Blue for P2).
    - **Critical Finishing State (`remaining_sec <= 4.0s`):**
      - High-intensity fiery gold/crimson ember bursts (3× particle spawn rate) and expanding shockwave rings (`trigger_danger_shockwave()`) on each final second tick.
      - Pulsing neon danger aura around the bar, urgent red fill (`Color(1.0, 0.24, 0.26)`), ringing stopwatch icon oscillation, scale pulse on `LblTimer`, and audio heartbeat ticking (`AudioManager.play_sound("time")`).

### 2.3. Bottom Action Bar (`BottomBar`), Kori (کری‌خوانی) & Sticker Controls — Unified Wood & Icon Rule
Contains **8 core buttons** arranged horizontally at the bottom of the screen (`margin_left = 24, margin_right = 24, separation = 10`), plus any game-specific action buttons (such as FekrBekr Phase 1 & Phase 2 buttons):
- **Unified Background Color (`KenneyUI.COLOR_WOOD`):**
  - Because `res://assets/images/frames/button.png` is a rich warm orange-brown wood texture (`RGB ≈ 115, 48, 28`), multiplying it by low-red tints (like raw blue or green) crushes the red channel and turns buttons into dark muddy charcoal.
  - Therefore, **all 8 buttons in `BottomBar`** and **all game-specific HUD action buttons** (e.g. `btn_fekr_submit`, `btn_fekr_clear`, `btn_fekr_opp`, `btn_fekr_dual`) **MUST** use `KenneyUI.COLOR_WOOD` so that every button on the HUD shares the exact same warm wood background color.
- **Transparent Icon Asset Rule:**
  - Every icon placed inside a HUD button (`zoom_in_white.png`, `zoom_out_white.png`, `refresh.png`, `flag_surrender_white.png`, `kori.png`, `Reactions/5.png`, `soundOn_white.png`, `soundOff_white.png`, `check.png`, `cross.png`, `aim.png`, `expand.png`) **MUST** have a **100% transparent background (`alpha = 0`)**.
  - **NEVER** use icon PNGs that have a baked dark or colored square background inside a wooden button frame.
- **Left Group (Camera & View Controls):**
  1. `BtnZoomIn`: Zoom In (`zoom_in_white.png`).
  2. `BtnZoomOut`: Zoom Out (`zoom_out_white.png`).
  3. `BtnCamTop`: 2D / 3D Toggle. Default view for every game is **2D (top-down)** (`is_top_down_view = true`), so `BtnCamTop` initially displays `"3D"` (tap to switch to 3D) and `"2D"` when in 3D mode (tap to switch back to 2D).
  4. `BtnCamReset`: Reset Camera View (`refresh.png`). Resets zoom height in 2D mode or orbit distance/yaw/tilt in 3D mode **without** leaving the current 2D/3D mode.
- **Right Group (Match & Social Controls):**
  5. `BtnSurrender`: White surrender flag (`flag_surrender_white.png`). Opens surrender confirmation dialog.
  6. `BtnKori`: کری‌خوانی (Kori / Taunt) button (`res://assets/icons/General/kori.png` — comment icon). Calls `reaction_picker.open_koris()` to display the scrollable 78-phrase Persian taunt list (`KORIS` from Flutter `app_consts.dart`).
  7. `BtnReactions`: Sticker / Emoji picker button (`res://assets/icons/Reactions/5.png` — sticker icon). Calls `reaction_picker.open_stickers()` to display the sticker grid.
  8. `BtnAudio`: White sound toggle (`soundOn_white.png` / `soundOff_white.png`). Toggles SFX & Music.
- **Kori (کری‌خوانی) & Sticker Network Protocol (`ReactionPicker` & `BaseTopHeader.show_reaction`):**
  - **Stickers (`reactionId <= 100`):** Sends `1..44` via `NetworkManager.send_game_reaction(r_id)`. `BaseTopHeader.show_reaction()` renders the sticker texture inside a `120 × 120` `BubbleFrame` on the player's top plaque for `2.4s`.
  - **Kori Taunts (`reactionId > 100`):** Selecting taunt `index` (`0..77`) sends `index + 101` (`101..178`) via `NetworkManager.send_game_reaction(index + 101)`. `BaseTopHeader.show_reaction()` looks up `KORIS[reaction_id - 101]`, plays `AudioManager.play_sound("chat")`, and displays a `330 × 104` Persian speech bubble (`"💬 " + KORIS[k_idx]`) on the player's top plaque for `4.2s`.

### 2.4. Floating Toast Notification (`ToastHint`)
Used for quick feedback messages (e.g. `"نوبت شما نیست؛ لطفاً منتظر حرکت حریف بمانید."`, `"این خانه قبلاً پر شده است؛ خانه دیگری انتخاب کنید."`, `"زاویه دوربین به حالت پیش‌فرض بازگشت"`, `" آغاز راند ۲ — آماده باشید!"`):
- **Position:** Anchored at **bottom-center** (`anchor_left = 0.5, anchor_right = 0.5, anchor_top = 1.0, anchor_bottom = 1.0`).
- **Offsets:** Symmetrically centered (`offset_left = -half_w, offset_right = half_w`, `offset_top = -240.0, offset_bottom = -165.0`).
- **Typography:** `font_size = 32`, centered alignment, golden font color with drop shadow.
- **Animation:** Chained Tween pop-in (`scale 0.85 -> 1.0`), 2.2s visible display, and smooth fade-out.
- **Implementation Note:** Never call `toast_hint.reset_size()` directly without resetting symmetric offsets, or the box will shift horizontally!

### 2.5. Disconnect Pause Dialog (`DisconnectPauseDialog`) & Reconnect Timer Synchronization
Matches Flutter's `DialogComponent().showTimerDialog` and backend `UserDisconnectTimerClass`:
- **Trigger (`Commands.User_Disconnected`):** Server sends `{"user_id": ..., "time": 45}`.
- **Pause Behavior:**
  - `hud.pause_turn_timer()` MUST be called so `turn_time_left` freezes while the match is paused, and board input is locked (`board.set_board_locked(true)`).
  - Dialog opens with blurred dark dimmer, displaying:
    - Title: `"⏸️ وقفه در مسابقه — قطع اتصال حریف"`
    - Description: `"ارتباط حریف با سرور موقتاً قطع شده است.\nلطفاً شکیبا باشید؛ در صورت عدم بازگشت در مهلت مقرر، پیروزی این مسابقه برای شما ثبت خواهد شد."`
    - Live countdown label: `"⏳ مهلت بازگشت حریف: %d ثانیه"`
    - Animated progress bar counting down smoothly.
- **Opponent Reconnection (`Commands.User_Reconnected`):**
  - The staying player ONLY receives `Commands.User_Reconnected` (they do NOT receive `Reconnect_Data`), and the returning player receives `User_Reconnected` ~2s before `Reconnect_Data`.
  - When `Commands.User_Reconnected` arrives, `main.gd` MUST call `hud.hide_pause_dialog()`, unlock the board, and call `hud.resume_timer_on_user_reconnected(remaining_time)` (extracting `time` from the payload if provided) so the turn countdown immediately resumes from the accurate remaining time.
- **Returning Player State & Timer Restoration (`Commands.Reconnect_Data` Ordering Rule):**
  - Because `BaseGameBoard` connects to `GameManager.reconnect_data_received` inside `_ready()` (after `main.gd`), `BaseGameBoard._on_internal_reconnect_data(payload)` runs **after** `main.gd:_on_reconnect_data_received(payload)`.
  - **CRITICAL RULE:** Any call to `hud.update_turn(...)` or `hud.set_setup_phase(...)` inside a board's `on_reconnect_data()` or `on_turn_changed()` resets `turn_time_left` to the full default duration (`20s` / `30s` / `45s`). Therefore, `BaseGameBoard._on_internal_reconnect_data(payload)` **MUST** call `hud.sync_reconnect_timer(payload)` **at the very end** (after `on_reconnect_data` and `on_turn_changed`) to restore the exact server remaining time (`payload["time"]`, which is `max_time - counter`).
  - For multi-phase games like `FekrBekr`, `sync_reconnect_timer(payload)` checks `payload["status"]` (`1` = 45s Secret Code Setup Phase, `2` = 30s Guessing Phase) and synchronizes both `turn_time_left` and `turn_max_time` accordingly.
- **Timeout (`Commands.Finish_Reconnect_Time`):**
  - `hide_pause_dialog()` is called immediately, and the remaining player is awarded the win via `GameResultDialog`.

### 2.6. Final Round Score Synchronization, Surrender & Match Result Dialog (`GameResultDialog`)
- **Final Round Score Synchronization Rule (`_current_round_scored` in `main.gd`):**
  - In round-based games (such as `TicTacToe`), when the final match-clinching round finishes (e.g., making the match `3 - 0`), the backend server may emit `Commands.Finish_Game` directly or emit `Commands.Finish_Game` **before** `Commands.Finish_Round`.
  - `main.gd` **MUST** track `_current_round_scored: bool` (reset to `false` in `_start_game_match()`, `_on_new_round_started()`, and `_on_turn_changed()`).
  - In both `_on_round_finished(payload)` and `_on_game_finished(data)`:
    - If `GameRegistry.has_round_score(GameManager.current_game_type)` and `not _current_round_scored` (and the match was not ended by surrender or disconnect timeout), set `_current_round_scored = true`, increment `GameManager.p1_score` (if `winner == 1`) or `GameManager.p2_score` (if `winner == 2`), and call `base_game_hud.update_scores(GameManager.p1_score, GameManager.p2_score)` **BEFORE** calling `base_game_hud.show_game_result(...)`.
    - This guarantees the finished dialog always displays the true final score (e.g., `۳ - ۰` instead of `۲ - ۰`) and never double-increments if both `Finish_Round` and `Finish_Game` arrive for the final round.
  - `BaseGameHUD.update_scores(...)` also forwards updates to `result_dialog.update_scores(...)`, and `GameResultDialog` formats round scores with Persian digits (`"امتیاز دست‌ها: %s" % _fa_digits(score)`).
- **Surrender Confirmation:**
  - Clicking `BtnSurrender` opens a confirmation modal (`"آیا از ادامه مسابقه انصراف می‌دهید؟\nبا اعلام تسلیم، نتیجه این بازی به سود حریف ثبت خواهد شد."`).
  - Confirming sends `Commands.Surrender` to backend and locks the board immediately.
  - The confirmation modal is hidden immediately with `visible = false` and `mouse_filter = IGNORE`.
- **Single-Execution Idempotency Guard (Preventing Double Finish Dialogs):**
  - When a player surrenders, the backend emits `Commands.Surrender` followed by `Commands.Finish_Game` (and in some backend sessions `Finish_Game` is emitted twice due to `timer.stop()` + `check_finish_game()`). Meanwhile, the local client also triggers a 1.15s surrender transition tween.
  - `BaseGameHUD` MUST maintain `_surrender_handled: bool`, `_result_shown: bool`, and `_surrender_result_tween: Tween` (all reset in `setup_match()`):
    - `show_surrender_notification()` returns immediately if `_surrender_handled` or `_result_shown` is `true`.
    - `show_game_result()` returns immediately if `_result_shown` is `true`, sets `_result_shown = true`, and kills `_surrender_result_tween` if running.
    - `GameResultDialog.show_result()` also guards against duplicate open animations if `visible and panel and panel.visible`.
- **Result Dialog Visibility Guarantee:**
  - In `show_result(...)`, always ensure `panel.visible = true`, `panel.modulate.a = 1.0`, `panel.mouse_filter = Control.MOUSE_FILTER_STOP`, and `btn_return.disabled = false`.
  - **CRITICAL:** Because `close()` and `close_immediate()` set `panel.visible = false`, `show_result()` MUST explicitly re-enable `panel.visible = true`, otherwise only the dark background DimOverlay will display and trap the user in a black screen!
- **Return to Menu:** Clicking `"بازگشت به لابی کافه"` (`BtnReturn`) emits `return_to_menu_requested`, which triggers `leave_game_requested` on HUD, clearing board caches and smoothly returning to the main menu.

---

## 3. 3D Cafe Environment & Camera Rules (`CafeTable`)

The 3D environment represents a cozy, nostalgic board game cafe:
- **Target Focus:** `Vector3(0.0, 0.08, -0.04)` (the exact center of the table board).
- **Orbit View (3D Mode):**
  - **Distance / Zoom Boundaries:** Strictly bounded to `2.20m` (min zoom) and `3.55m` (max zoom). Default is `3.20m`.
  - **Yaw (Horizontal Orbit):** Strictly bounded to `[-31.5°, +31.5°]` (`[-0.55 rad, +0.55 rad]`).
  - **Pitch (Vertical Tilt):** Strictly bounded to `[-63.0°, -33.2°]` (`[-1.10 rad, -0.58 rad]`). Default is `-42.0°`.
  - **Privacy Rule:** The camera must NEVER zoom out or pan so far that character bodies, faces, or empty chairs become visible. Only the hands across the table should be seen.
- **Camera Drag Lock During Piece Interaction (`camera_drag_locked`):**
  - In games that support drag-and-drop piece placement or interactive board controls (e.g. FekrBekr Phase 1 & Phase 2 peg dragging), the board MUST set `cafe_table.camera_drag_locked = true` as soon as the player presses or drags an interactive piece/slot, and reset `cafe_table.camera_drag_locked = false` on mouse release (`_input` release handler).
  - When `camera_drag_locked` is `true`, `CafeTable` immediately cancels `_is_dragging_camera` so releasing or dragging a piece on the board NEVER causes the camera to jump or orbit.
- **Top-Down View (Default 2D Mode for All Games & Strict 2D Lock Rule):**
  - **Default View is 2D:** Every game starts in **2D (top-down)** view (`is_top_down_view = true`, `camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)`, height `3.60m`). `transition_to_board_view()` and `spawn_board()` initialize `is_top_down_view = true` and emit `camera_mode_changed.emit(true)` so `BtnCamTop` displays `"3D"`.
  - **Strict 2D Lock Rule (No Accidental Jump to 3D):** While `is_top_down_view == true`, tapping pieces/cells (e.g. in Chess or TicTacToe), moving the mouse, single-finger dragging, double-tapping, or pressing `BtnCamReset` (`reset_camera_orbit()`) **MUST NEVER** set `is_top_down_view = false` or transition the camera to 3D. Only explicitly tapping `BtnCamTop` (`toggle_top_down_view()`) switches between 2D and 3D.
  - **Mouse Press Safety Reset:** In `CafeTable._process(delta)`, if `_mouse_pressed` is `true` and `not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)`, `CafeTable` must immediately reset `_mouse_pressed = false` and `_is_dragging = false` so board piece clicks that consume release events (`set_input_as_handled()`) never leave `_mouse_pressed` stuck `true`.
  - **Heights:** Min `2.75m` (full board visible with safe margin), Default `3.60m`, Max `5.20m` (wide view of table and mugs).
- **Lighting & Atmosphere:**
  - Table lamp omni-light: Energy `0.65 - 0.9` (prevents overexposed glare on game boards).
  - Candlelight: Subtle warm flicker at `5.5Hz` with sine modulation.
- **Luxury 3D Board-Game Cafe Table Props (`_build_board_game_cafe_props()` in `cafe_table.gd`):**
  - To create an authentic, rich board-game cafe atmosphere without obstructing any game board, `CafeTable` procedurally builds detailed 3D tabletop props strictly outside the central board zone (`radius >= 0.78m`):
    1. **Antique Brass Sand Hourglass** (`Vector3(-0.88, 0, -0.34)`): Carved walnut bases, 3 brass pillars, dual glass bulbs, golden sand cones, and central sand stream.
    2. **Carved Walnut Dice Tray & 2 Ivory/Gold 3D Dice** (`Vector3(0.88, 0, 0.24)`): Octagonal wooden bowl lined with green baize felt and two 3D dice with recessed pips.
    3. **Stacked Leather-Bound Rulebooks & Brass Compass Emblem** (`Vector3(-0.92, 0, 0.28)`): Burgundy and emerald leather books with cream page blocks, gold spine ribs, ribbon bookmark, and brass emblem.
    4. **Traditional Persian Ceramic Plate with Pistachios & Saffron Rock Candy** (`Vector3(0.88, 0, -0.38)`): Glazed turquoise plate with gold rim, pistachio shells, and amber rock candy crystals.
    5. **Vintage Brass Pocket Watch on Chain** (`Vector3(0.62, 0, 0.68)`): Hinged brass case, cream watch face, hands, crown loop, and curved brass chain.
    6. **Stack of Game Tokens / Coasters** (`Vector3(-0.62, 0, -0.68)`): Crimson, sapphire, and obsidian brass-rimmed game tokens.
- **Realistic Hands System (`RealisticHand`) & Per-Game Hand Policy:**
  - In games that use animated 3D hands (such as `Chess`), `PlayerHand` (enters from bottom) and `EnemyHand` (enters from top) place pieces with physical kinematics, with sleeve colors matching the player's role: Crimson Red (`Color(0.85, 0.15, 0.2)`) for P1, Sapphire Blue (`Color(0.15, 0.35, 0.85)`) for P2.
  - **TicTacToe No-Hands & Clean Front-Lip Rule:**
    - `TicTacToe` (`scenes/games/tictactoe/tictactoe_3d.gd`) **MUST NOT** use `PlayerHand` or `EnemyHand`; X and O pieces drop directly onto the board via `ActionVFXManager.animate_piece_drop` with impact particles.
    - Do **NOT** add any `Label3D` text on the front wooden lip under the `TicTacToe` board.

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
| `on_reconnect_data(payload: Dictionary)` | Re-synchronizes board after player reconnects (followed automatically by `hud.sync_reconnect_timer(payload)`). |
| `sync_board_state(board_state: Variant)` | Reconstructs physical pieces from server board array. |
| `reset_board()` | Clears pieces, resets state arrays and variables. |
| `cleanup_board()` | Frees materials, nodes, tweens, and caches on exit. |

### 4.2. 3D Board Craftsmanship & Procedural Material Rule
- **No Stretched 2D UI Background Textures on 3D Boards:**
  - **NEVER** stretch 2D UI background textures (such as `res://assets/images/background/background2.png`) across 3D board `MeshInstance3D` surfaces.
  - Always craft 3D boards using procedural `StandardMaterial3D` luxury finishes: carved royal walnut / mahogany frames (`Color(0.24, 0.12, 0.06)`), dark obsidian / slate playing beds (`Color(0.09, 0.08, 0.11)`), recessed cell wells, brushed imperial gold inlays (`metallic = 0.88, roughness = 0.20`), and clearcoat lacquered or gemstone tokens.
- **3D Typography Readability (`Label3D`):**
  - Any `Label3D` placed on a 3D board (row numbers, secret/guess headers, status badges) MUST use high-contrast colors with thick dark outlines (`outline_size >= 14`) and generous font sizes so text remains crisp in both angled 3D and top-down 2D camera modes.

### 4.3. Input Handling & Race Condition Prevention Rule
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
           show_hint("نوبت شما نیست؛ لطفاً منتظر حرکت حریف بمانید.")
           AudioManager.play_sound("miss_turn")
           return
           
       # 3. Check cell occupancy / move validity
       if board_state[target_idx] != 0:
           show_hint("این خانه قبلاً پر شده است؛ خانه دیگری انتخاب کنید.")
           AudioManager.play_sound("miss_turn")
           return
           
       # 4. Immediately lock board locally to drop subsequent rapid clicks
       set_board_locked(true)
       is_my_turn = false
       last_click_time = Time.get_ticks_msec() / 1000.0
       
       # 5. Dispatch move to server
       send_move(Commands.Select_Peace, target_idx)
   ```

### 4.4. Cache & Memory Cleanup Rule
Whenever a match concludes and the user returns to the lobby or main menu:
- `cafe_table.clear_board()` is called, which executes `cleanup_board()` on the current board node and calls `queue_free()`.
- Boards MUST implement `cleanup_board()` to cleanly kill running tweens, free piece nodes, unlock `cafe_table.camera_drag_locked = false`, and reset internal state arrays.
- Memory from the previous game must NEVER bleed into the next game (e.g. previous board state, piece positions, camera modes, or AFK strikes).

### 4.5. Audio Conventions (`AudioManager`)
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

### 4.6. Smooth 60fps `ScrollContainer` Drag-Scrolling & No-Hover-Ticking Rule
Across all scrollable dialogs and modals (`LobbyDialog` game selector & lobby list, `RulesDialog` game selector, `RankingDialog`, `StoreDialog`, and `ReactionPicker` Kori list):
1. **Pass-Through Mouse Filter:** Every clickable card or button inside a `ScrollContainer` **MUST** set `mouse_filter = Control.MOUSE_FILTER_PASS`.
2. **No Hover Audio or Scale Tweens on Scrollable Cards:** **NEVER** connect `AudioManager.sfx_tap()` or scale `Tween`s to `mouse_entered` / `mouse_exited` on cards inside a `ScrollContainer`. Doing so causes rapid audio ticking and frame lag as cards pass under the finger/cursor during a scroll.
3. **Viewport-Coordinate Drag Tracking Only:** Custom drag-scroll handlers on cards inside a `ScrollContainer` **MUST** use exclusively `InputEventMouseButton` (`MOUSE_BUTTON_LEFT`) and `InputEventMouseMotion` with **viewport coordinates** (`get_viewport().get_mouse_position().y`)—**NEVER** local `event.position.y` (which shifts in the opposite direction whenever `scroll_vertical` moves the card, causing violent frame-by-frame oscillation) and **NEVER** simultaneously binding `InputEventScreenTouch`/`InputEventScreenDrag` alongside `emulate_mouse_from_touch`.

### 4.7. Main Menu Offline Reconnection Rule (`main.gd` & `NetworkManager`)
- When the player is offline (`not NetworkManager.is_online`) and taps **لابی (Lobby)** or **بازی رقابتی (Ranked)** on the main menu—or when launching the app while offline—**NEVER** open `LoginDialog`.
- Instead, check `if not NetworkManager.is_online:` **before** checking `GameManager.is_logged_in`, call `NetworkManager.connect_to_game_server()` (ensuring `_reconnect_timer` is active), and display the reconnection notice (`"🔄 در حال تلاش برای اتصال مجدد به سرور بازی..."`). Once connected, automatically restore the saved user session.

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
- Win conditions, timers, reconnect payload fields, and round count.

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
3. Size footprint: Board width/length between `0.90m` and `1.35m` to rest naturally on the cafe table.
4. Implement procedural luxury physical meshes (warm woods, brass/gold inlays, recessed obsidian cells, clearcoat tokens matching Cafe Fekr aesthetics).
5. Implement physical piece drop, slide, or drag-and-drop animations (locking `cafe_table.camera_drag_locked` during piece dragging).

### Step 4: Wire `BaseGameBoard` Hooks
Implement `setup_board`, `on_turn_changed`, `on_piece_selected`, `on_reconnect_data`, `sync_board_state`, `reset_board`, and `cleanup_board`.

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
| ❌ **No Mismatched Button Colors** | All 8 bottom bar buttons and all game-specific HUD action buttons must use `KenneyUI.COLOR_WOOD` with transparent-background icons. |
| ❌ **No Accidental 2D -> 3D Jumps** | Default view for all games is 2D (`is_top_down_view = true`). Never exit 2D mode on piece/cell tap, mouse motion, single-finger drag, or camera reset; only `BtnCamTop` toggles 2D/3D. |
| ❌ **No Local-Coord Scroll or Hover Ticking** | Never use local `event.position.y` for `ScrollContainer` drag calculations or connect `sfx_tap()` to `mouse_entered` on scrollable cards; always use `get_viewport().get_mouse_position().y`. |
| ❌ **No Login Dialog When Offline** | Never open `LoginDialog` when `not NetworkManager.is_online`; show the reconnecting toast and trigger `connect_to_game_server()`. |
| ❌ **No Duplicate Input Listeners** | Do not bind click handlers to both `Area3D` and `_unhandled_input`. |
| ❌ **No Camera Orbit on Piece Drag** | Always lock `cafe_table.camera_drag_locked = true` while dragging/interacting with board pieces and unlock on mouse release. |
| ❌ **No Reconnect Timer Overwrites** | Never let `update_turn()` or `set_setup_phase()` overwrite the server's remaining timer during reconnect; always let `hud.sync_reconnect_timer(payload)` run last. |
| ❌ **No Duplicate Finish Dialogs** | Maintain `_surrender_handled` and `_result_shown` single-execution guards so `GameResultDialog` never opens twice on surrender or match finish. |
| ❌ **No Hidden Result Panels** | Always ensure `panel.visible = true` in `GameResultDialog.show_result()`. |
| ❌ **No Premature Game Finish** | Never set `is_game_finished = true` inside `stop_timer()`. |
| ❌ **No Endless Heartbeat** | Always call `AudioManager.stop_sound("time")` when a round or match ends. |
| ❌ **No Hardcoded Player Colors** | P1 is always Red, P2 is always Blue. Sleeves and piece highlights must reflect this. |
| ❌ **No 2D UI Textures on 3D Boards** | Never stretch 2D UI background images onto 3D board meshes; use procedural luxury materials and recessed 3D geometry. |
| ❌ **No Unbounded Cameras** | Do not zoom out to show full character models; maintain the cozy table view. |
| ❌ **No Score Boxes in Non-Score Games** | Always hide `ScoreBadge` when `GameRegistry.has_round_score(game_type)` is `false` (e.g. `Chess`, `FekrBekr`). |
| ❌ **No Extra Child Nodes Inside `ScoreBadge`** | Never add extra `Label` children (like `"🏆"`) inside `ScoreBadge` (`PanelContainer`), and always render player scores with `hekayat.ttf` + Persian digits (`_fa_digits`). |
| ❌ **No Stale Final-Round Score on Result Dialog** | Always synchronize the final round score via `_current_round_scored` in `main.gd` before opening `GameResultDialog`. |
| ❌ **No Hands or Front-Lip Text in TicTacToe** | Never trigger 3D hands or add front-frame `Label3D` text on the `TicTacToe` 3D board. |
