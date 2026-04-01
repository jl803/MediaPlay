import 'package:flutter_test/flutter_test.dart';
import 'package:media_player/main.dart';

void main() {
  testWidgets('MediaPlay app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MediaPlayApp());

    expect(find.text('MediaPlay'), findsOneWidget);
    expect(find.text('No media files'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
  });
}
