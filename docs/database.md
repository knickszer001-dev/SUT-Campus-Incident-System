# Database Structure & Security Rules

This document describes the Firestore NoSQL database schemas, document structures, collection patterns, and security constraints used in the SUT Campus Incident System.

---

## 1. Firestore Root Collections & Subcollections

### Collection: `users`
*   **Path**: `/users/{uid}`
*   **Description**: Stores profile metrics, authorization roles, and current location coordinates.

| Field Name | Type | Description |
|:---|:---|:---|
| `uid` | `String` | Firebase Auth unique user identifier. |
| `studentId` | `String` | Normalized alphanumeric Student/Staff ID (e.g. `B1234567`). |
| `email` | `String` | Virtual email address associated with the account (`B1234567@campus.local`). |
| `firstName` | `String` | First name. |
| `lastName` | `String` | Last name. |
| `phone` | `String` | Telephone number used in identity verification during recovery. |
| `role` | `String` | Authorization role: `user` \| `responder` \| `dispatcher` \| `admin`. |
| `department` | `String` | Department identifier: `hospital` \| `rescue` \| `security` \| `null`. |
| `volunteerPoints`| `Integer` | Points awarded to students for verified emergency reports. |
| `lastLocation` | `Map` | Geographic tracking container: `lat` (Double), `lng` (Double), `updatedAt` (Timestamp). |
| `fcmToken` | `String` | Active Firebase Cloud Messaging token. |
| `createdAt` | `Timestamp`| Registration timestamp. |

---

### Collection: `incidents`
*   **Path**: `/incidents/{incidentId}`
*   **Description**: Stores active and completed incident logs.

| Field Name | Type | Description |
|:---|:---|:---|
| `title` | `String` | Short summary title. |
| `description` | `String` | Detailed explanation of the emergency. |
| `type` | `String` | Incident category: `security` \| `medical` \| `accident` \| `facility` \| `assistance`. |
| `priority` | `String` | Priority tier: `LOW` \| `MEDIUM` \| `HIGH` \| `URGENT`. |
| `status` | `String` | State: `NEW` \| `IN_PROGRESS` \| `RESOLVED` \| `CANCELLED`. |
| `timelineStatus` | `String` | Operational milestone: `REPORTED` \| `ACCEPTED` \| `EN_ROUTE` \| `ARRIVED` \| `RESOLVED`. |
| `reporterId` | `String` | UID of the reporting user. |
| `reporterName` | `String` | Display name of the reporter. |
| `reporterPhone` | `String` | Phone number of the reporter. |
| `responderId` | `String` | UID of the assigned responder (`null` if unassigned). |
| `responderName` | `String` | Display name of the responder (`null` if unassigned). |
| `latitude` | `Double` | Incident latitude coordinate. |
| `longitude` | `Double` | Incident longitude coordinate. |
| `imageUrls` | `Array` | List of secure HTTPS links to image attachments on Firebase Storage. |
| `createdAt` | `Timestamp`| Server-side creation timestamp. |
| `updatedAt` | `Timestamp`| Server-side modification timestamp. |
| `lastMessageAt` | `Timestamp`| Timestamp of the last chat message sent. |
| `lastMessageSenderId` | `String` | UID of the sender of the last chat message. |
| `lastReadBy` | `Map` | Tracked read markers: `{uid: Timestamp}`. |

#### Subcollection: `messages`
*   **Path**: `/incidents/{incidentId}/messages/{messageId}`
*   **Description**: Holds messages sent within the incident chat channel.

| Field Name | Type | Description |
|:---|:---|:---|
| `senderId` | `String` | Sender unique user identifier. |
| `senderName` | `String` | Sender display name. |
| `text` | `String` | Message content. |
| `imageUrl` | `String` | Secure HTTPS link to a chat image attachment (`null` if text-only). |
| `createdAt` | `Timestamp`| Creation timestamp. |

---

### Collection: `direct_messages`
*   **Path**: `/direct_messages/{chatId}`
*   **Naming Format**: `dm_{sortedUid1}_{sortedUid2}` to prevent duplicate channels.
*   **Description**: Channels for direct communication between responders and dispatchers.

| Field Name | Type | Description |
|:---|:---|:---|
| `participants` | `Array` | List of participant UIDs: `[uid1, uid2]`. |
| `lastMessageAt` | `Timestamp`| Timestamp of the last DM sent. |
| `lastMessageText`| `String` | Content of the last message sent. |
| `lastMessageSenderId` | `String` | UID of the sender of the last DM. |
| `updatedAt` | `Timestamp`| Modification timestamp. |
| `lastReadBy` | `Map` | Tracked read markers: `{uid: Timestamp}`. |

#### Subcollection: `messages`
*   **Path**: `/direct_messages/{chatId}/messages/{messageId}`

| Field Name | Type | Description |
|:---|:---|:---|
| `senderId` | `String` | Unique user identifier of the sender. |
| `senderName` | `String` | Display name of the sender. |
| `text` | `String` | Message content. |
| `imageUrl` | `String` | Secure HTTPS link to a chat image attachment (`null` if text-only). |
| `createdAt` | `Timestamp`| Creation timestamp. |

---

## 2. Security Rules (`firestore.rules`)

To enforce data integrity and prevent role-spoofing or self-promotion, the repository enforces strict security rules at the database level:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Authorization helpers
    function isAuthenticated() { return request.auth != null; }
    function isUser(uid) { return isAuthenticated() && request.auth.uid == uid; }
    function getUserData() { return get(/databases/$(database)/documents/users/$(request.auth.uid)).data; }
    function hasRole(role) { return isAuthenticated() && getUserData().role == role; }

    // Users Collection rules
    match /users/{uid} {
      allow read: if isAuthenticated();
      // Restrict role creation to 'user' on signup
      allow create: if isUser(uid) && request.resource.data.role == 'user';
      // Prevent self-promotion during profile updates
      allow update: if isUser(uid) && request.resource.data.role == resource.data.role;
      allow delete: if hasRole('admin');
    }

    // Incidents Collection rules
    match /incidents/{incidentId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update, delete: if hasRole('dispatcher') || hasRole('admin') || hasRole('responder') || resource.data.reporterId == request.auth.uid;
      
      // Subcollection chat rules
      match /messages/{messageId} {
        allow read, write: if isAuthenticated() && (
          hasRole('dispatcher') || 
          hasRole('admin') || 
          resource.data.reporterId == request.auth.uid || 
          resource.data.responderId == request.auth.uid
        );
      }
    }
  }
}
```
