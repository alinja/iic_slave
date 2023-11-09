-- example tesbench

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iic_master_sim_pkg.all;

entity iic_slave_tb is
end entity iic_slave_tb;

architecture test of iic_slave_tb is
	component iic_slave_example is
	port(
	clk : in std_logic;
	rst : in std_logic;

	-- IO pins
	scl : inout std_logic;
	sda : inout std_logic;

	led      : out std_logic
	);
	end component;

	constant CLK_PERIOD : time := 100.0 ns;
	
	signal clk : std_logic := '0';
	signal rst : std_logic := '1';

	signal scl : std_logic;
	signal sda : std_logic;
	signal rdata_rd_mode : std_logic := '0';
	
begin

	clk <= not clk after CLK_PERIOD /2;
	rst <= '0' after 500 ns;
	rdata_rd_mode <= '1' after 97.15 us, '0' after 140 us;

	scl <= 'H';
	sda <= 'H';
	process
		variable ACK : std_logic;
		variable BYTE : std_logic_vector(7 downto 0);
		variable BYTE1 : std_logic_vector(7 downto 0);
		variable BYTE2 : std_logic_vector(7 downto 0);
		variable BYTE3 : std_logic_vector(7 downto 0);
	begin
		scl <= 'Z';
		sda <= 'Z';
		wait until rst = '0';
		
		iic_init(scl, sda);
		
		-- raw multibyte write access
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, x"c2", ACK);
		assert ACK = '1' report "Unexpected ACK: " & std_logic'image(ACK) severity failure;
		iic_sendbyte(scl, sda, x"00", ACK);
		assert ACK = '1' report "Unexpected ACK: " & std_logic'image(ACK) severity failure;
		iic_sendbyte(scl, sda, x"00", ACK);
		assert ACK = '1' report "Unexpected ACK: " & std_logic'image(ACK) severity failure;
		iic_sendbyte(scl, sda, x"80", ACK);
		assert ACK = '1' report "Unexpected ACK: " & std_logic'image(ACK) severity failure;
		iic_sendbyte(scl, sda, x"01", ACK);
		assert ACK = '1' report "Unexpected ACK: " & std_logic'image(ACK) severity failure;
		iic_sendbyte(scl, sda, x"02", ACK);
		assert ACK = '1' report "Unexpected ACK: " & std_logic'image(ACK) severity failure;
		iic_stop(scl, sda);
		wait for 30 us;
		
		-- raw multibyte read access
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, x"c2", ACK);
		assert ACK = '1' report "Unexpected ACK: " & std_logic'image(ACK) severity failure;
		iic_sendbyte(scl, sda, x"00", ACK);
		assert ACK = '1' report "Unexpected ACK: " & std_logic'image(ACK) severity failure;
		wait for 5 us;
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, x"c3", ACK);
		assert ACK = '1' report "Unexpected ACK: " & std_logic'image(ACK) severity failure;
		iic_receivebyte(scl, sda, BYTE, '1');
		assert BYTE = x"00" report "Unexpected BYTE" severity failure;
		iic_receivebyte(scl, sda, BYTE, '1');
		assert BYTE = x"80" report "Unexpected BYTE" severity failure;
		iic_receivebyte(scl, sda, BYTE, '1');
		assert BYTE = x"01" report "Unexpected BYTE" severity failure;
		iic_receivebyte(scl, sda, BYTE, '0');
		iic_stop(scl, sda);
		wait for 30 us;

		-- raw mismatched multibyte read access
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, x"ab", ACK);
		assert ACK = '0' report "Unexpected ACK: " & std_logic'image(ACK) severity failure;
		iic_sendbyte(scl, sda, x"ba", ACK);
		assert ACK = '0' report "Unexpected ACK: " & std_logic'image(ACK) severity failure;
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, x"ab", ACK);
		assert ACK = '0' report "Unexpected ACK: " & std_logic'image(ACK) severity failure;
		iic_receivebyte(scl, sda, BYTE, '1');
		iic_receivebyte(scl, sda, BYTE, '0');
		assert BYTE = x"ff" report "Unexpected BYTE" severity failure;
		iic_stop(scl, sda);
		assert BYTE = x"ff" report "Unexpected BYTE" severity failure;
		wait for 30 us;

		--- test recovery from various incorrect accesses
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, x"c2", ACK);
		iic_stop(scl, sda);
		wait for 30 us;
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, x"c2", ACK);
		iic_sendbyte(scl, sda, x"00", ACK);
		iic_stop(scl, sda);
		wait for 30 us;
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, x"c2", ACK);
		iic_sendbyte(scl, sda, x"00", ACK);
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, x"c2", ACK);
		iic_stop(scl, sda);
		wait for 30 us;
		
		-- simple 8-bit register accesses with higher level interfaces
		iic_reg8_write(scl, sda, x"82", x"00", x"ff");
		wait for 30 us;
		iic_reg8_write(scl, sda, x"c2", x"03", x"ff");
		iic_reg8_write(scl, sda, x"c2", x"02", x"00");
		iic_reg8_write(scl, sda, x"c2", x"ff", x"81");
		wait for 30 us;
		iic_reg8_read(scl, sda, x"c2", x"03", BYTE);
		assert BYTE = x"ff" report "Unexpected BYTE" severity failure;
		iic_reg8_read(scl, sda, x"c2", x"02", BYTE);
		assert BYTE = x"00" report "Unexpected BYTE" severity failure;
		iic_reg8_read(scl, sda, x"c2", x"ff", BYTE);
		wait for 30 us;

		iic_reg8_write(scl, sda, x"c2", x"02", 2, x"7e", x"81");
		iic_reg8_read(scl, sda, x"c2", x"02", BYTE);
		assert BYTE = x"7e" report "Unexpected BYTE" severity failure;
		iic_reg8_read(scl, sda, x"c2", x"03", BYTE);
		assert BYTE = x"81" report "Unexpected BYTE" severity failure;
		wait for 30 us;

		iic_reg8_write(scl, sda, x"c2", x"00", 4, x"7f", x"01", x"33", x"66");
		iic_reg8_read(scl, sda, x"c2", x"00", BYTE);
		assert BYTE = x"7f" report "Unexpected BYTE" severity failure;
		iic_reg8_read(scl, sda, x"c2", x"01", BYTE);
		assert BYTE = x"01" report "Unexpected BYTE" severity failure;
		iic_reg8_read(scl, sda, x"c2", x"02", BYTE);
		assert BYTE = x"33" report "Unexpected BYTE" severity failure;
		iic_reg8_read(scl, sda, x"c2", x"03", BYTE);
		assert BYTE = x"66" report "Unexpected BYTE" severity failure;
		wait for 30 us;
	
		iic_reg8_write(scl, sda, x"c2", x"00", 4, x"cc", x"aa", x"55", x"f1");
		iic_reg8_read(scl, sda, x"c2", x"00", 4, BYTE, BYTE1, BYTE2, BYTE3);
		assert BYTE  = x"cc" report "Unexpected BYTE" severity failure;
		assert BYTE1 = x"aa" report "Unexpected BYTE" severity failure;
		assert BYTE2 = x"55" report "Unexpected BYTE" severity failure;
		assert BYTE3 = x"f1" report "Unexpected BYTE" severity failure;
		wait for 30 us;
	
	end process;
	
	dut: iic_slave_example port map (
		clk => clk,
		rst => rst,
		scl => scl,
		sda => sda ,
		led => open	);

end;