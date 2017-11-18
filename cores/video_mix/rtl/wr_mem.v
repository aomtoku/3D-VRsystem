module wr_mem #(
	parameter DISP_HSTART = 0,
	parameter DISP_VSTART = 0
)(
	output wire   [7:0] debug        ,
	/* Dram Controller pins */
	input  wire         calib_done   ,
	input  wire         mem_rst      ,
	input  wire         cmd_clk      ,
	output reg          cmd_en       ,
	output wire   [2:0] cmd_instr    ,
	output wire   [5:0] cmd_bl       ,
	output wire  [29:0] cmd_byte_addr,
	input  wire         cmd_empty    ,
	input  wire         cmd_full     ,
	output wire         wr_en        ,
	output wire  [15:0] wr_mask      ,
	output wire [127:0] wr_data      ,
	input  wire         wr_full      ,
	input  wire         wr_empty     ,
	input  wire   [6:0] wr_count     ,
	/* User pins */
	input  wire [128:0] idata        ,
	input  wire  [11:0] cline        ,
	input  wire   [1:0] cpxl         ,
	input  wire   [1:0] sel          ,
	output wire         done         ,
	input  wire   [1:0] arb_state    ,
	output wire         wr_fifo_rd_en   ,
	input  wire         wr_probe      , 
	input  wire         rst
);

localparam PWIDTH = 16;
/* ------------------- Parameter -------------------- */
localparam BRST_LEN      = 6'd63;
localparam WRITE_CMD     =  3'd2;
localparam IDLE          = 2'b00,
           WAIT          = 2'b01,
           WRD           = 2'b10,
           CMD           = 2'b11;

localparam DISP_HSTART_BYTE = DISP_HSTART * (PWIDTH/8);
/* ------------------- Reg / Wire -------------------- */ 
reg  [1:0] state;
reg  [6:0] wr_cnt; 
reg [12:0] cmd_b;
reg  [1:0] doneb;
reg [10:0] line;
reg        doner, donebb;

wire       csel      = (sel == 1) ? 0 : 1;
/*
 *  Address Structure : Entire 30bit
 *  5'd0, VideoInput(1bit), V-Line(11bit), H-Pixels(13bit)
 */
reg wr_eng;
reg [29:0] cmd_addr;
reg [11:0] pixels ;
assign cmd_byte_addr = cmd_addr;
assign cmd_instr     = WRITE_CMD;
assign cmd_bl        = BRST_LEN;
assign wr_mask       = 16'd0;
assign wr_data       = idata[127:0];
assign wr_en         = state == WRD && wr_eng;
assign done          = doner;
wire doneg = doner || donebb;

assign wr_fifo_rd_en= wr_eng &&( ~(state == WAIT && idata[128]) || (wr_cnt != 0 && state == WRD));

always @ (posedge cmd_clk) begin
	if (mem_rst) begin
		state     <=  IDLE;  wr_cnt    <=  7'd0;
		line      <= 11'd0; 
		cmd_en    <=  1'd0;  cmd_b     <= 13'd0;
		doneb     <=  1'd0;  donebb    <=  1'd0;
		doner     <=  1'd0;  wr_eng    <=  1'd0;
	end else begin
		if (calib_done) begin
			doneb  <= {doneb[0], donebb};
			donebb <= doner;
			case(state)
				IDLE : begin
					if (wr_probe && ~doneg && wr_empty) begin
						state <= WAIT;
					end
					wr_cnt  <= 7'd0;
					cmd_en  <= 1'b0;
					cmd_b   <= 13'd1024 + DISP_HSTART_BYTE;
					doner   <= 1'b0;
					cmd_addr<= 30'd0;
				end 
				WAIT : begin
					if (idata[128] == 1'b0) begin
						wr_eng <= 1'b1;
					end else begin
						wr_eng <= 1'b0;
						state  <= WRD;
					end
				end
				WRD  : begin
					cmd_en <= 1'b0;
					if (~wr_full && wr_count <= 7'd64) begin
						if (wr_cnt == 7'd64) begin
							state   <= CMD;
							wr_eng  <= 1'b0;
						end else begin
							if (wr_cnt == 7'd2 && idata[128] == 1'b1) begin
								line <= cline[10:0];
								case(cpxl[0])
									1'b0 : cmd_b <= 13'd0 + DISP_HSTART_BYTE;
									1'b1 : cmd_b <= 13'd1024 + DISP_HSTART_BYTE;
								endcase
							end
							wr_cnt  <= wr_cnt + 7'd1;
							wr_eng  <= 1'b1;
						end
					end else wr_eng <= 1'b0;
				end
				CMD  : begin
					wr_cnt        <= 7'd0;
					if (~cmd_full && arb_state == 2'b10 && wr_count == 7'd64) begin
						cmd_en      <= 1'b1;
						cmd_addr    <= {5'd0, csel, line, cmd_b};
						state       <= IDLE;
						doner       <= 1'b1;
					end
				end
				default : state <= IDLE;
			endcase
		end
	end
end

assign debug = {1'b0, rst, wr_full, wr_probe, wr_en, csel, state};

endmodule
