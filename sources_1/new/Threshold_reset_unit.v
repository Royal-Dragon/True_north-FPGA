module threshold_reset_unit (
    input wire clk,
    input wire rst,
    input wire [7:0] membrane_potential,
    input wire [1:0] pos_neg_thresholds,
    input wire mask,
    input wire [7:0] v_reset,
    output wire threshold_output,
    output reg [7:0] reset_membrane_potential
);

    // Define threshold values
    wire [7:0] pos_threshold = 8'h80; // Example positive threshold
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
    
    // Apply mask if needed
    assign threshold_output = mask ? (threshold_result & mask) : threshold_result;
    
    // Reset logic - update membrane potential when threshold is crossed
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reset_membrane_potential <= 8'h00;
        end else if (threshold_output) begin
            reset_membrane_potential <= v_reset; // Reset to v_reset when spike occurs
        end else begin
            reset_membrane_potential <= membrane_potential; // Pass through unchanged
        end
    end

endmodule
