library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

library std;
use std.textio.all;

use work.mayo_tb_pkg.all;

entity mayo_verify_accelerator_tb is
end entity mayo_verify_accelerator_tb;

architecture behavior of mayo_verify_accelerator_tb is

    constant round        : positive := 2;
    constant w            : positive := 8;
    constant nibble       : positive := 4;
    constant stream_width : positive := 16 * nibble;   -- 64 bits = 8 bytes per word
    constant param_n      : positive := param_n_tb(round);  -- 78 (r1) / 81 (r2)
    constant sig_len_bytes : natural := param_n * 4 / 2;    -- n*k/2, k=4

    constant axi_data_width : integer := 32;
    constant axi_addr_width : integer := 4;
    constant ctrl_addr : std_logic_vector(axi_addr_width-1 downto 0) := x"0";

    constant ctrl_calc  : std_logic_vector(axi_data_width-1 downto 0) := x"00000001";
    constant ctrl_idle  : std_logic_vector(axi_data_width-1 downto 0) := x"00000000";

    file sig_inpFile : text open read_mode is sig_file(round);
    file epk_inpFile : text open read_mode is epk_file(round);

    signal clk : std_logic := '0';
    signal resetn : std_logic := '0';

    signal s_axi_awaddr  : std_logic_vector(axi_addr_width-1 downto 0) := (others => '0');
    signal s_axi_awprot  : std_logic_vector(2 downto 0) := (others => '0');
    signal s_axi_awvalid : std_logic := '0';
    signal s_axi_awready : std_logic;
    signal s_axi_wdata   : std_logic_vector(axi_data_width-1 downto 0) := (others => '0');
    signal s_axi_wstrb   : std_logic_vector((axi_data_width/8)-1 downto 0) := (others => '1');
    signal s_axi_wvalid  : std_logic := '0';
    signal s_axi_wready  : std_logic;
    signal s_axi_bresp   : std_logic_vector(1 downto 0);
    signal s_axi_bvalid  : std_logic;
    signal s_axi_bready  : std_logic := '0';
    signal s_axi_araddr  : std_logic_vector(axi_addr_width-1 downto 0) := (others => '0');
    signal s_axi_arprot  : std_logic_vector(2 downto 0) := (others => '0');
    signal s_axi_arvalid : std_logic := '0';
    signal s_axi_arready : std_logic;
    signal s_axi_rdata   : std_logic_vector(axi_data_width-1 downto 0);
    signal s_axi_rresp   : std_logic_vector(1 downto 0);
    signal s_axi_rvalid  : std_logic;
    signal s_axi_rready  : std_logic := '0';

    signal s_axis_tdata  : std_logic_vector(stream_width-1 downto 0) := (others => '0');
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tlast  : std_logic := '0';
    signal s_axis_tready : std_logic;

    signal m_axis_tdata  : std_logic_vector(stream_width-1 downto 0);
    signal m_axis_tvalid : std_logic;
    signal m_axis_tlast  : std_logic;
    signal m_axis_tready : std_logic := '1';

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
        constant sig_full_words : natural := (sig_len_b + bytes_per_word - 1) / bytes_per_word + round -1;
        variable curr_word : std_logic_vector(stream_width-1 downto 0);
        variable next_word : std_logic_vector(stream_width-1 downto 0);
        variable have_curr : boolean;
        variable have_next : boolean;
    begin
        tvalid_s <= '0';
        tlast_s  <= '0';
        tdata_s  <= (others => '0');
        wait until rising_edge(clk_s);

        -- Send only the complete sig words (salt words are not sent)
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

    procedure axi_write(
        constant addr : in std_logic_vector(axi_addr_width-1 downto 0);
        constant data : in std_logic_vector(axi_data_width-1 downto 0);
        signal clk_s : in std_logic;
        signal awaddr_s : out std_logic_vector(axi_addr_width-1 downto 0);
        signal awvalid_s : out std_logic;
        signal awready_s : in std_logic;
        signal wdata_s : out std_logic_vector(axi_data_width-1 downto 0);
        signal wvalid_s : out std_logic;
        signal wready_s : in std_logic;
        signal bready_s : out std_logic;
        signal bvalid_s : in std_logic
    ) is
    begin
        awaddr_s <= addr;
        wdata_s <= data;
        awvalid_s <= '1';
        wvalid_s <= '1';
        bready_s <= '1';

        loop
            wait until rising_edge(clk_s);
            exit when awready_s = '1' and wready_s = '1';
        end loop;

        awvalid_s <= '0';
        wvalid_s <= '0';

        loop
            wait until rising_edge(clk_s);
            exit when bvalid_s = '1';
        end loop;

        bready_s <= '0';
    end procedure;

    procedure axi_read(
        constant addr : in std_logic_vector(axi_addr_width-1 downto 0);
        variable data : out std_logic_vector(axi_data_width-1 downto 0);
        signal clk_s : in std_logic;
        signal araddr_s : out std_logic_vector(axi_addr_width-1 downto 0);
        signal arvalid_s : out std_logic;
        signal arready_s : in std_logic;
        signal rready_s : out std_logic;
        signal rvalid_s : in std_logic;
        signal rdata_s : in std_logic_vector(axi_data_width-1 downto 0)
    ) is
    begin
        araddr_s <= addr;
        arvalid_s <= '1';
        rready_s <= '1';

        loop
            wait until rising_edge(clk_s);
            exit when arready_s = '1';
        end loop;

        arvalid_s <= '0';

        loop
            wait until rising_edge(clk_s);
            exit when rvalid_s = '1';
        end loop;

        data := rdata_s;
        rready_s <= '0';
    end procedure;

