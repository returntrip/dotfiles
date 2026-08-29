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
  (shims-PATH-only, commit c5cab96), but jump still didn't work because the
  OSC 133 snippet in `dot_bashrc.tmpl` never emitted mark B (command-start) —
  only A/C/D. Without B, zellij has no signal for where the prompt ends and
  command input begins, so `[`/`]`/`m` had no region to act on. Also fixed:
  `$?` was captured after the `[[ ]]` test clobbered it (OSC 133;D always
  reported exit 0), and in the non-ble.sh branch the hook was prepended
  ahead of starship's PROMPT_COMMAND entry instead of appended, so anything
  it appended to PS1 would've been wiped out by starship's own PS1 rewrite.
  Patched; needs verification on a real machine (`chezmoi apply`, open
  zellij, run a couple commands, jump). Also: `s` in the config = scroll
  mode; scroll is reached via `Ctrl g` (locked→normal) then `s`. Keybindings
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
