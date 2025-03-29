`timescale 1ns / 1ps

module object_detection_system (
    input wire clk,
    input wire rst,
    input wire [7:0] pixel_data, // Input pixel data (grayscale)
    output wire object_detected  // Output flag for detected object
);

    // Parameters
    parameter NUM_NEURONS = 16; // Number of neurons in the array

    // Internal signals
    wire [NUM_NEURONS-1:0] spike_signals; // Packed array for spike signals
    reg [NUM_NEURONS-1:0] spike_accumulator; // Packed array for accumulated spikes

    // Instantiate neuron blocks
    genvar i;
    generate
        for (i = 0; i < NUM_NEURONS; i = i + 1) begin : neuron_array
            neuron_block uut (
                .clk(clk),
                .rst(rst),
                .mode_select(2'b00),           // Normal mode
                .read_vj(1'b0),               // Single-bit signal
                .write_vj(1'b0),              // Single-bit signal
                .sign_select(1'b0),           // Single-bit signal
                .synaptic_weights(4'h8),      // Example weight
                .stoch_det_mode_select(1'b0), // Single-bit signal
                .pos_neg_thresholds(2'b01),   // Positive threshold only
                .mask(1'b0),                  // Single-bit signal
                .v_reset(8'h00),              // Reset value
                .leak_weight(8'hF0),          // Leak weight
                .neuron_instruction(pixel_data), // Pixel data as input
                .write_membrane_value(8'h00),
                .random_number(8'h00),
                .spike_transmit(spike_signals[i]),  // Spike signal output
                .membrane_potential()         // Membrane potential not used here
            );
        end
    endgenerate

    // Spike accumulation logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            spike_accumulator <= {NUM_NEURONS{1'b0}};  // Reset all accumulator entries to 0
        end else begin
            spike_accumulator <= spike_accumulator | spike_signals; // Combine spikes from all neurons
        end
    end

    // Object detection logic (simple thresholding)
    assign object_detected = |spike_accumulator;   // Detect object if any neuron spikes

endmodule
