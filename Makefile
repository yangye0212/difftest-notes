TOP_NAME = SimTop
BUILD_DIR=$(shell pwd)/build

cpp_dir = $(abspath ./src/cpp)
verilog_files = $(shell find src/verilog -name "*.v")
cpp_files = $(shell find $(cpp_dir) -name "*.cpp")

EMU_MK = $(BUILD_DIR)/verilator-out/V$(TOP_NAME).mk
EMU = $(BUILD_DIR)/emu

default: run

verilator_flag = --cc --exe --top-module $(TOP_NAME) \
	-I$(BUILD_DIR) \
	-Mdir $(BUILD_DIR)/verilator-out \
	-o $(EMU) \
	--trace


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