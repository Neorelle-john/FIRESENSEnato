# FireSense Project Structure Documentation

This document provides a comprehensive overview of the FireSense project's folder structure, explaining the purpose and organization of each directory and key file.

## 📁 Root Directory Structure

```
firesense/
├── lib/                    # Main application source code
├── assets/                 # Images, fonts, and other static assets
├── test/                   # Unit and widget tests
├── android/                # Android-specific configuration
├── ios/                    # iOS-specific configuration
├── web/                    # Web-specific configuration
└── windows/                # Windows-specific configuration
```

---

## 📂 lib/ - Main Source Code

The `lib/` directory contains all the Dart source code for the application. It's organized into logical modules for better maintainability.

### 📁 lib/admin_side/
**Purpose**: Contains all screens and components specific to the admin interface.

**Contents**:
- `home_screen.dart` - Main admin dashboard with statistics, recent alerts, and navigation
- `alert_screen.dart` - Detailed alerts list with filtering and status management
- `client_screen.dart` - Client management interface
- `settings.dart` - Admin settings and preferences
- `admin_alarm_overlay.dart` - ⚠️ **DEPRECATED** - Moved to `lib/widgets/alarms/`

**Key Features**:
- Real-time alert monitoring
- Client management
- System statistics dashboard
- Alert status management (Active, Investigating, Resolved)

---

### 📁 lib/user_side/
**Purpose**: Contains all screens and components for regular users.

#### 📁 lib/user_side/contacts/
**Purpose**: Emergency contact management functionality.

**Contents**:
- `add_contact_screen.dart` - Add new emergency contacts
- `contacts_list_screen.dart` - View and manage all contacts
- `edit_contact_screen.dart` - Edit existing contact information

**Key Features**:
- Phone number validation and formatting
- Contact CRUD operations
- Integration with SMS service

#### 📁 lib/user_side/devices/
**Purpose**: Device management for users.

**Contents**:
- `add_device_screen.dart` - Register new fire detection devices
- `devices_screen.dart` - List all user's devices
- `device_detail_screen.dart` - Detailed device information and controls
- `edit_device_screen.dart` - Edit device information
- `location_picker_screen.dart` - Google Maps integration for device location

**Key Features**:
- Device registration and management
- Real-time sensor data monitoring
- Location-based device tracking
- Alarm acknowledgment

#### 📁 lib/user_side/emergency/
**Purpose**: Emergency response features.

**Contents**:
- `emergency_dial_screen.dart` - Quick dial interface for emergency services

#### 📁 lib/user_side/home/
**Purpose**: User home screen.

**Contents**:
- `home_screen.dart` - Main user dashboard with device overview

#### 📁 lib/user_side/materials/
**Purpose**: Fire safety educational materials.

**Contents**:
- `material_screen.dart` - Main materials hub
- `fire_checklist_screen.dart` - Fire safety checklist
- `fire_prevention_screen.dart` - Fire prevention tips and information

#### 📁 lib/user_side/settings/
**Purpose**: User settings and profile management.

**Contents**:
- `settings_screen.dart` - Main settings screen
- `profile_screen.dart` - User profile view
- `edit_profile_screen.dart` - Edit user profile
- `message_template_screen.dart` - Customize SMS message templates

---

### 📁 lib/services/
**Purpose**: Business logic and backend service integrations.

**Contents**:
- `admin_alert_service.dart` - Handles sending detailed alerts to admin Firestore collection
  - Fetches user and device details from Firestore
  - Uses `claimedBy` field from RTDB to identify device owners
  - Implements timeout handling and caching for performance

- `sensor_alarm_services.dart` - Monitors Realtime Database for alarm triggers
  - Listens to all devices for alarm state changes
  - Triggers notifications, SMS, and admin alerts
  - Implements debouncing to prevent rapid-fire triggers
  - Handles admin vs user notification differentiation

- `sms_alarm_service.dart` - SMS sending service using Semaphore API
  - Sends SMS to all emergency contacts when alarm is triggered
  - Formats phone numbers for Philippine mobile numbers
  - Implements timeout handling for emulator compatibility

