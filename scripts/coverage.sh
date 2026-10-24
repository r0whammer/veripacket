#!/usr/bin/env bash
# Line coverage of src/ by the Rust tests, using the LLVM tools shipped in
# the pinned toolchain (no cargo-llvm-cov: its pinned version predates this
# nightly's build-dir layout). Test binaries are located through Cargo's
# JSON output, so the build-dir layout does not matter.
#
# Run from the project root inside `nix develop`. Writes:
#   target/coverage/summary.json  (llvm-cov export -summary-only)
# and prints a per-file report plus the total line coverage percentage.
set -euo pipefail

cd "$(dirname "$0")/.."
out=target/coverage
rm -rf "$out"
mkdir -p "$out"

export CARGO_TARGET_DIR="$out/target"
export RUSTFLAGS="-C instrument-coverage"
export LLVM_PROFILE_FILE="$PWD/$out/profraw/%p-%m.profraw"

# Unit and integration tests (doc tests are not instrumented on stable flags).
cargo test --all-features --lib --tests --quiet
mapfile -t bins < <(cargo test --all-features --lib --tests --no-run \
  --message-format=json 2>/dev/null \
  | jq -r 'select(.reason == "compiler-artifact" and .profile.test) | .executable')

llvm_bin="$(rustc --print target-libdir)/../bin"
"$llvm_bin/llvm-profdata" merge -sparse "$out"/profraw/*.profraw -o "$out/merged.profdata"

objects=()
for bin in "${bins[@]}"; do objects+=(--object "$bin"); done
cov_args=(-instr-profile "$out/merged.profdata" "${objects[@]}"
  --ignore-filename-regex '(/rustc/|/\.cargo/|/tests/)')

"$llvm_bin/llvm-cov" report "${cov_args[@]}"
"$llvm_bin/llvm-cov" export -summary-only "${cov_args[@]}" > "$out/summary.json"
jq -r '"line coverage: \(.data[0].totals.lines.percent | . * 100 | round / 100)%"' "$out/summary.json"
