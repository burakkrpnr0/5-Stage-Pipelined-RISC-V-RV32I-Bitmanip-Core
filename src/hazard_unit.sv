`timescale 1 ns / 1 ps
module hazard_unit import riscv_pkg::*; (
    input  logic       id_ex_mem_read_i,
    input  logic       id_ex_valid_i,
    input  logic [4:0] id_ex_rd_addr_i,
    input  logic [4:0] id_rs1_addr_i,
    input  logic [4:0] id_rs2_addr_i,
    input  logic       id_uses_rs1_i,
    input  logic       id_uses_rs2_i,
    input  logic       id_ex_jump_i,
    input  logic       ex_take_branch_i,
    input  logic       mem_stall_i, 
    
    output logic       stall_pipeline_o, 
    output logic       flush_pipeline_o, 
    output logic       load_use_stall_o  
);
    logic data_hazard;
    logic control_hazard;

    assign data_hazard = id_ex_mem_read_i && id_ex_valid_i && (id_ex_rd_addr_i != 0) && 
                         ((id_uses_rs1_i && (id_ex_rd_addr_i == id_rs1_addr_i)) || 
                          (id_uses_rs2_i && (id_ex_rd_addr_i == id_rs2_addr_i)));

    assign control_hazard = (id_ex_valid_i && id_ex_jump_i) || (id_ex_valid_i && ex_take_branch_i);

    assign stall_pipeline_o = mem_stall_i;
    assign flush_pipeline_o = control_hazard && !mem_stall_i;
    assign load_use_stall_o = data_hazard && !mem_stall_i;

endmodule
