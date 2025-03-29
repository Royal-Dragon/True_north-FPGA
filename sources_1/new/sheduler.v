module scheduler (
    input wire clk,              // System clock
    input wire rst,              // Reset
    
    // Router interface
    input wire [13:0] spike_packet,     // [delivery_tick(4), axon_id(8), debug(2)]
    input wire spike_packet_valid,      // Spike packet is valid
    output reg spike_packet_ready,      // Ready to receive spike packet
    
    // Token controller interface
    input wire read_request,            // Request to read current tick spikes
    output reg [255:0] current_tick_spikes, // Current tick's spikes for all axons
    input wire clear_request,           // Request to clear current tick
    output reg error,                   // Error signal
    input wire error_ack,               // Error acknowledgment input (from token controller)
    
    // Status and debug outputs
    output reg [3:0] current_tick,      // Current tick pointer (for debugging)
    output reg [7:0] error_status       // Detailed error status
);

    // Scheduler SRAM (16 ticks x 256 axons)
    reg [255:0] spike_memory [0:15];
    
    // Parameters for validation
    localparam MAX_FUTURE_TICK = 4'd15;
    localparam MAX_AXON_ID = 8'd255;
    
    // Decode signals
    wire [3:0] delivery_tick;
    wire [7:0] axon_id;
    wire [1:0] debug_bits;
    
    // Decode incoming spike packet
    assign delivery_tick = spike_packet[13:10];
    assign axon_id = spike_packet[9:2];
    assign debug_bits = spike_packet[1:0];
    
    // State machine for handling spike writes
    localparam IDLE = 2'b00;
    localparam WRITE_SPIKE = 2'b01;
    localparam ERROR_STATE = 2'b11;
    
    reg [1:0] state;
    reg [15:0] error_timeout_counter;
    
    // Error codes
    localparam ERROR_NONE = 8'h00;
    localparam ERROR_CURRENT_TICK_WRITE = 8'h01;
    localparam ERROR_INVALID_TICK = 8'h02;
    localparam ERROR_INVALID_AXON = 8'h03;
    localparam ERROR_TIMEOUT = 8'h04;
    
    // Initialize memory and state
    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1)
            spike_memory[i] = 256'b0;
        current_tick = 4'b0;
        error = 1'b0;
        error_status = ERROR_NONE;
    end
    
    // Input validation
    always @(posedge clk) begin
        if (spike_packet_valid && spike_packet_ready) begin
            // Validate delivery_tick range
            if (delivery_tick > MAX_FUTURE_TICK) begin
                error <= 1'b1;
                error_status <= ERROR_INVALID_TICK;
            end
            
            // Validate axon_id range
            if (axon_id > MAX_AXON_ID) begin
                error <= 1'b1;
                error_status <= ERROR_INVALID_AXON;
            end
        end
    end
    
    // Main state machine for spike packet handling
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            spike_packet_ready <= 1'b1;
            error <= 1'b0;
            error_status <= ERROR_NONE;
            current_tick <= 4'b0;
            error_timeout_counter <= 16'd0;
            for (i = 0; i < 16; i = i + 1)
                spike_memory[i] <= 256'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (spike_packet_valid && spike_packet_ready) begin
                        // Check if we're trying to write to the current tick (error)
                        if (delivery_tick == current_tick) begin
                            state <= ERROR_STATE;
                            error <= 1'b1;
                            error_status <= ERROR_CURRENT_TICK_WRITE;
                            spike_packet_ready <= 1'b0;
                        end else begin
                            state <= WRITE_SPIKE;
                            spike_packet_ready <= 1'b0;
                        end
                    end
                end
                
                WRITE_SPIKE: begin
                    // Write the spike to memory
                    // Set the bit corresponding to the axon_id in the delivery_tick word
                    spike_memory[delivery_tick][axon_id] <= 1'b1;
                    
                    // Return to IDLE state
                    state <= IDLE;
                    spike_packet_ready <= 1'b1;
                end
                
                ERROR_STATE: begin
                    // Timeout detection
                    if (error_timeout_counter >= 16'hFFFF) begin
                        error_status <= ERROR_TIMEOUT;
                        state <= IDLE;
                        spike_packet_ready <= 1'b1;
                        error <= 1'b0;
                        error_timeout_counter <= 16'd0;
                    end else if (error_ack) begin
                        // Wait for error to be acknowledged
                        error <= 1'b0;
                        error_status <= ERROR_NONE;
                        state <= IDLE;
                        spike_packet_ready <= 1'b1;
                        error_timeout_counter <= 16'd0;
                    end else begin
                        error_timeout_counter <= error_timeout_counter + 1'b1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Handle read and clear requests from token controller
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_tick_spikes <= 256'b0;
        end else begin
            // Read request - provide spikes for current tick
            if (read_request) begin
                current_tick_spikes <= spike_memory[current_tick];
            end
            
            // Clear request - clear current tick and advance to next tick
            if (clear_request) begin
                spike_memory[current_tick] <= 256'b0;
                current_tick <= current_tick + 1'b1;
            end
        end
    end
    
    // Verify that read and clear requests are not simultaneous
    always @(posedge clk) begin
        if (read_request && clear_request) begin
            error <= 1'b1;
            error_status <= 8'h05; // Simultaneous read/clear error
        end
    end

endmodule
