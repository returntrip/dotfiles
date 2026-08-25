# CLAUDE.md

## Workflow notes

- Chezmoi dotfiles repo. The source tree is under `home/`; `home/.chezmoi.toml.tmpl` is the config template that computes machine flags (`isLinux`, `isWSL`, `isMacOS`, `isBlueX`, `isTTY`, `machineClass`, `work`/`personal`).
- After changing the config template, the target machine must run `chezmoi init` to regenerate its config — chezmoi does not auto-re-render a changed config template, it warns "run chezmoi init to regenerate config file". Then `chezmoi apply`.
- Machine classification lives in `home/.chezmoidata/machines.yaml` (hostname → work/personal). Unknown hostnames prompt once at init.
- Git push is done by the user via Zed from the host. Never set sandbox-https as the default upstream.

## TODO

- **macOS shell**: decided — macOS uses zsh with `dot_zshrc.tmpl` (cross-shell bits: aliases, addalias, EDITOR, atuin, mise, starship, secretsload). bash-only files (`.bashrc`, `.bash_aliases`, `.bash_profile`, `.inputrc`, blesh) stay excluded from macOS. Near term: verify the zshrc on a real Mac. Longer term: port the Linux side (`.bashrc` + `.bash_aliases`) to zsh so it's zsh everywhere — `shell-common` is already shared and mostly shell-agnostic, easing that port; then fold it into a single `zshrc` and drop the bash files. Chose zsh over fish (non-POSIX).
- **nono**: work-machine variants needed. Currently excluded from the work profile entirely.

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

## Known nono issue (v0.74.0)

- A bare `nono run --profile ...` from an interactive shell fails with
  "Landlock deny-overlap": 48 default denies (e.g. ~/.1password, ~/.aws,
  ~/.bash_history) under linux-host-compat conflict with the implicit home
  mount. Agents launched by Zed work (different env context). Appears to be a
  nono v0.74.0 regression, not a dotfiles issue. Blocks testing
  --env-credential from the shell.

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
