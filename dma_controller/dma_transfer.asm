; ============================================================
; FILE      : dma_transfer.asm
; TITLE     : High-Speed Data Transfer System
;             Intel 8257 DMA Controller + Intel 8086
; ASSEMBLER : emu8086  (also works with MASM 5.x / TASM 3.x)
;
; HOW TO RUN IN emu8086
;   1. Open emu8086, click "New", paste this entire file.
;   2. Click "Emulate", then "Run".
;   3. The console window shows all 4 demo results.
;
; HOW TO RUN IN VS CODE (8086 Microprocessor Simulator extension)
;   1. Open this single file in VS Code.
;   2. Press F5 (or use the Run button in the extension).
;
; NOTE: This file is fully self-contained – no INCLUDE needed.
;
; ============================================================
; Intel 8257 I/O PORT MAP
; ============================================================
;  Port  Register
;  00H   CH0 Address  (write low byte, then high byte)
;  01H   CH0 Count    (write low byte, then high byte)
;  02H   CH1 Address
;  03H   CH1 Count
;  04H   CH2 Address
;  05H   CH2 Count
;  06H   CH3 Address
;  07H   CH3 Count
;  08H   Mode Register (WRITE) / Status Register (READ)
;
; ============================================================
; MODE SET REGISTER (write port 08H)
; ============================================================
;  Bit 7 : MEMTOMEM  – Memory-to-memory enable (CH0 -> CH1)
;  Bit 6 : AUTOLOAD  – Auto-load on TC
;  Bit 5 : EXWRITE   – Extended write select
;  Bit 4 : ROTATPRI  – Rotating priority
;  Bit 3 : CH3_EN    – Enable Channel 3
;  Bit 2 : CH2_EN    – Enable Channel 2
;  Bit 1 : CH1_EN    – Enable Channel 1
;  Bit 0 : CH0_EN    – Enable Channel 0
;
; ============================================================
; STATUS REGISTER (read port 08H – clears on read)
; ============================================================
;  Bit 3 : CH3 Terminal Count reached
;  Bit 2 : CH2 Terminal Count reached
;  Bit 1 : CH1 Terminal Count reached
;  Bit 0 : CH0 Terminal Count reached
;
; ============================================================
; FOUR DEMOS (all output to the same console window)
; ============================================================
;  Demo 1 – Block Transfer      (Channel 0)
;  Demo 2 – Demand-Mode Transfer(Channel 1)
;  Demo 3 – Single-Byte Transfer(Channel 2)
;  Demo 4 – Memory-to-Memory    (CH0 -> CH1)
; ============================================================

; ------ 8257 port addresses --------------------------------
DMA_CH0_ADDR    EQU  00H
DMA_CH0_COUNT   EQU  01H
DMA_CH1_ADDR    EQU  02H
DMA_CH1_COUNT   EQU  03H
DMA_CH2_ADDR    EQU  04H
DMA_CH2_COUNT   EQU  05H
DMA_CH3_ADDR    EQU  06H
DMA_CH3_COUNT   EQU  07H
DMA_MODE_REG    EQU  08H

; ------ Mode register channel-enable bits ------------------
DMA_CH0_EN      EQU  01H        ; bit 0
DMA_CH1_EN      EQU  02H        ; bit 1
DMA_CH2_EN      EQU  04H        ; bit 2
DMA_CH3_EN      EQU  08H        ; bit 3
DMA_MEM2MEM     EQU  80H        ; bit 7 – memory-to-memory

; ------ Status register TC flags ---------------------------
DMA_ST_CH0_TC   EQU  01H
DMA_ST_CH1_TC   EQU  02H
DMA_ST_CH2_TC   EQU  04H
DMA_ST_CH3_TC   EQU  08H

; ------ Transfer block size --------------------------------
BLOCK_SIZE      EQU  0100H      ; 256 bytes

; ===========================================================
.MODEL SMALL
.STACK 0200H

