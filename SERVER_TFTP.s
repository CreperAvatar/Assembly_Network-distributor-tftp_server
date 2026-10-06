.section .data
 sockaddr_in_STAGE1:
    .hword 2
    .hword 0x4500
    .word 0
    .skip 8
sockaddr_dest:
    .hword 2
    .hword 0
    .word 0
    .skip 8
sockaddr_in_STAGE2:
    .hword 2
    .hword 0
    .word 0
    .skip 8
  file_name: .ascii "memtest"
  msg: .ascii "Nazov suboru ziskany; STATE: FILENAME OBTAINED \n"
  new_line: .ascii "\n"
  src_addr_len: .word 16
  interface_name: .asciz "eth0"
  text_tsize: .asciz "tsize"
  text_blksize: .asciz "blksize"
  text_error_message: .asciz "Expected file was not found. ERROR:1"
  ThisFile: .asciz "SERVER_TFTP"
  Path_ThisFile: .asciz "/home/pico/assembly/tftpSERVER/"
.section .bss
  recv_buffer: .skip 512
  recv_filename: .skip 128
  src_addr: .skip 16
  ifreq: .skip 32
  recv_buffer_metadata: .skip 120
  tftp_opt_acknowladgement_tsize: .skip 20
  tftp_opt_acknowladgement_blksize: .skip 14
  tftp_opt_acknowladgement_ts_blk: .skip 30
  tftp_opt_ack_datablock: .skip 4
  tftp_error_filenotfound: .skip 41
  syscall_open_FD: .skip 4
  filename_st_size_binary: .skip 4
  filename_st_size_ascii: .skip 10
  extract_digit_binary: .skip 10
  data_block: .skip 512
  data_send_packet: .skip 1027
  debug_1: .skip 32
.section .text
.global _start
_start:
mov r9, #0
PORT_69_LISTENING:
  mov r0, r6
  mov r7, #6
  SVC #0

  //Create socket
  mov r0, #2
  mov r1, #2
  mov r2, #0
  mov r7, #281
  SVC #0

  mov r6, r0

  //Bind socket
  mov r0, r6
  ldr r1, =sockaddr_in_STAGE1
  mov r2, #16
  mov r7, #282
  SVC #0

GET_IP_ADDRESS:
    INICIALIZATION:
      ldr r1, =ifreq
      ldr r2, =interface_name
      mov r3, #5
    LOOP_IP_GET:
        ldrb r5, [r2], #1
        strb r5, [r1], #1
        subs r3, r3, #1
        cmp r3, #0
        bne LOOP_IP_GET
    IP_SYSCALL:
        mov r0, r6
        mov r1, #0x8915
        ldr r2, =ifreq
        mov r7, #54
        SVC #0


LISTEN_LOOP:
  mov r0, r6
  cmp r9, #0
  moveq r0, r6
  cmp r9, #2
  moveq r0, r8
  ldr r1, =recv_buffer
  mov r2, #512
  mov r3, #0
  ldr r4, =src_addr
  ldr r5, =src_addr_len
  mov r7, #292
  SVC #0
  mov r2, r0
  add r12, r12, #1


