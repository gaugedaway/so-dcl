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

;;; Each permutation (L, L^-1, R, R^-1, T) is saved in .bss section
;;; in 3 copies. One of the copies is the main copy, and the two other
;;; copies are placed just before and after it in the memory.
;;; This makes it possible to permform shift permutations (Q_l, Q_r)
;;; simply by adding/subtracting values l/r from the index
;;; without checking if it becomes negative or exceeds 41,
;;; thus removing a lot of conditional jums, which improves
;;; speeds up encryption quite a lot. For example if 'perm' is the address
;;; of the middle of those three copies then perm[-1] == perm[41],
;;; perm[45] == perm[3] (even though the permuation has only 42 elements).


%assign	N		42	; 'Z' - '1'
%assign BUFFER_SIZE	4096


;;; Check if the value of the first argument
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

	;; save the initial positions of rotors
	;; - left rotor in r12, right in r13
	xor	r12, r12
	xor	r13, r13
	mov	rsi, [rsp+5*8]

	;; check if the key has length 2
	cmp	byte [rsi], 0
	je	error
	cmp 	byte [rsi+1], 0
	je	error
	cmp	byte [rsi+2], 0
	jne	error

	mov	r12b, [rsi]
	mov	r13b, [rsi+1]

	;; check if the initial positions are permitted characters
	check_char r12b
	check_char r13b

	;; convert ascii values to shift parameters
	sub	r12b, '1'
	sub	r13b, '1'

.loop:
	;; read a portion of stdin into buffer
	mov	rsi, buffer
	xor	eax, eax
	xor	edi, edi
	mov	edx, BUFFER_SIZE
	syscall

	;; save	addres of the buffer in rdi (to be used by stosb)
	mov	rdi, buffer

	;; if there're no characters left, exit
	cmp	eax, 0
	je	.end

	;; store the number of characters in rcx
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
	inc	r13b
	cmp	r13b, N
	jne	.dont_zero_right
	xor	r13b, r13b
.dont_zero_right:

	;; check whether to rotate the left rotor
	cmp	r13b, 'L' - '1'
	je	.inc_left
	cmp	r13b, 'R' - '1'
	je	.inc_left
	cmp	r13b, 'T' - '1'
	je	.inc_left
	jmp	.dont_inc_left
.inc_left:
	;; rotate the left rotor
	inc	r12b
	cmp	r12b, N
	jne	.dont_zero_left
	xor	r12b, r12b
.dont_zero_left:
.dont_inc_left:

	;; load the next character and check if it's in range
	;; from '1' to 'Z' in ascii
	lodsb
	check_char al

	;; convert ascii value to permutation index
	sub	al, '1'

	;; perform the permutations

	;; R
	add	rax, r13
	mov	al, [rperm + N + rax]
	sub	rax, r13

	;; L
	add	rax, r12
	mov	al, [lperm + N + rax]
	;; clean higher bytes of rax that are set because of last subtraction
	and	rax, 0xff
	sub	rax, r12

	;; T
	mov	al, [tperm + N + rax]
	;; clean higher bytes of rax that are set because of last subtraction
	and	rax, 0xff

	;; L^-1
	add	rax, r12
	mov	al, [lperm_rev + N + rax]
	sub	rax, r12

	;; R^-1
	add	rax, r13
	mov	al, [rperm_rev + N + rax]
	;; clean higher bytes of rax filled because of subtraction
	and	rax, 0xff
	sub	rax, r13

	;; check if the subtraction didn't make the value negative
	jge	.dont_add_n
	add	rax, N
.dont_add_n:

	;; convert permutation index back to ascii
	add	al, '1'

	;; save the output result back to buffer
	stosb

	;; decrease counter, check if there are more
	;; characters in buffer to process
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
;;; is passed in rsi has length N.
check_permutation_length:
	mov	rdi, rsi

	;; we expect '\0' at the position N, so the search
	;; for '\0' shouldn't stop until we pass this position
	mov	ecx, N + 2

	;; al holds the value to be searched for - 0
	xor	al, al

	repne \
	scasb

	;; if the string has incorrect length exit with error code
	sub	rdi, rsi
	cmp	rdi, N + 1
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
	mov	ecx, N
	mov	al, -1
	rep stosb

	;; store the desired location of the resulting permutation in rdi
	mov	rdi, r8

	;; zero cl (used as a counter in the loop) and eax
	;; (al is used to store characters)
	xor	cl, cl
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
	inc	cl
	cmp	cl, N
	jne	.loop

	;; triple the permutation and the reverse permutation;
	;; see description at the beginning of the file for details
	mov 	rsi, r8
	call	triple
	mov 	rsi, r9
	call	triple
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
	inc	cl
	cmp	cl, N
	jne	.loop


	;; triple the permutation;
	;; see description at the beginning of the file for details
	mov	rsi, tperm
	call triple
	ret


;;; Copy the permutation in under the address in rsi
;;; to the address rsi + N and rsi + 2N
triple:
	mov	rdi, rsi
	add	rdi, N
	mov	ecx, N
	rep \
	movsb
	mov 	ecx, N
	rep \
	movsb
	ret


;;; called in case of incorrect input, to exit with code 1
error:
	mov	eax, 60
	mov	edi, 1
	syscall



section .bss

buffer:
	resb 	BUFFER_SIZE
lperm:
	resb 	3*N
lperm_rev:
	resb 	3*N
rperm:
	resb 	3*N
rperm_rev:
	resb 	3*N
tperm:
	resb 	3*N