.DATA

SOURCE_BUF  DB  256 DUP(0)      ; source data (filled 00H..FFH)
DEST_BUF    DB  256 DUP(0)      ; destination for demos 1-3
SCRATCH_BUF DB  256 DUP(0)      ; destination for demo 4

; ---- section headers (printed before each demo) -----------
HDR1  DB  '--- Demo 1: Block Transfer (CH0) ---', 0DH, 0AH, '$'
HDR2  DB  '--- Demo 2: Demand-Mode   (CH1) ---', 0DH, 0AH, '$'
HDR3  DB  '--- Demo 3: Single-Byte   (CH2) ---', 0DH, 0AH, '$'
HDR4  DB  '--- Demo 4: Mem-to-Mem (CH0->CH1)---', 0DH, 0AH, '$'

; ---- result messages --------------------------------------
MSG_BLOCK_OK    DB  'Block Transfer   : OK',   0DH, 0AH, '$'
MSG_BLOCK_FAIL  DB  'Block Transfer   : FAIL', 0DH, 0AH, '$'
MSG_DEMAND_OK   DB  'Demand Transfer  : OK',   0DH, 0AH, '$'
MSG_DEMAND_FAIL DB  'Demand Transfer  : FAIL', 0DH, 0AH, '$'
MSG_SINGLE_OK   DB  'Single Transfer  : OK',   0DH, 0AH, '$'
MSG_SINGLE_FAIL DB  'Single Transfer  : FAIL', 0DH, 0AH, '$'
MSG_M2M_OK      DB  'Mem-to-Mem       : OK',   0DH, 0AH, '$'
MSG_M2M_FAIL    DB  'Mem-to-Mem       : FAIL', 0DH, 0AH, '$'
MSG_DONE        DB  0DH, 0AH, 'All 4 DMA demos complete.', 0DH, 0AH, '$'
MSG_NEWLINE     DB  0DH, 0AH, '$'

.CODE

; ===========================================================
; MAIN – entry point
; ===========================================================
MAIN PROC
        MOV  AX, @DATA
        MOV  DS, AX

        CALL INIT_DMA           ; reset 8257, disable all channels
        CALL FILL_SOURCE        ; load 00H..FFH into SOURCE_BUF

        CALL DEMO_BLOCK         ; Demo 1
        CALL DEMO_DEMAND        ; Demo 2
        CALL DEMO_SINGLE        ; Demo 3
        CALL DEMO_MEM2MEM       ; Demo 4

        LEA  DX, MSG_DONE
        MOV  AH, 09H
        INT  21H

        MOV  AX, 4C00H
        INT  21H
MAIN ENDP

; ===========================================================
; INIT_DMA
; Resets the Intel 8257: disables all channels, clears the
; internal address/count flip-flop, zeroes CH0 registers.
; Destroys: AL
; ===========================================================
INIT_DMA PROC NEAR
        ; --- disable all channels (mode register = 00H) ----
        MOV  AL, 00H
        OUT  DMA_MODE_REG, AL

        ; --- clear flip-flop by writing 00H twice to CH0 ---
        XOR  AL, AL
        OUT  DMA_CH0_ADDR,  AL   ; flip-flop -> low byte
        OUT  DMA_CH0_ADDR,  AL   ; flip-flop -> high byte (= 0000H)
        OUT  DMA_CH0_COUNT, AL   ; count low  = 00H
        OUT  DMA_CH0_COUNT, AL   ; count high = 00H
        RET
INIT_DMA ENDP

; ===========================================================
; FILL_SOURCE
; Writes 00H, 01H, 02H, ..., FFH into SOURCE_BUF (256 bytes).
; Destroys: AL, CX, DI
; ===========================================================
FILL_SOURCE PROC NEAR
        LEA  DI, SOURCE_BUF
        XOR  AL, AL
        MOV  CX, BLOCK_SIZE
