# Cafe Fekr — Godot 4 Client (`cafefekr`)

The **primary client application** for **Cafe Fekr (کافه فکر)** — an online, Persian-language collection of **25 board games** played within a shared, luxury 3D "Royal Persian Cafe" table experience.

Built with **Godot 4.7** using **GDScript**, this mobile-first portrait application communicates with the companion Python REST server (`kafehfekrserver` on port `5001`) and the realtime Socket.IO game server (`kafehfekrbackend` on port `5000`). It features active competitive matches, a full-featured social & clan hub, and a complete **Live Spectator Mode** with game discovery and read-only 3D board viewing.

---

## 1. High-Level Summary

| Property | Value |
|---|---|
| **Engine / Language** | Godot 4.7 (Mobile renderer / D3D12), GDScript |
| **Orientation & Resolution** | Portrait (1080 × 1920 base, 540 × 960 window override, `canvas_items/expand`) |
| **Target Platforms** | Android (APK, arm64-v8a / armeabi-v7a / x86_64), Windows Desktop |
| **Version** | `2.0.0` (Client-side force-update check via `allowed_version`) |
| **Persian Typography** | `res://assets/fonts/Vazir.ttf` (UI standard) & `res://assets/fonts/hekayat.ttf` (In-game 3D & score typography) |
| **Networking** | REST HTTP (`APIClient`) + Custom WebSocket Socket.IO v4 client (`SocketIOClient`) |
| **Active Games** | 25 distinct 3D board game scenes inheriting from `BaseGameBoard` |
| **Live Spectator System** | Full spectator browser (`LiveGamesDialog`), in-game overlay (`SpectatorOverlay`), and read-only board sync |
| **Core Directive** | **Zero Cross-Game Regressions** & Strict Game Isolation (see `GAME_SCENE_RULES.md`) |

---

## 2. System Architecture

The client follows a decoupled singleton-and-scene architecture:

```
+----------------------------------------------------------------------------------------------------+
|                                    APPLICATION ROOT (main.tscn)                                    |
|                                                                                                    |
|  +----------------------------------------------------+  +--------------------------------------+  |
|  |                 AUTOLOAD SINGLETONS                |  |           3D ENVIRONMENT             |  |
|  |                                                    |  |  (scenes/environment/cafe_table.tscn)|  |
|  |  - GameManager (Session, Level/XP, Match & Spectate|  |                                      |  |
|  |  - NetworkManager (Socket.IO + REST Dispatcher)   |  |  - Damped Orbit / Zoom Camera        |  |
|  |  - AudioManager (Music, Ambience, SFX)            |  |  - Strict 2D Top-Down View Toggle    |  |
|  |  - ActionVFXManager (Procedural Particle FX)       |  |  - Authentic Table Props & Lighting  |  |
|  +----------------------------------------------------+  |  - BoardContainer                    |  |
|                                                          |       \--> [Active Game Board 3D]    |  |
|                                                          +--------------------------------------+  |
|                                                                                                    |
|  +----------------------------------------------------------------------------------------------+  |
|  |                                      2D CANVAS UI LAYER                                      |  |
|  |                                                                                              |  |
|  |  +---------------------------------------+      +-----------------------------------------+  |  |
|  |  |           MAIN MENU & DOCK            |      |            IN-GAME HUD (HUD)            |  |  |
|  |  |                                       |      |  (scenes/games/base/base_game_hud.tscn) |  |  |
|  |  | - UserHeader (Coins, Level, Avatar)   |      |                                         |  |  |
|  |  | - Mode Cards (Rank, Classic, Lobby)   |      |  - TopHeaderSlot (Player Plaques)       |  |  |
|  |  | - Watch Live Button (Live Matches)    |      |  - MatchDetailsBox (Turn/Timer Bar VFX) |  |  |
|  |  | - Bottom Dock (Ranking, History, etc.)|      |  - ToastHint (Floating Notifications)   |  |  |
|  |  +---------------------------------------+      |  - BottomBar (8 Wood Action Buttons)    |  |  |
|  |                                                 |  - Dialogs (Countdown, Disconnect Pause)|  |  |
|  |  +---------------------------------------+      |  - GameResultDialog (Victory/Defeat)    |  |  |
|  |  |           MODAL DIALOGS               |      +-----------------------------------------+  |  |
|  |  |                                       |                                                   |  |
|  |  | - LoginDialog, QueueDialog, PickBan   |      +-----------------------------------------+  |  |
|  |  | - SocialDialog (Friends, Clans, Chat) |      |          SPECTATOR OVERLAY              |  |  |
|  |  | - LiveGamesDialog (Spectator Browser) |      | (scenes/ui/spectator/spectator_overlay) |  |  |
|  |  | - UserProfileDialog, Store, Rules     |      |  - Viewer Count Pill (👁️ %d تماشاگر)   |  |  |
|  |  +---------------------------------------+      |  - Exit Button ("ترک تماشا")            |  |  |
|  |                                                 +-----------------------------------------+  |  |
|  +----------------------------------------------------------------------------------------------+  |
+----------------------------------------------------------------------------------------------------+
```

