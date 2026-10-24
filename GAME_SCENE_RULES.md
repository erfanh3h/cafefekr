# Universal Game Scene & Board Architecture Rules for Cafe Fekr (Godot 4.3+)
> **Version 2.2** | *Updated with Yatzy UI Overhaul, Socket Payload Type Invariants, Cold Reconnect Delivery, Full 11-Game Status Matrix, and Right Vertical Action Panel Architecture Standards.*

---

## 🛡️ CRITICAL MANDATORY DIRECTIVE: ZERO CROSS-GAME REGRESSIONS & STRICT GAME ISOLATION

1. **Absolute Game Isolation:**
   - Every game in Cafe Fekr (`TicTacToe`, `Chess`, `FekrBekr`, `Yatzy`, and all future games) is an **independent module**.
   - When adding, updating, or fixing any game, you are **STRICTLY FORBIDDEN** from modifying or refactoring shared core systems (`GameManager`, `NetworkManager`, `BaseGameHUD`, `CafeTable`, `BaseGameBoard`) in a way that breaks, regresses, or alters the existing behavior of other games.
   - Core autoloads (`autoload/game_manager.gd`, `autoload/network_manager.gd`) and core scenes (`scenes/main.gd`, `scenes/hud/base_game_hud.gd`, `scenes/environment/cafe_table.gd`) serve **ALL** games. Any change to them must be 100% backward-compatible.

2. **No Game-Specific Hacks in Core Autoloads:**
   - Never inject game-specific branch logic (e.g. `if GameManager.current_game_type == ...`) into core autoloads or shared scripts unless strictly coordinating a generic polymorphic hook.
   - Game-specific logic MUST reside inside that game’s own directory: `scenes/games/<game_name>/` or `scripts/games/<game_name>/`.

3. **Polymorphic Hook Requirement:**
   - If a new game requires custom behavior (such as custom header UI, special timers, or unique 3D board mechanics), implement it by **extending base classes** (`BaseGameBoard`, `BaseTopHeader`) or registering callbacks through `GameRegistry`.

4. **Verify Existing Games Before Finalizing:**
   - Whenever any shared code is touched, you must run headless compilation and verify that all previously working games compile and initialize without errors.

---

## ⚠️ THE GOLDEN PRINCIPLE: FLUTTER & BACKEND ARE THE ABSOLUTE SOURCES OF TRUTH

- **NEVER GUESS GAME LOGIC, SERVER COMMANDS, OR PROTOCOL STRUCTURES.**
- Cafe Fekr is a multi-platform ecosystem with an established Python backend (`kafehfekrbackend`) and reference Flutter client (`kafehfekr` / `flutter-code`).
- When implementing, fixing, or porting ANY game:
  1. Inspect the backend session controller: `kafehfekrbackend/Controllers/GameSession/<game>_game_session.py`.
  2. Inspect the backend game logic engine: `kafehfekrbackend/Entities/Games/<game>/`.
  3. Inspect the Flutter client implementation: `flutter-code/lib/Games/<GameName>/`.
  4. Inspect the bot controller: `bots/controllers/<game>_bot_controller.py`.
- If Godot client logic diverges from the backend or Flutter reference, **the Godot client is wrong**. Align Godot with the backend and Flutter code.

---

## 1. Architectural Philosophy

Cafe Fekr delivers an immersive, luxury Parisian board-game cafe experience set in a cozy 3D environment. Players sit at a handcrafted wooden cafe table with emerald green felt (baize), ambient coffee cups, warm lighting, and physical playing pieces.

All games share:
1. **A Single Unified Game Scene (`main.tscn`):** Handles room connections, match orchestrations, and lifecycle events.
2. **A Universal In-Game HUD (`base_game_hud.tscn`):** Displays player cards, timers, scores, chat/kori, camera controls, right vertical action panel, and match states.
3. **A Realistic 3D Table Environment (`cafe_table.tscn`):** Renders the cafe table, lighting, camera rig, and decor.
4. **Pluggable 3D Game Boards (`BaseGameBoard`):** Instantiated dynamically into the table's `BoardSlot` based on `GameRegistry`.

---

## 2. Universal In-Game UI Rules (`BaseGameHUD`)

In Cafe Fekr, **the in-game experience is shared across ALL board games**:

