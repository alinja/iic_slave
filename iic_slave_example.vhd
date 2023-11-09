-- iic_slave_example - example design for iic_slave

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iic_slave_phy_pkg.all;
use work.iic_slave_mm_8x8_pkg.all;

entity iic_slave_example is
port(
	clk : in std_logic;
	rst : in std_logic;

	-- IO pins
	scl : inout std_logic;
	sda : inout std_logic;

	led      : out std_logic
);
end entity iic_slave_example;

architecture test of iic_slave_example is
	signal bus_addr : std_logic_vector(7 downto 0);
	signal bus_write : std_logic;
	signal bus_read : std_logic;
	signal bus_waitreq : std_logic;
	signal bus_wdata : std_logic_vector(7 downto 0);
	signal bus_rdata : std_logic_vector(7 downto 0);
	signal bus_rvalid : std_logic;

	signal reg0 : std_logic_vector(7 downto 0);
	signal reg1 : std_logic_vector(7 downto 0);
	signal reg2 : std_logic_vector(7 downto 0);
	signal reg3 : std_logic_vector(7 downto 0);
	signal acc_ctr : integer range 0 to 63;

	signal rst_ctr : unsigned(3 downto 0) := x"0";
	signal rst_i : std_logic;
	signal pwm_ctr : unsigned(7 downto 0);
	signal pwm_out : std_logic;
	signal blink_ctr : unsigned(19 downto 0);
	signal blink_on : std_logic;

begin

	reg: iic_slave_mm_8x8 generic map (
		ADDRESS => x"c2",
		FILTER_LEN => 3
	) port map (
		clk => clk,
		rst => rst_i,
		scl => scl,
		sda => sda,
		bus_addr => bus_addr,
		bus_write => bus_write,
		bus_read => bus_read,
		bus_waitreq => bus_waitreq,
		bus_wdata => bus_wdata,
		bus_rdata => bus_rdata,
		bus_rvalid => bus_rvalid );

	process(clk)
	begin
		if rising_edge(clk) then
			if rst_ctr < 10 then
				rst_i <= '1';
				rst_ctr <= rst_ctr + 1;
			else
				rst_i <= '0';
			end if;
			-- example register bank with artificially long response times
			bus_waitreq <= '1';
			if bus_write = '1' then
				case bus_addr is
				when x"00" =>
					reg0 <= bus_wdata;
				when x"01" =>
					reg1 <= bus_wdata;
				when x"02" =>
					reg2 <= bus_wdata;
				when x"03" =>
					reg3 <= bus_wdata;
				when others =>
					null;
				end case;
				if acc_ctr = 25 then
					bus_waitreq <= '0';
					acc_ctr <= 0;
				else
					acc_ctr <= acc_ctr + 1;
				end if;
			end if;
			bus_rvalid <= '0';
			if bus_read = '1' then
				case bus_addr is
				when x"00" =>
					bus_rdata <= reg0;
				when x"01" =>
					bus_rdata <= reg1;
				when x"02" =>
					bus_rdata <= reg2;
				when x"03" =>
					bus_rdata <= reg3;
				when others =>
					bus_rdata <= x"00";
					null;
				end case;
				if acc_ctr = 30 then
					bus_waitreq <= '0';
					bus_rvalid <= '1';
					acc_ctr <= 0;
				else
					acc_ctr <= acc_ctr + 1;
				end if;
			end if;

			-- super fancy led binking control
			pwm_ctr <= pwm_ctr + 1;
			if pwm_ctr < unsigned(reg1) then
				pwm_out <= '1';
			else
				pwm_out <= '0';
			end if;
			if pwm_ctr = x"00" then
				blink_ctr <= blink_ctr + 1;
			end if;
			blink_on <= blink_ctr(14) and blink_ctr(13) and blink_ctr(12);
			if reg0(0) = '1' then
				led <= not '0'; -- disabled
			else
				if reg0(1) = '1' then --blink on
					led <= not (blink_on and pwm_out);
				else
					led <= not pwm_out;
				end if;
			end if;

			if rst_i = '1' then
				acc_ctr <= 0;
				bus_waitreq <= '1';
				bus_rvalid <= '0';
				reg0 <= x"02";
				reg1 <= x"ff";
				reg2 <= x"00";
				reg3 <= x"00";
				pwm_ctr <= x"00";
				blink_ctr <= x"00000";
				
			end if;
		end if;
	end process;

end;