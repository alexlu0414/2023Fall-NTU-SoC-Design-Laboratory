module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,


    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,   



    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 

    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);
begin

    // write your code here!
// bram11 tap_RAM (
//         .CLK(axis_clk),
//         .WE(tap_WE),
//         .EN(tap_EN),
//         .Di(tap_Di),
//         .A(tap_A),
//         .Do(tap_Do)
//     );

// bram11 data_RAM(
//         .CLK(axis_clk),
//         .WE(data_WE),
//         .EN(data_EN),
//         .Di(data_Di),
//         .A(data_A),
//         .Do(data_Do)
//     );

wire fir_valid, fir_done;
wire [31:0] fir_y;
fir_1a1m fir_block(
    .clk(axis_clk),
    .reset(axis_rst_n),
    .x(data_Do),
    .coe(tap_Do),
    .valid(fir_valid), //when new coe & x has came
    .y(fir_y),
    .done(fir_done) //when new y is generated
);


reg [7:0] axilite_reg [0:127]; //1 byte x 0xFF
reg [pADDR_WIDTH-1 : 0] axilite_reg_addr;
reg [pDATA_WIDTH-1 : 0] axilite_reg_data;

parameter IDLE = 3'b000;
parameter RADDR = 3'b001;
parameter RDATA = 3'b010;
parameter WADDR = 3'b011;
parameter WDATA = 3'b100;
parameter BLANK = 3'b101;

parameter LOAD = 3'b001;
parameter CAL = 3'b010;

reg [2:0] axi_lite_current_state, axi_lite_next_state;
reg [31:0] data_length;
reg tap_load;
reg [2:0] fir_cs, fir_ns;

wire ap_start;
assign ap_start = axilite_reg[0][0];


//////////////////////// fir control /////////////////////////////////////////////////
assign fir_valid = (fir_cs == CAL)? 1 : 0;

always@(posedge axis_clk or negedge axis_rst_n)begin  //fir_cs
    if(!axis_rst_n)begin
        fir_cs <= 0;
    end
    else begin
        fir_cs <= fir_ns;
    end
end

always@(*)begin                     //fir_ns
    if(!axis_rst_n) fir_ns <= 0;
    else begin
        case(fir_cs)
            IDLE : begin
                if (ap_start) fir_ns = LOAD;
                else fir_ns = IDLE;
            end
            LOAD : fir_ns = CAL;
            CAL : begin
                if (fir_done) fir_ns = LOAD;
                else fir_ns = CAL;
            end
            default : fir_ns = fir_cs;
        endcase
    end
end


///////////////////////////// AXI Stream ////////////////////////////////////
reg ss_tready_r;
assign ss_tready = ss_tready_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //ss_tready
    if(!axis_rst_n)begin
        ss_tready_r <= 0;
    end
    else begin
        if(!axilite_reg[0][2] && (fir_cs == LOAD)) ss_tready_r <= 1;
        else ss_tready_r <= 0;
    end
end

assign sm_tlast = (sm_tvalid && data_length == 1)? 1 : 0;
assign sm_tdata = fir_y;
// reg [31:0] sm_tdata_r;
// assign sm_tdata = sm_tdata_r;
// always@(posedge axis_clk or negedge axis_rst_n)begin //sm_tdata
//     if(!axis_rst_n)begin
//         sm_tdata_r <= 0;
//     end
//     else begin
//         if(fir_done) sm_tdata_r <= fir_y;
//         else sm_tdata_r <= sm_tdata_r;
//     end
// end

assign sm_tvalid = (fir_done)? 1 : 0;
// reg sm_tvalid_r;
// assign sm_tvalid = sm_tvalid_r;
// always@(posedge axis_clk or negedge axis_rst_n)begin //sm_tvalid
//     if(!axis_rst_n)begin
//         sm_tvalid_r <= 0;
//     end
//     else begin
//         if(fir_done) sm_tvalid_r <= 1;
//         else sm_tvalid_r <= 0;
//     end
// end

/////////////////////////////////////////////////////////////////////////////
//////////////////////////////////// data bram /////////////////////////////////////////
reg data_EN_r;
assign data_EN = data_EN_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //data_EN
    if(!axis_rst_n)begin
        data_EN_r <= 0;
    end
    else begin
        if(fir_ns == LOAD || tap_load) data_EN_r <= 1;
    end
end

reg [3:0] data_WE_r;
assign data_WE = data_WE_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //data_WE
    if(!axis_rst_n)begin
        data_WE_r <= 0;
    end
    else begin
        if(fir_ns == LOAD || tap_load) data_WE_r <= 4'b1111;
        else data_WE_r <= 0;
    end
