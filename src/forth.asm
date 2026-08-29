; =========================================================
; Proyecto: Intérprete Forth para Windows x86 (32 bits) en MASM
; Archivo : forth.asm
; Estado  : versión funcional con validación básica de errores
;
; Incluye:
;   - Consola interactiva y parser por tokens
;   - Normalización del input a minúsculas
;   - Diccionario estático y definiciones dinámicas con : y ;
;   - Stack de datos y literales compilados mediante lit
;   - Return stack: >r r> r@
;   - Validación de underflow y división por cero
;   - Aritmética: + - * /
;   - Comparaciones: = < > 0= 0< 0>
;   - Stack: dup drop swap over depth
;   - Utilidades: . .s clear words quit
;   - Memoria: constant variable @ !
;   - Saltos internos: 0branch branch
;   - Condicionales: if else then
;   - Ciclos: begin until again while repeat
;   - Salida anticipada de palabras compiladas: exit
;
; Cambios recientes:
;   - Detectado underflow en las palabras que consumen stacks
;   - Detectada división por cero sin consumir sus operandos
;   - Las líneas con error no imprimen OK
;
; Notas:
;   - Las palabras de control se ejecutan durante la compilación
;   - Las direcciones de salto compiladas son absolutas
;   - while debe utilizarse después de begin
;   - repeat debe cerrar la estructura begin ... while ... repeat
;   - again crea un ciclo infinito salvo que se use exit
;   - clear vacía solamente la pila de datos
;   - El underflow informa el error y conserva el contenido existente
;
; Próxima etapa prevista:
;   - Validar estructuras de control incompletas durante la compilación
;   - Agregar ciclos contados: do loop +loop i
; =========================================================

.386
.model flat, stdcall
option casemap:none

GetStdHandle PROTO :DWORD
WriteConsoleA PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
ReadConsoleA  PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
ExitProcess   PROTO :DWORD

do_lit           PROTO
do_0branch       PROTO
do_branch        PROTO
do_plus          PROTO
do_minus         PROTO
do_mul           PROTO
do_div           PROTO
do_eq            PROTO
do_lt            PROTO
do_gt            PROTO
do_zero_eq       PROTO
do_zero_lt       PROTO
do_zero_gt       PROTO
do_fetch         PROTO
do_store         PROTO
do_constant_word PROTO
do_variable_word PROTO
do_constant_def  PROTO
do_variable_def  PROTO
do_depth         PROTO
do_dot           PROTO
do_dup           PROTO
do_drop          PROTO
do_dot_s         PROTO
do_swap          PROTO
do_over          PROTO
do_to_r          PROTO
do_r_from        PROTO
do_r_fetch       PROTO
do_clear         PROTO
do_words         PROTO
do_colon_start   PROTO
do_semicolon     PROTO
do_colon         PROTO
do_if            PROTO
do_else          PROTO
do_then          PROTO
do_begin         PROTO
do_until         PROTO
do_again         PROTO
do_while         PROTO
do_repeat        PROTO
do_exit          PROTO
do_quit          PROTO

copy_token_to_name_here PROTO
compile_dword PROTO
push_compile PROTO
pop_compile PROTO

includelib kernel32.lib

.data

Welcome_Forth_  db "      _",0Ah
                db "  _. |_ _  ._ _|_ |_",0Ah
                db " (_| | (_) |   |_ | |    v.1.1",13,10,0
msg_len_        equ ($ - Welcome_Forth_)

Welcome_Forth__ db "                ",13,10,0
msg_len__       equ ($ - Welcome_Forth__)

prompt          db ">> ",0
prompt_len      equ 3

ok_msg          db "OK",13,10,0
ok_len          equ 4

err_msg         db "?",13,10,0
err_len         equ 3

stack_underflow_msg db "Stack underflow",13,10,0
stack_underflow_len equ ($ - stack_underflow_msg)

division_zero_msg db "Division by zero",13,10,0
division_zero_len equ ($ - division_zero_msg)

space           db " "
crlf            db 13,10
lbracket        db "[ "
rbracket        db " ]",13,10

stack           dd 1000 dup(0)
dsp             dd 0
return_stack    dd 1000 dup(0)
rsp             dd 0

buffer_size     equ 256
buffer          db buffer_size dup(0)
bytesRead       dd ?
bytesWritten    dd ?

numBuffer       db 16 dup(0)

state           dd 0
error_flag      dd 0
dict_space      dd 4096 dup(0)
here            dd OFFSET dict_space
name_space      db 2048 dup(0)
name_here       dd OFFSET name_space
data_space      dd 1024 dup(0)
data_here       dd OFFSET data_space
current_def     dd 0
ip              dd 0
exit_target     dd 0

compile_stack   dd 128 dup(0)
compile_sp      dd 0

; =========================================================
; STATIC DICTIONARY
; layout: [link][name_ptr][code_ptr]
; dynamic const/var add one extra cell: [value_or_addr]
; =========================================================

name_lit        db "lit",0
word_lit_link   dd 0
word_lit_name   dd OFFSET name_lit
word_lit_code   dd OFFSET do_lit

name_0branch      db "0branch",0
word_0branch_link dd OFFSET word_lit_link
word_0branch_name dd OFFSET name_0branch
word_0branch_code dd OFFSET do_0branch

