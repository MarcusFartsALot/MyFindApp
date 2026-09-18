# MyFindApp

MyFindApp is a Flutter mobile app for a tourism and immigration system. Citizens and Tourists use the mobile app, while administrators manage applications through a separate PHP portal.

## Features

- Citizen and Tourist registration
- MyKad and passport OCR checks
- Supabase login, role checking and password recovery
- Citizen incident reports with media and location data
- Incident status tracking and notifications
- Tourist visa applications and PDF uploads
- Gemini-based visa risk assessment
- Visa history and travel declarations
- PHP admin portal for approvals, reports and visa management

## Tech stack

- Flutter and Dart
- Supabase Auth, PostgreSQL, Realtime and Storage
- PHP 8.1+ for the admin portal
- Google ML Kit Text Recognition
- Google Maps and geolocation packages
- Google Gemini API
- file_picker, image_picker, pdf, pdfrx and printing
- shared_preferences for local session and draft storage

## Project structure

~~~text
MyFindApp-master/
├── admin/                          PHP administrator portal
├── android/                        Android configuration
├── ios/                            iOS configuration
├── lib/
│   ├── AI VISA/                    Visa and AI features
│   ├── M300/                       Community incident reporting
│   ├── M400/                       Authentication and account features
│   ├── config/                     App configuration
│   ├── core/                       Supabase client and shared classes
│   └── main.dart                   App entry point
├── test/                           Flutter tests
├── pubspec.yaml                    Flutter dependencies
├── pubspec.lock                    Locked dependency versions
├── android/maps.properties.example Android Maps key template
└── admin/.env.example              PHP environment template
~~~

## Versions

| Tool | Version |
|---|---|
| Flutter | 3.38.x stable; lockfile requires at least 3.38.4 |
| Dart | 3.10.7 |
| Java/JDK | 17 |
| Android minimum SDK | API 24 |
| Android Gradle Plugin | 8.11.1 |
| Kotlin | 2.2.20 |
| iOS deployment target | 15.5 |
| App version | 1.0.0+1 |
| PHP | 8.1 or newer |

Important locked packages:

~~~text
supabase_flutter: 2.16.0
google_mlkit_text_recognition: 0.16.0
google_maps_flutter: 2.18.0
geolocator: 14.0.2
geocoding: 5.0.0
file_picker: 8.3.7
image_picker: 1.2.3
pdf: 3.12.0
pdfrx: 1.3.5
printing: 5.14.3
shared_preferences: 2.5.5
~~~

Android and iOS are the main target platforms. The project also contains web and desktop folders, but OCR, maps and file handling may need extra platform-specific work there.

## Requirements

Install the following before running the project:

- Flutter SDK and the Dart SDK included with Flutter
- Android Studio and Android SDK for Android development
- JDK 17
- Xcode and CocoaPods for iOS development
- PHP 8.1+ with curl, json, mbstring and sessions enabled
- A Supabase project
- An Android Google Maps API key
- A Google Gemini API key

Check the installation:

~~~bash
flutter --version
dart --version
php -v
flutter doctor
~~~

## Flutter setup

~~~bash
unzip MyFindApp-master.zip
cd MyFindApp-master
flutter pub get
~~~

The Flutter app reads configuration from lib/config/app_config.dart. Use Dart defines when running the app:

~~~bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY \
  --dart-define=PASSWORD_RESET_REDIRECT_URL=io.myfind.app://reset-password \
  --dart-define=GOOGLE_AI_API_KEY=YOUR_GEMINI_API_KEY
~~~

The source contains development defaults for the Supabase URL and client key. Passing values with Dart defines is recommended when using another Supabase project.

### Android Maps key

~~~bash
cp android/maps.properties.example android/maps.properties
~~~

Edit android/maps.properties:

~~~properties
MAPS_API_KEY=YOUR_ANDROID_RESTRICTED_GOOGLE_MAPS_KEY
~~~

This file is ignored by Git. Do not commit it.

### Password recovery redirect

Add this URL under Supabase Dashboard > Authentication > URL Configuration:

~~~text
io.myfind.app://reset-password
~~~

The same URL scheme is registered in the Android and iOS project files.

## Supabase setup

The ZIP does not include the Supabase SQL migration. Create the database schema, Row Level Security policies, RPC functions and Storage buckets separately.

Tables used by the application include:

~~~text
profiles
citizens
tourists
notifications
incident_reports
visa_applications
applicant_information
employment_information
financial_information
travel_information
supporting_documents
payment_transactions
risk_predictions
visa_submissions
visa_status_history
visa_travel_records
~~~

Storage buckets:

~~~text
registration-documents
incident-evidence
visa-documents
~~~

The Module 400 password-reset flow also calls:

~~~text
module400_password_reset_eligibility
~~~

