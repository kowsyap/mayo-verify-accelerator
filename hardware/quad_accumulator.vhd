library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mayo_pkg.all;

entity quad_accumulator is
    generic (
        w            : positive := 8;
        nibble       : positive := 4;
        param_m      : positive := 78;
        param_n      : positive := 86;
        param_o      : positive := 8;
        param_k      : positive := 10
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        calc     : in  std_logic;
        done     : out std_logic;

        -- datapath interfaces
        s_addr     : out std_logic_vector(nibble-1 downto 0);
        mem_ram_addr   : out std_logic_vector(clog2(param_n)-1 downto 0);
        u_data       : in  std_logic_vector(2*param_m*nibble-1 downto 0);
        y_ready      : in std_logic;
        y_valid      : out std_logic;
        y_last       : out std_logic;
        y            : out std_logic_vector(16*nibble-1 downto 0)
    );
end quad_accumulator;

architecture structural of quad_accumulator is

    -- control signals
    signal arr, reduce_calc : std_logic;
    signal Ei, Ea, Ey       : std_logic;
    signal Li, La, Ly       : std_logic;
    signal Ly_cnt, Ey_cnt   : std_logic;
    -- status signals
    signal zi, za, zy_cnt, reduce_done : std_logic;

begin

    dp_inst : entity work.quad_accumulator_datapath
        generic map (
            w => w,
            nibble => nibble,
            param_m => param_m,
            param_n => param_n,
            param_o => param_o,
            param_k => param_k
        )
        port map (
            clk    => clk,
            reset  => reset,
            s_addr => s_addr,
            mem_ram_addr => mem_ram_addr,
            u_data => u_data,
            arr => arr,
            reduce_calc => reduce_calc,

            Ei => Ei,
            Ea => Ea,
            Ey => Ey,
            Li => Li,
            La => La,
            Ly => Ly,
            Ly_cnt => Ly_cnt,
            Ey_cnt => Ey_cnt,
            zi => zi,
            za => za,
            zy_cnt => zy_cnt,
            reduce_done => reduce_done,
            y => y
        );

    ctrl_inst : entity work.quad_accumulator_controller
        port map (
            clk    => clk,
            reset  => reset,
            calc  => calc,
            done   => done,
            y_ready => y_ready,
            y_valid => y_valid,
            y_last => y_last,
            arr => arr,
            reduce_calc => reduce_calc,
            Ey => Ey,
            Ei => Ei,
            Ea => Ea,
            Li => Li,
            La => La,
            Ly => Ly,
            Ly_cnt => Ly_cnt,
            Ey_cnt => Ey_cnt,
            zi => zi,
            za => za,
            zy_cnt => zy_cnt,
            reduce_done => reduce_done
        );

end structural;
