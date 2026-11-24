import 'package:flutter_test/flutter_test.dart';
import 'package:iot_dashboard/models.dart';

void main() {
  test('parsea el formato que publica el ESP32', () {
    final s = SensorSample.parse('S1=55.200;S2=26.400;S3=72.000', DateTime(2026));
    expect(s.humedad, 55.2);
    expect(s.temperatura, 26.4);
    expect(s.luz, 72.0);
  });

  test('rechaza mensajes malformados o fuera de rango (como el firmware)', () {
    expect(() => SensorSample.parse('hola', DateTime(2026)), throwsFormatException);
    expect(() => SensorSample.parse('S1=101;S2=20;S3=10', DateTime(2026)), throwsFormatException);
    expect(() => SensorSample.parse('S1=50;S2=20', DateTime(2026)), throwsFormatException);
    expect(() => SensorSample.parse('S1=a;S2=20;S3=10', DateTime(2026)), throwsFormatException);
  });

  test('el ventilador replica map()+constrain() del firmware', () {
    expect(Rules.pasosVentilador(20), 0);
    expect(Rules.pasosVentilador(25), 0);
    expect(Rules.pasosVentilador(50), 500);
    expect(Rules.pasosVentilador(75), 1000);
    expect(Rules.pasosVentilador(100), 1000);
  });
}
