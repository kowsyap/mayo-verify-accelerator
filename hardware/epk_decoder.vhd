library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mayo_pkg.all;

entity epk_decoder is
    generic (
        w : positive := 8;
        nibble : positive := 4;
        param_m : positive := 64;
        param_n : positive := 66;
        param_o : positive := 8;
        param_d : positive := 64
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        calc : in std_logic;

        vector_input_valid  : in  std_logic;
        vector_tlast        : in  std_logic;
        vector_input        : in  std_logic_vector(16*nibble-1 downto 0);
        vector_input_ready  : out std_logic;

        p_data : out std_logic_vector(param_m*nibble-1 downto 0);
        col_idx : out std_logic_vector(clog2(param_n)-1 downto 0);
        row_idx : out std_logic_vector(clog2(param_n)-1 downto 0);

        ps_load : out std_logic;
        ps_mem_load : out std_logic;
        ps_wr : out std_logic;
        mem_wr : out std_logic;
        done : out std_logic
    );
end epk_decoder;

architecture structural of epk_decoder is
    signal Li, Ei, Lj, Ej, Lino, Ljno, Lij, Lk, Ek, Efifo : std_logic;
    signal zino, zjno, zin, zjn, zk : std_logic;
begin
    datapath_inst : entity work.epk_decoder_datapath
        generic map (
            w => w,
            nibble => nibble,
            param_m => param_m,
            param_n => param_n,
            param_o => param_o,
            param_d => param_d
        )
        port map (
            clk => clk,
            reset => reset,
            sk => vector_input,
           
            p_data => p_data,
            col_idx => col_idx,
            row_idx => row_idx,

            Li => Li,
            Ei => Ei,
            Lj => Lj,
            Ej => Ej,
            Lino => Lino,
            Ljno => Ljno,
            Lij => Lij,
            Ek => Ek,
            Efifo => Efifo,
            Lk => Lk,
            zino => zino,
            zjno => zjno,
            zin => zin,
            zjn => zjn,
            zk => zk
        );

    controller_inst : entity work.epk_decoder_controller
        port map (
            clk => clk,
            reset => reset,
            calc => calc,
            Li => Li,
            Ei => Ei,
            Lj => Lj,
            Lino => Lino,
            Ljno => Ljno,
            Lij => Lij,
            Ej => Ej,
            Ek => Ek,
            Efifo => Efifo,
            Lk => Lk,

            zino => zino,
            zjno => zjno,
            zin => zin,
            zjn => zjn,
            zk => zk,
            sk_input_ready => vector_input_ready,
            sk_input_valid => vector_input_valid,
            sk_input_tlast => vector_tlast,
            ps_load => ps_load,
            ps_mem_load => ps_mem_load,
            ps_wr => ps_wr,
            mem_wr => mem_wr,
            done => done
        );

end structural;
