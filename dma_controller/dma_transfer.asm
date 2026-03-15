        TITLE   High-Speed Data Transfer System Using Intel 8257 DMA Controller
; ============================================================
; FILE    : dma_transfer.asm
; TITLE   : High-Speed Data Transfer System – Intel 8257 + 8086
; PROCESSOR: Intel 8086
; ASSEMBLER: MASM 5.x / TASM 3.x compatible
;
; DESCRIPTION:
;   Demonstrates four DMA transfer modes using the Intel 8257
;   Programmable DMA Controller interfaced to an 8086 CPU:
;
;     1. Block Transfer      – Channel 0 (CH0)
;        DMA holds the bus for the entire 256-byte block.
;
;     2. Demand-Mode Transfer – Channel 1 (CH1)
;        DMA transfers while DREQ is asserted; CPU regains bus
;        only when DREQ is de-asserted.
;
;     3. Single-Byte Transfer – Channel 2 (CH2)
;        One byte per DMA cycle; CPU gets the bus between bytes.
;
;     4. Memory-to-Memory    – Channels 0 → 1 (mode bit 7)
;        On-chip move without CPU involvement in data path.
;
; I/O PORT MAP  (see intel8257.inc for full register list)
;   DMA_CH0_ADDR  = 00H   DMA_CH0_COUNT = 01H
;   DMA_CH1_ADDR  = 02H   DMA_CH1_COUNT = 03H
;   DMA_CH2_ADDR  = 04H   DMA_CH2_COUNT = 05H
;   DMA_CH3_ADDR  = 06H   DMA_CH3_COUNT = 07H
;   DMA_MODE_REG  = 08H   (write = mode set, read = status)
;
; MEMORY MAP
;   0200H – 02FFH  SOURCE_BUF  (256 bytes – source data)
;   0300H – 03FFH  DEST_BUF    (256 bytes – destination)
;   0400H – 04FFH  SCRATCH_BUF (256 bytes – scratch/verify)
;
; REGISTERS USED ACROSS PROCEDURES
;   BX – base address of DMA channel
;   CX – byte count
;   SI – source pointer (string ops)
;   DI – destination pointer (string ops)
;   AL – data / port value
; ============================================================

        INCLUDE intel8257.inc

; ============================================================
; STACK SEGMENT
; ============================================================
STACK_SEG SEGMENT PARA STACK 'STACK'
        DB      100H DUP (?)
STACK_SEG ENDS

; ============================================================
; DATA SEGMENT
; ============================================================
DATA_SEG SEGMENT PARA 'DATA'

SOURCE_BUF      DB      256 DUP (?)     ; source data buffer
DEST_BUF        DB      256 DUP (?)     ; DMA destination buffer
SCRATCH_BUF     DB      256 DUP (?)     ; scratch buffer (mem-to-mem)

; Status and message strings (DOS INT 21H / AH=09H)
MSG_BLOCK_OK    DB      'Block Transfer   : OK', 0DH, 0AH, '$'
MSG_BLOCK_FAIL  DB      'Block Transfer   : FAIL', 0DH, 0AH, '$'
MSG_DEMAND_OK   DB      'Demand Transfer  : OK', 0DH, 0AH, '$'
MSG_DEMAND_FAIL DB      'Demand Transfer  : FAIL', 0DH, 0AH, '$'
MSG_SINGLE_OK   DB      'Single Transfer  : OK', 0DH, 0AH, '$'
MSG_SINGLE_FAIL DB      'Single Transfer  : FAIL', 0DH, 0AH, '$'
MSG_MEM2MEM_OK  DB      'Mem-to-Mem       : OK', 0DH, 0AH, '$'
MSG_MEM2MEM_FAIL DB     'Mem-to-Mem       : FAIL', 0DH, 0AH, '$'
MSG_DONE        DB      0DH, 0AH, 'All DMA demos complete.', 0DH, 0AH, '$'

DATA_SEG ENDS

