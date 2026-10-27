-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Sum actual 20/26/32 token rows, then nearest-even division, independently per feature.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_mean_pool is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    cmd_valid_i : in std_logic;
    cmd_ready_o : out std_logic;
    cmd_i : in vector_cmd_t;
    done_valid_o : out std_logic;
    done_ready_i : in std_logic;
    status_o : out status_t;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in state_beat_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t
  );
end entity;

architecture rtl of eat_mean_pool is
  type phase_t is (IDLE,COLLECT,DIV_START,DIV_WAIT,EMIT,DONE);
  signal phase : phase_t := IDLE;
  signal command : vector_cmd_t := C_VECTOR_CMD_IDLE;
  signal sums : wide_vec_t(0 to C_MAX_MATRIX_COLS-1);
  signal token : natural range 0 to C_MAX_TOKENS-1 := 0;
  signal feature,output_base : natural range 0 to C_MAX_MATRIX_COLS-1 := 0;

  signal results:state_vec_t(0 to C_MAX_MATRIX_COLS-1);
  signal divide_index:natural range 0 to C_MAX_MATRIX_COLS-1:=0;
  signal divide_ready,divide_valid,divide_zero,divide_overflow:std_logic;
  signal divide_result,divide_numerator:wide_t;
begin
  divide_numerator<=sums(divide_index);
  divider:entity work.eat_round_divide(rtl) port map(clk_i=>clk_i,rst_i=>rst_i,s_valid_i=>flag(phase=DIV_START),s_ready_o=>divide_ready,
    numerator_i=>divide_numerator,denominator_i=>to_unsigned(command.tokens,64),m_valid_o=>divide_valid,m_ready_i=>flag(phase=DIV_WAIT),
    quotient_o=>divide_result,divide_by_zero_o=>divide_zero,overflow_o=>divide_overflow);
  cmd_ready_o<=flag(phase=IDLE) and not rst_i;done_valid_o<=flag(phase=DONE) and not rst_i;
  s_ready_o<=flag(phase=COLLECT) and not rst_i;m_valid_o<=flag(phase=EMIT) and not rst_i;
  process(all)
    variable beat : state_beat_t;
    variable value : wide_t;
  begin
    beat:=C_STATE_BEAT_IDLE;beat.feature_base:=output_base;beat.ctx:=command.ctx;
    beat.last:=flag(output_base+C_LANES>=command.features);
    for i in 0 to C_LANES-1 loop
      if output_base+i<command.features then
        beat.data(i):=results(output_base+i);beat.keep(i):='1';
      end if;
    end loop;
    m_data_o<=beat;
  end process;
  process(clk_i)
    variable bad : boolean;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;command<=C_VECTOR_CMD_IDLE;
      else
        case phase is
          when IDLE => if cmd_valid_i='1' then
            command<=cmd_i;sums<=(others=>(others=>'0'));token<=0;feature<=0;output_base<=0;
            if cmd_i.tokens=0 or cmd_i.features=0 then status_o<=('0','1','1',ERR_DIMENSION,cmd_i.ctx);phase<=DONE;
            else status_o<=('1','0','0',ERR_NONE,cmd_i.ctx);phase<=COLLECT;end if;
          end if;
          when COLLECT => if s_valid_i='1' then
            bad:=s_data_i.ctx/=command.ctx or s_data_i.token/=token or s_data_i.feature_base/=feature or
                 s_data_i.last/=flag(token+1=command.tokens and feature+C_LANES>=command.features);
            for i in 0 to C_LANES-1 loop
              if feature+i<command.features then
                if s_data_i.keep(i)/='1' then bad:=true;end if;
                sums(feature+i)<=sums(feature+i)+resize(s_data_i.data(i),64);
              elsif s_data_i.keep(i)/='0' then bad:=true;end if;
            end loop;
            if bad then status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            elsif feature+C_LANES>=command.features then
              if token+1=command.tokens then divide_index<=0;phase<=DIV_START;else token<=token+1;feature<=0;end if;
            else feature<=feature+C_LANES;end if;
          end if;
          when DIV_START => if divide_ready='1' then phase<=DIV_WAIT;end if;
          when DIV_WAIT => if divide_valid='1' then
            if divide_zero='1' or divide_overflow='1' or not fits(divide_result,C_STATE_BITS) then status_o<=('0','1','1',ERR_OVERFLOW,command.ctx);phase<=DONE;
            else
              results(divide_index)<=resize(divide_result,C_STATE_BITS);
              if divide_index+1=command.features then phase<=EMIT;else divide_index<=divide_index+1;phase<=DIV_START;end if;
            end if;
          end if;
          when EMIT => if m_ready_i='1' then
            if output_base+C_LANES>=command.features then status_o<=('0','1','0',ERR_NONE,command.ctx);phase<=DONE;
            else output_base<=output_base+C_LANES;end if;
          end if;
          when DONE => if done_ready_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
