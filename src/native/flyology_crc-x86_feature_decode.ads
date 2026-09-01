with Interfaces;

private package Flyology_CRC.X86_Feature_Decode is
   type Inputs is record
      Maximum_Basic_Leaf : Interfaces.Unsigned_32;
      Leaf_1_ECX         : Interfaces.Unsigned_32;
      Leaf_7_EBX         : Interfaces.Unsigned_32;
      Leaf_7_ECX         : Interfaces.Unsigned_32;
      XCR0               : Interfaces.Unsigned_64;
      XCR0_Was_Read      : Boolean;
   end record;

   type Capabilities is record
      Generic_SSE    : Boolean;
      CRC32C_SSE     : Boolean;
      AVX512_Ternary : Boolean;
      CRC32C_VPCLMUL : Boolean;
      AVX512_VPCLMUL : Boolean;
   end record;

   --  This predicate is the sole authority for executing XGETBV.  Requiring
   --  leaf 7 first avoids an unnecessary optional instruction when no
   --  AVX-512 tier can be selected.
   function XCR0_May_Be_Read
     (Maximum_Basic_Leaf : Interfaces.Unsigned_32;
      Leaf_1_ECX         : Interfaces.Unsigned_32) return Boolean;

   function Decode (Value : Inputs) return Capabilities;
end Flyology_CRC.X86_Feature_Decode;
