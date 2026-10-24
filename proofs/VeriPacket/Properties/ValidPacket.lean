-- M3 proofs: the generated `valid_packet` model agrees with `Spec.IsValidPacket`.
--
-- `m ⦃ r => P r ⦄` is Aeneas's total-correctness triple: `m` terminates
-- normally (no panic, no out-of-bounds index, no overflow, no divergence)
-- with a value `r` satisfying `P r`.
module

public import VeriPacket.Code.Funs
public import VeriPacket.Spec.Packet

@[expose] public section

namespace VeriPacket

open Aeneas Aeneas.Std Result
open VeriPacket.Spec

/-! ## Generated constants -/

@[simp, scalar_tac_simps, grind =, agrind =]
theorem HEADER_LEN_val : HEADER_LEN.val = headerLen := by
  simp [HEADER_LEN, headerLen]

@[simp, scalar_tac_simps, grind =, agrind =]
theorem MIN_PACKET_LEN_val : MIN_PACKET_LEN.val = minPacketLen := by
  simp [MIN_PACKET_LEN, minPacketLen]

/-! ## Spec lemmas (pure list reasoning) -/

/-- Buffers shorter than the minimum packet are never valid. -/
theorem not_isValidPacket_of_short (l : List U8) (h : l.length < minPacketLen) :
    ¬ IsValidPacket l := by
  match l with
  | [] => simp [IsValidPacket]
  | [_] => simp [IsValidPacket]
  | [_, _] => simp [IsValidPacket]
  | _ :: _ :: _ :: _ => grind [minPacketLen]

/-- For buffers of at least minimum length, validity is exactly the
index-based check that `valid_packet` performs. -/
theorem isValidPacket_iff (l : List U8) (h : minPacketLen ≤ l.length) :
    IsValidPacket l ↔
      l.length - headerLen = decodeLength (l[0]'(by grind [minPacketLen])).val
        (l[1]'(by grind [minPacketLen])).val := by
  match l with
  | [] | [_] | [_, _] => simp [minPacketLen] at h
  | hi :: lo :: k :: rest =>
    simp only [IsValidPacket, headerLen, List.length_cons, List.getElem_cons_zero,
      List.getElem_cons_succ]
    grind

/-- Every valid packet has at least the minimum packet length. -/
theorem IsValidPacket.min_length {l : List U8} (h : IsValidPacket l) :
    minPacketLen ≤ l.length := by
  match l, h with
  | _ :: _ :: _, h =>
    simp only [IsValidPacket] at h
    grind [minPacketLen]

/-! ## Generated functions -/

/-- `declared_length` never overflows and computes the big-endian value. -/
@[step]
theorem declared_length_spec (hi lo : U8) :
    declared_length hi lo ⦃ n => n.val = decodeLength hi.val lo.val ⦄ := by
  unfold declared_length decodeLength
  step*

/-- Functional correctness: `valid_packet` returns normally on every input
and accepts exactly the buffers that satisfy `IsValidPacket`. -/
theorem valid_packet_spec (buf : Slice U8) :
    valid_packet buf ⦃ b => (b = true ↔ IsValidPacket buf.val) ⦄ := by
  unfold valid_packet
  dsimp only
  split
  · simp only [WP.spec_ok, Bool.false_eq_true, false_iff]
    apply not_isValidPacket_of_short
    scalar_tac
  · have hmin : minPacketLen ≤ buf.length := by scalar_tac
    step as ⟨ i1, i1_post ⟩
    · simp [minPacketLen] at hmin; scalar_tac
    step as ⟨ i2, i2_post ⟩
    · simp [minPacketLen] at hmin; scalar_tac
    step as ⟨ declared, declared_post ⟩
    step as ⟨ i4, i4_post ⟩
    · simp [headerLen, minPacketLen] at *; scalar_tac
    rw [isValidPacket_iff buf.val hmin]
    simp only [decide_eq_true_eq, UScalar.eq_equiv, i4_post, declared_post, i1_post,
      i2_post, Slice.len_val, HEADER_LEN_val]

/-! ## M3 properties

Each is a corollary of `valid_packet_spec`. Every triple below also asserts
that `valid_packet` returns normally on its input. -/

/-- `valid_packet` returns normally (no panic, overflow, out-of-bounds access,
or divergence) on every input. -/
theorem valid_packet_returns_normally (buf : Slice U8) :
    valid_packet buf ⦃ _ => True ⦄ :=
  WP.spec_mono (valid_packet_spec buf) fun _ _ => trivial

/-- An accepted buffer is at least `minPacketLen` (3) bytes long. -/
theorem accepted_implies_min_length (buf : Slice U8) :
    valid_packet buf ⦃ b => b = true → minPacketLen ≤ buf.length ⦄ :=
  WP.spec_mono (valid_packet_spec buf) fun _ hb hacc => IsValidPacket.min_length (hb.mp hacc)

/-- An accepted buffer is a 2-byte header `hi lo` followed by a body whose
length is exactly the declared big-endian length. -/
theorem accepted_length_matches_header (buf : Slice U8) :
    valid_packet buf ⦃ b => b = true →
      ∃ hi lo body, buf.val = hi :: lo :: body ∧
        body.length = decodeLength hi.val lo.val ⦄ := by
  apply WP.spec_mono (valid_packet_spec buf)
  intro b hb hacc
  have hvalid := hb.mp hacc
  match hl : buf.val, hvalid with
  | hi :: lo :: body, hvalid =>
    simp only [IsValidPacket] at hvalid
    exact ⟨hi, lo, body, rfl, hvalid.2⟩

/-- Buffers shorter than `minPacketLen` (3) bytes are rejected. -/
theorem short_packets_rejected (buf : Slice U8) (h : buf.length < minPacketLen) :
    valid_packet buf ⦃ b => b = false ⦄ := by
  apply WP.spec_mono (valid_packet_spec buf)
  intro b hb
  cases b
  · rfl
  · exact absurd (hb.mp rfl) (not_isValidPacket_of_short buf.val h)

end VeriPacket
