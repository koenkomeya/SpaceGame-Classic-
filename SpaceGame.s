      TTL Low Power Timer Driver / PORTC + FGPIO Button Driver
;**********************************************************************
;Implements a driver for the LPTMR0 (Low Power Timer) to make it run 
; the function tick() in SpaceGame.c every hundredth of a second.
;Implements a driver for the PORTC to interrupt when either of the
; ports PTC3 and PTC12, which correspond to the two pushbuttons, go 
; high and for the FGPIO to read their state.
;In order for this to function properly, the MCGIRCLK must be set up
; to use the fast internal reference clock (See KL46 Sub-Family 
; Reference Manual, Rev 3 page 386) and the fast internal reference
; clock should run at 4 MHz.
;This module can be installed by including this file and setting the
; interrupt vector 47 to the PORTC_PORTD_IRQHandler handler in this 
; file for pure assembly projects. It automagically installs for 
; projects with the Device>Startup package installed.
;Name:  Koen Komeya 
;Date:  November 21, 2017~
;Class:  CMPE-250
;Section:  Lab Section 4: Thursday 11 AM - 1 PM
;----------------------------------------------------------------------
;Keil Template for KL46 Assembly with Keil C startup
;R. W. Melton
;November 13, 2017
;**********************************************************************
;Assembler directives
            THUMB
            GBLL  MIXED_ASM_C
MIXED_ASM_C SETL  {TRUE}
            OPT   64  ;Turn on listing macro expansions
;**********************************************************************
;Include files
            GET  MKL46Z4.s     ;Included by start.s
            OPT  1   ;Turn on listing
;**********************************************************************
;EQUates
;Clock Gating Mask
; SCGC5
;  VAL->BIT
;   1 -> 0  :LPTMR: Enable clock to the Low Power Timer
; Using SIM_SCGC5_LPTMR_MASK

;LPTMR0 Interrupt Priority
; Priority of the LPTMR0. Set to lowest, since there are more important
;  things to process.
LPTMR0_PRI    EQU 3
    
;LPTMR0 Interrupt Priority Mask
; NVIC_IPRx
;  VAL->BIT
;   3 ->7-6 :LPTMR0: Priority mask for LPTMR0.
LPTMR0_PRI_MASK EQU (3 << LPTMR0_PRI_POS)
    
;LPTMR0 Interrupt Priority Set
;See above
LPTMR0_PRI_SET  EQU (LPTMR0_PRI << LPTMR0_PRI_POS)

;LPTMR0 NVIC Register Mask
; NVIC_IXXR
;  VAL->BIT
;   1 -> 28 :LPTMR0: Mask for the NVIC's IXXR registers for LPTMR0.
; Using LPTMR0_IRQ_MASK

;LPTMR0 Base and offsets
;From KL46 Sub-Family Reference Manual, Rev 3 page 601
LPTMR0_BASE EQU 0x40040000
LPTMR0_CSR_OFFSET   EQU 0x00
LPTMR0_PSR_OFFSET   EQU 0x04
LPTMR0_CMR_OFFSET   EQU 0x08
;LPTMR0_CNR_OFFSET    EQU 0x0C ;We don't use the counter

;LPTMR0 Field Masks
;From KL46 Sub-Family Reference Manual, Rev 3 page 601-604

LPTMR0_CSR_TCF_MASK     EQU 0x80
LPTMR0_CSR_TCF_SHIFT    EQU 7
LPTMR0_CSR_TCF_S2C      EQU (LPTMR0_CSR_TCF_SHIFT + 1) ;Shift to carry

;LPTMR0 Main Control Register Config
; LPTMR0_PSR
;  VAL->BIT
;   0 -> 6 :TIE: Disable Interrupts for timer
;   X ->5-3:---: Related to Pulse Counter Mode
;   0 -> 2 :TFC: Reset on Timer Compare Flag
;   0 -> 1 :TMS: Use Time Counter Mode
;   1 -> 0 :TEN: Enable the Timer
LPTMR0_CSR_P_TC_EN  EQU 0x00000001
    
