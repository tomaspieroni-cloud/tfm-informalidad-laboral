# TFM: Informalidad laboral en Argentina ante shocks económicos

## Análisis de microdatos EPH 2022-2025 y simulación basada en agentes con calibración empírica

**Autor:** Tomás Nelio Pieroni  
**Programa:** Máster Universitario en Ciencia de Datos Aplicada a las Ciencias Sociales (DaSoc)  
**Universidades:** Universidad de Granada y Universidad de Salamanca  
**Curso:** 2025-2026  
**Fuente principal:** INDEC, Encuesta Permanente de Hogares (EPH)  
**Última actualización:** 4 de septiembre de 2026

\---

## 1\. Propósito del repositorio

Este repositorio contiene el flujo reproducible del TFM **“La informalidad laboral en Argentina ante shocks económicos: una simulación basada en agentes con calibración empírica (2022-2025)”**.

El proyecto integra:

1. procesamiento y auditoría de microdatos trimestrales de la EPH;
2. clasificación de formalidad laboral;
3. construcción y validación de un panel rotativo de corto plazo;
4. estimación de transiciones entre estados laborales;
5. identificación de perfiles de empleo informal mediante FAMD y K-means;
6. construcción del Índice de Vulnerabilidad Laboral Relativa (IVLR);
7. calibración de un modelo basado en agentes (ABM);
8. simulación de escenarios inflacionarios, devaluatorios e institucionales;
9. validación, análisis de sensibilidad y generación de figuras y tablas.

El README documenta decisiones técnicas y operativas que no se desarrollan por completo en la memoria. La interpretación académica de los resultados debe realizarse junto con el TFM.

### Distinciones centrales

* **Estado laboral:** empleo formal, empleo informal, desocupación o inactividad.
* **Perfil estructural:** tipo de inserción informal identificado mediante FAMD y K-means.
* **Vulnerabilidad laboral relativa:** atributo complementario medido mediante el IVLR.

El cluster y el IVLR no son estados laborales. Los clusters tampoco constituyen grupos naturales ni niveles ordenados de vulnerabilidad.

\---

## 2\. Alcance empírico

* **Período descriptivo:** 2022T1-2025T4, 16 trimestres.
* **Base consolidada:** 759.264 registros persona-trimestre y 240 variables, incluida `periodo`.
* **Cobertura:** población urbana de los 31 aglomerados relevados por la EPH.
* **Unidad general de análisis:** persona de 10 años y más.
* **Ventana de formalidad completa y clustering:** 2023T4-2025T4.
* **Ventana de origen para transiciones y calibración:** 2023T4-2025T3.
* **Diseño longitudinal:** enlaces de corto plazo compatibles con el panel rotativo 2-2 de la EPH.

La restricción desde 2023T4 responde a la disponibilidad de la clasificación oficial completa de formalidad para patrones y cuentapropistas. La reconstrucción retrospectiva de la formalidad independiente se evaluó, pero se descartó por correspondencia insuficiente con la medición oficial.

\---

## 3\. Estructura del proyecto

