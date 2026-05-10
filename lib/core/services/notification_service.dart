
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  Future<void> init() async {
    await Firebase.initializeApp();

    if (kIsWeb) {
      return;
    }

    try {
      final NotificationSettings settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            await Supabase.instance.client.from('profiles').update({'fcm_token': token}).eq('id', userId);
          }
        }

        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            await Supabase.instance.client.from('profiles').update({'fcm_token': token}).eq('id', userId);
          }
        });
      }
    } catch (e) {
      debugPrint('Notification permission unavailable: $e');
    }

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final RemoteNotification? notification = message.notification;
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('default_channel', 'Notifications'),
          ),
        );
      }
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
}
