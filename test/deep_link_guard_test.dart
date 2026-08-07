import 'package:flutter_test/flutter_test.dart';
import 'package:nastroi_app/utils/deep_link_guard.dart';

void main() {
  test('rejects a duplicate URI inside the deduplication window', () {
    final guard = DeepLinkGuard();
    final uri = Uri.parse('nastroi://person/example');
    final now = DateTime(2026);

    expect(guard.tryBegin(uri, now: now), isTrue);
    guard.finish();
    expect(
      guard.tryBegin(uri, now: now.add(const Duration(milliseconds: 500))),
      isFalse,
    );
    expect(
      guard.tryBegin(uri, now: now.add(const Duration(seconds: 3))),
      isTrue,
    );
  });

  test('rejects navigation while another link is opening', () {
    final guard = DeepLinkGuard();
    expect(guard.tryBegin(Uri.parse('nastroi://person/one')), isTrue);
    expect(guard.tryBegin(Uri.parse('nastroi://person/two')), isFalse);
  });
}