### 2.1. Top Header Architecture, Royal Player Plaques & Score Badges (`TopHeaderSlot`)
- **Royal Player Plaques (`P1Card` & `P2Card`):**
  - Mirrored left and right player cards inside `TopHeaderSlot`:
    - **P1 (Local Player / Red):** Anchored left.
    - **P2 (Opponent / Blue):** Anchored right.
  - Each plaque contains an avatar frame (`AvatarFrame`), player name (`LblName`), a bottom **"شما" / "حریف" pill tag**, and a styled **Role Badge pill** (`"🔴 مهره قرمز"` / `"🔵 مهره آبی"`, `"🔴 ارتش قرمز"` / `"🔵 ارتش آبی"` in Chess, `"🔐 کدشکن"` in FekrBekr, or `"🎲 تاس‌انداز قرمز/آبی"` in Yatzy).
  - Tapping either avatar emits `p1_profile_clicked` / `p2_profile_clicked` to open `UserProfileDialog`.
- **Score Badge Visibility Rule (`GameRegistry.has_round_score`):**
  - In games that do **not** have round scores (e.g. `Chess` and `FekrBekr`, where `GameRegistry.has_round_score(game_type)` is `false`), `ScoreBadge` (`_p1_score_badge` and `_p2_score_badge`) **MUST be hidden** (`visible = false`).
  - In round-based score games (e.g. `TicTacToe`) and cumulative point games (e.g. `Yatzy`), `ScoreBadge` is **visible** (`visible = true`).
  - Score badge numbers MUST use Persian digits via `_fa_digits(score)` and `hekayat.ttf`.
  - Never add redundant child labels (like `"🏆"`) inside `ScoreBadge`.
- **No Floating Center Sword / VS Icon:**
  - Do **NOT** spawn any floating `⚔️` / VS emblem between `P1Card` and `P2Card`; it stacks over the pre-game `StartGameOverlay` dialog and clutters the top header.
- **Game-Specific Header Specialization Rule:**
  - When a game has extra header requirements (e.g. `ChessTopHeader`, `YatzyTopHeader`), it **MUST inherit from `BaseTopHeader`**.
  - Declare the scene inheritance in Godot (`scenes/games/<game>/<game>_top_header.tscn` inheriting `base_top_header.tscn`).
  - Register the scene in `GameRegistry` under `"top_header_scene"`.
  - Do NOT modify the base header to hardcode one game's features; use the inheritance pattern.

### 2.2. Compact 2-Row Match Details Box (`MatchDetailsBox`) & Real-Time Timer Bar VFX
Located directly beneath the player cards at the top center:
- **Geometry & Structure:**
  - `MatchDetailsBox` is anchored horizontally centered (`anchor_left = 0.5, anchor_right = 0.5`, `offset_left = -264.0, offset_right = 264.0`, width `528px`, `offset_top = 136.0, offset_bottom = 236.0`, height `100px`).
  - Features an ornate wood frame with warm walnut gradient fill and thin inner gold border.
  - Divided strictly into **two rows**:
    1. **Row 1 (`StatusRow`):**
       - **Turn / Phase Label (`LblTurnStatus`):** Concise Persian status text (`font_size = 28`):
         - Pre-game waiting state: `"بازی درحال آغاز است"` (`Color(1.0, 0.88, 0.45)`).
         - My turn: `"🔴 نوبت شماست (قرمز)"` / `"🔵 نوبت شماست (آبی)"`.
         - Opponent turn: `"⏳ نوبت <نام حریف>"`.
         - Simultaneous turn (e.g. Yatzy): `"🎲 نوبت پرتاب تاس و انتخاب خانه"`.
       - **Timer Pill (`TimerRow` / `LblTimer`):** Stopwatch icon (`time.png`) + remaining time pill `"۱۰ ثانیه"` (`font_size = 26`) using Persian digits (`_fa_digits`).
    2. **Row 2 (`TurnTimerBar`):** Full-width recessed capsule bar (`504 × 22 px`, `corner_radius = 11`) with `TimerBarVFXOverlay`.
