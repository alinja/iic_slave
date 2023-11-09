-- iic_master_sim_pkg - simulation model for iic master

-- multi-master bus arbitration not supported

library ieee;
use ieee.std_logic_1164.all;


package iic_master_sim_pkg is
	constant IIC_BIT_PERIOD : time := 2.48 us;

	procedure iic_init(signal scl : inout std_logic; signal sda : inout std_logic);
	procedure iic_start(signal scl : inout std_logic; signal sda : inout std_logic);
	procedure iic_stop(signal scl : inout std_logic; signal sda : inout std_logic);
	procedure iic_sendbyte(signal scl : inout std_logic; signal sda : inout std_logic;
	                       byte : std_logic_vector(7 downto 0); ack : out std_logic);
	procedure iic_sendbyte(signal scl : inout std_logic; signal sda : inout std_logic;
	                       byte : std_logic_vector(7 downto 0));
	procedure iic_receivebyte(signal scl : inout std_logic; signal sda : inout std_logic;
	                       byte : out std_logic_vector(7 downto 0); ack : std_logic);

	procedure iic_reg8_write(signal scl : inout std_logic; signal sda : inout std_logic;
	                       dev_addr : std_logic_vector(7 downto 0); 
						   addr : std_logic_vector(7 downto 0); data : std_logic_vector(7 downto 0));
	procedure iic_reg8_read(signal scl : inout std_logic; signal sda : inout std_logic;
	                       dev_addr : std_logic_vector(7 downto 0); 
						   addr : std_logic_vector(7 downto 0); data : out std_logic_vector(7 downto 0));
	procedure iic_reg8_write(signal scl : inout std_logic; signal sda : inout std_logic;
	                       dev_addr : std_logic_vector(7 downto 0); 
						   addr : std_logic_vector(7 downto 0);
						   len : integer;
						   data0 : std_logic_vector(7 downto 0);
						   data1 : std_logic_vector(7 downto 0) := x"00";
						   data2 : std_logic_vector(7 downto 0) := x"00";
						   data3 : std_logic_vector(7 downto 0) := x"00");
	procedure iic_reg8_read(signal scl : inout std_logic; signal sda : inout std_logic;
	                       dev_addr : std_logic_vector(7 downto 0); 
						   addr : std_logic_vector(7 downto 0);
						   len : integer;
						   data0 : out std_logic_vector(7 downto 0);
						   data1 : out std_logic_vector(7 downto 0);
						   data2 : out std_logic_vector(7 downto 0);
						   data3 : out std_logic_vector(7 downto 0));


end package iic_master_sim_pkg;
 
