library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;

package mayo_tb_pkg is
  function cpk_file(version_i : positive) return string;
  function msg_file(version_i : positive) return string;
  function sig_file(version_i : positive) return string;
  function epk_file(version_i : positive) return string;
  function param_n_tb(version_i : positive) return positive;
  function trim_int_image(i : integer) return string;
  function kat_file_path(version_i : integer; set_i : integer) return string;
  function starts_with(s : string; p : string) return boolean;
  function strip_spaces(s : string) return string;
  function hex_char_to_nibble(c : character) return std_logic_vector;
  function hex_word_count(hex_s : string) return natural;
  procedure get_hex_word(constant hex_s : in string; constant idx   : in natural; variable w_out : out std_logic_vector);
  procedure free_line(variable l : inout line);
end package;

package body mayo_tb_pkg is

  function cpk_file(version_i : positive) return string is
  begin
    if version_i = 1 then
        return "input_gen_r1_cpk_mayo_2_test.txt";
    elsif version_i = 2 then
        return "input_gen_r2_cpk_mayo_2_test.txt";
    end if;
    return "input_gen_r1_cpk_mayo_2_test.txt";
  end function;

  function epk_file(version_i : positive) return string is
  begin
    if version_i = 1 then
        return "input_gen_r1_epk_mayo_2_test.txt";
    elsif version_i = 2 then
        return "input_gen_r2_epk_mayo_2_test.txt";
    end if;
    return "input_gen_r1_epk_mayo_2_test.txt";
  end function;

  function msg_file(version_i : positive) return string is
  begin
    if version_i = 1 then
       return "input_gen_r1_msg_mayo_2_test.txt";
    elsif version_i = 2 then
        return "input_gen_r2_msg_mayo_2_test.txt";
    end if;
    return "input_gen_r1_msg_mayo_2_test.txt";
  end function;

  function sig_file(version_i : positive) return string is
  begin
    if version_i = 1 then
        return "input_gen_r1_sig_mayo_2_test.txt";
    elsif version_i = 2 then
        return "input_gen_r2_sig_mayo_2_test.txt";
    end if;
    return "input_gen_r1_sig_mayo__test.txt";
  end function;

  function param_n_tb(version_i : positive) return positive is
  begin
    if version_i = 1 then
      return 78;
    elsif version_i = 2 then
      return 81;
    end if;
    return 66;
  end function;

  function trim_int_image(i : integer) return string is
    constant s : string := integer'image(i);
    variable p : integer := s'low;
  begin
    while p <= s'high and s(p) = ' ' loop
      p := p + 1;
    end loop;
    return s(p to s'high);
  end function;

  function kat_file_path(version_i : integer; set_i : integer) return string is
  begin
    return "KAT_R" & trim_int_image(version_i) & "_S" & trim_int_image(set_i) & ".kat";
  end function;

  function starts_with(s : string; p : string) return boolean is
  begin
    if s'length < p'length then
      return false;
    end if;
    return s(s'low to s'low + p'length - 1) = p;
  end function;

  function strip_spaces(s : string) return string is
    variable t : string(1 to s'length);
    variable n : natural := 0;
  begin
    for i in s'range loop
      if s(i) /= ' ' and s(i) /= HT and s(i) /= CR and s(i) /= LF then
        n := n + 1;
        t(n) := s(i);
      end if;
    end loop;
    if n = 0 then
      return "";
    end if;
    return t(1 to n);
  end function;

  function hex_char_to_nibble(c : character) return std_logic_vector is
    variable o : std_logic_vector(3 downto 0);
  begin
    case c is
      when '0' => o := "0000";
      when '1' => o := "0001";
      when '2' => o := "0010";
      when '3' => o := "0011";
      when '4' => o := "0100";
      when '5' => o := "0101";
      when '6' => o := "0110";
      when '7' => o := "0111";
      when '8' => o := "1000";
      when '9' => o := "1001";
      when 'A' | 'a' => o := "1010";
      when 'B' | 'b' => o := "1011";
      when 'C' | 'c' => o := "1100";
      when 'D' | 'd' => o := "1101";
      when 'E' | 'e' => o := "1110";
      when 'F' | 'f' => o := "1111";
      when others => o := "0000";
    end case;
    return o;
  end function;

  function hex_word_count(hex_s : string) return natural is
  begin
    if hex_s'length = 0 then
      return 0;
    end if;
    return (hex_s'length + 15) / 16;
  end function;

  procedure get_hex_word(
    constant hex_s : in string;
    constant idx   : in natural;
    variable w_out : out std_logic_vector
  ) is
    variable src_pos : integer;
    variable nib     : std_logic_vector(3 downto 0);
    constant word_nibbles : natural := w_out'length / 4;
  begin
    w_out := (others => '0');
    for n in 0 to integer(word_nibbles)-1 loop
      src_pos := idx * word_nibbles + n + 1;
      if src_pos <= hex_s'length then
        nib := hex_char_to_nibble(hex_s(src_pos));
        w_out(w_out'left - 4*n downto w_out'left - 3 - 4*n) := nib;
      else
        w_out(w_out'left - 4*n downto w_out'left - 3 - 4*n) := "0000";
      end if;
    end loop;
  end procedure;

  procedure free_line(variable l : inout line) is
  begin
    if l /= null then
      deallocate(l);
    end if;
  end procedure;
end package body;
