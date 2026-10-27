-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Unpack 128-bit TKEEP/TLAST framed input/constant transfers into byte streams.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_axi_stream_input is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_axis_tdata_i : in std_logic_vector(C_AXIS_BITS-1 downto 0);
    s_axis_tkeep_i : in std_logic_vector(C_AXIS_BITS/8-1 downto 0);
    s_axis_tlast_i : in std_logic;
    s_axis_tvalid_i : in std_logic;
    s_axis_tready_o : out std_logic;
    transfer_i : in transfer_cmd_t;
    transfer_valid_i : in std_logic;
    transfer_ready_o : out std_logic;
    clear_i : in std_logic;
    abort_i : in std_logic;
    busy_o : out std_logic;
    raw_valid_o : out std_logic;
    raw_ready_i : in std_logic;
    raw_data_o : out std_logic_vector(63 downto 0);
    raw_keep_o : out std_logic_vector(7 downto 0);
    raw_last_o : out std_logic;
    raw_byte_offset_o : out unsigned(31 downto 0);
    constant_valid_o : out std_logic;
    constant_ready_i : in std_logic;
    constant_data_o : out std_logic_vector(63 downto 0);
    constant_keep_o : out std_logic_vector(7 downto 0);
    constant_last_o : out std_logic;
    frame_error_o : out std_logic
  );
end entity;

architecture rtl of eat_axi_stream_input is
  type phase_t is (IDLE,RECEIVE_PACKET,OUTPUT_WORD,DRAIN_PACKET);
  signal phase : phase_t := IDLE;
  signal command : transfer_cmd_t := C_TRANSFER_CMD_IDLE;
  signal received,buffer_offset : unsigned(31 downto 0) := (others=>'0');
  signal buffer_data : std_logic_vector(C_AXIS_BITS-1 downto 0);
  signal buffer_keep : std_logic_vector(C_AXIS_BITS/8-1 downto 0);
  signal buffer_last,upper_half : std_logic := '0';
  signal error_reg : std_logic := '0';
  signal word_data : std_logic_vector(63 downto 0);
  signal word_keep : std_logic_vector(7 downto 0);
  signal word_last,selected_ready : std_logic;

begin
  assert C_AXIS_BITS=128 report "Ingress ABI2 requires 128-bit AXIS" severity failure;
  transfer_ready_o<=flag(phase=IDLE) and not error_reg and not abort_i and not rst_i;
  busy_o<=flag(phase/=IDLE) and not rst_i;frame_error_o<=error_reg;
  s_axis_tready_o<=flag(phase=RECEIVE_PACKET or phase=DRAIN_PACKET) and not rst_i;
  word_data<=buffer_data(63 downto 0) when upper_half='0' else buffer_data(127 downto 64);
  word_keep<=buffer_keep(7 downto 0) when upper_half='0' else buffer_keep(15 downto 8);
  word_last<=buffer_last and (upper_half or flag(buffer_keep(15 downto 8)=x"00"));
  raw_valid_o<=flag(phase=OUTPUT_WORD and command.kind=TRANSFER_INPUT) and not error_reg and not abort_i and not rst_i;
  constant_valid_o<=flag(phase=OUTPUT_WORD and command.kind=TRANSFER_CONSTANTS) and not error_reg and not abort_i and not rst_i;
  raw_data_o<=word_data;raw_keep_o<=word_keep;raw_last_o<=word_last;
  raw_byte_offset_o<=buffer_offset when upper_half='0' else buffer_offset+8;
  constant_data_o<=word_data;constant_keep_o<=word_keep;constant_last_o<=word_last;
  selected_ready<=raw_ready_i when command.kind=TRANSFER_INPUT else constant_ready_i;
  process(clk_i)
    variable remaining:unsigned(31 downto 0);
    variable count:natural range 0 to 16;
    variable expected_keep:std_logic_vector(15 downto 0);
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then phase<=IDLE;error_reg<='0';received<=(others=>'0');upper_half<='0';
      else
        if clear_i='1' and phase=IDLE then error_reg<='0';end if;
        if abort_i='1' then
          error_reg<='1';
          if phase=IDLE or (phase=OUTPUT_WORD and buffer_last='1') or (s_axis_tvalid_i='1' and s_axis_tready_o='1' and s_axis_tlast_i='1') then phase<=IDLE;
          else phase<=DRAIN_PACKET;end if;
        else
        case phase is
          when IDLE => if transfer_valid_i='1' and transfer_ready_o='1' then
            command<=transfer_i;received<=(others=>'0');
            if transfer_i.bytes=0 then error_reg<='1';else phase<=RECEIVE_PACKET;end if;
          end if;
          when RECEIVE_PACKET => if s_axis_tvalid_i='1' then
            remaining:=command.bytes-received;count:=16;if remaining<16 then count:=to_integer(remaining);end if;
            expected_keep:=(others=>'0');for i in 0 to 15 loop if i<count then expected_keep(i):='1';end if;end loop;
            if s_axis_tkeep_i/=expected_keep or s_axis_tlast_i/=flag(remaining<=16) then
              error_reg<='1';
              if s_axis_tlast_i='1' then phase<=IDLE;else phase<=DRAIN_PACKET;end if;
            else
              buffer_data<=s_axis_tdata_i;buffer_keep<=s_axis_tkeep_i;buffer_last<=s_axis_tlast_i;buffer_offset<=received;
              received<=received+count;upper_half<='0';phase<=OUTPUT_WORD;
            end if;
          end if;
          when OUTPUT_WORD => if selected_ready='1' then
            if upper_half='0' and buffer_keep(15 downto 8)/=x"00" then upper_half<='1';
            elsif buffer_last='1' then phase<=IDLE;else phase<=RECEIVE_PACKET;end if;
          end if;
          when DRAIN_PACKET => if s_axis_tvalid_i='1' and s_axis_tlast_i='1' then phase<=IDLE;end if;
        end case;
        end if;
      end if;
    end if;
  end process;
end architecture;
