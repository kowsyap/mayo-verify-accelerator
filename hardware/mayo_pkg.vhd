library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package mayo_pkg is

    constant MAYO_W : positive := 8;
    constant MAYO_NIBBLE : positive := 4;

    type mayo_params_t is record
        m : positive;
        n : positive;
        o : positive;
        k : positive;
    end record;
    type shift_rom16_type is array(natural range <>) of integer range 0 to 16;
    type fx_lookup_type is array(0 to 4) of STD_LOGIC_VECTOR(3 downto 0);
    type int_lut_t is array (natural range <>) of integer;
    function get_mayo_params(version: positive) return mayo_params_t;
    function shn(din : std_logic_vector; n : natural; nibble : positive) return std_logic_vector;
    function calc_width16(n : positive) return positive;
    function get_fx_lookup_table(m : positive) return fx_lookup_type;
    function get_shift_rom16(n : positive; x_width : positive) return shift_rom16_type;
    function get_load_rom16(n : positive; word_count : positive; x_width : positive) return shift_rom16_type;
    function make_tri_lut(k : positive) return int_lut_t;
    function clog2(n: integer) return integer;
    function ceil_div(a: integer; b: integer) return integer;

end package mayo_pkg;

package body mayo_pkg is

    function get_mayo_params(version: positive) return mayo_params_t is
    begin
        if version = 1 then
            return (
                m => 64, n => 78, o => 18, k => 4
            );
        else
            return (
                m => 64, n => 81, o => 17, k => 4
            );
        end if;
    end function;

    function shn(din : std_logic_vector; n : natural; nibble : positive) return std_logic_vector is
        variable v : std_logic_vector(din'range);
    begin
        if n = 0 then
            v := din;
        else
            v := (n*nibble-1 downto 0 => '0') & din(din'high downto n*nibble);
        end if;
        return v;
    end function shn;

    function calc_width16(n : positive) return positive is
    begin
        if (n mod 4) = 0 then
            return 2;
        elsif (n mod 2) = 0 then
            return 3;
        else
            return 4;
        end if;
    end function calc_width16;

    function get_fx_lookup_table(m : positive) return fx_lookup_type is
    begin
        case m is
            when 78 =>
                return ("1000","0001","0001","0000","0000");
            when 64 =>
                return ("1000","0000","0010","1000","0000");
            when 108 =>
                return ("1000","0000","0001","0111","0000");
            when 142 =>
                return ("0100","0000","1000","0001","0000");
            when 96 =>
                return ("0010","0010","0000","0010","0000");
            when 128 =>
                return ("0100","1000","0000","0100","0010");
            when others =>
                return ("1000","0000","0010","1000","0000");
        end case;
    end function get_fx_lookup_table;

    function get_shift_rom16(n : positive; x_width : positive) return shift_rom16_type is
        constant rom_size : integer := 2**x_width;
        variable rom : shift_rom16_type(0 to rom_size-1) := (others => 0);
    begin
        case n is
            when 66 =>
                rom := (
                    0 => 16,
                    1 => 2,
                    2 => 4,
                    3 => 6,
                    4 => 8,
                    5 => 10,
                    6 => 12,
                    7 => 14,
                    others => 0
                );
            when 58 =>
                rom := (
                    0 => 16,
                    1 => 10,
                    2 => 4,
                    3 => 14,
                    4 => 8,
                    5 => 2,
                    6 => 12,
                    7 => 6,
                    others => 0
                );
            when 60 =>
                rom := (
                    0 => 16,
                    1 => 12,
                    2 => 8,
                    3 => 4,
                    others => 0
                );
            when 78 | 142 =>
                rom := (
                    0 => 16,
                    1 => 14,
                    2 => 12,
                    3 => 10,
                    4 => 8,
                    5 => 6,
                    6 => 4,
                    7 => 2,
                    others => 0
                );
            when 81 =>
                rom := (
                    0 => 16,
                    1 => 1,
                    2 => 2,
                    3 => 3,
                    4 => 4,
                    5 => 5,
                    6 => 6,
                    7 => 7,
                    8 => 8,
                    9 => 9,
                    10 => 10,
                    11 => 11,
                    12 => 12,
                    13 => 13,
                    14 => 14,
                    15 => 15,
                    others => 0
                );
            when 86 | 118 =>
                rom := (
                    0 => 16,
                    1 => 6,
                    2 => 12,
                    3 => 2,
                    4 => 8,
                    5 => 14,
                    6 => 4,
                    7 => 10,
                    others => 0
                );
            when 90 | 122 =>
                rom := (
                    0 => 16,
                    1 => 10,
                    2 => 4,
                    3 => 14,
                    4 => 8,
                    5 => 2,
                    6 => 12,
                    7 => 6,
                    others => 0
                );
            when 99 =>
                rom := (
                    0 => 16,
                    1 => 3,
                    2 => 6,
                    3 => 9,
                    4 => 12,
                    5 => 15,
                    6 => 2,
                    7 => 5,
                    8 => 8,
                    9 => 11,
                    10 => 14,
                    11 => 1,
                    12 => 4,
                    13 => 7,
                    14 => 10,
                    15 => 13,
                    others => 0
                );
            when 108 =>
                rom := (
                    0 => 16,
                    1 => 12,
                    2 => 8,
                    3 => 4,
                    others => 0
                );
            when 133 =>
                rom := (
                    0 => 16,
                    1 => 5,
                    2 => 10,
                    3 => 15,
                    4 => 4,
                    5 => 9,
                    6 => 14,
                    7 => 3,
                    8 => 8,
                    9 => 13,
                    10 => 2,
                    11 => 7,
                    12 => 12,
                    13 => 1,
                    14 => 6,
                    15 => 11,
                    others => 0
                );
            when 154 =>
                rom := (
                    0 => 16,
                    1 => 10,
                    2 => 4,
                    3 => 14,
                    4 => 8,
                    5 => 2,
                    6 => 12,
                    7 => 6,
                    others => 0
                );
            when others =>
                rom := (others => 0);
        end case;

        return rom;
    end function get_shift_rom16;

    function get_load_rom16(n : positive; word_count : positive; x_width : positive) return shift_rom16_type is
        constant rom_size : integer := 2**x_width;
        variable rom : shift_rom16_type(0 to rom_size-1) := (others => word_count-1);
    begin
        case n is
            when 66 | 81 =>
                rom(1) := word_count;
            when 60 =>
                rom(1) := word_count;
                rom(2) := word_count;
                rom(3) := word_count;
            when 78 | 108 | 142 =>
                rom    := (others => word_count);
                rom(0) := word_count-1;
            when 86 | 118 =>
                rom(1) := word_count;
                rom(3) := word_count;
                rom(6) := word_count;
            when 58 | 90 | 122 | 154 =>
                rom(1)  := word_count;
                rom(2)  := word_count;
                rom(4)  := word_count;
                rom(5)  := word_count;
                rom(7)  := word_count;
            when 99 =>
                rom(1) := word_count;
                rom(6) := word_count;
                rom(11) := word_count;
            when 133 =>
                rom(1)  := word_count;
                rom(4)  := word_count;
                rom(7)  := word_count;
                rom(10) := word_count;
                rom(13) := word_count;
            when others =>
                rom := (others => 0);
        end case;

        return rom;
    end function get_load_rom16;

    function make_tri_lut(k : positive) return int_lut_t is
        variable lut : int_lut_t(0 to k-1);
        variable acc : integer := 0;
    begin
        for r in 0 to k-1 loop
            lut(r) := acc;
            acc := acc + (k - r);
        end loop;
        return lut;
    end function;

    function ceil_div(a: integer; b: integer) return integer is
    begin
        return (a + b - 1) / b;
    end ceil_div;

    function clog2(n: integer) return integer is
    variable m, p: integer;
    begin
        m := 0;
        p := 1;
        while p < n loop
        m := m + 1;
        p := p * 2;
        end loop;
        return m;
    end clog2;

end package body mayo_pkg;
