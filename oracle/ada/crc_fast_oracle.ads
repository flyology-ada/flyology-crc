with Flyology_CRC;
with Interfaces;
with System;

package CRC_Fast_Oracle is
   subtype Algorithm_ID is Interfaces.Unsigned_32;
   subtype Value_64 is Interfaces.Unsigned_64;

   function Checksum
     (Kind : Algorithm_ID;
      Data : Flyology_CRC.Byte_Array) return Value_64;

   subtype Benchmark_Handle is System.Address;

   function Prepare_Benchmark (Kind : Algorithm_ID) return Benchmark_Handle;

   function Benchmark_Checksum
     (Handle : Benchmark_Handle;
      Data : Flyology_CRC.Byte_Array) return Value_64;

   function Combine
     (Kind              : Algorithm_ID;
      Left, Right       : Value_64;
      Right_Byte_Length : Flyology_CRC.Byte_Count) return Value_64;

   function Checksum_Custom
     (Width         : Positive;
      Polynomial    : Value_64;
      Initial_Value : Value_64;
      Reflected     : Boolean;
      Final_XOR     : Value_64;
      Data          : Flyology_CRC.Byte_Array) return Value_64;

   function CRC32_AUTOSAR (Data : Flyology_CRC.Byte_Array) return Interfaces.Unsigned_32;
   function CRC32_BZIP2 (Data : Flyology_CRC.Byte_Array) return Interfaces.Unsigned_32;
   function CRC32_ISCSI (Data : Flyology_CRC.Byte_Array) return Interfaces.Unsigned_32;
   function CRC32_ISO_HDLC (Data : Flyology_CRC.Byte_Array) return Interfaces.Unsigned_32;
   function CRC64_ECMA_182 (Data : Flyology_CRC.Byte_Array) return Interfaces.Unsigned_64;
   function CRC64_NVME (Data : Flyology_CRC.Byte_Array) return Interfaces.Unsigned_64;
end CRC_Fast_Oracle;
