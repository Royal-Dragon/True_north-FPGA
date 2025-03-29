module neuron_block (
    input wire clk,
    input wire rst,
    // Control signals
    input wire [1:0] mode_select,
    input wire read_vj,
    input wire write_vj,
    input wire sign_select,
    input wire [3:0] synaptic_weights,
    input wire stoch_det_mode_select,
    input wire [1:0] pos_neg_thresholds,
    input wire mask,
    input wire [7:0] v_reset,
    // Data inputs
    input wire [7:0] leak_weight,
    input wire [7:0] neuron_instruction,
    input wire [7:0] write_membrane_value,
    // Random number input for stochastic mode
    input wire [7:0] random_number,
    // Outputs
    output wire spike_transmit,
    output wire [7:0] membrane_potential
);

    // Internal signals
    wire [7:0] leak_output;
    wire [7:0] leak_reversal_output;
    wire [7:0] synapse_output;
    wire [7:0] integrator_output;
    wire threshold_crossed;
    reg in_refractory_period;
    reg [3:0] refractory_counter;
    
    // Membrane potential register
    reg [7:0] v_j;
    
    // Assign membrane potential output
    assign membrane_potential = v_j;
    
    // Spike transmission with refractory period control
    assign spike_transmit = threshold_crossed && !in_refractory_period;
    
    // Refractory period management
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            in_refractory_period <= 0;
            refractory_counter <= 0;
        end else if (threshold_crossed && !in_refractory_period) begin
            // Start refractory period when threshold is crossed
            in_refractory_period <= 1;
            refractory_counter <= 4'hF; // 5 clock cycles refractory period
        end else if (in_refractory_period) begin
            if (refractory_counter == 0) begin
                in_refractory_period <= 0;
            end else begin
                refractory_counter <= refractory_counter - 1;
            end
        end
    end
    
    // Leak Unit
    leak_unit leak_unit_inst (
        .clk(clk),
        .rst(rst),
        .membrane_potential(v_j),
        .leak_weight(leak_weight),
        .leak_output(leak_output)
    );
    
    // Leak Reversal Unit
    leak_reversal_unit leak_reversal_inst (
        .clk(clk),
        .rst(rst),
        .leak_input(leak_output),
        .mode_select(mode_select),
        .leak_reversal_output(leak_reversal_output)
    );
    
    // Synapse Unit
    synapse_unit synapse_inst (
        .clk(clk),
        .rst(rst),
        .neuron_instruction(neuron_instruction),
        .sign_select(sign_select),
        .synaptic_weights(synaptic_weights),
        .stoch_det_mode_select(stoch_det_mode_select),
        .random_number(random_number),
        .synapse_output(synapse_output)
    );
    
    // Threshold Detection Unit
    threshold_detection_unit threshold_inst (
        .clk(clk),
        .rst(rst),
        .membrane_potential(v_j),
        .pos_neg_thresholds(pos_neg_thresholds),
        .mask(mask),
        .threshold_crossed(threshold_crossed)
    );
    
    // Integrator Unit
    integrator_unit integrator_inst (
        .clk(clk),
        .rst(rst),
        .leak_input(leak_reversal_output),
        .synapse_input(synapse_output),
        .mode_select(mode_select),
        .read_vj(read_vj),
        .write_vj(write_vj),
        .write_membrane_value(write_membrane_value),
        .spike_detected(spike_transmit),
        .v_reset(v_reset),
        .integrator_output(integrator_output)
    );
    
    // Update membrane potential
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            v_j <= 8'h00;
        end else if (spike_transmit) begin
            // Direct reset when spike is transmitted
            v_j <= v_reset;
        end else begin
            v_j <= integrator_output;
        end
    end
    
endmodule

module threshold_detection_unit (
    input wire clk,
    input wire rst,
    input wire [7:0] membrane_potential,
    input wire [1:0] pos_neg_thresholds,
    input wire mask,
    output reg threshold_crossed
);

    // Define threshold values
