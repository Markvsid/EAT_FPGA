-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Round weighted-value numerator times2^20 divided by final normalizer to Q12.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_attention_finalize is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    weighted_state_i : in av_vec_t(0 to C_LANES-1);
    normalizer_i : in normalizer_t;
    keep_i : in lane_mask_t;
    token_i : in token_index_t;
    feature_base_i : in feature_index_t;
    ctx_i : in context_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t;
    overflow_o : out std_logic
  );
end entity;

architecture rtl of eat_attention_finalize is
  signal full : std_logic := '0';
begin
  s_ready_o <= (not full or m_ready_i) and not rst_i;
  m_valid_o <= full and not rst_i;
  process(clk_i)
    variable numerator,result_value : signed(63 downto 0);
    variable beat : state_beat_t;
    variable bad : boolean;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';
      elsif s_ready_o='1' then
        full<=s_valid_i;
        if s_valid_i='1' then
          beat:=C_STATE_BEAT_IDLE;beat.keep:=keep_i;beat.token:=token_i;
          beat.feature_base:=feature_base_i;beat.ctx:=ctx_i;
          bad:=normalizer_i<=0;
          for i in 0 to C_LANES-1 loop
            if keep_i(i)='1' then
              numerator:=shift_left(resize(weighted_state_i(i),64),C_EXP_FRAC);
              result_value:=divide_even(numerator,unsigned(normalizer_i));
              bad:=bad or not fits(numerator,62) or not fits(result_value,C_STATE_BITS);
              beat.data(i):=sat(result_value,C_STATE_BITS);
            end if;
          end loop;
          m_data_o<=beat;overflow_o<=flag(bad);
        end if;
      end if;
    end if;
  end process;
end architecture;
