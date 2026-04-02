# High-Speed Data Transfer System Using Intel 8257 DMA Controller

8086 Assembly language project that interfaces the Intel 8257
Programmable DMA Controller for high-speed block data transfer.

---

## Quick Start

### emu8086 (recommended — free download)
1. Download **emu8086** from https://emu8086-microprocessor-emulator.com/
2. Open emu8086 → **New** → **COM template** (or paste directly)
3. Paste the entire contents of **`dma_transfer.asm`**
4. Click **Emulate** → **Run**
5. The console window shows all 4 demo results

### VS Code (8086 Microprocessor Simulator extension)
1. Install the extension **"8086 Microprocessor Simulator"** by Mostafa Wael
2. Open **`dma_transfer.asm`** (the single file — no other file needed)
3. Press **F5** or click the Run button in the extension panel

### MASM / TASM (command line)
```bat
; MASM
ml dma_transfer.asm /link

; TASM
tasm dma_transfer.asm
tlink dma_transfer.obj
```

> **Important:** `dma_transfer.asm` is **fully self-contained**.  
> Do **not** try to INCLUDE `intel8257.inc` — it is a reference document only.  
> Putting `INCLUDE intel8257.inc` back in the file will break compilation in
> any tool that cannot resolve local file includes (emu8086, the VS Code
> extension, and most online assemblers).

---

## What the Output Looks Like

All 4 demos run one after another in **the same console window**:

```
--- Demo 1: Block Transfer (CH0) ---
Block Transfer   : OK

--- Demo 2: Demand-Mode   (CH1) ---
Demand Transfer  : OK

--- Demo 3: Single-Byte   (CH2) ---
Single Transfer  : OK

--- Demo 4: Mem-to-Mem (CH0->CH1)---
Mem-to-Mem       : OK

All 4 DMA demos complete.
```

---

## Source Files

| File | Purpose |
|------|---------|
| `dma_transfer.asm` | **Single self-contained** 8086 assembly program — open this in your simulator |
| `intel8257.inc` | Reference document: port constants, register bit tables (not included by the ASM) |

---

## Transfer Modes Implemented

| Demo | Channel | Mode | Description |
|------|---------|------|-------------|
| Demo 1 | CH0 | Block | 8257 holds bus for entire 256-byte burst |
| Demo 2 | CH1 | Demand | Transfers while DREQ active; bus returned when DREQ drops |
| Demo 3 | CH2 | Single-byte | One byte per DMA cycle; 8086 regains bus between bytes |
| Demo 4 | CH0→CH1 | Memory-to-Memory | On-chip copy using 8257 mode-bit 7 (83H) |

---

## I/O Port Map

```
Port  Register
00H   CH0 Address  (write low byte first, then high byte)
01H   CH0 Count    (write low byte first, then high byte)
02H   CH1 Address
03H   CH1 Count
04H   CH2 Address
05H   CH2 Count
06H   CH3 Address
07H   CH3 Count
08H   Mode Set Register (WRITE) / Status Register (READ)
```

---

## Mode Set Register Bits (write to port 08H)

| Bit | Symbol    | Function |
|-----|-----------|----------|
| 7   | MEMTOMEM  | Memory-to-memory enable (CH0 → CH1) |
| 6   | AUTOLOAD  | Auto-load on CH2/CH3 terminal count |
| 5   | EXWRITE   | Extended write select |
| 4   | ROTATPRI  | Rotating channel priority |
| 3   | CH3_EN    | Enable Channel 3 |
| 2   | CH2_EN    | Enable Channel 2 |
| 1   | CH1_EN    | Enable Channel 1 |
| 0   | CH0_EN    | Enable Channel 0 |

Demo 4 (Memory-to-Memory) uses **mode byte = 83H**:
`83H = 80H (MEMTOMEM) | 02H (CH1_EN) | 01H (CH0_EN)`

---

## Status Register Bits (read port 08H — clears on read)

| Bit | Symbol      | Meaning |
|-----|-------------|---------|
| 0   | CH0 TC flag | Channel 0 Terminal Count reached |
| 1   | CH1 TC flag | Channel 1 Terminal Count reached |
| 2   | CH2 TC flag | Channel 2 Terminal Count reached |
| 3   | CH3 TC flag | Channel 3 Terminal Count reached |

---

## Proteus Simulation Setup

1. Place an **8086** CPU component and set its program file to the assembled `.exe` / `.hex`.
2. Place an **Intel 8257** component.
3. Connect the 8257 chip-select (`CS`) to the decoded address line for base I/O port `00H`.
4. Connect `DREQ0`–`DREQ2` to the peripheral data sources (one per demo).
5. Connect `DACK0`–`DACK2` and `TC` back to the peripherals.
6. Run simulation and observe the DMA transfer on the data bus.

---

## Address Decoding

The 8257 occupies I/O ports `00H`–`08H`. A 74LS138 3-to-8 decoder can select it:

```
A3  → active-low CS when A3=0, A2=0, A1=0
IOR → 8257 IOR pin
IOW → 8257 IOW pin
```

---

## References

1. Intel Corporation, *8257 Programmable DMA Controller Data Sheet*, 1983.
2. Liu, Y. C. and Gibson, G. A., *Microcomputer Systems: The 8086/8088 Family*, 2nd ed., Prentice-Hall, 1986.
3. Hall, D. V., *Microprocessors and Interfacing*, 2nd ed., Glencoe/McGraw-Hill, 1992.

