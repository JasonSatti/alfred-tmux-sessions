# Contributing

Open a pull request for changes. Keep fixes focused and describe how you tested them.
The maintainer reviews and merges contributions. No second reviewer is required while
this is a solo-maintained project.

## Local checks

Use Python 3.9 or newer for the development tools:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
python -m pytest
python scripts/build_workflow.py
```

The build creates `dist/Tmux Sessions.alfredworkflow`. Import that file into Alfred
to test your changes. CI also makes this file available as the
`tmux-sessions-workflow` artifact on each pull request.

`src/` is the source of truth for both scripts. `workflow/info.plist` stores the
workflow configuration, version, object connections, and descriptions. Its script
fields intentionally stay empty: the build inserts the current scripts. Icons live
in `workflow/`. The root-level `.alfredworkflow` file is the historical exported
release, not a build input or the package to use when testing source changes.

To verify an existing build against the source:

```bash
python scripts/build_workflow.py --check 'dist/Tmux Sessions.alfredworkflow'
```

On macOS with Alfred, Ghostty, and iTerm installed, check AppleScript compilation:

```bash
python scripts/check_applescript.py --include-iterm
```

This compiles the action script and its delayed iTerm script if present. It does
not run actions, attach to sessions, or open terminal windows. Installed apps
provide the scripting dictionaries needed for compilation.

## CI and the missing-iTerm fix

CI runs on pull requests and pushes to `main`. The required checks are:

- `Python tests and package`
- `AppleScript compilation`

`Without iTerm (advisory)` uses a separate macOS runner with Alfred and Ghostty
installed, but no iTerm. The current action script cannot compile there, which is
the known issue addressed by PR #5. That compilation step reports a warning until
the fix lands. After it passes with the fix, remove `continue-on-error: true`,
remove the advisory reporting step, rename the job to `Without iTerm`, and add it
to the required checks. Do not treat the advisory result as a passing regression
test.

CI uses GitHub-hosted runners and read-only repository permissions. Fork pull
requests do not need release credentials.

## Manual checks before releasing

Compilation cannot verify window focus, Accessibility permissions, or keystroke
delivery. Install the generated workflow and check the supported terminals:

- List and filter sessions, including the empty state.
- Create, attach, detach, delete, and open a linked session using disposable sessions.
- Open from a closed terminal app and confirm only one window appears.
- Try an existing shell window, a window inside tmux, and multiple windows or tabs.
  Verify the intended session is visible and no command lands in a running program.
- Test Ghostty or Terminal.app on a machine without iTerm after the compilation fix lands.

## Releases

Merging does not publish a release. To prepare one:

1. Update the version in `workflow/info.plist` and add a dated version entry to
   `CHANGELOG.md`. Merge that change after CI and the manual checks pass.
2. Create and push a version tag such as `v2.2.4` for that merged commit.
3. In GitHub Actions, choose **Draft release**, then **Run workflow** on `main`.
   Enter the existing tag.
4. The workflow checks that the tag belongs to `main`, matches the package version,
   and has a changelog entry. It reruns CI for that exact commit and attaches the
   resulting package to a draft GitHub release.
5. Review the draft notes and attachment, then publish when ready.

The workflow will not create missing tags or overwrite an existing release.
If a run fails after creating a draft, inspect that draft before retrying.

## Maintainer branch settings

Protect `main` by requiring pull requests and the two required checks above, with
zero required approving reviews. Block branch deletion and force pushes. Enable
required checks only after their first successful GitHub Actions run. Requiring
the branch to be up to date ensures checks cover the current merge base.

If write collaborators are added later, consider requiring code-owner review from
`@JasonSatti`. A solo maintainer cannot approve their own pull requests, so that
would also require deciding how to handle owner-authored changes.
