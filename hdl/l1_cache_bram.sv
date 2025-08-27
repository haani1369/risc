`default_nettype none

import help::*;
import cache_help::*;

module l1_cache_bram (
  input wire clk_in,
  input wire rst_in,

  output logic cpu_request_ready_out,
  input wire cpu_request_valid_in,
  input wire Word cpu_request_address_in,
  input wire MemoryOperation cpu_request_operation_in,
  input wire Word cpu_request_data_in,
  input wire cpu_response_ready_in,
  output logic cpu_response_valid_out,
  output Word cpu_response_data_out,

  input wire l2_cache_request_ready_in,
  output logic l2_cache_request_valid_out,
  output Word l2_cache_request_address_out,
  output MemoryOperation l2_cache_request_operation_out,
  output Line l2_cache_request_data_out,
  output logic l2_cache_response_ready_out,
  input wire l2_cache_response_valid_in,
  input wire Line l2_cache_response_data_in
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
  Word current_request_address;
  Word current_request_data;

  CacheWordOffset request_cache_word_offset;
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
      && cpu_request_valid_in
    );
    issue_array_write = (
      (state == LOOKUP && is_hit && current_request_operation == STORE)
      || state == FILL
    );


    cpu_request_ready_out = state == READY;
    cpu_response_valid_out = (
      state == LOOKUP && is_hit && current_request_operation == LOAD
    );
    l2_cache_request_valid_out = (
      (state == LOOKUP && !is_hit)
      || state == WRITEBACK
    );
    l2_cache_response_ready_out = state == FILL;
  end


  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= READY;
    end else begin
      case (state)
        READY: begin
          if (cpu_request_valid_in) begin
            // issue read from the brams
            request_cache_word_offset <= getCacheWordOffset(cpu_request_address_in);
            request_cache_tag <= getCacheTag(cpu_request_address_in);
            request_cache_index <= getCacheIndex(cpu_request_address_in);
            request_memory_line_address <= getMemoryLineAddress(
              cpu_request_address_in
            );

            current_request_address <= cpu_request_address_in;
            current_request_data <= cpu_request_data_in;
            current_request_operation <= cpu_request_operation_in;
            state <= LOOKUP;
          end else begin
            // do nothing
          end
        end


        LOOKUP: begin
          if (is_hit) begin
            if (current_request_operation == STORE) begin
              new_cache_tag <= request_cache_tag;
              new_cache_line_status <= DIRTY;
              for (int i = 0; i < CACHE_WORDS_PER_LINE; i++) begin
                if (i == request_cache_word_offset) begin
                  new_cache_line[i] <= current_request_data;
                end else begin
                  new_cache_line[i] <= retrieved_cache_line[i];
                end
              end

              state <= READY;
            end else begin // load
              cpu_response_data_out <= retrieved_cache_line[request_cache_word_offset];

              state <= cpu_response_ready_in? READY : LOOKUP;
            end
          end else begin // miss
            if (l2_cache_request_ready_in) begin
              if (
                retrieved_cache_line_status == CLEAN 
                || retrieved_cache_line_status == NOT_VALID
              ) begin // clean
                // just forward the request
                l2_cache_request_data_out <= current_request_data;
                l2_cache_request_address_out <= current_request_address;
                l2_cache_request_operation_out <= LOAD;

                state <= FILL;
              end else begin // dirty
                // writeback the dirty line
                l2_cache_request_data_out <= retrieved_cache_line;
                l2_cache_request_address_out <= {
                  retrieved_cache_tag,
                  request_cache_index,
                  {CACHE_WORD_OFFSET_WIDTH{1'b0}}
                };
                l2_cache_request_operation_out <= STORE;
                
                state <= WRITEBACK;
              end
            end else begin
              // do nothing
            end
          end
        end


        WRITEBACK: begin
          if (l2_cache_request_ready_in) begin
            l2_cache_request_data_out <= current_request_data;
            l2_cache_request_address_out <= current_request_address;
            l2_cache_request_operation_out <= LOAD;

            state <= FILL;
          end else begin
            // do nothing
          end
        end


        FILL: begin
          if (l2_cache_response_valid_in) begin
            if (current_request_operation == STORE) begin
              new_cache_line_status <= DIRTY;
              for (int i = 0; i < CACHE_WORDS_PER_LINE; i++) begin
                if (i == request_cache_word_offset) begin
                  new_cache_line[i] <= current_request_data;
                end else begin
                  new_cache_line[i] <= l2_cache_response_data_in[i];
                end
              end
            end else begin
              new_cache_line_status <= CLEAN;
              new_cache_line <= l2_cache_response_data_in;
            end
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