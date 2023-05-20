CRC_ACCUM_LOW 		EQU 0DH ; bank 1 regjistri R5
CRC_ACCUM_HI 		EQU 0EH ; bank 1 regjistri R6
CRC_MASK_LSB 		EQU 001H ;CRC-16 polinomi
CRC_MASK_MSB 		EQU 0A0H
TEMP_CRC_H 			EQU 40H
TEMP_CRC_L 			EQU 41H
t15 					EQU 63952 ;VONESA PREJ 1.5tch
t35 					EQU 61848 ;VONESA PREJ 3.5tch
t20 					EQU 63416 ;VONESA PREJ 2tch
PAKETI_GABIM1 		EQU 67H
PARITY_CHECK 		EQU 42H


ORG 0000H
	LJMP MAIN
ORG 000BH
	LJMP T0ISR
ORG 0023H
	LJMP SERVEC
ORG 0030H
MAIN:
	MOV SP,#35H
	MOV SCON,#0D0H ;TI=1, RI=0, REN=1
	MOV TMOD,#21H ;TIMER1=MOD2-AUTORELOAD,TIMER0=MOD1-16BIT
	MOV PCON,#00H ;SINGLE BAUD RATE
	MOV TH1,#0FDH ;9600 BAUD, #0xF3=>1200 BAUD (12 MHz)
	SETB TR1 ;startohet timeri per portin serik
	MOV P0,#00H
	MOV IE,#90H ;lejohet interapti i tajmerit0 dhe iportit serik
	CLR TI
	CLR P3.2
POLLING:
	 MOV C,P0.0
	 MOV 00H,C
	SJMP POLLING
	
	

;==============================================================
;		KTHIMI I PERGJIGJES PAS KALIMIT TE KOHES PREJ 3.5tch
;==============================================================
T0ISR:
	CLR TR0
	CLR TF0
	CLR C
	MOV C,00H
	JC PACKET_2
	MOV DPTR,#14FFH
	LCALL SEND_PACKET
	RETI
	PACKET_2:
	MOV DPTR,#0FFFH
	LCALL SEND_PACKET
	RETI
	 
	 
;=========================================================
;				PRANIMI I PAKETIT DHE ANALIZIMI
;=========================================================
SERVEC:
	CLR TF0
	LCALL PACKET_RECEIVE
	MOV R1,#50H
	MOV A,@R1
	CJNE A,#20H,ID_GABIM
	LCALL CRC_CALC
	MOV A,TEMP_CRC_H
	CJNE A,CRC_ACCUM_HI,ID_GABIM
	MOV A,TEMP_CRC_L
	CJNE A,CRC_ACCUM_LOW,ID_GABIM
	LCALL ANALYZE_DATA
	MOV TH0,#0FFH
	MOV TL0,#00H
	MOV IE,#92H
	CLR TF0
	SETB TR0
	SETB P3.2
	RETI
ID_GABIM:
	CLR P3.2
	MOV R1,#50H
	MOV R0,#0
	RETI

	
;=========================================================
;					PRANIMI I PAKETIT 
;=========================================================
PACKET_RECEIVE:
	MOV R1,#50H
	MOV R0,#0
BYTE_RECEIVE:
	MOV A,SBUF
	CLR RI
	LCALL PARITY_BIT
	PUSH ACC
	MOV A,PARITY_CHECK
	JNZ PARITY_ERROR
	POP ACC
	MOV @R1,A
	INC R0
	INC R1
	MOV TH0,#HIGH t15
	MOV TL0,#LOW t15
	SETB TR0
ANALYZE_T:
	JNB TF0,ANALYZE_RI
	SJMP DELAY_TIMEOUT
ANALYZE_RI:
	JB RI,BYTE_RECEIVE
	SJMP ANALYZE_T
PARITY_ERROR:
	POP ACC
DELAY_TIMEOUT:
	CLR TF0
	DEC R1
	DEC R0
	MOV TEMP_CRC_H,@R1
	DEC R1
	DEC R0
	MOV TEMP_CRC_L,@R1
	DEC R1
	MOV TH0,#HIGH t20
	MOV TL0,#LOW t20
	SETB TR0
WAIT_2TCH:JNB TF0,WAIT_2TCH
	RET
	
	
	
;===================================================
;			LLOGARITJA E CRC-SE
;===================================================
CRC_CALC:
	MOV A,R0
        MOV R3,A
	MOV CRC_ACCUM_LOW,#0FFH ;fshihet crc accum para fillimit
	MOV CRC_ACCUM_HI,#0FFH
	MOV R1,#50H
	PUSH 00H
	CC10:
	MOV A,@R1
	XRL A,CRC_ACCUM_LOW
	MOV CRC_ACCUM_LOW,A
	MOV R6,#8 ;R6 sherben si numrues i 8 bitave ne bajt
	CC20:
	MOV A,CRC_ACCUM_HI ;merret bajti i larte
	CLR C ;mbushet me 0
	RRC A ;shiftohet djathtas
	MOV CRC_ACCUM_HI,A
	MOV A,CRC_ACCUM_LOW ;dhe per bajtin e ulet
	RRC A ;shiftohet djathtas
	MOV CRC_ACCUM_LOW,A
	JNC CC30
	MOV A,CRC_ACCUM_LOW
	XRL A,#CRC_MASK_LSB
	MOV CRC_ACCUM_LOW,A
	MOV A,CRC_ACCUM_HI
	XRL A,#CRC_MASK_MSB
	MOV CRC_ACCUM_HI,A
	CC30:
	DJNZ R6,CC20 ;perseritet tete here
	INC R1 ;gati per bajtin e ardhshem te mesazhit
	DJNZ R3,CC10 ;nje bajt me pak per te llogarite
	pop 00H
	RET

;=============================================
;			ANALIZIMI I TE DHENAVE
;============================================
ANALYZE_DATA:
	MOV R1,#55H
	MOV A,@R1
	MOV B,#8
	DIV AB
	MOV R4,A
	MOV A,B
	CJNE A,#00,INCREASE
	RET
INCREASE:
	INC R4
	RET
	

;================================================
;			PARITY_CHECK
;================================================
PARITY_BIT:
	MOV C,RB8
	MOV 20H,C
	MOV C,P
	MOV 28H,C
	PUSH ACC
	MOV A,24H
	CJNE A,25H,BYTE_ERROR
	POP ACC
	MOV PARITY_CHECK,#00H
	RET
BYTE_ERROR:
	MOV PARITY_CHECK,#0FFH
	RET	
	
	
	
;===================================================
;			RUTINA PER DERGIMIN E PAKETIT
;===================================================
SEND_PACKET:
	SJMP FIRST
LOOP:
	MOV C,P
	MOV TB8,C
	MOV SBUF,A

WAIT: JNB TI,WAIT
FIRST:
	CLR TI
	INC DPTR
	MOV A,#00
	MOVC A,@A+DPTR
	CJNE A,#3,LOOP
	MOV IE,#90H
	CLR P3.2	
	RET
	
	
;==================================================
;				PAKETI I PARE- LIGHT ON
;==================================================
ORG 1000H
	DB 20H,01H,01H,01H,9AH,74H,3
	
	
;==================================================
;			PAKETI I DYTE-LIGHT OFF
;==================================================
ORG 1500H
	DB 20H,01H,01H,00H,5BH,0B4H,3
END