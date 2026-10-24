//! VeriPacket: a deliberately small binary packet validator written in safe
//! Rust so that it can be extracted with Charon/Aeneas and verified in Lean 4.
//!
//! # Wire format
//!
//! ```text
//! +-----------------+-----------+---------------------+
//! | length (u16 BE) | kind (u8) | payload (0..N bytes) |
//! +-----------------+-----------+---------------------+
//! ```
//!
//! - `length` counts the bytes **after** the 2-byte header, including the
//!   1-byte `kind` field. All lengths in this crate are measured in bytes.
//! - A buffer holds exactly one packet: it is accepted only when the number of
//!   bytes after the header equals the declared length. Trailing or missing
//!   bytes are rejected.
//! - The smallest valid packet is 3 bytes (header + `kind`, empty payload),
//!   i.e. declared length 1. The largest is 65 537 bytes (declared length
//!   `u16::MAX`).
//!
//! Validation never panics on malformed input; it returns `false`.

#![forbid(unsafe_code)]

/// Size in bytes of the big-endian `length` header.
pub const HEADER_LEN: usize = 2;

/// Size in bytes of the smallest valid packet: header plus `kind`.
pub const MIN_PACKET_LEN: usize = 3;

/// Decodes the big-endian `length` header from its two bytes.
///
/// The result is in `0..=65535`: at most `255 * 256 + 255`, so the
/// arithmetic cannot overflow even on a 16-bit `usize`.
pub fn declared_length(hi: u8, lo: u8) -> usize {
    (hi as usize) * 256 + (lo as usize)
}

/// Returns `true` iff `buf` is exactly one well-formed packet.
///
/// Accepts when `buf.len() >= MIN_PACKET_LEN` and
/// `buf.len() - HEADER_LEN == declared_length(buf[0], buf[1])`; rejects
/// everything else, including empty, truncated, and over-long buffers.
///
/// ```
/// use veripacket::valid_packet;
///
/// assert!(valid_packet(&[0x00, 0x01, 0x07]));        // kind only
/// assert!(valid_packet(&[0x00, 0x03, 0x07, 1, 2]));  // kind + 2-byte payload
/// assert!(!valid_packet(&[0x00, 0x02, 0x07]));       // truncated
/// assert!(!valid_packet(&[]));
/// ```
pub fn valid_packet(buf: &[u8]) -> bool {
    if buf.len() < MIN_PACKET_LEN {
        return false;
    }
    // In bounds: buf.len() >= 3 was checked above.
    let declared = declared_length(buf[0], buf[1]);
    // No underflow: buf.len() >= 3 > HEADER_LEN.
    buf.len() - HEADER_LEN == declared
}
