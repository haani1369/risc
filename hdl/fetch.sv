`default_nettype none


import processor_help::*;

module fetch (
  input wire clk_in,
  input wire rst_in,

  input wire cpu_request_valid_in,
  input wire FetchRequest cpu_request_payload_in,
  output logic cpu_request_ready_out,
  input wire cpu_response_ready_in,
  output logic cpu_response_valid_out,
  output FetchResult cpu_response_payload_out,

  input wire instruction_mmu_request_ready_in,
  output logic instruction_mmu_request_valid_out,
  output logic instruction_mmu_request_address_out,
  output logic instruction_mmu_response_ready_out,
  input wire instruction_mmu_response_valid_in,
  input wire Word instruction_mmu_response_data_in
);

  typedef enum {
    READY,
    FETCHING
  } FetchState;

  FetchState state;

  Word current_pc;
  logic ignore_fetched_instruction;

  always_comb begin
    cpu_response_payload_out = FetchResult {
      instruction: instruction_mmu_response_data_in,
      pc: current_pc
    };

    case (cpu_request_payload_in.operation)
      STALL: begin 
        instruction_mmu_request_address_out = current_pc; 
      end
      DEQUEUE: begin
        instruction_mmu_request_address_out = current_pc + 1;
      end
      REDIRECT: begin
        instruction_mmu_request_address_out = cpu_request_payload_in.redirect_pc;
      end
      default: begin
        instruction_mmu_request_address_out = 0;
      end
    endcase

    cpu_request_ready_out = instruction_mmu_request_ready_in;
    instruction_mmu_request_valid_out = cpu_request_valid_in;
    cpu_response_valid_out = (
      !ignore_fetched_instruction 
      && instruction_mmu_response_valid_in
    );
    instruction_mmu_response_ready_out = !instruction_mmu_request_ready_in; // TODO: check if this is legal
  end

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= READY;
    end else begin
      if (instruction_mmu_request_ready_in && cpu_request_valid_in) begin
        current_pc <= cpu_request_payload_in.operation == STALL?
          current_pc
          : cpu_request_payload_in.operation == DEQUEUE? 
            current_pc + 1 
            : cpu_request_payload_in.redirect_pc;
        ignore_fetched_instruction <= 1'b0;
      end else if (cpu_request_valid_in) begin // TODO: compare with minispec fetch
        if (cpu_request_payload_in.operation == REDIRECT) begin
          ignore_fetched_instruction <= 1'b1;
          current_pc <= cpu_request_payload_in.redirect_pc;
        end
      end
    end
  end

  
endmodule


`default_nettype wire
