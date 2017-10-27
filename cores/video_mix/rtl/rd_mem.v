module rd_mem #(
	parameter DWIDTH = 128,
	parameter PWIDTH =  16,
	parameter DEPTH  = 900 // Resolution 1440x900
) (
	output wire        [7:0] debug,   
	input  wire        [1:0] mode,
	input  wire              pclk,
	input  wire              rst,
	input  wire              hs,
	input  wire              vs,
	input  wire              de,
	output wire        [7:0] ored,
	output wire        [7:0] ogreen,
	output wire        [7:0] oblue,
	output wire              rd_fifo_empty,
	input  wire              memcon_en,
	output wire              memcon_donep,
	input  wire        [1:0] arb_state,

	input  wire              memclk,
	output wire              mcb_rd_en,
	input  wire [DWIDTH-1:0] mcb_rd_data,
	input  wire              mcb_rd_full,
	input  wire              mcb_rd_empty,
	input  wire        [6:0] mcb_rd_count,
	output wire              mcb_cmd_en,
	output wire        [2:0] mcb_cmd_instr,
	output wire        [5:0] mcb_cmd_bl,
	output wire       [29:0] mcb_cmd_byte_addr,
	input  wire              mcb_cmd_empty,
	input  wire              mcb_cmd_full
);

`define RGB
/*
 * This module for 1440x900 Video Output
 */

localparam IDLE          =   3'd0,
           ISSUE         =   3'd1,
           CMD           =   3'd2,
           DATA          =   3'd3,
           WAIT          =   3'd4;

localparam READ          =   3'd3;
localparam BRST_LENGTH   =  45;
localparam BRSTNUM       =   4;
localparam BRST_INTERVAL =   0;

localparam SW_HMD        =  2'd0;
localparam SW_XGA        =  2'd1;
localparam SW_FHD        =  2'd2;

/* -------------- State Machine -------------- */
reg         rd_en;
reg         cmd_en;
reg   [7:0] cntr, brstcnt;
reg  [10:0] linecnt;
reg  [29:0] cmd_byte;

assign mcb_cmd_bl        = (mode == SW_HMD) ? BRST_LENGTH - 1 : 
                           (mode == SW_XGA) ? 64 - 1 :
                           (mode == SW_FHD) ? /* todo */0 : 0;
assign mcb_rd_en         = rd_en;
assign mcb_cmd_en        = cmd_en;
assign mcb_cmd_instr     = READ;
assign mcb_cmd_byte_addr = cmd_byte;

wire  [7:0] flipcnt      = (mode == SW_HMD) ? BRSTNUM : 
                           (mode == SW_XGA) ? 8'd4 :
                           (mode == SW_FHD) ? /* todo */ 0 : 0;
wire [10:0] linedepth    = (mode == SW_HMD) ? DEPTH - 1 : 
                           (mode == SW_XGA) ? 11'd767 :
                           (mode == SW_FHD) ? /* todo */ 0 : 0;
wire  [7:0] brstlim      = (mode == SW_HMD) ? BRST_LENGTH : 
                           (mode == SW_XGA) ? 64 :
                           (mode == SW_FHD) ? /* todo */ 0 : 0;
/* -------------- Read Fifo ------------------ */
reg  [DWIDTH-1:0] sft_pxl;
reg        [12:0] brst_cnt_p;
reg         [2:0] state, cnt8, cnt8a;
reg         [3:0] done;
reg               vs_buf, vs_buff, deb, memcon_done;

wire              fifo_empty, fifo_full;
wire [DWIDTH-1:0] dout;

wire [PWIDTH-1:0] pxl_out    = sft_pxl[PWIDTH-1:0];
wire              fifo_wr_en = (state == DATA) && ~mcb_rd_empty; 
wire              fifo_rd_en = de && cnt8 == 3'd0;
wire              frame1      = brstcnt[1];
wire              frame2      = brstcnt[0];
wire              frame       = (mode == SW_HMD) ? frame1 : 
                                (mode == SW_XGA) ? frame2 :
                                (mode == SW_FHD) ? /* todo */0 : 0;

`ifdef RGB
wire [7:0] llred, llgreen, llblue;
assign ored   = (mode == SW_HMD) ? {pxl_out[ 9: 5], 3'd0} :
                (mode == SW_XGA) ? llred :
                (mode == SW_FHD) ? /* todo */0 : 0;
assign ogreen = (mode == SW_HMD) ? {pxl_out[15:10], 2'd0} :
                (mode == SW_XGA) ? llgreen :
                (mode == SW_FHD) ? /* todo */0 : 0;
assign oblue  = (mode == SW_HMD) ? {pxl_out[ 4: 0], 3'd0} : 
                (mode == SW_XGA) ? llblue :
                (mode == SW_FHD) ? /* todo */0 : 0;
`else
assign ored   = pxl_out[15:8];
assign ogreen = pxl_out[ 7:0];
assign oblue  = 0;
`endif
assign memcon_donep = done > 0 || memcon_done;

/* ------------------------------------------- */

always @ (posedge pclk) 
	if (rst) begin 
		cnt8   <= 3'd0; sft_pxl <= 128'd0; 
		deb    <= 1'b0; cnt8a   <= 3'd0;
	end else begin
		deb   <= de;
		if (de) begin
			if (cnt8 == 3'b111) cnt8 <= 3'd0;
			else cnt8 <= cnt8 + 3'd1;
		end else cnt8 <= 3'd0;
		cnt8a <= cnt8;

		if (deb && cnt8a == 0) sft_pxl <= dout[127:0];
		else sft_pxl <= {16'd0, sft_pxl[DWIDTH-1:16]};
	end

//`define LINE2

always @ (posedge memclk) begin
	if (rst) begin
		state       <= IDLE;   done        <= 1'b0;
		cmd_en      <= 1'b0;   rd_en       <= 1'b0;
		cntr        <= 8'd0;   cmd_byte    <=30'd0;
		brstcnt     <= 8'd0;   memcon_done <= 1'b0;
		brst_cnt_p  <=13'd0;   linecnt     <=11'd0;
	end else begin
		done    <= {done[2:0], memcon_done};
		vs_buf  <= vs; vs_buff <= vs_buf;
		if (~vs_buff) linecnt    <= 0;
		case (state)
			IDLE : begin
				if ({memcon_en, memcon_donep} == 2'b10) state <= ISSUE;
				brstcnt     <= 0;
				brst_cnt_p  <= 0;
				cmd_en      <= 0;
				memcon_done <= 0;
			end
			ISSUE: if (~mcb_cmd_full && arb_state == 2'b00) begin
				cntr     <= 8'd0;
				cmd_en   <= 1'b1;
				state    <=  CMD;
				cmd_byte <= {5'd0, frame, linecnt, brst_cnt_p}; 
			end
			CMD  : begin
				cmd_en <= 1'b0;
				if (mcb_rd_empty == 1'b0 && 
				    mcb_rd_count > 7'h07) begin
					state      <= DATA;
					rd_en      <= 1'b1;
					brstcnt    <= brstcnt + 8'd1;
					if (mode == SW_HMD) begin
						if (brstcnt[0] == 1) brst_cnt_p <= 13'd0;
						else brst_cnt_p <= 13'd720;
					end else begin 
					  if (brstcnt[1:0] == 2'b01)  brst_cnt_p <= 13'd1024;
					end
				end
			end
			DATA : if (~mcb_rd_empty) begin
				if (cntr == brstlim - 1)  begin
					cntr  <= 8'd0;
					rd_en <= 1'b0;
					state <= WAIT;
				end else
					cntr  <= cntr + 8'd1;
			end
			WAIT : begin
				if (brstcnt == flipcnt) begin
					if (linecnt == linedepth) linecnt <= 0;
					else linecnt <= linecnt + 11'd1;
					brstcnt     <= 8'd0;
					memcon_done <= 1'b1;
					state       <= IDLE;
				end else if (cntr > BRST_INTERVAL) state <= ISSUE;
				else cntr <= cntr + 8'd1;
			end
			default : state <= IDLE;
		endcase
	end
end

/* ------------ FIFO instatnce --------------------- */
wire rd_en_f = (mode == SW_HMD) ? fifo_wr_en : 
               (mode == SW_XGA) ? fifo_wr_en && ((brstcnt == 8'd1) || (brstcnt == 8'd2)) :
               (mode == SW_FHD) ? /* todo */0 : 0;

wr_fifo4line rd_fifo (
	.rst    (rst)         ,
	.wr_clk (memclk)      ,
	.rd_clk (pclk)        ,
	.din    (mcb_rd_data) ,
	.wr_en  (rd_en_f)  ,
	.rd_en  (fifo_rd_en)  ,
	.dout   (dout)        ,
	.full   (fifo_full)   ,
	.empty  (fifo_empty)
);

assign rd_fifo_empty = fifo_empty;
assign debug = {fifo_rd_en, mcb_rd_full, mcb_rd_empty, fifo_full, fifo_empty, state};

wire sw = (brstcnt == 8'd2) || (brstcnt == 8'd4);
ll151d inst_ll151d (
	.pclk  (pclk),
	.de    (de),
	.red   (llred),
	.green (llgreen),
	.blue  (llblue),
	.clkmem(memclk),
	.wr_en (fifo_wr_en),
	.idata (mcb_rd_data),
	.sw    (sw),
	.rst   (rst)
);

endmodule
