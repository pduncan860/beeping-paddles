
module sixtyhz(clock, slwclock);
input clock; // 50 MHz Clock
output reg slwclock;
reg [19:0] count;
parameter turnover = 19'd416667;
always @(posedge clock)
begin

if (count == turnover)
	begin
		slwclock <= ~slwclock;
		count <= 19'b0;
	end
else 
	begin
		count <= count + 1'b1;
	end
end
endmodule
