`define EDGE_FILTER_MACRO

module I2C_Edge_Filter #(
    parameter phase = 8
) (
    input clk,
    input rstn,
    input SDA,
    input SCL,

    output reg [1:0] sda_edge_buf,
    output reg [1:0] scl_edge_buf
);

  /*
  * (1,0) => --__ high to low
  * (0,1) => __-- low to high
  * (1,1), (0,0) => no change
  */

  reg [phase-1 : 0] sda_det;
  reg [phase-1 : 0] scl_det;

  always @(posedge clk, negedge rstn) begin
    if(!rstn)begin
      sda_det  <= {phase{1'bz}};
      scl_det  <= {phase{1'bz}};
      sda_edge_buf   <= 2'b11;
      scl_edge_buf   <= 2'b11;
    end else begin
      sda_det  <= {sda_det[phase-2 : 0], SDA};
      scl_det  <= {scl_det[phase-2 : 0], SCL};
      case (sda_det)
        {phase{1'b1}}: //strong high: 1111_1111
          sda_edge_buf <= {sda_edge_buf[0], 1'b1};
        {phase{1'b0}}: //strong low: 0000_0000
          sda_edge_buf <= {sda_edge_buf[0], 1'b0};
      endcase
      case (scl_det)
        {phase{1'b1}}: //strong high: 1111_1111
          scl_edge_buf <= {scl_edge_buf[0], 1'b1};
        {phase{1'b0}}: //strong low: 0000_0000
          scl_edge_buf <= {scl_edge_buf[0], 1'b0};
      endcase
    end
  end
    
endmodule