name_branch      db "branch",0
word_branch_link dd OFFSET word_0branch_link
word_branch_name dd OFFSET name_branch
word_branch_code dd OFFSET do_branch

name_plus       db "+",0
word_plus_link  dd OFFSET word_branch_link
word_plus_name  dd OFFSET name_plus
word_plus_code  dd OFFSET do_plus

name_minus      db "-",0
word_minus_link dd OFFSET word_plus_link
word_minus_name dd OFFSET name_minus
word_minus_code dd OFFSET do_minus

name_mul        db "*",0
word_mul_link   dd OFFSET word_minus_link
word_mul_name   dd OFFSET name_mul
word_mul_code   dd OFFSET do_mul

name_div        db "/",0
word_div_link   dd OFFSET word_mul_link
word_div_name   dd OFFSET name_div
word_div_code   dd OFFSET do_div

name_eq         db "=",0
word_eq_link    dd OFFSET word_div_link
word_eq_name    dd OFFSET name_eq
word_eq_code    dd OFFSET do_eq

name_lt         db "<",0
word_lt_link    dd OFFSET word_eq_link
word_lt_name    dd OFFSET name_lt
word_lt_code    dd OFFSET do_lt

name_gt         db ">",0
word_gt_link    dd OFFSET word_lt_link
word_gt_name    dd OFFSET name_gt
word_gt_code    dd OFFSET do_gt

name_zero_eq    db "0=",0
word_zero_eq_link dd OFFSET word_gt_link
word_zero_eq_name dd OFFSET name_zero_eq
word_zero_eq_code dd OFFSET do_zero_eq

name_zero_lt    db "0<",0
word_zero_lt_link dd OFFSET word_zero_eq_link
word_zero_lt_name dd OFFSET name_zero_lt
word_zero_lt_code dd OFFSET do_zero_lt

name_zero_gt    db "0>",0
word_zero_gt_link dd OFFSET word_zero_lt_link
word_zero_gt_name dd OFFSET name_zero_gt
word_zero_gt_code dd OFFSET do_zero_gt

name_fetch      db "@",0
word_fetch_link dd OFFSET word_zero_gt_link
word_fetch_name dd OFFSET name_fetch
word_fetch_code dd OFFSET do_fetch

name_store      db "!",0
word_store_link dd OFFSET word_fetch_link
word_store_name dd OFFSET name_store
word_store_code dd OFFSET do_store

name_constant   db "constant",0
word_constant_link dd OFFSET word_store_link
word_constant_name dd OFFSET name_constant
word_constant_code dd OFFSET do_constant_def

name_variable   db "variable",0
word_variable_link dd OFFSET word_constant_link
word_variable_name dd OFFSET name_variable
word_variable_code dd OFFSET do_variable_def

name_depth      db "depth",0
word_depth_link dd OFFSET word_variable_link
word_depth_name dd OFFSET name_depth
word_depth_code dd OFFSET do_depth

name_dot        db ".",0
word_dot_link   dd OFFSET word_depth_link
word_dot_name   dd OFFSET name_dot
word_dot_code   dd OFFSET do_dot

name_dup        db "dup",0
word_dup_link   dd OFFSET word_dot_link
word_dup_name   dd OFFSET name_dup
word_dup_code   dd OFFSET do_dup

name_drop       db "drop",0
word_drop_link  dd OFFSET word_dup_link
word_drop_name  dd OFFSET name_drop
word_drop_code  dd OFFSET do_drop

name_dot_s      db ".s",0
word_dot_s_link dd OFFSET word_drop_link
word_dot_s_name dd OFFSET name_dot_s
word_dot_s_code dd OFFSET do_dot_s

name_swap       db "swap",0
word_swap_link  dd OFFSET word_dot_s_link
word_swap_name  dd OFFSET name_swap
word_swap_code  dd OFFSET do_swap

name_over       db "over",0
word_over_link  dd OFFSET word_swap_link
word_over_name  dd OFFSET name_over
word_over_code  dd OFFSET do_over

name_to_r       db ">r",0
word_to_r_link  dd OFFSET word_over_link
word_to_r_name  dd OFFSET name_to_r
word_to_r_code  dd OFFSET do_to_r

name_r_from       db "r>",0
word_r_from_link  dd OFFSET word_to_r_link
word_r_from_name  dd OFFSET name_r_from
word_r_from_code  dd OFFSET do_r_from

name_r_fetch       db "r@",0
word_r_fetch_link  dd OFFSET word_r_from_link
word_r_fetch_name  dd OFFSET name_r_fetch
word_r_fetch_code  dd OFFSET do_r_fetch

name_clear      db "clear",0
word_clear_link dd OFFSET word_r_fetch_link
word_clear_name dd OFFSET name_clear
word_clear_code dd OFFSET do_clear

name_words      db "words",0
word_words_link dd OFFSET word_clear_link
word_words_name dd OFFSET name_words
word_words_code dd OFFSET do_words

name_colon      db ":",0
word_colon_link dd OFFSET word_words_link
word_colon_name dd OFFSET name_colon
word_colon_code dd OFFSET do_colon_start

name_semicolon      db ";",0
word_semicolon_link dd OFFSET word_colon_link
word_semicolon_name dd OFFSET name_semicolon
word_semicolon_code dd OFFSET do_semicolon

