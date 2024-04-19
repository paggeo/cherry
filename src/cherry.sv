`include "param.svh"

module cherry(
  input logic clk_i,
  input logic rst_ni
);
endmodule

logic [XLEN-1:0] pc;

logic [XLEN-1:0] inst_cache [0:4][0:1023];

always_ff @(posedge clk_i or negedge rst_ni) begin
  if(~rst_ni) begin
    pc <= 0;
  end else begin
    pc <= pc + 4;
  end
end

