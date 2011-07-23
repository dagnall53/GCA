   	TITLE		"Source for CAN accessory decoder using CBUS"
; filename ACC4_2a.asm
; use with ACC4_2 pcb rev A

;ACC4_2 is a modified version of ACC4_h for use with a 12V system
;Incorporates drive for the voltage doubler
;Changes 07/06/10
;RA4 is the doubler drive. Uses the LPINT for a 50Hz square wave
;RA0 is the charge cutoff. Hi is run, low is off.
;Tested 07/06/10. Works OK



;end of comments for ACC4_2



;	
; Assembly options
	LIST	P=18F2480,r=hex,N=75,C=120,T=ON

	include		"p18f2480.inc"

;set config registers

; note. there seem to be differences in the naming of the CONFIG parameters between
; versions of the p18F2480.inf files

	CONFIG	FCMEN = OFF, OSC = HSPLL, IESO = OFF
	CONFIG	PWRT = ON,BOREN = BOHW, BORV=0
	CONFIG	WDT=OFF
	CONFIG	MCLRE = ON
	CONFIG	LPT1OSC = OFF, PBADEN = OFF
	CONFIG	DEBUG = OFF
	CONFIG	XINST = OFF,LVP = OFF,STVREN = ON,CP0 = OFF
	CONFIG	CP1 = OFF, CPB = OFF, CPD = OFF,WRT0 = OFF,WRT1 = OFF, WRTB = OFF
	CONFIG 	WRTC = OFF,WRTD = OFF, EBTR0 = OFF, EBTR1 = OFF, EBTRB = OFF
	
;original CONFIG settings left here for reference
	
;	__CONFIG	_CONFIG1H,	B'00100110'	;oscillator HS with PLL
;	__CONFIG	_CONFIG2L,	B'00001110'	;brown out voltage and PWT	
;	__CONFIG	_CONFIG2H,	B'00000000'	;watchdog time and enable (disabled for now)
;	__CONFIG	_CONFIG3H,	B'10000000'	;MCLR enable	
;	__CONFIG	_CONFIG4L,	B'10000001'	;B'10000001'  for 	no debug
;	__CONFIG	_CONFIG5L,	B'00001111'	;code protection (off)	
;	__CONFIG	_CONFIG5H,	B'11000000'	;code protection (off)	
;	__CONFIG	_CONFIG6L,	B'00001111'	;write protection (off)	
;	__CONFIG	_CONFIG6H,	B'11100000'	;write protection (off)	
;	__CONFIG	_CONFIG7L,	B'00001111'	;table read protection (off)	
;	__CONFIG	_CONFIG7H,	B'01000000'	;boot block protection (off)




;	processor uses 4 MHz resonator but clock is 16 MHz.

;**************************************************************************
;definitions

LEARN 		equ 4	;input bits in port B
POL			equ 5
UNLEARN		equ	5	;setup jumper in port A (unlearn)
S_PORT		equ	PORTA
S_BIT		equ	3	;PB input
LED_PORT	equ	PORTB
LED2		equ	7
LED1		equ 6



CMD_ON	equ	0x90	;on event
CMD_OFF	equ	0x91	;off event
CMD_REQ	equ	0x92
SCMD_ON	equ	0x98
SCMD_OFF	equ	0x99
SCMD_REQ	equ	0x9A
EN_NUM  equ	.32		;number of allowed events
EV_NUM  equ 2		;number of allowed EVs per event
NV_NUM	equ	.16		;number of allowed NVs for node (provisional)
ACC4_ID equ 1

Modstat equ 1		;address in EEPROM

;module parameters  change as required

Para1	equ	.165	;manufacturer number
Para2	equ	 "H"	;for now
Para3	equ	ACC4_ID
Para4	equ EN_NUM		;node descriptors (temp values)
Para5	equ EV_NUM
Para6	equ NV_NUM
Para7	equ 0

; definitions used by bootloader

#define	MODE_SELF_VERIFY	;Enable self verification of written data (undefine if not wanted)

#define	HIGH_INT_VECT	0x0808	;HP interrupt vector redirect. Change if target is different
#define	LOW_INT_VECT	0x0818	;LP interrupt vector redirect. Change if target is different.
#define	RESET_VECT	0x0800	;start of target
#define	CAN_CD_BIT	RXB0EIDL,0	;Received control / data select bit
#define	CAN_PG_BIT	RXB0EIDL,1	;Received PUT / GET bit
#define	CANTX_CD_BIT	TXB0EIDL,0	;Transmit control/data select bit
#define	CAN_TXB0SIDH	B'10000000'	;Transmitted ID for target node
#define	CAN_TXB0SIDL	B'00001000'
#define	CAN_TXB0EIDH	B'00000000'	;
#define	CAN_TXB0EIDL	B'00000100'
#define	CAN_RXF0SIDH	B'00000000'	;Receive filter for target node
#define	CAN_RXF0SIDL	B'00001000'
#define	CAN_RXF0EIDH	B'00000000'
#define	CAN_RXF0EIDL	B'00000111'
#define	CAN_RXM0SIDH	B'11111111'	;Receive masks for target node
#define	CAN_RXM0SIDL	B'11101011'
#define	CAN_RXM0EIDH	B'11111111'
#define	CAN_RXM0EIDL	B'11111000'
#define	CAN_BRGCON1		B'00000011'	;CAN bit rate controls. As for other CBUS modules
#define	CAN_BRGCON2		B'10011110'
#define	CAN_BRGCON3		B'00000011'
#define	CAN_CIOCON		B'00100000'	;CAN I/O control	
;	************************************************************ ** * * * * * * * * * * * * * * *
;	************************************************************ ** * * * * * * * * * * * * * * *
#ifndef	EEADRH		
#define	EEADRH	EEADR+ 1	
#endif			
#define	TRUE	1	
#define	FALSE	0	
#define	WREG1	PRODH	; Alternate working register
#define	WREG2	PRODL	
#define	MODE_WRT_UNLCK	_bootCtlBits, 0	; Unlock write and erase
#define	MODE_ERASE_ONLY	_bootCtlBits, 1	; Erase without write
#define	MODE_AUTO_ERASE	_bootCtlBits, 2	; Enable auto erase before write
#define	MODE_AUTO_INC	_bootCtlBits, 3	; Enable auto inc the address
#define	MODE_ACK		_bootCtlBits, 4	; Acknowledge mode
#define	ERR_VERIFY		_bootErrStat, 0	; Failed to verify if set
#define	CMD_NOP			0x00	
#define	CMD_RESET		0x01	
#define	CMD_RST_CHKSM	0x02	
#define	CMD_CHK_RUN		0x03
#define CMD_BOOT_TEST 	0x04	




;****************************************************************
;	define RAM storage

;	RAM addresses used by boot. can also be used by application.

	CBLOCK 0
	_bootCtlMem
	_bootAddrL		; Address info
	_bootAddrH		
	_bootAddrU		
	_unused0		;(Reserved)
	_bootCtlBits	; Boot Mode Control bits
	_bootSpcCmd		; Special boot commands
	_bootChkL		; Chksum low byte fromPC
	_bootChkH		; Chksum hi byte from PC		
	_bootCount		
	_bootChksmL		; 16 bit checksum
	_bootChksmH		
	_bootErrStat	;Error Status flags
	ENDC
	
	; end of bootloader RAM
;************************************************************
	
	CBLOCK	0		;file registers - access bank
					;interrupt stack for low priority
					;hpint uses fast stack
	W_tempL
	St_tempL
	Bsr_tempL
	PCH_tempH		;save PCH in hpint
	PCH_tempL		;save PCH in lpint
	Fsr_temp0L
	Fsr_temp0H 
	Fsr_temp1L
	Fsr_temp1H 
	Fsr_temp2L
	TempCANCON
	TempCANSTAT
	Datmode			;flag for data waiting 
	Count			;counter for loading
	Count1
	Count2

	Cmdtmp		;command temp for number of bytes in frame jump table
	
	DNindex		;holds number of allowed DNs
	Match		;match flag

	ENcount		;which EN matched
	ENend		;last  EN number
	ENtemp
	EVtemp		;holds current EV
	EVtemp1	
	EVtemp2	
	IDcount		;used in self allocation of CAN ID.
	Latcount
	Keepcnt	;keepalive count
	Mode		;for FLiM / SLiM etc
	Mask
	Shift
	Shift1
	Eadr		;temp eeprom address
	
	Temp			;temps
	Temp1
	CanID_tmp	;temp for CAN Node ID
	IDtemph		;used in ID shuffle
	IDtempl
	NN_temph		;node number in RAM
	NN_templ
	ENtemp1			;number of events
	Dlc				;data length for CAN TX
	
	
	
	

	
	
	Rx0con			;start of receive packet 0
	Rx0sidh
	Rx0sidl
	Rx0eidh
	Rx0eidl
	Rx0dlc
	Rx0d0
	Rx0d1
	Rx0d2
	Rx0d3
	Rx0d4
	Rx0d5
	Rx0d6
	Rx0d7
	
	Tx1con			;start of transmit frame  1
	Tx1sidh
	Tx1sidl
	Tx1eidh
	Tx1eidl
	Tx1dlc
	Tx1d0
	Tx1d1
	Tx1d2
	Tx1d3
	Tx1d4
	Tx1d5
	Tx1d6
	Tx1d7
		
	
	
		

	;***************************************************************
	Timout		;used in timer routines
	Timbit		;
	Timset		;
	Timtemp
	T1a			;timer registers for each output
	T1b
	T2a
	T2b
	T3a
	T3b
	T4a
	T4b
	;****************************************************************
	Opnum		;used in testing for number match
	Opbit		;bit to set or clear in output	
	Opbit1		;temp used in output routine	
	;*************************************************************
	
	Outtmp		;used to sort out output
	Togmode		;outputs to toggle
	;

	Roll		;rolling bit for enum
	
	Fsr_tmp1Le	;temp store for FSR1
	Fsr_tmp1He 
	Enum0		;bits for new enum scheme.
	Enum1
	Enum2
	Enum3
	Enum4
	Enum5
	Enum6
	Enum7
	Enum8
	Enum9
	Enum10
	Enum11
	Enum12
	Enum13
	
	
		
	ENDC

;****************************************************************
	
	CBLOCK	0x100		;bank 1
	EN1					;start of EN ram
	EN1a
	EN1b
	EN1c
	
	EN2
	EN2a
	EN2b
	EN2c
	
	ENDC
	CBLOCK	0x200		;bank 2
	EV1					;start of EV ram
	ENDC
	
	

; This is the bootloader section

;*	Filename Boot2.asm  30/10/09

;*************************************************************** * * * * * * * * * * * * * * ;*
;*	CBUS bootloader

;*	Based on the Microchip botloader 'canio.asm' tho which full acknowledgement is made.
;*	Relevant information is contained in the Microchip Application note AN247

