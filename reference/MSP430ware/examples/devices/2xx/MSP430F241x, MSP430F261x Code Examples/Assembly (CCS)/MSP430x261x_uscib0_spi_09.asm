;*******************************************************************************
;   MSP430x261x Demo - USCI_B0, SPI 3-Wire Master Incremented Data
;
;   Description: SPI master talks to SPI slave using 3-wire mode. Incrementing
;   data is sent by the master starting at 0x01. Received data is expected to
;   be same as the previous transmission.  USCI RX ISR is used to handle
;   communication with the CPU, normally in LPM0. If high, P1.0 indicates
;   valid data reception.  Because all execution after LPM0 is in ISRs,
;   initialization waits for DCO to stabilize against ACLK.
;   ACLK = n/a, MCLK = SMCLK = DCO ~ 1048kHz.  BRCLK = SMCLK/2
;
;   Use with SPI Slave Data Echo code example.  If slave is in debug mode, P1.1
;   slave reset signal conflicts with slave's JTAG; to work around, use IAR's
;   "Release JTAG on Go" on slave device.  If breakpoints are set in
;   slave RX ISR, master must stopped also to avoid overrunning slave
;   RXBUF.
;
;                 MSP430F261x/241x
;                 -----------------
;             /|\|              XIN|-
;              | |                 |  
;              --|RST          XOUT|-
;                |                 |
;                |             P3.1|-> Data Out (UCB0SIMO)
;                |                 |
;          LED <-|P1.0         P3.2|<- Data In (UCB0SOMI)
;                |                 |
;  Slave reset <-|P1.1         P3.3|-> Serial Clock Out (UCB0CLK)
;
;  JL Bile
;  Texas Instruments Inc.
;  June 2008
;  Built Code Composer Essentials: v3 FET
;*******************************************************************************
 .cdecls C,LIST, "msp430x26x.h"
;-------------------------------------------------------------------------------
MST_Data	.equ    R6
SLV_Data	.equ	R7
;-------------------------------------------------------------------------------
			.text	;Program Start
;-------------------------------------------------------------------------------
RESET       mov.w   #0850h,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW+WDTHOLD,&WDTCTL  ; Stop watchdog timer
CheckCal    cmp.b   #0FFh,&CALBC1_1MHZ      ; Calibration constants erased?
            jeq     Trap
            cmp.b   #0FFh,&CALDCO_1MHZ
            jne     Load  
Trap        jmp     $                       ; Trap CPU!!
Load        mov.b   &CALBC1_1MHZ,&BCSCTL1   ; Set DCO to 1MHz
            mov.b   &CALDCO_1MHZ,&DCOCTL    ;  
            
SetupP1     clr.b   &P1OUT                  ; 
            bis.b   #03h,&P1DIR             ; P1 setup for LED and slave reset
            mov.b   #02h,&P1OUT             ; Set slave reset
SetupP3     bis.b   #00Eh,&P3SEL             ; P3.3,2,1 option select
SetupSPI    bis.b   #UCCKPL+UCMSB+UCMST+UCSYNC,&UCB0CTL0;3-pin, 8-bit SPI master
            bis.b   #UCSSEL_2,&UCB0CTL1     ; SMCLK
            bis.b   #02h,&UCB0BR0           ; /2
            clr.b   &UCB0BR1                ;
            bic.b   #UCSWRST,&UCB0CTL1      ; **Initialize USCI state machine**
            bis.b   #UCB0RXIE,&IE2          ; Enable USCI_B0 RX interrupt

            bic.b   #02h,&P1OUT             ; Now with SPI signals initialized,
            bis.b   #02h,&P1OUT             ; reset slave
            mov.w   #50,R15                 ; Wait for slave to initialize
waitForSlv  dec.w   R15                     ;
            jnz     waitForSlv              ;
                                            ;
            mov.b   #001h,MST_Data          ; Initialize data values
            mov.b   #000h,SLV_Data          ;
                                            ;
Mainloop    mov.b   MST_Data,&UCB0TXBUF     ; Transmit first character
            bis.b   #LPM0+GIE,SR            ; CPU off, enable interrupts
            nop                             ; Required for debugger only
                                            ;
;-------------------------------------------------------------------------------
USCIB0RX_ISR;       Test for valid RX and TX character
;-------------------------------------------------------------------------------
TX1         bit.b   #UCB0TXIFG,&IFG2        ; USCI_B0 TX buffer ready?
            jz      TX1                     ; Jump is TX buffer not ready
                                            ;
            cmp.b   SLV_Data,&UCB0RXBUF     ; Test for correct character RX'd
            jeq     Pass                    ;
Fail        bic.b   #01h,&P1OUT             ; If incorrect, clear LED
            jmp     TX2                     ;
Pass        bis.b   #01h,&P1OUT             ; If correct, light LED
TX2         inc.b   MST_Data                ; Increment master value
            inc.b   SLV_Data                ; Increment expected slave value
            mov.b   MST_Data,&UCB0TXBUF     ; Send next value
                                            ;
            mov.w   #30,R15                 ; Add time between transmissions to
cycleDelay  dec.w   R15                     ; make sure slave can keep up
            jnz     cycleDelay              ;
            reti                            ; Exit ISR
;-------------------------------------------------------------------------------
;			Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".int23"		        ; USCI_B0 Rx Vector
            .short  USCIB0RX_ISR            ;
            .sect   ".reset"	            ; POR, ext. Reset, Watchdog
            .short  RESET
            .end
