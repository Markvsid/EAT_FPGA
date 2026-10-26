-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Nearest-even signed numerator/positive denominator division; no truncating divide.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_round_divide is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    numerator_i : in wide_t;
    denominator_i : in unsigned(63 downto 0);
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    quotient_o : out wide_t;
    divide_by_zero_o : out std_logic;
    overflow_o : out std_logic
  );
end entity;

architecture rtl of eat_round_divide is
  type phase_t is (IDLE,DIVIDING,OUTPUT_RESULT);
  signal phase : phase_t := IDLE;
  signal dividend,quotient,den : unsigned(63 downto 0);
  signal remainder_reg : unsigned(64 downto 0);
  signal negative : std_logic;
  signal bit_index : natural range 0 to 63;

begin
  s_ready_o<=flag(phase=IDLE) and not rst_i;
  m_valid_o<=flag(phase=OUTPUT_RESULT) and not rst_i;
  process(clk_i)
    variable n : signed(64 downto 0);
    variable r : unsigned(64 downto 0);
    variable q : unsigned(63 downto 0);
    variable answer : signed(64 downto 0);
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then phase<=IDLE;
      else
        case phase is
          when IDLE =>
            if s_valid_i='1' then
              divide_by_zero_o<='0';overflow_o<='0';
              if denominator_i=0 then
                quotient_o<=(others=>'0');divide_by_zero_o<='1';phase<=OUTPUT_RESULT;
              else
                n:=resize(numerator_i,65); negative<=numerator_i(63);
                if n(64)='1' then dividend<=resize(unsigned(-n),64);else dividend<=unsigned(n(63 downto 0));end if;
                den<=denominator_i;quotient<=(others=>'0');remainder_reg<=(others=>'0');
                bit_index<=63;phase<=DIVIDING;
                -- The Python contract rejects the non-representable absolute INT64 minimum.
                overflow_o<=flag(numerator_i=signed'(x"8000000000000000"));
              end if;
            end if;
          when DIVIDING =>
            r:=shift_left(remainder_reg,1);r(0):=dividend(bit_index);q:=quotient;
            if r>=resize(den,65) then r:=r-resize(den,65);q(bit_index):='1';end if;
            quotient<=q;remainder_reg<=r;
            if bit_index=0 then
              if r>resize(den,65)-r or (r=resize(den,65)-r and q(0)='1') then q:=q+1;end if;
              answer:=signed('0'&q); if negative='1' then answer:=-answer;end if;
              quotient_o<=resize(answer,64);phase<=OUTPUT_RESULT;
            else bit_index<=bit_index-1;end if;
          when OUTPUT_RESULT => if m_ready_i='1' then phase<=IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
