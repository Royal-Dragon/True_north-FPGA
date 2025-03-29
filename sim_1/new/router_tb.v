`timescale 1ns/1ps

module router_tb;
    // Clock and reset signals
    reg clk;
    reg rst;
    
    // Local core interface
    reg [25:0] local_in_data;    // Spike packet from local core
    reg local_in_valid;          // Valid signal for local input
    wire local_in_ready;         // Ready signal for local input
    wire [13:0] local_out_data;  // Spike packet to local core scheduler
    wire local_out_valid;        // Valid signal for local output
    reg local_out_ready;         // Ready signal from scheduler
    
    // North port interface
    reg [25:0] north_in_data;
    reg north_in_valid;
    wire north_in_ready;
    wire [25:0] north_out_data;
    wire north_out_valid;
    reg north_out_ready;
    
    // South port interface
    reg [25:0] south_in_data;
    reg south_in_valid;
    wire south_in_ready;
    wire [25:0] south_out_data;
    wire south_out_valid;
    reg south_out_ready;
    
    // East port interface
    reg [25:0] east_in_data;
    reg east_in_valid;
    wire east_in_ready;
    wire [25:0] east_out_data;
    wire east_out_valid;
    reg east_out_ready;
    
    // West port interface
    reg [25:0] west_in_data;
    reg west_in_valid;
    wire west_in_ready;
    wire [25:0] west_out_data;
    wire west_out_valid;
    reg west_out_ready;
    
    // Error and status signals
    wire timeout_error;
    wire [2:0] error_source;
    
    // Monitoring variables
    integer packets_sent;
    integer packets_received;
    
    
    // Instantiate the router module
    router uut (
        .clk(clk),
        .rst(rst),
        
        // Local core interface
        .local_in_data(local_in_data),
        .local_in_valid(local_in_valid),
        .local_in_ready(local_in_ready),
        .local_out_data(local_out_data),
        .local_out_valid(local_out_valid),
        .local_out_ready(local_out_ready),
        
        // North port interface
        .north_in_data(north_in_data),
        .north_in_valid(north_in_valid),
        .north_in_ready(north_in_ready),
        .north_out_data(north_out_data),
        .north_out_valid(north_out_valid),
        .north_out_ready(north_out_ready),
        
        // South port interface
        .south_in_data(south_in_data),
        .south_in_valid(south_in_valid),
        .south_in_ready(south_in_ready),
        .south_out_data(south_out_data),
        .south_out_valid(south_out_valid),
        .south_out_ready(south_out_ready),
        
        // East port interface
        .east_in_data(east_in_data),
        .east_in_valid(east_in_valid),
        .east_in_ready(east_in_ready),
        .east_out_data(east_out_data),
        .east_out_valid(east_out_valid),
        .east_out_ready(east_out_ready),
        
        // West port interface
        .west_in_data(west_in_data),
        .west_in_valid(west_in_valid),
        .west_in_ready(west_in_ready),
        .west_out_data(west_out_data),
        .west_out_valid(west_out_valid),
        .west_out_ready(west_out_ready),
        
        // Error signals
        .timeout_error(timeout_error),
        .error_source(error_source)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    // Monitoring functions
    always @(posedge clk) begin
        if (local_in_valid && local_in_ready)
            $display("Time=%0t: Packet sent from LOCAL, dx=%0d, dy=%0d, axon=%0d", 
                     $time, local_in_data[25:17], local_in_data[16:8], local_in_data[7:0]);
                     
        if (local_out_valid && local_out_ready)
            $display("Time=%0t: Packet received at LOCAL, axon=%0d, delivery_tick=%0d", 
                     $time, local_out_data[13:6], local_out_data[5:2]);
                     
        if (timeout_error)
            $display("Time=%0t: TIMEOUT ERROR detected! Source: %0d", $time, error_source);
    end
    
    // Task to send a packet from local core
    task send_local_packet;
        input [8:0] dx;
        input [8:0] dy;
        input [7:0] axon_id;
        input [3:0] delivery_tick;
        input [1:0] debug;
        begin
            wait(local_in_ready);
            @(posedge clk);
            
            local_in_data = {dx, dy, axon_id, delivery_tick, debug};
            local_in_valid = 1'b1;
            
            wait(local_in_ready);
            @(posedge clk);
            
            local_in_valid = 1'b0;
            @(posedge clk);
            
            packets_sent = packets_sent + 1;
        end
    endtask
    
    // Task to send a packet from north router
    task send_north_packet;
        input [8:0] dx;
        input [8:0] dy;
        input [7:0] axon_id;
        input [3:0] delivery_tick;
        input [1:0] debug;
        begin
            wait(north_in_ready);
            @(posedge clk);
            
            north_in_data = {dx, dy, axon_id, delivery_tick, debug};
            north_in_valid = 1'b1;
            
            wait(north_in_ready);
            @(posedge clk);
            
            north_in_valid = 1'b0;
            @(posedge clk);
            
            packets_sent = packets_sent + 1;
        end
    endtask
    
    // Task to send a packet from south router
    task send_south_packet;
        input [8:0] dx;
        input [8:0] dy;
        input [7:0] axon_id;
        input [3:0] delivery_tick;
        input [1:0] debug;
        begin
            wait(south_in_ready);
            @(posedge clk);
            
            south_in_data = {dx, dy, axon_id, delivery_tick, debug};
            south_in_valid = 1'b1;
            
            wait(south_in_ready);
            @(posedge clk);
            
            south_in_valid = 1'b0;
            @(posedge clk);
            
            packets_sent = packets_sent + 1;
        end
    endtask
    
    // Task to send a packet from east router
    task send_east_packet;
        input [8:0] dx;
        input [8:0] dy;
        input [7:0] axon_id;
        input [3:0] delivery_tick;
        input [1:0] debug;
        begin
            wait(east_in_ready);
            @(posedge clk);
            
            east_in_data = {dx, dy, axon_id, delivery_tick, debug};
            east_in_valid = 1'b1;
            
            wait(east_in_ready);
            @(posedge clk);
            
            east_in_valid = 1'b0;
            @(posedge clk);
            
            packets_sent = packets_sent + 1;
        end
    endtask
    
    // Task to send a packet from west router
    task send_west_packet;
        input [8:0] dx;
        input [8:0] dy;
        input [7:0] axon_id;
        input [3:0] delivery_tick;
        input [1:0] debug;
        begin
            wait(west_in_ready);
            @(posedge clk);
            
            west_in_data = {dx, dy, axon_id, delivery_tick, debug};
            west_in_valid = 1'b1;
            
            wait(west_in_ready);
            @(posedge clk);
            
            west_in_valid = 1'b0;
            @(posedge clk);
            
            packets_sent = packets_sent + 1;
        end
    endtask
    
    // Task to verify routing works as expected
    task check_routing;
        input [8:0] dx;
        input [8:0] dy;
        input [7:0] axon_id;
        input expected_east;
        input expected_west;
        input expected_north;
        input expected_south;
        input expected_local;
        
         reg route_detected;  // Moved here at the beginning of the task
         integer i;           // Moved here at the beginning of the task
        begin

            
            route_detected = 0;
            
            for (i = 0; i < 50 && !route_detected; i = i + 1) begin
                @(posedge clk);
                
                // Check each output port
                if (expected_east && east_out_valid && east_out_data[7:0] == axon_id) begin
                    $display("PASS: Packet routed to EAST as expected");
                    route_detected = 1;
                    packets_received = packets_received + 1;
                end
                
                if (expected_west && west_out_valid && west_out_data[7:0] == axon_id) begin
                    $display("PASS: Packet routed to WEST as expected");
                    route_detected = 1;
                    packets_received = packets_received + 1;
                end
                
                if (expected_north && north_out_valid && north_out_data[7:0] == axon_id) begin
                    $display("PASS: Packet routed to NORTH as expected");
                    route_detected = 1;
                    packets_received = packets_received + 1;
                end
                
                if (expected_south && south_out_valid && south_out_data[7:0] == axon_id) begin
                    $display("PASS: Packet routed to SOUTH as expected");
                    route_detected = 1;
                    packets_received = packets_received + 1;
                end
                
                if (expected_local && local_out_valid && local_out_data[13:6] == axon_id) begin
                    $display("PASS: Packet delivered to LOCAL as expected");
                    route_detected = 1;
                    packets_received = packets_received + 1;
                end
            end
            
            if (!route_detected)
                $display("FAIL: Packet routing verification failed");
        end
    endtask
    
    // Main test sequence
    initial begin
        // Initialize signals
        rst = 1;
        local_in_data = 26'h0;
        local_in_valid = 0;
        local_out_ready = 1;
        
        north_in_data = 26'h0;
        north_in_valid = 0;
        north_out_ready = 1;
        
        south_in_data = 26'h0;
        south_in_valid = 0;
        south_out_ready = 1;
        
        east_in_data = 26'h0;
        east_in_valid = 0;
        east_out_ready = 1;
        
        west_in_data = 26'h0;
        west_in_valid = 0;
        west_out_ready = 1;
        
        packets_sent = 0;
        packets_received = 0;
        
        // Apply reset
        #20 rst = 0;
        #20;
        
        // Test Case 1: Basic Routing Tests
        $display("\n*** Test Case 1: Basic Routing Tests ***");
        // Local to East
        send_local_packet(9'd5, 9'd0, 8'h42, 4'h1, 2'b00);
        check_routing(9'd5, 9'd0, 8'h42, 1, 0, 0, 0, 0);
        #20;
        
        // Local to West
        send_local_packet(-9'd3, 9'd0, 8'h43, 4'h2, 2'b00);
        check_routing(-9'd3, 9'd0, 8'h43, 0, 1, 0, 0, 0);
        #20;
        
        // Local to North
        send_local_packet(9'd0, 9'd4, 8'h44, 4'h3, 2'b00);
        check_routing(9'd0, 9'd4, 8'h44, 0, 0, 1, 0, 0);
        #20;
        
        // Local to South
        send_local_packet(9'd0, -9'd2, 8'h45, 4'h4, 2'b00);
        check_routing(9'd0, -9'd2, 8'h45, 0, 0, 0, 1, 0);
        #20;
        
        // Local to Local
        send_local_packet(9'd0, 9'd0, 8'h46, 4'h5, 2'b00);
        check_routing(9'd0, 9'd0, 8'h46, 0, 0, 0, 0, 1);
        #50;
        
        // Test Case 2: East/West First Routing Policy
        $display("\n*** Test Case 2: East/West First Routing Policy ***");
        send_local_packet(9'd2, 9'd3, 8'h47, 4'h6, 2'b00);
        check_routing(9'd2, 9'd3, 8'h47, 1, 0, 0, 0, 0);
        #50;
        
        // Test Case 3: Simultaneous Packets
        $display("\n*** Test Case 3: Simultaneous Packet Routing ***");
        fork
            send_local_packet(9'd1, 9'd0, 8'h48, 4'h7, 2'b00);
            send_north_packet(9'd0, -9'd1, 8'h49, 4'h8, 2'b00);
        join
        #100;
        
        // Test Case 4: Backpressure Testing
        $display("\n*** Test Case 4: Backpressure Testing ***");
        east_out_ready = 0;
        send_local_packet(9'd3, 9'd0, 8'h4A, 4'h9, 2'b00);
        #50;
        east_out_ready = 1;
        #50;
        
        // Test Case 5: Multiple Input Congestion
        $display("\n*** Test Case 5: Multiple Input Congestion ***");
        fork
            send_local_packet(9'd1, 9'd0, 8'h50, 4'hA, 2'b00);
            send_north_packet(9'd0, -9'd1, 8'h51, 4'hB, 2'b00);
            send_south_packet(9'd0, 9'd1, 8'h52, 4'hC, 2'b00);
            send_east_packet(-9'd1, 9'd0, 8'h53, 4'hD, 2'b00);
            send_west_packet(9'd1, 9'd0, 8'h54, 4'hE, 2'b00);
        join
        #200;
        
        // Test Case 6: Boundary Values
        $display("\n*** Test Case 6: Boundary Values ***");
        send_local_packet(9'd255, 9'd255, 8'hFF, 4'hF, 2'b11);
        #50;
        send_local_packet(-9'd255, -9'd255, 8'h00, 4'h0, 2'b00);
        #50;
        
        // Test Case 7: Timeout Detection
        $display("\n*** Test Case 7: Timeout Detection Test ***");
        // Disable all output readys to force a timeout
        local_out_ready = 0;
        north_out_ready = 0;
        south_out_ready = 0;
        east_out_ready = 0;
        west_out_ready = 0;
        send_local_packet(9'd1, 9'd0, 8'h60, 4'h0, 2'b00);
        #3000; // Wait for timeout
        
        // Re-enable outputs
        local_out_ready = 1;
        north_out_ready = 1;
        south_out_ready = 1;
        east_out_ready = 1;
        west_out_ready = 1;
        
        // Final report
        $display("\n*** Test Complete ***");
        $display("Packets sent: %0d", packets_sent);
        $display("Packets received: %0d", packets_received);
        
        if (packets_sent == packets_received)
            $display("TEST PASSED - All packets were routed correctly");
        else
            $display("TEST FAILED - %0d packets lost", packets_sent - packets_received);
        
        $finish;
    end
endmodule
