# Release v1.3.0

## New Features
- **UI Improvements**: 
  - Enabled immersive UI mode and redesigned the settings screen for improved usability. (68ddd01)
  - Added new UI elements for better User Experience. (0d1abdf)
- **Map & Navigation**:
  - Added map display. (0d1abdf)
  - Added car icon to the occupancy map. (cde6fae)
- **Customization & Persistence**:
  - Implemented persistent movable UI element positions and scales using shared preferences. (1946a47)
- **System**:
  - Added on-screen notifications. (fba53bc)
  - Added handling for robot commands. (cde6fae)

## Bug Fixes
- **Display Logic**:
  - Changed battery display to show only the integer part. (cf7da1b)
  - Added epsilon check for odometer speed to avoid flickering between -0 and +0. (cf7da1b)

## Maintenance
- Updated `.gitignore` rules for build artifacts. (cde6fae)
