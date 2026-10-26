-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Split QKV and quantize Q/K/V independently to INT8 with recorded exponents.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_qkv_quantizer is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    cmd_valid_i : in std_logic;
    cmd_ready_o : out std_logic;
    cmd_i : in attention_cmd_t;
    done_valid_o : out std_logic;
    done_ready_i : in std_logic;
    status_o : out status_t;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in state_beat_t;
    q_valid_o : out std_logic;
    q_ready_i : in std_logic;
    q_data_o : out act_beat_t;
    k_valid_o : out std_logic;
    k_ready_i : in std_logic;
    k_data_o : out act_beat_t;
    v_valid_o : out std_logic;
    v_ready_i : in std_logic;
    v_data_o : out act_beat_t
  );
end entity;

architecture rtl of eat_qkv_quantizer is
  type phase_t is (IDLE,RUN,DONE);
  signal phase : phase_t := IDLE;
  signal command : attention_cmd_t := C_ATTENTION_CMD_IDLE;
  signal full : std_logic := '0';
  signal output_beat : act_beat_t := C_ACT_BEAT_IDLE;
  signal kind : natural range 0 to 2 := 0;
  signal selected_ready : std_logic;
  signal final_input : std_logic := '0';
  signal seen : std_logic_vector(C_MAX_TOKENS*3*C_WIDTH/C_LANES-1 downto 0) := (others=>'0');
  signal count : natural range 0 to C_MAX_TOKENS*3*C_WIDTH/C_LANES := 0;

begin
  cmd_ready_o<=flag(phase=IDLE) and not rst_i;done_valid_o<=flag(phase=DONE) and not rst_i;
  selected_ready<=q_ready_i when kind=0 else k_ready_i when kind=1 else v_ready_i;
  s_ready_o<=flag(phase=RUN) and not full and not final_input and not rst_i;
  q_valid_o<=full and flag(kind=0) and not rst_i;k_valid_o<=full and flag(kind=1) and not rst_i;v_valid_o<=full and flag(kind=2) and not rst_i;
  q_data_o<=output_beat;k_data_o<=output_beat;v_data_o<=output_beat;
  process(clk_i)
    variable beat : act_beat_t;
    variable index,output_kind,shift_amount : natural;
    variable bad : boolean;
    variable value : signed(63 downto 0);
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;full<='0';
      else
        if full='1' and selected_ready='1' then
          full<='0';
          if final_input='1' then status_o<=('0','1','0',ERR_NONE,command.ctx);phase<=DONE;end if;
        end if;
        case phase is
          when IDLE => if cmd_valid_i='1' then
            command<=cmd_i;seen<=(others=>'0');count<=0;final_input<='0';full<='0';
            if cmd_i.tokens=0 or to_integer(cmd_i.q_shift)<0 or to_integer(cmd_i.q_shift)>16 or
               to_integer(cmd_i.k_shift)<0 or to_integer(cmd_i.k_shift)>16 or to_integer(cmd_i.v_shift)<0 or to_integer(cmd_i.v_shift)>16 then
              status_o<=('0','1','1',ERR_DIMENSION,cmd_i.ctx);phase<=DONE;
            else status_o<=('1','0','0',ERR_NONE,cmd_i.ctx);phase<=RUN;end if;
          end if;
          when RUN => if s_valid_i='1' and s_ready_o='1' then
            index:=s_data_i.token*(3*C_WIDTH/C_LANES)+s_data_i.feature_base/C_LANES;
            bad:=s_data_i.ctx/=command.ctx or s_data_i.token>=command.tokens or s_data_i.feature_base mod C_LANES/=0 or s_data_i.keep/=x"ff" or seen(index)='1';
            if s_data_i.last/=flag(s_data_i.token+1=command.tokens and s_data_i.feature_base+C_LANES=3*C_WIDTH) then bad:=true;end if;
            if s_data_i.last='1' and count+1/=command.tokens*3*C_WIDTH/C_LANES then bad:=true;end if;
            if bad then full<='0';status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            else
              output_kind:=s_data_i.feature_base/C_WIDTH;kind<=output_kind;
              shift_amount:=to_integer(command.q_shift);
              if output_kind=1 then shift_amount:=to_integer(command.k_shift);elsif output_kind=2 then shift_amount:=to_integer(command.v_shift);end if;
              beat:=C_ACT_BEAT_IDLE;beat.ctx:=command.ctx;beat.keep:=s_data_i.keep;beat.token:=s_data_i.token;beat.feature_base:=s_data_i.feature_base mod C_WIDTH;
              beat.last:=flag(beat.token+1=command.tokens and beat.feature_base+C_LANES=C_WIDTH);
              for i in 0 to C_LANES-1 loop value:=rshift_even(resize(s_data_i.data(i),64),shift_amount);beat.data(i):=sat(value,C_ACT_BITS);end loop;
              output_beat<=beat;full<='1';final_input<=s_data_i.last;seen(index)<='1';count<=count+1;
            end if;
          end if;
          when DONE => if done_ready_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
