library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity decode_vector is
    generic(
        nibble_count : positive := 16;
        nibble : positive := 4;
        reverse : boolean := false
    );
    Port (
        a         : in  STD_LOGIC_VECTOR(nibble_count*nibble-1 downto 0);
        result    : out STD_LOGIC_VECTOR(nibble_count*nibble-1 downto 0)
    );
end decode_vector;

architecture Behavioral of decode_vector is
    constant BYTE_WIDTH : integer := 2 * nibble;
    constant count : integer := nibble_count/2;
begin

    ifgen: if reverse = true generate
        gen_swap : for i in 0 to count - 1 generate
            result((i+1)*BYTE_WIDTH - 1 downto i*BYTE_WIDTH + nibble) <= a((nibble_count*nibble-1) - (i*BYTE_WIDTH) downto (nibble_count*nibble-1) - (i*BYTE_WIDTH) - (nibble-1));
            result((i+1)*BYTE_WIDTH - nibble - 1 downto i*BYTE_WIDTH) <= a((nibble_count*nibble-1) - (i*BYTE_WIDTH) - nibble downto (nibble_count*nibble-1) - (i*BYTE_WIDTH) - (2*nibble-1));
        end generate;
    end generate;
    
    elsegen: if reverse = false generate
        gen_swap : for i in 0 to count - 1 generate
            result((i+1)*BYTE_WIDTH - 1 downto i*BYTE_WIDTH + nibble) <= a((i*BYTE_WIDTH + nibble - 1) downto (i*BYTE_WIDTH));
            result((i+1)*BYTE_WIDTH - nibble - 1 downto i*BYTE_WIDTH) <= a((i*BYTE_WIDTH + 2*nibble - 1) downto (i*BYTE_WIDTH + nibble));
        end generate;
    end generate;

end Behavioral;

