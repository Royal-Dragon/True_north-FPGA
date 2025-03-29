module token_controller (
    input wire clk,              // System clock
    input wire rst,              // Reset
    input wire tick,             // 1kHz synchronization pulse
    
    // Scheduler interface
    output reg scheduler_read_request,   // Request spikes for current tick
    input wire [255:0] axon_activity,    // Current axon activity from scheduler
    output reg scheduler_clear_request,  // Clear current tick after processing
    
    // Core SRAM interface
    output reg [7:0] sram_addr,          // Neuron address (0-255)
    output reg sram_read_request,        // Read neuron data
    input wire [255:0] synaptic_connections, // Synaptic connections for current neuron
    input wire [7:0] membrane_potential, // Current membrane potential from SRAM
    input wire [7:0] neuron_params,      // Neuron parameters from SRAM
    output reg sram_write_request,       // Write updated membrane potential
    output reg [7:0] updated_membrane_potential, // Updated membrane potential
    
    // Neuron block interface
    output reg neuron_clk_enable,        // Enable clock pulse to neuron
    output reg [7:0] neuron_instruction, // Instruction for neuron
    output reg read_vj,                  // Read membrane potential
    output reg write_vj,                 // Write membrane potential
    input wire spike_transmit,           // Spike output from neuron
    
    // Router interface
    output reg router_send_spike,        // Send spike to router
    output reg [25:0] spike_packet,      // Spike packet for router
    input wire [25:0] spike_destination, // Routing info from SRAM
    input wire [3:0] spike_delivery_tick, // Delivery tick from SRAM
    
    // Status
    output reg busy,                     // Controller is processing
    output reg error                     // Error condition detected
);

    // States for the controller state machine
    localparam IDLE = 4'd0;
    localparam REQUEST_AXONS = 4'd1;
    localparam PROCESS_NEURONS_START = 4'd2;
    localparam READ_NEURON_DATA = 4'd3;
    localparam PROCESS_AXONS = 4'd4;
    localparam APPLY_LEAK = 4'd5;
    localparam WAIT_LEAK = 4'd6;
    localparam CHECK_THRESHOLD = 4'd7;
    localparam WAIT_THRESHOLD = 4'd8;
    localparam SEND_SPIKE = 4'd9;
    localparam WRITE_BACK = 4'd10;
    localparam NEXT_NEURON = 4'd11;
    localparam WAIT_CLEAR = 4'd12;
    localparam CLEAR_AXONS = 4'd13;
    localparam ERROR_STATE = 4'd15;
    
    // Programmable delay values
    reg [7:0] delay_line_1;     // Delay for leak operation
    reg [7:0] delay_line_2;     // Delay for threshold check
    
    // Delay counters
    reg [7:0] delay_counter;
    
    reg [3:0] state;
    reg [7:0] current_neuron;
    reg [7:0] current_axon;
    
    // Implementation of state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all outputs and state
            state <= IDLE;
            current_neuron <= 8'd0;
            current_axon <= 8'd0;
            busy <= 1'b0;
            error <= 1'b0;
            delay_counter <= 8'd0;
            
            // Reset all interface signals
            scheduler_read_request <= 1'b0;
            scheduler_clear_request <= 1'b0;
            sram_addr <= 8'd0;
            sram_read_request <= 1'b0;
            sram_write_request <= 1'b0;
            updated_membrane_potential <= 8'd0;
            neuron_clk_enable <= 1'b0;
            neuron_instruction <= 8'd0;
            read_vj <= 1'b0;
            write_vj <= 1'b0;
            router_send_spike <= 1'b0;
            spike_packet <= 26'd0;
            
            // Initial delay line values (these would be set by scan chain in real chip)
            delay_line_1 <= 8'd10;
            delay_line_2 <= 8'd5;
        end else begin
            case (state)
                IDLE: begin
                    // Wait for tick signal
                    if (tick) begin
                        state <= REQUEST_AXONS;
                        busy <= 1'b1;
                    end
                end
                
                REQUEST_AXONS: begin
                    // Request current axon activity from scheduler
                    scheduler_read_request <= 1'b1;
                    state <= PROCESS_NEURONS_START;
                end
                
                PROCESS_NEURONS_START: begin
                    // Start processing neurons
                    scheduler_read_request <= 1'b0;
                    current_neuron <= 8'd0;
                    state <= READ_NEURON_DATA;
                end
                
                READ_NEURON_DATA: begin
                    // Read neuron data from SRAM
                    sram_addr <= current_neuron;
                    sram_read_request <= 1'b1;
                    state <= PROCESS_AXONS;
                    current_axon <= 8'd0;
                end
                
                PROCESS_AXONS: begin
                    // Process all axons for current neuron
                    sram_read_request <= 1'b0;
                    
                    // Check if current axon is active and connected
                    if (current_axon < 8'd255) begin
                        if (axon_activity[current_axon] && synaptic_connections[current_axon]) begin
                            // Send instruction to neuron block
                            neuron_instruction <= {6'b0, current_axon[1:0]}; // Encode axon type
                            neuron_clk_enable <= 1'b1;
                        end else begin
                            neuron_clk_enable <= 1'b0;
                        end
                        current_axon <= current_axon + 1'b1;
                    end else begin
                        // Processed all axons, apply leak
                        neuron_clk_enable <= 1'b0;
                        state <= APPLY_LEAK;
                    end
                end
                
                APPLY_LEAK: begin
                    // Send leak instruction to neuron
                    neuron_instruction <= 8'h02; // Leak instruction
                    neuron_clk_enable <= 1'b1;
                    delay_counter <= 8'd0;
                    state <= WAIT_LEAK;
                end
                
                WAIT_LEAK: begin
                    if (delay_counter >= delay_line_1) begin
                        neuron_clk_enable <= 1'b0;
                        state <= CHECK_THRESHOLD;
                    end else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end
                
                CHECK_THRESHOLD: begin
                    // Send threshold check instruction
                    neuron_instruction <= 8'h03; // Threshold check instruction
                    neuron_clk_enable <= 1'b1;
                    delay_counter <= 8'd0;
                    state <= WAIT_THRESHOLD;
                end
                
                WAIT_THRESHOLD: begin
                    if (delay_counter >= delay_line_2) begin
                        neuron_clk_enable <= 1'b0;
                        
                        // Check if neuron spiked
                        if (spike_transmit) begin
                            state <= SEND_SPIKE;
                        end else begin
                            state <= WRITE_BACK;
                        end
                    end else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end
                
                SEND_SPIKE: begin
                    // Send spike to router
                    router_send_spike <= 1'b1;
                    
                    // Construct spike packet from neuron's routing info
                    spike_packet <= {spike_destination, spike_delivery_tick};
                    
                    state <= WRITE_BACK;
                end
                
                WRITE_BACK: begin
                    // Write back membrane potential
                    sram_write_request <= 1'b1;
                    updated_membrane_potential <= membrane_potential;
                    router_send_spike <= 1'b0;
                    state <= NEXT_NEURON;
                end
                
                NEXT_NEURON: begin
                    // Move to next neuron or finish
                    sram_write_request <= 1'b0;
                    if (current_neuron < 8'd255) begin
                        current_neuron <= current_neuron + 1'b1;
                        state <= READ_NEURON_DATA;
                    end else begin
                        // Processed all neurons
                        state <= CLEAR_AXONS;
                        delay_counter <= 8'd0;
                    end
                end
                
                CLEAR_AXONS: begin
                    // Clear current axon activity in scheduler
                    scheduler_clear_request <= 1'b1;
                    state <= WAIT_CLEAR;
                end
                
                WAIT_CLEAR: begin
                    if (delay_counter >= 8'd10) begin
                        scheduler_clear_request <= 1'b0;
                        state <= IDLE;
                        busy <= 1'b0;
                    end else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end
                
                ERROR_STATE: begin
                    // Handle error condition
                    error <= 1'b1;
                    busy <= 1'b0;
                    
                    // We stay in error state until reset
                end
                
                default: state <= ERROR_STATE;
            endcase
        end
    end

    // Timeout detection logic
    reg [15:0] timeout_counter;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            timeout_counter <= 16'd0;
        end else if (state == IDLE) begin
            timeout_counter <= 16'd0;
        end else begin
            timeout_counter <= timeout_counter + 1'b1;
            // If we've been processing for too long (e.g., 900 clock cycles, which is close to 1ms at typical clock rates)
            if (timeout_counter >= 16'd900) begin
                state <= ERROR_STATE;
            end
        end
    end

endmodule
