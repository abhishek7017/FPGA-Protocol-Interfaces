

`timescale 1ns / 1ps

 
 module NRG1_DAC_SPI_master #(parameter 
	     HIGH_TIME=10'd10,           
	     LOW_TIME =10'd10)           
	                                 
 (                                                
input           CLK,                                  
input           RST,                    
input [3:0]     config_data,             
input [15:0]    sample_data,            
output          MOSI,
output          SCLK,
output          CS,
input           in_pwm,
output          LDAC

);

/////////////////internal_registers//////////////

reg         MOSI_i;
reg [4:0]   cycle;
reg [1:0]   state;
reg         SCLK_i;
reg         CS_i;
reg [4:0]   delay_counter;
reg         sclk_low_sync;
reg         sclk_low_sync1;

reg         pwm_sync;
reg         pwm_sync_1;


reg         sclk_low;
reg [9:0]   h_count;
reg [9:0]   l_count;
reg         sclk_high;
reg [15:0]  spi_frame;

wire        sclk_pos_edge;
wire        sclk_neg_edge;

wire        pwm_pos_edge;
wire        pwm_neg_edge;

wire [15:0] sample_data_i;



reg pwm_posedge_flag,pwm_negedge_flag;
reg spi_done;

/////////////////SCL_clock_generation_logic////////////////////////

always @(posedge CLK or negedge RST)begin
    if(RST == 1'b0)begin
        pwm_posedge_flag <= 1'b0;
        pwm_negedge_flag <= 1'b0;
 
    end else begin
        if(spi_done==1'b0)
        begin
         if(pwm_pos_edge == 1'b1)begin
            pwm_posedge_flag <= 1'b1;
            pwm_negedge_flag <= 1'b0;
           end
          else if(pwm_neg_edge == 1'b1)begin
            pwm_posedge_flag <= 1'b0;
            pwm_negedge_flag <= 1'b1;       
          end 
          end
        else if(spi_done == 1'b1)begin
            if(pwm_posedge_flag == 1'b1)begin
                pwm_posedge_flag <= 1'b0;
            end else if(pwm_negedge_flag == 1'b1)begin
                pwm_negedge_flag <= 1'b0;

            end
        end 
    
    end
end


always @(posedge CLK or negedge RST)
 begin 
	if (RST==1'b0)
	 begin 
	       sclk_low_sync<=0;
           sclk_low_sync1<=0;	   
	end
	else 
 	begin 
        	 sclk_low_sync<=sclk_low;
	         sclk_low_sync1<=sclk_low_sync;
	end 
end 
 assign sclk_pos_edge= sclk_low & ~sclk_low_sync;
 assign sclk_neg_edge=~sclk_low & sclk_low_sync;

always @(posedge CLK or negedge RST)
 begin 
	if (RST==1'b0) 
	begin 
 		h_count<=0;
		l_count<=0;	
	end

	else if ( sclk_low==1'b0)
	 begin
               h_count<=h_count+1'b1;
               l_count<=0;
       	 end
       else if ( sclk_high==1'b0) 
		begin
              	 	l_count<=l_count+1'b1;
               		h_count<=0;
       		end
 	    else 
		begin 
	       		h_count<=0;
           		l_count<=0;
       		end 	       
end 

always @(posedge CLK or negedge RST)
begin 
	if (RST==1'b0) 
	begin 
		sclk_high<=1'b1;
		sclk_low<=1'b0;
	end 
	else if ( h_count==HIGH_TIME-1) 
	begin 
		     sclk_high<=1'b0;
		     sclk_low<=1'b1;
	 end 
	else if ( l_count==LOW_TIME-1)
	begin
		     sclk_high<=1;
		     sclk_low<=0;
        end
end 


always @(posedge CLK or negedge RST)
 begin 
	if (RST==1'b0)
	 begin 
	   pwm_sync<= 1'b0;
       pwm_sync_1<= 1'b0;	   
	end
	else 
 	begin 
        pwm_sync<=in_pwm;
	    pwm_sync_1<=pwm_sync;
	end 
end 
 assign pwm_pos_edge= in_pwm & ~pwm_sync;
 assign pwm_neg_edge= ~in_pwm & pwm_sync;
 
 
// always @(posedge CLK or negedge RST)
// begin 
//	if (RST==1'b0)
//	 begin 
//	   mod_sync<= 1'b0;
//       mod_sync_1<= 1'b0;	   
//	end
//	else 
// 	begin 
//       mod_sync<=mod_pwm;
//	   mod_sync_1<=mod_sync;
//	end 
//end 

// assign mod_pos_edge= mod_sync & ~mod_sync_1;
// assign mod_neg_edge= ~mod_sync & mod_sync_1;
 
///////////////////////////////////////////////////////////////

assign sample_data_i=sample_data;




 always @(posedge CLK or negedge RST) 
 begin
      if(RST==1'b0) 
	begin
        	    MOSI_i<=1'b0;
            	state<=2'b0;
                cycle<=5'd0;
                CS_i<=1'b1;
                delay_counter<=5'd0;
                spi_frame<=16'h0;
                spi_done <= 1'b0;
        end
        
      else 
         begin  
    	case(state) 
 ////////SPI frame generation logic///////
      2'b00: begin                                      
              MOSI_i<=1'b0;
              delay_counter<=5'd0;  
              spi_done <= 1'b0;                           //DATA_frame=16 bits ,it includes (4 bit DAC configuration bits + 12 sampled data bits) 
              if ( pwm_posedge_flag || pwm_negedge_flag)                                      
		     begin  
              		spi_frame<={config_data,sample_data_i[11:0]};
              		state<=2'b01;             			 
	         end

	         else    	                 
	                 state<=2'b00;
	       end

 ///////SPI frame transfer logic//////////                   
     2'b01: begin 
                 if (sclk_low==1'b1 && cycle!=0 )         
                          SCLK_i<=1'b1;
        	     else                                      //DATA transfer takes place on falling edge of SCLK
		                   SCLK_i<=1'b0;               // at the start of transfer CS pin goes low 
                 if(sclk_neg_edge==1'b1)                       // after transaction of 16 bits(a frame) CS pin goes high   
		 begin
                     CS_i<=1'b0;      
                     if(cycle==16) 
		      begin
                       state<=2'b10;
                       CS_i<=1'b1;
                       end
                  else 
                     begin    
                        MOSI_i<=spi_frame[10'd15-cycle];
                        cycle<=cycle+1;
                         state<=2'b01; 
                      end 
                  end
              end

  //////////delay generation logic//////////          
       2'b10:    begin                                
                  if(delay_counter<5'd30)                        // To generate optimum width chipselect (CS) pulse ,delay logic is added which maintains CS as high for certain duration
 	 	   begin                                                   
                        delay_counter<=delay_counter+1;
                        spi_done <= 1'b1;
                        state<=2'b10;
                    end
                    else
                        delay_counter<=4'b0;    

                   if(delay_counter==5'b11101)
                       begin
                         cycle<=5'b00000;
                        state<=2'b00;
                        
                        end
                  end    
                  
          default: state<=2'b00;
          endcase 
      end 
 end                          
   
     assign MOSI=MOSI_i;
     assign SCLK=SCLK_i;
     assign CS=CS_i;
     assign LDAC=1'b0;




endmodule
