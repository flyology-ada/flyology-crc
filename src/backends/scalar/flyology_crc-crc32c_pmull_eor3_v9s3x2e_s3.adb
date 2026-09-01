package body Flyology_CRC.CRC32C_PMULL_EOR3_V9S3X2E_S3 is
   function Update
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32 is
   begin
      if Data'Length = 0 then
         return State;
      end if;
      raise Program_Error with "the CRC32C PMULL/EOR3 v9s3x2e_s3 kernel is unavailable";
   end Update;

   function Update_1024_V12
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32 is
     (if Data'Length = 1_024
      then raise Program_Error with "the CRC32C PMULL/EOR3 v12e_v1 kernel is unavailable"
      else State);
end Flyology_CRC.CRC32C_PMULL_EOR3_V9S3X2E_S3;
