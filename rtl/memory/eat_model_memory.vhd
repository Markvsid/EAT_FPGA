-- ABI2 virtual regions mapped to compact resident-bank RAM. No logical holes stored.
library ieee;use ieee.std_logic_1164.all;use ieee.numeric_std.all;
use work.eat_config_pkg.all;use work.eat_types_pkg.all;use work.eat_math_pkg.all;use work.eat_image_pkg.all;
entity eat_model_memory is
 generic(G_BANKS:positive:=3;G_WORDS_PER_BANK:positive:=90112);
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    req_valid_i : in std_logic;
    req_ready_o : out std_logic;
    req_i : in mem_req_t;
    rsp_valid_o : out std_logic;
    rsp_ready_i : in std_logic;
    rsp_o : out mem_rsp_t
  );
end entity;
architecture rtl of eat_model_memory is
 type lengths_t is array(0 to 8) of natural range 0 to C_IMAGE_BANK_WORDS;
 type banks_t is array(0 to G_BANKS-1) of lengths_t;
 signal counts:banks_t:=(others=>(others=>0));
 signal full:std_logic:='0';
 type ram_t is array(0 to G_BANKS*G_WORDS_PER_BANK-1) of std_logic_vector(63 downto 0);
begin
 assert G_BANKS<=C_MODEL_BANKS and G_WORDS_PER_BANK>=C_IMAGE_PROFILE_WORDS report "Invalid model RAM capacity" severity failure;
 req_ready_o<=(not full or rsp_ready_i) and not rst_i;rsp_valid_o<=full and not rst_i;
 process(clk_i)
  variable ram:ram_t;
  variable bank,offset,physical,relative,kind_index,prefix,total,new_length:natural;
  variable kind:constant_kind_t;
  variable found,bad,write_word:boolean;
 begin
  if rising_edge(clk_i) then
   if rst_i='1' then full<='0';counts<=(others=>(others=>0));rsp_o<=C_MEM_RSP_IDLE;
   elsif req_ready_o='1' then
    full<=req_valid_i;
    if req_valid_i='1' then
     rsp_o<=((others=>'0'),req_i.tag,'0');bank:=to_integer(req_i.address)/C_IMAGE_BANK_WORDS;offset:=to_integer(req_i.address) mod C_IMAGE_BANK_WORDS;
     physical:=0;found:=false;bad:=bank>=G_BANKS;kind:=CONST_PROFILE;relative:=0;kind_index:=0;
     if not bad then
      for candidate in constant_kind_t loop
       if offset>=region_offset(candidate) and offset<region_offset(candidate)+region_words(candidate) then kind:=candidate;relative:=offset-region_offset(candidate);found:=true;end if;
      end loop;
      if not found then bad:=true;
      elsif kind=CONST_PROFILE then
       if relative>=C_IMAGE_PROFILE_WORDS then bad:=true;else physical:=bank*G_WORDS_PER_BANK+relative;end if;
      else
       kind_index:=constant_kind_t'pos(kind);prefix:=C_IMAGE_PROFILE_WORDS;
       for i in 0 to 8 loop if i<kind_index then prefix:=prefix+counts(bank)(i);end if;end loop;
       if relative>=counts(bank)(kind_index) or prefix+relative>=G_WORDS_PER_BANK then bad:=true;
       else physical:=bank*G_WORDS_PER_BANK+prefix+relative;end if;
      end if;
     end if;
     write_word:=req_i.write_enable='1' and req_i.write_strobe/=x"00";
     if not bad and write_word then
      if kind=CONST_PROFILE then
       if req_i.write_strobe/=x"ff" then bad:=true;
       elsif relative>=16 and relative<=24 then
        kind_index:=relative-16;
        if unsigned(req_i.write_data)>region_words(constant_kind_t'val(kind_index)) then bad:=true;
        else
         new_length:=to_integer(unsigned(req_i.write_data));total:=C_IMAGE_PROFILE_WORDS+new_length;
         for i in 0 to 8 loop if i/=kind_index then total:=total+counts(bank)(i);end if;end loop;
         if total>G_WORDS_PER_BANK then bad:=true;else counts(bank)(kind_index)<=new_length;end if;
        end if;
       elsif relative=0 then counts(bank)<=(others=>0);end if;
      elsif req_i.write_strobe/=x"ff" and kind/=CONST_WEIGHT then bad:=true;
      elsif not valid_constant(kind,signed(req_i.write_data)) then bad:=true;end if;
     end if;
     if bad then rsp_o.error<='1';
     elsif req_i.write_enable='1' then
      for byte in 0 to 7 loop if req_i.write_strobe(byte)='1' then ram(physical)(byte*8+7 downto byte*8):=req_i.write_data(byte*8+7 downto byte*8);end if;end loop;
     else rsp_o.data<=ram(physical);end if;
    end if;
   end if;
  end if;
 end process;
end;
