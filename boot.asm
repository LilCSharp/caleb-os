; Sets the origin to 0x7c00 as this is where the BIOS loads the bootloader
ORG 0x7c00

; Specifies that this is a 16-bit architecture, meaning data comes in 16 bits
BITS 16

; For more information on interrupts, visit http://www.ctyme.com/rbrown.htm

start:
    mov si, message
    call print

    ; Has the bootloader jump to itself so that it doesn't execute its own
    ; signature.
    jmp $

print:
    ; Specifies background color and foreground
    mov bx, 0

.loop:
    ; Loads the character that the si register points to into the al register,
    ; and increments the si register
    lodsb

    ; If the null byte is reached, meaning si is at the end of the string, then
    ; jump to the .done routine. Else, prints the character
    cmp al, 0
    je .done
    call print_char
    jmp .loop

.done:
    ret

print_char:
    ; Moves 0eh into the ah register, which is a part of eax.
    ; 0eh is a command for a BIOS routine for video teletype output
    mov ah, 0eh

    ; This is an interrupt that calls the BIOS routine specified in the ah
    ; register.
    int 0x10

    ret

; Routine that creates bytes containing the specified string below. Terminates
; with the null byte
message: db 'Hello World!', 0

; Says that at least 510 bytes need to be used.
; If less than 510 bytes is filled, the rest is padded with 0's
times 510- ($ - $$) db 0

; The BIOS recognizes the bootloader via the signature 0x55AA.
; Since Intel Architectures are Little Endian, the reading order
; is reversed. This code loads the signature into the file.
dw 0xAA55