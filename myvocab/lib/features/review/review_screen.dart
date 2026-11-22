import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../domain/sm2.dart';
import '../../services/tts_service.dart';
import '../../services/widget_service.dart';
import '../../utils/tag_utils.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

enum ReviewDirection { enToVi, viToEn }

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<WordWithReview> _queue = [];
  final Set<int> _ratedWordIds = {};
  bool _isLoading = true;
  bool _isFlipped = false;
  bool _autoTts = true;
  ReviewDirection _direction = ReviewDirection.enToVi;
  int _initialDueCount = 0;
  int _reviewedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDueWords();
  }

  Future<void> _loadDueWords() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseProvider);
    final dueWords = await db.getDueWords();

    if (!mounted) return;

    setState(() {
      _queue = List.from(dueWords);
      _initialDueCount = dueWords.length;
      _reviewedCount = 0;
      _ratedWordIds.clear();
      _isFlipped = false;
      _isLoading = false;
    });

    _playTtsIfEnabled();
  }

  void _playTtsIfEnabled() {
    if (_queue.isNotEmpty && _autoTts && _direction == ReviewDirection.enToVi) {
      ref.read(ttsServiceProvider).speak(_queue.first.word.word);
    }
  }

  Future<void> _rateWord(int grade) async {
    if (_queue.isEmpty) return;
    final currentItem = _queue.first;
    final wordId = currentItem.word.id;

    // First time rating this word in this session -> apply SM-2 calculation and log
    if (!_ratedWordIds.contains(wordId)) {
      final sm2Result = Sm2.calculate(
        interval: currentItem.review.interval,
        easeFactor: currentItem.review.easeFactor,
        repetitions: currentItem.review.repetitions,
        lapses: currentItem.review.lapses,
        grade: grade,
      );

      await ref.read(databaseProvider).updateReviewAndLog(
            wordId: wordId,
            grade: grade,
            sm2Result: sm2Result,
          );

      ref.read(widgetServiceProvider).updateWidget(ref.read(databaseProvider));

      _ratedWordIds.add(wordId);
      _reviewedCount++;
    }

    if (!mounted) return;

    setState(() {
      _queue.removeAt(0);
      if (grade == Sm2.gradeAgain) {
        // Re-append to the end of the session queue for same-session practice
        _queue.add(currentItem);
      }
      _isFlipped = false;
    });

    _playTtsIfEnabled();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ôn tập từ vựng'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.green.shade600,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Hết từ cần ôn hôm nay! 🎉',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _reviewedCount > 0
                      ? 'Bạn đã hoàn thành xuất sắc $_reviewedCount từ trong phiên này. Hãy giữ vững phong độ nhé!'
                      : 'Hiện tại bạn không có từ nào cần ôn tập. Hãy thêm từ mới hoặc quay lại vào ngày mai!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _loadDueWords,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Kiểm tra lại từ cần ôn'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentItem = _queue.first;
    final word = currentItem.word;
    final tagsList = TagUtils.toList(word.tags);
    final remainingCount = _queue.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ôn tập từ vựng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại danh sách',
            onPressed: _loadDueWords,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Controls & Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Còn lại: $remainingCount từ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      // Direction Toggle
                      SegmentedButton<ReviewDirection>(
                        segments: const [
                          ButtonSegment(
                            value: ReviewDirection.enToVi,
                            label: Text('Anh ➔ Việt'),
                          ),
                          ButtonSegment(
                            value: ReviewDirection.viToEn,
                            label: Text('Việt ➔ Anh'),
                          ),
                        ],
                        selected: {_direction},
                        onSelectionChanged: (set) {
                          setState(() {
                            _direction = set.first;
                            _isFlipped = false;
                          });
                          _playTtsIfEnabled();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Auto-TTS toggle
                      Row(
                        children: [
                          Icon(
                            _autoTts ? Icons.volume_up : Icons.volume_off,
                            size: 18,
                            color: _autoTts
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tự động phát âm',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Switch(
                            value: _autoTts,
                            onChanged: (val) {
                              setState(() => _autoTts = val);
                              if (val) _playTtsIfEnabled();
                            },
                          ),
                        ],
                      ),
                      if (_initialDueCount > 0)
                        Text(
                          'Tiến độ: $_reviewedCount/$_initialDueCount',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Flashcard
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isFlipped = !_isFlipped);
                    if (_isFlipped &&
                        _autoTts &&
                        _direction == ReviewDirection.viToEn) {
                      ref.read(ttsServiceProvider).speak(word.word);
                    }
                  },
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    color: _isFlipped
                        ? theme.colorScheme.surface
                        : theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Top info: POS & Tags
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (word.pos != null && word.pos!.isNotEmpty)
                                Chip(
                                  label: Text(
                                    word.pos!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                )
                              else
                                const SizedBox.shrink(),
                              IconButton(
                                icon: const Icon(Icons.volume_up, size: 28),
                                color: theme.colorScheme.primary,
                                tooltip: 'Phát âm tiếng Anh',
                                onPressed: () {
                                  ref
                                      .read(ttsServiceProvider)
                                      .speak(word.word);
                                },
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Front side
                          if (!_isFlipped) ...[
                            if (_direction == ReviewDirection.enToVi) ...[
                              Text(
                                word.word,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (word.phonetic != null &&
                                  word.phonetic!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  word.phonetic!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontStyle: FontStyle.italic,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ] else ...[
                              Text(
                                word.meaningVi,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 24),
                            Text(
                              '👆 Chạm vào thẻ để lật mặt sau',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ]
                          // Back side (Flipped)
                          else ...[
                            Text(
                              word.word,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (word.phonetic != null &&
                                word.phonetic!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                word.phonetic!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withAlpha(70),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                word.meaningVi,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (word.example != null &&
                                word.example!.trim().isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                'Ví dụ: "${word.example}"',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            if (word.notes != null &&
                                word.notes!.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Ghi chú: ${word.notes}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.outline,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            if (tagsList.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                alignment: WrapAlignment.center,
                                children: tagsList
                                    .map((t) => Chip(
                                          label: Text('#$t',
                                              style:
                                                  const TextStyle(fontSize: 11)),
                                          visualDensity: VisualDensity.compact,
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],

                          const Spacer(),

                          Text(
                            'Chạm để lật thẻ',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.outline.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Rating Buttons Bar (Quên = 1, Mơ hồ = 3, Nhớ = 4, Dễ = 5)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (!_isFlipped)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Bạn có thể lật thẻ hoặc đánh giá ngay:',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      // Quên (1)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _rateWord(Sm2.gradeAgain),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Quên',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text('(1)', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Mơ hồ (3)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _rateWord(Sm2.gradeHard),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Mơ hồ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text('(3)', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Nhớ (4)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _rateWord(Sm2.gradeGood),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Nhớ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text('(4)', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dễ (5)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _rateWord(Sm2.gradeEasy),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Dễ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text('(5)', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
