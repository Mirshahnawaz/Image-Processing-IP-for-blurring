`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/01/2023 12:13:50 AM
// Design Name: 
// Module Name: imageControl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module imageControl(
input                    i_clk,
input                    i_rst,
input [7:0]              i_pixel_data,
input                    i_pixel_data_valid,
output reg [71:0]        o_pixel_data,
output                   o_pixel_data_valid,
output reg               o_intr
);

//PARAMETERS
parameter bufferSize = 512;         //Image dimensions 512 x 512
parameter pixelCounterwidth = $clog2(bufferSize);
parameter total_pixel = bufferSize * 4; //total pixels saved in four lineBuffers
parameter total_pixel_three_buffers = bufferSize * 3; //total pixels saved in three lineBuffers
parameter totalPixelCounterwidth = $clog2(total_pixel); // in how many bits total pixels encoded



reg [pixelCounterwidth-1:0] pixelCounter; //this is counter for counting the pixels coming to the lineBuffers and it used to switch the lineBuffer when 1 lineBuffer gets full then we start writing to the other lineBuffer the 2bit register currentWrLineBuffer is modified just because of the pixelCounter
reg [1:0] currentWrLineBuffer; // this is a 2bit register used for controlling the lineBuffDataValid signal (write signal for lineBuffers)
reg [3:0] lineBuffDataValid; //its a write signal for lineBuffers if it is enabled for lineBuffer then we are able to write that buffer it is handled by the currentWrLineBuffer register it has width of 2bits
reg [3:0] lineBuffRdData;   //its a read signal for lineBuffers if it is enabled for lineBuffer then we are able to read that buffer it is handled by the currentRdLineBuffer register it has width of 2bits
reg [1:0] currentRdLineBuffer; // this is a 2bit register used for controlling the lineBuffRdData signal (read signal for lineBuffers)
wire [23:0] lb0data; // Output of 0th lineBuffer
wire [23:0] lb1data; // Output of 1th lineBuffer
wire [23:0] lb2data; // Output of 2nd lineBuffer            //NOTE: WE ONLY READ 3 lineBuffers at a time and get 72 bits at the output at one time
wire [23:0] lb3data; // Output of 3rd lineBuffer
reg [pixelCounterwidth-1:0] rdCounter; //this is counter for counting the pixels that are read from the lineBuffers and it is used to help us in reading the 3 lineBuffers in parallel the 2bit register currentRdLineBuffer is modified just because of the rdCounter
reg rd_line_buffer; //its a read signal it is enabled when we are reading the data
reg [totalPixelCounterwidth:0] totalPixelCounter;
reg rdState;






localparam IDLE = 'b0,
           RD_BUFFER = 'b1;

assign o_pixel_data_valid = rd_line_buffer;

//THIS LOGIC IS FOR COUNTING THE TOTAL NUMBER OF PIXELS WHEN RESET SIGNAL COMES totalPixelCounter BECOMES 0 WHEN THERE ARE PIXELS
// COMING AS AN INPUT(i_pixel_data_valid)AND THERE IS NO PIXELS ARE READING (!rd_line_buffer) SO totalPixelCounter WILL BE INCREAMENTED BY 1
// WHEN THERE IS NO PIXEL COMING (!i_pixel_data_valid) AND THE PIXELS ARE READ (rd_line_buffer) THEN totalPixelCounter WILL
// DECREMENTED.

always @(posedge i_clk)
begin
    if(i_rst)
        totalPixelCounter <= 0;
    else
    begin
        if(i_pixel_data_valid & !rd_line_buffer)
            totalPixelCounter <= totalPixelCounter + 1;
        else if(!i_pixel_data_valid & rd_line_buffer)
            totalPixelCounter <= totalPixelCounter - 1;
    end
end

always @(posedge i_clk)
begin
    if(i_rst)
    begin
        rdState <= IDLE;
        rd_line_buffer <= 1'b0;
        o_intr <= 1'b0;
    end
    else
    begin
        case(rdState)
            IDLE:begin
                o_intr <= 1'b0;
                if(totalPixelCounter >= total_pixel_three_buffers)
                begin
                    rd_line_buffer <= 1'b1;
                    rdState <= RD_BUFFER;
                end
            end
            RD_BUFFER:begin
                if(rdCounter == bufferSize - 1)
                begin
                    rdState <= IDLE;
                    rd_line_buffer <= 1'b0;
                    o_intr <= 1'b1;
                end
            end
        endcase
    end
end
    
always @(posedge i_clk)
begin
    if(i_rst)
        pixelCounter <= 0;
    else 
    begin
        if(i_pixel_data_valid)
            pixelCounter <= pixelCounter + 1;
    end
end

//DEMULTIPLEXER LOGIC

//currentWrLineBuffer THIS IS A 2bit REGISTER AND IT DEPENDS ON pixelCounter register and i_pixel_data SIGNAL AND WHEN pixelCounter reaches to bufferSize 
//ANOTHER PIXEL COMING THEN currentWrLinebuffer CHANGES BY INCREAMENT OF 1 (currentWrLineBuffer+1)
always @(posedge i_clk)
begin
    if(i_rst)
        currentWrLineBuffer <= 0;
    else
    begin
        if(pixelCounter == bufferSize -1  & i_pixel_data_valid)
            currentWrLineBuffer <= currentWrLineBuffer+1;
    end
end

// HERE IS THE LOGIC OF DATA_VALID SIGNALS FOR LINE BUFFERS HERE WE USE lineBufferValid REGISTER HAVE WIDTH OF 4bits WHICH DEPENDS ON currentWrLineBuffer WHOSE LOGIC
// IS MENTIONED ABOVE 
always @(*)
begin
    lineBuffDataValid = 4'h0;
    lineBuffDataValid[currentWrLineBuffer] = i_pixel_data_valid;
end

always @(posedge i_clk)
begin
    if(i_rst)
        rdCounter <= 0;
    else 
    begin
        if(rd_line_buffer)
            rdCounter <= rdCounter + 1;
    end
end

always @(posedge i_clk)
begin
    if(i_rst)
    begin
        currentRdLineBuffer <= 0;
    end
    else
    begin
        if(rdCounter == bufferSize - 1 & rd_line_buffer)
            currentRdLineBuffer <= currentRdLineBuffer + 1;
    end
end


always @(*)
begin
    case(currentRdLineBuffer)
        0:begin
            o_pixel_data = {lb2data,lb1data,lb0data};
        end
        1:begin
            o_pixel_data = {lb3data,lb2data,lb1data};
        end
        2:begin
            o_pixel_data = {lb0data,lb3data,lb2data};
        end
        3:begin
            o_pixel_data = {lb1data,lb0data,lb3data};
        end
    endcase
end





//THIS LOGIC IS FOR MULTIPLEXER BECAUSE WE HAVE TO READ DATA FROM 3 LINEBUFFERS AT THE SAME TIME(PARALLEL) SO WITH THIS MULTIPLEXE 
// IT DECIDES FROM WHICH 3 LINE BUFFERS WE SHOULD READ THE PIXEL DATA e.g (WE SHOULD FIRST READ lineBuffer0,lineBuffer1,lineBuffer2
// then we should read lineBuffer1,lineBuffer2,lineBuffer3 then we should read lineBuffer2,lineBuffer3,lineBuffer0)

always @(*)
begin
    case(currentRdLineBuffer)
        0:begin
            lineBuffRdData[0] = rd_line_buffer;
            lineBuffRdData[1] = rd_line_buffer;
            lineBuffRdData[2] = rd_line_buffer;
            lineBuffRdData[3] = 1'b0;
        end
       1:begin
            lineBuffRdData[0] = 1'b0;
            lineBuffRdData[1] = rd_line_buffer;
            lineBuffRdData[2] = rd_line_buffer;
            lineBuffRdData[3] = rd_line_buffer;
        end
       2:begin
             lineBuffRdData[0] = rd_line_buffer;
             lineBuffRdData[1] = 1'b0;
             lineBuffRdData[2] = rd_line_buffer;
             lineBuffRdData[3] = rd_line_buffer;
       end  
      3:begin
             lineBuffRdData[0] = rd_line_buffer;
             lineBuffRdData[1] = rd_line_buffer;
             lineBuffRdData[2] = 1'b0;
             lineBuffRdData[3] = rd_line_buffer;
       end        
    endcase
end
    
lineBuffer lB0(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_data(i_pixel_data),
    .i_data_valid(lineBuffDataValid[0]),
    .o_data(lb0data),
    .i_rd_data(lineBuffRdData[0])
 ); 
 
 lineBuffer lB1(
     .i_clk(i_clk),
     .i_rst(i_rst),
     .i_data(i_pixel_data),
     .i_data_valid(lineBuffDataValid[1]),
     .o_data(lb1data),
     .i_rd_data(lineBuffRdData[1])
  ); 
  
  lineBuffer lB2(
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_data(i_pixel_data),
      .i_data_valid(lineBuffDataValid[2]),
      .o_data(lb2data),
      .i_rd_data(lineBuffRdData[2])
   ); 
   
   lineBuffer lB3(
       .i_clk(i_clk),
       .i_rst(i_rst),
       .i_data(i_pixel_data),
       .i_data_valid(lineBuffDataValid[3]),
       .o_data(lb3data),
       .i_rd_data(lineBuffRdData[3])
    );    
    
endmodule