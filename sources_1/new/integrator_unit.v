module integrator_unit (
    input wire clk,
    input wire rst,
    input wire [7:0] leak_input,
    input wire [7:0] synapse_input,
    input wire [1:0] mode_select,
    input wire read_vj,
    input wire write_vj,
    input wire [7:0] write_membrane_value,
    input wire spike_detected,         // New input to indicate spike
    input wire [7:0] reset_value,      // New input for reset value
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
            membrane_value <= reset_value;
            integrator_output <= reset_value;
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