- **Real-Time Procedural Timer Bar VFX (`TimerBarVFXOverlay`):**
  - `TurnTimerBar` hosts a custom `Control` overlay (`TimerBarVFXOverlay`) that renders 60fps procedural VFX in `_draw()`:
    - **Normal Turn State (`remaining_sec > 4.0s`):**
      - Smooth traveling energy shimmer bands sweeping across the filled portion of the bar.
      - Glowing leading-edge comet/fuse head at the bar tip with a rotating 4-ray star flare and gentle floating sparkles tinted to the active player's color (Red for P1, Blue for P2, Gold for simultaneous).
    - **Critical Finishing State (`remaining_sec <= 4.0s`):**
      - High-intensity fiery gold/crimson ember bursts (3× particle spawn rate) and expanding shockwave rings (`trigger_danger_shockwave()`) on each final second tick.
      - Pulsing neon danger aura around the bar, urgent red fill (`Color(1.0, 0.24, 0.26)`), ringing stopwatch icon oscillation, scale pulse on `LblTimer`, and audio heartbeat ticking (`AudioManager.play_sound("time")`).

### 2.3. Bottom Action Bar (`BottomBar`) — Unified Wood & White Icon Rule
Contains **7 core buttons** arranged horizontally at the bottom of the screen:
- **Unified Background Color (`KenneyUI.COLOR_WOOD`):**
  - Because `res://assets/images/frames/button.png` is a rich warm orange-brown wood texture (`RGB ≈ 115, 48, 28`), multiplying it by low-red tints crushes the red channel and turns buttons into dark muddy charcoal.
  - Therefore, **all 7 buttons in `BottomBar`** **MUST** use `KenneyUI.COLOR_WOOD` so that every button on the HUD shares the exact same warm wood background color.
- **Pure White-on-Transparent Icon Asset Rule:**
  - Every icon placed inside a HUD button (`zoom_in_white.png`, `zoom_out_white.png`, `refresh.png`, `flag_surrender_white.png`, `kori.png`, `soundOn_white.png`, `soundOff_white.png`) **MUST** be a crisp white foreground (`RGB = 255, 255, 255`) on a **100% transparent background (`alpha = 0`)**.
- **Left Group (Camera & View Controls):**
  1. `BtnZoomIn`: Zoom In (`zoom_in_white.png`)
  2. `BtnZoomOut`: Zoom Out (`zoom_out_white.png`)
  3. `BtnCameraReset`: Camera Angle Reset (`refresh.png`)
- **Center Action Button:**
  4. `BtnSurrender`: Surrender / Resign match button (`flag_surrender_white.png`). Opens confirmation dialog.
- **Right Group (Social & Audio):**
  5. `BtnChat`: In-game quick chat messages.
  6. `BtnReactions`: Kori / Emoji picker button (`kori.png`). Opens reaction grid.
  7. `BtnAudio`: White sound toggle (`soundOn_white.png` / `soundOff_white.png`). Toggles SFX & Music.

### 2.4. Right Vertical Action Panel (`RightActionPanel` / `GameSpecificActions`) — Architecture Rules
The Right Action Panel is a dedicated HUD slot located on the **right-center edge of the screen** (`anchor_left = 1.0, anchor_right = 1.0, anchor_top = 0.5, anchor_bottom = 0.5`, `offset_left = -128.0, offset_right = -24.0`, width `104px`, `offset_top = -240.0, offset_bottom = 240.0`):

1. **Separation of Concerns: 2D HUD Right Panel vs. 3D In-World Physical Buttons**:
   - **Use the 2D Right Panel** for:
     - **Board-wide meta-actions and phase transitions**: Actions that apply to the whole board or phase state, such as submitting a full secret code or guess in `FekrBekr` (`BtnFekrSubmit`).
     - **Board clearing / reset tools**: Actions that wipe local draft placements (`BtnFekrClear`).
     - **Camera view switches & inspection modes**: Dedicated board view toggles that change what the camera frames (e.g. `BtnFekrOpponent` to view opponent vault, `BtnFekrDual` to view both boards side-by-side).
     - **Administrative & helper tools**: Note-taking, draft markers, or game-wide toggles.
   - **Do NOT use the 2D Right Panel** when:
     - The game has direct **tactile in-world 3D physical buttons** on the wooden board itself (e.g. `Yatzy` uses physical 3D pushbuttons `BtnRollDice` and `BtnSubmitScore` carved directly into the dice arena plinth; `Chess` uses tactile promotion dials on the board).
     - For games without game-wide meta actions (e.g. `TicTacToe`, `Chess`, `Yatzy`), the Right Panel **MUST remain completely hidden** (`visible = false`) to maintain a clean, distraction-free viewport.
