%assign	ALPHABET_SIZE	42


	section .text


	global 	_start
_start:
	cld

	;; check the number of arguments
	cmp	qword [rsp], 5
	jne	error

	mov	rsi, [rsp+2*8]
	call	check_permutation
	mov	rsi, [rsp+3*8]
	call	check_permutation
	mov	rsi, [rsp+4*8]
	call	check_permutation

	;; exit with code 0
	mov	eax, 60
	xor	edi, edi
	syscall


check_permutation:
	;; check if the permutation string has the correct length
	mov	rdi, rsi
	mov	ecx, ALPHABET_SIZE + 2
	xor	al, al
	repne \
	scasb
	sub	rdi, rsi
	cmp	rdi, ALPHABET_SIZE + 1
	jne 	error
	ret


;;; called in case of incorrect input, to exit with code 1
error:
	mov	eax, 60
	mov	edi, 1
	syscall
