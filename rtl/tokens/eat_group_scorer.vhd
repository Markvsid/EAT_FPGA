-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Consume shared tensor OP_SCORE results, store token scores and sum exact groups of four.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_group_scorer is
  generic (
    G_ALLOW_STUB_SIM : boolean := false;
    G_SCORE_BASE : natural := 32768
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
    token_scores_valid_i : in std_logic;
    token_scores_ready_o : out std_logic;
    token_scores_i : in state_beat_t;
    scores_valid_o : out std_logic;
    scores_ready_i : in std_logic;
    score_o : out group_score_t;
    group_index_o : out natural range 0 to C_MAX_TOKENS/C_GROUP_SIZE-1;
    last_group_o : out std_logic;
    mem_req_valid_o : out std_logic;
    mem_req_ready_i : in std_logic;
    mem_req_o : out mem_req_t;
    mem_rsp_valid_i : in std_logic;
    mem_rsp_ready_o : out std_logic;
    mem_rsp_i : in mem_rsp_t;
    param_req_valid_o : out std_logic;
    param_req_ready_i : in std_logic;
    param_req_o : out param_req_t;
    param_rsp_valid_i : in std_logic;
    param_rsp_ready_o : out std_logic;
    param_rsp_i : in param_rsp_t
  );
end entity;

architecture rtl of eat_group_scorer is
  type phase_t is (IDLE,COLLECT,WRITE_REQ,WRITE_RSP,EMIT,DONE);
  signal phase : phase_t := IDLE;
  signal command : gate_cmd_t := C_GATE_CMD_IDLE;
  signal token : natural range 0 to C_MAX_TOKENS-1 := 0;
  signal group_sum : group_score_t := (others=>'0');
  signal token_score : state_t;

begin
  cmd_ready_o<=flag(phase=IDLE) and not rst_i;done_valid_o<=flag(phase=DONE) and not rst_i;
  token_scores_ready_o<=flag(phase=COLLECT) and not rst_i;
  scores_valid_o<=flag(phase=EMIT) and not rst_i;
  score_o<=group_sum;group_index_o<=token/C_GROUP_SIZE;last_group_o<=flag(token+1=command.tokens);
  mem_req_valid_o<=flag(phase=WRITE_REQ) and not rst_i;
  mem_req_o<=(to_unsigned(G_SCORE_BASE+token,C_MEM_ADDR_BITS),std_logic_vector(resize(token_score,64)),x"ff",'1',(others=>'0'));
  mem_rsp_ready_o<=flag(phase=WRITE_RSP) and not rst_i;
  param_req_valid_o<='0';param_req_o<=C_PARAM_REQ_IDLE;param_rsp_ready_o<='0';
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;
      else
        case phase is
          when IDLE => if cmd_valid_i='1' then
            command<=cmd_i;token<=0;group_sum<=(others=>'0');
            if cmd_i.tokens=0 or cmd_i.tokens mod C_GROUP_SIZE/=0 or G_SCORE_BASE+cmd_i.tokens>2**C_MEM_ADDR_BITS then
              status_o<=('0','1','1',ERR_DIMENSION,cmd_i.ctx);phase<=DONE;
            else status_o<=('1','0','0',ERR_NONE,cmd_i.ctx);phase<=COLLECT;end if;
          end if;
          when COLLECT => if token_scores_valid_i='1' then
            if token_scores_i.ctx/=command.ctx or token_scores_i.token/=token or token_scores_i.feature_base/=0 or
               token_scores_i.keep/=x"01" or token_scores_i.last/=flag(token+1=command.tokens) then
              status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            else
              token_score<=token_scores_i.data(0);group_sum<=group_sum+resize(token_scores_i.data(0),C_GROUP_SCORE_BITS);phase<=WRITE_REQ;
            end if;
          end if;
          when WRITE_REQ => if mem_req_ready_i='1' then phase<=WRITE_RSP;end if;
          when WRITE_RSP => if mem_rsp_valid_i='1' then
            if mem_rsp_i.error='1' or mem_rsp_i.tag/=0 then status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            elsif (token+1) mod C_GROUP_SIZE=0 then phase<=EMIT;
            else token<=token+1;phase<=COLLECT;end if;
          end if;
          when EMIT => if scores_ready_i='1' then
            if token+1=command.tokens then status_o<=('0','1','0',ERR_NONE,command.ctx);phase<=DONE;
            else token<=token+1;group_sum<=(others=>'0');phase<=COLLECT;end if;
          end if;
          when DONE => if done_ready_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
