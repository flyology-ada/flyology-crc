package body Flyology_CRC.CRC32C_X86_AVX512_PCLMUL_V4S3X3 is
   function Update
     (State : Interfaces.Unsigned_32;
      Data  : Byte_Array) return Interfaces.Unsigned_32 is
   begin
      if Data'Length = 0 then
         return State;
      end if;
      raise Program_Error with "the x86-64 CRC32C AVX-512 fusion kernel is unavailable";
   end Update;

   function Compiled return Boolean is (False);
end Flyology_CRC.CRC32C_X86_AVX512_PCLMUL_V4S3X3;
