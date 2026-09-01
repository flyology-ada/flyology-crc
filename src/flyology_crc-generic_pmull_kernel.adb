--  Generic eight-lane GF(2) folding and Barrett reduction. The mathematical
--  and implementation provenance is recorded in THIRD_PARTY_NOTICES.md.

with System.Storage_Elements;

package body Flyology_CRC.Generic_PMULL_Kernel is
   package body Engine is
      use type Interfaces.Unsigned_64;
      use type System.Address;
      use type System.Storage_Elements.Storage_Offset;

      subtype U64 is Interfaces.Unsigned_64;
      subtype Vector is Vector_Type;

   function Coefficient
     (High, Low : U64;
      Reflected : Boolean) return Vector
   with Inline_Always
   is
   begin
      if Reflected then
         --  Reflected folds pair the low state lane with the high coefficient
         --  and the high state lane with the low coefficient.  Arrange that
         --  pairing once so every stripe can use PMULL and PMULL2 directly.
         return Pair (High => Low, Low => High);
      else
         return Pair (High => High, Low => Low);
      end if;
   end Coefficient;

   function Initial_Vector (State : Value; Reflected : Boolean) return Vector
   with Inline_Always
   is
      Raw : constant U64 := U64 (State);
   begin
      if Reflected then
         return Pair (High => 0, Low => Raw);
      elsif Width = 16 then
         --  Forward CRC-16 operates in the kernel's scaled 32-bit space.
         return Pair (High => Interfaces.Shift_Left (Raw, 48), Low => 0);
      elsif Width = 32 then
         return Pair (High => Interfaces.Shift_Left (Raw, 32), Low => 0);
      else
         return Pair (High => Raw, Low => 0);
      end if;
   end Initial_Vector;

   function Fold_16
     (Current, Coeff, Data : Vector;
      Reflected            : Boolean) return Vector
   with Inline_Always
   is
      High_Product : Vector;
      Low_Product  : Vector;
      pragma Unreferenced (Reflected);
   begin
      High_Product := Carryless_Multiply_00 (Current, Coeff);
      Low_Product := Carryless_Multiply_11 (Current, Coeff);
      return Xor_3 (High_Product, Low_Product, Data);
   end Fold_16;

   function Fold_Width_32
     (State     : Vector;
      High, Low : U64;
      Reflected : Boolean) return Vector
   with Inline_Always
   is
      Low_Coefficient  : constant Vector := Pair (High => 0, Low => Low);
      High_Coefficient : constant Vector := Pair (High => High, Low => 0);
      First_Fold       : Vector;
      Masked           : Vector;
      Product          : Vector;
      Reflected_Mask   : constant Vector :=
        Pair (High => U64'Last, Low => 16#FFFF_FFFF_0000_0000#);
      Forward_Mask     : constant Vector :=
        Pair (High => 16#0000_0000_FFFF_FFFF#, Low => U64'Last);
   begin
      if Reflected then
         First_Fold :=
           Xor_128
             (Carryless_Multiply_00 (State, Low_Coefficient),
              Shift_Right (State, 8));
         Masked := And_128 (First_Fold, Reflected_Mask);
         Product :=
           Carryless_Multiply_11
             (Shift_Left (First_Fold, 12), High_Coefficient);
      else
         First_Fold :=
           Xor_128
             (Carryless_Multiply_01 (State, Low_Coefficient),
              Shift_Left (State, 8));
         Masked := And_128 (First_Fold, Forward_Mask);
         Product :=
           Carryless_Multiply_10
             (Shift_Right (First_Fold, 12), High_Coefficient);
      end if;
      return Xor_128 (Product, Masked);
   end Fold_Width_32;

   function Barrett_32
     (State     : Vector;
      Polynomial, Mu : U64;
      Reflected : Boolean) return Vector
   with Inline_Always
   is
      Mu_Polynomial : constant Vector := Pair (High => Polynomial, Low => Mu);
      First_Product : Vector;
      Second_Product : Vector;
   begin
      if Reflected then
         First_Product :=
           Carryless_Multiply_00 (State, Mu_Polynomial);
         Second_Product :=
           Carryless_Multiply_10 (First_Product, Mu_Polynomial);
         return Xor_128 (State, Second_Product);
      else
         First_Product :=
           Shift_Left
             (Carryless_Multiply_01 (State, Mu_Polynomial), 4);
         Second_Product :=
           Shift_Left
             (Carryless_Multiply_11
                (First_Product, Mu_Polynomial),
              4);
         return Xor_128 (Second_Product, State);
      end if;
   end Barrett_32;

   function Final_32
     (State : Vector; Reflected : Boolean; Keys : Folding_Keys) return Value
   with Inline_Always
   is
      Reduced : constant Vector :=
        Barrett_32
          (Fold_Width_32 (State, Keys (6), Keys (5), Reflected),
           Polynomial => Keys (8),
           Mu         => Keys (7),
           Reflected  => Reflected);
   begin
      if Width = 16 then
         if Reflected then
            return Value (Lane (Reduced, High => True) and 16#FFFF#);
         else
            return
              Value
                (Interfaces.Shift_Right (Lane (Reduced, High => False), 48)
                 and 16#FFFF#);
         end if;
      elsif Reflected then
         return Value (Lane (Reduced, High => True) and 16#FFFF_FFFF#);
      else
         return
           Value
             (Interfaces.Shift_Right (Lane (Reduced, High => False), 32)
              and 16#FFFF_FFFF#);
      end if;
   end Final_32;

   function Fold_Width_64
     (State     : Vector;
      High, Low : U64;
      Reflected : Boolean) return Vector
   with Inline_Always
   is
      Coeff : constant Vector := Coefficient (High, Low, Reflected);
   begin
      if Reflected then
         return
           Xor_128
             (Carryless_Multiply_01 (Coeff, State),
              Shift_Right (State, 8));
      else
         return
           Xor_128
             (Carryless_Multiply_01 (State, Coeff),
              Shift_Left (State, 8));
      end if;
   end Fold_Width_64;

   function Final_64
     (State : Vector; Reflected : Boolean; Keys : Folding_Keys) return Value
   with Inline_Always
   is
      Folded : constant Vector :=
        Fold_Width_64 (State, Keys (6), Keys (5), Reflected);
      Mu_Polynomial : constant Vector :=
        Coefficient (Keys (7), Keys (8), Reflected);
      First_Product  : Vector;
      Second_Product : Vector;
      Reduced        : Vector;
      Forward_Mask   : constant Vector := Pair (High => U64'Last, Low => 0);
      High_Only      : Vector;
   begin
      if Reflected then
         First_Product :=
           Carryless_Multiply_00 (Folded, Mu_Polynomial);
         Second_Product :=
           Carryless_Multiply_10 (First_Product, Mu_Polynomial);
         Reduced :=
           Xor_128
             (Xor_128 (Second_Product, Shift_Left (First_Product, 8)),
              Folded);
         return Value (Lane (Reduced, High => True));
      else
         High_Only := And_128 (Folded, Forward_Mask);
         First_Product :=
           Carryless_Multiply_11 (High_Only, Mu_Polynomial);
         Second_Product :=
           Carryless_Multiply_01
             (Xor_128 (First_Product, High_Only), Mu_Polynomial);
         Reduced := Xor_128 (Second_Product, Folded);
         return Value (Lane (Reduced, High => False));
      end if;
   end Final_64;

   function Load_Data
     (Source : System.Address; Reflected : Boolean) return Vector
   with Inline_Always
   is
      Loaded : constant Vector := Load_16 (Source);
   begin
      return (if Reflected then Loaded else Reverse_Bytes_128 (Loaded));
   end Load_Data;

   function Update_1024_Reflected
     (State  : Value;
      Keys   : Folding_Keys;
      Source : System.Address) return Value is
      X0, X1, X2, X3, X4, X5, X6, X7 : Vector;
      Result : Vector;
      Stripe_Address : System.Address := Source + 128;
      End_Address : constant System.Address := Source + 1_024;
      Coeff : constant Vector := Coefficient (Keys (4), Keys (3), True);
   begin
      if not Enable_1024_Reflected then
         raise Program_Error with "the exact reflected CRC-64 leaf is disabled";
      end if;

      if Use_Custom_Initial_Load then
         Load_Initial_Stripe_8
           (Source, X0, X1, X2, X3, X4, X5, X6, X7);
      else
         X0 := Load_16 (Source);
         X1 := Load_16 (Source + 16);
         X2 := Load_16 (Source + 32);
         X3 := Load_16 (Source + 48);
         X4 := Load_16 (Source + 64);
         X5 := Load_16 (Source + 80);
         X6 := Load_16 (Source + 96);
         X7 := Load_16 (Source + 112);
      end if;
      X0 := Xor_128 (X0, Initial_Vector (State, True));

      if Use_Custom_Stripe_Loop then
         Fold_Stripes_8
           (Stripe_Address, End_Address, True, Coeff,
            X0, X1, X2, X3, X4, X5, X6, X7);
      else
         while Stripe_Address /= End_Address loop
            declare
               First_Data, Second_Data : Vector;
            begin
               Load_16_Pair_Advance
                 (Stripe_Address, First_Data, Second_Data);
               X0 := Fold_16 (X0, Coeff, First_Data, True);
               X1 := Fold_16 (X1, Coeff, Second_Data, True);
               Load_16_Pair_Advance
                 (Stripe_Address, First_Data, Second_Data);
               X2 := Fold_16 (X2, Coeff, First_Data, True);
               X3 := Fold_16 (X3, Coeff, Second_Data, True);
               Load_16_Pair_Advance
                 (Stripe_Address, First_Data, Second_Data);
               X4 := Fold_16 (X4, Coeff, First_Data, True);
               X5 := Fold_16 (X5, Coeff, Second_Data, True);
               Load_16_Pair_Advance
                 (Stripe_Address, First_Data, Second_Data);
               X6 := Fold_16 (X6, Coeff, First_Data, True);
               X7 := Fold_16 (X7, Coeff, Second_Data, True);
            end;
         end loop;
      end if;

      Result := X7;
      if Use_Custom_Collapse then
         Collapse_Stripes_8
           (Keys, True, X0, X1, X2, X3, X4, X5, X6, Result);
      else
         Result := Fold_16
           (X0, Coefficient (Keys (10), Keys (9), True), Result, True);
         Result := Fold_16
           (X1, Coefficient (Keys (12), Keys (11), True), Result, True);
         Result := Fold_16
           (X2, Coefficient (Keys (14), Keys (13), True), Result, True);
         Result := Fold_16
           (X3, Coefficient (Keys (16), Keys (15), True), Result, True);
         Result := Fold_16
           (X4, Coefficient (Keys (18), Keys (17), True), Result, True);
         Result := Fold_16
           (X5, Coefficient (Keys (20), Keys (19), True), Result, True);
         Result := Fold_16
           (X6, Coefficient (Keys (2), Keys (1), True), Result, True);
      end if;

      return Final_64 (Result, True, Keys);
   end Update_1024_Reflected;

   function Update_Aligned_Blocks
     (State     : Value;
      Reflected : Boolean;
      Keys      : Folding_Keys;
      Data      : Byte_Array) return Value is
      X0     : Vector;
      X1     : Vector;
      X2     : Vector;
      X3     : Vector;
      X4     : Vector;
      X5     : Vector;
      X6     : Vector;
      X7     : Vector;
      First_Data  : Vector;
      Second_Data : Vector;
      Result : Vector;
      --  The generic precondition establishes one or more complete 128-byte
      --  stripes.  Derive the base through a checked Ada index once, then
      --  traverse only addresses proven to belong to those complete stripes;
      --  the final post-index update reaches End_Address and is not read.
      Base_Address : constant System.Address := Data (Data'First)'Address;
      End_Address : constant System.Address :=
        Base_Address + System.Storage_Elements.Storage_Offset (Data'Length);
      Stripe_Address : System.Address := Base_Address + 128;
      Coeff  : constant Vector := Coefficient (Keys (4), Keys (3), Reflected);
   begin
      if Use_Custom_Initial_Load then
         Load_Initial_Stripe_8
           (Base_Address, X0, X1, X2, X3, X4, X5, X6, X7);
         if not Reflected then
            X0 := Reverse_Bytes_128 (X0);
            X1 := Reverse_Bytes_128 (X1);
            X2 := Reverse_Bytes_128 (X2);
            X3 := Reverse_Bytes_128 (X3);
            X4 := Reverse_Bytes_128 (X4);
            X5 := Reverse_Bytes_128 (X5);
            X6 := Reverse_Bytes_128 (X6);
            X7 := Reverse_Bytes_128 (X7);
         end if;
         X0 := Xor_128 (X0, Initial_Vector (State, Reflected));
      else
         X0 :=
           Xor_128
             (Load_Data (Base_Address, Reflected),
              Initial_Vector (State, Reflected));
         X1 := Load_Data (Base_Address + 16, Reflected);
         X2 := Load_Data (Base_Address + 32, Reflected);
         X3 := Load_Data (Base_Address + 48, Reflected);
         X4 := Load_Data (Base_Address + 64, Reflected);
         X5 := Load_Data (Base_Address + 80, Reflected);
         X6 := Load_Data (Base_Address + 96, Reflected);
         X7 := Load_Data (Base_Address + 112, Reflected);
      end if;

      if Use_Custom_Stripe_Loop
        or else (Use_Custom_Forward_Stripe_Loop and then not Reflected)
      then
         if Stripe_Address /= End_Address then
            Fold_Stripes_8
              (Stripe_Address, End_Address, Reflected, Coeff,
               X0, X1, X2, X3, X4, X5, X6, X7);
         end if;
      else
         while Stripe_Address /= End_Address loop
            Load_16_Pair_Advance (Stripe_Address, First_Data, Second_Data);
            X0 :=
              Fold_16
                (X0,
                 Coeff,
                 (if Reflected then First_Data else Reverse_Bytes_128 (First_Data)),
                 Reflected);
            X1 :=
              Fold_16
                (X1,
                 Coeff,
                 (if Reflected then Second_Data else Reverse_Bytes_128 (Second_Data)),
                 Reflected);

            Load_16_Pair_Advance (Stripe_Address, First_Data, Second_Data);
            X2 :=
              Fold_16
                (X2,
                 Coeff,
                 (if Reflected then First_Data else Reverse_Bytes_128 (First_Data)),
                 Reflected);
            X3 :=
              Fold_16
                (X3,
                 Coeff,
                 (if Reflected then Second_Data else Reverse_Bytes_128 (Second_Data)),
                 Reflected);

            Load_16_Pair_Advance (Stripe_Address, First_Data, Second_Data);
            X4 :=
              Fold_16
                (X4,
                 Coeff,
                 (if Reflected then First_Data else Reverse_Bytes_128 (First_Data)),
                 Reflected);
            X5 :=
              Fold_16
                (X5,
                 Coeff,
                 (if Reflected then Second_Data else Reverse_Bytes_128 (Second_Data)),
                 Reflected);

            Load_16_Pair_Advance (Stripe_Address, First_Data, Second_Data);
            X6 :=
              Fold_16
                (X6,
                 Coeff,
                 (if Reflected then First_Data else Reverse_Bytes_128 (First_Data)),
                 Reflected);
            X7 :=
              Fold_16
                (X7,
                 Coeff,
                 (if Reflected then Second_Data else Reverse_Bytes_128 (Second_Data)),
                 Reflected);
         end loop;
      end if;

      --  Collapse lanes across distances of 112, 96, 80, 64, 48, 32, and
      --  16 bytes using the corresponding generated-key pairs.
      Result := X7;
      if Use_Custom_Collapse then
         Collapse_Stripes_8
           (Keys, Reflected, X0, X1, X2, X3, X4, X5, X6, Result);
      else
         Result :=
           Fold_16
             (X0, Coefficient (Keys (10), Keys (9), Reflected), Result,
              Reflected);
         Result :=
           Fold_16
             (X1, Coefficient (Keys (12), Keys (11), Reflected), Result,
              Reflected);
         Result :=
           Fold_16
             (X2, Coefficient (Keys (14), Keys (13), Reflected), Result,
              Reflected);
         Result :=
           Fold_16
             (X3, Coefficient (Keys (16), Keys (15), Reflected), Result,
              Reflected);
         Result :=
           Fold_16
             (X4, Coefficient (Keys (18), Keys (17), Reflected), Result,
              Reflected);
         Result :=
           Fold_16
             (X5, Coefficient (Keys (20), Keys (19), Reflected), Result,
              Reflected);
         Result :=
           Fold_16
             (X6, Coefficient (Keys (2), Keys (1), Reflected), Result,
              Reflected);
      end if;

      return
        (if Width <= 32
         then Final_32 (Result, Reflected, Keys)
         else Final_64 (Result, Reflected, Keys));
   end Update_Aligned_Blocks;
   end Engine;
end Flyology_CRC.Generic_PMULL_Kernel;
