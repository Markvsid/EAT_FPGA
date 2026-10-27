-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- PL transfer counts/routing for PS AXI DMA; not a custom DDR AXI master.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;

entity eat_dma_descriptor_engine is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    cmd_valid_i : in std_logic;
    cmd_ready_o : out std_logic;
    cmd_i : in transfer_cmd_t;
    done_valid_o : out std_logic;
    done_ready_i : in std_logic;
    status_o : out status_t;
    stream_bytes_accepted_i : in unsigned(15 downto 0);
    stream_last_i : in std_logic;
    frame_error_i : in std_logic;
    active_transfer_o : out transfer_cmd_t;
    active_valid_o : out std_logic
  );
end entity;

architecture rtl of eat_dma_descriptor_engine is
  type phase_t is (IDLE,ACTIVE,DONE);
  signal phase : phase_t := IDLE;
  signal command : transfer_cmd_t := C_TRANSFER_CMD_IDLE;
  signal accepted : unsigned(31 downto 0) := (others=>'0');

begin
  cmd_ready_o<=flag(phase=IDLE) and not rst_i;done_valid_o<=flag(phase=DONE) and not rst_i;
  active_transfer_o<=command;active_valid_o<=flag(phase=ACTIVE) and not rst_i;
  process(clk_i)
    variable count:unsigned(32 downto 0);
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;accepted<=(others=>'0');
      else
        case phase is
          when IDLE => if cmd_valid_i='1' then
            command<=cmd_i;accepted<=(others=>'0');
            if cmd_i.bytes=0 then status_o<=('0','1','1',ERR_FRAME,cmd_i.ctx);phase<=DONE;
            else status_o<=('1','0','0',ERR_NONE,cmd_i.ctx);phase<=ACTIVE;end if;
          end if;
          when ACTIVE =>
            count:=resize(accepted,33)+resize(stream_bytes_accepted_i,33);
            if frame_error_i='1' or count>resize(command.bytes,33) or (stream_last_i='1' and (stream_bytes_accepted_i=0 or count/=resize(command.bytes,33))) or
               (stream_last_i='0' and count=resize(command.bytes,33)) then
              status_o<=('0','1','1',ERR_FRAME,command.ctx);phase<=DONE;
            elsif stream_bytes_accepted_i/=0 then
              accepted<=count(31 downto 0);
              if stream_last_i='1' then status_o<=('0','1','0',ERR_NONE,command.ctx);phase<=DONE;end if;
            end if;
          when DONE => if done_ready_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
