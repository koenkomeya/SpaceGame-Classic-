      TTL Touch Sensing Driver
;**********************************************************************
;This module implements a driver for the TSI0 module, which does touch
; sensing detection. It utilizes interrupts to do scans.
;This module can be installed by including this file and setting the
; interrupt vector 42 to the TSI0_IRQHandler handler in this file for
; pure assembly projects. It automagically installs for projects with
; the Device>Startup package installed.
;Name:  Koen Komeya 
;Date:  November 26, 2017
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
TSI0_PRI_MASK   EQU (3 << TSI0_PRI_POS)
    
;TSI0 Interrupt Priority Set
;See above
TSI0_PRI_SET    EQU (TSI0_PRI << TSI0_PRI_POS)

;TSI0 NVIC Register Mask
; NVIC_IXXR
;  VAL->BIT
;   1 -> 26 :TSI0: Mask for the NVIC's IXXR registers for TSI0.
; Using TSI0_IRQ_MASK
                         
;(F)GPIO Mask for Pins PTB17
PTB17_MASK      EQU (1 << 17)

;TSI Channels
TSI_ELECTRODE1  EQU 9
TSI_ELECTRODE2  EQU 10

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
TSI0_GENCS_EOSF_MASK    EQU 0x00000004
TSI0_GENCS_EOSF_SHIFTPLUS1  EQU (2+1)
    
TSI0_DATA_TSICH_SHIFT   EQU 28
TSI0_DATA_SWTS_MASK     EQU 0x00400000
TSI0_DATA_TSICNT_MASK   EQU 0x0000FFFF

;TSI0 Enable Mask
; TSI0_GENCS
;  VAL -> BIT
;   1  -> 31  :OUTRGF : Clear out of range Flag
;   1  -> 28  : ESOR  : Use end of scan interrupts
;  0000->27-24: MODE  : Use capacitive sensing mode
;  111 ->23-21:REFCHRG: 16 microAmp charge value                  
;   01 ->20-19: DVOLT : deltaV = 0.7?                             NOTE (Contradictory dV values???)
;  101 ->18-16:EXTCHRG: 64 microAmp charge value
;  000 ->15-13:  PS   : Don't prescale output of reference oscillator
;  0000->12- 8: NSCN  : Scan Once
;   1  ->  7  : TSIEN : Enables TSI0
;   1  ->  6  :TSIIEN : Enable Interrupts
;   1  ->  5  : STPE  : Enable TSI0 in low power mode
;   0  ->  4  :  STM  : Use Software for Trigger scan
;   0  ->  1  : CURSW : Don't swap oscillators
TSI0_EN_1       EQU 0x90CD00E0
    
	
;TSI0 Data Config + Scan
; TSI0_DATA
;  VAL -> BIT
;  1001->31-28:TSICH: Use Channel 9 (corresponds to electrode 1 of sensor)
;  1010->31-28:TSICH: Use Channel 10 (corresponds to electrode 2 of sensor)
;   0  -> 23  :DMAEN: No DMA for interrupts
;   1  -> 22  : SWT : Trigger a scan
TSI0_DATA_SCAN9     EQU ((TSI_ELECTRODE1 << TSI0_DATA_TSICH_SHIFT) :OR: TSI0_DATA_SWTS_MASK)
TSI0_DATA_SCAN10    EQU ((TSI_ELECTRODE2 << TSI0_DATA_TSICH_SHIFT) :OR: TSI0_DATA_SWTS_MASK)

;TSI0 Disable Mask
; TSI0_GENCS
;  VAL->BIT
;   0 -> 7 :TSIEN: Disables TSI0
; Use TSI0_GENCS_TSIEN_MASK

;Settings
;The high threshold (16-bits)
;TSI0_HI_THRESHOLD   EQU 234                                    ; Calibrate
;The low threshold (16-bits)
;TSI0_LO_THRESHOLD   EQU 0



;**********************************************************************
;MACROs
;**********************************************************************
;Program
            AREA    TouchCode,CODE,READONLY
            EXPORT  EnableTSI   