;*
;* Basic Operation:
;* The following is a CAN bootloader designed for PIC18F microcontrollers
;* with built-in CAN such as the PIC18F458. The bootloader is designed to
;* be simple, small, flexible, and portable.
;*
;
;
;*
;* Commands:
;* Put commands received from source (Master --> Slave)
;* The count (DLC) can vary.
;* XXXXXXXXXXX 0 0 8 XXXXXXXX XXXXXX00 ADDRL ADDRH ADDRU RESVD CTLBT SPCMD CPDTL CPDTH
;* XXXXXXXXXXX 0 0 8 XXXXXXXX XXXXXX01 DATA0 DATA1 DATA2 DATA3 DATA4 DATA5 DATA6 DATA7
;*


;*
;* ADDRL - Bits 0 to 7 of the memory pointer.
;* ADDRH - Bits 8 - 15 of the memory pointer.
;* ADDRU - Bits 16 - 23 of the memory pointer.
;* RESVD - Reserved for future use.
;* CTLBT - Control bits.
;* SPCMD - Special command.
;* CPDTL - Bits 0 - 7 of 2s complement checksum
;* CPDTH - Bits 8 - 15 of 2s complement checksum
;* DATAX - General data.
;*
;* Control bits:
;* MODE_WRT_UNLCK-Set this to allow write and erase operations to memory.
;* MODE_ERASE_ONLY-Set this to only erase Program Memory on a put command. Must be on 64-byte
;*	boundary.
;* MODE_AUTO_ERASE-Set this to automatically erase Program Memory while writing data.
;* MODE_AUTO_INC-Set this to automatically increment the pointer after writing.
;* MODE_ACK-Set this to generate an acknowledge after a 'put' (PG Mode only)
;*
;* Special Commands:
;* CMD_NOP			0x00	Do nothing
;* CMD_RESET		0x01	Issue a soft reset after setting last EEPROM data to 0x00
;* CMD_RST_CHKSM 	0x02	Reset the checksum counter and verify
;* CMD_CHK_RUN		0x03	Add checksum to special data, if verify and zero checksum
;* CMD_BOOT_TEST 	0x04	Just sends a message frame back to verify boot mode.

;*	Modified version of the Microchip code by M Bolton  30/10/09
;
;	The user program must have the folowing vectors

;	User code reset vector  0x0800
;	User code HPINT vector	0x0808
;	user code LPINT vector	0x0818

;	Checksum is 16 bit addition of all programmable bytes.
;	User sends 2s complement of addition at end of program in command 0x03 (16 bits only)

;**********************************************************************************




	






;	processor uses  4 MHz. Resonator with HSPLL to give a clock of 16MHz

;********************************************************************************





	

	
	
	;

;****************************************************************
;	This is the bootloader
; ***************************************************************************** 
;_STARTUPCODE	0x00
	ORG 0x0000
; *****************************************************************************
	bra	_CANInit
	bra	_StartWrite
; ***************************************************************************** 
;_INTV_H CODE	0x08
	ORG 0x0008
; *****************************************************************************

	goto	HIGH_INT_VECT

; ***************************************************************************** 
;_INTV_L CODE	0x18
	ORG 0x0018
; *****************************************************************************

	goto	LOW_INT_VECT 

; ************************************************************** 
;	Code start
; **************************************************************
	ORG 0x0020
;_CAN_IO_MODULE CODE
; ************************************************************ ** * * * * * * * * * * * * * * * 
; Function: VOID _StartWrite(WREG _eecon_data)
;PreCondition: Nothing
;Input: _eecon_data
;Output: Nothing. Self write timing started.
;Side Effects: EECON1 is corrupted; WREG is corrupted.
;Stack Requirements: 1 level.
;Overview: Unlock and start the write or erase sequence to protected
;	memory. Function will wait until write is finished.
;
; ************************************************************ ** * * * * * * * * * * * * * * *
_StartWrite
	movwf 	EECON1
	btfss 	MODE_WRT_UNLCK	; Stop if write locked
	return
	movlw 	0x55	; Unlock
	movwf 	 EECON2 
	movlw	 0xAA 
	movwf 	 EECON2
	bsf	 EECON1, WR	; Start the write
	nop
	btfsc 	EECON1, WR	; Wait (depends on mem type)
	bra	$ - 2
 	return
; ************************************************************ ** * * * * * * * * * * * * * * *

; Function: _bootChksm _UpdateChksum(WREG _bootChksmL)
;
; PreCondition: Nothing
; Input: _bootChksmL
; Output: _bootChksm. This is a static 16 bit value stored in the Access Bank.
; Side Effects: STATUS register is corrupted.
; Stack Requirements: 1 level.
; Overview: This function adds a byte to the current 16 bit checksum
;	count. WREG should contain the byte before being called.
;
;	The _bootChksm value is considered a part of the special
;	register set for bootloading. Thus it is not visible. ;
;*************************************************************** * * * * * * * * * * * *
_UpdateChksum:
	addwf	_bootChksmL,	F ; Keep a checksum
	btfsc	STATUS,	C
	incf	_bootChksmH,	F
	return
;************************************************************ ** * * * * * * * * * * * * * * *
;
;	Function:	VOID _CANInit(CAN,	BOOT)
;
;	PreCondition: Enter only after a reset has occurred.
; Input: CAN control information, bootloader control information ; Output: None.
; Side Effects: N/A. Only run immediately after reset.
; Stack Requirements: N/A
; Overview: This routine is technically not a function since it will not
;	return when called. It has been written in a linear form to
;	save space.Thus 'call' and 'return' instructions are not
;	included, but rather they are implied. ;
;	This routine tests the boot flags to determine if boot mode is
;	desired or normal operation is desired. If boot mode then the
;	routine initializes the CAN module defined by user input. It
;	also resets some registers associated to bootloading.
;
; ************************************************************ ** * * * * * * * * * * * * * * *
_CANInit:
	clrf	EECON1
	setf	EEADR	; Point to last location of EEDATA
	setf	EEADRH
	bsf	EECON1, RD	; Read the control code
	incfsz EEDATA, W

	goto	RESET_VECT


	clrf	_bootSpcCmd 	; Reset the special command register
	movlw 	0x1C		; Reset the boot control bits
	movwf 	_bootCtlBits 
	movlb	d'15'		; Set Bank 15
	bcf 	TRISB, CANTX 	; Set the TX pin to output 
	movlw 	CAN_RXF0SIDH 	; Set filter 0
	movwf 	RXF0SIDH
	movlw 	CAN_RXF0SIDL 
	movwf 	RXF0SIDL
	comf	WREG		; Prevent filter 1 from causing a receive event





	movwf	RXF1SIDL	;		
	movlw	CAN_RXF0EIDH	
	movwf	RXF0EIDH	
	movlw	CAN_RXF0EIDL	
	movwf	RXF0EIDL	
	movlw	CAN_RXM0SIDH	;	Set mask
	movwf	RXM0SIDH	
	movlw	CAN_RXM0SIDL	
	movwf	RXM0SIDL	
	movlw	CAN_RXM0EIDH	
	movwf	RXM0EIDH	
	movlw	CAN_RXM0EIDL	
	movwf	RXM0EIDL	
	movlw	CAN_BRGCON1	;	Set bit rate
	movwf	BRGCON1	
	movlw	CAN_BRGCON2	
	movwf	BRGCON2	
	movlw	CAN_BRGCON3	
	movwf	BRGCON3	
	movlw	CAN_CIOCON	;	Set IO
	movwf	CIOCON	
	
	clrf	CANCON	; Enter Normal mode
	movlw	B'00001110'
	movwf	ADCON1
	bcf	TRISB,7
	bcf	TRISB,6
	bsf	PORTB,7		;gren LED on
	bsf	PORTB,6		;yellow LED on


; ************************************************************ ** * * * * * * * * * * * * * * * 
; This routine is essentially a polling loop that waits for a
; receive event from RXB0 of the CAN module. When data is
; received, FSR0 is set to point to the TX or RX buffer depending
; upon whether the request was a 'put' or a 'get'.
; ************************************************************ ** * * * * * * * * * * * * * * * 
_CANMain
	
	bcf	RXB0CON, RXFUL	; Clear the receive flag
_wait	clrwdt			; Clear WDT while waiting	
	btfss 	RXB0CON, RXFUL	; Wait for a message	
	bra	_wait



_CANMainJp1
	lfsr	0, RXB0D0
	movf	RXB0DLC, W 
	andlw 	0x0F
	movwf 	_bootCount 
	movwf 	WREG1
	bz	_CANMain 
_CANMainJp2				;?
	


; ************************************************************** * * * * * * * * * * * * * * * 
; Function: VOID _ReadWriteMemory()
;
; PreCondition:Enter only after _CANMain().
; Input: None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: This routine is technically not a function since it will not
;	return when called. It has been written in a linear form to
;	save space.Thus 'call' and 'return' instructions are not
;	included, but rather they are implied.
;This is the memory I/O engine. A total of eight data bytes are received and decoded. In addition two control bits are received, put/get and control/data.
;A pointer to the buffer is passed via FSR0 for reading or writing. 
;The control register set contains a pointer, some control bits and special command registers.
;Control
;<PG><CD><ADDRL><ADDRH><ADDRU><_RES_><CTLBT>< SPCMD><CPDTL><CPDTH>
;Data
;<PG>< CD>< DATA0>< DATA1>< DATA2>< DATA3>< DATA4>< DATA5>< DATA6>< DATA7>
;PG bit:	Put = 0, Get = 1
;CD bit:	Control = 0, Data = 1

; ************************************************************ ** * * * * * * * * * * * * * * *
_ReadWriteMemory:
	btfsc	CAN_CD_BIT	; Write/read data or control registers
	bra	_DataReg
; ************************************************************ ** * * * * * * * * * * * * * * * ; This routine reads or writes the bootloader control registers,
; then executes any immediate command received.
_ControlReg
	lfsr	1, _bootAddrL		;_bootCtlMem
_ControlRegLp1

	movff 	POSTINC0, POSTINC1 
	decfsz 	WREG1, F
	bra	_ControlRegLp1

; ********************************************************* 
; This is a no operation command.
	movf	_bootSpcCmd, W		; NOP Command
	bz	_CANMain
;	bz	_SpecialCmdJp2		; or send an acknowledge

; ********************************************************* 
; This is the reset command.
	xorlw 	CMD_RESET		; RESET Command 
	btfss 	STATUS, Z
	bra		_SpecialCmdJp4
	setf	EEADR		; Point to last location of EEDATA
	setf	EEADRH
	clrf	EEDATA		; and clear the data (FF for now)
	movlw 	b'00000100'	; Setup for EEData
	rcall 	_StartWrite
	bcf		PORTB,6		;yellow LED off
	reset
; *********************************************************
; This is the Selfcheck reset command. This routine 
; resets the internal check registers, i.e. checksum and 
; self verify.
_SpecialCmdJp4
	movf	_bootSpcCmd, W 
	xorlw 	CMD_RST_CHKSM
	bnz		_SpecialCmdJp1
	clrf	_bootChksmH
	clrf	_bootChksmL
	bcf		ERR_VERIFY		
	clrf	_bootErrStat
	bra		_CANMain
; RESET_CHKSM Command
; Reset chksum
; Clear the error verify flag

