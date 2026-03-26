---
name: deliver-appstore-complete
description: Complete an iOS release after App Store approval. Merges release branch into main, creates git tag, syncs develop, and cleans up. Works with any .xcodeproj project using git-flow branching.
---

# Deliver App Store Complete — Post-Approval

You are executing the `/deliver-appstore-complete` skill. This finalizes the release cycle after App Store approval.

## What to do

Run the `deliver-appstore-complete.sh` script from the `deliver-appstore` tool installation. The script is interactive and handles everything automatically.

### If the script is available locally:

```bash
deliver-appstore-complete.sh
```

### If the script is NOT installed, execute these steps manually:

#### Step 1: Detect version
- If on a `release/*` branch, extract version from branch name
- Otherwise, list available `release/*` branches and ask the user to select
- If no release branches found, ask for the version manually

#### Step 2: Pre-flight
1. Verify `release/<version>` branch exists
2. Verify `main` and `develop` branches exist
3. Verify clean working tree

#### Step 3: Merge release into main
```bash
git checkout main
git pull origin main
git merge --no-ff release/<version> -m "Merge release/<version> into main"
git push origin main
```

#### Step 4: Tag on main
```bash
git tag -a <version> -m "Release <version>"
git push origin <version>
```

#### Step 5: Merge main back into develop
```bash
git checkout develop
git pull origin develop
git merge --no-ff main -m "Merge main into develop after release <version>"
git push origin develop
```

#### Step 6: Cleanup
```bash
git branch -d release/<version>
git push origin --delete release/<version>
```

#### Step 7: GitHub Release (ask user)
```bash
gh release create <version> --title "v<version>" --notes "Release <version>" --target main
```

#### Step 8: Summary
Print what was done: tag created, branches merged, release branch cleaned up.

## Error handling
- If merge conflicts occur: never force — explain and ask user to resolve manually
- If tag already exists: warn and ask if the user wants to continue without tagging
- If branch doesn't exist: list available branches and ask for clarification
