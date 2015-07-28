module ll151d (
	input  wire         pclk,
	input  wire         de,
	output wire   [7:0] red,
	output wire   [7:0] green,
	output wire   [7:0] blue,
	input  wire         clkmem,
	input  wire         wr_en,
	input  wire [127:0] idata,
	input  wire         sw,
	input  wire         rst
);

reg  [127:0] sft_rpxl, sft_lpxl;
reg    [2:0] cnt8, cnt8a;
reg          deb;

wire         l_wr_en, r_wr_en;
wire         l_rd_en, r_rd_en;
wire         lfull, lempty, rfull, rempty;
wire [127:0] lout, rout;
wire  [15:0] rpxl_out    = sft_rpxl[15:0];
wire  [15:0] lpxl_out    = sft_lpxl[15:0];

assign l_wr_en = wr_en && (sw == 1'b0);
assign r_wr_en = wr_en && (sw == 1'b1);
assign l_rd_en = de && cnt8 == 3'd0;
assign r_rd_en = de && cnt8 == 3'd0;

assign red   = (cnt8a[0] == 0) ? {rpxl_out[ 9: 5], 3'd0} : {lpxl_out[ 9: 5], 3'd0};
assign green = (cnt8a[0] == 0) ? {lpxl_out[15:10], 2'd0} : {rpxl_out[15:10], 2'd0};
assign blue  = (cnt8a[0] == 0) ? {rpxl_out[ 4: 0], 3'd0} : {lpxl_out[ 4: 0], 3'd0};

always @ (posedge pclk) 
	if (rst) begin 
		cnt8   <= 3'd0; sft_rpxl <= 128'd0; 
		deb    <= 1'b0; cnt8a   <=   3'd0; sft_lpxl <= 128'd0;
	end else begin
		deb   <= de;
		if (de) begin
			if (cnt8 == 3'b111) cnt8 <= 3'd0;
			else cnt8 <= cnt8 + 3'd1;
		end else cnt8 <= 3'd0;
		cnt8a <= cnt8;

		if (deb && cnt8a == 0) begin
			sft_rpxl <= rout;
			sft_lpxl <= lout;
		end else begin
			sft_rpxl <= {16'd0, sft_rpxl[127:16]};
			sft_lpxl <= {16'd0, sft_lpxl[127:16]};
		end
	end

wr_fifo4line leftfifo (
	.rst    (rst)     ,
	.wr_clk (clkmem)  ,
	.rd_clk (pclk)    ,
	.din    (idata)   ,
	.wr_en  (l_wr_en) ,
	.rd_en  (l_rd_en) ,
	.dout   (lout)    ,
	.full   (lfull)   ,
	.empty  (lempty)
);

wr_fifo4line rightfifo (
	.rst    (rst)     ,
	.wr_clk (clkmem)  ,
	.rd_clk (pclk)    ,
	.din    (idata)   ,
	.wr_en  (r_wr_en) ,
	.rd_en  (r_rd_en) ,
	.dout   (rout)    ,
	.full   (rfull)   ,
	.empty  (rempty)
);

endmodule
