import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../utils/intent_utils.dart';
import '../add_word/add_word_screen.dart';
import '../review/review_screen.dart';
import '../statistics/statistics_screen.dart';
import '../word_list/word_list_screen.dart';

final dueWordCountStreamProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchDueWordCount();
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  static const MethodChannel _shareChannel =
      MethodChannel('com.tai.myvocab/share');

  final List<Widget> _screens = const [
    WordListScreen(),
    ReviewScreen(),
    StatisticsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initChannelListener();
    _checkInitialIntent();
  }

  void _initChannelListener() {
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedText') {
        final rawText = call.arguments as String?;
        if (rawText != null) {
          _handleSharedText(rawText);
        }
      } else if (call.method == 'onOpenReview') {
        if (mounted) {
          setState(() => _currentIndex = 1);
        }
      }
    });
  }

  Future<void> _checkInitialIntent() async {
    try {
      final initialAction =
          await _shareChannel.invokeMethod<String>('getInitialAction');
      if (initialAction == 'ACTION_OPEN_REVIEW' && mounted) {
        setState(() => _currentIndex = 1);
      }

      final initialText =
          await _shareChannel.invokeMethod<String>('getInitialText');
      if (initialText != null && initialText.isNotEmpty) {
        _handleSharedText(initialText);
      }
    } catch (_) {
      // Ignored in non-Android or tests
    }
  }

  void _handleSharedText(String rawText) {
    final cleaned = IntentUtils.cleanSharedText(rawText);
    if (cleaned.isNotEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddWordScreen(initialWordText: cleaned),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueCountAsync = ref.watch(dueWordCountStreamProvider);
    final dueCount = dueCountAsync.value ?? 0;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.format_list_bulleted),
            selectedIcon: Icon(Icons.format_list_bulleted_rounded),
            label: 'Từ vựng',
          ),
          NavigationDestination(
            icon: dueCount > 0
                ? Badge.count(
                    count: dueCount,
                    child: const Icon(Icons.school_outlined),
                  )
                : const Icon(Icons.school_outlined),
            selectedIcon: dueCount > 0
                ? Badge.count(
                    count: dueCount,
                    child: const Icon(Icons.school),
                  )
                : const Icon(Icons.school),
            label: 'Ôn tập',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Thống kê',
          ),
        ],
      ),
    );
  }
}
