#include <cstdio>
#include <cstdint>
// verilator
#include <VSimTop.h>

#define VM_TRACE  // gen vcd wave
#ifdef VM_TRACE
#include <verilated_vcd_c.h>  // Trace file format header
#endif



class Emu {
private:
  /* data */
  VSimTop *dut;
  enum { RUN, STOP };
  uint64_t state;
#ifdef VM_TRACE
  VerilatedVcdC* tfp;
  uint64_t vcd_times;
#endif
public:
  Emu(/* args */);
  ~Emu();
  void reset_n(uint64_t n);
  void single_cycle();
  void execute();
  void update_state() { if(state == RUN && dut->io_tick == 1) state = STOP; }
  bool isFinish() { return state == STOP; }
};

Emu::Emu(/* args */): dut(new VSimTop) {
#ifdef VM_TRACE
  vcd_times = 0;
#endif
}

Emu::~Emu() {
  delete dut;
}

void Emu::reset_n(uint64_t n) {
  while (n--) {
    dut->reset = 1;
    dut->clock = 0;
    dut->eval();
#ifdef VM_TRACE
    tfp->dump(vcd_times++);
#endif
    dut->clock = 1;
    dut->eval();
    dut->reset = 0;
#ifdef VM_TRACE
    tfp->dump(vcd_times++);
#endif
  }
}

void Emu::single_cycle() {
  dut->clock = 0;
  dut->eval();
#ifdef VM_TRACE
  tfp->dump(vcd_times++);
#endif
  dut->clock = 1;
  dut->eval();
#ifdef VM_TRACE
  tfp->dump(vcd_times++);
#endif
}

void Emu::execute() {
#ifdef VM_TRACE
    Verilated::traceEverOn(true);	// Verilator must compute traced signals
    VL_PRINTF("Enabling waves...\n");
    tfp = new VerilatedVcdC;
    dut->trace(tfp, 99);	// Trace 99 levels of hierarchy
    tfp->open("build/emu_wave.vcd");	// Open the dump file
#endif
  // set state
  state = RUN;
  printf("\t simulation: start ...\t\n");
  reset_n(2);
  while (!isFinish()) {
    // check emu state
    update_state();
    // run a cycle
    single_cycle();
  }
  printf("\t simulation: end ...\t\n");
#ifdef VM_TRACE
  tfp->close();
#endif
  dut->final();
#if VM_COVERAGE
  Verilated::mkdir("logs");
  Verilated::threadContextp()->coveragep()->write("logs/coverage.dat");
#endif
}


int main() {
  auto emu = new Emu;
  emu->execute();
  return 0;
}