# Cafe Fekr — Godot 4 Client (`cafefekr`)

The **primary client application** for **Cafe Fekr (کافه فکر)** — an online, Persian-language collection of **25 board games** played within a shared, luxury 3D "Royal Persian Cafe" table experience.

Built with **Godot 4.7** using **GDScript**, this mobile-first portrait application communicates with the companion Python REST server (`kafehfekrserver` on port `5001`) and the realtime Socket.IO game server (`kafehfekrbackend` on port `5000`).

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
|  |  - GameManager (Session, Level/XP, Match State)   |  |                                      |  |
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
|  |  | - Bottom Dock (Ranking, History, etc.)|      |  - MatchDetailsBox (Turn/Timer Bar VFX) |  |  |
|  |  +---------------------------------------+      |  - ToastHint (Floating Notifications)   |  |  |
|  |                                                 |  - BottomBar (8 Wood Action Buttons)    |  |  |
|  |  +---------------------------------------+      |  - Dialogs (Countdown, Disconnect Pause)|  |  |
|  |  |           MODAL DIALOGS               |      |  - GameResultDialog (Victory/Defeat)    |  |  |
|  |  |                                       |      +-----------------------------------------+  |  |
|  |  | - LoginDialog, QueueDialog, PickBan   |                                                   |  |
|  |  | - SocialDialog (Friends, Clans, Chat) |                                                   |  |
|  |  | - UserProfileDialog, Store, Rules     |                                                   |  |
|  |  +---------------------------------------+                                                   |  |
|  +----------------------------------------------------------------------------------------------+  |
+----------------------------------------------------------------------------------------------------+
```

---

## 3. Directory Structure

```
cafefekr/
├── project.godot               # Godot 4.7 engine configuration file
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
│   ├── game_manager.gd         # Session persistence, Level/XP curve, match state
│   ├── network_manager.gd      # High-level network manager and command signal hub
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
│   │   └── main.gd             # Master match coordinator (3,400+ lines)
│   │
│   └── ui/                     # Application dialogs & menus
│       ├── auth/               # LoginDialog (Phone SMS OTP login)
│       ├── classic_rank/       # ClassicRankDialog (Bot match selector)
│       ├── header/             # UserHeader (Top player info bar)
│       ├── history/            # GameHistoryDialog (Match history records)
│       ├── lobby/              # LobbyDialog (Custom rooms create/join)
│       ├── multi_rank/         # MultiRankDialog (3-player queue)
│       ├── profile/            # UserProfileDialog (Personalization & stats)
│       ├── queue/              # QueueDialog (Ranked queue & acceptance)
│       ├── rank/               # PickBanDialog (7-turn draft) & RankedBreakoutDialog
│       ├── ranking/            # RankingDialog (Global leaderboards)
│       ├── rules/              # RulesDialog (Game instructions viewer)
│       ├── social/             # SocialDialog (Friends, Clans, DMs, Notifications)
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
│   │   ├── commands.gd         # Client command string constants (~135 commands)
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
- **Signal Hub:** Declares ~70 signals dispatching all incoming Socket.IO events directly to UI and game boards.
- **Auto-Reconnection:** Background 4-second reconnect loop restores active matches (`open_game_id` > `open_pre_game_id`).

### 4.3. `AudioManager` (`autoload/audio_manager.gd`)
- Standardized sound keys (`add_peace`, `move_peace`, `remove_peace`, `win`, `lose`, `draw`, `time`, `miss_turn`, `chat`).
- Independent volume sliders and mute toggles for SFX and Music.

### 4.4. `ActionVFXManager` (`autoload/action_vfx_manager.gd`)
- Procedural piece drop shockwaves, celebratory confetti, sparkles, and procedural 60fps timer bar shimmer/danger flares.

---

## 5. 3D Cafe Environment & Camera (`CafeTable`)

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

## 6. The 2D In-Game HUD (`BaseGameHUD`)

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

## 7. Base Game Board Contract (`BaseGameBoard`)

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
- `sync_board_state(board_data)`: Reconstructs pieces from a raw board array.
- `reset_board()`: Clears pieces and internal state variables.
- `cleanup_board()`: Kills running tweens, frees materials, and clears caches upon exiting to menu.

### Input & Anti-Race-Condition Rule
- Move detection uses **Camera Raycasting in `_unhandled_input`** (not physics `Area3D` clicks).
- Boards must **immediately lock locally upon move dispatch** (`set_board_locked(true)`, `is_my_turn = false`) to drop rapid double-clicks while waiting for server ACK.

---

## 8. Catalog of the 25 Board Games

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

## 9. In-Game Social & Community System (`SocialDialog`)

The client features a full-screen antique club social interface (`scenes/ui/social/social_dialog.tscn`):
1. **Friends Tab:**
   - Active friends list with real-time presence indicators (`آنلاین`, `در حال بازی: شطرنج`, `آفلاین`).
   - Pending friend requests (incoming/outgoing).
   - Friend discovery and player search by username or ID.
2. **Clans Tab:**
   - My Clan hub: Emblem, trophies, clan level/XP, announcements, member roster, role badges (`رهبر کلن`, `قائم‌مقام`, `ارشد`, `عضو`).
   - Integrated Clan Chat: Real-time messaging stream inside the clan room.
   - Clan Directory: Search clans with filters (join type, language, minimum score).
   - Clan Creation: Custom Persian/alphanumeric `#TAG` and emblem picker.
3. **Messages Tab:**
   - Direct message conversations list with unread counters.
   - 1-on-1 private chat interface with friends.
4. **Notifications Tab:**
   - Real-time notification feed (friend requests, clan invitations, match rewards).
5. **Live Spectator Mode:**
   - Watch friends and clanmates play in authorized matches (`SocialSpectateJoin`).

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
