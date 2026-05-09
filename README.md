<div align="center">

# ♚ 3D Chess ♔

### A fully-featured 3D chess game built with Godot 4

[![Godot 4.6](https://img.shields.io/badge/Godot-4.6-478cbf?logo=godot-engine&logoColor=white)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-orange?logo=linux)](https://github.com/NativeCodex)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue?logo=windows)](https://github.com/NativeCodex)

<img src="https://img.shields.io/badge/Status-Complete-brightgreen" alt="Status">
<img src="https://img.shields.io/badge/AI-Minimax%20α%E2%80%93β-ff69b4" alt="AI">

---

[Features](#-features) • [Campaign](#-campaign) • [How to Play](#-how-to-play) • [Build from Source](#-build-from-source) • [Credits](#-credits)

</div>

---

## ✨ Features

<table>
<tr>
<td width="50%">

### 🎮 Gameplay
- Full chess rules: castling, en passant, pawn promotion
- Check, checkmate, and stalemate detection
- Move history and captured pieces display
- Save/Load game state (Ctrl+S / Ctrl+L)
- Quick restart on game over

</td>
<td width="50%">

### 🤖 AI Engine
- Minimax search with alpha-beta pruning
- Configurable depth (2–5) from settings
- Piece-square table evaluation
- 5 difficulty levels: Novice → Expert

</td>
</tr>
<tr>
<td>

### 🎯 Campaign Mode
- 10 progressive levels with unique objectives
- Star rating system (1–3 stars per level)
- Unlock levels sequentially
- Track wins, losses, and streaks

</td>
<td>

### 🎨 Visuals
- 3D board with imported glTF piece meshes
- Dynamic camera that follows active player
- Studio lighting: sun key, sky fill, bounce, top
- SSAO, bloom, ACES tonemapping
- Wooden table with legs

</td>
</tr>
<tr>
<td>

### 🔊 Audio
- Procedurally generated ambient music (Am chord)
- Volume control in settings
- Particle background on menu

</td>
<td>

### 📋 UI
- Splash screen with fade-in
- Main menu with live particle background
- New Game: 5 game modes
- Settings panel with sliders
- Credits screen

</td>
</tr>
</table>

---

## 🎯 Campaign

| # | Level | Objective | AI Depth |
|---|-------|-----------|:--------:|
| 1 | **First Blood** | Win your first game | 2 |
| 2 | **Rook's Pride** | Win while losing ≤ 3 pieces | 2 |
| 3 | **Knight's Gambit** | Defeat a stronger AI | 3 |
| 4 | **Queen's Hunt** | Capture the enemy queen and win | 3 |
| 5 | **Bishop's Siege** | Win against hard AI | 4 |
| 6 | **Speed Chess** | Win within 30 moves | 3 |
| 7 | **Material Master** | Win with a 5-point material lead | 3 |
| 8 | **King's Challenge** | Defeat expert AI (depth 5) | 5 |
| 9 | **Grandmaster** | Win without losing a single piece | 4 |
| 10 | **Chess Champion** | Win 3 games in a row against expert AI | 5 |

Each level earns **1–3 stars** based on performance. Unlock the next level by completing the current one.

---

## 🎮 How to Play

### Controls

| Key | Action |
|:---:|--------|
| 🖱️ Left Click | Select piece / Make move |
| `Ctrl` + `S` | Save game |
| `Ctrl` + `L` | Load game |

### Game Modes

| Mode | Description |
|------|-------------|
| **Human vs Human** | Two players on the same machine |
| **AI Novice** | AI at depth 2 — perfect for beginners |
| **AI Easy** | AI at depth 3 |
| **AI Hard** | AI at depth 4 |
| **AI Expert** | AI at depth 5 — the ultimate challenge |
| **Campaign** | 10-level progressive challenge mode |

### Tips
- Click a piece to see valid moves highlighted
- The camera automatically shifts to the active player's side
- In AI mode, the camera stays on your side
- Use Settings to adjust AI difficulty and music volume

---

## 🚀 Build from Source

### Prerequisites

- [Godot 4.6.2+](https://godotengine.org/download)

### Setup

```bash
# Clone the repository
git clone https://github.com/NativeCodex/3d-chess.git
cd 3d-chess

# Launch the game
godot --path .
```

### Export for Distribution

#### Linux
```bash
# Install Linux export templates first
godot --headless --export-release "Linux" exports/chess-game-linux.x86_64
```

#### Windows
```bash
# Install Windows export templates first
godot --headless --export-release "Windows" exports/chess-game-windows.exe
```

> **Note:** Export templates can be installed from the Godot editor: `Editor → Manage Export Templates`

---

## 🖼️ Screenshots

<details>
<summary>Click to expand</summary>

```
[Screenshots coming soon!]

Main Menu  |  Game View  |  Campaign  |  Credits
```

</details>

---

## 🛠️ Technical Details

| Component | Technology |
|-----------|------------|
| **Engine** | Godot 4.6.2 (OpenGL 3 Compat) |
| **Language** | GDScript |
| **Rendering** | OpenGL 3 Compatibility |
| **3D Assets** | Poly Pizza / CC0 (glTF format) |
| **Audio** | Procedural via AudioStreamGenerator |
| **AI** | Custom minimax with alpha-beta pruning |
| **Save System** | JSON via FileAccess |

---

## 🙏 Credits

| Role | Name |
|------|------|
| **Developer** | Sheldon Ramu |
| **Company** | NativeCodex — A Solo Developer Company |
| **Game Engine** | [Godot Engine](https://godotengine.org) |
| **AI Coding Assistant** | [OpenCode](https://opencode.ai) |
| **AI Model** | Big Pickle |
| **3D Assets** | [Poly Pizza](https://poly.pizza) / CC0 |
| **Operating System** | Linux Mint |

---

<div align="center">

**Made with ❤️ by NativeCodex**

[Report Bug](https://github.com/NativeCodex/3d-chess/issues) • [Request Feature](https://github.com/NativeCodex/3d-chess/issues)

</div>