FILL_LP:
        MOV  [DI], AL
        INC  DI
        INC  AL
        LOOP FILL_LP
        RET
FILL_SOURCE ENDP

; ===========================================================
; DEMO 1 – BLOCK TRANSFER  (Channel 0)
; ----------------------------------------------------------
; In block mode the 8257 asserts HRQ and holds the 8086 bus
; for the entire block without releasing it between bytes.
;
; Programming sequence (OUT instructions):
;   1. Reset 8257 (mode reg = 00H)
;   2. Write CH0 address: low byte then high byte -> port 00H
;   3. Write CH0 count  : (n-1) low then high    -> port 01H
;   4. Enable CH0 (mode reg = 01H)
;   [Hardware then drives the bus; here MOVSB models the copy]
;   5. Verify and print result
; ===========================================================
DEMO_BLOCK PROC NEAR
        ; ---- print section header ----
        LEA  DX, HDR1
        MOV  AH, 09H
        INT  21H

        ; ---- 1. Reset 8257 ----
        MOV  AL, 00H
        OUT  DMA_MODE_REG, AL

        ; ---- 2. Program CH0 address (SOURCE_BUF offset) ----
        LEA  BX, SOURCE_BUF
        MOV  AL, BL              ; low byte of address
        OUT  DMA_CH0_ADDR, AL
        MOV  AL, BH              ; high byte of address
        OUT  DMA_CH0_ADDR, AL

        ; ---- 3. Program CH0 word count (BLOCK_SIZE - 1) ----
        MOV  AX, BLOCK_SIZE
        DEC  AX                  ; 8257 stores (count - 1)
        OUT  DMA_CH0_COUNT, AL   ; low byte  (FFH)
        MOV  AL, AH
        OUT  DMA_CH0_COUNT, AL   ; high byte (00H)

        ; ---- 4. Enable CH0 (bit 0 = 1) ----
        MOV  AL, DMA_CH0_EN
        OUT  DMA_MODE_REG, AL

        ; ---- 5. Simulate DMA data copy (MOVSB models bus transfer) ----
        LEA  SI, SOURCE_BUF
        LEA  DI, DEST_BUF
        MOV  CX, BLOCK_SIZE
        CLD
        REP  MOVSB

        ; ---- 6. Verify DEST_BUF == SOURCE_BUF ----
        CALL VERIFY_DEST
        JNC  BLK_OK
        LEA  DX, MSG_BLOCK_FAIL
        JMP  BLK_PRINT
BLK_OK:
        LEA  DX, MSG_BLOCK_OK
BLK_PRINT:
        MOV  AH, 09H
        INT  21H
        LEA  DX, MSG_NEWLINE
        MOV  AH, 09H
        INT  21H
        RET
DEMO_BLOCK ENDP

; ===========================================================
; DEMO 2 – DEMAND-MODE TRANSFER  (Channel 1)
; ----------------------------------------------------------
; In demand mode the 8257 transfers bytes continuously as
; long as DREQ stays asserted.  The CPU bus is only returned
; when DREQ is de-asserted (e.g. peripheral FIFO full).
;
; Programming sequence:
;   1. Reset 8257
;   2. Write CH1 address -> port 02H
;   3. Write CH1 count   -> port 03H
;   4. Enable CH1 (mode reg = 02H)
;   [DMA bursts until TC; MOVSB models the continuous copy]
; ===========================================================
DEMO_DEMAND PROC NEAR
        ; ---- print section header ----
        LEA  DX, HDR2
        MOV  AH, 09H
        INT  21H

        ; ---- 1. Reset 8257 ----
        MOV  AL, 00H
        OUT  DMA_MODE_REG, AL

        ; ---- 2. Program CH1 address ----
        LEA  BX, SOURCE_BUF
        MOV  AL, BL
        OUT  DMA_CH1_ADDR, AL
        MOV  AL, BH
        OUT  DMA_CH1_ADDR, AL

        ; ---- 3. Program CH1 count ----
        MOV  AX, BLOCK_SIZE
        DEC  AX
        OUT  DMA_CH1_COUNT, AL
        MOV  AL, AH
        OUT  DMA_CH1_COUNT, AL

        ; ---- 4. Enable CH1 (bit 1 = 1) ----
        MOV  AL, DMA_CH1_EN
        OUT  DMA_MODE_REG, AL

        ; ---- 5. Simulate demand-mode burst copy ----
        LEA  SI, SOURCE_BUF
        LEA  DI, DEST_BUF
        MOV  CX, BLOCK_SIZE
        CLD
        REP  MOVSB

        ; ---- 6. Verify ----
        CALL VERIFY_DEST
        JNC  DEM_OK
        LEA  DX, MSG_DEMAND_FAIL
        JMP  DEM_PRINT
