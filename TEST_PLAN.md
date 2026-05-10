# CPUMeter Test Plan

## 1. Display Modes - CPU Metric

### Bars Mode
- [ ] White pixel lines visible in menu bar
- [ ] Lines respond to CPU activity (increase on system load)
- [ ] Six large square menu bar bars remain white/greyscale with transparent background
- [ ] Bars render sharply without soft or fractional-position edges
- [ ] Higher CPU activity increases greyscale intensity, not hue
- [ ] Lines scroll left as new data arrives
- [ ] 35×22px frame fits menu bar cleanly

### Number Mode
- [ ] Large bold monospaced number displays in menu bar (0-99)
- [ ] Number updates in real-time
- [ ] Number remains white/greyscale with transparent background
- [ ] Font size readable at 35×22px

### Gradient Mode
- [ ] Vertical fill bar visible from bottom
- [ ] Fill height matches CPU percentage (0-100%)
- [ ] "C" label visible in overlay
- [ ] Fill remains white/greyscale with transparent background

## 2. Display Modes - Memory Metric

### Bars Mode
- [ ] Switch to Memory metric via settings
- [ ] Bars now show memory utilization (not CPU)
- [ ] Greyscale-only menu bar styling still applies
- [ ] Accurate memory percentage display

### Number Mode
- [ ] Number shows memory percentage
- [ ] Updates in real-time
- [ ] Greyscale-only menu bar styling still applies

### Gradient Mode
- [ ] "M" label displays (not "C")
- [ ] Fill height matches memory percentage
- [ ] Greyscale-only menu bar styling still applies

## 3. Settings Popover

### Footer Title
- [ ] Footer icon is centered at the bottom of the popover
- [ ] CPUMeter title, footer icon, and version number use equal-width columns
- [ ] CPUMeter title, footer icon, and version number are centered within their columns

### Display Mode Selection
- [ ] Bars/Number/Gradient segmented control appears above CPU/Memory
- [ ] Bars/Number/Gradient segmented control stretches to the panel width
- [ ] Bars/Number/Gradient buttons responsive
- [ ] Switching modes updates graph immediately
- [ ] All three modes work with both metrics

### Metric Selection
- [ ] CPU/Memory segmented control stretches to the panel width
- [ ] CPU button highlighted when CPU selected
- [ ] Memory button highlighted when Memory selected
- [ ] Switching metrics updates graph immediately
- [ ] Current/Average/Peak stats update for new metric

### Statistics Display
- [ ] Current value shows real-time metric
- [ ] Average value displays (rolling average)
- [ ] Peak value displays (highest recorded)
- [ ] All three stats visible and updating

### Sharpness
- [ ] Popover panels and buttons use crisp opaque fills instead of blurred material
- [ ] Top monitor section uses compact control and tile spacing without clipping text

### Update Frequency Slider
- [ ] Slider responds from 0.1 to 2.0 seconds
- [ ] Release-only triggering (no lag while dragging)
- [ ] Adjusting frequency changes graph responsiveness
- [ ] Setting persists after app restart

### Launch at Startup
- [ ] Toggle checkbox visible and centered
- [ ] Can enable/disable
- [ ] Setting persists in ~/Library/LaunchAgents/com.cpumeter.plist

### Quit Button
- [ ] Closes app cleanly
- [ ] No errors on exit

## 4. App Behavior

### Single Instance
- [ ] Launching app twice shows only one process
- [ ] Lock file created at ~/.com.cpumeter.lock
- [ ] Lock file contains valid PID

### Settings Popover
- [ ] Clicking menu bar button opens popover
- [ ] Clicking again closes popover
- [ ] Clicking outside popover closes it
- [ ] Popover appears above menu bar item
- [ ] Popover backdrop is a flat dark macOS menu-extra surface without visible gradient
- [ ] Popover edge stroke is visible against the backdrop

### Click Responsiveness
- [ ] Button highlight fits 35×22px area (known: slight system padding)
- [ ] Click area responsive
- [ ] No missed clicks

## 5. Performance

### Resource Usage
- [ ] CPU usage < 0.5% (idle)
- [ ] Memory < 80MB (typical)
- [ ] No memory leaks over 1 hour runtime

### Accuracy
- [ ] CPU percentage matches Activity Monitor (±2%)
- [ ] Memory percentage matches System Memory widget (±2%)
- [ ] Real-time responsiveness (max 1 frame delay)

## 6. Persistence

### Preferences Save/Load
- [ ] Display mode persists after restart
- [ ] Update frequency persists after restart
- [ ] Metric selection persists after restart
- [ ] Launch at startup setting persists

### Auto-Launch
- [ ] Enable "Launch at Startup"
- [ ] Restart Mac
- [ ] App appears in menu bar automatically
- [ ] Process runs without user interaction

## 7. Release Build

### Debug Build
- [ ] Compiles without errors
- [ ] Runs stably for 10+ minutes
- [ ] All features functional

### Release Build
- [ ] `xcodebuild -scheme CPUMeter -configuration Release clean build` succeeds
- [ ] App launches and runs
- [ ] Performance optimal

### DMG Package
- [ ] DMG file creates correctly
- [ ] App installs from DMG to Applications
- [ ] Installed app runs without DerivedData

## Known Issues

- Button highlight visual area includes system-added padding (cosmetic only, doesn't affect functionality)

## Test Status

**Overall Status:** Ready for manual testing

**Test Date:** April 6, 2026
**Tester:** [To be filled]
