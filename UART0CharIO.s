      TTL UART0CharIO.s - Serial I/O Driver
;****************************************************************
;This module implements a driver to do serial I/O over the 
; OpenSDA port via the UART0. This module uses interrupt
; service routines (ISRs) to reduce the likelihood that a
; character is lost while the program is doing something else.
;This module can be installed by including this file and setting
; the interrupt vector 28 to the UART0_ISR handler in this file
; for pure assembly projects. It automagically installs for 
; projects with the Device>Startup package installed.
;The development of code presented in this module was 
; significantly aided with tutorials and instruction given in
; RIT's CMPE-250. I don't take any credit for most of the
; work in this file.
;Name:  Koen Komeya
;Date:  November 2, 2017
;Class:  CMPE-250
;Section:  Lab Section 4: Thursday 11 AM - 1 PM
;---------------------------------------------------------------
;Revision 1 (November 6, 2017): Removed unnecessary interrupt
; clearing code from UART0 Interrupt Service Routine.
;Revision 2 (November 8, 2017): Modularized the serial I/O
; driver and changed some magic numbers into their constant 
; representations.
;Revision 3 (November 21, 2017): Modified file to automatically
; install when added to projects with the Device>Startup 
; package installed.
;Revision 4 (November 21, 2017): Removed unnecessary buffer 
; symbols and copied an assembler directive telling the compiler
; that this is for a mixed assembly-C program.
;Revision 5 (November 24, 2017): Modified spacing of 
; instructions to be more uniform.
;Revision 6 (November 25, 2017): Fixed a problem with the header
; comment and fixed a small potential bug with the interrupt 
; service routine.
;---------------------------------------------------------------
;Adopted from Keil Template for KL46
;R. W. Melton
;September 25, 2017
;****************************************************************
;Assembler directives
            THUMB
            GBLL  MIXED_ASM_C 
MIXED_ASM_C SETL  {TRUE}
            OPT    64  ;Turn on listing macro expansions
;****************************************************************
;Include files
            GET  MKL46Z4.s     ;Included by start.s
            OPT  1   ;Turn on listing
