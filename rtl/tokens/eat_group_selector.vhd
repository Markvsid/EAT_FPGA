-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Stable top-k group selection; earlier group wins ties; no scores rounded to a mean.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_group_selector is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    cmd_valid_i : in std_logic;
    cmd_ready_o : out std_logic;
    cmd_i : in gate_cmd_t;
    done_valid_o : out std_logic;
    done_ready_i : in std_logic;
    status_o : out status_t;
    scores_valid_i : in std_logic;
    scores_ready_o : out std_logic;
    score_i : in group_score_t;
    group_index_i : in natural range 0 to C_MAX_TOKENS/C_GROUP_SIZE-1;
    last_group_i : in std_logic;
    decision_valid_o : out std_logic;
    decision_ready_i : in std_logic;
    decision_o : out group_decision_t
  );
end entity;

architecture rtl of eat_group_selector is
  constant GROUPS : positive := C_MAX_TOKENS/C_GROUP_SIZE;
  type scores_t is array(0 to GROUPS-1) of group_score_t;
  type phase_t is (IDLE,COLLECT,EMIT,DONE);
  signal phase : phase_t := IDLE;
  signal scores : scores_t;
  signal seen : std_logic_vector(GROUPS-1 downto 0) := (others=>'0');
  signal command : gate_cmd_t;
  signal decision : group_decision_t := C_GROUP_DECISION_IDLE;

begin
  cmd_ready_o<=flag(phase=IDLE) and not rst_i;
  scores_ready_o<=flag(phase=COLLECT) and not rst_i;
  decision_valid_o<=flag(phase=EMIT) and not rst_i;
  decision_o<=decision;
  done_valid_o<=flag(phase=DONE) and not rst_i;
  process(clk_i)
    variable all_scores : scores_t;
    variable mask : std_logic_vector(GROUPS-1 downto 0);
    variable count,rank_count,groups_count : natural;
    variable result_decision : group_decision_t;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;seen<=(others=>'0');
      else
        case phase is
          when IDLE => if cmd_valid_i='1' then
            command<=cmd_i;seen<=(others=>'0');status_o<=('1','0','0',ERR_NONE,cmd_i.ctx);
            if cmd_i.tokens=0 or cmd_i.tokens mod C_GROUP_SIZE/=0 or cmd_i.keep_groups>cmd_i.tokens/C_GROUP_SIZE then
              status_o<=('0','1','1',ERR_DIMENSION,cmd_i.ctx);phase<=DONE;
            else phase<=COLLECT;end if;
          end if;
          when COLLECT => if scores_valid_i='1' then
            groups_count:=command.tokens/C_GROUP_SIZE;
            if group_index_i>=groups_count or seen(group_index_i)='1' then
              status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            else
              all_scores:=scores;all_scores(group_index_i):=score_i;scores<=all_scores;
              mask:=seen;mask(group_index_i):='1';seen<=mask;
              count:=0;for i in 0 to GROUPS-1 loop if mask(i)='1' then count:=count+1;end if;end loop;
              if last_group_i='1' or count=groups_count then
                if last_group_i='0' or count/=groups_count then
                  status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
                else
                  result_decision:=C_GROUP_DECISION_IDLE;result_decision.ctx:=command.ctx;
                  for i in 0 to GROUPS-1 loop
                    if i<groups_count then
                      rank_count:=0;
                      for j in 0 to GROUPS-1 loop
                        if j<groups_count and (all_scores(j)>all_scores(i) or (all_scores(j)=all_scores(i) and j<i)) then rank_count:=rank_count+1;end if;
                      end loop;
                      if rank_count<command.keep_groups then result_decision.retained(i):='1';end if;
                    end if;
                  end loop;
                  result_decision.output_tokens:=command.keep_groups*C_GROUP_SIZE;
                  if command.use_rts='1' then result_decision.output_tokens:=result_decision.output_tokens+groups_count-command.keep_groups;end if;
                  decision<=result_decision;phase<=EMIT;
                end if;
              end if;
            end if;
          end if;
          when EMIT => if decision_ready_i='1' then status_o<=('0','1','0',ERR_NONE,command.ctx);phase<=DONE;end if;
          when DONE => if done_ready_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