2. **Universal Visual & Styling Standards**:
   - **Button Size & Spacing**: Buttons are `96 × 96 px` (`custom_minimum_size = Vector2(96, 96)`) with `16px` vertical separation in a `VBoxContainer`.
   - **Wood Texture**: Every button **MUST** be styled with `KenneyUI.style_button(btn, KenneyUI.COLOR_WOOD)`, matching the bottom bar and top cards.
   - **Vector Pure White Icons**: Use vector-style pure white-on-transparent icons scaled to `52 × 52 px` centered inside the button (`expand = true, stretch_mode = KEEP_CENTERED`). Never use colored badges or non-transparent backgrounds; only the clean icon renders.
   - **Touch Juice**: Buttons MUST have pivot set to center (`btn.pivot_offset = btn.custom_minimum_size / 2.0`) and receive `ActionVFXManager.apply_button_juice(btn, "tap_button")` for responsive scale bouncing on press.
3. **Safety Guards & Disconnect State**:
   - Tapping any right panel action button MUST verify `GameManager.is_game_active` and verify that the board is not locked (`not board.is_board_locked`).
   - If pressed while the match is not active or paused, it must trigger audio rejection (`AudioManager.sfx_button()`) and display a toast hint (`"لطفاً تا شروع مسابقه صبر کنید..."`).
4. **Extensibility for Upcoming Games**:
   - When introducing new games that require meta-actions (e.g., `Backgammon` doubling cube / roll requests, `Checkers` multi-jump undo, `Battleship` fleet deployment toggles), add the button group to `BaseGameHUD` under `RightActionPanel` or provide a modular container that toggles visibility based on `GameManager.current_game_type`.

### 2.5. Floating Toast Notification (`ToastHint`)
Used for quick feedback messages (e.g. `"نوبت شما نیست؛ لطفاً منتظر حرکت حریف بمانید."`, `"این خانه قبلاً پر شده است؛ خانه دیگری انتخاب کنید."`, `"زاویه دوربین به حالت پیش‌فرض بازگشت"`, `"آغاز راند ۲ — آماده باشید!"`):
- **Position:** Anchored at **bottom-center** (`anchor_left = 0.5, anchor_right = 0.5, anchor_top = 1.0, anchor_bottom = 1.0`).
- **Offsets:** Symmetrically centered (`offset_left = -half_w, offset_right = half_w`, `offset_top = -240.0, offset_bottom = -165.0`).
- **Typography:** `font_size = 32`, centered alignment, golden font color with drop shadow.
- **Animation:** Chained Tween pop-in (`scale 0.85 -> 1.0`), 2.2s visible display, and smooth fade-out.
- **Implementation Note:** Never call `toast_hint.reset_size()` directly without resetting symmetric offsets, or the box will shift horizontally!

### 2.6. Disconnect Pause Dialog (`DisconnectPauseDialog`) & Reconnect Timer Synchronization
Matches Flutter's `DialogComponent().showTimerDialog` and backend `UserDisconnectTimerClass`:
- **Trigger (`Commands.User_Disconnected`):** Server sends `{"user_id": ..., "time": 45}`.
- **Pause Behavior:**
  - `hud.pause_turn_timer()` MUST be called so `turn_time_left` freezes while the match is paused, and board input is locked (`board.set_board_locked(true)`).
  - Dialog opens with blurred dark dimmer, displaying:
    - Title: `"⏸️ وقفه در مسابقه — قطع اتصال حریف"`
    - Description: `"ارتباط حریف با سرور موقتاً قطع شده است.
لطفاً شکیبا باشید؛ در صورت عدم بازگشت در مهلت مقرر، پیروزی این مسابقه برای شما ثبت خواهد شد."`
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

### 2.7. Final Round Score Synchronization, Surrender & Match Result Dialog (`GameResultDialog`)
- **Final Round Score Synchronization Rule (`_current_round_scored` in `main.gd`):**
  - In round-based games (such as `TicTacToe`), when the final match-clinching round finishes (e.g., making the match `3 - 0`), the backend server may emit `Commands.Finish_Game` directly or emit `Commands.Finish_Game` **before** `Commands.Finish_Round`.
  - `main.gd` **MUST** track `_current_round_scored: bool` (reset to `false` in `_start_game_match()`, `_on_new_round_started()`, and `_on_turn_changed()`).
  - In both `_on_round_finished(payload)` and `_on_game_finished(data)`:
    - If `GameRegistry.has_round_score(GameManager.current_game_type)` and `not GameRegistry.is_cumulative_score(GameManager.current_game_type)` and `not _current_round_scored` (and the match was not ended by surrender or disconnect timeout), set `_current_round_scored = true`, increment `GameManager.p1_score` (if `winner == 1`) or `GameManager.p2_score` (if `winner == 2`), and call `base_game_hud.update_scores(GameManager.p1_score, GameManager.p2_score)` **BEFORE** calling `base_game_hud.show_game_result(...)`.
    - This guarantees the finished dialog always displays the true final score (e.g., `۳ - ۰` instead of `۲ - ۰`) and never double-increments if both `Finish_Round` and `Finish_Game` arrive for the final round.
  - In cumulative point games (such as `Yatzy`), scores are server-authoritative cumulative sums (`GameRegistry.is_cumulative_score = true`); they MUST NEVER receive the `+1` increment on match finish, and `GameResultDialog` displays `"مجموع امتیاز: %s" % _fa_digits(score)`.
