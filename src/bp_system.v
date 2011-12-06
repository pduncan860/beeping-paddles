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


//-- system ------------------------------------------------------------------//

/* reset_hard
 *   Return hardware to power-on configuration (earliest possible state).
 */
wire reset_hard;
assign reset_hard = KEY[0];

parameter 
		  // SYSTEM STATES (00-09) //
		  S_SYS_INIT		= 'd00,
		  S_SYS_WAIT		= 'd01,
		  // GAME STATES   (10-19) //
		  S_GAME_CHECK		= 'd10,
		  S_GAME_WIN_P1		= 'd11,
		  S_GAME_WIN_P2		= 'd12,
		  // VIDEO STATES  (20-29) //
		  S_VID_CLEAR		= 'd20,
		  S_VID_DRAW_FIELD	= 'd21,
		  S_VID_DRAW_SCORE  = 'd22,
		  S_VID_DRAW_PADDLE = 'd23,
		  S_VID_DRAW_BALL	= 'd24;

reg [4:0] S = S_SYS_INIT, 
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
		
		S_SYS_WAIT: begin
			NS = S_SYS_WAIT;
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
				NS = S_GAME_CHECK;
			end
			else begin
				NS = S_VID_DRAW_SCORE;
			end
		end
		
		S_VID_DRAW_PADDLE: begin
			if (gun_done) begin
				NS = S_VID_DRAW_BALL;
			end
			else begin
				NS = S_VID_DRAW_PADDLE;
			end
		end
		
		S_VID_DRAW_BALL: begin
			if (gun_done) begin
				NS = S_VID_DRAW_FIELD;
			end
			else begin
				NS = S_VID_DRAW_BALL;
			end
		end
		
		S_GAME_CHECK: begin
			NS = S_VID_DRAW_PADDLE;
		
			if (p1_score >= MAX_SCORE) begin
				NS = S_GAME_WIN_P1;
			end
			
			if (p2_score >= MAX_SCORE) begin
				NS = S_GAME_WIN_P2;
			end
		end
		
		S_GAME_WIN_P1: begin
			NS = S_SYS_WAIT;
		end
		
		S_GAME_WIN_P2: begin
			NS = S_SYS_WAIT;
		end
		
	endcase
end

//-- game --------------------------------------------------------------------//

parameter MAX_SCORE 		= 'd10,

          MIN_PADDLE_Y 		= RGN_FIELD_THICK,
		  MAX_PADDLE_Y 		= VGA_HEIGHT - RGN_FIELD_THICK - RGN_PADDLE_HEIGHT - 1,
		  
		  MAX_BALL_SPEED 	= 3'd6,
		  START_BALL_SPEED 	= 3'd1,
		  START_BALL_X		= (VGA_WIDTH >> 1) - (RGN_BALL_SIZE >> 1),
		  START_BALL_Y		= (VGA_HEIGHT >> 1) - (RGN_BALL_SIZE >> 1);

