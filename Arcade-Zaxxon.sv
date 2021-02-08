//============================================================================
//  Arcade: Zaxxon
//
//  Port to MiSTer
//  Zaxxon by Dar (darfpga@aol.fr - sourceforge/darfpga )
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output [11:0] VIDEO_ARX,
	output [11:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

`ifdef USE_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

`ifdef USE_DDRAM
	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,
`endif

`ifdef USE_SDRAM
	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,
`endif

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign USER_OUT  = '1;
assign LED_USER  = rom_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign {FB_PAL_CLK, FB_FORCE_BLANK, FB_PAL_ADDR, FB_PAL_DOUT, FB_PAL_WR} = '0;

wire [1:0] ar = status[20:19];

assign VIDEO_ARX = (!ar) ? ((status[2]) ? 8'd4 : 8'd3) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2]) ? 8'd3 : 8'd4) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"ZAXXON;;",
	"-;",
	"H0OJK,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"DIP;",
	"-;",
	"O6,Service,Off,On;",
	"O7,Flip,Off,On;",
	"-;",
	"OF,High Score Save,Manual,Off;",
	"-;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Start 1P,Start 2P,Coin;",
	"jn,A,B,Start,Select,R;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_48m, pll_locked;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys), // 24M
	.outclk_1(clk_48m),
	.locked(pll_locked)  
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire [15:0] audio_l, audio_r;

wire [15:0] joy1, joy2, joy3, joy4;
wire [15:0] joy = joy1 | joy2 | joy3 | joy4;
wire [15:0] joy1a, joy2a, joy3a, joy4a;

wire signed [8:0] mouse_x;
wire signed [8:0] mouse_y;
wire        mouse_strobe;
reg   [7:0] mouse_flags;

wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.status_menumask({direct_video}),

	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.joystick_0(joy1),
	.joystick_1(joy2),
	.joystick_2(joy3),
	.joystick_3(joy4),

	.joystick_analog_0(joy1a),
	.joystick_analog_1(joy2a),
	.joystick_analog_2(joy3a),
	.joystick_analog_3(joy4a)

);

// load the DIPS
reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

// load the game title
reg [7:0] mod = 0;
always @(posedge clk_sys) if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;

localparam mod_zaxxon = 0;
localparam mod_superzaxxon = 1;
localparam mod_futurespy= 2;


wire m_start1  = joy[5];
wire m_start2  = joy[6];
wire m_coin1   = joy[7];

wire m_right1  = joy1[0];
wire m_left1   = joy1[1];
wire m_down1   = (mod==mod_futurespy) ? joy1[2] : joy1[3];
wire m_up1     = (mod==mod_futurespy) ? joy1[3] : joy1[2];
wire m_fire1a  = joy1[4];
wire m_fire1b  = joy1[5];

wire m_right2  = joy2[0];
wire m_left2   = joy2[1];
wire m_down2   = (mod==mod_futurespy) ? joy2[2] : joy2[3];
wire m_up2     = (mod==mod_futurespy) ? joy2[3] : joy2[2];
wire m_fire2a  = joy2[4];
wire m_fire2b  = joy2[5];

wire m_right   = m_right1 | m_right2;
wire m_left    = m_left1  | m_left2; 
wire m_down    = m_down1  | m_down2; 
wire m_up      = m_up1    | m_up2;   
wire m_fire_a  = m_fire1a | m_fire2a;
wire m_fire_b  = m_fire1b | m_fire2b;

wire rom_download = ioctl_download && !ioctl_index;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;
wire        ioctl_wait;

wire reset = status[0] | buttons[1] | rom_download;

zaxxon zaxxon
(
	.mod_superzaxxon(mod==mod_superzaxxon),
	.mod_futurespy(mod==mod_futurespy),
	.clock_24(clk_sys),
	.reset(reset),
	.video_r(r),
	.video_g(g),
	.video_b(b),
	.video_vblank(vblank),
	.video_hblank(hblank),
	.video_hs(hs),
	.video_vs(vs),
//	.video_csync(cs),
//	.video_ce(ce_pix),
//	.tv15Khz_mode(~status[3]),
	.audio_out_l(audio_l),
	.audio_out_r(audio_r),

	.dl_addr(ioctl_addr[17:0]),
	.dl_wr(ioctl_wr&rom_download),
	.dl_data(ioctl_dout),

	.ram_address(ram_address),
	.ram_data(ioctl_din),
	.ram_data_in(hiscore_to_ram),
	.ram_data_write(hiscore_write),
	
	.coin1(m_coin1),
	.coin2(1'b0),
	.start1(m_start1),
	.start2(m_start2),

	.right(m_right),
	.left(m_left),
	.up(m_up),
	.down(m_down),
	.fire1(m_fire_a),
	.fire2(m_fire_b),
 
	.right_c(m_right),
	.left_c(m_left),
	.up_c(m_up),
	.down_c(m_down),
	.fire1_c(m_fire_a),
	.fire2_c(m_fire_b),
	
	.sw1_input(sw[0]), // cocktail(1) / sound(1) / ships(2) / N.U.(2) /  extra ship (2)	
	.sw2_input(8'h33), // coin b(4) / coin a(4)  -- "3" => 1c_1c

	//.service(status[6]),
	.flip_screen(~status[7]),
	
	.wave_data(wave_data),
	.wave_addr(wave_addr),
	.wave_rd(wave_rd)
);

//wire ce_pix_old;
wire hs, vs, cs;
wire hblank, vblank;
wire [2:0] r,g;
wire [1:0] b;

// dev - bypass arcade_video
//assign VGA_CLK = clk_sys;
//assign VGA_CE = ce_pix;
//assign VGA_R = {r, 4'b0000};
//assign VGA_G = {g, 4'b0000};
//assign VGA_B = {b, 5'b00000};
//assign VGA_HS = hs;
//assign VGA_VS = vs;
//assign VGA_DE = ~(vblank | hblank);

reg ce_pix;
always @(posedge clk_48m) begin
	reg [2:0] div;
	
	div <= div + 1'd1;
	ce_pix <= !div;
end

wire rotate_ccw = 0;
wire no_rotate = status[2] | direct_video  ;
screen_rotate screen_rotate (.*);

arcade_video #(256,8) arcade_video
(
	.*,

	.clk_video(clk_48m),
	.RGB_in({r,g,b}),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),

	.fx(status[5:3])
);

assign AUDIO_L = { audio_l };
assign AUDIO_R = { audio_r };
assign AUDIO_S = 1;

wire [19:0] wave_addr;
wire [15:0] wave_data;
wire        wave_rd;	
	
sdram sdram
(
	.*,
	.init(~pll_locked),
	.clk(clk_48m),

	.addr(ioctl_download ? ioctl_addr :{5'b0,wave_addr}),
	.we(ioctl_download && ioctl_wr && (ioctl_index==2)),
	.rd(~ioctl_download & wave_rd),
	.din(ioctl_dout),
	.dout(wave_data),

	.ready()
);


// HISCORE SAVE/LOAD

wire [11:0]ram_address;
wire [7:0]hiscore_to_ram;
wire hiscore_write;

hiscore #(12) hi (
   .clk(clk_sys),
   .reset(reset),
   .mode(status[15]),
	//.delay(25'h1FFFFFF),
	.delay(1'b0),
   .ioctl_upload(ioctl_upload),
   .ioctl_download(ioctl_download),
   .ioctl_wr(ioctl_wr),
   .ioctl_addr(ioctl_addr),
   .ioctl_dout(ioctl_dout),
   .ioctl_din(ioctl_din),
   .ioctl_index(ioctl_index),
   .ram_address(ram_address),
	.data_to_ram(hiscore_to_ram),
	.ram_write(hiscore_write)
);

endmodule