- **Surrender Confirmation:**
  - Clicking `BtnSurrender` opens a confirmation modal (`"آیا از ادامه مسابقه انصراف می‌دهید؟
با اعلام تسلیم، نتیجه این بازی به سود حریف ثبت خواهد شد."`).
  - Confirming sends `Commands.Surrender` to backend and locks the board immediately.
  - The confirmation modal is hidden immediately with `visible = false` and `mouse_filter = IGNORE`.
- **Single-Execution Idempotency Guard (Preventing Double Finish Dialogs):**
  - When a player surrenders, the backend emits `Commands.Surrender` followed by `Commands.Finish_Game` (and in some backend sessions `Finish_Game` is emitted twice due to `timer.stop()` + `check_finish_game()`). Meanwhile, the local client also triggers a 1.15s surrender transition tween.
  - `BaseGameHUD` MUST maintain `_surrender_handled: bool`, `_result_shown: bool`, and `_surrender_result_tween: Tween` (all reset in `setup_match()`):
    - When `_on_player_surrendered` executes, `_surrender_handled = true`.
    - When `show_game_result()` executes, `_result_shown = true`.
    - Any subsequent call while either flag is `true` is safely discarded, preventing flickering duplicate dialogs.

---

## 3. 3D Cafe Environment & Camera Rules (`CafeTable`)

- **Table Surface & Spatial Allocation**:
  - The emerald baize table arena measures `1.84m × 1.94m`.
  - Central board area: `X ∈ [-0.55, +0.55]`, `Z ∈ [-0.85, +0.85]`.
  - Board origin MUST be at `Vector3(0, 0, 0)` with the playing surface elevation at `Y = 0.0` or slightly above.
- **Default Camera Rig Positioning:**
  - `CameraGimbal` position: `Vector3(0, 0, 0)`.
  - Standard distance: `3.20m` to `3.38m` (optimized for 1080×1920 portrait mobile screen).
  - Default elevation angle (pitch): `-0.73` to `-1.16` radians (~42° to ~66° downward tilt).
  - Orbit limits: Yaw `[-0.45, +0.45]` rad, Pitch `[-1.25, -0.40]` rad, Distance `[2.10m, 4.20m]`.
- **Cozy Tabletop Props (Decorative Only):**
  1. **Hot Ceramic Coffee Cup** (`Vector3(-0.68, 0, 0.48)`): Porcelain cup with dark espresso, saucer, and rising steam particles.
  2. **Silver Coffee Spoon** (`Vector3(-0.76, 0, 0.52)`): Resting beside the saucer.
  3. **Pastry Plate with Croissant** (`Vector3(-0.65, 0, -0.45)`): Flaky croissant on a porcelain plate.
  4. **Glass Cafe Lamp** (`Vector3(0.68, 0, -0.45)`): Warm amber glow (`light_color = Color(1.0, 0.85, 0.58)`).
  5. **Vintage Brass Pocket Watch on Chain** (`Vector3(0.62, 0, 0.68)`): Hinged brass case, cream watch face, hands, crown loop, and curved brass chain.
  6. **Stack of Game Tokens / Coasters** (`Vector3(-0.62, 0, -0.68)`): Crimson, sapphire, and obsidian brass-rimmed game tokens.
