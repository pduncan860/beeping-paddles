/** BP Memory ******************************************************************
 *
 * Provides a simplified interface to the 512KB SRAM chip on the DE2. Uses a
 * continuous read and writes on asserting write-enable.
 *
 * Chip included on the DE2 tested against is ISSI's IS61LV25616AL-10TL, which
 * operates near 100 MHz. Either the 27 or 50 MHz clocks on the DE2 can be used
 * for this chip.
 *
 * $AUTHOR$   Reuben Smith, John Hall
 * $COURSE$   ECE 287 C, Fall 2011
 * $TEACHER$  Peter Jamieson
 *
 * References:
 *   <1> ftp://ftp.altera.com/up/pub/Webdocs/DE2_UserManual.pdf
 *   <2> http://www.issi.com/pdf/61LV25616AL.pdf
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


module bp_memory(
	//-- module interface ----------------------------------------------------//
	input				clock, reset,
	input [17:0]		address,
	input [15:0]		data_i,
	output reg [15:0]	data_o,
	input 				we,
	
	//-- chip interface ------------------------------------------------------//
	output reg [17:0] 	mem_addr,
	inout [15:0]  		mem_q,
	output reg 			mem_nce, mem_nwe, mem_noe, mem_nub, mem_nlb
);


//-- memory signals ----------------------------------------------------------//

// Set bidir to drive data_i when we is on, otherwise high impedence.
assign mem_q = (mem_nwe == `LO) ? data_i : 16'hzzzz;


//-- memory control ----------------------------------------------------------//

parameter S_READY 		= 2'd0,
          S_READ_CONT	= 2'd1,
          S_READ_DONE	= 2'd2,
          S_WRITE 		= 2'd3;

reg [1:0] S, NS;

always @(posedge clock or negedge reset) begin
	if (~reset) begin
		S <= S_READY;
	end
	else begin
		S <= NS;
	end	
end

always @(*) begin
	case (S)
		default: begin
			NS <= S_READY;
		end
		
		S_READY: begin
			NS <= S_READ_CONT;
		
			if (we) begin
				NS <= S_WRITE;
			end
		end
		
		S_READ_CONT: begin
			NS <= S_READ_DONE;
		end
		
		S_READ_DONE: begin
			NS <= S_READY;
		end
		
		S_WRITE: begin
			NS <= S_READY;
		end
	endcase
end

always @(posedge clock) begin
	case (S)
		default: begin 
		end
	
		// Ready:
		// 		Chip selected.
		//		All controls off.
		S_READY: begin
			mem_nce <= `LO;
			mem_nwe <= `HI;
			mem_noe <= `HI;
			mem_nub <= `HI;
			mem_nlb <= `HI;
		end
		
		// Read, Continuous:
		//		Output enabled, read from upper and lower bytes.
		//		Drive current address.
		S_READ_CONT: begin
			mem_noe <= `LO;
			mem_nub <= `LO;
			mem_nlb <= `LO;
			
			mem_addr <= address;
		end
		
		// Read, Done:
		//		Read data on data bus.
		S_READ_DONE: begin
			data_o <= mem_q;
		end
		
		// Write:
		//		Write enabled, output disabled, write to upper and lower bytes.
		//		Drive current address.
		//		Data written handled by continuous assignment under signals.
		S_WRITE: begin
			mem_nwe <= `LO;
			mem_noe <= `HI;
			mem_nub <= `LO;
			mem_nlb <= `LO;
			
			mem_addr <= address;
		end
	endcase
end

endmodule


`undef LO
`undef HI
