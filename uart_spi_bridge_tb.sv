`timescale 1ns / 1ps

module uart_spi_bridge_tb;
    logic i_clk;
    logic i_rst_n;
    logic i_rx;
    logic o_tx;
    logic i_cipo;
    logic o_copi;
    logic o_sclk;
    logic o_ready;
    logic o_error;

    logic       uart_clk_enable;
    logic [7:0] tx_data, rx_data;

    // 100 MHz clock
    always #5 i_clk = ~i_clk;
    real t_in  = 3.0;
    real t_out = 7.0;

    uart_spi_bridge DUT(.*);

    initial begin
        $dumpfile("uart_spi_bridge.vcd");
        $dumpvars(0, uart_spi_bridge_tb);
    end

    initial begin
        $display("Simulation start");
        i_clk   = 0;
        i_rst_n = 0;
        i_rx    = 1;
        i_cipo  = 0;

        tx_data    = 8'b10110101;
        rx_data    = 8'b11011100;
        
        reset;

        $display("Transmitting to UART: %b\n", tx_data);

        $display("Asserting start bit...");
        @(posedge DUT.UART.BD.r_rising_edge)
            #t_in i_rx = 'h0;

        $display("Sending data packet...");
        for (int i = 0; i < 8; i++)
            @(posedge DUT.UART.BD.r_rising_edge)
                #t_in i_rx = tx_data[i];

        $display("Sending stop bits...\n");
        @(posedge DUT.UART.BD.r_rising_edge)
            #t_in i_rx = 'h1;

        $display("Transmitting UART packet over SPI...");
        for (int i = 7; i >= 0; i--) begin
            i_cipo = rx_data[7-i];
            @(posedge o_sclk)
                #t_out assert(o_copi == tx_data[i]) else
                       $fatal(1, "SPI TX error");
        end

        $display("Waiting for UART to transmit SPI response...");
        @(posedge DUT.UART.BD.r_rising_edge);
        @(posedge DUT.UART.BD.r_rising_edge)
            #t_out assert(o_tx == 'h0);

        $display("Transmitting SPI response over UART...\n");
        for (int i = 0; i < 8; i++)
            @(posedge DUT.UART.BD.r_rising_edge)
                #t_out assert(o_tx == rx_data[7-i]) else
                       $fatal(1, "UART TX error");

        $display("Simulation finish");
        $finish;
    end

    task reset;
         $display("Resetting...");

        @(posedge i_clk)
            #t_in i_rst_n = 0;

        repeat (25) @(posedge i_clk);

        repeat (5) @(posedge i_clk)
            #t_in i_rst_n = 1;

        @(posedge i_clk)
            #t_out assert(o_tx      === 'h1 &&
                          o_copi    === 'h0 &&
                          o_sclk    === 'h0 &&
                          o_ready   === 'h1 &&
                          o_error   === 'h0) else
                    $fatal(1, "ERROR: Incorrect status outputs after reset");
    endtask
endmodule