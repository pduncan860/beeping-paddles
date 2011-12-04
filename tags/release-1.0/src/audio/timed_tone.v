/** BP Tone Generator ******************************************************************
 *
 * Provides a simple timed tone generator for audio tones during events of gamplay using
 * a slightly adapted module from John Loomis' 'audio3' project.
 *
 * $AUTHOR$   Reuben Smith, John Hall
 * $COURSE$   ECE 287 C, Fall 2011
 * $TEACHER$  Peter Jamieson
 *
 * References:
 *   <1> ftp://ftp.altera.com/up/pub/Webdocs/DE2_UserManual.pdf
 *   <2> http://www.johnloomis.org/digitallab/audio/audio3/audio3.html
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
 module timed_tone(
  input valid,
  input [4:0] seconds,
  // Clock Input (50 MHz)
  input clk50, // 50 MHz
  input clk27, // 27 MHz
  //  Push Buttons
  input  [3:0]  key,
  //  DPDT Switches 
  input  [17:0]  sw,
  // I2C
  output td_reset,
  inout  i2c_sdat, // I2C Data
  output i2c_sclk, // I2C Clock
  // Audio CODEC
  output/*inout*/ aud_adclrck, // Audio CODEC ADC LR Clock
  input	 aud_adcdat,  // Audio CODEC ADC Data
  output /*inout*/  aud_daclrck, // Audio CODEC DAC LR Clock
  output aud_dacdat,  // Audio CODEC DAC Data
  inout	 aud_bclk,    // Audio CODEC Bit-Stream Clock
  output aud_xck    // Audio CODEC Chip Clock
  );
  
  audio3 audz(clk50, clk27, key[0], pitch, td_reset, i2c_sdat, i2c_sclk, aud_adclrck,
   aud_adcdat, aud_daclrck,aud_dacdat,aud_bclk, aud_xck);
  
  
  parameter waiting = 1'b0;
  parameter play = 1'b1;
  parameter eigthsec = 26'd6_250_000;
  
  reg [17:0] pitch, pitch1;
  reg  S, NS;
  reg [30:0] count, nextcount;
  reg [4:0] seconds1;
  
  always @(posedge clk50 or negedge key[0])
  begin
	if (key[0] == 1'b0)
	begin
		S <= 0;
		count <= 0;
		pitch <= 0;
		seconds1 <= 0;
	end
	else
	begin
		seconds1 <= seconds;
		S <= NS;
		count <= nextcount;
		pitch <= pitch1;
	end
  end
  
  always @(*)
  begin
  pitch1 = pitch;
  nextcount = count;
  NS = S;
  case(S)
	  waiting:
	  begin
		  if ((valid) && (seconds > 1'b0))
   		  begin
	   	  pitch1 = sw[17:0];
		  NS = play;
		  end
	  end
	  play:
		  if (count < (seconds1*(eigthsec)))
		  nextcount = count + 1'b1;
		  else
		  begin
		  NS = waiting;
		  pitch1 = 0;
		  nextcount = 0;
		  end
  endcase
  end
  
  endmodule
  