---

## 3. Directory Structure

```
cafefekr/
├── project.godot               # Godot 4.7 engine configuration file (warnings calibrated)
├── export_presets.cfg          # Android & Windows export build configurations
├── GAME_SCENE_RULES.md         # 68 KB mandatory engineering rules & standards document
├── icon.svg                    # Application icon
│
├── android/                    # Android build template & gradle assets
│
├── assets/                     # Media, audio, textures, and fonts
│   ├── audio/                  # SFX (piece taps, wins, losses, timer ticks) & music
│   ├── fonts/                  # Persian TTF fonts (Vazir.ttf, hekayat.ttf)
│   ├── icons/                  # 100% transparent vector and PNG UI icons
│   └── images/                 # Textured buttons, badges, frames, and game cards
│
├── autoload/                   # Global singleton managers (autoload order matters)
│   ├── game_manager.gd         # Session persistence, Level/XP curve, match & spectator state
│   ├── network_manager.gd      # High-level network manager and command signal hub (~80 signals)
│   ├── audio_manager.gd        # Sound effects and soundtrack audio player
│   └── action_vfx_manager.gd   # Procedural particle and juice effects
│
├── scenes/                     # Scene tree
│   ├── environment/            # Shared 3D cafe table and camera
│   │   ├── cafe_table.tscn
│   │   └── cafe_table.gd       # Orbit/zoom camera, props, 2D top-down mode
│   │
│   ├── games/                  # 25 Game board scenes + shared base scenes
│   │   ├── base/               # Unified in-game HUD and top headers
│   │   │   ├── base_game_hud.tscn / .gd    # Shared 2D in-game HUD
│   │   │   └── base_top_header.tscn / .gd  # Shared player plaques & scores
│   │   ├── monopoly/           # Monopoly 3D board & specialized header
│   │   ├── risk/               # Risk Strike 3D board & header
│   │   ├── ludo/               # Ludo 3D board & 4-player header
│   │   ├── chess/              # Chess 3D board & missed-turn header
│   │   ├── fekrbekr/           # Mastermind (FekrBekr) 3D board & dual header
│   │   ├── yatzy/              # Yatzy 3D board & score sheet header
│   │   ├── battleship/         # Battleship 3D board & dual radar header
│   │   └── ...                 # 18 additional individual 3D game scenes
│   │
│   ├── main/                   # Root scene
│   │   ├── main.tscn           # Application entry point
│   │   └── main.gd             # Master coordinator (match lifecycle, spectator flow)
│   │
│   └── ui/                     # Application dialogs & menus
│       ├── auth/               # LoginDialog (Phone SMS OTP login)
│       ├── classic_rank/       # ClassicRankDialog (Bot match selector)
│       ├── header/             # UserHeader (Top player info bar)
│       ├── history/            # GameHistoryDialog (Match history records)
│       ├── lobby/              # LobbyDialog (Custom rooms create/join)
│       ├── multi_rank/         # MultiRankDialog (3-player queue)
│       ├── profile/            # UserProfileDialog (Personalization, stats, spectator privacy)
│       ├── queue/              # QueueDialog (Ranked queue & acceptance)
│       ├── rank/               # PickBanDialog (7-turn draft) & RankedBreakoutDialog
│       ├── ranking/            # RankingDialog (Global leaderboards)
│       ├── rules/              # RulesDialog (Game instructions viewer)
│       ├── social/             # SocialDialog (Friends, Clans, DMs, Notifications)
│       ├── spectator/          # Live Spectator UI components
│       │   ├── live_games_dialog.gd # Match discovery browser modal
│       │   └── spectator_overlay.gd # In-game live spectator HUD
│       └── store/              # StoreDialog (Coin store & IAP)
│
├── scripts/                    # Shared utility scripts and networking clients
│   ├── games/
│   │   ├── base_game_board.gd  # Abstract base class for all 3D game boards
│   │   ├── game_registry.gd    # Central registry for all 25 game rules and assets
│   │   └── game_docs.json      # Persian game rule descriptions
│   ├── network/
│   │   ├── api_client.gd       # REST HTTP client (kafehfekrserver:5001)
│   │   ├── socketio_client.gd  # Hand-rolled Socket.IO v4 WebSocket client
│   │   ├── commands.gd         # Client command string constants (~140 commands)
│   │   └── game_types.gd       # Client game type string constants
│   └── shaders/
│       └── solid_white_tint.gdshader
│
└── tests/                      # Manual test stubs
```