- **Realistic Hands System (`RealisticHand`) & Per-Game Hand Policy:**
  - In games that use animated 3D hands (such as `Chess`), `PlayerHand` (enters from bottom) and `EnemyHand` (enters from top) place pieces with physical kinematics, with sleeve colors matching the player's role: Crimson Red (`Color(0.85, 0.15, 0.2)`) for P1, Sapphire Blue (`Color(0.15, 0.35, 0.85)`) for P2.
  - **No-Hands Policy for Physical Particle & Die Rolling Games:**
    - `TicTacToe` and `Yatzy` **MUST NOT** use `PlayerHand` or `EnemyHand`. In `TicTacToe`, pieces drop from the sky with physics bounce. In `Yatzy`, dice tumble through aerodynamic tumbling tweens in the center arena.
    - Do **NOT** add any `Label3D` text on the front wooden lip under game boards.

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
  - **NEVER** stretch 2D UI background textures across 3D board `MeshInstance3D` surfaces.
  - Always craft 3D boards using procedural `StandardMaterial3D` luxury finishes: carved royal walnut / mahogany frames (`Color(0.24, 0.12, 0.06)`), dark obsidian / slate playing beds (`Color(0.09, 0.08, 0.11)`), recessed cell wells, brushed imperial gold inlays (`metallic = 0.88, roughness = 0.20`), and clearcoat lacquered or gemstone tokens.
- **3D Typography Readability (`Label3D`):**
  - Any `Label3D` placed on a 3D board MUST use high-contrast colors with thick dark outlines (`outline_size >= 14`) and generous font sizes so text remains crisp in both angled 3D and top-down 2D camera modes.

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

---

## 5. Comprehensive Game Status Matrix

| Game ID | Persian Title | Mechanism | Max Rounds | Scoring Mode | Turn Time | Top Header | 3D Board Footprint & Camera | Right Panel | 3D Hands | Bot Support | Implementation Status |
| :--- | :--- | :--- | :---: | :--- | :---: | :--- | :--- | :---: | :---: | :---: | :--- |
| `TicTacToe` | دوز | Turn-Based | 5 | Round Wins (3-pt target) | 20s | `BaseTopHeader` | Square (`0.90 × 0.90m`)<br>Dist: `3.20m`, Pitch: `-0.73` | Hidden | Disabled | Level 1-3<br>`run_tictactoe.bat` | ✅ **Production Ready** |
| `Chess` | شطرنج | Turn-Based | 1 | Match Win/Loss | 60s | `ChessTopHeader`<br>(AFK Strikes) | Square (`1.08 × 1.08m`)<br>Dist: `3.20m`, Pitch: `-0.73` | Hidden | Enabled | Stockfish / Custom<br>`run_chess.bat` | ✅ **Production Ready** |
| `FekrBekr` | فکر و بکر | Multi-Phase Simultaneous | 12 | Guess Count / Match Win | 60s (P2)<br>45s (P1) | `FekrBekrTopHeader`<br>(Dual Boards) | Portrait Rect (`0.76 × 1.80m`)<br>Dist: `3.38m`, Pitch: `-1.16` | **Active**<br>(Submit, Clear, Opponent, Dual) | Disabled | Level 1-3<br>`run_fekrbekr.bat` | ✅ **Production Ready** |
| `Yatzy` | پنج تاس (یاتزی) | Simultaneous Multi-Roll | 12 | Cumulative Points (12 Categories) | 60s | `YatzyTopHeader`<br>(Scores & Rolls) | Portrait Rect (`1.06 × 1.68m`)<br>Dist: `3.28m`, Pitch: `-1.14` | Hidden<br>(Tactile 3D Buttons) | Disabled | Level 1-3<br>`run_yatzy.bat` | ✅ **Production Ready** |
| `Checkers` | دامه (چکرز) | Turn-Based | 1 | Match Win/Loss | 30s | `BaseTopHeader` | Square (`1.08 × 1.08m`) | Hidden | Enabled | Planned | ⏳ Architecture Ready |
| `Backgammon` | تخته نرد | Turn-Based | 1-5 | Pip / Bear-off Points | 45s | Custom Header<br>(Pips & Dices) | Rectangular Case (`1.15 × 0.95m`) | Optional<br>(Doubling Cube) | Enabled | Planned | ⏳ Architecture Ready |
| `FourInARow` | چهار در یک خط | Turn-Based | 5 | Round Wins | 20s | `BaseTopHeader` | Vertical Grid (`0.85 × 0.85m`) | Hidden | Disabled | Planned | ⏳ Architecture Ready |
| `Othello` | اتللو (ریورسی) | Turn-Based | 1 | Disc Count Sum | 30s | `BaseTopHeader` | Square (`0.95 × 0.95m`) | Hidden | Enabled | Planned | ⏳ Architecture Ready |
| `Mill` | دوز دوازده تایی | Turn-Based | 3 | Round Wins | 30s | `BaseTopHeader` | Concentric Squares (`0.90 × 0.90m`) | Hidden | Enabled | Planned | ⏳ Architecture Ready |
| `DotBox` | نقطه خط | Turn-Based | 1 | Box Count Sum | 25s | `BaseTopHeader` | Lattice Grid (`0.85 × 0.85m`) | Hidden | Disabled | Planned | ⏳ Architecture Ready |
| `Battleship` | نبرد دریایی | Simultaneous / Alternating | 1 | Fleet Elimination | 30s | Custom Dual Header | Dual Radar Grids (`1.10 × 0.90m`) | Active<br>(Fleet Setup / Fire) | Disabled | Planned | ⏳ Architecture Ready |