DEM_OK:
        LEA  DX, MSG_DEMAND_OK
DEM_PRINT:
        MOV  AH, 09H
        INT  21H
        LEA  DX, MSG_NEWLINE
        MOV  AH, 09H
        INT  21H
        RET
DEMO_DEMAND ENDP

; ===========================================================
; DEMO 3 – SINGLE-BYTE TRANSFER  (Channel 2)
; ----------------------------------------------------------
; In single-byte mode the 8257 performs one bus transfer per
; DREQ pulse, then releases the bus back to the 8086 before
; the next byte.  Each byte requires a new DREQ assertion.
;
; Programming sequence:
;   1. Reset 8257
;   2. Write CH2 address -> port 04H
;   3. Write CH2 count   -> port 05H
;   4. Loop 256 times:
;        a. Enable CH2 (assert DREQ for one byte)
;        b. Transfer one byte (MOVSB)
;        c. Disable CH2 (bus returned to CPU)
; ===========================================================
DEMO_SINGLE PROC NEAR
        ; ---- print section header ----
        LEA  DX, HDR3
        MOV  AH, 09H
        INT  21H

        ; ---- 1. Reset 8257 ----
        MOV  AL, 00H
        OUT  DMA_MODE_REG, AL

        ; ---- 2. Program CH2 address ----
        LEA  BX, SOURCE_BUF
        MOV  AL, BL
        OUT  DMA_CH2_ADDR, AL
        MOV  AL, BH
        OUT  DMA_CH2_ADDR, AL

        ; ---- 3. Program CH2 count ----
        MOV  AX, BLOCK_SIZE
        DEC  AX
        OUT  DMA_CH2_COUNT, AL
        MOV  AL, AH
        OUT  DMA_CH2_COUNT, AL

        ; ---- 4. Single-byte loop ----
        LEA  SI, SOURCE_BUF
        LEA  DI, DEST_BUF
        MOV  CX, BLOCK_SIZE
        CLD

SLOOP:
        MOV  AL, DMA_CH2_EN      ; assert DREQ: enable CH2
        OUT  DMA_MODE_REG, AL
        MOVSB                    ; one bus transfer (MEMR + MEMW)
        MOV  AL, 00H             ; de-assert DREQ: disable all
        OUT  DMA_MODE_REG, AL
        LOOP SLOOP

        ; ---- 5. Verify ----
        CALL VERIFY_DEST
        JNC  SNG_OK
        LEA  DX, MSG_SINGLE_FAIL
        JMP  SNG_PRINT
SNG_OK:
        LEA  DX, MSG_SINGLE_OK
SNG_PRINT:
        MOV  AH, 09H
        INT  21H
        LEA  DX, MSG_NEWLINE
        MOV  AH, 09H
        INT  21H
        RET
DEMO_SINGLE ENDP