;This is the Test and Run command. The checksum is
; verified, and the self-write verification bit is checked. 
; If both pass, then the boot flag is cleared.
_SpecialCmdJp1
	movf	_bootSpcCmd, W		; RUN_CHKSM Command
	xorlw 	CMD_CHK_RUN 
	bnz	_SpecialCmdJp3
	movf	_bootChkL, W	; Add the control byte
	addwf	 _bootChksmL, F
	bnz	_SpecialCmdJp2
	movf	_bootChkH, W 
	addwfc	_bootChksmH, F
	bnz	_SpecialCmdJp2
	btfsc 	ERR_VERIFY		; Look for verify errors
	bra	_SpecialCmdJp2

	bra		_CANSendOK	;send OK message


_SpecialCmdJp2

	bra	_CANSendNOK	; or send an error acknowledge


_SpecialCmdJp3
	movf	_bootSpcCmd, W		; RUN_CHKSM Command
	xorlw 	CMD_BOOT_TEST 
	bnz	_CANMain
	bra	_CANSendBoot

; ************************************************************** * * * * * * * * * * * * * * * 
; This is a jump routine to branch to the appropriate memory access function.
; The high byte of the 24-bit pointer is used to determine which memory to access. 
; All program memories (including Config and User IDs) are directly mapped. 
; EEDATA is remapped.
_DataReg
; *********************************************************
_SetPointers
	movf	_bootAddrU, W	; Copy upper pointer
	movwf 	TBLPTRU
	andlw 	0xF0	; Filter
	movwf 	WREG2
	movf	_bootAddrH, W	; Copy the high pointer
	movwf 	TBLPTRH
	movwf 	EEADRH
	movf	_bootAddrL, W	; Copy the low pointer
	movwf 	TBLPTRL
	movwf	 EEADR
	btfss 	MODE_AUTO_INC	; Adjust the pointer if auto inc is enabled
	bra	_SetPointersJp1
	movf	_bootCount, W	; add the count to the pointer
	addwf	 _bootAddrL, F 
	clrf	WREG
	addwfc	 _bootAddrH, F 
	addwfc	 _bootAddrU, F 

_SetPointersJp1			;?

_Decode
	movlw 	0x30
	cpfslt 	WREG2
	bra	_DecodeJp1



	bra	_PMEraseWrite

_DecodeJp1
	movf	WREG2,W
	xorlw 	0x30
	bnz	_DecodeJp2



	bra	_CFGWrite 
_DecodeJp2
	movf	WREG2,W 
	xorlw 0xF0
	bnz	_CANMain
	bra	_EEWrite

f	

; Program memory < 0x300000
; Config memory = 0x300000
; EEPROM data = 0xF00000
	
; ************************************************************ ** * 
; ************************************************************** * 
; Function: VOID _PMRead()
;	VOID _PMEraseWrite ()
;
; PreCondition:WREG1 and FSR0 must be loaded with the count and address of
; the source data.
; Input: None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: These routines are technically not functions since they will not
;	return when called. They have been written in a linear form to
;	save space.Thus 'call' and 'return' instructions are not
;	included, but rather they are implied.
;These are the program memory read/write functions. Erase is available through control flags. An automatic erase option is also available.
; A write lock indicator is in place to ensure intentional write operations.
;Note: write operations must be on 8-byte boundaries and must be 8 bytes long. Also erase operations can only occur on 64-byte boundaries.
; ************************************************************ ** * * * * * * * * * * * * * * *



_PMEraseWrite:
	btfss 	MODE_AUTO_ERASE
	bra	_PMWrite
_PMErase:
	movf	TBLPTRL, W
	andlw	b'00111111'
	bnz	_PMWrite
_PMEraseJp1
	movlw	b'10010100' 
	rcall 	_StartWrite 
_PMWrite:
	btfsc 	MODE_ERASE_ONLY


	bra	_CANMain 

	movf	TBLPTRL, W
	andlw	b'00000111'
	bnz	_CANMain 
	movlw 	0x08
	movwf WREG1

_PMWriteLp1					; Load the holding registers
	movf	POSTINC0, W 
	movwf 	TABLAT
	rcall	 _UpdateChksum 	; Adjust the checksum
	tblwt*+
	decfsz	 WREG1, F
	bra	_PMWriteLp1

#ifdef MODE_SELF_VERIFY 
	movlw	 0x08
	movwf 	WREG1 
_PMWriteLp2
	tblrd*-			; Point back into the block
	movf	POSTDEC0, W 
	decfsz	 WREG1, F
	bra	_PMWriteLp2
	movlw	 b'10000100' 	; Setup writes
	rcall	_StartWrite 	; Write the data
	movlw 	0x08
	movwf 	WREG1
_PMReadBackLp1
	tblrd*+			; Test the data
	movf	TABLAT, W 
	xorwf 	POSTINC0, W
	btfss	STATUS, Z
	bsf	ERR_VERIFY 
	decfsz 	WREG1, F
	bra	_PMReadBackLp1	; Not finished then repeat
#else
	tblrd*-			; Point back into the block
				 ; Setup writes
	movlw 	b'10000100' 	; Write the data
	rcall 	_StartWrite 	; Return the pointer position
	tblrd*+
#endif

	bra	_CANMain


; ************************************************************** * * * * * * * * * * * * * * *
 ; Function: VOID _CFGWrite()
;	VOID _CFGRead()
;
; PreCondition:WREG1 and FSR0 must be loaded with the count and address of the source data. 
; Input: None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: These routines are technically not functions since they will not
;	return when called. They have been written in a linear form to
;	save space. Thus 'call' and 'return' instructions are not
;	included, but rather they are implied.
;
;	These are the Config memory read/write functions. Read is
;	actually the same for standard program memory, so any read
;	request is passed directly to _PMRead.
;
; ************************************************************ ** * * * * * * * * * * * * * * *
_CFGWrite

#ifdef MODE_SELF_VERIFY		; Write to config area
	movf	INDF0, W		; Load data
#else
	movf	POSTINC0, W
#endif
	movwf 	TABLAT
	rcall 	_UpdateChksum	; Adjust the checksum
	tblwt*			; Write the data
	movlw	b'11000100' 
	rcall 	_StartWrite
	tblrd*+			; Move the pointers and verify
#ifdef MODE_SELF_VERIFY 
	movf	TABLAT, W 
	xorwf 	POSTINC0, W

#endif
	decfsz 	WREG1, F
	bra	_CFGWrite	; Not finished then repeat

	bra	_CANMain 



; ************************************************************** * * * * * * * * * * * * * * * 
; Function: VOID _EERead()
;	VOID _EEWrite()
;
; PreCondition:WREG1 and FSR0 must be loaded with the count and address of
 ;	the source data.
; Input:	None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: These routines are technically not functions since they will not
;	return when called. They have been written in a linear form to
;	save space. Thus 'call' and 'return' instructions are not
;	included, but rather they are implied.
;
;	This is the EEDATA memory read/write functions.
;
; ************************************************************ ** * * * * * * * * * * * * * * *


_EEWrite:

#ifdef MODE_SELF_VERIFY
	movf	INDF0, W
#else
	movf	POSTINC0, W 
#endif

	movwf 	EEDATA
	rcall 	_UpdateChksum 
	movlw	b'00000100' 
	rcall	 _StartWrite

#ifdef MODE_SELF_VERIFY 
	clrf	EECON1
	bsf	EECON1, RD
	movf	EEDATA, W 
	xorwf 	POSTINC0, W
	btfss	STATUS, Z
	bsf	ERR_VERIFY
#endif

	infsnz	 EEADR, F 
	incf 	EEADRH, F 
	decfsz 	WREG1, F
	bra	_EEWrite


	bra	_CANMain 
	

; Read the data

; Adjust EEDATA pointer
; Not finished then repeat
; Load data
; Adjust the checksum 
; Setup for EEData
; and write
; Read back the data ; verify the data ; and adjust pointer
; Adjust EEDATA pointer
; Not finished then repeat

; ************************************************************** * * * * * * * * * * * * * * *
; Function: VOID _CANSendAck()
;	VOID _CANSendResponce ()
;
; PreCondition:TXB0 must be preloaded with the data.
; Input: None.
; Output: None.
; Side Effects: N/A.
; Stack Requirements: N/A
; Overview: These routines are technically not functions since they will not
;	return when called. They have been written in a linear form to
;	save space. Thus 'call' and 'return' instructions are not
;	included, but rather they are implied. ;
;	These routines are used for 'talking back' to the source. The
;	_CANSendAck routine sends an empty message to indicate
;	acknowledgement of a memory write operation. The
;	_CANSendResponce is used to send data back to the source. ;
; ************************************************************ ** * * * * * * * * * * * * * * *



_CANSendMessage
	btfsc 	TXB0CON,TXREQ 
	bra	$ - 2
	movlw 	CAN_TXB0SIDH 
	movwf 	TXB0SIDH
	movlw 	CAN_TXB0SIDL 
	movwf 	TXB0SIDL
	movlw 	CAN_TXB0EIDH 
	movwf 	TXB0EIDH	

	movlw	CAN_TXB0EIDL
	movwf	TXB0EIDL
	bsf	CANTX_CD_BIT
	btfss	CAN_CD_BIT 
	bcf	CANTX_CD_BIT
	bsf	TXB0CON, TXREQ
    	bra	 _CANMain	; Setup the command bit

_CANSendOK				;send OK message 
	movlw	1			;a 1 is OK
	movwf	TXB0D0
	movwf	TXB0DLC
	bra		_CANSendMessage
	
_CANSendNOK				;send not OK message
	clrf	TXB0D0		;a 0 is not OK
	movlw	1
	movwf	TXB0DLC
	bra		_CANSendMessage

_CANSendBoot
	movlw	2			;2 is confirm boot mode
	movwf	TXB0D0
	movlw	1
	movwf	TXB0DLC
	bra		_CANSendMessage
    
; Start the transmission

; 	End of bootloader	

;****************************************************************
;
;		start of program code

		ORG		0800h
		nop						;for debug
		goto	setup

		ORG		0808h
		goto	hpint			;high priority interrupt

		ORG		0810h			;node type parameters
node_ID	db		Para1,Para2,Para3,Para4,Para5,Para6,Para7
								;change these 7 bytes as required

		ORG		0818h	
		goto	lpint			;low priority interrupt


;*******************************************************************

		ORG		0820h			;start of ACC4 program
;	
;
;		high priority interrupt. Used for CAN receive and transmit error.

hpint	movff	CANCON,TempCANCON
		movff	CANSTAT,TempCANSTAT
	
	;	movff	PCLATH,PCH_tempH		;save PCLATH
	;	clrf	PCLATH
	
		movff	FSR0L,Fsr_temp0L		;save FSR0
		movff	FSR0H,Fsr_temp0H
		movff	FSR1L,Fsr_temp1L		;save FSR1
		movff	FSR1H,Fsr_temp1H
		movlw	8
		movwf	PCLATH
		movf	TempCANSTAT,W			;Jump table
		andlw	B'00001110'
		addwf	PCL,F			;jump
		bra		back
		bra		errint			;error interrupt
		bra		back
		bra		back
		bra		back
		bra		rxb1int			;only receive interrupts used
		bra		rxb0int
		bra		back
		
