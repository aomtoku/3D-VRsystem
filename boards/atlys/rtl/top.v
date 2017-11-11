`define MIXER
`define HDMI
`define FHD
module top (
	input  wire                        SYS_CLK,
	input  wire                        RSTBTN_,
	input  wire                  [4:0] SW,
	input  wire                        BSW,
	input  wire                  [3:0] RX0_TMDS,
	input  wire                  [3:0] RX0_TMDSB,
	input  wire                        RX0_SCL,
	inout  wire                        RX0_SDA,
	input  wire                  [3:0] RX1_TMDS,
	input  wire                  [3:0] RX1_TMDSB,
	input  wire                        RX1_SCL,
	inout  wire                        RX1_SDA,
`ifdef MIXER
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
`endif
	output wire                  [3:0] TMDS,
	output wire                  [3:0] TMDSB,
	output wire                  [7:0] LED
);

/* ------------ MCB Parameters ---------------- */
parameter C3_NUM_DQ_PINS          = 16;
parameter C3_MEM_ADDR_WIDTH       = 13;       
parameter C3_MEM_BANKADDR_WIDTH   = 3;      

wire clk100;
IBUFG sysclk_buf (.I(SYS_CLK), .O(clk100));

reg clk_buf;
assign clk50m = clk_buf;
always @(posedge clk100) clk_buf <= ~clk_buf;

BUFG clk50m_bufgbufg (.I(clk50m), .O(clk50m_bufg));
/* --------- Switching Logic -------------- */
wire [1:0] sws_sync;
synchro #(.INITIALIZE("LOGIC0"))
synchro_sws_0 (.async(SW[3]),.sync(sws_sync[0]),.clk(clk50m_bufg));
synchro #(.INITIALIZE("LOGIC0"))
synchro_sws_1 (.async(SW[4]),.sync(sws_sync[1]),.clk(clk50m_bufg));
reg [1:0] sws_sync_q;
always @ (posedge clk50m_bufg) sws_sync_q <= sws_sync;
wire sw0_rdy;

debnce debsw0 (
	.sync(sws_sync_q),
	.debnced(sw0_rdy),
	.clk(clk50m_bufg)
);

wire pclk;
wire [1:0] sws_clk;

synchro #(
	.INITIALIZE("LOGIC0")
) clk_sws_0 (
	.async  ( SW[3]      ),
	.sync   ( sws_clk[0] ),
	.clk    ( pclk       )
);

synchro #(
	.INITIALIZE("LOGIC0")
) clk_sws_1 (
	.async  ( SW[4]      ),
	.sync   ( sws_clk[1] ),
	.clk    ( pclk       )
);

reg  [1:0] sws_clk_sync; //clk synchronous output
always @(posedge pclk) begin
	sws_clk_sync <= sws_clk;
end

/* --------- Power UP logic -------------- */
wire pclk_lckd;
wire pwrup;
SRL16E #(
	.INIT(16'h1)
) pwrup_0 (
	.Q(pwrup),
	.A0(1'b1),
	.A1(1'b1),
	.A2(1'b1),
	.A3(1'b1),
	.CE(pclk_lckd),
	.CLK(clk50m_bufg),
	.D(1'b0)
);

reg switch = 1'b0;
always @ (posedge clk50m_bufg) switch <= pwrup | sw0_rdy;

wire gopclk;
SRL16E SRL16E_0 (
	.Q(gopclk),
	.A0(1'b1),
	.A1(1'b1),
	.A2(1'b1),
	.A3(1'b1),
	.CE(1'b1),
	.CLK(clk50m_bufg),
	.D(switch)
);

/* ---------- Resolution Logic ----------- */
localparam SW_HMD = 2'd0;
localparam SW_XGA = 2'd1;
localparam SW_FHD = 2'd2;
localparam SW_720P = 2'd3;



//wire [7:0] pclk_M = 8'd248 - 8'd1;
//wire [7:0] pclk_D = 8'd167 - 8'd1;


reg [7:0] pclk_M, pclk_D;
always @ (posedge clk50m_bufg) begin
	if(switch) begin
		case(sws_sync_q)
			SW_HMD: begin //106.47MHz 
				pclk_M <= 8'd181 - 8'd1;
				pclk_D <= 8'd85 - 8'd1;
			end
			SW_XGA: begin //65 MHz pixel clock
				pclk_M <= 8'd82 - 8'd1;
				pclk_D <= 8'd63 - 8'd1;
			end
			SW_720P: begin //74.25MHz
				pclk_M <= 8'd248 - 8'd1;
				pclk_D <= 8'd167 - 8'd1;
			end
`ifdef FHD
			SW_FHD: begin //148.5MHz 
				pclk_M <= 8'd199 - 8'd1;
				pclk_D <= 8'd67 - 8'd1;
			end
