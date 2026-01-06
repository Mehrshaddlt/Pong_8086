# Pong (8086 / MS-DOS, Text Mode) — Bonus Project (CSL)

This repository contains an educational implementation of **Pong** in **8086 assembly** for **MS-DOS**, intended for the **Computer Structure and Language (CSL)** course (Fall semester) at **Sharif University of Technology**.

The goal is to practice low-level programming concepts by building a complete interactive program using:
- **8086 real-mode assembly**
- **Direct video memory access** in VGA text mode (`B800h`)
- **Keyboard input** through BIOS interrupts
- A simple **game loop** (frame update / redraw)

The program is designed to run inside **DOSBox** (or similar DOS emulators).

---

## Project Structure

```
pong-8086/
  src/
    pong.asm
  build/
    pong.com
```

- `src/pong.asm`: main source file (8086 assembly)
- `build/pong.com`: generated DOS executable (created after building)

---

## Requirements

### Environment
- Windows + **WSL (Ubuntu)** for development
- **VS Code** connected to WSL (recommended workflow)

### Tools
- **NASM** (used to assemble a `.COM` binary)
- **DOSBox 0.74-3** (used to run the program)

> Course documents mention MASM/TASM as acceptable assemblers; this project uses **NASM** for building and **DOSBox** for execution.

---

## Setup

### 1) Install NASM in WSL
In Ubuntu (WSL):

```bash
sudo apt update
sudo apt install nasm
```

### 2) Prepare a DOSBox run folder on Windows
Create a folder that DOSBox will mount, for example:

```
D:\DOS\pong
```

---

## Build

From WSL, inside the repository directory:

```bash
mkdir -p build
nasm -f bin src/pong.asm -o build/pong.com
```

Copy the built program to the Windows DOS folder (so DOSBox can see it):

```bash
cp build/pong.com /mnt/d/DOS/pong/
```

---

## Run (DOSBox)

1. Open DOSBox.
2. Mount the Windows folder and run the program:

```
mount c d:\dos\pong
c:
pong.com
```

### Controls
- Left paddle: `W` (up), `S` (down)
- Right paddle: `↑` (up), `↓` (down)
- Exit: `Esc`

---

## Technical Notes (What the program demonstrates)

- **VGA text mode drawing**: writing character/attribute words to `B800:0000`.
- **Non-blocking keyboard input**: BIOS `int 16h`:
  - ASCII keys (`W`, `S`) via `AL`
  - Arrow keys via scan codes in `AH` when `AL = 0`
- **Simple frame loop**: clear screen → draw paddles → small delay → repeat.

---

## Expected Output

When executed, the program clears the DOSBox screen and displays two paddles:
- One near the left side
- One near the right side

Both paddles can be moved with the controls above.

---

## Acknowledgments

This project is prepared as a course-oriented assembly exercise aligned with the CSL bonus project description and focuses on practicing low-level programming concepts in a DOS-like environment.
