# Cappuccino · Registro y metas

Aplicación nativa para iPhone con SwiftUI y SwiftData, compatible con **iOS 17 o posterior**. Guarda ingresos y bencina por turno y calcula cuánto necesitas generar para llegar a una meta. La interfaz usa café, crema y caramelo, tarjetas con material translúcido y colores claros para distinguir ganancias y gastos.

Este proyecto es independiente del analizador de ofertas anterior. Funciona con registros que tú ingresas; no necesita transmisión de pantalla ni acceso a Uber.

## Qué incluye

- Registro de fecha, ingreso bruto y gasto de bencina en pesos chilenos.
- Saldo neto inmediato: **ingreso − bencina**, incluyendo días con saldo negativo.
- Un registro por día: al seleccionar una fecha guardada se carga para editarla, y guardar actualiza ese día sin duplicarlo.
- Historial persistente con los siete días recientes, opción de mostrar todo y eliminación confirmada.
- Resumen del mes con ingresos, bencina y saldo neto acumulados.
- Meta con nombre, monto, fecha inicial, plazo de 1 a 12 meses y 1 a 7 días laborales por semana; el valor inicial es **5 días: miércoles a domingo**, con descanso lunes y martes.
- Presupuesto diario de bencina, ahorro diario requerido y bruto mínimo diario.
- Persistencia local de registros y meta con SwiftData, sin cuentas ni servidores.

La calculadora se actualiza mientras cambias los valores; **Guardar meta** conserva la meta activa, y un guardado posterior la actualiza. Solo hay una meta activa en esta versión.

El saldo mostrado descuenta únicamente la bencina registrada. No representa utilidad después de mantenimiento, impuestos, seguros u otros gastos. La meta es una planificación: la app no transfiere dinero ni confirma que hayas separado ese saldo como ahorro.

## Cálculos y calendario

Los importes se manejan como pesos enteros, sin decimales. Los campos aceptan separadores de miles y rechazan importes inválidos. Para no quedar por debajo de la meta, el ahorro diario requerido se redondea hacia arriba al peso siguiente.

El período comienza en la fecha seleccionada, incluida, y termina al cumplirse el número de meses, sin incluir ese último día. Se cuentan días reales del calendario. La semana laboral comienza el miércoles: con 1 día se cuenta el miércoles; con 2, miércoles y jueves; con 3, miércoles a viernes; con 4, miércoles a sábado; con **5, miércoles a domingo**; con 6, miércoles a lunes; con 7, todos los días. La configuración inicial deja **lunes y martes de descanso**. No se excluyen feriados. Así, un mes no se trata como si siempre tuviera exactamente cuatro semanas.

```text
Días laborales = días del calendario que cumplen el horario seleccionado
Ahorro requerido por día = redondear hacia arriba(monto objetivo / días laborales)
Bruto mínimo por día = ahorro requerido por día + bencina diaria estimada
```

El presupuesto de bencina de la meta es independiente del gasto real de cada turno. Por ejemplo, del 1 de febrero al 1 de marzo de 2026, sin incluir el 1 de marzo, hay **20 días de trabajo de miércoles a domingo**. Con una meta de $300.000 y $12.000 diarios de bencina, la planificación exige $15.000 de ahorro y $27.000 de ingreso bruto por día.

## Estructura

```text
CappuccinoSavings/
├── Sources/
│   ├── Models/
│   │   ├── DailyRecord.swift
│   │   └── SavingsGoal.swift
│   ├── DailyEntryView.swift
│   ├── GoalCalculatorView.swift
│   ├── ContentView.swift
│   ├── SavingsApp.swift
│   ├── Design/CappuccinoTheme.swift
│   └── Support/SavingsMath.swift
├── Tests/
│   ├── SavingsMathTests.swift
│   └── PersistenceTests.swift
├── Config/Info.plist
├── project.yml
└── .github/workflows/build-ios.yml
```