FILL_IP_SOCKADDR_DEST:
  ldr r4, =src_addr
  ldr r3, =sockaddr_dest
  ldr r0, [r4, #4]
  str r0, [r3, #4]
FILL_PORT_SOCKADDR_DEST:
  ldrh r0, [r4, #2]
  strh r0, [r3, #2]

FILENAME_PROCESSING:
  ldrh r3, [r1]
  cmp r3, #0x0100
  beq GET_FILENAME
  cmp r3, #0x0400
  beq SEND_DATA
  b SEND_DATA
  bne EXIT
  GET_FILENAME:
    mov r5, #2
    ldr r1, =recv_buffer
    ldr r4, =recv_filename
    add r4, r4, #31 //Place for tftp path string
    GET_FILENAME_LOOP:
      ldrb r3, [r1, r5]
      cmp r3, #0x00
      beq NT_TO_POSIX_PATH_CONVERT
      strb r3, [r4], #1
      add r5, r5, #1
      B GET_FILENAME_LOOP



    NT_TO_POSIX_PATH_CONVERT:
      mov r0, #0
      mov r1, #0x2F
      mov r3, #0
      mov r7, #31
      ldr r4, =recv_filename
      sub r5, r5, #2
      NT_TO_POSIX_PATH_DO:
        cmp r0, r5
        beq ADD_TFTP_PATH
        ldrb r3, [r4, r7]

        cmp r3, #0x5c //We are looking for "\" char
        beq REPLACE_BACKSLASH
        add r0, r0, #1
        b NT_TO_POSIX_PATH_DO
        REPLACE_BACKSLASH:
          strb r1, [r4, r7] //Replace backslash with normal slash
          add r0, r0, #1
          b NT_TO_POSIX_PATH_DO

        ADD_TFTP_PATH:

          ldr r0, =Path_ThisFile
          ldr r1, =recv_filename
          mov r4, #0
          ADD_TFTP_PATH_DO:
            ldrb r3, [r0, r4]
            cmp r3, #0x00
            beq TSIZE_BLKSIZE_COMBINED
            strb r3, [r1, r4]
            add r4, r4, #1
            b ADD_TFTP_PATH_DO





TSIZE_BLKSIZE_COMBINED:
  add r5, r5, #3 //1
  sub r2, r2, r5
  cmp r2, #14
  beq OPEN_FILE
  bhi BLKSIZE_OR_COMBINED
  BLKSIZE_OR_COMBINED:
    cmp r2, #26
    beq CONSTRUCT_TS_BLK_COMBINED
    blo TFTP_OPT_ACK_BLKSIZE

  CONSTRUCT_TS_BLK_COMBINED:
    mov r9, #1
    bl OPEN_FILE
    mov r10, #20
    ldr r0, =tftp_opt_acknowladgement_ts_blk
    ldr r2, =text_tsize
    mov r3, #0
    mov r4, #2
    mov r5, #0
    mov r1, #0x0600
    strh r1, [r0]
    TSIZE_NAME_BUFFER_FILL2:
      ldrb r5, [r2, r3]
      cmp r5, #0x00
      beq SKIP_TNBF2
      strb r5, [r0, r4]
      add r3, r3, #1
      add r4, r4, #1
      b TSIZE_NAME_BUFFER_FILL2
    SKIP_TNBF2:
      ldr r3, =filename_st_size_ascii
      mov r1, #0
      mov r2, #0
      LOAD_ASCII_TO_BUFFER2:
        add r4, r4, #1
        ldrb r2, [r3, r1]
        cmp r2, #0
        beq TS_BLK_COMBINED_CONTINUE
        strb r2, [r0, r4]
        add r1, r1, #1
        add r10, r10, #1
        b LOAD_ASCII_TO_BUFFER2
  TS_BLK_COMBINED_CONTINUE:
    mov r1, #0
    add r4, r4, #1
    strb r1, [r0, r4]
    ldr r2, =text_blksize
    mov r3, #0
    BLKSIZE_NAME_BUFFER_FILL2:
      ldrb r5, [r2, r3]
      cmp r5, #0x00
      beq SKIP_BNBF2
      strb r5, [r0, r4]
      add r3, r3, #1
      add r4, r4, #1
      b BLKSIZE_NAME_BUFFER_FILL2
      SKIP_BNBF2:
        mov r2, #0x3135
        add r4, r4, #1
        strh r2, [r0, r4]
        add r4, r4, #2
        mov r2, #0x32
        strb r2, [r0, r4]


    add r10, r10, #1
    mov r9, #2
    bl SEND_FRAME_TOAT
    mov r0, r8
    ldr r1, =tftp_opt_acknowladgement_ts_blk
    mov r2, r10
    mov r3, #0
    ldr r4, =sockaddr_dest
    mov r5, #16
    mov r7, #290
    SVC #0
    mov r9, #2
    b LISTEN_LOOP


OPEN_FILE:
  mov r0, #1
  ldr r1, =recv_filename
  mov r2, #50
  mov r7, #4
  SVC #0
  ldr r0, =recv_filename
  mov r1, #0
  mov r2, #0
  mov r7, #5
  SVC #0

  cmp r0, #-2
  beq TFTP_ERROR_FILENOTFOUND
  b OPEN_CONTINUE
TFTP_ERROR_FILENOTFOUND:
  mov r9, #1
  bl SEND_FRAME_TOAT
  mov r9, #0
  mov r0, #0
  mov r1, #0
  mov r2, #0
  mov r3, #0
  ldr r0, =tftp_error_filenotfound
  mov r1, #0x0500
  strh r1, [r0]
  mov r1, #0x0100
  strh r1, [r0, #2]
  add r0, r0, #4
  ldr r1, =text_error_message
  FILL_TEF_MSG:
    ldrb r2, [r1], #1
    cmp r2, #0x00
    beq SENDto_TFTP_ERROR_FILENOTFOUND
    strb r2, [r0], #1
    b FILL_TEF_MSG

    SENDto_TFTP_ERROR_FILENOTFOUND:
      mov r1, #0
      strb r1, [r0]
      mov r0, r8
      ldr r1, =tftp_error_filenotfound
      mov r2, #41
      mov r3, #0
      ldr r4, =sockaddr_dest
      mov r5, #16
      mov r7, #290
      SVC #0

    mov r0, #0
    ldr r1, =recv_filename
    mov r3, #128
    mov r2, #0
    NULL_RECV_FILENAME:
      cmp r3, #0
      beq CLOSE_SOCKET
      strb r0, [r1, r2]
      sub r3, r3, #1
      add r2, r2, #1
      b NULL_RECV_FILENAME
    CLOSE_SOCKET:
      mov r0, r8
      mov r7, #6
      SVC #0
      b LISTEN_LOOP

  OPEN_CONTINUE:  //OC
  ldr r2, =syscall_open_FD
  mov r1, r0
  str r1, [r2]

  ldr r1, =recv_buffer_metadata
  mov r7, #108
  SVC #0

  ldr r2, =filename_st_size_binary
  ldr r0, [r1, #20]
  str r0, [r2]


  ldr r1, =filename_st_size_binary
  ldr r0, =extract_digit_binary
  ldr r2, [r1]
  mov r1, #10
  mov r3, #0
  EXT_DIG_BIN:
    cmp r2, #1
    bhs DO_EDB
    b ADD_ASCII_SUFIX
    DO_EDB:
      UDIV r3, r2, r1
      MLS r4, r3, r1, r2
      strb r4, [r0], #1
      mov r2, r3
      b EXT_DIG_BIN

    ADD_ASCII_SUFIX:
      ldr r0, =extract_digit_binary
      ldr r2, =filename_st_size_ascii
      mov r1, #10
      mov r4, #0
      FIND_START_DATA:
        ldrb r3, [r0, r1]
        cmp r3, #0
        subeq r1, r1, #1
        beq FIND_START_DATA
        ADD:
          cmp r1, #0 //1
          beq WRITE_LAST
            ldrb r3, [r0, r1] //7
            add r3, r3, #0x30 //"7"
            strb r3, [r2, r4] //"7"
            sub r1, r1, #1 //(2-1)=1
            add r4, r4, #1 //(0+1)=1
            b ADD
          WRITE_LAST:
            ldrb r3, [r0, r1]
            add r3, r3, #0x30
            strb r3, [r2, r4]
            mov r3, #0
            add r4, r4, #1
            strb r3, [r2, r4]

            cmp r9, #1
            beq DO_BXLR_RETURN_CHECK


TFTP_OPT_ACK_TSIZE:
  mov r10, #8
  ldr r0, =tftp_opt_acknowladgement_tsize
  mov r2, #0x0600
  mov r3, #0
  mov r4, #2
  strh r2, [r0]
  ldr r2, =text_tsize
  TSIZE_NAME_BUFFER_FILL:
    ldrb r5, [r2, r3]
    cmp r5, #0x00
    beq SKIP_TNBF
    strb r5, [r0, r4]
    add r3, r3, #1
    add r4, r4, #1
    b TSIZE_NAME_BUFFER_FILL
    SKIP_TNBF:
      ldr r3, =filename_st_size_ascii
      mov r1, #0
      mov r2, #0
      LOAD_ASCII_TO_BUFFER:
        add r4, r4, #1
        ldrb r2, [r3, r1]
        cmp r2, #0
        beq SEND_FRAME_TOAT
        strb r2, [r0, r4]
        add r1, r1, #1
        add r10, r10, #1
        b LOAD_ASCII_TO_BUFFER

      SEND_FRAME_TOAT:

        //Create socket
        mov r0, #2
        mov r1, #2
        mov r2, #0
        mov r7, #281
        SVC #0
        mov r8, r0

        //Fill structure
        mov r0, #40000
        add r1, r0, r12
        ldr r2, =sockaddr_in_STAGE2
        strh r1, [r2, #2]
        ldr r3, =ifreq
        ldr r1, [r3, #20]
        str r1, [r2, #4]

        //Bind to socket
        mov r0, r8
        ldr r1, =sockaddr_in_STAGE2
        mov r2, #16
        mov r7, #282
        SVC #0

        cmp r9, #1
        beq DO_BXLR_RETURN_CHECK
        bhi DO_BXLR_RETURN_CHECK
        bne SENDto_OACK_TSIZE
        DO_BXLR_RETURN_CHECK:
          bx lr

        SENDto_OACK_TSIZE:
          add r10, r10, #1
          mov r0, r8
          ldr r1, =tftp_opt_acknowladgement_tsize
          mov r2, r10
          mov r3, #0
          ldr r4, =sockaddr_dest
          mov r5, #16
          mov r7, #290
          SVC #0

          add r9, r9, #1
          b LISTEN_LOOP


TFTP_OPT_ACK_BLKSIZE:
  mov r9, #1
  bl OPEN_FILE

  ldr r0, =tftp_opt_acknowladgement_blksize
  mov r2, #0x0600
  mov r3, #0
  mov r4, #2
  strh r2, [r0]
  ldr r2, =text_blksize
  BLKSIZE_NAME_BUFFER_FILL:
    ldrb r5, [r2, r3]
    cmp r5, #0x00
    beq SKIP_BNBF
    strb r5, [r0, r4]
    add r3, r3, #1
    add r4, r4, #1
    b BLKSIZE_NAME_BUFFER_FILL
    SKIP_BNBF:
      mov r2, #0x3135
      add r4, r4, #1
      strh r2, [r0, r4]
      add r4, r4, #2
      mov r2, #0x32
      strb r2, [r0, r4]


      SENDto_OACK_BLKSIZE:
        mov r9, #2
        mov r0, r8
        mov r7, #6
        SVC #0
        bl SEND_FRAME_TOAT
        mov r0, r8
        ldr r1, =tftp_opt_acknowladgement_blksize
        mov r2, #14
        mov r3, #0
        ldr r4, =sockaddr_dest
        mov r5, #16
        mov r7, #290
        SVC #0

        mov r9, #2

        b LISTEN_LOOP


SEND_DATA:
  INITIAL_HEADER:
    ldr r0, =data_send_packet
    mov r1, #0x0300
    strh r1, [r0]
    mov r10, #0
    mov r10, #0x01
    strb r10, [r0, #3]
    ldr r9, =filename_st_size_binary
    ldr r9, [r9]
    mov r12, #0
    b DATA_LOAD
  ADD_BLOCK_COUNT:
    mov r10, #0
    add r12, r12, #0x01
    strb r12, [r0, #2]
    strb r10, [r0, #3]
    b DATA_LOAD
  LOOP_HEADER:
    ldr r0, =data_send_packet
    mov r1, #0x0300
    strh r1, [r0]
    cmp r10, #0xFF
    beq ADD_BLOCK_COUNT
    add r10, r10, #0x01
    strb r10, [r0, #3]

    DATA_LOAD:
      ldr r3, =syscall_open_FD
      ldr r4, [r3]

     mov r5, #0
    cmp r9, #512
    ble READ_L_512
    bhs READ_G_512
      READ_L_512:
        mov r0, r4  //read A.K.A PROSTE TO FUNGUJE SEM SA NEDIVAJ
        ldr r1, =data_block
        mov r2, r9
        mov r7, #3
        SVC #0
        mov r5, #1
        b PACKAGING
      READ_G_512:
        mov r0, r4
        ldr r1, =data_block
        mov r2, #512
        mov r7, #3
        SVC #0
        sub r9, r9, #512
        b PACKAGING

  PACKAGING:
    ldr r0, =data_send_packet
    add r0, r0, #4
    mov r6, #512
    GET_BYTES_DATA:
      cmp r6, #0
      beq SKIP_GBD
      ldrb r2, [r1], #1
      strb r2, [r0], #1
      sub r6, r6, #1
      b GET_BYTES_DATA
  SKIP_GBD:
    mov r6, r5
    mov r0, r8
    ldr r1, =data_send_packet
    cmp r5, #0
    moveq r2, #516
    addhi r9, r9, #4
    movhi r2, r9
    mov r3, #0
    ldr r4, =sockaddr_dest
    mov r5, #16
    mov r7, #290
    SVC #0

    CHECK_ACK_DATABLOCK:
      cmp r6, #1
      beq EXIT
      mov r0, r8
      ldr r1, =tftp_opt_ack_datablock
      mov r2, #4
      mov r3, #0
      mov r4, #0
      mov r5, #0
      mov r7, #292
      SVC #0
      ldr r0, =data_send_packet
      ldrh r4, [r0, #2]
      ldrh r2, [r1, #2]
      cmp r2, r4
      bne SKIP_GBD

    b LOOP_HEADER
EXIT:
  ldr r0, =ThisFile
  mov r1, #0
  mov r2, #0
  mov r7, #11
  SVC #0

  mov r0, r9
  mov r7, #1
  SVC #0