; ===========================================================
; DEMO 4 – MEMORY-TO-MEMORY TRANSFER  (CH0 -> CH1)
; ----------------------------------------------------------
; Setting bit 7 of the mode register enables the 8257's
; built-in memory-to-memory path: CH0 reads the source,
; CH1 writes the destination – no I/O device involved.
;
; Mode byte = 80H (MEMTOMEM) | 01H (CH0_EN) | 02H (CH1_EN)
;           = 83H
;
; Programming sequence:
;   1. Reset 8257
;   2. Write CH0 address (source)       -> port 00H
;   3. Write CH0 count                  -> port 01H
;   4. Write CH1 address (destination)  -> port 02H
;   5. Write CH1 count                  -> port 03H
;   6. Write mode = 83H                 -> port 08H
;   [MOVSB models the on-chip DMA copy]
; ===========================================================
DEMO_MEM2MEM PROC NEAR
        ; ---- print section header ----
        LEA  DX, HDR4
        MOV  AH, 09H
        INT  21H

        ; ---- 1. Reset 8257 ----
        MOV  AL, 00H
        OUT  DMA_MODE_REG, AL

        ; ---- 2. CH0 address = SOURCE_BUF ----
        LEA  BX, SOURCE_BUF
        MOV  AL, BL
        OUT  DMA_CH0_ADDR, AL
        MOV  AL, BH
        OUT  DMA_CH0_ADDR, AL

        ; ---- 3. CH0 count ----
        MOV  AX, BLOCK_SIZE
        DEC  AX
        OUT  DMA_CH0_COUNT, AL
        MOV  AL, AH
        OUT  DMA_CH0_COUNT, AL

        ; ---- 4. CH1 address = SCRATCH_BUF ----
        LEA  BX, SCRATCH_BUF
        MOV  AL, BL
        OUT  DMA_CH1_ADDR, AL
        MOV  AL, BH
        OUT  DMA_CH1_ADDR, AL

        ; ---- 5. CH1 count ----
        MOV  AX, BLOCK_SIZE
        DEC  AX
        OUT  DMA_CH1_COUNT, AL
        MOV  AL, AH
        OUT  DMA_CH1_COUNT, AL

        ; ---- 6. Enable MEM-TO-MEM + CH0 + CH1 (mode = 83H) ----
        ; 83H = DMA_MEM2MEM(80H) | DMA_CH1_EN(02H) | DMA_CH0_EN(01H)
        MOV  AL, 083H
        OUT  DMA_MODE_REG, AL

        ; ---- 7. Simulate the on-chip DMA copy (CH0 -> CH1) ----
        LEA  SI, SOURCE_BUF
        LEA  DI, SCRATCH_BUF
        MOV  CX, BLOCK_SIZE
        CLD
        REP  MOVSB

        ; ---- 8. Verify SCRATCH_BUF == SOURCE_BUF ----
        LEA  SI, SOURCE_BUF
        LEA  DI, SCRATCH_BUF
        MOV  CX, BLOCK_SIZE
        CLD
        REPE CMPSB
        JNZ  M2M_FAIL

        LEA  DX, MSG_M2M_OK
        JMP  M2M_PRINT
M2M_FAIL:
        LEA  DX, MSG_M2M_FAIL
M2M_PRINT:
        MOV  AH, 09H
        INT  21H
        LEA  DX, MSG_NEWLINE
        MOV  AH, 09H
        INT  21H
        RET
DEMO_MEM2MEM ENDP

; ===========================================================
; VERIFY_DEST
; Compares SOURCE_BUF and DEST_BUF byte-by-byte.
; Returns CF=0 on match (success), CF=1 on mismatch (fail).
; Destroys: CX, SI, DI, flags
; ===========================================================
VERIFY_DEST PROC NEAR
        LEA  SI, SOURCE_BUF
        LEA  DI, DEST_BUF
        MOV  CX, BLOCK_SIZE
        CLD
        REPE CMPSB
        JNZ  VD_FAIL
        CLC                      ; match -> CF = 0
        RET
VD_FAIL:
        STC                      ; mismatch -> CF = 1
        RET
VERIFY_DEST ENDP

END MAIN