rxb1int	bcf		PIR3,RXB1IF		;uses RB0 to RB1 rollover so may never use this
								;may need bank switch?
		lfsr	FSR0,Rx0con		;	
		goto	access
		
rxb0int	bcf		PIR3,RXB0IF
		btfsc	Datmode,1			;setup mode?
		bra		setmode	
		lfsr	FSR0,Rx0con
		goto	access
		
		;error routine here. Only acts on lost arbitration	

errint	movlb	.15					;change bank			
		btfss	TXB1CON,TXLARB
		bra		errbak				;not lost arb.
	
		movf	Latcount,F			;is it already at zero?
		bz		errbak
		decfsz	Latcount,F
		bra		errbak
		bcf		TXB1CON,TXREQ
		movlw	B'00111111'
		andwf	TXB1SIDH,F			;change priority
txagain bsf		TXB1CON,TXREQ		;try again
					
errbak		bcf		RXB1CON,RXFUL
		movlb	0
		bcf		RXB0CON,RXFUL		;ready for next  
		bcf		COMSTAT,RXB0OVFL	;clear overflow flags if set
		bcf		COMSTAT,RXB1OVFL		
		bra		back1


access	movf	CANCON,W
		andlw	B'11110001'
		movwf	CANCON
		movf	TempCANSTAT,W
		andlw	B'00001110'
		iorwf	CANCON
		
		lfsr	FSR1,RXB0CON	;this is switched bank
load	movff	POSTINC1,POSTINC0
		movlw	0x6E			;end of access buffer lo byte
		cpfseq	FSR1L
		bra		load
		bcf		RXB0CON,RXFUL
		
		btfsc	Rx0dlc,RXRTR		;is it RTR?
		bra		isRTR
;		btfsc	Datmode,1			;setup mode?
;		bra		setmode	
		movf	Rx0dlc,F
		bz		back
		bsf		Datmode,0		;valid message frame	
		
back	bcf		RXB0CON,RXFUL	;ready for next
	
back1	movlw	B'00000011'
		andwf	PIR3			;clear any other flags
		movf	CANCON,W
		andlw	B'11110001'
		iorwf	TempCANCON,W
		
		movwf	CANCON
;		movff	PCH_tempH,PCLATH
		movff	Fsr_temp0L,FSR0L		;recover FSR0
		movff	Fsr_temp0H,FSR0H
		movff	Fsr_temp1L,FSR1L		;recover FSR1
		movff	Fsr_temp1H,FSR1H
		

		
		retfie	1				;use shadow registers


isRTR	btfsc	Datmode,1		;setup mode?
		bra		back			;back
		btfss	Mode,1			;FLiM?
		bra		back
		movlb	.15
		
isRTR1	btfsc	TXB2CON,TXREQ	;send ID frame - preloaded in TXB2
		bra		isRTR1
		bsf		TXB2CON,TXREQ
		movlb	0
		bra		back

setmode	tstfsz	RXB0DLC
		bra		back				;only zero length frames for setup
		
		swapf	RXB0SIDH,W			;get ID into one byte
		rrcf	WREG
		andlw	B'01111000'			;mask
		movwf	Temp
		swapf	RXB0SIDL,W
		rrncf	WREG
		andlw	B'00000111'
		iorwf	Temp,W
		movwf	IDcount				;has current incoming CAN_ID

		lfsr	FSR1,Enum0			;set enum to table
enum_st	clrf	Roll				;start of enum sequence
		bsf		Roll,0
		movlw	8
enum_1	cpfsgt	IDcount
		bra		enum_2
		subwf	IDcount,F			;subtract 8
		incf	FSR1L				;next table byte
		bra		enum_1
enum_2	dcfsnz	IDcount,F
		bra		enum_3
		rlncf	Roll,F
		bra		enum_2
enum_3	movf	Roll,W
		iorwf	INDF1,F


;		call	shuffin				;get CAN ID as a single byte in W
;		cpfseq	IDcount
;		bra		back				;not equal
;		incf	IDcount,F
;		movlw	.100
;		cpfslt	IDcount				;too many?
;		decf	IDcount,F			;stay at 100
		bra		back		


		
		
	

;**************************************************************
;
;
;		low priority interrupt. Used by output timer overflow. Every 10 millisecs.
;	

lpint	movwf	W_tempL				;used for output timers
		movff	STATUS,St_tempL
		movff	BSR,Bsr_tempL

;		movff	PCLATH,PCH_tempL		;save PCLATH
;		clrf	PCLATH
	

		movlw	0x78				;Timer 1 lo byte. (adjust if needed)
		movwf	TMR1L				;reset timer 1
		clrf	PIR1				;clear all timer flags
		btg		PORTA,4				;doubler drive
		
	
lp1		clrf	Timout
		clrf	Timbit				;rolling bit for testing which timer
		dcfsnz	T1a,F
		bsf		Timout,0			;set bits in Timout if it needs to go off
		dcfsnz	T1b,F
		bsf		Timout,1	
		dcfsnz	T2a,F
		bsf		Timout,2
		dcfsnz	T2b,F
		bsf		Timout,3
		dcfsnz	T3a,F
		bsf		Timout,4
		dcfsnz	T3b,F
		bsf		Timout,5
		dcfsnz	T4a,F
		bsf		Timout,6
		dcfsnz	T4b,F
		bsf		Timout,7
		tstfsz	Timout
		bra		off						;turn off outputs
		bra		lpend					;nothing to do
		
off		bsf		Timbit,0				;set rolling bit
off1	movf	Timbit,W
		andwf	Timout,W
		bnz		dobit					;this timer is out
off2	rlncf	Timbit,F
		bra		off1					;try next timer
dobit	xorwf	Timout,F				;clear bit in Timout
		andwf	Timset,W				;is this timer continuous
		bz		donot					;a zero is continuous
				
		xorwf	Timset,F				;ignore next time
		call	map						;for mapping
		movwf	Timtemp
		comf	Timtemp,W
		andwf	PORTC,F					;turn off output
		bsf		PORTA,0					;charger back on
donot	tstfsz	Timout					;any more outputs to turn off?
		bra		off2	
		
lpend	movff	Bsr_tempL,BSR
		movf	W_tempL,W
		movff	St_tempL,STATUS	
		retfie	
						

;*********************************************************************


;	main waiting loop

main	btfsc	Mode,1			;is it SLiM?
		bra		mainf

mains	btfss	PIR2,TMR3IF		;flash timer overflow?
		bra		nofl_s			;no SLiM flash
		btg		PORTB,7			;toggle green LED
		bcf		PIR2,TMR3IF
nofl_s	bra		noflash				;main1
		
; here if FLiM mde

mainf	btfss	INTCON,TMR0IF		;is it flash?
		bra		noflash
		btfss	Datmode,2
		bra		nofl1
		
		btg		PORTB,6			;flash yellow LED
		
nofl1	bcf		INTCON,TMR0IF
		btfss	Datmode,3		;running mode
		bra		noflash
		decfsz	Keepcnt			;send keep alive?
		bra		noflash
		movlw	.10
		movwf	Keepcnt
		movlw	0x52
;		call	nnrel			;send keep alive frame (works OK, turn off for now)

noflash	btfsc	S_PORT,S_BIT	;setup button?
		bra		main3
		movlw	.100
		movwf	Count
		clrf	Count1
		clrf	Count2
wait	decfsz	Count2
		goto	wait
		btfss	Datmode,2
		bra		wait2
		btfss	INTCON,TMR0IF		;is it flash?
		bra		wait2
		btg		PORTB,6			;flash LED
		bcf		INTCON,TMR0IF
wait2	decfsz	Count1
		goto	wait
		btfsc	S_PORT,S_BIT
		bra		main4			;not held long enough
		decfsz	Count
		goto	wait
		btfss	Mode,1			;is it in FLiM?
		bra		go_FLiM
		clrf	Datmode			;back to virgin
;		bcf		Mode,1			;SLiM mode
		bcf		PORTB,6			;yellow off
		
		bsf		PORTB,7			;Green LED on
		clrf	INTCON			;interrupts off
		movlw	1
		movwf	IDcount			;back to start
		movlw	Modstat
		movwf	EEADR
		movlw 	0
		call	eewrite			;status to reset
		movlw	0x51			;send node release frame
		call	nnrel
		clrf	NN_temph
		clrf	NN_templ
wait1	btfss	S_PORT,S_BIT
		bra		wait1			;wait till release
		call	ldely
		btfss	S_PORT,S_BIT
		bra		wait1
	
		
		movlw	LOW NodeID			;put NN back to 0000
		movwf	EEADR
		movlw	0
		call	eewrite
		incf	EEADR
		movlw	0
		call	eewrite	
		btfss	Mode,1
		bra		main5				;FLiM setup
		movlw	Modstat
		movwf	EEADR
		movlw	0
		call	eewrite				;mode back to SLiM
		call	nv_rest				;restore NVs for SLiM
		clrf	Datmode
		bcf		Mode,1
		bcf		PORTB,6
		bsf		PORTB,7				;green LED on
	
		movlw	B'11000000'
		movwf	INTCON
		goto	main				;setloop

main5	movlw	Modstat
		movwf	EEADR
		movlw	1
		call	eewrite				;mode to FLiM in EEPROM
;		bsf		PORTB,7				;yellow will flash
;		bsf		PORTB,7				;green LED on still
		bsf		Mode,1				;to FLiM
		movlw	B'11000000'
		movwf	INTCON
		goto	setloop				;setloop

main4	btfss	Datmode,3		
		bra		main3
		btfss	Datmode,2
		bra		set2
		bcf		Datmode,2
		bsf		PORTB,6			;LED on
		bra		main3
set2	bsf		Datmode,2
		call	nnack

main3	btfss	Datmode,1		;setup mode ?
		bra		main1
		btfss	PIR2,TMR3IF		;setup timer out?
		bra		main3			;fast loop till timer out (main3?)
		bcf		T3CON,TMR3ON	;timer off
		bcf		PIR2,TMR3IF		;clear flag
		call	new_enum
		movlw	LOW CANid		;put new ID in EEPROM
		movwf	EEADR
		movf	IDcount,W
		call	eewrite
		call	newid_f			;put new ID in various buffers
		movlw	Modstat
		movwf	EEADR
		movlw	1
		call	eewrite			;set to normal status
		bcf		Datmode,1		;out of setup
		bsf		Datmode,2		;wait for NN
		call	nnack			;send blank NN for config
;		bsf		PORTB,7			;on light
		bra		main			;continue normally

go_FLiM	bsf		Datmode,1		;FLiM setup mode
		bcf		PORTB,7			;green off
		bra		wait1
		
		

; common to FLiM and SLiM					;
	
main1	btfss	Datmode,0		;any new CAN frame received?
		bra		main
		bra		packet
		
;		These are here as branch was too long

unset	;bsf		Datmode,5		;unlearn this event
		;bra		go_on
		btfss	Datmode,4			;Roger's mod
		bra		main2				;no error message on OPC 0x95
		bsf		Datmode,5
		bra		learn1