---

## 6. Step-by-Step Guide: Porting a New Game to Cafe Fekr

Whenever you are tasked with adding a new game (e.g. Checkers, Backgammon, Four-in-a-Row, Othello, Mill, etc.):

### Step 0: Study the Flutter & Backend References
Before writing any Godot code, open and read:
1. `flutter-code/lib/Games/<GameName>/Controllers/<game>_controller.dart`
2. `flutter-code/lib/Games/<GameName>/Models/`
3. `kafehfekrbackend/Controllers/GameSession/<game>_game_session.py`
4. `kafehfekrbackend/Entities/Games/<game>/`
5. `bots/controllers/<game>_bot_controller.py`

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

## 7. Architectural Hardening & Lessons Learned From Recent Fixes

### 7.1. Yatzy 3D Board UI Upgrades & Rectangular Camera Ratio
- **Portrait Rectangular Footprint (`1.06m × 1.68m`)**: In vertical 1080×1920 mobile viewport, a square board squashes rows and leaves excessive empty table baize. Reshaping to `1.06m × 1.68m` provides `0.146m` vertical height per row (50% more room), allowing generous spacing for large score plaques, 3D emblems, and dice wells.
- **3D Sculpted Category Emblems (`_build_3d_category_emblem`)**: Never map 2D icon textures onto flat planes in 3D. Use real 3D miniature beveled dice tiles with colored 3D pips for single numbers (1–6) and 3D miniature geometric sculptures (cube clusters, faceted crystals, crowns) for combo categories on raised golden medallion pedestals.
- **Typography & Bounding Frame Integrity**: All category text labels must fit strictly inside their card compartment (`get_aabb().size.x <= compartment_width`). Use balanced `pixel_size = 0.00125` and font sizes (`21..24`) with an internal brass dividing strip separating text from the 3D emblem.
- **Precision-Molded 3D Dice**: Dice faces must use flush, precision-spaced enamel cylinder pips with generous margins to avoid blobby overlapping sphere bezels. Under each die well, provide a framed 3D numeral badge displaying the Persian digit and glowing gold when held.

### 7.2. Strict Socket Payload Type Compliance (`SelectPeace`)
- Never assume a command takes a primitive integer or string. In `Yatzy`, the server (`YatzyGameClass.recieve_data`) explicitly requires:
  ```python
  if command_id == commands.Select_Peace:
      user_selected_index = data["index"]
  ```
  Sending raw integer `8` causes `TypeError: 'int' object is not subscriptable`.
- Always inspect Flutter (`sendCommand({"id": GameCommands.selectPeace, "data": {"index": equippedIndex}})`) and backend session code. Ensure Godot sends `send_move(Commands.Select_Peace, {"index": equipped_index})`.

### 7.3. Autoload Invariant Hardening (No Ghost Properties or Signals)
- Never call signals or properties that do not exist on `GameManager` (e.g. `scores_updated`, `p1_name`, `p2_name`).
- Doing so causes GDScript runtime exceptions that abort execution silently, preventing subsequent lines (such as `hud.update_scores` and `_refresh_visuals`) from executing.
- Always use `GameManager.get_opponent_player_data().get("name", ...)` for opponent names, and rely on `scores_updated` on HUD or direct `hud.update_scores()`.

### 7.4. Server-Authoritative Score Synchronization
- For cumulative score games like `Yatzy`, scores are updated continuously during the round as `Peace_Selected` events arrive.
- Update `GameManager.p1_score` and `GameManager.p2_score` immediately inside `NetworkManager` on both `Peace_Selected` and `Reconnect_Data`, and notify `BaseGameHUD.update_scores()` without waiting for round finish.

