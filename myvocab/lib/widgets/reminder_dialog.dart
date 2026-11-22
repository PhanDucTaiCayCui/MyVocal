import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../services/notification_service.dart';

class ReminderDialog {
  static const String settingKey = 'daily_reminder_time';
  static const String settingEnabledKey = 'daily_reminder_enabled';

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final savedTimeStr = await db.getSetting(settingKey);
    final savedEnabledStr = await db.getSetting(settingEnabledKey);

    TimeOfDay initialTime = const TimeOfDay(hour: 20, minute: 0);
    if (savedTimeStr != null && savedTimeStr.contains(':')) {
      final parts = savedTimeStr.split(':');
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        initialTime = TimeOfDay(hour: h, minute: m);
      }
    }

    final isEnabled = savedEnabledStr != 'false';

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        TimeOfDay selectedTime = initialTime;
        bool enabled = isEnabled;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.alarm, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Nhắc nhở hàng ngày'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nhận thông báo nhắc nhở ôn từ vựng hàng ngày để duy trì thói quen học tập.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Bật nhắc nhở'),
                    value: enabled,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setDialogState(() => enabled = val);
                    },
                  ),
                  if (enabled) ...[
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: const Text('Giờ nhắc nhở'),
                      trailing: Chip(
                        label: Text(
                          selectedTime.format(dialogContext),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: dialogContext,
                          initialTime: selectedTime,
                          helpText: 'CHỌN GIỜ NHẮC NHỞ HÀNG NGÀY',
                          confirmText: 'CHỌN',
                          cancelText: 'HỦY',
                        );
                        if (picked != null) {
                          setDialogState(() => selectedTime = picked);
                        }
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final notifService = ref.read(notificationServiceProvider);
                    await notifService.requestPermissions();

                    if (enabled) {
                      await notifService.scheduleDailyReminder(
                        hour: selectedTime.hour,
                        minute: selectedTime.minute,
                      );
                      final timeStr =
                          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                      await db.setSetting(settingKey, timeStr);
                      await db.setSetting(settingEnabledKey, 'true');

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đã lên lịch nhắc nhở lúc ${selectedTime.format(context)} mỗi ngày',
                            ),
                          ),
                        );
                      }
                    } else {
                      await notifService.cancelDailyReminder();
                      await db.setSetting(settingEnabledKey, 'false');

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã tắt nhắc nhở hàng ngày')),
                        );
                      }
                    }

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Lưu cài đặt'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
