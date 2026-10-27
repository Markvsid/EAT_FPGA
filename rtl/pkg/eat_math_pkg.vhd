library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
package eat_math_pkg is
  function fits(x : signed; bits : positive) return boolean;
  function sat(x : signed; bits : positive) return signed;
  function rshift_even(x : signed; amount : natural) return signed;
  function shift_even(x : signed; amount : integer) return signed;
  function divide_even(n : signed; d : unsigned) return signed;
  function flag(value : boolean) return std_logic;
end package;
package body eat_math_pkg is
  function flag(value : boolean) return std_logic is
  begin if value then return '1'; else return '0'; end if; end;
  function fits(x : signed; bits : positive) return boolean is
  begin
    if bits >= x'length then return true; end if;
    return resize(resize(x,bits),x'length)=x;
  end;
  function sat(x : signed; bits : positive) return signed is
    variable hi,lo : signed(bits-1 downto 0);
  begin
    hi := (others=>'1'); hi(bits-1):='0';
    lo := (others=>'0'); lo(bits-1):='1';
    if fits(x,bits) then return resize(x,bits);
    elsif x(x'high)='1' then return lo; else return hi; end if;
  end;
  function rshift_even(x : signed; amount : natural) return signed is
    variable ext,q : signed(x'length downto 0);
    variable remainder_value,half,mask : unsigned(x'length downto 0);
  begin
    if amount=0 then return x;end if;
    if amount>x'length then return to_signed(0,x'length);end if;
    ext:=resize(x,ext'length);q:=shift_right(ext,amount);
    mask:=(others=>'0');half:=(others=>'0');half(amount-1):='1';
    for i in mask'range loop if i<amount then mask(i):='1';end if;end loop;
    remainder_value:=unsigned(ext) and mask;
    -- Arithmetic shift gives floor division even for negatives. Its low-bit
    -- residue is nonnegative, so one conditional increment gives ties-to-even.
    if remainder_value>half or (remainder_value=half and q(0)='1') then q:=q+1;end if;
    return resize(q,x'length);
  end;
  function shift_even(x : signed; amount : integer) return signed is
  begin
    if amount>=0 then return rshift_even(x,amount);
    else return shift_left(x,-amount); end if;
  end;
  function divide_even(n : signed; d : unsigned) return signed is
    variable ext : signed(n'length downto 0);
    variable mag,den,q,r : unsigned(n'length downto 0);
  begin
    if d=0 then return to_signed(0,n'length); end if;
    ext:=resize(n,ext'length);
    if ext(ext'high)='1' then mag:=unsigned(-ext); else mag:=unsigned(ext); end if;
    den:=resize(d,den'length); q:=mag/den; r:=mag rem den;
    if r>den-r or (r=den-r and q(0)='1') then q:=q+1; end if;
    if n(n'high)='1' then ext:=-signed(q); else ext:=signed(q); end if;
    return resize(ext,n'length);
  end;
end package body;
