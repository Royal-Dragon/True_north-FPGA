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
