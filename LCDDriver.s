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

;LCD Fields
; (KL46 Family Data Sheet, p47-48)

;LCD Enable Mask
; LCD_GCR
;  VAL -> BIT
;   0  -> 31  :  RVEN   : No Regulated Voltage
; 0000 ->27-24: RVTRIM  : (Don't trim Regulated Voltage.)
;   1  -> 23  :  CPSEL  : Use Charge Pump
;  01  ->21-20:  LADJ   : Intermediate clock source (for glass cap 2000pF or less)
;   0  -> 17  : VSUPPLY : Use internal voltage supply.
;   1  -> 15  : PADSAFE : Use PADSAFE (disabled later in setup)
;   0  -> 14  : FDCIEN  : No interrupts
;  00  ->13-12: ALTDIV  : No clock divider
;   0  -> 11  :ALTSOURCE: (Alt Clock Source 1)
;   1  -> 10  :   FFR   : Fast frame rate
;   0  ->  9  : LCDDOZE : Don't disable in Doze Mode
;   0  ->  8  : LCDSTP  : Don't disable in Stop Mode
;   0  ->  7  :  LCDEN  : Don't Enable LCD (we'll do this later in setup)
;   0  ->  6  : SOURCE  : Use default clocks
;  001 -> 5-3 :  LCLK   : Use Clock Prescaler for clock frame freq of 51.2 Hz
;  011 -> 2-0 :  DUTY   : 1/4 Duty Cycle (Req'd by the on-board LCD)
LCD_GCR_SETUP   EQU (LCD_GCR_CPSEL_MASK :OR: (1 << LCD_GCR_LADJ_SHIFT) :OR: \
                     LCD_GCR_PADSAFE_MASK :OR: LCD_GCR_FFR_MASK :OR: \
                     (1 << LCD_GCR_LCLK_SHIFT) :OR: (3 << LCD_GCR_DUTY_SHIFT)) 

;LCD Disable Mask
; LCD_GENCS
;  VAL->BIT
;   0 -> 7 :LCDEN: Disables LCD
; Use LCD_GENCS_TSIE

;LCD pin enable setup
; Enables all pins hooked up to the LCD
; LCD_PENH - Set P37, P38, P40, P52, P53
; LCD_PENL - Set P7, P8, P10, P11, P17, P18, P19
LCD_PENH_COM   EQU 0x00300160
LCD_PENL_COM   EQU 0x000E0D80
;LCD COM backplane setup
; LCD_BPENH - Set LCD COM0 (P40) and COM1 (P52)
; LCD_BPENL - Set LCD COM2 (P19) and COM3 (P18)
LCD_BPENH_COM   EQU 0x00100100
LCD_BPENL_COM   EQU 0x000C0000

;LCD Segments (with COM0 = LCD_WF_A, COM1 = LCD_WF_B, COM2 = LCD_WF_C, COM3 = LCD_WF_D
;Segments ccording to the Lumex LCD-S401M16KR Data Sheet
    ; Lo phases
LCD_P_SEG   EQU LCD_WF_A_MASK
LCD_A_SEG   EQU LCD_WF_D_MASK
LCD_B_SEG   EQU LCD_WF_C_MASK
LCD_C_SEG   EQU LCD_WF_B_MASK
    ; Hi phases
LCD_D_SEG   EQU LCD_WF_A_MASK
LCD_E_SEG   EQU LCD_WF_B_MASK
LCD_F_SEG   EQU LCD_WF_D_MASK
LCD_G_SEG   EQU LCD_WF_C_MASK
    
;LCD Pins
LCD_ONES_HI EQU 37
LCD_ONES_LO EQU 17
LCD_TENS_HI EQU 7
LCD_TENS_LO EQU 8
LCD_100S_HI EQU 53
LCD_100S_LO EQU 38
LCD_KILO_HI EQU 10
LCD_KILO_LO EQU 11

;**********************************************************************
;MACROs

;Macro WriteLCDDig
; Solely intended for WriteLCDDec
; Arguments
;  Rlcd_wf - LCD_WF register, not destroyed. (R0-R7)
;  Rdecseg - LCD_DecSeg register, not destroyed. (R0-R7)
;  Rdig - Digit register, destroyed. (R0-R7)
;  Rfree - Scratch register, destroyed. (R0-R7)
;  pinh - Pin representing high phases as literal
;  pinl - Pin representing low phases as literal
            MACRO
            WriteLCDDig $Rlcd_wf,$Rdecseg,$Rdig,$Rfree,$pinh,$pinl
            IF      $pinl < 32
            LDRB    $Rfree,[$Rdecseg,$Rdig]
            STRB    $Rfree,[$Rlcd_wf,#($pinl)]
            ELSE    
            LDRB    $Rfree,[$Rdecseg,$Rdig]
            ADDS    $Rlcd_wf,$Rlcd_wf,#$pinl
            STRB    $Rfree,[$Rlcd_wf]
            SUBS    $Rlcd_wf,$Rlcd_wf,#$pinl
            ENDIF
            ADDS    $Rdig,$Rdig,#10
            IF      $pinh < 32
            LDRB    $Rfree,[$Rdecseg,$Rdig]
            STRB    $Rfree,[$Rlcd_wf,#($pinh)]
            ELSE    
            LDRB    $Rfree,[$Rdecseg,$Rdig]
            ADDS    $Rlcd_wf,$Rlcd_wf,#$pinh
            STRB    $Rfree,[$Rlcd_wf]
            SUBS    $Rlcd_wf,$Rlcd_wf,#$pinh
            ENDIF
            MEND
;**********************************************************************
;Program
            AREA    LCDCode,CODE,READONLY
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
            LDR     R2,=(SIM_SCGC5_SLCD_MASK :OR: SIM_SCGC5_PORTB_MASK :OR: \
                         SIM_SCGC5_PORTC_MASK :OR: SIM_SCGC5_PORTD_MASK :OR: \
                         SIM_SCGC5_PORTE_MASK) ;Need to enable other port mods too
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
            LDR     R2,=LCD_BASE
            MOV     R0,R2            
            LDR     R1,=LCD_GCR_SETUP
            STR     R1,[R0,#LCD_GCR_OFFSET]
            ; Enable Pins
            LDR     R1,=LCD_PENH_COM
            STR     R1,[R0,#LCD_PENH_OFFSET]
            LDR     R1,=LCD_PENL_COM
            STR     R1,[R0,#LCD_PENL_OFFSET]
            ; Configure backplanes
            LDR     R1,=LCD_BPENH_COM
            STR     R1,[R0,#LCD_BPENH_OFFSET]
            LDR     R1,=LCD_BPENL_COM
            STR     R1,[R0,#LCD_BPENL_OFFSET]
            ; Setup COM patterns
            LDR     R0,=LCD_WF     
            MOVS    R1,#LCD_WF_C_MASK
            STRB    R1,[R0,#19]
            MOVS    R1,#LCD_WF_D_MASK
            STRB    R1,[R0,#18]
            ADDS    R0,R0,#40
            MOVS    R1,#LCD_WF_A_MASK
            STRB    R1,[R0,#(40 - 40)]
            MOVS    R1,#LCD_WF_B_MASK
            STRB    R1,[R0,#(52 - 40)]
            ;Enable Module
            MOV     R0,R2          
            LDR     R1,[R0,#LCD_GCR_OFFSET]
            MOVS    R2,#LCD_GCR_LCDEN_MASK
            ORRS    R1,R1,R2
            STR     R1,[R0,#LCD_GCR_OFFSET]
            POP     {R0-R2}
			BX      LR
            ENDP
                
            EXPORT  DisableLCD   
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
			BX      LR
            ENDP

            EXPORT  WriteLCDDec 
            IMPORT  DIVU
;Subroutine WriteLCDDec
; Disables the LCD.
; Inputs
;  R0 - Unsigned number in decimal to write
; Outputs
;  NONE
; Modified: APSR
WriteLCDDec PROC {R1-R14}
            PUSH    {R0-R4}
            LDR     R2,=LCD_WF
            LDR     R3,=LCD_DecSeg
            MOV     R1,R0
            MOVS    R0,#10
            BL      DIVU
            WriteLCDDig R2,R3,R1,R4,LCD_ONES_HI,LCD_ONES_LO
            MOV     R1,R0
            MOVS    R0,#10
            BL      DIVU
            WriteLCDDig R2,R3,R1,R4,LCD_TENS_HI,LCD_TENS_LO
            MOV     R1,R0
            MOVS    R0,#10
            BL      DIVU
            WriteLCDDig R2,R3,R1,R4,LCD_100S_HI,LCD_100S_LO
            MOV     R1,R0
            MOVS    R0,#10
            BL      DIVU
            WriteLCDDig R2,R3,R1,R4,LCD_KILO_HI,LCD_KILO_LO
            POP     {R0-R4}
			BX      LR
            ENDP
                
          
            ALIGN
;**********************************************************************
;Constants
            AREA    LCDConst,DATA,READONLY
LCD_DecSeg ;Decimal segment representations
LCD_DS0_Lo  DCB     (LCD_A_SEG + LCD_B_SEG + LCD_C_SEG)
LCD_DS1_Lo  DCB     (LCD_B_SEG + LCD_C_SEG)
LCD_DS2_Lo  DCB     (LCD_A_SEG + LCD_B_SEG)
LCD_DS3_Lo  DCB     (LCD_A_SEG + LCD_B_SEG + LCD_C_SEG)
LCD_DS4_Lo  DCB     (LCD_B_SEG + LCD_C_SEG)
LCD_DS5_Lo  DCB     (LCD_A_SEG + LCD_C_SEG)
LCD_DS6_Lo  DCB     (LCD_A_SEG + LCD_C_SEG)
LCD_DS7_Lo  DCB     (LCD_A_SEG + LCD_B_SEG + LCD_C_SEG)
LCD_DS8_Lo  DCB     (LCD_A_SEG + LCD_B_SEG + LCD_C_SEG)
LCD_DS9_Lo  DCB     (LCD_A_SEG + LCD_B_SEG + LCD_C_SEG)
LCD_DS0_Hi  DCB     (LCD_D_SEG + LCD_E_SEG + LCD_F_SEG)
LCD_DS1_Hi  DCB     0
LCD_DS2_Hi  DCB     (LCD_D_SEG + LCD_E_SEG + LCD_G_SEG)
LCD_DS3_Hi  DCB     (LCD_D_SEG + LCD_G_SEG)
LCD_DS4_Hi  DCB     (LCD_F_SEG + LCD_G_SEG)
LCD_DS5_Hi  DCB     (LCD_D_SEG + LCD_F_SEG + LCD_G_SEG)
LCD_DS6_Hi  DCB     (LCD_D_SEG + LCD_E_SEG + LCD_F_SEG + LCD_G_SEG)
LCD_DS7_Hi  DCB     0
LCD_DS8_Hi  DCB     (LCD_D_SEG + LCD_E_SEG + LCD_F_SEG + LCD_G_SEG)
LCD_DS9_Hi  DCB     (LCD_D_SEG + LCD_F_SEG + LCD_G_SEG)

;**********************************************************************
;Variables
            AREA    LCDData,DATA,READWRITE
            END