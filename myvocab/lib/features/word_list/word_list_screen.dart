import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../services/tts_service.dart';
import '../../utils/tag_utils.dart';
import '../../widgets/reminder_dialog.dart';
import '../add_word/add_word_screen.dart';

// State holders for search & tag filter
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedTagFilterProvider = StateProvider<String?>((ref) => null);

// Reactive stream of words matching current query & tag filter
final filteredWordsStreamProvider = StreamProvider<List<Word>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = ref.watch(searchQueryProvider);
  final tag = ref.watch(selectedTagFilterProvider);

  return db.watchWords(
    searchQuery: query.trim().isNotEmpty ? query.trim() : null,
    tagFilter: tag,
  );
});

// Stream of all unique tags for filter chips
final allTagsStreamProvider = StreamProvider<List<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchWords().map((words) {
    final tagSet = <String>{};
    for (final w in words) {
      tagSet.addAll(TagUtils.toList(w.tags));
    }
    final sorted = tagSet.toList()..sort();
    return sorted;
  });
});

class WordListScreen extends ConsumerStatefulWidget {
  const WordListScreen({super.key});

  @override
  ConsumerState<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends ConsumerState<WordListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wordsAsync = ref.watch(filteredWordsStreamProvider);
    final allTagsAsync = ref.watch(allTagsStreamProvider);
    final currentTag = ref.watch(selectedTagFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MyVocab 📖',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm),
            tooltip: 'Cài đặt giờ nhắc nhở hàng ngày',
            onPressed: () {
              ReminderDialog.show(context, ref);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm từ vựng hoặc nghĩa tiếng Việt...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(searchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(searchQueryProvider.notifier).state = val;
                  },
                ),
                // Tag chips
                allTagsAsync.when(
                  data: (tags) {
                    if (tags.isEmpty) return const SizedBox.shrink();
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: const Text('Tất cả'),
                              selected: currentTag == null,
                              onSelected: (_) {
                                ref.read(selectedTagFilterProvider.notifier).state = null;
                              },
                            ),
                          ),
                          ...tags.map((tag) {
                            final isSelected = currentTag == tag;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text('#$tag'),
                                selected: isSelected,
                                onSelected: (sel) {
                                  ref.read(selectedTagFilterProvider.notifier).state =
                                      sel ? tag : null;
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (err, stack) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Word List Stream
          Expanded(
            child: wordsAsync.when(
              data: (words) {
                if (words.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_stories_outlined,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty || currentTag != null
                                ? 'Không tìm thấy từ vựng phù hợp.'
                                : 'Chưa có từ vựng nào trong kho từ.\nNhấn nút (+) bên dưới để thêm từ đầu tiên!',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: words.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemBuilder: (_, index) {
                    final word = words[index];
                    final tagsList = TagUtils.toList(word.tags);

                    return Dismissible(
                      key: ValueKey(word.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline, color: Colors.white, size: 28),
                            SizedBox(width: 6),
                            Text(
                              'Xóa',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Xác nhận xóa'),
                            content: Text(
                              'Bạn có chắc chắn muốn xóa từ "${word.word}" không?\n'
                              'Dữ liệu ôn tập liên quan cũng sẽ bị xóa vĩnh viễn.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Hủy'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Xóa'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (_) async {
                        await ref.read(databaseProvider).deleteWord(word.id);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('Đã xóa từ "${word.word}"')),
                          );
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddWordScreen(wordToEdit: word),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: Word + phonetic + pos + speaker
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8,
                                        children: [
                                          Text(
                                            word.word,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (word.phonetic != null &&
                                              word.phonetic!.isNotEmpty)
                                            Text(
                                              word.phonetic!,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontStyle: FontStyle.italic,
                                                color: theme.colorScheme.outline,
                                              ),
                                            ),
                                          if (word.pos != null && word.pos!.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primaryContainer,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                word.pos!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      theme.colorScheme.onPrimaryContainer,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.volume_up,
                                        color: theme.colorScheme.primary,
                                      ),
                                      tooltip: 'Phát âm',
                                      onPressed: () {
                                        ref
                                            .read(ttsServiceProvider)
                                            .speak(word.word);
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                // Vietnamese meaning
                                Text(
                                  word.meaningVi,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                // Example
                                if (word.example != null &&
                                    word.example!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Ví dụ: "${word.example}"',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],

                                // Notes
                                if (word.notes != null &&
                                    word.notes!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ghi chú: ${word.notes}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ],

                                // Tags
                                if (tagsList.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: tagsList.map((tag) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '#$tag',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('Lỗi tải dữ liệu: $err'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddWordScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm từ mới'),
      ),
    );
  }
}
