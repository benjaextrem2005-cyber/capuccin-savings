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

## Validación y datos

El código incluye pruebas de cálculos, validación de importes, comportamiento de los modelos y persistencia SwiftData en memoria. **La compilación y las pruebas XCTest no se han ejecutado desde Windows**, donde no hay SDK de iOS ni Xcode. El workflow realiza esa validación en macOS antes de producir la IPA. La instalación real, la persistencia entre aperturas, el teclado, los tamaños de letra y la apariencia de los materiales deben revisarse en tu iPhone.

Los datos se guardan en el contenedor local de la app. No hay sincronización ni respaldo externo integrado. Eliminar la app elimina sus registros; cambiar la identidad utilizada al firmar puede crear una instalación diferente. Conserva la identidad y tu respaldo del iPhone al actualizar.

## 🚀 Cómo compilar e instalar en tu iPhone desde Windows

1. **Subir el código a GitHub:** Al hacer `git push`, la GitHub Action (`build-ios.yml`) compilará el proyecto en la nube y te generará el archivo `.ipa` en la pestaña **Actions**.
2. **Descargar el .ipa:** Descarga el archivo de los *Artifacts* de GitHub a tu PC.
3. **Instalar con Sideloadly:**
   - Conecta tu iPhone por cable USB-C a la PC.
   - Abre **Sideloadly**, arrastra el archivo `.ipa`, pon tu Apple ID y dale a **Start**.
   - En tu iPhone ve a `Ajustes > General > VPN y gestión de dispositivos` y autoriza tu perfil.
