.data
endl   db 0ah
msg1   db "string : ",0dh
msg2   db "Substring : ",0dh
msg3   db "The number of occurrences: ",0dh
msg4   db "Position: ",0dh
endline   db 0ah,0dh	

fVirtualAlloc db "VirtualAlloc", 0
fVirtualFree db "VirtualFree", 0
fwrite db "WriteConsole",0
fGetStdHandle db "GetStdHandle", 0
fexit db "ExitProcess", 0
fread db "ReadConsole",0
end_line db 0ah,0dh
count dq 0
time  dq 0

.data?
res dq 1 dup(?)
res_times db 32 dup(?)
string dq 1 dup(?)
substring dq 32 dup(?)
position dq 32 dup(?)


BaseAddress dq 5 dup(?)
VA_of_exported_dir dq 5 dup(?)
VA_of_exported_table dq 5 dup(?)     
_Write dq 5 dup (?)        
_Read dq 5 dup (?)         
_GetStdHandle dq 5 dup (?)        
_Exit dq 5 dup (?)         
write dq 5 dup (?)       
read dq 5 dup (?)                    
STD_IN dq 5 dup (?)  
STD_OUT dq 5 dup (?) 
_VirtualAlloc dq 5 dup (?) 
_VirtualFree dq 5 dup (?) 

;======== Parameter of VirtualAlloc======================
; value of flAllocationType
MEM_COMMIT equ 1000h
MEM_RESERVE equ 2000h
MEM_RESET equ 80000h
MEM_RESET_UNDO equ 1000000h

;======== Parameter of VirtualFree======================
;Value of dwFreeType
MEM_DECOMMIT equ 4000h
MEM_RELEASE equ 8000h

;========Memory Protection Constants=====================
PAGE_READWRITE equ 04h
PAGE_EXECUTE_READWRITE equ 40h

len dq 5 dup (?) 


.code

main proc
	call init

	lea rcx,string
	mov rdx,200
	call Alloc
	mov string,rax

	lea rcx,substring
	mov rdx,10
	call Alloc
	mov substring,rax

	lea rcx,res
	mov rdx,1000
	call Alloc
	mov res,rax

	lea rdx,msg1
	call _OUTPUT
	
	mov r8,200
	mov rdx,string
	call _INPUT

	lea rdx,msg2
	call _OUTPUT

	mov r8,10
	mov rdx,substring
	call _INPUT

	mov rcx,string
	mov rdx,substring
	call _Substring

	lea rdx,msg3
	call _OUTPUT

	mov rcx,time
	lea rdx,res_times
	call Itoa

	lea rdx,res_times
	call _OUTPUT

	lea rdx,end_line
	CALL _OUTPUT

	lea rdx,msg4
	call _OUTPUT

	mov rdx,res
	call _OUTPUT


	mov rcx,string
	call Free

	mov rcx,substring
	call Free

	mov rcx,res
	call Free

	mov rax, _Exit
	mov rcx,0
	call rax


main endp

;====================================================================================================================================================

GetBaseAddress proc
	push rbp
	mov rbp,rsp
	xor rax,rax
	mov rax, gs:[rax+60h]     ; PEB at fs:[0x30](x86) or gs:[0x60](x64)
	mov rax, [rax+18h]        ; PEB -> Ldr
	mov rsi, [rax+20h]        ; PEB -> Ldr.InMemOrder
	lodsq					  ; rax = Second Module (ntdll.dll) || load value of pointer -> rsi to rax
	xchg rax,rsi              ; rax = PEB -> Ldr.InMemOrder ;  rsi = Second Module (ntdll.dll)
	lodsq                     ; rax = Third Module (kernel32.dll)
	mov rax, [rax+20h]        ; rax = Base Adrress
	mov BaseAddress, rax      ; Save
	leave
	ret
GetBaseAddress endp

GetExportedTable proc
	push rbp
	mov rbp,rsp
	xor rcx,rcx
	mov ecx,[rax+3ch]        ; rcx = DOS ->e_lfanew || RVA of PE signature || the last 4 bytes in MS-DOS header are e_lfanew
	add rcx,rax              ; VA = BaseAddress + RVA
	mov ecx,[rcx+88h]        ; RVA of exported directory
	add rcx,rax              ; VA of exported directory
	mov VA_of_exported_dir,rcx
	mov esi,[rcx+20h]        ; RVA of exported table
	add rsi,BaseAddress      ; VA of exported table
	mov VA_of_exported_table,rsi
	leave
	ret
