`timescale 1 ns / 1 ps
module load_store_unit import riscv_pkg::*; (
    input  width_e      ex_mem_mem_width_i,
    input  logic        ex_mem_mem_read_i,
    input  logic [31:0] mem_read_data_i,
    output logic [31:0] mem_read_data_formatted_o
);

    logic [7:0]  load_byte;
    logic [15:0] load_half;

    assign load_byte = mem_read_data_i[7:0];
    assign load_half = mem_read_data_i[15:0];

    always_comb begin
        mem_read_data_formatted_o = mem_read_data_i; 
        
        if (ex_mem_mem_read_i) begin
            unique case (ex_mem_mem_width_i)
                BYTE:    mem_read_data_formatted_o = {{24{load_byte[7]}}, load_byte};
                HALF:    mem_read_data_formatted_o = {{16{load_half[15]}}, load_half}; 
                BYTE_U:  mem_read_data_formatted_o = {24'b0, load_byte};
                HALF_U:  mem_read_data_formatted_o = {16'b0, load_half};
                WORD:    mem_read_data_formatted_o = mem_read_data_i;
                default: mem_read_data_formatted_o = mem_read_data_i;
            endcase
        end
    end
endmodule