---

## 4. Autoload Singletons

### 4.1. `GameManager` (`autoload/game_manager.gd`)
- **Session & Device:** Persists token and profile data in `user://session.cfg`; generates persistent UUID device identifier in `user://settings.cfg`.
- **Match State:** Tracks `active_game_id`, `current_game_type`, `current_turn`, `my_player_index`, `p1_score`, `p2_score`, `match_players`, and surrender states.
- **Spectator State:** Tracks `is_spectating: bool`, `spectated_game_id: String`, and `spectator_count: int`. Methods: `start_spectating_session(...)`, `stop_spectating_session()`.
- **Progressive Level & XP Curve:**
  $$\text{Level}(\text{XP}) = \left\lfloor\sqrt{\frac{\text{XP}}{20} + 1}\right\rfloor$$
  $$\text{TotalXP}(L) = 20 \times (L^2 - 1)$$
  - Level 1 $\rightarrow$ 2: 60 XP
  - Level 2 $\rightarrow$ 3: 100 XP
- **Ranked Mode Gate:** Players must reach **Level 3 (160 XP)** before Ranked Queue unlocks.

### 4.2. `NetworkManager` (`autoload/network_manager.gd`)
- **Dual Transport:**
  - Manages `APIClient` for REST requests to `http://<host>:5001`.
  - Manages `SocketIOClient` for WebSocket connections to `ws://<host>:5000/socket.io/?EIO=4&transport=websocket`.
- **Dynamic Host Resolution:** Host resolved from `user://server.cfg` (`[network] host`, default `192.168.1.2`).
- **Signal Hub:** Declares ~80 signals dispatching all incoming Socket.IO events directly to UI and game boards.
- **Spectator Controls & Safety:**
  - `request_spectate_game(game_id, player_id)`: Sends `RequestSpectate` on `/social`.
  - `leave_spectate_game()`: Sends `LeaveSpectate` and cleans up spectator room.
  - `request_spectator_state()`: Re-synchronizes board after network interruptions.
  - **Outbound Command Guard:** All outbound move commands (`Select_Peace`, `Surrender`, etc.) are **strictly blocked** while `is_spectating` is true.

### 4.3. `AudioManager` (`autoload/audio_manager.gd`)
- Standardized sound keys (`add_peace`, `move_peace`, `remove_peace`, `win`, `lose`, `draw`, `time`, `miss_turn`, `chat`).
- Independent volume sliders and mute toggles for SFX and Music.

### 4.4. `ActionVFXManager` (`autoload/action_vfx_manager.gd`)
- Procedural piece drop shockwaves, celebratory confetti, sparkles, and procedural 60fps timer bar shimmer/danger flares.

---

## 5. Live Spectator Mode Architecture

The client provides a complete spectator experience:

```
[Main Menu / Social Friends / Clan Tabs]
                   │
                   ▼ Tapping "تماشای زنده" (Watch Live) or "تماشا" on player card
       LiveGamesDialog.open()
       ├─ Queries REST /spectator/live-games
       └─ Emits RequestLiveGames on Socket.IO /social
                   │
                   ▼ User selects a match to spectate
       NetworkManager.request_spectate_game(game_id)
                   │
                   ▼ Backend validates access & emits SpectateAccepted {snapshot}
       main.gd:_on_spectate_accepted(payload)
       ├─ GameManager.start_spectating_session(game_id, ...)
       ├─ Instantiates 3D Board in read-only mode (is_board_locked = true)
       ├─ Syncs physical pieces via board.sync_board_state(board_data)
       ├─ Hides interactive HUD elements (Bottom action bar)
       └─ Displays SpectatorOverlay (👁️ viewer count pill, live banner, exit button)
                   │
                   ▼ Match updates arrive in real-time
       NetworkManager.spectator_game_state_received
       NetworkManager.spectator_count_updated
                   │
                   ▼ Match concludes or player taps "ترک تماشا"
       SpectatorOverlay.leave_spectate_requested
       └─ Clears 3D board, restores main menu cleanly without cross-game leaks!
```

