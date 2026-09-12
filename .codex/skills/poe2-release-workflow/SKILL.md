---
name: poe2-release-workflow
description: This skill should be used after implementing a POE2LootTracker feature change that needs a version bump, local Windows build validation without local release packaging, and publication through the repository's GitHub Actions release workflow.
---

# POE2LootTracker Feature Release Workflow

## Purpose

Apply the repository's release path after completing a functional change. Keep `pubspec.yaml` as the sole version source, validate locally without producing release archives, and let the tag-triggered GitHub Actions workflow build, package, and publish the Windows release.

## Workflow

1. Confirm that the feature change is complete and inspect the working tree with `git status --short`.
2. Choose the version increment requested by the task. When no release level is specified, increment the patch version. Do not alter `lib/app_version.dart` or `tracker_host/TrackerHost.csproj` by hand.
3. Change only `pubspec.yaml`'s top-level `version:` value, preserving the format `MAJOR.MINOR.PATCH` without a `+BUILD` suffix.
4. Synchronize generated version files from that source:

   ```powershell
   dart run tool/version.dart
   dart run tool/version.dart --check
   dart run tool/version.dart --tag
   ```

5. Run the local validation suite relevant to the change. Before pushing a release, run:

   ```powershell
   flutter analyze
   flutter test
   dotnet test tracker_host_tests/TrackerHost.Tests.csproj -c Release
   flutter build windows --release
   ```

6. Treat the local `flutter build windows --release` result as build validation only. Do not create a ZIP archive, SHA-256 file, GitHub Release, or local release bundle. Do not run `Compress-Archive`, `gh release create`, or equivalent packaging or publishing commands locally.
7. Recheck the generated version files and tag before committing:

   ```powershell
   dart run tool/version.dart --check
   $releaseTag = dart run tool/version.dart --tag
   git diff --check
   git status --short
   ```

8. Commit the feature and version synchronization with a concise outcome-only subject. Do not include a commit body or comment that documents decisions, alternatives, rationale, or reasoning.
9. Create and push the exact tag printed by `dart run tool/version.dart --tag`, then push the branch and tag:

   ```powershell
   git tag $releaseTag
   git push origin HEAD
   git push origin $releaseTag
   ```

10. Verify the GitHub Actions run for the pushed tag. Let `.github/workflows/release.yml` run its tests, build the Windows application, create the ZIP and SHA-256 assets, and publish the GitHub Release. Report the resulting workflow or release status without narrating internal decision-making.

## Communication and Content Guardrails

- Write user-facing application UI text only to explain product behavior or next actions. Never place decision records, rationale, alternatives considered, or chain-of-thought-style material in the UI.
- Use commit subjects that state the delivered outcome, such as `feat: add item filter` or `chore: release v1.0.6`. Never add decision-making, rationale, alternatives, or reasoning to commit messages or commit comments.
- Keep status updates factual: name completed actions, commands, artifacts, failures, and required next actions. Omit internal deliberation.

## Release Invariants

- Keep `pubspec.yaml` as the single version source; `tool/version.dart` generates `lib/app_version.dart` and `tracker_host/TrackerHost.csproj`.
- Use bare semantic versions in `pubspec.yaml` and tags in the form `vMAJOR.MINOR.PATCH`; do not add a pubspec build-number suffix.
- Preserve the full Flutter application and self-contained `tracker_host` as one Windows bundle. GitHub Actions, not the local machine, creates the distributable ZIP and its checksum.
- Stop and report failures from synchronization, validation, git checks, or GitHub Actions. Do not bypass failed checks or silently publish a mismatched version.
