`timescale 1ns/100ps

module truenorth_core_tb();

  // Testbench parameters
  parameter TICK_PERIOD = 1000; // 1ms = 1000ns
  parameter CLK_PERIOD = 10;    // 100MHz clock

  // DUT signals
  reg clk;                  // System clock
  reg rst;                  // Reset
  reg tick;                 // 1kHz synchronization pulse
    
  // Router ports - North
  reg [25:0] north_in_data;
  reg north_in_valid;
  wire north_in_ready;
  wire [25:0] north_out_data;
  wire north_out_valid;
  reg north_out_ready;
    
  // Router ports - South
  reg [25:0] south_in_data;
  reg south_in_valid;
  wire south_in_ready;
  wire [25:0] south_out_data;
  wire south_out_valid;
  reg south_out_ready;
    
  // Router ports - East
  reg [25:0] east_in_data;
  reg east_in_valid;
  wire east_in_ready;
  wire [25:0] east_out_data;
  wire east_out_valid;
  reg east_out_ready;
  reg [25:0] packet;  
  // Router ports - West
  reg [25:0] west_in_data;
  reg west_in_valid;
  wire west_in_ready;
  wire [25:0] west_out_data;
  wire west_out_valid;
  reg west_out_ready;
    
  // Programming interface
  reg [409:0] prog_data;
  reg [7:0] prog_addr;
  reg prog_write_en;
  reg prog_read_en;
  wire [409:0] prog_read_data;
  wire prog_ready;
    
  // Status outputs
  wire core_busy;
  wire core_error;
  wire [7:0] error_status;

  // Testbench variables
  integer i, j;
  integer spikes_sent = 0;
  integer spikes_received = 0;

  // DUT Instantiation
  truenorth_core dut (
    .clk(clk),
    .rst(rst),
    .tick(tick),
    
    // Router ports - North
    .north_in_data(north_in_data),
    .north_in_valid(north_in_valid),
    .north_in_ready(north_in_ready),
    .north_out_data(north_out_data),
    .north_out_valid(north_out_valid),
    .north_out_ready(north_out_ready),
    
    // Router ports - South
    .south_in_data(south_in_data),
    .south_in_valid(south_in_valid),
    .south_in_ready(south_in_ready),
    .south_out_data(south_out_data),
    .south_out_valid(south_out_valid),
    .south_out_ready(south_out_ready),
    
    // Router ports - East
    .east_in_data(east_in_data),
    .east_in_valid(east_in_valid),
    .east_in_ready(east_in_ready),
    .east_out_data(east_out_data),
    .east_out_valid(east_out_valid),
    .east_out_ready(east_out_ready),
    
    // Router ports - West
    .west_in_data(west_in_data),
    .west_in_valid(west_in_valid),
    .west_in_ready(west_in_ready),
    .west_out_data(west_out_data),
    .west_out_valid(west_out_valid),
    .west_out_ready(west_out_ready),
    
    // Programming interface
    .prog_data(prog_data),
    .prog_addr(prog_addr),
    .prog_write_en(prog_write_en),
    .prog_read_en(prog_read_en),
    .prog_read_data(prog_read_data),
    .prog_ready(prog_ready),
    
    // Status outputs
    .core_busy(core_busy),
    .core_error(core_error),
    .error_status(error_status)
  );

  // Clock generation
  always #(CLK_PERIOD/2) clk = ~clk;

  // Tick generation (1kHz)
  reg [31:0] tick_counter;
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      tick_counter <= 0;
      tick <= 0;
    end else begin
      if (tick_counter >= (TICK_PERIOD/CLK_PERIOD) - 1) begin
        tick_counter <= 0;
        tick <= 1;
      end else begin
        tick_counter <= tick_counter + 1;
        tick <= 0;
      end
    end
  end

  // Task to program a neuron
  task program_neuron;
    input [7:0] neuron_id;
    input [255:0] synaptic_connections;
    input [7:0] membrane_potential;
    input [7:0] neuron_params;
    input [25:0] spike_destination;
    input [3:0] spike_delivery_tick;
    begin
      wait(prog_ready);
      @(posedge clk);
      
      prog_addr = neuron_id;
      prog_data = {
        synaptic_connections,         // 256 bits - synaptic connections
        membrane_potential,           // 8 bits - membrane potential
        neuron_params,                // 8 bits - neuron parameters
        {108'b0},                     // 108 bits - unused/other parameters
        spike_destination,            // 26 bits - spike destination
        spike_delivery_tick           // 4 bits - spike delivery tick
      };
      prog_write_en = 1;
      
      @(posedge clk);
      prog_write_en = 0;
      @(posedge clk);
      
      $display("Time %0t: Programmed neuron %0d", $time, neuron_id);
    end
  endtask

  // Task to send a spike packet
  task send_spike;
    input [1:0] direction; // 0=North, 1=South, 2=East, 3=West
    input [8:0] dx;
    input [8:0] dy;
    input [7:0] axon_id;
    input [3:0] delivery_tick;
    begin
      packet = {dx, dy, axon_id, delivery_tick, 2'b00};
      
      case (direction)
        0: begin // North
          wait(north_in_ready);
          @(posedge clk);
          north_in_data = packet;
          north_in_valid = 1;
          @(posedge clk);
          wait(north_in_ready);
          north_in_valid = 0;
        end
        1: begin // South
          wait(south_in_ready);
          @(posedge clk);
          south_in_data = packet;
          south_in_valid = 1;
          @(posedge clk);
          wait(south_in_ready);
          south_in_valid = 0;
        end
        2: begin // East
          wait(east_in_ready);
          @(posedge clk);
          east_in_data = packet;
          east_in_valid = 1;
          @(posedge clk);
          wait(east_in_ready);
          east_in_valid = 0;
        end
        3: begin // West
          wait(west_in_ready);
          @(posedge clk);
          west_in_data = packet;
          west_in_valid = 1;
          @(posedge clk);
          wait(west_in_ready);
          west_in_valid = 0;
        end
      endcase
      
      spikes_sent = spikes_sent + 1;
      $display("Time %0t: Sent spike packet to %s: dx=%0d, dy=%0d, axon=%0d, tick=%0d", 
               $time, 
               direction == 0 ? "North" : direction == 1 ? "South" : direction == 2 ? "East" : "West",
               dx, dy, axon_id, delivery_tick);
    end
  endtask

  // Monitors to detect output spikes
  always @(posedge clk) begin
    if (north_out_valid && north_out_ready) begin
      spikes_received = spikes_received + 1;
      $display("Time %0t: Received spike on North port: %h", $time, north_out_data);
    end
    
    if (south_out_valid && south_out_ready) begin
      spikes_received = spikes_received + 1;
      $display("Time %0t: Received spike on South port: %h", $time, south_out_data);
    end
    
    if (east_out_valid && east_out_ready) begin
      spikes_received = spikes_received + 1;
      $display("Time %0t: Received spike on East port: %h", $time, east_out_data);
    end
    
    if (west_out_valid && west_out_ready) begin
      spikes_received = spikes_received + 1;
      $display("Time %0t: Received spike on West port: %h", $time, west_out_data);
    end
  end

  // Main test sequence
  initial begin
    // Initialize signals
    clk = 0;
    rst = 1;
    tick = 0;
    
    north_in_data = 0;
    north_in_valid = 0;
    north_out_ready = 1;
    
    south_in_data = 0;
    south_in_valid = 0;
    south_out_ready = 1;
    
    east_in_data = 0;
    east_in_valid = 0;
    east_out_ready = 1;
    
    west_in_data = 0;
    west_in_valid = 0;
    west_out_ready = 1;
    
    prog_data = 0;
    prog_addr = 0;
    prog_write_en = 0;
    prog_read_en = 0;
    
    // Apply reset
    #100;
    rst = 0;
    #100;
    
    $display("Test 1: Simple programming and spike injection");
    
    // Program neurons with a simple chain reaction
    // Neuron 0: Receives on axon 10, fires to axon 20
    program_neuron(
      8'd0,                       // neuron_id
      (1 << 10),                  // synaptic_connections (only connected to axon 10)
      8'd0,                       // membrane_potential
      8'h20,                      // neuron_params (threshold=80, fires on positive threshold)
      {9'd0, 9'd0, 8'd20},        // spike_destination (local core, axon 20)
      4'd2                        // spike_delivery_tick (2 ticks in the future)
    );
    
    // Neuron 10: Receives on axon 20, fires to neighboring core (east)
    program_neuron(
      8'd10,                      // neuron_id
      (1 << 20),                  // synaptic_connections (only connected to axon 20)
      8'd0,                       // membrane_potential
      8'h20,                      // neuron_params (threshold=80, fires on positive threshold)
      {9'd1, 9'd0, 8'd30},        // spike_destination (1 hop east, axon 30)
      4'd2                        // spike_delivery_tick (2 ticks in the future)
    );
    
    // Wait for a tick and then send a spike to axon 10
    wait(tick);
    #10;
    
    // Inject a spike to axon 10 (dx=0, dy=0 means local core)
    send_spike(
      2'd3,                       // Direction (West)
      9'd0,                       // dx (0 hops)
      9'd0,                       // dy (0 hops)
      8'd10,                      // axon_id
      4'd1                        // delivery_tick (1 tick in the future)
    );
    
    // Wait for 5 ticks to see the results
    repeat(5) @(posedge tick);
    
    $display("Test 2: Router connectivity test");
    
    // Send spikes in all directions
    send_spike(2'd0, 9'd0, 9'd1, 8'd5, 4'd1);  // North, 1 hop north
    send_spike(2'd1, 9'd0, -9'd1, 8'd6, 4'd1); // South, 1 hop south
    send_spike(2'd2, 9'd1, 9'd0, 8'd7, 4'd1);  // East, 1 hop east
    send_spike(2'd3, -9'd1, 9'd0, 8'd8, 4'd1); // West, 1 hop west
    
    // Wait for routing to complete
    repeat(5) @(posedge tick);
    
    $display("Test 3: Load stress test");
    
    // Send multiple spikes in rapid succession
    fork
      begin
        repeat(10) begin
          send_spike(2'd0, $random % 9, $random % 9, $random % 256, $random % 4 + 1);
          #($random % 20);
        end
      end
      begin
        repeat(10) begin
          send_spike(2'd1, $random % 9, $random % 9, $random % 256, $random % 4 + 1);
          #($random % 20);
        end
      end
      begin
        repeat(10) begin
          send_spike(2'd2, $random % 9, $random % 9, $random % 256, $random % 4 + 1);
          #($random % 20);
        end
      end
      begin
        repeat(10) begin
          send_spike(2'd3, $random % 9, $random % 9, $random % 256, $random % 4 + 1);
          #($random % 20);
        end
      end
    join
    
    // Wait for all spikes to be processed
    repeat(10) @(posedge tick);
    
    // Final report
    $display("Test complete. Sent %0d spikes, received %0d spikes", spikes_sent, spikes_received);
    
    if (core_error)
      $display("Core reported errors during testing. Status: %h", error_status);
    else
      $display("No errors reported by core");
    
    $finish;
  end

endmodule
