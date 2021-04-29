// Copyright 2019 Politecnico di Torino.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// File: ifu.sv
// Author: Marco Andorno
// Date: 03/10/2019

import len5_pkg::*;

`include "instr_sel.sv"
`include "presence_check.sv"
`include "fetch_controller.sv"

module ifu
(
  input   logic             clk_i,
  input   logic             rst_n_i,
  input   logic             flush_i,

  // From/to PC gen
  input   logic [XLEN-1:0]  pc_i,
  output  logic             fetch_ready_o,

  // From/to i-cache interface
  input   icache_out_t      cache_out_i,
  input   logic             read_done_i,
  output  logic             read_req_o,

  // From/to instruction decode
  input   logic             issue_ready_i,
  output  logic             issue_valid_o,
  output  logic [ILEN-1:0]  instruction_o
);

  // Signal declarations
  icache_out_t line_reg;
  icache_out_t line_bak;
  logic fetch_ready;
  logic here, will_be_here, line_valid;
  pc_src_t pc_sel;
  line_src_t line_sel;
  logic [XLEN-1:0] prev_pc_d, prev_pc_q;

  // --------
  // Line reg
  // --------
  always_ff @ (posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      line_valid <= '0;
      line_reg <= '0;
    end else begin
      if (flush_i) begin
        line_valid <= '0;
        line_reg <= '0;
      end else if (read_done_i) begin
        line_valid <= '1;
        line_reg <= cache_out_i;
      end
    end
  end

  // --------
  // Line bak
  // --------
  always_ff @ (posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      line_bak <= '0;
    end else begin
      if (flush_i) begin
        line_bak <= '0;
      end else if (fetch_ready) begin
        line_bak <= line_reg;
      end
    end
  end

  // ----------------
  // Fetch controller
  // ----------------
  fetch_controller u_fetch_controller
  (
    .clk_i            (clk_i),
    .rst_n_i          (rst_n_i),
    .flush_i          (flush_i),
    .here_i           (here),
    .will_be_here_i   (will_be_here),
    .issue_ready_i    (issue_ready_i),
    .read_done_i      (read_done_i),

    .fetch_ready_o    (fetch_ready),
    .read_req_o       (read_req_o),
    .issue_valid_o    (issue_valid_o),
    .pc_sel_o         (pc_sel),
    .line_sel_o       (line_sel)
  );

  // -------
  // Prev PC
  // -------
  assign prev_pc_d = fetch_ready ? pc_i : prev_pc_q;

  always_ff @ (posedge clk_i or negedge rst_n_i) begin: prev_pc
    if (!rst_n_i)     prev_pc_q <= '0;
    else if (flush_i) prev_pc_q <= '0;
    else              prev_pc_q <= prev_pc_d;
  end: prev_pc

  // ----------------
  // Presence checker
  // ----------------
  presence_check u_presence_check
  (
    .pc_i           (pc_i),
    .prev_pc_i      (prev_pc_q),
    .line_pc_i      (line_reg.pc),
    .line_valid_i   (line_valid),

    .here_o         (here),
    .will_be_here_o (will_be_here)
  );

  // --------------------
  // Instruction selector
  // --------------------
  instr_sel u_instr_sel
  (
    .cache_out_i    (cache_out_i),
    .line_reg_i     (line_reg),
    .line_bak_i     (line_bak),
    .pc_i           (pc_i[ICACHE_OFFSET+OFFSET-1:OFFSET]),
    .prev_pc_i      (prev_pc_q[ICACHE_OFFSET+OFFSET-1:OFFSET]),
    .pc_sel_i       (pc_sel),
    .line_sel_i     (line_sel),

    .instruction_o  (instruction_o)
  );

  // In case of flush, be ready to fetch next PC
  // at the following cycle
  assign fetch_ready_o = fetch_ready | flush_i;

endmodule
