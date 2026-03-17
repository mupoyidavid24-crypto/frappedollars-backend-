
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  Future<void> init() async {
    // 1. Initialisation Firebase Messaging
    await Firebase.initializeApp();
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Enregistrement du token FCM dans Supabase
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await Supabase.instance.client
              .from('profiles')
              .update({'fcm_token': token})
              .eq('id', userId);
        }
      }
      // 3. Rafraîchissement du token
      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await Supabase.instance.client
              .from('profiles')
              .update({'fcm_token': token})
              .eq('id', userId);
        }
      });
    }

    // 4. Initialisation notifications locales (Android/iOS/Web)
    // Initialisation notifications locales (Web: aucun argument, Mobile: settings)
    // ignore: undefined_prefixed_name
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    bool isWeb = identical(0, 0.0);
    await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

    // 5. Notifications en premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails('default_channel', 'Notifications'),
          ),
        );
      }
    });

    // 6. Notifications en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
}
