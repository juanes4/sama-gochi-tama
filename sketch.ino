#include <ESP32Servo.h>
#include <AccelStepper.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <time.h>
#include "secrets.h"

//ACTUADORES
Servo toldo;
const int pinToldo = 18;

AccelStepper bomba(AccelStepper::FULL4WIRE, 26, 25, 27, 14);
AccelStepper ventilador(AccelStepper::FULL4WIRE, 22, 23, 21, 19);

const int VELOCIDAD_MAXIMA = 1000;
const unsigned long CICLO_RIEGO = 13000;    // ms entre riegos
const unsigned long DURACION_RIEGO = 3000;  // ms que dura el riego

const float HUMEDAD_RIEGO = 50;     // riega si la humedad baja de este %
const float TEMP_VENT_MIN = 25;     // °C donde empieza el ventilador
const float TEMP_VENT_MAX = 75;     // °C donde el ventilador va al máximo
const float LUZ_TOLDO = 60;         // abre el toldo si la luz pasa de este %
const int TOLDO_ABIERTO = 90;       // grados
const int TOLDO_CERRADO = 0;        // grados

// Límites de valores válidos (cualquier otro mensaje se rechaza)
const float HUMEDAD_MIN = 0;
const float HUMEDAD_MAX = 100;
const float TEMP_MIN = -40;
const float TEMP_MAX = 125;
const float LUZ_MIN = 0;
const float LUZ_MAX = 100;

unsigned long ultimoRiego = -CICLO_RIEGO;
int anguloToldo = TOLDO_CERRADO;

// Últimos valores válidos recibidos por MQTT.
// Los escribe la tarea de red y los lee loop(), por eso van protegidos con un candado.
portMUX_TYPE candado = portMUX_INITIALIZER_UNLOCKED;
volatile float sensorHumedad = 0;
volatile float sensorTemperatura = 0;
volatile float sensorLuz = 0;
volatile bool hayDatos = false;  // los actuadores no actúan hasta recibir un dato válido

// Estado real de los actuadores para el reporte MQTT.
// Lo escribe loop() y lo publica la tarea de red (mismo candado).
volatile bool estadoRegando = false;
volatile int estadoAngulo = TOLDO_CERRADO;
volatile int estadoObjetivo = 0;          // velocidad pedida al ventilador (pasos/s)
volatile long posBomba = 0;               // pasos acumulados de cada motor
volatile long posVentilador = 0;
volatile bool hayCambio = false;          // la bomba o el toldo cambiaron: reportar ya
volatile unsigned long momentoCambio = 0;

//RED / MQTT SEGURO (EMQX Cloud, TLS + usuario/contraseña)
const char* broker = "ob1cb7cb.ala.us-east-1.emqxsl.com";
const int mqttPort = 8883;  // MQTT sobre TLS
const char* topicDatos = "equipo01/sensores/datos";  // el mismo que publican los sensores
const char* topicEstado = "equipo01/actuadores/datos"; // aquí se reporta el estado real
const unsigned long INTERVALO_ESTADO = 2000;  // ms entre reportes periódicos
const unsigned long ESPERA_CAMBIO = 300;      // ms tras un cambio antes de reportar (para medir pasos reales)
const int TAM_JSON = 256;                     // bytes del JSON de estado

// Usuario, clave, WiFi y certificado CA están en secrets.h

WiFiClientSecure espClient;
PubSubClient client(espClient);

const char* CLIENTE_ID = "ESP32Equipo01-actuadores";

const int CANAL_WIFI = 6;                     // canal de Wokwi-GUEST
const unsigned long REINTENTO_WIFI = 10000;   // ms entre intentos de WiFi
const unsigned long REINTENTO_MQTT = 5000;    // ms entre intentos de MQTT
const int TIEMPO_SOCKET = 5;                  // s de timeout del socket MQTT
const int TIEMPO_HANDSHAKE = 10;              // s de timeout del handshake TLS
const int BUFFER_MQTT = 512;                  // bytes del buffer MQTT (tópico + JSON de estado)
const int TAM_MENSAJE = 100;                  // bytes máximos del mensaje aceptado
const int TAM_ERROR_TLS = 100;                // bytes para el texto del error TLS

// Tarea de red (corre aparte para no frenar los motores)
const int PILA_TAREA_RED = 10240;             // bytes de pila (TLS necesita bastante)
const int PRIORIDAD_TAREA_RED = 1;
const int NUCLEO_RED = 0;                     // los motores quedan en el núcleo 1 (loop)
const int PAUSA_TAREA_RED_MS = 10;            // ms entre vueltas de la tarea de red

// Hora por NTP: el ESP32 la necesita para validar las fechas del certificado
const char* SERVIDOR_NTP_1 = "pool.ntp.org";
const char* SERVIDOR_NTP_2 = "time.google.com";
const long ZONA_HORARIA_S = -5 * 3600;        // Colombia UTC-5
const long HORARIO_VERANO_S = 0;
const time_t HORA_MINIMA_VALIDA = 1700000000; // cualquier hora menor = aún sin sincronizar

