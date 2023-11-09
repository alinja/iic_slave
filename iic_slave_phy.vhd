-- iic_slave_phy 
--
-- Fully synchronous sampling phy for iic style bus. 
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package iic_slave_phy_pkg is
component iic_slave_phy is
generic(
	FILTER_LEN : integer range 0 to 8 := 3
); port(
	clk : in std_logic;
	rst : in std_logic;

	-- IO pins
	scl : inout std_logic;
	sda : inout std_logic;

	-- Upper layer interface
	start      : out std_logic;							-- start condition on bus

	wdata_valid : out std_logic;						-- incoming byte write has arrived, asserted before ack
	wdata_ack   : in std_logic := '1';					-- set to '1' to send ack to bus, keep valid until next bit
	wdata       : out std_logic_vector(7 downto 0);		-- data byte from bus
	rdata_rd_mode : in std_logic := '0';			-- set to '1' after address to send byte instead of just reading from bus, 
	                                                    -- keep valid from ack until stop
	rdata         : in std_logic_vector(7 downto 0) := (others => '0'); -- data to send, keep valid until next byte
	rdata_done    : out std_logic;						-- data is sent, ack is valid and new rdata can be set
	rdata_ack     : out std_logic;						-- ack/nack after data byte
	stretch_clk   : in std_logic := '0';				-- stretch sclk if needed
	
	stop       : out std_logic
);
end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity iic_slave_phy is
generic(
	FILTER_LEN : integer range 0 to 8 := 3
); port(
	clk : in std_logic;
	rst : in std_logic;

	-- IO pins
	scl : inout std_logic;
	sda : inout std_logic;

	-- Upper layer interface
	start      : out std_logic;							-- start condition on bus

	wdata_valid : out std_logic;						-- incoming byte write has arrived, asserted before ack
	wdata_ack   : in std_logic := '1';					-- set to '1' to send ack to bus, keep valid until next bit
	wdata       : out std_logic_vector(7 downto 0);		-- data byte from bus
	rdata_rd_mode : in std_logic := '0';				-- set to '1' after address to send byte instead of just reading from bus, 
	                                                    -- keep valid from ack until stop
	rdata         : in std_logic_vector(7 downto 0) := (others => '0'); -- data to send, keep valid until next byte and set to ff after nak
	rdata_done    : out std_logic;						-- data is sent, ack is valid and new rdata can be set
	rdata_ack     : out std_logic;						-- ack/nack after data byte
	stretch_clk   : in std_logic := '0';				-- stretch sclk if needed
	
	stop       : out std_logic
);
end entity iic_slave_phy;


architecture test of iic_slave_phy is

	signal scl_rrr : std_logic;
	signal sda_rrr : std_logic;
	signal scl_rr : std_logic;
	signal sda_rr : std_logic;
	signal scl_r : std_logic;
	signal sda_r : std_logic;

	signal scl_filter_ctr : integer range 0 to 7;
	signal sda_filter_ctr : integer range 0 to 7;

	signal scl_r_prev : std_logic;
	signal sda_r_prev : std_logic;
	signal scl_r_prev2 : std_logic;
	signal sda_r_prev2 : std_logic;
	
	type phy_fsm_t is ( idle, started, wr_byte, wr_ack, rd_byte, rd_ack);	
	signal phy_fsm : phy_fsm_t;
	signal start_i : std_logic;
	signal stop_i : std_logic;
	signal ack_i : std_logic;
	signal bitc : integer range 0 to 7;
	signal wdata_i : std_logic_vector(7 downto 0);

