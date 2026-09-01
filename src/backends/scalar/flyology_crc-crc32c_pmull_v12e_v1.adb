package body Flyology_CRC.CRC32C_PMULL_V12E_V1 is
   function Update
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32 is
   begin
      if Data'Length = 0 then
         return State;
      end if;
      raise Program_Error with "the CRC32C PMULL v12e_v1 kernel is unavailable";
   end Update;

   function Update_V12_64_Tail
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32 is
     (if Data'Length >= 448 and then (Data'Length - 256) mod 192 = 0
      then raise Program_Error with "the CRC32C PMULL v12e_v1 kernel is unavailable"
      else State);
   function Update_1024_V12
     (State  : Interfaces.Unsigned_32;
      Source : System.Address) return Interfaces.Unsigned_32 is
      pragma Unreferenced (Source);
   begin
      raise Program_Error with "the CRC32C PMULL v12e_v1 kernel is unavailable";
      return State;
   end Update_1024_V12;
end Flyology_CRC.CRC32C_PMULL_V12E_V1;