`endif /*FHD*/
			default: begin //106.47 MHz pixel clock
				pclk_M <= 8'd181 - 8'd1;
				pclk_D <= 8'd85 - 8'd1;
			end
		endcase
    end
end

`ifdef FHD
//1920x1080@60Hz
localparam HPIXELS_FHD = 12'd1920; //1920 //Horizontal Live Pixels
localparam VLINES_FHD  = 12'd1080; //Vertical Live ines
localparam HSYNCPW_FHD = 12'd44;   //HSYNC Pulse Width
localparam VSYNCPW_FHD = 12'd5;    //VSYNC Pulse Width
localparam HFNPRCH_FHD = 12'd87; //88  //Horizontal Front Portch
localparam VFNPRCH_FHD = 12'd4;    //Vertical Front Portch
localparam HBKPRCH_FHD = 12'd149; //148  //Horizontal Front Portch
localparam VBKPRCH_FHD = 12'd36;   //Vertical Front Portch
`endif /*FHD*/

localparam HPIXELS_720P = 12'd1280;//Horizontal Live Pixels
localparam VLINES_720P  = 12'd720; //Vertical Live ines
localparam HSYNCPW_720P = 12'd40;  //HSYNC Pulse Width
localparam VSYNCPW_720P = 12'd5;   //VSYNC Pulse Width
localparam HFNPRCH_720P = 12'd110; //Horizontal Front Portch
localparam VFNPRCH_720P = 12'd5;   //Vertical Front Portch
localparam HBKPRCH_720P = 12'd220; //Horizontal Front Portch
localparam VBKPRCH_720P = 12'd20;  //Vertical Front Portch
//1440x900@60Hz
localparam HPIXELS_HMD = 12'd1440; //Horizontal Live Pixels
localparam VLINES_HMD  = 12'd900;  //Vertical Live ines
localparam HSYNCPW_HMD = 12'd152;  //HSYNC Pulse Width
localparam VSYNCPW_HMD = 12'd3;    //VSYNC Pulse Width
localparam HFNPRCH_HMD = 12'd80;   //Horizontal Front Portch
localparam VFNPRCH_HMD = 12'd1;    //Vertical Front Portch
localparam HBKPRCH_HMD = 12'd232;  //Horizontal Front Portch
localparam VBKPRCH_HMD = 12'd28;   //Vertical Front Portch

//1024x768@60HZ
localparam HPIXELS_XGA = 12'd1023; //Horizontal Live Pixels
localparam VLINES_XGA  = 12'd768;  //Vertical Live ines
localparam HSYNCPW_XGA = 12'd136;  //HSYNC Pulse Width
localparam VSYNCPW_XGA = 12'd6;    //VSYNC Pulse Width
localparam HFNPRCH_XGA = 12'd24;   //Horizontal Front Portch
localparam VFNPRCH_XGA = 12'd3;    //Vertical Front Portch
localparam HBKPRCH_XGA = 12'd160;  //Horizontal Front Portch
localparam VBKPRCH_XGA = 12'd29;   //Vertical Front Portch

//wire [11:0] tc_hsblnk  = HPIXELS_720P - 12'd1;                                             
//wire [11:0] tc_hssync  = HPIXELS_720P - 12'd1 + HFNPRCH_720P;                              
//wire [11:0] tc_hesync  = HPIXELS_720P - 12'd1 + HFNPRCH_720P + HSYNCPW_720P;               
//wire [11:0] tc_heblnk  = HPIXELS_720P - 12'd1 + HFNPRCH_720P + HSYNCPW_720P + HBKPRCH_720P;
//wire [11:0] tc_vsblnk  =  VLINES_720P - 12'd1;                                             
//wire [11:0] tc_vssync  =  VLINES_720P - 12'd1 + VFNPRCH_720P;                              
//wire [11:0] tc_vesync  =  VLINES_720P - 12'd1 + VFNPRCH_720P + VSYNCPW_720P;               
//wire [11:0] tc_veblnk  =  VLINES_720P - 12'd1 + VFNPRCH_720P + VSYNCPW_720P + VBKPRCH_720P;
//wire hvsync_polarity   = 1'b0;


reg [11:0] tc_hsblnk ;
reg [11:0] tc_hssync ;
reg [11:0] tc_hesync ;
reg [11:0] tc_heblnk ;
reg [11:0] tc_vsblnk ;
reg [11:0] tc_vssync ;
reg [11:0] tc_vesync ;
reg [11:0] tc_veblnk ;
reg hvsync_polarity  ;


always @(*) begin
	case (sws_clk_sync)
`ifdef FHD
		SW_FHD : begin
			hvsync_polarity = 1'b0;

			tc_hsblnk = HPIXELS_FHD - 12'd1;
			tc_hssync = HPIXELS_FHD - 12'd1 + HFNPRCH_FHD;
			tc_hesync = HPIXELS_FHD - 12'd1 + HFNPRCH_FHD + HSYNCPW_FHD;
			tc_heblnk = HPIXELS_FHD - 12'd1 + HFNPRCH_FHD + HSYNCPW_FHD + HBKPRCH_FHD;
			tc_vsblnk =  VLINES_FHD - 12'd1;
			tc_vssync =  VLINES_FHD - 12'd1 + VFNPRCH_FHD;
			tc_vesync =  VLINES_FHD - 12'd1 + VFNPRCH_FHD + VSYNCPW_FHD;
			tc_veblnk =  VLINES_FHD - 12'd1 + VFNPRCH_FHD + VSYNCPW_FHD + VBKPRCH_FHD;
		end
