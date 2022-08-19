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

    // ----------
    // PARAMETERS
    // ----------

    // ROB
    // ---
    localparam ROB_IDX_LEN = $clog2(ROB_DEPTH); // ROB index width
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
    localparam  BRANCH_TYPE_LEN = 3;
    localparam  BU_CTL_LEN      = BRANCH_TYPE_LEN; // size of 'branch_type_t' from len5_pkg

    // ALU
    localparam  ALU_CTL_LEN     = 4;            // ALU operation control

    // MULT
    localparam  MULT_CTL_LEN    = 3;            // integer multiplier operation control
    localparam  MULT_PIPE_DEPTH = 5;

    // DIV
    localparam  DIV_CTL_LEN     = 2;            // integer divider operation control

    // FPU
    localparam  FPU_CTL_LEN     = 4;            // floating point multiplier operation control

    // OPERANDS ONLY
    localparam  OP_ONLY_CTL_LEN = 2;

    // LOAD-STORE UNIT
    localparam  LSU_CTL_LEN     = 3;

    // MAXIMUM DIMENSION OF EU_CONTROL FIELDS
    localparam MAX_EU_CTL_LEN   = ALU_CTL_LEN;  // this must be set to the maximum of the previous parameters

    // ---
    // ALL
    // ---

    // Jump/branch auxiliary information
    typedef struct packed {
        logic   mispredicted;
        logic   taken;
    } res_aux_jb_t;

    // EU result auxiliary data
    typedef union packed {
        res_aux_jb_t    jb;
        logic [1:0]     raw;
    } res_aux_t;

    // ----
    // ROB
    // ----

    typedef logic [ROB_IDX_LEN-1:0] rob_idx_t;

    typedef struct packed {
        instr_t                     instruction;    // the instruction
        logic [XLEN-1:0]            instr_pc;       // the program counter of the instruction
        logic                       res_ready;      // the result of the instruction is ready
        logic [XLEN-1:0]            res_value;      // the value of the result (from the EU)
        res_aux_t                   res_aux;        // result auxiliary data
        logic [REG_IDX_LEN-1:0]     rd_idx;         // the destination register (rd)
        logic                       except_raised;  // an exception has been raised
        except_code_t               except_code;    // the exception code
    } rob_entry_t;

    // ----
    // CDB
    // ----
    
    typedef struct packed {
        rob_idx_t                   rob_idx;
        logic [XLEN-1:0]            res_value;
        res_aux_t                   res_aux;
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
    typedef enum logic [MAX_EU_CTL_LEN-1:0] {
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
    typedef enum logic [MAX_EU_CTL_LEN-1:0] {
        MULT_MUL,
        MULT_MULW,
        MULT_MULH,
        MULT_MULHU,
        MULT_MULHSU
    } mult_ctl_t;

    // Branch unit control
    typedef enum logic [MAX_EU_CTL_LEN-1:0] {
        BEQ   = 'h0,
        BNE   = 'h1,
        BLT   = 'h2,
        BGE   = 'h3,
        BLTU  = 'h4,
        BGEU  = 'h5,
        JUMP  = 'h6
    } branch_type_t;

    // Load-store unit control
    typedef enum logic [MAX_EU_CTL_LEN-1:0] { 
        LS_BYTE,
        LS_BYTE_U,
        LS_HALFWORD,
        LS_HALFWORD_U,
        LS_WORD,
        LS_WORD_U,
        LS_DOUBLEWORD
    } ldst_width_t;

    // EU control union
    typedef union packed {
        alu_ctl_t                   alu;
        mult_ctl_t                  mult;
        branch_type_t               bu;
        ldst_width_t                lsu;
        logic [MAX_EU_CTL_LEN-1:0]  raw;
    } eu_ctl_t;
    
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

    // -----------
    // BRANCH UNIT
    // -----------

    // Reservation station entry 
    typedef struct packed {
        logic                   valid;      // The entry contains a valid instruction
        logic                   busy;       // The instruction is being executed in the assigned EU
        `ifdef ENABLE_AGE_BASED_SELECTOR
        rob_idx_t               entry_age; // The age of the entry, used for scheduling
        `endif
        branch_type_t           branch_type;// Branch type for the branch unit
        logic                   rs1_ready;  // The first operand value is available in 'rs1_value'
        rob_idx_t               rs1_idx;    // The entry of the rob that will contain the required operand
        logic [XLEN-1:0]        rs1_value;  // The value of the first operand
        logic                   rs2_ready;  // The second operand value is available in 'rs2_value'
        rob_idx_t               rs2_idx;    // The entry of the rob that will contain the required operand
        logic [XLEN-1:0]        rs2_value;  // The value of the second operand
        logic [XLEN-1:0]        imm_value;  // Immediate value
        logic [XLEN-1:0]        curr_pc;    // Program counter of the current instruction
        logic                   res_ready;  // the computed target address and branch outcome are available
        rob_idx_t               res_idx;    // The entry of the ROB where the result will be stored
        logic                   taken;      // Branch outcome prediction, then replaced by computed outcome
        logic [XLEN-1:0]        target;     // Predicted target PC, later replaced by computed target PC
        logic                   mispredicted;// the branch was mispredicted
    } bu_rs_entry_t;

    // ---------------
    // LOAD-STORE UNIT
    // ---------------
    
    /* Load instruction status */
    typedef enum logic [LSU_CTL_LEN-1:0] {
        LOAD_S_EMPTY,
        LOAD_S_RS1_PENDING,
        LOAD_S_ADDR_REQ,
        LOAD_S_ADDR_WAIT,
        LOAD_S_MEM_REQ,
        LOAD_S_MEM_WAIT,
        LOAD_S_COMPLETED,
        LOAD_S_HALT     // for debug
    } lb_state_t;

    /* Load instruction data */
    typedef struct packed {
        ldst_width_t                 load_type;
        // logic [STBUFF_IDX_LEN-1:0]  older_stores;
        rob_idx_t                   rs1_rob_idx;
        logic [XLEN-1:0]            rs1_value;
        rob_idx_t                   dest_rob_idx;
        logic [XLEN-1:0]            imm_addr_value; // immediate offset, then replaced with resulting address
        logic                       except_raised;
        except_code_t               except_code;
        logic [XLEN-1:0]            value;
    } lb_data_t;

    /* Load instruction command */
    typedef enum logic [2:0] {
        LOAD_OP_NONE,
        LOAD_OP_PUSH,
        LOAD_OP_SAVE_RS1,
        LOAD_OP_SAVE_ADDR,
        LOAD_OP_SAVE_MEM
    } lb_op_t;

    // STORE BUFFER DATA TYPES
    // -----------------------

    /* Store instruction status */
    typedef enum logic [3:0] {
        STORE_S_EMPTY,
        STORE_S_RS12_PENDING,
        STORE_S_RS1_PENDING,
        STORE_S_RS2_PENDING,
        STORE_S_ADDR_REQ,
        STORE_S_ADDR_WAIT,
        STORE_S_WAIT_ROB,
        STORE_S_MEM_REQ,
        STORE_S_MEM_WAIT,
        STORE_S_COMPLETED,
        STORE_S_HALT    // for debug
    } sb_state_t;

    /* Store instruction data */
    typedef struct packed {
        ldst_width_t                store_type;
        logic                       speculative;    // the store instruction is speculative
        rob_idx_t                   rs1_rob_idx;
        logic [XLEN-1:0]            rs1_value;
        rob_idx_t                   rs2_rob_idx;
        logic [XLEN-1:0]            rs2_value;
        rob_idx_t                   dest_rob_idx;
        logic [XLEN-1:0]            imm_addr_value; // immediate offset, then replaced with resulting address
        logic                       except_raised;
        except_code_t               except_code;
        logic [XLEN-1:0]            value;
    } sb_data_t;

    /* Store instruction command */
    typedef enum logic [2:0] {
        STORE_OP_NONE,
        STORE_OP_PUSH,
        STORE_OP_SAVE_RS12,
        STORE_OP_SAVE_RS1,
        STORE_OP_SAVE_RS2,
        STORE_OP_SAVE_ADDR,
        STORE_OP_SAVE_MEM
    } sb_op_t;

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
