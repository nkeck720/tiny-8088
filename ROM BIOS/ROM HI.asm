	use16
	org 7FFFh		;upper 32K of the segment
	;
	; ROMHI.ASM - The upper 32k of the ROM BIOS for The Tiny 8088
	; This ROM BIOS is designed to do a minimum functionality test of the 8088 CPU
	; and then begin setting up the environment for the 8088 Monitor.
	; The CPU starts at address FFFF0 (FFFF:0000) which is 16 bytes before the end of the ROM.
	; We need to allow for that and tell it to jump to the start address given here.
	;
start:
	; Begin by testing registers
	mov ax, 0000h
	mov bx, ax
	mov cx, ax
	mov dx, ax
	mov si, ax
	cmp ax, 0000h
	jne fail_test
	cmp bx, 0000h
	jne fail_test
	cmp cx, 0000h
	jne fail_test
	cmp dx, 0000h
	jne fail_test
	cmp si, 0000h
	jne fail_test
	; If we're here, we passed.
	; Set up the DS and ES registers so we can initialize the serial port
	mov ss, ax
	mov bx, 7FFEh		; The end of the first memory chip
	mov sp, bx
	push cs
	push cs
	pop ds
	pop es
	jmp init_serial
fail_test:
	; Disable interrupts and halt forever
	cli
	hlt
	jmp fail_test
init_serial:
	; Begin by setting up the onboard 16450 
	; The 16450 base I/O address is at 00h
	; We want 300 baud 8N1 with interrupts enabled for data received
	; and transmit buffer empty, but we will enable interrupts only when we
	; have a handler set up
	; Start by setting up parity and data/stop bit information
	mov dx, 0003h
	out dx, 11000011b
	; Now we need to set the baud rate to 300
	mov dx, 0000h
	out dx, 80h
	inc dx
	out dx, 01h
	mov dx, 0003h
	out dx, 01000011b
	; Display "THE TINY 8088(crlf)" message
	mov cx, 15d
	mov si, 0000h
disp_message:
	mov ah, byte ptr data+si
	mov dx, 0000h
	out dx, ah
	; Poll to see if the if the next byte can be sent
wait_for_ready:
	mov dx, 0002h
	in  ah, dx
	and ah, 00001000b
	cmp ah, 00001000b
	jne wait_for_ready
	; If we're here the character has been sent and we're waiting for a
	; new one
	inc si
	loop disp_message
	; Now we need to detect memory in 32K increments. We will save the number of chips in a reserved
	; data area in low RAM.
	; Start by setting the segment we are starting at (0000h)
	mov bx, 0000h
	mov es, bx
	; Now set the BX register to zero chips and begin detecting chips at every half segment (32K blocks)
	mov bx, 0000h
detect_loop:
	mov byte ptr es:7FFEh, 0FFh
	mov ah, byte ptr es:7FFEh
	cmp ah, 0FFh
	jne done_detect
	; Otherwise we need to keep detecting
	inc bx
	mov byte ptr es:0FFFFh, 0FFh
	mov ah, byte ptr es:0FFFFh
	cmp ah, 0FFh
	jne done_detect
	inc bx
	; go to the next segment
	push bx
	push es
	pop bx
	add bx, 1000h
	mov es, bx
	pop bx
	jmp detect_loop
	
data:
	db "THE TINY 8088", 0Dh, 0Ah
times 32751-($-$$) db 0
; Here is where the CPU starts its execution on powerup
jmp start