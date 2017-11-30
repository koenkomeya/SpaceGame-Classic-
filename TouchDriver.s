      TTL Touch Sensing Driver
;**********************************************************************
;This module implements a driver for the TSI0 module, which does touch
; sensing detection. 
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
TSI0_PRI_MASK EQU (3 << TSI0_PRI_POS)
    
;TSI0 Interrupt Priority Set
;See above
TSI0_PRI_SET  EQU (TSI0_PRI << TSI0_PRI_POS)

;TSI0 NVIC Register Mask
; NVIC_IXXR
;  VAL->BIT
;   1 -> 26 :TSI0: Mask for the NVIC's IXXR registers for TSI0.
; Using TSI0_IRQ_MASK

;PORTB Hold Low Configuration
; Partially configures the other electrode of the touch input to hold low.
; PORTB_PCRn
;  VAL-> BIT
;   1 -> 24  :ISF : Clear Interrupt Status Flag
; XXXX->19-16:IRQC: PORTB doesn't support interrupts.
;  001->10-8 :MUX : Connect port to GPIO
;   X ->  6  :DSE : Port PTB17 does not support high drive
;   X ->  4  :PFE : (Read-only for these pins)
;   1 ->  2  :SRE : Slow Slew Rate (this will be held 0)
;   0 ->  1  : PE : Disable pull-xx resistor.
;   X ->  0  : PS : PE is disabled
PORTB_LOW_OUT_CONFIG    EQU (PORT_PCR_ISF_MASK :OR: \
                         PORT_PCR_MUX_SELECT_1_MASK :OR: \
                         PORT_PCR_SRE_MASK)
                         
;(F)GPIO Mask for Pins PTB17
PTB17_MASK    EQU (1 << 17)

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
;   0  -> 28  : ESOR  : Use out of range interrupts
;  0000->27-24: MODE  : Use capacitive sensing mode
;  101 ->23-21:REFCHRG: 16 microAmp charge value                  
;   01 ->20-19: DVOLT : deltaV = 0.7?                             NOTE (Contradictory dV values???)
;  111 ->18-16:EXTCHRG: 64 microAmp charge value
;  000 ->15-13:  PS   : Don't prescale output of reference oscillator
;  0011->12- 8: NSCN  : Scan 4 Times
;   1  ->  7  : TSIEN : Enables TSI0
;   0  ->  6  :TSIIEN : Disable Interrupts
;   1  ->  5  : STPE  : Enable TSI0 in low power mode
;   0  ->  4  :  STM  : Use Software for Trigger scan
;   0  ->  1  : CURSW : Don't swap oscillators
TSI0_EN_1     EQU 0x80AF03A0
    
    
;TSI0 Data Config
; TSI0_DATA
;  VAL -> BIT
;  1001->31-28:TSICH: Use Channel 9 (corresponds to electrode 1 of sensor)
;   0  -> 23  :DMAEN: No DMA for interrupts
;   0  -> 22  : SWT : Don't software trigger yet.
TSI0_DATA_1   EQU (9 << TSI0_DATA_TSICH_SHIFT)
	
;TSI0 Data Config + Scan
; TSI0_DATA
;  VAL -> BIT
;  1001->31-28:TSICH: Use Channel 9 (corresponds to electrode 1 of sensor)
;   0  -> 23  :DMAEN: No DMA for interrupts
;   1  -> 22  : SWT : Trigger a scan
TSI0_DATA_1_SCAN   EQU (TSI0_DATA_1 :OR: TSI0_DATA_SWTS_MASK)

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

