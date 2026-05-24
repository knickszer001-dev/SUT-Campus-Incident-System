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

// ===== Reset Password by Phone Verification =====
// ไม่ต้อง login — ผู้ใช้ยืนยันตัวตนด้วย studentId + เบอร์โทรที่เคยลงทะเบียนไว้
// แล้ว Admin SDK จะเปลี่ยนรหัสผ่านให้โดยตรง (ไม่ต้องส่งเมล)
exports.resetPasswordByPhone = functions.region("asia-southeast1").https.onCall(async (request) => {
    // firebase-functions v5: parameter แรกคือ request object, data อยู่ที่ request.data
    // firebase-functions v1 compat: parameter แรกคือ data โดยตรง
    const rawData = request.data || request;
    const studentId = rawData.studentId;
    const phoneNumber = rawData.phoneNumber;
    const newPassword = rawData.newPassword;

    console.log('[resetPasswordByPhone] Received:', { studentId, phoneNumber: phoneNumber ? '***' : undefined, hasPassword: !!newPassword });

    // Validate input
    if (!studentId || !phoneNumber || !newPassword) {
        console.log('[resetPasswordByPhone] Missing fields:', { studentId: !!studentId, phoneNumber: !!phoneNumber, newPassword: !!newPassword });
        throw new functions.https.HttpsError('invalid-argument', 'กรุณากรอกข้อมูลให้ครบ');
    }

    if (newPassword.length < 6) {
        throw new functions.https.HttpsError('invalid-argument', 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');
    }

    const uppercaseId = studentId.toUpperCase();
    const lowercaseId = studentId.toLowerCase();

    // Normalize phone: strip leading 0 or +66 for comparison
    const normalizePhone = (p) => p.replace(/[\s\-]/g, '').replace(/^(\+66|0)/, '');
    const inputPhone = normalizePhone(phoneNumber);


    try {
        // 1. Find user in Firestore by studentId (checking both upper and lower case)
        const usersSnapshot = await admin.firestore()
            .collection('users')
            .where('studentId', 'in', [uppercaseId, lowercaseId])
            .limit(1)
            .get();

        if (usersSnapshot.empty) {
            throw new functions.https.HttpsError('not-found', 'ไม่พบรหัสนักศึกษา/บุคลากรนี้ในระบบ');
        }

        const userDoc = usersSnapshot.docs[0];
        const userData = userDoc.data();

        // 2. Verify phone number matches
        const storedPhone = normalizePhone(userData.phoneNumber || '');
        if (!storedPhone || inputPhone !== storedPhone) {
            throw new functions.https.HttpsError('permission-denied', 'เบอร์โทรศัพท์ไม่ตรงกับที่ลงทะเบียนไว้');
        }

        // 3. Find user in Firebase Auth by email first (to guarantee we update the correct credentials)
        let authUid = userDoc.id; // Default fallback to Firestore document ID
        const possibleEmails = [];
        
        if (userData.email) {
            possibleEmails.push(userData.email);
        }
        possibleEmails.push(`${lowercaseId}@campus.local`);
        possibleEmails.push(`${uppercaseId}@campus.local`);
        possibleEmails.push(`${lowercaseId}@g.sut.ac.th`);
        possibleEmails.push(`${uppercaseId}@g.sut.ac.th`);

        // Remove duplicates
        const uniqueEmails = [...new Set(possibleEmails)];
        console.log('[resetPasswordByPhone] Checking emails in Auth:', uniqueEmails);

        for (const email of uniqueEmails) {
            try {
                const authUser = await admin.auth().getUserByEmail(email);
                if (authUser) {
                    authUid = authUser.uid;
                    console.log(`[resetPasswordByPhone] Found Auth user by email: ${email}, UID: ${authUid}`);
                    break;
                }
            } catch (e) {
                // Email not found in Auth, try next
            }
        }

        // 4. Update password via Admin SDK
        console.log(`[resetPasswordByPhone] Updating password for Auth UID: ${authUid}`);
        await admin.auth().updateUser(authUid, { password: newPassword });

        // 5. Log the reset event
        await admin.firestore().collection('users').doc(userDoc.id).update({
            'lastPasswordReset': admin.firestore.FieldValue.serverTimestamp(),
        });

        return { success: true, message: 'รีเซ็ตรหัสผ่านสำเร็จ' };

    } catch (error) {
        // Re-throw HttpsError as-is, wrap other errors
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        console.error('resetPasswordByPhone error:', error);
        throw new functions.https.HttpsError('internal', 'เกิดข้อผิดพลาดในระบบ กรุณาลองใหม่');
    }
});

// ===== Verify Student Identity by Phone (Step 1) =====
// เช็คว่า studentId + เบอร์โทรตรงกันหรือไม่ — ไม่เปลี่ยนรหัสผ่าน
exports.verifyStudentByPhone = functions.region("asia-southeast1").https.onCall(async (request) => {
    const rawData = request.data || request;
    const studentId = rawData.studentId;
    const phoneNumber = rawData.phoneNumber;

    if (!studentId || !phoneNumber) {
        throw new functions.https.HttpsError('invalid-argument', 'กรุณากรอกข้อมูลให้ครบ');
    }

    const uppercaseId = studentId.toUpperCase();
    const lowercaseId = studentId.toLowerCase();
    const normalizePhone = (p) => p.replace(/[\s\-]/g, '').replace(/^(\+66|0)/, '');
    const inputPhone = normalizePhone(phoneNumber);

    const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('studentId', 'in', [uppercaseId, lowercaseId])
        .limit(1)
        .get();

    if (usersSnapshot.empty) {
        throw new functions.https.HttpsError('not-found', 'ไม่พบรหัสนักศึกษา/บุคลากรนี้ในระบบ');
    }

    const userData = usersSnapshot.docs[0].data();
    const storedPhone = normalizePhone(userData.phoneNumber || '');

    if (!storedPhone || inputPhone !== storedPhone) {
        throw new functions.https.HttpsError('permission-denied', 'เบอร์โทรศัพท์ไม่ตรงกับที่ลงทะเบียนไว้');
    }

    return { success: true, message: 'ยืนยันตัวตนสำเร็จ' };
});