`endif /*FHD*/
		SW_720P : begin
			hvsync_polarity = 1'b0;

			tc_hsblnk = HPIXELS_720P - 12'd1;
			tc_hssync = HPIXELS_720P - 12'd1 + HFNPRCH_720P;
			tc_hesync = HPIXELS_720P - 12'd1 + HFNPRCH_720P + HSYNCPW_720P;
			tc_heblnk = HPIXELS_720P - 12'd1 + HFNPRCH_720P + HSYNCPW_720P + HBKPRCH_720P;
			tc_vsblnk =  VLINES_720P - 12'd1;
			tc_vssync =  VLINES_720P - 12'd1 + VFNPRCH_720P;
			tc_vesync =  VLINES_720P - 12'd1 + VFNPRCH_720P + VSYNCPW_720P;
			tc_veblnk =  VLINES_720P - 12'd1 + VFNPRCH_720P + VSYNCPW_720P + VBKPRCH_720P;
		end
		SW_HMD : begin
			hvsync_polarity = 1'b1;

			tc_hsblnk = HPIXELS_HMD - 12'd1;
			tc_hssync = HPIXELS_HMD - 12'd1 + HFNPRCH_HMD;
			tc_hesync = HPIXELS_HMD - 12'd1 + HFNPRCH_HMD + HSYNCPW_HMD;
			tc_heblnk = HPIXELS_HMD - 12'd1 + HFNPRCH_HMD + HSYNCPW_HMD + HBKPRCH_HMD;
			tc_vsblnk =  VLINES_HMD - 12'd1;
			tc_vssync =  VLINES_HMD - 12'd1 + VFNPRCH_HMD;
			tc_vesync =  VLINES_HMD - 12'd1 + VFNPRCH_HMD + VSYNCPW_HMD;
			tc_veblnk =  VLINES_HMD - 12'd1 + VFNPRCH_HMD + VSYNCPW_HMD + VBKPRCH_HMD;
		end
		SW_XGA : begin
			hvsync_polarity = 1'b1;

			tc_hsblnk = HPIXELS_XGA - 12'd1;
			tc_hssync = HPIXELS_XGA - 12'd1 + HFNPRCH_XGA;
			tc_hesync = HPIXELS_XGA - 12'd1 + HFNPRCH_XGA + HSYNCPW_XGA;
			tc_heblnk = HPIXELS_XGA - 12'd1 + HFNPRCH_XGA + HSYNCPW_XGA + HBKPRCH_XGA;
			tc_vsblnk =  VLINES_XGA - 12'd1;
			tc_vssync =  VLINES_XGA - 12'd1 + VFNPRCH_XGA;
			tc_vesync =  VLINES_XGA - 12'd1 + VFNPRCH_XGA + VSYNCPW_XGA;
			tc_veblnk =  VLINES_XGA - 12'd1 + VFNPRCH_XGA + VSYNCPW_XGA + VBKPRCH_XGA;
		end
	endcase
end
//
// DCM_CLKGEN SPI controller
//
wire progdone, progen, progdata;
dcmspi dcmspi_0 (
	.RST(switch),          //Synchronous Reset
	.PROGCLK(clk50m_bufg), //SPI clock
	.PROGDONE(progdone),   //DCM is ready to take next command
	.DFSLCKD(pclk_lckd),
	.M(pclk_M),            //DCM M value
	.D(pclk_D),            //DCM D value
	.GO(gopclk),           //Go programme the M and D value into DCM(1 cycle pulse)
	.BUSY(busy),
	.PROGEN(progen),       //SlaveSelect,
	.PROGDATA(progdata)    //CommandData
);

//
// DCM_CLKGEN to generate a pixel clock with a variable frequency
//
wire          clkfx;
DCM_CLKGEN #(
	.CLKFX_DIVIDE (21),
	.CLKFX_MULTIPLY (31),
	.CLKIN_PERIOD(20.000)
)
PCLK_GEN_INST (
	.CLKFX(clkfx),
	.CLKFX180(),
	.CLKFXDV(),
	.LOCKED(pclk_lckd),
	.PROGDONE(progdone),
	.STATUS(),
	.CLKIN(clk50m),
	.FREEZEDCM(1'b0),
	.PROGCLK(clk50m_bufg),
	.PROGDATA(progdata),
	.PROGEN(progen),
	.RST(1'b0)
);


wire pllclk0, pllclk1, pllclk2;
wire pclkx2, pclkx10, pll_lckd;
wire clkfbout;

//
// Pixel Rate clock buffer
//
BUFG pclkbufg (.I(pllclk1), .O(pclk));

//////////////////////////////////////////////////////////////////
// 2x pclk is going to be used to drive OSERDES2
// on the GCLK side
//////////////////////////////////////////////////////////////////
BUFG pclkx2bufg (.I(pllclk2), .O(pclkx2));

//////////////////////////////////////////////////////////////////
// 10x pclk is used to drive IOCLK network so a bit rate reference
// can be used by OSERDES2
//////////////////////////////////////////////////////////////////
PLL_BASE # (
	.CLKIN_PERIOD(13),
	.CLKFBOUT_MULT(10), //set VCO to 10x of CLKIN
	.CLKOUT0_DIVIDE(1),
	.CLKOUT1_DIVIDE(10),
	.CLKOUT2_DIVIDE(5),
	.COMPENSATION("INTERNAL")
) PLL_OSERDES (
	.CLKFBOUT(clkfbout),
	.CLKOUT0(pllclk0),
	.CLKOUT1(pllclk1),
	.CLKOUT2(pllclk2),
	.CLKOUT3(),
	.CLKOUT4(),
	.CLKOUT5(),
	.LOCKED(pll_lckd),
	.CLKFBIN(clkfbout),
	.CLKIN(clkfx),
	.RST(~pclk_lckd)
);

wire serdesstrobe;
wire bufpll_lock;
wire reset;
BUFPLL #(
	.DIVIDE(5)
) ioclk_buf (
	.PLLIN(pllclk0), 
	.GCLK(pclkx2), 
	.LOCKED(pll_lckd),
	.IOCLK(pclkx10), 
	.SERDESSTROBE(serdesstrobe), 
	.LOCK(bufpll_lock)
);

synchro #(
	.INITIALIZE("LOGIC1")
) synchro_reset (
	.async(!pll_lckd),
	.sync(reset),
	.clk(pclk)
);

wire VGA_HSYNC_INT, VGA_VSYNC_INT;
wire   [11:0] bgnd_hcount;
wire          bgnd_hsync;
wire          bgnd_hblnk;
wire   [11:0] bgnd_vcount;
wire          bgnd_vsync;
wire          bgnd_vblnk;


timing timing_inst (
	.tc_hsblnk ( tc_hsblnk     ), //input
	.tc_hssync ( tc_hssync     ), //input
	.tc_hesync ( tc_hesync     ), //input
	.tc_heblnk ( tc_heblnk     ), //input
	.hcount    ( bgnd_hcount   ), //output
	.hsync     ( VGA_HSYNC_INT ), //output
	.hblnk     ( bgnd_hblnk    ), //output
	.tc_vsblnk ( tc_vsblnk     ), //input
	.tc_vssync ( tc_vssync     ), //input
	.tc_vesync ( tc_vesync     ), //input
	.tc_veblnk ( tc_veblnk     ), //input
	.vcount    ( bgnd_vcount   ), //output
	.vsync     ( VGA_VSYNC_INT ), //output
	.vblnk     ( bgnd_vblnk    ), //output
	.restart   ( reset         ),
	.clk       ( pclk          )
);

/////////////////////////////////////////
// V/H SYNC and DE generator
/////////////////////////////////////////
assign active = !bgnd_hblnk && !bgnd_vblnk;

reg active_q;
reg vsync, hsync;
reg VGA_HSYNC, VGA_VSYNC;
reg de;

always @ (posedge pclk) begin
	hsync <= VGA_HSYNC_INT ^ hvsync_polarity ;
	vsync <= VGA_VSYNC_INT ^ hvsync_polarity ;
	VGA_HSYNC <= hsync;
	VGA_VSYNC <= vsync;

	active_q <= active;
	de <= active_q;
end

  ///////////////////////////////////
  // Video pattern generator:
  //   SMPTE HD Color Bar
  ///////////////////////////////////
wire [7:0] hdc_red, hdc_blue, hdc_green;
wire [7:0] bf_red , bf_blue , bf_green ;
wire [7:0] red_data    = (SW[0]) ? hdc_red   : bf_red;
wire [7:0] green_data  = (SW[0]) ? hdc_green : bf_green;
wire [7:0] blue_data   = (SW[0]) ? hdc_blue  : bf_blue;

  ////////////////////////////////////////////////////////////////
  // DVI Encoder
  ////////////////////////////////////////////////////////////////
dvi_encoder_top enc0 (
	.pclk         ( pclk         ),
	.pclkx2       ( pclkx2       ),
	.pclkx10      ( pclkx10      ),
	.serdesstrobe ( serdesstrobe ),
	.rstin        ( reset        ),
	.blue_din     ( blue_data    ),
	.green_din    ( green_data   ),
	.red_din      ( red_data     ),
	.aux0_din     ( 4'd0         ),
	.aux1_din     ( 4'd0         ),
	.aux2_din     ( 4'd0         ),
	.hsync        ( VGA_HSYNC    ),
	.vsync        ( VGA_VSYNC    ),
	.vde          ( de           ),
	.ade          ( 1'b0         ),
	.TMDS         ( TMDS         ),
	.TMDSB        ( TMDSB        )
);
`ifdef EXTEND

