
 module myI2STx_v1_0 #
    (
        // Users to add parameters here
      // Users to add parameters here

        // User parameters ends
        // Do not modify the parameters beyond this line


        // Parameters of Axi Slave Bus Interface S00_AXIS
        parameter integer C_S00_AXIS_TDATA_WIDTH    = 32
    )
    (
        // I2S Interface
        input mclk,
        output  bclk,
        output reg lrclk,
        output reg sdata = 0,

        // User ports ends
        // Do not modify the ports beyond this line


        // Ports of Axi Slave Bus Interface S00_AXIS
        input wire  s00_axis_aclk,
        input wire  s00_axis_aresetn,
        output reg  s00_axis_tready = 0,
        input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
        //input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb,
        input wire  s00_axis_tlast,
        input wire  s00_axis_tvalid
    );

    reg [31:0]shiftreg;
    reg [4:0]bitcounter;
    reg [2:0] state;
    wire [1:0]clk_div;
    reg [31:0] buffer;
    reg bufvalid;

    wire clk_12_28MHz;

    localparam S0 = 0;
    localparam S1 = 1;
    localparam S2 = 2;
    localparam S3 = 3;
    localparam S4 = 4;

//  clk_wiz_0 clk1
//  (
//  .clk_out1(clk_12_28MHz),
//  .clk_in1(s00_axis_aclk)
//  );

  c_counter_binary_0 bclk_div (
  .CLK(mclk),  // input wire CLK
  .Q(clk_div)      // output wire [1 : 0] Q
);
reg [1:0]bclk_sysc;
wire bclk_neg;

  assign bclk=clk_div[1];
always@(posedge s00_axis_aclk or negedge s00_axis_aresetn) begin
    if (s00_axis_aresetn==1'b0) begin
       bclk_sysc[0]<=1;
       bclk_sysc[1]<=1;
    end
    else begin
       bclk_sysc[0]<=clk_div[1];
       bclk_sysc[1]<=bclk_sysc[0];
    end
end
assign bclk_neg= ~bclk_sysc[0] & bclk_sysc[1];

    always @(posedge s00_axis_aclk or negedge s00_axis_aresetn )
     begin  
     if( s00_axis_aresetn==0)
     begin
        bufvalid <= 0;
        buffer<=32'b0;
     end
     else
     begin 
         if (bufvalid==0 && s00_axis_tready==0)
        begin
            buffer <= 32'b0;
            bufvalid <= 1'b0;
            s00_axis_tready <= 1;
        end else if (bufvalid==0 && s00_axis_tready==1 && s00_axis_tvalid==1) begin
            s00_axis_tready <= 0;
            buffer <= s00_axis_tdata;
            bufvalid <= 1'b1;
        end
        else if (bitcounter==5'd30 && bclk_neg==1'b1 && lrclk==1'b1)
                bufvalid<=1'b0;
      end
     end 
    always @(negedge bclk or negedge s00_axis_aresetn)
     begin
     if(s00_axis_aresetn==0)
     begin 
        state<=3'b0;
        bitcounter<=5'b0;
        shiftreg<=32'b0;
      end
      else
        begin  
            case(state)
                S0:     begin
                            if (bufvalid==1) begin
                                //bufvalid <= 0;
                                bitcounter <= 5'd0;
                                lrclk <= 0;

                                sdata <= 0;
                                state <= S1;
                                shiftreg <= {buffer[31:16],16'd0};
          
                            end
                        end
                S1:     begin
                           //if (bclk_neg==1'b1) begin
                            sdata <=shiftreg[31];
                            shiftreg<={shiftreg[30:0],1'b1};
                            bitcounter <= bitcounter+1;
                              if(bitcounter==5'd31 && lrclk==0) begin
                                  state <= S1;
                                  bitcounter<=0;
                                  lrclk<=~lrclk;
                                  shiftreg<={buffer[15:0],16'd1};               
                              end
                              else if (bitcounter==5'd31 && lrclk==1) begin
                                  state <= S1;
                                  bitcounter<=0;
                                  lrclk<=~lrclk;
                                  shiftreg<={buffer[31:16],16'd1};
                              end
                            end
//                      S2: begin
//                             shiftreg<=buffer;
//                               state <= S1;
//                           end

                default:begin
                            state <= S0;
                        end
            endcase
        end
     end

    endmodule