# System Features Specification

This document provides detailed technical specifications for the core functional features (F1 to F10) of the SUT Campus Incident System.

---

## F1: Incident Submission Pipeline
*   **Purpose**: Allows students and staff to quickly report campus emergencies.
*   **Behavior**: Polled GPS coordinates are refined via a 10-meter `Geolocator` distance filter. Images are uploaded asynchronously to `/incident_images/{id}_{filename}` on Firebase Storage, returning secure HTTPS download URLs before the parent document is written to `/incidents`.

---

## F2: virtual GSuite Credentials Conversion
*   **Purpose**: Simplifies login by allowing university users to authenticate using their alphanumeric Student/Staff IDs (e.g., `B1234567`) instead of traditional emails.
*   **Behavior**: When a user registers or logs in, the `AuthRepository` normalizes the ID to uppercase and appends `@campus.local` behind the scenes, routing the login through standard Firebase Auth:
    ```dart
    final virtualEmail = '${studentId.toUpperCase().trim()}@campus.local';
    await _firebaseAuth.signInWithEmailAndPassword(
      email: virtualEmail,
      password: password,
    );
    ```

---

## F3: Secure Phone-Based Credentials Recovery
*   **Purpose**: A secure password recovery flow that does not require email setups or OTP services.
*   **Execution Flow**:
    1.  **Verification**: The user enters their Student ID and telephone number. An HTTPS Callable function (`verifyStudentByPhone`) checks if these details match a record in the database.
    2.  **Reset**: If verified, the app requests the serverless Cloud Function (`resetPasswordByPhone`) to update the user's password using the Firebase Admin SDK, bypassing standard client-side password write blocks.

---

## F4: Reactive Riverpod State Streams
*   **Purpose**: Keeps the client UI synchronized with remote database updates.
*   **Behavior**: Combines Riverpod providers and Firestore document snapshots:
    *   `authStateProvider`: A Riverpod `StreamProvider` that tracks user login sessions.
    *   `currentUserProvider`: A `StreamProvider` linked to `/users/{uid}`. When profile fields—such as points or location coordinates—are updated, this stream automatically notifies and updates relevant UI components.

---

## F5: Smart Responder Recommendation Scoring
*   **Purpose**: Recommends the best responder for a given incident based on a three-tier scoring model.
*   **Scoring Model**:
    $$\text{Score} = S_{\text{dept}} + S_{\text{load}} + S_{\text{prox}}$$
    *   **Department Match ($S_{\text{dept}}$ = +3 points)**: Matches responder departments (e.g. `hospital`) to incident types (e.g. `medical`).
    *   **Workload Match ($S_{\text{load}}$ = +2 points)**: Checks active tasks; responders with fewer than 2 active cases receive a bonus.
    *   **Proximity Match ($S_{\text{prox}}$ = +1 point)**: Adds points if the responder is within a 1.0 km radius, calculated using the Haversine formula against their last recorded location.
*   **Optimization**: 
    To avoid performance issues, this function fetches all active `IN_PROGRESS` incidents in a single query:
    ```dart
    final activeIncidentsSnap = await _firestore.collection('incidents')
        .where('status', isEqualTo: 'IN_PROGRESS').get();
    ```
    It compiles these documents into an in-memory workload map (`activeCasesMap`), reducing lookup complexity to a fast $O(1)$ operations loop.

---

## F6: Live GPS Tracking
*   **Purpose**: Streams responder locations to the command center map.
*   **Behavior**: Responders report their current coordinates via a background location task. These coordinates are written to the database under `users/{uid}/lastLocation`. A real-time stream `getRespondersLocationStream()` allows dispatchers to monitor all responder locations on the command map.

---

## F7: Incident Chat Channels & DMs
*   **Purpose**: Enables immediate communication between responders, reporters, and dispatchers.
*   **Format**: Group chats are located at `/incidents/{incidentId}/messages` for active incident participants, and direct messages at `/direct_messages/{chatId}/messages` for communication between responders and dispatchers.

---

## F8: Double-Notification Suppression
*   **Purpose**: Mutes notification sounds if the user is actively viewing the chat room.
*   **Behavior**: A global watcher `WebNotificationWatcher` tracks the open chat ID. If a new message is received in that chat room, the system mutes the audible alert, ensuring a quiet, real-time messaging experience.

---

## F9: Responsive Dual-Layout
*   **Purpose**: Supports mobile, web, and desktop layouts from a single codebase.
*   **Behavior**: Uses `LayoutBuilder` to adapt the UI:
    *   **Mobile Screens (< 700px)**: Displays a bottom-navigation tab interface.
    *   **Desktop/Large Screens**: Displays a split-pane layout showing list panels, statistics, and interactive maps side-by-side.

---

## F10: Cross-Platform Sound System
*   **Purpose**: Supports audio notifications across environments.
*   **Behavior**: Native clients play alert sounds using the `audioplayers` package, while web clients trigger clean beeps by wrapping Web Audio API chimes directly inside JavaScript Interop functions.
