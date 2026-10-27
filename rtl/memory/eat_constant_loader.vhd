-- Functional VHDL-2008; synchronous reset and accepted-transfer state updates.
-- Range-check 64-bit containers, populate banks, attach host-verified identity; no SHA engine.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eat_config_pkg.all;
use work.eat_types_pkg.all;
use work.eat_math_pkg.all;
use work.eat_image_pkg.all;

entity eat_constant_loader is
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
    s_valid_i : in std_logic;
    s_ready_o : out std_logic;
    s_data_i : in std_logic_vector(63 downto 0);
    s_keep_i : in std_logic_vector(7 downto 0);
    s_last_i : in std_logic;
    identity_i : in identity_t;
    arm_valid_i : in std_logic;
    arm_ready_o : out std_logic;
    arm_bank_i : in bank_id_t;
    arm_identity_i : in identity_t;
    identity_bank_i : in bank_id_t;
    loaded_identity_o : out identity_t;
    bank_valid_o : out std_logic_vector(C_MODEL_BANKS-1 downto 0);
    mem_req_valid_o : out std_logic;
    mem_req_ready_i : in std_logic;
    mem_req_o : out mem_req_t;
    mem_rsp_valid_i : in std_logic;
    mem_rsp_ready_o : out std_logic;
    mem_rsp_i : in mem_rsp_t
  );
end entity;

architecture rtl of eat_constant_loader is
  type phase_t is (IDLE,ACCEPT_WORD,WRITE_REQ,WRITE_RSP,DONE);
  signal phase : phase_t := IDLE;
  type identities_t is array(0 to C_MODEL_BANKS-1) of identity_t;
  type contexts_t is array(0 to C_MODEL_BANKS-1) of context_t;
  type counts_t is array(constant_kind_t) of natural range 0 to C_IMAGE_BANK_WORDS;
  type bank_counts_t is array(0 to C_MODEL_BANKS-1) of counts_t;
  signal identities : identities_t := (others=>(others=>'0'));
  signal contexts : contexts_t := (others=>C_CONTEXT_IDLE);
  signal expected,progress : bank_counts_t := (others=>(others=>0));
  signal valid_banks,profile_ready : std_logic_vector(C_MODEL_BANKS-1 downto 0) := (others=>'0');
  signal profile : profile_t := (others=>(others=>'0'));
  signal command : transfer_cmd_t := C_TRANSFER_CMD_IDLE;
  signal transfer_identity : identity_t := (others=>'0');
  signal index : natural range 0 to C_IMAGE_BANK_WORDS-1 := 0;
  signal words : natural range 0 to C_IMAGE_BANK_WORDS := 0;
  signal write_data : std_logic_vector(63 downto 0);

