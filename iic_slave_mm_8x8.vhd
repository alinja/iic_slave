-- iic_slave_mm_8x8 - i2c slave to memory mapped 8-bit addr/8bit bus master
--
-- Fully sycnchronous RTL VHL implementation of I2C/SMBus/TWI/two-wire bus slave.
-- Focus on usability, readability and clock frequency instead of absolutely
-- minimum resource usage (about 130 LE/LUT4/FF).
--
-- Memory-mapped interface to 8-bit addr, 8-bit data Avalon/AXI style bus 
-- with handshake, stretching scl when needed.
--
-- Supports standard mode/fast mode/fast mode plus. 25MHz works as minimum clk 
-- frequency for 400kHz bus, but 200 MHz should be reachable on many FPGAs.
--
-- Adjustable PHY glitch filter. Longer filters tolerate more noise, but require higher
-- clock frequency. In my setup with 10k pullups and 30cm wires, 27M requires len=2 (bus 600k),
-- 125M requires len=3 (bus 1600k).
--
-- Test bench with I2C master simulation model is included. Syntesizable projects 
-- for Vivado an Quartus free versions are included. Tested on hardware using the
-- included Arduino project for Trinket M0
--
-- This code is released to public domain, but I appreciate feedback and improvements. 
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package iic_slave_mm_8x8_pkg is
component iic_slave_mm_8x8 is
generic(
	ADDRESS : std_logic_vector(7 downto 0) := x"20"; -- device address in 8-bit format, bit0 ignored
	FILTER_LEN : integer range 0 to 8 := 3
); port(
	clk : in std_logic;
	rst : in std_logic;

	-- IO pins
	scl : inout std_logic;
	sda : inout std_logic;

	-- mem bus
	bus_addr    : out std_logic_vector(7 downto 0);  -- avalon address / axi4-lite awaddr,araddr
	bus_write   : out std_logic;                     -- write / awvalid,wvalid
	bus_read    : out std_logic;                     -- read / arvalid,rvalid
	bus_waitreq : in std_logic := '0';               -- waitrequest / inverted awready, arready
	bus_wdata   : out std_logic_vector(7 downto 0);  -- writedata / wdata
	bus_rdata   : in std_logic_vector(7 downto 0) := x"00"; -- readdata / rdata
	bus_rvalid  : in std_logic := '1'                -- readdatavalid / rvalid
);
end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iic_slave_phy_pkg.all;

entity iic_slave_mm_8x8 is
generic(
	ADDRESS : std_logic_vector(7 downto 0) := x"20"; -- device address in 8-bit format, bit0 ignored
	FILTER_LEN : integer range 0 to 8 := 3
); port(
	clk : in std_logic;
	rst : in std_logic;

	-- IO pins
	scl : inout std_logic;
	sda : inout std_logic;

	-- mem bus
	bus_addr    : out std_logic_vector(7 downto 0);  -- avalon address / axi4-lite awaddr,araddr
	bus_write   : out std_logic;                     -- write / awvalid,wvalid
	bus_read    : out std_logic;                     -- read / arvalid,rvalid
	bus_waitreq : in std_logic := '0';               -- waitrequest / inverted awready, arready
	bus_wdata   : out std_logic_vector(7 downto 0);  -- writedata / wdata
	bus_rdata   : in std_logic_vector(7 downto 0) := x"00"; -- readdata / rdata
	bus_rvalid  : in std_logic := '1'                -- readdatavalid / rvalid
);
end entity iic_slave_mm_8x8;

architecture test of iic_slave_mm_8x8 is

	signal start : std_logic;
	signal wdata_valid : std_logic;
	signal wdata_ack   : std_logic;
	signal wdata       : std_logic_vector(7 downto 0);
	signal rdata_rd_mode : std_logic;
	signal rdata         : std_logic_vector(7 downto 0);
	signal rdata_done    : std_logic;
	signal rdata_ack     : std_logic;
	signal stretch_clk   : std_logic;
	signal stop : std_logic;

	signal start_flag : std_logic;
	signal stop_flag : std_logic;

	type protocol_fsm_t is ( idle, dev_addr, reg_addr, write_data, write_data_access, read_data);	
	signal protocol_fsm : protocol_fsm_t;
	signal addr : std_logic_vector(7 downto 0);

