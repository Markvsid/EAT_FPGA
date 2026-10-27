-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Chronological retained groups/summary emission with original-index tracking and actual count.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_token_compactor is
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
    decision_valid_i : in std_logic;
    decision_ready_o : out std_logic;
    decision_i : in group_decision_t;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in state_beat_t;
    m_valid_o : out std_logic;
    m_ready_i : in std_logic;
    m_data_o : out state_beat_t;
    mem_req_valid_o : out std_logic;
    mem_req_ready_i : in std_logic;
    mem_req_o : out mem_req_t;
    mem_rsp_valid_i : in std_logic;
    mem_rsp_ready_o : out std_logic;
    mem_rsp_i : in mem_rsp_t
  );
end entity;

architecture rtl of eat_token_compactor is
  type phase_t is (IDLE,DECISION,COLLECT,SCORE_REQ,SCORE_RSP,SELECT_GROUP,SUMMARIZE,SUM_DIV_START,SUM_DIV_WAIT,EMIT,DONE);
  signal phase : phase_t := IDLE;
  type tokens_t is array(0 to C_MAX_TOKENS-1) of state_vec_t(0 to C_WIDTH-1);
  type scores_t is array(0 to C_MAX_TOKENS-1) of state_t;
  signal tokens : tokens_t;
  signal scores : scores_t;
  signal summary : state_vec_t(0 to C_WIDTH-1);
  signal command : gate_cmd_t := C_GATE_CMD_IDLE;
  signal decision_reg : group_decision_t := C_GROUP_DECISION_IDLE;
  signal input_token,score_token,output_token : natural range 0 to C_MAX_TOKENS-1 := 0;
  signal feature : natural range 0 to C_WIDTH-1 := 0;
  signal group_index : natural range 0 to C_MAX_TOKENS/C_GROUP_SIZE-1 := 0;
  signal retained_token : natural range 0 to C_GROUP_SIZE-1 := 0;
  signal summary_mode : std_logic := '0';

  signal divide_numerator:wide_t;
  signal divide_denominator:unsigned(63 downto 0);
  signal divide_ready,divide_valid,divide_zero,divide_overflow:std_logic;
  signal divide_result:wide_t;
