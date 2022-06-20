
%macro func_start 0
    push ebp
    mov ebp, esp
%endmacro

%macro func_end 0
    mov esp, ebp
    pop ebp
    ret
%endmacro

%macro modulu 2
    mov eax, %1        
    xor edx, edx             
    mov ebx, %2            
    div ebx       ; edx = %1 mod %2
%endmacro

section	.rodata
    winner_format: db "The Winner is drone: %d", 10, 0
    DroneStructLen: equ 37 ; 8xpox, 8ypos, 8angle, 8speed, 4kills, 1isActive
    DRONE_STRUCT_XPOS_OFFSET: equ 0
    DRONE_STRUCT_YPOS_OFFSET: equ 8
    DRONE_STRUCT_HEADING_OFFSET: equ 16
    DRONE_STRUCT_SPEED_OFFSET: equ 24
    DRONE_STRUCT_KILLS_OFFSET: equ 32
    DRONE_STRUCT_ACTIVE_OFFSET: equ 36
    TARGET_STRUCT_SIZE: equ 17
    TARGET_STRUCT_XPOS_OFFSET: equ 0
    TARGET_STRUCT_YPOS_OFFSET: equ 8
    TARGET_STRUCT_IS_DESTROYED_OFFSET: equ 16


section .data
    curr_step: dd 0
    num_of_drones_left: dd 0
    drones_eliminated_this_round: dd 0

section .bss
    
section .text
    extern Nval
    extern Rval
    extern Kval
    extern Tval
    extern resume
    extern currDrone
    extern DronesArrayPointer
    extern cors
    extern finish_main
    extern printf
    global run_schedueler



    ; N<int> – number of drones
    ; R<int> - number of full scheduler cycles between each elimination
    ; K<int> – how many drone steps between game board printings
    ; T<int> – how many drone steps between target moves randomly
    ; d<float> – maximum distance that allows to destroy a target (at most 20)
    ; seed<int> - seed for initialization of LFSR shift register 

run_schedueler:
    func_start
    mov dword[curr_step], 0
    mov ebx, dword[Nval]
    mov dword[num_of_drones_left], ebx 

    _loop: 
        ;checking if elimination is next
        modulu dword[curr_step], dword[Rval]    ;now edx hold curr_step%R
        cmp edx, 0
        mov dword [drones_eliminated_this_round], 0
        je _eliminate

        ;checking if print is next
        _check_print: 
        modulu dword[curr_step], dword[Kval]    ;now edx hold curr_step%K
        cmp edx, 0
        je _print_board

        _check_move_target:
        modulu dword[curr_step], dword[Tval]    ;now edx hold curr_step%T
        cmp edx, 0
        je _move_target

        _check_drone_alive:
        modulu dword[curr_step], dword[Nval]    ;now edx hold curr_step%R
        mov dword[currDrone], edx           ;saving curr_drone index for later use
        mov ebx, dword[DronesArrayPointer]
        shl edx, 2
        add ebx, edx        ;now ebx points to curr drone :TODO CHECK THIS SHIT
        mov ebx, [ebx]
        cmp byte[ebx + DRONE_STRUCT_ACTIVE_OFFSET], 1
        je _call_drone_cor
        jmp _loop_end


        _eliminate:
            xor ecx, ecx        ; index
            mov esi, 2147483647 ; min KILL VALUE
            xor edx, edx        ; curr min kill drone index


            _eliminate_loop:
                cmp ecx, dword[Nval]        ; while i<N
                je _end_eliminate_loop
                mov eax, [DronesArrayPointer]   ; eax = start of pointer array
                mov edi, ecx
                shl edi, 2
                add eax, edi             ; eax = DronesArrayPointer[ecx]
                ;mov eax, [eax]           ; eax = start of curr drone struct

                cmp byte[eax+DRONE_STRUCT_ACTIVE_OFFSET], byte 0         ;isAlive() ?
                je _continue
                cmp esi, dword[eax+DRONE_STRUCT_KILLS_OFFSET]        ; curr min > ? drone kills
                jb _continue
                mov esi, dword[eax+DRONE_STRUCT_KILLS_OFFSET]         ; curr min = curr drone kills
                mov edx, ecx
                _continue:
                inc ecx
                jmp _eliminate_loop

            _end_eliminate_loop:
                mov eax, [DronesArrayPointer]   ; eax = start of pointer array
                mov edi, edx
                shl edi, 2
                add eax, edi             ; eax = DronesArrayPointer[ecx]
                ;mov eax, [eax]           ; eax = start of curr drone struct
                mov byte[eax+DRONE_STRUCT_ACTIVE_OFFSET], 0         ;loser was eliminated

                dec dword[num_of_drones_left]
                cmp dword[num_of_drones_left], 1
                je finish_game
                ;TODO: print num of winner drone
                ;TODO JUMP EQUALS END GAME (print board, return to main, free all cors)
                inc dword [drones_eliminated_this_round]
                cmp dword [drones_eliminated_this_round], 1
                je _eliminate

            jmp _check_print
        _print_board:
            mov ebx, [cors]                 ; ebx = start of cors array
            add ebx, 16                     ; move pointer of printer coroutine to ebx
            call resume                     ; resume printer
            jmp _check_move_target          ; board was printed
        _move_target:
            mov ebx, [cors]                 ; ebx = start of cors array
            add ebx, 8          ; move target of printer coroutine to ebx
            call resume                     ; resume target
            jmp _check_drone_alive          ; target was moved
        _call_drone_cor:
            ;edx holds i%N
            mov ebx, [cors]                 ; ebx = start of cors array
            add edx, 3                      ;   drones corourtines start at index 3
            shl edx, 3
            add ebx, edx         ; size of cors struct is 8, now ebx holds pointer to curr drone coroutine
            call resume                     ; resume curr drone
        _loop_end:
            inc dword[curr_step]                 ; i++
            jmp _loop
        func_end


finish_game:
    ;find winner
    mov ecx, 0                              ; loop counter
    search_winner_loop:
        mov ebx, [DronesArrayPointer]
        mov edx, ecx
        shl edx, 2
        add ebx, edx
        mov ebx, [ebx]
        cmp byte [ebx+DRONE_STRUCT_ACTIVE_OFFSET], 1
        je end_search_winner_loop
        inc ecx
        jmp search_winner_loop
    ;print winner drone

    end_search_winner_loop:
        ;now ecx is holding the numebr of the winner
        push winner_format
        push ecx
        call printf
        add esp, 8
        jmp finish_main
    ; call main_end

;TODO -> check if func start and func end are needed here, because resume and do resume take care of same things i think

