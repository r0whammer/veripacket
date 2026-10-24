-- M4 proofs: `parse_packet` returns fields that agree with the source bytes.
--
-- `m ⦃ r => P r ⦄` is Aeneas's total-correctness triple: `m` terminates
-- normally with a value `r` satisfying `P r` (see `ValidPacket.lean`).
module

public import VeriPacket.Properties.ValidPacket

@[expose] public section

namespace VeriPacket

open Aeneas Aeneas.Std Result
open VeriPacket.Spec

/-! ## Spec lemmas (pure list reasoning) -/

/-- A parse is only ever produced from a valid packet. -/
theorem IsParseOf.isValidPacket {l : List U8} {kind : U8} {payload : List U8}
    (h : IsParseOf l kind payload) : IsValidPacket l := by
  obtain ⟨hi, lo, rfl, hlen⟩ := h
  simp only [IsValidPacket, List.length_cons]
  grind

/-- A valid packet parses to its byte just after the header (offset 2) and
everything after that byte. -/
theorem isParseOf_of_isValidPacket {l : List U8} (h : IsValidPacket l)
    (h2 : headerLen < l.length) :
    IsParseOf l l[headerLen] (l.drop minPacketLen) := by
  match l, h with
  | hi :: lo :: kind :: payload, h =>
    simp only [IsValidPacket, List.length_cons] at h
    exact ⟨hi, lo, by simp [headerLen, minPacketLen], by simpa [minPacketLen] using h.2⟩

/-- The parse of a byte list is unique. -/
theorem IsParseOf.unique {l : List U8} {k₁ k₂ : U8} {p₁ p₂ : List U8}
    (h₁ : IsParseOf l k₁ p₁) (h₂ : IsParseOf l k₂ p₂) : k₁ = k₂ ∧ p₁ = p₂ := by
  obtain ⟨_, _, rfl, _⟩ := h₁
  obtain ⟨_, _, h, _⟩ := h₂
  simp_all

/-! ## Generated functions -/

@[step]
theorem Packet.impl.kind_spec (p : Packet) :
    Packet.impl.kind p ⦃ k => k = p.kind ⦄ := by
  simp [Packet.impl.kind]

@[step]
theorem Packet.impl.payload_spec (p : Packet) :
    Packet.impl.payload p ⦃ s => s = p.payload ⦄ := by
  simp [Packet.impl.payload]

/-- Functional correctness: `parse_packet` returns normally on every input,
returns `none` exactly on invalid buffers, and otherwise returns the unique
parse of the buffer. -/
theorem parse_packet_spec (buf : Slice U8) :
    parse_packet buf ⦃ r => match r with
      | none => ¬ IsValidPacket buf.val
      | some p => IsParseOf buf.val p.kind p.payload.val ⦄ := by
  unfold parse_packet
  step with valid_packet_spec as ⟨ b, hb ⟩
  split
  · have hvalid := hb.mp (by assumption)
    have hmin := IsValidPacket.min_length hvalid
    step as ⟨ k, hk ⟩
    · simp [headerLen, minPacketLen] at *; scalar_tac
    step as ⟨ s, hs, _ ⟩
    have h2 : headerLen < buf.val.length := by
      unfold headerLen; unfold minPacketLen at hmin; scalar_tac
    simp only [hk, hs]
    simpa [minPacketLen] using isParseOf_of_isValidPacket hvalid h2
  · simp only [WP.spec_ok]
    intro hvalid
    simp_all

/-! ## M4 properties -/

/-- `parse_packet` returns normally on every input. -/
theorem parse_packet_returns_normally (buf : Slice U8) :
    parse_packet buf ⦃ _ => True ⦄ :=
  WP.spec_mono (parse_packet_spec buf) fun _ _ => trivial

/-- `parse_packet` succeeds exactly on the buffers `valid_packet` accepts. -/
theorem parse_packet_some_iff_valid (buf : Slice U8) :
    parse_packet buf ⦃ r => r.isSome ↔ IsValidPacket buf.val ⦄ := by
  apply WP.spec_mono (parse_packet_spec buf)
  intro r hr
  match r, hr with
  | none, hr => simpa using hr
  | some _, hr => simpa using IsParseOf.isValidPacket hr

/-- The parsed `kind` is the source byte at offset 2. -/
theorem parsed_kind_is_source_byte (buf : Slice U8) :
    parse_packet buf ⦃ r => ∀ p, r = some p → buf.val[2]? = some p.kind ⦄ := by
  apply WP.spec_mono (parse_packet_spec buf)
  rintro _ hr p rfl
  obtain ⟨_, _, h, _⟩ := hr
  simp [h]

/-- The parsed payload is exactly the source bytes from offset 3 (just after
`kind`) to the end of the buffer. -/
theorem parsed_payload_is_suffix (buf : Slice U8) :
    parse_packet buf ⦃ r => ∀ p, r = some p →
      p.payload.val = buf.val.drop minPacketLen ⦄ := by
  apply WP.spec_mono (parse_packet_spec buf)
  rintro _ hr p rfl
  obtain ⟨_, _, h, _⟩ := hr
  simp [h, minPacketLen]

/-- The parsed payload plus the `kind` byte is exactly as long as the
big-endian length declared in the buffer's first two bytes. -/
theorem parsed_payload_length_matches_header (buf : Slice U8) :
    parse_packet buf ⦃ r => ∀ p, r = some p →
      ∃ hi lo, buf.val.take headerLen = [hi, lo] ∧
        p.payload.length + 1 = decodeLength hi.val lo.val ⦄ := by
  apply WP.spec_mono (parse_packet_spec buf)
  rintro _ hr p rfl
  obtain ⟨hi, lo, h, hlen⟩ := hr
  exact ⟨hi, lo, by simp [h, headerLen], hlen⟩

end VeriPacket
