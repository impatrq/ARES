// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:ares_app/app_firebase.dart'; // O el nombre de tu archivo principal

void main() {
  testWidgets('Prueba de carga inicial de ARES', (WidgetTester tester) async {
    // Carga nuestra app de ARES
    await tester.pumpWidget(const AresApp());

    // Verifica que el título de la app esté en pantalla
    expect(find.text('ARES ECG'), findsOneWidget);
  });
}