readEV	btfss	Datmode,4
		bra		main2			;prevent error message
		bsf		Datmode,6		;read back an EV
		bra		learn1

evns1	call	thisNN				;read event numbers
		sublw	0
		bnz		evns3
		call	evns2
		bra		main2
evns3	goto	notNN

reval	call	thisNN				;read event numbers
		sublw	0
		bnz		notNNx
		call	evsend
		bra		main2
notNNx	goto	notNN

go_on_x goto	go_on

params	btfss	Datmode,2		;only in setup mode
		bra		main2
		call	parasend
		bra		main2
		
;********************************************************************		
	
		

	
								;main packet handling is here
		
packet	movlw	CMD_ON			;on command?
		subwf	Rx0d0,W
		bz		go_on_x
		movlw	CMD_OFF			;off command?
		subwf	Rx0d0,W
		bz		go_on_x		
		movlw	SCMD_ON
		subwf	Rx0d0,W
		bz		short1
		movlw	SCMD_OFF
		subwf	Rx0d0,W
		bz		short1
		movlw	0x5C			;reboot
		subwf	Rx0d0,W
		bz		reboot
		btfss	Mode,1			;FLiM?
		bra		main2			;no more if SLiM
		movlw	0x42			;set NN on 0x42
		subwf	Rx0d0,W
		bz		setNN
		movlw	0x10			
		subwf	Rx0d0,W
		bz		params			;read node parameters
		
		movlw	0x53			;set to learn mode on 0x53
		subwf	Rx0d0,W
		bz		setlrn		
		movlw	0x54			;clear learn mode on 0x54
		subwf	Rx0d0,W
		bz		notlrn
		movlw	0x55			;clear all events on 0x55
		subwf	Rx0d0,W
		bz		clrens
		movlw	0x56			;read number of events left
		subwf	Rx0d0,W
		bz		rden
		movlw	0xD2			;is it set event?
		subwf	Rx0d0,W
		bz		chklrn			;do it
		movlw	0x95			;is it unset event
		subwf	Rx0d0,W			
		bz		unset
		movlw	0xB2			;read event variables
		subwf	Rx0d0,W
		bz		readEV
		
		movlw	0x71			;read NVs
		subwf	Rx0d0,W
		bz		readNVx
		movlw	0x96			;set NV
		subwf	Rx0d0,W
		bz		setNV
		movlw	0x57			;is it read events
		subwf	Rx0d0,W
		bz		readENx
		movlw	0x72
		subwf	Rx0d0,W
		bz		readENi			;read event by index
		movlw	0x73
		subwf	Rx0d0,W
		bz		para1a			;read individual parameters
		movlw	0x58
		subwf	Rx0d0,W
		bz		evns
		movlw	0x9C			;read event variables by EN#
		subwf	Rx0d0,W
		bz		reval
		bra		main2			;do nothing if OPC not supported
;		call	thisNN		
;		bnz		main2			;not this node
;		movlw	1				;error 1 not supported by this node
;		goto	errmsg	

short1	goto	short			;branches too long
readNVx	goto	readNV
readENx	goto	readEN

evns	goto	evns1
		bra		main2

reboot	btfss	Mode,1
		bra		reboot1
		call	thisNN
		sublw	0
		bnz		notNN
reboot1	movlw	0xFF
		movwf	EEADR
		movlw	0xFF
		call	eewrite			;set last EEPROM byte to 0xFF
		reset					;software reset to bootloader
			
main2	bcf		Datmode,0
		goto	main			;loop
		
setNN	btfss	Datmode,2		;in NN set mode?
		bra		main2			;no
		call	putNN			;put in NN
		bcf		Datmode,2
		bsf		Datmode,3
		movlw	.10
		movwf	Keepcnt			;for keep alive
		movlw	0x52
		call	nnrel			;confirm NN set
		bsf		LED_PORT,LED1	;yellow LED ON
		bcf		LED_PORT,LED2
		bra		main2
		
sendNN	btfss	Datmode,2		;in NN set mode?
		bra		main2			;no
		movlw	0x50			;send back NN
		movwf	Tx1d0
		movlw	3
		movwf	Dlc
		call	sendTX
		bra		main2

rden	goto	rden1


		
setlrn	call	thisNN
		sublw	0
		bnz		notNN
		bsf		Datmode,4
;		bsf		LED_PORT,LED2			;LED on
		bra		main2

notlrn	call	thisNN
		sublw	0
		bnz		notNN
		bcf		Datmode,4
notln1		;leave in learn mode
		bcf		Datmode,5
;		bcf		LED_PORT,LED2
		bra		main2
clrens	call	thisNN
		sublw	0
		bnz		notNN
		btfss	Datmode,4
		bra		clrerr
		call	enclear
		bra		notln1
notNN	bra		main2
clrerr	movlw	2			;not in learn mode
		goto	errmsg

chklrn	btfsc	Datmode,4
		bra		learn1			;is in learn mode		
		bra		main2
		

short	clrf	Rx0d1
		clrf	Rx0d2
		bra		go_on	
		
go_on	btfss	Mode,1			;FLiM?
		bra		go_on_s
		
		
go_on1	call	enmatch
		sublw	0
		bz		do_it
		bra		main2			;not here

go_on_s	btfss	PORTB,LEARN
		bra		learn1			;is in learn mode
		bra		go_on1



readENi	call	thisNN			;read event by index
		sublw	0
		bnz		notNN
		call	enrdi
		bra		main2


paraerr	movlw	3				;error not in setup mode
		goto	errmsg

para1a	call	thisNN			;read parameter by index
		sublw	0
		bnz		notNN
		call	para1rd
		bra		main2

setNV	call	thisNN
		sublw	0
		bnz		notNN			;not this node
		call	putNV
		bra		main2

readNV	call	thisNN
		sublw	0
		bnz		notNN			;not this node
		call	getNV
		bra		main2

readEN	call	thisNN
		sublw	0
		bnz		notNN
		call	enread
		bra		main2
		
do_it	
		call	ev_set			;do it -  for consumer action
		bra		main2
		

		
rden1	call	thisNN
		sublw	0
		bnz		notNN
		movlw	LOW ENindex+1		;read number of events available
		movwf	EEADR
		call	eeread
		sublw	EN_NUM
		movwf	Tx1d3
		movlw	0x70
		movwf	Tx1d0
		movlw	4
		movwf	Dlc
		call	sendTX
		bra		main2		
		
learn1	btfss	Mode,1			;FLiM?
		bra		learn2
		movlw	0xD2
		subwf	Rx0d0,W			;is it a learn command
		bz		learn2			;OK
		movlw	0x95			;is it unlearn
		subwf	Rx0d0,W
		bz		learn2
		movlw	0xB2
		subwf	Rx0d0
		bz		learn2
		movlw	1				;cmd not supported
		goto	errmsg1
;		bra		l_out2

learn2	call	enmatch			;is it there already?
		sublw 	0
		bz		isthere
		btfsc	Mode,1			;FLiM?
		bra		learn3
		btfss	PORTA,UNLEARN	;if unset and not here
		bra		l_out2			;do nothing else 
		call	learnin			;put EN into stack and RAM
		sublw	0
		bz		new_EV
		movlw	4
		goto	errmsg1			;too many
learn3	btfsc	Datmode,6		;read EV?
		bra		rdbak1			;not here
		btfsc	Datmode,5		;if unset and not here
		bra		l_out1			;do nothing else 
learn4	call	learnin			;put EN into stack and RAM
		sublw	0
		bz		new_EV
		movlw	4
		goto	errmsg2			;bra		l_out1			;too many
isthere	btfsc	Mode,1
		bra		isth1			;skip looking at switch
		btfss	PORTA,UNLEARN	;is it here and unlearn,goto unlearn
		bra		unlearn			;else modify EVs
isth1	btfss	Datmode,5		;FLiM unlearn?
		bra		mod_EV
		bra		unlearn
	


rdbak	movff	EVtemp,Tx1d5		;Index for readout	
		incf	Tx1d5,F				;add one back	
		bsf		EECON1,RD			;address set already
		movff	EEDATA,Tx1d6
		bra		shift4
rdbak1	movlw	5				;no match
		goto	errmsg2			
	

shift4	movlw	0xD3				;readback of EVs
		movwf	Tx1d0
		movff	Rx0d1,Tx1d1
		movff	Rx0d2,Tx1d2
		movff	Rx0d3,Tx1d3
		movff	Rx0d4,Tx1d4
		movlw	7
		movwf	Dlc
		call	sendTXa	
		bra		l_out1

new_EV	btfsc	Mode,1				;FLiM?
		bra		new_EVf				;not relevant if FLiM
		movlw	LOW ENindex+1		;here if a new event
		movwf	EEADR
		bsf		EECON1,RD
		decf	EEDATA,W
		movwf	ENcount				;recover EN counter

mod_EV	btfsc	Mode,1				;FLiM?
		bra		mod_EVf				;not relevant if FLiM
		rlncf	ENcount,W			;two byte values
		addlw	LOW EVstart			;point to EV
		movwf	EEADR
		bsf		EECON1,RD
		call	getop				;get switch. value in EVtemp
		movf	EVtemp,W
				
		iorwf	EEDATA,W
		movwf	Temp
		call	eewrite				;put back EV value	
		incf	EEADR
		bsf		EECON1,RD
		btfsc	PORTB,POL			;test polarity
		bra		shft3
		movf	EVtemp,W
				
		iorwf	EEDATA,W
		movwf	EVtemp2
shft4	call	eewrite				;put back EV qual value	
		movff	Temp,EVtemp
		call	ev_set				;try it
		bra		l_out2
shft3	comf	EVtemp,W			;clear the POL bit
		andwf	EEDATA,W
		movwf	EVtemp2
		bra		shft4

new_EVf	movlw	LOW ENindex+1		;here if a new event in FLiM mode
		movwf	EEADR
		bsf		EECON1,RD
		decf	EEDATA,W
		movwf	ENcount				;recover EN counter
mod_EVf	movff	Rx0d5,EVtemp	;store EV index
		movf	EVtemp,F		;is it zero?
		bz		noEV
		decf	EVtemp,F		;decrement. EVs start at 1
		movlw	EV_NUM
		cpfslt	EVtemp
		bra		noEV		
;		btfsc	Datmode,5		;is it here and unlearn,goto unlearn
;		bra		unlearn			;else modify EVs
		
		movff	Rx0d6,EVtemp2	;store EV
		
		
		rlncf	ENcount,W			;two byte values
		addlw	LOW EVstart			;point to EV
		movwf	EEADR
		movf	EVtemp,W			;add index to EEPROM value
		addwf	EEADR,F
		btfsc	Datmode,6			;is it readback
		bra		rdbak
		movf	EVtemp2,W
		call	eewrite				;put in
		bra		l_out2


			

l_out	bcf		Datmode,4
;		bcf		LED_PORT,LED2
l_out1	bcf		Datmode,6
l_out2	bcf		Datmode,0
		

		clrf	PCLATH
		goto	main2
		
noEV	movlw	6				;invalid EV#
		goto	errmsg2
								;unlearn an EN. 
