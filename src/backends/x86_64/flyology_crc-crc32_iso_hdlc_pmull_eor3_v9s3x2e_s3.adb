package body Flyology_CRC.CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3 is
   function Update
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32 is
     (if Data'Length = 0
      then State
      else raise Program_Error with "the ISO-HDLC EOR3 fusion backend is not compiled");

   function Update_1024_V12
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32 is
     (if Data'Length = 1_024
      then raise Program_Error with "the ISO-HDLC EOR3 v12e_v1 backend is unavailable"
      else State);
end Flyology_CRC.CRC32_ISO_HDLC_PMULL_EOR3_V9S3X2E_S3;
