library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SIPO_FIFO is
    generic (
        LEFT_SHIFT : boolean := true;
        INPUT_WIDTH  : positive := 8;   -- Width of the serial input data
        OUTPUT_WIDTH : positive := 256 -- Width of the parallel output data
    );
    port (
        clk         : in  std_logic;                         -- Clock input
        reset       : in  std_logic;                         -- Reset input (active high)
        serial_in   : in  std_logic_vector(INPUT_WIDTH-1 downto 0); -- Input data
        parallel_in   : in  std_logic_vector(OUTPUT_WIDTH-1 downto 0); -- Input data
        load        : in  std_logic;                         -- Load signal
        load_parallel : in  std_logic := '0';                         -- Load signal
        parallel_out : out std_logic_vector(OUTPUT_WIDTH-1 downto 0); -- Parallel output
        serial_out   : out std_logic_vector(INPUT_WIDTH-1 downto 0)
    );
end SIPO_FIFO;

architecture Behavioral of SIPO_FIFO is

    constant NUM_WORDS : integer := OUTPUT_WIDTH / INPUT_WIDTH;

    signal shift_register : std_logic_vector(OUTPUT_WIDTH-1 downto 0) := (others => '0');
begin

    process(clk, reset, load, serial_in)
        variable serial_register_temp : std_logic_vector(INPUT_WIDTH-1 downto 0) := (others => '0');
    begin
        if reset = '1' then
            shift_register <= (others => '0');
        elsif rising_edge(clk) then
            if load_parallel = '1' then
                shift_register <= parallel_in;
            elsif load = '1' then
                if NUM_WORDS = 1 then
                    shift_register <= serial_in;
                else
                    if LEFT_SHIFT then
                        shift_register <= shift_register(OUTPUT_WIDTH-INPUT_WIDTH-1 downto 0) & serial_in;
                    else
                        shift_register <= serial_in & shift_register(OUTPUT_WIDTH-1 downto INPUT_WIDTH);
                    end if;
                end if;
            end if;
        end if;
    end process;

    parallel_out <= shift_register;
    serial_out <= shift_register(OUTPUT_WIDTH-1 downto OUTPUT_WIDTH-INPUT_WIDTH) when LEFT_SHIFT else shift_register(INPUT_WIDTH-1 downto 0);
end Behavioral;
