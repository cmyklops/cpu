SCHEME      := CPUMeter
VERSION     ?= 1.4
DMG_NAME    := CPUMeter-$(VERSION).dmg
DMG_STAGING := /tmp/cpumeter-dmg-staging
DERIVED_DATA := /private/tmp/CPUMeterDerivedData
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/CPUMeter.app

# Resolve build output directories dynamically — no hardcoded DerivedData paths.
RELEASE_DIR := $(DERIVED_DATA)/Build/Products/Release
DEBUG_DIR   := $(DERIVED_DATA)/Build/Products/Debug

.PHONY: build install uninstall run clean dev test dmg release verify-release

# Build a Release binary.
build:
	xcodebuild -scheme $(SCHEME) -configuration Release -derivedDataPath "$(DERIVED_DATA)" CODE_SIGN_IDENTITY="-" build

test:
	xcodebuild test -scheme $(SCHEME) -derivedDataPath "$(DERIVED_DATA)"

# Copy the Release app to /Applications and re-register it with Launch Services.
install: build
	cp -R "$(RELEASE_DIR)/CPUMeter.app" /Applications/CPUMeter.app
	xattr -cr /Applications/CPUMeter.app
	touch /Applications/CPUMeter.app

# DESTRUCTIVE: permanently deletes /Applications/CPUMeter.app.
uninstall:
	rm -rf /Applications/CPUMeter.app

# Install the Release build and open it.
run: install
	open /Applications/CPUMeter.app

# Remove Xcode build artifacts for this scheme.
clean:
	xcodebuild -scheme $(SCHEME) -derivedDataPath "$(DERIVED_DATA)" clean

# Build a versioned DMG with CPUMeter.app and an Applications symlink.
dmg: build
	rm -rf "$(DMG_STAGING)" "$(DMG_NAME)"
	mkdir -p "$(DMG_STAGING)"
	cp -R "$(RELEASE_DIR)/CPUMeter.app" "$(DMG_STAGING)/CPUMeter.app"
	ln -s /Applications "$(DMG_STAGING)/Applications"
	hdiutil create -volname "CPUMeter $(VERSION)" \
		-srcfolder "$(DMG_STAGING)" \
		-ov -format UDZO \
		"$(DMG_NAME)"
	rm -rf "$(DMG_STAGING)"
	@echo "Created $(DMG_NAME)"

release:
	@test -n "$(DEVELOPER_ID_APPLICATION)" || (echo "Set DEVELOPER_ID_APPLICATION"; exit 1)
	@test -n "$(NOTARYTOOL_PROFILE)" || (echo "Set NOTARYTOOL_PROFILE"; exit 1)
	xcodebuild -scheme $(SCHEME) -configuration Release -derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGN_IDENTITY="$(DEVELOPER_ID_APPLICATION)" build
	codesign --force --deep --options runtime --timestamp --sign "$(DEVELOPER_ID_APPLICATION)" "$(RELEASE_APP)"
	rm -rf "$(DMG_STAGING)" "$(DMG_NAME)"
	mkdir -p "$(DMG_STAGING)"
	cp -R "$(RELEASE_APP)" "$(DMG_STAGING)/CPUMeter.app"
	ln -s /Applications "$(DMG_STAGING)/Applications"
	hdiutil create -volname "CPUMeter $(VERSION)" -srcfolder "$(DMG_STAGING)" -ov -format UDZO "$(DMG_NAME)"
	codesign --force --timestamp --sign "$(DEVELOPER_ID_APPLICATION)" "$(DMG_NAME)"
	xcrun notarytool submit "$(DMG_NAME)" --keychain-profile "$(NOTARYTOOL_PROFILE)" --wait
	xcrun stapler staple "$(DMG_NAME)"
	$(MAKE) verify-release

verify-release:
	spctl --assess --type execute --verbose "$(RELEASE_APP)"
	spctl --assess --type open --context context:primary-signature --verbose "$(DMG_NAME)"

# Build Debug, kill any running instance, and open the fresh build.
dev:
	xcodebuild -scheme $(SCHEME) -configuration Debug -derivedDataPath "$(DERIVED_DATA)" build
	pkill -x CPUMeter 2>/dev/null; sleep 0.3; open "$(DEBUG_DIR)/CPUMeter.app"
