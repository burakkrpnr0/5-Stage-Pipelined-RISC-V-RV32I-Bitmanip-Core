`timescale 1 ns / 1 ps
module riscv_alu import riscv_pkg::*; (
    input  logic [31:0] alu_in_a_i,
    input  logic [31:0] alu_in_b_i,
    input  alu_op_e     alu_ctrl_i,
    output logic [31:0] alu_result_o
);

    logic signed [31:0] signed_a;
    logic signed [31:0] signed_b;
    
    assign signed_a = signed'(alu_in_a_i);
    assign signed_b = signed'(alu_in_b_i);

    always_comb begin
        alu_result_o = 32'b0;
        
        unique case(alu_ctrl_i)
            ALU_ADD:    alu_result_o = alu_in_a_i + alu_in_b_i;
            ALU_SUB:    alu_result_o = alu_in_a_i - alu_in_b_i;
            ALU_AND:    alu_result_o = alu_in_a_i & alu_in_b_i;
            ALU_OR:     alu_result_o = alu_in_a_i | alu_in_b_i;
            ALU_XOR:    alu_result_o = alu_in_a_i ^ alu_in_b_i;
            ALU_SLL:    alu_result_o = alu_in_a_i << alu_in_b_i[4:0];
            ALU_SRL:    alu_result_o = alu_in_a_i >> alu_in_b_i[4:0];
            ALU_SRA:    alu_result_o = signed_a >>> alu_in_b_i[4:0]; 
            ALU_SLT:    alu_result_o = (signed_a < signed_b) ? 32'b1 : 32'b0; 
            ALU_SLTU:   alu_result_o = (alu_in_a_i < alu_in_b_i) ? 32'b1 : 32'b0;
            ALU_COPY_B: alu_result_o = alu_in_b_i;

            ALU_CLZ: begin 
                alu_result_o = 32;
                for (int i = 31; i >= 0; i--) begin
                    if (alu_in_a_i[i]) begin
                        alu_result_o = 31 - i;
                        break;
                    end
                end
            end
            ALU_CTZ: begin 
                alu_result_o = 32;
                for (int i = 0; i < 32; i++) begin
                    if (alu_in_a_i[i]) begin
                        alu_result_o = i;
                        break;
                    end
                end
            end
            ALU_CPOP: begin 
                alu_result_o = 32'b0;
                for (int i = 0; i < 32; i++) begin
                    if (alu_in_a_i[i]) alu_result_o = alu_result_o + 32'b1;
                end
            end
            default: alu_result_o = 32'b0;
        endcase
    end
endmodule
