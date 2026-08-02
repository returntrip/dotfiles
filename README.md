# chezmoi dotfiles management

To apply my dotfiles:

`sh -c "$(curl -fsLS https://raw.githubusercontent.com/returntrip/dotfiles/main/cminit)"`

## Removing managed files

chezmoi does not delete a destination file when its source is removed — the
target becomes unmanaged and stays on disk. There are three ways to remove a
managed file, depending on the situation.

### 1. `chezmoi destroy` — best while the source still exists

Removes the source entry, the destination file, and the state in one step.
Run from the destination directory (e.g. `cd ~`), while the file is still
managed:

```sh
chezmoi destroy .local/bin/toolbox-base-runner
```

### 2. `remove_` source prefix — atomic commit

Replace a managed source entry with a `remove_`-prefixed marker in the same
directory, e.g. rename `executable_toolbox-base-runner` to
`remove_toolbox-base-runner`. chezmoi removes the target on the next apply.
The marker file is source-only and never installed.

### 3. `.chezmoiremove` — retroactive, for already-deleted sources

If the source was already removed and pushed, the target is now unmanaged and
would never be cleaned up by `chezmoi apply`. List the target path in
`.chezmoiremove` in the source state — chezmoi deletes matching targets on the
next `chezmoi apply` on every machine. It is template-parsed and source-only
(never installed). Preview with `chezmoi apply --dry-run --verbose`.

Once every machine has pulled and applied, `.chezmoiremove` can be deleted —
it is only needed while stale copies still exist.
