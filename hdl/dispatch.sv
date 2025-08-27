`default_nettype none

import processor_help::*;

module dispatch (
  input wire clk_in,
  input wire rst_in,

  output logic rename_ready_out,
  input wire rename_valid_in,
  input wire RenameResult rename_payload_in [SUPER_SCALAR_WIDTH-1:0]

  input wire execute_ready_in,
  output logic execute_valid_out,
  output DispatchResult execute_payload_out
);


endmodule

`default_nettype wire
