with Interfaces;
with Interfaces.C;
with Flyology_CRC.Native;
with System;

package body Flyology_CRC.Native_Features is
   package C renames Interfaces.C;
   use type C.int;
   use type C.size_t;
   use type Interfaces.Unsigned_8;

   function Sysctl_By_Name
     (Name       : System.Address;
      Old_Value  : System.Address;
      Old_Length : access C.size_t;
      New_Value  : System.Address;
      New_Length : C.size_t) return C.int
   with Import, Convention => C, External_Name => "sysctlbyname";

   --  Apple arm/cpu_capabilities_public.h defines hw.optional.arm.caps as a
   --  stable bit-buffer ABI.  Existing bit assignments may not change:
   --  FEAT_SHA3 is bit 4, FEAT_PMULL is bit 11, AdvSIMD is bit 49, and
   --  FEAT_CRC32 is bit 51.
   SHA3_Bit    : constant Natural := 4;
   PMULL_Bit   : constant Natural := 11;
   AdvSIMD_Bit : constant Natural := 49;
   CRC32_Bit   : constant Natural := 51;

   type Capability_Set is record
      PMULL : Boolean;
      CRC32 : Boolean;
      SHA3  : Boolean;
   end record;

   No_Capabilities : constant Capability_Set := (others => False);

   function Query_Capabilities return Capability_Set is
      Name   : aliased C.char_array := C.To_C ("hw.optional.arm.caps");
      Length : aliased C.size_t := 0;
   begin
      if Sysctl_By_Name
           (Name'Address,
            System.Null_Address,
            Length'Access,
            System.Null_Address,
            0) /= 0
        or else Length = 0
        or else Length > C.size_t (Natural'Last)
      then
         return No_Capabilities;
      end if;

      declare
         type Capability_Buffer is
           array (Natural range <>) of aliased Interfaces.Unsigned_8;
         Capabilities : aliased Capability_Buffer (0 .. Natural (Length) - 1) :=
           [others => 0];
         Actual_Length : aliased C.size_t := Length;

         function Has (Bit : Natural) return Boolean is
            Byte_Index : constant Natural := Bit / 8;
            Mask       : constant Interfaces.Unsigned_8 :=
              Interfaces.Shift_Left (Interfaces.Unsigned_8'(1), Bit mod 8);
         begin
            return
              Byte_Index < Natural (Actual_Length)
              and then (Capabilities (Byte_Index) and Mask) /= 0;
         end Has;
      begin
         if Sysctl_By_Name
              (Name'Address,
               Capabilities'Address,
               Actual_Length'Access,
               System.Null_Address,
               0) /= 0
           or else Actual_Length > Length
         then
            return No_Capabilities;
         end if;

         return
           (PMULL => Has (PMULL_Bit) and then Has (AdvSIMD_Bit),
            CRC32 => Has (CRC32_Bit),
            SHA3  => Has (SHA3_Bit));
      end;
   exception
      when Constraint_Error | Storage_Error =>
         return No_Capabilities;
   end Query_Capabilities;

   Detected : constant Capability_Set :=
     (if Flyology_CRC.Native.Compiled
      then Query_Capabilities
      else No_Capabilities);

   function PMULL_Available return Boolean is (Detected.PMULL);

   function CRC32_Available return Boolean is (Detected.CRC32);

   function SHA3_Available return Boolean is (Detected.SHA3);

   function PMULL_64_1024_Reflected_Preferred return Boolean is (False);
end Flyology_CRC.Native_Features;
