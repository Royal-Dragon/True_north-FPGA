`timescale 1ns / 1ps

module object_detection_system_tb;

    reg clk;
    reg rst;
    reg [7:0] pixel_data;

    wire object_detected;

    object_detection_system uut (
        .clk(clk),
        .rst(rst),
        .pixel_data(pixel_data),
        .object_detected(object_detected)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // Generate a clock with a period of 10 time units (100MHz)
    end

    initial begin
        $display("Starting simulation...");
        
        rst = 1;
        pixel_data = 8'h00;

        #20 rst = 0;

        #20 pixel_data = 8'h10;
        #20 pixel_data = 8'h20;
        
        #20 pixel_data = 8'h80; 
        #20 pixel_data = 8'h90;

        #20 pixel_data = 8'h40;
        #20 pixel_data = 8'hFF;

        #100 $display("Simulation completed.");
        $finish;
    end

    initial begin
        $monitor("Time=%0t | Pixel Data=%h | Object Detected=%b", 
                 $time, pixel_data, object_detected);
    end

endmodule
