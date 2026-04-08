/*
0212开始做fp32的更改:
0214继续
0215完成，还未做tb
*/

module FIX2FP (
    // system interface
    input wire clk,
    input wire rst_n,
    // input interface
    input wire en,
    input wire vld_in,
    input wire [31:0] data_in,
    // output interface
    output reg vld_out,
    output wire [31:0] data_out
);

// ===================== signal inst ======================= //
wire data_in_s; //signature 符号位
wire [31:0] data_in_gat; 
wire [30:0] data_in_temp4;
wire [15:0] data_in_temp3;
wire [7:0]  data_in_temp2;
wire [3:0]  data_in_temp1; 
wire [1:0]  data_in_temp0; 
wire [4:0]  lod_index;       
// lod_index表示首位1右侧的bit数量，最低为5'd0，最高为5'd30
// lod_index : index of the first '1' from LSB
// equivalent to the number of bits on the right of the leading 1

reg  [7:0]  exp;

reg [23:0]  data_out_f;
reg         data_out_s;


// ===================== data gating for power management ======================= //
assign data_in_gat = (en || vld_in) ? data_in : 32'b0; 

// ===================== seperate data ======================= //
assign data_in_s = data_in_gat[31];
assign data_in_temp4 = data_in_gat[30:0];

// ===================== Leading one detect ver 1 ======================= // 
    assign lod_index[4] = ({1'b0, data_in_temp4[30:16]}==16'h0) ? 1'b0 : 1'b1;
    assign data_in_temp3 = lod_index[4] ? {1'b0, data_in_temp4[30:16]} : data_in_temp4[15:0];//高16位

    assign lod_index[3] = (data_in_temp3[15:8]==8'h0) ? 1'b0 : 1'b1;
    assign data_in_temp2 = lod_index[3] ? data_in_temp3[15:8] : data_in_temp3[7:0];//高8位 

    assign lod_index[2] = (data_in_temp2[7:4] == 4'h0) ? 1'b0 : 1'b1;
    assign data_in_temp1 = lod_index[2] ? data_in_temp2[7:4] : data_in_temp2[3:0];

    assign lod_index[1] = (data_in_temp1[3:2] == 2'b0) ? 1'b0 : 1'b1;
    assign data_in_temp0 = lod_index[1] ? data_in_temp1[3:2] : data_in_temp1[1:0];

    assign lod_index[0] = data_in_temp0[1];

// ====================== get exp ========================= //

    always @(posedge clk or negedge rst_n)           
        begin                                        
            if(!rst_n)                               
                exp <= 8'd0;                                    
            else if(en==1'b0)begin
                exp <= 8'd0; 
            end                                
            else begin
                exp <= {3'b0, lod_index} + 8'd127;  //8'b01111111
            end                                     
        end                                          

// ====================== get f_code ====================== //
always @(posedge clk or negedge rst_n) begin//截取+四舍五入，不再保留首位1
	if (rst_n==1'b0) begin
		data_out_f <= 24'd0;
	end
	else if (en==1'b0) begin
		data_out_f <= 24'd0;
	end
	else if(lod_index>24) begin
		if(data_in_s==1'b0)begin
			
			data_out_f <= data_in_gat[lod_index-24+:24] + 1'b1;
		end
		else begin
			data_out_f <= data_in_gat[lod_index-24+:24];
		end
	end
	else if (lod_index<=24) begin
		data_out_f <= data_in_gat[31:0]<<(32-lod_index);
	end
end

// ============ DFF of algin ============ // 
    always @(posedge clk or negedge rst_n)           
        begin                                        
            if(!rst_n) begin                              
                data_out_s <= 1'b0;
				vld_out <= 1'b0;				
			end
            else if (en==1'b0) begin
                data_out_s <= 1'b0;
				vld_out <= 1'b0;				
            end                                
            else begin
                data_out_s <= data_in_s;
				vld_out <= vld_in;
            end                                     
        end 

// ====================== get f_code ====================== //

assign data_out = (vld_out==1) ? {data_out_s, exp, data_out_f[23:1]} : 32'd0;

endmodule
