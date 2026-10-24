# VeriPacket

An educational binary packet validator in safe Rust, with functional
properties to be verified in Lean 4 via Charon → Aeneas. See `CLAUDE.md` for
the full plan, milestones, and proof policy.

## Packet format

```text
+-----------------+-----------+---------------------+
| length (u16 BE) | kind (u8) | payload (0..N bytes) |
+-----------------+-----------+---------------------+
```

Format decisions (implemented in `src/lib.rs`):

- `length` is big-endian and counts bytes after the 2-byte header, including `kind`.
- A buffer is exactly one packet. Accepted iff `buf.len() >= 3` and
  `buf.len() - 2 == length`. Trailing or missing bytes are rejected.
- Declared length 0 can never be valid (minimum is 1, the `kind` byte).
- Largest packet: declared length 65535, 65537 bytes total.
- Malformed input returns `false`; it never panics.

## Public API

| Item | Meaning |
| --- | --- |
| `HEADER_LEN = 2` | header size in bytes |
| `MIN_PACKET_LEN = 3` | smallest valid packet in bytes |
| `declared_length(hi, lo) -> usize` | decodes the BE header |
| `valid_packet(buf: &[u8]) -> bool` | accepts exactly one well-formed packet |
| `parse_packet(buf: &[u8]) -> Option<Packet<'_>>` | `Some` iff `valid_packet(buf)`; borrows the payload |
| `Packet::kind()` / `Packet::payload()` | byte at offset 2 / bytes from offset 3 to the end |

`Packet` derives `Clone`, `Copy`, `PartialEq`, `Eq` but not `Debug`: the
`core::fmt` slice impl would add an unverified external model to the
Aeneas translation.

## Status

| Milestone | Status |
| --- | --- |
| M0 Foundation | done: Cargo project, `flake.lock`, `proofs/` pinned to Aeneas rev in `flake.lock` (Lean v4.35.0) |
| M1 Minimal validator | implemented and tested (pinned nightly-2026-09-17) |
| M2 Translation | model generated: `proofs/VeriPacket/Code` builds with Lake; no external models needed |
| M3 First proofs | proof checked: `proofs/VeriPacket/Properties/ValidPacket.lean` (`just audit` lists axioms) |
| M4 Parsed structure | proof checked: `proofs/VeriPacket/Properties/ParsePacket.lean` |

## Development

Inside `nix develop` (Linux; the flake supports `x86_64-linux` and `aarch64-linux`):

```sh
cargo fmt --all -- --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-features
```

First-time proof setup (after `nix flake lock` and committing `flake.lock`):

```sh
scripts/init-proofs.sh      # writes proofs/lean-toolchain and proofs/lakefile.toml
charon cargo --preset=aeneas --dest-file=veripacket.llbc
aeneas -backend lean veripacket.llbc -dest proofs -subdir /VeriPacket/Code \
  -split-files -namespace VeriPacket
```

Common tasks are wrapped in the `justfile`; run `just` to list them
(`just check`, `just translate`, `just proofs`, `just verify`).
