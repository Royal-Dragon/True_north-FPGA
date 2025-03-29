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