begin
  divider:entity work.eat_round_divide(rtl) port map(clk_i=>clk_i,rst_i=>rst_i,s_valid_i=>flag(phase=SUM_DIV_START),s_ready_o=>divide_ready,
    numerator_i=>divide_numerator,denominator_i=>divide_denominator,m_valid_o=>divide_valid,m_ready_i=>flag(phase=SUM_DIV_WAIT),
    quotient_o=>divide_result,divide_by_zero_o=>divide_zero,overflow_o=>divide_overflow);
  cmd_ready_o<=flag(phase=IDLE) and not rst_i;done_valid_o<=flag(phase=DONE) and not rst_i;
  decision_ready_o<=flag(phase=DECISION) and not rst_i;s_ready_o<=flag(phase=COLLECT) and not rst_i;
  m_valid_o<=flag(phase=EMIT) and not rst_i;
  mem_req_valid_o<=flag(phase=SCORE_REQ) and not rst_i;mem_rsp_ready_o<=flag(phase=SCORE_RSP) and not rst_i;
  mem_req_o<=(to_unsigned(G_SCORE_BASE+score_token,C_MEM_ADDR_BITS),(others=>'0'),x"00",'0',(others=>'0'));
  process(all)
    variable beat : state_beat_t;
  begin
    beat:=C_STATE_BEAT_IDLE;beat.token:=output_token;beat.feature_base:=feature;beat.ctx:=command.ctx;beat.keep:=(others=>'1');
    beat.last:=flag(output_token+1=decision_reg.output_tokens and feature+C_LANES=C_WIDTH);
    for i in 0 to C_LANES-1 loop
      if feature+i<C_WIDTH then
        if summary_mode='1' then beat.data(i):=summary(feature+i);
        else beat.data(i):=tokens(group_index*C_GROUP_SIZE+retained_token)(feature+i);end if;
      end if;
    end loop;
    m_data_o<=beat;
  end process;
  process(clk_i)
    variable count,expected_count : natural;
    variable bad : boolean;
    variable numerator,denominator,importance : signed(63 downto 0);
    variable product : signed(127 downto 0);
    variable value : signed(63 downto 0);
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;
      else
        case phase is
          when IDLE => if cmd_valid_i='1' then
            command<=cmd_i;input_token<=0;feature<=0;score_token<=0;output_token<=0;group_index<=0;retained_token<=0;
            if cmd_i.tokens=0 or cmd_i.tokens mod C_GROUP_SIZE/=0 or cmd_i.keep_groups>cmd_i.tokens/C_GROUP_SIZE or
               G_SCORE_BASE+cmd_i.tokens>2**C_MEM_ADDR_BITS then status_o<=('0','1','1',ERR_DIMENSION,cmd_i.ctx);phase<=DONE;
            else status_o<=('1','0','0',ERR_NONE,cmd_i.ctx);phase<=DECISION;end if;
          end if;
          when DECISION => if decision_valid_i='1' then
            count:=0;bad:=decision_i.ctx/=command.ctx;
            for i in decision_i.retained'range loop
              if decision_i.retained(i)='1' then
                if i>=command.tokens/C_GROUP_SIZE then bad:=true;else count:=count+1;end if;
              end if;
            end loop;
            expected_count:=count*C_GROUP_SIZE;if command.use_rts='1' then expected_count:=expected_count+command.tokens/C_GROUP_SIZE-count;end if;
            if bad or count/=command.keep_groups or expected_count/=decision_i.output_tokens or expected_count=0 then
              status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            else decision_reg<=decision_i;phase<=COLLECT;end if;
          end if;
          when COLLECT => if s_valid_i='1' then
            if s_data_i.ctx/=command.ctx or s_data_i.token/=input_token or s_data_i.feature_base/=feature or s_data_i.keep/=x"ff" or
               s_data_i.last/=flag(input_token+1=command.tokens and feature+C_LANES=C_WIDTH) then
              status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            else
              for i in 0 to C_LANES-1 loop tokens(input_token)(feature+i)<=s_data_i.data(i);end loop;
              if feature+C_LANES=C_WIDTH then
                feature<=0;
                if input_token+1=command.tokens then
                  if command.use_rts='1' and command.keep_groups<command.tokens/C_GROUP_SIZE then phase<=SCORE_REQ;
                  else phase<=SELECT_GROUP;end if;
                else input_token<=input_token+1;end if;
              else feature<=feature+C_LANES;end if;
            end if;
          end if;
          when SCORE_REQ => if mem_req_ready_i='1' then phase<=SCORE_RSP;end if;
          when SCORE_RSP => if mem_rsp_valid_i='1' then
            if mem_rsp_i.error='1' or mem_rsp_i.tag/=0 or not fits(signed(mem_rsp_i.data),C_STATE_BITS) then
              status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);phase<=DONE;
            else
              scores(score_token)<=resize(signed(mem_rsp_i.data),C_STATE_BITS);
              if score_token+1=command.tokens then phase<=SELECT_GROUP;else score_token<=score_token+1;phase<=SCORE_REQ;end if;
            end if;
          end if;
          when SELECT_GROUP =>
            feature<=0;retained_token<=0;
            if decision_reg.retained(group_index)='1' then summary_mode<='0';phase<=EMIT;
            elsif command.use_rts='1' then summary_mode<='1';phase<=SUMMARIZE;
            elsif group_index+1=command.tokens/C_GROUP_SIZE then status_o<=('0','1','0',ERR_NONE,command.ctx);phase<=DONE;
            else group_index<=group_index+1;end if;
          when SUMMARIZE =>
            numerator:=(others=>'0');denominator:=(others=>'0');
            for i in 0 to C_GROUP_SIZE-1 loop
              importance:=resize(scores(group_index*C_GROUP_SIZE+i),64);if importance<0 then importance:=-importance;end if;
              importance:=importance+2**C_STATE_FRAC;denominator:=denominator+importance;
              product:=resize(tokens(group_index*C_GROUP_SIZE+i)(feature),64)*importance;numerator:=numerator+resize(product,64);
            end loop;
            if not fits(numerator,C_SUMMARY_NUM_BITS) or denominator<=0 then status_o<=('0','1','1',ERR_OVERFLOW,command.ctx);phase<=DONE;
            else divide_numerator<=numerator;divide_denominator<=unsigned(denominator);phase<=SUM_DIV_START;end if;
          when SUM_DIV_START => if divide_ready='1' then phase<=SUM_DIV_WAIT;end if;
          when SUM_DIV_WAIT => if divide_valid='1' then
            if divide_zero='1' or divide_overflow='1' or not fits(divide_result,C_STATE_BITS) then status_o<=('0','1','1',ERR_OVERFLOW,command.ctx);phase<=DONE;
            else
              summary(feature)<=resize(divide_result,C_STATE_BITS);
              if feature+1=C_WIDTH then feature<=0;phase<=EMIT;else feature<=feature+1;phase<=SUMMARIZE;end if;
            end if;
          end if;
          when EMIT => if m_ready_i='1' then
            if feature+C_LANES<C_WIDTH then feature<=feature+C_LANES;
            elsif output_token+1=decision_reg.output_tokens then status_o<=('0','1','0',ERR_NONE,command.ctx);phase<=DONE;
            else
              output_token<=output_token+1;feature<=0;
              if summary_mode='0' and retained_token+1<C_GROUP_SIZE then retained_token<=retained_token+1;
              else group_index<=group_index+1;phase<=SELECT_GROUP;end if;
            end if;
          end if;
          when DONE => if done_ready_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