unsigned long intentoWiFi = 0;
unsigned long intentoMQTT = 0;
bool horaConfigurada = false;

// ---------- Validación de mensajes ----------

// Formato esperado: "S1=<humedad>;S2=<temperatura>;S3=<luz>"
// S1 = humedad del DHT22, S2 = temperatura del NTC, S3 = luz de la fotoresistencia
void recibirMensaje(char* tema, byte* carga, unsigned int largo)
{
  if (strcmp(tema, topicDatos) != 0) {
    Serial.println("RECHAZADO: tema inesperado");
    return;
  }
  if (largo == 0 || largo >= TAM_MENSAJE) {
    Serial.println("RECHAZADO: tamano invalido");
    return;
  }

  char mensaje[TAM_MENSAJE];
  memcpy(mensaje, carga, largo);
  mensaje[largo] = '\0';
  if (strlen(mensaje) != largo) {
    Serial.println("RECHAZADO: caracteres nulos en el mensaje");
    return;
  }

  float h, t, l;
  int consumidos = 0;
  if (sscanf(mensaje, "S1=%f;S2=%f;S3=%f%n", &h, &t, &l, &consumidos) != 3
      || mensaje[consumidos] != '\0') {
    Serial.println("RECHAZADO: formato malformado");
    return;
  }

  if (!isfinite(h) || !isfinite(t) || !isfinite(l)
      || h < HUMEDAD_MIN || h > HUMEDAD_MAX
      || t < TEMP_MIN || t > TEMP_MAX
      || l < LUZ_MIN || l > LUZ_MAX) {
    Serial.println("RECHAZADO: valores fuera de rango");
    return;
  }

  portENTER_CRITICAL(&candado);
  sensorHumedad = h;
  sensorTemperatura = t;
  sensorLuz = l;
  hayDatos = true;
  portEXIT_CRITICAL(&candado);

  Serial.print("[MQTT] OK -> ");
  Serial.println(mensaje);
}

// ---------- Reporte de estado ----------

// Publica el JSON de estado cada 2 s, o poco después de que cambie la bomba o el toldo.
// Se llama SOLO desde la tarea de red (PubSubClient no se puede usar desde dos núcleos).
void publicarEstado()
{
  static unsigned long ultimoReporte = 0;
  static long antBomba = 0;
  static long antVentilador = 0;

  portENTER_CRITICAL(&candado);
  bool cambio = hayCambio;
  unsigned long desdeCambio = momentoCambio;
  bool regando = estadoRegando;
  int angulo = estadoAngulo;
  int objetivo = estadoObjetivo;
  long pB = posBomba;
  long pV = posVentilador;
  portEXIT_CRITICAL(&candado);

  unsigned long ahora = millis();
  bool cambioListo = cambio && ahora - desdeCambio >= ESPERA_CAMBIO;
  if (!cambioListo && ahora - ultimoReporte < INTERVALO_ESTADO) return;

  // Pasos dados de verdad desde el reporte anterior
  unsigned long dt = ahora - ultimoReporte;
  long pasosBomba = labs(pB - antBomba);
  long pasosVent = labs(pV - antVentilador);
  int pasosS = dt > 0 ? (int)(pasosVent * 1000 / dt) : 0;
  pasosS = constrain(pasosS, 0, VELOCIDAD_MAXIMA);
  int porcentaje = pasosS * 100 / VELOCIDAD_MAXIMA;

  char json[TAM_JSON];
  int n = snprintf(json, sizeof(json),
    "{\"ts\":%ld,\"bomba\":{\"activa\":%s,\"regando\":%s,\"pasos\":%ld},"
    "\"ventilador\":{\"activo\":%s,\"objetivo\":%d,\"pasos_s\":%d,\"porcentaje\":%d},"
    "\"toldo\":{\"angulo\":%d,\"estado\":\"%s\"}}",
    (long)time(nullptr),
    pasosBomba > 0 ? "true" : "false", regando ? "true" : "false", pasosBomba,
    pasosVent > 0 ? "true" : "false", objetivo, pasosS, porcentaje,
    angulo, angulo == TOLDO_ABIERTO ? "abierto" : "cerrado");
  if (n < 0 || n >= (int)sizeof(json)) return;

  bool ok = client.publish(topicEstado, json);
  Serial.print("[ESTADO] ");
  Serial.print(json);
  Serial.println(ok ? " | envio OK" : " | envio FALLO");

  ultimoReporte = ahora;
  antBomba = pB;
  antVentilador = pV;
  if (cambio) {
    portENTER_CRITICAL(&candado);
    hayCambio = false;
    portEXIT_CRITICAL(&candado);
  }
}

// ---------- Conexión ----------

void conectarWiFi()
{
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password, CANAL_WIFI);
  intentoWiFi = millis();
  Serial.println("Iniciando WiFi");
}

