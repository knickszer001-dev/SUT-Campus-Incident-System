# SUT Campus Incident System

[![Flutter Version](https://img.shields.io/badge/Flutter-%3E%3D_3.10.0-02569B?logo=flutter&style=flat-square)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-%3E%3D_3.0.0-0175C2?logo=dart&style=flat-square)](https://dart.dev)
[![Firebase Backend](https://img.shields.io/badge/Firebase-Serverless-FFCA28?logo=firebase&style=flat-square)](https://firebase.google.com)
[![Platform Support](https://img.shields.io/badge/Platforms-Android_%7C_iOS_%7C_Web_%7C_Windows-4E4E4E?style=flat-square)](#)

A real-time emergency dispatch and incident-reporting application custom-designed for **Suranaree University of Technology (SUT)**. Built with Flutter and a serverless Firebase backend, it connects reporters, central dispatchers, and responder teams (hospital, rescue, and security) to streamline safety coordination and minimize response times on campus.

> [!NOTE]  
> This repository contains bilingual documentation and specialized technical guides:
> *   📖 ** B1: Deep System Architecture Spec**: [docs/architecture.md](./docs/architecture.md)
> *   📖 ** B2: Database Schema & Collections Spec**: [docs/database.md](./docs/database.md)
> *   📖 ** B3: Detailed Features Spec (F1-F10)**: [docs/features.md](./docs/features.md)
> *   🇹🇭 ** Thai Technical Documentation (20 Chapters)**: [APP_TECHNICAL_DOCUMENTATION_THAI.md](./APP_TECHNICAL_DOCUMENTATION_THAI.md)
> *   🇹🇭 ** Thai Lean Workspace Guide**: [LEAN_APP_SOURCE_THAI.md](./LEAN_APP_SOURCE_THAI.md)

---

## Overview

The SUT Campus Incident System provides a structured communication pipeline for campus emergencies, replacing slow telephone-based dispatches.

### Stakeholder Roles
*   **Reporters (Students / Staff)**: Submit incidents with real-time GPS coordinates, description details, and media attachments.
*   **Dispatchers (Command Center)**: Manage dispatches using an interactive map, monitor active incident workloads, and assign responders.
*   **Responders (Safety Teams)**: Accept tasks, navigate to incidents, and coordinate with the command center via live group chats and direct messages.

---

## Features

### User Features
*   **Quick Reporting Form**: Report emergencies in three clicks by selecting a category (Security, Medical, Accident, Facility, General Assistance).
*   **Precision GPS Polling**: Polls device coordinates with high accuracy using a 10-meter geolocator filter.
*   **Media Attachments**: Upload photos directly from the camera or gallery to illustrate the emergency.
*   **Bulletins Board**: View campus announcements, safety warnings, and detour alerts.

### Dispatcher Features
*   **Dispatcher Dashboard**: A responsive, multi-pane control center showing statistics, active logs, and interactive maps.
*   **Smart Responder Suggestions**: Ranks responders based on department alignment, active workloads, and geographic distance.
*   **Real-time Responder Tracking**: Tracks responder coordinates on the map to monitor the response.
*   **Incident Archives**: Review resolved incidents and view monthly response statistics.

### Responder Features
*   **Mobile Dashboard**: Manage tasks and view assigned incidents in a clean interface.
*   **Operational Milestones**: Update progress using clear status transitions (`ACCEPTED` $\rightarrow$ `EN_ROUTE` $\rightarrow$ `ARRIVED` $\rightarrow$ `RESOLVED`).
*   **Navigation Tools**: View incident locations and calculate distances from your current location.
*   **Live Chat**: Coordinate with reporters and dispatchers using real-time group chats and direct messages.

---

## Screenshots / Demo

Visual assets are stored in the repository for review:
*   **University Logo**: [assets/images/university_logo.png](assets/images/university_logo.png)
*   **App Branding Banner**: [assets/images/sut_incident_logo.png](assets/images/sut_incident_logo.png)
*   **Department Brand Icons**: [assets/images/department_logo.png](assets/images/department_logo.png)

---

## Tech Stack

| Technology | Purpose | Role in Project |
|:---|:---|:---|
| **Flutter (>=3.10)** | Front-End Framework | Compiles native, high-performance applications for Android, iOS, Windows, and responsive Web clients. |
| **Dart (>=3.0)** | Programming Language | Modern, sound type-safe OOP language used for client-side development. |
| **Riverpod (v2.3.6)** | State Management | Decouples business logic from UI widgets, streaming reactive database updates. |
| **Firebase Auth** | Authentication | Manages sessions and GSuite-style virtual email logins. |
| **Cloud Firestore** | Real-time Database | NoSQL document database that synchronizes messages, incidents, and responder coordinates in real time. |
| **Firebase Storage** | Media Storage | Stores incident photo attachments, enforcing file format constraints and size limits. |
| **Cloud Functions** | Backend Serverless | Executes backend scripts (e.g., password recovery, FCM multi-casting) in the **Singapore region (`asia-southeast1`)**. |
| **Google Maps SDK** | Native Mapping | Renders high-performance interactive maps on native iOS and Android clients. |
| **Leaflet / OSM** | Web Mapping | Renders lightweight mapping interfaces on Web and Windows builds. |

---

## Architecture / System Design

The application is built on **Clean Architecture** and a **Feature-First Layering** strategy:

```
        ┌────────────────────────────────────────────────────────┐
        │                   PRESENTATION LAYER                   │
        │  (UI Widgets, Responsive Panels, Screens, Controllers)  │
        └───────────────────────────┬────────────────────────────┘
                                    │ Watches
                                    ▼
        ┌────────────────────────────────────────────────────────┐
        │                      DOMAIN LAYER                      │
        │       (State Transition Rules, Validation Logic)        │
        └───────────────────────────┬────────────────────────────┘
                                    │ Invokes
                                    ▼
        ┌────────────────────────────────────────────────────────┐
        │                       DATA LAYER                       │
        │  (Repositories, Firebase Auth/Firestore, FCM Services) │
        └────────────────────────────────────────────────────────┘
```

*   **Presentation Layer**: Monitors Riverpod providers directly. Employs `LayoutBuilder` widgets to dynamically rearrange views for mobile and desktop screens.
*   **Domain Layer**: Handles business logic (e.g., `responder_logic.dart`) to validate state transitions and prevent out-of-order workflow moves.
*   **Data Layer**: Manages external connections via repositories (`AuthRepository`, `IncidentRepository`, `ChatRepository`, `DirectChatRepository`), translating Firestore documents and mapping JSON entities.

For more details, see the [Architecture Spec](./docs/architecture.md).

---

## Project Structure

| Directory / File | Description |
|:---|:---|
| `assets/` | Local media assets, including university logos and notification sound files (`alert.mp3`). |
| `functions/` | Node.js backend Cloud Functions. |
| `firestore.rules` | Security rules for the Cloud Firestore database. |
| `storage.rules` | Security rules for Firebase Storage uploads. |
| `lib/main.dart` | App entry point, bootstrap services, and multi-platform authentication gateway. |
| `lib/core/` | Common helper files, theme configurations, and mapping widget adapters. |
| `lib/models/` | Unified data models for incidents and user profiles. |
| `lib/features/` | Modular business features (Auth, Chat, Dispatcher, Home, Incident, Profile). |

---

## Dependencies

Key packages and their roles in the project:
*   **`flutter_riverpod`**: Decouples business logic from UI widgets, streaming reactive database updates.
*   **`cloud_firestore`**: Provides real-time synchronization for messages, incidents, and coordinate logs.
*   **`firebase_auth`**: Manages authentication sessions and virtual email logins.
*   **`firebase_storage`**: Handles media file uploads for incident attachments.
*   **`firebase_messaging`**: Routes incoming push notifications on native mobile platforms.
*   **`cloud_functions`**: Connects client recovery requests to secure serverless endpoints.
*   **`google_maps_flutter`**: Renders interactive vector maps on native iOS and Android devices.
*   **`flutter_map`**: Renders Leaflet OpenStreetMap tiles on Web and Desktop builds.
*   **`geolocator`**: Accesses GPS sensors to poll user and responder coordinates.
*   **`audioplayers`**: Plays alert sounds on native clients.
*   **`fl_chart`**: Renders incident statistics and active workloads for dispatchers.

---

## Installation / Setup

### 1. Prerequisites
Ensure you have installed the following tools:
*   [Flutter SDK (v3.10.0 or higher)](https://docs.flutter.dev/get-started/install)
*   [Node.js (v20.x or higher)](https://nodejs.org)
*   [Firebase CLI](https://firebase.google.com/docs/cli)
*   An active Firebase project

### 2. Client Application Setup
Navigate to the root workspace directory and run the following command to download dependencies:
```powershell
flutter pub get
```

To run the application locally on your target platform:
```powershell
# Run on Windows Desktop
flutter run -d windows

# Run on Google Chrome (Web PWA)
flutter run -d chrome

# Run on a connected mobile device or emulator
flutter run
```

### 3. Backend Cloud Functions Setup
Navigate to the `functions/` directory and install dependencies:
```powershell
# Navigate to the functions folder
cd functions

# Install node dependencies
npm install
```

To test and deploy the backend functions:
```powershell
# Test functions locally using the Firebase emulator
firebase emulators:start

# Deploy backend functions to the Singapore serverless region
firebase deploy --only functions
```

---

## Configuration

To connect the application to your Firebase services, place the following configuration files in their respective directories before building:
1.  **Android Configuration**: `android/app/google-services.json`
2.  **iOS Configuration**: `ios/Runner/GoogleService-Info.plist`
3.  **Web / Core Configuration**: `lib/firebase_options.dart` (generated by running `flutterfire configure`)

Ensure your Firestore database contains the `app_config/version` configuration document to support version checks.

---

## Usage

### User Reporting Workflow
1.  Log in using your Student/Staff ID (e.g., `B1234567`) and password.
2.  Tap on an emergency category (e.g., *Medical*).
3.  Fill out the form, attach a photo, and verify your GPS coordinates.
4.  Tap **Submit**. The dispatcher and relevant responders will be notified immediately.

### Dispatcher Triage Workflow
1.  Access the **Dispatcher Control Panel** (automatically routed based on your role).
2.  Select an active incident from the sidebar list or map marker.
3.  Review the **Responder Suggestions** ranking table.
4.  Click **Assign** to assign the recommended responder.
5.  Use the **Monitor Tools** to view live chats and track responder coordinates on the map.

### Responder Resolution Workflow
1.  Access the **Responder Dashboard**.
2.  Select an assigned task.
3.  Cycle through the operational milestones by clicking status buttons (`ACCEPTED` $\rightarrow$ `EN_ROUTE` $\rightarrow$ `ARRIVED` $\rightarrow$ `RESOLVED`).
4.  Once resolved, submit the resolution form to complete the task.

---

## Workflow / System Flow

```
[User Form Input] ──► Polls Geolocator ──► Uploads to Storage ──► Doc created at /incidents
                                                                          │
                                                                          ▼
                                                            Status = NEW, Timeline = REPORTED
                                                                          │
                                                                          ▼
                                                            Dispatcher alerted via FCM sound chimes
                                                                          │
                                                                          ▼
                                                            Assigns recommended responder (F5 score)
                                                                          │
                                                                          ▼
                                                            Firestore Transaction updates doc
                                                                          │
                                                                          ▼
                                                            Status = IN_PROGRESS, Timeline = ACCEPTED
                                                                          │
                                                                          ▼
                                                            Responder moves: EN_ROUTE ──► ARRIVED
                                                                          │
                                                                          ▼
                                                            Task resolved: Status = RESOLVED
```

---

## Data Model / Database Structure

The database structure is summarized below. For full field definitions and JSON schemas, see the [Database Spec](./docs/database.md).

### Root Collection: `users`
Stores user profile information, authorization roles, and location coordinates:
*   **Key Fields**: `uid`, `studentId`, `email`, `phone`, `role` (`user`, `responder`, `dispatcher`, `admin`), `department` (`hospital`, `rescue`, `security`), `volunteerPoints`, `lastLocation` (`lat`, `lng`, `updatedAt`).

### Root Collection: `incidents`
Tracks active and completed incident logs:
*   **Key Fields**: `title`, `description`, `type`, `priority`, `status`, `timelineStatus`, `reporterId`, `responderId`, `latitude`, `longitude`, `imageUrls`.
*   **Subcollection**: `messages` (holds messages sent within the incident chat channel).

### Root Collection: `direct_messages`
Stores direct communication channels between responders and dispatchers:
*   **Key Fields**: `participants`, `lastMessageText`, `lastMessageSenderId`, `lastMessageAt`, `lastReadBy`.
*   **Subcollection**: `messages` (holds direct messages sent within the DM channel).

---

## API / Services Integration

### Firebase Cloud Functions
Deployed to the **Singapore region (`asia-southeast1`)** to support Firestore reactive triggers:
*   `sendPushNotification`: Sends multicast push notifications to targeted devices using the server-side Admin SDK.
*   `verifyStudentByPhone`: Verifies if a Student ID matches its registered phone number during password recovery.
*   `resetPasswordByPhone`: Resets a user's password using the Firebase Admin SDK.

### Map Integrations
*   **Mobile Clients**: Uses the **Google Maps SDK for Flutter** to render smooth vector maps.
*   **Web/Desktop Clients**: Uses **Leaflet OpenStreetMap (OSM)** tiles to render lightweight mapping interfaces without Google Maps SDK costs.

---

## Build / Deployment

### Android Build
Target SDK configurations are located in `android/app/build.gradle`:
*   `compileSdkVersion`: `33` (Android 13)
*   `minSdkVersion`: `21` (Android 5.0)
*   `targetSdkVersion`: `33`

To build a production release APK:
```powershell
flutter build apk --release
```

### Web Build
To build a production Progressive Web App (PWA):
```powershell
flutter build web --release
```

---

## Limitations / Notes

*   **Virtual Domain Dependencies**: The virtual authentication domain `@campus.local` is hardcoded inside `AuthRepository`. If the university updates its identity provider or domain name, this suffix must be updated manually.
*   **Clock-Drift Synchronization**: Security rules use the database timestamp (`request.time`) for read receipt validation. If a user's device experiences significant clock drift, read receipt updates may temporarily fail with permission errors.
*   **Region Restrictions**: Cloud Functions are locked to `asia-southeast1` (Singapore) to support reactive triggers. Do not change this region during deployment unless Firestore trigger support is expanded.

---

## Future Improvements

Potential future improvements include:
*   **SMS Gateway Integration**: Replace or complement phone-based password reset lookups with an SMS OTP verification service.
*   **Dynamic Routing API**: Integrate an open routing engine (e.g., OSRM) into the Leaflet map layer to provide responders with optimized driving routes.
*   **Offline Data Sync**: Enable local caching for incident forms to support offline submissions in thick-walled campus basements.

---

## Author / Credits

*   **SUT Safety & Security Department**: Primary stakeholder and system user.
*   **SUT Campus Incident Development Team**: Client and Cloud database development.
*   **Computer Engineering Department**, Suranaree University of Technology.

---

## License

This repository is intended for educational and academic purposes. Licensing information has not been explicitly specified.
