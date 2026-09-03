module memory 
   import riscv_pkg::*;
   #(
      parameter  DMemInitFile = "dmem.mem",
      parameter  IMemInitFile = "imem.mem",
      localparam dmem_delay   = 5
   ) (
      input  logic            clk_i,
      input  logic            rstn_i,
      input  imem_req_t       imem_req_i,
      output imem_res_t       imem_res_o,
      input  dmem_req_t       dmem_req_i,
      output dmem_res_t       dmem_res_o
   );

   logic [31:0] imem [0:2048-1];
   logic [31:0] dmem [0:2048-1];
   logic [10:0] imem_req_addr;
   logic [10:0] dmem_req_addr;
   logic [1:0] byte_idx;

   dmem_req_t dmem_req_delay [dmem_delay];
   dmem_req_t dmem_req;
   
   assign dmem_req = dmem_req_delay[0];
   assign imem_req_addr=imem_req_i.addr[12:2];
   assign dmem_req_addr=dmem_req.addr[12:2];



   initial begin
      $readmemh(DMemInitFile, dmem, 0, 2047);
      $readmemh(IMemInitFile, imem, 0, 2047);
      //for(int i=0;i<2048;i++) begin
         //$display("%0t [%h]=%h",$time, i, imem[i]);
      //end
   end


   always_ff @(posedge clk_i) begin
      if(!rstn_i) begin
         foreach(dmem_req_delay[i]) dmem_req_delay[i] <= '0;
         imem_res_o  <= '0;
         dmem_res_o  <= '0;
      end else begin
         if(imem_req_i.valid) begin
            imem_res_o.valid<=1;
            imem_res_o.data <= imem[imem_req_addr];
         end else begin
            imem_res_o <= '0;
         end

         if(dmem_req.valid) begin
            if(dmem_req.write) begin
               dmem_res_o.valid<=1;
               case(dmem_req.width)
                  BYTE: dmem[dmem_req_addr][dmem_req.addr[1:0]*08+:08] <= dmem_req.data[07:0];
                  HALF: dmem[dmem_req_addr][dmem_req.addr[  1]*16+:16] <= dmem_req.data[15:0];
                  WORD: dmem[dmem_req_addr]                            <= dmem_req.data[31:0];
                  default: begin /* invalid case */ end 
               endcase
            end else begin
               dmem_res_o.valid<=1;
               case(dmem_req.width)
                  BYTE: dmem_res_o.data <= {{24{1'b0}}, dmem[dmem_req_addr][dmem_req.addr[1:0]*08+:08]};
                  HALF: dmem_res_o.data <= {{16{1'b0}}, dmem[dmem_req_addr][dmem_req.addr[  1]*16+:16]};
                  WORD: dmem_res_o.data <= dmem[dmem_req_addr];
                  default: begin /* invalid case */ end 
               endcase
            end 
         end else begin
            dmem_res_o <= '0;
         end

         for(int i=0; i<dmem_delay-1; i++) begin
            dmem_req_delay[i] <= dmem_req_delay[i+1];
         end
         dmem_req_delay[dmem_delay-1] <= dmem_req_i;
      end
   end

endmodule


