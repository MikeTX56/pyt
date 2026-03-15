; ============================================================
; FILE    : intel8257.inc
; TITLE   : Intel 8257 DMA Controller – Constants and Macros
; CPU     : Intel 8086
; ASSEMBLER: MASM / TASM compatible
; ============================================================
;
; I/O PORT MAP (base address = 00H, chip-select from address decoder)
; -----------------------------------------------------------------
;  Port  Register
;  00H   Channel 0 – Base Address / Current Address  (16-bit, 2 writes)
;  01H   Channel 0 – Base Word Count / Current Count (16-bit, 2 writes)
;  02H   Channel 1 – Base Address / Current Address
;  03H   Channel 1 – Base Word Count / Current Count
;  04H   Channel 2 – Base Address / Current Address
;  05H   Channel 2 – Base Word Count / Current Count
;  06H   Channel 3 – Base Address / Current Address
;  07H   Channel 3 – Base Word Count / Current Count
;  08H   Mode Set Register (WRITE)  /  Status Register (READ)
; ============================================================

; ----------------------------------------------------------
; Channel address-register I/O ports
; ----------------------------------------------------------
DMA_CH0_ADDR    EQU  00H
DMA_CH0_COUNT   EQU  01H
DMA_CH1_ADDR    EQU  02H
DMA_CH1_COUNT   EQU  03H
DMA_CH2_ADDR    EQU  04H
DMA_CH2_COUNT   EQU  05H
DMA_CH3_ADDR    EQU  06H
DMA_CH3_COUNT   EQU  07H
DMA_MODE_REG    EQU  08H    ; Mode Set (W) / Status (R)

; ----------------------------------------------------------
; Mode Set Register bit definitions (write to port 08H)
; ----------------------------------------------------------
;  Bit 7 : MEMTOMEM  – Memory-to-Memory transfer enable (CH0->CH1)
;  Bit 6 : AUTOLOAD  – Auto-Load / CH2-CH3 stop-on-TC
;  Bit 5 : EXWRITE   – Extended write select
;  Bit 4 : ROTATPRI  – Rotating priority among channels
;  Bit 3 : CH3_EN    – Enable Channel 3
;  Bit 2 : CH2_EN    – Enable Channel 2
;  Bit 1 : CH1_EN    – Enable Channel 1
;  Bit 0 : CH0_EN    – Enable Channel 0
; ----------------------------------------------------------
DMA_CH0_EN      EQU  01H
DMA_CH1_EN      EQU  02H
DMA_CH2_EN      EQU  04H
DMA_CH3_EN      EQU  08H
DMA_ROTATPRI    EQU  10H
DMA_EXWRITE     EQU  20H
DMA_AUTOLOAD    EQU  40H
DMA_MEM2MEM     EQU  80H

; ----------------------------------------------------------
; Status Register bit definitions (read from port 08H)
; Reading clears the TC bits.
; ----------------------------------------------------------
;  Bit 7-4 : Reserved
;  Bit 3   : CH3 Terminal Count reached
;  Bit 2   : CH2 Terminal Count reached
;  Bit 1   : CH1 Terminal Count reached
;  Bit 0   : CH0 Terminal Count reached
; ----------------------------------------------------------
DMA_ST_CH0_TC   EQU  01H
DMA_ST_CH1_TC   EQU  02H
DMA_ST_CH2_TC   EQU  04H
DMA_ST_CH3_TC   EQU  08H

; ----------------------------------------------------------
; Transfer sizes used in this project
; ----------------------------------------------------------
BLOCK_SIZE      EQU  0100H   ; 256 bytes per transfer block

; ----------------------------------------------------------
; MACRO: DMA_RESET
; Purpose : Disable all channels (write 00H to mode register).
;           The 8257 flip-flop is also reset so the next address/
;           count write starts from the low byte.
; Destroys: AL
; ----------------------------------------------------------
DMA_RESET MACRO
    MOV  AL, 00H
    OUT  DMA_MODE_REG, AL
ENDM

; ----------------------------------------------------------
; MACRO: DMA_WRITE_ADDR  port, offset_reg
; Purpose : Write a 16-bit address (stored in BX) to an 8257
;           address register in two successive OUT instructions
;           (low byte first, then high byte).
; Parameters:
;   port – the channel address port constant (e.g. DMA_CH0_ADDR)
; Requires: BX = 16-bit address to program
; Destroys: AL
; ----------------------------------------------------------
DMA_WRITE_ADDR MACRO port
    MOV  AL, BL             ;; low byte of address
    OUT  port,  AL
    MOV  AL, BH             ;; high byte of address
    OUT  port,  AL
ENDM

; ----------------------------------------------------------
; MACRO: DMA_WRITE_COUNT  port
; Purpose : Write a 16-bit word count (CX - 1) to an 8257
;           count register in two successive OUT instructions.
; Requires: CX = number of bytes to transfer
; Destroys: AL, DX
; ----------------------------------------------------------
DMA_WRITE_COUNT MACRO port
    MOV  DX, CX
    DEC  DX                 ;; 8257 stores (count - 1)
    MOV  AL, DL             ;; low byte
    OUT  port, AL
    MOV  AL, DH             ;; high byte
    OUT  port, AL
ENDM

; ----------------------------------------------------------
; MACRO: DMA_ENABLE  mode_byte
; Purpose : Write the mode/command byte to port 08H, enabling
;           the desired channel(s) and transfer options.
; Parameters:
;   mode_byte – immediate value for the mode register
; Destroys: AL
; ----------------------------------------------------------
DMA_ENABLE MACRO mode_byte
    MOV  AL, mode_byte
    OUT  DMA_MODE_REG, AL
ENDM

; ----------------------------------------------------------
; MACRO: DMA_READ_STATUS
; Purpose : Read the 8257 status register into AL.
;           Reading clears all TC flags.
; Destroys: AL
; ----------------------------------------------------------
DMA_READ_STATUS MACRO
    IN   AL, DMA_MODE_REG
ENDM

; ----------------------------------------------------------
; MACRO: WAIT_TC  channel_mask
; Purpose : Poll the status register until the Terminal Count
;           flag for the specified channel is set.
; Parameters:
;   channel_mask – e.g. DMA_ST_CH0_TC for channel 0
; Destroys: AL
; ----------------------------------------------------------
WAIT_TC MACRO channel_mask
LOCAL POLL_LOOP
POLL_LOOP:
    IN   AL, DMA_MODE_REG
    TEST AL, channel_mask
    JZ   POLL_LOOP
ENDM