Review the RLS policies before allowing real users to access the system. Users should only access their own records, while administrator operations should be protected.

## Run the mobile app

### Android

Start an emulator or connect an Android device:

~~~bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY \
  --dart-define=PASSWORD_RESET_REDIRECT_URL=io.myfind.app://reset-password \
  --dart-define=GOOGLE_AI_API_KEY=YOUR_GEMINI_API_KEY
~~~

Build a release APK:

~~~bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY \
  --dart-define=PASSWORD_RESET_REDIRECT_URL=io.myfind.app://reset-password \
  --dart-define=GOOGLE_AI_API_KEY=YOUR_GEMINI_API_KEY
~~~

The current Android release setup uses the debug signing configuration. Set up a proper release keystore before publishing.

### iOS

Run these commands on macOS:

~~~bash
flutter pub get
cd ios
pod install
cd ..
flutter run -d ios
~~~

The project targets iOS 15.5. Xcode signing and the final bundle identifier still need to be configured before distribution.

## PHP admin portal

Copy admin/.env.example to .admin.env in the project root:

~~~dotenv
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVER_ONLY_SERVICE_ROLE_KEY
ADMIN_PASSWORD_RESET_URL=http://localhost:8081/admin_reset_password.php
ADMIN_RECOVERY_RATE_LIMIT_SECRET=USE_A_SEPARATE_RANDOM_SECRET
MAIL_FROM=no-reply@example.com
APP_NAME=MyFind
SESSION_NAME=myfind_admin
SESSION_SAVE_PATH=
~~~

The service-role key must stay on the PHP server. Do not place it in the Flutter app or commit it to GitHub.

Start the portal from the project root.

Windows with XAMPP:

~~~powershell
C:\xampp\php\php.exe -S localhost:8081 -t admin admin/router.php
~~~

Linux or macOS:

~~~bash
php -S localhost:8081 -t admin admin/router.php
~~~

Open http://localhost:8081/admin_login.php.

Do not run a plain PHP server from inside the admin folder because protected files could become accessible.

### Create the first administrator

1. Create an email/password user under Supabase Dashboard > Authentication > Users.
2. Add a matching row to profiles.
3. Set profiles.auth_id to the Supabase Auth user ID.
4. Set profiles.role to admin.

## How the modules work

### Authentication and accounts

main.dart initializes Supabase using PKCE. SessionGate checks for a trusted session and loads the current profile. AuthService signs users in and retrieves their role. RoleRouter sends approved Citizens and Tourists to the correct dashboard. Administrator accounts use the PHP portal.

Registration uses OCR to read identity documents, checks the entered identity number and uploads the document to Supabase Storage. An administrator must approve the application before the user can access the mobile app.

### Community reports

Citizens can submit an incident report with a description, category, urgency, location and supporting media. Reports are stored in incident_reports, while evidence is stored in incident-evidence. Users can view their tickets and update reports that are still pending review.

### AI Visa

Tourists can submit visa details, upload supporting documents and view visa history. The app sends structured application data to Gemini and stores the returned risk score, risk level, recommendation and explanation in Supabase.

The current payment screen validates card-form fields and creates a local transaction ID. It does not use a live Stripe SDK or payment gateway.

## Testing

~~~bash
flutter analyze
flutter test
~~~

The password-recovery test is located at test/password_recovery_session_test.dart. PHP tests and diagnostics are located in admin/tests/.

## Security notes

- Do not commit .admin.env, android/maps.properties or private API keys.
- Do not expose SUPABASE_SERVICE_ROLE_KEY in the Flutter app.
- The current lib/AI VISA/services/ai_service.dart contains a Google AI key directly in the source code. Rotate that key before uploading the project publicly.
- AiService currently does not use AppConfig.googleAiApiKey; it uses its own private key value. Move the AI request to a protected backend or update the service before production use.
- Use HTTPS for the PHP portal in production.
- Keep registration and visa documents in private Storage buckets.
- Configure real Android and iOS release signing before distribution.

## Troubleshooting

### flutter.sdk not set in local.properties

Run flutter pub get from the project root and open the project through Flutter or Android Studio so the Flutter SDK path can be generated.

### Android map is blank

Check that android/maps.properties exists and that the Google Maps key is restricted to the correct Android package name and SHA-1 certificate.

### Password reset opens the wrong page

Check the Supabase Redirect URLs and confirm that io.myfind.app://reset-password is present. Make sure the app was installed with the current Android or iOS deep-link configuration.

### PHP portal cannot find environment variables

Make sure .admin.env is in the project root and that the Supabase URL, anon key and service-role key belong to the same project.

### AI assessment fails

Check the Gemini API key, API quota and response status. Also check whether ai_service.dart is still using the old hard-coded key.

