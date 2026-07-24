/*
 * Tiny Tapeout Top Module Template
 * Wraps our MAC Engine + Thermal Shutdown Logic
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs: ui_in[7:0] = temp_sensor
    output wire [7:0] uio_out,  // IO outputs
    input  wire [7:0] uio_in,   // IO inputs: uio_in[3:0] = mem_addr, uio_in[4] = start, uio_in[5] = mem_write_en
    output wire [7:0] uo_out,   // Dedicated outputs: uo_out[7:0] = result lower byte
    input  wire       ena,      // always 1 when powered
    input  wire       clk,      // clock
    input  wire       rst_n     // active low reset
);

    // Convert active-low reset to active-high
    wire reset = !rst_n;

    // Pin mapping
    wire [7:0] temp_sensor    = ui_in;
    wire [3:0] mem_addr       = uio_in[3:0];
    wire       start          = uio_in[4];
    wire       mem_write_en   = uio_in[5];
    wire [7:0] mem_write_data = ui_in;

    // Output assignments
    assign uio_out = 8'b0;

    // 1. Thermal protection
    wire thermal_shutdown = (temp_sensor >= 8'd70);

    // 2. Fast Memory (SRAM)
    reg [7:0] fast_ram [0:15];
    reg [7:0] ram_read_data;

    always @(posedge clk) begin
        if (mem_write_en && !thermal_shutdown) begin
            fast_ram[mem_addr] <= mem_write_data;
        end
        ram_read_data <= fast_ram[mem_addr];
    end

    // 3. MAC Math Engine
    reg [15:0] mac_accum;

    always @(posedge clk or posedge reset) begin
        if (reset || thermal_shutdown) begin
            mac_accum <= 16'b0;
        end else if (start) begin
            mac_accum <= mac_accum + (ram_read_data * 8'd2);
        end
    end

    // Output lower 8 bits of calculation to the chip output pins
    assign uo_out = mac_accum[7:0];

endmodule
