-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Two-pass row norm: mean square, epsilon168, rsqrt LUT/parity, Q14 gamma and saturation.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_rmsnorm is
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
    m_data_o : out state_beat_t;
    param_req_valid_o : out std_logic;
    param_req_ready_i : in std_logic;
    param_req_o : out param_req_t;
    param_rsp_valid_i : in std_logic;
    param_rsp_ready_o : out std_logic;
    param_rsp_i : in param_rsp_t;
    mem_req_valid_o : out std_logic;
    mem_req_ready_i : in std_logic;
    mem_req_o : out mem_req_t;
    mem_rsp_valid_i : in std_logic;
    mem_rsp_ready_o : out std_logic;
    mem_rsp_i : in mem_rsp_t;
    saturation_events_o : out unsigned(15 downto 0)
  );
end entity;

architecture rtl of eat_rmsnorm is

begin
  unit:entity work.eat_vector_engine(rtl) generic map(G_OPERATION=>"rmsnorm")
    port map(clk_i=>clk_i,rst_i=>rst_i,cmd_valid_i=>cmd_valid_i,cmd_ready_o=>cmd_ready_o,cmd_i=>cmd_i,done_valid_o=>done_valid_o,done_ready_i=>done_ready_i,status_o=>status_o,s_valid_i=>s_valid_i,s_ready_o=>s_ready_o,s_data_i=>s_data_i,m_valid_o=>m_valid_o,m_ready_i=>m_ready_i,m_data_o=>m_data_o,param_req_valid_o=>param_req_valid_o,param_req_ready_i=>param_req_ready_i,param_req_o=>param_req_o,param_rsp_valid_i=>param_rsp_valid_i,param_rsp_ready_o=>param_rsp_ready_o,saturation_events_o=>saturation_events_o,param_rsp_i=>param_rsp_i);
  mem_req_valid_o<='0';mem_req_o<=C_MEM_REQ_IDLE;mem_rsp_ready_o<='0';
end architecture;
