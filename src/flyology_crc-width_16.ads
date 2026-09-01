with Interfaces;

package Flyology_CRC.Width_16 is
   --  Allocation-free CRC-16 computation for predefined and caller-defined
   --  algorithms, including one-shot, incremental, and combination operations.

   --  A completed 16-bit CRC value or a 16-bit algorithm parameter.
   subtype Value is Interfaces.Unsigned_16;

   --  Predefined CRC-16 algorithms, named after the canonical entries in the
   --  RevEng CRC Catalogue.
   --
   --  @enum ARC CRC-16/ARC.
   --  @enum CDMA2000 CRC-16/CDMA2000.
   --  @enum CMS CRC-16/CMS.
   --  @enum DDS_110 CRC-16/DDS-110.
   --  @enum DECT_R CRC-16/DECT-R.
   --  @enum DECT_X CRC-16/DECT-X.
   --  @enum DNP CRC-16/DNP.
   --  @enum EN_13757 CRC-16/EN-13757.
   --  @enum GENIBUS CRC-16/GENIBUS.
   --  @enum GSM CRC-16/GSM.
   --  @enum IBM_3740 CRC-16/IBM-3740.
   --  @enum IBM_SDLC CRC-16/IBM-SDLC.
   --  @enum ISO_IEC_14443_3_A CRC-16/ISO-IEC-14443-3-A.
   --  @enum KERMIT CRC-16/KERMIT.
   --  @enum LJ1200 CRC-16/LJ1200.
   --  @enum M17 CRC-16/M17.
   --  @enum MAXIM_DOW CRC-16/MAXIM-DOW.
   --  @enum MCRF4XX CRC-16/MCRF4XX.
   --  @enum MODBUS CRC-16/MODBUS.
   --  @enum NRSC_5 CRC-16/NRSC-5.
   --  @enum OPENSAFETY_A CRC-16/OPENSAFETY-A.
   --  @enum OPENSAFETY_B CRC-16/OPENSAFETY-B.
   --  @enum PROFIBUS CRC-16/PROFIBUS.
   --  @enum RIELLO CRC-16/RIELLO.
   --  @enum SPI_FUJITSU CRC-16/SPI-FUJITSU.
   --  @enum T10_DIF CRC-16/T10-DIF.
   --  @enum TELEDISK CRC-16/TELEDISK.
   --  @enum TMS37157 CRC-16/TMS37157.
   --  @enum UMTS CRC-16/UMTS.
   --  @enum USB CRC-16/USB.
   --  @enum XMODEM CRC-16/XMODEM.
   type Algorithm is
     (ARC,
      CDMA2000,
      CMS,
      DDS_110,
      DECT_R,
      DECT_X,
      DNP,
      EN_13757,
      GENIBUS,
      GSM,
      IBM_3740,
      IBM_SDLC,
      ISO_IEC_14443_3_A,
      KERMIT,
      LJ1200,
      M17,
      MAXIM_DOW,
      MCRF4XX,
      MODBUS,
      NRSC_5,
      OPENSAFETY_A,
      OPENSAFETY_B,
      PROFIBUS,
      RIELLO,
      SPI_FUJITSU,
      T10_DIF,
      TELEDISK,
      TMS37157,
      UMTS,
      USB,
      XMODEM);

   --  An immutable, reusable CRC-16 configuration. Assignment creates an
   --  independent copy and no dynamic allocation is involved.
   type Parameters is private;

   --  Return the parameters of a predefined CRC-16 algorithm.
   --
   --  @param Kind Predefined algorithm to configure.
   --  @return A reusable configuration for Kind.
   function Parameters_For (Kind : Algorithm) return Parameters;

   --  Create a custom CRC-16 configuration. Reflected applies to both input
   --  and output reflection; configurations with different input and output
   --  reflection settings are not represented by this API. Every bit pattern
   --  of the modular parameters is accepted.
   --
   --  @param Polynomial CRC polynomial in normal form.
   --  @param Initial_Value Initial register value.
   --  @param Reflected Whether the algorithm reflects both input and output.
   --  @param Final_XOR Value XORed with the register to produce the result.
   --  @return An immutable, reusable custom configuration.
   function Create
     (Polynomial    : Value;
      Initial_Value : Value;
      Reflected     : Boolean;
      Final_XOR     : Value) return Parameters;

   --  Compute a predefined CRC-16 over Data in one call. Data is borrowed for
   --  the call and is not copied or retained.
   --
   --  @param Kind Predefined algorithm to use.
   --  @param Data Input bytes, which may be empty.
   --  @return The completed CRC, including the algorithm's final XOR.
   function Compute (Kind : Algorithm; Data : Byte_Array) return Value;

   --  Compute a configured CRC-16 over Data in one call. Data is borrowed for
   --  the call and is not copied or retained.
   --
   --  @param Configuration CRC parameters to use.
   --  @param Data Input bytes, which may be empty.
   --  @return The completed CRC, including the configured final XOR.
   function Compute
     (Configuration : Parameters;
      Data          : Byte_Array) return Value;

   --  Mutable state for an incremental CRC-16 computation. Assignment creates
   --  an independent copy of the computation state.
   type Context is private;

   --  Start an incremental computation for a predefined algorithm.
   --
   --  @param Kind Predefined algorithm to use.
   --  @return A context in its initial state.
   function Start (Kind : Algorithm) return Context;

   --  Start an incremental computation for a custom configuration.
   --
   --  @param Configuration CRC parameters to use.
   --  @return A context in its initial state.
   function Start (Configuration : Parameters) return Context;

   --  Restore Object to the initial state of its existing configuration.
   --
   --  @param Object Context to reset.
   procedure Reset (Object : in out Context);

   --  Incorporate Data into Object. Data is borrowed for the call and is not
   --  copied or retained. Updating with an empty array leaves the CRC state
   --  unchanged.
   --
   --  @param Object Context to update.
   --  @param Data Next input bytes.
   procedure Update (Object : in out Context; Data : Byte_Array);

   --  Return the completed value of Object without changing or resetting it.
   --  More data may be supplied with Update after this call.
   --
   --  @param Object Context to inspect.
   --  @return The completed CRC, including the configured final XOR.
   function Result (Object : Context) return Value;

   --  Combine CRCs of two adjacent byte sequences computed with Kind. The
   --  caller must supply the exact byte length of the right sequence and use
   --  the same algorithm for both input CRCs.
   --
   --  @param Kind Predefined algorithm used for Left and Right.
   --  @param Left Completed CRC of the first sequence.
   --  @param Right Completed CRC of the immediately following sequence.
   --  @param Right_Byte_Length Length in bytes of the right sequence.
   --  @return The completed CRC of the concatenated sequences.
   function Combine
     (Kind              : Algorithm;
      Left, Right       : Value;
      Right_Byte_Length : Byte_Count) return Value;

   --  Combine CRCs of two adjacent byte sequences computed with Configuration.
   --  The caller must supply the exact byte length of the right sequence and
   --  use the same configuration for both input CRCs.
   --
   --  @param Configuration CRC parameters used for Left and Right.
   --  @param Left Completed CRC of the first sequence.
   --  @param Right Completed CRC of the immediately following sequence.
   --  @param Right_Byte_Length Length in bytes of the right sequence.
   --  @return The completed CRC of the concatenated sequences.
   function Combine
     (Configuration     : Parameters;
      Left, Right       : Value;
      Right_Byte_Length : Byte_Count) return Value;

private
   package Core is new Generic_Core (Value => Value, Width => 16);

   type Parameters is record
      Data : Core.Parameters;
   end record;

   type Context is record
      Data : Core.Context;
   end record;
end Flyology_CRC.Width_16;
