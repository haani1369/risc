`default_nettype none

import processor_help::*;

module decode (
  input wire clk_in,
  input wire rst_in,

  output logic fetch_ready_out,
  input wire fetch_valid_in,
  input wire Word fetch_payload_in [SUPER_SCALAR_WIDTH-1:0],

  input wire execute_ready_in,
  output logic execute_valid_out,
  output DecodeResult execute_payload_out [SUPER_SCALAR_WIDTH-1:0]
);

  logic rename_handshake [SUPER_SCALAR_WIDTH-1:0];
  logic fetch_handshake [SUPER_SCALAR_WIDTH-1:0];

  always_comb begin
    fetch_ready_out = !execute_valid_out || execute_ready_in; // only signalled if not stalled by rename!!!!!!

    rename_handshake = execute_ready_in && execute_valid_out;
    fetch_handshake = fetch_ready_out && fetch_valid_in;
  end

  Word program_counter;
  Word fetch_data_in;
  fetch_data_in = fetch_payload_in.instruction;
  program_counter = fetch_payload_in.program_counter;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      execute_valid_out <= 1'b0;
    end else begin
      if (fetch_handshake) begin // new data to decode and handoff
        for (int i = 0; i < SUPER_SCALAR_WIDTH; i=i+1) begin
          execute_payload_out[i].program_counter = program_counter;

          case (fetch_data_in[i][3:0]) // opcode
            LUI: begin
              execute_payload_out[i].instruction_type <= LUI;
              execute_payload_out[i].destination_register <= fetch_data_in[i][9:4];
              execute_payload_out[i].immediate <= {fetch_data_in[i][24:10], 10'b0};
            end

            JAL: begin
              execute_payload_out[i].instruction_type <= JAL;
              execute_payload_out[i].destination_register <= fetch_data_in[i][9:4];
              execute_payload_out[i].immediate <= {
                10{fetch_data_in[i][24]},
                fetch_data_in[i][24:10]
              };
            end

            JALR: begin
              execute_payload_out[i].instruction_type <= JALR;
              execute_payload_out[i].destination_register <= fetch_data_in[i][9:4];
              execute_payload_out[i].source_register_1 <= fetch_data_in[i][15:10];
              execute_payload_out[i].immediate <= {
                16{fetch_data_in[i][24]},
                fetch_data_in[i][24:16]
              };
            end

            BRANCH: begin
              execute_payload_out[i].source_register_1 <= fetch_data_in[i][12:7];
              execute_payload_out[i].source_register_2 <= fetch_data_in[i][18:13];
              execute_payload_out[i].immediate <= {
                19{fetch_data_in[i][24]},
                fetch_data_in[i][24:19]
              };

              case (fetch_data_in[i][6:4])
                EQ: begin
                  execute_payload_out[i].instruction_type <= BRANCH;
                  execute_payload_out[i].branch_operation <= EQ;
                end
                NEQ: begin
                  execute_payload_out[i].instruction_type <= BRANCH;
                  execute_payload_out[i].branch_operation <= NEQ;
                end
                LT: begin
                  execute_payload_out[i].instruction_type <= BRANCH;
                  execute_payload_out[i].branch_operation <= LT;
                end
                GE: begin
                  execute_payload_out[i].instruction_type <= BRANCH;
                  execute_payload_out[i].branch_operation <= GE;
                end
                LTU: begin
                  execute_payload_out[i].instruction_type <= BRANCH;
                  execute_payload_out[i].branch_operation <= LTU;
                end
                GEU: begin
                  execute_payload_out[i].instruction_type <= BRANCH;
                  execute_payload_out[i].branch_operation <= GEU;
                end
                default: begin
                  execute_payload_out[i].instruction_type <= UNSUPPORTED;
                end
              endcase
            end

            LOAD: begin
              execute_payload_out[i].instruction_type <= LOAD;
              execute_payload_out[i].destination_register <= fetch_data_in[i][9:4];
              execute_payload_out[i].source_register_1 <= fetch_data_in[i][15:10];
              execute_payload_out[i].immediate <= {
                16{fetch_data_in[i][24]},
                fetch_data_in[i][24:16]
              };
            end

            STORE: begin
              execute_payload_out[i].instruction_type <= STORE;
              execute_payload_out[i].source_register_1 <= fetch_data_in[i][9:4];
              execute_payload_out[i].source_register_2 <= fetch_data_in[i][15:10];
              execute_payload_out[i].immediate <= {
                16{fetch_data_in[i][24]},
                fetch_data_in[i][24:16]
              };
            end

            OP_IMM_NORMAL: begin
              execute_payload_out[i].destination_register <= fetch_data_in[i][12:7];
              execute_payload_out[i].source_register_1 <= fetch_data_in[i][18:13];
              execute_payload_out[i].immediate <= {
                19{fetch_data_in[i][24]},
                fetch_data_in[i][24:19]
              };

              case (fetch_data_in[i][6:4])
                3'b000: begin
                  execute_payload_out[i].instruction_type <= OP_IMM_NORMAL;
                  execute_payload_out[i].alu_operation <= ADD;
                end
                3'b001: begin
                  execute_payload_out[i].instruction_type <= OP_IMM_NORMAL;
                  execute_payload_out[i].alu_operation <= SLT;
                end
                3'b010: begin
                  execute_payload_out[i].instruction_type <= OP_IMM_NORMAL;
                  execute_payload_out[i].alu_operation <= SLTU;
                end
                3'b011: begin
                  execute_payload_out[i].instruction_type <= OP_IMM_NORMAL;
                  execute_payload_out[i].alu_operation <= XOR;
                end
                3'b100: begin
                  execute_payload_out[i].instruction_type <= OP_IMM_NORMAL;
                  execute_payload_out[i].alu_operation <= OR;
                end
                3'b101: begin
                  execute_payload_out[i].instruction_type <= OP_IMM_NORMAL;
                  execute_payload_out[i].branch_operation <= AND;
                end
                default: begin
                  execute_payload_out[i].instruction_type <= UNSUPPORTED;
                end
              endcase
            end

            OP_IMM_SHIFT: begin
              execute_payload_out[i].destination_register <= fetch_data_in[i][12:7];
              execute_payload_out[i].source_register_1 <= fetch_data_in[i][18:13];
              execute_payload_out[i].immediate <= {
                19{fetch_data_in[i][24]},
                fetch_data_in[i][24:19]
              };

              case (fetch_data_in[i][6:4])
                3'b000: begin
                  execute_payload_out[i].instruction_type <= OP_IMM_SHIFT;
                  execute_payload_out[i].alu_operation <= SLL;
                end
                3'b001: begin
                  execute_payload_out[i].instruction_type <= OP_IMM_SHIFT;
                  execute_payload_out[i].alu_operation <= SRL;
                end
                3'b010: begin
                  execute_payload_out[i].instruction_type <= OP_IMM_SHIFT;
                  execute_payload_out[i].alu_operation <= SRA;
                end
                default: begin
                  execute_payload_out[i].instruction_type <= UNSUPPORTED;
                end
              endcase
            end

            OP_NORMAL: begin
              execute_payload_out[i].destination_register <= fetch_data_in[i][12:7];
              execute_payload_out[i].source_register_1 <= fetch_data_in[i][18:13];
              execute_payload_out[i].source_register_2 <= fetch_data_in[i][24:19];

              case (fetch_data_in[i][6:4])
                3'b000: begin
                  execute_payload_out[i].instruction_type <= OP_NORMAL;
                  execute_payload_out[i].alu_operation <= ADD;
                end
                3'b001: begin
                  execute_payload_out[i].instruction_type <= OP_NORMAL;
                  execute_payload_out[i].alu_operation <= SLT;
                end
                3'b010: begin
                  execute_payload_out[i].instruction_type <= OP_NORMAL;
                  execute_payload_out[i].alu_operation <= SLTU;
                end
                3'b011: begin
                  execute_payload_out[i].instruction_type <= OP_NORMAL;
                  execute_payload_out[i].alu_operation <= XOR;
                end
                3'b100: begin
                  execute_payload_out[i].instruction_type <= OP_NORMAL;
                  execute_payload_out[i].alu_operation <= OR;
                end
                3'b101: begin
                  execute_payload_out[i].instruction_type <= OP_NORMAL;
                  execute_payload_out[i].branch_operation <= AND;
                end
                default: begin
                  execute_payload_out[i].instruction_type <= UNSUPPORTED;
                end
              endcase
            end

            OP_SHIFT: begin
              execute_payload_out[i].destination_register <= fetch_data_in[i][12:7];
              execute_payload_out[i].source_register_1 <= fetch_data_in[i][18:13];
              execute_payload_out[i].source_register_2 <= fetch_data_in[i][24:19];

              case (fetch_data_in[i][6:4])
                3'b000: begin
                  execute_payload_out[i].instruction_type <= OP_SHIFT;
                  execute_payload_out[i].alu_operation <= SLL;
                end
                3'b001: begin
                  execute_payload_out[i].instruction_type <= OP_SHIFT;
                  execute_payload_out[i].alu_operation <= SRL;
                end
                3'b010: begin
                  execute_payload_out[i].instruction_type <= OP_SHIFT;
                  execute_payload_out[i].alu_operation <= SRA;
                end
                default: begin
                  execute_payload_out[i].instruction_type <= UNSUPPORTED;
                end
              endcase
            end

            default: begin
              execute_payload_out[i].instruction_type <= UNSUPPORTED;
            end
          endcase
        end
        execute_valid_out <= 1'b1;
      end else if (rename_handshake) begin // nothing new to decode, just handoff
        execute_valid_out <= 1'b0;
      end else begin
        // do nothing
      end
    end
  end


endmodule

`default_nettype wire
