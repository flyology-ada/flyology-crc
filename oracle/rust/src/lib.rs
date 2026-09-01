use crc_fast::{
    checksum, checksum_combine, checksum_with_params, crc32_iscsi, crc32_iso_hdlc, crc64_nvme,
    CrcAlgorithm, CrcParams,
};
use std::ffi::c_void;
use std::slice;

const STATUS_OK: u32 = 0;
const STATUS_UNKNOWN_ALGORITHM: u32 = 1;
const STATUS_NULL_OUTPUT: u32 = 2;
const STATUS_NULL_INPUT: u32 = 3;
const STATUS_INVALID_WIDTH: u32 = 4;
const STATUS_INVALID_KEY_COUNT: u32 = 5;

static ALGORITHMS: [CrcAlgorithm; 50] = {
    use CrcAlgorithm::*;

    [
        Crc16Arc,
        Crc16Cdma2000,
        Crc16Cms,
        Crc16Dds110,
        Crc16DectR,
        Crc16DectX,
        Crc16Dnp,
        Crc16En13757,
        Crc16Genibus,
        Crc16Gsm,
        Crc16Ibm3740,
        Crc16IbmSdlc,
        Crc16IsoIec144433A,
        Crc16Kermit,
        Crc16Lj1200,
        Crc16M17,
        Crc16MaximDow,
        Crc16Mcrf4xx,
        Crc16Modbus,
        Crc16Nrsc5,
        Crc16OpensafetyA,
        Crc16OpensafetyB,
        Crc16Profibus,
        Crc16Riello,
        Crc16SpiFujitsu,
        Crc16T10Dif,
        Crc16Teledisk,
        Crc16Tms37157,
        Crc16Umts,
        Crc16Usb,
        Crc16Xmodem,
        Crc32Aixm,
        Crc32Autosar,
        Crc32Base91D,
        Crc32Bzip2,
        Crc32CdRomEdc,
        Crc32Cksum,
        Crc32Iscsi,
        Crc32IsoHdlc,
        Crc32Jamcrc,
        Crc32Mef,
        Crc32Mpeg2,
        Crc32Xfer,
        Crc64Ecma182,
        Crc64GoIso,
        Crc64Ms,
        Crc64Nvme,
        Crc64Redis,
        Crc64We,
        Crc64Xz,
    ]
};

fn algorithm(id: u32) -> Option<CrcAlgorithm> {
    ALGORITHMS.get(id as usize).copied()
}

unsafe fn input<'a>(data: *const u8, length: usize) -> Result<&'a [u8], u32> {
    if length == 0 {
        Ok(&[])
    } else if data.is_null() {
        Err(STATUS_NULL_INPUT)
    } else {
        Ok(slice::from_raw_parts(data, length))
    }
}

#[no_mangle]
/// Compute one predefined checksum by stable bridge ID.
///
/// # Safety
/// `output` must be writable for one `u64`. When `length` is nonzero, `data`
/// must point to `length` readable bytes. The regions must remain valid for the call.
pub unsafe extern "C" fn flyology_crc_fast_checksum(
    algorithm_id: u32,
    data: *const u8,
    length: usize,
    output: *mut u64,
) -> u32 {
    if output.is_null() {
        return STATUS_NULL_OUTPUT;
    }
    let Some(kind) = algorithm(algorithm_id) else {
        return STATUS_UNKNOWN_ALGORITHM;
    };
    let bytes = match input(data, length) {
        Ok(bytes) => bytes,
        Err(status) => return status,
    };
    output.write(checksum(kind, bytes));
    STATUS_OK
}

#[no_mangle]
/// Prepare an opaque, static benchmark handle for one catalogue algorithm.
pub extern "C" fn flyology_crc_fast_prepare_benchmark(algorithm_id: u32) -> *const c_void {
    ALGORITHMS
        .get(algorithm_id as usize)
        .map_or(std::ptr::null(), |kind| std::ptr::from_ref(kind).cast())
}

#[no_mangle]
/// Compute through a prepared benchmark handle without bridge dispatch.
///
/// # Safety
/// `handle` must be a non-null value returned by
/// `flyology_crc_fast_prepare_benchmark`. When `length` is nonzero, `data`
/// must point to `length` readable bytes. Neither pointer is retained.
pub unsafe extern "C" fn flyology_crc_fast_benchmark_checksum(
    handle: *const c_void,
    data: *const u8,
    length: usize,
) -> u64 {
    let algorithm = *handle.cast::<CrcAlgorithm>();
    let bytes = if length == 0 {
        &[]
    } else {
        slice::from_raw_parts(data, length)
    };
    checksum(algorithm, bytes)
}

#[no_mangle]
/// Combine two predefined checksums by stable bridge ID.
///
/// # Safety
/// `output` must be writable for one `u64` and remain valid for the call.
pub unsafe extern "C" fn flyology_crc_fast_combine(
    algorithm_id: u32,
    left: u64,
    right: u64,
    right_byte_length: u64,
    output: *mut u64,
) -> u32 {
    if output.is_null() {
        return STATUS_NULL_OUTPUT;
    }
    let Some(kind) = algorithm(algorithm_id) else {
        return STATUS_UNKNOWN_ALGORITHM;
    };
    output.write(checksum_combine(kind, left, right, right_byte_length));
    STATUS_OK
}

