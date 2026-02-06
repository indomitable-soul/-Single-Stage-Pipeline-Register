module pipeline_reg #(
    parameter int DATA_WIDTH = 32
)(
    input  logic                   clk,
    input  logic                   rst_n,

    // Input interface
    input  logic                   in_valid,
    output logic                   in_ready,
    input  logic [DATA_WIDTH-1:0]  in_data,

    // Output interface
    output logic                   out_valid,
    input  logic                   out_ready,
    output logic [DATA_WIDTH-1:0]  out_data
);

    logic [DATA_WIDTH-1:0] data_reg;
    logic                  full;

    // Handshake signals
    wire accept_in  = in_valid  && in_ready;
    wire accept_out = out_valid && out_ready;

    // Ready/Valid logic
    assign out_valid = full;
    assign out_data  = data_reg;

    // Can accept new data if buffer is empty
    // OR if current data is being consumed this cycle
    assign in_ready = !full || accept_out;

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            full     <= 1'b0;
            data_reg <= '0;
        end else begin
            case ({accept_in, accept_out})
                2'b10: begin
                    // Input only
                    data_reg <= in_data;
                    full     <= 1'b1;
                end
                2'b01: begin
                    // Output only
                    full <= 1'b0;
                end
                2'b11: begin
                    // Simultaneous in & out (pipeline behavior)
                    data_reg <= in_data;
                    full     <= 1'b1;
                end
                default: begin
                    // No transfer
                    full <= full;
                end
            endcase
        end
    end

endmodule