;The high side of the capacitance when being pressed (16-bits) (Left Side)
TSI0_HI_THRESHOLD   EQU 235                                     ;FIXME Calibrate
;The low side of the capacitance when being pressed (16-bits) (Right Side)
TSI0_LO_THRESHOLD   EQU 234


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
EnableTSI   PROC    {R0-R14}
            PUSH    {R0-R2}
            ;Enable system clock to the PORTB.
            LDR     R0,=SIM_SCGC5
            LDR     R1,[R0,#0]
            LDR     R2,=SIM_SCGC5_PORTB_MASK
            ORRS    R1,R1,R2
            STR     R1,[R0,#0]
            ;Allow PTB16 (Electrode) to connect to TSI0
            LDR     R0,=PORTB_BASE
            ;[Already fused directly to TSI]
            ;Set PTB17 (Electrode) to low.
            LDR     R1,=PORTB_LOW_OUT_CONFIG
            STR     R1,[R0,#PORTB_PCR16_OFFSET]
            LDR     R0,=FGPIOB_BASE
            LDR     R1,=PTB17_MASK
            STR     R1,[R0,#GPIO_PDDR_OFFSET]
            ;[By default it should be low, so we don't need to exp. set it]
            ;Enable Clock gating
            LDR     R0,=SIM_SCGC5
            LDR     R1,[R0,#0]
            MOVS    R2,#SIM_SCGC5_TSI_MASK
            ORRS    R1,R1,R2
            STR     R1,[R0,#0]
;           ;Set interrupt priority
;           LDR     R0,=TSI0_IPR
;           LDR     R1,[R0,#0]
;           LDR     R2,=TSI0_PRI_MASK
;           BICS    R1,R1,R2
;           LDR     R2,=TSI0_PRI_SET
;           ORRS    R1,R1,R2
;           STR     R1,[R0,#0]
;           ;Clear pending interrupts, unmask Interrupt
;           LDR     R0,=NVIC_ICPR
;           LDR     R1,=TSI0_IRQ_MASK
;           STR     R1,[R0,#0]
;           LDR     R0,=NVIC_ISER
;           STR     R1,[R0,#0]
            ;Config Module
            LDR     R0,=TSI0_BASE     ;(Note to self: Internal reference capacitor is 1.0pF)
            ;LDR     R1,=TSI0_DATA_1  ; We don't need to do this yet because it is set when scan starts
            ;STR     R1,[R0,#TSI0_DATA_OFFSET]
            ;Enable Module
            LDR     R1,=TSI0_EN_1
            STR     R1,[R0,#TSI0_GENCS_OFFSET]
            POP     {R0-R2}
			BX      LR
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
	        ;Start a software scan
            LDR     R0,=TSI0_BASE
			LDR     R1,=TSI0_DATA_1_SCAN
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
            PUSH    {R1-R2,LR}
            LDR     R0,=TSI0_BASE
			;Wait for scan to complete
RTSScanWait	LDR     R1,[R0,#TSI0_GENCS_OFFSET]
			LSRS    R2,R1,#TSI0_GENCS_EOSF_SHIFTPLUS1 ;Shift to carry
			BCC     RTSScanWait
			;Clear scan complete
			STR     R1,[R0,#TSI0_GENCS_OFFSET]
	        ;Determine the value 
			LDR     R0,[R0,#TSI0_DATA_OFFSET]
			LDR     R1,=TSI0_DATA_TSICNT_MASK
			ANDS    R1,R0,R1
			LDR     R2,=TSI0_LO_THRESHOLD
			SUBS    R1,R1,R2
			BLT     RTSCapTooSmall           ;If capacitance is too small, branch
		    LDR     R0,=(TSI0_HI_THRESHOLD - TSI0_LO_THRESHOLD)
RTS_IfGrThres ;If the raw value is greater than the high threshold.
            CMP     R1,R0
			BGE     RTS_WhenGrThres
RTS_EndIfGrThres	
			LSLS    R1,R1,#8                 ;raw  *= 256
			BL      DIVU                     ;raw2 /= threshold range
			SUBS    R0,R0,#127               ;Approximate transform into a signed value.
			RSBS    R0,R0,#0                 ;Negation of R0 to -128~127
            POP     {R1-R2,PC}
RTSCapTooSmall ;When the capacitance is too small, return 0
            MOVS    R0,#0
            POP     {R1-R2,PC}
RTS_WhenGrThres
            MOVS    R0,#127
			MVNS    R0,R0                    ;R0 = -128.
            POP     {R1-R2,PC}
	        ENDP
	
;Interrupt Service Routine TSI0_IRQHandler
; Handles interrupts for the TSI0.
; Modified: R0-R3, APSR (NONE if via Interrupt)
;TSI0_IRQHandler PROC {R4-R11}
;	        ;TODO remove if this turns out to be unneeded.
;           BX      LR                 
;           ENDP
                
            ALIGN
;**********************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;**********************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
            END