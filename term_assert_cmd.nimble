# Package
version       = "0.1.0"
author        = "Metacraft Labs"
description   = "Shell-script CLI for talking to a running TermAssert harness — equivalent of agent-harbor's tui-testing-cmd"
license       = "MIT"
srcDir        = "src"
bin           = @["cli/nim_tui_test_cmd"]
binDir        = ""
namedBin["cli/nim_tui_test_cmd"] = "term-assert-cmd"

# Dependencies
requires "nim >= 2.0.0"
