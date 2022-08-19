// Copyright 2022 Politecnico di Torino.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// File: updown_counter.sv
// Author: Michele Caon
// Date: 19/08/2022

module updown_counter #(
    W = 4 // number of bits
) (
    // Input signals 
    input   logic           clk_i,
    input   logic           rst_n_i,    // Asynchronous reset
    input   logic           en_i,
    input   logic           clr_i,      // Synchronous clear
    input   logic           up_dn_i,    // 1: up, 0: down

    // Output signals 
    output  logic [W-1:0]   count_o,  
    output  logic           tc_o    // Terminal count: '1' when count_o = 2^W-1
);

// Terminal count
assign tc_o = &count_o;

// Main counting process
always_ff @ (posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
        count_o <= 0; // Asynchronous reset
    end
    else if (clr_i) begin
        count_o <= 0; // Synchronous clear 
    end
    else if (en_i) begin
        if (up_dn_i)    count_o <= count_o + 1;
        else            count_o <= count_o - 1;
    end
end

endmodule