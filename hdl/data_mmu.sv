`default_nettype none

import help::*;
import cache_help::*;

module data_mmu (
  input wire clk_in,
  input wire rst_in

  output logic cpu_request_ready_out,
  input wire cpu_request_valid_in,
  input wire Word cpu_request_address_in,
  input wire MemoryOperation cpu_request_operation_in,
  input wire Word cpu_request_data_in,
  input wire cpu_response_ready_in,
  output logic cpu_response_valid_out,
  output Word cpu_response_data_out,
);

  // l1 -> l2 cache comms
  logic l1_l2_cache_request_ready;
  logic l1_l2_cache_request_valid;
  Word l1_l2_cache_request_address;
  MemoryOperation l1_l2_cache_request_operation;
  Line l1_l2_cache_request_data;
  logic l1_l2_cache_response_ready;
  logic l1_l2_cache_response_valid;
  Line l1_l2_cache_response_data;
  // l2 -> main memory comms
  logic l2_cache_main_memory_request_ready;
  logic l2_cache_main_memory_request_valid;
  Word l2_cache_main_memory_request_address;
  MemoryOperation l2_cache_main_memory_request_operation;
  Line l2_cache_main_memory_request_data;
  logic l2_cache_main_memory_response_ready;
  logic l2_cache_main_memory_response_valid;
  Line l2_cache_main_memory_response_data;


  l1_cache_bram my_l1_cache (
    .clk_in(clk_in),
    .rst_in(rst_in),

    .cpu_request_ready_out(cpu_request_ready_out),
    .cpu_request_valid_in(cpu_request_valid_in),
    .cpu_request_address_in(cpu_request_address_in),
    .cpu_request_operation_in(cpu_request_operation_in),
    .cpu_request_data_in(cpu_request_data_in),
    .cpu_response_ready_in(cpu_response_ready_in),
    .cpu_response_valid_out(cpu_response_valid_out),
    .cpu_response_data_out(cpu_response_data_out),

    .l2_cache_request_ready_in(l1_l2_cache_request_ready),
    .l2_cache_request_valid_out(l1_l2_cache_request_valid),
    .l2_cache_request_address_out(l1_l2_cache_request_address),
    .l2_cache_request_operation_out(l1_l2_cache_request_operation),
    .l2_cache_request_data_out(l1_l2_cache_request_data),
    .l2_cache_response_ready_out(l1_l2_cache_response_ready),
    .l2_cache_response_valid_in(l1_l2_cache_response_valid),
    .l2_cache_response_data_in(l1_l2_cache_response_data)
  );


  l2_cache_bram my_l2_cache (
    .clk_in(clk_in),
    .rst_in(rst_in),

    .l1_cache_request_ready_out(l1_l2_cache_request_ready),
    .l1_cache_request_valid_in(l1_l2_cache_request_valid),
    .l1_cache_request_address_in(l1_l2_cache_request_address),
    .l1_cache_request_operation_in(l1_l2_cache_request_operation),
    .l1_cache_request_data_in(l1_l2_cache_request_data),
    .l1_cache_response_ready_in(l1_l2_cache_response_ready),
    .l1_cache_response_valid_out(l1_l2_cache_response_valid),
    .l1_cache_response_data_out(l1_l2_cache_response_data),

    .main_memory_request_ready_in(l2_cache_main_memory_request_ready),
    .main_memory_request_valid_out(l2_cache_main_memory_request_valid),
    .main_memory_request_address_out(l2_cache_main_memory_request_address),
    .main_memory_request_operation_out(l2_cache_main_memory_request_operation),
    .main_memory_request_data_out(l2_cache_main_memory_request_data),
    .main_memory_response_ready_out(l2_cache_main_memory_response_ready),
    .main_memory_response_valid_in(l2_cache_main_memory_response_valid),
    .main_memory_response_data_in(l2_cache_main_memory_response_data)
  );

  Line main_memory_data;
  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(LINE_SIZE),
    .RAM_DEPTH(CACHE_SETS),
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
    .INIT_FILE("") // TODO: load with actual programs or smth
  ) data_memory (
    .clka(clk_in),
    .addra(l2_cache_main_memory_request_address),
    .dina(),
    .wea(1'b0),
    .ena(1'b1),
    .rsta(1'b0),
    .regcea(1'b1),
    .douta(main_memory_data)
  );

  // basic main memory state machine
  logic [1:0] memory_state_count;
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      l2_cache_main_memory_request_ready <= 1'b1;
      l2_cache_main_memory_response_valid <= 1'b0;

      memory_state_count <= 2'b0;
    end else begin
      if (memory_state_count == 2'b0 && l2_cache_main_memory_request_valid) begin
        l2_cache_main_memory_request_ready <= 1'b0;
        memory_state_count <= memory_state_count + 1;
      end else if (memory_state_count == 2'b01) begin
        memory_state_count <= memory_state_count + 1;
      end else if (memory_state_count == 2'b10) begin
        l2_cache_main_memory_response_data <= main_memory_data;
        l2_cache_main_memory_response_valid <= 1'b1;
        memory_state_count <= 2'b11;
      end else if (memory_state_count <= 2'b11) begin
        if (l2_cache_main_memory_response_data && l2_cache_main_memory_response_ready) begin
          l2_cache_main_memory_response_valid <= 1'b0;
          l2_cache_main_memory_request_ready <= 1'b1;
          memory_state_count <= 2'b0;
        end
      end else begin
        // do nothing
      end
    end
  end

endmodule


`default_nettype wire