TFM/
├── Datos/
│   └── Bases EPH/
│       # Microdatos trimestrales originales del INDEC.
│       # Los archivos originales se conservan sin modificaciones.
│
├── Scripts/
│   # Procesamiento, auditoría, construcción del panel y
│   # estimación de transiciones en R.
│   ├── 00\_configurar\_proyecto.R
│   ├── 01\_procesar\_datos.R
│   ├── 02\_cargar\_datos.R
│   ├── 03\_graficos.R
│   ├── 04\_descriptivos\_exploratorios.R
│   ├── 05\_auditoria\_exploratoria\_dataset.R
│   ├── 06\_auditoria\_codigos\_independientes.R
│   ├── 07\_panel\_auditoria\_inicial.R
│   ├── 07B\_reentrevistas\_completas.R
│   ├── 07C\_tasas\_reentrevista.R
│   ├── 07D\_attrition\_diagnostico.R
│   ├── 07E\_panel\_analitico\_final.R
│   ├── 08A\_auditoria\_estados\_transicion.R
│   ├── 08B\_matrices\_transicion\_conteos.R
│   ├── 08C\_probabilidades\_y\_movilidad.R
│   ├── 08D\_base\_analitica\_clustering.R
│   └── 09\_reconstruir\_base\_clustering\_candidata\_final.R
│
├── Script Py/
│   # FAMD, clustering, IVLR, preparación de insumos,
│   # calibración del ABM y análisis de escenarios.
│   ├── 10\_Clustering\_matriz\_final.ipynb
│   ├── 11\_Perfiles\_empleo\_informal\_FAMD\_K\_means.ipynb
│   ├── 12\_auditoria\_variables\_vulnerabilidad.ipynb
│   ├── 13\_Componentes\_IVLR.ipynb
│   ├── 13B\_diagnostico\_enlace\_ivlr\_panel.py
│   ├── 14\_transiciones\_segun\_ivlr.ipynb
│   ├── 15\_calibracion\_transiciones\_abm.ipynb
│   ├── 16\_insumos\_adicionales\_abm.ipynb
│   ├── 17A\_preparar\_insumos\_netlogo.py
│   ├── 18\_auditoria\_universo\_abm.py
│   ├── 19\_construir\_insumo\_macroeconomico\_trimestral.py
│   ├── 20\_analizar\_escenarios\_abm.py
│   ├── 21\_analizar\_mecanismos\_emergentes.py
│   │
│   ├── figura\_01\_informalidad\_2022\_2025.py
│   ├── tabla\_01\_panel\_longitudinal.py
│   ├── figura\_02\_flujo\_base\_analitica.py
│   ├── figura\_03\_perfiles.py
│   ├── figura\_04\_heatmap\_perfiles.py
│   ├── tabla\_02\_perfiles\_empleo\_informal.py
│   ├── figura\_05\_distribucion\_ivlr.py
│   ├── figura\_07\_destino\_segun\_ivlr.py
│   ├── tabla\_03\_persistencia\_transiciones\_ivlr.py
│   ├── figura\_08\_composicion\_inicial\_abm.py
│   ├── tabla\_04\_parametros\_calibracion\_abm.py
│   ├── figura\_09\_escenarios\_inflacionarios.py
│   ├── figura\_10\_escenarios\_devaluatorios.py
│   ├── figura\_11\_escenarios\_institucionales.py
│   ├── figura\_12\_escenario\_combinado.py
│   │
│   └── Anexos/
│       # Generación de figuras y tablas complementarias.
│       ├── Anexo.ipynb
│       ├── Anexo\_anexo.ipynb
│       └── generar\_anexos\_tfm.py
│
├── NetLogo/
│   # Modelo basado en agentes y experimentos de simulación.
│   ├── 17\_ABM\_escenarios\_final\_tablero.nlogo
│   ├── 17\_ABM\_base\_con\_shocks.nls
│   └── Experimentos/
│       # Archivos exportados por BehaviorSpace.
│
├── Salidas/
│   # Resultados intermedios y finales de cada etapa analítica.
│   ├── 01\_auditoria/
│   ├── 02\_descriptivos/
│   ├── 03\_exploratorios/
│   ├── 04\_clasificacion\_formalidad/
│   ├── 05\_panel\_longitudinal/
│   ├── 06\_transiciones/
│   ├── 07\_clustering/
│   ├── 08\_vulnerabilidad/
│   ├── 09\_ivlr/
│   ├── 10\_ivlr\_transiciones/
│   ├── 11\_calibracion\_abm/
│   ├── 12\_insumos\_abm/
│   ├── 13\_abm\_base/
│   ├── 14\_escenarios\_macroeconomicos/
│   ├── 20\_reportes\_escenarios\_abm/
│   └── 21\_mecanismos\_emergentes/
│
├── resultados\_graficos/
│   # Figuras y tablas finales utilizadas en la memoria del TFM.
│   ├── 01\_base\_longitudinal/
│   ├── 02\_clustering/
│   ├── 03\_ivlr/
│   ├── 04\_abm/
│   ├── 05\_escenarios/
│   └── 06\_anexos/
│
├── Graficos/
│   # Carpeta adicional de productos gráficos.
│   # Se conserva únicamente si contiene archivos no duplicados.
│
├── TFM.Rproj
├── .Rprofile
├── renv.lock
└── README.md





