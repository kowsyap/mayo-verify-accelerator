library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mayo_pkg.all;

entity epk_decoder_datapath is
    generic (
        w : positive := 8;
        nibble : positive := 4;
        param_m : positive := 64;
        param_n : positive := 81;
        param_o : positive := 17;
        param_d : positive := 64
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        sk : in std_logic_vector(16*nibble-1 downto 0);

        p_data : out std_logic_vector(param_m*nibble-1 downto 0);
        col_idx : out std_logic_vector(clog2(param_n)-1 downto 0);
        row_idx : out std_logic_vector(clog2(param_n)-1 downto 0);

        Li : in std_logic;
        Ei : in std_logic;

        Lj : in std_logic;
        Lino : in std_logic;
        Ljno : in std_logic;
        Lij  : in std_logic;
        Lk : in std_logic;
        Ej : in std_logic;
        Ek : in std_logic;
        Efifo : in std_logic;
        zino: out std_logic;  
        zjno: out std_logic;    
        zin: out std_logic;    
        zjn: out std_logic; 
        zk: out std_logic
    );
end epk_decoder_datapath;

architecture structural of epk_decoder_datapath is
    constant nibble_count : positive := 16; 
    constant word_count : positive := ceil_div(param_m, nibble_count); -- 64/16 ->4

    constant final_out_size : positive := word_count * nibble_count * nibble;

    signal fifo_reg : std_logic_vector(final_out_size-1 downto 0);
    signal p_decoded_vector : std_logic_vector(param_m*nibble-1 downto 0);
    signal partial_decoded_vector : std_logic_vector(nibble_count*nibble-1 downto 0);
    
    signal i, j : unsigned(clog2(param_n)-1 downto 0);
    signal k, expected_k_limit : unsigned(nibble-1 downto 0);

begin


    row_idx <= std_logic_vector(i);
    col_idx <= std_logic_vector(j);

    expected_k_limit <= to_unsigned(word_count, nibble);

    gen_r2 : if param_n = 81 generate
    begin
        p_data <= fifo_reg;
    end generate;

    gen_r1 : if param_n /= 81 generate
    begin
        bit_sliced_vector_inst: entity work.bit_sliced_vector
            generic map(
                param_m => param_m,
                nibble => nibble
            )
            port map(
                a => fifo_reg,
                result => p_data
            );
    end generate;

    decode_vector_inst: entity work.decode_vector
        generic map(
            nibble_count => nibble_count,
            nibble => nibble,
            reverse => true
        )
        port map(
            a => sk,
            result => partial_decoded_vector
        );

    epk_fifo_inst: entity work.SIPO_FIFO
        generic map(LEFT_SHIFT=>false,INPUT_WIDTH=>nibble_count*nibble,OUTPUT_WIDTH=>final_out_size)
        port map(
            clk => clk,
            reset => reset,
            serial_in => partial_decoded_vector,
            parallel_in => (others=>'0'),
            serial_out => open,
            load => Efifo,
            load_parallel => '0',
            parallel_out => fifo_reg
        );

    counterI: process(clk)
    begin
        if rising_edge(clk) then
            if Li = '1' then
                i <= (others => '0');
            elsif Lino = '1' then
                i <= to_unsigned(param_d,i'length);
            elsif Ei = '1' then
                i <= i + 1;
            end if;          
        end if;
    end process;

    counterJ: process(clk)
    begin
        if rising_edge(clk) then
            if Lj = '1' then
                j <= (others => '0');
            elsif Lij = '1' then
                j <= i;
            elsif Ljno = '1' then
                j <= to_unsigned(param_d,j'length);
            elsif Ej = '1' then
                j <= j + 1;
            end if;
        end if;
    end process;

    counterK: process(clk)
    begin
        if rising_edge(clk) then
            if Lk = '1' then
                k <= (others => '0');
            elsif Ek = '1' then
                k <= k + 1;
            end if;
        end if;
    end process;

    zino <= '1' when i = to_unsigned(param_d-1, clog2(param_n)) else '0';
    zjno <= '1' when j = to_unsigned(param_d-1, clog2(param_n)) else '0';
    zin <= '1' when i = to_unsigned(param_n-1, clog2(param_n)) else '0';
    zjn <= '1' when j = to_unsigned(param_n-1, clog2(param_n)) else '0';
    zk <= '1' when k = expected_k_limit else '0';

end structural;
