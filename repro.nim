## Reprobuild project file for term-assert-cmd.
##
## **Typed-Cross-Project-Deps rollout — a CONSUMER repo (SC-11 develop-mode
## Nim library-source consumption).** Unlike the Wave-0 leaves
## (``nim-pty`` / ``nim-libvterm`` / ``TermAssertClient``), this repo is NOT
## a leaf: its CLI entrypoint ``src/cli/nim_tui_test_cmd.nim`` does
## ``import term_assert_client`` — a module that lives in the sibling
## ``TermAssertClient`` repo's ``src/`` tree, resolvable at build time ONLY
## via the ``Justfile``'s ``--path:../TermAssertClient/src`` (see
## ``Justfile:7``, ``src-paths``). ``TermAssertClient`` is a METACRAFT
## sibling with a landed ``repro.nim`` that exports ``library
## term_assert_client`` (its umbrella ``src/term_assert_client.nim``), so
## this file consumes it with the SC-11 develop-mode pattern per
## ``reprobuild-specs/Cross-Repo-Source-Consumption.md`` §4.2a: a
## ``uses: "term_assert_client"`` selector names the sibling producer, and
## reprobuild threads the sibling's ``src/`` onto this consumer's
## ``nim c --path:`` through the ``nimPathDirs`` aux channel — NO hardcoded
## ``../TermAssertClient/src``, NO direnv.
##
## A Mode 1 / Mode 3 hybrid (per
## ``reprobuild-specs/Three-Mode-Convention-System.md``) modelled on the
## canonical ``runquota/repro.nim`` / ``reprobuild/repro.nim`` recipes and
## the SC-11 consumer shape
## (``reprobuild/tests/integration/t_cross_repo_nim_library_src_threaded_onto_consumer_path.nim``):
##
## * Declares the upstream tool floor + the sibling producer via ``uses:``:
##   the ``nim`` / ``gcc`` toolchain (matching the nimble file's
##   ``requires "nim >= 2.0.0"``) plus ``uses: "term_assert_client"`` (the
##   SC-11 Nim library-source producer). The SC-11 channel resolves the
##   sibling from source (develop override / workspace lock) and threads its
##   ``src/`` onto every ``nim c --path:`` in this package — the executable
##   compile below.
## * Declares ``executable term-assert-cmd`` (the CLI the nimble file names
##   ``namedBin["cli/nim_tui_test_cmd"] = "term-assert-cmd"``) as a
##   naming/visibility record; its producing ``nim.c(...)`` edge lives in
##   the package-level ``build:`` block (the DSL's ``parseExecutable`` only
##   accepts ``name:`` / ``cli:`` body members, so the edge lives one scope
##   out, exactly as ``reprobuild/repro.nim`` does it).
## * Emits, per runnable test file under ``tests/``, a BUILD edge
##   (``buildNimUnittest.build``) that compiles ``build/test-bin/<stem>``
##   and an EXECUTE edge (``edge.testBinary.run``) that runs it — the
##   two-edge test template from ``reprobuild-specs/Package-Model.md``
##   §"The test template". BUILD halves collect into ``test-builds``;
##   EXECUTE halves collect into ``test`` so ``repro build test`` /
##   ``repro test`` materialise the runnable closure. The executable's own
##   ``nim.c`` edge additionally collects into ``apps``.
##
## **Module search path + compile flags.** term-assert-cmd ships no
## ``config.nims`` / ``nim.cfg``; its ``Justfile`` supplies
## ``--path:src --path:tests --path:../TermAssertClient/src`` on every
## ``nim c``. Of those:
##   * ``--path:../TermAssertClient/src`` is the SIBLING import path — NOT
##     hardcoded here; the SC-11 ``uses: "term_assert_client"`` channel
##     threads it onto the executable compile's ``nim c --path:``.
##   * ``--path:src`` is load-bearing for the executable compile
##     (``src/cli/nim_tui_test_cmd.nim`` is under ``src/``, but the CLI
##     imports nothing from a sibling ``src/`` module beyond
##     ``term_assert_client``; ``--path:src`` is passed via ``paths`` on the
##     executable edge to mirror the repo's own compile).
##   * ``--path:tests`` is redundant — the single test imports no
##     ``tests/``-local helper module (only ``std/*``).
##
## Each edge reproduces the repo's DEFAULT matrix point — ``just test`` →
## ``test-orc`` → ``_matrix orc release on`` → ``nim c … --mm:orc
## -d:release --threads:on``: ``--mm:orc`` via ``mm:``, ``-d:release`` via
## ``defines:``, ``--threads:on`` via ``threadsOn`` (the wrapper default on
## the test edges; passed explicitly on the executable edge). The
## ``--styleCheck:usages --styleCheck:error`` from ``nim-flags`` is a style
## toggle that doesn't change the produced binary and isn't part of the
## typed ``nim c`` surface, so it's omitted — the corpus compiles + runs
## identically without it.
##
## **Per-test platform gating.** The single test, ``test_cli_smoke.nim``,
## ``import``s ``std/posix`` and builds a ``Sockaddr_un`` Unix-domain server
## (``AF_UNIX`` / ``bindSocket`` / ``listen`` / ``accept``) plus spawns the
## CLI under ``/bin/sh``. Both are POSIX constructs — the file does not
## compile on Windows (no ``Sockaddr_un`` / ``AF_UNIX`` in Nim's Windows
## ``std/posix`` surface) and it carries no in-test
## ``when defined(windows): skip()`` fallback. So it is genuinely
## POSIX-only: gated ``when not defined(windows)`` at extraction so the edge
## is present on Linux/macOS (where it compiles + runs to exit 0) and simply
## absent from the graph on Windows. On this Linux host the edge is in the
## graph and is a real run. (The test recompiles the CLI at run time via its
## own ``compileCli()`` helper — a subprocess ``nim c`` keyed off
## ``currentSourcePath()`` — but the TEST BINARY itself imports only
## ``std/*``, so its own compile needs neither ``--path:src`` nor the
## sibling ``src/``: the two-edge template compiles + runs it as-is.)
##
## **Tool provisioning.** ``defaultToolProvisioning "path"`` matches the
## canonical recipes: the nix dev shell puts ``nim`` + ``gcc`` on ``PATH``,
## so the weak-local PATH resolver is the right default (and SC-11 sibling
## resolution runs in path mode). Without it ``repro build`` refuses to run
## with "typed tool provisioning is required for uses declarations".

