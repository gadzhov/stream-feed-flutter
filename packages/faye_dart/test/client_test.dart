import 'dart:async';
import 'dart:convert';

import 'package:faye_dart/src/client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MockWebSocketChannel extends Mock implements WebSocketChannel {}

class MockWebSocketSink extends Mock implements WebSocketSink {}

void main() {
  late StreamController<String> server;
  late List<Map<String, Object?>> sent;
  late FayeClient client;

  void reply(String channel, Map<String, Object?> fields) {
    final request = sent.lastWhere((message) => message['channel'] == channel);
    server.add(jsonEncode([
      {'channel': channel, 'id': request['id'], ...fields},
    ]));
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 10));

  setUp(() {
    server = StreamController<String>.broadcast();
    sent = [];
    final channel = MockWebSocketChannel();
    final sink = MockWebSocketSink();
    when(() => channel.stream).thenAnswer((_) => server.stream);
    when(() => channel.sink).thenReturn(sink);
    when(() => sink.add(any())).thenAnswer((invocation) {
      sent.add(jsonDecode(invocation.positionalArguments.first as String)
          as Map<String, Object?>);
    });
    when(() => sink.close(any())).thenAnswer((_) async {});
    client = FayeClient(
      'ws://faye.test',
      webSocketChannelProvider: (uri, {protocols}) => channel,
      logHandlerFunction: (_) {},
    );
  });

  tearDown(() => server.close());

  test(
      'a channel the server refuses after a new handshake is not an unhandled error',
      () async {
    final subscribed = client.subscribe('/feed');
    await settle();
    reply('/meta/handshake', {'successful': true, 'clientId': 'first'});
    await settle();
    reply('/meta/subscribe', {'successful': true, 'subscription': '/feed'});
    await subscribed;

    reply('/meta/connect', {
      'successful': false,
      'error': '401::Client not found, please reconnect.',
      'advice': {'reconnect': 'handshake', 'interval': 0},
    });
    await settle();
    reply('/meta/handshake', {'successful': true, 'clientId': 'second'});
    await settle();
    reply('/meta/subscribe', {
      'successful': false,
      'error': '401::Client not found, please reconnect.'
    });
    await settle();

    expect(sent.where((message) => message['channel'] == '/meta/subscribe'),
        hasLength(2));
  });
}
