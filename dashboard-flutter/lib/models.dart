import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

enum LinkState { disconnected, connecting, connected, reconnecting, error }

enum EventLevel { info, ok, warn, error }

enum LogDir { incoming, outgoing, system }

enum AppPage { dashboard, historial, alertas }

enum StatKind { recibidos, rechazados, reconexiones }

String two(int n) => n.toString().padLeft(2, '0');

String hms(DateTime t) => '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';

/// Reglas copiadas tal cual del firmware de los actuadores
/// (actuadores_MQTT/sketch.ino). Como los actuadores no publican su estado,
/// el dashboard recalcula con estas reglas qué estarían haciendo.
class Rules {
  Rules._();

  static const double humedadMin = 0;
  static const double humedadMax = 100;
  static const double tempMin = -40;
  static const double tempMax = 125;
  static const double luzMin = 0;
  static const double luzMax = 100;

  static const double humedadRiego = 50; // riega si baja de este %
  static const Duration cicloRiego = Duration(seconds: 13);
  static const Duration duracionRiego = Duration(seconds: 3);

  static const int tempVentMin = 25; // °C donde empieza el ventilador
  static const int tempVentMax = 75; // °C donde va al máximo
  static const int velocidadMaxima = 1000;

  static const double luzToldo = 60; // abre el toldo si la luz pasa de este %
  static const int toldoAbierto = 90;
  static const int toldoCerrado = 0;

  /// Sensores publican cada 4 s; pasado este tiempo se marcan como "sin datos".
  static const Duration datosVencidos = Duration(seconds: 15);

  /// Equivalente a `map(temperatura, 25, 75, 0, 1000)` + `constrain` de Arduino
  /// (map trabaja con enteros, por eso se trunca la temperatura).
  static int pasosVentilador(double temperatura) {
    final t = temperatura.truncate();
    final v = ((t - tempVentMin) * velocidadMaxima) ~/ (tempVentMax - tempVentMin);
    return math.max(0, math.min(velocidadMaxima, v));
  }
}

/// Lectura de los tres sensores: S1 = humedad (%), S2 = temperatura (°C), S3 = luz (%).
class SensorSample {
  const SensorSample({
    required this.time,
    required this.humedad,
    required this.temperatura,
    required this.luz,
  });

  final DateTime time;
  final double humedad;
  final double temperatura;
  final double luz;

  /// Formato publicado por el ESP32: `S1=55.200;S2=26.400;S3=72.000`.
  /// Aplica las mismas validaciones que el firmware de los actuadores.
  factory SensorSample.parse(String raw, DateTime time) {
    final text = raw.trim();
    if (text.isEmpty || text.length >= 100) {
      throw const FormatException('tamaño inválido');
    }
    final values = <String, double>{};
    for (final part in text.split(';')) {
      final kv = part.split('=');
      if (kv.length != 2) {
        throw const FormatException('formato malformado (usa S1=..;S2=..;S3=..)');
      }
      final key = kv[0].trim();
      final v = double.tryParse(kv[1].trim());
      if (v == null || !v.isFinite) {
        throw FormatException('valor inválido en $key');
      }
      values[key] = v;
    }
    final h = values['S1'];
    final t = values['S2'];
    final l = values['S3'];
    if (values.length != 3 || h == null || t == null || l == null) {
      throw const FormatException('deben venir exactamente S1, S2 y S3');
    }
    if (h < Rules.humedadMin ||
        h > Rules.humedadMax ||
        t < Rules.tempMin ||
        t > Rules.tempMax ||
        l < Rules.luzMin ||
        l > Rules.luzMax) {
      throw const FormatException('valores fuera de rango');
    }
    return SensorSample(time: time, humedad: h, temperatura: t, luz: l);
  }
}

/// Variable seleccionable en el gráfico principal y en la tendencia.
enum ChartVar {
  temperatura('Temperatura', '°C', 6.0, null, null),
  humedad('Humedad', '%', 20.0, 0.0, 100.0),
  luz('Luz', '%', 20.0, 0.0, 100.0);

  const ChartVar(this.label, this.unit, this.minSpan, this.hardMin, this.hardMax);

  final String label;
  final String unit;
  final double minSpan;
  final double? hardMin;
  final double? hardMax;

  double of(SensorSample s) => switch (this) {
        ChartVar.temperatura => s.temperatura,
        ChartVar.humedad => s.humedad,
        ChartVar.luz => s.luz,
      };

  /// ¿La lectura está dentro del umbral en el que el actuador NO tiene que actuar?
  bool inThreshold(SensorSample s) => switch (this) {
        ChartVar.temperatura => s.temperatura <= Rules.tempVentMin,
        ChartVar.humedad => s.humedad >= Rules.humedadRiego,
        ChartVar.luz => s.luz <= Rules.luzToldo,
      };

  String get thresholdText => switch (this) {
        ChartVar.temperatura => 'sin ventilador (≤ ${Rules.tempVentMin} °C)',
        ChartVar.humedad => 'sin riego (≥ ${Rules.humedadRiego.toInt()} %)',
        ChartVar.luz => 'toldo cerrado (≤ ${Rules.luzToldo.toInt()} %)',
      };
}

class EventEntry {
  const EventEntry(this.time, this.level, this.title, [this.detail = '']);
  final DateTime time;
  final EventLevel level;
  final String title;
  final String detail;
}

class LogEntry {
  const LogEntry(this.time, this.dir, this.text);
  final DateTime time;
  final LogDir dir;
  final String text;
}

/// Ajustes del broker. Usuario y contraseña NO viajan en el código: se
/// piden en el primer arranque y se guardan en las preferencias locales.
class BrokerSettings {
  const BrokerSettings({
    required this.host,
    required this.port,
    required this.topic,
    required this.username,
    required this.password,
    required this.displayName,
  });

  final String host;
  final int port;
  final String topic;
  final String username;
  final String password;
  final String displayName;

  static const defaults = BrokerSettings(
    host: 'ob1cb7cb.ala.us-east-1.emqxsl.com',
    port: 8883,
    topic: 'equipo01/sensores/datos',
    username: '',
    password: '',
    displayName: 'Operador',
  );

  bool get hasCredentials => username.isNotEmpty;

  static BrokerSettings load(SharedPreferences p) => BrokerSettings(
        host: p.getString('host') ?? defaults.host,
        port: p.getInt('port') ?? defaults.port,
        topic: p.getString('topic') ?? defaults.topic,
        username: p.getString('username') ?? '',
        password: p.getString('password') ?? '',
        displayName: p.getString('displayName') ?? defaults.displayName,
      );

  Future<void> save(SharedPreferences p) async {
    await p.setString('host', host);
    await p.setInt('port', port);
    await p.setString('topic', topic);
    await p.setString('username', username);
    await p.setString('password', password);
    await p.setString('displayName', displayName);
  }
}