`SavingsApp` configura el contenedor de los dos modelos. Las vistas consultan y guardan con el contexto de SwiftData. Los cálculos y componentes de presentación se comparten para mantener las pantallas pequeñas. No hay dependencias de terceros en la app. XcodeGen genera el proyecto de Xcode a partir de `project.yml`; no se necesita editar un `.pbxproj` desde Windows.

## Compilar en la nube desde Windows

El flujo incluido usa GitHub Actions y un Mac remoto. **El iPhone no necesita estar conectado para compilar.** El resultado es una IPA **sin firma**, que Sideloadly o AltStore firmarán localmente antes de instalar. Descargar o copiar la IPA al teléfono por sí solo no la instala.

Los runners estándar de GitHub son gratuitos para repositorios públicos. Un repositorio privado consume la cuota y el almacenamiento del plan, y los excesos pueden cobrarse; consulta el uso y el presupuesto de tu cuenta antes de ejecutarlo. No se usan runners grandes. [Facturación oficial de GitHub Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

1. Crea un repositorio de GitHub con rama principal `main`.
2. Sube **el contenido de esta carpeta `CappuccinoSavings` a la raíz del repositorio**, incluyendo la carpeta oculta `.github`. En GitHub deben verse `project.yml`, `Sources`, `Tests` y `.github` al mismo nivel. Si la carpeta queda anidada, GitHub no descubrirá este workflow.
3. Revisa en `project.yml` el identificador `com.benja.cappuccinosavings`; puedes personalizarlo antes de la primera instalación. Después conviene mantenerlo para conservar los datos al actualizar.
4. Abre **Actions → Compilar Cappuccino para iPhone → Run workflow**. También se ejecuta al subir cambios a `main`.
5. El Mac instala XcodeGen, genera `SavingsApp.xcodeproj`, elige un simulador iPhone disponible y ejecuta las pruebas. Si pasan, archiva para un iPhone real con la firma desactivada y empaqueta `Payload/SavingsApp.app` en una IPA.
6. Cuando la ejecución termine en verde, abre **Artifacts → Cappuccino-unsigned-IPA**. Extrae el ZIP descargado: dentro está `Cappuccino-unsigned.ipa`.
7. Los resultados de XCTest se publican por separado. Los archivos permanecen disponibles durante 7 días; vuelve a ejecutar el workflow si necesitas regenerarlos.

Este proceso no necesita certificados, claves, contraseña de Apple ni cuenta de pago dentro de GitHub. Nunca subas credenciales ni datos financieros al repositorio. Si una prueba o la compilación fallan, la ejecución se detiene; no se publica una IPA nueva como si hubiera pasado la validación.

## Instalar en tu iPhone con Sideloadly

Esta app no usa capacidades que requieran una membresía Apple Developer de pago. Sideloadly admite un Apple ID gratuito; la firma dura **7 días** y la cuenta gratuita permite hasta **3 apps instaladas mediante sideloading**. Hay que renovar la firma para seguir abriendo la app. [Condiciones y renovación de Sideloadly](https://sideloadly.io/faq).

1. Descarga Sideloadly únicamente desde [su sitio oficial](https://sideloadly.io/). Sigue sus enlaces de **iTunes e iCloud para Windows en versión web**: la herramienta los requiere en vez de las versiones de Microsoft Store. Reinicia si los instaladores lo piden.
2. Usa un **cable USB-C que transmita datos**, conecta directamente al PC, desbloquea el iPhone y acepta **Confiar en esta computadora**. Comprueba que iTunes reconoce el teléfono antes de abrir Sideloadly.
3. Abre Sideloadly, selecciona tu iPhone, arrastra `Cappuccino-unsigned.ipa` y escribe tu Apple ID. Pulsa **Start** y completa la autenticación que solicite la herramienta. La firma se obtiene en tu PC; no compartas la contraseña en GitHub ni en el chat.
4. En el iPhone, ve a **Ajustes → General → VPN y gestión de dispositivos** y confía en el perfil asociado a tu Apple ID si aparece.
5. Activa **Ajustes → Privacidad y seguridad → Modo de desarrollador**, reinicia y confirma la activación. La opción puede aparecer después de iniciar el emparejamiento o la instalación. [Instrucciones de Apple para Modo de desarrollador](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
6. Abre **Cappuccino**. Guarda un turno de prueba, cierra la app y vuelve a abrirla para comprobar la persistencia.
7. Antes del vencimiento, renueva con Sideloadly usando **el mismo Apple ID y el mismo identificador de aplicación**. Instala encima de la anterior; **no borres la app para renovarla**, porque la base de datos es local. Puedes configurar la renovación automática con el PC y el iPhone disponibles. [Actualización y conservación de datos](https://sideloadly.io/faq).

Si el iPhone no aparece en iTunes o Sideloadly, primero hay que resolver el cable, puerto, controladores o la confianza. Compilar en la nube no corrige esa conexión. Prueba otro cable de datos, otro puerto USB-A/USB-C o el puerto de otro PC. La conexión Wi-Fi de Sideloadly necesita un emparejamiento USB inicial. [Conexión inalámbrica de Sideloadly](https://sideloadly.io/faq).

## Alternativa: AltStore Classic en Windows

1. Sigue la [instalación oficial de AltStore Classic para Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows): instala las versiones compatibles de iTunes/iCloud enlazadas allí y después AltServer para Windows.
2. Conecta y desbloquea el iPhone, acepta la confianza y activa la sincronización por Wi-Fi en iTunes. Ejecuta AltServer, selecciona **Install AltStore → tu iPhone** e inicia sesión con tu Apple ID.
3. Confía en el perfil y activa Modo de desarrollador si iOS lo solicita.
4. Transfiere `Cappuccino-unsigned.ipa` a la app Archivos del iPhone. Con AltServer accesible en el PC, abre **AltStore → My Apps → +**, selecciona la IPA e inicia la instalación.
5. Renueva desde **My Apps → Refresh All** antes de los 7 días, con AltServer disponible y el teléfono comunicado con el PC. AltStore ocupa uno de los tres espacios para apps gratuitas. [Caducidad y límite de apps de AltStore](https://faq.altstore.io/altstore-classic/your-altstore).

Usa **AltStore Classic**, que admite IPAs propias y AltServer. Su versión 2.3 requiere iOS 17.4 o posterior; para un iPhone con iOS 17.0–17.3 puedes usar Sideloadly. [Versiones oficiales de AltStore](https://faq.altstore.io/release-notes/altstore). La instalación mediante el marketplace AltStore PAL es otro proceso y no sustituye estos pasos.

## Si tienes acceso a un Mac

Instala Xcode 15 o posterior y XcodeGen; desde esta carpeta ejecuta:

```bash
brew install xcodegen
xcodegen generate --spec project.yml
open SavingsApp.xcodeproj
```

Selecciona el esquema `SavingsApp` y un simulador iPhone con iOS 17 o posterior. Ejecuta con **Run** y verifica con **Product → Test**. Para instalar directamente en un teléfono desde Xcode, selecciona tu equipo personal en **Signing & Capabilities** y un identificador disponible. El workflow ya contiene los comandos completos de pruebas y archivo sin firma.

## Validación y datos

El código incluye pruebas de cálculos, validación de importes, comportamiento de los modelos y persistencia SwiftData en memoria. **La compilación y las pruebas XCTest no se han ejecutado desde Windows**, donde no hay SDK de iOS ni Xcode. El workflow realiza esa validación en macOS antes de producir la IPA. La instalación real, la persistencia entre aperturas, el teclado, los tamaños de letra y la apariencia de los materiales deben revisarse en tu iPhone.

Los datos se guardan en el contenedor local de la app. No hay sincronización ni respaldo externo integrado. Eliminar la app elimina sus registros; cambiar la identidad utilizada al firmar puede crear una instalación diferente. Conserva la identidad y tu respaldo del iPhone al actualizar.
