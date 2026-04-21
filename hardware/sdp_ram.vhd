----------------------------------------------------------------------------------------------------
--
-- Entity: sdp_ram
--
-- Description: simple dual port ram
--
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdp_ram is
  generic (
    DATA_WIDTH : integer := 8;
    RAM_DEPTH  : integer := 256;
    ADDR_WIDTH : integer := 5
  );
  port (
    clk_i   :  in std_logic;
    ena_i   :  in std_logic;
    enb_i   :  in std_logic;
    wea_i   :  in std_logic;
    addra_i :  in std_logic_vector(ADDR_WIDTH-1 downto 0);
    addrb_i :  in std_logic_vector(ADDR_WIDTH-1 downto 0);
    da_i    :  in std_logic_vector(DATA_WIDTH-1 downto 0);
    db_o    : out std_logic_vector(DATA_WIDTH-1 downto 0)
  );

end sdp_ram;

architecture synth of sdp_ram is

  type ram_t is array (0 to RAM_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  shared variable ram : ram_t := (others => (others => '0'));

  attribute ram_style : string;
  attribute ram_style of ram:variable is "block";

begin

  -- write after read
  process(clk_i)
  begin
    if (rising_edge(clk_i)) then
      if (enb_i = '1') then
        db_o <= ram(to_integer(unsigned(addrb_i)));
      end if;

      if (ena_i = '1') then
        if (wea_i = '1') then
          ram(to_integer(unsigned(addra_i))) := da_i;
        end if;
      end if;
    end if;
  end process;

end synth;
