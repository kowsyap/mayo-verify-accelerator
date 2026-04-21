library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mayo_pkg.all;

entity data_storage is
    generic (
        w : positive := 8;
        nibble : positive := 4;
        param_m : positive := 64;
        param_n : positive := 81;
        param_o : positive := 17;
        param_k : positive := 4
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        calc : in std_logic;

        s_wr : in std_logic;
        s_in : in  std_logic_vector(param_n*nibble-1 downto 0);
        s_wr_addr : in std_logic_vector(nibble-1 downto 0);
        s_addr : in std_logic_vector(nibble-1 downto 0);
                
        ps_load : in std_logic;
        ps_mem_load : in std_logic;
        ps_wr : in std_logic;
        mem_wr : in std_logic;

        input_data : in  std_logic_vector(param_m * nibble-1 downto 0);
        col_idx : in std_logic_vector(clog2(param_n)-1 downto 0);
        row_idx : in std_logic_vector(clog2(param_n)-1 downto 0);
        ps_addr : in std_logic_vector(clog2(param_n)-1 downto 0);

        u_out : out std_logic_vector(2*param_m * nibble-1 downto 0)
    );
end data_storage;

architecture behavioral of data_storage is

    constant m_read_bits  : positive := param_m * nibble;

    type N_K_STORE_TYPE is array (0 to param_k-1) of std_logic_vector(param_n*nibble-1 downto 0);
    type M_K_STORE_TYPE is array (0 to param_k-1) of std_logic_vector(param_m*nibble-1 downto 0);
    type M2_K_STORE_TYPE is array (0 to param_k-1) of std_logic_vector(2*m_read_bits-1 downto 0);
    signal s_store : N_K_STORE_TYPE := ( others => ( others => '0' ) );
    signal ps_partial_arr : M_K_STORE_TYPE := ( others => ( others => '0' ) );
    signal u_arr : M2_K_STORE_TYPE := ( others => ( others => '0' ) );
    signal ps_arr : M_K_STORE_TYPE := ( others => ( others => '0' ) );

    signal col_idx_i : integer range 0 to param_n-1;
    signal ps_idx : integer range 0 to param_n-1;
    signal s_wr_idx : integer range 0 to param_k-1;
    signal rd_idx : integer range 0 to param_k-1;

    signal s_sel_i, s_addr_d : std_logic_vector(nibble-1 downto 0);
    signal wr_addr, ps_mem_rd_addr, ps_mem_wr_addr, m_mem_addr, ps_addr_d  : std_logic_vector(clog2(param_n)-1 downto 0);

    constant U_XOR_STAGES : integer := clog2(param_k);
    constant U_XOR_POW2 : integer := 2**U_XOR_STAGES;
    type U_XOR_LEVEL_T is array (0 to U_XOR_POW2-1) of std_logic_vector(2*m_read_bits-1 downto 0);
    type U_XOR_TREE_T is array (0 to U_XOR_STAGES) of U_XOR_LEVEL_T;
    signal u_xor_tree : U_XOR_TREE_T;

