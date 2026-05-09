## test_cli_smoke - exec the compiled CLI binary against a tiny in-test
## Unix-socket server and verify the wire protocol works end-to-end.

import std/[unittest, os, posix, osproc, json, options]

proc allocPath(): string =
  var dir = getEnv("TMPDIR")
  if dir.len == 0: dir = "/tmp"
  dir / ("term_assert_cmd_test_" & $getCurrentProcessId() & ".sock")

proc startServer(path: string): cint =
  discard unlink(cstring(path))
  let sh = posix.socket(AF_UNIX, SOCK_STREAM, 0)
  doAssert sh.cint != -1
  var addrUn: Sockaddr_un
  addrUn.sun_family = AF_UNIX.cushort
  copyMem(addr addrUn.sun_path[0], cstring(path), path.len)
  addrUn.sun_path[path.len] = '\0'
  doAssert bindSocket(sh, cast[ptr SockAddr](addr addrUn),
                      SockLen(sizeof(addrUn))) == 0
  doAssert listen(sh, 1) == 0
  return sh.cint

proc compileCli(): string =
  let here = currentSourcePath().parentDir()
  let outDir = here.parentDir() / "test-logs"
  createDir(outDir)
  let outBin = outDir / "term-assert-cmd"
  if not fileExists(outBin):
    let extraPaths =
      "--path:" & here.parentDir() / "src" &
      " --path:" & here.parentDir().parentDir() / "TermAssertClient" / "src"
    let cmd = "nim c --styleCheck:usages --styleCheck:error --mm:orc " &
              "-d:release --threads:on " & extraPaths &
              " -o:" & outBin & " " &
              here.parentDir() / "src" / "cli" / "nim_tui_test_cmd.nim"
    let (output, code) = execCmdEx(cmd)
    doAssert code == 0, "compile failed: " & output
  return outBin

suite "term-assert-cmd CLI smoke":
  test "screenshot command":
    let cli = compileCli()
    let path = allocPath()
    let lfd = startServer(path)
    defer:
      discard posix.close(lfd)
      discard unlink(cstring(path))

    # Spawn the CLI in the background; have the server accept and reply.
    let cmd = cli & " --uri " & path & " --cmd 'screenshot:hello'"
    var p = startProcess("/bin/sh", args = ["-c", cmd], options = {})
    defer: p.close()

    var addrUn: Sockaddr_un
    var alen = SockLen(sizeof(addrUn))
    let sh = posix.accept(SocketHandle(lfd),
                          cast[ptr SockAddr](addr addrUn), addr alen)
    doAssert sh.cint != -1
    let cfd = sh.cint
    defer: discard posix.close(cfd)

    # Read one line from the client.
    var line = ""
    while true:
      var ch: char
      let n = posix.read(cfd, addr ch, 1)
      if n <= 0: break
      if ch == '\n': break
      line.add ch
    let parsed = parseJson(line)
    check parsed.kind == JObject
    check parsed["cmd"].getStr() == "screenshot"
    check parsed["label"].getStr() == "hello"

    # Reply ok.
    let reply = "{\"ok\":true}\n"
    discard posix.write(cfd, unsafeAddr reply[0], reply.len)

    let exitCode = p.waitForExit()
    check exitCode == 0
