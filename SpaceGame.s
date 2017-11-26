      TTL Low Power Timer Driver
;**********************************************************************
;Implements a driver for the LPTMR0 (Low Power Timer) to make it run 
; the function tick() in SpaceGame.c every sixtieth of a second.
;This module can be installed by including this file and setting
; the interrupt vector 44 to the LPTimer_IRQHandler service routine in
; this file for pure assembly projects. It automagically installs for 
; projects with the Device>Startup package installed.
;Name:  Koen Komeya 
;Date:  October 26, 2017; November 21, 2017
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
LPTMR0_BASE  EQU 0x40040000
LPTMR0_CSR_OFFSET    EQU 0x00
;We don't need to touch the PSR because we dont want prescaling
; and the default is off, so its not listed
LPTMR0_CMR_OFFSET    EQU 0x08
LPTMR0_CNR_OFFSET    EQU 0x0C

;LPTMR0 Field Masks
;From KL46 Sub-Family Reference Manual, Rev 3 page 601-604
LPTMR0_CSR_


;**********************************************************************
;MACROs
;**********************************************************************
;Program
            AREA    MyCode,CODE,READONLY
            EXPORT  EnableClock  
;Subroutine EnableClock
; Initializes the LPTMR (Low P for interrupt-based 
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
            ;FIXME add LPTMR clock source
            ;Set interrupt priority
            LDR     R0,=LPTMR0_IPR
            LDR     R1,[R0,#0]
            MOVS    R2,#LPTMR0_PRI_MASK
            BICS    R1,R1,R2
            MOVS    R2,#LPTMR0_PRI_SET
            ORRS    R1,R1,R2
            STR     R1,[R0,#0]
            ;Clear pending interrupts, unmask Interrupt
            LDR     R0,=NVIC_ICPR
            LDR     R1,=LPTMR0_IRQ_MASK
            STR     R1,[R0,#0]
            LDR     R0,=NVIC_ISER
            STR     R1,[R0,#0]
            ;config & Enable Module
            LDR     R0,=LPTMR_BASE
            LDR
            ;Enable Clock
            POP     {R0-R2}
            ENDP
                
;Interrupt Service Routine LPTMR_IRQHandler
; Handles interrupts for the Periodic Interupt Timer
; Modified: R0-R1, APSR (NONE if via Interrupt)
LPTimer_IRQHandler PROC    {R2-R14}
            BL      
            LDR     R0,=LPTMR_BASE
            BX      LR                              ;Return
            ENDP
                
            ALIGN
;**********************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;**********************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
            END