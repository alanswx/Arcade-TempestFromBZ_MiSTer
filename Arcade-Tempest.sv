//============================================================================
//  Arcade: Battlezone
//
//  Port to MiSTer
//  Copyright (C) 2018 
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

	`ifdef USEFB
	// Use framebuffer from DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of 16 bytes.
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

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	
	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);

assign VGA_F1    = 0;
assign VGA_SCALER= 0;

assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;


wire [1:0] ar = status[15:14];
assign VIDEO_ARX =  (!ar) ? ( 8'd4) : (ar - 1'd1);
assign VIDEO_ARY =  (!ar) ? ( 8'd3) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.BATTLEZONE;;",
	"H0OEF,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"-;",
//	"O2,Orientation,Vert,Horz;",
//	"O34,Language,English,German,French,Spanish;",
//	"O56,Ships,2-4,3-5,4-6,5-7;", system locks up when activating above 3-5
	"DIP;",
	"-;",
	"O3,Self Test,Off,On;",
	"-;",
	"R0,Reset;",
	"J1,fire,Start 1P,Start 2P,Coin;",
	"jn,A,Start,Select,R;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_6, clk_25, clk_50;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_50),	
	.outclk_1(clk_25),	
	.outclk_2(clk_6),	
	.locked(pll_locked)
);


///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_index;


wire [15:0] joy_0, joy_1;
wire [15:0] joy = joy_0 | joy_1;
wire [15:0] joya;

wire        forced_scandoubler;
wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_25),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.joystick_0(joy_0),
	.joystick_1(joy_1),
   .joystick_analog_0(joya)
	
);


/// from ultratank

reg JoyW_Fw,JoyW_Bk,JoyX_Fw,JoyX_Bk;
reg JoyY_Fw,JoyY_Bk,JoyZ_Fw,JoyZ_Bk;
always @(posedge clk_50) begin 
	case ({joy[3],joy[2],joy[1],joy[0]}) // Up,Down,Left,Right
		4'b1010: begin JoyW_Fw=0; JoyW_Bk=0; JoyX_Fw=1; JoyX_Bk=0; end //Up_Left
		4'b1000: begin JoyW_Fw=1; JoyW_Bk=0; JoyX_Fw=1; JoyX_Bk=0; end //Up
		4'b1001: begin JoyW_Fw=1; JoyW_Bk=0; JoyX_Fw=0; JoyX_Bk=0; end //Up_Right
		4'b0001: begin JoyW_Fw=1; JoyW_Bk=0; JoyX_Fw=0; JoyX_Bk=1; end //Right
		4'b0101: begin JoyW_Fw=0; JoyW_Bk=1; JoyX_Fw=0; JoyX_Bk=0; end //Down_Right
		4'b0100: begin JoyW_Fw=0; JoyW_Bk=1; JoyX_Fw=0; JoyX_Bk=1; end //Down
		4'b0110: begin JoyW_Fw=0; JoyW_Bk=0; JoyX_Fw=0; JoyX_Bk=1; end //Down_Left
		4'b0010: begin JoyW_Fw=0; JoyW_Bk=1; JoyX_Fw=1; JoyX_Bk=0; end //Left
		default: begin JoyW_Fw=0; JoyW_Bk=0; JoyX_Fw=0; JoyX_Bk=0; end
	endcase
end

localparam mod_battlezone  = 0;
localparam mod_bradley     = 1;
localparam mod_redbaron   = 2;
localparam mod_tempest   = 3;


reg [7:0] mod = 255;
always @(posedge clk_25) if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;


reg [7:0] sw[8];
always @(posedge clk_25) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;


wire [7:0] JB;
wire [7:0] arcadebuttons;
wire [7:0] audiosel;
wire [7:0] REDBARONBUTTONS;
wire [7:0] REDBARONJOY;
always @(*) begin
			JB<=8'b0;
			arcadebuttons <= 8'b0;
			REDBARONBUTTONS<=8'b0;
        case (mod) 
		  
			mod_battlezone:
			begin
			   // Pokey P (arcade buttons) : NC,NC, Start, Fire, L-For, L-Rev, R-For, R-Rev
				JB <= { /* 7 coin */ joy[7],joy[5],joy[6],joy[4],JoyW_Fw,JoyW_Bk,JoyX_Fw,JoyX_Bk};
				arcadebuttons <= {{2'b00},{joy[5]},{|{joy[6],joy[4]}},JoyW_Fw,JoyW_Bk,JoyX_Fw,JoyX_Bk};

			end
			mod_bradley:
			begin
				JB <= { /* 7 coin */ joy[7],joy[5],joy[6],joy[4],JoyW_Fw,JoyW_Bk,JoyX_Fw,JoyX_Bk};
				arcadebuttons <= {{2'b00},{joy[5]},{|{joy[6],joy[4]}},JoyW_Fw,JoyW_Bk,JoyX_Fw,JoyX_Bk};
			end
			mod_redbaron:
			begin 
			    // Fire, Start, Analog ?
				JB <= { /* 7 coin */ ~joy[7],joy[5],joy[6],joy[4],joy[2],joy[3],joy[0],joy[1]};
				//arcadebuttons<={4'b0,joy[3],joy[0],joy[1]};
				REDBARONBUTTONS<={joy[4],joy[5],6'b0};		
				arcadebuttons <= audiosel[0] ? (8'd255-(8'd63 - joya[7:1])) : (8'd255-(8'd63 - joya[15:9]));
			end
			default:
			begin
				JB <= { /* 7 coin */ joy[7],joy[5],joy[6],joy[4],JoyW_Fw,JoyW_Bk,JoyX_Fw,JoyX_Bk};
				arcadebuttons <= {{2'b00},{joy[5]},{|{joy[6],joy[4]}},JoyW_Fw,JoyW_Bk,JoyX_Fw,JoyX_Bk};
			end
		 endcase
end			

wire [7:0] DSW0 = sw[0];
wire [7:0] DSW1 = sw[1];
//  assign buttons = {{2'b00},{JB[6]},{|JB[5:4]},{JB[3:0]}};
//  7-> coin


///////////////////////////////////////////////////////////////////

wire hblank, vblank;
wire hs, vs;
wire [3:0] r,g,b;

reg ce_pix;
always @(posedge clk_50) begin
       ce_pix <= !ce_pix;
end
arcade_video #(640,12) arcade_video
(
        .*,

        .clk_video(clk_50),

        .RGB_in({r,g,b}),

        .HBlank(hblank),
        .VBlank(vblank),
        .HSync(hs),
        .VSync(vs),

        .forced_scandoubler(0),
        .fx(0)
);




wire reset = (RESET | status[0] | buttons[1] | ioctl_download);
//wire reset = RESET;
wire [3:0] audio;
assign AUDIO_L = {audio, audio,8'b0};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;



top bzonetop(
.clk_i(clk_50),
.btnCpuReset(~reset),
.DSW0(DSW0),
.DSW1(DSW1),
.JB(JB),
.buttons(arcadebuttons),
.REDBARONBUTTONS(REDBARONBUTTONS),
.JD(),
.audiosel(audiosel),
.self_test(~status[3]),
.vgaRed(r),
.vgaGreen(g),
.vgaBlue(b),
.Hsync(hs),
.Vsync(vs),
.hBlank(hblank),
.vBlank(vblank),
.en_r(),
.audio(audio),
.ampPWM(),
.ampSD(),
.dl_addr(ioctl_addr),
.dl_data(ioctl_dout),
.dl_wr(ioctl_wr & !ioctl_index),

.mod_bradley(mod==mod_bradley),
.mod_redbaron(mod==mod_redbaron),
.mod_tempest(mod==mod_tempest),
.mod_battlezone(mod==mod_battlezone)



);


endmodule