name_if      db "if",0
word_if_link dd OFFSET word_semicolon_link
word_if_name dd OFFSET name_if
word_if_code dd OFFSET do_if

name_else      db "else",0
word_else_link dd OFFSET word_if_link
word_else_name dd OFFSET name_else
word_else_code dd OFFSET do_else

name_then      db "then",0
word_then_link dd OFFSET word_else_link
word_then_name dd OFFSET name_then
word_then_code dd OFFSET do_then

name_begin      db "begin",0
word_begin_link dd OFFSET word_then_link
word_begin_name dd OFFSET name_begin
word_begin_code dd OFFSET do_begin

name_until      db "until",0
word_until_link dd OFFSET word_begin_link
word_until_name dd OFFSET name_until
word_until_code dd OFFSET do_until

name_again      db "again",0
word_again_link dd OFFSET word_until_link
word_again_name dd OFFSET name_again
word_again_code dd OFFSET do_again

name_while      db "while",0
word_while_link dd OFFSET word_again_link
word_while_name dd OFFSET name_while
word_while_code dd OFFSET do_while

name_repeat      db "repeat",0
word_repeat_link dd OFFSET word_while_link
word_repeat_name dd OFFSET name_repeat
word_repeat_code dd OFFSET do_repeat

name_exit       db "exit",0
word_exit_link  dd OFFSET word_repeat_link
word_exit_name  dd OFFSET name_exit
word_exit_code  dd OFFSET do_exit

name_quit       db "quit",0
word_quit_link  dd OFFSET word_exit_link
word_quit_name  dd OFFSET name_quit
word_quit_code  dd OFFSET do_quit

last            dd OFFSET word_quit_link

.code

main PROC
    invoke GetStdHandle, -11
    invoke WriteConsoleA, eax, ADDR Welcome_Forth_, msg_len_, ADDR bytesWritten, 0
    invoke GetStdHandle, -11
    invoke WriteConsoleA, eax, ADDR Welcome_Forth__, msg_len__, ADDR bytesWritten, 0

main_loop:
    call print_prompt
    call read_line
    mov error_flag, 0
    call interpret
    cmp error_flag, 0
    jne main_loop
    call print_ok
    jmp main_loop
main ENDP

; =========================================================
; INTERPRETER / COMPILER
; =========================================================
interpret PROC
    mov esi, OFFSET buffer

next_token:
skip_spaces:
    mov al, [esi]
    cmp al, ' '
    jne check_end
    inc esi
    jmp skip_spaces

check_end:
    cmp byte ptr [esi], 13
    je interpret_done
    cmp byte ptr [esi], 10
    je interpret_done
    cmp byte ptr [esi], 0
    je interpret_done

    cmp state, 0
    je interpret_mode
    jmp compile_mode

interpret_mode:
    push esi
    call find_word
    pop esi
    cmp eax, 0
    jne exec_word

    push esi
    call is_number_token
    pop esi
    cmp eax, 0
    je invalid_token

    call parse_number
    call push_stack
    jmp next_token

exec_word:
    call execute_word
    jmp skip_token

compile_mode:
    push esi
    call find_word
    pop esi
    cmp eax, 0
    jne compile_known_word

    push esi
    call is_number_token
    pop esi
    cmp eax, 0
    je compile_invalid

    mov eax, OFFSET word_lit_link
    call compile_dword

    call parse_number
    call compile_dword
    jmp next_token

compile_known_word:
    cmp eax, OFFSET word_semicolon_link
    je compile_exec_word

    cmp eax, OFFSET word_if_link
    je compile_exec_word

    cmp eax, OFFSET word_else_link
    je compile_exec_word

    cmp eax, OFFSET word_then_link
    je compile_exec_word

    cmp eax, OFFSET word_begin_link
    je compile_exec_word

    cmp eax, OFFSET word_until_link
    je compile_exec_word

    cmp eax, OFFSET word_again_link
    je compile_exec_word

    cmp eax, OFFSET word_while_link
    je compile_exec_word

    cmp eax, OFFSET word_repeat_link
    je compile_exec_word

    cmp eax, OFFSET word_colon_link
    je compile_invalid

    cmp eax, OFFSET word_constant_link
    je compile_invalid

    cmp eax, OFFSET word_variable_link
    je compile_invalid

    call compile_dword
    jmp skip_token

compile_exec_word:
    call execute_word
    jmp skip_token

invalid_token:
    call print_error
    jmp skip_token

compile_invalid:
    call print_error
    mov state, 0
    mov current_def, 0
    mov compile_sp, 0
    ret

skip_token:
    mov al, [esi]
    cmp al, ' '
    je next_token
    cmp al, 13
    je next_token
    cmp al, 10
    je next_token
    cmp al, 0
    je next_token
    inc esi
    jmp skip_token

interpret_done:
    ret
interpret ENDP

; =========================================================
; DICTIONARY
; =========================================================
find_word PROC
    mov ebx, last
find_next:
    cmp ebx, 0
    je find_not_found

    push esi
    mov edi, [ebx+4]

compare_loop:
    mov al, [esi]
    mov dl, [edi]

    cmp al, ' '
    je compare_match
    cmp al, 13
    je compare_match
    cmp al, 10
    je compare_match
    cmp al, 0
    je compare_match

    cmp al, dl
    jne compare_no_match

    inc esi
    inc edi
    jmp compare_loop