GetExportedTable endp

GetProcAddress proc
	push rbp
	mov rbp,rsp
	sub rsp,16
	mov [rbp-8],rcx
	mov [rbp-16],rdx
	push rax
	push rbx
	push rdi
	xor rax,rax
	xor rcx,rcx
	xor rbx,rbx
	mov rsi,VA_of_exported_table
	mov rbx,[rbp-16]

	Start_find:
		inc rcx
		lodsd
		add rax,BaseAddress        ;VA of function
		xor rdi,rdi
	Cmp_function_name:
		xor rdx,rdx
		mov dl, byte ptr [rax+rdi]
		mov dh, byte ptr [rbx+rdi]
		inc rdi
		cmp dh,0
		je  Finish_find
		cmp dh,dl
		je  Cmp_function_name
		jmp Start_find
	Finish_find:
		mov rbx,VA_of_exported_dir
		mov esi, [rbx+24h]         ;RVA of function ordinal table
		add rsi, BaseAddress       ; VA of function ordinal table
		mov cx, [rsi+rcx*2]		   ; get LoadLibray biased_ordinal
		dec rcx					   ; get LoadLibray ordinal
		mov esi, [rbx+1ch]         ; RVA of Address Of Functions
		add rsi, BaseAddress       ; VA
		mov esi, [rsi+rcx*4]       ; RVA of LoadLibrayA
		add rsi, BaseAddress
		xor rbx,rbx
		mov rbx,[rbp-8]
		mov [rbx],rsi
		pop rdi
		pop rbx
		pop rax
		leave
		ret 

GetProcAddress endp

init proc
	push rbp
	mov rbp,rsp
	
	call GetBaseAddress
	call GetExportedTable

	lea rcx , _Write
	lea rdx , fWrite
	call GetProcAddress

	lea rcx , _Read
	lea rdx , fRead
	call GetProcAddress

	lea rcx , _GetStdHandle
	lea rdx , fGetStdHandle
	call GetProcAddress

	lea rcx , _Exit
	lea rdx , fExit
	call GetProcAddress

	mov rax, _GetStdHandle
	mov rcx,-11
	call rax
	mov STD_OUT , rax

	mov rax, _GetStdHandle
	mov rcx,-10
	call rax
	mov STD_IN, rax

	;LPVOID VirtualAlloc( LPVOID lpAddress, SIZE_T dwSize, DWORD  flAllocationType, DWORD  flProtect)

	lea rcx , _VirtualAlloc
	lea rdx , fVirtualAlloc
	call GetProcAddress

	;VirtualFree( LPVOID lpAddress, SIZE_T dwSize, DWORD  dwFreeType)
	lea rcx , _VirtualFree
	lea rdx , fVirtualFree
	call GetProcAddress

	leave
	ret
init endp

Strlen PROC                                         ; return value to RAX
	push	rbp
	mov		rbp,rsp
	push    rsi
	xor		rsi,rsi
	xor		rax,rax
	count_char:
		cmp	byte ptr [rcx+rsi],0dh
		jz finished
		inc rsi
		jmp count_char

	finished:
		mov rax,rsi
		pop rsi
		leave
		ret 
Strlen endp

_INPUT proc
	push rbp
	mov	rbp,rsp

	sub rsp,8
	mov rax, _Read
	mov rcx, STD_IN
	lea r9, read
	push 0
	call rax
	add rsp,16						; Align stack after call func
	leave
	ret

_INPUT endp

_OUTPUT proc
	push rbp
	mov rbp,rsp
	mov rcx,rdx
	call Strlen
	
	sub rsp,8
	mov r8, rax
	mov rax, _Write
	mov rcx, STD_OUT
	lea r9, write
	push 0
	call rax
	add rsp,16                     ; Align stack after call func
	leave
	ret

_OUTPUT endp

