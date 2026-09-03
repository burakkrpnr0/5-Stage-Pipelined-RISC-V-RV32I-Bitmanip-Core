`timescale 1 ns / 1 ps
module riscv_decoder import riscv_pkg::*; (
    input  logic [31:0] instr_i,      
    output logic [4:0]  rs1_addr_o, output logic [4:0] rs2_addr_o, output logic [4:0] rd_addr_o,    
    output logic        reg_write_o, output logic mem_read_o, output logic mem_write_o, output width_e mem_width_o,  
    output alu_op_e     alu_ctrl_o, output logic [1:0] alu_src_b_o, output wb_sel_e wb_sel_o,     
    output logic        branch_o, output logic jump_o, output logic is_jalr_o, output branch_type_e branch_type_o, output logic [31:0] imm_o,
    output logic        is_auipc_o,
    output logic        uses_rs1_o,
    output logic        uses_rs2_o 
);
    logic [2:0] funct3; 
    logic       funct7_5;
    logic       is_bitmanip;

    assign rs1_addr_o = instr_i[19:15]; 
    assign rs2_addr_o = instr_i[24:20]; 
    assign rd_addr_o  = instr_i[11:7];
    assign funct3     = instr_i[14:12]; 
    assign funct7_5   = instr_i[30];
    assign is_bitmanip= (instr_i[31:25] == 7'b0110000);

    always_comb begin
        case(instr_i[6:0])
            7'b0110111, 7'b0010111: imm_o = {instr_i[31:12], 12'b0}; 
            7'b0100011:             imm_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]}; 
            7'b1100011:             imm_o = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0}; 
            7'b1101111:             imm_o = {{12{instr_i[31]}}, instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0}; 
            default:                imm_o = {{20{instr_i[31]}}, instr_i[31:20]}; 
        endcase
    end

    function alu_op_e decode_bitmanip(input logic [4:0] rs2_val);
        case (rs2_val)
            5'b00000: return ALU_CLZ;
            5'b00001: return ALU_CTZ;
            5'b00010: return ALU_CPOP;
            default:  return ALU_SLL; 
        endcase
    endfunction

    always_comb begin
        reg_write_o = 0; mem_read_o = 0; mem_write_o = 0; mem_width_o = WORD;
        alu_ctrl_o = ALU_NONE; alu_src_b_o = 0; wb_sel_o = WB_ALU; branch_o = 0; jump_o = 0; is_jalr_o = 0; branch_type_o = BR_NONE; is_auipc_o = 0;
        
        uses_rs1_o = 1'b1; 
        uses_rs2_o = 1'b1;

        case(instr_i[6:0])
            7'b0110011: begin 
                reg_write_o = 1;
                case(funct3)
                    3'b000: begin
                        if (funct7_5) alu_ctrl_o = ALU_SUB;
                        else alu_ctrl_o = ALU_ADD;
                    end
                    3'b001: begin
                        if (is_bitmanip) alu_ctrl_o = decode_bitmanip(instr_i[24:20]);
                        else alu_ctrl_o = ALU_SLL;
                    end
                    3'b010: alu_ctrl_o = ALU_SLT; 
                    3'b011: alu_ctrl_o = ALU_SLTU; 
                    3'b100: alu_ctrl_o = ALU_XOR; 
                    3'b101: begin
                        if (funct7_5) alu_ctrl_o = ALU_SRA;
                        else alu_ctrl_o = ALU_SRL;
                    end
                    3'b110: alu_ctrl_o = ALU_OR; 
                    3'b111: alu_ctrl_o = ALU_AND; 
                    default: alu_ctrl_o = ALU_NONE;
                endcase
            end
            
            7'b0010011: begin 
                reg_write_o = 1; alu_src_b_o = 1;
                uses_rs2_o = 1'b0;
                case(funct3)
                    3'b000: alu_ctrl_o = ALU_ADD; 
                    3'b001: begin
                        if (is_bitmanip) alu_ctrl_o = decode_bitmanip(instr_i[24:20]);
                        else alu_ctrl_o = ALU_SLL;
                    end
                    3'b010: alu_ctrl_o = ALU_SLT; 
                    3'b011: alu_ctrl_o = ALU_SLTU; 
                    3'b100: alu_ctrl_o = ALU_XOR; 
                    3'b101: begin
                        if (funct7_5) alu_ctrl_o = ALU_SRA;
                        else alu_ctrl_o = ALU_SRL;
                    end
                    3'b110: alu_ctrl_o = ALU_OR; 
                    3'b111: alu_ctrl_o = ALU_AND; 
                    default: alu_ctrl_o = ALU_NONE;
                endcase
            end
            
            7'b0000011: begin 
                reg_write_o = 1; mem_read_o = 1; alu_src_b_o = 1; wb_sel_o = WB_MEM; alu_ctrl_o = ALU_ADD;
                uses_rs2_o = 1'b0;
                case(funct3)
                    3'b000: mem_width_o = BYTE;
                    3'b001: mem_width_o = HALF;
                    3'b100: mem_width_o = BYTE_U; 
                    3'b101: mem_width_o = HALF_U; 
                    default: mem_width_o = WORD;
                endcase
            end
            
            7'b0100011: begin 
                mem_write_o = 1; alu_src_b_o = 1; alu_ctrl_o = ALU_ADD;
                case(funct3)
                    3'b000:  mem_width_o = BYTE;
                    3'b001:  mem_width_o = HALF;
                    default: mem_width_o = WORD;
                endcase
            end
            
            7'b1100011: begin 
                branch_o = 1;
                case(funct3)
                    3'b000: begin alu_ctrl_o = ALU_SUB; branch_type_o = BR_BEQ; end
                    3'b001: begin alu_ctrl_o = ALU_SUB; branch_type_o = BR_BNE; end
                    3'b100: begin alu_ctrl_o = ALU_SLT; branch_type_o = BR_BLT; end
                    3'b101: begin alu_ctrl_o = ALU_SLT; branch_type_o = BR_BGE; end
                    3'b110: begin alu_ctrl_o = ALU_SLTU; branch_type_o = BR_BLTU; end
                    3'b111: begin alu_ctrl_o = ALU_SLTU; branch_type_o = BR_BGEU; end
                    default: alu_ctrl_o = ALU_NONE; 
                endcase
            end
            
            7'b1101111: begin reg_write_o = 1; jump_o = 1; wb_sel_o = WB_PC4; alu_ctrl_o = ALU_NONE; uses_rs1_o = 1'b0; uses_rs2_o = 1'b0; end 
            7'b1100111: begin reg_write_o = 1; jump_o = 1; wb_sel_o = WB_PC4; alu_ctrl_o = ALU_NONE; is_jalr_o = 1; uses_rs2_o = 1'b0; end 
            7'b0110111: begin reg_write_o = 1; alu_src_b_o = 1; alu_ctrl_o = ALU_COPY_B; wb_sel_o = WB_ALU; uses_rs1_o = 1'b0; uses_rs2_o = 1'b0; end 
            7'b0010111: begin reg_write_o = 1; alu_src_b_o = 1; alu_ctrl_o = ALU_ADD; wb_sel_o = WB_PCIMM; is_auipc_o = 1; uses_rs1_o = 1'b0; uses_rs2_o = 1'b0; end 
            
            default: ;
        endcase
    end
endmodule
