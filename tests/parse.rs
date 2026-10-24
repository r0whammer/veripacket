//! Boundary tests for `parse_packet`.

use veripacket::{parse_packet, valid_packet, HEADER_LEN};

/// Builds a buffer with header `declared`, kind `0xAB`, and `body_len - 1`
/// payload bytes (`body_len` bytes after the header in total).
fn packet(declared: u16, body_len: usize) -> Vec<u8> {
    let mut buf = declared.to_be_bytes().to_vec();
    buf.extend((0..body_len).map(|i| if i == 0 { 0xAB } else { i as u8 }));
    buf
}

#[test]
fn empty_and_truncated_are_rejected() {
    assert!(parse_packet(&[]).is_none());
    assert!(parse_packet(&[0x00]).is_none());
    assert!(parse_packet(&[0x00, 0x01]).is_none());
    assert!(parse_packet(&[0x00, 0x02, 0x07]).is_none());
}

#[test]
fn exactly_minimal_has_empty_payload() {
    let p = parse_packet(&[0x00, 0x01, 0x07]).unwrap();
    assert_eq!(p.kind(), 0x07);
    assert!(p.payload().is_empty());
}

#[test]
fn longer_packet_fields() {
    let buf = packet(4, 4);
    let p = parse_packet(&buf).unwrap();
    assert_eq!(p.kind(), 0xAB);
    assert_eq!(p.payload(), &[1, 2, 3]);
}

#[test]
fn payload_borrows_source_buffer() {
    let buf = packet(3, 3);
    let p = parse_packet(&buf).unwrap();
    assert!(std::ptr::eq(p.payload(), &buf[3..]));
}

#[test]
fn inconsistent_lengths_are_rejected() {
    assert!(parse_packet(&packet(5, 4)).is_none());
    assert!(parse_packet(&packet(4, 5)).is_none());
    assert!(parse_packet(&[0x00, 0x00, 0x00]).is_none());
}

#[test]
fn maximum_representable_length() {
    let buf = packet(u16::MAX, 65535);
    let p = parse_packet(&buf).unwrap();
    assert_eq!(p.payload().len(), 65534);
    assert!(parse_packet(&packet(u16::MAX, 65536)).is_none());
}

#[test]
fn agrees_with_valid_packet_and_source_bytes() {
    for body_len in 0..=300 {
        for declared in [0u16, 1, 2, 3, 255, 256, 257, 299, 300, 301, u16::MAX] {
            let buf = packet(declared, body_len);
            let parsed = parse_packet(&buf);
            assert_eq!(parsed.is_some(), valid_packet(&buf));
            if let Some(p) = parsed {
                assert_eq!(p.kind(), buf[HEADER_LEN]);
                assert_eq!(p.payload(), &buf[HEADER_LEN + 1..]);
                assert_eq!(p.payload().len() + 1, usize::from(declared));
            }
        }
    }
}
