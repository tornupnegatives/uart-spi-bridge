COMPILER=iverilog
CFLAGS=-g2012 -Wall
SIM=vvp

test-bridge:
	$(COMPILER) $(CFLAGS) -o test_bridge \
							 spi-controller/rtl/clock_divider.v spi-controller/rtl/spi_controller.v \
							 spi-controller/rtl/spi_controller_top.v \
							 uart/rtl/baud_generator.v uart/rtl/parity_checker.v uart/rtl/uart_tx.v \
							 uart/rtl/uart_rx.v uart/rtl/uart_top.v \
							 uart_spi_bridge.v uart_spi_bridge_tb.sv
	$(SIM) ./test_bridge
	rm -f test_bridge
	
clean:
	rm -f *.vcd