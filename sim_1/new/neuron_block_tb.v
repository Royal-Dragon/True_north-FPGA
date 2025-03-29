module neuron_block_tb;
    // Inputs
    reg clk;
    reg rst;
    reg [1:0] mode_select;
    reg read_vj;
    reg write_vj;
    reg sign_select;
    reg [3:0] synaptic_weights;
    reg stoch_det_mode_select;
    reg [1:0] pos_neg_thresholds;
    reg mask;
    reg [7:0] v_reset;
    reg [7:0] leak_weight;
    reg [7:0] neuron_instruction;
    reg [7:0] write_membrane_value;
    reg [7:0] random_number;
    
    // Outputs
    wire spike_transmit;
    wire [7:0] membrane_potential;
    
    // For monitoring
    integer spike_count = 0;
    
    // Instantiate the Unit Under Test (UUT)
    neuron_block uut (
        .clk(clk),
        .rst(rst),
        .mode_select(mode_select),
        .read_vj(read_vj),
        .write_vj(write_vj),
        .sign_select(sign_select),
        .synaptic_weights(synaptic_weights),
        .stoch_det_mode_select(stoch_det_mode_select),
        .pos_neg_thresholds(pos_neg_thresholds),
        .mask(mask),
        .v_reset(v_reset),
        .leak_weight(leak_weight),
        .neuron_instruction(neuron_instruction),
        .write_membrane_value(write_membrane_value),
        .random_number(random_number),
        .spike_transmit(spike_transmit),
        .membrane_potential(membrane_potential)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    // Count spikes for analysis
    always @(posedge clk) begin
        if (spike_transmit) begin
            spike_count = spike_count + 1;
            $display("Spike #%0d detected at time %0t, membrane_potential=%h, v_reset=%h", 
                     spike_count, $time, membrane_potential, v_reset);
        end
    end
    
    // Test sequence
    initial begin
        // Initialize inputs
        rst = 1;
        mode_select = 2'b00;
        read_vj = 0;
        write_vj = 0;
        sign_select = 0;
        synaptic_weights = 4'h3;
        stoch_det_mode_select = 0;
        pos_neg_thresholds = 2'b01; // Positive threshold only
        mask = 0;
        v_reset = 8'h00; // Reset to 0
        leak_weight = 8'hF0; // Strong leak
        neuron_instruction = 8'h01;
        write_membrane_value = 8'h00;
        random_number = 8'h00;
        
        // Reset sequence
        #20 rst = 0;
        
        // Test case 1: Initialize membrane potential
        #20;
        write_vj = 1;
        write_membrane_value = 8'h70; // Set to value below threshold
        #10;
        write_vj = 0;
        
        // Test case 2: Apply constant input to reach threshold
        #20;
        synaptic_weights = 4'h8; // Strong excitatory input
        neuron_instruction = 8'h01; // Activate input
        
        // Let the simulation run to observe multiple spikes
        #500;
        
        // Test case 3: Change reset value and observe effect
        v_reset = 8'h20; // Reset to higher value
        #500;
        
        // Test case 4: Test stochastic mode
        stoch_det_mode_select = 1;
        random_number = 8'h40;
        #500;
        
        // Test case 5: Test with negative threshold
        pos_neg_thresholds = 2'b11; // Both thresholds
        sign_select = 1; // Inhibitory input
        #500;
        
        // End simulation
        $display("Simulation completed with %0d spikes detected", spike_count);
        $finish;
    end
    
    // Monitor key signals
    initial begin
        $monitor("Time=%0t, membrane_potential=%h, spike=%b, v_reset=%h, refractory=%b", 
                 $time, membrane_potential, spike_transmit, v_reset, uut.in_refractory_period);
    end
    
endmodule
