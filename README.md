# Cafe Fekr — Godot 4 Client (`cafefekr`)

The **primary client application** for **Cafe Fekr (کافه فکر)** — an online, Persian-language collection of **25 board games** played within a shared, luxury 3D "Royal Persian Cafe" table experience.

Built with **Godot 4.7** using **GDScript**, this mobile-first portrait application communicates with the companion Python REST server (`kafehfekrserver` on port `5001`) and the realtime Socket.IO game server (`kafehfekrbackend` on port `5000`). It features active competitive matches, a modern **Five-Tab Navigation Hub** (`MainTabShell`), a full-featured social & clan hub, 20 collectible avatar frames, and a complete **Live Spectator Mode** with game discovery and read-only 3D board viewing.

---

## 1. High-Level Summary

| Property | Value |
|---|---|
| **Engine / Language** | Godot 4.7 (Mobile renderer / D3D12), GDScript |
| **App Version** | `2.1.2` (Client-side force-update check via `allowed_version`) |
| **Orientation & Resolution** | Portrait (1080 × 1920 base, 540 × 960 window override, `canvas_items/expand`) |
| **Target Platforms** | Android (APK, arm64-v8a / armeabi-v7a / x86_64), Windows Desktop |
| **Persian Typography** | `res://assets/fonts/Vazir.ttf` (UI standard) & `res://assets/fonts/hekayat.ttf` (In-game 3D & score typography) |
| **Main Navigation** | Five-Tab Hub (`MainTabShell`: Play, Library, History, Social, User/Profile) |
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
|  |  - ActionVFXManager (Procedural Particle FX)       |  |  - Authentic 3D Chairs (4 Textures)  |  |
|  +----------------------------------------------------+  |  - Authentic Table Props & Lighting  |  |
|                                                          |  - BoardContainer                    |  |
|                                                          |       \--> [Active Game Board 3D]    |  |
|                                                          +--------------------------------------+  |
|                                                                                                    |
|  +----------------------------------------------------------------------------------------------+  |
|  |                                      2D CANVAS UI LAYER                                      |  |
|  |                                                                                              |  |
|  |  +----------------------------------------------------------------------------------------+  |  |
|  |  |                 FIVE-TAB MAIN NAVIGATION HUB (MainTabShell)                            |  |  |
|  |  |                                                                                        |  |  |
|  |  |  1. PlayTab: 4 Game Mode Cards (Ranked, Classic, Lobby, Multi-Rank), Watch Live, Exit |  |  |
|  |  |  2. LibraryTab: 25-Game Catalog, Search, Category Chips, RTL Rulebook Reader           |  |  |
|  |  |  3. HistoryTab: برترین‌ها (4 Leaderboards: Score, Wins, Friends, Clans), Player Profiles|  |  |
|  |  |  4. SocialTab: Antique Club Hub (Friends with Live Presence, Clans, DMs, Notifs)       |  |  |
|  |  |  5. UserTab: Player Level/XP, Match Reviews, 20 Avatar Frames, Privacy & Sound Settings|  |  |
|  |  |  - BottomNavigation: Persistent 5-button antique wooden plaque with non-tiled 9-slice  |  |  |
|  |  +----------------------------------------------------------------------------------------+  |  |
|  |                                                                                              |  |
|  |  +--------------------------------------------------+  +----------------------------------+  |  |
|  |  |             IN-GAME HUD (BaseGameHUD)            |  |         SPECTATOR OVERLAY        |  |  |
|  |  |  (scenes/games/base/base_game_hud.tscn)          |  | (scenes/ui/spectator/overlay.gd) |  |  |
|  |  |                                                  |  |                                  |  |  |
|  |  |  - TopHeaderSlot (Player Plaques & Avatar Frames)|  |  - Viewer Count Pill             |  |  |
|  |  |  - MatchDetailsBox (Turn/Timer Bar VFX)          |  |    (👁️ %d تماشاگر)               |  |  |
|  |  |  - ToastHint (Floating Notifications)            |  |  - Exit Button ("ترک تماشا")      |  |  |
|  |  |  - BottomBar (8 Wood Action Buttons)             |  +----------------------------------+  |  |
|  |  |  - Dialogs (Countdown, Disconnect Pause)         |                                         |  |
|  |  |  - GameResultDialog (Victory/Defeat)             |                                         |  |
|  |  +--------------------------------------------------+                                         |  |
|  +----------------------------------------------------------------------------------------------+  |
+----------------------------------------------------------------------------------------------------+
```

---

## 3. Directory Structure

```
cafefekr/
├── project.godot               # Godot 4.7 engine configuration file (v2.1.2)
├── export_presets.cfg          # Android & Windows export build configurations
├── GAME_SCENE_RULES.md         # 70+ KB mandatory engineering rules & standards document
├── icon.svg                    # Application icon
│
├── android/                    # Android build template & gradle assets
│
├── assets/                     # Media, audio, textures, and fonts
│   ├── audio/                  # SFX (piece taps, wins, losses, timer ticks) & music
│   ├── fonts/                  # Persian TTF fonts (Vazir.ttf, hekayat.ttf)
│   ├── icons/                  # 100% transparent vector and PNG UI icons
│   └── images/                 # Textured buttons, badges, frames, and game cards
│       ├── badges/             # Clan tabs, watch live badge, trophies, medals
│       └── cafe_textures/      # 3D chair textures (cognac, emerald, crimson, teal)
│
├── autoload/                   # Global singleton managers (autoload order matters)
│   ├── game_manager.gd         # Session persistence, Level/XP curve, match & spectator state
│   ├── network_manager.gd      # High-level network manager and command signal hub (~80 signals)
│   ├── audio_manager.gd        # Sound effects and soundtrack audio player (50% default music)
│   └── action_vfx_manager.gd   # Procedural particle and juice effects
│
├── scenes/                     # Scene tree
│   ├── environment/            # Shared 3D cafe table, camera, and authentic chairs
│   │   ├── cafe_table.tscn
│   │   └── cafe_table.gd       # Orbit/zoom camera, props, 4 chair styles, 2D top-down mode
│   │
│   ├── games/                  # 25 Game board scenes + shared base scenes
│   │   ├── base/               # Unified in-game HUD and top headers
│   │   │   ├── base_game_hud.tscn / .gd    # Shared 2D in-game HUD
│   │   │   └── base_top_header.tscn / .gd  # Shared player plaques & scores
│   │   ├── risk/               # Risk Strike 3D board, defense-phase strategy cards, pacing
│   │   ├── monopoly/           # Monopoly 3D board & specialized header
│   │   ├── ludo/               # Ludo 3D board & 4-player header (multiplayer-resilient)
│   │   ├── chess/              # Chess 3D board & missed-turn header
│   │   ├── fekrbekr/           # Mastermind (FekrBekr) 3D board & dual header
│   │   ├── yatzy/              # Yatzy 3D board (3 re-rolls per round) & score sheet header
│   │   ├── mnumbers/           # Match Numbers 3D board (immediate 1st piece reveal/lock)
│   │   ├── battleship/         # Battleship 3D board & dual radar header
│   │   └── ...                 # 17 additional individual 3D game scenes
│   │
│   ├── main/                   # Root scene
│   │   ├── main.tscn           # Application entry point
│   │   └── main.gd             # Master coordinator (match lifecycle, spectator flow)
│   │
│   └── ui/                     # Application UI
│       ├── main_tabs/          # Modern Five-Tab Navigation Hub
│       │   ├── main_tab_shell.gd / .tscn # Master tab switcher
│       │   ├── tabs/
│       │   │   ├── play_tab.gd / .tscn     # Core match launcher
│       │   │   ├── library_tab.gd / .tscn  # 25 Games catalog & rules reader
│       │   │   ├── history_tab.gd / .tscn  # برترین‌ها (Global leaderboards)
│       │   │   ├── social_tab.gd / .tscn   # Friends, Clans, DMs, Challenges
│       │   │   └── user_tab.gd / .tscn     # Player profile, 20 avatar frames, settings
│       │   └── components/
│       │       ├── bottom_navigation.tscn  # Persistent 5-button wooden dock
│       │       └── sound_settings_popup.tscn
│       ├── auth/               # LoginDialog (Redesigned mobile phone & OTP dialog)
│       ├── classic_rank/       # ClassicRankDialog (Overhauled AI bot match selector)
│       ├── spectator/          # Live Spectator UI components
│       │   ├── live_games_dialog.gd # Match discovery browser modal
│       │   └── spectator_overlay.gd # In-game live spectator HUD
│       └── ...                 # Additional specialized dialogs
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
└── tests/                      # Integration and tab navigation test scripts
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
- **50% Default Music Volume:** Background cafe music calibrated to 50% for comfortable, non-intrusive ambience.