- `notification_service.dart` - Local and push notification management
  - Handles notification permissions
  - Creates notification channels
  - Differentiates between admin and user notifications
  - Integrates with Firebase Cloud Messaging

- `alarm_widget.dart` - ⚠️ **DEPRECATED** - Moved to `lib/widgets/alarms/user_alarm_overlay.dart`

**Key Features**:
- Singleton pattern for service instances
- Comprehensive error handling and timeout management
- Real-time Firebase integration
- Emulator compatibility fixes

---

### 📁 lib/utils/
**Purpose**: Reusable utility functions and helper classes.

**Contents**:
- `phone_utils.dart` - Phone number formatting and validation
  - `cleanPhoneNumber()` - Standardizes phone numbers to +63XXXXXXXXXX format
  - `isValidPhoneNumber()` - Validates Philippine mobile numbers
  - `formatPhoneNumberForSms()` - Formats for SMS service (removes +)

- `time_utils.dart` - Time formatting utilities
  - `getTimeAgo()` - Converts timestamp to "X minutes ago" format
  - `getDetailedTimeAgo()` - More detailed time formatting for alerts

- `name_utils.dart` - Name formatting utilities
  - `toTitleCase()` - Converts text to title case (e.g., "juan carlos" → "Juan Carlos")
  - `initialsFromName()` - Extracts initials from full names

- `map_utils.dart` - Google Maps integration utilities
  - `openInGoogleMaps()` - Opens location in Google Maps app or web
  - Handles app/web fallback and error messages
  - Prevents app hanging on emulators

- `auth_utils.dart` - Authentication and user role utilities
  - `isAdmin()` - Checks if current user is admin
  - `isAdminEmail()` - Checks if email is admin email
  - `getCurrentUserEmail()` - Gets current user email
  - `getCurrentUserId()` - Gets current user UID

**Key Features**:
- Static utility classes (no instantiation needed)
- Consistent formatting across the app
- Error handling and validation
- Reusable across multiple screens

---

### 📁 lib/constants/
**Purpose**: Application-wide constants and configuration values.

