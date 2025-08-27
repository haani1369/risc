`default_nettype none

import processor_help::*;

module rename (
  input wire clk_in,
  input wire rst_in,

  output logic decode_ready_out,
  input wire decode_valid_in,
  input wire DecodeResult decode_payload_in [SUPER_SCALAR_WIDTH-1:0],

  input wire dispatch_ready_in,
  output logic dispatch_valid_out,
  output RenameResult dispatch_payload_out [SUPER_SCALAR_WIDTH-1:0],

  input wire retire_valid_in [SUPER_SCALAR_WIDTH-1:0],
  input wire [$clog2(PHYSICAL_REGISTER_FILE_SIZE)-1:0] retire_freed_register_in [SUPER_SCALAR_WIDTH-1:0]
);

  logic decode_handshake [SUPER_SCALAR_WIDTH-1:0];
  logic dispatch_handshake [SUPER_SCALAR_WIDTH-1:0];

  // free list stuff
  localparam FREELIST_DEPTH = PHYSICAL_REGISTER_FILE_SIZE - ARCHITECTURAL_REGISTER_COUNT;
  localparam FREELIST_POINTER_WIDTH = $clog2(FREELIST_DEPTH);

  logic [FREELIST_POINTER_WIDTH-1:0] head_pointer;
  logic [FREELIST_POINTER_WIDTH-1:0] tail_pointer;
  logic [FREELIST_POINTER_WIDTH-1:0] next_head_pointer;
  logic [FREELIST_POINTER_WIDTH-1:0] next_tail_pointer;

  logic [$clog2(FREELIST_DEPTH+1)-1:0] count;
  logic [$clog2(FREELIST_DEPTH+1)-1:0] next_count;

  logic [$clog2(PHYSICAL_REGISTER_FILE_SIZE)-1:0] freelist_buffer [FREELIST_DEPTH-1:0];
  logic [$clog2(PHYSICAL_REGISTER_FILE_SIZE)-1:0] allocated_indices [SUPER_SCALAR_WIDTH-1:0];

  logic reclaimed_bitvector [SUPER_SCALAR_WIDTH-1:0];
  logic allocated_bitvector [SUPER_SCALAR_WIDTH-1:0];
  logic allocation_mask [SUPER_SCALAR_WIDTH-1:0];

  // rat stuff
  logic [$clog2(PHYSICAL_REGISTER_FILE_SIZE)-1:0] frontend_rat [ARCHITECTURAL_REGISTER_COUNT-1:0];

  logic [$clog2(PHYSICAL_REGISTER_FILE_SIZE)-1:0] final_physical_src1 [SUPER_SCALAR_WIDTH-1:0];
  logic [$clog2(PHYSICAL_REGISTER_FILE_SIZE)-1:0] final_physical_src2 [SUPER_SCALAR_WIDTH-1:0];

  logic [$clog2(SUPER_SCALAR_WIDTH+1)-1:0] retire_count;

  // signals
  always_comb begin
    for (int i = 0; i < SUPER_SCALAR_WIDTH; i++) begin
      allocation_mask[i] = writes_to_register(decode_payload_in[i]);
    end
    decode_ready_out = count >= $countones(allocation_mask) && dispatch_ready_in;
    retire_count = $countones(retire_valid_in);
  end

  // logic
  always_comb begin
    for (int i = 0; i < SUPER_SCALAR_WIDTH; i=i+1) begin
      allocated_bitvector[i] = decode_valid_in && writes_to_register(decode_payload_in[i]);
    end

    for (int i = 0; i < SUPER_SCALAR_WIDTH; i=i+1) begin
      if (allocated_bitvector[i]) begin
        logic [$clog2(SUPER_SCALAR_WIDTH+1)-1:0] alloc_offset = 0;
        for (int j = 0; j < i; j++) begin
          if (allocated_bitvector[j]) alloc_offset++;
        end
        allocated_indices[i] = freelist_buffer[head_pointer + alloc_offset];
      end else begin
        allocated_indices[i] = '0; // Don't care
      end
    end

    reclaimed_bitvector = retire_valid_in;

    next_head_pointer = ($countones(allocated_bitvector) + head_pointer >= FREELIST_DEPTH)?
      head_pointer + $countones(allocated_bitvector) - FREELIST_DEPTH
      : head_pointer + $countones(allocated_bitvector);
    next_tail_pointer = ($countones(reclaimed_bitvector) + tail_pointer >= FREELIST_DEPTH)?
      tail_pointer + $countones(reclaimed_bitvector) - FREELIST_DEPTH
      : tail_pointer + $countones(reclaimed_bitvector);
    next_count = count + $countones(reclaimed_bitvector) - $countones(allocated_bitvector);
  end

  always_comb begin // dependency forwarding
    if (decode_valid_in && decode_ready_out) begin
      for (int i = 0; i < SUPER_SCALAR_WIDTH; i=i+1) begin
        final_physical_src1[i] = frontend_rat[decode_payload_in[i].source_register_1];
        final_physical_src2[i] = frontend_rat[decode_payload_in[i].source_register_2];

        for (int j = 0; j < i; j=j+1) begin
          if (
            (decode_valid_in && writes_to_register(decode_payload_in[j]))
            && (
              decode_payload_in[j].destination_register 
              == decode_payload_in[i].source_register_1
            )
          ) begin
            final_physical_src1[i] = allocated_indices[j];
          end else begin
            // do nothing
          end
          if (
            (decode_valid_in && writes_to_register(decode_payload_in[j]))
            && (
              decode_payload_in[j].destination_register 
              == decode_payload_in[i].source_register_2
            )
          ) begin
            final_physical_src2[i] = allocated_indices[j];
          end else begin
            // do nothing
          end
        end
      end
    end else begin
      // do nothing
    end
  end

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      // freelist
      head_pointer <= '0;
      tail_pointer <= '0;
      count <= FREELIST_DEPTH;
      for (int i = 0; i < FREELIST_DEPTH; i=i+1) begin
        freelist_buffer[i] <= ARCHITECTURAL_REGISTER_COUNT + i;
      end

      // rat
      for (int i = 0; i < ARCHITECTURAL_REGISTER_COUNT; i=i+1) begin
        frontend_rat[i] <= i;
      end

      dispatch_valid_out <= 1'b0;
    end else begin
      if (decode_valid_in && decode_ready_out) begin
        for (int i = 0; i < SUPER_SCALAR_WIDTH; i=i+1) begin
          dispatch_payload_out[i].source_register_1 <= final_physical_src1[i];
          dispatch_payload_out[i].source_register_2 <= final_physical_src2[i];
          dispatch_payload_out[i].destination_register <= allocated_indices[i];
          dispatch_payload_out[i].instruction_type <= decode_payload_in[i].instruction_type;
          dispatch_payload_out[i].branch_operation <= decode_payload_in[i].branch_operation;
          dispatch_payload_out[i].memory_operation <= decode_payload_in[i].memory_operation;
          dispatch_payload_out[i].alu_operation <= decode_payload_in[i].alu_operation;
          dispatch_payload_out[i].immediate <= decode_payload_in[i].immediate;
        end

        for (int i = 0; i < SUPER_SCALAR_WIDTH; i=i+1) begin
          if (allocated_bitvector[i]) begin
            frontend_rat[decode_payload_in[i].destination_register] <= allocated_indices[i];
          end
        end

        head_pointer <= next_head_pointer;
        count <= next_count;

        dispatch_valid_out <= 1'b1;
      end else begin
        dispatch_valid_out <= 1'b0;
      end

      // reclaim stuff
      tail_pointer <= next_tail_pointer;
      if (retire_count > 0) begin
        for (int j = 0; j < SUPER_SCALAR_WIDTH; j++) begin
          if (retire_valid_in[j]) begin
            freelist_buffer[(tail_pointer + j) % FREELIST_DEPTH] <= retire_freed_register_in[j];
          end
        end
      end
    end
  end

  function logic writes_to_register(DecodeResult payload);
    return (
      payload.instruction_type == LUI
      || payload.instruction_type == JAL
      || payload.instruction_type == JALR
      || payload.instruction_type == LOAD
      || payload.instruction_type == OP_IMM_NORMAL
      || payload.instruction_type == OP_IMM_SHIFT
      || payload.instruction_type == OP_NORMAL
      || payload.instruction_type == OP_SHIFT
    );
  endfunction

endmodule

`default_nettype wire