### 4.4. `ActionVFXManager` (`autoload/action_vfx_manager.gd`)
- Procedural piece drop shockwaves, celebratory confetti, sparkles, and procedural 60fps timer bar shimmer/danger flares.

---

## 5. Modern Five-Tab Navigation Hub (`MainTabShell`)

The client main menu uses a portrait-first, 5-tab application architecture (`scenes/ui/main_tabs/`):
1. **`PlayTab` (بازی):**
   - The primary match launcher resting over the 3D cafe table.
   - 4 Wooden Mode Cards: Ranked Series (Bo3), Classic Rank (vs AI bot), Friendly Lobby, and Multi-Player Rank (Ludo/Risk/Monopoly).
   - "تماشای زنده" (Watch Live) button and Exit button.
2. **`LibraryTab` (کتابخانه بازی‌ها):**
   - Catalog of all 25 board games with live search, category filter chips (Strategy, Board, Dice, Card, Quick), and 2-part RTL game guide viewer.
3. **`HistoryTab` (برترین‌ها):**
   - Global leaderboards (Competitive Score, Total Wins, Friends, Clans) styled with antique wooden frames, medals, level badges, and 1-tap player/clan profile modals.
4. **`SocialTab` (اجتماعی / اتحاد):**
   - Integrated antique club hub: Friends list with real-time presence indicators, Clan hub (اتحاد), Direct Messages, and clan challenges.