**Contents**:
- `app_colors.dart` - Color constants
  - `AppColors.primaryRed` - Main brand color (#8B0000)
  - `AppColors.primaryRedDark` - Darker red variant
  - `AppColors.lightGrey` - Light grey background
  - `AppColors.textDark` - Dark text color
  - `AppColors.textSecondary` - Secondary text color

- `app_constants.dart` - Application constants
  - `AppConstants.adminEmail` - Admin email address
  - `AppConstants.defaultMapLat/Lng` - Default map location (Urdaneta City)
  - `AppConstants.alarmDebounceMs` - Debounce delay for alarms
  - `AppConstants.maxOperationTimeoutSeconds` - Max timeout for operations

**Key Features**:
- Centralized configuration
- Easy to update and maintain
- Type-safe constants
- Consistent values across the app

---

### 📁 lib/widgets/
**Purpose**: Reusable UI components and widgets.

#### 📁 lib/widgets/alarms/
**Purpose**: Alarm-related overlay widgets.

**Contents**:
- `user_alarm_overlay.dart` - User-side alarm overlay
  - Displays fire alarm alert
  - Shows evacuation instructions
  - "Acknowledge" button sets RTDB alarm to false
  - Full-screen modal overlay

- `admin_alarm_overlay.dart` - Admin-side alarm overlay
  - Displays alert details (user name, device location, timestamp)
  - "Open Alert" button (doesn't set alarm to false)
  - Fetches alert data from Firestore
  - Optimized timestamp display

**Key Features**:
- Consistent styling using `AppColors`
- Time formatting using `TimeUtils`
- Responsive design
- Error handling

#### 📁 lib/widgets/common/
**Purpose**: Common reusable widgets (currently empty, reserved for future use).

**Potential Contents**:
- Loading indicators
- Error message widgets
- Custom buttons
- Form input widgets

---

### 📁 lib/credentials/
**Purpose**: Authentication and user management screens.

**Contents**:
- `auth_gate.dart` - Authentication routing logic
  - Determines if user should see login or app screens
  - Handles authentication state changes

- `signin_screen.dart` - User sign-in interface
  - Email/password authentication
  - Form validation
  - Error handling

- `signup_screen.dart` - User registration interface
  - New user registration
  - Form validation
  - Profile creation

**Key Features**:
- Firebase Authentication integration
- Form validation
- User-friendly error messages
- Consistent UI design

---

### 📁 lib/
**Root level files**:
- `main.dart` - Application entry point
  - Initializes Firebase
  - Sets up app theme
  - Routes to AuthGate

- `firebase_options.dart` - Firebase configuration
  - Generated Firebase configuration
  - Platform-specific settings

---

## 🔄 Migration Notes

### Deprecated Files (Moved/Reorganized):
1. `lib/services/alarm_widget.dart` → `lib/widgets/alarms/user_alarm_overlay.dart`
2. `lib/admin_side/admin_alarm_overlay.dart` → `lib/widgets/alarms/admin_alarm_overlay.dart`
3. `lib/admin_side/persistent_alert_banner.dart` → **DELETED** (redundancy removed)

### Code Consolidation:
- Phone number utilities consolidated from multiple files → `lib/utils/phone_utils.dart`
- Time formatting utilities consolidated → `lib/utils/time_utils.dart`
- Name formatting utilities consolidated → `lib/utils/name_utils.dart`
- Google Maps opening logic consolidated → `lib/utils/map_utils.dart`
- Color constants consolidated → `lib/constants/app_colors.dart`
- Admin detection logic consolidated → `lib/utils/auth_utils.dart`

---

## 📋 Best Practices

### When Adding New Code:

1. **Utilities**: Place reusable functions in appropriate `lib/utils/` files
2. **Constants**: Add app-wide constants to `lib/constants/`
3. **Widgets**: Reusable UI components go in `lib/widgets/`
4. **Services**: Business logic and backend integration in `lib/services/`
5. **Screens**: Feature-specific screens in `lib/admin_side/` or `lib/user_side/`

### Import Guidelines:

```dart
// Constants first
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

// Utils second
import '../utils/phone_utils.dart';
import '../utils/time_utils.dart';

// Services third
import '../services/admin_alert_service.dart';

// Widgets fourth
import '../widgets/alarms/user_alarm_overlay.dart';

// Flutter packages last
import 'package:flutter/material.dart';
```

---

## 🎯 Quick Reference

### Finding Code:

- **Phone number validation**: `lib/utils/phone_utils.dart`
- **Time formatting**: `lib/utils/time_utils.dart`
- **Color constants**: `lib/constants/app_colors.dart`
- **Admin detection**: `lib/utils/auth_utils.dart`
- **Google Maps**: `lib/utils/map_utils.dart`
- **Alarm overlays**: `lib/widgets/alarms/`
- **Admin alerts**: `lib/services/admin_alert_service.dart`
- **SMS sending**: `lib/services/sms_alarm_service.dart`
- **Notifications**: `lib/services/notification_service.dart`

### Common Tasks:

- **Add a new utility function**: Add to appropriate file in `lib/utils/`
- **Add a new constant**: Add to `lib/constants/app_constants.dart` or `app_colors.dart`
- **Create reusable widget**: Add to `lib/widgets/common/` or appropriate subfolder
- **Add new service**: Create in `lib/services/` following singleton pattern
- **Add admin screen**: Create in `lib/admin_side/`
- **Add user screen**: Create in appropriate subfolder of `lib/user_side/`

---

## 📝 Notes

- All services use singleton pattern for consistency
- Timeout handling is implemented throughout to prevent emulator hangs
- Error handling is comprehensive with user-friendly messages
- Constants are centralized for easy maintenance
- Utilities are static classes for easy access
- Widgets use centralized color constants for consistent theming

---

**Last Updated**: November 2025
**Maintained By**: FireSense Development Team

