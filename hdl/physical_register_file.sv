`default_nettype none

import processor_help::*;

module physical_register_file (
  input wire clk_in,
  input wire rst_in,

  input wire RegisterFileReadRequest read_ports_reg0_request_in [SUPER_SCALAR_WIDTH-1:0],
  input wire RegisterFileReadRequest read_ports_reg1_request_in [SUPER_SCALAR_WIDTH-1:0],
  input wire RegisterFileWriteRequest write_ports_reg_request_in [SUPER_SCALAR_WIDTH-1:0],
  output RegisterFileReadResponse read_ports_reg0_response_out [SUPER_SCALAR_WIDTH-1:0],
  output RegisterFileReadResponse read_ports_reg1_response_out [SUPER_SCALAR_WIDTH-1:0]
);
  Word actual_register_file [PHYSICAL_REGISTER_FILE_SIZE-1:0];

  always @(posedge clk_in) begin
    for (int i = 0; i < SUPER_SCALAR_WIDTH; i=i+1) begin
      if (write_ports_reg_request_in[i].write_enable) begin
        actual_register_file[i][
          write_ports_reg_request_in.register
        ] <= write_ports_reg_request_in[i].data;
      end
    end
  end

  always_comb begin
    for (int i = 0; i < SUPER_SCALAR_WIDTH; i=i+1) begin
      read_ports_reg0_response_out = actual_register_file[i][read_ports_reg0_request_in[i]];
      read_ports_reg1_response_out = actual_register_file[i][read_ports_reg1_request_in[i]];
    end
  end

endmodule

`default_nettype wire
