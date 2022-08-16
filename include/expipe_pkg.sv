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
// File: expipe_pkg.sv
// Author: Michele Caon
// Date: 17/10/2019

`ifndef EXPIPE_PKG
`define EXPIPE_PKG

// LEN5 compilation switches
`include "len5_config.svh"

package expipe_pkg;

    /* Inlcude isnstruction macros */
    `include "instr_macros.svh"
    
    // Import global constants
    import len5_pkg::*;

    /* Add memory definitions */
    import memory_pkg::PPN_LEN;
    import memory_pkg::PADDR_LEN;
    import memory_pkg::PAGE_OFFSET_LEN;
    import memory_pkg::ldst_width_t;

    // ----------
    // PARAMETERS
    // ----------

    // ROB
    // ---
    localparam ROB_IDX_LEN = $clog2(ROB_DEPTH);//3 // ROB index width
    localparam ROB_EXCEPT_LEN = EXCEPT_TYPE_LEN;

    // ISSUE QUEUE
    // -----------
    localparam IQ_IDX_LEN = $clog2(IQ_DEPTH); // issue queue index width

    // EXECUTION UNITS
    // ---------------
    localparam BASE_EU_N    = 5;   // load buffer, store buffer, branch unit, ALU, operands only

`ifdef LEN5_M_EN
    localparam MULT_EU_N    = 2;   // MULT, DIV
`else
    localparam MULT_EU_N    = 0;
`endif /* LEN5_M_EN */

`ifdef LEN5_FP_EN
    localparam FP_EU_N      = 1;     // FPU
