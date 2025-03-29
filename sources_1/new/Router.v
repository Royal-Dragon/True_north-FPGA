module router (
    input wire clk,              // System clock
    input wire rst,              // Reset
    
    // Local core interface
    input wire [25:0] local_in_data,    // Spike packet from local core
    input wire local_in_valid,          // Valid signal for local input
    output reg local_in_ready,          // Ready signal for local input
    output reg [13:0] local_out_data,   // Spike packet to local core scheduler
    output reg local_out_valid,         // Valid signal for local output
    input wire local_out_ready,         // Ready signal from scheduler
    
    // North port interface
    input wire [25:0] north_in_data,    // Spike packet from north
    input wire north_in_valid,          // Valid signal for north input
    output reg north_in_ready,          // Ready signal for north input
    output reg [25:0] north_out_data,   // Spike packet to north
    output reg north_out_valid,         // Valid signal for north output
    input wire north_out_ready,         // Ready signal from north neighbor
    
    // South port interface
    input wire [25:0] south_in_data,
    input wire south_in_valid,
    output reg south_in_ready,
    output reg [25:0] south_out_data,
    output reg south_out_valid,
    input wire south_out_ready,
    
    // East port interface
    input wire [25:0] east_in_data,
    input wire east_in_valid,
    output reg east_in_ready,
    output reg [25:0] east_out_data,
    output reg east_out_valid,
    input wire east_out_ready,
    
    // West port interface
    input wire [25:0] west_in_data,
    input wire west_in_valid,
    output reg west_in_ready,
    output reg [25:0] west_out_data,
    output reg west_out_valid,
    input wire west_out_ready,
    
    // Error and status
    output reg timeout_error,
    output reg [2:0] error_source
);

    // Packet format: {dx[8:0], dy[8:0], axon_id[7:0], delivery_tick[3:0], debug[1:0]}
    // Extract routing fields for all input ports
    wire [8:0] local_dx = local_in_data[25:17];
    wire [8:0] local_dy = local_in_data[16:8];
    wire [7:0] local_axon_id = local_in_data[7:0];
    
    wire [8:0] north_dx = north_in_data[25:17];
    wire [8:0] north_dy = north_in_data[16:8];
    wire [7:0] north_axon_id = north_in_data[7:0];
    
    wire [8:0] south_dx = south_in_data[25:17];
    wire [8:0] south_dy = south_in_data[16:8];
    wire [7:0] south_axon_id = south_in_data[7:0];
    
    wire [8:0] east_dx = east_in_data[25:17];
    wire [8:0] east_dy = east_in_data[16:8];
    wire [7:0] east_axon_id = east_in_data[7:0];
    
    wire [8:0] west_dx = west_in_data[25:17];
    wire [8:0] west_dy = west_in_data[16:8];
    wire [7:0] west_axon_id = west_in_data[7:0];
    
    // Determine routing direction for each input port
    // Local input routing
    wire local_to_east = local_dx > 0;
    wire local_to_west = local_dx < 0;
    wire local_to_north = local_dx == 0 && local_dy > 0;
    wire local_to_south = local_dx == 0 && local_dy < 0;
    wire local_to_local = local_dx == 0 && local_dy == 0;
    
    // North input routing
    wire north_to_east = north_dx > 0;
    wire north_to_west = north_dx < 0;
    wire north_to_north = north_dx == 0 && north_dy > 0;
    wire north_to_south = north_dx == 0 && north_dy < 0;
    wire north_to_local = north_dx == 0 && north_dy == 0;
    
    // South input routing
    wire south_to_east = south_dx > 0;
    wire south_to_west = south_dx < 0;
    wire south_to_north = south_dx == 0 && south_dy > 0;
    wire south_to_south = south_dx == 0 && south_dy < 0;
    wire south_to_local = south_dx == 0 && south_dy == 0;
    
    // East input routing
    wire east_to_east = east_dx > 0;
    wire east_to_west = east_dx < 0;
    wire east_to_north = east_dx == 0 && east_dy > 0;
    wire east_to_south = east_dx == 0 && east_dy < 0;
    wire east_to_local = east_dx == 0 && east_dy == 0;
    
    // West input routing
    wire west_to_east = west_dx > 0;
    wire west_to_west = west_dx < 0;
    wire west_to_north = west_dx == 0 && west_dy > 0;
    wire west_to_south = west_dx == 0 && west_dy < 0;
    wire west_to_local = west_dx == 0 && west_dy == 0;
    
    // State machine for arbitration
    localparam IDLE = 3'b000;
    localparam ROUTE_LOCAL = 3'b001;
    localparam ROUTE_NORTH = 3'b010;
    localparam ROUTE_SOUTH = 3'b011;
    localparam ROUTE_EAST = 3'b100;
    localparam ROUTE_WEST = 3'b101;
    
    // Output port state machines
    reg [2:0] local_out_state;
    reg [2:0] north_out_state;
    reg [2:0] south_out_state;
    reg [2:0] east_out_state;
    reg [2:0] west_out_state;
    
    // Input and output buffers (small FIFOs)
    // For this implementation, we'll use a single register level buffer
    reg [25:0] local_in_buffer;
    reg local_in_buffer_valid;
    reg [25:0] north_in_buffer;
    reg north_in_buffer_valid;
    reg [25:0] south_in_buffer;
    reg south_in_buffer_valid;
    reg [25:0] east_in_buffer;
    reg east_in_buffer_valid;
    reg [25:0] west_in_buffer;
    reg west_in_buffer_valid;
    
    // Timeout detection (in clock cycles)
    localparam TIMEOUT_THRESHOLD = 16'hFFFF; // 65535 cycles
    reg [15:0] timeout_counter;
    
    // Packet modification for forwarding (for all input ports)
    // Local input
    wire [25:0] local_decr_dx_packet = {local_in_data[25:17] - 9'd1, local_in_data[16:0]};
    wire [25:0] local_incr_dx_packet = {local_in_data[25:17] + 9'd1, local_in_data[16:0]};
    wire [25:0] local_decr_dy_packet = {9'd0, local_in_data[16:8] - 9'd1, local_in_data[7:0]};
    wire [25:0] local_incr_dy_packet = {9'd0, local_in_data[16:8] + 9'd1, local_in_data[7:0]};
    wire [13:0] local_delivery_packet = {local_in_data[7:0], local_in_data[3:0], 2'b00}; // axon_id, delivery_tick, debug
    
    // North input
    wire [25:0] north_decr_dx_packet = {north_in_data[25:17] - 9'd1, north_in_data[16:0]};
    wire [25:0] north_incr_dx_packet = {north_in_data[25:17] + 9'd1, north_in_data[16:0]};
    wire [25:0] north_decr_dy_packet = {9'd0, north_in_data[16:8] - 9'd1, north_in_data[7:0]};
    wire [25:0] north_incr_dy_packet = {9'd0, north_in_data[16:8] + 9'd1, north_in_data[7:0]};
    wire [13:0] north_delivery_packet = {north_in_data[7:0], north_in_data[3:0], 2'b00};
    
    // South input
    wire [25:0] south_decr_dx_packet = {south_in_data[25:17] - 9'd1, south_in_data[16:0]};
    wire [25:0] south_incr_dx_packet = {south_in_data[25:17] + 9'd1, south_in_data[16:0]};
    wire [25:0] south_decr_dy_packet = {9'd0, south_in_data[16:8] - 9'd1, south_in_data[7:0]};
    wire [25:0] south_incr_dy_packet = {9'd0, south_in_data[16:8] + 9'd1, south_in_data[7:0]};
    wire [13:0] south_delivery_packet = {south_in_data[7:0], south_in_data[3:0], 2'b00};
    
    // East input
    wire [25:0] east_decr_dx_packet = {east_in_data[25:17] - 9'd1, east_in_data[16:0]};
    wire [25:0] east_incr_dx_packet = {east_in_data[25:17] + 9'd1, east_in_data[16:0]};
    wire [25:0] east_decr_dy_packet = {9'd0, east_in_data[16:8] - 9'd1, east_in_data[7:0]};
    wire [25:0] east_incr_dy_packet = {9'd0, east_in_data[16:8] + 9'd1, east_in_data[7:0]};
    wire [13:0] east_delivery_packet = {east_in_data[7:0], east_in_data[3:0], 2'b00};
    
    // West input
    wire [25:0] west_decr_dx_packet = {west_in_data[25:17] - 9'd1, west_in_data[16:0]};
    wire [25:0] west_incr_dx_packet = {west_in_data[25:17] + 9'd1, west_in_data[16:0]};
    wire [25:0] west_decr_dy_packet = {9'd0, west_in_data[16:8] - 9'd1, west_in_data[7:0]};
    wire [25:0] west_incr_dy_packet = {9'd0, west_in_data[16:8] + 9'd1, west_in_data[7:0]};
    wire [13:0] west_delivery_packet = {west_in_data[7:0], west_in_data[3:0], 2'b00};
    
    // Input port arbitration
    reg [2:0] arbiter_state;
    reg [2:0] next_arbiter_state;
    
    // Initialize all states to IDLE
    initial begin
        arbiter_state = IDLE;
        local_out_state = IDLE;
        north_out_state = IDLE;
        south_out_state = IDLE;
        east_out_state = IDLE;
        west_out_state = IDLE;
        timeout_error = 1'b0;
        error_source = 3'b000;
        timeout_counter = 16'b0;
    end
    
    // Buffer management logic for input ports
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            local_in_buffer_valid <= 1'b0;
            north_in_buffer_valid <= 1'b0;
            south_in_buffer_valid <= 1'b0;
            east_in_buffer_valid <= 1'b0;
            west_in_buffer_valid <= 1'b0;
        end else begin
            // Local input buffer
            if (local_in_valid && local_in_ready) begin
                local_in_buffer <= local_in_data;
                local_in_buffer_valid <= 1'b1;
            end else if (arbiter_state == ROUTE_LOCAL && local_in_ready) begin
                local_in_buffer_valid <= 1'b0;
            end
            
            // North input buffer
            if (north_in_valid && north_in_ready) begin
                north_in_buffer <= north_in_data;
                north_in_buffer_valid <= 1'b1;
            end else if (arbiter_state == ROUTE_NORTH && north_in_ready) begin
                north_in_buffer_valid <= 1'b0;
            end
            
            // South input buffer
            if (south_in_valid && south_in_ready) begin
                south_in_buffer <= south_in_data;
                south_in_buffer_valid <= 1'b1;
            end else if (arbiter_state == ROUTE_SOUTH && south_in_ready) begin
                south_in_buffer_valid <= 1'b0;
            end
            
            // East input buffer
            if (east_in_valid && east_in_ready) begin
                east_in_buffer <= east_in_data;
                east_in_buffer_valid <= 1'b1;
            end else if (arbiter_state == ROUTE_EAST && east_in_ready) begin
                east_in_buffer_valid <= 1'b0;
            end
            
            // West input buffer
            if (west_in_valid && west_in_ready) begin
                west_in_buffer <= west_in_data;
                west_in_buffer_valid <= 1'b1;
            end else if (arbiter_state == ROUTE_WEST && west_in_ready) begin
                west_in_buffer_valid <= 1'b0;
            end
        end
    end
    
    // Main router state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            arbiter_state <= IDLE;
            local_out_state <= IDLE;
            north_out_state <= IDLE;
            south_out_state <= IDLE;
            east_out_state <= IDLE;
            west_out_state <= IDLE;
            
            local_in_ready <= 1'b0;
            north_in_ready <= 1'b0;
            south_in_ready <= 1'b0;
            east_in_ready <= 1'b0;
            west_in_ready <= 1'b0;
            
            local_out_valid <= 1'b0;
            north_out_valid <= 1'b0;
            south_out_valid <= 1'b0;
            east_out_valid <= 1'b0;
            west_out_valid <= 1'b0;
            
            local_out_data <= 14'b0;
            north_out_data <= 26'b0;
            south_out_data <= 26'b0;
            east_out_data <= 26'b0;
            west_out_data <= 26'b0;
            
            timeout_error <= 1'b0;
            error_source <= 3'b000;
            timeout_counter <= 16'b0;
        end else begin
            // Default ready signals for inputs
            local_in_ready <= !local_in_buffer_valid;
            north_in_ready <= !north_in_buffer_valid;
            south_in_ready <= !south_in_buffer_valid;
            east_in_ready <= !east_in_buffer_valid;
            west_in_ready <= !west_in_buffer_valid;
            
            // Timeout counter logic
            if (arbiter_state != IDLE && timeout_counter < TIMEOUT_THRESHOLD) begin
                timeout_counter <= timeout_counter + 1'b1;
            end else if (arbiter_state == IDLE) begin
                timeout_counter <= 16'b0;
                timeout_error <= 1'b0;
            end
            
            // Timeout detection
            if (timeout_counter >= TIMEOUT_THRESHOLD) begin
                timeout_error <= 1'b1;
                error_source <= arbiter_state;
                timeout_counter <= 16'b0;
                arbiter_state <= IDLE;
            end else begin
                // Arbiter state machine
                case (arbiter_state)
                    IDLE: begin
                        // Priority: Local, North, South, East, West
                        if (local_in_buffer_valid) begin
                            arbiter_state <= ROUTE_LOCAL;
                        end else if (north_in_buffer_valid) begin
                            arbiter_state <= ROUTE_NORTH;
                        end else if (south_in_buffer_valid) begin
                            arbiter_state <= ROUTE_SOUTH;
                        end else if (east_in_buffer_valid) begin
                            arbiter_state <= ROUTE_EAST;
                        end else if (west_in_buffer_valid) begin
                            arbiter_state <= ROUTE_WEST;
                        end
                    end
                    
                    ROUTE_LOCAL: begin
                        // Handle local input
                        if (local_to_local && local_out_state == IDLE) begin
                            local_out_data <= local_delivery_packet;
                            local_out_valid <= 1'b1;
                            local_out_state <= ROUTE_LOCAL;
                        end else if (local_to_east && east_out_state == IDLE) begin
                            east_out_data <= local_decr_dx_packet;
                            east_out_valid <= 1'b1;
                            east_out_state <= ROUTE_LOCAL;
                        end else if (local_to_west && west_out_state == IDLE) begin
                            west_out_data <= local_incr_dx_packet;
                            west_out_valid <= 1'b1;
                            west_out_state <= ROUTE_LOCAL;
                        end else if (local_to_north && north_out_state == IDLE) begin
                            north_out_data <= local_decr_dy_packet;
                            north_out_valid <= 1'b1;
                            north_out_state <= ROUTE_LOCAL;
                        end else if (local_to_south && south_out_state == IDLE) begin
                            south_out_data <= local_incr_dy_packet;
                            south_out_valid <= 1'b1;
                            south_out_state <= ROUTE_LOCAL;
                        end
                        
                        // Once routing is complete, acknowledge and go back to IDLE
                        if ((local_to_local && local_out_state == ROUTE_LOCAL && local_out_ready) ||
                            (local_to_east && east_out_state == ROUTE_LOCAL && east_out_ready) ||
                            (local_to_west && west_out_state == ROUTE_LOCAL && west_out_ready) ||
                            (local_to_north && north_out_state == ROUTE_LOCAL && north_out_ready) ||
                            (local_to_south && south_out_state == ROUTE_LOCAL && south_out_ready)) begin
                            local_in_ready <= 1'b1;
                            arbiter_state <= IDLE;
                        end
                    end
                    
                    ROUTE_NORTH: begin
                        // Handle north input
                        if (north_to_local && local_out_state == IDLE) begin
                            local_out_data <= north_delivery_packet;
                            local_out_valid <= 1'b1;
                            local_out_state <= ROUTE_NORTH;
                        end else if (north_to_east && east_out_state == IDLE) begin
                            east_out_data <= north_decr_dx_packet;
                            east_out_valid <= 1'b1;
                            east_out_state <= ROUTE_NORTH;
                        end else if (north_to_west && west_out_state == IDLE) begin
                            west_out_data <= north_incr_dx_packet;
                            west_out_valid <= 1'b1;
                            west_out_state <= ROUTE_NORTH;
                        end else if (north_to_north && north_out_state == IDLE) begin
                            north_out_data <= north_decr_dy_packet;
                            north_out_valid <= 1'b1;
                            north_out_state <= ROUTE_NORTH;
                        end else if (north_to_south && south_out_state == IDLE) begin
                            south_out_data <= north_incr_dy_packet;
                            south_out_valid <= 1'b1;
                            south_out_state <= ROUTE_NORTH;
                        end
                        
                        // Once routing is complete, acknowledge and go back to IDLE
                        if ((north_to_local && local_out_state == ROUTE_NORTH && local_out_ready) ||
                            (north_to_east && east_out_state == ROUTE_NORTH && east_out_ready) ||
                            (north_to_west && west_out_state == ROUTE_NORTH && west_out_ready) ||
                            (north_to_north && north_out_state == ROUTE_NORTH && north_out_ready) ||
                            (north_to_south && south_out_state == ROUTE_NORTH && south_out_ready)) begin
                            north_in_ready <= 1'b1;
                            arbiter_state <= IDLE;
                        end
                    end
                    
                    ROUTE_SOUTH: begin
                        // Handle south input
                        if (south_to_local && local_out_state == IDLE) begin
                            local_out_data <= south_delivery_packet;
                            local_out_valid <= 1'b1;
                            local_out_state <= ROUTE_SOUTH;
                        end else if (south_to_east && east_out_state == IDLE) begin
                            east_out_data <= south_decr_dx_packet;
                            east_out_valid <= 1'b1;
                            east_out_state <= ROUTE_SOUTH;
                        end else if (south_to_west && west_out_state == IDLE) begin
                            west_out_data <= south_incr_dx_packet;
                            west_out_valid <= 1'b1;
                            west_out_state <= ROUTE_SOUTH;
                        end else if (south_to_north && north_out_state == IDLE) begin
                            north_out_data <= south_decr_dy_packet;
                            north_out_valid <= 1'b1;
                            north_out_state <= ROUTE_SOUTH;
                        end else if (south_to_south && south_out_state == IDLE) begin
                            south_out_data <= south_incr_dy_packet;
                            south_out_valid <= 1'b1;
                            south_out_state <= ROUTE_SOUTH;
                        end
                        
                        // Once routing is complete, acknowledge and go back to IDLE
                        if ((south_to_local && local_out_state == ROUTE_SOUTH && local_out_ready) ||
                            (south_to_east && east_out_state == ROUTE_SOUTH && east_out_ready) ||
                            (south_to_west && west_out_state == ROUTE_SOUTH && west_out_ready) ||
                            (south_to_north && north_out_state == ROUTE_SOUTH && north_out_ready) ||
                            (south_to_south && south_out_state == ROUTE_SOUTH && south_out_ready)) begin
                            south_in_ready <= 1'b1;
                            arbiter_state <= IDLE;
                        end
                    end
                    
                    ROUTE_EAST: begin
                        // Handle east input
                        if (east_to_local && local_out_state == IDLE) begin
                            local_out_data <= east_delivery_packet;
                            local_out_valid <= 1'b1;
                            local_out_state <= ROUTE_EAST;
                        end else if (east_to_east && east_out_state == IDLE) begin
                            east_out_data <= east_decr_dx_packet;
                            east_out_valid <= 1'b1;
                            east_out_state <= ROUTE_EAST;
                        end else if (east_to_west && west_out_state == IDLE) begin
                            west_out_data <= east_incr_dx_packet;
                            west_out_valid <= 1'b1;
                            west_out_state <= ROUTE_EAST;
                        end else if (east_to_north && north_out_state == IDLE) begin
                            north_out_data <= east_decr_dy_packet;
                            north_out_valid <= 1'b1;
                            north_out_state <= ROUTE_EAST;
                        end else if (east_to_south && south_out_state == IDLE) begin
                            south_out_data <= east_incr_dy_packet;
                            south_out_valid <= 1'b1;
                            south_out_state <= ROUTE_EAST;
                        end
                        
                        // Once routing is complete, acknowledge and go back to IDLE
                        if ((east_to_local && local_out_state == ROUTE_EAST && local_out_ready) ||
                            (east_to_east && east_out_state == ROUTE_EAST && east_out_ready) ||
                            (east_to_west && west_out_state == ROUTE_EAST && west_out_ready) ||
                            (east_to_north && north_out_state == ROUTE_EAST && north_out_ready) ||
                            (east_to_south && south_out_state == ROUTE_EAST && south_out_ready)) begin
                            east_in_ready <= 1'b1;
                            arbiter_state <= IDLE;
                        end
                    end
                    
                    ROUTE_WEST: begin
                        // Handle west input
                        if (west_to_local && local_out_state == IDLE) begin
                            local_out_data <= west_delivery_packet;
                            local_out_valid <= 1'b1;
                            local_out_state <= ROUTE_WEST;
                        end else if (west_to_east && east_out_state == IDLE) begin
                            east_out_data <= west_decr_dx_packet;
                            east_out_valid <= 1'b1;
                            east_out_state <= ROUTE_WEST;
                        end else if (west_to_west && west_out_state == IDLE) begin
                            west_out_data <= west_incr_dx_packet;
                            west_out_valid <= 1'b1;
                            west_out_state <= ROUTE_WEST;
                        end else if (west_to_north && north_out_state == IDLE) begin
                            north_out_data <= west_decr_dy_packet;
                            north_out_valid <= 1'b1;
                            north_out_state <= ROUTE_WEST;
                        end else if (west_to_south && south_out_state == IDLE) begin
                            south_out_data <= west_incr_dy_packet;
                            south_out_valid <= 1'b1;
                            south_out_state <= ROUTE_WEST;
                        end
                        
                        // Once routing is complete, acknowledge and go back to IDLE
                        if ((west_to_local && local_out_state == ROUTE_WEST && local_out_ready) ||
                            (west_to_east && east_out_state == ROUTE_WEST && east_out_ready) ||
                            (west_to_west && west_out_state == ROUTE_WEST && west_out_ready) ||
                            (west_to_north && north_out_state == ROUTE_WEST && north_out_ready) ||
                            (west_to_south && south_out_state == ROUTE_WEST && south_out_ready)) begin
                            west_in_ready <= 1'b1;
                            arbiter_state <= IDLE;
                        end
                    end
                    
                    default: arbiter_state <= IDLE;
                endcase
            end
            
            // Handle output port completion
            if (local_out_state != IDLE && local_out_ready) begin
                local_out_valid <= 1'b0;
                local_out_state <= IDLE;
            end
            
            if (north_out_state != IDLE && north_out_ready) begin
                north_out_valid <= 1'b0;
                north_out_state <= IDLE;
            end
            
            if (south_out_state != IDLE && south_out_ready) begin
                south_out_valid <= 1'b0;
                south_out_state <= IDLE;
            end
            
            if (east_out_state != IDLE && east_out_ready) begin
                east_out_valid <= 1'b0;
                east_out_state <= IDLE;
            end
            
            if (west_out_state != IDLE && west_out_ready) begin
                west_out_valid <= 1'b0;
                west_out_state <= IDLE;
            end
        end
    end

endmodule
