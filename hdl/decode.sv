`default_nettype none

import processor_help::*;

module decode (
  input wire clk_in,
  input wire rst_in,

  output logic fetch_ready_out,
  input wire fetch_valid_in,
  input wire Word fetch_data_in [SUPER_SCALAR_WIDTH-1:0],

  input wire rename_ready_in,
  output logic rename_valid_out,
  output DecodeResult rename_payload_out [SUPER_SCALAR_WIDTH-1:0]
);

  logic rename_handshake [SUPER_SCALAR_WIDTH-1:0];
  logic fetch_handshake [SUPER_SCALAR_WIDTH-1:0];

  always_comb begin
    fetch_ready_out = !rename_valid_out || rename_ready_in; // only signalled if not stalled by rename!!!!!!

    rename_handshake = rename_ready_in && rename_valid_out;
    fetch_handshake = fetch_ready_out && fetch_valid_in;
  end

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      rename_valid_out <= 1'b0;
    end else begin
      if (fetch_handshake) begin // new data to decode and handoff
        for (int i = 0; i < SUPER_SCALAR_WIDTH; i=i+1) begin
          case (fetch_data_in[i][3:0]) // opcode
            LUI: begin
              rename_payload_out[i].instruction_type <= LUI;
              rename_payload_out[i].destination_register <= fetch_data_in[i][9:4];
              rename_payload_out[i].immediate <= {fetch_data_in[i][24:10], 10'b0};
            end

            JAL: begin
              rename_payload_out[i].instruction_type <= JAL;
              rename_payload_out[i].destination_register <= fetch_data_in[i][9:4];
              rename_payload_out[i].immediate <= {
                10{fetch_data_in[i][24]},
                fetch_data_in[i][24:10]
              };
            end

            JALR: begin
              rename_payload_out[i].instruction_type <= JALR;
              rename_payload_out[i].destination_register <= fetch_data_in[i][9:4];
              rename_payload_out[i].source_register_1 <= fetch_data_in[i][15:10];
              rename_payload_out[i].immediate <= {
                16{fetch_data_in[i][24]},
                fetch_data_in[i][24:16]
              };
            end

            BRANCH: begin
              rename_payload_out[i].source_register_1 <= fetch_data_in[i][12:7];
              rename_payload_out[i].source_register_2 <= fetch_data_in[i][18:13];
              rename_payload_out[i].immediate <= {
                19{fetch_data_in[i][24]},
                fetch_data_in[i][24:19]
              };

              case (fetch_data_in[i][6:4])
                EQ: begin
                  rename_payload_out[i].instruction_type <= BRANCH;
                  rename_payload_out[i].branch_operation <= EQ;
                end
                NEQ: begin
                  rename_payload_out[i].instruction_type <= BRANCH;
                  rename_payload_out[i].branch_operation <= NEQ;
                end
                LT: begin
                  rename_payload_out[i].instruction_type <= BRANCH;
                  rename_payload_out[i].branch_operation <= LT;
                end
                GE: begin
                  rename_payload_out[i].instruction_type <= BRANCH;
                  rename_payload_out[i].branch_operation <= GE;
                end
                LTU: begin
                  rename_payload_out[i].instruction_type <= BRANCH;
                  rename_payload_out[i].branch_operation <= LTU;
                end
                GEU: begin
                  rename_payload_out[i].instruction_type <= BRANCH;
                  rename_payload_out[i].branch_operation <= GEU;
                end
                default: begin
                  rename_payload_out[i].instruction_type <= UNSUPPORTED;
                end
              endcase
            end

            LOAD: begin
              rename_payload_out[i].instruction_type <= LOAD;
              rename_payload_out[i].destination_register <= fetch_data_in[i][9:4];
              rename_payload_out[i].source_register_1 <= fetch_data_in[i][15:10];
              rename_payload_out[i].immediate <= {
                16{fetch_data_in[i][24]},
                fetch_data_in[i][24:16]
              };
            end

            STORE: begin
              rename_payload_out[i].instruction_type <= STORE;
              rename_payload_out[i].source_register_1 <= fetch_data_in[i][9:4];
              rename_payload_out[i].source_register_2 <= fetch_data_in[i][15:10];
              rename_payload_out[i].immediate <= {
                16{fetch_data_in[i][24]},
                fetch_data_in[i][24:16]
              };
            end

            OP_IMM_NORMAL: begin
              rename_payload_out[i].destination_register <= fetch_data_in[i][12:7];
              rename_payload_out[i].source_register_1 <= fetch_data_in[i][18:13];
              rename_payload_out[i].immediate <= {
                19{fetch_data_in[i][24]},
                fetch_data_in[i][24:19]
              };

              case (fetch_data_in[i][6:4])
                3'b000: begin
                  rename_payload_out[i].instruction_type <= OP_IMM_NORMAL;
                  rename_payload_out[i].alu_operation <= ADD;
                end
                3'b001: begin
                  rename_payload_out[i].instruction_type <= OP_IMM_NORMAL;
                  rename_payload_out[i].alu_operation <= SLT;
                end
                3'b010: begin
                  rename_payload_out[i].instruction_type <= OP_IMM_NORMAL;
                  rename_payload_out[i].alu_operation <= SLTU;
                end
                3'b011: begin
                  rename_payload_out[i].instruction_type <= OP_IMM_NORMAL;
                  rename_payload_out[i].alu_operation <= XOR;
                end
                3'b100: begin
                  rename_payload_out[i].instruction_type <= OP_IMM_NORMAL;
                  rename_payload_out[i].alu_operation <= OR;
                end
                3'b101: begin
                  rename_payload_out[i].instruction_type <= OP_IMM_NORMAL;
                  rename_payload_out[i].branch_operation <= AND;
                end
                default: begin
                  rename_payload_out[i].instruction_type <= UNSUPPORTED;
                end
              endcase
            end

            OP_IMM_SHIFT: begin
              rename_payload_out[i].destination_register <= fetch_data_in[i][12:7];
              rename_payload_out[i].source_register_1 <= fetch_data_in[i][18:13];
              rename_payload_out[i].immediate <= {
                19{fetch_data_in[i][24]},
                fetch_data_in[i][24:19]
              };

              case (fetch_data_in[i][6:4])
                3'b000: begin
                  rename_payload_out[i].instruction_type <= OP_IMM_SHIFT;
                  rename_payload_out[i].alu_operation <= SLL;
                end
                3'b001: begin
                  rename_payload_out[i].instruction_type <= OP_IMM_SHIFT;
                  rename_payload_out[i].alu_operation <= SRL;
                end
                3'b010: begin
                  rename_payload_out[i].instruction_type <= OP_IMM_SHIFT;
                  rename_payload_out[i].alu_operation <= SRA;
                end
                default: begin
                  rename_payload_out[i].instruction_type <= UNSUPPORTED;
                end
              endcase
            end

            OP_NORMAL: begin
              rename_payload_out[i].destination_register <= fetch_data_in[i][12:7];
              rename_payload_out[i].source_register_1 <= fetch_data_in[i][18:13];
              rename_payload_out[i].source_register_2 <= fetch_data_in[i][24:19];

              case (fetch_data_in[i][6:4])
                3'b000: begin
                  rename_payload_out[i].instruction_type <= OP_NORMAL;
                  rename_payload_out[i].alu_operation <= ADD;
                end
                3'b001: begin
                  rename_payload_out[i].instruction_type <= OP_NORMAL;
                  rename_payload_out[i].alu_operation <= SLT;
                end
                3'b010: begin
                  rename_payload_out[i].instruction_type <= OP_NORMAL;
                  rename_payload_out[i].alu_operation <= SLTU;
                end
                3'b011: begin
                  rename_payload_out[i].instruction_type <= OP_NORMAL;
                  rename_payload_out[i].alu_operation <= XOR;
                end
                3'b100: begin
                  rename_payload_out[i].instruction_type <= OP_NORMAL;
                  rename_payload_out[i].alu_operation <= OR;
                end
                3'b101: begin
                  rename_payload_out[i].instruction_type <= OP_NORMAL;
                  rename_payload_out[i].branch_operation <= AND;
                end
                default: begin
                  rename_payload_out[i].instruction_type <= UNSUPPORTED;
                end
              endcase
            end

            OP_SHIFT: begin
              rename_payload_out[i].destination_register <= fetch_data_in[i][12:7];
              rename_payload_out[i].source_register_1 <= fetch_data_in[i][18:13];
              rename_payload_out[i].source_register_2 <= fetch_data_in[i][24:19];

              case (fetch_data_in[i][6:4])
                3'b000: begin
                  rename_payload_out[i].instruction_type <= OP_SHIFT;
                  rename_payload_out[i].alu_operation <= SLL;
                end
                3'b001: begin
                  rename_payload_out[i].instruction_type <= OP_SHIFT;
                  rename_payload_out[i].alu_operation <= SRL;
                end
                3'b010: begin
                  rename_payload_out[i].instruction_type <= OP_SHIFT;
                  rename_payload_out[i].alu_operation <= SRA;
                end
                default: begin
                  rename_payload_out[i].instruction_type <= UNSUPPORTED;
                end
              endcase
            end

            default: begin
              rename_payload_out[i].instruction_type <= UNSUPPORTED;
            end
          endcase
        end
        rename_valid_out <= 1'b1;
      end else if (rename_handshake) begin // nothing new to decode, just handoff
        rename_valid_out <= 1'b0;
      end else begin
        // do nothing
      end
    end
  end


endmodule

`default_nettype wire
