with Interfaces;

package Flyology_CRC.Width_64 is
   --  Allocation-free CRC-64 computation for predefined and caller-defined
   --  algorithms, including accelerated CRC-64/NVME, incremental state, and
   --  checksum combination.

   --  A completed 64-bit CRC value or a 64-bit algorithm parameter.
   subtype Value is Interfaces.Unsigned_64;

   --  Predefined CRC-64 algorithms, named after the canonical entries in the
   --  RevEng CRC Catalogue.
   --
   --  @enum ECMA_182 CRC-64/ECMA-182.
   --  @enum GO_ISO CRC-64/GO-ISO.
   --  @enum MS CRC-64/MS.
   --  @enum NVME CRC-64/NVME.
   --  @enum REDIS CRC-64/REDIS.
   --  @enum WE CRC-64/WE.
   --  @enum XZ CRC-64/XZ.
   type Algorithm is (ECMA_182, GO_ISO, MS, NVME, REDIS, WE, XZ);

   --  An immutable, reusable CRC-64 configuration. Assignment creates an
   --  independent copy and no dynamic allocation is involved.
   type Parameters is private;

   --  Return the parameters of a predefined CRC-64 algorithm.
   --
   --  @param Kind Predefined algorithm to configure.
   --  @return A reusable configuration for Kind.
   function Parameters_For (Kind : Algorithm) return Parameters;

   --  Create a custom CRC-64 configuration. Reflected applies to both input
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

   --  Compute a predefined CRC-64 over Data in one call. Data is borrowed for
   --  the call and is not copied or retained.
   --
   --  @param Kind Predefined algorithm to use.
   --  @param Data Input bytes, which may be empty.
   --  @return The completed CRC, including the algorithm's final XOR.
   function Compute (Kind : Algorithm; Data : Byte_Array) return Value;

   --  Compute a configured CRC-64 over Data in one call. Data is borrowed for
   --  the call and is not copied or retained.
   --
   --  @param Configuration CRC parameters to use.
   --  @param Data Input bytes, which may be empty.
   --  @return The completed CRC, including the configured final XOR.
   function Compute
     (Configuration : Parameters;
      Data          : Byte_Array) return Value;

   --  Compute CRC-64/NVME using the fastest supported runtime-selected
   --  implementation, with a portable fallback.
   --
   --  @param Data Input bytes, which may be empty.
   --  @return The completed CRC-64/NVME value.
   function Compute_NVME (Data : Byte_Array) return Value;

   --  Mutable state for an incremental CRC-64 computation. Assignment creates
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
   package Core is new Generic_Core (Value => Value, Width => 64);

   type Parameters is record
      Data : Core.Parameters;
   end record;

   type Context is record
      Data : Core.Context;
   end record;
end Flyology_CRC.Width_64;
