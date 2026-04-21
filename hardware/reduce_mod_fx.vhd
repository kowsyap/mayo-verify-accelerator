library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.mayo_pkg.all;

entity reduce_mod_fx is
    generic(
        param_m : positive := 64;
        param_k : positive := 9;
        nibble:positive := 4
    );
    Port (
        clk      : in  STD_LOGIC;
        reset    : in  STD_LOGIC;
        a         : in  STD_LOGIC_VECTOR(2*param_m*nibble-1 downto 0);
        result    : out STD_LOGIC_VECTOR(param_m*nibble-1 downto 0);
        start     : in  STD_LOGIC;
        done     :  out  STD_LOGIC
    );
end reduce_mod_fx;

architecture Ctrl of reduce_mod_fx is 

    constant lookup_table : fx_lookup_type := get_fx_lookup_table(param_m);
    constant count_max : integer :=  (param_k * (param_k + 1)) / 2 - 1;
    constant total_nibbles: integer :=2*param_m;
    constant window: integer := total_nibbles - count_max;

    signal l: unsigned(7 downto 0);

    signal a_temp, a_next, result_reg: std_logic_vector(2*param_m*nibble-1 downto 0);
    signal a_slice : std_logic_vector(3 downto 0);

    signal El, Ll, Ef, Lf, Ea, La, Ed, Ld, zl : std_logic; 
    signal intermediate_results: fx_lookup_type := (others =>(others=>'0'));

    type state_type is (IDLE, S1, OK);
    signal state, next_state : state_type := IDLE;

begin

    gen_mul: for i in 0 to 4 generate
        signal res : std_logic_vector(nibble-1 downto 0);
    begin
        mul_inst: entity work.mul_gf16
            port map (
                a => a_slice,
                b => lookup_table(i),
                result => intermediate_results(i)
            );
    end generate;

    a_next <= (3 downto 0 => '0') &
    a_temp(2*param_m*nibble-1 downto (window+1)*nibble) &
    (a_temp((window-0)*nibble+3 downto (window-0)*nibble) xor intermediate_results(0)) &
    (a_temp((window-1)*nibble+3 downto (window-1)*nibble) xor intermediate_results(1)) &
    (a_temp((window-2)*nibble+3 downto (window-2)*nibble) xor intermediate_results(2)) &
    (a_temp((window-3)*nibble+3 downto (window-3)*nibble) xor intermediate_results(3)) &
    (a_temp((window-4)*nibble+3 downto (window-4)*nibble) xor intermediate_results(4)) &
    a_temp((window-4)*nibble-1 downto 4);

    l_counter: process(clk)
    begin
        if rising_edge(clk) then
            if Ll = '1' then
                l <= to_unsigned(count_max,l'length);
            elsif El = '1' then
                l <= l - 1;
            end if;
        end if;
    end process;

    a_fifo_inst: entity work.SIPO_FIFO
        generic map(LEFT_SHIFT=>false,INPUT_WIDTH=>nibble,OUTPUT_WIDTH=>count_max*nibble)
        port map(
            clk => clk,
            reset => reset,
            serial_in => (others=>'0'),
            parallel_in => a(param_m*nibble-1 downto (param_m-count_max) * nibble),
            serial_out => a_slice,
            load => Ef,
            load_parallel => Lf,
            parallel_out => open
        );

    a_reg_proc : process(clk)
    begin
        if rising_edge(clk) then
            if La='1' then
                a_temp <= a;
            elsif Ea='1' then
                a_temp <= a_next;
            end if;
        end if;
    end process a_reg_proc;

    result_proc : process(clk)
    begin
        if rising_edge(clk) then
            if Ld='1' then
                result_reg <= (others=>'0');
            elsif Ed='1' then
                result_reg <= std_logic_vector(shift_left(unsigned(a_temp), nibble*count_max));
            end if;
        end if;
    end process result_proc;

    fsm_proc : process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
        elsif rising_edge(clk) then
            state <= next_state;
        end if;
    end process;

    control_proc : process(state, zl, start)
    begin
        Ll <= '0'; 
        Lf <= '0'; 
        La <= '0'; 
        El <= '0';
        Ef <= '0';
        Ea <= '0';
        Ld <= '0';
        Ed <= '0';
        done <= '0';
        next_state <= state;
        case state is
            when IDLE =>
                if start = '1' then
                    Ll <= '1';
                    Lf <= '1';
                    La <= '1';
                    Ld <= '1';
                    next_state <= S1;
                end if;
            
            when S1 =>
                if zl = '0' then
                    El <= '1';
                    Ef <= '1';
                    Ea <= '1';
                else
                    Ed <= '1';
                    next_state <= OK;
                end if;

            when OK =>
                done <= '1';
                if start = '0' then
                    next_state <= IDLE;
                end if;
        end case;
    end process;
    
    zl <= '1' when l = to_unsigned(0, l'length) else '0';
    result <= result_reg(2*param_m*nibble-1 downto param_m*nibble);

end Ctrl;
