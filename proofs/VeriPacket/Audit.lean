-- Axiom audit for the headline theorems. `lake build VeriPacket.Audit`
-- prints the axioms each depends on; expected: propext, Classical.choice,
-- Quot.sound only (no sorryAx, no project-specific axioms).
import VeriPacket

#print axioms VeriPacket.declared_length_spec
#print axioms VeriPacket.valid_packet_spec
#print axioms VeriPacket.valid_packet_returns_normally
#print axioms VeriPacket.accepted_implies_min_length
#print axioms VeriPacket.accepted_length_matches_header
#print axioms VeriPacket.short_packets_rejected
