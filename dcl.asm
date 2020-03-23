;;; 1. Assignment: DCL
;;; Author: Adam Bac


;;; General note: all used permutations are stored in the .bss section
;;; as strings of 42 bytes with values in range 0-41. So to compute the
;;; result of applying a permutation to a character 'A', one should take the
;;; 17th byte of the string (because 'A' - '1' = 16, and bytes are
;;; indexed starting from 0) and add the ascii code of '1' to it.
;;; Indexes from 0 to 41 are used to encode the permutation, instead of
;;; actuall ascii values in order to avoid repeated subtracting needed
;;; to convert ascii values to indexes in permutation.



%assign	ALPHABET_SIZE	42	; 'Z' - '1'
%assign BUFFER_SIZE	4096



;;; Performs a cyclic shift, permutation and a reverse cyclic shift
;;; on the value stored in AL (has to be in range 0-41).
;;; First argument is the address of the permuation (encoded as described
;;; above) and the second is the shift parameter (a shift with parameter
;;; 2 shifts 'A' to 'C'; parameter = 0 means no shift).
;;; Arguments can be literal values or registers.
%macro permute 2
	add	al, %2
	cmp	al, ALPHABET_SIZE
	jb	%%dont_sub
	sub	al, ALPHABET_SIZE
%%dont_sub:

	mov	al, [%1 + rax]

	sub	al, %2
	jae	%%dont_add
	add	al, ALPHABET_SIZE
%%dont_add:
%endmacro



;;; Check if the value of the first argument (literal or a register)
;;; is a character from '1' to 'Z' in ascii.
%macro check_char 1
	cmp	%1, '1'
	jb	error
	cmp	%1, 'Z'
	ja	error
%endmacro



section .text


	global 	_start
_start:
	;; string operations should increment
	cld

	;; check the number of arguments
	cmp	qword [rsp], 5
	jne	error

	;; process the permutation L
	mov	rsi, [rsp+2*8]
	mov	r8, lperm
	mov	r9, lperm_rev
	call	process_l_or_r

	;; process the permutation R
	mov	rsi, [rsp+3*8]
	mov	r8, rperm
	mov	r9, rperm_rev
	call	process_l_or_r

	;; process the permutation T
	mov	rsi, [rsp+4*8]
	call	process_t

	;; save the initial positions of rotors in bx
	;; - left rotor in bl, right in bh
	mov	rbx, [rsp+5*8]
	mov	bx, [rbx]

	;; check if the initial positions are permitted characters
	check_char bl
	check_char bh

	;; convert ascii values to shift parameters
	sub	bl, '1'
	sub	bh, '1'

.loop:
	;; read a portion of stdin into buffer
	mov	rsi, buffer
	xor	eax, eax
	xor	edi, edi
	mov	edx, BUFFER_SIZE
	syscall

	;; if there're no characters left, exit
	cmp	eax, 0
	je	.end

	;; store the number of characters in rax
	;; (it will be used as a counter in the loop)
	;; and in rdx (it will be used as an argument to sys_write)
	mov	ecx, eax
	mov	edx, eax

	;; set rax to 0, since al will be used to store
	;; the currently processed character
	xor	eax, eax

	;; a loop processing each character in the buffer
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

	;; load the next character and check if it's in range
	;; from '1' to 'Z' in ascii
	mov	al, [rsi]
	check_char al

	;; convert ascii value to permutation index
	sub	al, '1'

	;; perform the permutations
	permute	rperm, bh
	permute	lperm, bl
	mov	al, [tperm + rax]
	permute lperm_rev, bl
	permute rperm_rev, bh

	;; convert permutation index back to ascii
	add	al, '1'

	;; save the output result back to buffer
	mov	[rsi], al

	;; move pointer to the next character, decrease counter,
	;; check if there are more characters in buffer to process
	inc	rsi
	dec	ecx
	jnz	.inner_loop

	;; write the content of the buffer to stdout
	mov	eax, 1
	mov	rsi, buffer
	mov	edi, 1
	syscall

	;; read the next block
	jmp	.loop

.end:
	;; exit with code 0
	mov	eax, 60
	xor	edi, edi
	syscall



;;; Checks if a zero-terminated string, a pointer to which
;;; is passed in rsi has length ALPHABET_SIZE.
check_permutation_length:
	mov	rdi, rsi

	;; we expect '\0' at the position ALPHABET_SIZE, so the search
	;; for '\0' shouldn't stop until we pass this position
	mov	ecx, ALPHABET_SIZE + 2

	;; al holds the value to be searched for - 0
	xor	al, al

	repne scasb

	;; if the string has incorrect length exit with error code
	sub	rdi, rsi
	cmp	rdi, ALPHABET_SIZE + 1
	jne 	error

	ret



;;; Given a permutation string as passed in a command line argument (L or R),
;;; the following subroutine checks if it has the correct length,
;;; contains only allowed characters ('1'-'Z'), and if every character
;;; occurs only once. It saves the permutation in a specified address
;;; (encoded as described at the beginning of the file) and computes
;;; it's reverse. For permutation T, process_t is used instead.
;;; rsi - address of the permutation string
;;; r8 - address where the permutation should be saved
;;; r9 - address where the reverse permutation should be saved
process_l_or_r:
	call	check_permutation_length

	;; fill the space reserved for the reverse permutation with values -1
	mov	rdi, r9
	mov	ecx, 42
	mov	al, -1
	rep stosb

	;; store the desired location of the resulting permutation in rdi
	mov	rdi, r8

	;; zero ecx (used as a counter in the loop) and eax
	;; (al is used to store characters)
	xor	ecx, ecx
	xor	eax, eax
.loop:
	;; load a character from [rsi] to al, increment rsi
	lodsb

	;; check if the character is from range '1' to 'Z' in ascii
	check_char al

	;; convert ascii value to permutation index and save it in
	;; the resulting permutation
	sub	al, '1'
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

	;; increment the counter and if there are characters left, repeat
	inc	ecx
	cmp	ecx, ALPHABET_SIZE
	jne	.loop

	ret



;;; Given a string of permutation T as passed in a command line argument,
;;; the following subroutine checks if it has the correct length,
;;; contains only allowed characters ('1'-'Z'), and if the permutation
;;; consists only of disjoint transpositions.
;;; It saves the permutation in a specified address
;;; (encoded as described at the beginning of the file).
;;; rsi - address of the permutation string
process_t:
	call	check_permutation_length

	;; zero ecx (used as a counter in the loop) and eax
	;; (al is used to store the characters)
	xor	ecx, ecx
	xor	eax, eax
.loop:
	;; load a character from the string to al
	mov	al, [rsi + rcx]

	;; check if the character is from range '1' to 'Z' in ascii
	check_char al

	;; convert ascii value to permutation index and save it in
	;; the resulting permutation
	sub	al, '1'
	mov	[tperm + rcx], al

	;; apply the permutation again and check if it gives back
	;; our current position in the string (in other words, if
	;; the character we processed lies on a cycle of length 2.
	mov	al, [rsi + rax]
	sub	al, '1'
	cmp	al, cl
	jne	error

	;; increment the counter and if there are characters left, repeat
	inc	ecx
	cmp	ecx, ALPHABET_SIZE
	jne	.loop

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

buffer:
	resb	BUFFER_SIZE
