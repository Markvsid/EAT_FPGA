-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Add bias in accumulator domain, check 40 bits, multiply Q24, round and saturate state.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_requantizer is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    accumulators_i : in acc_vec_t(0 to C_LANES-1);
    bias_i : in acc_vec_t(0 to C_LANES-1);
    multipliers_i : in multiplier_vec_t(0 to C_LANES-1);
    keep_i : in lane_mask_t;
    token_i : in token_index_t;
    feature_base_i : in feature_index_t;
    last_i : in std_logic;
    ctx_i : in context_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t;
    saturation_events_o : out unsigned(15 downto 0);
    overflow_o : out std_logic
  );
end entity;

architecture rtl of eat_requantizer is
  signal full : std_logic := '0';
begin
  s_ready_o <= (not full or m_ready_i) and not rst_i;
  m_valid_o <= full and not rst_i;
  process(clk_i)
    variable total : signed(C_ACC_BITS downto 0);
    variable product : signed(C_ACC_BITS+C_MULT_BITS downto 0);
    variable rounded : signed(C_ACC_BITS+C_MULT_BITS downto 0);
    variable beat : state_beat_t;
    variable events : natural;
    variable bad : boolean;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then full<='0';
      elsif s_ready_o='1' then
        full<=s_valid_i;
        if s_valid_i='1' then
          beat:=C_STATE_BEAT_IDLE;beat.keep:=keep_i;beat.token:=token_i;
          beat.feature_base:=feature_base_i;beat.last:=last_i;beat.ctx:=ctx_i;
          bad:=false;events:=0;
          for i in 0 to C_LANES-1 loop
            if keep_i(i)='1' then
              total:=resize(accumulators_i(i),total'length)+resize(bias_i(i),total'length);
              product:=total*multipliers_i(i);
              bad:=bad or not fits(total,C_ACC_BITS) or not fits(product,63) or multipliers_i(i)<=0;
              rounded:=rshift_even(product,C_MULT_FRAC);
              beat.data(i):=sat(rounded,C_STATE_BITS);
              if not fits(rounded,C_STATE_BITS) then events:=events+1;end if;
            end if;
          end loop;
          m_data_o<=beat;saturation_events_o<=to_unsigned(events,16);overflow_o<=flag(bad);
        end if;
      end if;
    end if;
  end process;
end architecture;
