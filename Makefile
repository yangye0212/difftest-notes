TOP_NAME = SimTop
BUILD_DIR=$(shell pwd)/build

cpp_dir = $(abspath ./src/cpp)
verilog_files = $(shell find src/verilog -name "*.v")
cpp_files = $(shell find $(cpp_dir) -name "*.cpp")

EMU_MK = $(BUILD_DIR)/verilator-out/V$(TOP_NAME).mk
EMU = $(BUILD_DIR)/emu


# verilator arguements
EMU_CXXFLAGS += -std=c++11 -static -Wall
EMU_COVERAGE ?= 0

verilator_flag = --cc --exe --top-module $(TOP_NAME) \
	-I$(BUILD_DIR) \
	-Mdir $(BUILD_DIR)/verilator-out \
	-CFLAGS "$(EMU_CXXFLAGS)" \
	-o $(EMU) \
	--trace

ifeq ($(EMU_COVERAGE),1)
verilator_flag += --coverage-line --coverage-toggle
EMU_CXXFLAGS += -DVM_COVERAGE
endif

default: run

$(EMU_MK): $(verilog_files) $(cpp_files)
	@mkdir -p $(BUILD_DIR)
	verilator $(verilator_flag) $(verilog_files) $(cpp_files)

$(EMU): $(EMU_MK)
	$(MAKE) -C $(BUILD_DIR)/verilator-out -f V$(TOP_NAME).mk

run: $(EMU)
	@$(EMU)

clean:
	-rm -rf $(BUILD_DIR)

verilator: $(EMU_MK)
emu: $(EMU)

.PHONY: verilator emu run clean