;Subroutine EnableTSI
; Initializes the TSI for interrupt-based 
; If the TSI is currently enabled, undefined behavior.
; Inputs
;  NONE
; Outputs
;  NONE
; Modified: APSR
EnableTSI   PROC    {R0-R14}
            PUSH    {R0-R2,LR}
            ;Enable system clock to the PORTB.
            LDR     R0,=SIM_SCGC5
            LDR     R1,[R0,#0]
            LDR     R2,=SIM_SCGC5_PORTB_MASK
            ORRS    R1,R1,R2
            STR     R1,[R0,#0]
            ;Allow PTB16,PTB17 (Electrodes) to connect to TSI0
            LDR     R0,=PORTB_BASE
            ;[Already fused directly to TSI]
            ;[By default it should be low, so we don't need to exp. set it]
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
            LDR     R0,=TSI0_BASE     ;(Note to self: Internal reference capacitor is 1.0pF)
            ;LDR     R1,=TSI0_DATA_1  ; We don't need to do this yet because it is set when scan starts
            ;STR     R1,[R0,#TSI0_DATA_OFFSET]
            ;Enable Module
            LDR     R1,=TSI0_EN_1
            STR     R1,[R0,#TSI0_GENCS_OFFSET]
            ;Get Untouched values and add 2 to each to get threshold values.
            BL      ScanTSI
ETSIScanWait; Wait for scan to complete
            LDR     R0,=ScanDone
            LDRB    R1,[R0]
            CMP     R1,#0
            BEQ     ETSIScanWait
            ; Copy values into threshold
            LDR     R0,=Scan1Res
            LDM     R0!,{R1}
            LDR     R2,=0x00020002 ;Add 2 to each threshold
            ADD     R1,R1,R2
            STR     R1,[R0]
            POP     {R0-R2,PC}
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
;           ;Disable Interrupts
;           LDR     R0,=NVIC_ICER
;           LDR     R1,=TSI0_IRQ_MASK
;           STR     R1,[R0,#0]
            ;Disable Clock gating
            LDR     R0,=SIM_SCGC5
            LDR     R1,[R0,#0]
            MOVS    R2,#SIM_SCGC5_TSI_MASK
            BICS    R1,R1,R2
            STR     R1,[R0,#0]
            POP     {R0-R2}
			BX      LR
            ENDP


            EXPORT  ScanTSI
;Subroutine ScanTSI
; Tells the TSI to start a scan.
; Inputs
;  NONE
; Outputs
;  NONE
; Modified: APSR
ScanTSI     PROC    {R0-R14}
            PUSH    {R0-R1}
            ;Clear ScanDone
            LDR     R0,=ScanDone
            MOVS    R1,#0
            STRB    R1,[R0,#0]
	        ;Start a software scan
            LDR     R0,=TSI0_BASE
			LDR     R1,=TSI0_DATA_SCAN9
			STR     R1,[R0,#TSI0_DATA_OFFSET]
            POP     {R0-R1}
			BX      LR
	        ENDP
				
		    IMPORT  DIVU
            EXPORT  ReadTSIScaled 
;Subroutine ReadTSIScaled
; Determines where the TSI0 is pressed and scales the value to -128~127.
; Returns 0 if the TSI is currently not being pressed.
; ScanTSI must be called before this is called.
; Inputs
;  NONE
; Outputs
;  R0 - The scaled TSI press location.
; Modified: R0, APSR
ReadTSIScaled PROC {R1-R14}
            PUSH    {R1-R3,LR}
			;Wait for scan to complete
            LDR     R1,=ScanDone
RTSScanWait	
            ;Old method (Single electrode)
            ;LDR     R1,[R0,#TSI0_GENCS_OFFSET]
			;LSRS    R2,R1,#TSI0_GENCS_EOSF_SHIFTPLUS1 ;Shift to carry
			;BCC     RTSScanWait
            ;New method
            LDRB    R2,[R1]
            CMP     R2,#0
            BEQ     RTSScanWait
            ;based on approach @ os.mbed.com/users/Kojto/code/tsi_sensor
            LDR     R0,=Scan1Res
            LDM     R0,{R0,R1}
            ; electrode 1 
            UXTH    R2,R0
            UXTH    R3,R1
            SUBS    R2,R2,R3
            BLO     RTS_E1TooSmall
            ; electrode 2
            LSRS    R0,R0,#16
            LSRS    R1,R1,#16
            SUBS    R0,R0,R1
            BMI     RTS_Min  ;Ensures we are positive (if not, it will be minimal)
RTS_EndElec2Calc
            LSLS    R1,R0,#8 ;Dividend = Elec2Rel 
            ADD     R0,R0,R2 ;Divisor = Elec1Rel + Elec2Rel 
            BL      DIVU
            SUBS    R0,R0,#128
            ; Bounds checking
            CMP     R0,#128
            BGE     RTS_Max
            MOVS    R1,#128
            CMN     R0,R1
            BLT     RTS_Min
            POP     {R1-R3,PC}
RTS_E1TooSmall 
            ;When the capacitance of electrode 1 is too small, if capacitance
            ; of electrode 2 is too small, return 0.
            MOVS    R2,#0
            LSRS    R0,R0,#16
            LSRS    R1,R1,#16
            SUBS    R0,R0,R1
            BHS     RTS_EndElec2Calc
            MOVS    R0,#0
            POP     {R1-R3,PC}
RTS_Min     ;We got a value of -129 or less, return -128
            MOVS    R0,#127
            MVNS    R0,R0
            POP     {R1-R3,PC}
RTS_Max     ;We got a value of 128 or more, return 127
            MOVS    R0,#127
            POP     {R1-R3,PC}
	        ENDP
	
            EXPORT  TSI0_IRQHandler
;Interrupt Service Routine TSI0_IRQHandler
; Handles interrupts for the TSI0.
; Modified: R0-R1, APSR (NONE if via Interrupt)
TSI0_IRQHandler PROC {R4-R11}
            LDR     R0,=TSI0_BASE
            LDR     R1,[R0,#TSI0_GENCS_OFFSET]
			;Clear scan complete
			STR     R1,[R0,#TSI0_GENCS_OFFSET]
	        ;Determine the value 
			LDR     R0,[R0,#TSI0_DATA_OFFSET]
			LDR     R1,=TSI0_DATA_TSICNT_MASK
			ANDS    R1,R0,R1
            ;Determine which electrode is being scanned
            LSRS    R0,R0,#TSI0_DATA_TSICH_SHIFT
            CMP     R0,#TSI_ELECTRODE2
            BEQ     TIH_Elec2
TIH_Elec1   ;Code for Electrode 1
            ; Save Value
            LDR     R0,=Scan1Res
            STRH    R1,[R0]
            ; Start Scanning for Electrode 2
            LDR     R0,=TSI0_BASE
			LDR     R1,=TSI0_DATA_SCAN10
			STR     R1,[R0,#TSI0_DATA_OFFSET]
            BX      LR     
TIH_Elec2   ;Code for Electrode 2
            ; Save Value
            LDR     R0,=Scan2Res
            STRH    R1,[R0]
            ; Set ScanDone
            LDR     R0,=ScanDone
            MOVS    R1,#1
            STRB    R1,[R0]
            BX      LR                 
            ENDP
                
            ALIGN
;**********************************************************************
;Constants
            AREA    TouchConst,DATA,READONLY
;**********************************************************************
;Variables
            AREA    TouchData,DATA,READWRITE
;Do NOT change order of following 4 variables without removing optimizations in 
; EnableTSI and ReadTSIScaled
Scan1Res    SPACE   2   ;Result of Electrode 1 Scan
Scan2Res    SPACE   2   ;Result of Electrode 2 Scan
Threshold1  SPACE   2   ;Electrode 1 Threshold
Threshold2  SPACE   2   ;Electrode 2 Threshold
ScanDone    SPACE   1   ;Used by TSI0_IRQHandler to state that the scan is complete. (0=Not Done; 1=Done)
            END