### 7.5. Cold-Start Reconnection Board State Delivery
- If a user returns to an ongoing match from the main menu, `main.gd` initially spawns the default game board before `Reconnect_Data` arrives.
- When `Reconnect_Data` arrives, `main._on_reconnect_data_received(payload)` detects `inferred_type` and calls `_switch_active_game(inferred_type)`.
- **CRITICAL**: Because the new board is instantiated *after* `NetworkManager.reconnect_data_received` has already fired, `main.gd` **MUST** explicitly invoke `board.on_reconnect_data(payload)` on the newly switched board node to deliver the server state immediately.

### 7.6. Responsive Board State Visual Refresh Hooks
- Every board implementation inheriting from `BaseGameBoard` MUST implement:
  - `on_turn_changed(turn: int, is_me: bool)` -> calls `_refresh_visuals()`
  - `set_board_locked(locked: bool)` -> calls `_refresh_visuals()`
- This guarantees that when `User_Reconnected` arrives or `sync_turn_state()` runs, the board visuals update instantly without requiring the user to tap a piece or die first.

---

## 8. Checklist & Prohibitions

| Item | Rule |
| :--- | :--- |
| ❌ **No Cross-Game Regressions** | Never alter core shared code in a way that breaks, regresses, or alters behavior for existing games. |
| ❌ **No Game Hacks in Shared Systems** | Game-specific mechanics must live in the inherited board/header, not inside `GameManager` or `BaseGameBoard`. |
| ❌ **No Tight Coupling** | All games must be fully separate and pluggable through `GameRegistry` and standard `BaseGameBoard` lifecycle hooks. |
| ❌ **No Guessing Logics** | Never guess game rules; port them directly from `flutter-code` and `kafehfekrbackend`. |
| ❌ **No Custom HUDs** | Never build a standalone HUD per game. Always use `BaseGameHUD`. |
| ❌ **No Mismatched Button Colors** | All 7 bottom bar buttons and all right panel action buttons must use `KenneyUI.COLOR_WOOD` with pure white-on-transparent icons. |
| ❌ **Right Panel Exclusivity** | Only use the 2D Right Panel for game-wide meta-actions (FekrBekr). Hide it completely for standard piece games (TicTacToe, Chess, Yatzy). |
| ❌ **No Duplicate Input Listeners** | Do not bind click handlers to both `Area3D` and `_unhandled_input`. |
| ❌ **No Camera Orbit on Piece Drag** | Always lock `cafe_table.camera_drag_locked = true` while dragging/interacting with board pieces and unlock on mouse release. |
| ❌ **No Reconnect Timer Overwrites** | Never let `update_turn()` or `set_setup_phase()` overwrite the server's remaining timer during reconnect; always let `hud.sync_reconnect_timer(payload)` run last. |
| ❌ **No Duplicate Finish Dialogs** | Maintain `_surrender_handled` and `_result_shown` single-execution guards so `GameResultDialog` never opens twice on surrender or match finish. |
| ❌ **No Premature Game Finish** | Never set `is_game_finished = true` inside `stop_timer()`. |
| ❌ **No Endless Heartbeat** | Always call `AudioManager.stop_sound("time")` when a round or match ends. |
| ❌ **No Score Boxes in Non-Score Games** | Always hide `ScoreBadge` when `GameRegistry.has_round_score(game_type)` is `false` (e.g. `Chess`, `FekrBekr`). |
| ❌ **No Extra Child Nodes Inside `ScoreBadge`** | Never add extra `Label` children inside `ScoreBadge` (`PanelContainer`), and always render player scores with `hekayat.ttf` + Persian digits (`_fa_digits`). |
| ❌ **No Stale Final-Round Score on Result Dialog** | Always synchronize the final round score via `_current_round_scored` in `main.gd` before opening `GameResultDialog`. |
| ❌ **No Increment on Cumulative Scores** | Never apply `+1` round increment to cumulative score games (`Yatzy`) on `Finish_Game`; preserve server total points. |
| ❌ **No Missing Reconnect Delivery** | Always deliver `board.on_reconnect_data(payload)` when `_switch_active_game()` occurs on cold-start reconnect. |
| ❌ **No Hands in Incompatible Games** | Never trigger 3D hands in games without physical piece pickup animations (`TicTacToe`, `Yatzy`). |
