# term-assert-cmd

Shell-script CLI for talking to a running [TermAssert](../TermAssert)
harness. Equivalent of agent-harbor's `tui-testing-cmd` Rust binary.

## What this tool does

Inside a child process running under TermAssert, shell scripts can call
this CLI to request a screenshot, request a clean exit, or ping the
harness — without linking the
[TermAssertClient](../TermAssertClient) Nim library directly.

```sh
term-assert-cmd --uri "$TERM_ASSERT_URI" --cmd "screenshot:main_menu"
term-assert-cmd --cmd "exit:0"   # uses $TERM_ASSERT_URI by default
term-assert-cmd --cmd "ping"
```

## Status

Distributed as a separate Nimble package so users who only need the CLI
don't pull in the full library stack. Public, MIT-licensed.

## Commands

```sh
just build           # compile the CLI + tests
just test            # run the smoke tests
just lint            # nim check + nixfmt --check
just format          # nimpretty + nixfmt
```

## Project structure

```
src/
  cli/nim_tui_test_cmd.nim        # the CLI entrypoint
tests/
  test_cli_smoke.nim              # spawn the CLI under a real harness
.github/workflows/ci.yml          # lint + test
flake.nix                         # nix devShell
Justfile                          # build/test/lint/format
term_assert_cmd.nimble            # single-source-of-truth version
```

## Specs

The authoritative spec for this tool is the **M28** entry in
`Front-Ends/IsoNim/isonim-tui.milestones.org` in the
`codetracer-specs` repo.
