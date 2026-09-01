package body Flyology_CRC is
   use type Interfaces.Unsigned_64;

   subtype U64 is Interfaces.Unsigned_64;

   function Reverse_Bits (Item : U64; Count : Positive) return U64 is
      Source : U64 := Item;
      Target : U64 := 0;
   begin
      for Bit in 1 .. Count loop
         Target := Target * 2 or (Source and 1);
         Source := Source / 2;
      end loop;
      return Target;
   end Reverse_Bits;

   function Generate_Folding_Keys
     (Width      : Positive;
      Polynomial : U64;
      Reflected  : Boolean) return Folding_Keys is
      type Exponents is array (Folding_Key_Index) of Natural;

      --  Exponent positions for the private 23-key fold-by-eight layout.
      --  Mathematical provenance is recorded in THIRD_PARTY_NOTICES.md.
      Exponents_16_32 : constant Exponents :=
        (0, 32 * 3, 32 * 5, 32 * 31, 32 * 33, 32 * 3, 32 * 2, 0, 0,
         32 * 27, 32 * 29, 32 * 23, 32 * 25, 32 * 19, 32 * 21,
         32 * 15, 32 * 17, 32 * 11, 32 * 13, 32 * 7, 32 * 9,
         32 * 63, 32 * 65);
      Exponents_64 : constant Exponents :=
        (0, 64 * 2, 64 * 3, 64 * 16, 64 * 17, 64 * 2, 64, 0, 0,
         64 * 14, 64 * 15, 64 * 12, 64 * 13, 64 * 10, 64 * 11,
         64 * 8, 64 * 9, 64 * 6, 64 * 7, 64 * 4, 64 * 5,
         64 * 32, 64 * 33);

      Working_Polynomial : U64;
      Selected_Exponents : Exponents;
      Result             : Folding_Keys := (others => 0);

      function Key (Exponent : Natural) return U64 is
         Value      : U64;
         Iterations : Natural;
      begin
         if Width = 16 or else Width = 32 then
            if Exponent < 32 then
               return 0;
            end if;
            Value := 16#080000000#;
            Iterations := Exponent - 31;
            for Step in 1 .. Iterations loop
               Value := Value * 2;
               if (Value and 16#100000000#) /= 0 then
                  Value := Value xor Working_Polynomial;
               end if;
            end loop;
            if Reflected then
               return Reverse_Bits (Value, 64) / (U64 (2) ** 31);
            else
               return Value * (U64 (2) ** 32);
            end if;
         end if;

         if Exponent <= 64 then
            return 0;
         end if;
         Value := 16#8000000000000000#;
         Iterations := Exponent - (if Reflected then 64 else 63);
         for Step in 1 .. Iterations loop
            Value :=
              Value * 2 xor
              ((0 - Value / 16#8000000000000000#) and Working_Polynomial);
         end loop;
         return (if Reflected then Reverse_Bits (Value, 64) else Value);
      end Key;

      function Mu return U64 is
         Value    : U64;
         Quotient : U64 := 0;
         High     : U64;
         Low      : U64;
      begin
         if Width = 16 or else Width = 32 then
            Value := 16#100000000#;
            for Step in 1 .. 33 loop
               Quotient := Quotient * 2;
               if (Value and 16#100000000#) /= 0 then
                  Quotient := Quotient or 1;
                  Value := Value xor Working_Polynomial;
               end if;
               Value := Value * 2;
            end loop;
            if Reflected then
               return Reverse_Bits (Quotient, 64) / (U64 (2) ** 31);
            else
               return Quotient;
            end if;
         end if;

         High := 1;
         Low := 0;
         for Step in 1 .. (if Reflected then 64 else 65) loop
            Quotient := Quotient * 2;
            if High /= 0 then
               Quotient := Quotient or 1;
               Low := Low xor Working_Polynomial;
            end if;
            High := Low / 16#8000000000000000#;
            Low := Low * 2;
         end loop;
         return (if Reflected then Reverse_Bits (Quotient, 64) else Quotient);
      end Mu;

      function Formatted_Polynomial return U64 is
         Reversed : U64;
      begin
         if not Reflected then
            return Working_Polynomial;
         elsif Width = 16 then
            Reversed := Reverse_Bits ((Working_Polynomial / (U64 (2) ** 16)) and 16#FFFF#, 16);
         elsif Width = 32 then
            Reversed := Reverse_Bits (Working_Polynomial and 16#FFFFFFFF#, 32);
         else
            Reversed := Reverse_Bits (Working_Polynomial, 64);
         end if;
         return Reversed * 2 or 1;
      end Formatted_Polynomial;
   begin
      case Width is
         when 16 =>
            Working_Polynomial := Polynomial * (U64 (2) ** 16) or (U64 (2) ** 32);
            Selected_Exponents := Exponents_16_32;
         when 32 =>
            Working_Polynomial := Polynomial or (U64 (2) ** 32);
            Selected_Exponents := Exponents_16_32;
         when 64 =>
            Working_Polynomial := Polynomial;
            Selected_Exponents := Exponents_64;
         when others =>
            raise Program_Error with "folding keys require CRC width 16, 32, or 64";
      end case;

      for Index in Folding_Key_Index range 1 .. Folding_Key_Index'Last loop
         Result (Index) := Key (Selected_Exponents (Index));
      end loop;
      Result (7) := Mu;
      Result (8) := Formatted_Polynomial;
      return Result;
   end Generate_Folding_Keys;

   package body Generic_Core is
      Zero    : constant Value := 0;
      One     : constant Value := 1;
      Top_Bit : constant Value := Value (2) ** (Width - 1);
      Byte_Radix      : constant Value := Value (2) ** 8;
      Top_Byte_Factor : constant Value := Value (2) ** (Width - 8);

      function Reflect (Item : Value) return Value is
         Source : Value := Item;
         Target : Value := Zero;
      begin
         for Bit in 1 .. Width loop
            Target := Target * 2;
            if (Source and One) /= Zero then
               Target := Target or One;
            end if;
            Source := Source / 2;
         end loop;
         return Target;
      end Reflect;

      function Create
        (Polynomial    : Value;
         Initial_Value : Value;
         Reflected     : Boolean;
         Final_XOR     : Value) return Parameters is
      begin
         return
           Create
             (Polynomial,
              Initial_Value,
              Reflected,
              Final_XOR,
              Generate_Folding_Keys (Width, U64 (Polynomial), Reflected));
      end Create;

      function Create
        (Polynomial    : Value;
         Initial_Value : Value;
         Reflected     : Boolean;
         Final_XOR     : Value;
         Keys          : Folding_Keys) return Parameters is
         Result : Parameters :=
           (Polynomial         => Polynomial,
            Working_Polynomial => (if Reflected then Reflect (Polynomial) else Polynomial),
            Initial_Value      => Initial_Value,
            --  The scaled CRC-16 representation reverses asymmetric reflected
            --  initial values. CRC-32 and CRC-64 consume the catalogue value
            --  directly.
            Working_Initial    =>
              (if Reflected and then Width = 16 then Reflect (Initial_Value) else Initial_Value),
            Reflected          => Reflected,
            Final_XOR          => Final_XOR,
            Table              => (others => Zero),
            Keys               => Keys);
         State : Value;
      begin
         for Index in Byte loop
            if Reflected then
               State := Value (Index);
               for Bit in 1 .. 8 loop
                  if (State and One) /= Zero then
                     State := State / 2 xor Result.Working_Polynomial;
                  else
                     State := State / 2;
                  end if;
               end loop;
            else
               State := Value (Index) * Top_Byte_Factor;
               for Bit in 1 .. 8 loop
                  if (State and Top_Bit) /= Zero then
                     State := State * 2 xor Result.Working_Polynomial;
                  else
                     State := State * 2;
                  end if;
               end loop;
            end if;
            Result.Table (Index) := State;
         end loop;
         return Result;
      end Create;

      function Start (Configuration : Parameters) return Context is
      begin
         return (Configuration => Configuration, State => Configuration.Working_Initial);
      end Start;

      procedure Reset (Object : in out Context) is
      begin
         Object.State := Object.Configuration.Working_Initial;
      end Reset;

      procedure Update_State
        (State         : in out Value;
         Configuration : Parameters;
         Data          : Byte_Array) is
         Index : Byte;
      begin
         if Configuration.Reflected then
            for Element of Data loop
               Index := Byte ((State xor Value (Element)) and Value (Byte'Last));
               State := State / Byte_Radix xor Configuration.Table (Index);
            end loop;
         else
            for Element of Data loop
               Index := Byte (State / Top_Byte_Factor xor Value (Element));
               State := State * Byte_Radix xor Configuration.Table (Index);
            end loop;
         end if;
      end Update_State;

      procedure Update (Object : in out Context; Data : Byte_Array) is
      begin
         Update_State (Object.State, Object.Configuration, Data);
      end Update;

      function Result (Object : Context) return Value is
      begin
         return Object.State xor Object.Configuration.Final_XOR;
      end Result;

      function Compute
        (Configuration : Parameters;
         Data          : Byte_Array) return Value is
         State : Value := Configuration.Working_Initial;
      begin
         Update_State (State, Configuration, Data);
         return State xor Configuration.Final_XOR;
      end Compute;

      function Combine
        (Configuration     : Parameters;
         Left, Right       : Value;
         Right_Byte_Length : Byte_Count) return Value is
         --  Altered Ada translation of Mark Adler's generalized GF(2) matrix
         --  method; see THIRD_PARTY_NOTICES.md.
         type Matrix is array (Natural range <>) of Value;

         function Matrix_Times (Columns : Matrix; Vector : Value) return Value is
            Remaining : Value := Vector;
            Sum       : Value := Zero;
            Column    : Natural := Columns'First;
         begin
            while Remaining /= Zero loop
               if (Remaining and One) /= Zero then
                  Sum := Sum xor Columns (Column);
               end if;
               Remaining := Remaining / 2;
               Column := Column + 1;
            end loop;
            return Sum;
         end Matrix_Times;

         procedure Square (Target : out Matrix; Source : Matrix) is
         begin
            for Column in Target'Range loop
               Target (Column) := Matrix_Times (Source, Source (Column));
            end loop;
         end Square;

         Odd       : Matrix (0 .. Width - 1);
         Even      : Matrix (0 .. Width - 1);
         Column    : Value;
         Combined  : Value := Left xor Configuration.Working_Initial xor Configuration.Final_XOR;
         Remaining : Byte_Count := Right_Byte_Length;
      begin
         if Configuration.Reflected then
            Odd (0) := Configuration.Working_Polynomial;
            Column := One;
            for Index in 1 .. Width - 1 loop
               Odd (Index) := Column;
               Column := Column * 2;
            end loop;
         else
            Column := Value (2);
            for Index in 0 .. Width - 2 loop
               Odd (Index) := Column;
               Column := Column * 2;
            end loop;
            Odd (Width - 1) := Configuration.Polynomial;
         end if;

         Square (Even, Odd);
         Square (Odd, Even);

         while Remaining /= 0 loop
            Square (Even, Odd);
            if (Remaining and 1) /= 0 then
               Combined := Matrix_Times (Even, Combined);
            end if;
            Remaining := Remaining / 2;
            exit when Remaining = 0;

            Square (Odd, Even);
            if (Remaining and 1) /= 0 then
               Combined := Matrix_Times (Odd, Combined);
            end if;
            Remaining := Remaining / 2;
         end loop;

         return Combined xor Right;
      end Combine;
   end Generic_Core;
end Flyology_CRC;
