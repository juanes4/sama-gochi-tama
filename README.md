# Invernadero IoT · Equipo 01

Dashboards para monitorear el invernadero: leen los sensores y los actuadores que los ESP32
publican en el broker EMQX por MQTT.

| Tópico | Contenido |
|---|---|
| `equipo01/sensores/datos` | Lecturas de S1 humedad, S2 temperatura y S3 luz |
| `equipo01/actuadores/datos` | Estado real de la bomba, el ventilador y el toldo |

> **Entrega:** el entregable del proyecto es el **dashboard web** (`dashboard-web/`).
> El dashboard Flutter es una versión de escritorio adicional y no forma parte de la entrega.

## Estructura

```
.
├── dashboard-web/          ENTREGA · Dashboard en el navegador (HTML + CSS + JS, sin compilar)
│   ├── index.html
│   ├── css/styles.css
│   ├── js/app.js
│   └── vendor/mqtt.min.js  Copia local de MQTT.js por si falla el CDN
└── dashboard-flutter/      Extra, no se entrega · Dashboard de escritorio en Flutter (MQTT sobre TLS, 8883)
    ├── lib/
    ├── assets/certs/
    └── test/
```

## Dashboard web (entrega)

1. Abre `dashboard-web/index.html` con la extensión **Live Server** de VS Code
   (clic derecho › *Open with Live Server*), o con doble clic.
2. Pulsa el engranaje y escribe el usuario y la contraseña de EMQX.
   El puerto es el de WebSocket seguro (**8084**), no el 8883.
3. ¿No tienes broker? El botón ▶ de la barra lateral activa el modo demo con datos simulados.

## Dashboard Flutter (extra)

Las instrucciones están en [dashboard-flutter/README.md](dashboard-flutter/README.md).
