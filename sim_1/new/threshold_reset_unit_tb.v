module threshold_reset_unit_tb;
    // Inputs
    reg clk;
    reg rst;
    reg [7:0] membrane_potential;
    reg [1:0] pos_neg_thresholds;
    reg mask;
    reg [7:0] v_reset;
    
    // Outputs
    wire threshold_output;
    wire [7:0] reset_membrane_potential;
    
    // Instantiate the Unit Under Test (UUT)
    threshold_reset_unit uut (
        .clk(clk),
        .rst(rst),
        .membrane_potential(membrane_potential),
        .pos_neg_thresholds(pos_neg_thresholds),
        .mask(mask),
        .v_reset(v_reset),
        .threshold_output(threshold_output),
        .reset_membrane_potential(reset_membrane_potential)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    // Test sequence
    initial begin
        // Initialize inputs
        rst = 1;
        membrane_potential = 8'h00;
        pos_neg_thresholds = 2'b01; // Positive threshold only
        mask = 0;
        v_reset = 8'h00;
        
        // Reset sequence
        #20 rst = 0;
        
        // Test case 1: Below threshold
        #20;
        membrane_potential = 8'h70; // Below positive threshold (8'h80)
        v_reset = 8'h00;
        
        // Test case 2: Above threshold - should trigger reset
        #20;
        membrane_potential = 8'h90; // Above positive threshold
        
        // Test case 3: Test with different reset value
        #20;
        membrane_potential = 8'h70; // Below threshold again
        v_reset = 8'h20; // Different reset value
        
        #20;
        membrane_potential = 8'h90; // Above threshold again
        
        // Test case 4: Test with mask
        #20;
        membrane_potential = 8'h70;
        mask = 1;
        
        #20;
        membrane_potential = 8'h90; // Should still trigger with mask=1
        
        // Test case 5: Test with negative threshold
        #20;
        membrane_potential = 8'h50;
        pos_neg_thresholds = 2'b10; // Negative threshold only
        
        #20;
        membrane_potential = 8'h30; // Below negative threshold (8'h40)
        
        // End simulation
        #20;
        $finish;
    end
    
    // Monitor
    initial begin
        $monitor("Time=%t, membrane_potential=%h, threshold_output=%b, reset_membrane_potential=%h", 
                 $time, membrane_potential, threshold_output, reset_membrane_potential);
    end
    
endmodule