5. **`UserTab` (کاربر و تنظیمات):**
   - Top player profile banner, level/XP progress bar, personal match history with replay/review modals, doubled stats matrix, 20-frame avatar selector, sound volume sliders, privacy settings, and notification center.
- **`BottomNavigation`:**
   - Persistent 5-button bottom bar styled with a single, continuous antique wooden frame plaque (9-slice stretched, non-tiled) with 15–20px content padding.

---

## 6. Live Spectator Mode Architecture

```
[PlayTab / Social Friends / Clan Tabs]
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

---

## 7. 3D Cafe Environment & Authentic 3D Chairs (`CafeTable`)

The 3D environment (`scenes/environment/cafe_table.tscn` / `cafe_table.gd`) remains constant across all games:
- **Central Focus:** Table center at `Vector3(0.0, 0.08, -0.04)`.
- **Default View is 2D (Top-Down):** Every game opens in 2D top-down mode (`rotation_degrees.x = -90.0`, height `3.60m`). Players can toggle to 3D orbit using the HUD camera button.
- **Orbit Constraints (3D Mode):**
  - Zoom Distance: `2.20m` to `3.55m` (Default `3.20m`).
  - Yaw (Orbit): Strictly bounded to `[-31.5°, +31.5°]`.
  - Pitch (Tilt): Strictly bounded to `[-63.0°, -33.2°]`.
- **Authentic 3D Chairs:**
  - 4 Procedurally placed cafe chairs surrounding the table with rich material variations: Cognac leather, Emerald leather, Crimson velvet, and Teal damask.
  - Placed strictly outside the playing area so they never obstruct camera raycasting or board visibility.
- **3D Tabletop Props:** Antique sand hourglass, carved walnut dice tray with 3D dice, leather-bound rulebooks, Persian plate with pistachios and saffron rock candy, and vintage brass pocket watch.
- **No 3D Hands:** Disembodied 3D hands are strictly removed across all games; pieces animate physically on the board with drop and slide VFX.

---

## 8. Catalog of the 25 Board Games

| Game ID | Persian Title | Players | Turn Time | Rounds | Scoring Type | Header |
|---|---|---|---|---|---|---|
| `TicTacToe` | تیک تاک تو | 2 | 10s | 5 | Round wins | Base |
| `RPC` | سنگ کاغذ قیچی | 2 | 7s | 3 | Simultaneous | Base |
| `FekrBekr` | فکر بکر | 2 | 60s (Setup 60s) | 12 | Guess count | Specialized |
| `Yatzy` | یاتزی | 2 | 60s | 12 | Cumulative | Specialized (3 re-rolls) |
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
| `MNumbers` | کشف اعداد | 2 | 7s | 1 | Pair points | Base (Immediate 1st reveal) |
| `MSweeper` | مین یاب | 2 | 600s | 1 | Mine points | Base |
| `Ludo` | منچ | 2–4 | 25s | 1 | Podium finish | Specialized (4 Players) |
| `Risk` | ریسک استرایک | 2–4 | 30s (Pass 5s) | 1 | Podium finish | Specialized (Cards/Dice/Pacing) |
| `Monopoly` | مونوپولی | 2–4 | 28s (Resp 14s) | 1 | Wealth / Podium| Specialized (Properties) |
| `Uno` | اونو | 2–4 | 20s | 1 | Card points | Base |
| `Coup` | کودتا | 2–4 | 25s (Resp 12s) | 1 | Last standing | Specialized (Influence) |
| `Quiz` | کوئیز | 2–4 | 15s | 10 | Answer points | Specialized (Questions) |
| `Quoridor` | کریدور | 2–4 | 30s | 1 | Race to edge | Specialized (Walls) |

---

## 9. Building & Exporting

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
