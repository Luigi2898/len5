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
// File: load_store_unit.sv
// Author: Michele Caon
// Date: 15/07/2022

`include "len5_config.svh"

import expipe_pkg::*;
import len5_pkg::*;
import memory_pkg::*;

/**
 * @brief	Bare-metal load-store unit.
 *
 * @details	This module contains the load and store buffers, and an adder
 *          to compute the target memory address. It is meant to be directly
 *          attached to a memory (no support for virtual memory).
 */
module load_store_unit #(
    parameter LB_DEPTH = 4,
    parameter SB_DEPTH = 4
) (
    input   logic                       clk_i,
    input   logic                       rst_n_i,
    input   logic                       flush_i,

    /* Issue stage */
    input   logic                       issue_lb_valid_i,
    input   logic                       issue_sb_valid_i,
    output  logic                       issue_lb_ready_o,
    output  logic                       issue_sb_ready_o,
    input   ldst_width_t                issue_type_i,   // byte, halfword, ...
    input   op_data_t                   issue_rs1_i,    // base address
    input   op_data_t                   issue_rs2_i,    // data to store
    input   logic [XLEN-1:0]            issue_imm_i,    // offset
    input   rob_idx_t                   issue_dest_rob_idx_i,

    /* Commit stage */
    input   logic                       comm_spec_instr_i,
    input   rob_idx_t                   comm_rob_head_idx_i,

    /* Common data bus (CDB) */
    input   logic                       cdb_valid_i,
    input   logic                       cdb_lb_ready_i,
    input   logic                       cdb_sb_ready_i,
    output  logic                       cdb_lb_valid_o,
    output  logic                       cdb_sb_valid_o,
    input   cdb_data_t                  cdb_data_i,
    output  cdb_data_t                  cdb_lb_data_o,
    output  cdb_data_t                  cdb_sb_data_o,

    /* Memory system */
    input   logic                       mem_valid_i,
    input   logic                       mem_ready_i,
    output  logic                       mem_valid_o,
    output  logic                       mem_ready_o,
    output  mem_req_t                   mem_req_o,
    input   mem_ans_t                   mem_ans_i
);

    // INTERNAL SIGNALS
    // ----------------

    // Load/store buffer <--> address adder arbiter
    logic                       lb_adderarb_valid, sb_adderarb_valid;
    logic                       lb_adderarb_ready, sb_adderarb_ready;
    adder_req_t                 lb_adderarb_req, sb_adderarb_req;
    logic                       adderarb_lb_valid, adderarb_sb_valid;
    logic                       adderarb_lb_ready, adderarb_sb_ready;
    adder_ans_t                 adder_lsb_ans;

    // Address adder arbiter <--> address adder
    logic                       adderarb_adder_valid;
    logic                       adderarb_adder_ready;
    logic                       adder_adderarb_valid;
    logic                       adder_adderarb_ready;
    adder_req_t                 adderarb_adder_req;

    // Load/store buffer <--> memory arbiter
    logic                       lb_memarb_valid, sb_memarb_valid;
    logic                       lb_memarb_ready, sb_memarb_ready;
    mem_req_t                   lb_memarb_req, sb_memarb_req;
    logic                       memarb_lb_valid, memarb_sb_valid;
    logic                       memarb_lb_ready, memarb_sb_ready;

    // ----------------------
    // LOAD AND STORE BUFFERS
    // ----------------------

    // Load buffer
    load_buffer #(
        .DEPTH (LB_DEPTH )
    ) u_load_buffer (
    	.clk_i                      (clk_i                ),
        .rst_n_i                    (rst_n_i              ),
        .flush_i                    (flush_i              ),
        .issue_valid_i              (issue_lb_valid_i     ),
        .issue_ready_o              (issue_lb_ready_o     ),
        .issue_type_i               (issue_type_i         ),
        .issue_rs1_i                (issue_rs1_i          ),
        .issue_imm_i                (issue_imm_i          ),
        .issue_dest_rob_idx_i       (issue_dest_rob_idx_i ),
        .cdb_valid_i                (cdb_valid_i          ),
        .cdb_ready_i                (cdb_lb_ready_i       ),
        .cdb_valid_o                (cdb_lb_valid_o       ),
        .cdb_data_i                 (cdb_data_i           ),
        .cdb_data_o                 (cdb_lb_data_o        ),
        .adder_valid_i              (adderarb_lb_valid    ),
        .adder_ready_i              (adderarb_lb_ready    ),
        .adder_valid_o              (lb_adderarb_valid    ),
        .adder_ready_o              (lb_adderarb_ready    ),
        .adder_ans_i                (adder_lsb_ans        ),
        .adder_req_o                (lb_adderarb_req      ),
        .mem_valid_i                (memarb_lb_valid      ),
        .mem_ready_i                (memarb_lb_ready      ),
        .mem_valid_o                (lb_memarb_valid      ),
        .mem_ready_o                (lb_memarb_ready      ),
        .mem_req_o                  (lb_memarb_req        ),
        .mem_ans_i                  (mem_ans_i            )
    );
    
    // Store buffer
    store_buffer #(
        .DEPTH (SB_DEPTH )
    ) u_store_buffer(
    	.clk_i                (clk_i                ),
        .rst_n_i              (rst_n_i              ),
        .flush_i              (flush_i              ),
        .issue_valid_i        (issue_sb_valid_i     ),
        .issue_ready_o        (issue_sb_ready_o     ),
        .issue_type_i         (issue_type_i         ),
        .issue_rs1_i          (issue_rs1_i          ),
        .issue_rs2_i          (issue_rs2_i          ),
        .issue_imm_i          (issue_imm_i          ),
        .issue_dest_rob_idx_i (issue_dest_rob_idx_i ),
        .comm_spec_instr_i    (comm_spec_instr_i    ),
        .comm_rob_head_idx_i  (comm_rob_head_idx_i  ),
        .cdb_valid_i          (cdb_valid_i          ),
        .cdb_ready_i          (cdb_sb_ready_i       ),
        .cdb_valid_o          (cdb_sb_valid_o       ),
        .cdb_data_i           (cdb_data_i           ),
        .cdb_data_o           (cdb_sb_data_o        ),
        .adder_valid_i        (adderarb_sb_valid    ),
        .adder_ready_i        (adderarb_sb_ready    ),
        .adder_valid_o        (sb_adderarb_valid    ),
        .adder_ready_o        (sb_adderarb_ready    ),
        .adder_ans_i          (adder_lsb_ans        ),
        .adder_req_o          (sb_adderarb_req      ),
        .mem_valid_i          (memarb_sb_valid      ),
        .mem_ready_i          (memarb_sb_ready      ),
        .mem_valid_o          (sb_memarb_valid      ),
        .mem_ready_o          (sb_memarb_ready      ),
        .mem_req_o            (sb_memarb_req        ),
        .mem_ans_i            (mem_ans_i            )
    );
    
    // -------------
    // ADDRESS ADDER
    // -------------
    // NOTE: shared between load and store buffers
    address_adder u_address_adder(
    	.clk_i   (clk_i                ),
        .rst_n_i (rst_n_i              ),
        .flush_i (flush_i              ),
        .valid_i (adderarb_adder_valid ),
        .ready_i (adderarb_adder_ready ),
        .valid_o (adder_adderarb_valid ),
        .ready_o (adder_adderarb_ready ),
        .req_i   (adderarb_adder_req   ),
        .ans_o   (adder_lsb_ans        )
    );

    // --------------
    // MEMORY ARBITER
    // --------------
    `ifdef ENABLE_STORE_PRIO_2WAY_ARBITER
    // The store buffer, connected to valid_i[0] is given higher priority than the load buffer. This should increase the hit ratio of the store to load forwarding. However, it increases the load execution latency. Depending on the scenario, performance may be better or worse than the fair arbiter.

    prio_2way_arbiter #(
        .DATA_T (mem_req_t)
    ) u_mem_arbiter	(
        .high_prio_valid_i (sb_memarb_valid ),
        .low_prio_valid_i  (lb_memarb_valid ),
        .ready_i           (mem_ready_i     ),
        .valid_o           (mem_valid_o     ),
        .high_prio_ready_o (memarb_sb_ready ),
        .low_prio_ready_o  (memarb_lb_ready ),
        .high_prio_data_i  (sb_memarb_req   ),
        .low_prio_data_i   (lb_memarb_req   ),
        .data_o            (mem_req_o       )
    );
    `else
    fair_2way_arbiter #(
        .DATA_T (mem_req_t )
    ) u_mem_arbiter (	
        .clk_i     (clk_i           ),
        .rst_n_i   (rst_n_i         ),
        .valid_a_i (sb_memarb_valid ),
        .valid_b_i (lb_memarb_valid ),
        .ready_i   (mem_ready_i     ),
        .valid_o   (mem_valid_o     ),
        .ready_a_o (memarb_sb_ready ),
        .ready_b_o (memarb_lb_ready ),
        .data_a_i  (sb_memarb_req   ),
        .data_b_i  (lb_memarb_req   ),
        .data_o    (mem_req_o       )
    );
    `endif

    // Answer decoder
    always_comb begin : mem_ans_decoder
        memarb_lb_valid = 1'b0;
        memarb_sb_valid = 1'b0;
        mem_ready_o     = 1'b0;

        if (mem_valid_i) begin
            case (mem_ans_i.acc_type)
                MEM_ACC_LD: begin
                    memarb_lb_valid = 1'b1;
                    mem_ready_o     = lb_memarb_ready;
                end
                MEM_ACC_ST: begin
                    memarb_sb_valid = 1'b1;
                    mem_ready_o     = sb_memarb_ready;
                end
                default:;
            endcase
        end
    end

    // --------------------------------
    // VIRTUAL ADDRESS ADDER HS ARBITER
    // --------------------------------
    `ifdef ENABLE_STORE_PRIO_2WAY_ARBITER
    // The store buffer, connected to valid_i[0] is given higher priority than the load buffer. This should increase the hit ratio of the store to load forwarding. However, it increases the load execution latency. Depending on the scenario, performance may be better or worse than the fair arbiter.

    prio_2way_arbiter #(
        .DATA_T (adder_req_t)
    ) u_adder_arbiter	(
        .high_prio_valid_i (sb_adderarb_valid    ),
        .low_prio_valid_i  (lb_adderarb_valid    ),
        .ready_i           (adder_adderarb_ready ),
        .valid_o           (adderarb_adder_valid ),
        .high_prio_ready_o (adderarb_sb_ready    ),
        .low_prio_ready_o  (adderarb_lb_ready    ),
        .high_prio_data_i  (sb_adderarb_req      ),
        .low_prio_data_i   (lb_adderarb_req      ),
        .data_o            (adderarb_adder_req   )
    );
    `else
    fair_2way_arbiter #(
        .DATA_T (adder_req_t )
    ) u_adder_arbiter (	
        .clk_i     (clk_i                ),
        .rst_n_i   (rst_n_i              ),
        .valid_a_i (sb_adderarb_valid    ),
        .valid_b_i (lb_adderarb_valid    ),
        .ready_i   (adder_adderarb_ready ),
        .valid_o   (adderarb_adder_valid ),
        .ready_a_o (adderarb_sb_ready    ),
        .ready_b_o (adderarb_lb_ready    ),
        .data_a_i  (sb_adderarb_req      ),
        .data_b_i  (lb_adderarb_req      ),
        .data_o    (adderarb_adder_req   )
    );
    `endif

    // Answer decoder
    always_comb begin : adder_ans_decoder
        adderarb_lb_valid       = 1'b0;
        adderarb_sb_valid       = 1'b0;
        adderarb_adder_ready    = 1'b0;

        if (adder_adderarb_valid) begin
            if (adder_lsb_ans.is_store) begin
                adderarb_sb_valid       = 1'b1;
                adderarb_adder_ready    = sb_adderarb_ready;
            end else begin
                adderarb_lb_valid       = 1'b1;
                adderarb_adder_ready    = lb_adderarb_ready;
            end
        end
    end

endmodule