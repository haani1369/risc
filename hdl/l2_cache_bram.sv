`default_nettype none

import help::*;
import cache_help::*;

module l2_cache_bram (
  input wire clk_in,
  input wire rst_in,

  output logic l1_cache_request_ready_out,
  input wire l1_cache_request_valid_in,
  input wire Word l1_cache_request_address_in,
  input wire MemoryOperation l1_cache_request_operation_in,
  input wire Line l1_cache_request_data_in,
  input wire l1_cache_response_ready_in,
  output logic l1_cache_response_valid_out,
  output Line l1_cache_response_data_out,

  input wire main_memory_request_ready_in,
  output logic main_memory_request_valid_out,
  output Word main_memory_request_address_out,
  output MemoryOperation main_memory_request_operation_out,
  output Line main_memory_request_data_out,
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
  ) l2_line_bram (
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
  ) l2_tag_bram (
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
  ) l2_line_status_bram (
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
  Line current_request_data;

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
      && l1_cache_request_valid_in
    );
    issue_array_write = (
      (state == LOOKUP && is_hit && current_request_operation == STORE)
      || state == FILL
    );


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
            current_request_data <= l1_cache_request_data_in;
            current_request_operation <= l1_cache_request_operation_in;
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
              new_cache_line <= current_request_data;

              state <= READY;
            end else begin // load
              l1_cache_response_data_out <= retrieved_cache_line;

              state <= l1_cache_response_ready_in? READY : LOOKUP;
            end
          end else begin // miss
            if (main_memory_request_ready_in) begin
              if (
                retrieved_cache_line_status == CLEAN 
                || retrieved_cache_line_status == NOT_VALID
              ) begin // clean
                // just forward the request
                main_memory_request_data_out <= current_request_data;
                main_memory_request_address_out <= current_request_address;
                main_memory_request_operation_out <= LOAD;

                state <= FILL;
              end else begin // dirty
                // writeback the dirty line
                main_memory_request_data_out <= retrieved_cache_line;
                main_memory_request_address_out <= {
                  retrieved_cache_tag,
                  request_cache_index,
                  {CACHE_WORD_OFFSET_WIDTH{1'b0}}
                };
                main_memory_request_operation_out <= STORE;
                
                state <= WRITEBACK;
              end
            end else begin
              // do nothing
            end
          end
        end


        WRITEBACK: begin
          if (main_memory_request_ready_in) begin
            main_memory_request_data_out <= current_request_data;
            main_memory_request_address_out <= current_request_address;
            main_memory_request_operation_out <= LOAD;

            state <= FILL;
          end else begin
            // do nothing
          end
        end


        FILL: begin
          if (main_memory_response_valid_in) begin
            if (current_request_operation == STORE) begin
              new_cache_line_status <= DIRTY;
              new_cache_line <= current_request_data;
            end else begin
              new_cache_line_status <= CLEAN;
              new_cache_line <= main_memory_response_data_in;
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