import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../services/backup_service.dart';
import '../../services/widget_service.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  bool _isLoading = true;
  int _streak = 0;
  int _totalWords = 0;
  int _masteredWords = 0;
  Map<DateTime, int> _last7Days = {};
  String? _lastBackupStr;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseProvider);
    final backupService = ref.read(backupServiceProvider);

    final streak = await db.calculateStreak();
    final total = await db.getTotalWordsCount();
    final mastered = await db.getMasteredWordsCount();
    final chartData = await db.getReviewCountsLast7Days();
    final lastBackup = await backupService.getLastBackupDate(db);

    if (!mounted) return;

    setState(() {
      _streak = streak;
      _totalWords = total;
      _masteredWords = mastered;
      _last7Days = chartData;
      _lastBackupStr = lastBackup;
      _isLoading = false;
    });
  }

  Future<void> _handleExport() async {
    final db = ref.read(databaseProvider);
    final backupService = ref.read(backupServiceProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang chuẩn bị file sao lưu...')),
    );

    try {
      await backupService.exportBackup(db);
      await _loadStatistics();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xuất sao lưu: $e')),
        );
      }
    }
  }

  Future<void> _handleImport() async {
    final db = ref.read(databaseProvider);
    final backupService = ref.read(backupServiceProvider);

    try {
      final summary = await backupService.importBackup(db);
      if (summary != null && mounted) {
        // Update widget as well
        ref.read(widgetServiceProvider).updateWidget(db);
        await _loadStatistics();

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Nhập dữ liệu thành công'),
              content: Text(
                'Đã nhập thành công ${summary.importedCount} từ mới.\n'
                'Bỏ qua ${summary.skippedCount} từ đã tồn tại trong kho từ.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi nhập sao lưu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Determine backup warning status
    DateTime? lastBackupDate;
    bool needsBackupWarning = false;
    String backupStatusMessage = '';

    if (_lastBackupStr == null) {
      needsBackupWarning = true;
      backupStatusMessage = 'Chưa từng sao lưu dữ liệu! Hãy tạo bản sao lưu ngay để bảo vệ tiến độ học tập.';
    } else {
      lastBackupDate = DateTime.tryParse(_lastBackupStr!);
      if (lastBackupDate != null) {
        final diffDays = DateTime.now().difference(lastBackupDate).inDays;
        if (diffDays > 14) {
          needsBackupWarning = true;
          backupStatusMessage = 'Đã hơn 14 ngày chưa sao lưu! Bạn nên cập nhật bản sao lưu mới.';
        } else {
          backupStatusMessage =
              'Sao lưu gần nhất: ${lastBackupDate.day.toString().padLeft(2, '0')}/${lastBackupDate.month.toString().padLeft(2, '0')}/${lastBackupDate.year} ${lastBackupDate.hour.toString().padLeft(2, '0')}:${lastBackupDate.minute.toString().padLeft(2, '0')}';
        }
      }
    }

    // Chart bars setup
    final sortedDays = _last7Days.keys.toList()..sort();
    final maxReviews = _last7Days.values.fold<int>(0, (max, v) => v > max ? v : max);
    final chartYMax = (maxReviews < 5 ? 5 : maxReviews + 2).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê & Sao lưu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới thống kê',
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3 Metric Cards Row
              Row(
                children: [
                  // Streak Card
                  Expanded(
                    child: Card(
                      elevation: 2,
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        child: Column(
                          children: [
                            const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 32),
                            const SizedBox(height: 6),
                            Text(
                              '$_streak ngày',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Chuỗi ôn tập',
                              style: TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Total Words Card
                  Expanded(
                    child: Card(
                      elevation: 2,
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        child: Column(
                          children: [
                            const Icon(Icons.menu_book, color: Colors.blue, size: 32),
                            const SizedBox(height: 6),
                            Text(
                              '$_totalWords từ',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tổng từ vựng',
                              style: TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mastered Card (interval >= 21)
                  Expanded(
                    child: Card(
                      elevation: 2,
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        child: Column(
                          children: [
                            const Icon(Icons.military_tech, color: Colors.green, size: 32),
                            const SizedBox(height: 6),
                            Text(
                              '$_masteredWords từ',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Thành thạo (≥21d)',
                              style: TextStyle(fontSize: 11, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 7-day Review Activity Bar Chart
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bar_chart, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Hoạt động ôn tập (7 ngày qua)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            maxY: chartYMax,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final day = sortedDays[group.x.toInt()];
                                  final dayStr = '${day.day}/${day.month}';
                                  return BarTooltipItem(
                                    '$dayStr\n${rod.toY.toInt()} từ',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= sortedDays.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final day = sortedDays[index];
                                    final isToday = day.day == DateTime.now().day &&
                                        day.month == DateTime.now().month;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        isToday ? 'Hôm nay' : '${day.day}/${day.month}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                          color: isToday
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  getTitlesWidget: (value, meta) {
                                    if (value % 2 != 0 && value != 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: const FlGridData(
                              show: true,
                              drawVerticalLine: false,
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: List.generate(sortedDays.length, (i) {
                              final day = sortedDays[i];
                              final count = _last7Days[day] ?? 0;
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: count.toDouble(),
                                    color: theme.colorScheme.primary,
                                    width: 18,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Backup & Restore Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.backup_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Sao lưu & Phục hồi dữ liệu (JSON)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Warning or info banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: needsBackupWarning
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: needsBackupWarning
                                ? Colors.red.shade200
                                : Colors.green.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              needsBackupWarning
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              color: needsBackupWarning
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                backupStatusMessage,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: needsBackupWarning
                                      ? Colors.red.shade900
                                      : Colors.green.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _handleExport,
                              icon: const Icon(Icons.upload_file),
                              label: const Text(
                                'Xuất sao lưu (Export)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _handleImport,
                              icon: const Icon(Icons.download),
                              label: const Text(
                                'Nhập dữ liệu (Import)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
