-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- AXI4-Lite register front end; independent AW/W buffering, identity and snapshots.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;
use work.eat_registers_pkg.all;

entity eat_axi_ctrl_regs is
  generic (
    G_ALLOW_STUB_SIM : boolean := false
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    s_axi_awaddr_i : in std_logic_vector(C_AXIL_ADDR_BITS-1 downto 0);
    s_axi_awvalid_i : in std_logic;
    s_axi_awready_o : out std_logic;
    s_axi_wdata_i : in std_logic_vector(C_AXIL_DATA_BITS-1 downto 0);
    s_axi_wstrb_i : in std_logic_vector(C_AXIL_DATA_BITS/8-1 downto 0);
    s_axi_wvalid_i : in std_logic;
    s_axi_wready_o : out std_logic;
    s_axi_bresp_o : out std_logic_vector(1 downto 0);
    s_axi_bvalid_o : out std_logic;
    s_axi_bready_i : in std_logic;
    s_axi_araddr_i : in std_logic_vector(C_AXIL_ADDR_BITS-1 downto 0);
    s_axi_arvalid_i : in std_logic;
    s_axi_arready_o : out std_logic;
    s_axi_rdata_o : out std_logic_vector(C_AXIL_DATA_BITS-1 downto 0);
    s_axi_rresp_o : out std_logic_vector(1 downto 0);
    s_axi_rvalid_o : out std_logic;
    s_axi_rready_i : in std_logic;
    request_valid_o : out std_logic;
    request_ready_i : in std_logic;
    request_o : out control_request_t;
    transfer_valid_o : out std_logic;
    transfer_ready_i : in std_logic;
    transfer_o : out transfer_cmd_t;
    status_i : in status_t;
    loaded_identity_i : in identity_t;
    counters_i : in counter_snapshot_t;
    config_o : out control_request_t;
    transfer_config_o : out transfer_cmd_t;
    arm_valid_o : out std_logic;
    arm_ready_i : in std_logic;
    arm_bank_o : out bank_id_t;
    arm_identity_o : out identity_t;
    clear_status_o : out std_logic;
    clear_counters_o : out std_logic;
    selected_bank_valid_i : in std_logic;
    snapshot_id_i : in unsigned(31 downto 0);
    interrupt_o : out std_logic
  );
end entity;

architecture rtl of eat_axi_ctrl_regs is
  signal aw_full,w_full,b_full,r_full : std_logic := '0';
  signal aw_addr : std_logic_vector(C_AXIL_ADDR_BITS-1 downto 0);
  signal w_data : std_logic_vector(31 downto 0);
  signal w_strobe : std_logic_vector(3 downto 0);
  signal config : control_request_t := C_CONTROL_REQUEST_IDLE;
  signal load_address : mem_addr_t := (others=>'0');
  signal load_bytes : unsigned(31 downto 0) := (others=>'0');
  signal load_kind : constant_kind_t := CONST_WEIGHT;
  signal transfer_kind : transfer_kind_t := TRANSFER_CONSTANTS;
  signal req_pending,transfer_pending,arm_pending : std_logic := '0';
  signal sticky_done,sticky_error,incoming_seen : std_logic := '0';
  signal error_code : error_t := ERR_NONE;
  signal counter_latch : counter_snapshot_t := C_COUNTERS_IDLE;
  signal counter_latch_valid : std_logic := '0';
  signal counter_id : unsigned(31 downto 0) := (others=>'0');
  function merge_bytes(old_value,new_value:std_logic_vector(31 downto 0);strobe:std_logic_vector(3 downto 0)) return std_logic_vector is
    variable result:std_logic_vector(31 downto 0):=old_value;
  begin for i in 0 to 3 loop if strobe(i)='1' then result(i*8+7 downto i*8):=new_value(i*8+7 downto i*8);end if;end loop;return result;end;

