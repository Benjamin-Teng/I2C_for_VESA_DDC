
module EDID_Controll (
    input clk,
    input rstn,
    inout wire SINK_SCL,
    inout wire SINK_SDA,
    inout wire SOURCE_SCL,
    inout wire SOURCE_SDA
);
  localparam [2:0] RESET  = 3'd0;
  localparam [2:0] START  = 3'd1;
  localparam [2:0] S2M    = 3'd2;
  localparam [2:0] M2S    = 3'd3;
  localparam [2:0] ACKW   = 3'd4;
  localparam [2:0] SrPC   = 3'd5; // Start Repeated, Stop, Continue
  localparam [2:0] ACKR   = 3'd6;
  localparam [2:0] OPCODE = 3'd7;


  localparam  CNT_WIDTH = 8;
  localparam  CNT_INIT  = 0;
  localparam  [CNT_WIDTH-1 : 0] DATAFIN = 8;

  reg [2:0] state = RESET;
  reg [2:0] next_state;

  wire [1:0] scl_edge_buf;
  wire [1:0] sda_edge_buf;

  reg sda_en = 1'b1, next_sda_en;  //Default is Master to Slave
  reg scl_en = 1'b1, next_scl_en;
  wire fil_scl, fil_sda; //for filtering SCL, SDA

  wire [CNT_WIDTH-1 : 0] cnt;
  reg cnt_ctrl = 1'b0;

  assign SINK_SCL   = (scl_en) ? 1'bz : SOURCE_SCL;
  assign SOURCE_SCL = (!scl_en) ? 1'bz : SINK_SCL;

  assign SINK_SDA   = (sda_en) ? 1'bz : SOURCE_SDA;
  assign SOURCE_SDA = (!sda_en) ? 1'bz : SINK_SDA;

  assign fil_scl = (scl_en) ? SINK_SCL : SOURCE_SCL;
  assign fil_sda = (sda_en) ? SINK_SDA : SOURCE_SDA;
  //assume now computer transmits signals to monitor
  I2C_Edge_Filter #(
      .phase(4)
  ) I2C_Edge_Filter_inst_sin (
      .clk(clk),
      .rstn(rstn),
      .SCL(fil_scl),
      .SDA(fil_sda),
      .scl_edge_buf(scl_edge_buf),
      .sda_edge_buf(sda_edge_buf)
  );
  Counter #( // For detecting ACKW/NACK when signal transition has come through 1 byte
    .WIDTH (CNT_WIDTH),
    .INIT  (CNT_INIT)
  ) Counter_inst (
    .clk (clk),
    .rstn (cnt_ctrl),
    .trigger (scl_edge_buf), //___--- rise edge
    .cnt  (cnt)
  );


  always @(posedge clk, negedge rstn) begin
    if(!rstn) begin
      state  <= RESET;
      sda_en <= 1'b1;
      scl_en <= 1'b1;
    end else begin
      state  <= next_state;
      sda_en <= next_sda_en;
      scl_en <= next_scl_en;
    end
  end

  /*
  *       {RESET,      master(sink) is ready}
  *       {START,   SCL fall, transit begins}
  *       {OPCODE,     8th bit determine R/W}
  *       {OPCODE,       00 is W and 11 is R}

  *       {S2M,  when 1 byte is transmitted,},
  *       {S2M, state changes to ACK & sink }

  *       {M2S,  when 1 byte is transmitted,},
  *       {M2S,  state changes to ACK & src } 

  *       {ACKW,    ACK, then going to write}
  *       {ACKW,         NACK, state ch to R} 
  *       {ACKR,     ACK, then going to read} 
  *       {ACKR,         NACK, state ch to R} 
  */
  //*Mealy Machine
  always @(*) begin
    case ({state, scl_edge_buf, sda_edge_buf})
          {RESET,        2'b11,        2'b10} : {next_state, next_sda_en, next_scl_en} = {START,  2'b11};
          {START,        2'b10,        2'b00} : {next_state, next_sda_en, next_scl_en} = {OPCODE, 2'b11};
          {OPCODE,       2'b10,        2'b11} : {next_state, next_sda_en, next_scl_en} = (cnt == DATAFIN)?{ACKR, 2'b01}:{state, sda_en, scl_en};
          {OPCODE,       2'b10,        2'b00} : {next_state, next_sda_en, next_scl_en} = (cnt == DATAFIN)?{ACKW, 2'b01}:{state, sda_en, scl_en};
          
          {S2M,          2'b10,        2'b00},
          {S2M,          2'b10,        2'b11} : {next_state, next_sda_en, next_scl_en} = (cnt == DATAFIN)?{ACKR, 2'b11}:{state, sda_en, scl_en};
          
          {M2S,          2'b10,        2'b00},
          {M2S,          2'b10,        2'b11} : {next_state, next_sda_en, next_scl_en} = (cnt == DATAFIN)?{ACKW, 2'b01}:{state, sda_en, scl_en};
          
          {ACKR,         2'b10,        2'b00} : {next_state, next_sda_en, next_scl_en} = {SrPC,   2'b01};//master is receiver
          {ACKR,         2'b10,        2'b11} : {next_state, next_sda_en, next_scl_en} = {RESET,  2'b11};//NACK
          {ACKW,         2'b10,        2'b00} : {next_state, next_sda_en, next_scl_en} = {SrPC,   2'b11};//slave is receiver
          {ACKW,         2'b10,        2'b11} : {next_state, next_sda_en, next_scl_en} = {RESET,  2'b11};//NACK
          
          {SrPC,         2'b11,        2'b10} : {next_state, next_sda_en, next_scl_en} = {START,  2'b11};//SR
          {SrPC,         2'b11,        2'b01} : {next_state, next_sda_en, next_scl_en} = {RESET,  2'b11};//STOP
          {SrPC,         2'b10,        2'b11},
          {SrPC,         2'b10,        2'b00} : {next_state, next_sda_en, next_scl_en} = (sda_en)?{M2S, 2'b11}:{S2M,  2'b01};//Continue, slave release SCL
      default:
            {next_state, next_sda_en, next_scl_en} = {state, sda_en, scl_en};
    endcase
  end
  //*Moore Machine
  always @(*) begin
    case (state)
      OPCODE:  cnt_ctrl = 1'b1;
      S2M:     cnt_ctrl = 1'b1;
      M2S:     cnt_ctrl = 1'b1;
      SrPC:    cnt_ctrl = 1'b1;
      default: cnt_ctrl = 1'b0;
    endcase
  end

endmodule
