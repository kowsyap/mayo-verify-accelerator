library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity quad_accumulator_controller is
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;
        calc    : in  std_logic;
        done    : out std_logic;

        y_ready      : in  std_logic;
        y_valid      : out std_logic;
        y_last       : out std_logic;

        reduce_calc  : out std_logic;
        arr          : out std_logic;

        Ey           : out std_logic;
        Ei           : out std_logic;
        Ea           : out std_logic;
        Li           : out std_logic;
        La           : out std_logic;
        Ly           : out std_logic;
        Ly_cnt       : out std_logic;
        Ey_cnt       : out std_logic;

        zi           : in  std_logic;
        za           : in  std_logic;
        zy_cnt       : in  std_logic;
        reduce_done  : in  std_logic
    );
end quad_accumulator_controller;

architecture behavioral of quad_accumulator_controller is

    type state_type is (IDLE, S1, S2, S3, S4, S5, S6, OK);
    signal state_reg, state_next : state_type := IDLE;

begin

    reg: process(clk, reset)
    begin
        if reset = '1' then
            state_reg <= IDLE;
        elsif rising_edge(clk) then
            state_reg <= state_next;
        end if;
    end process;

    process(state_reg, calc, zi, za, reduce_done, y_ready, zy_cnt)
    begin
        done        <= '0';
        arr         <= '0';
        reduce_calc <= '0';
        y_valid     <= '0';
        y_last      <= '0';

        Ei     <= '0';
        Ea     <= '0';
        Ey     <= '0';
        Li     <= '0';
        La     <= '0';
        Ly     <= '0';
        Ly_cnt <= '0';
        Ey_cnt <= '0';

        state_next <= state_reg;

        case state_reg is
            when IDLE =>
                Li <= '1';
                if calc = '1' then
                    La <= '1';
                    Ly <= '1';
                    state_next <= S2;
                end if;
            when S1 =>
                state_next <= S2;
            when S2 =>
                arr <= '1';
                if za = '0' then
                    Ea <= '1';
                    state_next <= S2;
                else
                    state_next <= S3;
                end if;
            when S3 =>
                if zi = '0' then
                    Ei <= '1';
                    La <= '1';
                    state_next <= S2;
                else
                    state_next <= S4;
                end if;
            when S4 =>
                state_next <= S5;
            when S5 =>
                reduce_calc <= '1';
                if reduce_done = '1' then
                    Ey     <= '1';
                    Ly_cnt <= '1';
                    state_next <= S6;
                end if;
            when S6 =>
                y_valid <= '1';
                if zy_cnt = '1' then
                    y_last <= '1';
                end if;
                if y_ready = '1' then
                    if zy_cnt = '0' then
                        Ey_cnt <= '1';
                    else
                        state_next <= OK;
                    end if;
                end if;
            when OK =>
                done <= '1';
                if calc = '0' then
                    state_next <= IDLE;
                end if;
        end case;
    end process;

end behavioral;