/** BP System ******************************************************************
 *
 * The heart of the beast.
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


// TODO Switch velocity from 2-compl. to sign-magnitude.


`define LO 1'b0
`define HI 1'b1


module bp_system(
	//-- system --------------------------------------------------------------//
	input				CLOCK_27, CLOCK_50,
	input [3:0]			KEY,
	input [17:0] 		SW,
	
	//-- audio ---------------------------------------------------------------//
	output				I2C_SCLK,
	inout				I2C_SDAT,
	output				TD_RESET,
	output				AUD_ADCLRCK, AUD_DACLRCK, AUD_XCK,
	inout				AUD_BCLK,
	input				AUD_ADCDAT,
	output				AUD_DACDAT,
	
	//-- input ---------------------------------------------------------------//
	inout [35:0]		GPIO_0, GPIO_1,
	
	//-- video ---------------------------------------------------------------//
	output				VGA_SYNC, VGA_HS, VGA_VS, VGA_BLANK, VGA_CLK,
	output [9:0]		VGA_R, VGA_G, VGA_B
);


// machine state and next-state
reg [7:0] mS	= S_SYS_INIT, 
		  mNS	= S_SYS_INIT;
		  
// machine state advance
always @(posedge CLOCK_50 or negedge reset_soft) begin
	if (!reset_soft) begin
		mS <= S_SYS_INIT;
	end
	else begin
		mS <= mNS;
	end
end

// machine state control
always @(*) begin
	case (mS)
		default: begin
			mNS = S_SYS_INIT;
		end
	
		// system states //
		S_SYS_INIT: begin
			mNS = S_VID_CLEAR;
		end
		
		S_SYS_WAIT: begin
			mNS = S_SYS_WAIT;
		end
		
		// video states //
		S_VID_CLEAR: begin
			if (gun_done) begin
				mNS = S_VID_DRAW_BORDER;
			end
			else begin
				mNS = S_VID_CLEAR;
			end
		end
		
		S_VID_DRAW_BORDER: begin
			if (gun_done) begin
				mNS = S_VID_DRAW_BALL;
			end
			else begin
				mNS = S_VID_DRAW_BORDER;
			end
		end
		
		S_VID_DRAW_BALL: begin
			if (gun_done) begin
				mNS = S_VID_DRAW_DIVIDER;
			end
			else begin
				mNS = S_VID_DRAW_BALL;
			end
		end
		
		S_VID_DRAW_DIVIDER: begin
			if (gun_done) begin
				mNS = S_VID_DRAW_SCORE;
			end
			else begin
				mNS = S_VID_DRAW_DIVIDER;
			end
		end
		
		S_VID_DRAW_SCORE: begin
			if (gun_done) begin
				mNS = S_VID_DRAW_PADDLES;
			end
			else begin
				mNS = S_VID_DRAW_SCORE;
			end
		end
		
		S_VID_DRAW_PADDLES: begin
			if (gun_done) begin
				mNS = S_VID_DRAW_BALL;
			end
			else begin
				mNS = S_VID_DRAW_PADDLES;
			end
		end
	endcase
end


//-- system ------------------------------------------------------------------//

// soft-level system reset (return all to initial)
wire reset_soft = KEY[0];

// system states (000-009)
parameter S_SYS_INIT		= 'd000,
		  S_SYS_WAIT		= 'd001;
		  

//-- game --------------------------------------------------------------------//

parameter GAME_MAX_SCORE		= 'd10,

		  GAME_P1_START_X		= 'd4,
		  GAME_P1_START_Y		= VID_SCREEN_HHEIGHT - (VID_PADDLE_HEIGHT >> 1),
          GAME_P2_START_X		= VID_SCREEN_WIDTH - 'd8,
          GAME_P2_START_Y		= GAME_P1_START_Y,
          
          GAME_PADDLE_MIN_Y		= VID_BORDER_SIZE,
          GAME_PADDLE_MAX_Y		= VID_SCREEN_HEIGHT - VID_PADDLE_HEIGHT - VID_BORDER_SIZE + 1,
          GAME_PADDLE_SPEED		= 4'd2,
          GAME_PADDLE_MAX_SPEED	= 4'd6,
          
          GAME_BALL_START_X		= VID_SCREEN_HWIDTH - (VID_BALL_SIZE >> 1),
          GAME_BALL_START_Y		= VID_SCREEN_HHEIGHT - (VID_BALL_SIZE >> 1),
          GAME_BALL_START_VX	= 4'd2,
          GAME_BALL_START_VY	= 4'd0,
          GAME_BALL_MAX_SPEED	= 4'd7;

// game clock //
wire game_clock;
sixtyhz game_clock_generator(CLOCK_50, game_clock);

// p1 state //
reg [3:0] p1_score = 4'd0;

// current and previous positions (px)
reg [9:0] p1_paddle_x	= GAME_P1_START_X[9:0], 
		  p1_paddle_px	= GAME_P1_START_X[9:0];
reg [8:0] p1_paddle_y	= GAME_P1_START_Y[8:0], 
		  p1_paddle_py	= GAME_P1_START_Y[8:0];
		  
// velocity (px)
reg [3:0] p1_paddle_vx = 4'd0, 
          p1_paddle_vy = 4'd0;
		  
// p2 state //
reg [3:0] p2_score = 4'd0;

// current and previous positions (px)
reg [9:0] p2_paddle_x	= GAME_P2_START_X[9:0], 
		  p2_paddle_px	= GAME_P2_START_X[9:0];
reg [8:0] p2_paddle_y	= GAME_P2_START_Y[8:0], 
	      p2_paddle_py	= GAME_P2_START_Y[8:0];
          
// velocity (px)
reg [3:0] p2_paddle_vx = 4'd0, 
          p2_paddle_vy = 4'd0;
          
// ball state //
// current and previous positions (px)
reg [9:0] ball_x	= 10'd320, 
		  ball_px	= 10'd320;
reg [8:0] ball_y	= 9'd240, 
		  ball_py	= 9'd240;
          
// velocity (px)
reg [3:0] ball_vx = 4'd0,
          ball_vy = 4'd0;
                 
// game states
parameter S_GAME_INIT			= 'd000,
		  S_GAME_WAIT_START0	= 'd001,
		  S_GAME_WAIT_START1	= 'd002,
		  S_GAME_START			= 'd003,
		  S_GAME_UPDATE			= 'd004;
		  
reg [7:0] gS	= S_GAME_INIT, 
		  gNS	= S_GAME_INIT;

// game state advance
always @(posedge game_clock or negedge reset_soft) begin
	if (!reset_soft) begin
		gS <= S_GAME_INIT;
	end
	else begin
		gS <= gNS;
	end
end

// game state control
always @(*) begin
	case (gS)
		default: begin
			gNS = S_GAME_INIT;
		end
		
		S_GAME_INIT: begin
			gNS = S_GAME_WAIT_START0;
		end
		
		S_GAME_WAIT_START0: begin
			if (button0[BTN_START] || button1[BTN_START]) begin
				gNS = S_GAME_WAIT_START1;
			end
			else begin
				gNS = S_GAME_WAIT_START0;
			end
		end
		
		S_GAME_WAIT_START1: begin
			if (~button0[BTN_START] && ~button1[BTN_START]) begin
				gNS = S_GAME_START;
			end
			else begin
				gNS = S_GAME_WAIT_START1;
			end
		end
		
		S_GAME_START: begin
			gNS = S_GAME_UPDATE;
		end
		
		S_GAME_UPDATE: begin
			gNS = S_GAME_UPDATE;
		end
	endcase
end

// game state output
always @(posedge game_clock or negedge reset_soft) begin
	if (!reset_soft) begin
		reset_game_state();
	end
	else begin
		case (gS)
			default: begin
				reset_game_state();
			end
			
			S_GAME_INIT: begin
				reset_game_state();
			end
			
			S_GAME_START: begin
				serve_ball(1'b1);
			end
			
			S_GAME_UPDATE: begin
				// set prior positions
				p1_paddle_px <= p1_paddle_x;
				p1_paddle_py <= p1_paddle_y;
				
				p2_paddle_px <= p2_paddle_x;
				p2_paddle_py <= p2_paddle_y;
				
				// clear velocities from last tick
				p1_paddle_vx <= 4'd0;
				p1_paddle_vy <= 4'd0;
				
				p2_paddle_vx <= 4'd0;
				p2_paddle_vy <= 4'd0;
				
				// update p1 paddle //
				if (button0[BTN_UP]) begin
					if (button0[BTN_RB]) begin
						p1_paddle_vy <= -GAME_PADDLE_MAX_SPEED[3:0];
					end
					else begin
						p1_paddle_vy <= -GAME_PADDLE_SPEED[3:0];
					end
					
					// BUG: Paddle can skip this check and wrap. //
					if (p1_paddle_y + p1_paddle_vy >= GAME_PADDLE_MIN_Y) begin
					    p1_paddle_y <= p1_paddle_y + p1_paddle_vy;
					end
					else begin
						p1_paddle_y <= GAME_PADDLE_MIN_Y;
						p1_paddle_vy <= 4'd0;
					end
				end
				else if (button0[BTN_DOWN]) begin
					if (button0[BTN_RB]) begin
						p1_paddle_vy <= GAME_PADDLE_MAX_SPEED[3:0];
					end
					else begin
						p1_paddle_vy <= GAME_PADDLE_SPEED[3:0];
					end
					
					if (p1_paddle_y + p1_paddle_vy <= GAME_PADDLE_MAX_Y) begin
					    p1_paddle_y <= p1_paddle_y + p1_paddle_vy;
					end
					else begin
						p1_paddle_y <= GAME_PADDLE_MAX_Y;
						p1_paddle_vy <= 4'd0;
					end
				end
								
				// update p2 paddle //
				// TODO
		
				// update ball //
				ball_px <= ball_x;
				ball_py <= ball_y;
				
				// TODO
			end
		endcase
	end
end


task reset_game_state;
begin
	// p1 state reset
	p1_score <= 4'd0;
	
	p1_paddle_x <= GAME_P1_START_X[9:0];
	p1_paddle_px <= GAME_P1_START_X[9:0];
	p1_paddle_y <= GAME_P1_START_Y[8:0];
	p1_paddle_py <= GAME_P1_START_Y[8:0];
	
	p1_paddle_vx <= 4'd0;
	p1_paddle_vy <= 4'd0;
	
	// p2 state reset
	p2_score <= 4'd0;
	
	p2_paddle_x <= GAME_P2_START_X[9:0];
	p2_paddle_px <= GAME_P2_START_X[9:0];
	p2_paddle_y <= GAME_P2_START_Y[8:0];
	p2_paddle_py <= GAME_P2_START_Y[8:0];
	
	p2_paddle_vx <= 4'd0;
	p2_paddle_vy <= 4'd0;
	
	// ball state reset
	ball_x <= 10'd320;
	ball_px <= 10'd320;
	ball_y <= 9'd240;
	ball_py <= 9'd240;
	
	ball_vx <= 4'd0;
	ball_vy <= 4'd0;
end
endtask

task serve_ball;
input direction;
begin
	// position ball to center of field
	ball_x <= GAME_BALL_START_X[9:0];
	ball_y <= GAME_BALL_START_Y[8:0];
	
	ball_vy <= GAME_BALL_START_VY;

	// right
	if (direction) begin
		// launch ball to p2
		ball_vx <= GAME_BALL_START_VX;
	end
	// left
	else begin
		// launch ball to p1
		ball_vx <= -GAME_BALL_START_VX;
	end
end
endtask

//-- audio -------------------------------------------------------------------//

// sound frequencies and durations (1/8ths)
parameter SND_OFF_F		= 18'd000,
		  SND_OFF_T		=  5'd  0,

		  SND_PADDLE_F	= 18'd750,
		  SND_PADDLE_T	=  5'd  1,
		  
		  SND_SCORED_F	= 18'd900,
		  SND_SCORED_T	=  5'd  3;

// beep_state high for 2 ticks of 50 MHz plays sound
reg beep_state			= `LO;
// beep frequency to be played
reg [17:0] beep_freq	= SND_OFF_F;
// beep duration in 1/8 seconds
reg [4:0] beep_time		= SND_OFF_T;

// beeper module
timed_tone beeper(
	.valid(beep_state),
	.seconds(beep_time),
	.key({ 3'b0, reset_soft }),
	.sw(beep_freq),
	
	.clk50(CLOCK_50),
	.clk27(CLOCK_27),

	.td_reset(TD_RESET),

	.i2c_sclk(I2C_SCLK),
	.i2c_sdat(I2C_SDAT),
	.aud_xck(AUD_XCK),
	.aud_bclk(AUD_BCLK),
	.aud_adclrck(AUD_ADCLRCK),
	.aud_daclrck(AUD_DACLRCK),
	.aud_adcdat(AUD_ADCDAT),
	.aud_dacdat(AUD_DACDAT)
);


//-- video -------------------------------------------------------------------//

// video states (010-019)
parameter S_VID_CLEAR			= 'd010,
		  S_VID_DRAW_BORDER		= 'd011,
		  S_VID_DRAW_DIVIDER 	= 'd012,
		  S_VID_DRAW_SCORE		= 'd013,
		  S_VID_DRAW_PADDLES	= 'd014,
		  S_VID_DRAW_BALL		= 'd015;

// all units in pixels
parameter // display area //
		  VID_SCREEN_WIDTH		= 'd320 - 1,
		  VID_SCREEN_HWIDTH 	= VID_SCREEN_WIDTH >> 1,
		  VID_SCREEN_HEIGHT		= 'd240 - 1,
		  VID_SCREEN_HHEIGHT 	= VID_SCREEN_HEIGHT >> 1,
		  // field thickness //
		  VID_BORDER_SIZE		= 'd  4,
		  VID_DIVIDER_WIDTH		= 'd  3,
		  VID_DIVIDER_HEIGHT	= 'd  3,	// 2^x, not x
		  // score size //
		  VID_SCORE_SIZE		= 'd  4,
		  VID_SCORE_MARGIN		= 'd  4,
		  VID_SCORE_WIDTH		= 'd 16,
		  VID_SCORE_HEIGHT		= 'd 24,
		  VID_SCORE_HHEIGHT		= VID_SCORE_HEIGHT >> 1,
		  // score border //
		  VID_SCORE_BTOP		= VID_SCORE_SIZE,
		  VID_SCORE_BHTOP		= (VID_SCORE_HEIGHT >> 1) - (VID_SCORE_BTOP >> 1),
		  VID_SCORE_BLEFT		= VID_SCORE_SIZE,
		  VID_SCORE_BBOTTOM		= VID_SCORE_HEIGHT - VID_SCORE_SIZE,
		  VID_SCORE_BHBOTTOM	= (VID_SCORE_SIZE >> 1) + (VID_SCORE_BBOTTOM >> 1) + 1,
		  VID_SCORE_BRIGHT		= VID_SCORE_WIDTH - VID_SCORE_SIZE,
		  // score position //
		  VID_SCORE_P1_X		= VID_SCREEN_HWIDTH - (VID_SCREEN_HWIDTH >> 1),
		  VID_SCORE_P1_Y		= VID_BORDER_SIZE + VID_SCORE_MARGIN,
		  VID_SCORE_P2_X		= VID_SCREEN_HWIDTH + (VID_SCREEN_HWIDTH >> 1),
		  VID_SCORE_P2_Y		= VID_BORDER_SIZE + VID_SCORE_MARGIN,
		  // paddle //
		  VID_PADDLE_WIDTH		= 'd  4,
		  VID_PADDLE_HEIGHT		= 'd 32,
		  // ball //
		  VID_BALL_SIZE			= 'd  3;

// gun colors
parameter CLR_BLACK		= 3'b000,
		  CLR_BLUE		= 3'b001,
		  CLR_GREEN		= 3'b010,
		  CLR_RED		= 3'b100,
		  CLR_WHITE		= 3'b111;
		  
// video 'gun' attributes for rendering
reg [9:0] gun_x = 10'd0;			// x-coord to render
reg [8:0] gun_y = 9'd0;				// y-coord to render
reg [2:0] gun_color = CLR_BLACK;	// 1b RGB color at (x, y)
reg		  gun_plot = `LO,			// send high on 50 MHz clock to write current 
									// (x, y, color) to video memory
		  gun_done = `LO;			// signal from gun goes high on frame 
									// completion
// signal for redraw									
reg clear_gun_done = `LO;

// video adapter
vga_adapter video(
	.clock(CLOCK_50),
	.resetn(reset_soft),
	
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

// gun position control
always @(posedge CLOCK_50 or negedge reset_soft) begin
	if (!reset_soft) begin
		gun_x <= 10'd0;
		gun_y <= 9'd0;
		gun_done <= `LO;
	end
	else begin
		if (clear_gun_done) begin
			gun_done <= `LO;
		end
	
		if (gun_done == `LO) begin
			if (gun_y == VID_SCREEN_HEIGHT + 1'd1) begin
				gun_x <= 10'd0;
				gun_y <= 9'd0;
				gun_done <= `HI; 
			end
			else if (gun_x == VID_SCREEN_WIDTH + 1'd1) begin
				gun_x <= 10'd0;
				gun_y <= gun_y + 1'd1;
			end
			else begin
				gun_x <= gun_x + 1'd1;
			end
		end
	end
end

// video state output
always @(*) begin
	gun_color <= CLR_BLACK;
	gun_plot <= `LO;

	case (mS)
		default: begin
			clear_gun_done <= `LO;
			gun_color <= CLR_BLACK;
			gun_plot <= `LO;
		end
	
		S_VID_CLEAR: begin
			clear_gun_done <= `LO;

			if (!gun_done) begin
				gun_color <= CLR_BLACK;
				gun_plot <= `HI;
			end
			else begin
				clear_gun_done <= `HI;
			end
		end
		
		S_VID_DRAW_BORDER: begin
			clear_gun_done <= `LO;
			
			if (!gun_done) begin				
				if (gun_y < VID_BORDER_SIZE || 
				    gun_y > VID_SCREEN_HEIGHT - VID_BORDER_SIZE) begin
				    gun_color <= CLR_WHITE;
					gun_plot <= `HI;
				end
			end
			else begin
				clear_gun_done <= `HI;
			end
		end
		
		S_VID_DRAW_BALL: begin
			clear_gun_done <= `LO;

			if (!gun_done) begin
				// clear old ball
				if (gun_y >= ball_py &&
					gun_y < ball_py + VID_BALL_SIZE) begin
					if (gun_x >= ball_px &&
						gun_x < ball_px + VID_BALL_SIZE) begin
						gun_color <= CLR_BLACK;
						gun_plot <= `HI;
					end
				end
				
				// draw ball
				if (gun_y >= ball_y &&
					gun_y < ball_y + VID_BALL_SIZE) begin
					if (gun_x >= ball_x &&
						gun_x < ball_x + VID_BALL_SIZE) begin
						gun_color <= CLR_WHITE;
						gun_plot <= `HI;
					end
				end
			end
			else begin
				clear_gun_done <= `HI;
			end
		end
		
		S_VID_DRAW_DIVIDER: begin
			clear_gun_done <= `LO;
		
			if (!gun_done) begin
				if (gun_x > VID_SCREEN_HWIDTH - (VID_DIVIDER_WIDTH >> 1) &&
			        gun_x < VID_SCREEN_HWIDTH + (VID_DIVIDER_WIDTH >> 1)) begin
					if (gun_y[VID_DIVIDER_HEIGHT]) begin
						gun_color <= CLR_WHITE;
						gun_plot <= `HI;
					end
				end
			end
			else begin
				clear_gun_done <= `HI;
			end
		end
		
		S_VID_DRAW_SCORE: begin
			clear_gun_done <= `LO;

			if (!gun_done) begin
				// draw p1 score
				if (gun_y >= VID_SCORE_P1_Y && 
					gun_y < VID_SCORE_P1_Y + VID_SCORE_HEIGHT) begin
					if (gun_x >= VID_SCORE_P1_X &&
				        gun_x < VID_SCORE_P1_X + VID_SCORE_WIDTH) begin
				        // STUB
				        gun_color <= get_score_pixel(
							VID_SCORE_P1_X, 
							VID_SCORE_P1_Y, 
							p1_score
						);
				        gun_plot <= `HI;
					end
				end
				
				// draw p2 score
				if (gun_y >= VID_SCORE_P2_Y &&
				    gun_y < VID_SCORE_P2_Y + VID_SCORE_HEIGHT) begin
					if (gun_x >= VID_SCORE_P2_X &&
				        gun_x < VID_SCORE_P2_X + VID_SCORE_WIDTH) begin
				        // STUB
				        gun_color <= get_score_pixel(
							VID_SCORE_P2_X, 
							VID_SCORE_P2_Y, 
							p2_score
						);
				        gun_plot <= `HI;
					end
				end
			end
			else begin
				clear_gun_done <= `HI;
			end
		end
		
		S_VID_DRAW_PADDLES: begin
			clear_gun_done <= `LO;

			if (!gun_done) begin
				// clear old p1 paddle
				if (gun_y >= p1_paddle_py && 
			        gun_y < p1_paddle_py + VID_PADDLE_HEIGHT) begin
					if (gun_x >= p1_paddle_px &&
						gun_x < p1_paddle_px + VID_PADDLE_WIDTH) begin
						gun_color <= CLR_BLACK;
						gun_plot <= `HI;
					end
			    end
			    
			    // draw p1 paddle
			    if (gun_y >= p1_paddle_y && 
			        gun_y < p1_paddle_y + VID_PADDLE_HEIGHT) begin
					if (gun_x >= p1_paddle_x &&
						gun_x < p1_paddle_x + VID_PADDLE_WIDTH) begin
						gun_color <= CLR_WHITE;
						gun_plot <= `HI;
					end
			    end
			    
			    // clear old p2 paddle
				if (gun_y >= p2_paddle_py && 
			        gun_y < p2_paddle_py + VID_PADDLE_HEIGHT) begin
					if (gun_x >= p2_paddle_px &&
						gun_x < p2_paddle_px + VID_PADDLE_WIDTH) begin
						gun_color <= CLR_BLACK;
						gun_plot <= `HI;
					end
			    end
			    
			    // draw p2 paddle
			    if (gun_y >= p2_paddle_y && 
			        gun_y < p2_paddle_y + VID_PADDLE_HEIGHT) begin
					if (gun_x >= p2_paddle_x &&
						gun_x < p2_paddle_x + VID_PADDLE_WIDTH) begin
						gun_color <= CLR_WHITE;
						gun_plot <= `HI;
					end
			    end
			end
			else begin
				clear_gun_done <= `HI;
			end
		end
	endcase
end


function [2:0] get_score_pixel;
input [9:0] x;
input [8:0] y;
input [3:0] value;
begin
	get_score_pixel = CLR_BLACK;

	case (value)
		default: begin
			get_score_pixel = CLR_BLACK;
		end
	
		4'd0: begin
			if (gun_y < y + VID_SCORE_BTOP ||			// top
			    gun_x < x + VID_SCORE_BLEFT ||			// left
			    gun_x >= x + VID_SCORE_BRIGHT ||		// right
			    gun_y >= y + VID_SCORE_BBOTTOM) begin	// bottom
				get_score_pixel = CLR_WHITE;
			end
		end
		
		4'd1: begin
			if (gun_x >= x + VID_SCORE_BRIGHT) begin	// right
				get_score_pixel = CLR_WHITE;
			end
		end
		
		4'd2: begin
			if (gun_y < y + VID_SCORE_BTOP ||											// top
			    (gun_x < x + VID_SCORE_BLEFT && gun_y >= y + VID_SCORE_BHBOTTOM) ||		// left-bottom
			    (gun_y >= y + VID_SCORE_BHTOP && gun_y < y + VID_SCORE_BHBOTTOM) ||		// middle
			    (gun_x >= x + VID_SCORE_BRIGHT && gun_y <= y + VID_SCORE_BHTOP) ||		// right-top
			    gun_y >= y + VID_SCORE_BBOTTOM) begin									// bottom
				get_score_pixel = CLR_WHITE;
			end
		end
		
		4'd3: begin
			if (gun_y < y + VID_SCORE_SIZE ||											// top
			    (gun_y >= y + VID_SCORE_BHTOP && gun_y < y + VID_SCORE_BHBOTTOM) ||		// middle
			    gun_x >= x + VID_SCORE_BRIGHT ||										// right
			    gun_y >= y + VID_SCORE_BBOTTOM) begin									// bottom
				get_score_pixel = CLR_WHITE;
			end
		end
		
		4'd4: begin
			if (gun_x < x + VID_SCORE_BLEFT && gun_y <= y + VID_SCORE_BHTOP ||			// left-top
			    (gun_y >= y + VID_SCORE_BHTOP && gun_y < y + VID_SCORE_BHBOTTOM) ||		// middle
			    gun_x >= x + VID_SCORE_BRIGHT) begin									// right
				get_score_pixel = CLR_WHITE;
			end
		end
		
		4'd5: begin
			if (gun_y < y + VID_SCORE_BTOP ||											// top
			    (gun_x < x + VID_SCORE_BLEFT && gun_y <= y + VID_SCORE_BHTOP) ||		// left-top
			    (gun_y >= y + VID_SCORE_BHTOP && gun_y < y + VID_SCORE_BHBOTTOM) ||		// middle
			    (gun_x >= x + VID_SCORE_BRIGHT && gun_y >= y + VID_SCORE_BHBOTTOM) ||	// right-bottom
			    gun_y >= y + VID_SCORE_BBOTTOM) begin									// bottom
				get_score_pixel = CLR_WHITE;
			end
		end
			
		4'd6: begin
			if (gun_y < y + VID_SCORE_BTOP || 											// top
			    gun_x < x + VID_SCORE_BLEFT ||											// left
			    (gun_y >= y + VID_SCORE_BHTOP && gun_y < y + VID_SCORE_BHBOTTOM) ||		// middle
			    (gun_x >= x + VID_SCORE_BRIGHT && gun_y >= y + VID_SCORE_BHBOTTOM) ||	// right-bottom
			    gun_y >= y + VID_SCORE_BBOTTOM) begin									// bottom
				get_score_pixel = CLR_WHITE;
			end
		end
		
		4'd7: begin
			if (gun_y < y + VID_SCORE_BTOP ||			// top
			    gun_x >= x + VID_SCORE_BRIGHT) begin	// right
				get_score_pixel = CLR_WHITE;
			end
		end	
							
		4'd8: begin
			if (gun_y < y + VID_SCORE_BTOP || 											// top
			    gun_x < x + VID_SCORE_BLEFT ||											// left
			    (gun_y >= y + VID_SCORE_BHTOP && gun_y < y + VID_SCORE_BHBOTTOM) ||		// middle
			    gun_x >= x + VID_SCORE_BRIGHT ||										// right
			    gun_y >= y + VID_SCORE_BBOTTOM) begin									// bottom
				get_score_pixel = CLR_WHITE;
			end
		end
		
		4'd9: begin
			if (gun_y < y + VID_SCORE_BTOP ||											// top
				(gun_x < x + VID_SCORE_BLEFT && gun_y <= y + VID_SCORE_BHTOP) ||		// left-top
			    (gun_y >= y + VID_SCORE_BHTOP && gun_y < y + VID_SCORE_BHBOTTOM) ||		// middle
			    gun_x >= x + VID_SCORE_BRIGHT) begin									// right
				get_score_pixel = CLR_WHITE;
			end
		end	
		
		4'd10: begin // "A"
			if (gun_y < y + VID_SCORE_BTOP ||											// top
				gun_x < x + VID_SCORE_BLEFT ||											// left
			    (gun_y >= y + VID_SCORE_BHTOP && gun_y < y + VID_SCORE_BHBOTTOM) ||		// middle
			    gun_x >= x + VID_SCORE_BRIGHT) begin									// right
				get_score_pixel = CLR_WHITE;
			end
		end
	endcase
end
endfunction


//-- input -------------------------------------------------------------------//
// button indices
parameter BTN_START 	= 'd4,
		  BTN_SELECT 	= 'd5,
		  BTN_A			= 'd7,
		  BTN_B			= 'd6,
		  BTN_X			= 'd1,
		  BTN_Y			= 'd0,
		  BTN_UP		= 'd9,
		  BTN_DOWN		= 'd8,
		  BTN_LEFT		= 'd11,
		  BTN_RIGHT		= 'd10,
		  BTN_LB		= 'd3,
		  BTN_RB		= 'd2;

// ignore unused header pins
assign GPIO_0[35:7] = 27'bz,
       GPIO_0[5] = 1'bz,
       GPIO_0[3] = 1'bz,
       GPIO_0[1:0] = 2'bz;
assign GPIO_1[35:7] = 27'bz,
       GPIO_1[5] = 1'bz,
       GPIO_1[3] = 1'bz,
       GPIO_1[1:0] = 2'bz;

wire [11:0] button0, button1;

gameinput input0(
	.clock(CLOCK_50),
	.gameclock(game_clock),
	.reset(reset_soft),

	.data(GPIO_0[6]),
	.lat(GPIO_0[4]),
	.pulse(GPIO_0[2]),
	
	.plyr_input(button0)
);

gameinput input1(
	.clock(CLOCK_50),
	.gameclock(game_clock),
	.reset(reset_soft),
	
	.data(GPIO_1[6]),
	.lat(GPIO_1[4]),
	.pulse(GPIO_1[2]),

	.plyr_input(button1)
);


endmodule


`undef LO
`undef HI
