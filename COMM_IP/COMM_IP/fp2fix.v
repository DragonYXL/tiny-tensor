module FP2FIX(
    input wire        clk,
    input wire        rst_n,           // Active low reset
    input wire        en,              // enable
    input wire        vld_in,          // input valid
    input wire [15:0] data_in, 
    //input wire        data_flag,       // 0:fp16, 1:fp32
    //input wire [5:0]  data_out_width,  
 
    output reg [15:0] data_out,
    output reg        overflow,
    output reg        underflow,
    output reg        vld_out,
);


// =================== signal inst ==================== //
    
reg is_zero_flag; 
wire [10:0] f_bits;
wire       s_bits;
wire [4:0] e_bits;

wire [5:0] real_e;

reg overflow_pre;
reg underflow_pre;

reg [24:0] f_shift;
reg [14:0] f_round;

reg s_bits_1d;
reg s_bits_2d;

reg vld_in_1d;
reg data_out_temp;

// =================== signal inst end ==================== //   
// =================== data_in proc ==================== //  

//assign is_zero_flag = (vld_in==1'b0) ? 1'b0 : (data_in[14:0]==15'h00) ? 1'b1 : 1'b0 ;

    always @(posedge clk or negedge rst_n)           
        begin                                        
            if(!rst_n)                               
                is_zero_flag <= 1'b0;                                   
            else if(en==1'b0)                                
                is_zero_flag <= 1'b0;                                        
            else if(vld_in==1'b1 &&  (data_in[14:0]==15'h00))  
                is_zero_flag <= 1'b1;                             
        end                                          

assign s_bits = (vld_in==1'b0) ? 1'b0 : data_in[15] ;
assign e_bits = (vld_in==1'b0) ? 5'b0 : data_in[14:10];
assign f_bits = (vld_in==1'b0) ? 11'b0 : {1'b1,data_in[9:0]}; // data gating for low power

    always @(posedge clk or negedge rst_n)           
        begin                                        
            if(!rst_n) begin                              
                s_bits_1d <= 1'b0;
                s_bits_2d <= 1'b0;
                vld_in_1d <= 1'b0;
                vld_out <= 1'b0;    
            end                                
            else if(en==1'b0)begin
                s_bits_1d <= 1'b0;
                s_bits_2d <= 1'b0;
                vld_in_1d <= 1'b0;
                vld_out <= 1'b0; 
            end                                                                                     
            else if(vld_in & vld_in_1d) begin
                s_bits_1d <= s_bits;
                s_bits_2d <= s_bits_1d;
                vld_in_1d <= vld_in;
                vld_out <= vld_in_1d;
            end                                    
        end    

    //always @(posedge clk or negedge rst_n)           
    //    begin                                        
    //        if(!rst_n) begin                              
    //            vld_in_1d <= 1'b0;
    //            vld_in_2d <= 1'b0;   
    //        end                                
    //        else if(en==1'b0)begin
    //            vld_in_1d <= 1'b0;
    //            vld_in_2d <= 1'b0; 
    //        end                                                                                     
    //        else if(vld_in & vld_in_1d) begin
    //            vld_in_1d <= vld_in;
    //            vld_in_2d <= vld_in_1d;
    //        end                                    
    //    end  
// =================== get real e ======================= //

assign real_e = e_bits - $signed(4'd15) ;

    always @(posedge clk or negedge rst_n)           
        begin                                        
            if(!rst_n)                               
                overflow_pre <= 1'b0;                                   
            else if(en == 1'b0)                                
                overflow_pre <= 1'b0;                                       
            else if (($signed(real_e)>=15) && (vld_in == 1'b1)) begin
                overflow_pre <= 1'b1;
            end
            else begin
                overflow_pre <= 1'b0;
            end
        end       

    always @(posedge clk or negedge rst_n)           
        begin                                        
            if(!rst_n)                               
                underflow_pre <= 1'b0;                                   
            else if(en == 1'b0)                                
                underflow_pre <= 1'b0;                                       
            else if (($signed(real_e)<(-5'sd14)) && (vld_in == 1'b1)) begin
                underflow_pre <= 1'b1;
            end
            else begin
                underflow_pre <= 1'b0;
            end
        end         

    always @(posedge clk or negedge rst_n)           
        begin                                        
            if(!rst_n) begin                              
                overflow  <= 1'b0
                underflow <= 1'b0  
            end                                 
            else if(en ==1'b0) begin                               
                overflow  <= 1'b0 
                underflow <= 1'b0 
            end                                        
            else begin
                overflow  <= overflow_pre;
                underflow <= underflow_pre;
            end
        end                                          
// =================== shift bits ======================= //

    always @(posedge clk or negedge rst_n)           
        begin                                        
            if(!rst_n)                               
                f_shift <= 25'h0;                                   
            else if(en == 1'b0)                                
                f_shift <= 25'h0;                                     
            else if(vld==1'b1 && real_e[5]==1'b0)       
                f_shift <= f_bits << real_e[4:0];
            else if(vld==1'b1 && real_e[5]==1'b1)
                f_shift <= f_bits >> real_e[4:0];
        end                                          

// =================== get f_round ====================== //
    always @(*) begin
        if(s_bits_1d==1'b0)begin
            if(f_shift[9]==1'b1) begin
                f_round = f_shift[24:9] + 1'b1;
            end
        end
        else begin
            f_round = f_shift[24:10] ;
        end
    end

// =================== data_out proc ==================== //

    always @(*) begin
        if (is_zero_flag) begin
            data_out_temp = 16'h0; 
        end
        else if (underflow_pre==1'b1) begin
            data_out_temp = 16'h0;
        end
        else if(overflow_pre==1'b1) begin
            data_out_temp = 16'hffff;
        end
        else begin
            data_out_temp = {s_bits_1d,f_round};
        end
    end

    always @(posedge clk or negedge rst_n)           
        begin                                        
            if(!rst_n)                               
                data_out <= 16'd0;                                   
            else if(en==1'b0) begin
                data_out <= 16'd0;
            end                                                        
            else if (vld_in_1d) begin
                data_out <= data_out_temp;
            end                                     
        end                                          
endmodule

