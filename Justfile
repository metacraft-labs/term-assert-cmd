## Justfile - term-assert-cmd.

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

alias t := test
alias fmt := format

# Path-based deps to the sibling client library.
src-paths := "--path:src --path:tests --path:../TermAssertClient/src"

nim-flags := "--styleCheck:usages --styleCheck:error"

tests := "tests/test_cli_smoke.nim"

build:
    @mkdir -p test-logs
    nim c {{nim-flags}} {{src-paths}} --mm:orc -d:release --threads:on \
        -o:test-logs/term-assert-cmd src/cli/nim_tui_test_cmd.nim 2>&1 | tee test-logs/build.log
    @for t in {{tests}}; do \
      echo "Building $t"; \
      nim c {{nim-flags}} {{src-paths}} --mm:orc -d:release --threads:on \
          -o:test-logs/$(basename $t .nim) $t 2>&1 | tee -a test-logs/build.log; \
    done

test: test-orc

test-orc:
    just _matrix orc release on

test-arc:
    just _matrix arc release on

test-refc:
    just _matrix refc release on

test-threads-off:
    just _matrix orc release off

test-all: test-orc test-arc test-refc test-threads-off

_matrix mm mode threads:
    @mkdir -p test-logs
    @for t in {{tests}}; do \
      echo "[{{mm}}/{{mode}}/threads:{{threads}}] $t"; \
      nim c {{nim-flags}} {{src-paths}} \
        --mm:{{mm}} -d:{{mode}} --threads:{{threads}} \
        -r $t 2>&1 | tee -a test-logs/{{mm}}-{{mode}}-threads-{{threads}}.log; \
    done

lint: lint-nim lint-nix

lint-nim:
    @mkdir -p test-logs
    nim check {{nim-flags}} {{src-paths}} --mm:orc src/cli/nim_tui_test_cmd.nim 2>&1 | tee test-logs/lint-nim.log
    @for t in {{tests}}; do \
      echo "Checking $t"; \
      nim check {{nim-flags}} {{src-paths}} --mm:orc --threads:on $t 2>&1 | tee -a test-logs/lint-nim.log; \
    done

lint-nix:
    nixfmt --check flake.nix

format: format-nim format-nix

format-nim:
    @if command -v nimpretty >/dev/null 2>&1; then \
      nimpretty src/cli/*.nim tests/*.nim; \
    else \
      echo "nimpretty not available; skipping Nim formatting"; \
    fi

format-nix:
    nixfmt flake.nix

bump-version version:
    sed -i 's/^version[[:space:]]*=.*/version       = "{{version}}"/' term_assert_cmd.nimble

bench:
    @echo "term-assert-cmd has no benchmark suite — it's a tiny CLI."

bench-quick:
    just bench

clean:
    rm -rf test-logs nim-cache
    find tests -maxdepth 1 -type f -executable -name "test_*" -not -name "*.nim" -delete
