//Detect Rise edge
module Counter #(
    parameter WIDTH = 8,
    parameter INIT  = 0
) (
    input clk,
    input rstn,
    input wire [1:0] trigger,

    output reg [WIDTH-1 : 0] cnt
);
    localparam WAITRISE = 1'b0;
    localparam WAITFALL = 1'b1;

    reg state, next_state;
    reg [WIDTH-1 : 0] next_cnt;

    always @(posedge clk) begin
        if(!rstn)begin
            state <= WAITRISE;
            cnt   <= INIT;
        end else begin
            state <= next_state;
            cnt   <= next_cnt;
        end
    end
    //*Mealy Machine
    always @(*) begin
        case ({state   , trigger})
              {WAITRISE,   2'b01} : {next_state, next_cnt} = {WAITFALL, cnt + 1'b1};
              {WAITFALL,   2'b10} : {next_state, next_cnt} = {WAITRISE, cnt};
            default:
                {next_state, next_cnt} = {state   , cnt};
        endcase
    end

endmodule