begin

    col_idx_i <= to_integer(unsigned(col_idx));
    s_wr_idx <= to_integer(unsigned(s_wr_addr));
    ps_idx <= to_integer(unsigned(ps_addr_d));
    rd_idx <= to_integer(unsigned(s_addr_d));

    ps_mem_rd_addr <= row_idx when calc = '1' else ps_addr;
    ps_mem_wr_addr <= row_idx;

    delayed_regs: process(clk)
    begin
        if rising_edge(clk) then
            ps_addr_d <= ps_addr;
            s_addr_d <= s_addr;
        end if;
    end process;

    s_store_proc : process(clk)
    begin
        if rising_edge(clk) then
            if s_wr = '1' then
                s_store(s_wr_idx) <= s_in;
            end if;
        end if;
    end process;


    gen_ps : for k in 0 to param_k-1 generate
        signal s_sel, s_sel_ps : std_logic_vector(nibble-1 downto 0);
        signal partial_mul, mul_input_data : std_logic_vector(param_m*nibble-1 downto 0);
        signal wr_data, rd_data : std_logic_vector(param_m*nibble-1 downto 0);
    begin
        s_sel_ps <= s_store(k)((param_n-col_idx_i)*nibble-1 downto (param_n-col_idx_i-1)*nibble);

        wr_data <= ps_partial_arr(k);
        
        mul_array_inst : entity work.mul_gf16_array
            generic map(
                m => param_m,
                nibble => nibble
            )
            port map(
                input_data => input_data,
                a => s_sel_ps,
                result => partial_mul
            );

        ps_partial_proc : process(clk)
        begin
            if rising_edge(clk) then
                if ps_load = '1' then
                    ps_partial_arr(k) <= (others => '0');
                elsif ps_mem_load = '1' then
                    ps_partial_arr(k) <= rd_data;
                elsif ps_wr = '1' then
                    ps_partial_arr(k) <= ps_partial_arr(k) xor partial_mul;
                end if;
            end if;
        end process;

        sdp_ram_inst_ps : entity work.sdp_ram
            generic map(
                DATA_WIDTH => param_m*nibble,
                RAM_DEPTH => param_n,
                ADDR_WIDTH => clog2(param_n)
            )
            port map(
                clk_i => clk,
                ena_i => '1',
                enb_i => '1',
                wea_i => mem_wr,
                addra_i => ps_mem_wr_addr,
                addrb_i => ps_mem_rd_addr,
                da_i => wr_data,
                db_o => rd_data
            );

        ps_arr(k) <= rd_data;

    end generate;

    s_sel_i <= s_store(rd_idx)((param_n-ps_idx)*nibble-1 downto (param_n-ps_idx-1)*nibble);

    gen_u : for k in 0 to param_k-1 generate
        signal s_sel_j : std_logic_vector(nibble-1 downto 0);
        signal i_partial_mul_out, j_partial_mul_out : std_logic_vector(param_m*nibble-1 downto 0);
        signal u_temp, u_temp2 : std_logic_vector(param_m*nibble-1 downto 0);
        signal uk_temp : std_logic_vector(2*m_read_bits-1 downto 0);
        constant uk_idx : integer := param_k-1-k;
    begin
        s_sel_j <= s_store(k)((param_n-ps_idx)*nibble-1 downto (param_n-ps_idx-1)*nibble);

        partial_mul_inst1 : entity work.mul_gf16_array
        generic map(
            m => param_m,
            nibble => nibble
        )
        port map(
            input_data => ps_arr(k),
            a => s_sel_i,
            result => i_partial_mul_out
        );

        partial_mul_inst2 : entity work.mul_gf16_array
        generic map(
            m => param_m,
            nibble => nibble
        )
        port map(
            input_data => ps_arr(rd_idx),
            a => s_sel_j,
            result => j_partial_mul_out
        );

        u_temp <= i_partial_mul_out when rd_idx = k else i_partial_mul_out xor j_partial_mul_out;
        u_temp2 <= (others => '0') when rd_idx > k else u_temp;
        uk_temp <= std_logic_vector(resize(unsigned(u_temp2), uk_temp'length));

        u_arr(k) <= std_logic_vector(shift_left(unsigned(uk_temp), uk_idx * nibble));

    end generate;

    gen_u_xor_init : for i in 0 to U_XOR_POW2-1 generate
    begin
        gen_u_xor_init_assign : if i < param_k generate
            u_xor_tree(0)(i) <= u_arr(i);
        end generate;
        gen_u_xor_init_zero : if i >= param_k generate
            u_xor_tree(0)(i) <= (others => '0');
        end generate;
    end generate;

    gen_u_xor_tree : if U_XOR_STAGES > 0 generate
        gen_u_xor_stage : for s in 0 to U_XOR_STAGES-1 generate
            constant STAGE_COUNT : integer := U_XOR_POW2 / (2**(s+1));
        begin
            gen_u_xor_nodes : for i in 0 to U_XOR_POW2-1 generate
            begin
                gen_u_xor_pair : if i < STAGE_COUNT generate
                    u_xor_tree(s+1)(i) <= u_xor_tree(s)(2*i) xor u_xor_tree(s)(2*i+1);
                end generate;
                gen_u_xor_zero : if i >= STAGE_COUNT generate
                    u_xor_tree(s+1)(i) <= (others => '0');
                end generate;
            end generate;
        end generate;
    end generate;

    u_out <= u_xor_tree(U_XOR_STAGES)(0);

end behavioral;
