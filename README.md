# Cappuccino · Registro y metas

Aplicación nativa para iPhone con SwiftUI y SwiftData, compatible con **iOS 17 o posterior**. La versión **1.1.0** registra ingresos, bencina, otros gastos y dinero apartado para tu meta. La interfaz usa café, crema y caramelo, tarjetas con material translúcido y colores claros para distinguir ganancias y gastos.

Este proyecto es independiente del analizador de ofertas anterior. Funciona con registros que tú ingresas; no necesita transmisión de pantalla ni acceso a Uber.

## Qué incluye

- Registro de fecha, ingreso bruto y gasto de bencina en pesos chilenos.
- Saldo neto inmediato: **ingreso − bencina − otros gastos registrados**, incluyendo días con saldo negativo.
- Un registro por día: al seleccionar una fecha guardada se carga para editarla, y guardar actualiza ese día sin duplicarlo.
- Historial persistente con los siete días recientes, opción de mostrar todo y eliminación confirmada.
- Resumen del mes con ingresos, bencina, otros gastos y saldo neto acumulados.
- Meta con nombre, monto, fecha inicial, plazo de 1 a 12 meses y 1 a 7 días laborales por semana; el valor inicial es **5 días: miércoles a domingo**, con descanso lunes y martes.
- Presupuesto diario de bencina, ahorro diario requerido y bruto mínimo diario.
- Registro «Aparté dinero» con fecha, historial, porcentaje alcanzado y saldo pendiente de la meta.
- Meta del turno recalculada con el ahorro pendiente y los días de trabajo que quedan; muestra cuánto ingreso bruto falta generar.
- Gastos de mantención, peajes, estacionamiento, reparaciones, seguro y otros, con fecha y eliminación confirmada.
- Resumen semanal de miércoles a martes, gráfico de ingresos y gastos y comparación con los mismos días transcurridos de la semana anterior.
- Persistencia local de registros, meta, aportes y gastos con SwiftData, sin cuentas ni servidores.

La calculadora se actualiza mientras cambias los valores; **Guardar meta** conserva la meta activa, y un guardado posterior la actualiza manteniendo sus aportes. Solo hay una meta activa en esta versión. Los aportes son registros manuales del dinero que realmente apartaste; puedes eliminarlos para corregir un error. No se deducen automáticamente de las ganancias ni se consideran un gasto adicional.

El saldo mostrado descuenta exclusivamente los gastos registrados. No incluye costos que no hayas ingresado. La app no transfiere dinero ni se conecta al banco. Los aportes se vinculan a la meta mediante su identificador, de forma independiente del resultado de cada turno.

## Cálculos y calendario

Los importes se manejan como pesos enteros, sin decimales. Los campos aceptan separadores de miles y rechazan importes inválidos. Para no quedar por debajo de la meta, el ahorro diario requerido se redondea hacia arriba al peso siguiente.

El período comienza en la fecha seleccionada, incluida, y termina al cumplirse el número de meses, sin incluir ese último día. Se cuentan días reales del calendario. La semana laboral comienza el miércoles: con 1 día se cuenta el miércoles; con 2, miércoles y jueves; con 3, miércoles a viernes; con 4, miércoles a sábado; con **5, miércoles a domingo**; con 6, miércoles a lunes; con 7, todos los días. La configuración inicial deja **lunes y martes de descanso**. No se excluyen feriados. Así, un mes no se trata como si siempre tuviera exactamente cuatro semanas.

```text
Días laborales = días del calendario que cumplen el horario seleccionado
Ahorro requerido por día = redondear hacia arriba(monto objetivo / días laborales)
Bruto mínimo por día = ahorro requerido por día + bencina diaria estimada
```

El presupuesto de bencina de la meta es independiente del gasto real de cada turno. Por ejemplo, del 1 de febrero al 1 de marzo de 2026, sin incluir el 1 de marzo, hay **20 días de trabajo de miércoles a domingo**. Con una meta de $300.000 y $12.000 diarios de bencina, la planificación exige $15.000 de ahorro y $27.000 de ingreso bruto por día.

