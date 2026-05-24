const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Callable function to send push notifications manually
// We deploy this to 'asia-southeast1' (Singapore) because 'asia-southeast3' does not support Firestore triggers.
exports.sendPushNotification = functions.region("asia-southeast1").https.onCall(async (data, context) => {
    // Basic auth check
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
    }

    const { targetRoles, targetUid, title, body, payload, channelId } = data;
    const senderUid = context.auth.uid;

    let tokens = [];

    // 1. Send to specific user
    if (targetUid && targetUid !== senderUid) {
        const userDoc = await admin.firestore().collection("users").doc(targetUid).get();
        if (userDoc.exists && userDoc.data().fcmToken) {
            tokens.push(userDoc.data().fcmToken);
        }
    }

    // 2. Send to specific roles (e.g., ['dispatcher'])
    if (targetRoles && Array.isArray(targetRoles)) {
        for (const role of targetRoles) {
            const usersSnapshot = await admin.firestore().collection("users").where("role", "==", role).get();
            usersSnapshot.forEach(doc => {
                const token = doc.data().fcmToken;
                if (token && !tokens.includes(token) && doc.id !== senderUid) {
                    tokens.push(token);
                }
            });
        }
    }

    if (tokens.length === 0) {
        return { success: false, message: "No target FCM tokens found." };
    }

    const message = {
        tokens: tokens,
        notification: { title, body },
        data: payload || {},
        android: {
            priority: "high",
            notification: {
                channelId: channelId || "status_updates"
            }
        },
        webpush: {
            notification: {
                title: title,
                body: body,
                icon: "/icons/Icon-192.png",
                badge: "/icons/Icon-192.png",
                vibrate: [200, 100, 200, 100, 200],
                requireInteraction: true,
            },
            fcmOptions: {
                link: "https://campus-incident-system.web.app"
            }
        }
    };

    try {
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Successfully sent multicast message. Success: ${response.successCount}, Failure: ${response.failureCount}`);
        return { success: true, successCount: response.successCount, failureCount: response.failureCount };
    } catch (error) {
        console.error(`Error sending push notification:`, error);
        throw new functions.https.HttpsError('internal', 'Failed to send push notification.');
    }
});
