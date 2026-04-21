library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

library std;
use std.textio.all;

use work.mayo_tb_pkg.all;

entity mayo_verify_tb is
end entity mayo_verify_tb;

architecture behavior of mayo_verify_tb is

    constant round        : positive := 2;
    constant w            : positive := 8;
    constant nibble       : positive := 4;
    constant stream_width : positive := 16 * nibble;   -- 64 bits = 8 bytes per word
    constant param_n      : positive := param_n_tb(round);  -- 78 (r1) / 81 (r2)
    constant sig_len_bytes : natural := param_n * 4 / 2;    -- n*k/2, k=4

    file sig_inpFile : text open read_mode is sig_file(round);
    file epk_inpFile : text open read_mode is epk_file(round);

    signal clk : std_logic := '0';
    signal reset : std_logic := '1';

    signal calc : std_logic := '0';

    signal tdata_i : std_logic_vector(stream_width-1 downto 0) := (others => '0');
    signal tvalid_i : std_logic := '0';
    signal tlast_i : std_logic := '0';
    signal tready_o : std_logic;

    signal done_o : std_logic;

    signal tdata_o : std_logic_vector(stream_width-1 downto 0);
    signal tvalid_o : std_logic;
    signal tlast_o : std_logic;
    signal tready_i : std_logic := '1';

    constant clk_period : time := 10 ns;

    procedure read_next_valid_word(
        file vec_file : text;
        variable word_out : out std_logic_vector(stream_width-1 downto 0);
        variable found : out boolean
    ) is
        variable vector_line : line;
        variable vector_valid : boolean;
    begin
        found := false;

        while not endfile(vec_file) loop
            readline(vec_file, vector_line);
            hread(vector_line, word_out, good => vector_valid);
            if vector_valid then
                found := true;
                exit;
            end if;
        end loop;
    end procedure;

    -- Sends ceil(sig_len_b/8) SIG words (no tlast, salt words skipped)
    -- followed by all EPK words (tlast on last word).
    procedure drive_combined_stream(
        file sig_f          : text;
        file epk_f          : text;
        constant sig_len_b  : in natural;
        signal clk_s        : in  std_logic;
        signal tready_s     : in  std_logic;
        signal tdata_s      : out std_logic_vector(stream_width-1 downto 0);
        signal tvalid_s     : out std_logic;
        signal tlast_s      : out std_logic
    ) is
        constant bytes_per_word : natural := stream_width / 8;                                    -- 8
        constant sig_full_words : natural := (sig_len_b + bytes_per_word - 1) / bytes_per_word; -- 20 (r1)
        variable curr_word : std_logic_vector(stream_width-1 downto 0);
        variable next_word : std_logic_vector(stream_width-1 downto 0);
        variable have_curr : boolean;
        variable have_next : boolean;
    begin
        tvalid_s <= '0';
        tlast_s  <= '0';
        tdata_s  <= (others => '0');
        wait until rising_edge(clk_s);

        -- Send only the complete sig words (salt and any partial word are not sent)
        for i in 0 to sig_full_words - 1 loop
            read_next_valid_word(sig_f, curr_word, have_curr);
            exit when not have_curr;
            tdata_s  <= curr_word;
            tvalid_s <= '1';
            tlast_s  <= '0';
            loop
                wait until rising_edge(clk_s);
                exit when tready_s = '1';
            end loop;
        end loop;

        -- EPK words: tlast on last word only
        read_next_valid_word(epk_f, curr_word, have_curr);
        while have_curr loop
            read_next_valid_word(epk_f, next_word, have_next);
            tdata_s  <= curr_word;
            tvalid_s <= '1';
            if have_next then
                tlast_s <= '0';
            else
                tlast_s <= '1';
            end if;
            loop
                wait until rising_edge(clk_s);
                exit when tready_s = '1';
            end loop;
            curr_word := next_word;
            have_curr := have_next;
        end loop;

        tvalid_s <= '0';
        tlast_s  <= '0';
        tdata_s  <= (others => '0');
    end procedure;

begin

    clk <= not clk after clk_period / 2;

    dut : entity work.mayo_verify
        generic map (
            round => round,
            w => w,
            nibble => nibble
        )
        port map (
            clk_i    => clk,
            reset_i  => reset,
            calc_i   => calc,
            tdata_i  => tdata_i,
            tvalid_i => tvalid_i,
            tlast_i  => tlast_i,
            tready_o => tready_o,
            done_o   => done_o,
            tdata_o  => tdata_o,
            tvalid_o => tvalid_o,
            tlast_o  => tlast_o,
            tready_i => tready_i
        );

    stimulus_proc : process
    begin
        reset <= '1';
        wait for 100 ns;
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);

        calc <= '1';
        report "calc asserted — starting combined SIG+EPK stream" severity note;

        drive_combined_stream(sig_inpFile, epk_inpFile, sig_len_bytes, clk, tready_o, tdata_i, tvalid_i, tlast_i);

        wait until rising_edge(clk) and done_o = '1';
        report "done observed" severity note;
        calc <= '0';

        wait for clk_period;
        report "Simulation complete" severity note;
        wait;
    end process;

    sink_proc : process
        variable l : line;
    begin
        wait until reset = '0';
        loop
            wait until rising_edge(clk);
            if tvalid_o = '1' and tready_i = '1' then
                hwrite(l, tdata_o);
                if tlast_o = '1' then
                    write(l, string'(" LAST"));
                end if;
                writeline(output, l);

                if tlast_o = '1' then
                    report "Observed output tlast" severity note;
                end if;
            end if;
        end loop;
    end process;

end architecture behavior;
