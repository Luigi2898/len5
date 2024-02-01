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
// File: issue_decoder.sv
// Author: Michele Caon
// Date: 13/11/2019

import len5_config_pkg::*;
import len5_pkg::*;
import expipe_pkg::*;
import memory_pkg::*;
import csr_pkg::*;
import instr_pkg::*;

module issue_decoder (
  // Instruction from the issue logic
  input instr_t    instruction_i,  // the issuing instruction
  input csr_priv_t priv_mode_i,    // current privilege mode

  // Issue decoder <--> issue CU
  output issue_type_t issue_type_o,  // issue operation type

  // Information to the issue logic
  output except_code_t except_code_o,  // exception code to send to the ROB
  output issue_eu_t    assigned_eu_o,  // assigned EU
  output logic         skip_eu_o,      // do not assign to any EU
  output eu_ctl_t      eu_ctl_o,       // controls for the assigned EU
  output logic         rs1_req_o,      // rs1 fetch is required
  output logic         rs1_is_pc_o,    // rs1 is the current PC (for AUIPC)
  output logic         rs2_req_o,      // rs2 fetch is required
  output logic         rs2_is_imm_o,   // replace rs2 value with imm. (for i-type ALU instr.)
  //   output logic         rs3_req_o,      // rs3 (S, D only) fetch is required
  output imm_format_t  imm_format_o    // immediate format
);

  // INTERNAL SIGNALS
  // ----------------
  // Exceptions
  except_code_t except_code;

  // Main decoder (opcode and special cases)
  issue_type_t  issue_type;
  issue_eu_t    assigned_eu;
  eu_ctl_t      eu_ctl;
  logic         rs1_req;
  logic         rs1_is_pc;  // for AUIPC
  logic         rs2_req;
  logic         rs2_is_imm;  // for i-type ALU instr
  //   logic rs3_req;
  imm_format_t  imm_format;
  logic         skip_eu;
  logic         opcode_except;

  // -------------------
  // INSTRUCTION DECODER
  // -------------------
  // New supported instructions can be added here. Instruction definitions
  // are taken from 'instr_pkg.sv', which is generated by the RISC-V opcode
  // generator called by 'sw/opcodes/gen_opcodes.sh'.

  // Main instruction decoder
  // ------------------------
  always_comb begin : main_decoder
    // Default values
    issue_type    = ISSUE_TYPE_NONE;
    skip_eu       = 1'b0;
    assigned_eu   = EU_INT_ALU;
    eu_ctl.raw    = '0;
    rs1_req       = 1'b0;
    rs1_is_pc     = 1'b0;
    rs2_req       = 1'b0;
    rs2_is_imm    = 1'b0;
    // rs3_req = 1'b0;
    imm_format    = IMM_TYPE_I;
    opcode_except = 1'b0;
    except_code   = E_ILLEGAL_INSTRUCTION;

    // Main decoding logic
    unique case (instruction_i.raw)
      // RV64I
      ADD: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_ADD;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      ADDW: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_ADDW;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      ADDI: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_ADD;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      ADDIW: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_ADDW;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      SUB: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SUB;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      SUBW: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SUBW;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      AND: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_AND;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      ANDI: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_AND;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      OR: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_OR;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      ORI: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_OR;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      XOR: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_XOR;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      XORI: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_XOR;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      SLL: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SLL;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      SLLW: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SLLW;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      SLLI: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SLL;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      SLLIW: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SLLW;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      SRL: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SRL;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      SRLW: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SRLW;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      SRLI: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SRL;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      SRLIW: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SRLW;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      SRA: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SRA;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      SRAW: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SRAW;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      SRAI: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SRA;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      SRAIW: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SRAW;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      SLT: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SLT;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      SLTU: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SLTU;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
      end
      SLTI: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SLT;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      SLTIU: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_SLTU;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      LUI: begin
        issue_type = ISSUE_TYPE_LUI;
        skip_eu    = 1'b1;
        imm_format = IMM_TYPE_U;
      end
      AUIPC: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_INT_ALU;
        eu_ctl.alu  = ALU_ADD;
        imm_format  = IMM_TYPE_U;
        rs1_is_pc   = 1'b1;
        rs2_is_imm  = 1'b1;
      end
      JAL: begin
        issue_type  = ISSUE_TYPE_JUMP;
        assigned_eu = EU_BRANCH_UNIT;
        eu_ctl.bu   = BU_JAL;
        imm_format  = IMM_TYPE_J;
      end
      JALR: begin
        issue_type  = ISSUE_TYPE_JUMP;
        assigned_eu = EU_BRANCH_UNIT;
        eu_ctl.bu   = BU_JALR;
        rs1_req     = 1'b1;
        imm_format  = IMM_TYPE_I;
      end
      BEQ: begin
        issue_type  = ISSUE_TYPE_BRANCH;
        assigned_eu = EU_BRANCH_UNIT;
        eu_ctl.bu   = BU_BEQ;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        imm_format  = IMM_TYPE_B;
      end
      BNE: begin
        issue_type  = ISSUE_TYPE_BRANCH;
        assigned_eu = EU_BRANCH_UNIT;
        eu_ctl.bu   = BU_BNE;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        imm_format  = IMM_TYPE_B;
      end
      BLT: begin
        issue_type  = ISSUE_TYPE_BRANCH;
        assigned_eu = EU_BRANCH_UNIT;
        eu_ctl.bu   = BU_BLT;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        imm_format  = IMM_TYPE_B;
      end
      BLTU: begin
        issue_type  = ISSUE_TYPE_BRANCH;
        assigned_eu = EU_BRANCH_UNIT;
        eu_ctl.bu   = BU_BLTU;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        imm_format  = IMM_TYPE_B;
      end
      BGE: begin
        issue_type  = ISSUE_TYPE_BRANCH;
        assigned_eu = EU_BRANCH_UNIT;
        eu_ctl.bu   = BU_BGE;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        imm_format  = IMM_TYPE_B;
      end
      BGEU: begin
        issue_type  = ISSUE_TYPE_BRANCH;
        assigned_eu = EU_BRANCH_UNIT;
        eu_ctl.bu   = BU_BGEU;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        imm_format  = IMM_TYPE_B;
      end
      LB: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_LOAD_BUFFER;
        eu_ctl.lsu  = LS_BYTE;
        rs1_req     = 1'b1;
        imm_format  = IMM_TYPE_I;
      end
      LBU: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_LOAD_BUFFER;
        eu_ctl.lsu  = LS_BYTE_U;
        rs1_req     = 1'b1;
        imm_format  = IMM_TYPE_I;
      end
      LH: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_LOAD_BUFFER;
        eu_ctl.lsu  = LS_HALFWORD;
        rs1_req     = 1'b1;
        imm_format  = IMM_TYPE_I;
      end
      LHU: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_LOAD_BUFFER;
        eu_ctl.lsu  = LS_HALFWORD_U;
        rs1_req     = 1'b1;
        imm_format  = IMM_TYPE_I;
      end
      LW: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_LOAD_BUFFER;
        eu_ctl.lsu  = LS_WORD;
        rs1_req     = 1'b1;
        imm_format  = IMM_TYPE_I;
      end
      LWU: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_LOAD_BUFFER;
        eu_ctl.lsu  = LS_WORD_U;
        rs1_req     = 1'b1;
        imm_format  = IMM_TYPE_I;
      end
      LD: begin
        issue_type  = ISSUE_TYPE_INT;
        assigned_eu = EU_LOAD_BUFFER;
        eu_ctl.lsu  = LS_DOUBLEWORD;
        rs1_req     = 1'b1;
        imm_format  = IMM_TYPE_I;
      end
      SB: begin
        issue_type  = ISSUE_TYPE_STORE;
        assigned_eu = EU_STORE_BUFFER;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        imm_format  = IMM_TYPE_S;
      end
      SH: begin
        issue_type  = ISSUE_TYPE_STORE;
        assigned_eu = EU_STORE_BUFFER;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        imm_format  = IMM_TYPE_S;
      end
      SW: begin
        issue_type  = ISSUE_TYPE_STORE;
        assigned_eu = EU_STORE_BUFFER;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        imm_format  = IMM_TYPE_S;
      end
      SD: begin
        issue_type  = ISSUE_TYPE_STORE;
        assigned_eu = EU_STORE_BUFFER;
        rs1_req     = 1'b1;
        rs2_req     = 1'b1;
        imm_format  = IMM_TYPE_S;
      end
      FENCE: begin
        issue_type = ISSUE_TYPE_STALL;
        skip_eu    = 1'b1;
      end
      ECALL: begin  // TODO: add ECALL support
        issue_type    = ISSUE_TYPE_EXCEPT;
        skip_eu       = 1'b1;
        opcode_except = 1'b1;
        unique case (priv_mode_i)
          PRIV_MODE_U: except_code = E_ENV_CALL_UMODE;
          PRIV_MODE_S: except_code = E_ENV_CALL_SMODE;
          default:     except_code = E_ENV_CALL_MMODE;
        endcase
      end
      EBREAK: begin  // TODO: add EBREAK support
        issue_type    = ISSUE_TYPE_EXCEPT;
        skip_eu       = 1'b1;
        opcode_except = 1'b1;
        except_code   = E_BREAKPOINT;
      end

      // RV64M
      MUL: begin
        if (LEN5_M_EN != 1'b0) begin
          issue_type  = ISSUE_TYPE_INT;
          assigned_eu = EU_INT_MULT;
          eu_ctl.mult = MULT_MUL;
          rs1_req     = 1'b1;
          rs2_req     = 1'b1;
        end else begin
          issue_type    = ISSUE_TYPE_EXCEPT;
          skip_eu       = 1'b1;
          opcode_except = 1'b1;
        end
      end
      MULH: begin
        if (LEN5_M_EN != 1'b0) begin
          issue_type  = ISSUE_TYPE_INT;
          assigned_eu = EU_INT_MULT;
          eu_ctl.mult = MULT_MULH;
          rs1_req     = 1'b1;
          rs2_req     = 1'b1;
        end else begin
          issue_type    = ISSUE_TYPE_EXCEPT;
          skip_eu       = 1'b1;
          opcode_except = 1'b1;
        end
      end
      MULHU: begin
        if (LEN5_M_EN != 1'b0) begin
          issue_type  = ISSUE_TYPE_INT;
          assigned_eu = EU_INT_MULT;
          eu_ctl.mult = MULT_MULHU;
          rs1_req     = 1'b1;
          rs2_req     = 1'b1;
        end else begin
          issue_type    = ISSUE_TYPE_EXCEPT;
          skip_eu       = 1'b1;
          opcode_except = 1'b1;
        end
      end
      MULHSU: begin
        if (LEN5_M_EN != 1'b0) begin
          issue_type  = ISSUE_TYPE_INT;
          assigned_eu = EU_INT_MULT;
          eu_ctl.mult = MULT_MULHSU;
          rs1_req     = 1'b1;
          rs2_req     = 1'b1;
        end else begin
          issue_type    = ISSUE_TYPE_EXCEPT;
          skip_eu       = 1'b1;
          opcode_except = 1'b1;
        end
      end
      MULW: begin
        if (LEN5_M_EN != 1'b0) begin
          issue_type  = ISSUE_TYPE_INT;
          assigned_eu = EU_INT_MULT;
          eu_ctl.mult = MULT_MULW;
          rs1_req     = 1'b1;
          rs2_req     = 1'b1;
        end else begin
          issue_type    = ISSUE_TYPE_EXCEPT;
          skip_eu       = 1'b1;
          opcode_except = 1'b1;
        end
      end
      DIV: begin
        if (LEN5_M_EN != 1'b0) begin
          issue_type  = ISSUE_TYPE_INT;
          assigned_eu = EU_INT_DIV;
          eu_ctl.div  = DIV_DIV;
          rs1_req     = 1'b1;
          rs2_req     = 1'b1;
        end else begin
          issue_type    = ISSUE_TYPE_EXCEPT;
          skip_eu       = 1'b1;
          opcode_except = 1'b1;
        end
      end
      DIVU: begin
        if (LEN5_M_EN != 1'b0) begin
          issue_type  = ISSUE_TYPE_INT;
          assigned_eu = EU_INT_DIV;
          eu_ctl.div  = DIV_DIVU;
          rs1_req     = 1'b1;
          rs2_req     = 1'b1;
        end else begin
          issue_type    = ISSUE_TYPE_EXCEPT;
          skip_eu       = 1'b1;
          opcode_except = 1'b1;
        end
      end
      DIVW: begin
        if (LEN5_M_EN != 1'b0) begin
          issue_type  = ISSUE_TYPE_INT;
          assigned_eu = EU_INT_DIV;
          eu_ctl.div  = DIV_DIVW;
          rs1_req     = 1'b1;
          rs2_req     = 1'b1;
        end else begin
          issue_type    = ISSUE_TYPE_EXCEPT;
          skip_eu       = 1'b1;
          opcode_except = 1'b1;
        end
      end
      DIVUW: begin
        if (LEN5_M_EN != 1'b0) begin
          issue_type  = ISSUE_TYPE_INT;
          assigned_eu = EU_INT_DIV;
          eu_ctl.div  = DIV_DIVUW;
          rs1_req     = 1'b1;
          rs2_req     = 1'b1;
        end else begin
          issue_type    = ISSUE_TYPE_EXCEPT;
          skip_eu       = 1'b1;
          opcode_except = 1'b1;
        end
      end
      REM: begin
        if (LEN5_M_EN != 1'b0) begin
          issue_type  = ISSUE_TYPE_INT;
          assigned_eu = EU_INT_DIV;
          eu_ctl.div  = DIV_REM;
          rs1_req     = 1'b1;
          rs2_req     = 1'b1;
        end else begin
          issue_type    = ISSUE_TYPE_EXCEPT;
          skip_eu       = 1'b1;
          opcode_except = 1'b1;
        end
      end
      REMU: begin
        if (LEN5_M_EN != 1'b0) begin
          issue_type  = ISSUE_TYPE_INT;
          assigned_eu = EU_INT_DIV;
          eu_ctl.div  = DIV_REMU;
          rs1_req     = 1'b1;
          rs2_req     = 1'b1;
        end else begin
          issue_type    = ISSUE_TYPE_EXCEPT;
          skip_eu       = 1'b1;
          opcode_except = 1'b1;
        end
      end
      REMW: begin
        if (LEN5_M_EN != 1'b0) begin
          issue_type  = ISSUE_TYPE_INT;
          assigned_eu = EU_INT_DIV;
          eu_ctl.div  = DIV_REMW;
          rs1_req     = 1'b1;
          rs2_req     = 1'b1;
        end else begin
          issue_type    = ISSUE_TYPE_EXCEPT;
          skip_eu       = 1'b1;
          opcode_except = 1'b1;
        end
      end
      REMUW: begin
        if (LEN5_M_EN != 1'b0) begin
          issue_type  = ISSUE_TYPE_INT;
          assigned_eu = EU_INT_DIV;
          eu_ctl.div  = DIV_REMUW;
          rs1_req     = 1'b1;
          rs2_req     = 1'b1;
        end else begin
          issue_type    = ISSUE_TYPE_EXCEPT;
          skip_eu       = 1'b1;
          opcode_except = 1'b1;
        end
      end

      // RV32ZICSR
      // TODO: check CSR instructions
      CSRRW: begin
        issue_type = ISSUE_TYPE_CSR;
        skip_eu    = 1'b1;
        rs2_req    = 1'b1;
      end
      CSRRWI: begin
        issue_type = ISSUE_TYPE_CSR;
        skip_eu    = 1'b1;
        rs2_req    = 1'b1;
        rs2_is_imm = 1'b1;
      end
      CSRRS: begin
        issue_type = ISSUE_TYPE_CSR;
        skip_eu    = 1'b1;
        rs2_req    = 1'b1;
      end
      CSRRSI: begin
        issue_type = ISSUE_TYPE_CSR;
        skip_eu    = 1'b1;
        rs2_req    = 1'b1;
        rs2_is_imm = 1'b1;
      end
      CSRRC: begin
        issue_type = ISSUE_TYPE_CSR;
        skip_eu    = 1'b1;
        rs2_req    = 1'b1;
      end
      CSRRCI: begin
        issue_type = ISSUE_TYPE_CSR;
        skip_eu    = 1'b1;
        rs2_req    = 1'b1;
        rs2_is_imm = 1'b1;
      end

      // RV32SYSTEM
      // TODO: add support for SYSTEM instructions
      MRET: begin
        issue_type    = ISSUE_TYPE_EXCEPT;
        skip_eu       = 1'b1;
        opcode_except = 1'b1;
        except_code   = E_ENV_CALL_MMODE;
      end
      WFI: begin
        issue_type = ISSUE_TYPE_STALL;
        skip_eu    = 1'b1;
      end

      // RV64F
      // TODO: add support for FPU instructions

      // Unsupported instruction
      default: begin
        issue_type    = ISSUE_TYPE_EXCEPT;
        skip_eu       = 1'b1;
        opcode_except = 1'b1;
      end
    endcase
  end

  assign issue_type_o  = (opcode_except) ? ISSUE_TYPE_EXCEPT : issue_type;
  assign skip_eu_o     = (opcode_except) ? 1'b1 : skip_eu;

  // -----------------
  // OUTPUT GENERATION
  // -----------------
  assign except_code_o = except_code;
  assign assigned_eu_o = assigned_eu;
  assign eu_ctl_o      = eu_ctl;
  assign rs1_req_o     = rs1_req;
  assign rs1_is_pc_o   = rs1_is_pc;
  assign rs2_req_o     = rs2_req;
  assign rs2_is_imm_o  = rs2_is_imm;
  //   assign rs3_req_o = rs3_req;
  assign imm_format_o  = imm_format;

  // ----------
  // ASSERTIONS
  // ----------
`ifndef SYNTHESIS
`ifndef VERILATOR
  /* Assertions here */
`endif /* VERILATOR */
`endif /* SYNTHESIS */

endmodule
