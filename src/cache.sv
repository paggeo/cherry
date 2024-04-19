module cache #(
// Cache parameters
  parameter Tag_Width               = 32,
  parameter Cache_Size_Bytes        = 1024,
  parameter Cache_Block_Size_Words  = 8,
  parameter Word_Size_Bytes         = 4,
  parameter Cache_Associativity     = 1

  
// Interface parameters
  parameter Command_Width   = 2, // 00: Nothing, 01: Write, 10: Read

  parameter In_Data_Width         = Word_Size_Bytes * Cache_Block_Size_Words * 8,
  parameter Addr_Width      = 32, 

  parameter Out_Data_Width        = 32,
  
  
)
(
  input logic [Addr_Width-1:0]        addr_i,
  input logic [Command_Width-1:0]     command_i,
  input logic [In_Data_Width-1:0]           data_i,
  
  // TODO: ADD support for coherency

  output logic [Out_Data_Width-1:0]         data_o,
  output logic                              eviction_o,  
  output logic [Addr_Width-1:0]       eviction_addr_o,
  output logic                              hit_o // 1: hit, 0: miss
  
);

  localparam int Num_Sets = Cache_Size_Bytes/Word_Size_Bytes/Cache_Block_Size_Words/Cache_Associativity;
  localparam int Index_Width = $clog2(Num_Sets);
  localparam int Offset_Width = $clog2(Cache_Block_Size_Words);
  localparam int Tag_Width = Addr_Width - Index_Width - Offset_Width;

  typedef logic [Word_Size_Bytes * 8 - 1:0] cache_word_t;

  typedef struct packed{
    cache_word_t  block [Cache_Block_Size_Words]; 
    logic       [Tag_Width-1:0]              tag;
    logic       [32:0]                       age;
    logic                                    valid;
  } cache_block_t;

  typedef cache_block_t [Cache_Associativity-1] cache_set_t;

  logic cache_set_t [Num_Sets] cache;

  assign set_index = addr_i[Index_Width + Offset_Width : Index_Width];
  assign tag       = addr_i[Input_Addr_Width-1:Index_Width + Offset_Width];
  assign offset    = addr_i[Offset_Width-1:0];

  // Notes: create the replacement policy 

  function logic [Cache_Associativity-1:0] replacement_policy(
    input cache_set_t cache_set_i;
    output logic [Cache_Associativity-1:0] eviction_index_o;
    );
    logic [31:0] max_age;
    logic [Cache_Associativity-1:0] lru_index;
    begin 
      max_age = cache_set[0].age;
      lru_index = 0;
      for (int i=1; i< Cache_Associativity; i++) begin
        if (cache_set[i].age > max_age) begin
          max_age = cache_set[i].age;
          lru_index = i;
        end
      end
      eviction_index_o = lru_index;
    end 
  endfunction

  function update_ages(
    input cache_set_t cache_set_i;
    input block_index;
    );
    
    logic block_age;
    begin 
      block_age = cache_set_i[block_index].age;
      for (int i=0; i< Cache_Associativity; i++) begin
        if (cache_set_o[i].age > block_age) cache_set_o[i].age = cache_set_i[i].age - 1;
      end
      cache_set_o[block_index].age = Cache_Associativity - 1;
    end
  endfunction

  logic [Cache_Associativity-1:0] eviction_index;
  always_comb begin 
    hit_o = 0;
    data_o = 0;
    eviction_o = 0;
    eviction_addr_o = 0;
    if (command_i == 2'b01) begin // Write. 
      eviction_index = replacement_policy(cache[set_index], eviction_index);
      //evict the block
      eviction_o = 1;
      eviction_addr_o = {cache[set_index][eviction_index].tag, set_index, offset};
      data_o = cache[set_index][eviction_index];

      // replace the block
      cache[set_index][eviction_index].block = data_i;
      cache[set_index][eviction_index].tag == tag;
      cache[set_index][eviction_index].valid == 1'b1;

      update_ages(cache[set_index], eviction_index);
    end

    else if (command_i == 2'b10) begin // Read
      for (int i = 0; i < Cache_Associativity; i++) begin
        if (cache[set_index][i].tag == tag && cache[set_index][i].valid == 1'b1) begin // Tag is unique
          hit_o = 1;
          data_o = cache[set_index][i].block[offset];
          update_ages(cache[set_index], i);
        end
      end
    end 
  end

endmodule