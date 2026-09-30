import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketService({
    this.url = 'ws://localhost:8000/ws/live',
  });

  final String url;

  WebSocketChannel? _channel;

  Stream<dynamic>? get messages => _channel?.stream;

  void connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse(url),
    );
  }

  void listenForMessages(
    void Function(dynamic message) onMessage,
  ) {
    _channel?.stream.listen(
      onMessage,
      onError: (error) {
        print('WebSocket error: $error');
      },
      onDone: () {
        print('WebSocket connection closed');
      },
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}