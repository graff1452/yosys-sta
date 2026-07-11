module counter
(
    input clk,
    input rst,
    input en,
    output reg [1:0] count
);
    always @(posedge clk) 
    begin
        if (rst) 
        begin
            count <= 2'd0;
        end
        else if (en) 
        begin
            count <= count + 2'd1;
        end
    end
endmodule
