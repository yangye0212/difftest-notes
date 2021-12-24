module MyCounter(
  input   clock,
  input   reset,
  output  io_tick
);
`ifdef RANDOMIZE_REG_INIT
  reg [31:0] _RAND_0;
`endif // RANDOMIZE_REG_INIT
  reg [3:0] value; // @[Counter.scala 60:40]
  wire [3:0] _value_T_1 = value + 4'h1; // @[Counter.scala 76:24]
  assign io_tick = value == 4'hf; // @[Counter.scala 14:22]
  always @(posedge clock) begin
    if (reset) begin // @[Counter.scala 60:40]
      value <= 4'h0; // @[Counter.scala 60:40]
    end else begin
      value <= _value_T_1; // @[Counter.scala 76:15]
    end
  end
// Register and memory initialization
`ifdef RANDOMIZE_GARBAGE_ASSIGN
`define RANDOMIZE
`endif
`ifdef RANDOMIZE_INVALID_ASSIGN
`define RANDOMIZE
`endif
`ifdef RANDOMIZE_REG_INIT
`define RANDOMIZE
`endif
`ifdef RANDOMIZE_MEM_INIT
`define RANDOMIZE
`endif
`ifndef RANDOM
`define RANDOM $random
`endif
`ifdef RANDOMIZE_MEM_INIT
  integer initvar;
`endif
`ifndef SYNTHESIS
`ifdef FIRRTL_BEFORE_INITIAL
`FIRRTL_BEFORE_INITIAL
`endif
initial begin
  `ifdef RANDOMIZE
    `ifdef INIT_RANDOM
      `INIT_RANDOM
    `endif
    `ifndef VERILATOR
      `ifdef RANDOMIZE_DELAY
        #`RANDOMIZE_DELAY begin end
      `else
        #0.002 begin end
      `endif
    `endif
`ifdef RANDOMIZE_REG_INIT
  _RAND_0 = {1{`RANDOM}};
  value = _RAND_0[3:0];
`endif // RANDOMIZE_REG_INIT
  `endif // RANDOMIZE
end // initial
`ifdef FIRRTL_AFTER_INITIAL
`FIRRTL_AFTER_INITIAL
`endif
`endif // SYNTHESIS
endmodule
module SimTop(
  input   clock,
  input   reset,
  output  io_tick
);
  wire  my_counter_clock; // @[Counter.scala 21:26]
  wire  my_counter_reset; // @[Counter.scala 21:26]
  wire  my_counter_io_tick; // @[Counter.scala 21:26]
  MyCounter my_counter ( // @[Counter.scala 21:26]
    .clock(my_counter_clock),
    .reset(my_counter_reset),
    .io_tick(my_counter_io_tick)
  );
  assign io_tick = my_counter_io_tick; // @[Counter.scala 22:11]
  assign my_counter_clock = clock;
  assign my_counter_reset = reset;
endmodule
