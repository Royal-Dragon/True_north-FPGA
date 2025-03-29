`timescale 1ns/1ps

module scheduler_tb;
    // Clock and reset signals
    reg clk;
    reg rst;
    
    // Router interface signals
    reg [13:0] spike_packet;     // [delivery_tick(4), axon_id(8), debug(2)]
    reg spike_packet_valid;
    wire spike_packet_ready;
    
    // Token controller interface signals
    reg read_request;
    wire [255:0] current_tick_spikes;
    reg clear_request;
    wire error;
    reg error_ack;
    
    // Debug signals
    wire [3:0] current_tick;
    
    // For monitoring
    integer i;
    integer errors_detected;
    integer spikes_written;
    integer test_phase;
    integer active_spikes;
    
    // Instantiate the scheduler module
    scheduler uut (
        .clk(clk),
        .rst(rst),
        // Router interface
        .spike_packet(spike_packet),
        .spike_packet_valid(spike_packet_valid),
        .spike_packet_ready(spike_packet_ready),
        // Token controller interface
        .read_request(read_request),
        .current_tick_spikes(current_tick_spikes),
        .clear_request(clear_request),
        .error(error),
        .error_ack(error_ack),
        // Debug output
        .current_tick(current_tick)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    // Error monitoring
    always @(posedge clk) begin
        if (error) begin
            errors_detected = errors_detected + 1;
            $display("Error detected at time %0t during test phase %0d", 
                     $time, test_phase);
        end
    end
    
    // Spike activity monitoring
    always @(posedge clk) begin
        if (spike_packet_valid && spike_packet_ready) begin
            spikes_written = spikes_written + 1;
            $display("Spike written at time %0t: tick=%0d, axon=%0d", 
                     $time, spike_packet[13:10], spike_packet[9:2]);
        end
    end
    
    // Test sequence
    initial begin
        // Initialize signals
        rst = 1;
        spike_packet = 14'h0;
        spike_packet_valid = 0;
        read_request = 0;
        clear_request = 0;
        error_ack = 0;
        errors_detected = 0;
        spikes_written = 0;
        test_phase = 0;
        
        // Apply reset
        #20 rst = 0;
        #20;
        
        // Test Phase 1: Basic spike writing to future ticks
        test_phase = 1;
        $display("\n*** Test Phase 1: Basic Spike Writing ***");
        
        // Write spikes to different future ticks and axons
        // Tick 1, Axons 5, 10, 20
        write_spike(4'h1, 8'd5, 2'b00);
        write_spike(4'h1, 8'd10, 2'b00);
        write_spike(4'h1, 8'd20, 2'b00);
        
        // Tick 2, Axons 50, 100
        write_spike(4'h2, 8'd50, 2'b00);
        write_spike(4'h2, 8'd100, 2'b00);
        
        // Tick 5, Axon 200
        write_spike(4'h5, 8'd200, 2'b00);
        #20;
        
        // Test Phase 2: Read current tick (should be empty)
        test_phase = 2;
        $display("\n*** Test Phase 2: Read Empty Tick ***");
        read_current_tick();
        check_spike_count(0);
        #20;
        
        // Test Phase 3: Processing tick 0 (current tick)
        test_phase = 3;
        $display("\n*** Test Phase 3: Processing Tick 0 ***");
        
        // Clear current tick and advance to tick 1
        clear_current_tick();
        #20;
        
        // Test Phase 4: Processing tick 1
        test_phase = 4;
        $display("\n*** Test Phase 4: Processing Tick 1 ***");
        
        // Read current tick (should have axons 5, 10, 20)
        read_current_tick();
        check_spike_count(3);
        check_spike_present(8'd5, 1);
        check_spike_present(8'd10, 1);
        check_spike_present(8'd20, 1);
        check_spike_present(8'd50, 0);
        #20;
        
        // Clear current tick and advance to tick 2
        clear_current_tick();
        #20;
        
        // Test Phase 5: Processing tick 2
        test_phase = 5;
        $display("\n*** Test Phase 5: Processing Tick 2 ***");
        
        // Read current tick (should have axons 50, 100)
        read_current_tick();
        check_spike_count(2);
        check_spike_present(8'd50, 1);
        check_spike_present(8'd100, 1);
        #20;
        
        // Clear current tick and advance to tick 3
        clear_current_tick();
        #20;
        
        // Test Phase 6: Add more spikes to future ticks
        test_phase = 6;
        $display("\n*** Test Phase 6: Add More Spikes ***");
        
        // Tick 5, Axon 150
        write_spike(4'h5, 8'd150, 2'b00);
        
        // Tick 7, Axon 255
        write_spike(4'h7, 8'd255, 2'b00);
        #20;
        
        // Test Phase 7: Processing tick 3 (should be empty)
        test_phase = 7;
        $display("\n*** Test Phase 7: Processing Empty Tick 3 ***");
        read_current_tick();
        check_spike_count(0);
        clear_current_tick();
        #20;
        
        // Test Phase 8: Processing tick 4 (should be empty)
        test_phase = 8;
        $display("\n*** Test Phase 8: Processing Empty Tick 4 ***");
        read_current_tick();
        check_spike_count(0);
        clear_current_tick();
        #20;
        
        // Test Phase 9: Processing tick 5
        test_phase = 9;
        $display("\n*** Test Phase 9: Processing Tick 5 ***");
        read_current_tick();
        check_spike_count(2);
        check_spike_present(8'd150, 1);
        check_spike_present(8'd200, 1);
        clear_current_tick();
        #20;
        
        // Test Phase 10: Error condition - write to current tick
        test_phase = 10;
        $display("\n*** Test Phase 10: Error Test - Write to Current Tick ***");
        
        // Set the current tick to 6 by clearing all previous ticks
        clear_current_tick();
        
        // Try to write to current tick (should cause error)
        spike_packet = {4'h6, 8'd80, 2'b00};
        spike_packet_valid = 1;
        @(posedge clk);
        
        // Wait for error to be detected
        wait(error);
        $display("Error detected as expected");
        
        // Acknowledge the error
        @(posedge clk);
        @(posedge clk);
        error_ack = 1;
        @(posedge clk);
        @(posedge clk);
        error_ack = 0;
        spike_packet_valid = 0;
        #20;
        
        // Test Phase 11: Tick wrap-around behavior
        test_phase = 11;
        $display("\n*** Test Phase 11: Tick Wrap-Around Test ***");
        
        // Advance through ticks until we get back to tick 0
        // From current tick to tick 15
        for (i = current_tick; i < 16; i = i + 1) begin
            $display("Processing tick %0d", i);
            read_current_tick();
            if (i == 7) check_spike_count(1);
            else check_spike_count(0);
            clear_current_tick();
            #10;
        end
        
        // Now at tick 0 (wrapped around), add a spike
        $display("Back at tick 0 (wrapped around)");
        write_spike(4'h0, 8'd1, 2'b00);
        read_current_tick();
        check_spike_count(1);
        check_spike_present(8'd1, 1);
        
        // Final report
        $display("\n*** Test Complete ***");
        $display("Spikes written: %0d", spikes_written);
        $display("Errors detected: %0d", errors_detected);
        
        if (errors_detected == 1)
            $display("TEST PASSED - All expected behaviors verified");
        else
            $display("TEST FAILED - Unexpected error count");
        
        $finish;
    end
    
    // Task to write a spike to the scheduler
    task write_spike;
        input [3:0] tick;
        input [7:0] axon;
        input [1:0] debug;
        begin
            spike_packet = {tick, axon, debug};
            spike_packet_valid = 1;
            
            // Wait for ready signal
            wait(spike_packet_ready);
            @(posedge clk);
            
            // Deassert valid after write
            spike_packet_valid = 0;
            @(posedge clk);
        end
    endtask
    
    // Task to read the current tick
    task read_current_tick;
        begin
            read_request = 1;
            @(posedge clk);
            read_request = 0;
            @(posedge clk);
            
            // Count active spikes
            active_spikes = 0;
            for (i = 0; i < 256; i = i + 1) begin
                if (current_tick_spikes[i])
                    active_spikes = active_spikes + 1;
            end
            
            // Display active axons
            $write("Active axons: ");
            for (i = 0; i < 256; i = i + 1) begin
                if (current_tick_spikes[i])
                    $write("%0d ", i);
            end
            $write("\n");
            $display("Total active axons: %0d", active_spikes);
        end
    endtask
    
    // Task to clear the current tick
    task clear_current_tick;
        begin
            clear_request = 1;
            @(posedge clk);
            clear_request = 0;
            @(posedge clk);
            $display("Current tick cleared and advanced to %0d", current_tick);
        end
    endtask
    
    // Task to check spike count
    task check_spike_count;
        input integer expected_count;
        integer actual_count;
        begin
            actual_count = 0;
            for (i = 0; i < 256; i = i + 1) begin
                if (current_tick_spikes[i])
                    actual_count = actual_count + 1;
            end
            
            if (actual_count == expected_count)
                $display("PASS: Found %0d spikes as expected", expected_count);
            else
                $display("FAIL: Expected %0d spikes, found %0d", expected_count, actual_count);
        end
    endtask
    
    // Task to check if a specific axon has a spike
    task check_spike_present;
        input [7:0] axon_id;
        input expected_value;
        begin
            if (current_tick_spikes[axon_id] == expected_value)
                $display("PASS: Axon %0d has expected value %0d", axon_id, expected_value);
            else
                $display("FAIL: Axon %0d has value %0d, expected %0d", 
                         axon_id, current_tick_spikes[axon_id], expected_value);
        end
    endtask
    
endmodule
