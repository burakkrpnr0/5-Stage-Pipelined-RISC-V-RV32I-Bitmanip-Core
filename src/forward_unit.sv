`timescale 1 ns / 1 ps
module forward_unit import riscv_pkg::*; (
    input  logic       ex_mem_reg_write_i,
    input  logic       ex_mem_valid_i,
    input  logic [4:0] ex_mem_rd_addr_i,
    input  logic       ex_mem_mem_read_i, 
    
    input  logic       mem_wb_reg_write_i,
    input  logic       mem_wb_valid_i,
    input  logic [4:0] mem_wb_rd_addr_i,
    
    input  logic [4:0] id_ex_rs1_addr_i,
    input  logic [4:0] id_ex_rs2_addr_i,
    
    output logic [1:0] forward_a_o,
    output logic [1:0] forward_b_o
);
    always_comb begin
        forward_a_o = 2'b00;
        forward_b_o = 2'b00;

        if (ex_mem_reg_write_i && !ex_mem_mem_read_i && (ex_mem_rd_addr_i != 0) && (ex_mem_rd_addr_i == id_ex_rs1_addr_i) && ex_mem_valid_i) begin
            forward_a_o = 2'b10;
        end else if (mem_wb_reg_write_i && (mem_wb_rd_addr_i != 0) && (mem_wb_rd_addr_i == id_ex_rs1_addr_i) && mem_wb_valid_i) begin
            forward_a_o = 2'b01; 
        end

        if (ex_mem_reg_write_i && !ex_mem_mem_read_i && (ex_mem_rd_addr_i != 0) && (ex_mem_rd_addr_i == id_ex_rs2_addr_i) && ex_mem_valid_i) begin
            forward_b_o = 2'b10; 
        end else if (mem_wb_reg_write_i && (mem_wb_rd_addr_i != 0) && (mem_wb_rd_addr_i == id_ex_rs2_addr_i) && mem_wb_valid_i) begin
            forward_b_o = 2'b01;
        end
    end
endmodule
