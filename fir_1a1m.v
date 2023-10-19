module fir_1a1m (
    input clk,
    input reset,
    input wire [31:0] x,
    input wire [31:0] coe,
    input wire valid, //when new coe & x has came
    output reg [31:0] y,
    output wire done //when new y is generated
);

reg [3:0] counter15;
//reg [31:0] accu;

assign done = (counter15 == 11)? 1 : 0;
//assign y = (counter15 == 11)? accu : 0;

always@(posedge clk or negedge reset)begin
    if(!reset)begin
        counter15 <= 0;
    end
    else begin
        if(valid)begin
            if(counter15 < 12) counter15 <= counter15 + 1;
            else if (counter15 >= 12) counter15 <= 0;
        end
        else counter15 <= 0;

    end
end
    
// always@(posedge clk or negedge reset)begin
//     if(!reset)begin
//         accu <= 0;
//     end
//     else begin
//         if (valid)begin
//             if (!done) accu <= accu + (x * coe);
//             else if (done) accu <= 0;
//         end
//     end
// end

always@(posedge clk or negedge reset)begin
    if(!reset)begin
        y <= 0;
    end
    else begin
        if (valid)begin
            if (!done) y <= y + (x * coe);
            else if (done) y <= 0;
        end
    end
end













endmodule