### Spectator UI Components
1. **`LiveGamesDialog` (`scenes/ui/spectator/live_games_dialog.gd`):**
   - Filter tabs: **"همه" (All Matches)**, **"دوستان" (Friends)**, **"کلن" (Clan)**, plus game type selector.
   - Shows active player plaques, avatars, scores, current game badge, and live spectator count.
   - 1-tap "تماشا" button to join.
2. **`SpectatorOverlay` (`scenes/ui/spectator/spectator_overlay.gd`):**
   - Anchored at bottom-center so it never obscures the player plaques at the top.
   - Displays live viewer count (`👁️ %d تماشاگر`), active turn indicator, and prominent red "ترک تماشا" button.
3. **Player Privacy Controls (`UserProfileDialog`):**
   - Configurable `allow_spectators` dropdown: `همه` (Everyone), `فقط دوستان` (Friends only), `فقط هم‌کلنی‌ها` (Clan only), `هیچ‌کس` (Nobody).

---

## 6. 3D Cafe Environment & Camera (`CafeTable`)

The 3D environment (`scenes/environment/cafe_table.tscn` / `cafe_table.gd`) remains constant across all games:
- **Central Focus:** Table center at `Vector3(0.0, 0.08, -0.04)`.
- **Default View is 2D (Top-Down):** Every game opens in 2D top-down mode (`rotation_degrees.x = -90.0`, height `3.60m`). Players can toggle to 3D orbit using the HUD camera button.
- **Orbit Constraints (3D Mode):**
  - Zoom Distance: `2.20m` to `3.55m` (Default `3.20m`).
  - Yaw (Orbit): Strictly bounded to `[-31.5°, +31.5°]`.
  - Pitch (Tilt): Strictly bounded to `[-63.0°, -33.2°]`.
- **Camera Drag Lock:** Boards lock camera orbit while pieces are being dragged (`camera_drag_locked = true`).
- **3D Tabletop Props:** Built outside the playing radius (`r >= 0.78m`): antique sand hourglass, carved walnut dice tray with 3D dice, leather-bound rulebooks, Persian plate with pistachios and saffron rock candy, and vintage brass pocket watch.
- **No 3D Hands:** Disembodied 3D hands are strictly removed across all games; pieces animate physically on the board with drop and slide VFX.

---

## 7. The 2D In-Game HUD (`BaseGameHUD`)

Unified interface rendered on a `CanvasLayer` (`scenes/games/base/base_game_hud.tscn`):
1. **Top Header Slot (`TopHeaderSlot`):** Instantiates `BaseTopHeader` or a specialized inherited header. Displays Royal Crimson (P1) and Sapphire (P2) player plaques, avatar frames, role pills, and scores (hidden if `GameRegistry.has_round_score` is false).
2. **Match Details Box (`MatchDetailsBox`):** Compact 2-row console:
   - Row 1: Round Pill (`راند ۱ از ۵`), Turn Status Banner, Stopwatch Timer Pill (`۱۰ ثانیه`).
   - Row 2: Recessed `TurnTimerBar` with real-time procedural 60fps `TimerBarVFXOverlay` (energy shimmer during turn, fiery ember shockwaves in the final 4 seconds).
3. **Bottom Action Bar (`BottomBar`):** 8 wooden buttons (`KenneyUI.COLOR_WOOD`):
   - Camera Controls: Zoom In, Zoom Out, 2D/3D Toggle, Camera Reset.
   - Match Controls: Surrender Flag, Kori Taunts (78 Persian taunt phrases), Sticker Picker (44 emojis), Audio Toggle.
4. **Toast Hint (`ToastHint`):** Centered floating feedback pill (`font_size = 32`) with smooth pop-in and fade-out animations.
5. **Disconnect Pause Dialog (`DisconnectPauseDialog`):** Freezes turn countdown and displays a 60-second recovery timer if the opponent loses connection.
6. **Pre-Game Overlay (`StartGameOverlay`):** Animated 5-second countdown banner before round start.
7. **Game Result Dialog (`GameResultDialog`):** Displays match outcome, round scores, earned XP/coins, and a return-to-menu button.

---

## 8. Base Game Board Contract (`BaseGameBoard`)