Alloc proc
	;ptr = VirtualAlloc(NULL,size,MEM_RESERVE,PAGE_READWRITE); //reserving memory
	;ptr = VirtualAlloc(ptr,size,MEM_COMMIT,PAGE_READWRITE);  //commiting memory
	push rbp
	mov rbp,rsp
	sub rsp,20h
	mov [rbp-8],rcx
	mov [rbp-16],rdx
	
	mov rax,_VirtualAlloc
	mov rcx,0
	mov r8, MEM_RESERVE
	mov r9, PAGE_READWRITE
	call rax

	mov rcx,rax
	mov rax,_VirtualAlloc
	mov rdx,[rbp-16]
	mov r8, MEM_COMMIT
	mov r9, PAGE_READWRITE
	call rax

	add rsp,20h
	leave
	ret
Alloc endp

Free proc
	;VirtualFree(ptr, 0, MEM_RELEASE)    //releasing memory

	push rbp
	mov rbp,rsp
	sub rsp,40h
	mov rax, _VirtualFree
	mov rdx,0
	mov r8,MEM_RELEASE
	call rax

	leave
	ret
Free endp

;====================================================================================================================================================


Itoa proc                     ;rcx = int     rdx = address of string
	push rbp
	mov rbp,rsp
	sub rsp,8
	mov [rbp-8],rdx
	push rax
	push rbx
	push rdx
	push rsi
	xor rbx,rbx
	mov rax,rcx
	mov rsi,10
	Start_div:
		xor rdx,rdx
		div rsi
		add dl,30h
		push rdx
		inc rbx
		cmp rax,0
		je Tmp
		jmp Start_div
	Tmp:
		xor rsi,rsi
		mov rcx,[rbp-8]
		
	Pop_Itoa:
		cmp rbx,0
		je  End_Itoa
		pop rdx
		mov BYTE PTR [rcx+rsi],dl
		inc rsi
		dec rbx
		jmp Pop_Itoa
	End_Itoa:
		mov BYTE PTR [rcx+rsi],0dh
		pop	rsi
		pop rdx
		pop rbx
		pop rax
		add rsp,8
		leave
		ret
Itoa endp

_Substring proc
	push rbp
	mov rbp,rsp
	sub rsp,16
	mov [rbp-8],rcx								; string
	mov [rbp-16],rdx							; substring
	push rax
	push rbx
	push rdi
	push rsi

	xor rsi,rsi
	xor rdi,rdi

	Start_find:									; Find the first character that is the same
		cmp byte ptr [rcx+rsi],0dh
		je  End_find
		xor rbx,rbx
		mov bh,byte ptr [rcx+rsi]
		mov bl,byte ptr [rdx]
		cmp bh,bl
		je  Next_find
		inc rsi
		jmp Start_find
	Next_find:
		cmp byte ptr [rdx+rdi],0dh
		je  Push_pos
		xor rbx,rbx
		mov bh,byte ptr [rcx+rsi]
		mov bl,byte ptr [rdx+rdi]
		inc rsi
		inc rdi
		cmp bh,bl
		je  Next_find
		jmp Temp_find

	Temp_find:
		sub rsi,rdi
		inc rsi
		xor rdi,rdi
		jmp Start_find

	Push_pos:
		sub rsi,rdi
		mov rcx,rsi
		lea rdx,position
		call Itoa

		lea rcx,position
		mov rdx,res
		call Push_position
		
		mov rcx,[rbp-8]
		mov rdx,[rbp-16]
		inc time
		inc rsi
		xor rdi,rdi
		jmp Start_find

	End_find:
		pop rsi
		pop rdi
		pop rbx
		pop rax
		add rsp,16
		leave 
		ret


_Substring endp

Push_position proc										;rcx = position		rdx = res
	push rbp
	mov rbp,rsp
	push rbx
	push rsi
	push rdi

	xor rdi,rdi
	mov rsi,count

	Start_push:
		cmp byte ptr [rcx+rdi],0dh
		je  End_push
		xor rbx,rbx
		mov bl,byte ptr [rcx+rdi]
		mov byte ptr [rdx+rsi],bl
		inc rdi
		inc rsi
		jmp Start_push
	End_push:
		mov byte ptr [rdx+rsi],20h
		inc rsi
		mov byte ptr [rdx+rsi],0dh
		mov count ,rsi
		pop rdi
		pop rsi
		pop rbx
		leave 
		ret
Push_position endp


end

