// TESTED AND WORKING
//`include "/home/phd-students/walid.walid/Desktop/RISC/len5_core_master/Data_path_memory.sv"
//`include "/home/phd-students/walid.walid/Desktop/RISC/len5_core_master/CU_DP_MEM.sv"
//import mmm_pkg::*;

// LEN5 compilation switches
`include "len5_config.svh"

/* Import UVM macros and package */
`include "uvm_macros.svh"
import uvm_pkg::*;

import len5_pkg::*;
import expipe_pkg::*;
import memory_pkg::*;
import csr_pkg::*;

module tb_combined;

/******************************/
/* ---- TB CONFIGURATION ---- */
/******************************/

// Set memory file path
`ifndef MEMORY_FILE
`define MEMORY_FILE "tb/memory/memory.txt"
`endif /* MEMORY_FILE */

// Initial program counter
localparam [XLEN-1:0] BOOT_PC = `BOOT_PC;

/******************/
/* ---- BODY ---- */
/******************/

    logic clk_i;
	logic rst_n_i;
	logic             flush_i;
	
  	// L2 Cache Arbiter <-> L2 Cache Emulator
	l2arb_l2c_req_t       l2arb_l2c_req_o;
  	logic                 l2c_l2arb_req_rdy_i;
  	l2c_l2arb_ans_t       l2c_l2arb_ans_i;
  	logic                 l2arb_l2c_ans_rdy_o;

always #5 clk_i = ~clk_i;

initial begin
	// /* Set the memory addressing mode */
	// if (0 == $value$plusargs("BOOT_PC=%x", BOOT_PC)) begin
	// 	`uvm_fatal("CONFIG", $sformatf("Invalid boot program counter specified"));
	// end

	/* Print boot program counter */
	`uvm_info("CONFIG", $sformatf("Boot program counter: 0x%x", BOOT_PC), UVM_MEDIUM);

	/* Print memory file being used */
	`uvm_info("CONFIG", $sformatf("Memory file: %s", `MEMORY_FILE), UVM_MEDIUM);

	/* Print M extension information */
	`uvm_info("CONFIG", $sformatf("M extension: %s", `ifdef LEN5_M_EN "YES" `else "NO" `endif), UVM_MEDIUM);
	
	/* Print FP extension information */
	`uvm_info("CONFIG", $sformatf("D extension: %s", `ifdef LEN5_FP_EN "YES" `else "NO" `endif), UVM_MEDIUM);

    //$monitor("Time = %0t -- instruction = 0x%8x, fetch ready = %0b", $time, instruction_i, fetch_ready_o);
    clk_i = 1;
    rst_n_i = 0;

	// reset
    #10 rst_n_i = 1;

    // #600 $finish;
end

// ---
// DUT
// ---

cu_dp_mem #(.BOOT_PC(BOOT_PC)) u_CU_DP_MEM
(
	.clk_i (clk_i),
    .rst_n_i (rst_n_i),
	.flush_i  (flush_i),
 	.l2arb_l2c_req_o(l2arb_l2c_req_o),
  	.l2c_l2arb_req_rdy_i(l2c_l2arb_req_rdy_i),
  	.l2c_l2arb_ans_i(l2c_l2arb_ans_i),
  	.l2arb_l2c_ans_rdy_o(l2arb_l2c_ans_rdy_o) 
);

cache_L2_system_emulator #(`MEMORY_FILE) u_cache_L2_system_emulator
(
  // Main
	.clk_i    (clk_i),
    .rst_ni  (rst_n_i),
	.flush_i  (flush_i),
	.l2arb_l2c_req_i(l2arb_l2c_req_o),
  	.l2c_l2arb_req_rdy_o(l2c_l2arb_req_rdy_i),
  	.l2c_l2arb_ans_o(l2c_l2arb_ans_i),
  	.l2arb_l2c_ans_rdy_i(l2arb_l2c_ans_rdy_o)
);

    
endmodule
