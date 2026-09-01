--  CRC-only kernels for buffers shorter than 128 bytes. That threshold is
--  dispatch policy, not an arithmetic limit of these functions. See
--  THIRD_PARTY_NOTICES.md for implementation provenance.

with System.Machine_Code;
with System.Storage_Elements;

package body Flyology_CRC.CRC32_AArch64_Small is
   use System.Machine_Code;
   use type System.Bit_Order;
   use type System.Storage_Elements.Storage_Count;

   subtype U8 is Interfaces.Unsigned_8;
   subtype U32 is Interfaces.Unsigned_32;
   subtype U64 is Interfaces.Unsigned_64;
   subtype Count is System.Storage_Elements.Storage_Count;

   pragma Compile_Time_Error
     (System.Default_Bit_Order /= System.Low_Order_First,
      "the AArch64 CRC32 small kernels require little-endian byte order");

   function Next
     (Source : System.Address;
      Bytes  : Count) return System.Address is
     (System.Storage_Elements."+"
        (Source, System.Storage_Elements.Storage_Offset (Bytes)));
   pragma Inline_Always (Next);

   function Alignment
     (Source : System.Address;
      Bytes  : Count) return Count is
     (Count
        (System.Storage_Elements."mod"
           (Source, System.Storage_Elements.Storage_Offset (Bytes))));
   pragma Inline_Always (Alignment);

   function Load_Byte (Source : System.Address) return U32 is
      Item : U8 with Import, Address => Source;
   begin
      return U32 (Item);
   end Load_Byte;
   pragma Inline_Always (Load_Byte);

   function Load_64 (Source : System.Address) return U64 is
      Item : U64 with Import, Address => Source;
   begin
      return Item;
   end Load_64;
   pragma Inline_Always (Load_64);

   function CRC32C_Byte (CRC, Item : U32) return U32 is
      Result : U32;
   begin
      Asm
        (Template => "crc32cb %w0, %w1, %w2",
         Outputs  => U32'Asm_Output ("=&r", Result),
         Inputs   =>
           [U32'Asm_Input ("r", CRC),
            U32'Asm_Input ("r", Item)]);
      return Result;
   end CRC32C_Byte;
   pragma Inline_Always (CRC32C_Byte);

   function CRC32C_64 (CRC : U32; Item : U64) return U32 is
      Result : U32;
   begin
      Asm
        (Template => "crc32cx %w0, %w1, %x2",
         Outputs  => U32'Asm_Output ("=&r", Result),
         Inputs   =>
           [U32'Asm_Input ("r", CRC),
            U64'Asm_Input ("r", Item)]);
      return Result;
   end CRC32C_64;
   pragma Inline_Always (CRC32C_64);

   function CRC32_Byte (CRC, Item : U32) return U32 is
      Result : U32;
   begin
      Asm
        (Template => "crc32b %w0, %w1, %w2",
         Outputs  => U32'Asm_Output ("=&r", Result),
         Inputs   =>
           [U32'Asm_Input ("r", CRC),
            U32'Asm_Input ("r", Item)]);
      return Result;
   end CRC32_Byte;
   pragma Inline_Always (CRC32_Byte);

   function CRC32_64 (CRC : U32; Item : U64) return U32 is
      Result : U32;
   begin
      Asm
        (Template => "crc32x %w0, %w1, %x2",
         Outputs  => U32'Asm_Output ("=&r", Result),
         Inputs   =>
           [U32'Asm_Input ("r", CRC),
            U64'Asm_Input ("r", Item)]);
      return Result;
   end CRC32_64;
   pragma Inline_Always (CRC32_64);

   function Update_ISCSI
     (State : U32;
      Data  : Byte_Array) return U32 is
      CRC       : U32 := State;
      Pointer   : System.Address := Data'Address;
      Remaining : Count := Count (Data'Length);
   begin
      while Remaining > 0 and then Alignment (Pointer, 8) /= 0 loop
         CRC := CRC32C_Byte (CRC, Load_Byte (Pointer));
         Pointer := Next (Pointer, 1);
         Remaining := Remaining - 1;
      end loop;

      --  Eight aligned 64-bit words yield eight direct CRC operations per
      --  64-byte group.
      while Remaining >= 64 loop
         CRC := CRC32C_64 (CRC, Load_64 (Pointer));
         CRC := CRC32C_64 (CRC, Load_64 (Next (Pointer, 8)));
         CRC := CRC32C_64 (CRC, Load_64 (Next (Pointer, 16)));
         CRC := CRC32C_64 (CRC, Load_64 (Next (Pointer, 24)));
         CRC := CRC32C_64 (CRC, Load_64 (Next (Pointer, 32)));
         CRC := CRC32C_64 (CRC, Load_64 (Next (Pointer, 40)));
         CRC := CRC32C_64 (CRC, Load_64 (Next (Pointer, 48)));
         CRC := CRC32C_64 (CRC, Load_64 (Next (Pointer, 56)));
         Pointer := Next (Pointer, 64);
         Remaining := Remaining - 64;
      end loop;

      while Remaining >= 8 loop
         CRC := CRC32C_64 (CRC, Load_64 (Pointer));
         Pointer := Next (Pointer, 8);
         Remaining := Remaining - 8;
      end loop;

      while Remaining > 0 loop
         CRC := CRC32C_Byte (CRC, Load_Byte (Pointer));
         Pointer := Next (Pointer, 1);
         Remaining := Remaining - 1;
      end loop;
      return CRC;
   end Update_ISCSI;

   function Update_ISO_HDLC
     (State : U32;
      Data  : Byte_Array) return U32 is
      CRC       : U32 := State;
      Pointer   : System.Address := Data'Address;
      Remaining : Count := Count (Data'Length);
   begin
      while Remaining > 0 and then Alignment (Pointer, 8) /= 0 loop
         CRC := CRC32_Byte (CRC, Load_Byte (Pointer));
         Pointer := Next (Pointer, 1);
         Remaining := Remaining - 1;
      end loop;

      --  Keep the ISO-HDLC loop geometry identical to the pinned CRC32C path;
      --  only the architectural CRC instruction family differs.
      while Remaining >= 64 loop
         CRC := CRC32_64 (CRC, Load_64 (Pointer));
         CRC := CRC32_64 (CRC, Load_64 (Next (Pointer, 8)));
         CRC := CRC32_64 (CRC, Load_64 (Next (Pointer, 16)));
         CRC := CRC32_64 (CRC, Load_64 (Next (Pointer, 24)));
         CRC := CRC32_64 (CRC, Load_64 (Next (Pointer, 32)));
         CRC := CRC32_64 (CRC, Load_64 (Next (Pointer, 40)));
         CRC := CRC32_64 (CRC, Load_64 (Next (Pointer, 48)));
         CRC := CRC32_64 (CRC, Load_64 (Next (Pointer, 56)));
         Pointer := Next (Pointer, 64);
         Remaining := Remaining - 64;
      end loop;

      while Remaining >= 8 loop
         CRC := CRC32_64 (CRC, Load_64 (Pointer));
         Pointer := Next (Pointer, 8);
         Remaining := Remaining - 8;
      end loop;

      while Remaining > 0 loop
         CRC := CRC32_Byte (CRC, Load_Byte (Pointer));
         Pointer := Next (Pointer, 1);
         Remaining := Remaining - 1;
      end loop;
      return CRC;
   end Update_ISO_HDLC;
end Flyology_CRC.CRC32_AArch64_Small;