compare_match:
    cmp byte ptr [edi], 0
    jne compare_no_match

    pop esi
    mov eax, ebx
    ret

compare_no_match:
    pop esi
    mov ebx, [ebx]
    jmp find_next

find_not_found:
    xor eax, eax
    ret
find_word ENDP

execute_word PROC
    mov edi, eax
    mov eax, [edi+8]
    call eax
    ret
execute_word ENDP

; =========================================================
; TOKEN CHECK / PARSER / HELPERS
; =========================================================
is_number_token PROC
    xor eax, eax

    cmp byte ptr [esi], '-'
    jne int_check_first

    mov dl, [esi+1]
    cmp dl, ' '
    je int_not_number
    cmp dl, 13
    je int_not_number
    cmp dl, 10
    je int_not_number
    cmp dl, 0
    je int_not_number

    inc esi

int_check_first:
    mov dl, [esi]
    cmp dl, '0'
    jb int_not_number
    cmp dl, '9'
    ja int_not_number

int_loop:
    mov dl, [esi]
    cmp dl, ' '
    je int_is_number
    cmp dl, 13
    je int_is_number
    cmp dl, 10
    je int_is_number
    cmp dl, 0
    je int_is_number

    cmp dl, '0'
    jb int_not_number
    cmp dl, '9'
    ja int_not_number

    inc esi
    jmp int_loop

int_is_number:
    mov eax, 1
    ret

int_not_number:
    xor eax, eax
    ret
is_number_token ENDP

parse_number PROC
    xor edx, edx
    xor ebx, ebx

    cmp byte ptr [esi], '-'
    jne parse_loop_start
    mov ebx, 1
    inc esi

parse_loop_start:
    movzx ecx, byte ptr [esi]

    cmp ecx, ' '
    je parse_done
    cmp ecx, 13
    je parse_done
    cmp ecx, 10
    je parse_done
    cmp ecx, 0
    je parse_done

    cmp ecx, '0'
    jb parse_done
    cmp ecx, '9'
    ja parse_done

    sub ecx, '0'
    imul edx, 10
    add edx, ecx

    inc esi
    jmp parse_loop_start

parse_done:
    mov eax, edx
    cmp ebx, 0
    je parse_exit
    neg eax

parse_exit:
    ret
parse_number ENDP

copy_token_to_name_here PROC
    push ebx
    push edi

    mov edi, name_here
    mov eax, edi

ct_loop:
    mov bl, [esi]
    cmp bl, ' '
    je ct_done
    cmp bl, 13
    je ct_done
    cmp bl, 10
    je ct_done
    cmp bl, 0
    je ct_done

    mov [edi], bl
    inc edi
    inc esi
    jmp ct_loop

ct_done:
    mov byte ptr [edi], 0
    inc edi
    mov name_here, edi

    pop edi
    pop ebx
    ret
copy_token_to_name_here ENDP

compile_dword PROC
    push ebx
    mov ebx, here
    mov DWORD PTR [ebx], eax
    add ebx, 4
    mov here, ebx
    pop ebx
    ret
compile_dword ENDP

push_compile PROC
    mov ebx, compile_sp
    mov DWORD PTR compile_stack[ebx*4], eax
    inc compile_sp
    ret
push_compile ENDP

pop_compile PROC
    cmp compile_sp, 0
    jle pop_compile_empty
    dec compile_sp
    mov ebx, compile_sp
    mov eax, DWORD PTR compile_stack[ebx*4]
    ret

pop_compile_empty:
    xor eax, eax
    ret
pop_compile ENDP

; =========================================================
; STACK
; =========================================================
push_stack PROC
    mov ebx, dsp
    mov DWORD PTR stack[ebx*4], eax
    inc dsp
    ret
push_stack ENDP

pop_stack PROC
    cmp dsp, 0
    jle pop_empty
    dec dsp
    mov ebx, dsp
    mov eax, DWORD PTR stack[ebx*4]
    ret

pop_empty:
    xor eax, eax
    ret
pop_stack ENDP

; =========================================================
; COMPILED WORD SUPPORT
; =========================================================
do_lit PROC
    push ebx
    mov ebx, ip
    mov eax, DWORD PTR [ebx]
    add ebx, 4
    mov ip, ebx
    pop ebx
    call push_stack
    ret
do_lit ENDP

do_0branch PROC
    push ebx
    cmp dsp, 1
    jb do_0branch_underflow
    call pop_stack
    mov ebx, ip
    cmp eax, 0
    jne do_0branch_no_jump

    mov eax, DWORD PTR [ebx]
    mov ip, eax
    pop ebx
    ret

do_0branch_no_jump:
    add ebx, 4
    mov ip, ebx
    pop ebx
    ret

do_0branch_underflow:
    call print_stack_underflow
    pop ebx
    ret
do_0branch ENDP

do_branch PROC
    push ebx
    mov ebx, ip
    mov eax, DWORD PTR [ebx]
    mov ip, eax
    pop ebx
    ret
do_branch ENDP

do_colon_start PROC
find_colon_end:
    mov al, [esi]
    cmp al, ' '
    je skip_spaces_after_colon
    cmp al, 13
    je dcs_exit
    cmp al, 10
    je dcs_exit
    cmp al, 0
    je dcs_exit
    inc esi
    jmp find_colon_end