unlearn	movlw	LOW ENindex+1		;get number of events in stack
		movwf	EEADR
		bsf		EECON1,RD
		
		movff	EEDATA,ENend
		movff	EEDATA,ENtemp
		rlncf	ENend,F			;ready for end value
		rlncf	ENend,F
		movlw	LOW ENstart
		addwf	ENend,F			;end now points to next past end in EEPROM
		movlw	4
		addwf	ENend,F
		rlncf	ENcount,F		;Double the counter for two bytes
		rlncf	ENcount,F		;Double the counter for two bytes
		movlw	LOW ENstart + 4
		addwf	ENcount,W
		movwf	EEADR
un1		bsf		EECON1,RD
		movf	EEDATA,W		;get byte
		decf	EEADR,F
		decf	EEADR,F
		decf	EEADR,F
		decf	EEADR,F
		call	eewrite			;put back in
		movlw	5
		addwf	EEADR,F
		movf	ENend,W
		cpfseq	EEADR
		bra		un1
		
		rrncf	ENcount,F		;back to double bytes
		rlncf	ENtemp,F
		movlw	LOW EVstart
		addwf	ENtemp,F
		movlw	2
		addwf	ENtemp,F
		movlw	LOW EVstart + 2
		addwf	ENcount,W
		movwf	EEADR
un2		bsf		EECON1,RD
		movf	EEDATA,W		;get byte
		decf	EEADR,F
		decf	EEADR,F
		call	eewrite			;put back in
		movlw	3
		addwf	EEADR,F
		movf	ENtemp,W
		cpfseq	EEADR
		bra		un2
		movlw	LOW ENindex+1
		movwf	EEADR
		bsf		EECON1,RD
		movf	EEDATA,W
		movwf	Temp
		decf	Temp,W
		call	eewrite			;put back number in stack less 1
		call	en_ram			;rewrite RAM stack
		bcf		Datmode,5
		
		bra		l_out1
				

	

	
						
		





		


		



		


;***************************************************************************
;		main setup routine
;*************************************************************************

setup	clrf	INTCON			;no interrupts yet
		clrf	ADCON0			;turn off A/D, all digital I/O
		movlw	B'00001111'
		movwf	ADCON1
		
		;port settings will be hardware dependent. RB2 and RB3 are for CAN.
		;set S_PORT and S_BIT to correspond to port used for setup.
		;rest are hardware options
		
	
		movlw	B'00101000'		;Port A. PA3 is setup PB
		movwf	TRISA			;
		movlw	B'00111011'		;RB2 = CANTX, RB3 = CANRX, 	
								;RB6,7 for debug and ICSP and LEDs
								;PORTB has pullups enabled on inputs
		movwf	TRISB
		bcf		LED_PORT,LED2
		bcf		LED_PORT,LED1
		bsf		PORTB,2			;CAN recessive
		movlw	B'00000000'		;Port C  set to outputs.
		movwf	TRISC
		clrf	PORTC
	
		
;	next segment is essential.
		
		bsf		RCON,IPEN		;enable interrupt priority levels
		clrf	BSR				;set to bank 0
		clrf	EECON1			;no accesses to program memory	
		clrf	Datmode
		clrf	Latcount
		clrf	ECANCON			;CAN mode 0 for now. 
		 
		bsf		CANCON,7		;CAN to config mode
		movlw	B'00000011'		;set CAN bit rate at 125000 for now
		movwf	BRGCON1
		movlw	B'10011110'		;set phase 1 etc
		movwf	BRGCON2
		movlw	B'00000011'		;set phase 2 etc
		movwf	BRGCON3
		movlw	B'00100000'
		movwf	CIOCON			;CAN to high when off
		movlw	B'00100100'		;B'00100100'
		movwf	RXB0CON			;enable double buffer of RX0
		movlb	.15
		movlw	B'00100100'		;reject extended frames
		movwf	RXB1CON
		clrf	RXF0SIDL
		clrf	RXF1SIDL
		movlb	0
		


		
mskload	lfsr	0,RXM0SIDH		;Clear masks, point to start
mskloop	clrf	POSTINC0		
		movlw	LOW RXM1EIDL+1		;end of masks
		cpfseq	FSR0L
		bra		mskloop
		
		clrf	CANCON			;out of CAN setup mode
		clrf	CCP1CON
		movlw	B'10000100'
		movwf	T0CON			;set Timer 0 for LED flash
		movlw	B'10000001'		;Timer 1 control.16 bit write
		movwf	T1CON			;Timer 1 is for output duration
		movlw	0x63
		movwf	TMR1H			;set timer hi byte
		
		clrf	Tx1con
		movlw	B'00100011'
		movwf	IPR3			;high priority CAN RX and Tx error interrupts(for now)
		clrf	IPR1			;all peripheral interrupts are low priority
		clrf	IPR2
		clrf	PIE2
		movlw	B'00000001'
		movwf	PIE1			;enable interrupt for timer 1


;next segment required
		
		movlw	B'00000001'
		movwf	IDcount			;set at lowest value for starters
		
		clrf	INTCON2			;
		clrf	INTCON3			;
		

		movlw	B'00100011'		;B'00100011'  Rx0 and RX1 interrupt and Tx error
								
		movwf	PIE3
	
		clrf	PIR1
		clrf	PIR2
		movlb	.15
		bcf		RXB1CON,RXFUL
		movlb	0
		bcf		RXB0CON,RXFUL		;ready for next
		bcf		COMSTAT,RXB0OVFL	;clear overflow flags if set
		bcf		COMSTAT,RXB1OVFL
		clrf	PIR3			;clear all flags
	
	
		
		
		;		test for setup mode
		clrf	Mode
		movlw	Modstat			;get setup status
		movwf	EEADR
		call	eeread
		movwf	Datmode
		sublw	0				;not set yet
		bnz		setid
		bra		slimset			;wait for setup PB
	
		
setid	bsf		Mode,1			;flag FLiM
		call	newid_f			;put ID into Tx1buf, TXB2 and ID number store
		
	
seten_f	call	en_ram			;put events in RAM
		
		movlw	B'11000000'
		movwf	INTCON			;enable interrupts
		bsf		LED_PORT,LED1	;Yellow LED on.
		bcf		LED_PORT,LED2			
		bcf		Datmode,0
		goto	main

slimset	bcf		Mode,1
		;test for clear all events
		btfss	PORTB,LEARN		;ignore the clear if learn is set
		goto	seten
		btfss	PORTA,UNLEARN
		call	enclear			;clear all events if unlearn is set during power up
seten	call	en_ram			;put events in RAM
		call	nv_rest			;if SLiM put default NVs in.
		
	
		movlw	B'11000000'
		movwf	INTCON			;enable interrupts
		bcf		PORTB,6
		bsf		PORTB,7			;RUN LED on. Green for SLiM
		goto	main
		
	
setloop	
		movlw	B'11000000'
		movwf	INTCON			;enable interrupts
		bsf		Datmode,1		;setup mode

		call	enum			;sends RTR frame
		bra		main				
	
		

		
;****************************************************************************
;		start of subroutines		
;*************************************************************************


;
;		shuffle for standard ID. Puts 7 bit ID into IDtemph and IDtempl for CAN frame
shuffle	movff	CanID_tmp,IDtempl		;get 7 bit ID
		swapf	IDtempl,F
		rlncf	IDtempl,W
		andlw	B'11100000'
		movwf	IDtempl					;has sidl
		movff	CanID_tmp,IDtemph
		rrncf	IDtemph,F
		rrncf	IDtemph,F
		rrncf	IDtemph,W
		andlw	B'00001111'
		movwf	IDtemph					;has sidh
		return

;*********************************************************************************

;		reverse shuffle for incoming ID. sidh and sidl into one byte.

shuffin	movff	Rx0sidl,IDtempl
		swapf	IDtempl,F
		rrncf	IDtempl,W
		andlw	B'00000111'
		movwf	IDtempl
		movff	Rx0sidh,IDtemph
		rlncf	IDtemph,F
		rlncf	IDtemph,F
		rlncf	IDtemph,W
		andlw	B'01111000'
		iorwf	IDtempl,W			;returns with ID in W
		return


;************************************************************************************
;		sets an output  
		

do_out	movf	Opbit,W			;Opbit has bit set for corresponding output number
		call	map				;remaps this bit to correspond with actual output pin.
		bcf		PORTA,0			;disable charger
		iorwf	PORTC,F			;set output
		movf	Opbit,W
		iorwf	Timset,F		;set to timed for now
		lfsr	2,T1a			;get time
		movf	Opnum,W
		addlw	LOW NVstart			;EEPROM
		movwf	EEADR
		bsf		EECON1,RD
		movf	EEDATA,W
		movwf	Timtemp			;hold value
		bz		timcont			;time was zero so continuous
		movf	Opnum,W			;get index
		movff	Timtemp,PLUSW2 	;put in
		
		bra		onback			;done
timcont	comf	Opbit,W
		andwf	Timset,F		;clear bit
onback	return
;************************************************************************
;		turns an output off
		
out_off	movf	Opbit,W
		call	map
		movwf	Opbit1
		comf	Opbit1,W
		andwf	PORTC,F			;clear this output
		comf	Opbit,W
		andwf	Timset,F		;set to  no timer
offback	return	
		
;********************************************************************
;		Do an event.  arrives with EV in EVtemp and POL in EVtemp2
;		Toggles outputs. Turns off before on.
;		Checks which outputs are active for the event
;		Checks command for ON or OFF and checks the POL bit for which way to set output

ev_set		clrf	Opbit
			btfss	EVtemp,0
			bra		ev_set1		;no action on pair 1
			btfss	Rx0d0,0		;on or off?
			bra		ev1a
			btfss	EVtemp2,0	;reverse?
			bra		ev1_off
			bra		ev1_on
ev1a		btfss	EVtemp2,0
			bra		ev1_on
			bra		ev1_off			
ev1_on		movlw	0
			movwf	Opnum		;output 1 is on
			bsf		Opbit,1
			call	out_off
			rrncf	Opbit,F
			call	do_out
			call	delay2
			bra		ev_set1
ev1_off		movlw	1
			movwf	Opnum		;output 2 is on
			bsf		Opbit,0
			call	out_off
			rlncf	Opbit,F
			call	do_out
			call	delay2
ev_set1		clrf	Opbit
			btfss	EVtemp,1
			bra		ev_set2		;no action on pair 2
			btfss	Rx0d0,0		;on or off?
			bra		ev2a
			btfss	EVtemp2,1	;reverse?
			bra		ev2_off
			bra		ev2_on
ev2a		btfss	EVtemp2,1
			bra		ev2_on
			bra		ev2_off			
ev2_on		movlw	2
			movwf	Opnum		;output 3 is on
			bsf		Opbit,3
			call	out_off
			rrncf	Opbit,F
			call	do_out
			call	delay2
			bra		ev_set2
ev2_off		movlw	3
			movwf	Opnum		;output 4 is on
			bsf		Opbit,2
			call	out_off
			rlncf	Opbit,F
			call	do_out
			call	delay2
