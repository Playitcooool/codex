# Private Fork Maintenance

This repository uses a personal long-lived branch called `my-codex`.

## Branch roles

- `upstream/main`: official OpenAI Codex history
- `main`: clean local and remote mirror of `upstream/main`
- `plan-mode-model-override`: source branch for the first private customization
- `my-codex`: derived branch rebuilt from `upstream/main` plus ordered private patch branches

Do not develop directly on `my-codex`. Create private customizations as separate
branches from clean `main`, then add them to the patch manifest.

## Daily sync workflow

1. Ensure the working tree is clean.
2. Run:

   ```bash
   ./scripts/sync-my-codex.sh
   ```

3. If the script reports a cherry-pick conflict:
   - inspect the failing patch branch named in the error
   - resolve the conflict
   - rerun the script from a clean state

The script:

- fetches `origin` and `upstream`
- resets `main` to `upstream/main`
- recreates `my-codex` from `upstream/main`
- replays the branches in `scripts/private-patch-branches.txt`
- force-pushes `origin/main` and `origin/my-codex`

## Recommended day-to-day workflow

Do not develop directly on `my-codex`. Treat it as a generated integration
branch.

For a new private customization, start from clean `main` unless the new work
explicitly depends on another patch branch:

```bash
git checkout main
git pull --ff-only origin main
git checkout -b patch-your-feature
```

Implement and commit the change on the new `patch-*` branch, add that branch to
`scripts/private-patch-branches.txt`, then rebuild `my-codex`:

```bash
./scripts/sync-my-codex.sh
```

Only branch from an existing patch branch when the new customization genuinely
depends on the older private change.

## Optional modes

```bash
./scripts/sync-my-codex.sh --dry-run
./scripts/sync-my-codex.sh --no-push
```

- `--dry-run` prints the commands without changing branches
- `--no-push` updates local branches only

## Adding a new private customization

1. Start from clean `main`:

   ```bash
   git checkout main
   git reset --hard upstream/main
   git checkout -b patch-your-feature
   ```

2. Implement and commit the change on `patch-your-feature`.
3. Add the branch name to `scripts/private-patch-branches.txt`.
4. Rebuild the long-lived branch:

   ```bash
   ./scripts/sync-my-codex.sh
   ```

## Recovery notes

- If replay fails, `my-codex` stops at the failing cherry-pick so you can inspect
  the conflict directly.
- If you want to restart from scratch after a failed replay:

  ```bash
  git cherry-pick --abort
  git checkout plan-mode-model-override
  ./scripts/sync-my-codex.sh
  ```

- The generated patch file under `codex-rs/0001-codex-Add-a-Plan-mode-model-override.patch`
  is only a local backup. The source of truth is the patch branch itself.