Every board extends `BaseGameBoard` (`scripts/games/base_game_board.gd`):

```gdscript
class_name MyGame3D
extends "res://scripts/games/base_game_board.gd"
```

### Lifecycle Virtual Hooks
- `setup_board(game_data)`: Initializes board matrices and piece coordinates from server payload.
- `on_turn_changed(turn, is_my_turn)`: Updates interactive pieces and highlights legal moves.
- `on_piece_selected(user_id, target_piece, extra)`: Spawns/moves physical 3D piece with drop VFX and SFX.
- `on_round_finished(payload)`: Locks board and highlights winning lines or pieces.
- `on_new_round(round_num)`: Resets pieces and board state for the next round.
- `on_reconnect_data(payload)`: Restores board state upon player reconnection (followed by `hud.sync_reconnect_timer(payload)`).
- `sync_board_state(board_data)`: Reconstructs pieces from a raw board array (used for both match reconnection and live spectating).
- `reset_board()`: Clears pieces and internal state variables.
- `cleanup_board()`: Kills running tweens, frees materials, and clears caches upon exiting to menu.

---

## 9. Catalog of the 25 Board Games

| Game ID | Persian Title | Players | Turn Time | Rounds | Scoring Type | Header |
|---|---|---|---|---|---|---|
| `TicTacToe` | تیک تاک تو | 2 | 10s | 5 | Round wins | Base |
| `RPC` | سنگ کاغذ قیچی | 2 | 7s | 3 | Simultaneous | Base |
| `FekrBekr` | فکر بکر | 2 | 60s (Setup 60s) | 12 | Guess count | Specialized |
| `Yatzy` | یاتزی | 2 | 60s | 12 | Cumulative | Specialized |
| `FourInRow` | دوز چهارتایی | 2 | 15s | 1 | Single | Base |
| `Chess` | شطرنج | 2 | 20s | 1 | Single | Specialized (AFK Strikes) |
| `Checkers` | چکرز | 2 | 20s | 1 | Single | Base |
| `BackGammon` | تخته نرد | 2 | 30s | 1 | Cumulative | Base |
| `Othello` | اتللو | 2 | 20s | 1 | Piece count | Base |
| `Mill` | دوز نه تایی | 2 | 15s | 1 | Single | Base |
| `DotBox` | نقطه خط | 2 | 15s | 1 | Box count | Base |
| `Pentago` | پنتاگو | 2 | 25s | 1 | Single | Base |
| `Yinsh` | یینش | 2 | 30s (Ring 20s) | 1 | Ring points | Base |
| `BattleShip` | نبرد کشتی | 2 | 12s (Setup 60s) | 1 | Hit points | Specialized (Dual Radar) |
| `Sudoku` | سودوکو | 2 | 1200s | 1 | Race duel | Base |
| `BoxFour` | چهارطرفه | 2 | 12s | 1 | Territory | Base |
| `MNumbers` | کشف اعداد | 2 | 7s | 1 | Pair points | Base |
| `MSweeper` | مین یاب | 2 | 600s | 1 | Mine points | Base |
| `Ludo` | منچ | 2–4 | 25s | 1 | Podium finish | Specialized (4 Players) |
| `Risk` | ریسک استرایک | 2–4 | 30s (Pass 5s) | 1 | Podium finish | Specialized (Cards/Dice) |
| `Monopoly` | مونوپولی | 2–4 | 28s (Resp 14s) | 1 | Wealth / Podium| Specialized (Properties) |
| `Uno` | اونو | 2–4 | 20s | 1 | Card points | Base |
| `Coup` | کودتا | 2–4 | 25s (Resp 12s) | 1 | Last standing | Specialized (Influence) |
| `Quiz` | کوئیز | 2–4 | 15s | 10 | Answer points | Specialized (Questions) |
| `Quoridor` | کریدور | 2–4 | 30s | 1 | Race to edge | Specialized (Walls) |

---

## 10. Building & Exporting

### Prerequisites
- Godot Engine **4.7** (Mobile feature profile).
- Android SDK, NDK, and Java 17 (for Android export).

### Exporting via Godot Editor
1. Open `project.godot` in Godot 4.7.
2. Navigate to **Project $\rightarrow$ Export**.
3. Select an export preset:
   - **Android:** Generates `cafefekr.apk` (or architecture-specific APKs: `v7`, `v8`, `x86_64`).
   - **Windows Desktop:** Generates `cafefekr.exe` and `cafefekr.pck`.
4. Click **Export Project**.
