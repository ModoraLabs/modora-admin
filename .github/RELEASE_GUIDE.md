# 🚀 Release Guide

This guide explains how to create releases for modora-admin on GitHub. Releases are
published automatically by GitHub Actions (`.github/workflows/release.yml`) whenever a
`v*.*.*` tag is pushed.

## 📋 Release via Git tag

### Steps:

1. **Update version in `fxmanifest.lua`**
   ```lua
   version '2.0.4'  -- Update to new version
   ```

2. **Update `CHANGELOG.md`** with the new version entry (the workflow copies these notes
   into the GitHub Release body — the heading must match `## [<version>] - <date>`)
   ```markdown
   ## [2.0.4] - 2026-07-02

   ### Fixed
   - Fixed issue X
   - Improved feature Y
   ```

3. **Commit and push your changes**
   ```bash
   git add .
   git commit -m "Release v2.0.4"
   git push github main
   ```

4. **Create and push a git tag** — this triggers the release workflow
   ```bash
   git tag -a v2.0.4 -m "Release v2.0.4"
   git push github v2.0.4
   ```

5. **Done.** GitHub Actions builds `modora-admin-<version>.zip` and creates the release at
   **Releases** automatically. No manual release step is needed.

## 📝 Release Checklist

- [ ] Version updated in `fxmanifest.lua` (`RESOURCE_VERSION` is read from this at runtime)
- [ ] Version updated in `README.md` (if referenced there)
- [ ] CHANGELOG.md updated with new version entry (heading matches `## [<version>] - <date>`)
- [ ] All changes committed and pushed to `main`
- [ ] Git tag created and pushed (triggers the automatic release)

## 🎯 Version Format

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR.MINOR.PATCH** (e.g., 2.0.3, 2.1.0, 3.0.0)
- Tag format: **vMAJOR.MINOR.PATCH** (e.g., v2.0.3, v2.1.0, v3.0.0)

## 📦 What Gets Included in Releases

The release workflow packages:
- `config.lua`, `fxmanifest.lua`, `README.md`, `LICENSE`, `CHANGELOG.md`
- `client/`, `server/`, `html/` folders with all assets

## 🔗 Repository

- **GitHub:** https://github.com/ModoraLabs/modora-admin
- The in-resource version check (`server/bootstrap.lua`) uses the GitHub Releases API to
  compare the current version with the latest release.
