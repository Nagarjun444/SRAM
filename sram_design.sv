module ram(clk,addres,data_in,write,read,data_out);

  input clk,write,read;

  input[2:0] addres;

  input[7:0] data_in;

output reg [7:0] data_out;

  reg [7:0] mem [0:7];



always@(posedge clk)
begin
  if(write)
    begin
      mem[addres]=data_in;
   end
 if(read) 
 begin
 data_out=mem[addres];
 end

end
endmodule
