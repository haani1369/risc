`default_nettype none

import processor_help::*;

module rename (
  input wire clk_in,
  input wire rst_n,

  output logic decode_ready_out,
  input wire decode_valid_in,
  input DecodeResult decode_payload_in [SUPER_SCALAR_WIDTH-1:0],

  input wire dispatch_ready_in,
  output logic dispatch_valid_out,
  output RenameResult dispatch_payload_out [SUPER_SCALAR_WIDTH-1:0],

  input wire [SUPER_SCALAR_WIDTH-1:0] retire_valid_in,
  input wire [$clog2(PHYSICAL_REGISTER_FILE_SIZE)-1:0] retire_freed_register_in [SUPER_SCALAR_WIDTH-1:0]
);

  localparam FREELIST_DEPTH = PHYSICAL_REGISTER_FILE_SIZE - ARCHITECTURAL_REGISTER_COUNT;
  localparam FREELIST_POINTER_WIDTH = $clog2(FREELIST_DEPTH);

  logic [FREELIST_POINTER_WIDTH-1:0] head_ptr;
  logic [FREELIST_POINTER_WIDTH-1:0] tail_ptr;
  logic [FREELIST_POINTER_WIDTH-1:0] head_ptr_next;
  logic [FREELIST_POINTER_WIDTH-1:0] tail_ptr_next;

  logic [$clog2(FREELIST_DEPTH+1)-1:0] count_reg;
  logic [$clog2(FREELIST_DEPTH+1)-1:0] count_next;

  logic [$clog2(PHYSICAL_REGISTER_FILE_SIZE)-1:0] freelist_buffer [FREELIST_DEPTH-1:0];
  logic [$clog2(PHYSICAL_REGISTER_FILE_SIZE)-1:0] allocated_indices [SUPER_SCALAR_WIDTH-1:0];

  logic [$clog2(SUPER_SCALAR_WIDTH+1)-1:0] num_allocated;
  logic [$clog2(SUPER_SCALAR_WIDTH+1)-1:0] num_reclaimed;

  // Combinational read for freelist
  genvar gen_i;
  generate
    for (gen_i = 0; gen_i < SUPER_SCALAR_WIDTH; gen_i++) begin : alloc_read_ports
      assign allocated_indices[gen_i] = freelist_buffer[head_ptr + gen_i];
    end
  endgenerate

  logic [$clog2(PHYSICAL_REGISTER_FILE_SIZE)-1:0] frontend_rat [ARCHITECTURAL_REGISTER_COUNT-1:0];

  always_comb begin
    num_allocated = '0;
    for (int j = 0; j < SUPER_SCALAR_WIDTH; j++) begin
      if (decode_valid_in && writes_to_register(decode_payload_in[j])) begin
        num_allocated = num_allocated + 1;
      end
    end

    num_reclaimed = $countones(retire_valid_in);
    head_ptr_next = head_ptr + num_allocated;
    tail_ptr_next = tail_ptr + num_reclaimed;
    count_next = count_reg + num_reclaimed - num_allocated;
  end


  always_ff @(posedge clk_in or negedge rst_n) begin
    if (!rst_n) begin
      // Reset pipeline outputs
      dispatch_valid_out <= 1'b0;
      for (int i = 0; i < SUPER_SCALAR_WIDTH; i++) begin
        dispatch_payload_out[i] <= '0;
      end

      // Reset Free List
      head_ptr <= '0;
      tail_ptr <= '0;
      count_reg <= FREELIST_DEPTH;
      for (int j = 0; j < FREELIST_DEPTH; j++) begin
        freelist_buffer[j] <= ARCHITECTURAL_REGISTER_COUNT + j;
      end

      // Reset RAT
      for (int i = 0; i < ARCHITECTURAL_REGISTER_COUNT; i++) begin
        frontend_rat[i] <= i;
      end
    end else begin
      // Handle rename stage processing
      if (decode_valid_in && decode_ready_out && dispatch_ready_in) begin
        // Process each instruction in the rename group
        for (int i = 0; i < SUPER_SCALAR_WIDTH; i++) begin
          // RAT lookup for sources
          logic [$clog2(PHYSICAL_REGISTER_FILE_SIZE)-1:0] final_psrc1;
          logic [$clog2(PHYSICAL_REGISTER_FILE_SIZE)-1:0] final_psrc2;

          final_psrc1 = frontend_rat[decode_payload_in[i].source_register_1];
          final_psrc2 = frontend_rat[decode_payload_in[i].source_register_2];

          // Intra-group dependency forwarding
          for (int j = 0; j < i; j++) begin
            if (writes_to_register(decode_payload_in[j]) && 
                (decode_payload_in[j].destination_register == decode_payload_in[i].source_register_1)) begin
              final_psrc1 = allocated_indices[j];
            end
            if (writes_to_register(decode_payload_in[j]) && 
                (decode_payload_in[j].destination_register == decode_payload_in[i].source_register_2)) begin
              final_psrc2 = allocated_indices[j];
            end
          end

          // Register the final renamed instruction
          dispatch_payload_out[i].source_register_1 <= final_psrc1;
          dispatch_payload_out[i].source_register_2 <= final_psrc2;
          dispatch_payload_out[i].destination_register <= allocated_indices[i];
          dispatch_payload_out[i].instruction_type <= decode_payload_in[i].instruction_type;
          dispatch_payload_out[i].branch_operation <= decode_payload_in[i].branch_operation;
          dispatch_payload_out[i].memory_operation <= decode_payload_in[i].memory_operation;
          dispatch_payload_out[i].alu_operation <= decode_payload_in[i].alu_operation;
          dispatch_payload_out[i].immediate <= decode_payload_in[i].immediate;
        end

        dispatch_valid_out <= 1'b1;

        // Update internal rename state
        head_ptr <= head_ptr_next;
        count_reg <= count_next;
        
        // Update RAT with new mappings
        for (int i = 0; i < SUPER_SCALAR_WIDTH; i++) begin
          if (writes_to_register(decode_payload_in[i])) begin
            frontend_rat[decode_payload_in[i].destination_register] <= allocated_indices[i];
          end
        end
      end else begin
        dispatch_valid_out <= 1'b0;
      end

      // Reclamation logic (independent of handshake)
      tail_ptr <= tail_ptr_next;
      for (int j = 0; j < SUPER_SCALAR_WIDTH; j++) begin
        if (retire_valid_in[j]) begin
          freelist_buffer[tail_ptr + j] <= retire_freed_register_in[j];
        end
      end
    end
  end

  //============================================================================
  // Handshake Logic
  //============================================================================
  assign decode_ready_out = (count_reg >= num_allocated) && dispatch_ready_in;

  //============================================================================
  // Helper Function
  //============================================================================
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
