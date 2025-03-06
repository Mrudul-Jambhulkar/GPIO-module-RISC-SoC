`timescale 1ns/1ps

module tb_gpio();
    // Clock and Reset
    reg clk = 0;
    reg rst_n;
    
    // AXI Lite Interface Signals
    reg         cfg_awvalid;
    reg  [31:0] cfg_awaddr;
    reg         cfg_wvalid;
    reg  [31:0] cfg_wdata;
    reg  [3:0]  cfg_wstrb;
    reg         cfg_bready;
    reg         cfg_arvalid;
    reg  [31:0] cfg_araddr;
    reg         cfg_rready;
    
    wire        cfg_awready;
    wire        cfg_wready;
    wire        cfg_bvalid;
    wire [1:0]  cfg_bresp;
    wire        cfg_arready;
    wire        cfg_rvalid;
    wire [31:0] cfg_rdata;
    wire [1:0]  cfg_rresp;
    
    // GPIO Signals
    reg  [31:0] gpio_input;
    wire [31:0] gpio_output;
    wire [31:0] gpio_output_enable;
    wire        intr;

    // Device Under Test
    gpio dut (
        .clk_i(clk),
        .rst_i(~rst_n),
        .cfg_awvalid_i(cfg_awvalid),
        .cfg_awaddr_i(cfg_awaddr),
        .cfg_wvalid_i(cfg_wvalid),
        .cfg_wdata_i(cfg_wdata),
        .cfg_wstrb_i(cfg_wstrb),
        .cfg_bready_i(cfg_bready),
        .cfg_arvalid_i(cfg_arvalid),
        .cfg_araddr_i(cfg_araddr),
        .cfg_rready_i(cfg_rready),
        .gpio_input_i(gpio_input),
        .cfg_awready_o(cfg_awready),
        .cfg_wready_o(cfg_wready),
        .cfg_bvalid_o(cfg_bvalid),
        .cfg_bresp_o(cfg_bresp),
        .cfg_arready_o(cfg_arready),
        .cfg_rvalid_o(cfg_rvalid),
        .cfg_rdata_o(cfg_rdata),
        .cfg_rresp_o(cfg_rresp),
        .gpio_output_o(gpio_output),
        .gpio_output_enable_o(gpio_output_enable),
        .intr_o(intr)
    );

    // Clock Generation
    always #10 clk = ~clk;

    // AXI Write Task
    task axi_write;
        input [31:0] address;
        input [31:0] data;
        begin
            @(posedge clk);
            cfg_awvalid <= 1'b1;
            cfg_awaddr  <= address;
            cfg_wvalid  <= 1'b1;
            cfg_wdata   <= data;
            cfg_wstrb   <= 4'hF;
            
            wait (cfg_awready && cfg_wready);
            @(posedge clk);
            cfg_awvalid <= 1'b0;
            cfg_wvalid  <= 1'b0;
            
            cfg_bready <= 1'b1;
            wait (cfg_bvalid);
            @(posedge clk);
            cfg_bready <= 1'b0;
        end
    endtask

    // AXI Read Task
    task axi_read;
        input [31:0] address;
        begin
            @(posedge clk);
            cfg_arvalid <= 1'b1;
            cfg_araddr  <= address;
            
            wait (cfg_arready);
            @(posedge clk);
            cfg_arvalid <= 1'b0;
            
            cfg_rready <= 1'b1;
            wait (cfg_rvalid);
            @(posedge clk);
            cfg_rready <= 1'b0;
        end
    endtask

    initial begin
        // Initialize Signals
        clk = 0;
        rst_n = 0;
        cfg_awvalid = 0;
        cfg_wvalid = 0;
        cfg_bready = 0;
        cfg_arvalid = 0;
        cfg_rready = 0;
        gpio_input = 32'h0;
        
        // Reset Sequence
        #20;
        rst_n = 1;
        #100;
        
        gpio_input = 32'h5555_5555;
  
        axi_read(32'h04);   // Read inputs
        
        axi_write(32'h00, 32'hFFFF_0000);  // Set all as outputs
        
        axi_write(32'h08, 32'h0000_FFFF);   // Write the output register value  (0000_FFFF)
        
        axi_write(32'h0C, 32'hFFFF_FFFF);   // Set the SET bits (FFFF_FFFF)
        
        axi_write(32'h10, 32'h3333_3333);   // Set the CLR bits (CCCC_CCCC)
        
        gpio_input = 32'h6666_6666;
        
        axi_read(32'h04);   // Read inputs
       
        axi_read(32'h00);   // Reading the direction register
        
        axi_write(32'h08, 32'h0000_0000);   // Write the output register value  (0000_0000)
        
        axi_write(32'h0C, 32'h0000_0001);   // Set the SET bits (0000_0001)
        
        axi_write(32'h0C, 32'hFF00_0011);   // Set the SET bits (FF00_0011)
        
        axi_write(32'h10, 32'h0000_0001);   // Set the CLR bits (FF00_0010)
        
        // iNTERRUPTS
        axi_write(32'h1C, 32'hFFFF_FFFF);   // ClR interrupt
        
        gpio_input = 32'h0;
        
        axi_read(32'h20);
        
        axi_write(32'h24, 32'h1);  // Active High
        
        //axi_read(32'h20);
        
        axi_write(32'h28, 32'h0);   // Mode
        
        //axi_read(32'h20);
        
        axi_write(32'h14,32'h1);    // Mask register
        
        //axi_read(32'h20);
        
        #40;
        
        gpio_input = 32'h1;
        
        #40;
        
        //axi_read(32'h20);
        
        //gpio_input = 32'h0;
        
        #40;
        
       axi_write(32'h1C, 32'h1);   // ClR interrupt
        
        
        

        #1000;
        
    
        
        $display("All tests completed");
        $finish;
    end
endmodule