void conectarMQTT()
{
  // La conexión TLS valida el certificado del servidor con ROOT_CA
  if (client.connect(CLIENTE_ID, MQTT_USUARIO, MQTT_CLAVE)) {
    Serial.println("MQTT conectado (TLS + usuario)");
    client.subscribe(topicDatos);
  } else {
    Serial.print("Error MQTT: ");
    Serial.print(client.state());  // 4 = usuario/clave incorrectos, 5 = no autorizado
    char errorTLS[TAM_ERROR_TLS];
    if (espClient.lastError(errorTLS, sizeof(errorTLS)) != 0) {
      Serial.print(" | Error TLS: ");
      Serial.print(errorTLS);
    }
    Serial.println();
  }
}

void mantenerConexion()
{
  unsigned long ahora = millis();
  if (WiFi.status() != WL_CONNECTED) {
    if (ahora - intentoWiFi >= REINTENTO_WIFI) conectarWiFi();
    return;
  }

  if (!horaConfigurada) {
    configTime(ZONA_HORARIA_S, HORARIO_VERANO_S, SERVIDOR_NTP_1, SERVIDOR_NTP_2);
    horaConfigurada = true;
  }
  if (time(nullptr) < HORA_MINIMA_VALIDA) return;  // esperar hora válida

  if (!client.connected() && ahora - intentoMQTT >= REINTENTO_MQTT) {
    intentoMQTT = ahora;
    conectarMQTT();
  }
  if (client.connected()) {
    client.loop();
    publicarEstado();
  }
}

// Tarea de red: WiFi, TLS y MQTT en el núcleo 0
void tareaRed(void* parametro)
{
  conectarWiFi();
  for (;;) {
    mantenerConexion();
    vTaskDelay(pdMS_TO_TICKS(PAUSA_TAREA_RED_MS));
  }
}

// ---------- Programa principal ----------

void setup()
{
  Serial.begin(115200);
  toldo.attach(pinToldo);
  toldo.write(TOLDO_CERRADO);  // empieza cerrado

  bomba.setMaxSpeed(VELOCIDAD_MAXIMA);
  ventilador.setMaxSpeed(VELOCIDAD_MAXIMA);

  espClient.setCACert(ROOT_CA);               // valida el servidor (sin setInsecure)
  espClient.setHandshakeTimeout(TIEMPO_HANDSHAKE);
  client.setServer(broker, mqttPort);
  client.setCallback(recibirMensaje);
  client.setSocketTimeout(TIEMPO_SOCKET);
  client.setBufferSize(BUFFER_MQTT);

  xTaskCreatePinnedToCore(tareaRed, "red", PILA_TAREA_RED, NULL,
                          PRIORIDAD_TAREA_RED, NULL, NUCLEO_RED);
}

// loop() corre en el núcleo 1 y solo maneja los actuadores, así los motores no se frenan
void loop()
{
  // Copia de los últimos datos válidos
  portENTER_CRITICAL(&candado);
  bool datos = hayDatos;
  float humedad = sensorHumedad;
  float temperatura = sensorTemperatura;
  float luz = sensorLuz;
  portEXIT_CRITICAL(&candado);

  if (!datos) return;  // sin datos válidos no se activa nada

  unsigned long ahora = millis();

  // Bomba: riega si la humedad está por debajo del 50 %
  if (humedad < HUMEDAD_RIEGO && ahora - ultimoRiego >= CICLO_RIEGO)
  {
    ultimoRiego = ahora;
  }

  bool regando = ahora - ultimoRiego < DURACION_RIEGO;
  if (regando)
  {
    bomba.setSpeed(VELOCIDAD_MAXIMA);
    bomba.runSpeed();
  }

  // Ventilador: más rápido entre 25 °C y 75 °C
  int velocidadVentilador = map(temperatura, TEMP_VENT_MIN, TEMP_VENT_MAX, 0, VELOCIDAD_MAXIMA);
  velocidadVentilador = constrain(velocidadVentilador, 0, VELOCIDAD_MAXIMA);
  ventilador.setSpeed(velocidadVentilador);
  ventilador.runSpeed();

  // Toldo: abre si la luz pasa del 60 %
  int angulo = (luz > LUZ_TOLDO) ? TOLDO_ABIERTO : TOLDO_CERRADO;
  if (angulo != anguloToldo)  // solo mueve el servo cuando cambia
  {
    anguloToldo = angulo;
    toldo.write(angulo);
  }

  // Deja el estado real para que la tarea de red lo publique
  portENTER_CRITICAL(&candado);
  if (regando != estadoRegando || anguloToldo != estadoAngulo) {
    hayCambio = true;
    momentoCambio = ahora;
  }
  estadoRegando = regando;
  estadoAngulo = anguloToldo;
  estadoObjetivo = velocidadVentilador;
  posBomba = bomba.currentPosition();
  posVentilador = ventilador.currentPosition();
  portEXIT_CRITICAL(&candado);
}