## 4\. Requisitos de reproducción

### R

* R 4.2 o superior.
* RStudio recomendado.
* Dependencias fijadas mediante `renv.lock`.

### Python

* Python 3.11.
* Entorno Conda denominado `trabajo`.
* Jupyter o Visual Studio Code con el kernel `trabajo`.
* Los notebooks no instalan paquetes ni crean entornos.

### NetLogo

* NetLogo 7.0.3.
* BehaviorSpace para las ejecuciones finales.
* Exportación en modalidad **Table output**.

\---

## 5\. Secuencia de reproducción

### 5.1. Flujo completo desde los microdatos

1. Abrir `TFM.Rproj`.
2. Restaurar el entorno de R con `renv::restore()` si fuera necesario.
3. Ejecutar `Scripts/01\_procesar\_datos.R` para reconstruir la base consolidada.
4. Ejecutar `Scripts/02\_cargar\_datos.R` al iniciar una sesión de trabajo.
5. Ejecutar los scripts 03 a 06 para gráficos, descriptivos y auditorías.
6. Ejecutar los scripts 07 a 07E para construir y validar el panel.
7. Ejecutar los scripts 08A a 08D y el script 09 para estados, transiciones y base de clustering.
8. Activar el entorno Conda `trabajo`.
9. A continuación, ejecutar 17A\_preparar\_insumos\_netlogo.py y 18\_auditoria\_universo\_abm.py, y revisar los controles exportados en Salidas/13\_abm\_base/insumos\_netlogo/.
10. Verificar `Salidas/13\_abm\_base/insumos\_netlogo/`.
11. Ejecutar `19\_construir\_insumo\_macroeconomico\_trimestral.py`.
12. Abrir el modelo final en NetLogo 7.0.3.
13. Ejecutar los experimentos guardados en BehaviorSpace con las semillas 1 a 100.
14. Conservar los nombres de los archivos exportados en `NetLogo/Experimentos/`.
15. Ejecutar `20\_analizar\_escenarios\_abm.py`.
16. Ejecutar `21\_analizar\_mecanismos\_emergentes.py`.
17. Revisar los registros de validación antes de utilizar resultados o figuras.

### 5.2. Reproducción abreviada del ABM

Salidas/13\_abm\_base/insumos\_netlogo/
↓
NetLogo/17\_ABM\_escenarios\_final\_tablero.nlogo
↓
NetLogo/Experimentos/\*.csv
↓
Script Py/20\_analizar\_escenarios\_abm.py
↓
Salidas/20\_reportes\_escenarios\_abm/
↓
Script Py/21\_analizar\_mecanismos\_emergentes.py
↓
Salidas/21\_mecanismos\_emergentes/



## 6\. Datos, panel y estados laborales

### 6.1. Identificación y panel

Los enlaces individuales utilizan:

```text
CODUSU + NRO\_HOGAR + COMPONENTE
```

Los controles de consistencia comparan sexo y edad entre observaciones enlazadas.

* Panel bruto: 302.800 enlaces trimestrales.
* Panel consistente: 283.246 enlaces, 93,5 % del panel bruto.
* Ventana principal de transiciones: 2023T4-2025T4.
* Enlaces con estados válidos en esa ventana: 128.427.
* La comparación de attrition no mostró diferencias sustantivas en sexo, edad, estado laboral o formalidad entre personas reentrevistadas y no reentrevistadas.

El panel permite describir movilidad de corto plazo. No representa trayectorias longitudinales completas de toda la población.

### 6.2. Estados laborales

Se mantienen cuatro estados:

1. empleo formal;
2. empleo informal;
3. desocupación;
4. inactividad.

La categoría ocupacional, el cluster y el IVLR se conservan como atributos y no como estados adicionales.

### 6.3. Formalidad

* Para asalariados, `PP07H` permite extender la clasificación de formalidad a 2022T1-2025T4.
* Para patrones y cuentapropistas, la clasificación oficial completa se utiliza desde 2023T4.
* `EMPLEO` clasifica la formalidad de la ocupación principal.
* `SECTOR` caracteriza la unidad económica.
* La medición completa, el clustering y la calibración principal se restringen a 2023T4-2025T4.

