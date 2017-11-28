      TTL LCD Driver
;**********************************************************************
;This module implements a driver for the SLCD module, which does touch
; sensing detection. It receives updates from the module via
; interrupts.
;This module can be installed by including this file.
;Name:  Koen Komeya 
;Date:  November 27, 2017
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
;   1 -> 19 :SLCD: Enable clock to the Touch Sensing Input
; Using SIM_SCGC5_SLCD_MASK

;LCD Interrupt Priority
; Priority of the LCD.
LCD_PRI    EQU 3
    
;LCD Interrupt Priority Mask
; NVIC_IPRx
;  VAL-> BIT
;   3 ->15-14:LCD: Priority mask for LCD.
LCD_PRI_MASK EQU (3 << LCD_PRI_POS)
    
;LCD Interrupt Priority Set
;See above
LCD_PRI_SET  EQU (LCD_PRI << LCD_PRI_POS)

;LCD NVIC Register Mask
; NVIC_IXXR
;  VAL->BIT
;   1 -> 26 :LCD: Mask for the NVIC's IXXR registers for LCD.
; Using LCD_IRQ_MASK

;LCD Base and Offsets
;From KL46 Sub-Family Reference Manual, Rev 3 page 843
LCD_BASE           EQU 0x40053000
LCD_GCR_OFFSET     EQU 0x0

;LCD Fields
;From KL46 Sub-Family Reference Manual, Rev 3 page 844-849

LCD_GCR_RVEN_MASK      EQU 0x80000000
LCD_GCR_RVTRIM_MASK    EQU 0x0F000000
LCD_GCR_LCDEN_MASK     EQU 0x00000080

;LCD Enable Mask
; NVIC_IXXR
;  VAL -> BIT
;   1  -> 31  :RVEN: Clear out of range Flag
LCD_EN_1     EQU 
;LCD Disable Mask
; LCD_GENCS
;  VAL->BIT
;   0 -> 7 :TSIEN: Disables LCD
; Use LCD_GENCS_TSIE

;**********************************************************************
;MACROs
;**********************************************************************
;Program
            AREA    MyCode,CODE,READONLY
            EXPORT  EnableLCD 
;Subroutine EnableLCD
; Initializes the LCD for interrupt-based 
; If the LCD is currently enabled, undefined behavior.
; Inputs
;  NONE
; Outputs
;  NONE
; Modified: APSR
EnableLCD   PROC {R0-R14}
            PUSH    {R0-R2}
            ;Enable Clock gating
            LDR     R0,=SIM_SCGC5
            LDR     R1,[R0,#0]
            LDR     R2,=SIM_SCGC5_SLCD_MASK
            ORRS    R1,R1,R2
            STR     R1,[R0,#0]
;           ;Set interrupt priority
;           LDR     R0,=LCD_IPR
;           LDR     R1,[R0,#0]
;           LDR     R2,=LCD_PRI_MASK
;           BICS    R1,R1,R2
;           LDR     R2,=LCD_PRI_SET
;           ORRS    R1,R1,R2
;           STR     R1,[R0,#0]
;           ;Clear pending interrupts, unmask Interrupt
;           LDR     R0,=NVIC_ICPR
;           LDR     R1,=LCD_IRQ_MASK
;           STR     R1,[R0,#0]
;           LDR     R0,=NVIC_ISER
;           STR     R1,[R0,#0]
            ;Config Module
            LDR     R0,=LCD_BASE     
			
            
            ;Enable Module
            LDR     R1
            STR     R1,[R0,#LCD_GENCS_OFFSET]
            POP     {R0-R2}
            ENDP
                
            EXPORT  DisableTSI    
;Subroutine DisableLCD
; Disables the LCD.
; Inputs
;  NONE
; Outputs
;  NONE
; Modified: APSR
DisableLCD  PROC {R0-R14}
            PUSH    {R0-R2}
            ;Disable Module
            LDR     R0,=LCD_BASE
            LDR     R1,[R0,#LCD_GCR_OFFSET]
            MOVS    R2,#LCD_GCR_LCDEN_MASK
            BICS    R1,R1,R2
            STR     R1,[R0,#LCD_GCR_OFFSET]
            ;Disable Clock gating
            LDR     R0,=SIM_SCGC5
            LDR     R1,[R0,#0]
            LDR     R2,=SIM_SCGC5_SLCD_MASK
            BICS    R1,R1,R2
            STR     R1,[R0,#0]
            POP     {R0-R2}
            ENDP

                
            ALIGN
;**********************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;**********************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
            END