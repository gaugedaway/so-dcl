%assign	ALPHABET_SIZE	42


section .text


	global 	_start
_start:
	cld

	;; check the number of arguments
	cmp	qword [rsp], 5
	jne	error

	mov	rsi, [rsp+2*8]
	mov	r8, lperm
	mov	r9, lperm_rev
	call	process_permutation
	mov	rsi, [rsp+3*8]
	mov	r8, rperm
	mov	r9, rperm_rev
	call	process_permutation
	mov	rsi, [rsp+4*8]
	mov	r8, tperm
	mov	r9, tperm_rev
	call	process_permutation

	;; exit with code 0
	mov	eax, 60
	xor	edi, edi
	syscall


;;; rsi - address of the permutation string
;;; r8 - address where the permutation should be saved
;;; r9 - address where the reverse permutation should be saved
process_permutation:
	;; check if the permutation string has correct length
	mov	rdi, rsi
	mov	ecx, ALPHABET_SIZE + 2
	xor	al, al
	repne \
	scasb
	sub	rdi, rsi
	cmp	rdi, ALPHABET_SIZE + 1
	jne 	error

	;; fill the space reserved for the reverse permutation with values -1
	mov	rdi, r9
	mov	ecx, 42
	mov	al, -1
	rep \
	stosb

	mov	rdi, r8
	mov	ecx, 0
	xor	eax, eax
.loop:
	;; loade a byte from [rsi] to al, increment rsi
	lodsb

	;; exit with error code when the character in [rsi] has value
	;; greater than 'Z'
	cmp 	al, 'Z'
	jg	error

	;; subtract ascii value of '1' from the character in [rsi]
	;; and exit error if that character had value lower than '1'
	sub	al, '1'
	jl	error

	stosb

	;; if the value in the reverse permutation on the position al
	;; (that is, the value to which the reverse permutation maps
	;; the currently processed character) has already been set
	;; (that is, it's different from -1), it means that the character
	;; occurs twice it the original permutation, which is not allowed
	cmp	byte [r9 + rax], -1
	jne	error

	;; set the corresponding value in the reverse permutation
	mov	[r9 + rax], al

	inc	ecx
	cmp	ecx, ALPHABET_SIZE
	jl	.loop

	ret


;;; called in case of incorrect input, to exit with code 1
error:
	mov	eax, 60
	mov	edi, 1
	syscall



section .bss

lperm:
	resb	ALPHABET_SIZE

lperm_rev:
	resb	ALPHABET_SIZE

rperm:
	resb	ALPHABET_SIZE

rperm_rev:
	resb	ALPHABET_SIZE

tperm:
	resb	ALPHABET_SIZE

tperm_rev:
	resb	ALPHABET_SIZE