begin

    clk <= not clk after clk_period / 2;

    dut : entity work.mayo_verify_accelerator
        generic map (
            round => round,
            w => w,
            nibble => nibble,
            C_S_AXI_DATA_WIDTH => axi_data_width,
            C_S_AXI_ADDR_WIDTH => axi_addr_width
        )
        port map (
            ACLK => clk,
            ARESETN => resetn,
            S_AXI_AWADDR => s_axi_awaddr,
            S_AXI_AWPROT => s_axi_awprot,
            S_AXI_AWVALID => s_axi_awvalid,
            S_AXI_AWREADY => s_axi_awready,
            S_AXI_WDATA => s_axi_wdata,
            S_AXI_WSTRB => s_axi_wstrb,
            S_AXI_WVALID => s_axi_wvalid,
            S_AXI_WREADY => s_axi_wready,
            S_AXI_BRESP => s_axi_bresp,
            S_AXI_BVALID => s_axi_bvalid,
            S_AXI_BREADY => s_axi_bready,
            S_AXI_ARADDR => s_axi_araddr,
            S_AXI_ARPROT => s_axi_arprot,
            S_AXI_ARVALID => s_axi_arvalid,
            S_AXI_ARREADY => s_axi_arready,
            S_AXI_RDATA => s_axi_rdata,
            S_AXI_RRESP => s_axi_rresp,
            S_AXI_RVALID => s_axi_rvalid,
            S_AXI_RREADY => s_axi_rready,
            s_axis_tdata => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tlast => s_axis_tlast,
            s_axis_tready => s_axis_tready,
            m_axis_tdata => m_axis_tdata,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tlast => m_axis_tlast,
            m_axis_tready => m_axis_tready
        );

    stimulus_proc : process
        variable status_reg : std_logic_vector(axi_data_width-1 downto 0);
    begin
        resetn <= '0';
        wait for 100 ns;
        wait until rising_edge(clk);
        resetn <= '1';
        wait until rising_edge(clk);

        axi_write(ctrl_addr, ctrl_calc, clk, s_axi_awaddr, s_axi_awvalid, s_axi_awready,
                  s_axi_wdata, s_axi_wvalid, s_axi_wready, s_axi_bready, s_axi_bvalid);
        report "calc asserted - starting combined SIG+EPK stream" severity note;

        drive_combined_stream(sig_inpFile, epk_inpFile, sig_len_bytes, clk,
                              s_axis_tready, s_axis_tdata, s_axis_tvalid, s_axis_tlast);

        loop
            axi_read(ctrl_addr, status_reg, clk, s_axi_araddr, s_axi_arvalid, s_axi_arready,
                     s_axi_rready, s_axi_rvalid, s_axi_rdata);
            exit when status_reg(0) = '1';
        end loop;
        report "done observed through AXI-Lite status" severity note;

        axi_write(ctrl_addr, ctrl_idle, clk, s_axi_awaddr, s_axi_awvalid, s_axi_awready,
                  s_axi_wdata, s_axi_wvalid, s_axi_wready, s_axi_bready, s_axi_bvalid);

        wait for clk_period;
        report "Simulation complete" severity note;
        wait;
    end process;

    sink_proc : process
        variable l : line;
    begin
        wait until resetn = '1';
        loop
            wait until rising_edge(clk);
            if m_axis_tvalid = '1' and m_axis_tready = '1' then
                hwrite(l, m_axis_tdata);
                if m_axis_tlast = '1' then
                    write(l, string'(" LAST"));
                end if;
                writeline(output, l);
            end if;
        end loop;
    end process;

end architecture behavior;