//    wire [7:0] pos_threshold = 8'h80;  Example positive threshold
    wire [7:0] pos_threshold = 8'h50; // Lower positive threshold (example)
    wire [7:0] neg_threshold = 8'h40; // Example negative threshold
    
    // Threshold comparison logic
    wire pos_threshold_crossed = membrane_potential >= pos_threshold;
    wire neg_threshold_crossed = membrane_potential <= neg_threshold;
    
    // Threshold selection based on pos_neg_thresholds
    reg threshold_result;
    
    always @(*) begin
        case (pos_neg_thresholds)
            2'b00: threshold_result = 1'b0;                  // No threshold
            2'b01: threshold_result = pos_threshold_crossed; // Positive threshold only
            2'b10: threshold_result = neg_threshold_crossed; // Negative threshold only
            2'b11: threshold_result = pos_threshold_crossed || neg_threshold_crossed; // Both thresholds
        endcase
    end
    
    // Apply mask if needed and register the output
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            threshold_crossed <= 1'b0;
        end else begin
            threshold_crossed <= mask ? (threshold_result & mask) : threshold_result;
        end
    end

endmodule

module integrator_unit (
    input wire clk,
    input wire rst,
    input wire [7:0] leak_input,
    input wire [7:0] synapse_input,
    input wire [1:0] mode_select,
    input wire read_vj,
    input wire write_vj,
    input wire [7:0] write_membrane_value,
    input wire spike_detected,
    input wire [7:0] v_reset,
    output reg [7:0] integrator_output
);

    reg [7:0] membrane_value;
    
    // Integration logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            membrane_value <= 8'h00;
            integrator_output <= 8'h00;
        end else if (spike_detected) begin
            // Reset membrane potential when spike is detected
            membrane_value <= v_reset;
            integrator_output <= v_reset;
        end else if (write_vj) begin
            // Handle explicit write operations
            membrane_value <= write_membrane_value;
            integrator_output <= write_membrane_value;
        end else begin
            // Normal integration operation
            membrane_value <= membrane_value + leak_input + synapse_input;
            integrator_output <= membrane_value + leak_input + synapse_input;
        end
    end
endmodule

module leak_unit (
    input wire clk,
    input wire rst,
    input wire [7:0] membrane_potential,
    input wire [7:0] leak_weight,
    output wire [7:0] leak_output
);

    // Implement leakage effect by multiplying membrane potential with leak weight
    // This is a simplified implementation - actual implementation would use a multiplier
    wire [15:0] mult_result;
    assign mult_result = membrane_potential * leak_weight;
    
    // Scale down the result (assuming leak_weight is a fraction)
    assign leak_output = mult_result[15:8]; // Take the high byte as result

endmodule

module leak_reversal_unit (
    input wire clk,
    input wire rst,
    input wire [7:0] leak_input,
    input wire [1:0] mode_select,
    output reg [7:0] leak_reversal_output
);

    // Mode-dependent leak reversal
    always @(*) begin
        case (mode_select)
            2'b00: leak_reversal_output = leak_input;                // Normal mode
            2'b01: leak_reversal_output = ~leak_input + 8'h01;       // Invert (2's complement)
            2'b10: leak_reversal_output = 8'h00;                     // Zero leak
            2'b11: leak_reversal_output = {leak_input[7], leak_input[6:0]}; // Sign-preserve mode
        endcase
    end

endmodule

module synapse_unit (
    input wire clk,
    input wire rst,
    input wire [7:0] neuron_instruction,
    input wire sign_select,
    input wire [3:0] synaptic_weights,
    input wire stoch_det_mode_select,
    input wire [7:0] random_number,
    output reg [7:0] synapse_output
);

    wire [7:0] weight_value;
    wire [7:0] stochastic_output;
    wire [7:0] deterministic_output;
    
    // Extend synaptic weight to 8 bits
    assign weight_value = {4'b0000, synaptic_weights};
    
    // Deterministic mode - direct multiplication
    assign deterministic_output = neuron_instruction[0] ? 
                                 (sign_select ? -weight_value : weight_value) : 8'h00;
    
    // Stochastic mode - probabilistic output based on random number
    assign stochastic_output = (random_number < weight_value) ? 
                              (sign_select ? 8'hFF : 8'h01) : 8'h00;
    
    // Select between stochastic and deterministic modes
    always @(*) begin
        synapse_output = stoch_det_mode_select ? stochastic_output : deterministic_output;
    end

endmodule
