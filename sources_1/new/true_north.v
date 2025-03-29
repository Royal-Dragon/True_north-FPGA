module truenorth_core (
    input wire clk,                  // System clock
    input wire rst,                  // Reset
    input wire tick,                 // 1kHz synchronization pulse
    
    // Router ports - North
    input wire [25:0] north_in_data,
    input wire north_in_valid,
    output wire north_in_ready,
    output wire [25:0] north_out_data,
    output wire north_out_valid,
    input wire north_out_ready,
    
    // Router ports - South
    input wire [25:0] south_in_data,
    input wire south_in_valid,
    output wire south_in_ready,
    output wire [25:0] south_out_data,
    output wire south_out_valid,
    input wire south_out_ready,
    
    // Router ports - East
    input wire [25:0] east_in_data,
    input wire east_in_valid,
    output wire east_in_ready,
    output wire [25:0] east_out_data,
    output wire east_out_valid,
    input wire east_out_ready,
    
    // Router ports - West
    input wire [25:0] west_in_data,
    input wire west_in_valid,
    output wire west_in_ready,
    output wire [25:0] west_out_data,
    output wire west_out_valid,
    input wire west_out_ready,
    
    // Programming interface
    input wire [409:0] prog_data,
    input wire [7:0] prog_addr,
    input wire prog_write_en,
    input wire prog_read_en,
    output wire [409:0] prog_read_data,
    output wire prog_ready,
    
    // Status outputs
    output wire core_busy,
    output wire core_error,
    output wire [7:0] error_status
);

    // Internal connections
    wire [25:0] local_in_data;
    wire local_in_valid;
    wire local_in_ready;
    wire [13:0] local_out_data;  // To scheduler
    wire local_out_valid;
    wire local_out_ready;
    
    // Router to scheduler connections
    wire [13:0] spike_packet;
    wire spike_packet_valid;
    wire spike_packet_ready;
    
    // Scheduler to token controller connections
    wire read_request;
    wire [255:0] current_tick_spikes;
    wire clear_request;
    wire scheduler_error;
    wire error_ack;
    wire [3:0] current_tick;
    
    // Token controller to neuron block connections
    wire neuron_clk_enable;
    wire [7:0] neuron_instruction;
    wire read_vj;
    wire write_vj;
    wire spike_transmit;
    
    // Token controller to SRAM connections
    wire [7:0] sram_addr;
    wire sram_read_request;
    wire [255:0] synaptic_connections;
    wire [7:0] membrane_potential;
    wire [7:0] neuron_params;
    wire sram_write_request;
    wire [7:0] updated_membrane_potential;
    
    // Token controller to router connections
    wire router_send_spike;
    wire [25:0] spike_packet_to_router;
    
    // Core SRAM internal connections
    wire core_sram_ready;
    wire core_sram_error;
    wire [409:0] core_sram_read_data;
    
    // Extract components from core SRAM data
    assign synaptic_connections = core_sram_read_data[409:154];  // 256 bits
    assign membrane_potential = core_sram_read_data[153:146];    // 8 bits
    assign neuron_params = core_sram_read_data[145:138];         // 8 bits
    wire [25:0] spike_destination = core_sram_read_data[29:4];   // 26 bits
    wire [3:0] spike_delivery_tick = core_sram_read_data[3:0];   // 4 bits
    
    // SRAM data for writing
    wire [409:0] core_sram_write_data;
    assign core_sram_write_data[409:154] = synaptic_connections;
    assign core_sram_write_data[153:146] = updated_membrane_potential;
    assign core_sram_write_data[145:0] = core_sram_read_data[145:0]; // Other params unchanged
    
    // Access control for SRAM (programming vs. runtime)
    wire [409:0] sram_write_data = prog_write_en ? prog_data : core_sram_write_data;
    wire [7:0] sram_addr_mux = prog_write_en || prog_read_en ? prog_addr : sram_addr;
    wire sram_read_en = prog_read_en || sram_read_request;
    wire sram_write_en = prog_write_en || sram_write_request;
    
    // Status signals
    assign core_error = scheduler_error || core_sram_error;
    assign prog_ready = core_sram_ready;
    assign prog_read_data = core_sram_read_data;
    
    // Instantiate router
    router router_inst (
        .clk(clk),
        .rst(rst),
        
        // Local core interface
        .local_in_data(spike_packet_to_router),
        .local_in_valid(router_send_spike),
        .local_in_ready(local_in_ready),
        .local_out_data(spike_packet),
        .local_out_valid(spike_packet_valid),
        .local_out_ready(spike_packet_ready),
        
        // North port
        .north_in_data(north_in_data),
        .north_in_valid(north_in_valid),
        .north_in_ready(north_in_ready),
        .north_out_data(north_out_data),
        .north_out_valid(north_out_valid),
        .north_out_ready(north_out_ready),
        
        // South port
        .south_in_data(south_in_data),
        .south_in_valid(south_in_valid),
        .south_in_ready(south_in_ready),
        .south_out_data(south_out_data),
        .south_out_valid(south_out_valid),
        .south_out_ready(south_out_ready),
        
        // East port
        .east_in_data(east_in_data),
        .east_in_valid(east_in_valid),
        .east_in_ready(east_in_ready),
        .east_out_data(east_out_data),
        .east_out_valid(east_out_valid),
        .east_out_ready(east_out_ready),
        
        // West port
        .west_in_data(west_in_data),
        .west_in_valid(west_in_valid),
        .west_in_ready(west_in_ready),
        .west_out_data(west_out_data),
        .west_out_valid(west_out_valid),
        .west_out_ready(west_out_ready),
        
        // Error and status
        .timeout_error(router_timeout_error),
        .error_source(router_error_source)
    );
    
    // Instantiate scheduler
    scheduler scheduler_inst (
        .clk(clk),
        .rst(rst),
        
        // Router interface
        .spike_packet(spike_packet[13:0]),
        .spike_packet_valid(spike_packet_valid),
        .spike_packet_ready(spike_packet_ready),
        
        // Token controller interface
        .read_request(read_request),
        .current_tick_spikes(current_tick_spikes),
        .clear_request(clear_request),
        .error(scheduler_error),
        .error_ack(error_ack),
        
        // Status and debug
        .current_tick(current_tick),
        .error_status(error_status)
    );
    
    // Instantiate token controller
    token_controller token_controller_inst (
        .clk(clk),
        .rst(rst),
        .tick(tick),
        
        // Scheduler interface
        .scheduler_read_request(read_request),
        .axon_activity(current_tick_spikes),
        .scheduler_clear_request(clear_request),
        
        // Core SRAM interface
        .sram_addr(sram_addr),
        .sram_read_request(sram_read_request),
        .synaptic_connections(synaptic_connections),
        .membrane_potential(membrane_potential),
        .neuron_params(neuron_params),
        .sram_write_request(sram_write_request),
        .updated_membrane_potential(updated_membrane_potential),
        
        // Neuron block interface
        .neuron_clk_enable(neuron_clk_enable),
        .neuron_instruction(neuron_instruction),
        .read_vj(read_vj),
        .write_vj(write_vj),
        .spike_transmit(spike_transmit),
        
        // Router interface
        .router_send_spike(router_send_spike),
        .spike_packet(spike_packet_to_router),
        .spike_destination(spike_destination),
        .spike_delivery_tick(spike_delivery_tick),
        
        // Status
        .busy(core_busy),
        .error(token_controller_error)
    );
    
    // Generate stochastic inputs for neuron
    wire [7:0] random_number;
    lfsr_random random_gen (
        .clk(clk),
        .rst(rst),
        .random_out(random_number)
    );
    
    // Extract neuron parameters from memory
    wire [1:0] mode_select = neuron_params[1:0];
    wire sign_select = neuron_params[2];
    wire [3:0] synaptic_weights = neuron_params[6:3];
    wire stoch_det_mode_select = neuron_params[7];
    wire [1:0] pos_neg_thresholds = membrane_potential[1:0];
    wire mask = membrane_potential[2];
    wire [7:0] v_reset = membrane_potential[7:0];
    wire [7:0] leak_weight = core_sram_read_data[137:130];
    
    // Instantiate neuron block
    neuron_block neuron_block_inst (
        .clk(neuron_clk_enable),  // Gated clock from token controller
        .rst(rst),
        
        // Control signals
        .mode_select(mode_select),
        .read_vj(read_vj),
        .write_vj(write_vj),
        .sign_select(sign_select),
        .synaptic_weights(synaptic_weights),
        .stoch_det_mode_select(stoch_det_mode_select),
        .pos_neg_thresholds(pos_neg_thresholds),
        .mask(mask),
        .v_reset(v_reset),
        
        // Data inputs
        .leak_weight(leak_weight),
        .neuron_instruction(neuron_instruction),
        .write_membrane_value(updated_membrane_potential),
        .random_number(random_number),
        
        // Outputs
        .spike_transmit(spike_transmit),
        .membrane_potential(membrane_potential)
    );
    
    // Instantiate core SRAM
    core_sram core_sram_inst (
        .clk(clk),
        .rst(rst),
        
        // Control signals
        .read_request(sram_read_en),
        .write_request(sram_write_en),
        .addr(sram_addr_mux),
        
        // Data signals
        .write_data(sram_write_data),
        .read_data(core_sram_read_data),
        
        // Status signals
        .ready(core_sram_ready),
        .error(core_sram_error)
    );
    
endmodule

// Simple LFSR for random number generation
module lfsr_random (
    input wire clk,
    input wire rst,
    output reg [7:0] random_out
);
    // 8-bit LFSR implementation
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            random_out <= 8'h4A;  // Non-zero seed
        end else begin
            random_out <= {random_out[6:0], random_out[7] ^ random_out[5] ^ random_out[4] ^ random_out[3]};
        end
    end
endmodule