end

reg [11:0] data_A_r;
assign data_A = data_A_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //data_A
    if(!axis_rst_n)begin
        data_A_r <= 0;
    end
    else begin
        if(tap_load && bram_w_counter[0]) begin
            if(data_A_r > 40)begin
                data_A_r <= 0;
            end
            else data_A_r <= data_A_r + 4; //when tap_load, data bram initialize 
        end
        else begin
            if (fir_ns == LOAD) begin
                data_A_r <= data_A_old;
            end
            else if (fir_ns == CAL) begin
                if(data_A_r <= 0)begin
                    data_A_r <= 40;
                end
                else data_A_r <= data_A_r - 4; 
            end

        end

    end
end

reg [11:0] data_A_old;
always@(posedge axis_clk or negedge axis_rst_n)begin //data_A_old
    if(!axis_rst_n)begin
        data_A_old <= 0;
    end
    else begin
        if (fir_cs == LOAD) begin
            if(data_A_old >= 40)begin
                data_A_old <= 0;
            end
            else data_A_old <= data_A_old + 4; 
        end
    end
end

reg [31:0] data_Di_r;
assign data_Di = data_Di_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //tap_Di
    if(!axis_rst_n)begin
        data_Di_r <= 0;
    end
    else begin
        if(fir_ns == LOAD) data_Di_r <= ss_tdata;
        else data_Di_r <= 0;
    end
end

///////////////////////////////////////////////////////////////////////////////
//////////////////////////////////// tap bram /////////////////////////////////////////
reg [1:0] bram_w_counter;
reg load_finish;
always@(posedge axis_clk or negedge axis_rst_n)begin //bram_w_counter (for bram write)
    if(!axis_rst_n)begin
        bram_w_counter <= 0;
    end
    else begin
        if(tap_load || fir_cs == LOAD) bram_w_counter <= bram_w_counter + 1; 
    end
end

