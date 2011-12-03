/** SNES Controller Interface ***************************************************************
 *
 * Provides a means of communication, through SNES controller, with the game logic, outputs 
 * state of buttons after receiving pulse from 60 Hz game clock.
 *
 * $AUTHOR$   John Hall, Reuben Smith
 * $COURSE$   ECE 287 C, Fall 2011
 * $TEACHER$  Peter Jamieson
 *
 * References:
 *   <1> http://web.mit.edu/6.111/www/s2004/PROJECTS/2/nes.htm
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
 
module gameinput(clock, gameclock, reset, lat, pulse, data, plyr_input);
   input clock, gameclock, reset, data;
   output lat, pulse;
   reg lat, lat1, pulse, pulse1, data1;
   output [11:0] plyr_input;
   
   reg left = 1'b0, 
	   right = 1'b0, 
	   up = 1'b0, 
	   down = 1'b0, 
	   A = 1'b0, 
	   B = 1'b0, 
	   select = 1'b0, 
	   start = 1'b0, 
	   Lb = 1'b0, 
	   Rb = 1'b0, 
	   X = 1'b0, 
	   Y = 1'b0;
   reg left1, right1, up1, down1, A1, B1, select1, start1, Lb1, Rb1, X1, Y1;
   assign plyr_input = {left, right, up, down, A, B, select, start, Lb, Rb, X, Y};              
   
   reg [4:0] state, nextstate, returnstate, nextreturnstate;
   reg [12:0] count, nextcount; 

   parameter START = 5'd0;
   parameter IDLE = 5'd1;
   parameter LATCH = 5'd2;
   parameter WAIT = 5'd3;
   parameter PULSE = 5'd4;
   parameter READ_B = 5'd5; // Read data for each of the button states
   parameter READ_Y = 5'd6;
   parameter READ_SEL = 5'd7;
   parameter READ_STRT = 5'd8;
   parameter READ_UP = 5'd9;
   parameter READ_DOWN = 5'd10;
   parameter READ_LEFT = 5'd11;
   parameter READ_RIGHT = 5'd12;
   parameter READ_A = 5'd13;
   parameter READ_X = 5'd14;
   parameter READ_LB = 5'd15;
   parameter READ_RB = 5'd16;
   parameter NULL_1 = 5'd17;
   parameter NULL_2 = 5'd18;
   parameter NULL_3 = 5'd19;
   parameter NULL_4 = 5'd20;
   
   
   
   parameter TWELVE_US = 12'd600;    //count for 12 us on a 50 MHz clock
   parameter SIX_US = 12'd300; //count for 6 us on a 50 MHz clock
 
always @ (posedge clock or negedge reset)
begin
	if (!reset) begin
		 state <= START;
		 returnstate <= START;
		 count <= 0;
		end    
  else  begin
		 state <= nextstate;
		 returnstate <= nextreturnstate;
		 count <= nextcount;
		end
end

always@(posedge clock)
begin
	 data1 <= ~data;
	  lat <= lat1;
	  pulse <= pulse1;
	  left <= left1;
	  right <= right1;
	  up <= up1;
	  down <= down1;
	  A <= A1;
	  B <= B1;
	  select <= select1;
	  start <= start1;
	  X <= X1;
	  Y <= Y1;
	  Lb <= Lb1;
	  Rb <= Rb1;
end
 
always @ (*)
   begin
		  //defaults
		  nextstate = state;
		  nextreturnstate = returnstate;
		  nextcount = count;
		  lat1 = lat;
		  pulse1 = pulse;
		  left1 = left;
		  right1 = right;
		  up1 = up;
		  down1 = down;
		  A1 = A;
		  B1 = B;
		  select1 = select;
		  start1 = start;
		  X1 = X;
		  Y1 = Y;
		  Lb1 = Lb;
		  Rb1 = Rb;
 
		  case (state)
		  START:
		  begin
				 nextstate = IDLE;
				 nextcount = 0;
		  end
		  IDLE:
		  begin
				 nextcount = 0;
				 //get input at input rate specified by game clock
				 if (gameclock)             nextstate = LATCH;
		  end
		  LATCH:
		  begin
				 //latch 12 us, then go to read A
				 lat1 = 1'b1;
				 if (count == TWELVE_US) begin
					   nextcount = 0;
					   lat1 = 1'b0;
					   nextstate = READ_B;
				 end
				 else   nextcount = count + 1'b1;
		  end
		  WAIT:
		  begin
				 //wait 6 us, then go to pulse
				 if (count == SIX_US) begin
					   nextcount = 0;
					   nextstate = PULSE;

				 end
				 else   nextcount = count + 1'b1;
		  end
		  PULSE:
		  begin
				 //pulse 6 us, then go to returnstate and read data
				 pulse1 = 1;
				 if (count == SIX_US) begin
					   nextcount = 0;
					   pulse1 = 1'b0;
					   nextstate = returnstate;

				 end
				 else   nextcount = count + 1'b1;
		  end
		  READ_B:
		  begin
				 B1 = data1;
				 nextreturnstate = READ_Y;
				 nextstate = WAIT;
		  end
		  READ_Y:
		  begin
				 Y1 = data1;
				 nextreturnstate = READ_SEL;
				 nextstate = WAIT;
		  end
		  READ_SEL:
		  begin
				 select1 = data1;
				 nextreturnstate = READ_STRT;
				 nextstate = WAIT;
		  end
		  READ_STRT:
		  begin
				 start1 = data1;
				 nextreturnstate = READ_UP;
				 nextstate = WAIT;
		  end
		  READ_UP:
		  begin
				 up1 = data1;
				 nextreturnstate = READ_DOWN;
				 nextstate = WAIT;
		  end
		  READ_DOWN:
		  begin
				 down1 = data1;
				 nextreturnstate = READ_LEFT;
				 nextstate = WAIT;
		  end
		  READ_LEFT:
		  begin
				 left1 = data1;
				 nextreturnstate = READ_RIGHT;
				 nextstate = WAIT;
		  end
		  READ_RIGHT:
		  begin
				 right1 = data1;
				 nextreturnstate = READ_A;
				 nextstate = WAIT;
		  end
		  READ_A:
		  begin
				 A1 = data1;
				 nextreturnstate = READ_X;
				 nextstate = WAIT;
		  end
		  READ_X:
		  begin
				 X1 = data1;
				 nextreturnstate = READ_LB;
				 nextstate = WAIT;
		  end
		  READ_LB:
		  begin
				 Lb1 = data1;
				 nextreturnstate = READ_RB;
				 nextstate = WAIT;
		  end
		  READ_RB:
		  begin
				 Rb1 = data1;
				 nextreturnstate = NULL_1;
				 nextstate = WAIT;
		  end
		  NULL_1:
		  begin
				 nextreturnstate = NULL_2;
				 nextstate = WAIT;
		  end
		  NULL_2:
		  begin
				 nextreturnstate = NULL_3;
				 nextstate = WAIT;
		  end
		  NULL_3:
		  begin
				 nextreturnstate = NULL_4;
				 nextstate = WAIT;
		  end
		  NULL_4:
		  begin
				 nextstate= IDLE;
		  end
		  default:
				 nextstate = IDLE;
		  endcase
end

endmodule

 