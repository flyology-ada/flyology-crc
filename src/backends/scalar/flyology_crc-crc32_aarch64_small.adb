package body Flyology_CRC.CRC32_AArch64_Small is
   function Update_ISCSI
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32 is
   begin
      if Data'Length = 0 then
         return State;
      end if;
      raise Program_Error with "the AArch64 CRC32C small kernel is unavailable";
   end Update_ISCSI;

   function Update_ISO_HDLC
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32 is
   begin
      if Data'Length = 0 then
         return State;
      end if;
      raise Program_Error with "the AArch64 CRC32 small kernel is unavailable";
   end Update_ISO_HDLC;
end Flyology_CRC.CRC32_AArch64_Small;
