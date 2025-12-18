// ROM Controller
// Designer: Copilot
// Reviewer: Microarchitecture Lead
//
// Boot ROM controller with MBIST support
// Size: 32 KB (8K words x 32-bit)
// Latency: 1 cycle

module rom_controller (
    // Clocking & Reset
    input  logic        clk,
    input  logic        rst_n,

    // Memory Access Interface
    input  logic        rom_req,           // Access request
    input  logic [14:0] rom_addr,          // Address (32KB, word-aligned)
    output logic [31:0] rom_rdata,         // Read data
    output logic        rom_ready,         // Data valid (1-cycle after req)

    // DFT Interface
    input  logic        mbist_en,          // MBIST mode enable
    output logic        mbist_done,        // MBIST complete
    output logic        mbist_fail         // MBIST failure flag
);

    // Memory array: 32 KB = 8K words x 32 bits
    // Address [14:0] provides word addressing for 8K words (2^13 = 8192 words)
    localparam int ROM_DEPTH = 8192;       // 8K words
    localparam int ADDR_WIDTH = 13;        // Word address width

    logic [31:0] rom_mem [0:ROM_DEPTH-1];  // ROM memory array

    // Internal signals
    logic [ADDR_WIDTH-1:0] read_addr;
    logic                  ready_reg;
    
    // MBIST state machine
    typedef enum logic [2:0] {
        MBIST_IDLE,
        MBIST_MARCH_UP,
        MBIST_MARCH_DOWN,
        MBIST_VERIFY,
        MBIST_DONE
    } mbist_state_t;

    mbist_state_t mbist_state;
    logic [ADDR_WIDTH-1:0] mbist_addr;
    logic                  mbist_error;
    logic [31:0]           mbist_read_data;
    logic [31:0]           mbist_expected;

    // Extract word address from byte address
    assign read_addr = rom_addr[ADDR_WIDTH+1:2];

    // Initialize ROM with memory file (synthesis directive)
    initial begin
        // Initialize all locations to zero
        for (int i = 0; i < ROM_DEPTH; i++) begin
            rom_mem[i] = 32'h0;
        end
        
        // Load from .mem file if it exists
        // This will be replaced by synthesis tools
        `ifdef ROM_INIT_FILE
            $readmemh(`ROM_INIT_FILE, rom_mem);
        `endif
    end

    // Normal read operation (1-cycle latency)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rom_rdata  <= 32'h0;
            ready_reg  <= 1'b0;
        end else begin
            if (!mbist_en && rom_req) begin
                rom_rdata <= rom_mem[read_addr];
                ready_reg <= 1'b1;
            end else if (mbist_en) begin
                rom_rdata <= 32'h0;
                ready_reg <= 1'b0;
            end else begin
                ready_reg <= 1'b0;
            end
        end
    end

    assign rom_ready = ready_reg;

    // MBIST controller
    // Implements simplified March algorithm:
    // 1. March up: Write 0 to all addresses
    // 2. March down: Read and verify 0, write 1
    // 3. Verify: Read and verify 1
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mbist_state    <= MBIST_IDLE;
            mbist_addr     <= '0;
            mbist_error    <= 1'b0;
            mbist_done     <= 1'b0;
            mbist_fail     <= 1'b0;
            mbist_expected <= 32'h0;
        end else begin
            case (mbist_state)
                MBIST_IDLE: begin
                    if (mbist_en) begin
                        mbist_state    <= MBIST_MARCH_UP;
                        mbist_addr     <= '0;
                        mbist_error    <= 1'b0;
                        mbist_done     <= 1'b0;
                        mbist_fail     <= 1'b0;
                        mbist_expected <= 32'h0;
                    end
                end

                MBIST_MARCH_UP: begin
                    // March up: verify current value matches expected, then write complement
                    mbist_read_data = rom_mem[mbist_addr];
                    if (mbist_addr > 0 && mbist_read_data !== mbist_expected) begin
                        mbist_error <= 1'b1;
                    end
                    
                    mbist_addr <= mbist_addr + 1;
                    if (mbist_addr == ROM_DEPTH - 1) begin
                        mbist_state    <= MBIST_MARCH_DOWN;
                        mbist_expected <= 32'h0;
                    end
                end

                MBIST_MARCH_DOWN: begin
                    // March down: verify and write inverse pattern
                    mbist_addr <= mbist_addr - 1;
                    mbist_read_data = rom_mem[mbist_addr];
                    if (mbist_read_data !== mbist_expected) begin
                        mbist_error <= 1'b1;
                    end
                    
                    if (mbist_addr == 0) begin
                        mbist_state    <= MBIST_VERIFY;
                        mbist_expected <= 32'h0;
                    end
                end

                MBIST_VERIFY: begin
                    // Final verification pass
                    mbist_read_data = rom_mem[mbist_addr];
                    if (mbist_read_data !== mbist_expected) begin
                        mbist_error <= 1'b1;
                    end
                    
                    mbist_addr <= mbist_addr + 1;
                    if (mbist_addr == ROM_DEPTH - 1) begin
                        mbist_state <= MBIST_DONE;
                    end
                end

                MBIST_DONE: begin
                    mbist_done <= 1'b1;
                    mbist_fail <= mbist_error;
                    if (!mbist_en) begin
                        mbist_state <= MBIST_IDLE;
                    end
                end

                default: begin
                    mbist_state <= MBIST_IDLE;
                end
            endcase
        end
    end

endmodule
