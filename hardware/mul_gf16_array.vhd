library ieee;
use ieee.std_logic_1164.all;

entity mul_gf16_array is
    generic (
        m : positive := 78;
        nibble : positive := 4
    );
    port (
        input_data : in std_logic_vector(m*nibble-1 downto 0);
        a : in std_logic_vector(nibble-1 downto 0);
        result : out std_logic_vector(m*nibble-1 downto 0)
    );
end mul_gf16_array;

architecture structural of mul_gf16_array is
begin
    gen_m : for i in 0 to m-1 generate
        mul_inst : entity work.mul_gf16
            port map(
                a => input_data((i+1)*nibble-1 downto i*nibble),
                b => a,
                result => result((i+1)*nibble-1 downto i*nibble)
            );
    end generate;
end structural;