\---

## 7\. Clustering de perfiles informales

### Especificación

* Universo: 80.300 observaciones persona-trimestre de empleo informal.
* Casos incluidos en FAMD y K-means: 79.751.
* Casos sin cluster por falta de `CAES`: 549, equivalentes al 0,68 %.
* Método: FAMD seguido de K-means.
* Variables activas: `CH04`, `CH06`, `NIVEL\_ED`, `CAT\_OCUP`, `CAES`, `TAM\_EST`, `INTENSI`.
* Variables externas: `REGION` y `log\_P21\_real`.
* Dimensiones FAMD calculadas: 15.
* Dimensiones retenidas: 7.
* Número de clusters: 5.
* Semilla: 42.
* Ponderadores: no activos en el ajuste; utilizados para descripción poblacional.
* Estabilidad: índice de Rand ajustado superior a 0,999 entre las inicializaciones evaluadas.

### Perfiles finales

1. Cuentapropismo predominantemente unipersonal.
2. Asalariados informales jóvenes vinculados al comercio.
3. Asalariados informales en establecimientos grandes.
4. Asalariados informales en hogares particulares.
5. Inserciones informales mixtas en pequeños establecimientos.

Los perfiles describen formas estructurales de inserción. No deben interpretarse como una escala de mejor a peor empleo.

\---

## 8\. Índice de Vulnerabilidad Laboral Relativa

### 8.1. Componentes

#### Ingreso

* `P21 = -9`: no respuesta; se trata como faltante.
* `P21 = 0`: ingreso nulo observado; no se recodifica como faltante.
* El ingreso real se transforma en percentil dentro de cada trimestre.
* `componente\_ingreso = 1 - percentil\_ingreso`.

#### Intensidad laboral

* subocupado: 1;
* ocupado pleno o sobreocupado: 0;
* no trabajó: faltante en la especificación principal.

#### Educación

La privación educativa se ajusta por edad:

* 10-17 años: no evaluable;
* 18-24 años: privación para primaria incompleta, primaria completa o sin instrucción;
* 25 años o más: privación para primaria incompleta, primaria completa, secundaria incompleta o sin instrucción.

### 8.2. Fórmulas

```text
IVLR básico = 0,70 × intensidad + 0,30 × educación
```

```text
IVLR ampliado = 0,45 × ingreso + 0,35 × intensidad + 0,20 × educación
```

La versión ampliada es la medida principal. La versión con pesos iguales se utiliza como sensibilidad.

* IVLR básico observado: 78.424 casos, 97,66 %.
* IVLR ampliado observado: 64.761 casos, 80,65 %.
* Correlación de Spearman entre el IVLR ampliado y la versión con pesos iguales: 0,958.
* Los pesos se fijaron antes de analizar las transiciones.
* No se redistribuyen pesos cuando falta un componente.
* Las transiciones en `t+1` no intervienen en la construcción del índice.

El IVLR mide vulnerabilidad relativa dentro del empleo informal. No es una medida general de pobreza, bienestar o exclusión social.

\---

## 9\. Transiciones y calibración del ABM

### 9.1. Evidencia observada desde el empleo informal

En los 27.891 enlaces válidos con origen informal:

|Destino en t+1|n|Porcentaje no ponderado|
|-|-:|-:|
|Empleo informal|20.193|72,40 %|
|Inactividad|3.507|12,57 %|
|Empleo formal|2.917|10,46 %|
|Desocupación|1.274|4,57 %|

Los cuartiles del IVLR ampliado se calculan dentro de cada trimestre de origen. En términos ponderados, Q1 presenta una formalización de 19,11 %, frente a 5,11 % en Q4; las salidas a desocupación son 3,46 % y 10,54 %, respectivamente, mientras que las salidas a inactividad son 6,33 % y 18,04 %.

Estas relaciones son descriptivas y prospectivas, no causales.

### 9.2. Jerarquía de probabilidades desde informalidad

1. regla específica `cluster × cuartil`;
2. respaldo general del cuartil cuando falta el cluster;
3. regla general desde informalidad cuando falta el IVLR ampliado.

