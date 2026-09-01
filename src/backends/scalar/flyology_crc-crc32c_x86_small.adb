package body Flyology_CRC.CRC32C_X86_Small is
   function Update
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32 is
   begin
      if Data'Length = 0 then
         return State;
      end if;
      raise Program_Error with "the x86-64 CRC32C small kernel is unavailable";
   end Update;

   function Compiled return Boolean is (False);
end Flyology_CRC.CRC32C_X86_Small;
