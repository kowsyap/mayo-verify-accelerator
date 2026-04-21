library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bit_sliced_vector is
    generic(
        param_m : positive := 64;
        nibble : positive := 4
    );
    Port (
        a         : in  STD_LOGIC_VECTOR(param_m*nibble-1 downto 0);
        result    : out STD_LOGIC_VECTOR(param_m*nibble-1 downto 0)
    );
end bit_sliced_vector;

architecture structural of bit_sliced_vector is
    constant group_count : integer := param_m/8;
    type partials_array_type is array(0 to group_count-1) of std_logic_vector(8*nibble-1 downto 0);
    signal partials : partials_array_type;
begin
    gen_blocks: for i in 0 to group_count-1 generate
        decode_unit: entity work.bit_sliced_unit
            generic map (param_m => param_m, nibble => nibble, index => i)
            port map (
                i_bstring => a,
                o_partial => result(nibble*8*(i+1)-1 downto nibble*8*i)
            );
    end generate;
    
end architecture;
