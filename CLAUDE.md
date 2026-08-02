# CLAUDE.md

## Workflow notes

- Chezmoi dotfiles repo. The source tree is under `home/`; `home/.chezmoi.toml.tmpl` is the config template that computes machine flags (`isLinux`, `isWSL`, `isMacOS`, `isBlueX`, `isTTY`, `machineClass`, `work`/`personal`).
- After changing the config template, the target machine must run `chezmoi init` to regenerate its config — chezmoi does not auto-re-render a changed config template, it warns "run chezmoi init to regenerate config file". Then `chezmoi apply`.
- Machine classification lives in `home/.chezmoidata/machines.yaml` (hostname → work/personal). Unknown hostnames prompt once at init.
- Git push is done by the user via Zed from the host. Never set sandbox-https as the default upstream.

## TODO

- **macOS shell**: decide between adapting bash configs for zsh vs switching to zsh globally. For now bash-only files (`.bashrc`, `.bash_aliases`, `.bash_profile`, `.inputrc`, blesh) are excluded from macOS because it uses zsh.
- **zed**: needs per-profile config (work vs personal, macOS variant). Currently only ships to personal Linux.
- **nono**: work-machine variants needed. Currently excluded from the work profile entirely.
- **krew-install-packages.sh**: runs on macOS too — confirm whether macOS needs krew plugins, or gate it to Linux.
- **Remove `.chezmoiremove`**: once every machine (t490s, rauros, W5CG2241T4, any Mac) has pulled and run `chezmoi apply`, the stale targets are gone and `.chezmoiremove` becomes a no-op — safe to delete in a follow-up commit.
