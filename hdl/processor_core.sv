`default_nettype none


import processor_help::*;

module processor_core (
  input wire clk_in,
  input wire rst_in

  input wire instruction_mmu_request_ready_in,
  output logic instruction_mmu_request_valid_out,
  output Word instruction_mmu_request_address_out,
  output logic instruction_mmu_response_ready_out,
  input wire instruction_mmu_response_valid_in,
  input wire Word instruction_mmu_response_data_in

  input wire data_mmu_request_ready_in,
  output logic data_mmu_request_valid_out,
  output Word data_mmu_request_address_out,
  output MemoryOperation data_mmu_request_operation_out,
  output Word data_mmu_request_data_out,
  output logic data_mmu_response_ready_out,
  input wire data_mmu_response_valid_in,
  input wire Word data_mmu_response_data_in
);

  // fetch -> decode comms
  logic fetch_decode_request_ready;
  logic fetch_decode_request_valid;
  FetchRequest fetch_decode_request_payload;
  logic fetch_decode_response_ready;
  logic fetch_decode_response_valid;
  FetchResult fetch_decode_response_payload;

  fetch my_fetch (
    .clk_in(clk_in),
    .rst_in(rst_in),

    .instruction_mmu_request_ready_in(instruction_mmu_request_ready_in),
    .instruction_mmu_request_valid_out(instruction_mmu_request_valid_out),
    .instruction_mmu_request_address_out(instruction_mmu_request_address_out),
    .instruction_mmu_response_ready_out(instruction_mmu_response_ready_out),
    .instruction_mmu_response_valid_in(instruction_mmu_response_valid_in),
    .instruction_mmu_response_data_in(instruction_mmu_response_data_in)

    // TODO: change relevant signals to come from branch predict
    .cpu_request_ready_out(fetch_decode_request_ready),
    .cpu_request_valid_in(fetch_decode_request_valid),
    .cpu_request_payload_in(fetch_decode_request_payload),
    .cpu_response_ready_in(fetch_decode_response_ready),
    .cpu_response_valid_out(fetch_decode_response_valid),
    .cpu_response_payload_out(fetch_decode_response_payload),
  );

  decode my_decode (
    .clk_in(),
    .rst_in(),

    .fetch_ready_out(),
    .fetch_valid_in(),
    .fetch_data_in(),

    .rename_ready_in(),
    .rename_valid_out(),
    .rename_payload_out()
  );

  rename my_rename (
    .clk_in(),
    .rst_in(),

    .decode_ready_out(),
    .decode_valid_in(),
    .decode_payload_in(),

    .execute_ready_in(),
    .execute_valid_out(),
    .execute_payload_out(),
  );

  execute my_execute (
    .clk_in(),
    .rst_in(),

    .decode_ready_out(),
    .decode_valid_in(),
    .decode_payload_in(),

    .writeback_ready_in(),
    .writeback_valid_out(),
    .writeback_payload_out()
  );

endmodule


`default_nettype wire
