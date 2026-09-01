with Ada.Streams;
with Interfaces.C;

package body CRC_Fast_Oracle is
   package C renames Interfaces.C;
   use type C.unsigned;
   use type System.Address;

   pragma Compile_Time_Error (C.unsigned'Size /= 32, "Rust u32 requires a 32-bit C unsigned");
   pragma Compile_Time_Error
     (C.unsigned_long_long'Size /= 64, "Rust u64 requires a 64-bit C unsigned long long");
   pragma Compile_Time_Error
     (C.size_t'Size /= System.Address'Size, "Rust usize and Ada address sizes must match");
   pragma Compile_Time_Error
     (Ada.Streams.Stream_Element'Size /= 8, "Rust u8 requires an 8-bit Ada stream element");

   function Imported_Checksum
     (Kind   : C.unsigned;
      Data   : System.Address;
      Length : C.size_t;
      Output : access C.unsigned_long_long) return C.unsigned
   with Import, Convention => C, External_Name => "flyology_crc_fast_checksum";

   function Imported_Prepare_Benchmark (Kind : C.unsigned) return System.Address
   with Import, Convention => C, External_Name => "flyology_crc_fast_prepare_benchmark";

   function Imported_Benchmark_Checksum
     (Handle : System.Address;
      Data   : System.Address;
      Length : C.size_t) return C.unsigned_long_long
   with Import, Convention => C, External_Name => "flyology_crc_fast_benchmark_checksum";

   function Imported_Combine
     (Kind              : C.unsigned;
      Left, Right       : C.unsigned_long_long;
      Right_Byte_Length : C.unsigned_long_long;
      Output            : access C.unsigned_long_long) return C.unsigned
   with Import, Convention => C, External_Name => "flyology_crc_fast_combine";

   function Imported_Checksum_Custom
     (Width         : C.unsigned;
      Polynomial    : C.unsigned_long_long;
      Initial_Value : C.unsigned_long_long;
      Reflected     : C.unsigned;
      Final_XOR     : C.unsigned_long_long;
      Data          : System.Address;
      Length        : C.size_t;
      Output        : access C.unsigned_long_long) return C.unsigned
   with Import, Convention => C, External_Name => "flyology_crc_fast_checksum_custom";

   function Imported_CRC32_ISCSI
     (Data : System.Address; Length : C.size_t) return C.unsigned
   with Import, Convention => C, External_Name => "flyology_crc_fast_crc32_iscsi";

   function Imported_CRC32_AUTOSAR
     (Data : System.Address; Length : C.size_t) return C.unsigned
   with Import, Convention => C, External_Name => "flyology_crc_fast_crc32_autosar";

   function Imported_CRC32_BZIP2
     (Data : System.Address; Length : C.size_t) return C.unsigned
   with Import, Convention => C, External_Name => "flyology_crc_fast_crc32_bzip2";

   function Imported_CRC32_ISO_HDLC
     (Data : System.Address; Length : C.size_t) return C.unsigned
   with Import, Convention => C, External_Name => "flyology_crc_fast_crc32_iso_hdlc";

   function Imported_CRC64_NVME
     (Data : System.Address; Length : C.size_t) return C.unsigned_long_long
   with Import, Convention => C, External_Name => "flyology_crc_fast_crc64_nvme";

   function Imported_CRC64_ECMA_182
     (Data : System.Address; Length : C.size_t) return C.unsigned_long_long
   with Import, Convention => C, External_Name => "flyology_crc_fast_crc64_ecma_182";

   procedure Require_Success (Status : C.unsigned) is
   begin
      if Status /= 0 then
         raise Program_Error with "crc-fast oracle status" & C.unsigned'Image (Status);
      end if;
   end Require_Success;

   function Checksum
     (Kind : Algorithm_ID;
      Data : Flyology_CRC.Byte_Array) return Value_64 is
      Output : aliased C.unsigned_long_long;
   begin
      Require_Success
        (Imported_Checksum
           (C.unsigned (Kind), Data'Address, C.size_t (Data'Length), Output'Access));
      return Value_64 (Output);
   end Checksum;

   function Prepare_Benchmark (Kind : Algorithm_ID) return Benchmark_Handle is
      Result : constant System.Address := Imported_Prepare_Benchmark (C.unsigned (Kind));
   begin
      if Result = System.Null_Address then
         raise Program_Error with "crc-fast oracle rejected benchmark algorithm" & Kind'Image;
      end if;
      return Result;
   end Prepare_Benchmark;

   function Benchmark_Checksum
     (Handle : Benchmark_Handle;
      Data : Flyology_CRC.Byte_Array) return Value_64 is
   begin
      return Value_64
        (Imported_Benchmark_Checksum
           (Handle, Data'Address, C.size_t (Data'Length)));
   end Benchmark_Checksum;

   function Combine
     (Kind              : Algorithm_ID;
      Left, Right       : Value_64;
      Right_Byte_Length : Flyology_CRC.Byte_Count) return Value_64 is
      Output : aliased C.unsigned_long_long;
   begin
      Require_Success
        (Imported_Combine
           (C.unsigned (Kind),
            C.unsigned_long_long (Left),
            C.unsigned_long_long (Right),
            C.unsigned_long_long (Right_Byte_Length),
            Output'Access));
      return Value_64 (Output);
   end Combine;

   function Checksum_Custom
     (Width         : Positive;
      Polynomial    : Value_64;
      Initial_Value : Value_64;
      Reflected     : Boolean;
      Final_XOR     : Value_64;
      Data          : Flyology_CRC.Byte_Array) return Value_64 is
      Output : aliased C.unsigned_long_long;
   begin
      Require_Success
        (Imported_Checksum_Custom
           (C.unsigned (Width),
            C.unsigned_long_long (Polynomial),
            C.unsigned_long_long (Initial_Value),
            C.unsigned (Boolean'Pos (Reflected)),
            C.unsigned_long_long (Final_XOR),
            Data'Address,
            C.size_t (Data'Length),
            Output'Access));
      return Value_64 (Output);
   end Checksum_Custom;

   function CRC32_AUTOSAR (Data : Flyology_CRC.Byte_Array) return Interfaces.Unsigned_32 is
   begin
      return Interfaces.Unsigned_32 (Imported_CRC32_AUTOSAR (Data'Address, C.size_t (Data'Length)));
   end CRC32_AUTOSAR;

   function CRC32_BZIP2 (Data : Flyology_CRC.Byte_Array) return Interfaces.Unsigned_32 is
   begin
      return Interfaces.Unsigned_32 (Imported_CRC32_BZIP2 (Data'Address, C.size_t (Data'Length)));
   end CRC32_BZIP2;

   function CRC32_ISCSI (Data : Flyology_CRC.Byte_Array) return Interfaces.Unsigned_32 is
   begin
      return Interfaces.Unsigned_32 (Imported_CRC32_ISCSI (Data'Address, C.size_t (Data'Length)));
   end CRC32_ISCSI;

   function CRC32_ISO_HDLC (Data : Flyology_CRC.Byte_Array) return Interfaces.Unsigned_32 is
   begin
      return
        Interfaces.Unsigned_32 (Imported_CRC32_ISO_HDLC (Data'Address, C.size_t (Data'Length)));
   end CRC32_ISO_HDLC;

   function CRC64_ECMA_182 (Data : Flyology_CRC.Byte_Array) return Interfaces.Unsigned_64 is
   begin
      return Interfaces.Unsigned_64 (Imported_CRC64_ECMA_182 (Data'Address, C.size_t (Data'Length)));
   end CRC64_ECMA_182;

   function CRC64_NVME (Data : Flyology_CRC.Byte_Array) return Interfaces.Unsigned_64 is
   begin
      return Interfaces.Unsigned_64 (Imported_CRC64_NVME (Data'Address, C.size_t (Data'Length)));
   end CRC64_NVME;
end CRC_Fast_Oracle;
