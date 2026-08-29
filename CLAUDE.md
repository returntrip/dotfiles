# CLAUDE.md

## Workflow notes

- Chezmoi dotfiles repo. The source tree is under `home/`; `home/.chezmoi.toml.tmpl` is the config template that computes machine flags (`isLinux`, `isWSL`, `isMacOS`, `isBlueX`, `isTTY`, `machineClass`, `work`/`personal`).
- After changing the config template, the target machine must run `chezmoi init` to regenerate its config — chezmoi does not auto-re-render a changed config template, it warns "run chezmoi init to regenerate config file". Then `chezmoi apply`.
- Machine classification lives in `home/.chezmoidata/machines.yaml` (hostname → work/personal). Unknown hostnames prompt once at init.
- Git push is done by the user via Zed from the host. Never set sandbox-https as the default upstream.

## TODO

- **macOS shell**: decided — macOS uses zsh with `dot_zshrc.tmpl` (cross-shell bits: aliases, addalias, EDITOR, atuin, mise, starship, secretsload). bash-only files (`.bashrc`, `.bash_aliases`, `.bash_profile`, `.inputrc`, blesh) stay excluded from macOS. Near term: verify the zshrc on a real Mac. Longer term: port the Linux side (`.bashrc` + `.bash_aliases`) to zsh so it's zsh everywhere — `shell-common` is already shared and mostly shell-agnostic, easing that port; then fold it into a single `zshrc` and drop the bash files. Chose zsh over fish (non-POSIX).
- **nono work variants**: dropped — no work-machine nono agents planned.
- **Zellij scroll-by-command (OSC 133)**: `[`/`]` (jump between prompts)
  and `c` (copy last command's output) work reliably as of `dot_bashrc.tmpl`'s
  current `blehook`-based ble.sh integration. `m` (select command + output)
  is a **known, unresolved limitation**: it reliably selects the right
  region but only ever gives the output, never the command line too —
  see "Known limitation" below before spending more time on it.

  Bugs found and fixed along the way (all confirmed via byte capture —
  `script -qc bash file.log` then `grep -aoE
  $'\033\]133;[A-D][^\a\033]{0,20}' file.log`; viewing a raw OSC log
  directly, e.g. `cat -v`, can leak an unterminated mouse-tracking-enable
  sequence into the real terminal and break mouse selection — `reset` or
  `printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1015l\e[?25h'` recovers
  it):
  - `blehook` is a plain function (`blehook NAME+=handler`, one token, no
    slash) — `blehook/PRECMD += handler` parses as a command containing a
    `/` and fails silently at startup ("No such file or directory"), so
    nothing was ever registered through several earlier attempts.
  - Mark `A` printf'd from `precmd` goes stale: ble.sh erases/redraws the
    prompt for its own layout passes between `precmd` and Enter, and a
    `printf`'d mark's screen position doesn't survive that. Fixed by
    embedding `A` inside `PS1` itself so it rides along with every redraw
    (mirrors WezTerm's ble.sh-aware integration).
  - The `PS1` wrap must not accumulate: without undoing it, `PS1` grows by
    a nested layer every single prompt, unbounded, and scrollback marks
    become garbage within a few commands. `precmd` is self-healing instead
    — if `PS1` still equals exactly what was set last cycle, unwrap back
    to the saved base before wrapping again.
  - `$?` must be captured before `[[ ]]` runs (it clobbers `$?` first) or
    `D`'s exit code is always wrong; the non-ble.sh branch must *append*
    its hook to `PROMPT_COMMAND`, not prepend, or it runs before
    starship's `PS1` rewrite and loses everything appended to `PS1`.
  - `/etc/profile.d/vte.sh` (Ptyxis/GNOME's own OSC 133 integration,
    active whenever `$VTE_VERSION` is set, which is every pane here) was
    independently emitting its own `C` mark via plain bash's native `PS0`
    mechanism — not routed through ble.sh, so it fires regardless and
    doubled up with ours (confirmed: `C` firing 2× per prompt, one from
    each source). Its `A`/`B`/`D` contribution is harmless in practice
    (baked once into `PS1` at shell startup, then wiped by starship's
    first dynamic `PS1` render), but `C` lives in `PS0`, which nothing
    else touches, so it persists. Fixed by clearing `PS0` in the ble.sh
    branch so ours is the only source.

  **Known limitation, not expected to be fixable from `.bashrc`**: `B`
  (command-start, needed for `m` to include the command line) was tested
  every way that seemed reasonable — embedded in `PS1` next to `A`
  (works for `A`, not `B`), `printf`'d from `preexec` at the same proven
  timing as `C` (also failed, and was a conceptual error besides — lands
  at the *end* of the typed command, not the start), with the VTE
  duplication eliminated (no change), and across environments:
  - Plain bash, no ble.sh: **100% reliable** — the only environment where
    `B` has ever worked correctly.
  - Plain zsh, no live-redraw editor at all (so it can't be a redraw-race
    like ble.sh's): **100% consistently wrong**, always output-only.
  - bash + ble.sh (the real daily driver): **intermittent** — mostly
    output-only, occasionally correct, no identified pattern to *which*
    commands.
  - Fish (native OSC 133, zero shell-side code): also output-only,
    matching zsh, not bash.

  Three different failure patterns across three environments using
  structurally the same technique is genuinely strange and beyond what's
  diagnosable from the shell-script side — plain bash being the *only*
  reliable case, with zsh/fish/ble.sh all failing in different ways,
  suggests the gap is in how zellij's `SelectCommandAtScrollPosition`
  resolves `B`, not in any of these shells' mark delivery. Worth filing
  upstream with zellij directly if picked back up — the isolation here is
  about as clean as it gets. Also noticed but not chased: `[`/`]` combined
  with pane frames off (`pane_frames false`, this config's setting)
  sometimes needs pressing twice to land on the actual input line vs. the
  first line of a multi-line prompt; no explanation found.

  Misc: scroll mode is reached via `Ctrl g` (locked→normal) then `s` (or
  `Ctrl s` directly, added to `shared_except "locked"`). Search in scroll
  mode is bound to `f`, NOT `/` — `clear-defaults=true` means zellij's
  stock bindings don't exist unless redefined here (this is zellij's own
  actual default too, confirmed against its `default.kdl`), so `/` is
  simply unbound, not broken; add `bind "/" { SwitchToMode "entersearch";
  SearchInput 0; }` to the `scroll` block if wanted. Keybindings
  `[`/`]`/`m`/`c` are in scroll mode.

## Security model (Zed agents)

- Every Zed agent runs through nono (no unsandboxed agent). Claude + DeepSeek
  both use nono profiles; the old claude-acp registry agent was removed.
- Secrets are bws-referenced at apply time: the repo only contains bws secret
  IDs, never values. Values materialize at `chezmoi apply` via bitwardenSecrets.
- settings.json is 0600 (private_).
- Real secrets (FORGEJO_TOKEN, DEEPSEEK_REAL_KEY, CLAUDE_CODE_OAUTH_TOKEN) are
  rendered into 0600 files under `~/.config/nono/secrets/` by chezmoi, and
  nono's proxy (custom_credentials) injects them as `Authorization: Bearer`
  on egress. The agent process env only ever holds a placeholder
  (nono-phantom-placeholder) or a SHA-256 hash of the secret, never the raw
  value — so the cross-agent /proc/<pid>/environ leak is closed.
- The DeepSeek SDK reads the placeholder from ANTHROPIC_AUTH_TOKEN; the proxy
  swaps in the real key for api.deepseek.com. Claude Code reads
  CLAUDE_CODE_OAUTH_TOKEN; the claude_oauth proxy credential handles
  api.anthropic.com.
- nono requires `env_var` on each file:// custom_credential — that's the
  variable name the proxy resolves the file secret into; it does not expose
  the raw value to the child.

## nono Landlock cwd interaction

A bare `nono run --profile ...` from the **home directory** fails with
"Landlock deny-overlap": nono wants to share the cwd (home) as an allowed
parent, which conflicts with the ~48 default denies (e.g. ~/.1password,
~/.aws, ~/.bash_history) — Landlock can't express deny-under-allow. Running
from a non-home dir (`cd /tmp`) works fine. Zed launches agents with a
different cwd, so they never hit it. Not a nono regression; a cwd-vs-deny
interaction.

## Template safety rule (empty-render hazard)

A template that can render empty on some profile will **overwrite an existing
target with an empty file** on that profile (this zeroed `~/.ssh/config` on
macOS: `dot_ssh/config.tmpl` renders only when `.isWSL`). Any template whose
literal output is entirely inside an `if`-gate **must** either:

- be ignored on the profiles where it would render empty (`.chezmoiignore`), or
- render a non-empty safe default on those profiles.

Before adding or editing a template, check it cannot render empty on any
machine class. `chezmoi apply --dry-run --verbose` shows what each profile
would write.