La tarjeta de meta diaria usa las fechas restantes y el dinero apartado antes del turno actual para fijar su cuota. Apartar dinero durante ese mismo día actualiza el progreso y cuánto falta reservar, sin reducir dos veces la cuota del día. El bruto mínimo suma esa cuota, la bencina real del turno si ya existe un registro (o la estimada si falta) y los otros gastos registrados de esa fecha. El importe pendiente de generar descuenta el ingreso bruto registrado. Ganar lo necesario y apartarlo son dos acciones distintas.

En lunes y martes, con el horario predeterminado, la tarjeta muestra el siguiente turno programado. Una meta alcanzada se muestra como cumplida; una meta vencida con saldo pendiente pide ajustar el plazo. No se divide entre cero ni se cuentan aportes futuros. La semana financiera incluye miércoles a martes para reflejar también gastos registrados en días de descanso. Se comparan períodos de igual duración, y los días futuros no se presentan como resultados reales.

## Estructura

```text
CappuccinoSavings/
├── Sources/
│   ├── Models/
│   │   ├── DailyRecord.swift
│   │   ├── SavingsGoal.swift
│   │   ├── SavingsContribution.swift
│   │   └── VehicleExpense.swift
│   ├── DailyEntryView.swift
│   ├── GoalCalculatorView.swift
│   ├── ExpensesView.swift
│   ├── WeeklySummaryView.swift
│   ├── ContentView.swift
│   ├── SavingsApp.swift
│   ├── Design/CappuccinoTheme.swift
│   ├── Components/DailyTargetCard.swift
│   ├── Support/SavingsMath.swift
│   └── Support/FinanceMath.swift
├── Tests/
│   ├── SavingsMathTests.swift
│   ├── FinanceMathTests.swift
│   ├── PersistenceTests.swift
│   └── MigrationTests.swift
├── Config/Info.plist
├── project.yml
└── .github/workflows/build-ios.yml
```

`SavingsApp` configura el contenedor de los cuatro modelos. Las vistas consultan y guardan con el contexto de SwiftData. Los cálculos y componentes de presentación se comparten para mantener las pantallas pequeñas. Swift Charts dibuja el gráfico semanal. No hay dependencias de terceros en la app. XcodeGen genera el proyecto de Xcode a partir de `project.yml`; no se necesita editar un `.pbxproj` desde Windows.

## Validación y datos

El código incluye pruebas de cálculos, validación de importes, comportamiento de los modelos y persistencia SwiftData en memoria. **La compilación y las pruebas XCTest no se han ejecutado desde Windows**, donde no hay SDK de iOS ni Xcode. El workflow realiza esa validación en macOS antes de producir la IPA. La instalación real, la persistencia entre aperturas, el teclado, los tamaños de letra y la apariencia de los materiales deben revisarse en tu iPhone.

La prueba de migración crea en disco una base con los dos modelos de la versión 1.0 y la abre con los cuatro modelos de la 1.1 para comprobar que se conserven los registros y la meta. Para actualizar instala el nuevo IPA encima del anterior con el mismo Apple ID y bundle ID. La versión nueva no borra la base ni reemplaza errores de apertura por una base vacía.

Los datos se guardan en el contenedor local de la app. No hay sincronización ni respaldo externo integrado. Eliminar la app elimina sus registros; cambiar la identidad utilizada al firmar puede crear una instalación diferente. Conserva la identidad y tu respaldo del iPhone al actualizar.

## 🚀 Cómo compilar e instalar en tu iPhone desde Windows

1. **Subir el código a GitHub:** Al hacer `git push`, la GitHub Action (`build-ios.yml`) compilará el proyecto en la nube y te generará el archivo `.ipa` en la pestaña **Actions**.
2. **Descargar el .ipa:** Descarga el archivo de los *Artifacts* de GitHub a tu PC.
3. **Instalar con Sideloadly:**
   - Conecta tu iPhone por cable USB-C a la PC.
   - Abre **Sideloadly**, arrastra el archivo `.ipa`, pon tu Apple ID y dale a **Start**.
   - En tu iPhone ve a `Ajustes > General > VPN y gestión de dispositivos` y autoriza tu perfil.