begin

	process(clk)
	begin
		if rising_edge(clk) then
			-- input sampling register
			scl_rrr <= to_ux01(scl);
			sda_rrr <= to_ux01(sda);
			-- metastability settling register
			scl_rr <= scl_rrr;
			sda_rr <= sda_rrr;
		end if;
	end process;

	process(clk)
		variable ACK_V : std_logic;
	begin
		if rising_edge(clk) then
			-- debounce filter, requires FILTER_LEN continuous samples to change signal state
			if FILTER_LEN = 0 then
				scl_r <= scl_rr;
				sda_r <= sda_rr;
			else
				if scl_rr = '1' then
					if scl_filter_ctr < FILTER_LEN-1 then
						scl_filter_ctr <= scl_filter_ctr + 1;
					else
						scl_r <= scl_rr;
					end if;
				else
					if scl_filter_ctr > 0 then
						scl_filter_ctr <= scl_filter_ctr - 1;
					else
						scl_r <= scl_rr;
					end if;
				end if;
				if sda_rr = '1' then
					if sda_filter_ctr < FILTER_LEN-1 then
						sda_filter_ctr <= sda_filter_ctr + 1;
					else
						sda_r <= sda_rr;
					end if;
				else
					if sda_filter_ctr > 0 then
						sda_filter_ctr <= sda_filter_ctr - 1;
					else
						sda_r <= sda_rr;
					end if;
				end if;
			end if;
			scl_r_prev <= scl_r;
			sda_r_prev <= sda_r;
			scl_r_prev2 <= scl_r_prev;
			sda_r_prev2 <= sda_r_prev;
			
			-- setup&hold for start is 260 ns
			if (sda_r_prev = '1' and sda_r = '0') and 
			   (scl_r_prev = '1' and scl_r = '1') then
				start_i <= '1';
			else
				start_i <= '0';
			end if;
		
			-- setup&hold for stop is 260 ns
			if (sda_r_prev = '0' and sda_r = '1') and 
			   (scl_r_prev = '1' and scl_r = '1') then
				stop_i <= '1';
			else
				stop_i <= '0';
			end if;


			wdata_valid <= '0';
			rdata_done <= '0';
			case phy_fsm is
			when idle =>
				ack_i <= '0';
				sda <= 'Z';
				scl <= 'Z';
				if start_i = '1' then
					phy_fsm <= started;
				end if;
			when started =>
				ack_i <= '0';
				sda <= 'Z';
				scl <= 'Z';
				if scl_r_prev = '1' and scl_r = '0' then
					bitc <= 7;
					phy_fsm <= wr_byte;
				end if;
			when wr_byte =>
				-- sample input bits on falling edge. Setup 260+50 ns, hold 0 ns
				sda <= 'Z';
				if scl_r_prev = '1' and scl_r = '0' then
					wdata_i <= wdata_i(6 downto 0) & sda_r_prev2; -- prev2 to ensure sampling before edge
					if bitc = 0 then
						ack_i <= '1';
						wdata_valid <= '1';
						phy_fsm <= wr_ack;
					else
						bitc <= bitc - 1;
					end if;
				end if;
			when wr_ack =>
				if stretch_clk = '1' then -- TODO: only on first bit for HS mode
					scl <= '0';
				else
					scl <= 'Z';
				end if;
				if scl_r_prev = '1' and scl_r = '0' then
					ack_i <= '0';
					sda <= 'Z';
					if rdata_rd_mode = '1' then
						bitc <= 7;
						phy_fsm <= rd_byte;
					else
						bitc <= 7;
						phy_fsm <= wr_byte;
					end if;
				end if;
			when rd_byte =>
				if scl = '0' and stretch_clk = '1' then
					scl <= '0';
				else
					scl <= 'Z';
				end if;
				-- data setup to rising scl is 250 ns, hold 0ns
				if rdata(bitc) = '1' then
					sda <= 'Z';
				else
					sda <= '0';
				end if;
				if scl_r_prev = '1' and scl_r = '0' then
					if bitc = 0 then
						--sda <= 'Z'; --TODO: faster reaction time
						phy_fsm <= rd_ack;
					else
						bitc <= bitc - 1;
					end if;
				end if;
			--when rd_ack =>
			when others =>
				sda <= 'Z';
				if scl_r_prev = '1' and scl_r = '0' then
					rdata_ack <= not sda_r_prev2;
					rdata_done <= '1';
					bitc <= 7;
					phy_fsm <= rd_byte;
				end if;
			end case;
			if ack_i = '1'then
				if wdata_ack = '1' then
					sda <= '0';
				else
					sda <= 'Z';
				end if;
			end if;
			if stop_i = '1' then
				phy_fsm <= idle;
			end if;
			if start_i = '1' then
				phy_fsm <= started;
			end if;
			
		
			if rst = '1' then
				scl_filter_ctr <= 0;
				sda_filter_ctr <= 0;
				phy_fsm <= idle;
				ack_i <= '0';
				wdata_valid <= '0';
				rdata_done <= '0';
				rdata_ack <= '0';

				scl <= 'Z';
				sda <= 'Z';
			end if;
		end if;
	end process;
	start <= start_i;
	stop <= stop_i;
	wdata <= wdata_i;
end;