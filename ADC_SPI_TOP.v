

`timescale 1ns / 1ps

module NRG1_ADC_SPI_master  #(parameter 
	     HIGH_TIME=10'd12,
	     LOW_TIME =10'd13)
(
//////////////input output declaration////////////////
input CLK,
input RST,
output MOSI,SCLK,CS,
input MISO,
input [15:0]config_data,             //ADC configuration data
output [15:0]sample_data            //sampled data from ADC
);            
///////////////////////////////////////////////////////



/////////////////////internal registers////////////////////////////
reg [15:0]rx_reg_temp;
reg MOSI_i;
reg [4:0]cycle;
reg [1:0]state;
reg [4:0]cycle1;
reg SCLK_i;
reg [3:0]clock_counter_5MHZ;
reg CS_i;
reg [4:0]delay_counter;
reg sclk_low_sync;

reg sclk_low;
wire sclk_pos_edge;
wire sclk_neg_edge;
reg [9:0] h_count;
reg [9:0] l_count;
reg sclk_high;
wire [15:0]config_data_i;
reg [15:0]mode_cntrl_reg;
reg [15:0]rx_temp_reg_i;
//////////////////////////////////////////////////////////////////

//////////////////////SCLK clock generation logic////////////////
always @(posedge CLK or negedge RST) begin 
	if (!RST) begin 
	   sclk_low_sync<=0;
           
	end
	else begin 
         sclk_low_sync<=sclk_low;
	 
	end 
end 
 assign sclk_pos_edge= sclk_low & ~sclk_low_sync;
 assign sclk_neg_edge=~sclk_low & sclk_low_sync;

always @(posedge CLK or negedge RST) begin 
	if (!RST) begin 
 		h_count<=0;
		l_count<=0;	
	end

	else if (  sclk_low==1'b0) begin
               h_count<=h_count+1'b1;
               l_count<=0;
       end
       else if ( sclk_high==1'b0) begin
               l_count<=l_count+1'b1;
               h_count<=0;
       end
       else begin 
	       h_count<=0;
               l_count<=0;
       end 	       
end 

always @(posedge CLK or negedge RST)begin 

	if (!RST) begin 
		sclk_high<=1'b1;
		sclk_low<=1'b0;
	end 
	else if ( h_count==HIGH_TIME-1) begin 
		     sclk_high<=1'b0;
		     sclk_low<=1'b1;
	     end 
	else if ( l_count==LOW_TIME-1)begin
		     sclk_high<=1;
		     sclk_low<=0;
        end
end 

/////////////////////////////////////////////////////////////////
assign config_data_i=config_data;


always @(posedge CLK or negedge RST) 
 begin
      if(!RST) begin
            MOSI_i<=1'b0;
            state<=2'b00;
            cycle<=5'b0;
            CS_i<=1'b1;
            delay_counter<=5'b0;
            mode_cntrl_reg<=16'h0000;
           end
         else 
              begin   
            case(state)  
     2'b00: begin                                            //state 0                                        
                 if (sclk_low==1'b1 && cycle!=0 )           // Serial transmission 16 bit ADC configuration data 
                       SCLK_i<=1'b1;
        	     else
		          SCLK_i<=1'b0;
                 if(sclk_neg_edge==1'b1) begin
                     CS_i<=1'b0;      
                     if(cycle==16)  begin
                       state<=2'b01;
                       end
                   else  begin    
                        MOSI_i<=config_data_i[10'd15-cycle];
                        cycle<=cycle+1;
                         state<=2'b00;  end 
                            end
              end
           
       2'b01:    begin                                      //state 1
                  if(delay_counter<31) begin                //delay generation logic for optimum CS pulse width
                        delay_counter<=delay_counter+1;
                        state<=2'b01;
                        end
                    else
                        delay_counter<=4'b0;    
                 if(delay_counter==5'b01111 ) 
                  begin
                        CS_i<=1'b1; 
                        cycle<=5'b00000;
                    end    
                  else if(delay_counter==5'b11111)
                       begin
                           state<=2'b10;     
                       end
                end       
      2'b10: begin                                           //state 2
                 if (sclk_low==1'b1 && cycle!=0 )            // 16 bit dummy data transmission
                          SCLK_i<=1'b1;
        	     else
		                 SCLK_i<=1'b0;
 
                 if(sclk_neg_edge==1'b1) begin
                     CS_i<=1'b0;      
                     if(cycle==16)  begin
                       state<=2'b11;
                       end
                   else  begin    
                        MOSI_i<=mode_cntrl_reg[10'd15-cycle];
                        cycle<=cycle+1;
                         state<=2'b10;  end 
                            end
              end
           
       2'b11:    begin                                      //state3
                  if(delay_counter<31) begin                //delay generation logic for optimum CS pulse width
                        delay_counter<=delay_counter+1;
                        state<=2'b11;
                        end
                    else
                        delay_counter<=4'b0;    
                 if(delay_counter==5'b01111 ) 
                  begin
                        CS_i<=1'b1; 
                        cycle<=5'b00000;
                    end    
                  else if(delay_counter==5'b11111)
                       begin
                           state<=2'b00;     
                       end
                end 
             default: state<=2'b00;
            endcase 
           end 
        end  
     

  
      always @(posedge CLK or negedge RST)
      begin     
       if(!RST)
       begin
            cycle1<=4'b0;
            rx_reg_temp<=0;

       end
       else 
        begin                                                  //logic to read data after sampling and conversion of analog signal 

                if (CS_i == 1'b1) begin
                       cycle1<=0;
                       if(rx_reg_temp [15:12] == config_data_i[10:7]) 
                            begin
                             rx_temp_reg_i <= rx_reg_temp;       
                             end      
                      end   
                  else 
                       begin
                       if(sclk_neg_edge==1'b1) begin 
                          if(cycle1==16) begin
                           cycle1<=0;              
                           end
                          else
                            begin
                            rx_reg_temp[10'd15-cycle1]<=MISO;
                            cycle1<=cycle1+1; 
                            end 
                         end              
                     end
                   end                         
               
                         

         end                          

     assign MOSI=MOSI_i;
     assign SCLK=SCLK_i;
     assign CS=CS_i;
     assign sample_data=rx_temp_reg_i;



  endmodule