skip_spaces_after_colon:
    cmp byte ptr [esi], ' '
    jne have_name
    inc esi
    jmp skip_spaces_after_colon

have_name:
    mov ebx, here
    mov current_def, ebx

    mov eax, last
    mov DWORD PTR [ebx], eax
    add ebx, 4
    mov here, ebx

    call copy_token_to_name_here

    mov ebx, here
    mov DWORD PTR [ebx], eax
    add ebx, 4
    mov DWORD PTR [ebx], OFFSET do_colon
    add ebx, 4

    mov here, ebx
    mov eax, current_def
    mov last, eax
    mov state, 1
    mov compile_sp, 0

dcs_exit:
    ret
do_colon_start ENDP

do_semicolon PROC
    cmp state, 1
    jne ds_exit

    xor eax, eax
    call compile_dword
    mov state, 0
    mov current_def, 0
    mov compile_sp, 0

ds_exit:
    ret
do_semicolon ENDP

do_colon PROC
    push ebx
    push esi
    push ip

    lea ebx, [edi+12]
    mov ip, ebx

dc_loop:
    mov ebx, ip
    mov eax, DWORD PTR [ebx]
    add ebx, 4
    mov ip, ebx

    cmp eax, 0
    je dc_done

    mov edi, eax
    mov eax, [edi+8]
    call eax
    jmp dc_loop

dc_done:
    pop ip
    pop esi
    pop ebx
    ret
do_colon ENDP

; EXIT ends the currently executing colon definition.
; It redirects IP to a permanent zero cell. On the next
; do_colon iteration, the zero token terminates the word.
do_exit PROC
    mov ip, OFFSET exit_target
    ret
do_exit ENDP

do_if PROC
    cmp state, 1
    jne do_if_exit

    mov eax, OFFSET word_0branch_link
    call compile_dword

    mov eax, here
    call push_compile

    xor eax, eax
    call compile_dword

do_if_exit:
    ret
do_if ENDP

do_else PROC
    cmp state, 1
    jne do_else_exit

    mov eax, OFFSET word_branch_link
    call compile_dword

    mov edx, here
    xor eax, eax
    call compile_dword

    call pop_compile
    test eax, eax
    jz do_else_exit

    mov ecx, here
    mov DWORD PTR [eax], ecx

    mov eax, edx
    call push_compile

do_else_exit:
    ret
do_else ENDP

do_then PROC
    cmp state, 1
    jne do_then_exit

    call pop_compile
    test eax, eax
    jz do_then_exit

    mov edx, here
    mov DWORD PTR [eax], edx

do_then_exit:
    ret
do_then ENDP

; BEGIN marks the current compilation address.
do_begin PROC
    cmp state, 1
    jne do_begin_exit

    mov eax, here
    call push_compile

do_begin_exit:
    ret
do_begin ENDP

; UNTIL compiles a backward conditional branch.
; Runtime stack effect: ( flag -- )
; A zero flag repeats the loop; nonzero exits it.
do_until PROC
    cmp state, 1
    jne do_until_exit

    call pop_compile
    test eax, eax
    jz do_until_exit
    mov edx, eax

    mov eax, OFFSET word_0branch_link
    call compile_dword

    mov eax, edx
    call compile_dword

do_until_exit:
    ret
do_until ENDP

; AGAIN compiles an unconditional backward branch.
do_again PROC
    cmp state, 1
    jne do_again_exit

    call pop_compile
    test eax, eax
    jz do_again_exit
    mov edx, eax

    mov eax, OFFSET word_branch_link
    call compile_dword

    mov eax, edx
    call compile_dword

do_again_exit:
    ret
do_again ENDP

; WHILE compiles a conditional exit after a BEGIN marker.
; Compile-stack before: [ ... begin-address ]
; Compile-stack after : [ ... begin-address exit-placeholder ]
; Runtime stack effect of the generated 0branch: ( flag -- )
do_while PROC
    cmp state, 1
    jne do_while_exit

    ; The BEGIN address remains on the compile stack.
    ; Compile 0branch followed by an unresolved target cell.
    mov eax, OFFSET word_0branch_link
    call compile_dword

    mov eax, here
    call push_compile

    xor eax, eax
    call compile_dword

do_while_exit:
    ret
do_while ENDP

; REPEAT closes BEGIN ... WHILE ... REPEAT.
; It compiles an unconditional branch back to BEGIN, then patches
; WHILE's pending target so a false condition exits after the loop.
do_repeat PROC
    cmp state, 1
    jne do_repeat_exit

    ; Top item is WHILE's exit placeholder.
    call pop_compile
    test eax, eax
    jz do_repeat_exit
    mov edx, eax

    ; Next item is BEGIN's backward target.
    call pop_compile
    test eax, eax
    jz do_repeat_exit
    mov ecx, eax

    mov eax, OFFSET word_branch_link
    call compile_dword

    mov eax, ecx
    call compile_dword

    ; HERE now points to the first instruction after the loop.
    mov eax, here
    mov DWORD PTR [edx], eax

do_repeat_exit:
    ret
do_repeat ENDP

; =========================================================
; ARITHMETIC / COMPARISONS / MEMORY
; =========================================================
do_plus PROC
    cmp dsp, 2
    jb do_plus_underflow
    call pop_stack
    mov edx, eax
    call pop_stack
    add eax, edx
    call push_stack
