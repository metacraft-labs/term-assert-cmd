## term-assert-cmd - tiny CLI tool that talks to a running TermAssert
## harness over the Unix-socket IPC. The intended use case is shell
## scripts inside a child process that want to pin a screenshot or
## request a clean exit without linking the Nim client library.
##
## Usage:
##
## ```
## term-assert-cmd --uri <socket-path> --cmd "screenshot:label"
## term-assert-cmd --uri <socket-path> --cmd "exit:0"
## term-assert-cmd --uri <socket-path> --cmd "ping"
## ```
##
## When `--uri` is omitted, the tool reads `$TERM_ASSERT_URI`. Exits 0
## on success, non-zero on failure with a stderr diagnostic.

import std/[os, strutils]
import term_assert_client

const usage = """
term-assert-cmd - shell-script interface to a running TermAssert harness.

Usage:
  term-assert-cmd [--uri PATH] --cmd "screenshot:LABEL"
  term-assert-cmd [--uri PATH] --cmd "exit:CODE"
  term-assert-cmd [--uri PATH] --cmd "ping"

Options:
  --uri PATH    Unix-socket path of the harness IPC server. Defaults to
                $TERM_ASSERT_URI when unset.
  --cmd CMD     One of: screenshot:LABEL, exit:CODE, ping.
  --help, -h    Show this message.
"""

proc fail(msg: string) =
  stderr.writeLine "term-assert-cmd: " & msg
  quit(2)

proc main() =
  var uri = ""
  var cmd = ""
  var i = 1
  while i <= paramCount():
    let a = paramStr(i)
    case a
    of "--uri":
      if i + 1 > paramCount(): fail("--uri requires a value")
      uri = paramStr(i + 1)
      inc i, 2
    of "--cmd":
      if i + 1 > paramCount(): fail("--cmd requires a value")
      cmd = paramStr(i + 1)
      inc i, 2
    of "--help", "-h":
      stdout.write usage
      quit(0)
    else:
      fail("unknown argument: " & a)
  if cmd.len == 0:
    fail("--cmd is required (try --help)")
  if uri.len == 0:
    uri = getEnv("TERM_ASSERT_URI")
  if uri.len == 0:
    fail("no socket URI provided (use --uri or set TERM_ASSERT_URI)")

  var client: TuiTestClient
  try:
    client = connectHarness(uri)
  except CatchableError as e:
    fail("connect: " & e.msg)

  let colon = cmd.find(':')
  let head = if colon < 0: cmd else: cmd[0 ..< colon]
  let tail = if colon < 0: "" else: cmd[colon + 1 .. ^1]

  try:
    case head
    of "screenshot":
      if tail.len == 0: fail("screenshot:LABEL - LABEL is required")
      client.requestScreenshot(tail)
      stdout.writeLine "ok"
    of "exit":
      var code = 0
      if tail.len > 0:
        try: code = parseInt(tail)
        except CatchableError: fail("exit:CODE - CODE must be an integer")
      client.requestExit(code)
      stdout.writeLine "ok"
    of "ping":
      let pong = client.ping()
      stdout.writeLine (if pong: "ok" else: "no-pong")
      if not pong: quit(1)
    else:
      fail("unknown command: " & head)
  except CatchableError as e:
    fail(e.msg)

when isMainModule:
  main()