;LPTMR0 Main Control Register Config + Clear Timer Compare Flag
; LPTMR0_PSR
;  VAL->BIT
;   1 -> 7 :TCF: Clear Timer Compare Flag
;   0 -> 6 :TIE: Disable Interrupts for timer
;   X ->5-3:---: Related to Pulse Counter Mode
;   0 -> 2 :TFC: Reset on Timer Compare Flag
;   0 -> 1 :TMS: Use Time Counter Mode
;   1 -> 0 :TEN: Enable the Timer
LPTMR0_CSR_P_TC_EN_CLEARTCF EQU (LPTMR0_CSR_P_TC_EN :OR: LPTMR0_CSR_TCF_MASK)

; We need to get the prescaler to run every 0.01 seconds.
; Therefore we need to ensure an interrupt happens every (4MHz*0.01s/2=20000)
; cycles of the MCGIRCLK. 20000 = 32 * 625
;LPTMR0 Prescaler Mask
; LPTMR0_PSR
;  VAL ->BIT
;  0110->6-3:PRESCALE: Prescale by a factor of 128
;    0 -> 2 :  PBYP  : Use Prescaler
;   00 ->1-0:  PCS   : Use MCGIRCLK (see page 93 of above ref manual)
LPTMR0_PSR_MCGIRC_PRE128    EQU 0x00000030
LPTMR0_PSR_MCGIRC_PRE64     EQU 0x00000028
LPTMR0_PSR_MCGIRC_PRE32     EQU 0x00000020

;LPTMR0 Compare Value
; LPTMR0_CMR
;  VAL->BIT
;  625->15-0:COMPARE: Compare Value; trigger interrupt after 625 prescaled edges
LPTMR0_CMR_COMPARE625   EQU 625
    
;PUSHBUTTON
; SCGC5
;  VAL->BIT
;   1 -> 11:PORTC: Enable clock to the Low Power Timer
; Using SIM_SCGC5_PORTC_MASK

;PORTC Interrupt Priority
; Priority of the PORTC (and PORTD). Set to 2, since there are more
;  important things to process, but we want responsive inputs and
;  there may be things that should have less priority than the PORTC.
PORTC_PORTD_PRI    EQU 2
    
;PORTC Interrupt Priority Mask
; NVIC_IPRx
;  VAL->BIT
;   3 ->31-30:PORTC: Priority mask for PORTC (and PORTD).
PORTC_PORTD_PRI_MASK EQU (3 << PORTC_PORTD_PRI_POS)
    
;PORTC Interrupt Priority Set
;See above
PORTC_PORTD_PRI_SET  EQU (PORTC_PORTD_PRI << PORTC_PORTD_PRI_POS)

