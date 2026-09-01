with Interfaces;
with System;

private package Flyology_CRC.Native is
   use type System.Address;

   --  AArch64 Advanced SIMD registers are 128 bits wide.  Keeping this
   --  representation private confines the GCC vector ABI to the native leaf.
   type Machine_Vector is array (0 .. 15) of Interfaces.Unsigned_8;
   for Machine_Vector'Alignment use 16;
   pragma Machine_Attribute (Machine_Vector, "vector_type");

   pragma Compile_Time_Error
     (Machine_Vector'Size /= 128, "the CRC native vector must be exactly 128 bits");
   --  The explicit alignment clause above is the representation authority.
   --  GNAT does not classify Alignment as a static expression on every
   --  supported target, so executable tests validate the selected leaf.

   function Compiled return Boolean;

   --  Source need not be aligned, but it must designate 16 readable bytes.
   function Load_16 (Source : System.Address) return Machine_Vector;

   function Xor_128 (Left, Right : Machine_Vector) return Machine_Vector;

   function Reverse_Bytes_128 (Value : Machine_Vector) return Machine_Vector;

   --  The selector suffixes follow the PCLMUL immediate-bit contract:
   --  00 is low/low, 01 high/low, 10 low/high, and 11 high/high. The
   --  executable x86 and AArch64 implementations are authoritative here.
   function Carryless_Multiply_00
     (Left, Right : Machine_Vector) return Machine_Vector;

   function Carryless_Multiply_01
     (Left, Right : Machine_Vector) return Machine_Vector;

   function Carryless_Multiply_10
     (Left, Right : Machine_Vector) return Machine_Vector;

   function Carryless_Multiply_11
     (Left, Right : Machine_Vector) return Machine_Vector;

   function Update_PMULL_16
     (State     : Interfaces.Unsigned_16;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_16
   with Pre => Data'Length >= 128 and then Data'Length mod 128 = 0;

   function Update_PMULL_32
     (State     : Interfaces.Unsigned_32;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_32
   with Pre => Data'Length >= 128 and then Data'Length mod 128 = 0;

   function Update_PMULL_64
     (State     : Interfaces.Unsigned_64;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Interfaces.Unsigned_64
   with Pre => Data'Length >= 128 and then Data'Length mod 128 = 0;

   function Update_PMULL_64_1024_Reflected
     (State  : Interfaces.Unsigned_64;
      Keys   : Folding_Keys;
      Source : System.Address) return Interfaces.Unsigned_64
   with Pre => Source /= System.Null_Address;
   --  Source designates exactly 1,024 readable bytes.  This raw-pointer leaf
   --  is selected only by the Linux non-SHA3 exact-length dispatch, after the
   --  public Byte_Array contract has established that geometry.
   --  These width-specific entry points are the only batch boundary into the
   --  selected +aes leaf.  Callers must first establish PMULL_Available.  State
   --  is the raw algorithm-form register before Final_XOR.
end Flyology_CRC.Native;
