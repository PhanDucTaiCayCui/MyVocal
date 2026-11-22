import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../services/dictionary_service.dart';
import '../../services/tts_service.dart';
import '../../services/widget_service.dart';
import '../../utils/tag_utils.dart';

class AddWordScreen extends ConsumerStatefulWidget {
  final Word? wordToEdit;
  final String? initialWordText;

  const AddWordScreen({
    super.key,
    this.wordToEdit,
    this.initialWordText,
  });

  @override
  ConsumerState<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends ConsumerState<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _wordController;
  late final TextEditingController _phoneticController;
  late final TextEditingController _posController;
  late final TextEditingController _meaningViController;
  late final TextEditingController _exampleController;
  late final TextEditingController _notesController;
  late final TextEditingController _tagsController;

  Timer? _debounceTimer;
  bool _isLoadingDictionary = false;
  String? _duplicateWarning;
  String? _dictionaryNotice;
  List<String> _englishDefinitions = [];

  bool get isEditMode => widget.wordToEdit != null;

  @override
  void initState() {
    super.initState();
    final w = widget.wordToEdit;
    final initialWord = widget.initialWordText ?? w?.word ?? '';
    _wordController = TextEditingController(text: initialWord);
    _phoneticController = TextEditingController(text: w?.phonetic ?? '');
    _posController = TextEditingController(text: w?.pos ?? '');
    _meaningViController = TextEditingController(text: w?.meaningVi ?? '');
    _exampleController = TextEditingController(text: w?.example ?? '');
    _notesController = TextEditingController(text: w?.notes ?? '');
    _tagsController = TextEditingController(
      text: TagUtils.formatForDisplay(w?.tags),
    );

    _wordController.addListener(_onWordChanged);

    if (widget.initialWordText != null &&
        widget.initialWordText!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkDuplicate();
        _lookupDictionary(auto: false);
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _wordController.removeListener(_onWordChanged);
    _wordController.dispose();
    _phoneticController.dispose();
    _posController.dispose();
    _meaningViController.dispose();
    _exampleController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _onWordChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _checkDuplicate();
      if (!isEditMode && _wordController.text.trim().isNotEmpty) {
        _lookupDictionary(auto: true);
      }
    });
  }

  Future<void> _checkDuplicate() async {
    final text = _wordController.text.trim();
    if (text.isEmpty) {
      if (mounted) setState(() => _duplicateWarning = null);
      return;
    }

    final db = ref.read(databaseProvider);
    final existing = await db.findWordByText(
      text,
      excludeId: widget.wordToEdit?.id,
    );

    if (mounted) {
      setState(() {
        if (existing != null) {
          _duplicateWarning = 'Từ "$text" đã tồn tại trong kho từ vựng!';
        } else {
          _duplicateWarning = null;
        }
      });
    }
  }

  Future<void> _lookupDictionary({bool auto = false}) async {
    final query = _wordController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoadingDictionary = true;
      _dictionaryNotice = null;
    });

    try {
      final service = ref.read(dictionaryServiceProvider);
      final result = await service.lookup(query);

      if (!mounted) return;

      if (result != null) {
        setState(() {
          if (_phoneticController.text.trim().isEmpty && result.phonetic != null) {
            _phoneticController.text = result.phonetic!;
          }
          if (_posController.text.trim().isEmpty && result.partOfSpeech != null) {
            _posController.text = result.partOfSpeech!;
          }
          if (_exampleController.text.trim().isEmpty && result.example != null) {
            _exampleController.text = result.example!;
          }
          _englishDefinitions = result.definitions;
          _dictionaryNotice = 'Đã tra từ thành công từ từ điển trực tuyến.';
        });
      } else {
        setState(() {
          _englishDefinitions = [];
          if (!auto) {
            _dictionaryNotice =
                'Không tìm thấy từ "$query" trong từ điển trực tuyến. Bạn có thể tự nhập dữ liệu bên dưới.';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _englishDefinitions = [];
          if (!auto) {
            _dictionaryNotice =
                'Không thể kết nối từ điển trực tuyến (ngoại tuyến). Bạn có thể tự nhập dữ liệu bên dưới.';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDictionary = false);
      }
    }
  }

  Future<void> _saveWord() async {
    if (!_formKey.currentState!.validate()) return;

    final wordText = _wordController.text.trim().toLowerCase();
    if (wordText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập từ tiếng Anh!')),
      );
      return;
    }

    // Check duplicate
    final db = ref.read(databaseProvider);
    final duplicate = await db.findWordByText(
      wordText,
      excludeId: widget.wordToEdit?.id,
    );

    if (duplicate != null) {
      if (mounted) {
        setState(() {
          _duplicateWarning = 'Từ "$wordText" đã tồn tại trong kho từ vựng!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu: Từ này đã tồn tại trong kho từ vựng!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final normalizedTags = TagUtils.normalize(_tagsController.text);
    final phonetic = _phoneticController.text.trim().isEmpty
        ? null
        : _phoneticController.text.trim();
    final pos = _posController.text.trim().isEmpty
        ? null
        : _posController.text.trim();
    final meaningVi = _meaningViController.text.trim();
    final example = _exampleController.text.trim().isEmpty
        ? null
        : _exampleController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    if (isEditMode) {
      final updated = widget.wordToEdit!.copyWith(
        word: wordText,
        phonetic: Value(phonetic),
        pos: Value(pos),
        meaningVi: meaningVi,
        example: Value(example),
        notes: Value(notes),
        tags: Value(normalizedTags),
      );
      await db.updateWord(updated);
      ref.read(widgetServiceProvider).updateWidget(db);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật từ vựng thành công!')),
        );
        Navigator.pop(context, true);
      }
    } else {
      final companion = WordsCompanion.insert(
        word: wordText,
        phonetic: Value(phonetic),
        pos: Value(pos),
        meaningVi: meaningVi,
        example: Value(example),
        notes: Value(notes),
        tags: Value(normalizedTags),
        createdAt: DateTime.now(),
      );

      await db.insertWordWithReview(wordCompanion: companion);
      ref.read(widgetServiceProvider).updateWidget(db);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm từ vựng mới thành công!')),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Chỉnh sửa từ vựng' : 'Thêm từ mới'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: isEditMode ? 'Cập nhật' : 'Lưu',
            onPressed: _duplicateWarning != null ? null : _saveWord,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Word Input Card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Từ tiếng Anh',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _wordController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'Nhập từ tiếng Anh (ví dụ: resilience)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.spellcheck),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_wordController.text.trim().isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.volume_up),
                                    tooltip: 'Nghe phát âm',
                                    onPressed: () {
                                      ref
                                          .read(ttsServiceProvider)
                                          .speak(_wordController.text.trim());
                                    },
                                  ),
                                if (_isLoadingDictionary)
                                  const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(Icons.search),
                                    tooltip: 'Tra từ điển trực tuyến',
                                    onPressed: () => _lookupDictionary(auto: false),
                                  ),
                              ],
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập từ tiếng Anh';
                            }
                            return null;
                          },
                        ),
                        if (_duplicateWarning != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _duplicateWarning!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_dictionaryNotice != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _dictionaryNotice!,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // English Definitions Preview (Temporary, not saved to DB)
                if (_englishDefinitions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: theme.colorScheme.primaryContainer.withAlpha(80),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Gợi ý nghĩa tiếng Anh (từ điển):',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._englishDefinitions.take(4).map(
                                (d) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Expanded(
                                        child: Text(
                                          d,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Phonetic & POS
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _phoneticController,
                          decoration: const InputDecoration(
                            labelText: 'Phiên âm (Phonetic)',
                            hintText: 'Ví dụ: /rɪˈzɪl.jəns/',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.record_voice_over),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _posController,
                          decoration: const InputDecoration(
                            labelText: 'Từ loại (Part of Speech)',
                            hintText: 'Ví dụ: noun, verb, adjective...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Meaning Vietnamese (Required)
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _meaningViController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Nghĩa tiếng Việt *',
                            hintText: 'Nhập nghĩa tiếng Việt (bắt buộc)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.translate),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập nghĩa tiếng Việt';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _exampleController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Câu ví dụ',
                            hintText: 'Ví dụ: She showed great resilience.',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.format_quote),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú cá nhân',
                            hintText: 'Mẹo nhớ, từ đồng nghĩa, ngữ cảnh...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.note_alt_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _tagsController,
                          decoration: const InputDecoration(
                            labelText: 'Thẻ phân loại (tags)',
                            hintText: 'Ví dụ: ielts, b2, giao tiếp (phân cách bằng dấu phẩy)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.label_outline),
                            helperText: 'Các thẻ sẽ được tự động chuẩn hóa dạng ,tag1,tag2,',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(isEditMode ? Icons.update : Icons.save),
                  label: Text(
                    isEditMode ? 'Cập nhật từ vựng' : 'Lưu vào kho từ vựng',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _duplicateWarning != null ? null : _saveWord,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