import repro_project_dsl

# ``ct_test_nim_unittest`` supplies the ``buildNimUnittest.build(...)``
# typed-tool used by the test BUILD edge and the ``edge.testBinary.run(...)``
# UFCS dispatch for the EXECUTE edge; it also re-exports the ``nim`` typed
# tool (``nim.c(...)``) used by the executable edge, and ``repro_project_dsl``
# so the import order is unimportant. Like the ``nim-stackable-hooks`` /
# ``nim-pty`` / ``TermAssertClient`` leaf recipes, this file does NOT import
# ``ct_test_runner_install`` (engine-coupled, reprobuild-internal): the
# execute edge routes through the engine's default direct-binary runner (run
# the binary, key on exit status), which is exactly the exit-0 verification
# this corpus needs — Nim ``unittest`` prints per-suite results and exits
# non-zero on failure.
import ct_test_nim_unittest

type
  CliTestSpec = object
    ## One entry per runnable test file. ``source`` is the repo-relative
    ## ``.nim`` path; ``binary`` is the ``build/test-bin/<stem>`` output.
    source: string
    binary: string

# POSIX-only test corpus — ``test_cli_smoke.nim`` imports ``std/posix`` and
# builds a ``Sockaddr_un`` Unix-domain server, so it compiles + runs only off
# Windows. Gated ``when not defined(windows)`` at extraction below.
const posixTestSpecs: seq[CliTestSpec] = @[
  CliTestSpec(source: "tests/test_cli_smoke.nim",
    binary: "build/test-bin/test_cli_smoke"),
]

