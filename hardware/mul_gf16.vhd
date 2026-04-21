library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mul_gf16 is
    Port (
        a : in  STD_LOGIC_VECTOR (3 downto 0);
        b : in  STD_LOGIC_VECTOR (3 downto 0);
        result : out  STD_LOGIC_VECTOR (3 downto 0)
    );
end mul_gf16;

architecture Behavioral of mul_gf16 is
    signal product : STD_LOGIC_VECTOR (6 downto 0);
    signal intermediate1 : STD_LOGIC_VECTOR (5 downto 0);
    signal intermediate2 : STD_LOGIC_VECTOR (4 downto 0);
    signal intermediate3 : STD_LOGIC_VECTOR (3 downto 0);
begin
    product(0) <= (a(0) and b(0));
    product(1) <= (a(0) and b(1)) xor (a(1) and b(0));
    product(2) <= (a(0) and b(2)) xor (a(1) and b(1)) xor (a(2) and b(0));
    product(3) <= (a(0) and b(3)) xor (a(1) and b(2)) xor (a(2) and b(1)) xor (a(3) and b(0));
    product(4) <= (a(1) and b(3)) xor (a(2) and b(2)) xor (a(3) and b(1));
    product(5) <= (a(2) and b(3)) xor (a(3) and b(2));
    product(6) <= (a(3) and b(3));

    intermediate1 <= product(5 downto 0) xor "001100" when product(6)='1' else product(5 downto 0);
    intermediate2 <= intermediate1(4 downto 0) xor "00110" when intermediate1(5)='1' else intermediate1(4 downto 0);
    intermediate3 <= intermediate2(3 downto 0) xor "0011" when intermediate2(4)='1' else intermediate2(3 downto 0);
    result <= intermediate3(3 downto 0);
    
end Behavioral;
