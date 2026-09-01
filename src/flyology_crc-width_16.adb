with Ada.Streams;
with Flyology_CRC.Generated_Catalogue;
with Flyology_CRC.Generic_AVX512_Ternary;
with Flyology_CRC.Generic_AVX512_VPCLMUL;
with Flyology_CRC.Generic_SSE;
with Flyology_CRC.Native;
with Flyology_CRC.Native_EOR3;
with Flyology_CRC.Native_Features;
with Flyology_CRC.X86_Features;

package body Flyology_CRC.Width_16 is
   use type Value;
   use type Ada.Streams.Stream_Element_Offset;

   procedure Update_Raw
     (State         : in out Value;
      Configuration : Core.Parameters;
      Data          : Byte_Array)
   with Inline_Always
   is
   begin
      if Data'Length >= 128
        and then
          (X86_Features.AVX512_VPCLMUL_Available
           or else X86_Features.AVX512_Ternary_Available
           or else X86_Features.Generic_SSE_Available
           or else Native_Features.PMULL_Available)
      then
         --  Native loads are unaligned, so the maximal complete-stripe prefix
         --  can be folded directly and only the suffix needs the table core.
         declare
            Folded_Length : constant Ada.Streams.Stream_Element_Offset :=
              Ada.Streams.Stream_Element_Offset (Data'Length - Data'Length mod 128);
            Folded_Last : constant Ada.Streams.Stream_Element_Offset :=
              Data'First + (Folded_Length - 1);
            Folded : Byte_Array renames Data (Data'First .. Folded_Last);
         begin
            if Folded'Length >= 256
              and then X86_Features.AVX512_VPCLMUL_Available
            then
               State :=
                 Generic_AVX512_VPCLMUL.Update_16
                   (State, Configuration.Reflected, Configuration.Keys, Folded);
            elsif X86_Features.Generic_SSE_Available
              and then X86_Features.AVX512_Ternary_Available
            then
               State :=
                 Generic_AVX512_Ternary.Update_16
                   (State, Configuration.Reflected, Configuration.Keys, Folded);
            elsif X86_Features.Generic_SSE_Available then
               State :=
                 Generic_SSE.Update_16
                   (State, Configuration.Reflected, Configuration.Keys, Folded);
            elsif Native_Features.SHA3_Available then
               State :=
                 Native_EOR3.Update_PMULL_16
                   (State, Configuration.Reflected, Configuration.Keys, Folded);
            else
               State :=
                 Native.Update_PMULL_16
                   (State, Configuration.Reflected, Configuration.Keys, Folded);
            end if;

            if Folded_Last < Data'Last then
               Core.Update_State
                 (State,
                  Configuration,
                  Data (Folded_Last + 1 .. Data'Last));
            end if;
         end;
      else
         Core.Update_State (State, Configuration, Data);
      end if;
   end Update_Raw;

   function Create
     (Polynomial    : Value;
      Initial_Value : Value;
      Reflected     : Boolean;
      Final_XOR     : Value) return Parameters is
   begin
      return
        (Data =>
           Core.Create
             (Polynomial    => Polynomial,
              Initial_Value => Initial_Value,
              Reflected     => Reflected,
              Final_XOR     => Final_XOR));
   end Create;

   function Build_Parameters (Kind : Algorithm) return Parameters is
      Item : constant Generated_Catalogue.Parameters_16 := Generated_Catalogue.Lookup (Kind);
   begin
      return
        (Data =>
           Core.Create
             (Polynomial    => Item.Polynomial,
              Initial_Value => Item.Initial_Value,
              Reflected     => Item.Reflected,
              Final_XOR     => Item.Final_XOR,
              Keys          => Item.Keys));
   end Build_Parameters;

   type Predefined_Array is array (Algorithm) of Parameters;

   function Initialize_Predefined return Predefined_Array is
      Result : Predefined_Array;
   begin
      for Kind in Algorithm loop
         Result (Kind) := Build_Parameters (Kind);
      end loop;
      return Result;
   end Initialize_Predefined;

   Predefined : constant Predefined_Array := Initialize_Predefined;

   function Parameters_For (Kind : Algorithm) return Parameters is
   begin
      return Predefined (Kind);
   end Parameters_For;

   function Compute (Kind : Algorithm; Data : Byte_Array) return Value is
   begin
      return Compute (Predefined (Kind), Data);
   end Compute;

   function Compute
     (Configuration : Parameters;
      Data          : Byte_Array) return Value is
      State : Value := Configuration.Data.Working_Initial;
   begin
      Update_Raw (State, Configuration.Data, Data);
      return State xor Configuration.Data.Final_XOR;
   end Compute;

   function Start (Kind : Algorithm) return Context is
   begin
      return (Data => Core.Start (Predefined (Kind).Data));
   end Start;

   function Start (Configuration : Parameters) return Context is
   begin
      return (Data => Core.Start (Configuration.Data));
   end Start;

   procedure Reset (Object : in out Context) is
   begin
      Core.Reset (Object.Data);
   end Reset;

   procedure Update (Object : in out Context; Data : Byte_Array) is
   begin
      Update_Raw (Object.Data.State, Object.Data.Configuration, Data);
   end Update;

   function Result (Object : Context) return Value is
   begin
      return Core.Result (Object.Data);
   end Result;

   function Combine
     (Kind              : Algorithm;
      Left, Right       : Value;
      Right_Byte_Length : Byte_Count) return Value is
   begin
      return Core.Combine (Predefined (Kind).Data, Left, Right, Right_Byte_Length);
   end Combine;

   function Combine
     (Configuration     : Parameters;
      Left, Right       : Value;
      Right_Byte_Length : Byte_Count) return Value is
   begin
      return Core.Combine (Configuration.Data, Left, Right, Right_Byte_Length);
   end Combine;
end Flyology_CRC.Width_16;
