#!/bin/bash
# deliver-appstore — build.sh
# Archive, export, and upload to App Store Connect

# Archive the app
# Usage: archive_app "$PROJECT" "$SCHEME" "$TEAM_ID" "$APP_NAME"
archive_app() {
    local project="$1"
    local scheme="$2"
    local team_id="$3"
    local app_name="$4"
    local archive_path="/tmp/${app_name}.xcarchive"

    log_step "ARCHIVE" "Building $scheme (Release)..."
    log_info "This may take several minutes depending on project size."

    xcodebuild clean archive \
        -project "$project" \
        -scheme "$scheme" \
        -configuration Release \
        -archivePath "$archive_path" \
        -destination "generic/platform=iOS" \
        -allowProvisioningUpdates \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="$team_id" \
        2>&1 | tail -20

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        abort "Archive failed. Check the build output above for errors."
    fi

    log_success "Archive created at $archive_path"
    echo "$archive_path"
}

# Generate ExportOptions.plist for App Store upload
# Usage: generate_export_options "$TEAM_ID"
generate_export_options() {
    local team_id="$1"
    local plist_path="/tmp/ExportOptions.plist"

    cat > "$plist_path" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>${team_id}</string>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
PLIST

    log_success "Generated ExportOptions.plist at $plist_path"
    echo "$plist_path"
}

# Export archive and upload to App Store Connect
# Usage: export_and_upload "$APP_NAME" "$ARCHIVE_PATH" "$PLIST_PATH"
export_and_upload() {
    local app_name="$1"
    local archive_path="$2"
    local plist_path="$3"
    local export_path="/tmp/${app_name}Export"

    log_step "UPLOAD" "Exporting and uploading to App Store Connect..."
    log_info "Using Xcode credentials for upload (destination=upload)."

    xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "$plist_path" \
        -allowProvisioningUpdates \
        2>&1 | tail -20

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        abort "Export/Upload failed. Check the output above for errors.\nCommon issues:\n  - Xcode not signed in to App Store Connect\n  - Build number already used (increment it)\n  - Provisioning profile issues"
    fi

    log_success "App uploaded to App Store Connect!"
    echo "$export_path"
}