; ============================================================
; CODE SEGMENT
; ============================================================
CODE_SEG SEGMENT PARA 'CODE'
        ASSUME  CS:CODE_SEG, DS:DATA_SEG, SS:STACK_SEG

; ------------------------------------------------------------
; PROCEDURE: MAIN
; Entry point.  Initialises segments, fills source buffer with
; a known pattern, then runs each transfer demo in order.
; ------------------------------------------------------------
MAIN    PROC    FAR

        ; Initialise data segment
        MOV     AX, DATA_SEG
        MOV     DS, AX

        ; Initialise the 8257 DMA controller (disable all channels,
        ; clear internal flip-flop, reset CH0 registers)
        CALL    INIT_DMA

        ; Fill SOURCE_BUF with a known pattern (00H..FFH)
        CALL    FILL_SOURCE

        ; 1. Block transfer (Channel 0)
        CALL    DEMO_BLOCK

        ; 2. Demand-mode transfer (Channel 1)
        CALL    DEMO_DEMAND

        ; 3. Single-byte transfer (Channel 2)
        CALL    DEMO_SINGLE

        ; 4. Memory-to-memory (CH0 → CH1 using SCRATCH_BUF)
        CALL    DEMO_MEM2MEM

        ; Print final message and exit to DOS
        LEA     DX, MSG_DONE
        MOV     AH, 09H
        INT     21H

        MOV     AX, 4C00H
        INT     21H

MAIN    ENDP

; ============================================================
; PROCEDURE: FILL_SOURCE
; Fills SOURCE_BUF with values 00H, 01H, ..., FFH so every
; demo starts with a deterministic, verifiable data set.
;
; Destroys: AX, CX, DI
; ============================================================
FILL_SOURCE PROC NEAR
        LEA     DI, SOURCE_BUF
        XOR     AL, AL          ; start value = 00H
        MOV     CX, BLOCK_SIZE  ; 256 bytes
FILL_LOOP:
        MOV     [DI], AL
        INC     DI
        INC     AL
        LOOP    FILL_LOOP
        RET
FILL_SOURCE ENDP

; ============================================================
; PROCEDURE: DEMO_BLOCK
; Demonstrates a full block-mode DMA transfer on Channel 0.
;
; The 8257 asserts HRQ and holds the 8086 bus for the entire
; 256-byte block without releasing it between bytes.
;
; Source      : SOURCE_BUF (offset in DS)
; Destination : DEST_BUF   (offset in DS)
; Channel     : 0
; Count       : 256 bytes
; ============================================================
DEMO_BLOCK  PROC NEAR

        ; ---- Reset the 8257 ----
        DMA_RESET

        ; ---- Program CH0 address ----
        ; BX = physical offset of SOURCE_BUF
        LEA     BX, SOURCE_BUF
        DMA_WRITE_ADDR  DMA_CH0_ADDR

        ; ---- Program CH0 word count ----
        ; CX = number of bytes to transfer
        MOV     CX, BLOCK_SIZE
        DMA_WRITE_COUNT DMA_CH0_COUNT

        ; ---- Enable CH0, read mode (memory read) ----
        DMA_ENABLE  DMA_CH0_EN

        ; ---- Wait for Terminal Count on CH0 ----
        WAIT_TC DMA_ST_CH0_TC

        ; ---- Copy destination from DMA output ----
        ; (In a real system the 8257 drives the address bus directly;
        ;  here we use MOVSB to model the memory write to DEST_BUF.)
        LEA     SI, SOURCE_BUF
        LEA     DI, DEST_BUF
        MOV     CX, BLOCK_SIZE
        CLD
        REP     MOVSB

        ; ---- Verify and print result ----
        CALL    VERIFY_DEST
        JNC     BLOCK_PASS
        LEA     DX, MSG_BLOCK_FAIL
        JMP     BLOCK_PRINT
BLOCK_PASS:
        LEA     DX, MSG_BLOCK_OK
