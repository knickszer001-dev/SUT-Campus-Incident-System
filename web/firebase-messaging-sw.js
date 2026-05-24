// Firebase Messaging Service Worker — Web Push Notifications
// This service worker handles background push notifications for the web app

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDMabkRNwBmOQHocgE5un6BIHCU3bob1gg',
  appId: '1:31291316300:web:f208277a9cd51df935fce9',
  messagingSenderId: '31291316300',
  projectId: 'campus-incident-system',
  authDomain: 'campus-incident-system.firebaseapp.com',
  storageBucket: 'campus-incident-system.firebasestorage.app',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background message:', payload);

  const notificationTitle = payload.notification?.title || payload.data?.title || '🚨 ระบบแจ้งเหตุ';
  const notificationBody = payload.notification?.body || payload.data?.body || 'มีการแจ้งเตือนใหม่';
  
  const notificationOptions = {
    body: notificationBody,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    vibrate: [200, 100, 200, 100, 200],
    tag: payload.data?.type || 'default',
    data: payload.data || {},
    requireInteraction: true,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click — open the app
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification click:', event);
  event.notification.close();

  // Focus existing window or open new one
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
