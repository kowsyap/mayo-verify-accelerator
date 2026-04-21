library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity epk_decoder_controller is
    port (
        clk : in std_logic;
        reset : in std_logic;
        calc : in std_logic;
        Li : out std_logic;
        Lj : out std_logic;
        Lino : out std_logic;
        Ljno : out std_logic;
        Lij : out std_logic;
        Lk : out std_logic;
        Ei : out std_logic;
        Ej : out std_logic;
        Ek : out std_logic;
        Efifo : out std_logic;
        zino : in std_logic;
        zjno : in std_logic;
        zin : in std_logic;
        zjn : in std_logic;
        zk : in std_logic;
        sk_input_ready : out std_logic;
        sk_input_valid : in std_logic;
        sk_input_tlast : in std_logic;
        ps_load : out std_logic;
        ps_mem_load : out std_logic;
        ps_wr : out std_logic;
        mem_wr : out std_logic;
        done : out std_logic
    );
end epk_decoder_controller;

architecture behavioral of epk_decoder_controller is
    type state_type is (
        Idle, 
        P1_start, P1_fetch, P1_write, P1_running, P1T_write,
        P2_start, P2_running, P2_load, P2_fetch, P2_write, P2T_write,
        P3_start, P3_running, P3_fetch, P3_write, P3T_write,
        WAITER,
        Ok
        );
    signal current_state, next_state : state_type := Idle;
    signal tlast_seen : std_logic := '0';
    signal sk_input_ready_s : std_logic;

begin

    sk_input_ready <= sk_input_ready_s;

    tlast_latch : process(clk, reset)
    begin
        if reset = '1' then
            tlast_seen <= '0';
        elsif rising_edge(clk) then
            if sk_input_valid = '1' and sk_input_ready_s = '1' and sk_input_tlast = '1' then
                tlast_seen <= '1';
            elsif current_state = Idle then
                tlast_seen <= '0';
            end if;
        end if;
    end process;

    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= Idle;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    process(current_state, calc, zino, zjno, zin, zjn, tlast_seen, zk, sk_input_valid)
    begin

        Li <= '0'; 
        Lj <= '0'; 
        Lino <= '0'; 
        Ljno <= '0'; 
        Lij <= '0';
        Ei <= '0'; 
        Ej <= '0'; 
        sk_input_ready_s <= '0';
        ps_load <= '0';
        ps_mem_load <= '0';
        ps_wr <= '0';
        mem_wr <= '0';
        Efifo <= '0';
        Lk <= '0';
        Ek <= '0';

        done <= '0';
        next_state <= current_state;

        case current_state is
            when Idle =>
                Li <= '1';
                Lj <= '1';
                Lk <= '1';
                ps_load <= '1';
                if calc = '1' then
                    next_state <= P1_start;
                end if;

            when P1_start =>
                Li <= '1';
                next_state <= P1_running;
            when P1_running =>
                Lij <= '1';
                ps_load <= '1';
                next_state <= P1_fetch;
            when P1_fetch =>
                if zk = '0' then
                    sk_input_ready_s <= '1';
                    if sk_input_valid = '1' then
                        Efifo <= '1';
                        Ek <= '1';
                    end if;
                else
                    Lk <= '1';
                    next_state <= P1_write;
                end if;
            when P1_write =>
                ps_wr <= '1';
                if zjno = '0' then
                    Ej <= '1';
                    next_state <= P1_fetch;
                else
                    next_state <= P1T_write;
                end if;
            when P1T_write =>
                mem_wr <= '1';
                if zino = '0' then
                    Ei <= '1';
                    next_state <= P1_running;
                else
                    next_state <= P2_start;
                end if;

            when P2_start =>
                Li <= '1';
                Ljno <= '1';
                next_state <= P2_running;
            when P2_running =>
                Ljno <= '1';
                next_state <= P2_load;
            when P2_load =>
                ps_mem_load <= '1';
                next_state <= P2_fetch;
            when P2_fetch =>
                if zk = '0' then
                    sk_input_ready_s <= '1';
                    if sk_input_valid = '1' then
                        Efifo <= '1';
                        Ek <= '1';
                    end if;
                else
                    Lk <= '1';
                    next_state <= P2_write;
                end if;
            when P2_write =>
                ps_wr <= '1';
                if zjn = '0' then
                    Ej <= '1';
                    next_state <= P2_fetch;
                else
                    next_state <= P2T_write;
                end if;
            when P2T_write =>
                mem_wr <= '1';
                if zino = '0' then
                    Ei <= '1';
                    Ljno <= '1';
                    next_state <= P2_running;
                else
                    next_state <= P3_start;
                end if;
            
            when P3_start =>
                Lino <= '1';
                next_state <= P3_running;
            when P3_running =>
                Lij <= '1';
                ps_load <= '1';
                next_state <= P3_fetch;
            when P3_fetch =>
                if zk = '0' then
                    sk_input_ready_s <= '1';
                    if sk_input_valid = '1' then
                        Efifo <= '1';
                        Ek <= '1';
                    end if;
                else
                    Lk <= '1';
                    next_state <= P3_write;
                end if;
            when P3_write =>
                ps_wr <= '1';
                if zjn = '0' then
                    Ej <= '1';
                    next_state <= P3_fetch;
                else
                    next_state <= P3T_write;
                end if;
            when P3T_write =>
                mem_wr <= '1';
                if zin = '0' then
                    Ei <= '1';
                    next_state <= P3_running;
                else
                    next_state <= OK;
                end if;
            
            when WAITER =>
                sk_input_ready_s <= '1';
                if tlast_seen = '0' then
                    next_state <= Ok;
                end if;

            when Ok =>
                done <= '1';
                if calc = '0' then
                    next_state <= IDLE;
                end if;

            when others =>
                next_state <= Idle;
        end case;
    end process;

end behavioral;
