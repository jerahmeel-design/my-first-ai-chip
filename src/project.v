module ai_chip_top (
    input  wire        clk,           // System clock
    input  wire        reset,         // Master reset
    input  wire [7:0]  temp_sensor,   // Temperature input in °C (8-bit integer)
    input  wire        start,         // Start computation trigger
    input  wire [3:0]  mem_addr,      // Memory address input (4-bit -> 16 locations)
    input  wire [7:0]  mem_write_data,// Data to write into fast memory
    input  wire        mem_write_en,  // Memory write enable
    output reg  [15:0] result,        // Math engine output result
    output reg         overheat_flag, // High when temperature >= 70°C
    output reg         busy           // High while math engine is running
);

    // =========================================================================
    // 1. THERMAL PROTECTION CIRCUIT (AUTOMATIC SHUTDOWN AT 70°C)
    // =========================================================================
    wire thermal_shutdown;
    assign thermal_shutdown = (temp_sensor >= 8'd70); // Triggers if temp reaches 70°C

    always @(posedge clk or posedge reset) begin
        if (reset)
            overheat_flag <= 1'b0;
        else
            overheat_flag <= thermal_shutdown;
    end

    // =========================================================================
    // 2. SUPER-FAST SINGLE-CYCLE MEMORY (SRAM / REGISTER FILE)
    // =========================================================================
    reg [7:0] fast_ram [0:15]; // 16x8-bit ultra-fast register memory
    reg [7:0] ram_read_data;

    always @(posedge clk) begin
        if (mem_write_en && !thermal_shutdown) begin
            fast_ram[mem_addr] <= mem_write_data; // Write on clock edge
        end
        ram_read_data <= fast_ram[mem_addr];       // Single-cycle read
    end

    // =========================================================================
    // 3. MATH ENGINE (1 MULTIPLY-ACCUMULATE UNIT)
    // =========================================================================
    reg        mac_enable;
    reg [7:0]  mac_in_a;
    reg [7:0]  mac_in_b;
    reg [15:0] mac_accum;

    always @(posedge clk or posedge reset) begin
        if (reset || thermal_shutdown) begin
            mac_accum <= 16'b0; // Immediately clear/freeze if overheated
        end else if (mac_enable) begin
            mac_accum <= mac_accum + (mac_in_a * mac_in_b);
        end
    end

    // =========================================================================
    // 4. CONTROL STATE MACHINE (FSM)
    // =========================================================================
    localtype state_t;
    parameter IDLE     = 2'b00,
              COMPUTE  = 2'b01,
              SHUTDOWN = 2'b10;

    reg [1:0] state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= IDLE;
            busy       <= 1'b0;
            mac_enable <= 1'b0;
            result     <= 16'b0;
        end else begin
            // Safety Priority: Immediate shutdown if thermal threshold reached
            if (thermal_shutdown) begin
                state      <= SHUTDOWN;
                busy       <= 1'b0;
                mac_enable <= 1'b0;
            end else begin
                case (state)
                    IDLE: begin
                        mac_enable <= 1 me;
                        mac_enable <= 1'b0;
                        if (start) begin
                            state      <= COMPUTE;
                            busy       <= 1'b1;
                            mac_enable <= 1'b1;
                            mac_in_a   <= ram_read_data; // Load operand from fast RAM
                            mac_in_b   <= 8'd2;           // Example constant weight
                        end
                    end

                    COMPUTE: begin
                        result     <= mac_accum;
                        busy       <= 1'b0;
                        mac_enable <= 1'b0;
                        state      <= IDLE;
                    end

                    SHUTDOWN: begin
                        busy       <= 1'b0;
                        mac_enable <= 1'b0;
                        if (!thermal_shutdown) begin
                            state  <= IDLE; // Recovery once temperature drops below 70°C
                        end
                    end
                endcase
            end
        end
    end

endmodule