`else
    localparam FP_EU_N      = 0;
`endif /* LEN5_FP_EN */

    // Total number of execution units
    localparam EU_N = BASE_EU_N + MULT_EU_N + FP_EU_N;

    // RESERVATION STATIONS
    // --------------------

    // BRANCH UNIT
    localparam  BU_CTL_LEN      = BRANCH_TYPE_LEN; // size of 'branch_type_t' from len5_pkg

    // ALU
    localparam  ALU_EXCEPT_LEN  = 2;
    localparam  ALU_CTL_LEN     = 4;            // ALU operation control

    // MULT
    localparam  MULT_EXCEPT_LEN = 2;
    localparam  MULT_CTL_LEN    = 3;            // integer multiplier operation control
    localparam  MULT_PIPE_DEPTH = 5;

    // DIV
    localparam  DIV_EXCEPT_LEN  = 2;
    localparam  DIV_CTL_LEN     = 2;            // integer divider operation control

    // FPU
    localparam  FPU_EXCEPT_LEN  = 2;
    localparam  FPU_CTL_LEN     = 4;            // floating point multiplier operation control

    // OPERANDS ONLY
    localparam  OP_ONLY_CTL_LEN = 2;

    // MAXIMUM DIMENSION OF EU_CONTROL FIELDS
    localparam MAX_EU_CTL_LEN   = ALU_CTL_LEN;  // this must be set to the maximum of the previous parameters

    // ----
    // ROB
    // ----

    typedef logic [ROB_IDX_LEN-1:0] rob_idx_t;

    typedef struct packed {
        instr_t                     instruction;    // the instruction
        logic [XLEN-1:0]            instr_pc;       // the program counter if the instruction
        logic                       res_ready;      // the result of the instruction is ready
        logic [XLEN-1:0]            res_value;      // the value of the result (from the EU)
        logic [REG_IDX_LEN-1:0]     rd_idx;         // the destination register (rd)
        logic                       except_raised;  // an exception has been raised
        except_code_t               except_code;    // the exception code
    } rob_entry_t;

    // ----
    // CDB
    // ----
    
    typedef struct packed {
        rob_idx_t                   rob_idx;
        logic [XLEN-1:0]            value;
        logic                       except_raised;
        except_code_t               except_code;
    } cdb_data_t;

    // -----------
    // ISSUE QUEUE
    // -----------

    typedef struct packed {
        logic [XLEN-1:0]    curr_pc;
        instr_t             instruction;
        logic [XLEN-1:0]    pred_target;
        logic               pred_taken;
        logic               except_raised;
        except_code_t       except_code;
    } iq_entry_t;
    
    // ---------------
    // REGISTER STATUS
    // ---------------
    
    typedef struct packed {
        rob_idx_t     busy;       /* at most as many entry in the ROB, the current (this instruction) */
        rob_idx_t     rob_idx;
    } regstat_entry_t;

    // Operand data
    // ------------
    typedef struct packed {
        logic                   ready;
        rob_idx_t               rob_idx;
        logic [XLEN-1:0]        value;
    } op_data_t;

    // -----------
    // ISSUE LOGIC
    // -----------

    // IMMEDIATE TYPE
    typedef enum logic [2:0] {
        IMM_TYPE_I,
        IMM_TYPE_S,
        IMM_TYPE_B,
        IMM_TYPE_U,
        IMM_TYPE_J,
        IMM_TYPE_RS1
    } imm_format_t;

    // --------------------
    // RESERVATION STATIONS
    // --------------------

    // ALU opcodes
    typedef enum logic [ALU_CTL_LEN-1:0] {
        ALU_ADD,
        ALU_ADDW,
        ALU_SUB,
        ALU_SUBW,
        ALU_AND,
        ALU_OR,
        ALU_XOR,
        ALU_SLL,    // shift left
        ALU_SLLW,
        ALU_SRL,    // shift right
        ALU_SRLW,
        ALU_SRA,    // shift right w/ sign extension
        ALU_SRAW,
        ALU_SLT,    // set if less than
        ALU_SLTU    // set if less than (unsigned)
    } alu_ctl_t;

    // Mult opcodes
    typedef enum logic [MULT_CTL_LEN-1:0] {
        MULT_MUL,
        MULT_MULW,
        MULT_MULH,
        MULT_MULHU,
        MULT_MULHSU
    } mult_ctl_t;
    
    // ASSIGNED EU
    typedef enum logic [$clog2(EU_N)-1:0] {
        EU_LOAD_BUFFER,
        EU_STORE_BUFFER,
        EU_BRANCH_UNIT,
        EU_INT_ALU,
    `ifdef LEN5_M_EN
        EU_INT_MULT,
        EU_INT_DIV,
    `endif /* LEN5_M_EN */
    `ifdef LEN5_FP_EN
        EU_FPU,
    `endif /* LEN5_FP_EN */
        EU_OPERANDS_ONLY,   // probably not necessary if pipeline is stalled
        EU_NONE             //the instruction is directly sent to the ROB (csr, special instructions, etc.)
    } issue_eu_t;

    // ---------------
    // LOAD-STORE UNIT
    // ---------------
    
    // LOAD BUFFER ENTRY TYPE
    typedef struct packed {
        logic                       valid;             // the entry contains a valid instructions
        logic                       busy;              // The entry is waiting for an operation to complete
        logic                       store_dep;         // the entry must wait for alla previous store to commit before it can be executed
        logic                       pfwd_attempted;    // the entry is ready for the cache access
        `ifdef ENABLE_AGE_BASED_SELECTOR
        rob_idx_t     entry_age;         // the age of the entry, used for scheduling
        `endif
        logic [STBUFF_IDX_LEN:0]    older_stores;      // Number of older uncommitted stores (if 0, the entry is dependency-free)
        ldst_width_t                 load_type;         // LB, LBU, LH, LHU, LW, LWU, LD
        logic                       rs1_ready;         // the value of rs1 contained in 'rs1_value' field is valid
        rob_idx_t     rs1_idx;           // the index of the ROB that will contain the base address
        logic [XLEN-1:0]            rs1_value;         // the value of the base address
        logic [XLEN-1:0]            imm_value;         // the value of the immediate field (offset)
        logic                       vaddr_ready;       // the virtual address has already been computed
        logic [XLEN-1:0]            vaddr;             // the virtual address
        logic                       paddr_ready;       // the address translation (TLB access) has already completed
        logic [PPN_LEN-1:0]         ppn;  // the physical page number
        rob_idx_t     dest_idx;          // the entry of the ROB where the loaded value will be stored
        logic                       except_raised;
        except_code_t               except_code;       // exception code 
        logic [XLEN-1:0]            ld_value;          // the value loaded from memory
        logic                       completed;         // the value has been fetched from D$
    } lb_entry_t;

    // STORE BUFFER ENTRY TYPE
    typedef struct packed {
        logic                       valid;              // the entry contains a valid instructions
        logic                       busy;               // The entry is waiting for an operation to complete
        `ifdef ENABLE_AGE_BASED_SELECTOR
        rob_idx_t     entry_age;          // the age of the entry, used for scheduling
        `endif
        ldst_width_t                 store_type;         // SB, SH, SW, SD
        logic                       rs1_ready;          // the value of rs1 (BASE ADDRESS) contained in 'rs1_value' field is valid
        rob_idx_t     rs1_idx;            // the index of the ROB that will contain the base address
        logic [XLEN-1:0]            rs1_value;          // the value of the BASE ADDRESS
        logic                       rs2_ready;          // the value of rs2 (VALUE to be stored) contained in 'rs2_value' field is valid
        rob_idx_t     rs2_idx;            // the index of the ROB that will contain the base address
        logic [XLEN-1:0]            rs2_value;          // the value to be stored in memory
        logic [XLEN-1:0]            imm_value;          // the value of the immediate field (offset)
        logic                       vaddr_ready;        // the virtual address has already been computed
        logic [XLEN-1:0]            vaddr;              // the virtual address
        logic                       paddr_ready;        // the address translation (TLB access) has already completed
        logic [PPN_LEN-1:0]         ppn;                // the physical address (last 12 MSBs are identical to virtual address
        // logic                       dc_completed;       // the D$ completed the write request
        rob_idx_t     dest_idx;           // the entry of the ROB where the loaded value will be stored
        logic                       except_raised;
        except_code_t               except_code;        // exception code
        logic                       completed;          // the value has been stored to the D$
    } sb_entry_t;

    // Address adder interface
    // -----------------------
    
    // Request
    typedef struct packed {
        logic [BUFF_IDX_LEN-1:0]    tag;
        logic                       is_store;
        ldst_width_t                ls_type;
        logic [XLEN-1:0]            base;
        logic [XLEN-1:0]            offs;
    } adder_req_t;

    // Answer
    typedef struct packed {
        logic [BUFF_IDX_LEN-1:0]    tag;
        logic                       is_store;
        logic [XLEN-1:0]            result;
        logic                       except_raised;
        except_code_t               except_code;
    } adder_ans_t;

    // ------------
    // COMMIT LOGIC
    // ------------

    // Virtual address adder exception codes
    typedef enum logic [1:0] { VADDER_ALIGN_EXCEPT, VADDER_PAGE_EXCEPT, VADDER_NO_EXCEPT } vadder_except_t;

    // Commit destination data type
    typedef enum logic [3:0] { 
        COMM_TYPE_NONE,     // no data to commit (e.g., nops)
        COMM_TYPE_INT_RF,   // commit to integer register file
        COMM_TYPE_FP_RF,    // commit to floating-point register file
        COMM_TYPE_STORE,    // commit store instructions
        COMM_TYPE_BRANCH,   // commit branch instructions
        COMM_TYPE_JUMP,     // commit jump-and-link instructions
        COMM_TYPE_CSR,      // commit to CSRs
        COMM_TYPE_FENCE,    // commit fence instructions
        COMM_TYPE_ECALL,    // commit ECALL instructions
        COMM_TYPE_EBREAK,   // commit EBREAK instructions
        COMM_TYPE_XRET,     // commit URET, SRET, and MRET instructions
        COMM_TYPE_WFI,      // commit wait for interrupt instructions
        COMM_TYPE_EXCEPT    // handle exceptions
    } comm_type_t;

endpackage

`endif