;PORTC Configuration
; Configures the pushbutton ports so that the port is low when the
;  button is pressed and high otherwise.
; PORTC_PCRn
;  VAL-> BIT
;   1 -> 24  :ISF : Clear Interrupt Status Flag
; 1010->19-16:IRQC: Interrupt on falling edge (this is to ensure we don't miss)
;  001->10-8 :MUX : Connect port to GPIO
;   X ->  6  :DSE : Don't care, because this will be used as an input
;   X ->  4  :PFE : (Read-only for these pins)
;   1 ->  2  :SRE : Slow Slew Rate
;   1 ->  1  : PE : Enable pull-xx resistor
;   1 ->  0  : PS : Use an internal pull-up resistor
PORTC_PUSHBUTTON_CFG    EQU (PORT_PCR_ISF_MASK :OR: \
                             (2_1010 << PORT_PCR_IRCQ_SHIFT) :OR: \
                             PORT_PCR_MUX_SELECT_1_MASK :OR: \
                             PORT_PCR_SRE_MASK :OR: PORT_PCR_PE_MASK :OR: \
                             PORT_PCR_PS_MASK)

; Mask for Pins PTC3=SW1 (RightButton) and PTC12=SW3(LeftButton)
; Clears interrupts when written to ISFR.
;(F)GPIO Mask for Pins PTC3=SW1 (RightButton) and PTC12=SW3(LeftButton)
PTC3_PTC12_MASK    EQU 0x00001008

;**********************************************************************
;MACROs
;**********************************************************************
;Program
            AREA    MyCode,CODE,READONLY
; LPTMR0 Driver
            EXPORT  EnableClock  
            EXPORT  WaitForTick
;Subroutine EnableClock
; Initializes the LPTMR (Low Power Timer) for poll-based 
;  timing at 100Hz.
; If the clock is already enabled, undefined behavior ensues.
; Inputs
;  NONE
; Outputs
;  NONE
; Modified: APSR
EnableClock  PROC {R0-R14}
            PUSH    {R0-R2}
            ;Enable Clock gating
            LDR     R0,=SIM_SCGC5
            LDR     R1,[R0,#0]
            MOVS    R2,#SIM_SCGC5_LPTMR_MASK
            ORRS    R1,R1,R2
            STR     R1,[R0,#0]
            ;Force fast internal reference clock
            LDR     R0,=MCG_C2
            MOVS    R1,#MCG_C2_IRCS_MASK
            LDRB    R2,[R0]
            ORRS    R2,R2,R1
            STRB    R2,[R0]
;           ;Set interrupt priority
;           LDR     R0,=LPTMR0_IPR
;           LDR     R1,[R0,#0]
;           MOVS    R2,#LPTMR0_PRI_MASK
;           BICS    R1,R1,R2
;           MOVS    R2,#LPTMR0_PRI_SET
;           ORRS    R1,R1,R2
;           STR     R1,[R0,#0]
;           ;Clear pending interrupts, unmask Interrupt
;           LDR     R0,=NVIC_ICPR
;           LDR     R1,=LPTMR0_IRQ_MASK
;           STR     R1,[R0,#0]
;           LDR     R0,=NVIC_ISER
;           STR     R1,[R0,#0]
            ;config & Enable Module
            LDR     R0,=LPTMR0_BASE
            MOVS    R1,#LPTMR0_PSR_MCGIRC_PRE32
            STR     R1,[R0,#LPTMR0_PSR_OFFSET]
            LDR     R1,=LPTMR0_CMR_COMPARE625
            STR     R1,[R0,#LPTMR0_CMR_OFFSET]
            MOVS    R1,#LPTMR0_CSR_P_TC_EN
            STR     R1,[R0,#LPTMR0_CSR_OFFSET]
            ;Set Tick wait to 1.
            POP     {R0-R2}
			BX      LR
            ENDP

;Subroutine WaitForTick
; Blocks until the next tick interval.
; Inputs
;  NONE
; Outputs
;  NONE
; Modified: APSR
WaitForTick PROC {R0-R14}
            PUSH    {R0-R1}
            LDR     R0,=LPTMR0_BASE
W4T_PollLoop;Wait for TCF to be set. (That signals a tick interval has passed)
            LDR     R1,[R0,#LPTMR0_CSR_OFFSET]
            LSRS    R1,R1,#LPTMR0_CSR_TCF_S2C
            BCC     W4T_PollLoop
            ;Clear TCF flag
            MOVS    R1,#LPTMR0_CSR_P_TC_EN_CLEARTCF
            STR     R1,[R0,#LPTMR0_CSR_OFFSET]
            POP     {R0-R1}
			BX      LR
            ENDP
                
;Interrupt Service Routine LPTMR_IRQHandler
; Handles interrupts for the Periodic Interupt Timer
; Modified: R0-R1, APSR (NONE if via Interrupt)
;LPTimer_IRQHandler PROC    {R2-R14}
            
            ;Clear timer flag
;           LDR     R0,=LPTMR0_BASE
;           MOVS    R1,#LPTMR0_CSR_I_TC_EN_CLEARTCF
;           STR     R1,[R0,LPTMR0_CSR_OFFSET]
;           BX      LR                              ;Return
;           ENDP

;----------------------------------------------------------------------
; PORT Driver
            EXPORT  EnableButtonDriver
            EXPORT  CheckAndClearPress
            EXPORT  PORTC_PORTD_IRQHandler
       
;Subroutine EnableButtonDriver
; Initializes the PORTC to be able to read the state of (PTC3=SW1) and
;  (PTC12=SW2) goes high.
; Inputs
;  NONE
; Outputs
;  NONE
; Modified: APSR
EnableButtonDriver PROC {R0-R14}
            PUSH    {R0-R2}
            ;Enable system clock to the PORTC.
            LDR     R0,=SIM_SCGC5
            LDR     R1,[R0,#0]
            LDR     R2,=SIM_SCGC5_PORTC_MASK
            ORRS    R1,R1,R2
            STR     R1,[R0,#0]
            ;Set interrupt priority
            LDR     R0,=PORTC_PORTD_IPR
            LDR     R1,[R0,#0]
            LDR     R2,=PORTC_PORTD_PRI_MASK
            BICS    R1,R1,R2
            LDR     R2,=PORTC_PORTD_PRI_SET
            ORRS    R1,R1,R2
            STR     R1,[R0,#0]
            ;Clear pending interrupts, unmask Interrupt
            LDR     R0,=NVIC_ICPR
            LDR     R1,=PORTC_PORTD_IRQ_MASK
            STR     R1,[R0,#0]
            LDR     R0,=NVIC_ISER
            STR     R1,[R0,#0]
            ;Configure ports
            LDR     R0,=PORTC_BASE
            LDR     R1,=PORTC_PUSHBUTTON_CFG
            STR     R1,[R0,#PORTC_PCR3_OFFSET]
            STR     R1,[R0,#PORTC_PCR12_OFFSET]
            ;PTC3 and PTC12 are inputs in FGPIO by default
            POP     {R0-R2}
            BX      LR
            ENDP
                
;Subroutine CheckAndClearPress
; Checks if the button was pressed; returns the result in R0.
; At the same time, clears the pressed state atomically.
; In order for this to function properly, EnableButtoDriver must have
;  been called first.
; Inputs
;  NONE
; Outputs
;  R0 - 1 if the button was pressed, 0 otherwise
; Modified: R0, APSR
CheckAndClearPress PROC {R1-R14}
            PUSH    {R1-R2}
            ;Get and clear Button Pressed [Critical Section]
            CPSID   I   ;(Mask interrupts temporarily to make operation atomic)
            LDR     R1,=ButtonPressed
            MOVS    R2,#0
            LDRB    R0,[R1,#0]
            STRB    R2,[R1,#0]
            CPSIE   I   ;(Unmask interrupts)
            ;Check if button is still being pressed.
            LDR     R1,=FGPIOC_BASE
            LDR     R2,=PTC3_PTC12_MASK
            LDR     R1,[R1,#GPIO_PDIR_OFFSET]
            ANDS    R1,R1,R2
            RSBS    R0,R0,#0 
            ASRS    R1,R1,#31  
            RSBS    R0,R0,#0 
            ;ADDS    R0,R0,#1
            ;Sum together the two possibilities and normalize to 0 or 1.
            ADDS    R0,R0,R1
            RSBS    R0,R0,#0 
            ASRS    R0,R0,#31  
            RSBS    R0,R0,#0
            POP     {R1-R2}
            BX      LR
            ENDP
                
            EXPORT  PORTC_PORTD_IRQHandler
;Interrupt Service Routine PORTC_PORTD_IRQHandler
; Handles interrupts for the PORTC pins (technically also handles 
;  PORTD, but we don't listen to any of PORTD's ports).
; Modified: R0-R2, APSR (NONE if via Interrupt)
PORTC_PORTD_IRQHandler PROC    {R3-R14}
            ;Check for pushbutton interrupts.
            LDR     R0,=PORTC_ISFR
            LDR     R1,=PTC3_PTC12_MASK
            LDR     R2,[R0,#0]
            ANDS    R2,R2,R1
            ;Clear interrupt flags for pushbuttons
            STR     R2,[R0,#0]
            ;Set ButtonPressed
            RSBS    R2,R2,#0    ;no pushbuttons prsd <=> will be non-negative
            ASRS    R2,R2,#31   ;Pressed -> R2=-1; Not Pressed -> R2=0
            RSBS    R2,R2,#0    ;Pressed -> R2=1; NotPressed -> R2=0
            LDR     R1,=ButtonPressed
            STRB    R2,[R1,#0]
            BX      LR                              ;Return
            ENDP
                
            ALIGN
;**********************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;**********************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
ButtonPressed   SPACE   1   ;Variable that holds if the button was pressed.
            END
