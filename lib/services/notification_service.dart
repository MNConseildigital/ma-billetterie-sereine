import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(settings);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'tickets_channel',
      'Rappels billets',
      channelDescription: 'Notifications de rappel pour les billets',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

  static Future<void> scheduleTicketReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'tickets_channel',
      'Rappels billets',
      channelDescription: 'Notifications programmées pour les billets',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    // uiLocalNotificationDateInterpretation supprimé — paramètre retiré dans
    // flutter_local_notifications ^19.x (Android uniquement désormais)
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> scheduleTestNotificationInTenSeconds() async {
    final now = DateTime.now();
    final scheduled = now.add(const Duration(seconds: 10));

    await scheduleTicketReminder(
      id: 999999,
      title: 'Test rappel billet',
      body: 'Votre notification programmée fonctionne.',
      scheduledDate: scheduled,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // NOTIFICATIONS BOURSE
  // ═══════════════════════════════════════════════════════════════

  /// Notification : nouvelle demande d'achat reçue
  static Future<void> showPurchaseRequestNotification({
    required String eventName,
  }) async {
    await showInstantNotification(
      title: '🔔 Nouvelle demande d\'achat',
      body: 'Quelqu\'un est intéressé par votre billet "$eventName"',
    );
  }

  /// Notification : nouveau message reçu
  static Future<void> showNewMessageNotification({
    required String senderName,
    required String ticketTitle,
  }) async {
    await showInstantNotification(
      title: '💬 Nouveau message',
      body: '$senderName concernant "$ticketTitle"',
    );
  }

  /// Notification : transfert de billet confirmé
  static Future<void> showTransferSuccessNotification({
    required String eventName,
  }) async {
    await showInstantNotification(
      title: '✅ Transfert réussi',
      body: 'Le billet "$eventName" a été transféré dans votre coffre-fort',
    );
  }
}