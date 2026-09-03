`timescale 1 ns / 1 ps
module tb();
   import riscv_pkg::*;

  logic clk;
  logic rstn;
  imem_req_t        imem_req;
  imem_res_t        imem_res;
  dmem_req_t        dmem_req;
  dmem_res_t        dmem_res;
  commit_t          commit;

  riscv_multicycle i_core_model (
    .clk_i       (clk),
    .rstn_i      (rstn),
    
    .imem_req_o  (imem_req),
    .imem_res_i  (imem_res),

    .dmem_req_o  (dmem_req),
    .dmem_res_i   (dmem_res),
    
    .commit_o    (commit) 
  );

  memory 
   #(
      .DMemInitFile("dmem.mem"),
      .IMemInitFile("imem.mem")
   ) i_memory (
      .clk_i        (clk),
      .rstn_i       (rstn),
      .imem_req_i   (imem_req),
      .imem_res_o   (imem_res),
      .dmem_req_i   (dmem_req),
      .dmem_res_o   (dmem_res)
   );

  integer file_pointer;
  initial begin
    file_pointer = $fopen("model.log", "w");
    #4;
    forever begin
      if (commit.valid) begin
        if (commit.reg_addr == 0) begin
          $fwrite(file_pointer, "0x%8h (0x%8h)", commit.pc, commit.instr);
        end else begin
          if (commit.reg_addr > 9) begin
            $fwrite(file_pointer, "0x%8h (0x%8h) x%0d 0x%8h", commit.pc, commit.instr, commit.reg_addr, commit.reg_data);
          end else begin
            $fwrite(file_pointer, "0x%8h (0x%8h) x%0d  0x%8h", commit.pc, commit.instr, commit.reg_addr, commit.reg_data);
          end
        end
        if (commit.mem_wrt == 1) begin
          $fwrite(file_pointer, " mem 0x%8h 0x%8h", commit.mem_addr, commit.mem_data);
        end
        $fwrite(file_pointer, "\n");
        #2;
      end else #1;
    end
  end
  initial
    forever begin
      clk = 0;
      #1;
      clk = 1;
      #1;
    end
  initial begin
    rstn = 0;
    #4;
    rstn = 1;
    #20000;
    $finish;
  end


  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end

endmodule

