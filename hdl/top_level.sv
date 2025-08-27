`default_nettype none

import help::*;
import cache_help::*;

module top_level (
  input  wire clk_100mhz,
  input  wire [3:0] btn,
  output wire [15:0] led
);

  logic sys_rst;
  assign sys_rst = btn[0];

  instruction_mmu my_instruction_mmu (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),

    // TODO: rename these signals... for a multicore processor, it's gonna be
    // packed versions of these, along with a core # input
    .fetch_request_ready_out(),
    .fetch_request_valid_in(),
    .fetch_request_address_in(),
    .fetch_response_ready_in(),
    .fetch_response_valid_out(),
    .fetch_response_data_out(),
  );

  data_mmu my_data_mmu (
  .clk_in(clk_100mhz),
  .rst_in(sys_rst)

  .cpu_request_ready_out(),
  .cpu_request_valid_in(),
  .cpu_request_address_in(),
  .cpu_request_operation_in(),
  .cpu_request_data_in(),
  .cpu_response_ready_in(),
  .cpu_response_valid_out(),
  .cpu_response_data_out(),
);

  processor_core my_single_processor_core (
    // TODO
  );

endmodule

`default_nettype wire