always@(posedge axis_clk or negedge axis_rst_n)begin //tap_load (flag for tap bram input)
    if(!axis_rst_n)begin
        tap_load <= 0;
    end
    else begin
        if(arvalid && rready) begin //the start of coef check
            if(tap_A <= 12'h028 && load_finish == 0) begin
                tap_load <= 1; 
            end
            else tap_load <= 0;
        end

        
    end
end

reg tap_EN_r;
assign tap_EN = tap_EN_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //tap_EN
    if(!axis_rst_n)begin
        tap_EN_r <= 0;
    end
    else begin
        if(tap_load) tap_EN_r <= 1;
    end
end

reg [3:0] tap_WE_r;
assign tap_WE = tap_WE_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //tap_WE
    if(!axis_rst_n)begin
        tap_WE_r <= 0;
    end
    else begin
        if(tap_load) tap_WE_r <= 4'b1111;
        else tap_WE_r <= 0;
    end
end

reg [11:0] tap_A_r;
assign tap_A = tap_A_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //tap_A
    if(!axis_rst_n)begin
        tap_A_r <= 0;
        load_finish <= 0;
    end
    else begin
        if(tap_load && bram_w_counter[0] == 1 || fir_ns == CAL) begin
            if(tap_A_r > 40)begin
                tap_A_r <= 0;
                load_finish <= 1;
            end
            else tap_A_r <= tap_A_r + 4;
        end
        else tap_A_r <= tap_A_r;
    end
end

reg [31:0] tap_Di_r;
assign tap_Di = tap_Di_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //tap_Di
    if(!axis_rst_n)begin
        tap_Di_r <= 0;
    end
    else begin
        if(tap_load && bram_w_counter[0] == 1) tap_Di_r <= {axilite_reg[12'h20 + tap_A + 7], axilite_reg[12'h20 + tap_A + 6], axilite_reg[12'h20 + tap_A + 5], axilite_reg[12'h20 + tap_A + 4]};
    end
end

///////////////////////////////////////////////////////////////////////////////
always@(posedge axis_clk or negedge axis_rst_n)begin //data_length
    if(!axis_rst_n)begin
        data_length <= 0;
    end
    else begin
        if(fir_cs != IDLE)begin
            if (fir_done) data_length <= data_length -1;

            
        end
        else data_length <= {axilite_reg[19], axilite_reg[18], axilite_reg[17], axilite_reg[16]};
    end
end


// always@(posedge axis_clk or negedge axis_rst_n)begin  //lite current state
//     if(!axis_rst_n)begin
//         axi_lite_current_state <= 0;
//     end
//     else begin
//         axi_lite_current_state <= axi_lite_next_state;
//     end
// end

// always@(*)begin                     //lite next state
//     if(!axis_rst_n) axi_lite_next_state <= 0;
//     else begin
//         case(axi_lite_current_state)
//             //IDLE : axi_lite_next_state = (awvalid) ? WADDR : (arvalid) ? RADDR : IDLE;
//             IDLE : axi_lite_next_state = WADDR;
//             RADDR : if (arvalid && arready) axi_lite_next_state = RDATA;
//             RDATA : if (rvalid  && rready ) axi_lite_next_state = IDLE;
//             WADDR : if (awvalid && awready) axi_lite_next_state = WDATA;
//             WDATA : if (wvalid  && wready ) axi_lite_next_state = IDLE;
//             default : axi_lite_next_state = IDLE;
//         endcase
//     end
// end


reg awready_r;
assign awready = awready_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //reg_adder & awready
    if(!axis_rst_n)begin
        axilite_reg_addr <= 0;
        awready_r <= 0;
    end
    else begin
        //if(axi_lite_current_state == WADDR)begin
        if(awvalid)begin
            axilite_reg_addr <= awaddr;
            awready_r <= ~awready_r;
        end
        else begin
            awready_r <= 0;
        end
    end
end

reg wready_r;
assign wready = wready_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //wready
    if(!axis_rst_n)begin
        wready_r <= 0;
    end
    else begin
        if(wvalid)begin
            wready_r <= ~wready_r;
        end
        else begin
        end
    end
end

always@(posedge axis_clk or negedge axis_rst_n)begin //reg_data 
    if(!axis_rst_n)begin
        axilite_reg_data <= 0;
    end
    else begin
        if(wvalid == 1)begin
            axilite_reg_data <= wdata;
        end
        else begin
        end
    end
end

integer i;
always@(posedge axis_clk or negedge axis_rst_n)begin //axireg 
    if(!axis_rst_n)begin
        for(i = 1; i <= 127; i = i + 1)begin
            axilite_reg[i] <= 0;
        end
        axilite_reg[0] <= 8'b00000100; //ap_idle = 1
    end
    else begin
        //if(axi_lite_current_state == WDATA && wvalid == 1)begin
        if(wvalid == 1)begin
            // axilite_reg[axilite_reg_addr] <= wdata[7:0];
            // axilite_reg[axilite_reg_addr + 1] <= wdata[15:8];
            // axilite_reg[axilite_reg_addr + 2] <= wdata[23:16];
            // axilite_reg[axilite_reg_addr + 3] <= wdata[31:23];
            axilite_reg[awaddr] <= wdata[7:0];
            axilite_reg[awaddr + 1] <= wdata[15:8];
            axilite_reg[awaddr + 2] <= wdata[23:16];
            axilite_reg[awaddr + 3] <= wdata[31:23];
        end
        else begin
            if(ap_start == 1)begin
                axilite_reg[0] <= 0;
            end
            else if(axilite_reg[0][2:0] == 3'b010 && rvalid)begin
                axilite_reg[0][2:0] <= 3'b100;
            end
            else if (data_length == 0 && axilite_reg[0][2:0] == 3'b000)begin    // done = 1 for 1 cycle
                axilite_reg[0][2:0] <= 3'b010;
            end
        end
    end
end

reg arready_r;
assign arready = arready_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //arready
    if(!axis_rst_n)begin
        arready_r <= 0;
    end
    else begin
        if(arvalid && !rvalid)begin
            arready_r <= ~arready_r;
        end
        else begin
            arready_r <= 0;
        end
    end
end

reg [pDATA_WIDTH-1 : 0] rdata_r;
assign rdata = rdata_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //rdata
    if(!axis_rst_n)begin
        rdata_r <= 0;
    end
    else begin
        if(arvalid && arready)begin
            rdata_r <= {axilite_reg[araddr + 3], axilite_reg[araddr + 2], axilite_reg[araddr + 1], axilite_reg[araddr]};
        end
        else begin
        end
    end
end

reg rvalid_r;
assign rvalid = rvalid_r;
always@(posedge axis_clk or negedge axis_rst_n)begin //rvalid
    if(!axis_rst_n)begin
        rvalid_r <= 0;
    end
    else begin
        if(arvalid && arready)begin
            rvalid_r <= 1;
        end
        else begin
            rvalid_r <= 0;
        end
    end
end

end
endmodule