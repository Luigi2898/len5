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

# RTL simulation
FIRMWARE		?= $(BUILD_DIR)/sw/main.hex
MAX_CYCLES		?= 1000000
LOG_LEVEL		?= LOG_MEDIUM

# VARIABLES
# ---------
# RTL simulation files
SIM_CORE_FILES 	:= $(shell find rtl -type f -name "*.core")
SIM_HDL_FILES 	:= $(shell find rtl -type f -name "*.v" -o -name "*.sv" -o -name "*.svh")
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

# Check RTL code
.PHONY: check
check: | .check-fusesoc
	@echo "## Checking RTL code..."
	fusesoc run --no-export --target format polito:len5:len5
	fusesoc run --no-export --target lint polito:len5:len5

# RTL simulation
# --------------
# Build Verilator model
# Re-run every time the necessary files (.core, RTL, CPP) change
.PHONY: verilator-build
verilator-build: $(BUILD_DIR)/.verilator.lock
$(BUILD_DIR)/.verilator.lock: $(SIM_CORE_FILES) $(SIM_HDL_FILES) $(SIM_CPP_FILES) | .check-fusesoc
	@echo "## Building simulation model with Verilator..."
	fusesoc run --no-export --target sim --tool verilator $(FUSESOC_FLAGS) --build polito:len5:len5 2>&1 | tee build/build.log
	touch $@

# Run Verilator simulation
.PHONY: verilator-run
verilator-run: $(BUILD_DIR)/.verilator.lock
	fusesoc run --no-export --target sim --tool verilator --run $(FUSESOC_FLAGS) epfl:heeperator:heeperator \
		--log_level=$(LOG_LEVEL) \
		--firmware=$(FIRMWARE) \
		--max_cycles=$(MAX_CYCLES) \
		$(FUSESOC_ARGS) 2>&1 | tee build/sim.log

# QuestaSim
.PHONY: questasim-sim
questasim-sim: | .check-fusesoc
	@echo "## Running simulation with QuestaSim..."
	fusesoc run --no-export --target sim --tool modelsim $(FUSESOC_FLAGS) --build polito:len5:len5 2>&1 | tee build/build.log
	
# Software
# --------
# Application from 'sw/applications'
.PHONY: app
app:
	@echo "## Building application '$(PROJECT)'"
	$(MAKE) -C sw app PROJECT=$(PROJECT) BUILD_DIR=$(BUILD_DIR)

# Simple test application
.PHONY: app-helloworld
app-helloworld:
	@echo "## Building helloworld application"
	$(MAKE) -C sw PROJECT=hello_world BUILD_DIR=$(BUILD_DIR)

# Compile example applicationa and run RTL simulation
.PHONY: app-helloworld-questasim
run-helloworld-questasim: questasim-sim app-helloworld | .check-fusesoc
	@echo "## Running helloworld application"
	cd ./build/vlsi_polito_len5_0/sim-modelsim; \
	make run PLUSARGS="c firmware=../../../sw/applications/hello_world.hex"; \
	cd ../../..;

# Utilities
# ---------
# Check if fusesoc is available
.PHONY: .check-fusesoc
.check-fusesoc:
	@if [ ! `which fusesoc` ]; then \
	printf -- "### ERROR: 'fusesoc' is not in PATH. Is the correct conda environment active?\n" >&2; \
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