ev_set2		clrf	Opbit
			btfss	EVtemp,2
			bra		ev_set3		;no action on pair 3
			btfss	Rx0d0,0		;on or off?
			bra		ev3a
			btfss	EVtemp2,2	;reverse?
			bra		ev3_off
			bra		ev3_on
ev3a		btfss	EVtemp2,2
			bra		ev3_on
			bra		ev3_off			
ev3_on		movlw	4
			movwf	Opnum		;output 5 is on
			bsf		Opbit,5
			call	out_off
			rrncf	Opbit,F
			call	do_out
			call	delay2
			bra		ev_set3
ev3_off		movlw	5
			movwf	Opnum		;output 6 is on
			bsf		Opbit,4
			call	out_off
			rlncf	Opbit,F
			call	do_out
			call	delay2
ev_set3		clrf	Opbit
			btfss	EVtemp,3
			bra		ev_set4		;no action on pair 4
			btfss	Rx0d0,0		;on or off?
			bra		ev4a
			btfss	EVtemp2,3	;reverse?
			bra		ev4_off
			bra		ev4_on
ev4a		btfss	EVtemp2,3
			bra		ev4_on
			bra		ev4_off			
ev4_on		movlw	6
			movwf	Opnum		;output 7 is on
			bsf		Opbit,7
			call	out_off
			rrncf	Opbit,F
			call	do_out
			call	delay2
			bra		ev_set4
ev4_off		movlw	7
			movwf	Opnum		;output 8 is on
			bsf		Opbit,6
			call	out_off
			rlncf	Opbit,F
			call	do_out
			call	delay2
ev_set4		return			
			

					
		
;******************************************************************
;		maps logical output to real output  (PCB layout was a problem)

map		movwf	Opbit1			;save opbit	
		clrf	Shift1
map1	rrcf	Opbit1,F		;which bit is set?
		bc		map2			;this one
		incf	Shift1,F			;add one
		bra		map1
map2	movf	Shift1,W
		addlw	LOW Opmap
		movwf	EEADR			;get mapped value
		bsf		EECON1,RD
		movf	EEDATA,W		;output bit in W
		return
		
;***************************************************************************

;		reloads the timer settings from EEPROM to RAM

timload	movlw	LOW NVstart			;reloads timers
		movwf	EEADR
		lfsr	FSR1,T1a
timloop	bsf		EECON1,RD
		movff	EEDATA,POSTINC1
		incf	EEADR
		movlw	LOW NVstart+8
		cpfseq	EEADR
		bra		timloop
		return
		

;**************************************************************************
;		write to EEPROM, EEADR must be set before this sub.
;		data to write comes in W
eewrite	movwf	EEDATA			
		bcf		EECON1,EEPGD
		bcf		EECON1,CFGS
		bsf		EECON1,WREN
		
		clrf	INTCON	;disable interrupts
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf		EECON1,WR
eetest	btfsc	EECON1,WR
		bra		eetest
		bcf		PIR2,EEIF
		bcf		EECON1,WREN
		movlw	B'11000000'
		movwf	INTCON		;reenable interrupts
		
		return	
		



			
;**************************************************************************
;
;		EN match.	Compares EN (in Rx0d1 and Rx0d2) with stored ENs
;		If match, returns with W = 0
;		The matching number is in ENcount. The corresponding EV is in EVtemp and EVtemp2
;
enmatch	lfsr	FSR0,EN1	;EN ram image
		movlw	LOW ENindex+1	;
		movwf	EEADR
		bsf		EECON1,RD
		movff	EEDATA,Count
		clrf	ENcount
	
		
ennext	clrf	Match
		movf	POSTINC0,W
		cpfseq	Rx0d1
		incf	Match
		movf	POSTINC0,W
		cpfseq	Rx0d2
		incf	Match
		movf	POSTINC0,W
		cpfseq	Rx0d3
		incf	Match
		movf	POSTINC0,W
		cpfseq	Rx0d4
		incf	Match
		tstfsz	Match
		bra		en_match
		rlncf	ENcount,W		;get EVs
		addlw	LOW EVstart		
		movwf	EEADR
		bcf		EEADR,0		;multiple of 2
		bsf		EECON1,RD
		movff	EEDATA,EVtemp	;EV
		incf	EEADR
		bsf		EECON1,RD
		movff	EEDATA,EVtemp2	;EV qualifier
		
		retlw	0			;is a match
en_match	
		movf	Count,F
		bz		en_out
		decf	Count,F
		incf	ENcount,F
		bra		ennext
en_out	retlw	1			;no match
			
;**************************************************************************


;		learn input of EN

learnin	btfss	PORTA,UNLEARN			;don't do if unlearn
		return
		movlw	LOW ENindex+1
		movwf	EEADR
		bsf		EECON1,RD
		movff	EEDATA,ENcount		;hold pointer
		movlw	EN_NUM
		cpfslt	ENcount
		retlw	1						;too many
		lfsr	FSR0,EN1			;point to EN stack in RAM
		
		rlncf	ENcount,F			;double it
		rlncf	ENcount,F			;double again
		movf	ENcount,W
		movff	Rx0d1,PLUSW0		;put in RAM stack
		addlw	1
		movff	Rx0d2,PLUSW0
		addlw	1
		movff	Rx0d3,PLUSW0
		addlw	1
		movff	Rx0d4,PLUSW0
		movlw	LOW ENstart
		addwf	ENcount,W
		movwf	EEADR
		movf	Rx0d1,W				;get EN hi byte
		call	eewrite
		incf	EEADR
		movf	Rx0d2,W
		call	eewrite
		incf	EEADR
		movf	Rx0d3,W
		call	eewrite
		incf	EEADR
		movf	Rx0d4,W
		call	eewrite
		
		
		movlw	LOW ENindex+1
		movwf	EEADR
		bsf		EECON1,RD
		movf	EEDATA,W
		addlw	1
		movwf	Temp					;increment for next
		call	eewrite				;put back
		movlw	EN_NUM				;is it full now?
		subwf	Temp,W
		bnz		notful
		bsf		T3CON,TMR3ON		;set for flash
		retlw	1
notful	retlw	0	

;***************************************************************************	

newid_f	movlw	LOW CANid			;put in stored ID. FLiM mode
		movwf	EEADR
		bsf		EECON1,RD
		movf	EEDATA,W
		movwf	CanID_tmp			
		call	shuffle
		movlw	B'11110000'
		andwf	Tx1sidh
		movf	IDtemph,W		;set current ID into CAN buffer
		iorwf	Tx1sidh			;leave priority bits alone
		movf	IDtempl,W
		movwf	Tx1sidl			;only top three bits used
		movlw	LOW NodeID
		movwf	EEADR
		call	eeread
		movwf	NN_temph			;get stored NN
		incf	EEADR
		call	eeread
		movwf	NN_templ	
		
		movlb	.15				;put ID into TXB2 for enumeration response to RTR
new_1	btfsc	TXB2CON,TXREQ
		bra		new_1
		clrf	TXB2SIDH
		movf	IDtemph,W
		movwf	TXB2SIDH
		movf	IDtempl,W
		movwf	TXB2SIDL
		movlw	0xB0
		iorwf	TXB2SIDH		;set priority
		clrf	TXB2DLC			;no data, no RTR
		movlb	0
		btfsc	Datmode,3		;already set up?
		return	

;**************************************************************************

;		check if command is for this node

thisNN	movf	NN_temph,W
		subwf	Rx0d1,W
		bnz		not_NN
		movf	NN_templ,W
		subwf	Rx0d2,W
		bnz		not_NN
		retlw 	0			;returns 0 if match
not_NN	retlw	1

;************************************************************************
		
;		send number of events

evns2	movlw	LOW	ENindex+1
		movwf	EEADR
		call	eeread
		movwf	Tx1d3
		movlw	0x74
		movwf	Tx1d0
		movlw	4
		movwf	Dlc
		call	sendTX
		return

;***********************************************************

;		send EVs by reference to EN index

evsend	movf	Rx0d3,W		;get event index
		bz		notEN		;can,t be zero
		decf	WREG
		movwf	Temp
		movlw	LOW ENindex+1	;get number of stored events
		movwf	EEADR
		call	eeread
		cpfslt	Temp
		bra		notEN		;too many events in index
		
		movf	Temp,W
		mullw	EV_NUM		;PRODL has start of EVs
		movf	Rx0d4,W		;get EV index
		bz		notEN		;
		decf	WREG
		movwf	Temp1
		movlw	EV_NUM
		cpfslt	Temp1
		bra		notEN		;too many EVs in index
		movf	Temp1,W
		addwf	PRODL,W		;get EV adress
		addlw	LOW EVstart
		movwf	EEADR
		call	eeread
		movwf	Tx1d5		;put in EV value
		movlw	0xB5
		movwf	Tx1d0
		movff	Rx0d3,Tx1d3
		movff	Rx0d4,Tx1d4
		movlw	6
		movwf	Dlc
		call	sendTX	
		return
notEN	movlw	8		;invalid EN#
		call	errsub
		return

;**************************************************************************
;		send node parameter bytes (7 maximum)

parasend	
		movlw	0xEF
		movwf	Tx1d0
		movlw	LOW node_ID
		movwf	TBLPTRL
		movlw	8
		movwf	TBLPTRH		;relocated code
		lfsr	FSR0,Tx1d1
		movlw	7
		movwf	Count
		bsf		EECON1,EEPGD
		
para1	tblrd*+
		movff	TABLAT,POSTINC0
		decfsz	Count
		bra		para1
		bcf		EECON1,EEPGD	
		movlw	8
		movwf	Dlc
		call	sendTXa
		return

;**********************************************************

;		send individual parameter

para1rd	movlw	0x9B
		movwf	Tx1d0
		movlw	LOW node_ID
		movwf	TBLPTRL
		movlw	8
		movwf	TBLPTRH		;relocated code
		decf	Rx0d3,W
		addwf	TBLPTRL
		bsf		EECON1,EEPGD
		tblrd*
		movff	TABLAT,Tx1d4
		bcf		EECON1,EEPGD
		movff	Rx0d3,Tx1d3
		movlw	5
		movwf	Dlc
		call	sendTX
		return

;*********************************************************************
;		put in NN from command

putNN	movff	Rx0d1,NN_temph
		movff	Rx0d2,NN_templ
		movlw	LOW NodeID
		movwf	EEADR
		movf	Rx0d1,W
		call	eewrite
		incf	EEADR
		movf	Rx0d2,W
		call	eewrite
		movlw	Modstat
		movwf	EEADR
		movlw	B'00001000'		;Module status has NN set
		call	eewrite
		return

;***********************************************************

;	error message send

errmsg	call	errsub
		goto	main2 
errmsg1	call	errsub
		goto	l_out2
errmsg2	call	errsub
		goto	l_out1

errsub	movwf	Tx1d3		;main eror message send. Error no. in WREG
		movlw	0x6F
		movwf	Tx1d0
		movlw	4
		movwf	Dlc
		call	sendTX
		return

;*************************************************************************

;	send individual event by index