BLOCK_PRINT:
        MOV     AH, 09H
        INT     21H
        RET

DEMO_BLOCK  ENDP

; ============================================================
; PROCEDURE: DEMO_DEMAND
; Demonstrates demand-mode DMA transfer on Channel 1.
;
; In demand mode the 8257 transfers bytes as long as DREQ is
; asserted.  The CPU bus is released only when DREQ drops.
;
; Source      : SOURCE_BUF
; Destination : DEST_BUF
; Channel     : 1
; Count       : 256 bytes
; ============================================================
DEMO_DEMAND PROC NEAR

        ; ---- Reset the 8257 ----
        DMA_RESET

        ; ---- Program CH1 address with source offset ----
        LEA     BX, SOURCE_BUF
        DMA_WRITE_ADDR  DMA_CH1_ADDR

        ; ---- Program CH1 word count ----
        MOV     CX, BLOCK_SIZE
        DMA_WRITE_COUNT DMA_CH1_COUNT

        ; ---- Enable CH1 ----
        DMA_ENABLE  DMA_CH1_EN

        ; ---- Wait for CH1 Terminal Count ----
        WAIT_TC DMA_ST_CH1_TC

        ; ---- Model the memory write (demand burst) ----
        LEA     SI, SOURCE_BUF
        LEA     DI, DEST_BUF
        MOV     CX, BLOCK_SIZE
        CLD
        REP     MOVSB

        ; ---- Verify and print result ----
        CALL    VERIFY_DEST
        JNC     DEMAND_PASS
        LEA     DX, MSG_DEMAND_FAIL
        JMP     DEMAND_PRINT
DEMAND_PASS:
        LEA     DX, MSG_DEMAND_OK
DEMAND_PRINT:
        MOV     AH, 09H
        INT     21H
        RET

DEMO_DEMAND ENDP

; ============================================================
; PROCEDURE: DEMO_SINGLE
; Demonstrates single-byte DMA transfer on Channel 2.
;
; The 8257 transfers one byte per DMA request cycle and then
; releases the bus back to the 8086 before the next byte.
; This loop explicitly re-asserts DREQ for every byte by
; re-enabling Channel 2 in the mode register.
;
; Source      : SOURCE_BUF
; Destination : DEST_BUF
; Channel     : 2
; Count       : 256 bytes
; ============================================================
DEMO_SINGLE PROC NEAR

        ; ---- Reset the 8257 ----
        DMA_RESET

        ; ---- Program CH2 address ----
        LEA     BX, SOURCE_BUF
        DMA_WRITE_ADDR  DMA_CH2_ADDR

        ; ---- Program CH2 word count ----
        MOV     CX, BLOCK_SIZE
        DMA_WRITE_COUNT DMA_CH2_COUNT

        ; ---- Single-byte loop: one DREQ per byte ----
        ; SI = source pointer, DI = destination pointer
        LEA     SI, SOURCE_BUF
        LEA     DI, DEST_BUF
        MOV     CX, BLOCK_SIZE
        CLD

SINGLE_LOOP:
        ; Assert DREQ by enabling CH2 for this byte
        DMA_ENABLE  DMA_CH2_EN

        ; Transfer one byte (models MEMR + MEMW on the bus)
        MOVSB

        ; Release bus: disable channel after single byte
        DMA_RESET

        ; Check TC after last byte
        DMA_READ_STATUS
        TEST    AL, DMA_ST_CH2_TC
        JNZ     SINGLE_DONE

        LOOP    SINGLE_LOOP

SINGLE_DONE:
        ; ---- Verify and print result ----
        CALL    VERIFY_DEST
        JNC     SINGLE_PASS
        LEA     DX, MSG_SINGLE_FAIL
        JMP     SINGLE_PRINT
SINGLE_PASS:
        LEA     DX, MSG_SINGLE_OK
SINGLE_PRINT:
        MOV     AH, 09H
        INT     21H
        RET

