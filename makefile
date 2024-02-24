####################
# ----- INFO ----- #
####################
# Makefile to generate the LEN5 processor files and build the design with fusesoc

#############################
# ----- CONFIGURATION ----- #
#############################

# General configuration
MAKE           	?= make
BUILD_DIR	   	?= $(realpath .)/build

# Software build configuration
PROJECT  ?= hello_world
LINKER   ?= $(realpath sw/linker/len5-sim.ld)
COPT   	 ?= -O0

# RTL simulation
FIRMWARE		?= $(BUILD_DIR)/main.hex
MAX_CYCLES		?= 100000
LOG_LEVEL		?= LOG_MEDIUM
DUMP_TRACE		?= false

# VARIABLES
# ---------
# RTL simulation files
SIM_CORE_FILES 	:= $(shell find . -type f -name "*.core")
SIM_HDL_FILES 	:= $(shell find rtl -type f -name "*.v" -o -name "*.sv" -o -name "*.svh")
SIM_HDL_FILES 	+= $(shell find tb -type f -name "*.v" -o -name "*.sv" -o -name "*.svh")
SIM_CPP_FILES	:= $(shell find tb/verilator -type f -name "*.cpp" -o -name "*.hh")

#######################
# ----- TARGETS ----- #
#######################

# HDL source
# ----------
# Format code
.PHONY: format
format: | .check-fusesoc
	@echo "## Formatting RTL code..."
	fusesoc run --no-export --target format polito:len5:len5

# Static analysis
.PHONY: lint
lint: | .check-fusesoc
	@echo "## Running static analysis..."
	fusesoc run --no-export --target lint polito:len5:len5

# RTL simulation
# --------------
# Build Verilator model
# Re-run every time the necessary files (.core, RTL, CPP) change
.PHONY: verilator-build
verilator-build: $(BUILD_DIR)/.verilator.lock
$(BUILD_DIR)/.verilator.lock: $(SIM_CORE_FILES) $(SIM_HDL_FILES) $(SIM_CPP_FILES) | .check-fusesoc $(BUILD_DIR)/
	@echo "## Building simulation model with Verilator..."
	fusesoc run --no-export --target sim --tool verilator $(FUSESOC_FLAGS) --build polito:len5:len5
	touch $@

# Run Verilator simulation
.PHONY: verilator-sim
verilator-sim: $(BUILD_DIR)/.verilator.lock | .check-fusesoc
	fusesoc run --no-export --target sim --tool verilator --run $(FUSESOC_FLAGS) polito:len5:len5 \
		--log_level=$(LOG_LEVEL) \
		--firmware=$(FIRMWARE) \
		--max_cycles=$(MAX_CYCLES) \
		--dump_trace=$(DUMP_TRACE) \
		$(FUSESOC_ARGS)

.PHONY: verilator-opt
verilator-opt: $(BUILD_DIR)/.verilator.lock | .check-fusesoc
	fusesoc run --no-export --target sim --tool verilator --run $(FUSESOC_FLAGS) polito:len5:len5 \
		--log_level=$(LOG_LEVEL) \
		--firmware=$(FIRMWARE) \
		--max_cycles=$(MAX_CYCLES) \
		--dump_waves=false \
		$(FUSESOC_ARGS)

# Open dumped waveform with GTKWave
.PHONY: verilator-waves
verilator-waves: $(BUILD_DIR)/sim-common/waves.fst | .check-gtkwave
	gtkwave -a tb/misc/verilator-waves.gtkw $<

# QuestaSim
.PHONY: questasim-sim
questasim-sim: | app .check-fusesoc $(BUILD_DIR)/
	@echo "## Running simulation with QuestaSim..."
	fusesoc run --no-export --target sim --tool modelsim $(FUSESOC_FLAGS) --build polito:len5:len5 2>&1 | tee build/build.log
	
# Software
# --------
# Application from 'sw/applications'
# NOTE: the -B option to make forces recompilation everytime, which is needed since PROJECT is user-defined
.PHONY: app
app: | $(BUILD_DIR)/
	@echo "## Building application '$(PROJECT)'"
	$(MAKE) -BC sw app

# Simple test application
.PHONY: app-helloworld
app-helloworld:
	@echo "## Building helloworld application"
	$(MAKE) -BC sw PROJECT=hello_world BUILD_DIR=$(BUILD_DIR)

# Compile example applicationa and run RTL simulation
.PHONY: app-helloworld-questasim
run-helloworld-questasim: questasim-sim app-helloworld | .check-fusesoc
	@echo "## Running helloworld application"
	cd ./build/vlsi_polito_len5_0/sim-modelsim; \
	make run PLUSARGS="c firmware=../../../sw/applications/hello_world.hex"; \
	cd ../../..;

# Spike simulation
.PHONY: spike-sim
spike-sim:
	@echo "## Running simulation with Spike..."
	spike -m0xf000:0x100000,0x20000000:0x1000 -d $(BUILD_DIR)/main.elf

.PHONY: spike-trace
spike-trace: $(BUILD_DIR)/sim-common/
	@echo "## Running simulation with Spike..."
	spike --log=$(BUILD_DIR)/sim-common/spike-trace.log -l -m0xf000:0x100000,0x20000000:0x1000 $(BUILD_DIR)/main.elf

# Check that nothing is broken
# ----------------------------
.PHONE: check
check: | .check-fusesoc
	@echo "## Checking software build..."
	$(MAKE) app PROJECT=hello_world BUILD_DIR=$(BUILD_DIR)
	@echo "## Checking RTL..."
	fusesoc run --no-export --target format polito:len5:len5
	fusesoc run --no-export --target lint polito:len5:len5
	$(MAKE) verilator-build
	@echo "\033[1;32mSUCCESS: all checks passed!\033[0m"

# Utilities
# ---------
# Check if fusesoc is available
.PHONY: .check-fusesoc
.check-fusesoc:
	@if [ ! `which fusesoc` ]; then \
	printf -- "### ERROR: 'fusesoc' is not in PATH. Is the correct conda environment active?\n" >&2; \
	exit 1; fi

# Check if GTKWave is available
.PHONY: .check-gtkwave
.check-gtkwave:
	@if [ ! `which gtkwave` ]; then \
	printf -- "### ERROR: 'gtkwave' is not in PATH. Is the correct conda environment active?\n" >&2; \
	exit 1; fi

# Create new directories
%/:
	mkdir -p $@

# Clean-up
.PHONY: clean
clean: clean-app clean-sim

.PHONY: clean-sim
clean-sim:
	@rm -rf build

.PHONY: clean-app
clean-app:
	$(MAKE) -C sw clean

.PHONY: .print
.print:
	@echo "SIM_HDL_FILES: $(SIM_HDL_FILES)"
	@echo "SIM_CPP_FILES: $(SIM_CPP_FILES)"

# Export variables for software linker script
# -------------------------------------------
export BUILD_DIR
export PROJECT
export LINKER
export COPT
