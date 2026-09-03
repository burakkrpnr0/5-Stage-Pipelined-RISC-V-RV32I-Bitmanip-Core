`timescale 1 ns / 1 ps

/* verilator lint_off UNUSED */
/* verilator lint_off UNDRIVEN */
/* verilator lint_off SYNCASYNCNET */
/* verilator lint_off CASEINCOMPLETE */

module riscv_multicycle import riscv_pkg::*; (
    input  logic clk_i, input logic rstn_i,
    output imem_req_t imem_req_o, input imem_res_t imem_res_i,
    output dmem_req_t dmem_req_o, input dmem_res_t dmem_res_i,
    output commit_t commit_o
);
    localparam logic [31:0] RESET_VECTOR = 32'h8000_0000;

    logic stall_pipeline, flush_pipeline, load_use_stall;
    logic [31:0] pc_reg, next_pc, pc_sent;
    logic ignore_next_imem;
    
    logic [31:0] if_id_pc, if_id_instr; logic if_id_valid;

    logic [4:0]  id_rs1_addr, id_rs2_addr, id_rd_addr;
    logic        id_reg_write, id_mem_read, id_mem_write, id_branch, id_jump, id_is_jalr, id_is_auipc;
    width_e      id_mem_width;
    alu_op_e     id_alu_ctrl; 
    branch_type_e id_branch_type;
    logic [1:0]  id_alu_src_b;
    wb_sel_e     id_wb_sel;
    logic [31:0] id_imm, id_rs1_data, id_rs2_data;
    logic [31:0] reg_file [0:31];
    logic [31:0] wb_write_data;
    logic        id_uses_rs1, id_uses_rs2;

    logic [31:0] id_ex_pc, id_ex_rs1_data, id_ex_rs2_data, id_ex_imm, id_ex_instr;
    logic [4:0]  id_ex_rs1_addr, id_ex_rs2_addr, id_ex_rd_addr;
    logic        id_ex_reg_write, id_ex_mem_read, id_ex_mem_write, id_ex_branch, id_ex_jump, id_ex_is_jalr, id_ex_valid, id_ex_is_auipc;
    width_e      id_ex_mem_width; 
    alu_op_e     id_ex_alu_ctrl; 
    branch_type_e id_ex_branch_type;
    logic [1:0]  id_ex_alu_src_b;
    wb_sel_e     id_ex_wb_sel;

    logic [31:0] ex_alu_a, ex_alu_b, ex_alu_res;
    logic        ex_take_branch;
    logic [31:0] ex_branch_target, ex_jalr_target;
    logic        ex_redirect; 
    logic [1:0]  forward_a, forward_b; logic [31:0] forwarded_rs2, forwarded_rs1;

    logic [31:0] ex_mem_pc, ex_mem_rs2_data, ex_mem_alu_res, ex_mem_instr;
    logic [4:0]  ex_mem_rd_addr;
    logic        ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write, ex_mem_valid;
    width_e      ex_mem_mem_width; 
    wb_sel_e     ex_mem_wb_sel;

    logic [31:0] mem_read_data_formatted;

    logic [31:0] mem_wb_pc, mem_wb_alu_res, mem_wb_mem_data, mem_wb_instr, mem_wb_wdata;
    logic [4:0]  mem_wb_rd_addr;
    logic        mem_wb_reg_write, mem_wb_valid, mem_wb_mem_write;
    wb_sel_e     mem_wb_wb_sel;

    logic is_mem_op;
    assign is_mem_op = ex_mem_valid && (ex_mem_mem_read || ex_mem_mem_write);
    
    logic mem_busy;
    assign mem_busy = is_mem_op && !dmem_res_i.valid;

    hazard_unit u_hazard (
        .id_ex_mem_read_i(id_ex_mem_read),
        .id_ex_valid_i(id_ex_valid),
        .id_ex_rd_addr_i(id_ex_rd_addr),
        .id_rs1_addr_i(id_rs1_addr),
        .id_rs2_addr_i(id_rs2_addr),
        .id_uses_rs1_i(id_uses_rs1),
        .id_uses_rs2_i(id_uses_rs2),
        .id_ex_jump_i(id_ex_jump),
        .ex_take_branch_i(ex_take_branch),
        .mem_stall_i(mem_busy), 
        .stall_pipeline_o(stall_pipeline),
        .flush_pipeline_o(flush_pipeline),
        .load_use_stall_o(load_use_stall)
    );

    forward_unit u_forward (
        .ex_mem_reg_write_i(ex_mem_reg_write),
        .ex_mem_valid_i(ex_mem_valid),
        .ex_mem_rd_addr_i(ex_mem_rd_addr),
        .ex_mem_mem_read_i(ex_mem_mem_read),
        .mem_wb_reg_write_i(mem_wb_reg_write),
        .mem_wb_valid_i(mem_wb_valid),
        .mem_wb_rd_addr_i(mem_wb_rd_addr),
        .id_ex_rs1_addr_i(id_ex_rs1_addr),
        .id_ex_rs2_addr_i(id_ex_rs2_addr),
        .forward_a_o(forward_a),
        .forward_b_o(forward_b)
    );

    branch_unit u_branch (
        .branch_type_i(id_ex_branch_type),
        .alu_a_i(forwarded_rs1), 
        .alu_b_i(forwarded_rs2), 
        .ex_take_branch_o(ex_take_branch)
    );

    load_store_unit u_lsu (
        .ex_mem_mem_width_i(ex_mem_mem_width),
        .ex_mem_mem_read_i(ex_mem_mem_read),
        .mem_read_data_i(dmem_res_i.data), 
        .mem_read_data_formatted_o(mem_read_data_formatted)
    );

    logic dmem_req_sent;
    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            dmem_req_sent <= 1'b0;
        end else begin
            if (is_mem_op && !dmem_req_sent) dmem_req_sent <= 1'b1;
            else if (!stall_pipeline) dmem_req_sent <= 1'b0;
        end
    end

    dmem_req_t dmem_req_local;
    assign dmem_req_local.valid = is_mem_op && !dmem_req_sent; 
    assign dmem_req_local.write = ex_mem_mem_write;
    
    assign dmem_req_local.width = (ex_mem_mem_width == BYTE_U) ? BYTE :
                                  (ex_mem_mem_width == HALF_U) ? HALF : 
                                  ex_mem_mem_width;
                                  
    assign dmem_req_local.addr  = ex_mem_alu_res;
    assign dmem_req_local.data  = ex_mem_rs2_data; 
    assign dmem_req_o = dmem_req_local;

    imem_req_t imem_req_local;
    assign imem_req_local.valid = 1'b1;
    assign imem_req_local.addr  = pc_reg;
    assign imem_req_o = imem_req_local;

    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            pc_reg <= RESET_VECTOR;
            pc_sent <= RESET_VECTOR;
        end else if (!stall_pipeline) begin 
            pc_reg <= next_pc;
            pc_sent <= pc_reg; 
        end
    end

    logic [31:0] saved_instr, saved_pc;
    logic saved_valid, has_saved;
    always_ff @(posedge clk_i) begin
        if (!rstn_i || flush_pipeline) has_saved <= 0;
        else if ((stall_pipeline || load_use_stall) && !has_saved) begin
            saved_instr <= imem_res_i.data; saved_pc <= pc_sent; saved_valid <= imem_res_i.valid; has_saved <= 1;
        end else if (!stall_pipeline && !load_use_stall) has_saved <= 0;
    end

    always_ff @(posedge clk_i) begin
        if (!rstn_i) ignore_next_imem <= 0;
        else if (ex_redirect && !stall_pipeline) ignore_next_imem <= 1;
        else if (!stall_pipeline) ignore_next_imem <= 0;
    end

    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            if_id_pc <= 0; if_id_instr <= 0; if_id_valid <= 0;
        end else if (flush_pipeline || ignore_next_imem) begin 
            if_id_valid <= 0; 
        end else if (!stall_pipeline && !load_use_stall) begin
            if_id_pc <= has_saved ? saved_pc : pc_sent;
            if_id_instr <= has_saved ? saved_instr : imem_res_i.data;
            if_id_valid <= has_saved ? saved_valid : imem_res_i.valid;
        end
    end

    riscv_decoder u_dec (
        .instr_i(if_id_instr), .rs1_addr_o(id_rs1_addr), .rs2_addr_o(id_rs2_addr), 
        .rd_addr_o(id_rd_addr), .reg_write_o(id_reg_write), .mem_read_o(id_mem_read), 
        .mem_write_o(id_mem_write), .mem_width_o(id_mem_width), .alu_ctrl_o(id_alu_ctrl), 
        .alu_src_b_o(id_alu_src_b), .wb_sel_o(id_wb_sel), .branch_o(id_branch), 
        .jump_o(id_jump), .is_jalr_o(id_is_jalr), .branch_type_o(id_branch_type), 
        .imm_o(id_imm), .is_auipc_o(id_is_auipc),
        .uses_rs1_o(id_uses_rs1), .uses_rs2_o(id_uses_rs2)
    );
    
    always_comb begin
        id_rs1_data = (id_rs1_addr == 0) ? 32'b0 : (mem_wb_reg_write && mem_wb_valid && mem_wb_rd_addr == id_rs1_addr) ? wb_write_data : reg_file[id_rs1_addr];
        id_rs2_data = (id_rs2_addr == 0) ? 32'b0 : (mem_wb_reg_write && mem_wb_valid && mem_wb_rd_addr == id_rs2_addr) ? wb_write_data : reg_file[id_rs2_addr];
    end
    
    always_ff @(posedge clk_i) begin
        if (!rstn_i || flush_pipeline || (load_use_stall && !stall_pipeline)) id_ex_valid <= 0;
        else if (!stall_pipeline) begin
            id_ex_pc <= if_id_pc; id_ex_rs1_data <= id_rs1_data; id_ex_rs2_data <= id_rs2_data; id_ex_imm <= id_imm; id_ex_rs1_addr <= id_rs1_addr; id_ex_rs2_addr <= id_rs2_addr; id_ex_rd_addr <= id_rd_addr; id_ex_reg_write <= id_reg_write; id_ex_mem_read <= id_mem_read; id_ex_mem_write <= id_mem_write; id_ex_branch <= id_branch; id_ex_jump <= id_jump; id_ex_is_jalr <= id_is_jalr; id_ex_branch_type <= id_branch_type; id_ex_mem_width <= id_mem_width; id_ex_alu_ctrl <= id_alu_ctrl; id_ex_alu_src_b <= id_alu_src_b; id_ex_wb_sel <= id_wb_sel; id_ex_instr <= if_id_instr; id_ex_is_auipc <= id_is_auipc; id_ex_valid <= if_id_valid;
        end
    end

    always_comb begin
        unique case (forward_a)
            2'b10: forwarded_rs1 = ex_mem_alu_res;
            2'b01: forwarded_rs1 = wb_write_data;
            default: forwarded_rs1 = id_ex_rs1_data;
        endcase

        unique case (forward_b)
            2'b10: forwarded_rs2 = ex_mem_alu_res;
            2'b01: forwarded_rs2 = wb_write_data;
            default: forwarded_rs2 = id_ex_rs2_data;
        endcase
    end

    assign ex_alu_a = id_ex_is_auipc ? id_ex_pc : forwarded_rs1;
    assign ex_alu_b = (id_ex_alu_src_b == 2'b01) ? id_ex_imm : forwarded_rs2;
    
    riscv_alu u_alu (.alu_in_a_i(ex_alu_a), .alu_in_b_i(ex_alu_b), .alu_ctrl_i(id_ex_alu_ctrl), .alu_result_o(ex_alu_res));
    
    assign ex_branch_target = id_ex_pc + id_ex_imm; 
    assign ex_jalr_target = (forwarded_rs1 + id_ex_imm) & ~32'b1; 
    assign ex_redirect = (id_ex_valid && id_ex_jump) || (id_ex_valid && ex_take_branch);
    
    always_comb begin
        if (ex_redirect) begin
            if (id_ex_is_jalr) next_pc = ex_jalr_target;
            else               next_pc = ex_branch_target;
        end else begin
            next_pc = pc_reg + 4;
        end
    end
    
    always_ff @(posedge clk_i) begin
        if (!rstn_i) ex_mem_valid <= 0;
        else if (!stall_pipeline) begin
            ex_mem_pc <= id_ex_pc; ex_mem_rs2_data <= forwarded_rs2; ex_mem_rd_addr <= id_ex_rd_addr; ex_mem_reg_write <= id_ex_reg_write; ex_mem_mem_read <= id_ex_mem_read; ex_mem_mem_write <= id_ex_mem_write; ex_mem_mem_width <= id_ex_mem_width; ex_mem_wb_sel <= id_ex_wb_sel; ex_mem_instr <= id_ex_instr; ex_mem_valid <= id_ex_valid;
            ex_mem_alu_res <= ex_alu_res;
        end
    end

    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            mem_wb_valid <= 0;
        end else begin
            if (mem_wb_valid && mem_wb_reg_write && mem_wb_rd_addr != 0) reg_file[mem_wb_rd_addr] <= wb_write_data;
            
            if (stall_pipeline) mem_wb_valid <= 0; 
            else begin
                mem_wb_pc <= ex_mem_pc; mem_wb_alu_res <= ex_mem_alu_res; mem_wb_mem_data <= mem_read_data_formatted; mem_wb_rd_addr <= ex_mem_rd_addr; mem_wb_reg_write <= ex_mem_reg_write; mem_wb_mem_write <= ex_mem_mem_write; mem_wb_wb_sel <= ex_mem_wb_sel; mem_wb_instr <= ex_mem_instr; mem_wb_valid <= ex_mem_valid; mem_wb_wdata <= ex_mem_rs2_data;
            end
        end
    end
    
    always_comb begin
        unique case (mem_wb_wb_sel)
            WB_ALU:   wb_write_data = mem_wb_alu_res;
            WB_MEM:   wb_write_data = mem_wb_mem_data;
            WB_PC4:   wb_write_data = mem_wb_pc + 4;
            WB_PCIMM: wb_write_data = mem_wb_alu_res; 
            default:  wb_write_data = mem_wb_alu_res;
        endcase
    end
    
    commit_t commit_local;
    assign commit_local.valid = mem_wb_valid; 
    assign commit_local.pc = mem_wb_pc; 
    assign commit_local.instr = mem_wb_instr; 
    assign commit_local.reg_addr = (mem_wb_reg_write) ? mem_wb_rd_addr : 5'b0; 
    assign commit_local.reg_data = wb_write_data; 
    assign commit_local.mem_addr = mem_wb_alu_res; 
    assign commit_local.mem_data = mem_wb_wdata; 
    assign commit_local.mem_wrt = mem_wb_mem_write;
    assign commit_o = commit_local;

endmodule
