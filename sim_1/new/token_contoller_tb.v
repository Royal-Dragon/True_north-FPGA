`timescale 1ns/1ps

module token_controller_tb;
    // Clock and reset
    reg clk;
    reg rst;
    reg tick;
    
    // Scheduler interface signals
    reg [255:0] axon_activity;
    wire scheduler_read_request;
    wire scheduler_clear_request;
    
    // Core SRAM interface signals
    wire [7:0] sram_addr;
    wire sram_read_request;
    reg [255:0] synaptic_connections;
    reg [7:0] membrane_potential;
    reg [7:0] neuron_params;
    wire sram_write_request;
    wire [7:0] updated_membrane_potential;
    
    // Neuron block interface signals
    wire neuron_clk_enable;
    wire [7:0] neuron_instruction;
    wire read_vj;
    wire write_vj;
    reg spike_transmit;
    
    // Router interface signals
    wire router_send_spike;
    wire [25:0] spike_packet;
    reg [25:0] spike_destination;
    reg [3:0] spike_delivery_tick;
    
    // Status signals
    wire busy;
    wire error;
    
    // Counters and monitoring
    integer cycles_count;
    integer neurons_processed;
    
    // Instantiate token controller
    token_controller uut (
        .clk(clk),
        .rst(rst),
        .tick(tick),
        
        // Scheduler interface
        .scheduler_read_request(scheduler_read_request),
        .axon_activity(axon_activity),
        .scheduler_clear_request(scheduler_clear_request),
        
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
        .spike_packet(spike_packet),
        .spike_destination(spike_destination),
        .spike_delivery_tick(spike_delivery_tick),
        
        // Status
        .busy(busy),
        .error(error)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    // Monitor state changes and important signals
    always @(posedge clk) begin
        if (uut.state != prev_state) begin
            $display("Time=%0t: State changed from %0d to %0d", 
                     $time, prev_state, uut.state);
            prev_state = uut.state;
        end
        
        if (neuron_clk_enable) begin
            $display("Time=%0t: Neuron clock enabled, instruction=%h", 
                     $time, neuron_instruction);
        end
        
        if (sram_read_request) begin
            $display("Time=%0t: Reading SRAM for neuron %0d", 
                     $time, sram_addr);
        end
        
        if (sram_write_request) begin
            $display("Time=%0t: Writing back membrane potential %h for neuron %0d", 
                     $time, updated_membrane_potential, sram_addr);
        end
        
        if (router_send_spike) begin
            $display("Time=%0t: Sending spike from neuron %0d, packet=%h", 
                     $time, sram_addr, spike_packet);
        end
        
        if (error) begin
            $display("ERROR detected at time %0t", $time);
        end
    end
    
    // Track neuron processing progress
    always @(posedge clk) begin
        if (sram_write_request) begin
            neurons_processed = neurons_processed + 1;
        end
    end
    
    // SRAM response simulator
    always @(posedge clk) begin
        if (sram_read_request) begin
            // Simulate SRAM read delay (1 cycle)
            #10;
            
            // Provide test data based on neuron address
            case (sram_addr)
                8'd0: begin
                    // Neuron 0: Has active synapses with axons 5 and 10
                    synaptic_connections = 256'h0;
                    synaptic_connections[5] = 1'b1;
                    synaptic_connections[10] = 1'b1;
                    membrane_potential = 8'h30;
                    neuron_params = 8'h20;      // Sample params
                    spike_destination = 26'h123; // Sample destination
                    spike_delivery_tick = 4'h3;  // Sample delivery tick
                end
                
                8'd1: begin
                    // Neuron 1: Has active synapses with axons 20 and 30
                    synaptic_connections = 256'h0;
                    synaptic_connections[20] = 1'b1;
                    synaptic_connections[30] = 1'b1;
                    membrane_potential = 8'h40;
                    neuron_params = 8'h20;      // Sample params
                    spike_destination = 26'h456; // Sample destination
                    spike_delivery_tick = 4'h2;  // Sample delivery tick
                end
                
                default: begin
                    // Other neurons: Random connections
                    synaptic_connections = 256'h0;
                    synaptic_connections[sram_addr+3] = 1'b1;
                    synaptic_connections[sram_addr*2] = 1'b1;
                    membrane_potential = 8'h20;
                    neuron_params = 8'h20;
                    spike_destination = 26'h100 + sram_addr;
                    spike_delivery_tick = 4'h1;
                end
            endcase
        end
    end
    
    // Neuron response simulator
    always @(posedge clk) begin
        if (neuron_clk_enable) begin
            case (neuron_instruction)
                8'h02: begin // Leak instruction
                    // No special response needed
                    spike_transmit = 1'b0;
                end
                
                8'h03: begin // Threshold check instruction
                    // Generate a spike for certain neurons (for testing)
                    spike_transmit = ((sram_addr % 10) == 0) ? 1'b1 : 1'b0;
                    #2; // Small delay
                end
                
                default: begin
                    spike_transmit = 1'b0;
                end
            endcase
        end else begin
            spike_transmit = 1'b0;
        end
    end
    
    // Test sequence
    reg [3:0] prev_state;
    
    initial begin
        // Initialize variables
        rst = 1;
        tick = 0;
        axon_activity = 256'h0;
        synaptic_connections = 256'h0;
        membrane_potential = 8'h0;
        neuron_params = 8'h0;
        spike_transmit = 0;
        spike_destination = 26'h0;
        spike_delivery_tick = 4'h0;
        cycles_count = 0;
        neurons_processed = 0;
        prev_state = 4'h0;
        
        // Apply reset for 20 ns
        #20 rst = 0;
        
        // Wait a bit after reset
        #20;
        
        // Test Case 1: Basic tick processing
        $display("\n--- Test Case 1: Basic tick processing ---");
        // Set up active axons
        axon_activity[5] = 1'b1;
        axon_activity[10] = 1'b1;
        axon_activity[20] = 1'b1;
        axon_activity[30] = 1'b1;
        
        // Apply a tick
        tick = 1;
        #10 tick = 0;
        
        // Wait for the controller to process all neurons
        wait(scheduler_clear_request);
        #40;
        
        $display("Processed %0d neurons in %0d cycles", neurons_processed, cycles_count);
        neurons_processed = 0;
        
        // Test Case 2: Sparse activity
        $display("\n--- Test Case 2: Sparse activity ---");
        // Only a few active axons
        axon_activity = 256'h0;
        axon_activity[100] = 1'b1;
        axon_activity[200] = 1'b1;
        
        // Apply a tick
        tick = 1;
        #10 tick = 0;
        
        // Wait for completion
        wait(scheduler_clear_request);
        #40;
        
        // Test Case 3: Dense activity (stress test)
        $display("\n--- Test Case 3: Dense activity (stress test) ---");
        // Many active axons
        axon_activity = {128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 128'h0};
        
        // Apply a tick
        tick = 1;
        #10 tick = 0;
        
        // Wait for completion or timeout
        fork : wait_block
            begin
                // Wait for completion
                wait(scheduler_clear_request);
            end
            begin
                // Timeout after 10000 cycles
                repeat(10000) @(posedge clk);
                $display("Timeout waiting for dense activity processing!");
                disable wait_block;
            end
        join
        
        #100;
        
        // Test Case 4: Error condition testing
        $display("\n--- Test Case 4: Error condition testing ---");
        // Force a timeout by not clearing a condition that would complete processing
        rst = 1;
        #20 rst = 0;
        
        // Set impossible activity pattern to trigger timeout
        axon_activity = {256{1'b1}}; // All axons active
        
        // Apply a tick
        tick = 1;
        #10 tick = 0;
        
        // Wait for error signal or completion
        fork : error_wait
            begin
                wait(error);
                $display("Error condition detected as expected!");
            end
            begin
                wait(scheduler_clear_request);
                $display("Unexpectedly completed processing without error!");
            end
            begin
                // Timeout after watching for a while
                repeat(10000) @(posedge clk);
                $display("Test timeout reached!");
                disable error_wait;
            end
        join
        
        #100;
        
        $display("\n--- All tests complete ---");
        $finish;
    end
    
    // Count clock cycles for performance metrics
    always @(posedge clk) begin
        cycles_count = cycles_count + 1;
    end
    
endmodule
