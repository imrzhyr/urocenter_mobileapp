import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:urocenter/services/document_service.dart';
import 'package:urocenter/services/chat_service.dart';
import 'package:urocenter/features/auth/services/auth_service.dart';
import '../features/user/services/user_profile_service.dart';
import '../services/storage_service.dart';
import '../features/chat/services/chat_playback_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/call_service.dart';
import '../core/models/notification_model.dart';
import 'package:urocenter/providers/in_app_notification_provider.dart';

// TODO: If services require other dependencies (like an ApiClient), 
// those dependencies should also be provided via Riverpod and passed here.

// --- Core Firebase Providers ---

/// Provides the current Firebase Auth instance.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Provides the current Firestore instance.
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Provides the current GoogleSignIn instance.
final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn());

// --- Authentication Service Providers ---

/// Provider for AuthService.
final authServiceProvider = Provider<AuthService>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final googleSignIn = ref.watch(googleSignInProvider);
  return AuthService(firebaseAuth, googleSignIn);
});

/// Stream provider for the authentication state changes.
/// Listens to Firebase Auth state changes and provides the current User or null.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  // Depends on the authServiceProvider instance
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Provider for UserProfileService
final userProfileServiceProvider = Provider<UserProfileService>((ref) => UserProfileService());

/// Provides the StorageService instance.
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

/// Provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return NotificationService(firestore, auth, ref);
});

/// Provider for streaming notifications
final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return notificationService.notificationsStream();
});

/// Provider for DocumentService
final documentServiceProvider = Provider<DocumentService>((ref) {
  // TODO: Inject dependencies if needed
  return DocumentService(); // Simple instance for now
});

/// Provider for ChatService
final chatServiceProvider = Provider<ChatService>((ref) {
  // Inject dependencies: Firestore, Auth, Ref
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return ChatService(firestore, auth, ref);
});

/// Provider for ChatPlaybackService
final chatPlaybackProvider = Provider<ChatPlaybackService>((ref) => ChatPlaybackService());

// --- ADDED: Global Incoming Message Stream Provider ---

/// Stream provider for global incoming chat messages for notifications.
final globalIncomingMessagesProvider = StreamProvider<NotificationData?>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getGlobalIncomingMessagesStream();
});

// --- ADDED: Provider to track currently viewed chat screen ---

/// State provider holding the ID of the chat screen currently being viewed.
/// Null if no chat screen is currently active.
final currentlyViewedChatIdProvider = StateProvider<String?>((ref) => null);

// --- END: Providers ---

// Example for fetching initial data (consider FutureProvider or StreamProvider)

// /// Provider to fetch the initial user profile
// final userProfileProvider = FutureProvider<User?>((ref) async {
//   final userService = ref.watch(userProfileServiceProvider);
//   return await userService.getCurrentUserProfile();
// });

// /// Provider to fetch the initial list of user documents
// final userDocumentsProvider = FutureProvider<List<DocumentModel>>((ref) async {
//   // Assuming getUserDocuments is in UserProfileService based on its current location
//   final userService = ref.watch(userProfileServiceProvider);
//   return await userService.getUserDocuments();
// });

// /// Provider to fetch the initial chat list
// final chatListProvider = FutureProvider<List<Chat>>((ref) async {
//   final chatService = ref.watch(chatServiceProvider);
//   return await chatService.getChatList();
// }); 