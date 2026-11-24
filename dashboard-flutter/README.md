# Dashboard IoT · Equipo 01 (Flutter + EMQX)

Dashboard de escritorio (Windows / Linux / macOS) que se conecta **directo al broker EMQX**
por MQTT sobre TLS (puerto 8883) y muestra los sensores y actuadores del invernadero.
Diseño inspirado en la imagen de referencia: tarjetas blancas, acento rojo coral y barra lateral.

## Cómo correrlo

Necesitas Flutter 3.27 o superior con soporte de escritorio (`flutter doctor`).

```bash
cd dashboard-flutter
flutter create --platforms=windows,linux,macos .   # genera las carpetas de plataforma (solo la 1ª vez)
flutter pub get
flutter run -d windows        # o: -d linux  /  -d macos
```

`flutter create .` no sobrescribe `lib/` ni `pubspec.yaml`; solo añade lo que falta.

**macOS:** añade esta clave en `macos/Runner/DebugProfile.entitlements` y `Release.entitlements`
para permitir conexiones de red salientes:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

## Primer arranque

1. En EMQX (*Access Control → Authentication*) crea un usuario **solo para el dashboard**
   (por ejemplo `dashboard`). Así no reutilizas las credenciales de los ESP32.
2. Al abrir la app aparece el diálogo de conexión. El host, el puerto y el tópico ya vienen
   rellenos (`ob1cb7cb.ala.us-east-1.emqxsl.com`, `8883`, `equipo01/sensores/datos`).
   Escribe el usuario y la contraseña y pulsa **Guardar y conectar**.
3. Se guardan en las preferencias locales del equipo (texto plano; no van en el código).
   Puedes cambiarlos desde el botón de ajustes o la tarjeta punteada de la barra lateral.

Si algo falla, el banner rojo bajo el título muestra el motivo (credenciales rechazadas,
fallo TLS, host inalcanzable…).

## Qué muestra

| Zona | Contenido |
|---|---|
| Panel principal | Gráfico en vivo de temperatura / humedad / luz, mín-máx, % de lecturas dentro del umbral y últimas alertas |
| Sensores | S1 humedad (DHT22), S2 temperatura (NTC), S3 luz (LDR) con su estado |
| Bomba de riego | Anillo con el riego en curso y contador de riegos |
| Toldo | Panel animado de 0° a 90° |
| Tendencia | Últimas 12 lecturas, promedio y botón para copiar el CSV |
| Ventilador | % de velocidad y curva de las últimas lecturas |
| Registro MQTT | Mensajes recibidos como chat + cuadro para publicar una lectura de prueba |
| Historial / Alertas | Tabla completa de lecturas y lista de eventos |

## Importante: el estado de los actuadores es estimado

El firmware de actuadores **no publica su estado**, solo se suscribe a `equipo01/sensores/datos`.
Por eso el dashboard aplica las mismas reglas que el `sketch.ino` (ver `lib/models.dart`, clase `Rules`):

- **Bomba:** humedad < 50 % → riega 3 s, como máximo una vez cada 13 s.
- **Ventilador:** velocidad lineal entre 25 °C y 75 °C (`map` de enteros, igual que Arduino).
- **Toldo:** luz > 60 % → 90° (abierto); si no, 0°.

Si cambias esos umbrales en el firmware, cámbialos también en `Rules`. Si quieres ver el
estado *real*, haz que el ESP32 de actuadores publique en un tópico (p. ej. `equipo01/actuadores/estado`)
y suscribe el dashboard a él.

## Publicar una lectura de prueba

El cuadro de la tarjeta "Registro MQTT" publica en el tópico de sensores (valida el formato antes).
Esa lectura también la reciben los ESP32 de actuadores, así que moverá la bomba, el ventilador y
el toldo reales/simulados. El usuario del dashboard necesita permiso de *publish* en ese tópico;
si solo quieres monitorear, déjalo en *subscribe*.

## Estructura

```
lib/
  main.dart                  arranque
  shell.dart                 marco, barra superior, navegación
  models.dart                formato S1/S2/S3, reglas de actuadores, ajustes
  mqtt_service.dart          conexión MQTT + TLS (usa assets/certs)
  dashboard_controller.dart  estado, historial, eventos, lógica de actuadores
  pages/pages.dart           Dashboard, Historial, Alertas
  widgets/                   tarjetas, gráficos (CustomPainter) y barra lateral
test/widget_test.dart        pruebas del parser y del mapeo del ventilador
```

## Notas técnicas

- En escritorio se usa el socket TCP nativo, por eso no se necesita WebSocket ni `wss`.
- `assets/certs/digicert_global_root_g2.pem` es la misma CA raíz que usan tus ESP32
  (se añade a las CA del sistema).
- Los gráficos están dibujados con `CustomPainter`, sin librerías de gráficas.
- La fuente (Manrope) la descarga `google_fonts` la primera vez; sin internet usa la fuente por defecto.
