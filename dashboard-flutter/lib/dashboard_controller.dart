import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'mqtt_service.dart';

/// Estado de toda la app: conexión MQTT, lecturas, historial, eventos y el
/// estado "estimado" de los actuadores (bomba, ventilador y toldo).
class DashboardController extends ChangeNotifier {
  DashboardController(SharedPreferences prefs)
      : _prefs = prefs,
        settings = BrokerSettings.load(prefs) {
    _service = MqttService(onState: _onState, onMessage: _onMessage);
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  static const int maxHistory = 300;

  final SharedPreferences _prefs;
  late final MqttService _service;
  late final Timer _ticker;

  BrokerSettings settings;

  // ---- Conexión ----
  LinkState link = LinkState.disconnected;
  String? linkDetail;
  int received = 0;
  int rejected = 0;
  int reconnects = 0;
  bool paused = false;
  StatKind statKind = StatKind.recibidos;

  // ---- Datos ----
  final List<SensorSample> history = [];
  SensorSample? last;
  ChartVar chartVar = ChartVar.temperatura;
  bool stale = false;

  // ---- Actuadores (estimados con la lógica del firmware) ----
  bool pumpOn = false;
  double wateringProgress = 0; // 0..1 dentro del riego en curso
  Duration? nextWateringIn;
  int wateringCount = 0;
  double fanPercent = 0;
  int awningAngle = Rules.toldoCerrado;
  DateTime? _lastWatering;
  bool _fanWasOn = false;

  // ---- Registro y alertas ----
  final List<EventEntry> events = []; // más nuevo primero
  final List<LogEntry> log = []; // más viejo primero

  int get alertCount => events
      .where((e) => e.level == EventLevel.warn || e.level == EventLevel.error)
      .length;

  int get statValue => switch (statKind) {
        StatKind.recibidos => received,
        StatKind.rechazados => rejected,
        StatKind.reconexiones => reconnects,
      };

  // ------------------------------------------------------------------
  // Conexión
  // ------------------------------------------------------------------

  Future<void> connect() async {
    if (!settings.hasCredentials) {
      _onState(LinkState.error, 'Configura el usuario y la contraseña del broker.');
      return;
    }
    await _service.connect(settings);
  }

  Future<void> disconnect() => _service.disconnect();

  Future<void> applySettings(BrokerSettings s) async {
    settings = s;
    await s.save(_prefs);
    notifyListeners();
    await connect();
  }

  void _onState(LinkState state, String? detail) {
    final changed = state != link;
    link = state;
    linkDetail = detail;
    if (changed) {
      switch (state) {
        case LinkState.connecting:
          _system('Conectando a ${settings.host}:${settings.port}…');
        case LinkState.connected:
          _system('Conectado · suscrito a ${settings.topic}');
          _event(EventLevel.ok, 'Conectado a EMQX', settings.host);
        case LinkState.reconnecting:
          reconnects++;
          _system('Conexión perdida, reintentando…');
          _event(EventLevel.warn, 'Reconectando', 'Se perdió la conexión con el broker');
        case LinkState.disconnected:
          _system(detail ?? 'Desconectado');
        case LinkState.error:
          _system(detail ?? 'Error de conexión');
          _event(EventLevel.error, 'Error de conexión', detail ?? '');
      }
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Mensajes entrantes
  // ------------------------------------------------------------------

  void _onMessage(String payload) {
    if (paused) return;
    final now = DateTime.now();
    _addLog(LogEntry(now, LogDir.incoming, payload));
    try {
      final s = SensorSample.parse(payload, now);
      received++;
      last = s;
      history.add(s);
      if (history.length > maxHistory) history.removeAt(0);
      stale = false;
      _evaluate();
    } on FormatException catch (e) {
      rejected++;
      _event(EventLevel.warn, 'Mensaje rechazado', e.message);
    }
    notifyListeners();
  }

  /// Publica una lectura de prueba en el tópico de sensores.
  /// Devuelve un mensaje de error, o null si salió bien.
  String? publishRaw(String text) {
    try {
      SensorSample.parse(text, DateTime.now());
    } on FormatException catch (e) {
      return 'Formato inválido: ${e.message}';
    }
    if (!_service.publish(settings.topic, text.trim())) {
      return 'Sin conexión con el broker.';
    }
    _addLog(LogEntry(DateTime.now(), LogDir.outgoing, text.trim()));
    notifyListeners();
    return null;
  }

  // ------------------------------------------------------------------
  // Lógica de actuadores (misma que actuadores_MQTT/sketch.ino)
  // ------------------------------------------------------------------

  void _tick() {
    if (last == null) return;
    _evaluate();
    notifyListeners();
  }

  void _evaluate() {
    final s = last;
    if (s == null) return;
    final now = DateTime.now();

    // Bomba: riega 3 s si humedad < 50 %, como máximo una vez cada 13 s.
    final sinceWatering = _lastWatering == null ? null : now.difference(_lastWatering!);
    final due = sinceWatering == null || sinceWatering >= Rules.cicloRiego;
    if (s.humedad < Rules.humedadRiego && due) {
      _lastWatering = now;
      wateringCount++;
    }
    final elapsed = _lastWatering == null ? null : now.difference(_lastWatering!);
    final watering = elapsed != null && elapsed < Rules.duracionRiego;
    wateringProgress = (watering && elapsed != null)
        ? elapsed.inMilliseconds / Rules.duracionRiego.inMilliseconds
        : 0;
    nextWateringIn = (!watering && s.humedad < Rules.humedadRiego && elapsed != null)
        ? Rules.cicloRiego - elapsed
        : null;
    if (watering != pumpOn) {
      pumpOn = watering;
      _event(
        pumpOn ? EventLevel.warn : EventLevel.ok,
        pumpOn ? 'Bomba: riego iniciado' : 'Bomba: riego terminado',
        'Humedad ${s.humedad.toStringAsFixed(1)} % (umbral ${Rules.humedadRiego.toInt()} %)',
      );
    }

    // Ventilador: velocidad proporcional entre 25 °C y 75 °C.
    final pasos = Rules.pasosVentilador(s.temperatura);
    fanPercent = pasos * 100 / Rules.velocidadMaxima;
    final fanOn = pasos > 0;
    if (fanOn != _fanWasOn) {
      _fanWasOn = fanOn;
      _event(
        fanOn ? EventLevel.warn : EventLevel.ok,
        fanOn ? 'Ventilador encendido' : 'Ventilador apagado',
        'Temperatura ${s.temperatura.toStringAsFixed(1)} °C',
      );
    }

    // Toldo: se abre si la luz supera el 60 %.
    final angle = s.luz > Rules.luzToldo ? Rules.toldoAbierto : Rules.toldoCerrado;
    if (angle != awningAngle) {
      awningAngle = angle;
      _event(
        angle == Rules.toldoAbierto ? EventLevel.warn : EventLevel.ok,
        angle == Rules.toldoAbierto ? 'Toldo abierto' : 'Toldo cerrado',
        'Luz ${s.luz.toStringAsFixed(1)} % (umbral ${Rules.luzToldo.toInt()} %)',
      );
    }

    stale = now.difference(s.time) > Rules.datosVencidos;
  }

  // ------------------------------------------------------------------
  // Acciones de la interfaz
  // ------------------------------------------------------------------

  void selectVar(ChartVar v) {
    chartVar = v;
    notifyListeners();
  }

  void selectStat(StatKind k) {
    statKind = k;
    notifyListeners();
  }

  void togglePause() {
    paused = !paused;
    _system(paused ? 'Recepción en pausa' : 'Recepción reanudada');
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    last = null;
    stale = false;
    pumpOn = false;
    wateringProgress = 0;
    nextWateringIn = null;
    fanPercent = 0;
    awningAngle = Rules.toldoCerrado;
    _lastWatering = null;
    _fanWasOn = false;
    notifyListeners();
  }

  /// Porcentaje de las últimas [n] lecturas dentro del umbral de [v].
  double thresholdPercent(ChartVar v, {int n = 30}) {
    if (history.isEmpty) return 0;
    final recent = history.length > n ? history.sublist(history.length - n) : history;
    final ok = recent.where(v.inThreshold).length;
    return ok * 100 / recent.length;
  }

  String toCsv() {
    final b = StringBuffer('hora,humedad_pct,temperatura_c,luz_pct\n');
    for (final s in history) {
      b.writeln('${s.time.toIso8601String()},${s.humedad},${s.temperatura},${s.luz}');
    }
    return b.toString();
  }

  // ------------------------------------------------------------------
  // Utilidades internas
  // ------------------------------------------------------------------

  void _event(EventLevel level, String title, [String detail = '']) {
    events.insert(0, EventEntry(DateTime.now(), level, title, detail));
    if (events.length > 80) events.removeRange(80, events.length);
  }

  void _system(String text) => _addLog(LogEntry(DateTime.now(), LogDir.system, text));

  void _addLog(LogEntry e) {
    log.add(e);
    if (log.length > 120) log.removeRange(0, log.length - 120);
  }

  @override
  void dispose() {
    _ticker.cancel();
    _service.disconnect();
    super.dispose();
  }
}
