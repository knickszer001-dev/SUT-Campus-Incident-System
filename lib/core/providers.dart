import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/incident/data/incident_repository.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/data/direct_chat_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.read(firebaseAuthProvider),
    firestore: ref.read(firestoreProvider),
  );
});

final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  return IncidentRepository(
    firestore: ref.read(firestoreProvider),
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    firestore: ref.read(firestoreProvider),
  );
});

final directChatRepositoryProvider = Provider<DirectChatRepository>((ref) {
  return DirectChatRepository(
    firestore: ref.read(firestoreProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// currentUserProvider — ใช้ StreamProvider (ไม่ใช่ Future) เพื่อ real-time
/// เมื่อ profile ถูกแก้ไข (เช่น จาก ProfileScreen) ทุกหน้าที่ watch จะอัปเดตอัตโนมัติ
final currentUserProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref
      .read(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists ? doc.data() : null);
});

/// #33: Theme Mode Provider (Dark Mode toggle)
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
