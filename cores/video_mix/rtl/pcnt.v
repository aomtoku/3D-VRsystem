module pcnt (
	input  wire        clk,
	input  wire        rst,
	input  wire        hs,
	input  wire        vs,
	input  wire        de,
	output reg  [11:0] hcnt,
	output reg  [11:0] vcnt
);

wire [11:0] hpixels = 12'd1920;

always @ (posedge clk) begin
	if (rst) begin
		hcnt <= 12'd0;
		vcnt <= 12'd0;
	end else begin
		if (de) 
			hcnt <= hcnt + 12'd1;
		else//if (hs)
			hcnt <= 12'd0;

		if (vs)
			vcnt <= 12'd0;
		else if (hcnt == hpixels - 1)
			vcnt <= vcnt + 12'd1;
	end
end



endmodule
