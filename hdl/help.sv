`default_nettype none

package help;
  localparam WORD_SIZE = 25;
  typedef logic [WORD_SIZE-1:0] Word;
endpackage


package processor_help;
  import help::*;

  localparam SUPER_SCALAR_WIDTH = 4;

  localparam PHYSICAL_REGISTER_FILE_SIZE = 128;
  localparam LOG_PHYSICAL_REGISTER_FILE_SIZE = $clog2(PHYSICAL_REGISTER_FILE_SIZE);
  localparam ARCHITECTURAL_REGISTER_FILE_SIZE = 64;
  localparam LOG_ARCHITECTURAL_REGISTER_FILE_SIZE = $clog2(ARCHITECTURAL_REGISTER_FILE_SIZE);

  typedef logic [REGISTER_FILE_SIZE-1:0] RegisterFileReadRequest;
  typedef struct logic {
    logic [REGISTER_FILE_SIZE-1:0] register,
    logic write_enable,
    logic Word data
  } RegisterFileWriteRequest;
  typedef logic [REGISTER_FILE_PORT_SETS-1:0] Word RegisterFileReadResponse; 

  // fetch
  typedef enum logic [1:0] {
    DEQUEUE,
    STALL,
    REDIRECT
  } FetchOperation;

  typedef struct logic {
    FetchOperation operation;
    Word redirect_pc;
  } FetchRequest;

  typedef struct logic {
    Word pc;
    Word instruction;
  } FetchResult;

  // decode
  localparam DECODE_OPCODE_WIDTH = 4;
  localparam DECODE_REGISTER_WIDTH = 6;

  localparam DECODE_ARITH_FUNCTION_WIDTH = 3;
  localparam DECODE_ARITH_IMMEDIATE_WIDTH = 6;

  localparam DECODE_LUI_JAL_IMMEDIATE_WIDTH = 15;

  localparam DECODE_JALR_IMMEDIATE_WIDTH = 9;

  localparam DECODE_BRANCH_FUNCTION_WIDTH = 3;
  localparam DECODE_BRANCH_IMMEDIATE_WIDTH = 6;

  localparam DECODE_LOAD_STORE_IMMEDIATE_WIDTH = 9;

  typedef enum logic [3:0] {
    UNSUPPORTED = 4'b0000,
    LUI = 4'b0001,
    JAL = 4'b0010,
    JALR = 4'b0011,
    BRANCH = 4'b0100,
    LOAD = 4'b0101,
    STORE = 4'b0110,
    OP_IMM_NORMAL = 4'b0111,
    OP_IMM_SHIFT = 4'b1000,
    OP_NORMAL = 4'b1001,
    OP_SHIFT = 4'b1010
  } InstructionType;
  typedef enum logic [3:0] {
    EQ = 3'b000,
    NEQ = 3'b001,
    LT = 3'b010,
    GE = 3'b011,
    LTU = 3'b100,
    GEU = 3'b101
  } BranchOperation;
  typedef enum logic {
    ADD,
    SUB,
    AND,
    OR,
    XOR,
    SLT,
    SLTU,
    SLL,
    SRL,
    SRA
  } ALUOperation;
  typedef enum logic [0:0] {
    LOAD,
    STORE
  } MemoryOperation;

  typedef struct logic {
    InstructionType instruction_type;
    BranchOperation branch_operation;
    ALUOperation alu_operation;
    MemoryOperation memory_operation;
    logic [LOG_REGISTER_FILE_SIZE-1:0] destination_register;
    logic [LOG_REGISTER_FILE_SIZE-1:0] source_register_1;
    logic [LOG_REGISTER_FILE_SIZE-1:0] source_register_2;
    Word immediate;
  } DecodeResult;

  typedef struct logic {
    InstructionType instruction_type;
    BranchOperation branch_operation;
    ALUOperation alu_operation;
    MemoryOperation memory_operation;
    logic [LOG_ARCHITECTURAL_REGISTER_FILE_SIZE-1:0] destination_register;
    logic [LOG_ARCHITECTURAL_REGISTER_FILE_SIZE-1:0] source_register_1;
    logic [LOG_ARCHITECTURAL_REGISTER_FILE_SIZE-1:0] source_register_2;
    Word immediate;
  } RenameResult;

endpackage


package cache_help;
  import help::*;

  localparam CACHE_SETS = 2048;
  localparam CACHE_WORDS_PER_LINE = 4;

  localparam CACHE_WORD_OFFSET_WIDTH = $clog2(CACHE_WORDS_PER_LINE);
  localparam CACHE_INDEX_WIDTH = $clog2(CACHE_SETS);
  localparam CACHE_TAG_WIDTH = (
    WORD_SIZE 
    - CACHE_INDEX_WIDTH 
    - CACHE_WORD_OFFSET_WIDTH 
  );

  localparam LINE_SIZE = CACHE_WORDS_PER_LINE * WORD_SIZE;
  localparam MEMORY_LINE_WIDTH = $clog2(LINE_SIZE);
  localparam MEMORY_LINE_ADDRESS_WIDTH = (
    WORD_SIZE
    - CACHE_WORD_OFFSET_WIDTH
  );

  typedef logic [CACHE_WORD_OFFSET_WIDTH-1:0] CacheWordOffset;
  typedef logic [CACHE_INDEX_WIDTH-1:0] CacheIndex;
  typedef logic [CACHE_TAG_WIDTH-1:0] CacheTag;

  localparam CACHE_LINE_STATUS_WIDTH = 2;
  typedef enum {
    NOT_VALID = 2'b00,
    CLEAN = 2'b10,
    DIRTY = 2'b01
  } CacheLineStatus;

  typedef enum logic [0:0] {
    LOAD,
    STORE
  } MemoryOperation;

  typedef logic [CACHE_WORDS_PER_LINE-1:0] [WORD_SIZE-1:0] Line;
  typedef logic [MEMORY_LINE_ADDRESS_WIDTH-1:0] MemoryLineAddress;

  // typedef struct {
  //   MemoryFunctionType op;
  //   Word address;
  //   Word data;
  // } L1_CacheRequest;

  // typedef struct {
  //   MemoryFunctionType op;
  //   Word address;
  //   Line data;
  // } L2_CacheRequest;

  typedef enum {
    READY,
    LOOKUP,
    WRITEBACK,
    FILL
  } CacheRequestStatus;


  // typedef struct {
  //   MemoryFunctionType op;
  //   MemoryLineAddress line_address;
  //   Line data;
  // } MainMemoryRequest;

  // helper functions
  function CacheWordOffset getCacheWordOffset(Word address);
    return address[
      CACHE_WORD_OFFSET_WIDTH-1
      :0
    ];
  endfunction

  function CacheIndex getCacheIndex(Word address);
    return address[
      CACHE_INDEX_WIDTH+CACHE_WORD_OFFSET_WIDTH-1
      :CACHE_WORD_OFFSET_WIDTH
    ];
  endfunction

  function CacheTag getCacheTag(Word address);
    return address[
      WORD_SIZE-1
      :CACHE_INDEX_WIDTH+CACHE_WORD_OFFSET_WIDTH
    ];
  endfunction

  function MemoryLineAddress getMemoryLineAddress(Word address);
    return {getCacheTag(address), getCacheIndex(address)};
  endfunction
endpackage

`default_nettype wire
