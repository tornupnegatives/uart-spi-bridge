`timescale 1ns / 1ps

module uart_spi_bridge
    (
        // FPGA interface
        input i_clk,
        input i_rst_n,

        // UART interface
        input   i_rx,
        output  o_tx,

        // SPI interface
        input   i_cipo,
        output  o_copi,
        output  o_sclk,

        // Status
        output o_ready,
        output o_error
    );

    // FSM
    localparam [4:0]
        READY       = 5'b00001,
        SPI_START   = 5'b00010,
        SPI_TXRX    = 5'b00100,
        UART_START  = 5'b01000,
        UART_TX     = 5'b10000;

    reg [4:0] r_state, r_next_state;

    // Bridge wires
    wire [7:0] w_uart_rx,       w_spi_rx;
    wire       w_uart_rx_valid, w_spi_rx_valid;
    wire       w_uart_ready,    w_spi_ready;

    // Control registers
    reg r_uart_tx_valid, r_next_uart_tx_valid;
    reg r_spi_tx_valid,  r_next_spi_tx_valid;
    reg [7:0] r_tx_bus,  r_next_tx_bus;
    reg r_uart_rst_n,    r_next_uart_rst_n;

    // Status registers
    reg r_ready, r_next_ready;

    uart_top UART(
        .i_clk(i_clk),
        .i_rst_n(r_uart_rst_n),
        //.i_config,
        .i_tx_valid(r_uart_tx_valid),
        .i_tx_parallel({1'h0, r_tx_bus[7:0]}),
        .o_rx_parallel(w_uart_rx),
        .i_rx(i_rx),
        .o_tx(o_tx),
        .o_ready(w_uart_ready),
        .o_rx_error(o_error),
        .o_rx_valid(w_uart_rx_valid)
    );

    spi_controller_top SPI(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        //.i_config
        .i_tx(r_tx_bus),
        .i_tx_valid(r_spi_tx_valid),
        .o_rx(w_spi_rx),
        .o_rx_valid(w_spi_rx_valid),
        .i_cipo(i_cipo),
        .o_copi(o_copi),
        .o_sclk(o_sclk),
        .o_ready(w_spi_ready)
    );

    always @(posedge i_clk) begin
        if (~i_rst_n) begin
            r_state         <= READY;
            r_uart_tx_valid <= 'h0;
            r_spi_tx_valid  <= 'h0;
            r_tx_bus        <= 'h0;
            r_uart_rst_n    <= 'h0;
            r_ready         <= 'h0;
        end

        else begin
            r_state         <= r_next_state;
            r_uart_tx_valid <= r_next_uart_tx_valid;
            r_spi_tx_valid  <= r_next_spi_tx_valid;
            r_tx_bus        <= r_next_tx_bus;
            r_uart_rst_n    <= r_next_uart_rst_n;
            r_ready         <= r_next_ready;
        end
    end

    always @(*) begin
        r_next_state            = r_state;
        r_next_uart_tx_valid    = r_uart_tx_valid;
        r_next_spi_tx_valid     = r_spi_tx_valid;
        r_next_tx_bus           = r_tx_bus;
        r_next_uart_rst_n       = r_uart_rst_n;
        r_next_ready            = r_ready;

        case (r_state)
            READY: begin
                r_next_ready = w_spi_ready && w_uart_ready;

                if (i_rst_n) begin
                    r_next_uart_rst_n = 'h1;

                    // Wait for UART data and place it on the data bus for SPI TX
                    if (w_uart_rx_valid) begin
                        r_next_tx_bus   = w_uart_rx;
                        r_next_ready    = 'h0;
                        r_next_state    = SPI_START;
                    end
                end
            end

            SPI_START: begin
                r_next_spi_tx_valid = 'h1;
                r_next_state = SPI_TXRX;
            end

            SPI_TXRX: begin
                // When SPI TX is complete, send SPI RX back over UART
                if (w_spi_rx_valid) begin
                    r_next_tx_bus        = w_spi_rx;
                    r_next_state         = UART_START;
                end

                // Hold UART in reset while SPI is transmitting
                else begin
                    r_next_uart_rst_n = 'h0;
                    r_next_spi_tx_valid = 'h0;
                end
            end

            UART_START: begin
                // Release UART from reset and begin transmission
                r_next_uart_rst_n    = 'h1;
                r_next_uart_tx_valid = 'h1;
                r_next_state = UART_TX;
            end

            UART_TX: begin
                r_next_uart_tx_valid = 'h0;
                if (w_uart_ready)
                    r_next_state = READY;
            end
        endcase
    end

    assign o_ready = r_ready;
endmodule