package body iic_master_sim_pkg is

	-- low level phy operations

	procedure iic_init(signal scl : inout std_logic; signal sda : inout std_logic) is
	begin
		sda <= 'Z';
		scl <= 'Z';
		wait for IIC_BIT_PERIOD;
	end procedure;

	procedure wait_for_scl(signal scl : inout std_logic ) is
	begin
		if to_ux01(scl) /= '1' then
			wait until to_ux01(scl) = '1';
		end if;
	end procedure;

	procedure iic_start(signal scl : inout std_logic; signal sda : inout std_logic) is
	begin
		sda <= 'Z';
		scl <= 'Z';
		wait for IIC_BIT_PERIOD/2;
		sda <= '0';
		wait for IIC_BIT_PERIOD/2;
		scl <= '0';
		wait for IIC_BIT_PERIOD/2;
	end procedure;

	procedure iic_stop(signal scl : inout std_logic; signal sda : inout std_logic) is
	begin
		sda <= '0';
		scl <= '0';
		wait for IIC_BIT_PERIOD/2;
		scl <= 'Z';
		wait for IIC_BIT_PERIOD/2;
		sda <= 'Z';
		wait for IIC_BIT_PERIOD/2;
	end procedure;

	procedure iic_sendbyte(signal scl : inout std_logic; signal sda : inout std_logic;
	                       byte : std_logic_vector(7 downto 0); ack : out std_logic) is
	begin
		-- data byte
		for i in 7 downto 0 loop
			scl <= '0';
			if byte(i) = '1' then
				sda <= 'Z';
			else
				sda <= '0';
			end if;
			wait for IIC_BIT_PERIOD/2;
			scl <= 'Z';
			wait_for_scl(scl);
			wait for IIC_BIT_PERIOD/2;
		end loop;
		
		-- wait for ack
		scl <= '0';
		sda <= 'Z';
		wait for IIC_BIT_PERIOD/2;
		scl <= 'Z';
		wait_for_scl(scl);
		wait for IIC_BIT_PERIOD/2;
		ACK := not to_ux01(sda);
		scl <= '0';
		wait for IIC_BIT_PERIOD/2; -- extra wait just to visualize byte boudaries
	end procedure;

	procedure iic_sendbyte(signal scl : inout std_logic; signal sda : inout std_logic;
	                       byte : std_logic_vector(7 downto 0)) is
		variable ACK : std_logic;
	begin
		iic_sendbyte(scl, sda, byte, ACK);
		--report std_logic'image(ACK);
	end procedure;


	procedure iic_receivebyte(signal scl : inout std_logic; signal sda : inout std_logic;
	                       byte : out std_logic_vector(7 downto 0); ack : std_logic) is
	begin
		-- data byte
		sda <= 'Z';
		for i in 7 downto 0 loop
			scl <= '0';
			wait for IIC_BIT_PERIOD/2;
			scl <= 'Z';
			wait_for_scl(scl);
			wait for IIC_BIT_PERIOD/2;
			byte(i) := to_ux01(sda);
		end loop;
		
		-- send ack
		scl <= '0';
		if ack = '1' then
			sda <= '0';
		else
			sda <= 'Z';
		end if;
		wait for IIC_BIT_PERIOD/2;
		scl <= 'Z';
		wait_for_scl(scl);
		wait for IIC_BIT_PERIOD/2;
		wait for IIC_BIT_PERIOD/2; -- extra wait just to visualize byte boundaries in simulation
	end procedure;

	procedure iic_reg8_write(signal scl : inout std_logic; signal sda : inout std_logic;
	                       dev_addr : std_logic_vector(7 downto 0); 
						   addr : std_logic_vector(7 downto 0); data : std_logic_vector(7 downto 0)) is
		variable ACK : std_logic;
	begin
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, dev_addr, ACK);
		--report std_logic'image(ACK);
		iic_sendbyte(scl, sda, addr);
		iic_sendbyte(scl, sda, data);
		iic_stop(scl, sda);
		wait for 10 us;
	end procedure;

	procedure iic_reg8_read(signal scl : inout std_logic; signal sda : inout std_logic;
	                       dev_addr : std_logic_vector(7 downto 0); 
						   addr : std_logic_vector(7 downto 0); data : out std_logic_vector(7 downto 0)) is
		variable ACK : std_logic;
	begin
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, dev_addr, ACK);
		iic_sendbyte(scl, sda, addr);
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, dev_addr or x"01", ACK);
		iic_receivebyte(scl, sda, data, '0');
		iic_stop(scl, sda);
		wait for 10 us;
	end procedure;

	procedure iic_reg8_write(signal scl : inout std_logic; signal sda : inout std_logic;
	                       dev_addr : std_logic_vector(7 downto 0); 
						   addr : std_logic_vector(7 downto 0);
						   len : integer;
						   data0 : std_logic_vector(7 downto 0);
						   data1 : std_logic_vector(7 downto 0) := x"00";
						   data2 : std_logic_vector(7 downto 0) := x"00";
						   data3 : std_logic_vector(7 downto 0) := x"00") is
		variable ACK : std_logic;
	begin
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, dev_addr, ACK);
		--report std_logic'image(ACK);
		iic_sendbyte(scl, sda, addr);
		if len = 1 then
			iic_sendbyte(scl, sda, data0);
		elsif len = 2 then
			iic_sendbyte(scl, sda, data0);
			iic_sendbyte(scl, sda, data1);
		elsif len = 3 then
			iic_sendbyte(scl, sda, data0);
			iic_sendbyte(scl, sda, data1);
			iic_sendbyte(scl, sda, data2);
		elsif len = 4 then
			iic_sendbyte(scl, sda, data0);
			iic_sendbyte(scl, sda, data1);
			iic_sendbyte(scl, sda, data2);
			iic_sendbyte(scl, sda, data3);
		else
			assert false report "Unsupported len" severity failure;
		end if;
		iic_stop(scl, sda);
		wait for 10 us;
	end procedure;

	procedure iic_reg8_read(signal scl : inout std_logic; signal sda : inout std_logic;
	                       dev_addr : std_logic_vector(7 downto 0); 
						   addr : std_logic_vector(7 downto 0);
						   len : integer;
						   data0 : out std_logic_vector(7 downto 0);
						   data1 : out std_logic_vector(7 downto 0);
						   data2 : out std_logic_vector(7 downto 0);
						   data3 : out std_logic_vector(7 downto 0)) is
		variable ACK : std_logic;
	begin
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, dev_addr, ACK);
		iic_sendbyte(scl, sda, addr);
		iic_start(scl, sda);
		iic_sendbyte(scl, sda, dev_addr or x"01", ACK);
		if len = 1 then
			iic_receivebyte(scl, sda, data0, '0');
		elsif len = 2 then
			iic_receivebyte(scl, sda, data0, '1');
			iic_receivebyte(scl, sda, data1, '0');
		elsif len = 3 then
			iic_receivebyte(scl, sda, data0, '1');
			iic_receivebyte(scl, sda, data1, '1');
			iic_receivebyte(scl, sda, data2, '0');
		elsif len = 4 then
			iic_receivebyte(scl, sda, data0, '1');
			iic_receivebyte(scl, sda, data1, '1');
			iic_receivebyte(scl, sda, data2, '1');
			iic_receivebyte(scl, sda, data3, '0');
		else
			assert false report "Unsupported len" severity failure;
		end if;
		iic_stop(scl, sda);
		wait for 10 us;
	end procedure;

end;