module core_sram (
    input wire clk,
    input wire rst,
    
    // Control signals
    input wire read_request,
    input wire write_request,
    input wire [7:0] addr,         // 8-bit address for 256 neurons
    
    // Data signals
    input wire [409:0] write_data,  // 410 bits per neuron
    output reg [409:0] read_data,
    
    // Status signals
    output reg ready,
    output reg error
);

    // Memory array: 256 rows x 410 columns
    // Each row stores data for one neuron:
    // - 256 bits: synaptic connections
    // - 124 bits: membrane potential and parameters
    // - 26 bits: spike destination information
    // - 4 bits: spike delivery tick
    reg [409:0] memory [0:255];
    
    // Redundancy management (simplified)
    reg [9:0] redundant_columns;
    reg [3:0] redundant_rows;
    
    // Operation timing
    reg [2:0] op_counter;
    localparam READ_CYCLES = 3'd2;
    localparam WRITE_CYCLES = 3'd3;
    
    // State machine
    localparam IDLE = 2'b00;
    localparam READING = 2'b01;
    localparam WRITING = 2'b10;
    localparam ERROR_STATE = 2'b11;
    reg [1:0] state;
    
    // Initialize SRAM
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            memory[i] = 410'b0;
        ready = 1'b1;
        error = 1'b0;
        state = IDLE;
        op_counter = 3'b0;
        redundant_columns = 10'b0;
        redundant_rows = 4'b0;
    end
    
    // SRAM operation state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            op_counter <= 3'b0;
            ready <= 1'b1;
            error <= 1'b0;
            read_data <= 410'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (read_request && write_request) begin
                        // Can't read and write simultaneously
                        state <= ERROR_STATE;
                        error <= 1'b1;
                        ready <= 1'b0;
                    end else if (read_request) begin
                        state <= READING;
                        ready <= 1'b0;
                        op_counter <= 3'b0;
                    end else if (write_request) begin
                        state <= WRITING;
                        ready <= 1'b0;
                        op_counter <= 3'b0;
                    end
                end
                
                READING: begin
                    if (op_counter < READ_CYCLES) begin
                        op_counter <= op_counter + 1'b1;
                    end else begin
                        // Check if address is in valid range (includes redundant rows)
                        if (addr < (256 + redundant_rows)) begin
                            read_data <= memory[addr];
                            state <= IDLE;
                            ready <= 1'b1;
                        end else begin
                            state <= ERROR_STATE;
                            error <= 1'b1;
                        end
                    end
                end
                
                WRITING: begin
                    if (op_counter < WRITE_CYCLES) begin
                        op_counter <= op_counter + 1'b1;
                    end else begin
                        // Check if address is in valid range
                        if (addr < (256 + redundant_rows)) begin
                            memory[addr] <= write_data;
                            state <= IDLE;
                            ready <= 1'b1;
                        end else begin
                            state <= ERROR_STATE;
                            error <= 1'b1;
                        end
                    end
                end
                
                ERROR_STATE: begin
                    // Stay in error state until reset
                    error <= 1'b1;
                    ready <= 1'b0;
                end
            endcase
        end
    end
endmodule
