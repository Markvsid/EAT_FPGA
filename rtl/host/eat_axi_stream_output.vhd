-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Pack class-order signed24 logits into sign-extended 32-bit words; TLAST on final word.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_axi_stream_output is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in state_beat_t;
    classes_i : in natural range 0 to C_MAX_CLASSES;
    output_accepted_o : out std_logic;
    m_axis_tdata_o : out std_logic_vector(C_AXIS_BITS-1 downto 0);
    m_axis_tkeep_o : out std_logic_vector(C_AXIS_BITS/8-1 downto 0);
    m_axis_tlast_o : out std_logic;
    m_axis_tvalid_o : out std_logic;
    m_axis_tready_i : in std_logic
  );
end entity;

architecture rtl of eat_axi_stream_output is
  signal busy : std_logic := '0';
  signal beat : state_beat_t := C_STATE_BEAT_IDLE;
  signal classes : natural range 0 to C_MAX_CLASSES := 0;
  signal upper_half : std_logic := '0';
  signal final_beat : std_logic;

begin
  s_ready_o<=not busy and not rst_i and flag(classes_i>0);
  m_axis_tvalid_o<=busy and not rst_i;
  final_beat<=flag(beat.feature_base+4>=classes) when upper_half='0' else flag(beat.feature_base+8>=classes);
  m_axis_tlast_o<=final_beat;
  process(all)
    variable base,index : natural;
  begin
    base:=0;if upper_half='1' then base:=4;end if;
    m_axis_tdata_o<=(others=>'0');m_axis_tkeep_o<=(others=>'0');
    for lane in 0 to 3 loop
      index:=base+lane;
      if beat.feature_base+index<classes and beat.keep(index)='1' then
        m_axis_tdata_o(32*lane+31 downto 32*lane)<=std_logic_vector(resize(beat.data(index),32));
        m_axis_tkeep_o(4*lane+3 downto 4*lane)<=(others=>'1');
      end if;
    end loop;
  end process;
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then busy<='0';upper_half<='0';output_accepted_o<='0';
      else
        output_accepted_o<='0';
        if s_valid_i='1' and s_ready_o='1' then
          beat<=s_data_i;classes<=classes_i;upper_half<='0';busy<='1';
          assert s_data_i.feature_base mod 8=0 and s_data_i.feature_base<classes_i report "Invalid classifier feature base" severity failure;
          for i in 0 to 7 loop
            assert s_data_i.keep(i)=flag(s_data_i.feature_base+i<classes_i) report "Invalid classifier mask" severity failure;
          end loop;
        elsif busy='1' and m_axis_tready_i='1' then
          if final_beat='1' then busy<='0';output_accepted_o<='1';
          elsif upper_half='0' then upper_half<='1';
          else busy<='0';end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