wire [3:0] paddle_speed = (SW[3:0] > 4'd0) ? SW[3:0] : 4'd2,
		   paddle_turbo = (SW[7:4] > 4'd0) ? SW[7:4] : 4'd5;
		   
reg [3:0] p1_speed = 4'd0,
		  p2_speed = 4'd0;

reg [3:0] p1_score = 4'd0,
		  p2_score = 4'd0;

reg [9:0] p1_paddle_x = RGN_FIELD_THICK,
          p2_paddle_x = VGA_WIDTH - (RGN_FIELD_THICK << 1) - RGN_PADDLE_WIDTH;
		  
reg [8:0] p1_paddle_y = (VGA_HEIGHT >> 1) - (RGN_PADDLE_HEIGHT >> 1),
          p2_paddle_y = (VGA_HEIGHT >> 1) - (RGN_PADDLE_HEIGHT >> 1);

reg [9:0] ball_x = START_BALL_X, 
          ball_y = START_BALL_Y, 
          ball_ox = START_BALL_X, 
          ball_oy = START_BALL_Y;
          
reg [3:0] ball_vx = { 1'b0, START_BALL_SPEED }, 
		  ball_vy = 4'd0;


// paddle control //
always @(posedge input_clock or negedge reset_hard) begin
	if (!reset_hard) begin
		p1_paddle_y <= (VGA_HEIGHT >> 1) - (RGN_PADDLE_HEIGHT >> 1);
		p2_paddle_y <= (VGA_HEIGHT >> 1) - (RGN_PADDLE_HEIGHT >> 1);
		
		p1_speed <= 4'd0;
		p2_speed <= 4'd0;
	end
	else begin	
		p1_speed <= 4'd0;
		p2_speed <= 4'd0;
	
		// P1 sending input
		if (button0 > 12'd0) begin		
			if (button0[9]) begin			// up
				p1_speed[3] <= `HI;
				
				if (button0[2]) begin			// RB
					p1_speed[2:0] <= paddle_turbo[2:0];
				end
				else begin
					p1_speed[2:0] <= paddle_speed[2:0];
				end
			
				if (p1_paddle_y - p1_speed[2:0] >= MIN_PADDLE_Y &&
					!(p1_paddle_y - p1_speed[2:0] > p1_paddle_y)) begin
					p1_paddle_y <= p1_paddle_y - p1_speed[2:0];
				end
				else begin
					p1_paddle_y <= MIN_PADDLE_Y;
				end
			end
			else if (button0[8]) begin		// down
				p1_speed[3] <= `LO;
			
				if (button0[2]) begin			// RB
					p1_speed[2:0] <= paddle_turbo[2:0];
				end
				else begin
					p1_speed[2:0] <= paddle_speed[2:0];
				end
			
				if (p1_paddle_y + p1_speed[2:0] <= MAX_PADDLE_Y) begin
					p1_paddle_y <= p1_paddle_y + p1_speed[2:0];
				end
				else begin
					p1_paddle_y <= MAX_PADDLE_Y;
				end
			end
		end
		
		// P2 sending input
		if (button1 > 12'd0) begin				
			if (button1[9]) begin			// up
				p2_speed[3] <= `HI;
				
				if (button1[2]) begin			// RB
					p2_speed[2:0] <= paddle_turbo[2:0];
				end
				else begin
					p2_speed[2:0] <= paddle_speed[2:0];
				end
			
				if (p2_paddle_y - p2_speed[2:0] >= MIN_PADDLE_Y &&
					!(p2_paddle_y - p2_speed[2:0] > p2_paddle_y)) begin
					p2_paddle_y <= p2_paddle_y - p2_speed[2:0];
				end
				else begin
					p2_paddle_y <= MIN_PADDLE_Y;
				end
			end
			else if (button1[8]) begin		// down
				p2_speed[3] <= `LO;
				
				if (button1[2]) begin			// RB
					p2_speed[2:0] <= paddle_turbo[2:0];
				end
				else begin
					p2_speed[2:0] <= paddle_speed[2:0];
				end
			
				if (p2_paddle_y + p2_speed[2:0] <= MAX_PADDLE_Y) begin
					p2_paddle_y <= p2_paddle_y + p2_speed[2:0];
				end
				else begin
					p2_paddle_y <= MAX_PADDLE_Y;
				end
			end
		end
	end
end

// ball logic //
always @(posedge input_clock or negedge reset_hard) begin
	if (!reset_hard) begin
		ball_x <= START_BALL_X; 
        ball_y <= START_BALL_Y; 
        ball_ox <= START_BALL_X;
        ball_oy <= START_BALL_Y;	
        
        ball_vx <= { 1'b0, START_BALL_SPEED };
        ball_vy <= 4'd0;
        
        beep_state <= `LO;
        
        p1_score <= 4'd0;
        p2_score <= 4'd0;
	end
	else begin
		if (S != S_SYS_WAIT) begin
	
		beep_state <= `LO;
	
        ball_ox <= ball_x;
        ball_oy <= ball_y;
	
		// ball moving left
		if (ball_vx[3]) begin
			// ball not at edge of field
			if (ball_x - ball_vx[2:0] > 10'd0 &&
			    !(ball_x - ball_vx[2:0] > ball_x)) begin
			    // ball hitting p1 paddle?
				if (ball_x - ball_vx[2:0] <= p1_paddle_x + RGN_PADDLE_WIDTH) begin
					// ball in front of paddle?
					if (ball_y >= p1_paddle_y && ball_y < p1_paddle_y + RGN_PADDLE_HEIGHT) begin
						play_paddle_beep();
					
						ball_x <= p1_paddle_x + RGN_PADDLE_WIDTH;
						ball_vx <= { ~ball_vx[3], (ball_vx[2:0] < 3'b111) ? ball_vx[2:0] + 1'b1 : MAX_BALL_SPEED };
						
						// no reflection if paddle and ball going same direction
						if (p1_speed[2:0] > 3'b000) begin
							if (ball_vy[3] == p1_speed[3]) begin
								ball_vy[2:0] <= 
									// clamp speed to 3'b111
									(ball_vy[2:0] + p1_speed[2:0] < MAX_BALL_SPEED) ? 
										ball_vy[2:0] + p1_speed[2:0] : 
										MAX_BALL_SPEED;
							end
							// possibly reflect
							else begin
								// no reflection possible
								if (ball_vy[2:0] >= p1_speed[2:0]) begin
									ball_vy[2:0] <=
										// clamp speed to 3'b000
										(ball_vy[2:0] - p1_speed[2:0] > 3'b000) ?
											ball_vy[2:0] - p1_speed[2:0] :
											3'b000;
								end
								// reflect
								else begin
									ball_vy <= {
										~ball_vy[3],
										p1_speed[2:0] - ball_vy[2:0]
									};
								end
							end
						end
					end
					// ball not in front of paddle
					else begin
						ball_x <= ball_x - ball_vx[2:0];
					end
				end
				// ball not hitting p1 paddle
				else begin
					ball_x <= ball_x - ball_vx[2:0];
				end
			end
			// ball at edge of field
			else begin
				// score p2
				p2_score <= p2_score + 1'd1;
				play_score_beep();
				
				ball_x <= START_BALL_X;
				ball_y <= START_BALL_Y;
				ball_vx <= { ~ball_vx[3], START_BALL_SPEED };
				ball_vy <= 4'd0;
			end
		end
		// ball moving right
		else begin
			// ball not at edge of field
			if (ball_x + ball_vx[2:0] < VGA_WIDTH - RGN_BALL_SIZE - 1) begin
				// ball hitting p2 paddle?
				if (ball_x + ball_vx[2:0] > p2_paddle_x - RGN_BALL_SIZE) begin
					// ball in front of paddle?
					if (ball_y >= p2_paddle_y && ball_y < p2_paddle_y + RGN_PADDLE_HEIGHT) begin
						play_paddle_beep();
					
						ball_x <= p2_paddle_x - RGN_BALL_SIZE;
						ball_vx <= { ~ball_vx[3], (ball_vx[2:0] < MAX_BALL_SPEED) ? ball_vx[2:0] + 1'b1 : MAX_BALL_SPEED };
						
						// no reflection if paddle and ball going same direction
						if (p2_speed[2:0] > 3'b000) begin
							if (ball_vy[3] == p2_speed[3]) begin
								ball_vy[2:0] <= 
									// clamp speed to 3'b111
									(ball_vy[2:0] + p2_speed[2:0] < MAX_BALL_SPEED) ? 
										ball_vy[2:0] + p2_speed[2:0] : 
										MAX_BALL_SPEED;
							end
							// possibly reflect
							else begin
								// no reflection possible
								if (ball_vy[2:0] >= p2_speed[2:0]) begin
									ball_vy[2:0] <=
										// clamp speed to 3'b000
										(ball_vy[2:0] - p2_speed[2:0] > 3'b000) ?
											ball_vy[2:0] - p2_speed[2:0] :
											3'b000;
								end
								// reflect
								else begin
									ball_vy <= {
										~ball_vy[3],
										p2_speed[2:0] - ball_vy[2:0]
									};
								end
							end
						end
					end
					// ball not in front of paddle
					else begin
						ball_x <= ball_x + ball_vx[2:0];
					end
				end
				// ball not hitting p2 paddle
				else begin
					ball_x <= ball_x + ball_vx[2:0];
				end
			end
			// ball at edge of field
			else begin
				// score p1
				p1_score <= p1_score + 1'd1;
				play_score_beep();
			
				ball_x <= START_BALL_X;
				ball_y <= START_BALL_Y;
				ball_vx <= { ~ball_vx[3], START_BALL_SPEED };
				ball_vy <= 4'd0;
			end
		end
		
		// ball moving up
		if (ball_vy[3]) begin
			// ball not at edge of field
			if (ball_y - ball_vy[2:0] >= RGN_FIELD_THICK &&
			    !(ball_y - ball_vy[2:0] > ball_y)) begin
				ball_y <= ball_y - ball_vy[2:0];
			end
			// ball at edge of field
			else begin
				ball_y <= RGN_FIELD_THICK;
				ball_vy <= { ~ball_vy[3], ball_vy[2:0] };
			end
		end
		// ball moving down
		else begin
			// ball not at edge of field
			if (ball_y + ball_vy[2:0] < VGA_HEIGHT - RGN_FIELD_THICK - RGN_BALL_SIZE &&
			    !(ball_y + ball_vy[2:0] < ball_y)) begin
				ball_y <= ball_y + ball_vy[2:0];
			end
			// ball at edge of field
			else begin
				ball_y <= VGA_HEIGHT - RGN_FIELD_THICK - RGN_BALL_SIZE;
				ball_vy <= { ~ball_vy[3], ball_vy[2:0] };
			end
		end
		
		end
		else begin
			beep_state <= `LO;
		end
	end
end

task play_score_beep;
begin
	beep_freq <= SND_SCORED_F;
	beep_time <= SND_SCORED_T;
	beep_state <= `HI;
end
endtask

task play_paddle_beep;
begin
	beep_freq <= SND_PADDLE_F;
	beep_time <= SND_PADDLE_T;
	beep_state <= `HI;
end
endtask


//-- audio -------------------------------------------------------------------//

parameter SND_PADDLE_F	= 18'd750,
		  SND_PADDLE_T	=  5'd  1,
		  SND_SCORED_F	= 18'd900,
		  SND_SCORED_T	=  5'd  3;

reg beep_state = `LO;
reg [17:0] beep_freq = SND_PADDLE_F;
reg [4:0] beep_time = SND_PADDLE_T;


timed_tone beeper(
	.valid(beep_state),
	.seconds(beep_time),
	.key({ 3'b0, reset_hard }),
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
	.aud_dacdat(AUD_DACDAT),
);


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
		  RGN_PADDLE_HEIGHT		= 'd32,
		  
		  RGN_BALL_SIZE			= 'd 4;

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
			
			S_VID_DRAW_BALL: begin
				gun_plot <= `LO;
				
				if (gun_x >= ball_ox && gun_x < ball_ox + RGN_BALL_SIZE &&
				    gun_y >= ball_oy && gun_y < ball_oy + RGN_BALL_SIZE) begin
					gun_color <= 3'b000;
					gun_plot <= `HI;
				end
				
				if (gun_x >= ball_x && gun_x < ball_x + RGN_BALL_SIZE &&
				    gun_y >= ball_y && gun_y < ball_y + RGN_BALL_SIZE) begin
					gun_color <= 3'b111;
					gun_plot <= `HI;
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

	.data(GPIO_0[6]),
	.lat(GPIO_0[4]),
	.pulse(GPIO_0[2]),
	
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
