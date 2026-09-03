`timescale 1 ns / 1 ps

package riscv_pkg;

    typedef enum logic [2:0] {
        BYTE   = 3'b000,
        HALF   = 3'b001,
        WORD   = 3'b010,
        BYTE_U = 3'b100, 
        HALF_U = 3'b101  
    } width_e;

    typedef enum logic [1:0] {
        WB_ALU   = 2'b00,
        WB_MEM   = 2'b01,
        WB_PC4   = 2'b10,
        WB_PCIMM = 2'b11
    } wb_sel_e;

    typedef enum logic [3:0] {
        ALU_ADD   = 4'b0000,
        ALU_SUB   = 4'b0001,
        ALU_AND   = 4'b0010,
        ALU_OR    = 4'b0011,
        ALU_XOR   = 4'b0100,
        ALU_SLL   = 4'b0101,
        ALU_SRL   = 4'b0110,
        ALU_SRA   = 4'b0111,
        ALU_SLT   = 4'b1000,
        ALU_SLTU  = 4'b1001,
        ALU_COPY_B= 4'b1010, 
        ALU_CLZ   = 4'b1011, 
        ALU_CTZ   = 4'b1100, 
        ALU_CPOP  = 4'b1101, 
        ALU_NONE  = 4'b1111  
    } alu_op_e;

    typedef enum logic [2:0] {
        BR_BEQ  = 3'b000,
        BR_BNE  = 3'b001,
        BR_BLT  = 3'b100,
        BR_BGE  = 3'b101,
        BR_BLTU = 3'b110,
        BR_BGEU = 3'b111,
        BR_NONE = 3'b010 
    } branch_type_e;

    typedef struct packed {
        logic        valid;
        logic [31:0] addr;
        logic [31:0] data;
        logic        write;
        width_e      width;
    } dmem_req_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] addr;
    } imem_req_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] data;
    } dmem_res_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] data;
    } imem_res_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [31:0] instr;
        logic [4:0]  reg_addr;
        logic [31:0] reg_data;
        logic [31:0] mem_addr;
        logic [31:0] mem_data;
        logic        mem_wrt;
    } commit_t;

endpackage
