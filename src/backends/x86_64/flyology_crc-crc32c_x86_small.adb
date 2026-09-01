--  CRC32C-only geometry for short buffers. The one-shot dispatcher selects
--  this leaf through 256 bytes; that threshold remains in the caller. See
--  THIRD_PARTY_NOTICES.md for implementation provenance.

with System.Machine_Code;
with System.Storage_Elements;

package body Flyology_CRC.CRC32C_X86_Small is
   use System.Machine_Code;
   use type System.Bit_Order;
   use type System.Storage_Elements.Storage_Count;

   subtype U8 is Interfaces.Unsigned_8;
   subtype U32 is Interfaces.Unsigned_32;
   subtype U64 is Interfaces.Unsigned_64;
   subtype Count is System.Storage_Elements.Storage_Count;

   pragma Compile_Time_Error
     (System.Default_Bit_Order /= System.Low_Order_First,
      "the x86-64 CRC32C small kernel requires little-endian byte order");
   pragma Compile_Time_Error
     (System.Word_Size /= 64,
      "the x86-64 CRC32C small kernel requires 64-bit words");

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

   function CRC32C_Byte (CRC : U32; Source : System.Address) return U32 is
      Item : U8 with Import, Address => Source;
      Result : U32 := CRC;
   begin
      --  SSE4.2 CRC32B is not exposed as an Ada intrinsic by GNAT.  Direct
      --  typed inline assembly keeps the instruction in this selected leaf.
      Asm
        (Template => "crc32b %b1, %0",
         Outputs  => U32'Asm_Output ("+r", Result),
         Inputs   => U8'Asm_Input ("m", Item));
      return Result;
   end CRC32C_Byte;
   pragma Inline_Always (CRC32C_Byte);

   function CRC32C_64 (CRC : U32; Source : System.Address) return U32 is
      Item : U64 with Import, Address => Source;
      Result : U32 := CRC;
   begin
      --  CRC32Q writes a zero-extended 32-bit CRC into its 64-bit destination.
      --  The %q modifier names the 64-bit hardware register while the typed
      --  Ada output retains exactly the architecturally meaningful low word.
      Asm
        (Template => "crc32q %1, %q0",
         Outputs  => U32'Asm_Output ("+r", Result),
         Inputs   => U64'Asm_Input ("m", Item));
      return Result;
   end CRC32C_64;
   pragma Inline_Always (CRC32C_64);

   function Update
     (State : U32;
      Data  : Byte_Array) return U32 is
      CRC       : U32 := State;
      Pointer   : System.Address := Data'Address;
      Remaining : Count := Count (Data'Length);
   begin
      --  Match slice::align_to::<u64>: a byte prefix reaches the next
      --  eight-byte address, after which all word loads are aligned.
      while Remaining > 0 and then Alignment (Pointer, 8) /= 0 loop
         CRC := CRC32C_Byte (CRC, Pointer);
         Pointer := Next (Pointer, 1);
         Remaining := Remaining - 1;
      end loop;

      --  Issue eight direct CRC32Q operations per 64-byte group.
      while Remaining >= 64 loop
         CRC := CRC32C_64 (CRC, Pointer);
         CRC := CRC32C_64 (CRC, Next (Pointer, 8));
         CRC := CRC32C_64 (CRC, Next (Pointer, 16));
         CRC := CRC32C_64 (CRC, Next (Pointer, 24));
         CRC := CRC32C_64 (CRC, Next (Pointer, 32));
         CRC := CRC32C_64 (CRC, Next (Pointer, 40));
         CRC := CRC32C_64 (CRC, Next (Pointer, 48));
         CRC := CRC32C_64 (CRC, Next (Pointer, 56));
         Pointer := Next (Pointer, 64);
         Remaining := Remaining - 64;
      end loop;

      while Remaining >= 8 loop
         CRC := CRC32C_64 (CRC, Pointer);
         Pointer := Next (Pointer, 8);
         Remaining := Remaining - 8;
      end loop;

      while Remaining > 0 loop
         CRC := CRC32C_Byte (CRC, Pointer);
         Pointer := Next (Pointer, 1);
         Remaining := Remaining - 1;
      end loop;
      return CRC;
   end Update;

   function Compiled return Boolean is (True);
end Flyology_CRC.CRC32C_X86_Small;
