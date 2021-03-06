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
	; Do a push-pop test
	mov ax, 0FFFFh
	push ax
	pop ax
	cmp ax, 0FFFFh
	jne fail_test
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
	mov al, 11000011b
	out dx, al
	; Now we need to set the baud rate to 300
	mov dx, 0000h
	mov al, 80h
	out dx, al
	inc dx
	mov al, 01h
	out dx, al
	mov dx, 0003h
	mov al, 01000011b
	out dx, al
	; Display "THE TINY 8088(crlf)" message
	mov cx, 15d
	mov si, 0000h
disp_message:
	mov al, byte ptr stuff+si
	mov dx, 0000h
	out dx, al
	; Poll to see if the if the next byte can be sent
wait_for_ready:
	mov dx, 0002h
	in  al, dx
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
done_detect:
	; Check to see if we have more than zero chips. If we have none then we have a failure condition
	cmp bx, 0000h
	je  fail_test
	; Now we need to tell the user how many memory chips we got
	mov si, chip_detect
	push cs
	pop ds
chip_detect_msg:
	mov al, byte ptr ds:si
	; check if it's a null
	cmp al, 00h
	je  print_number
	; Print the character
	mov dx, 0000h
	out dx, al
wait_chip_detect:
	; Poll for next character to be printed
	mov dx, 0002h
	in  al, dx
	and ah, 00001000b
	cmp ah, 00001000b
	jne wait_chip_detect
	; Next char ready
	inc si
	jmp chip_detect_msg
print_number:
	; Now we need to print the number of chips by converting the number
	; in BX to ascii
	push bx
	; Get the ones digit
	mov si, nums
	and bx, 0F000h
	mov cl, 2Dh
	shr bx, cl
	add si, bx
	mov al, byte ptr ds:si
	mov dx, 0000h
	out dx, al
	call wait_loop
	pop bx
	push bx
	mov si, nums
	and bx, 00F00h
	mov cl, 1Eh
	shr bx, cl
	add si, bx
	mov al, byte ptr ds:si
	out dx, al
	call wait_loop
	pop bx
	push bx
	mov si, nums
	and bx, 000F0h
	mov cl, 0Fh
	shr bx, cl
	add si, bx
	mov al, byte ptr ds:si
	mov dx, 0000h
	out dx, al
	call wait_loop
	pop bx
	push bx
	mov si, nums
	and bx, 0000Fh
	add si, bx
	mov al, byte ptr ds:si
	mov dx, 0000h
	out dx, al
	call wait_loop
	; Now we need to do a memory test.
	mov bx, 0000h
	mov es, bx
	mov si, 0000h		; for counting chips
mem_test:
	; First, set the segment we are testing in
	; On the stack is the number of chips
	mov cx, 7FFEh
first_seg_loop:
	mov bx, cx
	mov byte ptr es:bx, 0FFh
	mov ah, byte ptr es:bx
	cmp ah, 0FFh
	jne done_test
	; Otherwise, continue
	loop first_seg_loop
	; If we're here a 32K chip tested OK
	inc si
	; Now test the high bit of the segment.
	mov cx, 8000h
second_seg_loop:
	mov bx, cx
	add bx, 7FFFh
	mov byte ptr es:bx, 0FFh
	mov ah, byte ptr es:bx
	cmp ah, 0FFh
	jne done_test
	loop second_seg_loop
	; If we're here, then we need to increment es and continue
	push es
	pop bx
	inc bx
	mov es, bx
	jmp mem_test
done_test:
	;We need to see if zero chips tested okay
	cmp si, 00h
	je  fail_test
	; Otherwise we can continue by printing the number that passed
	mov bx, chip_test
	push cs
	pop ds
chip_test_msg:
	mov al, byte ptr ds:bx
	; check if it's a null
	cmp al, 00h
	je  print_number
	; Print the character
	mov dx, 0000h
	out dx, al
wait_chip_test:
	; Poll for next character to be printed
	mov dx, 0002h
	in  al, dx
	and ah, 00001000b
	cmp ah, 00001000b
	jne wait_chip_test
	; Next char ready
	inc bx
	jmp chip_test_msg
	; Now print the number
	mov bx, si
	push bx
	mov si, nums
	and bx, 0F000h
	mov cl, 2Dh
	shr bx, cl
	add si, bx
	mov al, byte ptr ds:si
	mov dx, 0000h
	out dx, al
	call wait_loop
	pop bx
	push bx
	mov si, nums
	and bx, 00F00h
	mov cl, 1Eh
	shr bx, cl
	add si, bx
	mov al, byte ptr ds:si
	out dx, al
	call wait_loop
	pop bx
	push bx
	mov si, nums
	and bx, 000F0h
	mov cl, 0Fh
	shr bx, cl
	add si, bx
	mov al, byte ptr ds:si
	mov dx, 0000h
	out dx, al
	call wait_loop
	pop bx
	push bx
	mov si, nums
	and bx, 0000Fh
	add si, bx
	mov al, byte ptr ds:si
	mov dx, 0000h
	out dx, al
	call wait_loop
	; Now we need to save the number of chips in a word somewhere in low RAM
	; In this case we will save it just after the IVT
	mov bx, 0000h
	mov es, bx
	mov bx, 0400h
	pop ax
	mov word ptr es:bx, ax
	; Begin setting up the few interrupts that we can now
	; This includes INT10 teletype functions, INT16 input functions,
	; and basic IBM PC-compatible interrupt services. We will also enable interrupts
	; on the 16450 for data recieved and we will put it in a RAM buffer from 00500 hex to 005FF hex
		
stuff:
		    db "THE TINY 8088", 0Dh, 0Ah
chip_detect db "     MEM CHIPS DETECTED", 0Dh, 00h
chip_test   db "     TEST OK", 0Dh, 00h
nums		db "0123456789ABCDEF"
wait_loop:
	mov dx, 0002h
	in  al, dx
	and al, 00001000b
	cmp al, 00001000b
	jne wait_loop
	ret
times 32751-($-$$) db 0
; Here is where the CPU starts its execution on powerup
cli
jmp start
times 12 db 0