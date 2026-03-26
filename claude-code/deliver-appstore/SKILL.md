---
name: deliver-appstore
description: Build, sign, and upload an iOS app to App Store Connect. Auto-detects Xcode project settings (scheme, team ID, version). Manages git-flow branching (develop -> release -> PR to main). Works with any .xcodeproj project.
---

# Deliver App Store — Build & Upload

You are executing the `/deliver-appstore` skill. This automates the full iOS release pipeline.

## What to do

Run the `deliver-appstore.sh` script from the `deliver-appstore` tool installation. The script is interactive and handles everything automatically.

### If the script is available locally:

```bash
# Find and run the script
deliver-appstore.sh
```

### If the script is NOT installed, execute these steps manually:

#### Step 1: Pre-flight
1. Verify you are in a directory with a `.xcodeproj` file
2. Verify the git working tree is clean (`git status --porcelain`)
3. Detect the Xcode project, scheme, team ID, and current version
4. Verify `develop` and `main` branches exist

#### Step 2: Ask the user for parameters
- **Version** (e.g., `1.4.0`) — show the current detected version as reference
- **Build number** (e.g., `1`) — suggest current + 1

#### Step 3: Branch management
- If on a feature branch, ask if the user wants to merge it into `develop` first
- If on develop, pull latest
- Create `release/<version>` from develop

#### Step 4: Bump version
- Check if version is in `.xcconfig` files (grep for `MARKETING_VERSION` in `*.xcconfig`)
- If xcconfig: update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in that file
- If not: update all occurrences in `project.pbxproj`
- Commit: `git commit -am "Bump version to <version> (<build>)"`

#### Step 5: Archive
```bash
xcodebuild clean archive \
  -project "<Project>.xcodeproj" \
  -scheme "<Scheme>" \
  -configuration Release \
  -archivePath "/tmp/<AppName>.xcarchive" \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="<TeamID>"
```

#### Step 6: Export & Upload
Generate `/tmp/ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string><TeamID></string>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
```

Then export and upload:
```bash
xcodebuild -exportArchive \
  -archivePath "/tmp/<AppName>.xcarchive" \
  -exportPath "/tmp/<AppName>Export" \
  -exportOptionsPlist /tmp/ExportOptions.plist \
  -allowProvisioningUpdates
```

#### Step 7: Push & PR
```bash
git push -u origin release/<version>
gh pr create --base main --head release/<version> \
  --title "Release <version>" \
  --body "Release <version> (build <build>)"
```

#### Step 8: Summary
Print what was done and remind the user:
- Wait for App Store review approval
- Then run `/deliver-appstore-complete` to finish the release cycle

## Error handling
- If archive fails: show the last lines of build output and suggest common fixes (signing, dependencies)
- If upload fails: check if Xcode is signed in, if build number was already used
- If git merge fails: never force — explain the conflict and ask the user to resolve manually
- Always offer to abort and return to the previous state