;****************************************************************
;EQUates
; imported from a Useful EQUates file supplied by Dr. Melton 
;---------------------------------------------------------------
;NVIC_ICER
;31-00:CLRENA=masks for HW IRQ sources;
;             read:   0 = unmasked;   1 = masked
;             write:  0 = no effect;  1 = mask
;12:UART0 IRQ mask
NVIC_ICER_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;NVIC_ICPR
;31-00:CLRPEND=pending status for HW IRQ sources;
;             read:   0 = not pending;  1 = pending
;             write:  0 = no effect;
;                     1 = change status to not pending
;12:UART0 IRQ pending status
NVIC_ICPR_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;NVIC_IPR0-NVIC_IPR7
;2-bit priority:  00 = highest; 11 = lowest
NVIC_IPR_UART0_MASK   EQU (3 << UART0_PRI_POS)
NVIC_IPR_UART0_PRI    EQU (UART0_IRQ_PRIORITY << UART0_PRI_POS)
;---------------------------------------------------------------
;NVIC_ISER
;31-00:SETENA=masks for HW IRQ sources;
;             read:   0 = masked;     1 = unmasked
;             write:  0 = no effect;  1 = unmask
;12:UART0 IRQ mask
NVIC_ISER_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;PORTx_PCRn (Port x pin control register n [for pin n])
;___->10-08:Pin mux control (select 0 to 8)
;Use provided PORT_PCR_MUX_SELECT_2_MASK
;---------------------------------------------------------------
;Port A
PORT_PCR_SET_PTA1_UART0_RX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
PORT_PCR_SET_PTA2_UART0_TX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
;---------------------------------------------------------------
;SIM_SCGC4
;1->10:UART0 clock gate control (enabled)
;Use provided SIM_SCGC4_UART0_MASK
;---------------------------------------------------------------
;SIM_SCGC5
;1->09:Port A clock gate control (enabled)
;Use provided SIM_SCGC5_PORTA_MASK
;---------------------------------------------------------------
;SIM_SOPT2
;01=27-26:UART0SRC=UART0 clock source select
;         (PLLFLLSEL determines MCGFLLCLK' or MCGPLLCLK/2)
; 1=   16:PLLFLLSEL=PLL/FLL clock select (MCGPLLCLK/2)
SIM_SOPT2_UART0SRC_MCGPLLCLK  EQU  \
                                 (1 << SIM_SOPT2_UART0SRC_SHIFT)
SIM_SOPT2_UART0_MCGPLLCLK_DIV2 EQU \
    (SIM_SOPT2_UART0SRC_MCGPLLCLK :OR: SIM_SOPT2_PLLFLLSEL_MASK)
;---------------------------------------------------------------  
;SIM_SOPT5
; 0->   16:UART0 open drain enable (disabled)
; 0->   02:UART0 receive data select (UART0_RX)
;00->01-00:UART0 transmit data select source (UART0_TX)
SIM_SOPT5_UART0_EXTERN_MASK_CLEAR  EQU  \
                               (SIM_SOPT5_UART0ODE_MASK :OR: \
                                SIM_SOPT5_UART0RXSRC_MASK :OR: \
                                SIM_SOPT5_UART0TXSRC_MASK)
; End import                 
;UART0_BDH~UART_BDL
; VAL ->BIT
;  0  -> 15 :LBKDIE : Disable interrupts for LIN Break Detection
;  0  -> 14 :RXEDGIE: Disable interrupts for active edges on RX Input
;  0  -> 13 : SBNS  : Use 1 Stop Bit
;0x271->12-0:  SBR  : Baud Rate Modulo Divisor = 125 (Makes Baud Rate 96000)
IUP_BD_96000   EQU     0x7D00   ;reordered BDL then BDH (little endian shenanigans)
IUP_BD_480000  EQU     0x1900   ;reordered BDL then BDH (little endian shenanigans)
;UART0_C1 
; VAL->BIT
;  0 -> 7 :LOOPS : Don't use Loop Mode
;  0 -> 6 :DOZEEN: UART enable in wait mode
;  0 -> 5 : RSRC : Doesn't matter because Loop Mode is disabled
;  0 -> 4 :  M   : Using 8-bit Data
;  0 -> 3 : WAKE : Idle-line Wakeup
;  0 -> 2 : ILT  : Idle character bit count starts after start bit
;  0 -> 1 :  PE  : No parity generation or checking
;  0 -> 0 :  PT  : Doesn't matter because no parity gen/check
;UART0_C2 (disabling Transmitter/Receiver)
; VAL->BIT
;  0 -> 7 :TIE : Disable interrupts for Transmit Data Register Empty
;  0 -> 6 :TCIE: Disable interrupts for Transmit Complete 
;  0 -> 5 :RIE : Disable interrupts for Reciever Data Register Full
;  0 -> 4 :ILIE: Disable interrupts for IDLE
;  0 -> 3 : TE : Disable Transmitter
;  0 -> 2 : RE : Disable Receiver 
;  0 -> 1 :RWU : Don't put Receiver in standby mode until data recieve (~RWU)
;  0 -> 0 :SBK : Don't queue break characters.
;UART0_C3
; VAL->BIT:
;  0 -> 7 :R98T : Doesn't matter because we are dealing with 8-bit data
;  0 -> 6 :R9T8 : Doesn't matter because we are dealing with 8-bit data
;  0 -> 5 :TXDIR: Doesn't matter because Loop Mode is disabled
;  0 -> 4 :TXINV: Don't invert data
;  0 -> 3 :ORIE : Doesn't matter because (~RWU) receiver is not set to use RWU functionality
;  0 -> 2 :NEIE : Disable interrupts for Noise
;  0 -> 1 :FEIE : Disable interrupts for Framing Errors
;  0 -> 0 :PEIE : Disable interrupts for Parity Errors
;UART0_C5
; VAL->BIT
;  0 -> 7 :  TDMAE  : Don't generate DMA Request when Transmit Data Register is Empty
;  0 -> 6 :Reserved : No effect (Reserved)
;  0 -> 5 :  RDMAE  : Don't generate DMA Request when Receive Data Register is Full
;  0 ->4-2:Reserved : No effect (Reserved)
;  0 -> 1 :BOTHEDGE : Receiver samples input data using rising edge of baud rate clock.
;  0 -> 0 :RESYNCDIS: Resynchronization of receieved data every word is enabled.
IUP_ZERO        EQU     0x00
;UART0_C2 (enabling Transmitter/Receiver) No Interrupts
; VAL->BIT
;  0 -> 7 : TIE  : Disable interrupts for Transmit Data Register Empty
;  0 -> 6 : TCIE : Disable interrupts for Transmit Complete 
;  0 -> 5 : RIE  : Disable interrupts for Reciever Data Register Full
;  0 -> 4 : ILIE : Disable interrupts for IDLE
;  1 -> 3 :  TE  : Enable Transmitter
;  1 -> 2 :  RE  : Enable Receiver 
;  0 -> 1 : RWU  : Don't put Receiver in standby mode until data recieve (~RWU)
;  0 -> 0 : SBK  : Don't queue break characters.
IUP_C2_EN_ID    EQU     (UART0_C2_TE_MASK :OR: UART0_C2_RE_MASK)  
;UART0_C2 (enabling Transmitter/Receiver) Reciever Interrupts Only
; VAL->BIT
;  0 -> 7 : TIE  : Enable interrupts for Transmit Data Register Empty
;  0 -> 6 : TCIE : Disable interrupts for Transmit Complete 
;  1 -> 5 : RIE  : Enable interrupts for Reciever Data Register Full
;  0 -> 4 : ILIE : Disable interrupts for IDLE
;  1 -> 3 :  TE  : Enable Transmitter
;  1 -> 2 :  RE  : Enable Receiver 
;  0 -> 1 : RWU  : Don't put Receiver in standby mode until data recieve (~RWU)
;  0 -> 0 : SBK  : Don't queue break characters.
IUP_C2_EN_RIE   EQU     0x2C   
;UART0_C2 (enabling Transmitter/Receiver) Transmitter and Reciever Interrupts
; VAL->BIT
;  1 -> 7 : TIE  : Enable interrupts for Transmit Data Register Empty
;  0 -> 6 : TCIE : Disable interrupts for Transmit Complete 
;  1 -> 5 : RIE  : Enable interrupts for Reciever Data Register Full
;  0 -> 4 : ILIE : Disable interrupts for IDLE
;  1 -> 3 :  TE  : Enable Transmitter
;  1 -> 2 :  RE  : Enable Receiver 
;  0 -> 1 : RWU  : Don't put Receiver in standby mode until data recieve (~RWU)
;  0 -> 0 : SBK  : Don't queue break characters.
IUP_C2_EN_TRIE  EQU     0xAC     
;UART0_C4
; VAL ->BIT
; 00  -> 7 :MAEN: Don't filter recieved data.
;  0  -> 6 :M10 : Don't use 10-bit Mode
;00111->5-0:OSR : Use an oversampling ratio of {0x3+1=} 4. (Makes Baud Rate 96000)     
IUP_C4_96000   EQU     0x03
IUP_C4_480000  EQU     0x03
;UART0_S1
; VAL->BIT
;  0 -> 7 :TDRE: No effect (Read-only)
;  0 -> 6 : TC : No effect (Read-only)
;  0 -> 5 :RDRF: No effect (Read-only)
;  1 -> 4 :IDLE: Clear Idle Line Flag
;  1 -> 3 : OR : Clear Receiver Overrun Flag
;  1 -> 2 : NF : Clear Noise Flag
;  1 -> 1 : FE : Clear Framing Error Flag
;  1 -> 0 : PF : Clear Parity Error Flag
;UART0_S2
; VAL->BIT
;  1 -> 7 :LBKDIF : Clear LIN Break Detect Interrupt Flag
;  1 -> 6 :RXEDGIF: Clear Flag for detection of Active Edges on UART_RX pin.
;  0 -> 5 : MSBF  : Don't reverse order of bits.
;  0 -> 4 : RXINV : Don't invert polarity of received data
;  0 -> 3 : RWUID : Doesn't matter because (~RWU) receiver is not set to use RWU functionality
;  0 -> 2 : BRK13 : Break character transmitted with length of 10 bit times.
;  0 -> 1 : LBKDE : Break character is detected at length 10 bit times.
;  0 -> 0 :  RAF  : No effect
IUP_S1_CLR_FL_S2_CLR_FL     EQU     0xC01F     ;S2 then S1 
    
SIM_BASE_OFF_1000           EQU     (SIM_BASE + 0x1000)
SIM_SOPT2_ALT_OFFSET        EQU     (SIM_SOPT2_OFFSET - 0x1000)
SIM_SOPT5_ALT_OFFSET        EQU     (SIM_SOPT5_OFFSET - 0x1000)
SIM_SCGC4_ALT_OFFSET        EQU     (SIM_SCGC4_OFFSET - 0x1000)
SIM_SCGC5_ALT_OFFSET        EQU     (SIM_SCGC5_OFFSET - 0x1000)
    
;Interrupt Options
UART0_IRQ_PRIORITY          EQU     1
	
;Shift required to move the TDRE bit to the carry with an LSRS
UA0ISR_UART0_S1_TDRE_SHIFT_2C   EQU     (UART0_S1_TDRE_SHIFT + 1)
;Shift required to move the RDRF bit to the carry with an LSRS           
UA0ISR_UART0_S1_RDRF_SHIFT_2C   EQU     (UART0_S1_RDRF_SHIFT + 1)
;Shift required to move the TIE bit to the carry with an LSRS           
UA0ISR_UART0_C2_TIE_SHIFT_2C    EQU     (UART0_C2_TIE_SHIFT + 1)

;Characters
ESCAPE                      EQU     0x1B
DELETE                      EQU     0x7F

; struct queue{
;     byte *in_ptr
;     byte *out_ptr
;     byte *buf_strt
;     byte *buf_past
;     byte buf_size
;     byte num_enqd
; }
QO_IN_PTR   EQU     0   ;Queue Offset for INput PoinTeR  (word)
QO_OUT_PTR  EQU     4   ;Queue Offset for OUTput PoinTeR  (word)
QO_BUF_STRT EQU     8   ;Queue Offset for BUFfer's STaRT address (word) 
QO_BUF_PAST EQU     12  ;Queue Offset for address PAST BUFfer end (word)
QO_BUF_SIZE EQU     16  ;Queue Offset for BUFfer's SIZE (byte)
QO_NUM_ENQD EQU     18  ;Queue Offset for NUMber of elements ENQueueD (byte)
Q_SIZEOF    EQU     20  ;sizeof(queue)
	
IOQBUF_SIZE EQU     512 ;80
;****************************************************************
            AREA    CharIOCode,CODE,READONLY
            EXPORT  Init_UART0_IRQ
            EXPORT  GetChar
            EXPORT  PutChar
            EXPORT  GetStringSB
            EXPORT  PutStringSB
            EXPORT  PutNumHex
            EXPORT  PutNumU
            EXPORT  PutNumUB
            EXPORT  UART0_ISR
            EXPORT  UART0_IRQHandler
            EXPORT  Flush
		    EXPORT  DIVU
;Subroutine Init_UART0_IRQ
; Initializes the UART0 for interrupt-based serial I/O with 8 data bits,
; no parity, and one stop bit at 96000 baud.
; Inputs
;  NONE
; Outputs
;  NONE
; Modified: APSR
Init_UART0_IRQ  PROC    {R0-R14}
            PUSH    {R0-R2,LR}
;Initialize Queues
            LDR     R0,=RxQBuffer
            LDR     R1,=RxQRecord
            LDR     R2,=IOQBUF_SIZE
            BL      InitQueue
            LDR     R0,=TxQBuffer
            LDR     R1,=TxQRecord
            ;MOVS    R2,#IOQBUF_SIZE
            BL      InitQueue
;Do UART0 stuff 
            ;Select GPLLCLK / 2 as UART0 clock source 
            LDR     R0,=SIM_BASE_OFF_1000
            LDR     R1,[R0,#SIM_SOPT2_ALT_OFFSET]
            LDR     R2,=SIM_SOPT2_UART0SRC_MASK
            BICS    R1,R1,R2
            LDR     R2,=SIM_SOPT2_UART0_MCGPLLCLK_DIV2
            ORRS    R1,R1,R2
            STR     R1,[R0,#SIM_SOPT2_ALT_OFFSET]
            ;Enable external connection for UART0
            LDR     R1,[R0,#SIM_SOPT5_ALT_OFFSET]
            LDR     R2,=SIM_SOPT5_UART0_EXTERN_MASK_CLEAR 
            BICS    R1,R1,R2
            STR     R1,[R0,#SIM_SOPT5_ALT_OFFSET]   
            ;Enable clock for UART0 module 
            LDR     R1,[R0,#SIM_SCGC4_ALT_OFFSET]
            LDR     R2,=SIM_SCGC4_UART0_MASK 
            ORRS    R1,R1,R2
            STR     R1,[R0,#SIM_SCGC4_ALT_OFFSET]   
            ;Enable clock for Port A module
            LDR     R1,[R0,#SIM_SCGC5_ALT_OFFSET]
            LDR     R2,=SIM_SCGC5_PORTA_MASK
            ORRS    R1,R1,R2
            STR     R1,[R0,#SIM_SCGC5_ALT_OFFSET] 
            ;Connect PORT A Pin 1 (PTA1) to UART0 Rx (J1 Pin 02)
            LDR     R0,=PORTA_BASE
            LDR     R1,=PORT_PCR_SET_PTA1_UART0_RX
            STR     R1,[R0,#PORTA_PCR1_OFFSET]
            ;Connect PORT A Pin 2 (PTA2) to UART0 Tx (J1 Pin 04) 
            LDR     R1,=PORT_PCR_SET_PTA2_UART0_TX
            STR     R1,[R0,#PORTA_PCR2_OFFSET]
            ;NVIC 
            ;Set UART0 IRQ Priority
            LDR     R0,=UART0_IPR
            LDR     R1,=NVIC_IPR_UART0_MASK
            LDR     R2,[R0,#0]
            BICS    R2,R2,R1
            LDR     R1,=NVIC_IPR_UART0_PRI
            ORRS    R2,R2,R1
            STR     R2,[R0,#0]
            ;Clear Pending UART0 interrupts
            LDR     R0,=NVIC_ICPR
            LDR     R1,=NVIC_ICPR_UART0_MASK
            STR     R1,[R0,#0]
            ;Unmask ("Enable") UART0 interrupts
            LDR     R0,=NVIC_ISER
            LDR     R1,=NVIC_ISER_UART0_MASK
            STR     R1,[R0,#0]
            ;UART0
            LDR     R0,=UART0_BASE
            ;Disable the UART during setup
            MOVS    R2,#IUP_ZERO                
            STRB    R2,[R0,#UART0_C2_OFFSET]
            ;Set Baud Rate Modulo Divisor and Oversampling Ratio.
            ;The values are chosen such that the baud rate essentially equals 9600.
            ; (Baud Rate = Baud clock / (BDR * (OSR + 1))
            LDR     R1,=IUP_BD_480000               
            STRH    R1,[R0,#UART0_BDH_OFFSET]   ;(This sets BDH and BDL at the same time)
            ;Initialize UART0
            STRB    R2,[R0,#UART0_C1_OFFSET]    ;Initialize UART C1 = 0
            STRB    R2,[R0,#UART0_C3_OFFSET]    ;Initialize UART C3 = 0
            MOVS    R1,#IUP_C4_480000            ;Initialize UART C4
            STRB    R1,[R0,#UART0_C4_OFFSET]
            STRB    R2,[R0,#UART0_C5_OFFSET]    ;Initialize UART C5 = 0
            LDR     R1,=IUP_S1_CLR_FL_S2_CLR_FL ;Clear Flags on UART S1 and UART S2
            STRH    R1,[R0,#UART0_S1_OFFSET]    ;(This sets S1 and S2 at the same time)
            ;Reenable UART
            LDR     R0,=UART0_BASE
            MOVS    R1,#IUP_C2_EN_RIE           ;Interrupts for only recieve     
            STRB    R1,[R0,#UART0_C2_OFFSET]
            POP     {R0-R2,PC}                  ;Return
            ENDP 
;Subroutine GetChar
; Blocking read for a character from the UART0
; Inputs
;  NONE
; Outputs
;  R0 - Character read (byte)
; Modified: R0, APSR
GetChar     PROC    {R1-R14}
            PUSH    {R1,LR}
            ;Loop for data
            LDR     R1,=RxQRecord           
GC_Loop     CPSID   I
            BL      Dequeue
            CPSIE   I
            BCS     GC_Loop              ;If still empty loop back
            ; We got data
            POP     {R1,PC}
            ENDP
					
;Subroutine GetCharPrintable
; Blocking read for a non-control character from the UART0.
; Inputs
;  NONE
; Outputs
;  R0 - Character read (byte)
; Modified: R0, APSR
GetCharPrintable PROC    {R1-R14}
            PUSH    {R1,LR}
GCP_Loop	
            BL      GetChar
            CMP     R0,#ESCAPE
GCP_EscapeIf    
            BNE     GCP_EscapeEnd   ; if (char is escape){
GCP_EscapeLoop 
            BL      GetChar
            CMP     R0,#'~'         ;     keep eating characters until we hit the tilde (end of sequence)
            BNE     GCP_EscapeLoop
            B       GCP_Loop
GCP_EscapeEnd
            CMP     R0,#0x20        ;Don't accept other control characters
            BLO     GCP_Loop
            CMP     R0,#DELETE
            BEQ     GCP_Loop
            POP     {R1,PC}
            ENDP
					
;Subroutine PutChar
; Blocking write for a character to the UART0
; Inputs
;  R0 - Character to write (byte)
; Outputs
;  NONE
; Modified: APSR
PutChar     PROC    {R0-R14}
            PUSH    {R1-R3,LR}
            ;Loop for data
            LDR     R1,=TxQRecord   
            LDR     R2,=UART0_C2           
PC_Loop     CPSID   I
            ;Mask TransmitInterrupt
            MOVS    R3,#IUP_C2_EN_TRIE
            STRB    R3,[R2,#0]
            BL      Enqueue
            CPSIE   I
            BCS     PC_Loop              ;If still full loop back
            ; Data is sent
            POP     {R1-R3,PC}
            ENDP
;Subroutine GetStringSB
; Blocking read for a NUL-terminated string from the UART0
; Inputs
;  R0 - Pointer to buffer to fill (byte*)
;  R1 - Buffer Length (unsigned word)
; Outputs
;  NONE 
; Modified: APSR
GetStringSB PROC    {R0-R14}
;R2 is used to represent the current offset in the buffer
;R3 is used to hold the buffer pointer
            PUSH    {R0-R3,LR}
            MOVS    R2,#0           ;Initializes R2 to 0
            MOV     R3,R0           ;Moves the buffer pointer to R3.
            SUBS    R1,R1,#1        ; Subtracts 1 from length for NUL char.
GSSB_LpSt       
            BL      GetChar         ;Reads char
            CMP     R0,#'\r'        ;If the character is carriage return, break loop
            BEQ     GSSB_LpNd
            CMP     R0,#ESCAPE
GSSB_EscapeIf   
            BNE     GSSB_EscapeElse ; if (char is escape){
GSSB_EscapeLoop 
            BL      GetChar
            CMP     R0,#'~'         ;     keep eating characters until we hit the tilde (end of sequence)
            BNE     GSSB_EscapeLoop
            B       GSSB_LpSt
                                    ; }
GSSB_EscapeElse 
            CMP     R0,#DELETE      ;Check if the character is backspace (sent as delete character)
GSSB_BkSpIf     
            BNE     GSSB_BkSpElse   ; else if (char is delete){
            SUBS    R2,R2,#1        ;     subtract 1 from current position
            BMI     GSSB_DelNeg     ;     if we're stil positive
            BL      PutChar         ;         print it to terminal
            B       GSSB_LpSt
GSSB_DelNeg                         ;     if we've gone into the negative
            MOVS    R2,#0           ;         Make current position 0 to be safe.
            B       GSSB_LpSt       ; }
GSSB_BkSpElse   
            CMP     R2,R1           ; else if (hasn't reached end of buffer){
            BGE     GSSB_LpSt 
            CMP     R0,#0x20		;     if (char < 0x20) (if we are a control char)
            BLT		GSSB_LpSt		;         continue loop;
            BL      PutChar         ;     Echo character
            STRB    R0,[R3,R2]      ;     Stores character to buffer
            ADDS    R2,R2,#1        ;     Increments offset
GSSB_BkSpEndIf  
            B       GSSB_LpSt       ; } (loop)
GSSB_LpNd
            MOVS    R0,#0           ;Sets R0 = 0
            STRB    R0,[R3,R2]      ;Write the NUL character to the buffer
            MOVS    R0,#'\r'        ;Print carriage return
            BL      PutChar
            MOVS    R0,#'\n'        ;Print new line 
            BL      PutChar
            POP     {R0-R3,PC}
            ENDP
;Subroutine PutStringSB
; Blocking write for a NUL-terminated string to the UART0
; Inputs
;  R0 - Pointer to buffer (byte*)
;  R1 - Buffer Length (unsigned word)
; Outputs
;  NONE
; Modified: APSR
PutStringSB PROC    {R0-R14}
;R2 is used to represent the current offset in the buffer
;R3 is used to hold the buffer pointer
            PUSH    {R0,R2-R3,LR}
            CMP     R1,#0           ; Check if buffer length is <= 0. If this is the case,
            BLE     PSSB_Return     ; it shouldn't have anything to print so return
            MOVS    R2,#0           ;Initializes R2 to 0
            MOV     R3,R0           ;Moves the buffer pointer to R3.
PSSB_LpSt       
            LDRB    R0,[R3,R2]      ;Loads character
            CMP     R0,#0           ;If the character is NUL, break loop
            BEQ     PSSB_LpNd
            BL      PutChar         ;Prints char
            ADDS    R2,R2,#1        ;Increments offset
            CMP     R2,R1           ;If we haven't reached end of buffer, continue.
            BNE     PSSB_LpSt
PSSB_LpNd
PSSB_Return
            POP     {R0,R2-R3,PC}
            ENDP
;Function DIVU - Does unsigned division.
; Inputs
;  R0 - The Divisor (unsigned word)
;  R1 - The Dividend (unsigned word)
; Outputs
;  R0 - The Quotient (unsigned word)
;  R1 - The Remainder (unsigned word)
;  APSR - On failure (R0=0), carry is set, otherwise carry is set to 0 and 
;         N,Z flags are set accordingly to the quotient.
; Modified: APSR
DIVU        PROC    {R2-R14}    ; We preserve all registers except R0, R1.
            CMP     R0,#0       ; Carry is set if immediate is equal to 0
            BNE     DIVU_0END   
            BX      LR
DIVU_0END   
            PUSH    {R2,R3,LR}
; R2 - current shift being tested for subtract; will contain max value divisor can be shifted
;      before overflow. The shift is stored as a the bit number that is currently set
; we'll start by finding how far of a shift we can test for subtracting.
            MOVS    R2,#1       ; start shift at 2^0
            CMP     R0,#0       ; test to make sure that the divisor isn't already too large to shift.
            BMI     DIVU_NTSTLP
DIVU_STSTLP                     ; Start TeST LooP
            LSLS    R2,R2,#1
            LSLS    R0,R0,#1    ; also checks if the sign bit (highest bit is set)
            CMP     R1,R0       ; we check if it the shifted divisor is larger than the dividend
            BHI     DIVU_STSTLP ; branch back if it can be shifted up again.
DIVU_NTSTLP                     ; eNd TeST LooP
; Start from the max shift and set bit n according to whether or not 2^n * Divisor can be subtracted
; R3 - Interim stores the the quotient
            MOVS    R3,#0       ; initialize R3
DIVU_SSUBLP                     ; Start SUBtraction LooP
            CMP     R1,R0       ; we check if it can be subtracted
            BLO     DIVU_ENDCS  ; 
DIVU_CANSUB                     ; yes
            SUBS    R1,R1,R0    ; subtract the divisor*2^n from the dividend
            ORRS    R3,R3,R2    ; add 2^n to the quotient
DIVU_ENDCS           
            LSRS    R0,R0,#1    ; Decrease the current shift being tested.
            LSRS    R2,R2,#1    ; also checks if we have hit 0 (that means we finished n=0)
            BNE     DIVU_SSUBLP ; Loop if we have not yet
DIVU_NSUBLP                     ; eNd SUBtraction LooP
            ADDS    R0,R3,#0    ; move the quotient to R0, also clears carry flag
            POP     {R2,R3,PC}  ; return (remainder is already in R1)
            ENDP
					
;Subroutine InitQueue
; Initializes a queue record structure.
; Inputs
;  R0 - Pointer to queue memory (void*)
;  R1 - Pointer to queue record structure (queue*)
;  R2 - Size of queue memory (unsigned byte)
; Outputs
;  NONE 
; Modified: APSR
InitQueue   PROC    {R0-R14}
	        PUSH    {R2,LR}
            STR     R0,[R1,#QO_IN_PTR]   ;R1->in_ptr = R0 
			STR     R0,[R1,#QO_OUT_PTR]  ;R1->out_ptr = R0
			STR     R0,[R1,#QO_BUF_STRT] ;R1->buf_strt = R0
			STRH    R2,[R1,#QO_BUF_SIZE] ;R1->buf_size = R2
			ADD     R2,R2,R0
			STR     R2,[R1,#QO_BUF_PAST] ;R1->buf_past = R0 + R2
			MOVS    R2,#0
			STRH    R2,[R1,#QO_NUM_ENQD] ;R1->num_enqd = 0
			POP     {R2,PC}
			ENDP

;Subroutine Dequeue
; Attempts to remove a character from the queue
; Inputs
;  R1 - Pointer to queue record structure (queue*)
; Outputs
;  R0 - Dequeued character if operation succeeded, otherwise unchanged. (unsigned byte)
;  APSR - C flag will be set iff deque failed
; Modified: R0, APSR
Dequeue     PROC    {R1-R14}
	        PUSH    {R2,R3,LR}
            LDRH    R3,[R1,#QO_NUM_ENQD];R3 = R1->num_enqd
DQ_IfNone
			CMP     R3,#0
			BEQ     DQ_Return           ;if(R3 == 0) return fail [Since they're equal, C = 1]     
DQ_EndIfNone                            ;
            SUBS    R3,R3,#1            ;R3--;
			STRH    R3,[R1,#QO_NUM_ENQD];R1->num_enqd = R3
            LDR     R2,[R1,#QO_OUT_PTR] ;R2 = R1->out_ptr
			LDRB    R0,[R2,#0]          ;R0 = *R2
			ADDS    R2,R2,#1            ;R2++ 
			LDR     R3,[R1,#QO_BUF_PAST];R3 <- R1->buf_past
DQ_IfPastBuf
			CMP     R2,R3
			BLO     DQ_EndIfPastBuf     ;if (R2 >= R1->buf_past)
DQ_ThenPastBuf                          ;[implies C=1]
            ADDS    R0,R0,#0            ;    Clears APSR C flag
			LDR     R2,[R1,#QO_BUF_STRT];    R2 = R1->buf_strt
DQ_EndIfPastBuf                         ;[otherwise implies C=0]
			STR     R2,[R1,#QO_OUT_PTR] ;R1->out_ptr = R2
			                            ;return ok
DQ_Return
            POP     {R2,R3,PC}          
			ENDP

;Subroutine Enqueue
; Attempts to add a character from the queue.
; Inputs
;  R0 - Character to enqueue (byte)
;  R1 - Pointer to queue record structure (queue*)
; Outputs
;  APSR - C flag will be set iff deque failed
; Modified: APSR
Enqueue     PROC    {R0-R14}
	        PUSH    {R2,R3,LR}
            LDRH    R2,[R1,#QO_BUF_SIZE];R2 <- R1->buf_size
            LDRH    R3,[R1,#QO_NUM_ENQD];R3 = R1->num_enqd
NQ_IfNone
			CMP     R3,R2
			BEQ     NQ_Return           ;if(R3 == R1->buf_size) return fail [Since they're equal, C = 1]
NQ_EndIfNone                            
            ADDS    R3,R3,#1            ;R3++;
			STRH    R3,[R1,#QO_NUM_ENQD];R1->num_enqd = R3
            LDR     R2,[R1,#QO_IN_PTR]  ;R2 = R1->in_ptr
			STRB    R0,[R2,#0]          ;*R2 = R0
			ADDS    R2,R2,#1            ;R2++ 
			LDR     R3,[R1,#QO_BUF_PAST];R3 <- R1->buf_past
NQ_IfPastBuf
			CMP     R2,R3
			BLO     NQ_EndIfPastBuf     ;if (R2 >= R1->buf_past)
NQ_ThenPastBuf                          ;[implies C=1]
            ADDS    R0,R0,#0            ;    Clears APSR C flag
			LDR     R2,[R1,#QO_BUF_STRT];    R2 = R1->buf_strt
NQ_EndIfPastBuf                         ;[otherwise implies C=0]
			STR     R2,[R1,#QO_IN_PTR]  ;R1->in_ptr = R2
			                            ;return ok
NQ_Return
            POP     {R2,R3,PC}          
			ENDP
				
;Subroutine PutNumHex
; Prints to terminal the hex representation of an unsigned word value
; Inputs
;  R0 - Number to print (unsigned word)
; Outputs
;  NONE
; Modified: APSR
PutNumHex   PROC    {R0-R14}
            PUSH    {R0-R2,LR}
; bite - representation of R0 as byte array with most sig byte as bite[3]
; the loop can be unravelled for performance bonus and one less register but basically quadruples space
			REV     R1,R0           ;Reverse byte order of R0 and place in R1
			MOVS    R2,#4
PNH_For                             ;for (n = 3; n >= 0; n--){
			MOVS    R0,#0xF0
			ANDS    R0,R0,R1        ;    R0 <- bite[n] & 0xF0
			LSRS    R0,R0,#4        ;    R0 >>= 4
			ADDS    R0,R0,#'0'      ;    Converts R0 to ASCII equiv if 0-9
PNH_IfHiNib
			CMP     R0,#':'         ;    (Compare to the first char after '9', 
			                        ;     which corresponds to 'A')
			BLO     PNH_EndIfHiNib  ;    if (R0 >= ':'){
PNH_ThenHiNib
            ADDS    R0,R0,#('A'-':');        Converts R0 to ASCII equiv if A-F
PNH_EndIfHiNib                      ;    }
            BL      PutChar         ;    PutChar(R0)
			MOVS    R0,#0x0F
			ANDS    R0,R0,R1        ;    R0 <- bite[3] & 0x0F
			ADDS    R0,R0,#'0'      ;    Converts R0 to ASCII equiv if 0-9
PNH_IfLoNib
			CMP     R0,#':'         ;    (Compare to the first char after '9', 
			                        ;     which corresponds to 'A')
			BLO     PNH_EndIfLoNib  ;    if (R0 >= ':'){
PNH_ThenLoNib
            ADDS    R0,R0,#('A'-':');        Converts R0 to ASCII equiv if A-F
PNH_EndIfLoNib                      ;    }
            BL      PutChar         ;    PutChar(R0)
			LSRS    R1,R1,#8        ;    Process next byte
			SUBS    R2,R2,#1 
			BNE     PNH_For
PNH_EndFor                          ;}
			POP     {R0-R2,PC}
			ENDP
			
;Subroutine PutNumU
; Blocking write for an unsigned integer to the UART0.
; Inputs
;  R0 - Unsigned integer to print
; Outputs
;  NONE 
; Modified: NONE
PutNumU     PROC    {R0-R14},{}
;R2 will hold the address of PutNumUBuf
;R3 will hold the current offset of where to write to.
            PUSH    {R0-R3,LR}
            MOVS    R1,R0           ;moves the dividend to R1
            LDR     R2,=PutNumUBuf
            MOVS    R3,#10
PNU_DigLpSt    
            SUBS    R3,R3,#1        ;decrement offset (increments represented power of 10)
            MOVS    R0,#10          ;load 10 for division
            BL      DIVU            ; divide
            ADDS    R1,R1,#'0'      ;convert remainder to ASCII
            STRB    R1,[R2,R3]      ;store ascii remainder
            MOVS    R1,R0           ;moves quotient to R1 and tests if = 0
            BNE     PNU_DigLpSt     ;if there is still a quotient, keep looping
PNU_DigLpNd    
            ADDS    R0,R2,R3        ;Make R0 point to the start of the string
            SUBS    R3,R3,#10       ;Subtract position from 10 to get length.
            RSBS    R1,R3,#0        ;and put in R1 for the PutString call.
            BL      PutStringSB
            POP     {R0-R3,PC}
            ENDP
                
;Subroutine PutNumUB
; Blocking write for an unsigned integer (0-255) to the UART0.
; Before this subroutine is called, 0 must be written to byte @ PutNumUBuf_Last.
; Inputs
;  R0 - Unsigned integer to print (unsigned byte)
; Outputs
;  NONE 
; Modified: APSR
PutNumUB    PROC    {R0-R14}
			PUSH    {R0,R1,LR}
			UXTB    R1,R0           ;Same as R1 = R0 & 0xFF
PNUB_IfGreat100
            CMP     R1,#100
            BLO     PNUB_EndIfGreat100
PNUB_ThenGreat100
	        MOVS    R0,#'1'         ;Get ready to print '1'
PNUB_IfGreat200
            CMP     R1,#200
			BLO     PNUB_EndIfGreat200
PNUB_ThenGreat200
            ADDS    R0,R0,#1        ;If R1 < 200 print 2 instead.
		    SUBS    R1,R1,#100
PNUB_EndIfGreat200
            BL      PutChar
			SUBS    R1,R1,#100
PNUB_EndIfGreat100
            MOVS    R0,#10
			BL      DIVU
; If no ten's place, skip printing it (my implementation of DIVU sets Z
;  if quotient = 0 and division is not by 0)
			BEQ     PNUB_Skip10sPlace
			ADDS    R0,R0,#'0'      ; Print tens place
			BL      PutChar
PNUB_Skip10sPlace
			ADDS    R1,R1,#'0'      ; Print ones place
			MOV     R0,R1
			BL      PutChar
            POP     {R0,R1,PC}
            ENDP
				

;Subroutine PrintQueue
; Prints the contents of a queue
; Inputs
;  R1 - Pointer to queue record structure (queue*)
; Modified: APSR
PrintQueue  PROC    {R1-R14}
	        PUSH    {R0,R2-R4,LR}
            LDRH    R2,[R1,#QO_NUM_ENQD] ;R2 <- R1->num_enqd
PQ_IfNone
			CMP     R2,#0
			BEQ     PQ_Return            ;if(R2 == 0) return
PQ_EndIfNone                            
; R3 is used as the memory address to be accessed for the next character
            LDR     R3,[R1,#QO_OUT_PTR] ;R3 = R1->out_ptr
			LDR     R4,[R1,#QO_BUF_PAST];R4 <- R1->buf_past
PQ_Loop                                 ;do{ 
			LDRB    R0,[R3,#0]          
			BL      PutChar             ;    PutChar(*R3)
			ADDS    R3,R3,#1            ;    Advance R3 to next character to print
PQ_IfPastBuf
			CMP     R3,R4
			BNE     PQ_EndIfPastBuf     ;    if (R3 == R1->buf_past) //about to go outside the buffer?
PQ_ThenPastBuf                          
			LDR     R3,[R1,#QO_BUF_STRT];        R3 = R1->buf_strt //loop around
PQ_EndIfPastBuf                         
            SUBS    R2,R2,#1            ;    R2--;
			BNE     PQ_Loop
PQ_LoopEnd                              ;} while (R2 > 0);
PQ_Return
            POP     {R0,R2-R4,PC}       ;return
			ENDP
				
;Subroutine Flush
; Flushes the transmit buffer.
; Interrupts should be disabled when calling
; Inputs/Outputs
;  NONE
; Modified: APSR
Flush       PROC    {R0-R14}
	        PUSH    {R0-R2,LR}
            LDR     R1,=TxQRecord
			LDR     R2,=UART0_BASE          
Fl_Loop     ;flush all characters out       ;while true{
            LDRB    R0,[R2,#UART0_S1_OFFSET]; Read UART0 S1 Register to get TDRE flag
			LSRS    R0,R0,#UA0ISR_UART0_S1_TDRE_SHIFT_2C;TDRE is now in carry 
			BCC     Fl_Loop                 ; if (Can Transmit data){
            BL      Dequeue 
            BCS     Fl_Exit                 ;   if empty, exit
            STRB    R0,[R2,#UART0_D_OFFSET] ;   transmit character
            B       Fl_Loop                 ; }
Fl_Exit                                     ;}
            POP     {R0-R2,PC}              ;return
			ENDP
                
;Interrupt Service Routine UART0_ISR / UART0_IRQHandler
; Handles interrupts for the UART0.
; Modified: R0-R3, APSR (NONE if via Interrupt)
UART0_IRQHandler
UART0_ISR   PROC    {R4-R11}, {}
            CPSID   I                       ;Mask interrupts
			MOV     R12,LR                  ;Save Link Register (Could be replaced with PUSH {LR})
			LDR     R3,=UART0_BASE          
            LDRB    R1,[R3,#UART0_C2_OFFSET];Read UART0 C2 Register to get TIE flag
            LSRS    R0,R1,#UA0ISR_UART0_C2_TIE_SHIFT_2C ;TIE is now in carry
            BCC     UA0ISR_EndIfTIE
UA0ISR_IfTIE                                ;if (Transmit Interrupt Enabled){
            LDRB    R1,[R3,#UART0_S1_OFFSET]    
			LSRS    R0,R1,#UA0ISR_UART0_S1_TDRE_SHIFT_2C;TDRE is now in carry 
			BCC     UA0ISR_EndIfTx          ; if (Can Transmit data){
UA0ISR_IfTx LDR     R1,=TxQRecord           ;  Dequeue a character
            BL      Dequeue 
            BCS     UA0ISR_ElseDQ_F
UA0ISR_IfDQ_S                               ;  if (success){
            STRB    R0,[R3,#UART0_D_OFFSET] ;   transmit character
            B       UA0ISR_EndIfDQ          ;  }
UA0ISR_ElseDQ_F                             ;  else {
            MOVS    R1,#IUP_C2_EN_RIE       ;   disable transmit interrupts
            STRB    R1,[R3,#UART0_C2_OFFSET]  
UA0ISR_EndIfDQ  
UA0ISR_EndIfTx                              ; }
UA0ISR_EndIfTIE
            LDRB    R2,[R3,#UART0_S1_OFFSET]    
			LSRS    R0,R2,#UA0ISR_UART0_S1_RDRF_SHIFT_2C;RDRF is now in carry 
			BCC     UA0ISR_EndIfRx          ;if (Recieved data){
UA0ISR_IfRx LDRB    R0,[R3,#UART0_D_OFFSET] ; recieve a character
            LDR     R1,=RxQRecord           ; Try enqueue
            BL      Enqueue
UA0ISR_EndIfRx                              ;}
			MOV     LR,R12                  ;Restore Link Register
            CPSIE   I                       ;Unmask interrupts
            BX      LR                      ;return (This statement and above one can be replaced w/ POP {PC})
            ENDP
;>>>>>   end subroutine code <<<<<
            ALIGN
;****************************************************************
;Variables
            AREA    CharIOData,DATA,READWRITE
;>>>>> begin variables here <<<<<
RxQRecord   SPACE   Q_SIZEOF
	        ALIGN
TxQRecord   SPACE   Q_SIZEOF
RxQBuffer   SPACE   IOQBUF_SIZE
TxQBuffer   SPACE   IOQBUF_SIZE
PutNumUBuf  SPACE   11  		;Defines Buffer of size 11.
;>>>>>   end variables here <<<<<
            ALIGN
            END