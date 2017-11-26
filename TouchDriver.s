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
;**********************************************************************
;MACROs
;**********************************************************************
;Program
            AREA    MyCode,CODE,READONLY
            EXPORT  EnableTSI   
;Subroutine EnableTSI
; Initializes the TSI for interrupt-based 
; Inputs
;  NONE
; Outputs
;  NONE
; Modified: APSR
EnableTSI   PROC {R0-R14}
            ;Enable Clock gating
            ;Enable Module
            ;Enable Interrupts
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
            ;Disable Interrupts
            ;Disable Module
            ;Disable Clock gating
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