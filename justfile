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
    @if compgen -G "{{ generated }}/*_Template.lean" > /dev/null; then \
      echo "note: external-model templates generated; review before use:"; \
      ls {{ generated }}/*_Template.lean; \
    fi

# Build the Lean project and check all proofs
proofs: _proofs-ready
    cd proofs && lake build

# Fail if the committed Lean model is stale relative to the Rust source
check-generated: translate
    git diff --exit-code -- {{ generated }}
    @test -z "$(git status --porcelain -- {{ generated }})" || \
      { echo "untracked generated files in {{ generated }}"; exit 1; }

# End to end: Rust checks, regenerate the model, check proofs
verify: check translate proofs

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