enrdi	movlw	LOW ENindex + 1
		movwf	EEADR
		call	eeread
		movwf	ENtemp1
		bz		noens1		;no events set
		movf	Rx0d3,W	
		decf	WREG
		cpfsgt	ENtemp1
		bra		noens1		;too many
		rlncf	WREG
		rlncf	WREG
		addlw	LOW	ENstart
		movwf	EEADR
		call	eeread
		movwf	Tx1d3
		incf	EEADR
		call	eeread
		movwf	Tx1d4
		incf	EEADR
		call	eeread
		movwf	Tx1d5
		incf	EEADR
		call	eeread
		movwf	Tx1d6
enrdi1	movff	Rx0d3,Tx1d7
		movlw	0xF2
		movwf	Tx1d0
		movlw	8
		movwf	Dlc
		call	sendTX
		return
noens1	movlw	7				;no events set
		call	errsub
		return

;*************************************************************************

;		read back all events in sequence

enread	clrf	Temp
		movlw	LOW ENindex + 1
		movwf	EEADR
		call	eeread
		movwf	ENtemp1
		bz		noens		;no events set
		
		movlw	1
		movwf	Tx1d7		;first event
		movlw	LOW	ENstart
		movwf	EEADR
		
	
enloop1	
;		movff	NN_temph,Tx1d1
;		movff	NN_templ,Tx1d2
		call	eeread
		movwf	Tx1d3
		incf	EEADR,F
		call	eeread
		movwf	Tx1d4
		incf	EEADR,F
		call	eeread
		movwf	Tx1d5
		incf	EEADR,F
		call	eeread
		movwf	Tx1d6
		incf	EEADR,F
		
ensend	movlw	0xF2
		movwf	Tx1d0		;OPC
		movlw	8
		movwf	Dlc
		call	sendTX			;send event back
		call	dely
		movf	Tx1d7,F
		bz		lasten
		incf	Temp,F
		movf	ENtemp1,W
		subwf	Temp,W
		bz		lasten
		incf	Tx1d7
		bra		enloop1			;next one
noens	clrf	Rx0d3
		bra		noens1
	
	
lasten	return

;************************************************************************************
;		
eeread	bcf		EECON1,EEPGD	;read a EEPROM byte, EEADR must be set before this sub.
		bcf		EECON1,CFGS		;returns with data in W
		bsf		EECON1,RD
		movf	EEDATA,W
		return

;*********************************************************************
;		send a CAN frame
;		entry at sendTX puts the current NN in the frame - for producer events
;		entry at sendTXa neeeds Tx1d1 and Tx1d2 setting first
;		Latcount is the number of CAN send retries before priority is increased
;		the CAN-ID is pre-loaded in the Tx1 buffer 
;		Dlc must be loaded by calling source to the data length value
		
sendTX	movff	NN_temph,Tx1d1
		movff	NN_templ,Tx1d2

sendTXa	movf	Dlc,W				;get data length
		movwf	Tx1dlc
		movlw	B'00001111'		;clear old priority
		andwf	Tx1sidh,F
		movlw	B'10110000'
		iorwf	Tx1sidh			;low priority
		movlw	.10
		movwf	Latcount
		call	sendTX1			;send frame
		return

;		Send contents of Tx1 buffer via CAN TXB1

sendTX1	lfsr	FSR0,Tx1con
		lfsr	FSR1,TXB1CON
		
		movlb	.15				;check for buffer access
ldTX2	btfsc	TXB1CON,TXREQ	; Tx buffer available...?
		bra		ldTX2			;... not yet
		movlb	0
		
ldTX1	movf	POSTINC0,W
		movwf	POSTINC1	;load TXB1
		movlw	Tx1d7+1
		cpfseq	FSR0L
		bra		ldTX1

		
		movlb	.15				;bank 15
tx1test	btfsc	TXB1CON,TXREQ	;test if clear to send
		bra		tx1test
		bsf		TXB1CON,TXREQ	;OK so send
		
tx1done	movlb	0				;bank 0
		return					;successful send

;***************************************************************
enum	clrf	Tx1con			;CAN ID enumeration. Send RTR frame, start timer
		clrf	Enum0
		clrf	Enum1
		clrf	Enum2
		clrf	Enum3
		clrf	Enum4
		clrf	Enum5
		clrf	Enum6
		clrf	Enum7
		clrf	Enum8
		clrf	Enum9
		clrf	Enum10
		clrf	Enum11
		clrf	Enum12
		clrf	Enum13
;		call	dely			;wait a bit (didn't work without this!)
		
		movlw	B'10111111'		;fixed node, default ID  
		movwf	Tx1sidh
		movlw	B'11100000'
		movwf	Tx1sidl
		movlw	B'01000000'		;RTR frame
		movwf	Dlc
		
		movlw	0x3C			;set T3 to 100 mSec (may need more?)
		movwf	TMR3H
		movlw	0xAF
		movwf	TMR3L
		movlw	B'10110001'
		movwf	T3CON			;enable timer 3
;		bsf		Datmode,1		;used to flag setup state
		movlw	.10
		movwf	Latcount
		
		call	sendTXa			;send RTR frame
		clrf	Tx1dlc			;prevent more RTR frames
		return
		


		
		
;*********************************************************************
;		a delay routine
;		may be used to allow CDU to recharge between succesive outputs.
;		probably needs to be longer for this.
			
dely	movlw	.10
		movwf	Count1
dely2	clrf	Count
dely1	decfsz	Count,F
		goto	dely1
		decfsz	Count1
		bra		dely2
		return	
	
delay2	clrf	Count2		;long delay for CDU recharge
del2	call	dely
		decfsz	Count2
		bra		del2
		return	

;****************************************************************

;		longer delay

ldely	movlw	.100
		movwf	Count2
ldely1	call	dely
		decfsz	Count2
		bra		ldely1
		
		return	

;**********************************************************************
;		loads ENs from EEPROM to RAM for fast access
;		shifts all 32 even if less are used

en_ram	movlw	EN_NUM
		movwf	Count			;number of ENs allowed 
		
		bcf		STATUS,C		;clear carry
		rlncf	Count,F			;double it
		rlncf	Count,F			;double again
		lfsr	FSR0,EN1		;set FSR0 to start of ram buffer
		movlw	LOW ENstart			;load ENs from EEPROM to RAM
		movwf	EEADR
enload	bsf		EECON1,RD		;get first byte
		movff	EEDATA,POSTINC0
		incf	EEADR
		decfsz	Count,F
		bra		enload
		return
		
;***************************************************************	
		
getop	movlw	B'00000011'		;get DIP switch setting for output
		andwf	PORTB,W			;mask
				
		movwf	Shift
		movlw	1
		movwf	EVtemp
shift	movf	Shift,F			;is it zero?
		bz		shift2
		rlncf	EVtemp,F		;put rolling bit into EVtemp
		decf	Shift,F
		bra		shift
		
shift2	return

;****************************************************************
		
		;		clears all stored events

enclear	movlw	EN_NUM * 6 	;number of locations in EEPROM
		movwf	Count
		movlw	LOW ENstart
		movwf	EEADR
enloop	movlw	0
		call	eewrite
		incf	EEADR
		decfsz	Count
		bra		enloop
		return	
;****************************************************************************

nnack	movlw	0x50			;request frame for new NN or ack if not virgin
nnrel	movwf	Tx1d0
		movff	NN_temph,Tx1d1
		movff	NN_templ,Tx1d2
		movlw	3
		movwf	Dlc
		call	sendTX
		return

;**************************************************************************

putNV	movlw	NV_NUM + 1		;put new NV in EEPROM and the NV ram.
		cpfslt	Rx0d3
		return
		movf	Rx0d3,W
		bz		no_NV
		decf	WREG			;NVI starts at 1
		addlw	LOW NVstart
		movwf	EEADR
		movf	Rx0d4,W
	
		call	eewrite	
		
no_NV	return

;************************************************************************

getNV	movlw	NV_NUM + 1		;get NV from EEPROM and send.
		cpfslt	Rx0d3
		bz		no_NV1
		movf	Rx0d3,W
		bz		no_NV1
		decf	WREG			;NVI starts at 1
		addlw	LOW NVstart
		movwf	EEADR
		call	eeread
		movwf	Tx1d4			;NV value
getNV1	movff	Rx0d3,Tx1d3		;NV index
getNV2	movff	Rx0d1,Tx1d1
		movff	Rx0d2,Tx1d2
		movlw	0x97			;NV answer
		movwf	Tx1d0
		movlw	5
		movwf	Dlc
		call	sendTXa
		return

no_NV1	clrf	Tx1d3			;if not valid NV
		clrf	Tx1d4
		bra		getNV2

nv_rest	movlw	8
		movwf	Count
		movlw	LOW Timers
		movwf	Temp
		movwf	EEADR
nv_rest1 call	eeread
		movwf	Temp1
		movlw	0xDA
		addwf	EEADR,F
		movf	Temp1,W
		call	eewrite
		decfsz	Count
		bra		nv_rest2
		return
nv_rest2 incf	Temp,F
		movf	Temp,W
		movwf	EEADR
		bra		nv_rest1

;**********************************************************************

;		new enumeration scheme
;		here with enum array set
;
new_enum	movff	FSR1L,Fsr_tmp1Le	;save FSR1 just in case
			movff	FSR1H,Fsr_tmp1He 
			clrf	IDcount
			incf	IDcount,F			;ID starts at 1
			clrf	Roll
			bsf		Roll,0
			lfsr	FSR1,Enum0			;set FSR to start
here1		incf	INDF1,W				;find a space
			bnz		here
			movlw	8
			addwf	IDcount,F
			incf	FSR1L
			bra		here1
here		movf	Roll,W
			andwf	INDF1,W
			bz		here2
			rlcf	Roll,F
			incf	IDcount,F
			bra		here
here2		movlw	.99					;limit to ID
			cpfslt	IDcount
			call	segful
			movff	Fsr_tmp1Le,FSR1L	;
			movff	Fsr_tmp1He,FSR1H 
			return
			
segful		movlw	7		;segment full, no CAN_ID allocated
			call	errsub
			setf	IDcount
			bcf		IDcount,7
			return		
;************************************************************************
	
	ORG 0xF00000			;EEPROM data. Defaults

CANid	de	B'01111111',0	;CAN id default and module status
NodeID	de	0,0		;Node ID
ENindex	de	0,0		;points to next available EN number (only lo byte used)
					;value actually stored in ENindex+1

		
Timers	de	.5,.5				;Timers (for now)
		de	.5,.5				;These are for each output
		de	.5,.5												
		de	.5,.5												
				

Opmap	de	B'00000001',B'10000000'					;output mapping
		de	B'00000010',B'01000000'					;don't change this
		de	B'00100000',B'00000100'
		de	B'00010000',B'00001000'	
		
		ORG 0xF00020
	
	
ENstart	;start of 32 event numbers. 128 bytes
		
		ORG 0xF000A0
		
EVstart	de	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0		;event qualifiers
		de	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0		;clear EEPROM
		de	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		de	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

NVstart
		de	5,5,5,5,5,5,5,5,0,0,0,0,0,0,0,0
;		de	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

		ORG 0xF000FE
		de	0,0									;for boot.
		
			
		
		end
