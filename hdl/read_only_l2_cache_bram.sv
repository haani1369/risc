`default_nettype none

import help::*;
import cache_help::*;

module read_only_l2_cache_bram (
  input wire clk_in,
  input wire rst_in,

  output logic l1_cache_request_ready_out,
  input wire l1_cache_request_valid_in,
  input wire Word l1_cache_request_address_in,
  input wire l1_cache_response_ready_in,
  output logic l1_cache_response_valid_out,
  output Line l1_cache_response_data_out,

  input wire main_memory_request_ready_in,
  output logic main_memory_request_valid_out,
  output Word main_memory_request_address_out,
  output logic main_memory_response_ready_out,
  input wire main_memory_response_valid_in,
  input wire Line main_memory_response_data_in
);

  // region local brams


  // read/write signals
  logic issue_array_write;
  logic issue_array_read;

  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(LINE_SIZE),
    .RAM_DEPTH(CACHE_SETS),
    .RAM_PERFORMANCE("LOW_LATENCY"),
    .INIT_FILE("")
  ) l1_line_bram (
    .clka(clk_in),
    .addra(request_cache_index),
    .dina(new_cache_line),
    .wea(issue_array_write),
    .ena(1'b1),
    .rsta(1'b0),
    .regcea(issue_array_read),
    .douta(retrieved_cache_line)
  );

  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(CACHE_TAG_WIDTH),
    .RAM_DEPTH(CACHE_SETS),
    .RAM_PERFORMANCE("LOW_LATENCY"),
    .INIT_FILE("")
  ) l1_tag_bram (
    .clka(clk_in),
    .addra(request_cache_index),
    .dina(new_cache_tag),
    .wea(issue_array_write),
    .ena(1'b1),
    .rsta(1'b0),
    .regcea(issue_array_read),
    .douta(retrieved_cache_tag)
  );

  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(CACHE_LINE_STATUS_WIDTH),
    .RAM_DEPTH(CACHE_SETS),
    .RAM_PERFORMANCE("LOW_LATENCY"),
    .INIT_FILE("")
  ) l1_line_status_bram (
    .clka(clk_in),
    .addra(request_cache_index),
    .dina(new_cache_line_status),
    .wea(issue_array_write),
    .ena(1'b1),
    .rsta(1'b0),
    .regcea(issue_array_read),
    .douta(retrieved_cache_line_status)
  );


  // endregion local brams


  // region actual logic
  CacheRequestStatus state;

  MemoryOperation current_request_operation;
  assign current_request_operation = LOAD;
  Word current_request_address;

  CacheIndex request_cache_index;
  CacheTag request_cache_tag;
  MemoryLineAddress request_memory_line_address;

  // this is the result from the bram
  CacheTag retrieved_cache_tag;
  CacheLineStatus retrieved_cache_line_status;
  Line retrieved_cache_line;

  // this is what will be written
  CacheTag new_cache_tag;
  CacheLineStatus new_cache_line_status;
  Line new_cache_line;

  logic is_hit;
  always_comb begin
    is_hit = (
      request_cache_tag == retrieved_cache_tag 
      && retrieved_cache_line_status != NOT_VALID
    );

    issue_array_read = (
      state == READY
      && l1_cache_request_valid_in
    );
    issue_array_write = state == FILL;

    l1_cache_request_ready_out = state == READY;
    l1_cache_response_valid_out = (
      state == LOOKUP && is_hit && current_request_operation == LOAD
    );
    main_memory_request_valid_out = (
      (state == LOOKUP && !is_hit)
      || state == WRITEBACK
    );
    main_memory_response_ready_out = state == FILL;
  end


  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= READY;
    end else begin
      case (state)
        READY: begin
          if (l1_cache_request_valid_in) begin
            // issue read from the brams
            request_cache_word_offset <= getCacheWordOffset(l1_cache_request_address_in);
            request_cache_tag <= getCacheTag(l1_cache_request_address_in);
            request_cache_index <= getCacheIndex(l1_cache_request_address_in);
            request_memory_line_address <= getMemoryLineAddress(
              l1_cache_request_address_in
            );

            current_request_address <= l1_cache_request_address_in;
            state <= LOOKUP;
          end else begin
            // do nothing
          end
        end


        LOOKUP: begin
          if (is_hit) begin
            l1_cache_response_data_out <= retrieved_cache_line;

            state <= l1_cache_response_ready_in? READY : LOOKUP;
          end else begin // miss
            if (main_memory_request_ready_in) begin
              // just forward the request
              main_memory_request_address_out <= current_request_address;

              state <= FILL;
            end else begin
              // do nothing
            end
          end
        end

        WRITEBACK: begin
          if (main_memory_request_ready_in) begin
            main_memory_request_address_out <= current_request_address;

            state <= FILL;
          end else begin
            // do nothing
          end
        end

        FILL: begin
          if (main_memory_response_valid_in) begin
            new_cache_line_status <= CLEAN;
            new_cache_line <= main_memory_response_data_in;
            new_cache_tag <= request_cache_tag;

            state <= READY;
          end else begin
            // do nothing
          end
        end

        default: begin
          state <= READY;
        end

      endcase
    end
  end

  // endregion actual logic

endmodule

`default_nettype wire