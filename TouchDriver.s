      TTL Touch Sensing Driver
;**********************************************************************
;This module implements a driver for the TSI0 module, which does touch
; sensing detection. It receives updates from the module via
; interrupts.
;This module can be installed by including this file and setting the
; interrupt vector 42 to the TSI0_IRQHandler handler in this file for
; pure assembly projects. It automagically installs for projects with
; the Device>Startup package installed.
;Name:  Koen Komeya 
;Date:  November 21, 2017
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
;   1 -> 6  :TSI: Enable clock to the Touch Sensing Input
; Using SIM_SCGC5_TSI_MASK

;TSI0 Interrupt Priority
; Priority of the TSI0. 
TSI0_PRI    EQU 2
    
;TSI0 Interrupt Priority Mask
; NVIC_IPRx
;  VAL-> BIT
;   3 ->23-22:TSI0: Priority mask for TSI0.
TSI0_PRI_MASK EQU (3 << TSI0_PRI_POS)
    
;TSI0 Interrupt Priority Set
;See above
TSI0_PRI_SET  EQU (TSI0_PRI << TSI0_PRI_POS)

;TSI0 NVIC Register Mask
; NVIC_IXXR
;  VAL->BIT
;   1 -> 26 :TSI0: Mask for the NVIC's IXXR registers for TSI0.
; Using TSI0_IRQ_MASK

;TSI0 Base and Offsets
;From KL46 Sub-Family Reference Manual, Rev 3 page 843
TSI0_BASE           EQU 0x40045000
TSI0_GENCS_OFFSET   EQU 0x0
TSI0_DATA_OFFSET    EQU 0x4
TSI0_TSHD_OFFSET    EQU 0x8

;TSI0 Fields
;From KL46 Sub-Family Reference Manual, Rev 3 page 844-849

TSI0_GENCS_OUTRGF_MASK  EQU 0x80000000
TSI0_GENCS_TSIEN_MASK   EQU 0x00000080
TSI0_GENCS_TSIIEN_MASK  EQU 0x00000040

;TSI0 Enable Mask
; NVIC_IXXR
;  VAL -> BIT
;   1  -> 31  :OUTRGF : Clear out of range Flag
;   0  -> 28  : ESOR  : Use out of range interrupts
;  0000->27-24: MODE  : Use capacitive sensing mode
;      ->23-21:REFCHRG:                                   FIXME
;      ->20-19: DVOLT :
;      ->18-16:EXTCHRG:
;      ->15-13:  PS   :
;      ->12- 8: NSCN  : Scan N Times
;   1  ->  7  : TSIEN : Enables TSI0
;   1  ->  6  :TSIIEN : Enable Interrupts
;   1  ->  5  : STPE  : Enable TSI0 in low power mode
;      ->  4  :  STM  : Use Hardware? for Trigger scan
TSI0_EN_I_1     EQU 0x800000E0
;TSI0 Disable Mask
; TSI0_GENCS
;  VAL->BIT
;   0 -> 7 :TSIEN: Disables TSI0
; Use TSI0_GENCS_TSIEN_MASK


;**********************************************************************
;MACROs
;**********************************************************************
;Program
            AREA    MyCode,CODE,READONLY
            EXPORT  EnableTSI   
;Subroutine EnableTSI
; Initializes the TSI for interrupt-based 
; If the TSI is currently enabled, undefined behavior.
; Inputs
;  NONE
; Outputs
;  NONE
; Modified: APSR
EnableTSI   PROC {R0-R14}
            PUSH    {R0-R2}
            ;Enable Clock gating
            LDR     R0,=SIM_SCGC5
            LDR     R1,[R0,#0]
            MOVS    R2,#SIM_SCGC5_TSI_MASK
            ORRS    R1,R1,R2
            STR     R1,[R0,#0]
            ;Set interrupt priority
            LDR     R0,=TSI0_IPR
            LDR     R1,[R0,#0]
            LDR     R2,=TSI0_PRI_MASK
            BICS    R1,R1,R2
            LDR     R2,=TSI0_PRI_SET
            ORRS    R1,R1,R2
            STR     R1,[R0,#0]
            ;Clear pending interrupts, unmask Interrupt
            LDR     R0,=NVIC_ICPR
            LDR     R1,=TSI0_IRQ_MASK
            STR     R1,[R0,#0]
            LDR     R0,=NVIC_ISER
            STR     R1,[R0,#0]
            ;Config Module
            LDR     R0,=TSI0_BASE
            
            ;Enable Module
            LDR     R1,=TSI0_EN_I_1
            STR     R1,[R0,#TSI0_GENCS_OFFSET]
            POP     {R0-R2}
            ENDP
                
            EXPORT  DisableTSI    
;Subroutine DisableTSI
; Disables the TSI.
; Inputs
;  NONE
; Outputs
;  NONE
; Modified: APSR
DisableTSI  PROC {R0-R14}
            PUSH    {R0-R2}
            ;Disable Module
            LDR     R0,=TSI0_BASE
            LDR     R1,[R0,#TSI0_GENCS_OFFSET]
            MOVS    R2,#TSI0_GENCS_TSIEN_MASK
            BICS    R1,R1,R2
            STR     R1,[R0,#TSI0_GENCS_OFFSET]
            ;Disable Interrupts
            LDR     R0,=NVIC_ICER
            LDR     R1,=TSI0_IRQ_MASK
            STR     R1,[R0,#0]
            ;Disable Clock gating
            LDR     R0,=SIM_SCGC5
            LDR     R1,[R0,#0]
            MOVS    R2,#SIM_SCGC5_TSI_MASK
            BICS    R1,R1,R2
            STR     R1,[R0,#0]
            POP     {R0-R2}
            ENDP

;Interrupt Service Routine TSI0_IRQHandler
; Handles interrupts for the TSI0.
; Modified: R0-R3, APSR (NONE if via Interrupt)
TSI0_IRQHandler   PROC    {R4-R11}, {}
            
            BX      LR                      ;return (This statement and above one can be replaced w/ POP {PC})
            ENDP
                
            ALIGN
;**********************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;**********************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
            END