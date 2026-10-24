//! Boundary tests for `valid_packet`.

use veripacket::{declared_length, valid_packet, HEADER_LEN, MIN_PACKET_LEN};

/// Builds a buffer with header `declared`, kind `0xAB`, and `body_len - 1`
/// payload bytes (`body_len` bytes after the header in total).
fn packet(declared: u16, body_len: usize) -> Vec<u8> {
    let mut buf = declared.to_be_bytes().to_vec();
    buf.extend((0..body_len).map(|i| if i == 0 { 0xAB } else { i as u8 }));
    buf
}

/// Independent reference model of the format.
fn spec(buf: &[u8]) -> bool {
    buf.len() >= 3 && usize::from(u16::from_be_bytes([buf[0], buf[1]])) == buf.len() - 2
}

#[test]
fn constants() {
    assert_eq!(HEADER_LEN, 2);
    assert_eq!(MIN_PACKET_LEN, 3);
}

#[test]
fn declared_length_is_big_endian() {
    assert_eq!(declared_length(0x00, 0x00), 0);
    assert_eq!(declared_length(0x00, 0x01), 1);
    assert_eq!(declared_length(0x01, 0x00), 256);
    assert_eq!(declared_length(0x12, 0x34), 0x1234);
    assert_eq!(declared_length(0xFF, 0xFF), 65535);
}

#[test]
fn empty_is_rejected() {
    assert!(!valid_packet(&[]));
}

#[test]
fn truncated_headers_are_rejected() {
    assert!(!valid_packet(&[0x00]));
    assert!(!valid_packet(&[0x00, 0x00]));
    assert!(!valid_packet(&[0x00, 0x01])); // declares a kind byte that is missing
}

#[test]
fn exactly_minimal_is_accepted() {
    assert!(valid_packet(&[0x00, 0x01, 0x00]));
    assert!(valid_packet(&[0x00, 0x01, 0xFF]));
}

#[test]
fn zero_declared_length_is_rejected() {
    // A three-byte buffer whose header claims no body.
    assert!(!valid_packet(&[0x00, 0x00, 0x00]));
}

#[test]
fn valid_longer_packets_are_accepted() {
    assert!(valid_packet(&packet(2, 2)));
    assert!(valid_packet(&packet(10, 10)));
    assert!(valid_packet(&packet(256, 256))); // needs the high byte
}

#[test]
fn inconsistent_lengths_are_rejected() {
    // Declared longer than present (truncated body).
    assert!(!valid_packet(&packet(5, 4)));
    assert!(!valid_packet(&packet(256, 255)));
    // Declared shorter than present (trailing bytes).
    assert!(!valid_packet(&packet(4, 5)));
    assert!(!valid_packet(&packet(1, 2)));
}

#[test]
fn byte_order_is_not_little_endian() {
    // [0x01, 0x00] is 256 BE but 1 LE.
    assert!(!valid_packet(&[0x01, 0x00, 0xAB]));
    assert!(valid_packet(&packet(256, 256)));
}

#[test]
fn maximum_representable_length() {
    assert!(valid_packet(&packet(u16::MAX, 65535)));
    assert!(!valid_packet(&packet(u16::MAX, 65534)));
    // One byte more than any header can describe.
    assert!(!valid_packet(&packet(u16::MAX, 65536)));
    assert!(!valid_packet(&packet(0, 65536)));
}

#[test]
fn matches_reference_model_on_small_inputs() {
    for body_len in 0..=300 {
        for declared in [0u16, 1, 2, 3, 255, 256, 257, 299, 300, 301, u16::MAX] {
            let buf = packet(declared, body_len);
            assert_eq!(
                valid_packet(&buf),
                spec(&buf),
                "declared={declared} body_len={body_len}"
            );
        }
    }
    // Buffers shorter than a header.
    for len in 0..HEADER_LEN {
        assert!(!valid_packet(&vec![0x00; len]));
    }
}
