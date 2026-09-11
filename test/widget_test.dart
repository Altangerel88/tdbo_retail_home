import 'package:flutter_test/flutter_test.dart';

import 'package:tdbo_retail_home/main.dart';

void main() {
  testWidgets('Retail home renders header, sections and nav', (tester) async {
    await tester.pumpWidget(const RetailApp());

    expect(find.text('Алтангэрэл'), findsOneWidget);
    expect(find.text('Сүүлийн гүйлгээ'), findsOneWidget);
    expect(find.text('Нүүр'), findsOneWidget);
  });
}