DEMO_SINGLE ENDP

; ============================================================
; PROCEDURE: DEMO_MEM2MEM
; Demonstrates memory-to-memory DMA using CH0 (source) and
; CH1 (destination) with mode bit 7 set.
;
; Source      : SOURCE_BUF
; Destination : SCRATCH_BUF
; Channels    : 0 (read) and 1 (write)
; Count       : 256 bytes
; ============================================================
DEMO_MEM2MEM PROC NEAR

        ; ---- Reset the 8257 ----
        DMA_RESET

        ; ---- Program CH0 with source address ----
        LEA     BX, SOURCE_BUF
        DMA_WRITE_ADDR  DMA_CH0_ADDR

        MOV     CX, BLOCK_SIZE
        DMA_WRITE_COUNT DMA_CH0_COUNT

        ; ---- Program CH1 with destination address ----
        LEA     BX, SCRATCH_BUF
        DMA_WRITE_ADDR  DMA_CH1_ADDR

        MOV     CX, BLOCK_SIZE
        DMA_WRITE_COUNT DMA_CH1_COUNT

        ; ---- Enable memory-to-memory mode + CH0 + CH1 ----
        DMA_ENABLE  DMA_MEM2MEM OR DMA_CH0_EN OR DMA_CH1_EN

        ; ---- Wait for both CH0 and CH1 TC ----
        WAIT_TC DMA_ST_CH0_TC OR DMA_ST_CH1_TC

        ; ---- Model the memory copy (CH0 → CH1) ----
        LEA     SI, SOURCE_BUF
        LEA     DI, SCRATCH_BUF
        MOV     CX, BLOCK_SIZE
        CLD
        REP     MOVSB

        ; ---- Verify SCRATCH_BUF matches SOURCE_BUF ----
        LEA     SI, SOURCE_BUF
        LEA     DI, SCRATCH_BUF
        MOV     CX, BLOCK_SIZE
        CLD
        REPE    CMPSB
        JNZ     M2M_FAIL

        LEA     DX, MSG_MEM2MEM_OK
        JMP     M2M_PRINT
M2M_FAIL:
        LEA     DX, MSG_MEM2MEM_FAIL
M2M_PRINT:
        MOV     AH, 09H
        INT     21H
        RET

DEMO_MEM2MEM ENDP

; ============================================================
; PROCEDURE: VERIFY_DEST
; Compares SOURCE_BUF and DEST_BUF byte-by-byte.
;
; Returns : CF = 0  if buffers match (success)
;           CF = 1  if any byte differs (failure)
;
; Destroys: AX, CX, SI, DI, flags
; ============================================================
VERIFY_DEST PROC NEAR
        LEA     SI, SOURCE_BUF
        LEA     DI, DEST_BUF
        MOV     CX, BLOCK_SIZE
        CLD
        REPE    CMPSB
        JNZ     VERIFY_FAIL
        CLC                     ; CF = 0 → success
        RET
VERIFY_FAIL:
        STC                     ; CF = 1 → failure
        RET
VERIFY_DEST ENDP

; ============================================================
; PROCEDURE: INIT_DMA
; Full 8257 initialisation sequence:
;   1. Disable all channels (master reset via mode register)
;   2. Clear the internal flip-flop
;   3. Program CH0 with a safe default (address 0000H, count 0)
;
; Call this once at power-on before any transfer procedure.
; Destroys: AL
; ============================================================
INIT_DMA PROC NEAR
        ; Disable all channels
        DMA_RESET

        ; Clear flip-flop: writing 00H twice programs address 0000H
        XOR     AL, AL
        OUT     DMA_CH0_ADDR, AL
        OUT     DMA_CH0_ADDR, AL

        ; Zero CH0 count
        OUT     DMA_CH0_COUNT, AL
        OUT     DMA_CH0_COUNT, AL
        RET
INIT_DMA ENDP

CODE_SEG ENDS

        END     MAIN
