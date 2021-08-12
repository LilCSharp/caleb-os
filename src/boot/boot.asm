; Sets the origin to 0x7c00 as this is where the BIOS loads the bootloader
ORG 0x7c00

; Specifies that this is a 16-bit architecture, meaning data comes in 16 bits
BITS 16

; For more information on interrupts, visit http://www.ctyme.com/rbrown.htm
; For more information on FAT BIOS Param Block specs, visit https://wiki.osdev.org/FAT

CODE_SEG equ gdt_code - gdt_start ; Will store the offset 0x8
DATA_SEG equ gdt_data - gdt_start ; Will store the offset 0x10

_start:
    jmp short start
    nop

times 33 db 0 ; BIOS Parameter Block outside of the first 3 short jump NOP

start:
    jmp 0:step2 ; Changes the code segment to 0x7c0

step2:
    cli ; Clear Interrupts

    mov ax, 0x00 ; To modify the data segment register, ax must be set

    ; Sets the data segment to the location where the BIOS loads the bootloader
    ; lodsb indexes data with the data segment and offsets with the si register
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti ; Enables Interrupts

.load_protected:
    cli
    lgdt[gdt_descriptor]
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax
    jmp CODE_SEG:load32 ; Jumps to the code segment to get the offset, then jumps to load32

; Global Descriptor Table
; For more information, visit
gdt_start:
gdt_null:
    dd 0x0
    dd 0x0

; Offset 0x8
gdt_code:     ; Code Segment points to this
    dw 0xffff ; Segment limit to first 0-15 bits
    dw 0      ; Base first 0-15 bits
    db 0      ; Base 16-23 bits
    db 0x9a   ; Access byte (bit mask)
    db 1100111b ; High 4 bit flags and low 4 bit flags
    db 0      ; Base 24-31 bits

; Offset 0x10
gdt_data:     ; Should be pointed at by DS, SS, ES, FS, GS
    dw 0xffff ; Segment limit to first 0-15 bits
    dw 0      ; Base first 0-15 bits
    db 0      ; Base 16-23 bits
    db 0x92   ; Access byte (bit mask)
    db 1100111b ; High 4 bit flags and low 4 bit flags
    db 0      ; Base 24-31 bits

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start-1
    dd gdt_start ; Is the offset

[BITS 32]
load32:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov ebp, 0x00200000
    mov esp, ebp

    ; Enables the A20 Line
    in al, 0x92
    or al, 2
    out 0x92, al

    jmp $

; Says that at least 510 bytes need to be used.
; If less than 510 bytes is filled, the rest is padded with 0's
times 510- ($ - $$) db 0

; The BIOS recognizes the bootloader via the signature 0x55AA.
; Since Intel Architectures are Little Endian, the reading order
; is reversed. This code loads the signature into the file.
dw 0xAA55