begin
  cmd_ready_o<=flag(phase=IDLE) and not rst_i;
  arm_ready_o<=flag(phase=IDLE) and not cmd_valid_i and not rst_i;
  done_valid_o<=flag(phase=DONE) and not rst_i;s_ready_o<=flag(phase=ACCEPT_WORD) and not rst_i;
  mem_req_valid_o<=flag(phase=WRITE_REQ) and not rst_i;mem_rsp_ready_o<=flag(phase=WRITE_RSP) and not rst_i;
  bank_valid_o<=valid_banks;
  loaded_identity_o<=identities(to_integer(identity_bank_i)) when to_integer(identity_bank_i)<C_MODEL_BANKS else (others=>'0');
  process(all)
    variable request:mem_req_t;variable offset:mem_addr_t;
  begin
    request:=C_MEM_REQ_IDLE;offset:=command.address+index;
    if to_integer(command.ctx.model_bank)<C_MODEL_BANKS and to_integer(offset)<region_words(command.constant_kind) then
      request.address:=image_address(command.constant_kind,command.ctx.model_bank,offset);
    end if;
    request.write_data:=write_data;request.write_strobe:=x"ff";request.write_enable:='1';mem_req_o<=request;
  end process;
  process(clk_i)
    variable bank,count,offset : natural;
    variable ready : boolean;
  begin
    if rising_edge(clk_i) then
      if rst_i='1' then
        phase<=IDLE;status_o<=C_STATUS_IDLE;valid_banks<=(others=>'0');profile_ready<=(others=>'0');
        expected<=(others=>(others=>0));progress<=(others=>(others=>0));identities<=(others=>(others=>'0'));
      else
        case phase is
          when IDLE =>
            if cmd_valid_i='1' then
              command<=cmd_i;transfer_identity<=identity_i;index<=0;status_o<=('1','0','0',ERR_NONE,cmd_i.ctx);
              bank:=to_integer(cmd_i.ctx.model_bank);
              if bank>=C_MODEL_BANKS or cmd_i.kind/=TRANSFER_CONSTANTS or cmd_i.bytes=0 or cmd_i.bytes>region_words(cmd_i.constant_kind)*8 or cmd_i.bytes(2 downto 0)/="000" then
                status_o<=('0','1','1',ERR_LOAD_RANGE,cmd_i.ctx);phase<=DONE;
              else
                valid_banks(bank)<='0';count:=to_integer(shift_right(cmd_i.bytes,3));words<=count;offset:=to_integer(cmd_i.address);
                if cmd_i.constant_kind=CONST_PROFILE then
                  profile_ready(bank)<='0';expected(bank)<=(others=>0);progress(bank)<=(others=>0);identities(bank)<=identity_i;contexts(bank)<=cmd_i.ctx;
                  if offset/=0 or count/=C_IMAGE_PROFILE_WORDS then status_o<=('0','1','1',ERR_LOAD_RANGE,cmd_i.ctx);phase<=DONE;
                  else profile<=(others=>(others=>'0'));phase<=ACCEPT_WORD;end if;
                elsif profile_ready(bank)='0' or identity_i/=identities(bank) or cmd_i.ctx.mode/=contexts(bank).mode or cmd_i.ctx.workload/=contexts(bank).workload then
                  status_o<=('0','1','1',ERR_IDENTITY,cmd_i.ctx);profile_ready(bank)<='0';phase<=DONE;
                elsif offset/=progress(bank)(cmd_i.constant_kind) or offset+count>expected(bank)(cmd_i.constant_kind) then
                  status_o<=('0','1','1',ERR_LOAD_RANGE,cmd_i.ctx);profile_ready(bank)<='0';phase<=DONE;
                else phase<=ACCEPT_WORD;end if;
              end if;
            elsif arm_valid_i='1' then
              bank:=to_integer(arm_bank_i);
              status_o<=C_STATUS_IDLE;status_o.done<='1';phase<=DONE;
              if bank>=C_MODEL_BANKS then status_o.error<='1';status_o.code<=ERR_IDENTITY;
              else
                ready:=profile_ready(bank)='1' and identities(bank)=arm_identity_i;
                for kind in constant_kind_t loop if expected(bank)(kind)/=progress(bank)(kind) then ready:=false;end if;end loop;
                status_o.ctx<=contexts(bank);
                if ready then valid_banks(bank)<='1';else valid_banks(bank)<='0';status_o.error<='1';status_o.code<=ERR_IDENTITY;end if;
              end if;
            end if;
          when ACCEPT_WORD => if s_valid_i='1' then
            bank:=to_integer(command.ctx.model_bank);
            if s_keep_i/=x"ff" or s_last_i/=flag(index+1=words) then
              status_o<=('0','1','1',ERR_FRAME,command.ctx);profile_ready(bank)<='0';phase<=DONE;
            elsif not valid_constant(command.constant_kind,signed(s_data_i)) then
              status_o<=('0','1','1',ERR_LOAD_RANGE,command.ctx);profile_ready(bank)<='0';phase<=DONE;
            else
              write_data<=s_data_i;
              if command.constant_kind=CONST_PROFILE then profile(index)<=signed(s_data_i);end if;
              phase<=WRITE_REQ;
            end if;
          end if;
          when WRITE_REQ => if mem_req_ready_i='1' then phase<=WRITE_RSP;end if;
          when WRITE_RSP => if mem_rsp_valid_i='1' then
            bank:=to_integer(command.ctx.model_bank);
            if mem_rsp_i.error='1' or mem_rsp_i.tag/=0 then status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);profile_ready(bank)<='0';phase<=DONE;
            elsif index+1=words then
              if command.constant_kind=CONST_PROFILE then
                if not valid_profile(profile,transfer_identity) or number(profile,3)/=workload_t'pos(command.ctx.workload) or number(profile,4)/=mode_t'pos(command.ctx.mode) then
                  status_o<=('0','1','1',ERR_PROTOCOL,command.ctx);profile_ready(bank)<='0';
                else
                  for kind in constant_kind_t loop
                    if kind=CONST_PROFILE then expected(bank)(kind)<=C_IMAGE_PROFILE_WORDS;progress(bank)(kind)<=C_IMAGE_PROFILE_WORDS;
                    else expected(bank)(kind)<=number(profile,16+constant_kind_t'pos(kind));end if;
                  end loop;
                  profile_ready(bank)<='1';status_o<=('0','1','0',ERR_NONE,command.ctx);
                end if;
              else
                progress(bank)(command.constant_kind)<=progress(bank)(command.constant_kind)+words;status_o<=('0','1','0',ERR_NONE,command.ctx);
              end if;
              phase<=DONE;
            else index<=index+1;phase<=ACCEPT_WORD;end if;
          end if;
          when DONE => if done_ready_i='1' then phase<=IDLE;status_o<=C_STATUS_IDLE;end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
