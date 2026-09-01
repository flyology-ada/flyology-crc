with Ada.Streams;
with Interfaces;

package Flyology_CRC is
   --  Shared byte types for the Flyology CRC-16, CRC-32, and CRC-64 packages.
   --  Width-specific child packages provide one-shot, incremental, custom,
   --  and checksum-combination operations.

   --  One byte of CRC input.
   subtype Byte is Ada.Streams.Stream_Element;

   --  A contiguous sequence of CRC input bytes. CRC operations borrow the
   --  array for the duration of a call and do not retain it.
   subtype Byte_Array is Ada.Streams.Stream_Element_Array;

   --  A byte length used when combining independently computed CRC values.
   subtype Byte_Count is Interfaces.Unsigned_64;

private
   --  The fold-by-eight kernels use 23 generated carry-less-multiplication
   --  keys.  This is private because it is an implementation representation,
   --  not a caller-facing limit.
   subtype Folding_Key_Index is Natural range 0 .. 22;
   type Folding_Keys is array (Folding_Key_Index) of Interfaces.Unsigned_64;

   function Generate_Folding_Keys
     (Width      : Positive;
      Polynomial : Interfaces.Unsigned_64;
      Reflected  : Boolean) return Folding_Keys;

   generic
      type Value is mod <>;
      Width : Positive;
   package Generic_Core is
      type Lookup_Table is array (Byte) of Value;

      type Parameters is record
         Polynomial         : Value;
         Working_Polynomial : Value;
         Initial_Value      : Value;
         Working_Initial    : Value;
         Reflected          : Boolean;
         Final_XOR          : Value;
         Table              : Lookup_Table;
         Keys               : Folding_Keys;
      end record;

      function Create
        (Polynomial    : Value;
         Initial_Value : Value;
         Reflected     : Boolean;
         Final_XOR     : Value) return Parameters;

      function Create
        (Polynomial    : Value;
         Initial_Value : Value;
         Reflected     : Boolean;
         Final_XOR     : Value;
         Keys          : Folding_Keys) return Parameters;

      type Context is record
         Configuration : Parameters;
         State         : Value;
      end record;

      function Start (Configuration : Parameters) return Context;
      procedure Reset (Object : in out Context);
      procedure Update_State
        (State         : in out Value;
         Configuration : Parameters;
         Data          : Byte_Array);
      --  Update the raw algorithm-form state without applying Final_XOR.
      --  Width-specific children use this for a native prefix's scalar tail.
      procedure Update (Object : in out Context; Data : Byte_Array);
      function Result (Object : Context) return Value;

      function Compute
        (Configuration : Parameters;
         Data          : Byte_Array) return Value;

      function Combine
        (Configuration     : Parameters;
         Left, Right       : Value;
         Right_Byte_Length : Byte_Count) return Value;
   end Generic_Core;
end Flyology_CRC;