wire pclk1x10, serdesstrobe1,bufpll_lock1;
BUFPLL #(
	.DIVIDE(5)
) ioclk1_buf (
	.PLLIN(pllclk0), 
	.GCLK(pclkx2), 
	.LOCKED(pll_lckd),
	.IOCLK(pclk1x10), 
	.SERDESSTROBE(serdesstrobe1), 
	.LOCK(bufpll_lock1)
);

dvi_encoder_top enc1 (
	.pclk         ( pclk          ),
	.pclkx2       ( pclkx2        ),
	.pclkx10      ( pclk1x10      ),
	.serdesstrobe ( serdesstrobe1 ),
	.rstin        ( reset         ),
	.blue_din     ( blue_data     ),
	.green_din    ( green_data    ),
	.red_din      ( red_data      ),
	.aux0_din     ( 4'd0          ),
	.aux1_din     ( 4'd0          ),
	.aux2_din     ( 4'd0          ),
	.hsync        ( VGA_HSYNC     ),
	.vsync        ( VGA_VSYNC     ),
	.vde          ( de            ),
	.ade          ( 1'b0          ),
	.TMDS         ( ETMDS         ),
	.TMDSB        ( ETMDSB        )
);
`endif

hdcolorbar clrbar(
	.i_clk_74M (pclk),
	.i_rst     (reset),
	.i_hcnt    (bgnd_hcount),
	.i_vcnt    (bgnd_vcount),
	.baronly   (1'b0),
	.i_format  (2'b00),
	.o_r       (hdc_red),
	.o_g       (hdc_green),
	.o_b       (hdc_blue)
);

/* --------------- EDID instance ---------------- */
i2c_edid edid0_inst (
	.clk(clk100),
	.rst(~RSTBTN_),
	.scl(RX0_SCL),
	.sda(RX0_SDA)
);
i2c_edid edid1_inst (
	.clk(clk100),
	.rst(~RSTBTN_),
	.scl(RX1_SCL),
	.sda(RX1_SDA)
);

/* --------------- Decoder Port0 ---------------- */
wire        rx0_tmdsclk;
wire        rx0_pclkx10, rx0_pllclk0;
wire        rx0_plllckd;
wire        rx0_reset;
wire        rx0_serdesstrobe;

wire        rx0_psalgnerr;      // channel phase alignment error
wire [7:0]  rx0_red;      // pixel data out
wire [7:0]  rx0_green;    // pixel data out
wire [7:0]  rx0_blue;     // pixel data out
wire        rx0_de;
wire [29:0] rx0_sdata;
wire        rx0_blue_vld;
wire        rx0_green_vld;
wire        rx0_red_vld;
wire        rx0_blue_rdy;
wire        rx0_green_rdy;
wire        rx0_red_rdy;

`ifdef HDMI
hdmi_decoder hdmi_decode0 (
	.tmdsclk_p   (RX0_TMDS[3]) ,  // tmds clock
	.tmdsclk_n   (RX0_TMDSB[3]),  // tmds clock
	.blue_p      (RX0_TMDS[0]) ,  // Blue data in
	.green_p     (RX0_TMDS[1]) ,  // Green data in
	.red_p       (RX0_TMDS[2]) ,  // Red data in
	.blue_n      (RX0_TMDSB[0]),  // Blue data in
	.green_n     (RX0_TMDSB[1]),  // Green data in
	.red_n       (RX0_TMDSB[2]),  // Red data in
	.exrst       (~RSTBTN_)    ,  // external reset input, e.g. reset button
	
	.reset       (rx0_reset)       ,  // rx reset
	.pclk        (rx0_pclk)        ,  // regenerated pixel clock
	.pclkx2      (rx0_pclkx2)      ,  // double rate pixel clock
	.pclkx10     (rx0_pclkx10)     ,  // 10x pixel as IOCLK
	.pllclk0     (rx0_pllclk0)     ,  // send pllclk0 out so it can be fed into a different BUFPLL
	.pllclk1     (rx0_pllclk1)     ,  // PLL x1 output
	.pllclk2     (rx0_pllclk2)     ,  // PLL x2 output
                 
	.pll_lckd    (rx0_plllckd)     ,  // send pll_lckd out so it can be fed into a different BUFPLL
	.serdesstrobe(rx0_tmdsclk)     ,  // BUFPLL serdesstrobe output
	.tmdsclk     (rx0_serdesstrobe),  // TMDS cable clock
                 
	.hsync       (rx0_hsync)       , // hsync data
	.vsync       (rx0_vsync)       , // vsync data
	.ade         ()                , // data enable
	.vde         (rx0_de)          , // data enable

	.blue_vld    (rx0_blue_vld)    ,
	.green_vld   (rx0_green_vld)   ,
	.red_vld     (rx0_red_vld)     ,
	.blue_rdy    (rx0_blue_rdy)    ,
	.green_rdy   (rx0_green_rdy)   ,
	.red_rdy     (rx0_red_rdy)     ,
                                   
	.psalgnerr   (rx0_psalgnerr)   ,
	.debug       ()                ,
                       
	.sdout       (rx0_sdata)       ,
	.aux0        (),
	.aux1        (),
	.aux2        (),
	.red         (rx0_red)         ,      // pixel data out
	.green       (rx0_green)       ,    // pixel data out
	.blue        (rx0_blue)
); 
`else
dvi_decoder dvi_rx0 (
	//These are input ports
	.tmdsclk_p   (RX0_TMDS[3]) ,
	.tmdsclk_n   (RX0_TMDSB[3]),
	.blue_p      (RX0_TMDS[0]) ,
	.green_p     (RX0_TMDS[1]) ,
	.red_p       (RX0_TMDS[2]) ,
	.blue_n      (RX0_TMDSB[0]),
	.green_n     (RX0_TMDSB[1]),
	.red_n       (RX0_TMDSB[2]),
	.exrst       (~RSTBTN_)    ,

	//These are output ports
	.reset       (rx0_reset)   ,
	.pclk        (rx0_pclk)    ,
	.pclkx2      (rx0_pclkx2)  ,
	.pclkx10     (rx0_pclkx10) ,
	.pllclk0     (rx0_pllclk0) , // PLL x10 output
	.pllclk1     (rx0_pllclk1) ,  // PLL x1 output
	.pllclk2     (rx0_pllclk2) , // PLL x2 output
	.pll_lckd    (rx0_plllckd) ,
	.tmdsclk     (rx0_tmdsclk) ,
	.serdesstrobe(rx0_serdesstrobe),
	.hsync       (rx0_hsync)   ,
	.vsync       (rx0_vsync)   ,
	.de          (rx0_de)      ,

	.blue_vld    (rx0_blue_vld) ,
	.green_vld   (rx0_green_vld),
	.red_vld     (rx0_red_vld)  ,
	.blue_rdy    (rx0_blue_rdy) ,
	.green_rdy   (rx0_green_rdy),
	.red_rdy     (rx0_red_rdy)  ,

	.psalgnerr   (rx0_psalgnerr),

	.sdout       (rx0_sdata)    ,
	.red         (rx0_red)      ,
	.green       (rx0_green)    ,
	.blue        (rx0_blue)
); 
`endif
/* --------------- Decoder Port1 ---------------- */
wire        rx1_tmdsclk;
wire        rx1_pclkx10, rx1_pllclk0;
wire        rx1_plllckd;
wire        rx1_reset;
wire        rx1_serdesstrobe;

wire        rx1_psalgnerr;      // channel phase alignment error
wire [7:0]  rx1_red;      // pixel data out
wire [7:0]  rx1_green;    // pixel data out
wire [7:0]  rx1_blue;     // pixel data out
wire        rx1_de;
wire [29:0] rx1_sdata;
wire        rx1_blue_vld;
wire        rx1_green_vld;
wire        rx1_red_vld;
wire        rx1_blue_rdy;
wire        rx1_green_rdy;
wire        rx1_red_rdy;

`ifdef HDMI
hdmi_decoder hdmi_decode1 (
	.tmdsclk_p   (RX1_TMDS[3]) ,  // tmds clock
	.tmdsclk_n   (RX1_TMDSB[3]),  // tmds clock
	.blue_p      (RX1_TMDS[0]) ,  // Blue data in
	.green_p     (RX1_TMDS[1]) ,  // Green data in
	.red_p       (RX1_TMDS[2]) ,  // Red data in
	.blue_n      (RX1_TMDSB[0]),  // Blue data in
	.green_n     (RX1_TMDSB[1]),  // Green data in
	.red_n       (RX1_TMDSB[2]),  // Red data in
	.exrst       (~RSTBTN_)    ,  // external reset input, e.g. reset button
	
	.reset       (rx1_reset)       ,  // rx reset
	.pclk        (rx1_pclk)        ,  // regenerated pixel clock
	.pclkx2      (rx1_pclkx2)      ,  // double rate pixel clock
	.pclkx10     (rx1_pclkx10)     ,  // 10x pixel as IOCLK
	.pllclk0     (rx1_pllclk0)     ,  // send pllclk0 out so it can be fed into a different BUFPLL
	.pllclk1     (rx1_pllclk1)     ,  // PLL x1 output
	.pllclk2     (rx1_pllclk2)     ,  // PLL x2 output
                 
	.pll_lckd    (rx1_plllckd)     ,  // send pll_lckd out so it can be fed into a different BUFPLL
	.serdesstrobe(rx1_tmdsclk)     ,  // BUFPLL serdesstrobe output
	.tmdsclk     (rx1_serdesstrobe),  // TMDS cable clock
                 
	.hsync       (rx1_hsync)       , // hsync data
	.vsync       (rx1_vsync)       , // vsync data
	.ade         ()                , // data enable
	.vde         (rx1_de)          , // data enable

	.blue_vld    (rx1_blue_vld)    ,
	.green_vld   (rx1_green_vld)   ,
	.red_vld     (rx1_red_vld)     ,
	.blue_rdy    (rx1_blue_rdy)    ,
	.green_rdy   (rx1_green_rdy)   ,
	.red_rdy     (rx1_red_rdy)     ,
                                   
	.psalgnerr   (rx1_psalgnerr)   ,
	.debug       ()                ,
                       
	.sdout       (rx1_sdata)       ,
	.aux0        (),
	.aux1        (),
	.aux2        (),
	.red         (rx1_red)         ,      // pixel data out
	.green       (rx1_green)       ,    // pixel data out
	.blue        (rx1_blue)
); 
`else
dvi_decoder dvi_rx1 (
	//These are input ports
	.tmdsclk_p   (RX1_TMDS[3])     ,
	.tmdsclk_n   (RX1_TMDSB[3])    ,
	.blue_p      (RX1_TMDS[0])     ,
	.green_p     (RX1_TMDS[1])     ,
	.red_p       (RX1_TMDS[2])     ,
	.blue_n      (RX1_TMDSB[0])    ,
	.green_n     (RX1_TMDSB[1])    ,
	.red_n       (RX1_TMDSB[2])    ,
	.exrst       (~RSTBTN_)        ,

	//These are output ports
	.reset       (rx1_reset)       ,
	.pclk        (rx1_pclk)        ,
	.pclkx2      (rx1_pclkx2)      ,
	.pclkx10     (rx1_pclkx10)     ,
	.pllclk0     (rx1_pllclk0)     , // PLL x10 output
	.pllclk1     (rx1_pllclk1)     , // PLL x1 output
	.pllclk2     (rx1_pllclk2)     , // PLL x2 output
	.pll_lckd    (rx1_plllckd)     ,
	.tmdsclk     (rx1_tmdsclk)     ,
	.serdesstrobe(rx1_serdesstrobe),
	.hsync       (rx1_hsync)       ,
	.vsync       (rx1_vsync)       ,
	.de          (rx1_de)          ,

	.blue_vld    (rx1_blue_vld)    ,
	.green_vld   (rx1_green_vld)   ,
	.red_vld     (rx1_red_vld)     ,
	.blue_rdy    (rx1_blue_rdy)    ,
	.green_rdy   (rx1_green_rdy)   ,
	.red_rdy     (rx1_red_rdy)     ,

	.psalgnerr   (rx1_psalgnerr)   ,

	.sdout       (rx1_sdata)       ,
	.red         (rx1_red)         ,
	.green       (rx1_green)       ,
	.blue        (rx1_blue)
); 
`endif

mixer inst_mixer (
	/* Input Port 0 */
	.pclk0           (rx0_pclk)  ,
	.hs0             (rx0_hsync) ,
	.vs0             (rx0_vsync) ,
	.de0             (rx0_de)    ,
	.ir0             (rx0_red)   ,
	.ig0             (rx0_green) ,
	.ib0             (rx0_blue)  ,
    /* Input Port 1 */
	.pclk1           (rx1_pclk)  ,
	.hs1             (rx1_hsync) ,
	.vs1             (rx1_vsync) ,
	.de1             (rx1_de)    ,
	.ir1             (rx1_red)   ,
	.ig1             (rx1_green) ,
	.ib1             (rx1_blue)  ,
	/* Output port for Ethernet */
	.polarity        (hvsync_polarity),
	.mode            (sws_clk_sync),
	.opclk           (pclk)      ,
	.oserdes_rst     (serdes_rst),
	.ohs             (VGA_HSYNC) ,
	.ovs             (VGA_VSYNC) ,
	.ode             (active)    ,
	.ored            (bf_red)    ,
	.ogreen          (bf_green)  ,
	.oblue           (bf_blue)   ,
	/* DRAM controller */
	.mcb3_dram_dq    (mcb3_dram_dq)   ,
	.mcb3_dram_a     (mcb3_dram_a)    ,
	.mcb3_dram_ba    (mcb3_dram_ba)   ,
	.mcb3_dram_ras_n (mcb3_dram_ras_n),
	.mcb3_dram_cas_n (mcb3_dram_cas_n),
	.mcb3_dram_we_n  (mcb3_dram_we_n) ,
	.mcb3_dram_odt   (mcb3_dram_odt)  ,
	.mcb3_dram_cke   (mcb3_dram_cke)  ,
	.mcb3_dram_dm    (mcb3_dram_dm)   ,
	.mcb3_dram_udqs  (mcb3_dram_udqs) ,
	.mcb3_dram_udqs_n(mcb3_dram_udqs_n),
	.mcb3_rzq        (mcb3_rzq)       ,
	.mcb3_zio        (mcb3_zio)       ,
	.mcb3_dram_udm   (mcb3_dram_udm)  ,  
	.c3_sys_rst_n    (c3_sys_rst_n)   ,
	.mcb3_dram_dqs   (mcb3_dram_dqs)  ,
	.mcb3_dram_dqs_n (mcb3_dram_dqs_n),
	.mcb3_dram_ck    (mcb3_dram_ck)   ,
	.mcb3_dram_ck_n  (mcb3_dram_ck_n) ,
	/* System pins */
	.debug           (LED)            ,
	.rst             (~RSTBTN_)       , 
	.sw              (SW[2:1])        ,
	.bsw             (BSW)            ,
	.sysclk          (clk100)
);

endmodule

