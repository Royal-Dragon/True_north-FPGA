module scheduler_sram (
    input wire clk,
    input wire rst,
    
    // Write port (from router)
    input wire write_request,
    input wire [3:0] write_tick,
    input wire [7:0] write_axon,
    
    // Read port (to token controller)
    input wire read_request,
    input wire [3:0] read_tick,
    output reg [255:0] read_data,
    
    // Clear port (from token controller)
    input wire clear_request,
    input wire [3:0] clear_tick,
    
    // Status signals
    output reg ready,
    output reg error
);

    // Memory array: 16 ticks x 256 axons
    reg [255:0] memory [0:15];
    
    // State machine
    localparam IDLE = 2'b00;
    localparam OPERATING = 2'b01;
    localparam ERROR_STATE = 2'b11;
    reg [1:0] state;
    
    // Operation tracking
    reg op_write_pending;
    reg op_read_pending;
    reg op_clear_pending;
    
    // Initialize memory
    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1)
            memory[i] = 256'b0;
        ready = 1'b1;
        error = 1'b0;
        state = IDLE;
        op_write_pending = 1'b0;
        op_read_pending = 1'b0;
        op_clear_pending = 1'b0;
    end
    
    // Main state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            ready <= 1'b1;
            error <= 1'b0;
            op_write_pending <= 1'b0;
            op_read_pending <= 1'b0;
            op_clear_pending <= 1'b0;
            read_data <= 256'b0;
            for (i = 0; i < 16; i = i + 1)
                memory[i] <= 256'b0;
        end else begin
            case (state)
                IDLE: begin
                    // Check for operation conflicts
                    if ((write_request && read_request && write_tick == read_tick) ||
                        (write_request && clear_request && write_tick == clear_tick) ||
                        (read_request && clear_request && read_tick == clear_tick)) begin
                        state <= ERROR_STATE;
                        error <= 1'b1;
                        ready <= 1'b0;
                    end else begin
                        if (write_request || read_request || clear_request) begin
                            state <= OPERATING;
                            ready <= 1'b0;
                            op_write_pending <= write_request;
                            op_read_pending <= read_request;
                            op_clear_pending <= clear_request;
                        end
                    end
                end
                
                OPERATING: begin
                    // Process operations
                    if (op_write_pending) begin
                        // Set the bit at the specified axon
                        memory[write_tick][write_axon] <= 1'b1;
                        op_write_pending <= 1'b0;
                    end
                    
                    if (op_read_pending) begin
                        // Read the entire row for the specified tick
                        read_data <= memory[read_tick];
                        op_read_pending <= 1'b0;
                    end
                    
                    if (op_clear_pending) begin
                        // Clear the entire row for the specified tick
                        memory[clear_tick] <= 256'b0;
                        op_clear_pending <= 1'b0;
                    end
                    
                    // Check if all operations are complete
                    if (!op_write_pending && !op_read_pending && !op_clear_pending) begin
                        state <= IDLE;
                        ready <= 1'b1;
                    end
                end
                
                ERROR_STATE: begin
                    // Stay in error state until reset
                    error <= 1'b1;
                    ready <= 1'b0;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
