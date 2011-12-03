/** BP System ******************************************************************
 *
 * Core module which brings in all physical connections and contains all BP
 * subsystem modules.
 *
 * $AUTHOR$   Reuben Smith, John Hall
 * $COURSE$   ECE 287 C, Fall 2011
 * $TEACHER$  Peter Jamieson
 *
 * References:
 *   None.
 *
 */


/*
 * Copyright (c) 2011, Reuben Smith and John Hall
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions are met:
 *
 * # Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 * # Redistributions in binary form must reproduce the above copyright notice, 
 *   this list of conditions and the following disclaimer in the documentation 
 *   and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 *
 */


`define LO 1'b0
`define HI 1'b1

`timescale 1ns/100ps


module bp_system(
	//-- system --------------------------------------------------------------//
	input				CLOCK_27, CLOCK_50,
	input [3:0]			KEY,
	
	//-- audio ---------------------------------------------------------------//
	
	
	//-- input ---------------------------------------------------------------//
	inout [35:0]		GPIO_0, GPIO_1,
	
	//-- video ---------------------------------------------------------------//
	output				VGA_SYNC, VGA_HS, VGA_VS, VGA_BLANK, VGA_CLK,
	output [9:0]		VGA_R, VGA_G, VGA_B,
	
	input [17:0] SW,
	output [17:0] LEDR
);

//-- system ------------------------------------------------------------------//

/* reset_hard
 *   Return hardware to power-on configuration (earliest possible state).
 */
wire reset_hard;
assign reset_hard = KEY[0];

parameter 
		  // SYSTEM STATES (000-099) //
		  S_SYS_INIT		= 'd000,
		  S_SYS_WAIT		= 'd001,
		  // GAME STATES   (100-199) //
		  // VIDEO STATES  (200-299) //
		  S_VID_CLEAR		= 'd200,
		  S_VID_DRAW_FIELD	= 'd201,
		  S_VID_DRAW_SCORE  = 'd202,
		  S_VID_DRAW_PADDLE = 'd203;

reg [8:0] S = S_SYS_INIT, 
		  NS;

always @(posedge CLOCK_50 or negedge reset_hard) begin
	if (!reset_hard) begin
		S <= S_SYS_INIT;
	end
	else begin
		S <= NS;
	end
end

always @(*) begin
	case (S)
		S_SYS_INIT: begin
			NS = S_VID_CLEAR;
		end
		
		S_VID_CLEAR: begin
			if (gun_done) begin
				NS = S_VID_DRAW_FIELD;
			end
			else begin
				NS = S_VID_CLEAR;
			end
		end
		
		S_VID_DRAW_FIELD: begin
			if (gun_done) begin
				NS = S_VID_DRAW_SCORE;
			end
			else begin
				NS = S_VID_DRAW_FIELD;
			end
		end
		
		S_VID_DRAW_SCORE: begin
			if (gun_done) begin
				NS = S_VID_DRAW_PADDLE;
			end
			else begin
				NS = S_VID_DRAW_SCORE;
			end
		end
		
		S_VID_DRAW_PADDLE: begin
			if (gun_done) begin
				NS = S_VID_DRAW_FIELD;
			end
			else begin
				NS = S_VID_DRAW_PADDLE;
			end
		end
		
		S_SYS_WAIT: begin
			NS = S_SYS_WAIT;
		end
	endcase
end

//-- game --------------------------------------------------------------------//

parameter MAX_SCORE = 'd10,
          MIN_PADDLE_Y = RGN_FIELD_THICK,
		  MAX_PADDLE_Y = VGA_HEIGHT - RGN_FIELD_THICK - RGN_PADDLE_HEIGHT - 1;

wire [3:0] paddle_speed = (SW[3:0] > 4'd0) ? SW[3:0] : 4'd2,
		   paddle_turbo = (SW[7:4] > 4'd0) ? SW[7:4] : 4'd5;

reg [3:0] p1_score = 4'd0,
		  p2_score = 4'd0;

reg [9:0] p1_paddle_x = RGN_FIELD_THICK,
          p2_paddle_x = VGA_WIDTH - RGN_FIELD_THICK - RGN_PADDLE_WIDTH;
		  
reg [8:0] p1_paddle_y = (VGA_HEIGHT >> 1) - (RGN_PADDLE_HEIGHT >> 1),
          p2_paddle_y = (VGA_HEIGHT >> 1) - (RGN_PADDLE_HEIGHT >> 1);

reg [9:0] ball_x, ball_y;

always @(posedge input_clock) begin
	if (button1[9] && p2_paddle_y > MIN_PADDLE_Y) begin
		if (button1[2]) begin
			p2_paddle_y = p2_paddle_y - paddle_turbo;
		end
		else begin
			p2_paddle_y = p2_paddle_y - paddle_speed;
		end
	end
	else if (button1[8] && p2_paddle_y < MAX_PADDLE_Y) begin
		if (button1[2]) begin
			p2_paddle_y = p2_paddle_y + paddle_turbo;
		end
		else begin
			p2_paddle_y = p2_paddle_y + paddle_speed;
		end
	end
end

//-- audio -------------------------------------------------------------------//




//-- video -------------------------------------------------------------------//
 
parameter VGA_WIDTH = 'd320,
		  VGA_HEIGHT = 'd240;
 
reg [9:0] gun_x = 10'd0;
reg [8:0] gun_y = 9'd0;
reg [2:0] gun_color = 3'b000;
reg gun_plot = `LO;
reg gun_done = `LO;
    
vga_adapter video(
	.clock(CLOCK_50),
	.resetn(reset_hard),
	
	.colour(gun_color),
	.x(gun_x),
	.y(gun_y),
	.plot(gun_plot),
	
	.VGA_CLK(VGA_CLK),
	.VGA_SYNC(VGA_SYNC),
	.VGA_HS(VGA_HS),
	.VGA_VS(VGA_VS),
	.VGA_BLANK(VGA_BLANK),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B)
);

//defparam video.MONOCHROME = "TRUE";

parameter RGN_FIELD_THICK 		= 'd4,

		  RGN_STRIP_THICK 		= 'd2,
		  
		  RGN_SCORE_MARGIN		= 'd4,
		  RGN_SCORE_THICK		= 'd4,
		  RGN_SCORE_THICK_HALF 	= RGN_SCORE_THICK >> 1,
		  RGN_SCORE_WIDTH		= 'd16,
		  RGN_SCORE_HEIGHT		= 'd24,
		  RGN_SCORE_HEIGHT_HALF	= RGN_SCORE_HEIGHT >> 1,
		  RGN_SCORE_P1_TOP		= RGN_FIELD_THICK + RGN_SCORE_MARGIN,
		  RGN_SCORE_P1_LEFT		= (VGA_WIDTH >> 1) - (VGA_WIDTH >> 2),
		  RGN_SCORE_P2_TOP  	= RGN_SCORE_P1_TOP,
		  RGN_SCORE_P2_LEFT 	= (VGA_WIDTH >> 1) + (VGA_WIDTH >> 2),
		  RGN_SCORE_B_TOP		= RGN_SCORE_THICK,
		  RGN_SCORE_B_LEFT		= RGN_SCORE_THICK,
		  RGN_SCORE_B_RIGHT		= RGN_SCORE_WIDTH - RGN_SCORE_THICK,
		  RGN_SCORE_B_BOTTOM	= RGN_SCORE_HEIGHT - RGN_SCORE_THICK,
		  RGN_SCORE_B_HTOP		= RGN_SCORE_HEIGHT_HALF - RGN_SCORE_THICK_HALF,
		  RGN_SCORE_B_HBOTTOM	= RGN_SCORE_HEIGHT_HALF + RGN_SCORE_THICK_HALF,
		  
		  RGN_PADDLE_WIDTH		= 'd 4,
		  RGN_PADDLE_HEIGHT		= 'd32;

always @(posedge CLOCK_50 or negedge reset_hard) begin
	if (!reset_hard) begin
		gun_x <= 10'd0;
		gun_y <= 9'd0;
		gun_done <= `LO;
	end
	else begin
		if (gun_done == `LO) begin
			if (gun_y == VGA_HEIGHT - 1) begin
				gun_done <= `HI;
				gun_x <= 10'd0;
				gun_y <= 9'd0;
			end
			else if (gun_x == VGA_WIDTH - 1) begin
				gun_x <= 10'd0;
				gun_y <= gun_y + 1'd1;
			end
			else begin
				gun_x <= gun_x + 1'd1;
			end
		end
	
		case (S)
			S_VID_CLEAR: begin
				gun_color <= 3'b000;
				gun_plot <= `HI;
				
				if (gun_done) begin
					gun_plot <= `LO;
					gun_done <= `LO;
				end
			end
			
			S_VID_DRAW_FIELD: begin
				gun_color <= 3'b111;
				
				if ((gun_x > (VGA_WIDTH >> 1) - RGN_STRIP_THICK) && 
				    (gun_x < (VGA_WIDTH >> 1) + RGN_STRIP_THICK)) begin
					if (gun_y[3]) begin
						gun_plot <= `HI;
					end
				end
				else if (gun_y < RGN_FIELD_THICK || gun_y >= VGA_HEIGHT - RGN_FIELD_THICK - 1) begin
					gun_plot <= `HI;
				end
				else begin
					gun_plot <= `LO;
				end
				
				if (gun_done) begin
					gun_plot <= `LO;
					gun_done <= `LO;
				end
			end
			
			S_VID_DRAW_SCORE: begin		
				gun_plot <= `LO;
					
				if (gun_y >= RGN_SCORE_P1_TOP && gun_y < RGN_SCORE_P1_TOP + RGN_SCORE_HEIGHT) begin
					if (gun_x >= RGN_SCORE_P1_LEFT && gun_x < RGN_SCORE_P1_LEFT + RGN_SCORE_WIDTH) begin
						gun_color <= draw_score(RGN_SCORE_P1_LEFT, RGN_SCORE_P1_TOP, p1_score);
						gun_plot <= `HI;
					end
					else if (gun_x >= RGN_SCORE_P2_LEFT && gun_x < RGN_SCORE_P2_LEFT + RGN_SCORE_WIDTH) begin
						gun_color <= draw_score(RGN_SCORE_P2_LEFT, RGN_SCORE_P2_TOP, p2_score);
						gun_plot <= `HI;
					end
				end
			
				if (gun_done) begin
					gun_plot <= `LO;
					gun_done <= `LO;
				end
			end
			
			S_VID_DRAW_PADDLE: begin
				gun_plot <= `LO;
				
				if (gun_x >= p1_paddle_x && gun_x < p1_paddle_x + RGN_PADDLE_WIDTH) begin
					if (gun_y >= RGN_FIELD_THICK && gun_y < VGA_HEIGHT - RGN_FIELD_THICK - 1) begin
						gun_color <= draw_paddle(p1_paddle_x, p1_paddle_y);
						gun_plot <= `HI;
					end
				end
				else if (gun_x >= p2_paddle_x && gun_x < p2_paddle_x + RGN_PADDLE_WIDTH) begin
					if (gun_y >= RGN_FIELD_THICK && gun_y < VGA_HEIGHT - RGN_FIELD_THICK - 1) begin
						gun_color <= draw_paddle(p2_paddle_x, p2_paddle_y);
						gun_plot <= `HI;
					end
				end
				
				if (gun_done) begin
					gun_plot <= `LO;
					gun_done <= `LO;
				end
			end
		endcase
	end
end


function [2:0] draw_score;
input [9:0] x;
input [8:0] y;
input [3:0] value;
begin
	draw_score = 3'b000;

	case (value)
		default: begin
			draw_score = 3'b000;
		end
	
		4'd0: begin
			if (gun_y < y + RGN_SCORE_B_TOP || 
			    gun_x < x + RGN_SCORE_B_LEFT ||
			    gun_x >= x + RGN_SCORE_B_RIGHT ||
			    gun_y >= y + RGN_SCORE_B_BOTTOM) begin
				draw_score = 3'b111;
			end
		end
		
		4'd1: begin
			if (gun_x >= x + RGN_SCORE_B_RIGHT) begin
				draw_score = 3'b111;
			end
		end
		
		4'd2: begin
			if (gun_y < y + RGN_SCORE_B_TOP ||
			    (gun_x < x + RGN_SCORE_B_LEFT && gun_y >= y + RGN_SCORE_B_HBOTTOM) ||
			    (gun_y >= y + RGN_SCORE_B_HTOP && gun_y < y + RGN_SCORE_B_HBOTTOM) ||
			    (gun_x >= x + RGN_SCORE_B_RIGHT && gun_y <= y + RGN_SCORE_B_HTOP) ||
			    gun_y >= y + RGN_SCORE_B_BOTTOM) begin
				draw_score = 3'b111;
			end
		end
		
		4'd3: begin
			if (gun_y < y + RGN_SCORE_THICK ||
			    (gun_y >= y + RGN_SCORE_B_HTOP && gun_y < y + RGN_SCORE_B_HBOTTOM) ||
			    gun_x >= x + RGN_SCORE_B_RIGHT ||
			    gun_y >= y + RGN_SCORE_B_BOTTOM) begin
				draw_score = 3'b111;
			end
		end
		
		4'd4: begin
			if (gun_x < x + RGN_SCORE_B_LEFT && gun_y <= y + RGN_SCORE_B_HTOP ||
			    (gun_y >= y + RGN_SCORE_B_HTOP && gun_y < y + RGN_SCORE_B_HBOTTOM) ||
			    gun_x >= x + RGN_SCORE_B_RIGHT) begin
				draw_score = 3'b111;
			end
		end
		
		4'd5: begin
			if (gun_y < y + RGN_SCORE_B_TOP ||
			    (gun_x < x + RGN_SCORE_B_LEFT && gun_y <= y + RGN_SCORE_B_HTOP) ||
			    (gun_y >= y + RGN_SCORE_B_HTOP && gun_y < y + RGN_SCORE_B_HBOTTOM) ||
			    (gun_x >= x + RGN_SCORE_B_RIGHT && gun_y >= y + RGN_SCORE_B_HBOTTOM) ||
			    gun_y >= y + RGN_SCORE_B_BOTTOM) begin
				draw_score = 3'b111;
			end
		end
			
		4'd6: begin
			if (gun_y < y + RGN_SCORE_B_TOP || 
			    gun_x < x + RGN_SCORE_B_LEFT ||
			    (gun_y >= y + RGN_SCORE_B_HTOP && gun_y < y + RGN_SCORE_B_HBOTTOM) ||
			    (gun_x >= x + RGN_SCORE_B_RIGHT && gun_y >= y + RGN_SCORE_B_HBOTTOM) ||
			    gun_y >= y + RGN_SCORE_B_BOTTOM) begin
				draw_score = 3'b111;
			end
		end
		
		4'd7: begin
			if (gun_y < y + RGN_SCORE_B_TOP ||
			    gun_x >= x + RGN_SCORE_B_RIGHT) begin
				draw_score = 3'b111;
			end
		end	
							
		4'd8: begin
			if (gun_y < y + RGN_SCORE_B_TOP || 
			    gun_x < x + RGN_SCORE_B_LEFT ||
			    (gun_y >= y + RGN_SCORE_B_HTOP && gun_y < y + RGN_SCORE_B_HBOTTOM) ||
			    gun_x >= x + RGN_SCORE_B_RIGHT ||
			    gun_y >= y + RGN_SCORE_B_BOTTOM) begin
				draw_score = 3'b111;
			end
		end
		
		4'd9: begin
			if (gun_y < y + RGN_SCORE_B_TOP ||
				(gun_x < x + RGN_SCORE_B_LEFT && gun_y <= y + RGN_SCORE_B_HTOP) ||
			    (gun_y >= y + RGN_SCORE_B_HTOP && gun_y < y + RGN_SCORE_B_HBOTTOM) ||
			    gun_x >= x + RGN_SCORE_B_RIGHT) begin
				draw_score = 3'b111;
			end
		end	
		
		4'd10: begin
			if (gun_y < y + RGN_SCORE_B_TOP ||
				gun_x < x + RGN_SCORE_B_LEFT ||
			    (gun_y >= y + RGN_SCORE_B_HTOP && gun_y < y + RGN_SCORE_B_HBOTTOM) ||
			    gun_x >= x + RGN_SCORE_B_RIGHT) begin
				draw_score = 3'b111;
			end
		end
	endcase
end
endfunction


function [2:0] draw_paddle;
input [9:0] x;
input [8:0] y;
begin
	draw_paddle = 3'b000;

	if (gun_x >= x && gun_x < x + RGN_PADDLE_WIDTH) begin
		if (gun_y >= y && gun_y < y + RGN_PADDLE_HEIGHT) begin
			draw_paddle = 3'b111;
		end
	end
end
endfunction

//-- input -------------------------------------------------------------------//

wire input_clock;
sixtyhz snes_con_clock(CLOCK_50, input_clock);

wire [11:0] button0, button1;

gameinput con0(
	.clock(CLOCK_50),
	.gameclock(input_clock),
	.reset(reset_hard),
	/*
	.data(GPIO_0[DATA_PIN_HERE]),
	.lat(GPIO_0[LATCH_PIN_HERE]),
	.pulse(GPIO_0[PULSE_PIN_HERE]),
	*/
	.plyr_input(button0)
);

gameinput con1(
	.clock(CLOCK_50),
	.gameclock(input_clock),
	.reset(reset_hard),
	
	.data(GPIO_1[6]),
	.lat(GPIO_1[4]),
	.pulse(GPIO_1[2]),

	.plyr_input(button1)
);
	

endmodule


`undef LO
`undef HI
