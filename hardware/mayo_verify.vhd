library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.mayo_pkg.all;

entity mayo_verify is
    generic (
        round  : positive := 2;
        w      : positive := MAYO_W;
        nibble : positive := MAYO_NIBBLE
    );
    port (
        clk_i : in  std_logic;
        reset_i : in std_logic;

        calc_i : in std_logic;

        tdata_i : in  std_logic_vector(16*MAYO_NIBBLE-1 downto 0);
        tvalid_i : in std_logic;
        tlast_i : in std_logic;
        tready_o : out std_logic;

        done_o     : out std_logic;

        tdata_o : out std_logic_vector(16*MAYO_NIBBLE-1 downto 0);
        tvalid_o : out std_logic;
        tlast_o  : out std_logic;
        tready_i : in  std_logic
    );
end entity mayo_verify;

architecture behavioral of mayo_verify is

    constant P        : mayo_params_t := get_mayo_params(round);
    constant param_m  : positive := P.m;
    constant param_n  : positive := P.n;
    constant param_o  : positive := P.o;
    constant param_k  : positive := P.k;
    constant param_d  : positive := P.n - P.o;

    constant m_read_bits : positive := param_m * nibble;

    -- FSM
    type state_t is (IDLE, SIG_DECODE, EPK_DECODE, QA_COMPUTE, DONE);
    signal state : state_t;

    -- internal calc signals driven by FSM
    signal epk_calc     : std_logic;
    signal sig_dec_calc : std_logic;
    signal qa_calc      : std_logic;

    -- reset extended to include soft-reset from calc_i going low
    signal reset_all : std_logic;

    -- internal done signals from sub-modules
    signal epk_done     : std_logic;
    signal sig_dec_done : std_logic;
    signal qa_done      : std_logic;

    -- epk_decoder <-> data_storage
    signal ps_load     : std_logic;
    signal ps_mem_load : std_logic;
    signal ps_wr       : std_logic;
    signal mem_wr      : std_logic;
    signal p_reg       : std_logic_vector(param_m*nibble-1 downto 0);
    signal ps_col_idx  : std_logic_vector(clog2(param_n)-1 downto 0);
    signal ps_row_idx  : std_logic_vector(clog2(param_n)-1 downto 0);
    signal mem_ram_addr: std_logic_vector(clog2(param_n)-1 downto 0);

    -- sig_decoder <-> data_storage
    signal s_data       : std_logic_vector(param_n*nibble-1 downto 0);
    signal s_wr_addr    : std_logic_vector(nibble-1 downto 0);
    signal s_wr         : std_logic;
    signal s_addr       : std_logic_vector(nibble-1 downto 0);

    -- data_storage <-> quad_accumulator
    signal u_reg   : std_logic_vector(2*m_read_bits-1 downto 0);

    -- data_storage debug
    signal s_dbg_msb : std_logic_vector(31 downto 0);
    signal s_dbg_lsb : std_logic_vector(31 downto 0);

    signal sk_input_ready_o, sig_input_ready_o  : std_logic;

begin

    reset_all <= reset_i or (not calc_i);

    -- FSM
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if reset_i = '1' or calc_i = '0' then
                state <= IDLE;
            else
                case state is
                    when IDLE =>
                        if calc_i = '1' then
                            state <= SIG_DECODE;
                        end if;

                    when SIG_DECODE =>
                        if sig_dec_done = '1' then
                            state <= EPK_DECODE;
                        end if;

                    when EPK_DECODE =>
                        if epk_done = '1' then
                            state <= QA_COMPUTE;
                        end if;

                    when QA_COMPUTE =>
                        if qa_done = '1' then
                            state <= DONE;
                        end if;

                    when DONE =>
                        null;
                end case;
            end if;
        end if;
    end process;

    sig_dec_calc <= '1' when state = SIG_DECODE else '0';
    epk_calc     <= '1' when state = EPK_DECODE else '0';
    qa_calc      <= '1' when state = QA_COMPUTE else '0';

    done_o     <= '1' when state = DONE else '0';

    tready_o <= (sk_input_ready_o  and epk_calc) or (sig_input_ready_o and sig_dec_calc);

    epk_decode_inst : entity work.epk_decoder
        generic map (
            w        => w,
            nibble   => nibble,
            param_m  => param_m,
            param_n  => param_n,
            param_o  => param_o,
            param_d  => param_d
        )
        port map (
            clk            => clk_i,
            reset          => reset_all,
            calc           => epk_calc,

            vector_input_ready => sk_input_ready_o,
            vector_input       => tdata_i,
            vector_tlast       => tlast_i,
            vector_input_valid => tvalid_i,

            p_data         => p_reg,
            col_idx        => ps_col_idx,
            row_idx        => ps_row_idx,
            ps_load        => ps_load,
            ps_mem_load    => ps_mem_load,
            ps_wr          => ps_wr,
            mem_wr         => mem_wr,
            done           => epk_done
        );

    sig_decoder_inst : entity work.sig_decoder
        generic map (
            w        => w,
            nibble   => nibble,
            param_n  => param_n,
            param_k  => param_k
        )
        port map (
            clk                => clk_i,
            reset              => reset_all,
            calc               => sig_dec_calc,
            vector_input_ready => sig_input_ready_o,
            vector_input       => tdata_i,
            vector_input_valid => tvalid_i,
            s_data             => s_data,
            s_addr             => s_wr_addr,
            s_wr               => s_wr,
            done               => sig_dec_done
        );

    memory_bank : entity work.data_storage
        generic map (
            w        => w,
            nibble   => nibble,
            param_m  => param_m,
            param_n  => param_n,
            param_o  => param_o,
            param_k  => param_k
        )
        port map (
            clk         => clk_i,
            reset       => reset_all,
            calc        => epk_calc,
            s_wr        => s_wr,
            s_in        => s_data,
            s_wr_addr   => s_wr_addr,
            s_addr      => s_addr,
            ps_load     => ps_load,
            ps_mem_load => ps_mem_load,
            ps_wr       => ps_wr,
            mem_wr      => mem_wr,
            input_data  => p_reg,
            col_idx     => ps_col_idx,
            row_idx     => ps_row_idx,
            ps_addr     => mem_ram_addr,
            u_out       => u_reg
        );

    quad_accum_inst : entity work.quad_accumulator
        generic map (
            w        => w,
            nibble   => nibble,
            param_m  => param_m,
            param_n  => param_n,
            param_o  => param_o,
            param_k  => param_k
        )
        port map (
            clk          => clk_i,
            reset        => reset_all,
            calc         => qa_calc,
            u_data       => u_reg,
            s_addr       => s_addr,
            mem_ram_addr => mem_ram_addr,

            y            => tdata_o,
            y_valid      => tvalid_o,
            y_last       => tlast_o,
            y_ready      => tready_i,

            done         => qa_done
        );

end behavioral;
