%assign	ALPHABET_SIZE	42
%assign BUFFER_SIZE	4096


%macro permute 2
	add	al, %2
	cmp	al, ALPHABET_SIZE
	jl	%%dont_sub
	sub	al, ALPHABET_SIZE
%%dont_sub:

	mov	al, [%1 + rax]

	sub	al, %2
	jnl	%%dont_add
	add	al, ALPHABET_SIZE
%%dont_add:
%endmacro


%macro check_char 1
	cmp	%1, '1'
	jb	error
	cmp	%1, 'Z'
	ja	error
%endmacro


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

	;; initial positions
	mov	rbx, [rsp+5*8]
	mov	bx, [rbx]

	check_char bl
	check_char bh
	sub	bl, '1'
	sub	bh, '1'

.loop:
	;; read a portion of stdin into buffer
	mov	rsi, buffer
	xor	eax, eax
	xor	edi, edi
	mov	edx, BUFFER_SIZE
	syscall

	;; if there're no characters to be read, exit
	cmp	eax, 0
	je	.end

	mov	ecx, eax
	mov	edx, eax
	xor	eax, eax
.inner_loop:

	;; rotate the right rotor
	inc	bh
	cmp	bh, ALPHABET_SIZE
	jne	.dont_zero_right
	xor	bh, bh
.dont_zero_right:

	;; check whether to rotate the left rotor
	cmp	bh, 'L' - '1'
	je	.inc_left
	cmp	bh, 'R' - '1'
	je	.inc_left
	cmp	bh, 'T' - '1'
	je	.inc_left
	jmp	.dont_inc_left
.inc_left:
	;; rotate the left rotor
	inc	bl
	cmp	bl, ALPHABET_SIZE
	jne	.dont_zero_left
	xor	bl, bl
.dont_zero_left:
.dont_inc_left:

	mov	al, [rsi]
	sub	al, '1'

	;; perform the permutations
	permute	rperm, bh
	permute	lperm, bl
	mov	al, [tperm + rax]
	permute lperm_rev, bl
	permute rperm_rev, bh

	add	al, '1'
	mov	[rsi], al

	inc	rsi
	dec	ecx
	jnz	.inner_loop

	mov	eax, 1
	mov	rsi, buffer
	mov	edi, 1
	syscall

	jmp	.loop

.end:
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
	mov	[r9 + rax], cl

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

buffer:
	resb	BUFFER_SIZE
