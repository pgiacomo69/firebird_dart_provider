import 'package:fb_connector/fb_connector.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    final fbProvider = FbProvider();

    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () {
      expect(fbProvider !=null, isTrue);
    });
  });
}
