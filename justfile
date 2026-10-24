# VeriPacket task runner. Run `just` to list recipes.
# Every recipe expects the `nix develop` shell (direnv activates it on `cd`).

set shell := ["bash", "-euo", "pipefail", "-c"]

llbc := "veripacket.llbc"
generated := "proofs/VeriPacket/Code"

# List available recipes
default:
    @just --list

# Format Rust sources
fmt:
    cargo fmt --all

# Check Rust formatting without changing files
fmt-check:
    cargo fmt --all -- --check

# Run Clippy with warnings as errors
lint:
    cargo clippy --all-targets --all-features -- -D warnings

# Run unit, integration, and doc tests
test:
    cargo test --all-features

# All Rust checks: format, lint, test
check: fmt-check lint test

# Build and open Rustdoc
doc:
    cargo doc --no-deps --open

# Pin proofs/ to the Aeneas revision in flake.lock (re-run after an Aeneas upgrade)
init-proofs: _nix
    scripts/init-proofs.sh

# Extract the crate to LLBC with Charon
extract: _nix
    charon cargo --preset=aeneas --dest-file={{ llbc }}

# Regenerate the Lean model from fresh LLBC (writes proofs/VeriPacket/Code)
translate: extract
    aeneas -backend lean {{ llbc }} -dest proofs -subdir /VeriPacket/Code \
      -split-files -namespace VeriPacket
    @templates="$(find {{ generated }} -name '*_Template.lean')"; \
    if [ -n "$templates" ]; then \
      echo "note: external-model templates generated; review before use:"; \
      echo "$templates"; \
    fi

# Build the Lean project and check all proofs
proofs: _proofs-ready
    cd proofs && lake build

# Print the axioms each headline theorem depends on; fail on any beyond
# Lean's standard three, or on sorry/admit in human-authored Lean
audit: proofs
    #!/usr/bin/env bash
    set -euo pipefail
    out="$(cd proofs && lake env lean VeriPacket/Audit.lean)"
    echo "$out"
    extra="$(grep -o '\[.*\]' <<< "$out" | tr -d '[] ' | tr ',' '\n' \
      | grep -vxE 'propext|Classical\.choice|Quot\.sound' | sort -u || true)"
    if [ -n "$extra" ]; then echo "unexpected axioms:"; echo "$extra"; exit 1; fi
    if grep -rnwE 'sorry|admit' proofs/VeriPacket.lean proofs/VeriPacket/Spec proofs/VeriPacket/Properties; then
      echo "placeholder found in human-authored Lean"; exit 1
    fi

# Fail if the committed Lean model is stale relative to the Rust source
check-generated: translate
    git diff --exit-code -- {{ generated }}
    @test -z "$(git status --porcelain -- {{ generated }})" || \
      { echo "untracked generated files in {{ generated }}"; exit 1; }

# End to end: Rust checks, regenerate the model, check proofs
verify: check translate proofs

# Line coverage of src/ by the Rust tests (writes target/coverage/summary.json)
coverage:
    scripts/coverage.sh

# Run every pre-commit hook against the whole tree
hooks:
    pre-commit run --all-files

# Remove Cargo build output and LLBC (keeps generated Lean)
clean:
    cargo clean
    rm -f {{ llbc }}

[private]
_nix:
    @test -n "${AENEAS_SOURCE:-}" || { echo "run inside nix develop (or allow direnv)"; exit 1; }

[private]
_proofs-ready: _nix
    @test -f proofs/lakefile.toml || { echo "proofs/ not set up; run: just init-proofs"; exit 1; }