begin

	phy: iic_slave_phy generic map (
		FILTER_LEN => FILTER_LEN
	) port map (
		clk => clk,
		rst => rst,
		scl => scl,
		sda => sda,
		start       => start,
		wdata_valid => wdata_valid,
		wdata_ack   => wdata_ack,
		wdata       => wdata,
		rdata_rd_mode => rdata_rd_mode,
		rdata       => rdata,
		rdata_done  => rdata_done,
		rdata_ack   => rdata_ack,
		stretch_clk => stretch_clk,
		stop        => stop
	);

	process(clk)
		variable HANDLE_START_STOP : std_logic;
	begin
		if rising_edge(clk) then

			if start = '1' then
				start_flag <= '1';
			end if;
			if stop = '1' then
				stop_flag <= '1';
			end if;
			
			HANDLE_START_STOP := '0';
			case protocol_fsm is
			when idle =>
				stop_flag <= '0';
				wdata_ack <= '0';
				if start_flag = '1' then
					start_flag <= '0';
					protocol_fsm <= dev_addr;
				end if;
			when dev_addr =>
				if wdata_valid = '1' then
					if wdata(7 downto 1) = ADDRESS(7 downto 1) then
						wdata_ack <= '1';
						if wdata(0) = '1' then
							bus_read <= '1';
							stretch_clk <= '1'; --TODO make optional
							protocol_fsm <= read_data;
						else
							protocol_fsm <= reg_addr;
						end if;
					else
						protocol_fsm <= idle;
					end if;
				else
					HANDLE_START_STOP := '1';
				end if;
			when reg_addr =>
				if wdata_valid = '1' then
					wdata_ack <= '1';
					addr <= wdata;
					protocol_fsm <= write_data;
				else
					HANDLE_START_STOP := '1';
				end if;
			when write_data =>
				if wdata_valid = '1' then
					bus_wdata <= wdata;
					bus_write <= '1';
					stretch_clk <= '1'; --TODO make optional
					protocol_fsm <= write_data_access;
				else
					HANDLE_START_STOP := '1';
				end if;
			when write_data_access =>
				if bus_waitreq = '0' then
					bus_write <= '0';
					addr <= std_logic_vector(unsigned(addr)+1);
					stretch_clk <= '0';
					protocol_fsm <= write_data;
					--HANDLE_START_STOP := '1';
				end if;
			--when read_data =>
			when others =>
				if bus_waitreq = '0' then
					bus_read <= '0';
				end if;
				if bus_rvalid = '1' then
					rdata <= bus_rdata;
					stretch_clk <= '0'; --TODO setup before scl rising edge
					HANDLE_START_STOP := '1';
				end if;
				if rdata_done = '1' then
					if rdata_ack = '0' then
						rdata <= x"ff";
						protocol_fsm <= idle;
					else
						addr <= std_logic_vector(unsigned(addr)+1);
						bus_read <= '1';
						stretch_clk <= '1';
					end if;
				end if;
			end case;
			if HANDLE_START_STOP = '1' then
				if stop_flag = '1' then
					protocol_fsm <= idle;
				end if;
				if start_flag = '1' then
					start_flag <= '0';
					protocol_fsm <= dev_addr;
				end if;
			end if;

			if rst = '1' then
				stretch_clk <= '0';
				wdata_ack <= '0';

				protocol_fsm <= idle;
				stop_flag <= '0';
				
				bus_read <= '0';
				bus_write <= '0';
			end if;
		end if;
	end process;
	rdata_rd_mode <= '1' when protocol_fsm = read_data else '0';
	bus_addr <= addr;

end;