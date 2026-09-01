with Interfaces.C;
with Flyology_CRC.Native;

package body Flyology_CRC.Native_Features is
   package C renames Interfaces.C;
   use type C.unsigned_long;

   function Get_Auxiliary_Value
     (Kind : C.unsigned_long) return C.unsigned_long
   with Import, Convention => C, External_Name => "getauxval";

   --  Linux UAPI include/uapi/linux/auxvec.h assigns AT_HWCAP 16.  The
   --  AArch64 UAPI asm/hwcap.h assigns AdvSIMD bit 1, PMULL bit 4, CRC32
   --  bit 7, and SHA3 bit 17.
   AT_HWCAP    : constant C.unsigned_long := 16;
   HWCAP_ASIMD : constant C.unsigned_long := 2 ** 1;
   HWCAP_PMULL : constant C.unsigned_long := 2 ** 4;
   HWCAP_CRC32 : constant C.unsigned_long := 2 ** 7;
   HWCAP_SHA3  : constant C.unsigned_long := 2 ** 17;

   type Capability_Set is record
      PMULL : Boolean;
      CRC32 : Boolean;
      SHA3  : Boolean;
   end record;

   No_Capabilities : constant Capability_Set := (others => False);

   function Detect return Capability_Set is
      Capabilities : C.unsigned_long;
   begin
      if not Flyology_CRC.Native.Compiled then
         return No_Capabilities;
      end if;

      Capabilities := Get_Auxiliary_Value (AT_HWCAP);
      return
        (PMULL =>
           (Capabilities and HWCAP_ASIMD) /= 0
           and then (Capabilities and HWCAP_PMULL) /= 0,
         CRC32 => (Capabilities and HWCAP_CRC32) /= 0,
         SHA3  => (Capabilities and HWCAP_SHA3) /= 0);
   end Detect;

   Detected : constant Capability_Set := Detect;

   function PMULL_Available return Boolean is (Detected.PMULL);

   function CRC32_Available return Boolean is (Detected.CRC32);

   function SHA3_Available return Boolean is (Detected.SHA3);

   function PMULL_64_1024_Reflected_Preferred return Boolean is
     (Detected.PMULL and then not Detected.SHA3);
end Flyology_CRC.Native_Features;
