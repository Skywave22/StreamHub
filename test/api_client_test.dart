import 'package:flutter_test/flutter_test.dart';
import 'package:streamhub/core/networking/api_client.dart';

import 'test_helpers.dart';

void main() {
  test('returns a successful response', () async {
    final adapter = FakeAdapter((o) async => textBody('hello'));
    final api = fakeApi(adapter);
    final resp = await api.get('https://example.com/x');
    expect(resp.isOk, isTrue);
    expect(resp.bodyString, 'hello');
  });

  test('retries on 5xx with backoff and then throws HttpException', () async {
    final adapter = FakeAdapter((o) async => jsonBody({'error': 'boom'}, 500));
    final api = fakeApi(adapter, maxRetries: 2);
    await expectLater(api.get('https://example.com/x'), throwsA(isA<HttpException>()));
    expect(adapter.callCount, 3); // initial + 2 retries
  });

  test('deduplicates identical concurrent requests', () async {
    final adapter = FakeAdapter((o) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return jsonBody({'ok': true});
    });
    final api = fakeApi(adapter);
    await Future.wait([api.get('https://example.com/x'), api.get('https://example.com/x')]);
    expect(adapter.callCount, 1);
  });

  test('does not retry client errors', () async {
    final adapter = FakeAdapter((o) async => jsonBody({'nope': true}, 401));
    final api = fakeApi(adapter, maxRetries: 2);
    await expectLater(api.get('https://example.com/x'), throwsA(isA<HttpException>()));
    expect(adapter.callCount, 1);
  });

  test('probe falls back to a ranged GET when HEAD is rejected', () async {
    final adapter = FakeAdapter((o) async {
      if (o.method == 'HEAD') return textBody('', 405);
      return textBody('x', 206);
    });
    final api = fakeApi(adapter);
    final result = await api.probe('https://example.com/video.mp4');
    expect(result.reachable, isTrue);
    expect(result.statusCode, 206);
  });
}
