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
; For more information, visit: https://wiki.osdev.org/Global_Descriptor_Table
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
    db 11001111b ; High 4 bit flags and low 4 bit flags
    db 0      ; Base 24-31 bits

; Offset 0x10
gdt_data:     ; Should be pointed at by DS, SS, ES, FS, GS
    dw 0xffff ; Segment limit to first 0-15 bits
    dw 0      ; Base first 0-15 bits
    db 0      ; Base 16-23 bits
    db 0x92   ; Access byte (bit mask)
    db 11001111b ; High 4 bit flags and low 4 bit flags
    db 0      ; Base 24-31 bits

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start-1
    dd gdt_start ; Is the offset


; For more information on ATA read/write sectors, visit:
; https://wiki.osdev.org/ATA_read/write_sectors and especially
; https://wiki.osdev.org/ATA_PIO_Mode
[BITS 32]
load32:
    mov eax, 1 ; Starting sector to load from (0 is the boot sector)
    mov ecx, 100 ; Total number of sectors that will be loaded into memory
    mov edi, 0x0100000 ; The address that the sectors will be loaded into
    call ata_lba_read ; Talk with the drive and loads sectors into memory
    jmp CODE_SEG:0x0100000

ata_lba_read:
    mov ebx, eax, ; Backup the LBA

    ; Send the highest 8 bits of the lba to the hard disk controller
    shr eax, 24
    or eax, 0xE0 ; Selects the master drive
    mov dx, 0x1F6 ; Port that expects the 8 bits
    out dx, al

    ; Finished sending the highest 8 bits of the LBA
    ; Send the total sectors to read
    mov eax, ecx
    mov dx, 0x1F2
    out dx, al
    ; Finished sending the total sectors to read

    ; Send more bits of the LBA
    mov eax, ebx ; Restore the backup LBA
    mov dx, 0x1F3
    out dx, al
    ; Finished sending more bits of the LBA

    ; Send more bits of the LBA
    mov dx, 0x1F4
    mov eax, ebx ; Restore the backup of the LBA
    shr eax, 8
    out dx, al
    ; Finished sending more bits of the LBA

    ; Send upper 16 bits of the LBA
    mov dx, 0x1F5
    mov eax, ebx ; Restore the backup of the LBA
    shr eax, 16
    out dx, al
    ; Finished sending upper 16 bits of the LBA

    mov dx, 0x1f7
    mov al, 0x20
    out dx, al

; Read all sectors into memory
.next_sector:
    push ecx

; Checking if reading needs to be done
.try_again:
    mov dx, 0x1f7
    in al, dx
    test al, 8
    jz .try_again

    ; Need to read 256 words at a time
    mov ecx, 256
    mov dx, 0x1F0
    rep insw ; Reading a word from a port and stores into the address in edi
    pop ecx
    loop .next_sector
    ; End of reading sectors into memory
    ret

; Says that at least 510 bytes need to be used.
; If less than 510 bytes is filled, the rest is padded with 0's
times 510- ($ - $$) db 0

; The BIOS recognizes the bootloader via the signature 0x55AA.
; Since Intel Architectures are Little Endian, the reading order
; is reversed. This code loads the signature into the file.
dw 0xAA55