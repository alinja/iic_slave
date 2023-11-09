# iic_slave_mm_8x8 - i2c slave to memory mapped 8-bit addr/8bit bus master

Fully sycnchronous architecture independent RTL VHDL implementation of I2C/SMBus/TWI/two-wire bus slave.
Focus on usability, readability and clock frequency instead of absolutely minimum 
resource usage (about 130 LE/LUT4/FF).

Memory-mapped interface to 8-bit addr, 8-bit data Avalon/AXI style bus with handshake,
stretching scl when needed.

Supports standard mode/fast mode/fast mode plus. Due to relative many pipeline levels,
relatively high clock is requred compared to bus speed. 25MHz works as minimum clk frequency 
for 400kHz bus, but 200 to 300 MHz should be reachable on current FPGAs.

Adjustable PHY glitch filter. Longer filters tolerate more noise, but require higher
clock frequency. In my setup with 10k pullups and 30cm wires, 27M requires len=2 (bus max 600k),
125M requires len=3 (bus max 1600k).

Test bench with I2C master simulation model is included. Syntesizable projects for 
Vivado, Quartus and Libero free versions are included. Tested on hardware using the included
Arduino project for Trinket M0.

In synthesis, use I/O registers to minimize skew and schmitt trigger inputs if available.

This code is released to public domain, but I appreciate feedback and improvements. 
