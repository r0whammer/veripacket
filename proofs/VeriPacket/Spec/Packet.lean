-- Human-authored specification of the VeriPacket wire format.
-- Stated over plain bytes and natural numbers, independently of the
-- Aeneas-generated model in `VeriPacket/Code`.
module

public import Aeneas

@[expose] public section

namespace VeriPacket.Spec

open Aeneas.Std

/-- Size in bytes of the big-endian `length` header. -/
def headerLen : Nat := 2

/-- Size in bytes of the smallest valid packet: header plus `kind`. -/
def minPacketLen : Nat := 3

/-- Value of a big-endian 16-bit length header with bytes `hi`, `lo`. -/
def decodeLength (hi lo : Nat) : Nat := hi * 256 + lo

/-- `bytes` is exactly one well-formed packet: a 2-byte header `hi lo`
followed by a body (`kind` plus payload) that is at least one byte long and
whose length equals the declared length. -/
def IsValidPacket : List U8 → Prop
  | hi :: lo :: body => 1 ≤ body.length ∧ body.length = decodeLength hi.val lo.val
  | _ => False

end VeriPacket.Spec
