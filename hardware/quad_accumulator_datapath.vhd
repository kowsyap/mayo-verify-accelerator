library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mayo_pkg.all;

entity quad_accumulator_datapath is
    generic (
        w          : positive := 8;
        nibble     : positive := 4;
        param_m    : positive := 78;
        param_n    : positive := 86;
        param_o    : positive := 8;
        param_k    : positive := 10
    );
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;

        s_addr     : out std_logic_vector(nibble-1 downto 0);
        mem_ram_addr : out std_logic_vector(clog2(param_n)-1 downto 0);
        u_data       : in  std_logic_vector(2*param_m*nibble-1 downto 0);
        y            : out std_logic_vector(16*nibble-1 downto 0);

        reduce_calc   : in  std_logic;
        arr      : in  std_logic;

        Ei      : in  std_logic;
        Ea      : in  std_logic;
        Ey      : in  std_logic;
        Li      : in  std_logic;
        La      : in  std_logic;
        Ly      : in  std_logic;
        Ly_cnt  : in  std_logic;
        Ey_cnt  : in  std_logic;

        zi      : out std_logic;
        za      : out std_logic;
        zy_cnt  : out std_logic;
        reduce_done : out std_logic
    );
end quad_accumulator_datapath;

architecture rtl of quad_accumulator_datapath is

    constant m_read_bits: positive := param_m*nibble;
    
    signal i: unsigned(nibble-1 downto 0);
    signal a: unsigned (clog2(param_n)-1 downto 0);

    constant Y_WORDS     : positive := m_read_bits / (16*nibble); -- 256/64 = 4
    constant Y_CNT_BITS  : positive := clog2(Y_WORDS);

    signal reduce_dout, y_reg: std_logic_vector(m_read_bits-1 downto 0);
    signal y_long_reg, u_reg : std_logic_vector(2*m_read_bits-1 downto 0);
    signal y_temp, y_temp_d : std_logic_vector(2*m_read_bits-1 downto 0);
    signal arr_d, arr_d2 : std_logic;
    signal y_cnt : unsigned(Y_CNT_BITS-1 downto 0);

    constant TRI_LUT : int_lut_t(0 to param_k-1) := make_tri_lut(param_k);

begin

    process(i, u_reg)
    begin
        case to_integer(i) is
            when 1 => y_temp <= shn(u_reg, 4, nibble);
            when 2 => y_temp <= shn(u_reg, 7, nibble);
            when 3 => y_temp <= shn(u_reg, 9, nibble);
            when others => y_temp <= u_reg;
        end case;
    end process;
    
    s_addr <= std_logic_vector(resize(i, s_addr'length));
    
    mem_ram_addr <= std_logic_vector(resize(a,mem_ram_addr'length));
    
    ureg_reverse_inst : entity work.reverse_reg
    generic map(
        nibble => nibble,
        nibble_count => 2*param_m
    )
    port map(
        din => u_data,
        dout => u_reg
    );

    mod_fx_inst: entity work.reduce_mod_fx(Ctrl)
        generic map(param_m=>param_m,param_k=>param_k,nibble=>nibble)
        port map(
            clk => clk,
            reset => reset,
            a => y_long_reg,
            result => reduce_dout,
            start => reduce_calc,
            done => reduce_done
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

    counterA: process(clk)
    begin
        if rising_edge(clk) then
            if La = '1' then
                a <= (others => '0');
            elsif Ea = '1' then
                a <= a + 1;
            end if;          
        end if;
    end process;

    y_reg_inst : PROCESS(clk)
    begin
        if rising_edge(clk) then
            y_temp_d <= y_temp;
            arr_d <= arr;
            arr_d2 <= arr_d;
            if Ey = '1' then
                y_reg <= reduce_dout;
            end if;
        end if;
    end process;
    
    y_long_reg_inst : PROCESS(clk)
    begin
        if rising_edge(clk) then
            if Ly = '1' then
                y_long_reg <= (others => '0');
            elsif arr_d2 = '1' then
                y_long_reg <= y_long_reg xor y_temp_d;
            end if;
        end if;
    end process;

    counterYcnt: process(clk)
    begin
        if rising_edge(clk) then
            if Ly_cnt = '1' then
                y_cnt <= (others => '0');
            elsif Ey_cnt = '1' then
                y_cnt <= y_cnt + 1;
            end if;
        end if;
    end process;

    zi     <= '1' when i     = to_unsigned(param_k-1, nibble)           else '0';
    za     <= '1' when a     = to_unsigned(param_n-1, clog2(param_n))   else '0';
    zy_cnt <= '1' when y_cnt = to_unsigned(Y_WORDS-1, Y_CNT_BITS)       else '0';

    y         <= y_reg((to_integer(y_cnt)+1)*(16*nibble)-1 downto to_integer(y_cnt)*(16*nibble));

end rtl;