do_plus_end:
    ret
do_plus_underflow:
    call print_stack_underflow
    ret
do_plus ENDP

do_minus PROC
    cmp dsp, 2
    jb do_minus_underflow
    call pop_stack
    mov edx, eax
    call pop_stack
    sub eax, edx
    call push_stack
do_minus_end:
    ret
do_minus_underflow:
    call print_stack_underflow
    ret
do_minus ENDP

do_mul PROC
    cmp dsp, 2
    jb do_mul_underflow
    call pop_stack
    mov edx, eax
    call pop_stack
    imul eax, edx
    call push_stack
do_mul_end:
    ret
do_mul_underflow:
    call print_stack_underflow
    ret
do_mul ENDP

do_div PROC
    cmp dsp, 2
    jb do_div_underflow
    mov ebx, dsp
    dec ebx
    cmp DWORD PTR stack[ebx*4], 0
    je do_div_zero
    call pop_stack
    mov ecx, eax
    call pop_stack
    cdq
    idiv ecx
    call push_stack
do_div_end:
    ret
do_div_underflow:
    call print_stack_underflow
    ret
do_div_zero:
    call print_division_by_zero
    ret
do_div ENDP

do_eq PROC
    cmp dsp, 2
    jb do_eq_underflow
    call pop_stack
    mov edx, eax
    call pop_stack
    cmp eax, edx
    jne do_eq_false
    mov eax, -1
    call push_stack
    jmp do_eq_end
do_eq_false:
    xor eax, eax
    call push_stack
do_eq_end:
    ret
do_eq_underflow:
    call print_stack_underflow
    ret
do_eq ENDP

do_lt PROC
    cmp dsp, 2
    jb do_lt_underflow
    call pop_stack
    mov edx, eax
    call pop_stack
    cmp eax, edx
    jge do_lt_false
    mov eax, -1
    call push_stack
    jmp do_lt_end
do_lt_false:
    xor eax, eax
    call push_stack
do_lt_end:
    ret
do_lt_underflow:
    call print_stack_underflow
    ret
do_lt ENDP

do_gt PROC
    cmp dsp, 2
    jb do_gt_underflow
    call pop_stack
    mov edx, eax
    call pop_stack
    cmp eax, edx
    jle do_gt_false
    mov eax, -1
    call push_stack
    jmp do_gt_end
do_gt_false:
    xor eax, eax
    call push_stack
do_gt_end:
    ret
do_gt_underflow:
    call print_stack_underflow
    ret
do_gt ENDP

do_zero_eq PROC
    cmp dsp, 1
    jb do_zero_eq_underflow
    call pop_stack
    cmp eax, 0
    jne do_zero_eq_false
    mov eax, -1
    call push_stack
    jmp do_zero_eq_end
do_zero_eq_false:
    xor eax, eax
    call push_stack
do_zero_eq_end:
    ret
do_zero_eq_underflow:
    call print_stack_underflow
    ret
do_zero_eq ENDP

do_zero_lt PROC
    cmp dsp, 1
    jb do_zero_lt_underflow
    call pop_stack
    cmp eax, 0
    jge do_zero_lt_false
    mov eax, -1
    call push_stack
    jmp do_zero_lt_end
do_zero_lt_false:
    xor eax, eax
    call push_stack
do_zero_lt_end:
    ret
do_zero_lt_underflow:
    call print_stack_underflow
    ret
do_zero_lt ENDP

do_zero_gt PROC
    cmp dsp, 1
    jb do_zero_gt_underflow
    call pop_stack
    cmp eax, 0
    jle do_zero_gt_false
    mov eax, -1
    call push_stack
    jmp do_zero_gt_end
do_zero_gt_false:
    xor eax, eax
    call push_stack
do_zero_gt_end:
    ret
do_zero_gt_underflow:
    call print_stack_underflow
    ret
do_zero_gt ENDP

do_fetch PROC
    cmp dsp, 1
    jb do_fetch_underflow
    call pop_stack
    mov eax, DWORD PTR [eax]
    call push_stack
do_fetch_end:
    ret
do_fetch_underflow:
    call print_stack_underflow
    ret
do_fetch ENDP

do_store PROC
    cmp dsp, 2
    jb do_store_underflow
    call pop_stack
    mov edx, eax
    call pop_stack
    mov DWORD PTR [edx], eax
do_store_end:
    ret
do_store_underflow:
    call print_stack_underflow
    ret
do_store ENDP

do_constant_word PROC
    mov eax, DWORD PTR [edi+12]
    call push_stack
    ret
do_constant_word ENDP

do_variable_word PROC
    mov eax, DWORD PTR [edi+12]
    call push_stack
    ret
do_variable_word ENDP

do_constant_def PROC
    cmp state, 0
    jne dcd_exit
    cmp dsp, 1
    jb dcd_underflow

find_constant_end:
    mov al, [esi]
    cmp al, ' '
    je skip_spaces_after_constant
    cmp al, 13
    je dcd_exit
    cmp al, 10
    je dcd_exit
    cmp al, 0
    je dcd_exit
    inc esi
    jmp find_constant_end

skip_spaces_after_constant:
    cmp byte ptr [esi], ' '
    jne have_constant_name
    inc esi
    jmp skip_spaces_after_constant

