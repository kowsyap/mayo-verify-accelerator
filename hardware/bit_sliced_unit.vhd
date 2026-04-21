library ieee;
use ieee.std_logic_1164.all;

entity bit_sliced_unit is
    generic (
        param_m : positive := 8; 
        nibble : positive := 4;
        index : integer := 0
    );
    port (
        i_bstring : in  std_logic_vector(param_m*nibble-1 downto 0);
        o_partial : out std_logic_vector(8*nibble-1 downto 0)
    );
end bit_sliced_unit;

architecture behavior of bit_sliced_unit is
    constant N : integer := param_m/8;
    signal b0, b1, b2, b3 : std_logic_vector(7 downto 0);
    signal temp_partial : std_logic_vector(8*nibble-1 downto 0);
begin

    b0 <= i_bstring(2*nibble*(0*N + index + 1)-1 downto 2*nibble*(0*N + index));
    b1 <= i_bstring(2*nibble*(1*N + index + 1)-1 downto 2*nibble*(1*N + index));
    b2 <= i_bstring(2*nibble*(2*N + index + 1)-1 downto 2*nibble*(2*N + index));
    b3 <= i_bstring(2*nibble*(3*N + index + 1)-1 downto 2*nibble*(3*N + index));

    gen_bits: for j in 0 to 7 generate
        constant slice_high : integer := nibble*(j+1)-1;
        constant slice_low  : integer := nibble*j;
    begin
          temp_partial(slice_high downto slice_low) <= b3(j) & b2(j) & b1(j) & b0(j);
    end generate;

    o_partial <= temp_partial;

end architecture;
