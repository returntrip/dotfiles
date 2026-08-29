# CLAUDE.md

## Workflow notes

- Chezmoi dotfiles repo. The source tree is under `home/`; `home/.chezmoi.toml.tmpl` is the config template that computes machine flags (`isLinux`, `isWSL`, `isMacOS`, `isBlueX`, `isTTY`, `machineClass`, `work`/`personal`).
- After changing the config template, the target machine must run `chezmoi init` to regenerate its config — chezmoi does not auto-re-render a changed config template, it warns "run chezmoi init to regenerate config file". Then `chezmoi apply`.
- Machine classification lives in `home/.chezmoidata/machines.yaml` (hostname → work/personal). Unknown hostnames prompt once at init.
- Git push is done by the user via Zed from the host. Never set sandbox-https as the default upstream.

## TODO

- **macOS shell**: decided — macOS uses zsh with `dot_zshrc.tmpl` (cross-shell bits: aliases, addalias, EDITOR, atuin, mise, starship, secretsload). bash-only files (`.bashrc`, `.bash_aliases`, `.bash_profile`, `.inputrc`, blesh) stay excluded from macOS. Near term: verify the zshrc on a real Mac. Longer term: port the Linux side (`.bashrc` + `.bash_aliases`) to zsh so it's zsh everywhere — `shell-common` is already shared and mostly shell-agnostic, easing that port; then fold it into a single `zshrc` and drop the bash files. Chose zsh over fish (non-POSIX).
- **nono work variants**: dropped — no work-machine nono agents planned.
- **Zellij scroll-by-command**: mise clobbering PROMPT_COMMAND was fixed
  (shims-PATH-only, commit c5cab96). Actual root cause of jump/select never
  working, found by capturing the direct error (it flashed by as a mystery
  "white line" in zellij before the next prompt overwrote it): `blehook`
  is a plain function, called as `blehook NAME+=handler` (one token, no
  spaces, no slash). `dot_bashrc.tmpl` used `blehook/PRECMD += handler`
  (literal slash) — bash parses that as a command name containing a `/`
  and tries to exec it as a file path, failing silently at shell startup
  with "bash: blehook/PRECMD: No such file or directory". Nothing was ever
  registered, through several earlier attempts (an initial lowercase
  `blehook/precmd` typo, "fixed" to `blehook/PRECMD` — same wrong syntax,
  same silent failure). Fixed to `blehook PRECMD+=__zellij_osc133_precmd`
  / `blehook PREEXEC+=__zellij_osc133_preexec`.

  Once hooks actually fired, captured raw OSC bytes via `script -qc bash
  file.log` + `grep -aoE $'\033\]133;[A-D][^\a\033]{0,20}' file.log`
  (viewing the raw log directly, e.g. `cat -v`, is risky — it can contain
  unterminated mouse-tracking enable sequences that leak through and break
  mouse text selection in the real terminal; `reset` or `printf
  '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1015l\e[?25h'` recovers it).
  That capture showed A/D firing exactly once per prompt (correct) but B
  twice and C 2-4 times per prompt. Root cause for B: it was baked
  directly into the `PS1` string and left there — ble.sh redraws PS1 for
  its own internal layout passes, re-emitting whatever's embedded in it
  each time. Fixed by mirroring WezTerm's own ble.sh-aware shell
  integration (`__wezterm_semantic_precmd`/`preexec` in
  wezterm/assets/shell-integration/wezterm.sh): preexec restores PS1 to
  its saved unmarked value (only if PS1 still matches what precmd set —
  skip if something else already changed it) right before the command
  runs, then precmd re-marks it fresh next cycle. C's over-firing is
  separate (ble.sh's PREEXEC can fire for commands it runs internally
  while composing the prompt, not just the user's typed command) — guarded
  with a once-per-cycle flag reset in precmd.

  Also fixed earlier (real but secondary, and moot until the blehook
  syntax landed): mark B was missing entirely at first — only A/C/D were
  emitted; `$?` was captured after `[[ ]]` clobbered it (OSC 133;D always
  reported exit 0); non-ble.sh branch prepended its hook instead of
  appending, so it would've run before starship's PS1 rewrite and lost the
  B mark.

  Bisect settled the cause: in a clean shell with no ble.sh/starship/atuin
  (`printf '%s\n' <PS1/PROMPT_COMMAND/PS0 lines> > /tmp/osctest.rc` then
  `env -u BLE_VERSION bash --rcfile /tmp/osctest.rc -i`, marks as
  `PS1='\[\033]133;A\007\]test$ \[\033]133;B\007\]'`, D via
  PROMPT_COMMAND, C via PS0) `[`/`]` jump correctly. So zellij and the
  marks are both fine — ble.sh's prompt redraw was the whole problem, and
  the working shell's structure (A and B embedded in PS1) is what the
  ble.sh path now mirrors. Note when running this bisect: paste the rcfile
  creation and the `bash --rcfile` launch as two separate pastes, and type
  test commands by hand — pasting the launch together with follow-up lines
  races the new shell's startup and silently leaves PS1 unset (prompt stays
  `bash-5.3$` instead of `test$`, which invalidates the test).

  Still needs end-to-end verification with ble.sh actually enabled
  (`chezmoi update`, fresh pane, test `[`/`]`/`m`). Also: `s` in the config
  = scroll mode; scroll is reached via `Ctrl g` (locked→normal) then `s`.
  Search in scroll mode is bound to `f`, NOT `/` — `clear-defaults=true`
  means zellij's stock bindings don't exist unless redefined here, so `/`
  is unbound and will never do anything (repeatedly mistaken for a bug).
  Keybindings `[`/`]`/`m`/`c` are in scroll mode.

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