have_constant_name:
    call pop_stack             ; EAX = constant value
    mov edx, eax               ; preserve across header creation

    mov ebx, here
    mov eax, last
    mov DWORD PTR [ebx], eax   ; link
    add ebx, 4
    mov here, ebx

    call copy_token_to_name_here

    mov ebx, here
    mov DWORD PTR [ebx], eax   ; name_ptr
    add ebx, 4
    mov DWORD PTR [ebx], OFFSET do_constant_word
    add ebx, 4
    mov DWORD PTR [ebx], edx   ; value
    add ebx, 4

    mov eax, ebx
    sub eax, 16
    mov last, eax
    mov here, ebx

dcd_exit:
    ret
dcd_underflow:
    call print_stack_underflow
    ret
do_constant_def ENDP

do_variable_def PROC
    cmp state, 0
    jne dvd_exit

find_variable_end:
    mov al, [esi]
    cmp al, ' '
    je skip_spaces_after_variable
    cmp al, 13
    je dvd_exit
    cmp al, 10
    je dvd_exit
    cmp al, 0
    je dvd_exit
    inc esi
    jmp find_variable_end

skip_spaces_after_variable:
    cmp byte ptr [esi], ' '
    jne have_variable_name
    inc esi
    jmp skip_spaces_after_variable

have_variable_name:
    mov ebx, data_here
    mov DWORD PTR [ebx], 0     ; initial value
    mov edx, ebx               ; preserve address
    add ebx, 4
    mov data_here, ebx

    mov ebx, here
    mov eax, last
    mov DWORD PTR [ebx], eax   ; link
    add ebx, 4
    mov here, ebx

    call copy_token_to_name_here

    mov ebx, here
    mov DWORD PTR [ebx], eax   ; name_ptr
    add ebx, 4
    mov DWORD PTR [ebx], OFFSET do_variable_word
    add ebx, 4
    mov DWORD PTR [ebx], edx   ; addr
    add ebx, 4

    mov eax, ebx
    sub eax, 16
    mov last, eax
    mov here, ebx

dvd_exit:
    ret
do_variable_def ENDP

; =========================================================
; STACK / UTILITY WORDS
; =========================================================
do_depth PROC
    mov eax, dsp
    call push_stack
    ret
do_depth ENDP

do_dot PROC
    cmp dsp, 1
    jb do_dot_underflow
    call pop_stack
    call print_number
do_dot_end:
    ret
do_dot_underflow:
    call print_stack_underflow
    ret
do_dot ENDP

do_dup PROC
    cmp dsp, 1
    jb do_dup_underflow
    call pop_stack
    mov edx, eax
    call push_stack
    mov eax, edx
    call push_stack
do_dup_end:
    ret
do_dup_underflow:
    call print_stack_underflow
    ret
do_dup ENDP

do_drop PROC
    cmp dsp, 1
    jb do_drop_underflow
    call pop_stack
do_drop_end:
    ret
do_drop_underflow:
    call print_stack_underflow
    ret
do_drop ENDP

do_dot_s PROC
    call print_stack
    ret
do_dot_s ENDP

do_swap PROC
    cmp dsp, 2
    jb do_swap_underflow
    mov ebx, dsp
    dec ebx
    mov eax, DWORD PTR stack[ebx*4]
    dec ebx
    mov edx, DWORD PTR stack[ebx*4]
    mov DWORD PTR stack[ebx*4], eax
    inc ebx
    mov DWORD PTR stack[ebx*4], edx
do_swap_end:
    ret
do_swap_underflow:
    call print_stack_underflow
    ret
do_swap ENDP

do_over PROC
    cmp dsp, 2
    jb do_over_underflow
    mov ebx, dsp
    sub ebx, 2
    mov eax, DWORD PTR stack[ebx*4]
    call push_stack
do_over_end:
    ret
do_over_underflow:
    call print_stack_underflow
    ret
do_over ENDP

; >r moves the top data-stack value to the return stack.
; Stack effect: ( x -- ) ( R: -- x )
do_to_r PROC
    cmp dsp, 1
    jb do_to_r_underflow
    call pop_stack
    mov ebx, rsp
    mov DWORD PTR return_stack[ebx*4], eax
    inc rsp
do_to_r_end:
    ret
do_to_r_underflow:
    call print_stack_underflow
    ret
do_to_r ENDP

; r> moves the top return-stack value to the data stack.
; Stack effect: ( -- x ) ( R: x -- )
do_r_from PROC
    cmp rsp, 1
    jb do_r_from_underflow
    dec rsp
    mov ebx, rsp
    mov eax, DWORD PTR return_stack[ebx*4]
    call push_stack
do_r_from_end:
    ret
do_r_from_underflow:
    call print_stack_underflow
    ret
do_r_from ENDP

; r@ copies the top return-stack value to the data stack.
; Stack effect: ( -- x ) ( R: x -- x )
do_r_fetch PROC
    cmp rsp, 1
    jb do_r_fetch_underflow
    mov ebx, rsp
    dec ebx
    mov eax, DWORD PTR return_stack[ebx*4]
    call push_stack
do_r_fetch_end:
    ret
do_r_fetch_underflow:
    call print_stack_underflow
    ret
do_r_fetch ENDP

