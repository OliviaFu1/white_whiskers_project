import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:frontend/state/notifiers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// Still exported for use by api_client, register_page, etc.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Signals AppShell to navigate to the medication page.
/// Used as a fast path when the callback fires on the main isolate.
final ValueNotifier<bool> pendingMedicationNavigation = ValueNotifier(false);

/// shared_preferences key used to signal navigation across isolates.
const _kPendingMedNav = 'pending_medication_nav';

/// Only Android and iOS support local notifications.
bool get _supported =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Top-level function required for background isolate entry point.
/// May run in a background isolate — only use cross-isolate-safe APIs here.
@pragma('vm:entry-point')
Future<void> onNotificationTap(NotificationResponse response) async {
  // Persist navigation intent so AppShell can pick it up on resume,
  // regardless of whether this runs in the main or background isolate.
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPendingMedNav, true);
    // Store payload so the backend notification can be created later.
    if (response.payload != null) {
      await prefs.setString('pending_medication_payload', response.payload!);
    }
    // Store the tap date so the medication schedule opens on the right day.
    await prefs.setString(
      'pending_medication_date',
      DateTime.now().toIso8601String(),
    );
  } catch (_) {}

  // Fast path: if we're on the main isolate the ValueNotifier works immediately.
  pendingMedicationNavigation.value = true;
}