#[no_mangle]
/// Compute a checksum using caller-supplied Rocksoft parameters.
///
/// # Safety
/// `output` must be writable for one `u64`. When `length` is nonzero, `data`
/// must point to `length` readable bytes. The regions must remain valid for the call.
pub unsafe extern "C" fn flyology_crc_fast_checksum_custom(
    width: u32,
    polynomial: u64,
    initial_value: u64,
    reflected: u32,
    final_xor: u64,
    data: *const u8,
    length: usize,
    output: *mut u64,
) -> u32 {
    if output.is_null() {
        return STATUS_NULL_OUTPUT;
    }
    if width != 16 && width != 32 && width != 64 {
        return STATUS_INVALID_WIDTH;
    }
    let bytes = match input(data, length) {
        Ok(bytes) => bytes,
        Err(status) => return status,
    };
    let params = CrcParams::new(
        "Flyology CRC differential custom parameters",
        width as u8,
        polynomial,
        initial_value,
        reflected != 0,
        final_xor,
        0,
    );
    output.write(checksum_with_params(params, bytes));
    STATUS_OK
}

#[no_mangle]
/// Generate crc-fast's 23 fold-by-8 keys for caller-supplied parameters.
///
/// # Safety
/// `output` must point to exactly `output_length` writable `u64` values and
/// remain valid for the call. The bridge requires an output length of 23.
pub unsafe extern "C" fn flyology_crc_fast_folding_keys(
    width: u32,
    polynomial: u64,
    reflected: u32,
    output: *mut u64,
    output_length: usize,
) -> u32 {
    if output.is_null() {
        return STATUS_NULL_OUTPUT;
    }
    if width != 16 && width != 32 && width != 64 {
        return STATUS_INVALID_WIDTH;
    }
    if output_length != 23 {
        return STATUS_INVALID_KEY_COUNT;
    }

    let params = CrcParams::new(
        "Flyology CRC differential folding keys",
        width as u8,
        polynomial,
        0,
        reflected != 0,
        0,
        0,
    );
    let keys = params.keys.to_keys_array_23();
    output.copy_from_nonoverlapping(keys.as_ptr(), keys.len());
    STATUS_OK
}

#[no_mangle]
/// Compute CRC-32/ISCSI through the oracle's specialized entry point.
///
/// # Safety
/// When `length` is nonzero, `data` must point to `length` readable bytes.
pub unsafe extern "C" fn flyology_crc_fast_crc32_iscsi(data: *const u8, length: usize) -> u32 {
    crc32_iscsi(input(data, length).expect("valid benchmark input"))
}

#[no_mangle]
/// Compute CRC-32/AUTOSAR through a fixed benchmark entry point.
///
/// # Safety
/// When `length` is nonzero, `data` must point to `length` readable bytes.
pub unsafe extern "C" fn flyology_crc_fast_crc32_autosar(data: *const u8, length: usize) -> u32 {
    checksum(
        CrcAlgorithm::Crc32Autosar,
        input(data, length).expect("valid benchmark input"),
    ) as u32
}

#[no_mangle]
/// Compute CRC-32/BZIP2 through a fixed benchmark entry point.
///
/// # Safety
/// When `length` is nonzero, `data` must point to `length` readable bytes.
pub unsafe extern "C" fn flyology_crc_fast_crc32_bzip2(data: *const u8, length: usize) -> u32 {
    checksum(
        CrcAlgorithm::Crc32Bzip2,
        input(data, length).expect("valid benchmark input"),
    ) as u32
}

#[no_mangle]
/// Compute CRC-32/ISO-HDLC through the oracle's specialized entry point.
///
/// # Safety
/// When `length` is nonzero, `data` must point to `length` readable bytes.
pub unsafe extern "C" fn flyology_crc_fast_crc32_iso_hdlc(data: *const u8, length: usize) -> u32 {
    crc32_iso_hdlc(input(data, length).expect("valid benchmark input"))
}

#[no_mangle]
/// Compute CRC-64/NVME through the oracle's specialized entry point.
///
/// # Safety
/// When `length` is nonzero, `data` must point to `length` readable bytes.
pub unsafe extern "C" fn flyology_crc_fast_crc64_nvme(data: *const u8, length: usize) -> u64 {
    crc64_nvme(input(data, length).expect("valid benchmark input"))
}

#[no_mangle]
/// Compute CRC-64/ECMA-182 through a fixed benchmark entry point.
///
/// # Safety
/// When `length` is nonzero, `data` must point to `length` readable bytes.
pub unsafe extern "C" fn flyology_crc_fast_crc64_ecma_182(data: *const u8, length: usize) -> u64 {
    checksum(
        CrcAlgorithm::Crc64Ecma182,
        input(data, length).expect("valid benchmark input"),
    )
}
