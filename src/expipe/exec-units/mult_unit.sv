// Copyright 2021 Politecnico di Torino.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// File: mult_unit.sv
// Author: Michele Caon
// Date: 17/11/2021

import len5_pkg::*;
import expipe_pkg::*;

module mult_unit
#(
    RS_DEPTH = 4, // must be a power of 2,
    
    // EU-specific parameters
    EU_CTL_LEN = 4
)
(
    input   logic                   clk_i,
    input   logic                   rst_n_i,
    input   logic                   flush_i,
	

    // Handshake from/to issue logic
    input   logic                   issue_valid_i,
    output  logic                   issue_ready_o,

    // Data from the issue stage
    input   mult_ctl_t              eu_ctl_i,
    input   logic                   rs1_ready_i,
    input   rob_idx_t rs1_idx_i,
    input   logic [XLEN-1:0]        rs1_value_i,
    input   logic                   rs2_ready_i,
    input   rob_idx_t rs2_idx_i,          
    input   logic [XLEN-1:0]        rs2_value_i,        // can contain immediate for I type instructions
    input   rob_idx_t dest_idx_i,

    // Hanshake from/to the CDB 
    input   logic                   cdb_ready_i,
    input   logic                   cdb_valid_i,        // to know if the CDB is carrying valid data
    output  logic                   cdb_valid_o,

    // Data from/to the CDB
    input   rob_idx_t cdb_idx_i,
    input   logic [XLEN-1:0]        cdb_res_value_i,
    input   logic                   cdb_except_raised_i,
    output  cdb_data_t              cdb_data_o
);

    // Handshake from/to the execution unit
    logic                   rs_mult_valid;
    logic                   rs_mult_ready;
    logic                   mult_rs_valid;
    logic                   mult_rs_ready;

    // Data from/to the execution unit
    logic [$clog2(RS_DEPTH)-1:0] rs_mult_entry_idx;
    logic [EU_CTL_LEN-1:0]  rs_mult_ctl;
    logic [XLEN-1:0]        rs_mult_rs1_value;
    logic [XLEN-1:0]        rs_mult_rs2_value;
    logic [$clog2(RS_DEPTH)-1:0] mult_rs_entry_idx;
    logic [XLEN-1:0]        mult_rs_result;
    logic                   mult_rs_except_raised;
    except_code_t           mult_rs_except_code;

generic_rs #(.EU_CTL_LEN (EU_CTL_LEN), .RS_DEPTH (RS_DEPTH)) u_mult_generic_rs
(
    .clk_i (clk_i),
    .rst_n_i (rst_n_i),
    .flush_i (flush_i),
    .issue_valid_i (issue_valid_i),
    .issue_ready_o (issue_ready_o),
    .eu_ctl_i (eu_ctl_i),
    .rs1_ready_i (rs1_ready_i),
    .rs1_idx_i (rs1_idx_i),
    .rs1_value_i (rs1_value_i),
    .rs2_ready_i (rs2_ready_i),
    .rs2_idx_i (rs2_idx_i),
    .rs2_value_i (rs2_value_i),
    .dest_idx_i (dest_idx_i),
    .eu_ready_i (mult_rs_ready),
    .eu_valid_i (mult_rs_valid),
    .eu_valid_o (rs_mult_valid),
    .eu_ready_o (rs_mult_ready),
    .eu_entry_idx_i (mult_rs_entry_idx),
    .eu_result_i (mult_rs_result),
    .eu_except_raised_i (mult_rs_except_raised),
    .eu_except_code_i (mult_rs_except_code),
    .eu_ctl_o (rs_mult_ctl),
    .eu_rs1_o (rs_mult_rs1_value),
    .eu_rs2_o (rs_mult_rs2_value),
    .eu_entry_idx_o (rs_mult_entry_idx), 
    .cdb_ready_i (cdb_ready_i),
    .cdb_valid_i (cdb_valid_i),
    .cdb_valid_o (cdb_valid_o),
    .cdb_idx_i (cdb_idx_i),
    .cdb_res_value_i (cdb_res_value_i),
    .cdb_except_raised_i (cdb_except_raised_i),
    .cdb_data_o (cdb_data_o)
);

mult #(.EU_CTL_LEN (EU_CTL_LEN), .PIPE_DEPTH(MULT_PIPE_DEPTH), .RS_DEPTH (RS_DEPTH)) u_mult
(
    .clk_i              (clk_i),
    .rst_n_i            (rst_n_i),
    .flush_i            (flush_i),
	.valid_i            (rs_mult_valid),
    .ready_i            (rs_mult_ready),
    .valid_o            (mult_rs_valid),
    .ready_o            (mult_rs_ready),
    .ctl_i              (rs_mult_ctl),
    .entry_idx_i        (rs_mult_entry_idx),
    .rs1_value_i        (rs_mult_rs1_value),
    .rs2_value_i        (rs_mult_rs2_value),
    .entry_idx_o        (mult_rs_entry_idx),
    .result_o           (mult_rs_result),
    .except_raised_o    (mult_rs_except_raised),
    .except_code_o      (mult_rs_except_code)
);

endmodule