La tabla operativa contiene 24 celdas: 20 combinaciones directas de cinco clusters por cuatro cuartiles y cuatro respaldos para observaciones sin cluster.

### 9.3. Otros estados de origen

|Origen|n|P(formal)|P(informal)|P(desocupación)|P(inactividad)|
|-|-:|-:|-:|-:|-:|
|Desocupación|4.099|0,0863|0,2985|0,3105|0,3046|
|Empleo formal|35.658|0,8689|0,0919|0,0142|0,0250|
|Inactividad|60.779|0,0166|0,0657|0,0274|0,8904|

### 9.4. Nuevos informales

Los agentes que ingresan a la informalidad reciben un cluster y un cuartil según distribuciones empíricas específicas para su estado de origen. Estas distribuciones se estiman sobre casos con IVLR ampliado observado, equivalentes al 78,21 % de las entradas. La extensión a nuevos informales sin IVLR observado es un supuesto explícito del modelo.

\---

## 10\. Modelo basado en agentes

### 10.1. Implementación

* Software: NetLogo 7.0.3.
* Unidad temporal: un tick equivale a un trimestre.
* Horizonte: ticks 0 a 8.
* Actualización: simultánea.
* Aleatoriedad: reproducible mediante semilla.
* Población inicial: 41.398 agentes muestrales de 2023T4.
* Peso representado: 25.325.272 personas.
* Número de réplicas: 100 por escenario.
* Semillas finales: 1 a 100.

|Estado inicial|Agentes|
|-|-:|
|Formal|12.151|
|Informal|9.114|
|Desocupación|1.055|
|Inactividad|19.078|
|**Total**|**41.398**|

Cada agente mantiene su ponderador. La muestra no se expande físicamente. El número de agentes y el peso poblacional permanecen constantes durante las simulaciones.

### 10.2. Lógica de actualización

En cada tick:

1. se lee el vector empírico de probabilidades correspondiente al agente;
2. se aplica el operador del escenario;
3. se normaliza el vector para que sume uno;
4. se sortea un destino provisional;
5. se asigna un perfil al agente que ingresa a la informalidad;
6. se actualizan simultáneamente todos los agentes;
7. se registran stocks, flujos y resultados ponderados.

El vector de destinos conserva siempre este orden:

```text
\[formal, informal, desocupación, inactividad]


El insumo macroeconómico comprende los 16 trimestres de 2022–2025. La inflación trimestral se calculó a partir del IPC nacional del último mes de cada trimestre y la variación cambiaria mediante la cotización minorista vendedora del último día hábil disponible. El salario mínimo nominal trimestral se obtuvo como promedio de los valores mensuales vigentes y se expresó en términos reales mediante el IPC. Diciembre de 2021 se utilizó como período de referencia para calcular la primera variación de 2022. Las intensidades baja, moderada y alta de los escenarios se definieron mediante los percentiles 25, 50 y 75 de las variaciones trimestrales observadas.

\---

## 11\. Escenarios

### 11.1. Escenario base

Utiliza las probabilidades empíricas sin perturbaciones. Las bases I0, M0, D0 y C0 fueron verificadas con variables y semillas comunes.

### 11.2. Inflación

Afecta directamente a trabajadores informales, reduce relativamente la transición hacia formalidad y aumenta la permanencia informal. La exposición es mayor en los cuartiles de mayor vulnerabilidad.

|Escenario|Intensidad|Referencia|
|-|-:|-|
|M0|0,000|Base|
|M1|0,158|P25 de inflación trimestral|
|M2|0,325|Mediana|
|M3|0,421|P75|

La intensidad general se ajusta según el cuartil del IVLR: 0,75 para Q1, 0,90 para Q2, 1,10 para Q3, 1,25 para Q4 y 1,00 para los casos sin cuartil. El operador inflacionario reduce la probabilidad informal–formal y aumenta la permanencia informal, mientras que el devaluatorio reduce la formalización y aumenta el tránsito hacia la desocupación entre los informales, además de elevar las salidas desde formalidad hacia informalidad y desocupación.

### 

### 11.3. Devaluación

Para informales, reduce la formalización y aumenta la salida a desocupación; para formales, aumenta las transiciones hacia informalidad y desocupación.

|Escenario|Intensidad|Referencia|
|-|-:|-|
|D0|0,000|Base|
|D1|0,057|P25 de devaluación trimestral|
|D2|0,112|Mediana|
|D3|0,186|P75|

El máximo observado de 131,70 % en 2023T4 se conserva como episodio extremo y no se utiliza como escenario principal.

### 11.4. Condiciones institucionales

|Escenario|Contratación|Desvinculación|Interpretación operativa|
|-|-:|-:|-|
|I0|0,00|0,00|Base institucional|
|I1|0,15|0,00|Mayor facilidad de contratación|
|I2|0,15|0,15|Flexibilidad moderada|
|I3|0,30|0,30|Flexibilidad intensa|

Los escenarios institucionales permanecen activos hasta el final. Representan mecanismos estilizados y no reproducen una norma específica.La contratación modifica las entradas hacia formalidad desde informalidad y desocupación, mientras que la desvinculación modifica las salidas desde formalidad hacia informalidad y desocupación.

### 11.5. Escenario combinado

C1 combina:

* inflación: 0,325;
* devaluación: 0,112;
* contratación: 0,15;
* desvinculación: 0,15.

Los multiplicadores se aplican conjuntamente sobre el vector base y se normalizan una sola vez. En C1, el componente institucional comparte la ventana transitoria de los shocks macroeconómicos. No debe confundirse con I1-I3.

### 11.6. Ventana temporal

Los shocks transitorios actúan en las transiciones 1→2, 2→3 y 3→4. Desde 4→5 se restauran las probabilidades base. La ventana es experimental y no corresponde literalmente a tres trimestres históricos.

\---

## 12\. Resultados de referencia del ABM

Estos valores sirven para auditar la reproducción. No sustituyen el capítulo de resultados del TFM.

### Inflación, tick 4 frente a M0

|Escenario|Formalidad|Informalidad|
|-|-:|-:|
|M1|-1,199 pp|+1,887 pp|
|M2|-2,314 pp|+3,651 pp|
|M3|-2,932 pp|+4,609 pp|

### Devaluación, tick 4 frente a D0

|Escenario|Formalidad|Informalidad|Desocupación|Inactividad|
|-|-:|-:|-:|-:|
|D1|-0,661 pp|+0,405 pp|+0,167 pp|+0,089 pp|
|D2|-1,203 pp|+0,736 pp|+0,304 pp|+0,163 pp|
|D3|-2,038 pp|+1,255 pp|+0,512 pp|+0,272 pp|

### Institucional

La movilidad formal bruta media durante los ticks 2-4 es 0,0606 en I1, 0,0648 en I2 y 0,0719 en I3. Stocks formales semejantes pueden coexistir con distintos niveles de entrada y salida.

### Combinado, tick 4 frente a C0

|Estado|Diferencia C1-C0|
|-|-:|
|Formalidad|-3,751 pp|
|Informalidad|+4,640 pp|
|Desocupación|+0,095 pp|
|Inactividad|-0,983 pp|

Bajo los supuestos programados, la informalidad concentra la mayor parte del ajuste. Estos resultados no identifican efectos causales de la inflación, la devaluación o las instituciones laborales.

\---

## 13\. Validación y controles

### 13.1. Insumos

* encabezados esperados;
* identificadores únicos;
* pesos positivos;
* estados, clusters y cuartiles válidos;
* ausencia de claves duplicadas;
* vectores con valores en `\[0,1]`;
* suma unitaria con tolerancia `1e-8`.

### 13.2. Operadores

* intensidad cero reproduce el vector original;
* no se crean transiciones inexistentes desde probabilidades nulas;
* la dirección del ajuste coincide con la definición del escenario;
* la exposición diferencial Q1-Q4 se aplica cuando corresponde;
* los mecanismos se activan solo en la ventana prevista;
* las probabilidades base se restauran después de los shocks transitorios.

### 13.3. Simulación

Se validaron 18 archivos, 14 de escenarios principales y cuatro institucionales de perfiles. Cada archivo final debe contener:

* 900 filas;
* 100 semillas;
* ticks 0 a 8;
* nueve observaciones por semilla;
* ningún duplicado semilla-tick;
* 41.398 agentes por observación;
* peso total de 25.325.272;
* suma correcta de los cuatro estados;
* coincidencia con la base en ticks 0 y 1.

Los percentiles 2,5 y 97,5 describen variación entre réplicas simuladas. No son intervalos de confianza poblacionales.

\---

## 14\. Archivos principales

|Archivo o carpeta|Función|
|-|-|
|`Salidas/base\_eph\_2022\_2025.rds`|Base consolidada de 759.264 registros|
|`Salidas/06\_transiciones/panel\_estados\_auditado.rds`|Panel consistente con estados en t y t+1|
|`Salidas/07\_clustering/base\_clustering\_final.parquet`|Entrada oficial del clustering|
|`Salidas/07\_clustering/base\_final\_clusters\_sin\_region.parquet`|Base con clusters finales|
|`Salidas/09\_ivlr/base\_componentes\_ivlr.parquet`|Componentes previos del IVLR|
|`Salidas/09\_ivlr/base\_ivlr\_preliminar.parquet`|IVLR básico, ampliado y sensibilidad|
|`Salidas/11\_calibracion\_abm/probabilidades\_operativas\_abm.csv`|Reglas desde empleo informal|
|`Salidas/12\_insumos\_abm/transiciones\_generales\_otros\_estados\_operativa.csv`|Reglas desde otros estados|
|`Salidas/12\_insumos\_abm/distribucion\_entrantes\_informalidad\_por\_origen.csv`|Perfiles de nuevos informales según origen|
|`Salidas/13\_abm\_base/poblacion\_inicial\_2023T4.csv`|Población inicial del ABM|
|`Salidas/13\_abm\_base/insumos\_netlogo/`|Insumos operativos de NetLogo|
|`Salidas/14\_escenarios\_macroeconomicos/`|Insumo y auditoría macroeconómica|
|`NetLogo/Experimentos/`|Salidas crudas de BehaviorSpace|
|`Salidas/20\_reportes\_escenarios\_abm/`|Tablas, figuras y validaciones de escenarios|
|`Salidas/21\_mecanismos\_emergentes/`|Síntesis de mecanismos y gráficos complementarios|

\---

## 15\. Correspondencia con los anexos del TFM

Esta sección permite localizar el respaldo técnico de cada anexo de la memoria.

### Anexo A. Diagnósticos del FAMD y estabilidad del clustering

Documenta:

* valores propios y selección de siete dimensiones;
* comparación de soluciones para distintos valores de `k`;
* elección de cinco clusters;
* estabilidad frente a distintas inicializaciones;
* índice de Rand ajustado superior a 0,999.

Fuentes principales:

```text
Script Py/10\_Clustering\_matriz\_final.ipynb
Script Py/11\_Perfiles\_empleo\_informal\_FAMD\_K\_means.ipynb
Salidas/07\_clustering/
```

### Anexo B. Caracterización ampliada de los perfiles

Contiene la descripción sustantiva de los cinco perfiles mediante edad, posición en el hogar, educación, categoría ocupacional, rama, tamaño del establecimiento e intensidad laboral.

Fuentes principales:

```text
Script Py/11\_Perfiles\_empleo\_informal\_FAMD\_K\_means.ipynb
Salidas/07\_clustering/base\_final\_clusters\_sin\_region.parquet
Salidas/07\_clustering/
```

Las modas ponderadas resumen la categoría más frecuente. No representan la distribución completa de cada variable.

### Anexo C. Matrices completas de transición laboral

Incluye:

* matriz no ponderada de enlaces muestrales;
* matriz ponderada con `PONDERA` del trimestre de origen;
* comparación de persistencias;
* alcance interpretativo;
* relación con la calibración jerárquica del ABM.

Fuentes principales:

```text
Scripts/08A\_auditoria\_estados\_transicion.R
Scripts/08B\_matrices\_transicion\_conteos.R
Scripts/08C\_probabilidades\_y\_movilidad.R
Salidas/06\_transiciones/
Salidas/11\_calibracion\_abm/
Salidas/12\_insumos\_abm/
```

Las matrices describen movilidad trimestral y no identifican mecanismos causales ni duración total de los estados.

### Anexo D. Sensibilidad del IVLR

Compara la especificación principal con una versión de pesos iguales. Incluye distribuciones, concordancia individual y correlación de Spearman de 0,958.

Fuentes principales:

```text
Script Py/12\_auditoria\_variables\_vulnerabilidad.ipynb
Script Py/13\_Componentes\_IVLR.ipynb
Script Py/14\_transiciones\_segun\_ivlr.ipynb
Salidas/08\_vulnerabilidad/
Salidas/09\_ivlr/
Salidas/10\_ivlr\_transiciones/
```

El análisis evalúa robustez ordinal. No demuestra que los pesos principales sean únicos ni óptimos.

### Anexo E. Especificación, validación y reproducibilidad del ABM

Describe:

* secuencia operativa del ABM;
* jerarquía de calibración;
* asignación de perfiles a nuevos informales;
* actualización simultánea;
* controles internos;
* réplicas, semillas y comparación pareada;
* alcance y limitaciones.

Fuentes principales:

```text
NetLogo/17\_ABM\_escenarios\_final\_tablero.nlogo
NetLogo/17\_ABM\_base\_con\_shocks.nls
Salidas/13\_abm\_base/insumos\_netlogo/
NetLogo/Experimentos/
Script Py/20\_analizar\_escenarios\_abm.py
Script Py/21\_analizar\_mecanismos\_emergentes.py
Salidas/20\_reportes\_escenarios\_abm/
Salidas/21\_mecanismos\_emergentes/
```

## 16\. Reglas de interpretación

1. Las probabilidades base provienen de transiciones observadas y son descriptivas.
2. Los operadores de escenario son supuestos explícitos, no elasticidades econométricas.
3. Los resultados simulados son consecuencias internas del modelo.
4. No deben atribuirse resultados a una norma, gobierno o episodio histórico específico.
5. La persistencia posterior a un shock no equivale a evidencia empírica de histéresis.
6. Cluster e IVLR capturan dimensiones distintas.
7. La vulnerabilidad observada en t se asocia con el destino en t+1, pero esta relación no es causal.
8. Un stock laboral semejante puede ocultar flujos y rotaciones diferentes.
9. La validación actual es empírica en la calibración e interna en la simulación; no constituye validación predictiva temporal fuera de muestra.

\---

## 17\. Limitaciones técnicas

* La formalidad completa de trabajadores independientes solo está disponible desde 2023T4.
* El panel rotativo permite enlaces de corto plazo, no trayectorias completas.
* El IVLR no se actualiza endógenamente en el ABM.
* El modelo no actualiza ingresos, educación ni otros atributos individuales.
* No se modelan empresas, demanda laboral, salarios, redes ni decisiones de contratación a nivel de firma.
* Los operadores no son coeficientes causales estimados.
* Las distribuciones de entrada a informalidad se estiman sobre casos con IVLR ampliado observado.
* Los resultados dependen de la calibración, las intensidades y la forma funcional de los operadores.

\---

## 18\. Prácticas de reproducibilidad

* Datos originales preservados sin cambios.
* Dependencias de R fijadas con `renv`.
* Python 3.11 gestionado con Conda.
* NetLogo 7.0.3 para el motor y BehaviorSpace.
* Semilla 42 para el clustering.
* Semillas 1 a 100 para las simulaciones finales.
* Entradas no sobrescritas.
* Salidas separadas por etapa.
* Exportación CSV preferentemente con `utf-8-sig`.
* Exportación Parquet con PyArrow y sin índice.
* Validación de filas y claves en uniones críticas.
* Comparaciones pareadas por semilla y tick.
* Listas explícitas de archivos finales para excluir pruebas de desarrollo.

\---

## 19\. Datos, licencia y uso

Los microdatos de la EPH pertenecen al INDEC y se utilizan con fines académicos. Si el repositorio se publica, debe comprobarse qué archivos pueden redistribuirse y cuáles deben ser descargados desde la fuente oficial.

El código puede revisarse y reproducirse junto con la memoria, los metadatos y este README. Antes de asignar una licencia abierta, debe confirmarse que no existan restricciones institucionales o de terceros sobre archivos incluidos en el repositorio.