Future<void> handleBackendNotificationIfPending() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString('pending_medication_payload');
    await prefs.remove('pending_medication_payload');
    // process_due_doses already creates the backend notification — just refresh.
    if (payload != null && payload.isNotEmpty) {
      await loadNotifications();
    }
  } catch (_) {}
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Cached during [init] so all scheduling uses the same resolved location
  /// rather than relying on [tz.local] being set at call time.
  static tz.Location? _localLocation;
  static tz.Location get _loc => _localLocation ?? tz.local;

  static const _channelId = 'medication_reminders';
  static const _channelName = 'Medication Reminders';
  static const _channelDesc =
      'Daily reminders to administer pet medications on schedule';

  /// Offset added to the medication ID to produce a unique notification ID
  /// for refill-low alerts, avoiding collisions with daily dose reminders.
  static const _refillIdOffset = 1000000;

  /// Offset added to the pet ID for birthday reminder notification IDs.
  static const _birthdayIdOffset = 2000000;

  static NotificationResponse? _pendingLaunch;

  /// Call this after [runApp] to handle taps that cold-launched the app.
  static Future<void> handlePendingLaunch() async {
    final pending = _pendingLaunch;
    if (pending != null) {
      _pendingLaunch = null;
      await onNotificationTap(pending);
    }
  }

  static Future<void> init() async {
    if (!_supported) return;

    tz_data.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    _localLocation = tz.getLocation(localTz);
    tz.setLocalLocation(_localLocation!);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: onNotificationTap,
      // No background handler: on Android, tapping a notification while the app
      // is backgrounded fires onDidReceiveNotificationResponse on the main isolate
      // when the app resumes. A background isolate handler cannot reliably use
      // plugins (shared_preferences, navigation) without extra setup.
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    // Only prompt for exact alarm permission if not already granted.
    final canExact =
        await androidPlugin?.canScheduleExactNotifications() ?? false;
    if (!canExact) {
      await androidPlugin?.requestExactAlarmsPermission();
    }

    // Store response if the app was cold-launched by tapping a notification.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse != null) {
      _pendingLaunch = launch!.notificationResponse;
    }
  }

  static const _kNotificationsEnabled = 'notifications_enabled';
  static const kDoseRemindersEnabled  = 'notifications_dose_reminders';
  static const kRefillAlertsEnabled   = 'notifications_refill_alerts';
  static const kBirthdayEnabled       = 'notifications_birthday';
  // Saved (UTC ISO-8601) whenever dose reminders are re-enabled so that
  // processDueDoses can ignore doses that elapsed while they were off.
  static const _kResumeTs = 'notification_resume_ts';

  /// Returns the full preferences map in one prefs read.
  static Future<({bool global, bool dose, bool refill, bool birthday})>
  getPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      global: prefs.getBool(_kNotificationsEnabled) ?? true,
      dose: prefs.getBool(kDoseRemindersEnabled) ?? true,
      refill: prefs.getBool(kRefillAlertsEnabled) ?? true,
      birthday: prefs.getBool(kBirthdayEnabled) ?? true,
    );
  }

  /// Returns whether the user has notifications enabled (default: true).
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kNotificationsEnabled) ?? true;
  }

  /// Enables or disables all local notifications.
  /// Disabling cancels every scheduled notification immediately.
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsEnabled, value);
    if (value) {
      // Record when notifications were re-enabled so processDueDoses can
      // ignore doses that elapsed while they were off.
      await prefs.setString(_kResumeTs, DateTime.now().toUtc().toIso8601String());
    } else if (_supported) {
      await _plugin.cancelAll();
    }
  }

  static Future<void> setCategoryEnabled(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (value && key == kDoseRemindersEnabled) {
      // Record resume timestamp so processDueDoses ignores past doses.
      await prefs.setString(_kResumeTs, DateTime.now().toUtc().toIso8601String());
    }
  }

  /// Returns the stored resume timestamp (UTC), or null if never set.
  static Future<DateTime?> getResumeTs() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kResumeTs);
    if (s == null) return null;
    try {
      return DateTime.parse(s).toUtc();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _categoryEnabled(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_kNotificationsEnabled) ?? true) &&
        (prefs.getBool(key) ?? true);
  }

  /// Fires an immediate notification — use this to verify the system works.
  static Future<void> showNow({
    required String title,
    required String body,
  }) async {
    if (!_supported) return;
    await _plugin.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Schedules or cancels a daily notification for a medication.
  /// Only acts on `fixed_times` scheduled, active/paused medications.
  static Future<void> syncFromMedication(
    Map<String, dynamic> med,
    String petName,
  ) async {
    if (!_supported) return;
    if (!await isEnabled()) return;

    final id = med["id"] as int;
    final petId = med["pet_id"] as int?;
    final status = (med["status"] ?? "").toString();
    final isActiveOrPaused = status == "active" || status == "paused";

    if (!isActiveOrPaused || med["as_needed"] == true) {
      await cancel(id);
      return;
    }

    // Refill reminder: 7 days before the expected last day.
    final prescriptions =
        (med["prescriptions"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final expirationDateStr = prescriptions.isNotEmpty
        ? prescriptions.first["expiration_date"]?.toString()
        : null;
    if (await _categoryEnabled(kRefillAlertsEnabled)) {
      await _syncRefillReminder(
        id,
        (med["drug_name"] ?? "Medication").toString(),
        petName,
        expirationDateStr,
        petId,
      );
    } else {
      await _plugin.cancel(id + _refillIdOffset);
    }

    final schedules =
        (med["schedules"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final fixed = schedules.firstWhere(
      (s) => s["schedule_type"] == "fixed_times" && s["active"] != false,
      orElse: () => {},
    );

    if (fixed.isEmpty) {
      await cancel(id);
      return;
    }

    final timeStr = fixed["time_of_day"]?.toString() ?? "";
    final parts = timeStr.split(":");
    final hour = parts.length >= 2 ? (int.tryParse(parts[0]) ?? 0) : 0;
    final minute = parts.length >= 2 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final drugName = (med["drug_name"] ?? "Medication").toString();

    if (!await _categoryEnabled(kDoseRemindersEnabled)) {
      await _plugin.cancel(id);
      return;
    }

    await _scheduleDailyAt(
      id: id,
      hour: hour,
      minute: minute,
      title: 'Time to give $drugName to $petName',
      body: "Don't forget to administer $drugName to $petName.",
      payload: jsonEncode({
        'type': 'medication',
        'pet_id': petId,
        'drug_name': drugName,
        'pet_name': petName,
      }),
    );
  }

  static Future<void> cancel(int medId) async {
    if (!_supported) return;
    await _plugin.cancel(medId);
    await _plugin.cancel(medId + _refillIdOffset);
  }

  /// Schedules a one-time birthday notification for the next occurrence of the
  /// pet's birthday at 9 AM. Re-syncing on every app launch ensures it
  /// reschedules automatically each year after the previous one fires.
  static Future<void> syncBirthdayReminder(
    int petId,
    String petName,
    String? birthdateStr, {
    bool isDeceased = false,
    String? sex, // "male" | "female" | "unknown" or null
  }) async {
    final notifId = petId + _birthdayIdOffset;
    if (!_supported || !await _categoryEnabled(kBirthdayEnabled)) {
      await _plugin.cancel(notifId);
      return;
    }
    if (birthdateStr == null || birthdateStr.isEmpty) {
      await _plugin.cancel(notifId);
      return;
    }

    final DateTime birthdate;
    try {
      birthdate = DateTime.parse(birthdateStr);
    } catch (_) {
      await _plugin.cancel(notifId);
      return;
    }

    final now = tz.TZDateTime.now(_loc);

    // Next birthday: this year if not yet passed today, otherwise next year.
    var nextBirthday = tz.TZDateTime(
      _loc,
      now.year,
      birthdate.month,
      birthdate.day,
      9, // 9 AM
      0,
    );
    if (!nextBirthday.isAfter(now)) {
      nextBirthday = tz.TZDateTime(
        _loc,
        now.year + 1,
        birthdate.month,
        birthdate.day,
        9,
        0,
      );
    }

    await _plugin.cancel(notifId);

    final canExact =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;

    final objPronoun = switch (sex?.toLowerCase()) {
      "male" => "him",
      "female" => "her",
      _ => "them",
    };
    final title = isDeceased
        ? 'Remembering $petName'
        : 'Happy Birthday, $petName!';
    final body = isDeceased
        ? "Today would have been ${petName}'s birthday. Thinking of you and $objPronoun."
        : "Today is ${petName}'s special day! Give $objPronoun some extra love.";

    await _plugin.zonedSchedule(
      notifId,
      title,
      body,
      nextBirthday,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode({
        'type': 'birthday',
        'pet_id': petId,
        'pet_name': petName,
      }),
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedules (or cancels) a one-time "7 days left" reminder for a medication
  /// that has a prescription with a known expected last day.
  static Future<void> _syncRefillReminder(
    int medId,
    String drugName,
    String petName,
    String? expirationDateStr,
    int? petId,
  ) async {
    final notifId = medId + _refillIdOffset;
    if (expirationDateStr == null || expirationDateStr.isEmpty) {
      await _plugin.cancel(notifId);
      return;
    }

    final DateTime lastDay;
    try {
      lastDay = DateTime.parse(expirationDateStr);
    } catch (_) {
      await _plugin.cancel(notifId);
      return;
    }

    // Fire at 9 AM, 7 days before the expected last day.
    final reminderDate = lastDay.subtract(const Duration(days: 7));
    final now = tz.TZDateTime.now(_loc);
    final scheduled = tz.TZDateTime(
      _loc,
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      9, // 9 AM
      0,
    );

    if (scheduled.isBefore(now)) {
      // Reminder date already passed — cancel any stale notification.
      await _plugin.cancel(notifId);
      return;
    }

    await _plugin.cancel(notifId);

    final canExact =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;

    await _plugin.zonedSchedule(
      notifId,
      'Refill reminder: $drugName',
      '$drugName for $petName runs out in 7 days. Time to request a refill!',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode({
        'type': 'medication',
        'pet_id': petId,
        'drug_name': drugName,
        'pet_name': petName,
      }),
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> _scheduleDailyAt({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    await _plugin.cancel(id);

    final now = tz.TZDateTime.now(_loc);
    var scheduled = tz.TZDateTime(
      _loc,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final canExact =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
