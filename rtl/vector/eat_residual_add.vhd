-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Rendezvous matching token/feature/context beats; saturating signed24 addition.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_residual_add is
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
    a_valid_i : in std_logic;
    a_ready_o : out std_logic;
    a_data_i : in state_beat_t;
    b_valid_i : in std_logic;
    b_ready_o : out std_logic;
    b_data_i : in state_beat_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t;
    saturation_events_o : out unsigned(15 downto 0)
  );
end entity;

architecture rtl of eat_residual_add is
  type phase_t is (IDLE,RUN,DONE);
  signal phase : phase_t := IDLE;
  signal command : vector_cmd_t := C_VECTOR_CMD_IDLE;
  signal a,b : state_beat_t := C_STATE_BEAT_IDLE;
  signal af,bf,full,inputs_done : std_logic := '0';
  signal token : natural range 0 to C_MAX_TOKENS-1 := 0;
  signal feature : natural range 0 to C_MAX_MATRIX_COLS-1 := 0;

begin
  cmd_ready_o<=flag(phase=IDLE) and not rst_i;done_valid_o<=flag(phase=DONE) and not rst_i;
  a_ready_o<=flag(phase=RUN) and not af and not inputs_done and not rst_i;
  b_ready_o<=flag(phase=RUN) and not bf and not inputs_done and not rst_i;
  m_valid_o<=full and not rst_i;
  process(clk_i)
    variable beat : state_beat_t;
    variable total : signed(C_STATE_BITS downto 0);
    variable events : natural;variable bad : boolean;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then phase<=IDLE;af<='0';bf<='0';full<='0';status_o<=C_STATUS_IDLE;
      else
        if full='1' and m_ready_i='1' then
          full<='0';
          if m_data_o.last='1' then status_o<=('0','1','0',ERR_NONE,command.ctx);phase<=DONE;end if;
        end if;
        case phase is
          when IDLE => if cmd_valid_i='1' then
            command<=cmd_i;token<=0;feature<=0;af<='0';bf<='0';full<='0';inputs_done<='0';
            if cmd_i.tokens=0 or cmd_i.features=0 then status_o<=('0','1','1',ERR_DIMENSION,cmd_i.ctx);phase<=DONE;
            else status_o<=('1','0','0',ERR_NONE,cmd_i.ctx);phase<=RUN;end if;
          end if;
          when RUN =>
            if a_valid_i='1' and a_ready_o='1' then a<=a_data_i;af<='1';end if;
            if b_valid_i='1' and b_ready_o='1' then b<=b_data_i;bf<='1';end if;
            if af='1' and bf='1' and (full='0' or m_ready_i='1') then
              af<='0';bf<='0';events:=0;beat:=a;
              bad:=a.ctx/=b.ctx or a.ctx/=command.ctx or a.token/=b.token or a.token/=token or
                a.feature_base/=b.feature_base or a.feature_base/=feature or a.keep/=b.keep or a.last/=b.last or
                a.last/=flag(token+1=command.tokens and feature+C_LANES>=command.features);
              for i in 0 to C_LANES-1 loop
                if feature+i<command.features then
                  if a.keep(i)/='1' then bad:=true;end if;
                  total:=resize(a.data(i),total'length)+resize(b.data(i),total'length);
                  beat.data(i):=sat(total,C_STATE_BITS);if not fits(total,C_STATE_BITS) then events:=events+1;end if;
                else if a.keep(i)/='0' then bad:=true;end if;beat.data(i):=(others=>'0');end if;
              end loop;
              if bad then status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;full<='0';
              else
                m_data_o<=beat;full<='1';saturation_events_o<=to_unsigned(events,16);
                if beat.last='1' then inputs_done<='1';
                elsif feature+C_LANES>=command.features then feature<=0;token<=token+1;
                else feature<=feature+C_LANES;end if;
              end if;
            end if;
          when DONE => if done_ready_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
