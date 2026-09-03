`timescale 1 ns / 1 ps
module branch_unit import riscv_pkg::*; (
    input  branch_type_e branch_type_i,
    input  logic [31:0]  alu_a_i,   
    input  logic [31:0]  alu_b_i,  
    output logic         ex_take_branch_o
);

    logic br_eq, br_lt, br_ltu;

    assign br_eq  = (alu_a_i == alu_b_i);
    assign br_lt  = ($signed(alu_a_i) < $signed(alu_b_i));
    assign br_ltu = (alu_a_i < alu_b_i);

    always_comb begin
        unique case(branch_type_i)
            BR_BEQ:  ex_take_branch_o = br_eq;
            BR_BNE:  ex_take_branch_o = !br_eq;
            BR_BLT:  ex_take_branch_o = br_lt;
            BR_BGE:  ex_take_branch_o = !br_lt;
            BR_BLTU: ex_take_branch_o = br_ltu;
            BR_BGEU: ex_take_branch_o = !br_ltu;
            default: ex_take_branch_o = 1'b0;
        endcase
    end
endmodule
