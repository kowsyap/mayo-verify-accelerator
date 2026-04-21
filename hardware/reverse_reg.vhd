library ieee;
use ieee.std_logic_1164.all;

entity reverse_reg is
    generic (
        nibble : positive := 4;
        nibble_count : positive := 16
    );
    port (
        din  : in  std_logic_vector(nibble_count*nibble-1 downto 0);
        dout : out std_logic_vector(nibble_count*nibble-1 downto 0)
    );
end reverse_reg;

architecture rtl of reverse_reg is
begin
    gen_rev : for idx in 0 to nibble_count-1 generate
        dout((idx+1)*nibble-1 downto idx*nibble) <=
            din(((nibble_count-idx)*nibble)-1 downto ((nibble_count-1-idx)*nibble));
    end generate;
end rtl;