do_clear PROC
    mov dsp, 0
    ret
do_clear ENDP

do_words PROC
    push ebx
    push edi
    push esi

    invoke GetStdHandle, -11
    mov esi, eax
    mov ebx, last

words_loop:
    cmp ebx, 0
    je words_done

    mov edi, [ebx+4]

words_name_loop:
    cmp byte ptr [edi], 0
    je words_name_done
    invoke WriteConsoleA, esi, edi, 1, ADDR bytesWritten, 0
    inc edi
    jmp words_name_loop

words_name_done:
    invoke WriteConsoleA, esi, ADDR space, 1, ADDR bytesWritten, 0
    mov ebx, [ebx]
    jmp words_loop

words_done:
    invoke WriteConsoleA, esi, ADDR crlf, 2, ADDR bytesWritten, 0

    pop esi
    pop edi
    pop ebx
    ret
do_words ENDP

do_quit PROC
    invoke ExitProcess, 0
    ret
do_quit ENDP

; =========================================================
; CONSOLE OUTPUT
; =========================================================
print_prompt PROC
    invoke GetStdHandle, -11
    invoke WriteConsoleA, eax, ADDR prompt, prompt_len, ADDR bytesWritten, 0
    ret
print_prompt ENDP

print_ok PROC
    invoke GetStdHandle, -11
    invoke WriteConsoleA, eax, ADDR ok_msg, ok_len, ADDR bytesWritten, 0
    ret
print_ok ENDP

print_error PROC
    mov error_flag, 1
    invoke GetStdHandle, -11
    invoke WriteConsoleA, eax, ADDR err_msg, err_len, ADDR bytesWritten, 0
    ret
print_error ENDP

print_stack_underflow PROC
    mov error_flag, 1
    invoke GetStdHandle, -11
    invoke WriteConsoleA, eax, ADDR stack_underflow_msg, stack_underflow_len, ADDR bytesWritten, 0
    call do_exit
    ret
print_stack_underflow ENDP

print_division_by_zero PROC
    mov error_flag, 1
    invoke GetStdHandle, -11
    invoke WriteConsoleA, eax, ADDR division_zero_msg, division_zero_len, ADDR bytesWritten, 0
    call do_exit
    ret
print_division_by_zero ENDP

print_space PROC
    invoke GetStdHandle, -11
    invoke WriteConsoleA, eax, ADDR space, 1, ADDR bytesWritten, 0
    ret
print_space ENDP

print_crlf PROC
    invoke GetStdHandle, -11
    invoke WriteConsoleA, eax, ADDR crlf, 2, ADDR bytesWritten, 0
    ret
print_crlf ENDP

print_number PROC
    push eax
    call print_number_no_nl
    pop eax
    call print_crlf
    ret
print_number ENDP

print_number_no_nl PROC
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov edi, OFFSET numBuffer
    add edi, 15
    mov byte ptr [edi], 0

    mov ebx, eax
    cmp eax, 0
    jne pn_check_sign

    dec edi
    mov byte ptr [edi], '0'
    jmp pn_print

pn_check_sign:
    cmp eax, 0
    jge pn_convert
    neg eax

pn_convert:
    mov ecx, 10

pn_loop:
    xor edx, edx
    div ecx
    add dl, '0'
    dec edi
    mov byte ptr [edi], dl
    test eax, eax
    jnz pn_loop

    cmp ebx, 0
    jge pn_print
    dec edi
    mov byte ptr [edi], '-'

pn_print:
    mov esi, edi
    xor ecx, ecx

pn_len_loop:
    cmp byte ptr [esi], 0
    je pn_len_done
    inc esi
    inc ecx
    jmp pn_len_loop

pn_len_done:
    invoke GetStdHandle, -11
    invoke WriteConsoleA, eax, edi, ecx, ADDR bytesWritten, 0

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
print_number_no_nl ENDP

print_stack PROC
    push ebx
    push edi

    invoke GetStdHandle, -11
    invoke WriteConsoleA, eax, ADDR lbracket, 2, ADDR bytesWritten, 0

    mov edi, dsp
    xor ebx, ebx

ps_loop:
    cmp ebx, edi
    jge ps_done

    mov eax, DWORD PTR stack[ebx*4]
    call print_number_no_nl

    inc ebx
    cmp ebx, edi
    jge ps_done

    call print_space
    jmp ps_loop

ps_done:
    invoke GetStdHandle, -11
    invoke WriteConsoleA, eax, ADDR rbracket, 4, ADDR bytesWritten, 0

    pop edi
    pop ebx
    ret
print_stack ENDP

; =========================================================
; CONSOLE INPUT
; =========================================================
to_lower_buffer PROC
    mov esi, OFFSET buffer

tl_loop:
    mov al, [esi]
    cmp al, 0
    je tl_done
    cmp al, 13
    je tl_done
    cmp al, 'A'
    jb tl_next
    cmp al, 'Z'
    ja tl_next
    add byte ptr [esi], 32
tl_next:
    inc esi
    jmp tl_loop

tl_done:
    ret
to_lower_buffer ENDP

read_line PROC
    invoke GetStdHandle, -10
    invoke ReadConsoleA, eax, ADDR buffer, buffer_size, ADDR bytesRead, 0
    call to_lower_buffer
    ret
read_line ENDP

END main