begin
  s_axi_awready_o<=not aw_full and (not b_full or s_axi_bready_i) and not rst_i;
  s_axi_wready_o<=not w_full and (not b_full or s_axi_bready_i) and not rst_i;
  s_axi_bvalid_o<=b_full and not rst_i;
  s_axi_arready_o<=(not r_full or s_axi_rready_i) and not rst_i;s_axi_rvalid_o<=r_full and not rst_i;
  request_valid_o<=req_pending and not rst_i;transfer_valid_o<=transfer_pending and not rst_i;arm_valid_o<=arm_pending and not rst_i;
  transfer_config_o<=(transfer_kind,load_bytes,load_address,load_kind,(config.inference_id,config.mode,config.workload,config.model_bank));
  config_o<=config;interrupt_o<=(sticky_done or sticky_error) and not rst_i;
  process(clk_i)
    variable address,index,action_count : natural;
    variable value,old_value,read_data : std_logic_vector(31 downto 0);
    variable bad,busy : boolean;
    variable snapshot : counter_snapshot_t;
  begin
    if rising_edge(clk_i) then
      clear_status_o<='0';clear_counters_o<='0';
      if rst_i='1' then
        aw_full<='0';w_full<='0';b_full<='0';r_full<='0';req_pending<='0';transfer_pending<='0';arm_pending<='0';
        config<=C_CONTROL_REQUEST_IDLE;load_address<=(others=>'0');load_bytes<=(others=>'0');load_kind<=CONST_WEIGHT;transfer_kind<=TRANSFER_CONSTANTS;
        sticky_done<='0';sticky_error<='0';incoming_seen<='0';error_code<=ERR_NONE;counter_latch_valid<='0';counter_latch<=C_COUNTERS_IDLE;counter_id<=(others=>'0');
        s_axi_bresp_o<="00";s_axi_rresp_o<="00";s_axi_rdata_o<=(others=>'0');request_o<=C_CONTROL_REQUEST_IDLE;transfer_o<=C_TRANSFER_CMD_IDLE;arm_bank_o<=(others=>'0');arm_identity_o<=(others=>'0');
      else
        busy:=status_i.busy='1' or req_pending='1' or transfer_pending='1' or arm_pending='1';
        if status_i.done='0' and status_i.error='0' then incoming_seen<='0';
        elsif incoming_seen='0' then
          incoming_seen<='1';sticky_done<=status_i.done;
          if status_i.error='1' then sticky_error<='1';error_code<=status_i.code;end if;
        end if;
        if req_pending='1' and request_ready_i='1' then req_pending<='0';end if;
        if transfer_pending='1' and transfer_ready_i='1' then transfer_pending<='0';end if;
        if arm_pending='1' and arm_ready_i='1' then arm_pending<='0';end if;
        if b_full='1' and s_axi_bready_i='1' then b_full<='0';end if;
        if s_axi_awvalid_i='1' and s_axi_awready_o='1' then aw_addr<=s_axi_awaddr_i;aw_full<='1';end if;
        if s_axi_wvalid_i='1' and s_axi_wready_o='1' then w_data<=s_axi_wdata_i;w_strobe<=s_axi_wstrb_i;w_full<='1';end if;
        if aw_full='1' and w_full='1' and (b_full='0' or s_axi_bready_i='1') then
          aw_full<='0';w_full<='0';b_full<='1';s_axi_bresp_o<="00";address:=to_integer(unsigned(aw_addr));bad:=address mod 4/=0;
          if not bad then
            if unsigned(aw_addr)=C_REG_CONTROL then
              value:=merge_bytes(x"00000000",w_data,w_strobe);action_count:=0;
              if value(0)='1' then action_count:=action_count+1;end if;if value(1)='1' then action_count:=action_count+1;end if;if value(4)='1' then action_count:=action_count+1;end if;
              bad:=unsigned(value)>31 or action_count>1 or (busy and unsigned(value)/=0);
              if value(0)='1' and (request_ready_i='0' or sticky_error='1') then bad:=true;end if;
              if value(1)='1' and (transfer_ready_i='0' or sticky_error='1' or load_bytes=0) then bad:=true;end if;
              if value(4)='1' and (arm_ready_i='0' or sticky_error='1') then bad:=true;end if;
              if not bad then
                if value(2)='1' then clear_status_o<='1';sticky_done<='0';sticky_error<='0';error_code<=ERR_NONE;end if;
                if value(3)='1' then clear_counters_o<='1';counter_latch_valid<='0';end if;
                if value(0)='1' then request_o<=config;req_pending<='1';sticky_done<='0';end if;
                if value(1)='1' then transfer_o<=(transfer_kind,load_bytes,load_address,load_kind,(config.inference_id,config.mode,config.workload,config.model_bank));transfer_pending<='1';sticky_done<='0';end if;
                if value(4)='1' then arm_bank_o<=config.model_bank;arm_identity_o<=config.expected_identity;arm_pending<='1';sticky_done<='0';end if;
              end if;
            elsif busy then bad:=true;
            elsif unsigned(aw_addr)=C_REG_MODE then
              value:=merge_bytes(std_logic_vector(to_unsigned(mode_t'pos(config.mode),32)),w_data,w_strobe);
              if unsigned(value)>2 then bad:=true;else config.mode<=mode_t'val(to_integer(unsigned(value)));end if;
            elsif unsigned(aw_addr)=C_REG_MODEL then
              old_value:=(others=>'0');old_value(7 downto 4):=std_logic_vector(config.model_bank);old_value(0):=flag(config.workload=WORKLOAD_SPEECH);value:=merge_bytes(old_value,w_data,w_strobe);
              if (value and x"ffffff0e")/=x"00000000" or unsigned(value(7 downto 4))>=C_MODEL_BANKS then bad:=true;
              else config.model_bank<=unsigned(value(7 downto 4));if value(0)='1' then config.workload<=WORKLOAD_SPEECH;else config.workload<=WORKLOAD_HAR;end if;end if;
            elsif unsigned(aw_addr)=C_REG_INFERENCE_ID then config.inference_id<=unsigned(merge_bytes(std_logic_vector(config.inference_id),w_data,w_strobe));
            elsif address>=to_integer(C_REG_EXPECTED_ID) and address<to_integer(C_REG_EXPECTED_ID)+32 then
              index:=(address-to_integer(C_REG_EXPECTED_ID))/4;config.expected_identity(32*index+31 downto 32*index)<=merge_bytes(config.expected_identity(32*index+31 downto 32*index),w_data,w_strobe);
            elsif unsigned(aw_addr)=C_REG_LOAD_ADDRESS then
              value:=merge_bytes(std_logic_vector(resize(load_address,32)),w_data,w_strobe);if unsigned(value)>=2**C_MEM_ADDR_BITS then bad:=true;else load_address<=resize(unsigned(value),C_MEM_ADDR_BITS);end if;
            elsif unsigned(aw_addr)=C_REG_LOAD_BYTES then load_bytes<=unsigned(merge_bytes(std_logic_vector(load_bytes),w_data,w_strobe));
            elsif unsigned(aw_addr)=C_REG_LOAD_KIND then
              value:=merge_bytes(std_logic_vector(to_unsigned(constant_kind_t'pos(load_kind),32)),w_data,w_strobe);
              if unsigned(value)>constant_kind_t'pos(constant_kind_t'high) then bad:=true;else load_kind<=constant_kind_t'val(to_integer(unsigned(value)));end if;
            elsif unsigned(aw_addr)=C_REG_TRANSFER_KIND then
              value:=merge_bytes(std_logic_vector(to_unsigned(transfer_kind_t'pos(transfer_kind),32)),w_data,w_strobe);
              if unsigned(value)>1 then bad:=true;else transfer_kind<=transfer_kind_t'val(to_integer(unsigned(value)));end if;
            else bad:=true;end if;
          end if;
          if bad then s_axi_bresp_o<="10";end if;
        end if;
        if s_axi_arready_o='1' then
          r_full<=s_axi_arvalid_i;
          if s_axi_arvalid_i='1' then
            address:=to_integer(unsigned(s_axi_araddr_i));bad:=address mod 4/=0;read_data:=(others=>'0');snapshot:=counter_latch;
            if not bad then
              if unsigned(s_axi_araddr_i)=C_REG_CONTROL then null;
              elsif unsigned(s_axi_araddr_i)=C_REG_MODE then read_data:=std_logic_vector(to_unsigned(mode_t'pos(config.mode),32));
              elsif unsigned(s_axi_araddr_i)=C_REG_MODEL then read_data(7 downto 4):=std_logic_vector(config.model_bank);read_data(0):=flag(config.workload=WORKLOAD_SPEECH);
              elsif unsigned(s_axi_araddr_i)=C_REG_STATUS then read_data(0):=flag(busy);read_data(1):=sticky_done;read_data(2):=sticky_error;read_data(3):=selected_bank_valid_i;
              elsif unsigned(s_axi_araddr_i)=C_REG_ERROR then read_data:=std_logic_vector(to_unsigned(error_t'pos(error_code),32));
              elsif unsigned(s_axi_araddr_i)=C_REG_ABI_VERSION then read_data:=C_ABI_VERSION;
              elsif unsigned(s_axi_araddr_i)=C_REG_NUMERIC_VER then read_data:=std_logic_vector(to_unsigned(C_NUMERIC_VERSION,32));
              elsif unsigned(s_axi_araddr_i)=C_REG_INFERENCE_ID then read_data:=std_logic_vector(config.inference_id);
              elsif unsigned(s_axi_araddr_i)=C_REG_LOAD_ADDRESS then read_data:=std_logic_vector(resize(load_address,32));
              elsif unsigned(s_axi_araddr_i)=C_REG_LOAD_BYTES then read_data:=std_logic_vector(load_bytes);
              elsif unsigned(s_axi_araddr_i)=C_REG_LOAD_KIND then read_data:=std_logic_vector(to_unsigned(constant_kind_t'pos(load_kind),32));
              elsif unsigned(s_axi_araddr_i)=C_REG_TRANSFER_KIND then read_data:=std_logic_vector(to_unsigned(transfer_kind_t'pos(transfer_kind),32));
              elsif unsigned(s_axi_araddr_i)=C_REG_OUTPUT_CLASSES then if config.workload=WORKLOAD_HAR then read_data:=std_logic_vector(to_unsigned(6,32));else read_data:=std_logic_vector(to_unsigned(35,32));end if;
              elsif unsigned(s_axi_araddr_i)=C_REG_SNAPSHOT_ID then read_data:=std_logic_vector(snapshot_id_i);counter_latch<=counters_i;counter_id<=snapshot_id_i;counter_latch_valid<='1';
              elsif address>=to_integer(C_REG_EXPECTED_ID) and address<to_integer(C_REG_EXPECTED_ID)+32 then index:=(address-to_integer(C_REG_EXPECTED_ID))/4;read_data:=config.expected_identity(32*index+31 downto 32*index);
              elsif address>=to_integer(C_REG_LOADED_ID) and address<to_integer(C_REG_LOADED_ID)+32 then index:=(address-to_integer(C_REG_LOADED_ID))/4;read_data:=loaded_identity_i(32*index+31 downto 32*index);
              elsif address>=to_integer(C_REG_COUNTER_BASE) and address<to_integer(C_REG_COUNTER_BASE)+8*(counter_event_t'pos(counter_event_t'high)+1) then
                if counter_latch_valid='0' then snapshot:=counters_i;counter_latch<=counters_i;counter_id<=snapshot_id_i;counter_latch_valid<='1';end if;
                index:=(address-to_integer(C_REG_COUNTER_BASE))/8;
                if (address-to_integer(C_REG_COUNTER_BASE)) mod 8=0 then read_data:=std_logic_vector(snapshot(counter_event_t'val(index))(31 downto 0));else read_data:=std_logic_vector(snapshot(counter_event_t'val(index))(63 downto 32));end if;
              else bad:=true;end if;
            end if;
            s_axi_rdata_o<=read_data;s_axi_rresp_o<="00";if bad then s_axi_rresp_o<="10";end if;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
