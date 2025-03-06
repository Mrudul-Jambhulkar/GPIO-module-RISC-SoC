
`timescale 1ns/1ps

// GPIO Definitions
`define GPIO_DIRECTION                    8'h00
`define GPIO_DIRECTION_OUTPUT_DEFAULT     0
`define GPIO_DIRECTION_OUTPUT_B           0
`define GPIO_DIRECTION_OUTPUT_T           31
`define GPIO_DIRECTION_OUTPUT_W           32
`define GPIO_DIRECTION_OUTPUT_R           31:0

`define GPIO_INPUT                        8'h04
`define GPIO_INPUT_VALUE_DEFAULT          0
`define GPIO_INPUT_VALUE_B                0
`define GPIO_INPUT_VALUE_T                31
`define GPIO_INPUT_VALUE_W                32
`define GPIO_INPUT_VALUE_R                31:0

`define GPIO_OUTPUT                       8'h08
`define GPIO_OUTPUT_DATA_DEFAULT          0
`define GPIO_OUTPUT_DATA_B                0
`define GPIO_OUTPUT_DATA_T                31
`define GPIO_OUTPUT_DATA_W                32
`define GPIO_OUTPUT_DATA_R                31:0

`define GPIO_OUTPUT_SET                   8'h0C
`define GPIO_OUTPUT_SET_DATA_DEFAULT      0
`define GPIO_OUTPUT_SET_DATA_B            0
`define GPIO_OUTPUT_SET_DATA_T            31
`define GPIO_OUTPUT_SET_DATA_W            32
`define GPIO_OUTPUT_SET_DATA_R            31:0

`define GPIO_OUTPUT_CLR                   8'h10
`define GPIO_OUTPUT_CLR_DATA_DEFAULT      0
`define GPIO_OUTPUT_CLR_DATA_B            0
`define GPIO_OUTPUT_CLR_DATA_T            31
`define GPIO_OUTPUT_CLR_DATA_W            32
`define GPIO_OUTPUT_CLR_DATA_R            31:0

`define GPIO_INT_MASK                     8'h14
`define GPIO_INT_MASK_ENABLE_DEFAULT      0
`define GPIO_INT_MASK_ENABLE_B            0
`define GPIO_INT_MASK_ENABLE_T            31
`define GPIO_INT_MASK_ENABLE_W            32
`define GPIO_INT_MASK_ENABLE_R            31:0

`define GPIO_INT_SET                      8'h18
`define GPIO_INT_SET_SW_DEFAULT           0
`define GPIO_INT_SET_SW_IRQ_B             0
`define GPIO_INT_SET_SW_IRQ_T             31
`define GPIO_INT_SET_SW_IRQ_W             32
`define GPIO_INT_SET_SW_IRQ_R             31:0

`define GPIO_INT_CLR                      8'h1C
`define GPIO_INT_CLR_ACK_DEFAULT          0
`define GPIO_INT_CLR_ACK_B                0
`define GPIO_INT_CLR_ACK_T                31
`define GPIO_INT_CLR_ACK_W                32
`define GPIO_INT_CLR_ACK_R                31:0

`define GPIO_INT_STATUS                   8'h20
`define GPIO_INT_STATUS_RAW_DEFAULT       0
`define GPIO_INT_STATUS_RAW_B             0
`define GPIO_INT_STATUS_RAW_T             31
`define GPIO_INT_STATUS_RAW_W             32
`define GPIO_INT_STATUS_RAW_R             31:0

`define GPIO_INT_LEVEL                    8'h24
`define GPIO_INT_LEVEL_ACTIVE_HIGH_DEFAULT 0
`define GPIO_INT_LEVEL_ACTIVE_HIGH_B      0
`define GPIO_INT_LEVEL_ACTIVE_HIGH_T      31
`define GPIO_INT_LEVEL_ACTIVE_HIGH_W      32
`define GPIO_INT_LEVEL_ACTIVE_HIGH_R      31:0

`define GPIO_INT_MODE                     8'h28
`define GPIO_INT_MODE_EDGE_DEFAULT        0
`define GPIO_INT_MODE_EDGE_B              0
`define GPIO_INT_MODE_EDGE_T              31
`define GPIO_INT_MODE_EDGE_W              32
`define GPIO_INT_MODE_EDGE_R              31:0

// Main GPIO Module
module gpio
(
    // Inputs
     input          clk_i
    ,input          rst_i
    ,input          cfg_awvalid_i
    ,input  [31:0]  cfg_awaddr_i
    ,input          cfg_wvalid_i
    ,input  [31:0]  cfg_wdata_i
    ,input  [3:0]   cfg_wstrb_i
    ,input          cfg_bready_i
    ,input          cfg_arvalid_i
    ,input  [31:0]  cfg_araddr_i
    ,input          cfg_rready_i
    ,input  [31:0]  gpio_input_i

    // Outputs
    ,output reg        cfg_awready_o
    ,output reg        cfg_wready_o
    ,output reg        cfg_bvalid_o
    ,output reg [1:0]   cfg_bresp_o
    ,output reg        cfg_arready_o
    ,output reg        cfg_rvalid_o
    ,output  [31:0]  cfg_rdata_o
    ,output reg [1:0]   cfg_rresp_o
    ,output [31:0]  gpio_output_o
    ,output [31:0]  gpio_output_enable_o
    ,output         intr_o
);

// State definitions for AXI write FSM
localparam AXI_WRITE_IDLE = 2'd0;
localparam AXI_WRITE_DATA = 2'd1;
localparam AXI_WRITE_RESP = 2'd2;

// State definitions for AXI read FSM
localparam AXI_READ_IDLE = 2'd0;
localparam AXI_READ_DATA = 2'd1;

// FSM state registers
reg [1:0] write_state_q;
reg [1:0] read_state_q;

// Address capture registers
reg [31:0] write_addr_q;
reg [31:0] read_addr_q;

// Write data capture register
reg write_en_w;
reg read_en_w;

// FSM for write channel
// Write data capture register
reg [31:0] wr_data_q;

// FSM for write channel
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        write_state_q <= AXI_WRITE_IDLE;
        write_addr_q <= 32'b0;
        wr_data_q <= 32'b0;
        cfg_bresp_o   <= 2'b00;
    end 
    else begin
        case (write_state_q)
            AXI_WRITE_IDLE: begin
                // Both address and data are valid
				cfg_awready_o <= 1;
				cfg_wready_o  <= 1;
				cfg_bvalid_o  <= 0;
				write_en_w <= 0;
				cfg_bresp_o <= 2'b00;
                if (cfg_awvalid_i && cfg_wvalid_i) begin
				    write_en_w <= 1 ; 
                    write_state_q <= AXI_WRITE_RESP;
                    write_addr_q <= cfg_awaddr_i;
                    if (cfg_wready_o) begin
                        wr_data_q <= cfg_wdata_i;
                    end
                end
                // Only address is valid
                else if (cfg_awvalid_i) begin
                    write_state_q <= AXI_WRITE_DATA;
                    write_addr_q <= cfg_awaddr_i;
                end
            end

            AXI_WRITE_DATA: begin
                // Wait for write data
				cfg_awready_o <= 0;
				cfg_wready_o  <= 1;
				cfg_bvalid_o  <= 0;
				write_en_w <= 0;
				cfg_bresp_o <= 2'b00;
                if (cfg_wvalid_i && cfg_wready_o) begin
                    write_state_q <= AXI_WRITE_RESP;
                    wr_data_q <= cfg_wdata_i;
                end
            end

            AXI_WRITE_RESP: begin
                // Wait for write response to be accepted
				write_en_w <= 0;
				cfg_awready_o <= 0;
				cfg_wready_o  <= 0;
				cfg_bvalid_o  <= 1;
				cfg_bresp_o <= 2'b00;
                if (cfg_bready_i) begin
                    write_state_q <= AXI_WRITE_IDLE;
                end
            end

            default: write_state_q <= AXI_WRITE_IDLE;
        endcase
    end
end

// FSM for read channel
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        read_state_q <= AXI_READ_IDLE;
        read_addr_q <= 32'b0;
    end 
    else begin
        case (read_state_q)
            AXI_READ_IDLE: begin
                // Address is valid
				read_en_w  <= 0;
				cfg_arready_o <= 1;
				cfg_rvalid_o  <= 0 ;
                cfg_rresp_o   <= 2'b00;  // OKAY response
                if (cfg_arvalid_i) begin
				    read_en_w <= 1 ;
                    read_state_q <= AXI_READ_DATA;
                    read_addr_q <= cfg_araddr_i;
                end
            end

            AXI_READ_DATA: begin
                // Wait for read data to be accepted
				read_en_w <= 0 ;
				cfg_arready_o <= 0 ;
				cfg_rvalid_o  <= 1;
				cfg_rresp_o   = 2'b00;  // OKAY response
                if (cfg_rready_i) begin
                    read_state_q <= AXI_READ_IDLE;
                end
            end

            default: read_state_q <= AXI_READ_IDLE;
        endcase
    end
end

// AXI handshake signals
// assign cfg_awready_o = (write_state_q == AXI_WRITE_IDLE);
// assign cfg_wready_o  = (write_state_q == AXI_WRITE_IDLE) || (write_state_q == AXI_WRITE_DATA);
// assign cfg_bvalid_o  = (write_state_q == AXI_WRITE_RESP);
// assign cfg_bresp_o   = 2'b00;  // OKAY response

// assign cfg_arready_o = (read_state_q == AXI_READ_IDLE);
// assign cfg_rvalid_o  = (read_state_q == AXI_READ_DATA);
// assign cfg_rresp_o   = 2'b00;  // OKAY response

// Write and Read enable signals
// wire read_en_w  = (read_state_q == AXI_READ_IDLE) & cfg_arvalid_i;
// wire write_en_w = (write_state_q == AXI_WRITE_IDLE) & cfg_awvalid_i & cfg_wvalid_i;

// Direction Register
reg [31:0]  gpio_direction_reg;

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        gpio_direction_reg <= 32'd`GPIO_DIRECTION_OUTPUT_DEFAULT;
    end else if (write_en_w && (cfg_awaddr_i[7:0] == `GPIO_DIRECTION)) begin
        gpio_direction_reg <= cfg_wdata_i[`GPIO_DIRECTION_OUTPUT_R];
    end
end

// Input Register
reg [31:0]  gpio_input_reg;

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        gpio_input_reg <= 32'd`GPIO_INPUT_VALUE_DEFAULT;
    end else begin
        gpio_input_reg <= gpio_input_i;
    end
end


// Output Register (Stores the exact value given to the output register)
reg [31:0] gpio_output_reg;

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        gpio_output_reg <= 32'd`GPIO_OUTPUT_DATA_DEFAULT;
    end else if (write_en_w && (cfg_awaddr_i[7:0] == `GPIO_OUTPUT)) begin
        gpio_output_reg <= cfg_wdata_i[`GPIO_OUTPUT_DATA_R];
    end
end

// ---------------------------------------------------------------------------------------------------------------------------------------------------

// Interrupt Mask Control Register
reg gpio_int_mask_wr_q;

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        gpio_int_mask_wr_q <= 1'b0;
    end else if (write_en_w && (cfg_awaddr_i[7:0] == `GPIO_INT_MASK)) begin
        gpio_int_mask_wr_q <= 1'b1;
    end else begin
        gpio_int_mask_wr_q <= 1'b0;
    end
end

// Interrupt Mask Register
reg [31:0]  gpio_int_mask_reg;

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        gpio_int_mask_reg <= 32'd`GPIO_INT_MASK_ENABLE_DEFAULT;
    end else if (write_en_w && (cfg_awaddr_i[7:0] == `GPIO_INT_MASK)) begin
        gpio_int_mask_reg <= cfg_wdata_i[`GPIO_INT_MASK_ENABLE_R];
    end
end

// Interrupt Level Control Register
reg gpio_int_level_wr_q;

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        gpio_int_level_wr_q <= 1'b0;
    end else if (write_en_w && (cfg_awaddr_i[7:0] == `GPIO_INT_LEVEL)) begin
        gpio_int_level_wr_q <= 1'b1;
    end else begin
        gpio_int_level_wr_q <= 1'b0;
    end
end

// Interrupt Level Register
reg [31:0]  gpio_int_level_active_high_q;

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        gpio_int_level_active_high_q <= 32'd`GPIO_INT_LEVEL_ACTIVE_HIGH_DEFAULT;
    end else if (write_en_w && (cfg_awaddr_i[7:0] == `GPIO_INT_LEVEL)) begin
        gpio_int_level_active_high_q <= cfg_wdata_i[`GPIO_INT_LEVEL_ACTIVE_HIGH_R];
    end
end

// Interrupt Mode Control Register
reg gpio_int_mode_wr_q;

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        gpio_int_mode_wr_q <= 1'b0;
    end else if (write_en_w && (cfg_awaddr_i[7:0] == `GPIO_INT_MODE)) begin
        gpio_int_mode_wr_q <= 1'b1;
    end else begin
        gpio_int_mode_wr_q <= 1'b0;
    end
end

// Interrupt Mode Register
reg [31:0]  gpio_int_mode_edge_q;

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        gpio_int_mode_edge_q <= 32'd`GPIO_INT_MODE_EDGE_DEFAULT;
    end else if (write_en_w && (cfg_awaddr_i[7:0] == `GPIO_INT_MODE)) begin
        gpio_int_mode_edge_q <= cfg_wdata_i[`GPIO_INT_MODE_EDGE_R];
    end
end

// -------------------------------------------------------------------------------------------------------------------------------------------------------

// Writing the data in the data_r register
reg [31:0] data_r;
wire [31:0] gpio_int_status_raw_value;

always @ (posedge clk_i or posedge rst_i) begin
    if(rst_i) begin
        data_r <= 32'h0;
    end else if(read_en_w) begin
        case (cfg_araddr_i[7:0])
            `GPIO_DIRECTION:
            begin
                data_r[`GPIO_DIRECTION_OUTPUT_R] <= gpio_direction_reg;
            end
            `GPIO_INPUT:
            begin
                data_r[`GPIO_INPUT_VALUE_R] <= gpio_input_reg;
            end
            `GPIO_OUTPUT:
            begin
                data_r[`GPIO_OUTPUT_DATA_R] <= gpio_output_reg;
            end
            `GPIO_INT_MASK:
            begin
                data_r[`GPIO_INT_MASK_ENABLE_R]<= gpio_int_mask_reg;
            end
            `GPIO_INT_STATUS:
            begin
                data_r[`GPIO_INT_STATUS_RAW_R] <= interrupt_raw_q;
            end
            `GPIO_INT_LEVEL:
            begin
                data_r[`GPIO_INT_LEVEL_ACTIVE_HIGH_R] <= gpio_int_level_active_high_q;
            end
            `GPIO_INT_MODE:
            begin
                data_r[`GPIO_INT_MODE_EDGE_R] <= gpio_int_mode_edge_q;
            end
            default:
                data_r <= 32'b0;
        endcase
    end
end

assign cfg_rdata_o = data_r;

// Output logic (Stores the final manipulated value after set/clr)
reg [31:0] output_reg;

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        output_reg <= 32'b0;
    end 
    else begin
        // When write is enabled
        if (write_en_w) begin
            case (cfg_awaddr_i[7:0])
            // When we have to write in Output_register
                `GPIO_OUTPUT: begin
                    output_reg <= cfg_wdata_i[`GPIO_OUTPUT_DATA_R];
                end
                // When we have some set bits
                `GPIO_OUTPUT_SET: begin
                    output_reg <= output_reg | cfg_wdata_i[`GPIO_OUTPUT_SET_DATA_R];
                end
                // When we have some clr bits
                `GPIO_OUTPUT_CLR: begin
                    output_reg <= output_reg & ~cfg_wdata_i[`GPIO_OUTPUT_CLR_DATA_R];
                end
                default: begin
                    output_reg <= output_reg;
                end
            endcase
        end
    end
end

// Writing the output of the GPIO pins
assign gpio_output_o = output_reg;

// Which pins are enabled as input/output
assign gpio_output_enable_o = gpio_direction_reg;

// ---------------------------------------------------------------------------------------------------------------------------------

// Interrupt Logic

reg intr_q;
reg [31:0] interrupt_raw_q;
reg [31:0] interrupt_raw_r;
reg [31:0] input_last_q;

// Store previous input for edge detection
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        input_last_q <= 32'b0;
    end else begin
        input_last_q <= gpio_input_i;
    end
end

reg [31:0] active_high_inputs;
reg [31:0] active_low_inputs;
reg [31:0] level_active_w;

reg [31:0] edge_detect_w;
reg [31:0] rising_edges;
reg [31:0] falling_edges;
reg [31:0] edge_active_w;

reg [31:0] interrupt_clear;
reg [31:0] interrupt_set;
reg [31:0] next_interrupt_raw;
reg [31:0] raw_interrupt_value;
reg [31:0] intr_q_value;

always @ (*) begin
    if (rst_i) begin
        active_high_inputs = 32'b0;
        active_low_inputs = 32'b0;
        level_active_w = 32'b0;
        edge_detect_w = 32'b0;
        rising_edges = 32'b0;
        falling_edges = 32'b0;
        edge_active_w = 32'b0;
        interrupt_clear = 32'b0;
        interrupt_set = 32'b0;
        next_interrupt_raw = 32'b0;
        raw_interrupt_value = 32'b0;
        intr_q_value = 32'b0;
    end else begin
        active_high_inputs = gpio_input_i & gpio_int_level_active_high_q;
        active_low_inputs = ~gpio_input_i & ~gpio_int_level_active_high_q;
        level_active_w = (active_high_inputs | active_low_inputs) & (~gpio_int_mode_edge_q);
        
        // Edge detection logic
        edge_detect_w = input_last_q ^ gpio_input_i;
        rising_edges = edge_detect_w & gpio_input_i;
        falling_edges = edge_detect_w & ~gpio_input_i;
        edge_active_w = ((rising_edges & gpio_int_level_active_high_q) | 
                          (falling_edges & ~gpio_int_level_active_high_q)) & 
                          gpio_int_mode_edge_q;
        
        // Interrupt status logic
        // Interrupt clear signal
        interrupt_clear = (write_en_w && (cfg_awaddr_i[7:0] == `GPIO_INT_CLR)) ? 
                            cfg_wdata_i[`GPIO_INT_CLR_ACK_R] : 32'b0;
        
        // Software interrupt set signal
        interrupt_set = (write_en_w && (cfg_awaddr_i[7:0] == `GPIO_INT_SET)) ? 
                          cfg_wdata_i[`GPIO_INT_SET_SW_IRQ_R] : 32'b0;
        
        // Next state logic for raw interrupts
        next_interrupt_raw = (interrupt_raw_q & ~interrupt_clear|   // Clear takes priority
                              interrupt_set |      // Software set
                              edge_active_w |     // New edge triggers
                              level_active_w); // Level triggers
        
        interrupt_raw_q = next_interrupt_raw & gpio_int_mask_reg;
        intr_q = |(next_interrupt_raw & gpio_int_mask_reg);
    end
end


// Output interrupts
assign intr_o = intr_q;

endmodule