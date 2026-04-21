library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.mayo_pkg.all;

entity sig_decoder is
    generic (
        w : positive := 8;
        nibble : positive := 4;
        param_n : positive := 66;
        param_k : positive := 9
    );
    port (
        clk                 : in  std_logic;
        reset               : in  std_logic;
        calc                : in  std_logic;
        vector_input_valid  : in  std_logic;
        vector_input        : in  std_logic_vector(16*nibble-1 downto 0);
        vector_input_ready  : out std_logic;
        s_data              : out std_logic_vector(param_n*nibble-1 downto 0);
        s_addr              : out std_logic_vector(nibble-1 downto 0);
        s_wr                : out std_logic;
        done                : out std_logic
    );
end sig_decoder;

architecture Behavioral of sig_decoder is

    constant x_width : integer := calc_width16(param_n);  -- 81->4 -- 78->3
    constant nibble_count : positive := 16; 
    constant word_count : positive := ceil_div(param_n, nibble_count); -- 81/16=6 -- 78/16=5 
    constant final_out_size : positive := (word_count + 1) * w * w;
    constant sig_words : positive := ceil_div(param_n*param_k, 16); -- 86*10/16=54 -- 81*10/16=51 -- 118*10/16=74 -- 154*10/16=97
    
    type state_type is (IDLE, S1, S2, S3, OK);
    signal state, next_state : state_type := IDLE;

    constant shift_rom : shift_rom16_type(0 to 2**x_width-1) := get_shift_rom16(param_n, x_width);
    constant load_rom : shift_rom16_type(0 to 2**x_width-1) := get_load_rom16(param_n, word_count, x_width);
    
    signal fifo_reg, shifted_fifo: std_logic_vector(final_out_size-1 downto 0);
    signal partial_decoded_vector: std_logic_vector(nibble_count*nibble-1 downto 0);
    signal decoded_vector : std_logic_vector(param_n*nibble-1 downto 0);

    signal i: unsigned(nibble-1 downto 0);
    signal x : unsigned(x_width-1 downto 0);
    signal expected_k_limit, k : unsigned(nibble-1 downto 0);

    signal Lx, Ex : std_logic;
    signal Lk, Ek : std_logic;
    signal Li, Ei : std_logic;

    signal zk, zi : std_logic;

    signal Efifo, k_init : std_logic;
    signal k_set, k_reset, k_init_reg : std_logic := '0';
    signal vector_input_ready_s: std_logic;

begin

    shifted_fifo <= std_logic_vector(shift_right(unsigned(fifo_reg), nibble*shift_rom(to_integer(x))));
    s_data <= decoded_vector;
    s_addr <= std_logic_vector(i);
    vector_input_ready <= vector_input_ready_s;

    sreg_reverse_inst1 : entity work.reverse_reg
    generic map(
        nibble => nibble,
        nibble_count => param_n
    )
    port map(
        din => shifted_fifo(param_n*nibble-1 downto 0),
        dout => decoded_vector
    );

    counterI: process(clk)
    begin
        if rising_edge(clk) then
            if Li = '1' then
                i <= (others => '0');
            elsif Ei = '1' then
                i <= i + 1;
            end if;
        end if;
    end process;

    counterX: process(clk)
    begin
        if rising_edge(clk) then
            if Lx = '1' then
                x <= (others => '0');
            elsif Ex = '1' then
                x <= x + 1;
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

    state_reg : process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
        elsif rising_edge(clk) then
            state <= next_state;
            if k_reset = '1' then
                k_init_reg <= '0';
            elsif k_set = '1' then
                k_init_reg <= '1';
            end if;
        end if;
    end process;

    decode_vector_inst: entity work.decode_vector
    generic map(
        nibble_count => nibble_count,
        nibble => nibble,
        reverse => true
    )
    port map(
        a => vector_input,
        result => partial_decoded_vector
    );

    sig_fifo_inst: entity work.SIPO_FIFO
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


    fsm_next : process(state, calc, zk, zi, k_init_reg, vector_input_valid)
    begin
        vector_input_ready_s <= '0';
        done <= '0';
        s_wr <= '0';
        Efifo <= '0';
        Lx <= '0';
        Ex <= '0';
        Lk <= '0';
        Ek <= '0';
        Li <= '0';
        Ei <= '0';

        k_set <= '0';
        k_reset <= '0';
        k_init <= '0';
        next_state <= state;

        case state is
        when IDLE =>
            if calc = '1' then
                k_reset <= '1';
                Lk <= '1';
                Lx <= '1';
                Li <= '1';
                next_state <= S1;
            end if;

        when S1 =>
            if k_init_reg = '0' then
                k_init <= '1';
            end if;
            if zk = '0' then
                vector_input_ready_s <= '1';
                if vector_input_valid = '1' then
                    Efifo <= '1';
                    Ek <= '1';
                end if;
            else
                Lk <= '1';
                k_set <= '1';
                next_state <= S2;
            end if;

        when S2 =>
            s_wr <= '1';
            next_state <= S3;

        when S3 =>
            Ex <= '1';
            if zi = '0' then
                Ei <= '1';
                next_state <= S1;
            else
                next_state <= OK;
            end if;
        
        when OK =>
            done <= '1';
            if calc = '0' then
                next_state <= IDLE;
            end if;

        when others =>
            next_state <= IDLE;
        end case;
    end process;

    expected_k_limit <= to_unsigned(word_count, nibble) when k_init = '1' else to_unsigned(load_rom(to_integer(x)), nibble);

    zk <= '1' when k = expected_k_limit else '0';
    zi <= '1' when i = to_unsigned(param_k - 1, clog2(param_k)) else '0';

end Behavioral;
