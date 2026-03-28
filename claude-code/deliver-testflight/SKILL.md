---
name: deliver-testflight
description: Build, sign, and upload an iOS app to TestFlight. Auto-detects Xcode project settings (scheme, team ID). No git operations — just archive and upload. Works with any .xcodeproj project.
---

# Deliver TestFlight — Build & Upload

You are executing the `/deliver-testflight` skill. This archives and uploads an iOS app to TestFlight.

## What to do

#### Step 1: Pre-flight
1. Verify you are in a directory with a `.xcodeproj` file
2. Detect the Xcode project, scheme, team ID, current marketing version, and current build number
3. Show the detected settings to the user

#### Step 2: Confirm
- Show the current marketing version and build number that will be archived
- Ask the user to confirm before proceeding
- If the user wants a different build number, they should update it themselves before running this skill

**IMPORTANT: Once the user confirms, execute Steps 3–4 automatically without asking for further confirmation. Do not pause between steps.**

#### Step 3: Archive
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

#### Step 4: Export & Upload
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

#### Step 5: Summary
Print what was done:
- Version and build number that was uploaded
- The build will appear in TestFlight within ~10–30 minutes after Apple processing
- Remind: if this is the first build for a new version, the user may need to set "What to Test" notes and add test groups in App Store Connect

## Important
- **No git operations**: This skill does NOT commit, branch, tag, or push anything. It only builds and uploads.
- The user is responsible for having the correct version/build number set before running this skill.

## Error handling
- If archive fails: show the last lines of build output and suggest common fixes (signing, dependencies)
- If upload fails: check if Xcode is signed in, if build number was already used
- Always offer to abort and return to the previous state
