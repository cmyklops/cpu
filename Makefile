SCHEME      := CPUMeter
VERSION     := $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' CPUMeter/Info.plist 2>/dev/null || echo 0.1)
DMG_NAME    := CPUMeter-$(VERSION).dmg
DMG_STAGING := /tmp/cpumeter-dmg-staging

# Resolve build output directories dynamically — no hardcoded DerivedData paths.
RELEASE_DIR := $(shell xcodebuild -scheme $(SCHEME) -configuration Release -showBuildSettings 2>/dev/null | awk '/BUILT_PRODUCTS_DIR =/{print $$3; exit}')
DEBUG_DIR   := $(shell xcodebuild -scheme $(SCHEME) -configuration Debug  -showBuildSettings 2>/dev/null | awk '/BUILT_PRODUCTS_DIR =/{print $$3; exit}')

.PHONY: build install uninstall run clean dev dmg

# Build a Release binary.
build:
	xcodebuild -scheme $(SCHEME) -configuration Release build

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
	xcodebuild -scheme $(SCHEME) clean

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

# Build Debug, kill any running instance, and open the fresh build.
dev:
	xcodebuild -scheme $(SCHEME) -configuration Debug build
	pkill -x CPUMeter 2>/dev/null; sleep 0.3; open "$(DEBUG_DIR)/CPUMeter.app"
