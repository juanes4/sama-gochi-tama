import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'models.dart';

/// Cliente MQTT sobre TLS (puerto 8883) para EMQX Cloud/Serverless.
/// En escritorio se usa el socket TCP nativo, no hace falta WebSocket.
class MqttService {
  MqttService({required this.onState, required this.onMessage});

  final void Function(LinkState state, String? detail) onState;
  final void Function(String payload) onMessage;

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _sub;
  SecurityContext? _context;
  int _attempt = 0; // descarta callbacks de clientes viejos
  bool _connectedOnce = false;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  /// Confía en las CA del sistema y, además, en la raíz DigiCert Global Root G2
  /// (la misma que usan los ESP32) incluida en assets/certs.
  Future<SecurityContext> _securityContext() async {
    final cached = _context;
    if (cached != null) return cached;
    final ctx = SecurityContext(withTrustedRoots: true);
    try {
      final pem = await rootBundle.load('assets/certs/digicert_global_root_g2.pem');
      ctx.setTrustedCertificatesBytes(
        pem.buffer.asUint8List(pem.offsetInBytes, pem.lengthInBytes),
      );
    } catch (_) {
      // Si falla, quedan las CA del sistema, que normalmente bastan.
    }
    _context = ctx;
    return ctx;
  }

  Future<void> connect(BrokerSettings s) async {
    await disconnect();
    final attempt = ++_attempt;
    _connectedOnce = false;
    onState(LinkState.connecting, null);

    final id = 'dashboard-flutter-${math.Random().nextInt(0xFFFFFF).toRadixString(16)}';
    final client = MqttServerClient.withPort(s.host, id, s.port, maxConnectionAttempts: 1)
      ..secure = true
      ..securityContext = await _securityContext()
      ..keepAlivePeriod = 30
      ..connectTimeoutPeriod = 8000
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..logging(on: false)
      ..onConnected = () {
        if (attempt != _attempt) return;
        _connectedOnce = true;
        onState(LinkState.connected, null);
      }
      ..onDisconnected = () {
        if (attempt != _attempt || !_connectedOnce) return;
        onState(LinkState.disconnected, 'Conexión perdida');
      }
      ..onAutoReconnect = () {
        if (attempt != _attempt) return;
        onState(LinkState.reconnecting, null);
      }
      ..onAutoReconnected = () {
        if (attempt != _attempt) return;
        onState(LinkState.connected, null);
      }
      ..connectionMessage = MqttConnectMessage()
          .withClientIdentifier(id)
          .authenticateAs(s.username, s.password)
          .startClean();
    _client = client;

    try {
      await client.connect();
    } catch (e) {
      _fail(attempt, client, _explain(e, client));
      return;
    }
    if (attempt != _attempt) return;
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      _fail(attempt, client, _explain(null, client));
      return;
    }

    _sub = client.updates!.listen(_handle);
    client.subscribe(s.topic, MqttQos.atMostOnce);
  }

  void _fail(int attempt, MqttServerClient client, String message) {
    if (attempt != _attempt) return;
    client.disconnect();
    _client = null;
    onState(LinkState.error, message);
  }

  String _explain(Object? e, MqttServerClient client) {
    final code = client.connectionStatus?.returnCode;
    if (code == MqttConnectReturnCode.badUsernameOrPassword ||
        code == MqttConnectReturnCode.notAuthorized) {
      return 'EMQX rechazó el usuario o la contraseña.';
    }
    if (e is TlsException) {
      return 'Falló el handshake TLS: ${e.message}';
    }
    if (e is SocketException) {
      return 'No se alcanza el broker (${e.message}). Revisa el host, el puerto y tu internet.';
    }
    return 'No se pudo conectar${e == null ? '' : ': $e'}';
  }

  void _handle(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final e in events) {
      final msg = e.payload;
      if (msg is! MqttPublishMessage) continue;
      onMessage(MqttPublishPayload.bytesToStringAsString(msg.payload.message));
    }
  }

  /// Publica en [topic]. Devuelve false si no hay conexión.
  bool publish(String topic, String text) {
    final client = _client;
    if (client == null || !isConnected) return false;
    final builder = MqttClientPayloadBuilder()..addString(text);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    return true;
  }

  Future<void> disconnect() async {
    _attempt++; // invalida los callbacks del cliente actual
    await _sub?.cancel();
    _sub = null;
    _client?.disconnect();
    _client = null;
  }
}
