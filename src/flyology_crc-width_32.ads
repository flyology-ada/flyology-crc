with Interfaces;

package Flyology_CRC.Width_32 is
   --  Allocation-free CRC-32 computation for predefined and caller-defined
   --  algorithms, including accelerated one-shot operations, incremental
   --  state, and checksum combination.

   --  A completed 32-bit CRC value or a 32-bit algorithm parameter.
   subtype Value is Interfaces.Unsigned_32;

   --  Predefined CRC-32 algorithms, named after the canonical entries in the
   --  RevEng CRC Catalogue.
   --
   --  @enum AIXM CRC-32/AIXM.
   --  @enum AUTOSAR CRC-32/AUTOSAR.
   --  @enum BASE91_D CRC-32/BASE91-D.
   --  @enum BZIP2 CRC-32/BZIP2.
   --  @enum CD_ROM_EDC CRC-32/CD-ROM-EDC.
   --  @enum CKSUM CRC-32/CKSUM.
   --  @enum ISCSI CRC-32/ISCSI (CRC-32C, Castagnoli).
   --  @enum ISO_HDLC CRC-32/ISO-HDLC.
   --  @enum JAMCRC CRC-32/JAMCRC.
   --  @enum MEF CRC-32/MEF.
   --  @enum MPEG_2 CRC-32/MPEG-2.
   --  @enum XFER CRC-32/XFER.
   type Algorithm is
     (AIXM,
      AUTOSAR,
      BASE91_D,
      BZIP2,
      CD_ROM_EDC,
      CKSUM,
      ISCSI,
      ISO_HDLC,
      JAMCRC,
      MEF,
      MPEG_2,
      XFER);

   --  An immutable, reusable CRC-32 configuration. Assignment creates an
   --  independent copy and no dynamic allocation is involved.
   type Parameters is private;

   --  Return the parameters of a predefined CRC-32 algorithm.
   --
   --  @param Kind Predefined algorithm to configure.
   --  @return A reusable configuration for Kind.
   function Parameters_For (Kind : Algorithm) return Parameters;

   --  Create a custom CRC-32 configuration. Reflected applies to both input
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

   --  Compute a predefined CRC-32 over Data in one call. Data is borrowed for
   --  the call and is not copied or retained.
   --
   --  @param Kind Predefined algorithm to use.
   --  @param Data Input bytes, which may be empty.
   --  @return The completed CRC, including the algorithm's final XOR.
   function Compute (Kind : Algorithm; Data : Byte_Array) return Value;

   --  Compute a configured CRC-32 over Data in one call. Data is borrowed for
   --  the call and is not copied or retained.
   --
   --  @param Configuration CRC parameters to use.
   --  @param Data Input bytes, which may be empty.
   --  @return The completed CRC, including the configured final XOR.
   function Compute
     (Configuration : Parameters;
      Data          : Byte_Array) return Value;

   --  Compute CRC-32/ISCSI (CRC-32C, Castagnoli) using the fastest supported
   --  runtime-selected implementation, with a portable fallback.
   --
   --  @param Data Input bytes, which may be empty.
   --  @return The completed CRC-32/ISCSI value.
   function Compute_ISCSI (Data : Byte_Array) return Value;

   --  Compute CRC-32/ISO-HDLC using the fastest supported runtime-selected
   --  implementation, with a portable fallback.
   --
   --  @param Data Input bytes, which may be empty.
   --  @return The completed CRC-32/ISO-HDLC value.
   function Compute_ISO_HDLC (Data : Byte_Array) return Value;

   --  Mutable state for an incremental CRC-32 computation. Assignment creates
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
   package Core is new Generic_Core (Value => Value, Width => 32);

   type Parameters is record
      Data : Core.Parameters;
   end record;

   type Context is record
      Data : Core.Context;
   end record;
end Flyology_CRC.Width_32;