package term_assert_cmd:
  defaultToolProvisioning "path"

  uses:
    # Toolchain floor — the PATH-resolvable binaries the build needs.
    # ``nim`` compiles the CLI executable + the test binary (matching the
    # nimble file's ``requires "nim >= 2.0.0"``); ``gcc`` is the C back-end
    # ``nim c`` shells out to and the linker.
    "nim >=2.0"
    "gcc >=12"
    # SC-11 Nim library-source producer: the sibling ``TermAssertClient``
    # repo exports ``library term_assert_client`` (umbrella
    # ``src/term_assert_client.nim``). This selector makes reprobuild build
    # the sibling from source (develop override / workspace lock) and thread
    # its ``src/`` onto this package's ``nim c --path:`` via the
    # ``nimPathDirs`` aux channel, so ``import term_assert_client`` in
    # ``src/cli/nim_tui_test_cmd.nim`` resolves with NO hardcoded
    # ``../TermAssertClient/src``.
    "term_assert_client"

  # Executable declaration — the CLI the nimble file publishes as
  # ``namedBin["cli/nim_tui_test_cmd"] = "term-assert-cmd"``. A
  # naming/visibility record; its producing ``nim.c(...)`` edge lives in the
  # package-level ``build:`` block (the DSL's ``parseExecutable`` accepts
  # only ``name:`` / ``cli:`` body members).
  executable termAssertCmd:
    name: "term-assert-cmd"

  build:
    # The CLI executable edge. ``paths = @["src"]`` supplies ``--path:src``;
    # the sibling ``TermAssertClient/src`` is threaded by the SC-11
    # ``uses: "term_assert_client"`` channel, NOT hardcoded here. Flags
    # reproduce the repo's default matrix point (``_matrix orc release on``):
    # ``mm = "orc"``, ``defines = @["release"]``, ``threadsOn = true``.
    var appActions: seq[BuildActionDef] = @[]
    appActions.add(nim.c(
      source = "src/cli/nim_tui_test_cmd.nim",
      output = "build/bin/term-assert-cmd",
      defines = @["release"],
      paths = @["src"],
      mm = "orc",
      threadsOn = true,
      actionId = "term_assert_cmd.apps.term-assert-cmd"))
    discard collect("apps", appActions)

    # Two-edge test template (Package-Model.md §"The test template"): one
    # compile BUILD edge + one EXECUTE edge per runnable test file. BUILD
    # halves collect into ``test-builds`` (compile verification); EXECUTE
    # halves collect into ``test`` so ``repro test`` / ``repro build test``
    # materialise the runnable closure (each execute edge transitively
    # depends on its build edge).
    #
    # The test binary imports only ``std/*`` (it recompiles the CLI at run
    # time via its own subprocess ``nim c``), so its compile needs neither
    # ``--path:src`` nor the sibling ``src/``. Flags still reproduce the
    # repo's default matrix point: ``defines = @["release"]``, ``mm = "orc"``,
    # ``threadsOn`` (default).
    var testBuildActions: seq[BuildActionDef] = @[]
    var testExecuteActions: seq[BuildActionDef] = @[]

    proc emitTestPair(source, binary: string;
                      buildActions, executeActions: var seq[BuildActionDef]) =
      var lastSlash = -1
      for i in 0 ..< binary.len:
        if binary[i] == '/' or binary[i] == '\\':
          lastSlash = i
      let stem =
        if lastSlash >= 0: binary[lastSlash + 1 .. ^1]
        else: binary
      let edge = buildNimUnittest.build(
        source = source,
        binary = binary,
        defines = @["release"],
        mm = "orc",
        actionId = "term_assert_cmd.test_build." & stem)
      buildActions.add(edge.action)
      # ``registerImplicitName = false`` because the BUILD edge already owns
      # the binary basename as the implicit target name; the explicit
      # ``actionId`` is the execute edge's selector (two-edge shape).
      let executeEdge = edge.testBinary.run(
        actionId = "term_assert_cmd.test_execute." & stem,
        registerImplicitName = false)
      executeActions.add(executeEdge)

    # POSIX-only tests — the smoke test's Unix-domain-socket server compiles
    # + runs only off Windows; gated at extraction so it never enters the
    # graph on Windows.
    when not defined(windows):
      for spec in posixTestSpecs:
        emitTestPair(spec.source, spec.binary,
          testBuildActions, testExecuteActions)

    discard collect("test", testExecuteActions)
    discard collect("test-builds", testBuildActions)
