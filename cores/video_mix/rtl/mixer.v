module mixer #(
	parameter C3_P0_MASK_SIZE           =                16,
	parameter C3_P0_DATA_PORT_SIZE      =               128,
	parameter DEBUG_EN                  =                 0,       
	parameter C3_MEMCLK_PERIOD          =              2500,       
	parameter C3_CALIB_SOFT_IP          =            "TRUE",       
	parameter C3_SIMULATION             =           "FALSE",       
	parameter C3_HW_TESTING             =           "FALSE",       
	parameter C3_RST_ACT_LOW            =                 0,       
	parameter C3_INPUT_CLK_TYPE         =    "SINGLE_ENDED",       
	parameter C3_MEM_ADDR_ORDER         = "ROW_BANK_COLUMN",       
	parameter C3_NUM_DQ_PINS            =                16,       
	parameter C3_MEM_ADDR_WIDTH         =                13,       
	parameter C3_MEM_BANKADDR_WIDTH     =                 3        
)(
	/* Input Port 0 */
	input  wire       pclk0,
	input  wire       hs0,
	input  wire       vs0,
	input  wire       de0,
	input  wire [7:0] ir0,
	input  wire [7:0] ig0,
	input  wire [7:0] ib0,
    /* Input Port 1 */
	input  wire       pclk1,
	input  wire       hs1,
	input  wire       vs1,
	input  wire       de1,
	input  wire [7:0] ir1,
	input  wire [7:0] ig1,
	input  wire [7:0] ib1,
	/* Output port for Ethernet */
	input  wire [1:0] mode,
	input  wire       opclk,
	input  wire       oserdes_rst,
	input  wire       ohs,
	input  wire       ovs,
	input  wire       ode,
	output wire [7:0] ored,
	output wire [7:0] ogreen,
	output wire [7:0] oblue,

	/* DRAM controller */
	inout  [C3_NUM_DQ_PINS-1:0]        mcb3_dram_dq,
	output [C3_MEM_ADDR_WIDTH-1:0]     mcb3_dram_a,
	output [C3_MEM_BANKADDR_WIDTH-1:0] mcb3_dram_ba,
	output                             mcb3_dram_ras_n,
	output                             mcb3_dram_cas_n,
	output                             mcb3_dram_we_n,
	output                             mcb3_dram_odt,
	output                             mcb3_dram_cke,
	output                             mcb3_dram_dm,
	inout                              mcb3_dram_udqs,
	inout                              mcb3_dram_udqs_n,
	inout                              mcb3_rzq,
	inout                              mcb3_zio,
	output                             mcb3_dram_udm,
	input                              c3_sys_rst_n,
	inout                              mcb3_dram_dqs,
	inout                              mcb3_dram_dqs_n,
	output                             mcb3_dram_ck,
	output                             mcb3_dram_ck_n,
	/* System pins */
	output wire [7:0] debug,
	input wire  [1:0] sw,
	input wire        bsw,
	input wire  rst, 
	input wire  sysclk
);
`define RGB
`define WXGA
`define REG
/* -------------- Parameters / CLK configuration --------------- */
defparam inst_DCM0.CLK_FEEDBACK          =                 "1X";
defparam inst_DCM0.CLKDV_DIVIDE          =                    3;
defparam inst_DCM0.CLKFX_DIVIDE          =                    2;
defparam inst_DCM0.CLKFX_MULTIPLY        =                    8; 
defparam inst_DCM0.CLKIN_DIVIDE_BY_2     =              "FALSE"; 
defparam inst_DCM0.CLKOUT_PHASE_SHIFT    =               "NONE";
defparam inst_DCM0.DESKEW_ADJUST         = "SYSTEM_SYNCHRONOUS";
defparam inst_DCM0.DFS_FREQUENCY_MODE    =                "LOW";
defparam inst_DCM0.DLL_FREQUENCY_MODE    =                "LOW";
defparam inst_DCM0.DSS_MODE              =               "NONE";
defparam inst_DCM0.DUTY_CYCLE_CORRECTION =               "TRUE";
defparam inst_DCM0.PHASE_SHIFT           =                    0;
defparam inst_DCM0.STARTUP_WAIT          =              "FALSE"; 

localparam MCB_FLIP   =                8;
localparam WIDTH      =             1920;
localparam DEPTH      =             1080;
localparam DCNT       = WIDTH / MCB_FLIP;
localparam COLOR_MODE =          "YCBCR"; // "YCBCR" or "RGB"

localparam SEL_NO     =             2'd0,
           SEL_PORT0  =             2'd1,
           SEL_PORT1  =             2'd2;

localparam ARB_IDLE   =             2'd0,
           ARB_READ   =             2'd1,
           ARB_WRITE  =             2'd2,
           ARB_DAME   =             2'd3;

localparam READ_READY =             2'd0,
           READ_REQ   =             2'd1,
           READ_DONE  =             2'd2;
/* ---------------------- Wire / Reg ------------------------ */
reg                             resetinr, migen;
reg                      [15:0] powoncntm;

wire                            user_CLKDVi, c3_clk0, MClkFB, Mclk0;
wire                            mcb_clkfx_in, clk200outx, DcmLock, clkdv;
wire                            c3_calib_done, c3_rst0;
wire                            clkmem = c3_clk0;

wire                            p0_cmd_en       , wr_cmd_en   , rd_cmd_en;
wire                      [2:0] p0_cmd_instr    , wr_cmd_instr, rd_cmd_instr;
wire                      [5:0] p0_cmd_bl       , wr_cmd_bl   , rd_cmd_bl;
wire                     [29:0] p0_cmd_byte_addr, wr_cmd_addr , rd_cmd_addr;
wire                            p0_cmd_empty ;   
wire                            p0_cmd_full  ;  
wire                            p0_wr_en     ;  
wire      [C3_P0_MASK_SIZE-1:0] p0_wr_mask; 
wire [C3_P0_DATA_PORT_SIZE-1:0] p0_wr_data ,    p0_rd_data; 
wire                            p0_wr_full ,    p0_rd_full;
wire                            p0_wr_empty,    p0_rd_empty;
wire                      [6:0] p0_wr_count,    p0_rd_count;
wire                            p0_wr_underrun, p0_rd_overflow;
wire                            p0_wr_error,    p0_rd_error;

BUFG instmcbc (.I(Mclk0),.O(MClkFB));

DCM inst_DCM0 (
	.CLK0    (Mclk0)       ,
	.CLK2X   (clk200outx)  ,
	.LOCKED  (DcmLock)     ,
	.CLKFB   (MClkFB)      ,
	.CLKIN   (sysclk)      ,
	.DSSEN   (1'b0)        ,
	.CLKDV   (clkdv)       ,
	.CLKFX   (mcb_clkfx_in),
	.PSCLK   (1'b0)        ,
	.PSEN    (1'b0)        ,
	.PSINCDEC(1'b0)        ,
	.RST     (1'b0)
);

/* ---------- Reset Generation on Power on ------------ */
always @ (posedge sysclk) begin
	if (DcmLock == 1'b0) begin
		resetinr  <=  1'b1;
		powoncntm <= 16'd0;
		migen     <=  1'b0;
	end else begin
`ifdef SIMULATION
		if (powoncntm != 16'h1F)
`else
		if (powoncntm != 16'hFFFF)
`endif
			powoncntm <= powoncntm + 16'd1;
		else begin
			resetinr <= 1'b0;
			migen    <= 1'b1;
		end
	end
end

mymcb #(
	.C3_P0_MASK_SIZE(C3_P0_MASK_SIZE),
	.C3_P0_DATA_PORT_SIZE(C3_P0_DATA_PORT_SIZE),
`ifdef SIMULATION
	.DEBUG_EN(0),
	.C3_SIMULATION("TRUE"),
`else
	.DEBUG_EN(0),
	.C3_SIMULATION("FALSE"),
`endif
	.C3_MEMCLK_PERIOD(2500),
	.C3_CALIB_SOFT_IP("TRUE"),
	.C3_RST_ACT_LOW(0),
	.C3_INPUT_CLK_TYPE("SINGLE_ENDED"),
	.C3_MEM_ADDR_ORDER("ROW_BANK_COLUMN"),
	.C3_NUM_DQ_PINS(16),
	.C3_MEM_ADDR_WIDTH(13),
	.C3_MEM_BANKADDR_WIDTH(3)
) inst_frameb (
	/* DRAM pins */
	.mcb3_dram_dq       (mcb3_dram_dq),
	.mcb3_dram_a        (mcb3_dram_a),
	.mcb3_dram_ba       (mcb3_dram_ba),
	.mcb3_dram_ras_n    (mcb3_dram_ras_n),
	.mcb3_dram_cas_n    (mcb3_dram_cas_n),
	.mcb3_dram_we_n     (mcb3_dram_we_n),
	.mcb3_dram_odt      (mcb3_dram_odt),
	.mcb3_dram_cke      (mcb3_dram_cke),
	.mcb3_dram_dm       (mcb3_dram_dm),
	.mcb3_dram_udqs     (mcb3_dram_udqs),
	.mcb3_dram_udqs_n   (mcb3_dram_udqs_n),
	.mcb3_rzq           (mcb3_rzq),
	.mcb3_zio           (mcb3_zio),
	.mcb3_dram_udm      (mcb3_dram_udm),
	.c3_sys_clk         (mcb_clkfx_in),
	.c3_sys_rst_n       (c3_sys_rst_n),
	.c3_calib_done      (c3_calib_done),
	.c3_clk0            (c3_clk0),
	.c3_rst0            (c3_rst0),
	.mcb3_dram_dqs      (mcb3_dram_dqs),
	.mcb3_dram_dqs_n    (mcb3_dram_dqs_n),
	.mcb3_dram_ck       (mcb3_dram_ck),
	.mcb3_dram_ck_n     (mcb3_dram_ck_n),
	/* User pins */
	.c3_p0_cmd_clk      (clkmem),
	.c3_p0_cmd_en       (p0_cmd_en),
	.c3_p0_cmd_instr    (p0_cmd_instr),
	.c3_p0_cmd_bl       (p0_cmd_bl),
	.c3_p0_cmd_byte_addr(p0_cmd_byte_addr),
	.c3_p0_cmd_empty    (p0_cmd_empty),
	.c3_p0_cmd_full     (p0_cmd_full),
	.c3_p0_wr_clk       (clkmem),
	.c3_p0_wr_en        (p0_wr_en),
	.c3_p0_wr_mask      (p0_wr_mask),
	.c3_p0_wr_data      (p0_wr_data),
	.c3_p0_wr_full      (p0_wr_full),
	.c3_p0_wr_empty     (p0_wr_empty),
	.c3_p0_wr_count     (p0_wr_count),
	.c3_p0_wr_underrun  (p0_wr_underrun),
	.c3_p0_wr_error     (p0_wr_error),
	.c3_p0_rd_clk       (clkmem),
	.c3_p0_rd_en        (p0_rd_en),
	.c3_p0_rd_data      (p0_rd_data),
	.c3_p0_rd_full      (p0_rd_full),
	.c3_p0_rd_empty     (p0_rd_empty),
	.c3_p0_rd_count     (p0_rd_count),
	.c3_p0_rd_overflow  (p0_rd_overflow),
	.c3_p0_rd_error     (p0_rd_error)
);

reg  frame_en, ovsf;
`ifndef SIMULATION
wire vrst = ~frame_en || resetinr || oserdes_rst;
always @ (posedge opclk) 
	if (rst) begin
		frame_en <= 1'd0;
	end else begin
		ovsf <= ovs;
		if ({ovs,ovsf} == 2'b10) frame_en <= 1'd1;
	end
`else
wire vrst = ~frame_en || resetinr;
`endif

/* ---------- Port 0 (Camera0, Camera1, Disp0, Disp1) ----------- */
reg    [1:0] arb_state, read_state, darv;
reg    [7:0] shiftcnt0, shiftcnt1;
reg  [127:0] tmp0, tmp1;

wire  [11:0] hcnt0, vcnt0, hcnt1, vcnt1;
wire [128:0] wrp0_dout, wrp1_dout;
wire         done, memcon_done;

wire         memcon_en    = read_state == READ_REQ;
wire   [1:0] sel          = darv;
`ifdef RGB
wire  [15:0] wrp0_din     = {ig0[7:2], ir0[7:3], ib0[7:3]};
wire  [15:0] wrp1_din     = {ig1[7:2], ir1[7:3], ib1[7:3]};
`else
wire  [15:0] wrp0_din     = {ir0, ig0};
wire  [15:0] wrp1_din     = {ir1, ig1};
`endif
wire         wr_fifo_en0  = de0 && (hcnt0[2:0] == 3'b111) && hcnt0[10] == 1'b0; 
wire         wr_fifo_en1  = de1 && (hcnt1[2:0] == 3'b111) && hcnt1[10] == 1'b0;
wire [128:0] fin0         = (hcnt0[2:0] == 3'b111) ? {1'b1, wrp0_din, tmp0[127:16]} : 129'd0;
wire [128:0] fin1         = (hcnt1[2:0] == 3'b111) ? {1'b1, wrp1_din, tmp1[127:16]} : 129'd0;

reg trig0, trig1;
always @ (posedge pclk0) begin
	if (vrst) begin
		trig0 <= 1'd0;
	end else begin
		if (hcnt0[10] == 1'b0 && hcnt0[8:1] == 8'b11111111)
			trig0 <= 1'b1;
		else 
			trig0 <= 1'b0;
	end
end

always @ (posedge pclk1) begin
	if (vrst) begin
		trig1 <= 1'd0;
	end else begin
		if (hcnt1[10] == 1'b0 && hcnt1[8:1] == 8'b11111111)
			trig1 <= 1'b1;
		else 
			trig1 <= 1'b0;
	end
end

reg          tr0, tr1, trr0,trr1;
wire [128:0] dout         = (sel == SEL_PORT0) ? wrp0_dout :
                            (sel == SEL_PORT1) ? wrp1_dout : 0;
wire         rd_fifo_en0  = (sel == SEL_PORT0) && wr_fifo_rd_en;
wire         rd_fifo_en1  = (sel == SEL_PORT1) && wr_fifo_rd_en;
wire         write_timing = ((sel == SEL_PORT0 && shiftcnt0 != 8'd0) || 
                             (sel == SEL_PORT1 && shiftcnt1 != 8'd0));

assign  p0_cmd_en         = (arb_state[1] == 0) ? rd_cmd_en    : wr_cmd_en    ;    
assign  p0_cmd_instr      = (arb_state[1] == 0) ? rd_cmd_instr : wr_cmd_instr ;
assign  p0_cmd_bl         = (arb_state[1] == 0) ? rd_cmd_bl    : wr_cmd_bl    ;
assign  p0_cmd_byte_addr  = (arb_state[1] == 0) ? rd_cmd_addr  : wr_cmd_addr  ;

reg de0r0, de0r1, de0r2, de0r3, de0r4;
reg de1r0, de1r1, de1r2, de1r3, de1r4;

reg dummy_en0, dummy_en1;
always @ (posedge pclk0)
	if (vrst) dummy_en0 <= 1'b0;
	else begin
        if (hcnt0 >=  12'd1025 && hcnt0 <=  12'd1028)
			dummy_en0 <= 1'b1;
        else if (hcnt0 >= 12'd513 && hcnt0 <= 12'd516)
			dummy_en0 <= 1'b1;
		else 
			dummy_en0 <= 1'b0;
	end

always @ (posedge pclk1)
	if (vrst) dummy_en1 <= 1'b0;
	else begin
        if (hcnt1 >=  12'd1025 && hcnt1 <=  12'd1028)
			dummy_en1 <= 1'b1;
        else if (hcnt1 >= 12'd513 && hcnt1 <= 12'd516)
			dummy_en1 <= 1'b1;
		else 
			dummy_en1 <= 1'b0;
	end

always @ (posedge pclk0) begin
	if (vrst) tmp0 <= 0;
	else if (de0) tmp0 <= {wrp0_din, tmp0[127:16]};
	de0r0 <= de0; de0r1 <= de0r0; de0r2 <= de0r1; de0r3 <= de0r2; de0r4 <= de0r3;
end
always @ (posedge pclk1) begin
	if (vrst) tmp1 <= 0;
	else if (de1) tmp1 <= {wrp1_din, tmp1[127:16]};
	de1r0 <= de1; de1r1 <= de1r0; de1r2 <= de1r1; de1r3 <= de1r2; de1r4 <= de1r3;
end
always @ (posedge opclk)
	if (vrst) begin
		read_state <= READ_READY;
	end else begin
		case (read_state) 
			READ_READY : if (rd_fifo_empty) read_state <= READ_REQ;
			READ_REQ   : if (memcon_done)   read_state <= READ_DONE;
			READ_DONE  : read_state <= READ_READY;
			default    : read_state <= READ_READY;
		endcase
	end


wire t0 = {tr0, trr0} == 2'b01;
wire t1 = {tr1, trr1} == 2'b01;


reg testpr, perr, full;
// Arbiter
always @ (posedge clkmem) begin
	if (vrst) begin
		darv      <= 2'd0; arb_state <= 2'd0;
		shiftcnt0 <= 8'd0; shiftcnt1 <= 8'd0;
		trr0      <= 1'd0; tr0       <= 1'd0;
		trr1      <= 1'd0; tr1       <= 1'd0;
		testpr    <= 1'd0; perr      <= 1'd0;
		//full      <= 1'd0;
	end else begin
		tr0 <= trig0; trr0 <= tr0;
		tr1 <= trig1; trr1 <= tr1;
	
		if (~(t0 && sel == SEL_PORT0 && done)) begin
			if (t0) shiftcnt0 <= shiftcnt0 + 8'd1;
			else if (sel == SEL_PORT0 && done) shiftcnt0 <= shiftcnt0 - 8'd1;
		end
		if (~(t1 && sel == SEL_PORT1 && done)) begin
			if (t1) shiftcnt1 <= shiftcnt1 + 8'd1;
			else if (sel == SEL_PORT1 && done) shiftcnt1 <= shiftcnt1 - 8'd1;
		end
		case (darv)
			SEL_NO   : begin
				if (shiftcnt1 > shiftcnt0) darv <= SEL_PORT1;
				else if (shiftcnt0 != 8'd0)    darv <= SEL_PORT0;
				else if (shiftcnt1 != 8'd0)    darv <= SEL_PORT1;
			end
			SEL_PORT0: if (done) darv <= SEL_NO;
			SEL_PORT1: if (done) darv <= SEL_NO;
			default darv <= SEL_NO;
		endcase
		arb_state <= arb_state + 1;
		if (shiftcnt0[7] || shiftcnt1[7])
			testpr <= 1;
		if (p0_rd_overflow || p0_wr_underrun)
			perr  <= 1;
		/*if (lfull0||lfull1)
			full <= 1;*/
	end
	
end

//wire [142:0] linefd0, linefd1;
wire [255:0] linefd0, linefd1;
wire [ 1:0] pxl0  = linefd0[13:12];
wire [11:0] line0 = linefd0[11:0]; 
wire [ 1:0] pxl1  = linefd1[13:12];
wire [11:0] line1 = linefd1[11:0]; 
wire        lfull0, lempty0, lfull1, lempty1;
assign wrp0_dout = linefd0[142:14];
assign wrp1_dout = linefd1[142:14];

wire [1:0] xpos0 = hcnt0[10:9]; 
wire [1:0] xpos1 = hcnt1[10:9];

line_fifo inst_lfifo0 ( // 24bit x 1024 {12'hcnt, 12'vcnt}
	.rst   (vrst|bsw)       ,
	.wr_clk(pclk0)      ,
	.rd_clk(clkmem)     ,  
	.din   ({113'd0, fin0, xpos0, vcnt0})  ,
	.wr_en (wr_fifo_en0||dummy_en0),
	.rd_en (rd_fifo_en0),
	.dout  (linefd0)    ,
	.full  (lfull0)     ,
	.empty (lempty0)
);

line_fifo inst_lfifo1 (
	.rst   (vrst|bsw)       ,
	.wr_clk(pclk1)      ,
	.rd_clk(clkmem)     ,  
	.din   ({113'd0, fin1, xpos1, vcnt1}),
	.wr_en (wr_fifo_en1||dummy_en1),
	.rd_en (rd_fifo_en1),
	.dout  (linefd1)    ,
	.full  (lfull1)     ,
	.empty (lempty1)
);


wire  [11:0] linecnt  = (sel == SEL_PORT0) ? line0  : line1;
wire  [ 1:0] pxlcnt   = (sel == SEL_PORT0) ? pxl0   : pxl1; 

pcnt inst_pcnt0 (
	.clk (pclk0),
	.rst (vrst) ,
	.hs  (hs0)  ,
	.vs  (vs0)  ,
	.de  (de0)  ,
	.hcnt(hcnt0),
	.vcnt(vcnt0)
);

pcnt inst_pcnt1 (
	.clk  (pclk1),
	.rst  (vrst) ,
	.hs   (hs1)  ,
	.vs   (vs1)  ,
	.de   (de1)  ,
	.hcnt (hcnt1),
	.vcnt (vcnt1)
);
wire [7:0]debug1;

wr_mem inst_wrp0 (
	.debug        (debug1)       ,
	/* Dram Controller pins */ 
	.calib_done   (c3_calib_done),
	.cmd_clk      (clkmem)       ,
	.cmd_en       (wr_cmd_en)    ,
	.cmd_instr    (wr_cmd_instr) ,
	.cmd_bl       (wr_cmd_bl)    ,
	.cmd_byte_addr(wr_cmd_addr)  ,
	.cmd_empty    (p0_cmd_empty) ,
	.cmd_full     (p0_cmd_full)  ,
	.wr_en        (p0_wr_en)     ,
	.wr_mask      (p0_wr_mask)   ,
	.wr_data      (p0_wr_data)   ,
	.wr_full      (p0_wr_full)   ,
	.wr_empty     (p0_wr_empty)  ,
	.wr_count     (p0_wr_count)  ,
	/* User pins */
	.sel          (sel)          ,
	.cline        (linecnt)      ,
	.wr_fifo_rd_en(wr_fifo_rd_en),
	.cpxl         (pxlcnt)       ,
	.idata        (dout)         ,
	.done         (done)         ,
	.arb_state    (arb_state)    ,
	.wr_probe     (write_timing) ,
	.rst          (vrst) 
);


/* --------------------- Port 1 (Display) -------------------- */
wire [7:0]debug2;
rd_mem inst_rdmem (
	.debug            (debug2)             ,
	.mode             (mode)               ,
	.pclk             (opclk)              ,
	.rst              (vrst|~c3_calib_done),
	.hs               (ohs)                ,
	.vs               (ovs)                ,
	.de               (ode)                ,
	.ored             (ored)               ,
	.ogreen           (ogreen)             ,
	.oblue            (oblue)              ,
	.rd_fifo_empty    (rd_fifo_empty)      ,
	.arb_state        (arb_state)          ,
	.memcon_en        (memcon_en)          ,
	.memcon_donep     (memcon_done)        ,
	.memclk           (clkmem)             ,
	.mcb_rd_en        (p0_rd_en)           ,
	.mcb_rd_data      (p0_rd_data)         ,
	.mcb_rd_full      (p0_rd_full)         ,
	.mcb_rd_empty     (p0_rd_empty)        ,
	.mcb_rd_count     (p0_rd_count)        ,
	.mcb_cmd_en       (rd_cmd_en)          ,
	.mcb_cmd_instr    (rd_cmd_instr)       ,
	.mcb_cmd_bl       (rd_cmd_bl)          ,
	.mcb_cmd_byte_addr(rd_cmd_addr)        ,
	.mcb_cmd_empty    (p0_cmd_empty)       ,
	.mcb_cmd_full     (p0_cmd_full)
);

reg regfull0, regfull1;
always @ (posedge clkmem)
	if (rst|bsw) begin
		regfull0 <= 0;
		regfull1 <= 0;
	end else begin
		if (lfull0 && ~lempty0) regfull0 <= 1;
		if (lfull1 && ~lempty1) regfull1 <= 1;
	end

assign debug = (sw == 2'b00) ? {wr_fifo_en1, rd_fifo_en1, wr_fifo_en0, rd_fifo_en0, p0_wr_error, p0_rd_error, p0_wr_underrun, p0_rd_overflow} : 
               (sw == 2'b01) ? {lfull1, lempty1, lfull0, lempty0, testpr, perr, regfull0, regfull1} :
               (sw == 2'b10) ? debug1 : debug2;

endmodule
