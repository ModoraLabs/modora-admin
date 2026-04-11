# 🚀 Release Guide

This guide explains how to create releases for modora-admin on GitLab.

## 📋 Release via Git tag

Releases on GitLab are created from git tags (semantic versioning).

### Steps:

1. **Update version in `fxmanifest.lua`**
   ```lua
   version '1.0.2'  -- Update to new version
   ```

2. **Update `CHANGELOG.md`** with the new version entry
   ```markdown
   ## [1.0.2] - 2025-01-29
   
   ### Fixed
   - Fixed issue X
   - Improved feature Y
   ```

3. **Commit and push your changes**
   ```bash
   git add .
   git commit -m "Release v1.0.2"
   git push origin main
   ```

4. **Create and push a git tag**
   ```bash
   git tag -a v1.0.2 -m "Release v1.0.2"
   git push origin v1.0.2
   ```

5. **Create the release on GitLab:**
   - Go to **Deploy** → **Releases** → **New release**
   - Select the tag (e.g. `v1.0.2`)
   - Fill in title and description (copy from CHANGELOG.md)
   - Add release assets (zip) if needed
   - Click **Create release**

## 🔧 Manual Release (Alternative)

If you prefer to create releases fully manually in GitLab:

1. Go to **Deploy** → **Releases** → **New release**
2. Create a new tag (e.g., `v1.0.2`) or select an existing one
3. Fill in release title and description (copy from CHANGELOG.md)
4. Upload release assets (zip) if needed
5. Click **Create release**

## 📝 Release Checklist

- [ ] Version updated in `fxmanifest.lua`
- [ ] Version updated in `server.lua` (RESOURCE_VERSION)
- [ ] Version updated in `README.md`
- [ ] CHANGELOG.md updated with new version entry
- [ ] All changes committed and pushed
- [ ] Git tag created and pushed (for automatic release)

## 🎯 Version Format

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR.MINOR.PATCH** (e.g., 1.0.1, 1.1.0, 2.0.0)
- Tag format: **vMAJOR.MINOR.PATCH** (e.g., v1.0.1, v1.1.0, v2.0.0)

## 📦 What Gets Included in Releases

The automatic release workflow includes:
- All `.lua` files
- All `.md` files (README, CHANGELOG, etc.)
- `html/` folder with all assets
- `LICENSE` file

## 🔗 Repository

- **GitLab:** https://gitlab.modora.xyz/modoralabs/modora-admin
- The in-resource version check uses the GitLab Releases API to compare the current version with the latest release.



