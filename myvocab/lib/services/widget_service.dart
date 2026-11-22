import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../data/database.dart';

class WidgetService {
  static const String androidWidgetName = 'HomeWidgetProvider';

  Future<void> updateWidget(AppDatabase db) async {
    try {
      final word = await db.getWordForWidget();
      if (word != null) {
        await HomeWidget.saveWidgetData<String>('word', word.word);
        final meaning = word.pos != null && word.pos!.isNotEmpty
            ? '(${word.pos}) ${word.meaningVi}'
            : word.meaningVi;
        await HomeWidget.saveWidgetData<String>('meaning', meaning);
      } else {
        await HomeWidget.saveWidgetData<String>('word', 'MyVocab');
        await HomeWidget.saveWidgetData<String>(
          'meaning',
          'Chưa có từ vựng. Hãy thêm từ mới!',
        );
      }

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
      );
    } catch (_) {
      // Ignored in test / unsupported environments
    }
  }
}

final widgetServiceProvider = Provider<WidgetService>((ref) {
  return WidgetService();
});
