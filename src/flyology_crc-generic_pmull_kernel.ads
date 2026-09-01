with Interfaces;
with System;

private package Flyology_CRC.Generic_PMULL_Kernel is
   generic
      type Value is mod <>;
      Width : Positive;
      type Vector_Type is private;
      with function Load_16 (Source : System.Address) return Vector_Type;
      with procedure Load_16_Pair_Advance
        (Source        : in out System.Address;
         First, Second : out Vector_Type);
      with procedure Fold_Stripes_8
        (Source      : in out System.Address;
         End_Address : System.Address;
         Reflected   : Boolean;
         Coeff       : Vector_Type;
         X0, X1, X2, X3, X4, X5, X6, X7 : in out Vector_Type);
      Use_Custom_Stripe_Loop : Boolean;
      Use_Custom_Forward_Stripe_Loop : Boolean := False;
      Use_Custom_Initial_Load : Boolean := False;
      with procedure Load_Initial_Stripe_8
        (Source : System.Address;
         X0, X1, X2, X3, X4, X5, X6, X7 : out Vector_Type) is null;
      Use_Custom_Collapse : Boolean := False;
      with procedure Collapse_Stripes_8
        (Keys      : Folding_Keys;
         Reflected : Boolean;
         X0, X1, X2, X3, X4, X5, X6 : Vector_Type;
         Result    : in out Vector_Type) is null;
      with function Xor_128 (Left, Right : Vector_Type) return Vector_Type;
      with function Xor_3
        (First, Second, Third : Vector_Type) return Vector_Type;
      with function Reverse_Bytes_128 (Value : Vector_Type) return Vector_Type;
      with function Shift_Left
        (Value : Vector_Type; Bytes : Natural) return Vector_Type;
      with function Shift_Right
        (Value : Vector_Type; Bytes : Natural) return Vector_Type;
      with function And_128 (Left, Right : Vector_Type) return Vector_Type;
      with function Pair
        (High, Low : Interfaces.Unsigned_64) return Vector_Type;
      with function Lane
        (Item : Vector_Type; High : Boolean) return Interfaces.Unsigned_64;
      with function Carryless_Multiply_00
        (Left, Right : Vector_Type) return Vector_Type;
      with function Carryless_Multiply_01
        (Left, Right : Vector_Type) return Vector_Type;
      with function Carryless_Multiply_10
        (Left, Right : Vector_Type) return Vector_Type;
      with function Carryless_Multiply_11
        (Left, Right : Vector_Type) return Vector_Type;
      Enable_1024_Reflected : Boolean := False;
   package Engine is
      function Update_1024_Reflected
        (State  : Value;
         Keys   : Folding_Keys;
         Source : System.Address) return Value
      with Pre => Width = 64 and then Enable_1024_Reflected;
      --  Fixed-geometry raw-pointer entry for one reflected CRC-64 operation.
      --  Source must designate exactly 1,024 readable bytes.  The selected
      --  native caller establishes that private contract before entering the
      --  optional-instruction leaf.

      function Update_Aligned_Blocks
        (State     : Value;
         Reflected : Boolean;
         Keys      : Folding_Keys;
         Data      : Byte_Array) return Value
      with
        Pre =>
          Width in 16 | 32 | 64
          and then Data'Length >= 128
          and then Data'Length mod 128 = 0;
      --  State is the raw algorithm-form register, before Final_XOR.  In
      --  particular, a reflected CRC-16 initial value has already been bit
      --  reversed by Generic_Core.Create; CRC-32 and CRC-64 values have not.
      --  Data contains one or more complete 128-byte stripes.  Both load
      --  operations are unaligned, so no address-alignment promise is required
      --  from the caller.  Load_16_Pair_Advance is supplied by the selected
      --  architecture leaf so this generic unit contains no native instructions.
      --  Use_Custom_Stripe_Loop lets a register-constrained leaf express that
      --  same fold as one native loop while this unit retains initialization,
      --  collapse, and reduction.  The custom loop is called only when Source
      --  is before End_Address and must advance Source exactly to End_Address.
      --  Use_Custom_Forward_Stripe_Loop restricts that hook to forward input;
      --  reflected input retains the ordinary generated loop unchanged.
      --  Use_Custom_Initial_Load lets a selected leaf load the first complete
      --  stripe without changing byte reversal, initial-state injection,
      --  folding, or reduction.  Every default-disabled instantiation retains
      --  the ordinary load path.
      --  Use_Custom_Collapse lets a selected leaf consume the seven contiguous
      --  key pairs directly while preserving the generic engine's exact
      --  seven-fold order.  Result enters as X7 and leaves as the collapsed
      --  state; the supplied Keys remain caller-owned and unmodified.
   end Engine;
end Flyology_CRC.Generic_PMULL_Kernel;
