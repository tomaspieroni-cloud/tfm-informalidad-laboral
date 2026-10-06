# -*- coding: utf-8 -*-
"""
20_analizar_escenarios_abm.py
=============================

Análisis descriptivo de los resultados finales de BehaviorSpace del ABM
sobre informalidad laboral en Argentina (2022–2025).

Familias analizadas:
    - Institucional  (I0 base, I1 contratación, I2 flexibilidad moderada,
                      I3 flexibilidad intensa).
    - Inflación      (M0 base, M1 baja, M2 moderada, M3 alta).
    - Devaluación    (D0 base, D1 baja, D2 moderada, D3 alta).
    - Combinado      (C0 base, C1 moderado).

ADVERTENCIAS
------------
- NO se incluye la perturbación contractiva estilizada en el análisis principal.
- Los resultados se describen y comparan, pero NO se interpretan de forma causal.
- Los percentiles 2,5 y 97,5 son percentiles empíricos de las réplicas:
  NO son intervalos de confianza poblacionales.
- El porcentaje se calcula ponderado por el peso de los agentes
  (columnas ``proporcion-*`` ya exportadas por NetLogo).

Requisitos: Python 3.11+, pandas, numpy, matplotlib.
"""

from __future__ import annotations

import logging
from pathlib import Path

import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# Configuración del backend de matplotlib (sin interfaz gráfica).
# ---------------------------------------------------------------------------
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

# ===========================================================================
# Constantes globales
# ===========================================================================

# Raíz del proyecto (una sola definición). El script vive en "Script Py/".
RAIZ: Path = Path(__file__).resolve().parents[1]

# Carpetas de entrada y salida.
RUTA_EXPERIMENTOS: Path = RAIZ / "NetLogo" / "Experimentos"
RUTA_SALIDAS: Path = RAIZ / "Salidas" / "20_reportes_escenarios_abm"

# Si es False, no se sobrescriben salidas existentes (FileExistsError).
SOBRESCRIBIR: bool = False

# Número de líneas de metadatos que preceden al encabezado en los CSV de
# BehaviorSpace (Table version 2.0).
METADATOS_SKIPROWS: int = 6

# Parámetros esperados de la población simulada (validación dura).
N_AGENTES: int = 41398
SUMA_PESOS: int = 25325272
N_SEMILLAS: int = 100
N_TICKS: int = 9  # ticks 0 a 8
TICKS: list[int] = list(range(0, N_TICKS))
TICKS_REPORTE: tuple[int, ...] = (1, 4, 8)  # ticks de reporte principal

# Columnas comunes.
COL_SEMILLA: str = "semilla-modelo"
COL_TICK: str = "ticks"
COL_COUNT_TURTLES: str = "count turtles"
COL_SUMA_PESO: str = "sum [peso] of turtles"

# Conteos de agentes por estado (para validación de suma).
COL_CONTEOS_ESTADOS: list[str] = [
    "n-formales",
    "n-informales",
    "n-desocupados",
    "n-inactivos",
]

# Porcentaje ponderado por estado (ya calculado por NetLogo con los pesos).
COL_PORCENTAJE: dict[str, str] = {
    "formalidad": "proporcion-formales",
    "informalidad": "proporcion-informales",
    "desocupacion": "proporcion-desocupados",
    "inactividad": "proporcion-inactivos",
}
ESTADOS: list[str] = ["formalidad", "informalidad", "desocupacion", "inactividad"]
ETIQUETA_ESTADOS: dict[str, str] = {
    "formalidad": "Formalidad",
    "informalidad": "Informalidad",
    "desocupacion": "Desocupación",
    "inactividad": "Inactividad",
}

# ---------------------------------------------------------------------------
# Flujos de transición: (nombre, columna numerador, columna denominador).
# El denominador es el número de agentes del estado de origen.
# ---------------------------------------------------------------------------
FLUJOS: list[tuple[str, str, str]] = [
    (
        "informal_a_formal",
        'count turtles with [estado-origen = "informal" and estado-actual = "formal"]',
        'count turtles with [estado-origen = "informal"]',
    ),
    (
        "informal_a_informal",
        'count turtles with [estado-origen = "informal" and estado-actual = "informal"]',
        'count turtles with [estado-origen = "informal"]',
    ),
    (
        "informal_a_desocupacion",
        'count turtles with [estado-origen = "informal" and estado-actual = "desocupacion"]',
        'count turtles with [estado-origen = "informal"]',
    ),
    (
        "desocupacion_a_formal",
        'count turtles with [estado-origen = "desocupacion" and estado-actual = "formal"]',
        'count turtles with [estado-origen = "desocupacion"]',
    ),
    (
        "formal_a_informal",
        'count turtles with [estado-origen = "formal" and estado-actual = "informal"]',
        'count turtles with [estado-origen = "formal"]',
    ),
    (
        "formal_a_desocupacion",
        'count turtles with [estado-origen = "formal" and estado-actual = "desocupacion"]',
        'count turtles with [estado-origen = "formal"]',
    ),
]

# Salida total desde formalidad = (formal->informal + formal->desocupacion)/formal.
FLUJO_SALIDA_FORMAL: tuple[str, list[str], str] = (
    "salida_total_desde_formalidad",
    [
        'count turtles with [estado-origen = "formal" and estado-actual = "informal"]',
        'count turtles with [estado-origen = "formal" and estado-actual = "desocupacion"]',
    ],
    'count turtles with [estado-origen = "formal"]',
)

# ---------------------------------------------------------------------------
# Cuartiles (métricas por cuartil y denominador). Solo se usan cuando las
# columnas existen. NO se generan combinaciones cluster por cuartil.
# ---------------------------------------------------------------------------
CUARTILES: list[int] = [1, 2, 3, 4]

METRICAS_CUARTIL: list[tuple[str, callable]] = [
    (
        "informal_a_formal",
        lambda q: (
            f'count turtles with [estado-origen = "informal" and '
            f'estado-actual = "formal" and ultimo-cuartil-informal = {q}]'
        ),
    ),
    (
        "informal_a_informal",
        lambda q: (
            f'count turtles with [estado-origen = "informal" and '
            f'estado-actual = "informal" and cuartil-actual = {q}]'
        ),
    ),
    (
        "informal_a_desocupacion",
        lambda q: (
            f'count turtles with [estado-origen = "informal" and '
            f'estado-actual = "desocupacion" and ultimo-cuartil-informal = {q}]'
        ),
    ),
]


def _col_den_cuartil(q: int) -> str:
    """Columna denominador (agentes informales del cuartil q)."""
    return f'count turtles with [estado-origen = "informal" and ultimo-cuartil-informal = {q}]'


# ---------------------------------------------------------------------------
# Familias de escenarios: orden, etiquetas, archivos y configuración gráfica.
# Los diccionarios son explícitos: no se depende del orden de las columnas
# ni del orden de archivos en disco.
# ---------------------------------------------------------------------------
FAMILIAS: dict[str, dict] = {
    "institucional": {
        "titulo": "Escenarios institucionales (ABM, Argentina 2022–2025)",
        "base": "I0",
        "orden": ["I0", "I1", "I2", "I3"],
        "etiquetas": {
            "I0": "Base institucional",
            "I1": "Contratación",
            "I2": "Flexibilidad moderada",
            "I3": "Flexibilidad intensa",
        },
        "archivos": {
            "I0": "institucional_I0_base_8_ticks.csv",
            "I1": "institucional_I1_contratacion_8_ticks.csv",
            "I2": "institucional_I2_flexibilidad_moderada_8_ticks.csv",
            "I3": "institucional_I3_flexibilidad_intensa_8_ticks.csv",
        },
        # Archivos de perfiles por cuartil (institucional).
        "perfiles": {
            "I0": "institucional_perfiles_I0.csv",
            "I1": "institucional_perfiles_I1.csv",
            "I2": "institucional_perfiles_I2.csv",
            "I3": "institucional_perfiles_I3.csv",
        },
        "sombreado_ticks": None,
        "nota": "El mecanismo permanece activo desde la transición 1 a 2.",
        "colores": {
            "I0": "black",
            "I1": "#1f77b4",
            "I2": "#ff7f0e",
            "I3": "#2ca02c",
        },
    },
    "inflacion": {
        "titulo": "Escenarios de inflación (ABM, Argentina 2022–2025)",
        "base": "M0",
        "orden": ["M0", "M1", "M2", "M3"],
        "etiquetas": {
            "M0": "Base inflación",
            "M1": "Inflación baja",
            "M2": "Inflación moderada",
            "M3": "Inflación alta",
        },
        "archivos": {
            "M0": "inflacion_M0_base_8_ticks.csv",
            "M1": "inflacion_M1_baja_8_ticks.csv",
            "M2": "inflacion_M2_moderada_8_ticks.csv",
            "M3": "inflacion_M3_alta_8_ticks.csv",
        },
        "perfiles": None,
        "sombreado_ticks": (1, 4),
        "nota": "Sombreado: ventana de transiciones afectadas entre los ticks 1 y 4.",
        "colores": {
            "M0": "black",
            "M1": "#1f77b4",
            "M2": "#ff7f0e",
            "M3": "#d62728",
        },
    },
    "devaluacion": {
        "titulo": "Escenarios de devaluación (ABM, Argentina 2022–2025)",
        "base": "D0",
        "orden": ["D0", "D1", "D2", "D3"],
        "etiquetas": {
            "D0": "Base devaluación",
            "D1": "Devaluación baja",
            "D2": "Devaluación moderada",
            "D3": "Devaluación alta",
        },
        "archivos": {
            "D0": "devaluacion_D0_base_8_ticks.csv",
            "D1": "devaluacion_D1_baja_8_ticks.csv",
            "D2": "devaluacion_D2_moderada_8_ticks.csv",
            "D3": "devaluacion_D3_alta_8_ticks.csv",
        },
        "perfiles": None,
        "sombreado_ticks": (1, 4),
        "nota": "Sombreado: ventana de transiciones afectadas entre los ticks 1 y 4.",
        "colores": {
            "D0": "black",
            "D1": "#1f77b4",
            "D2": "#ff7f0e",
            "D3": "#d62728",
        },
    },
    "combinado": {
        "titulo": "Escenarios combinados (ABM, Argentina 2022–2025)",
        "base": "C0",
        "orden": ["C0", "C1"],
        "etiquetas": {
            "C0": "Base combinada",
            "C1": "Combinado moderado",
        },
        "archivos": {
            "C0": "combinado_C0_base_8_ticks.csv",
            "C1": "combinado_C1_moderado_8_ticks.csv",
        },
        "perfiles": None,
        "sombreado_ticks": (1, 4),
        "nota": "Sombreado: ventana de transiciones afectadas entre los ticks 1 y 4.",
        "colores": {
            "C0": "black",
            "C1": "#1f77b4",
        },
    },
}

# Nombres de las tablas de salida.
TABLAS_SALIDA: list[str] = [
    "tabla_resultados_agregados.csv",
    "tabla_diferencias_vs_base.csv",
    "tabla_flujos_transicion.csv",
    "tabla_resultados_cuartiles.csv",
    "registro_validacion_archivos.csv",
]


# ===========================================================================
# Funciones auxiliares
# ===========================================================================

def configurar_logging() -> None:
    """Configura el registro de eventos en consola."""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)-7s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )


def verificar_salidas() -> None:
    """Comprueba si alguna salida ya existe.

    Si ``SOBRESCRIBIR`` es False y la carpeta de salida contiene algún archivo
    esperado, detiene la ejecución con FileExistsError.
    """
    if not RUTA_SALIDAS.exists():
        return
    nombres_figuras = [f"figura_{familia}.png" for familia in FAMILIAS]
    esperadas = TABLAS_SALIDA + nombres_figuras
    existentes = [n for n in esperadas if (RUTA_SALIDAS / n).exists()]
    if existentes and not SOBRESCRIBIR:
        raise FileExistsError(
            "SOBRESCRIBIR=False y las siguientes salidas ya existen: "
            f"{existentes}. Elimínalas o activa SOBRESCRIBIR."
        )


def leer_behavior_space(ruta: Path) -> pd.DataFrame:
    """Lee un CSV de BehaviorSpace saltando las líneas de metadatos.

    Parámetros
    ----------
    ruta : Path
        Ruta al archivo CSV.

    Devuelve
    --------
    pd.DataFrame
        Tabla de resultados ya limpia y ordenada por semilla y tick.
    """
    df = pd.read_csv(ruta, skiprows=METADATOS_SKIPROWS)
    df = df.sort_values([COL_SEMILLA, COL_TICK]).reset_index(drop=True)
    return df


# ===========================================================================
# Validación de archivos
# ===========================================================================

def validar_archivo(
    df: pd.DataFrame, familia: str, escenario: str, tipo: str, nombre: str
) -> list[str]:
    """Valida un DataFrame de BehaviorSpace y devuelve la lista de errores.

    Comprueba: columnas obligatorias, 900 filas, 100 semillas (1..100),
    ticks 0..8, 9 filas por semilla, sin duplicados semilla-tick,
    count turtles = 41398, suma de pesos = 25325272 y suma de estados =
    count turtles.
    """
    # Validación de columnas antes de cualquier uso (errores informativos).
    columnas_obligatorias = {
        COL_SEMILLA,
        COL_TICK,
        COL_COUNT_TURTLES,
        COL_SUMA_PESO,
        *COL_CONTEOS_ESTADOS,
        *COL_PORCENTAJE.values(),
    }
    columnas_faltantes = columnas_obligatorias.difference(df.columns)
    if columnas_faltantes:
        raise ValueError(
            f"{nombre}: faltan columnas obligatorias: "
            f"{sorted(columnas_faltantes)}"
        )

    errores: list[str] = []

    semillas = set(df[COL_SEMILLA].unique())
    ticks = set(df[COL_TICK].unique())

    if len(df) != N_SEMILLAS * N_TICKS:
        errores.append(f"filas={len(df)} (esperado {N_SEMILLAS * N_TICKS})")
    if semillas != set(range(1, N_SEMILLAS + 1)):
        errores.append(f"semillas fuera de 1..{N_SEMILLAS}: {sorted(semillas)}")
    if ticks != set(TICKS):
        errores.append(f"ticks fuera de 0..8: {sorted(ticks)}")
    if not (df.groupby(COL_SEMILLA).size() == N_TICKS).all():
        errores.append("no hay 9 filas por semilla")
    if df.duplicated(subset=[COL_SEMILLA, COL_TICK]).any():
        errores.append("combinaciones semilla-tick duplicadas")
    if not (df[COL_COUNT_TURTLES] == N_AGENTES).all():
        errores.append(f"count turtles distinto de {N_AGENTES}")
    if not (df[COL_SUMA_PESO] == SUMA_PESOS).all():
        errores.append(f"sum [peso] of turtles distinto de {SUMA_PESOS}")
    suma_estados = df[COL_CONTEOS_ESTADOS].sum(axis=1)
    if not (suma_estados == df[COL_COUNT_TURTLES]).all():
        errores.append("los cuatro estados no suman count turtles")

    if errores:
        detalle = "; ".join(errores)
        raise ValueError(
            f"Validación fallida [{familia}/{escenario} ({tipo}): {nombre}]: {detalle}"
        )
    return errores


def cargar_y_validar(
    familia: str, escenario: str, nombre_archivo: str, tipo: str, registro: list[dict]
) -> pd.DataFrame:
    """Carga y valida un archivo, y registra el resultado de la validación."""
    ruta = RUTA_EXPERIMENTOS / nombre_archivo
    df = leer_behavior_space(ruta)
    try:
        errores = validar_archivo(df, familia, escenario, tipo, nombre_archivo)
    except ValueError as exc:
        registro.append(
            {
                "archivo": nombre_archivo,
                "familia": familia,
                "escenario": escenario,
                "tipo": tipo,
                "valido": False,
                "errores": str(exc),
            }
        )
        raise  # detiene la ejecución (política de validación dura)
    registro.append(
        {
            "archivo": nombre_archivo,
            "familia": familia,
            "escenario": escenario,
            "tipo": tipo,
            "filas": len(df),
            "semillas": df[COL_SEMILLA].nunique(),
            "ticks_unicos": sorted(df[COL_TICK].unique()),
            "duplicados_semilla_tick": int(df.duplicated(subset=[COL_SEMILLA, COL_TICK]).sum()),
            "count_turtles_ok": bool((df[COL_COUNT_TURTLES] == N_AGENTES).all()),
            "suma_pesos_ok": bool((df[COL_SUMA_PESO] == SUMA_PESOS).all()),
            "estados_suman_ok": bool(
                (df[COL_CONTEOS_ESTADOS].sum(axis=1) == df[COL_COUNT_TURTLES]).all()
            ),
            "valido": True,
            "errores": "",
        }
    )
    return df


def validar_bases_comunes(bases: dict[str, pd.DataFrame]) -> None:
    """Comprueba que I0, M0, D0 y C0 sean idénticas en variables comunes.

    Las cuatro bases deben reproducir exactamente la misma población en los
    ticks 0 a 8 (conteos y porcentajes ponderados). Si alguna difiere, la
    comparación pareada frente a la base carecería de sentido.
    """
    columnas_comparacion = [
        COL_SEMILLA,
        COL_TICK,
        COL_COUNT_TURTLES,
        COL_SUMA_PESO,
        *COL_CONTEOS_ESTADOS,
        *COL_PORCENTAJE.values(),
    ]

    nombres = list(bases)
    nombre_referencia = nombres[0]
    referencia = (
        bases[nombre_referencia][columnas_comparacion]
        .sort_values([COL_SEMILLA, COL_TICK])
        .reset_index(drop=True)
    )

    for nombre in nombres[1:]:
        comparada = (
            bases[nombre][columnas_comparacion]
            .sort_values([COL_SEMILLA, COL_TICK])
            .reset_index(drop=True)
        )
        try:
            pd.testing.assert_frame_equal(
                referencia,
                comparada,
                check_dtype=False,
                check_exact=True,
            )
        except AssertionError as exc:
            raise ValueError(
                f"La base {nombre} no coincide exactamente con "
                f"{nombre_referencia}."
            ) from exc

    logging.info("Bases I0, M0, D0 y C0 idénticas en las variables comunes.")


# ===========================================================================
# Cálculos
# ===========================================================================

def _resumen(serie: pd.Series) -> dict:
    """Estadísticos descriptivos de una serie (sin percentiles 'de confianza')."""
    return {
        "media": float(serie.mean()),
        "desv_estandar": float(serie.std(ddof=1)),
        "mediana": float(serie.median()),
        "p2_5": float(serie.quantile(0.025)),
        "p97_5": float(serie.quantile(0.975)),
        "n_replicas": int(serie.count()),
    }


def calcular_agregados(df: pd.DataFrame, familia: str, escenario: str) -> pd.DataFrame:
    """Media, desvío, mediana y percentiles 2,5/97,5 del porcentaje ponderado.

    Se calcula por escenario, estado y tick (0 a 8).
    """
    filas: list[dict] = []
    for estado, col in COL_PORCENTAJE.items():
        for tick in TICKS:
            serie = df.loc[df[COL_TICK] == tick, col] * 100.0  # porcentaje
            filas.append(
                {
                    "familia": familia,
                    "escenario": escenario,
                    "estado": estado,
                    "tick": tick,
                    **_resumen(serie),
                }
            )
    return pd.DataFrame(filas)


def calcular_diferencias(
    df_esc: pd.DataFrame, df_base: pd.DataFrame, familia: str, escenario: str
) -> pd.DataFrame:
    """Diferencia pareada (por semilla y tick) frente al escenario base.

    Se expresa en puntos porcentuales (pp) del porcentaje ponderado.
    """
    cfg = FAMILIAS[familia]
    base = cfg["base"]
    pareado = pd.merge(
        df_esc, df_base, on=[COL_SEMILLA, COL_TICK], suffixes=("_esc", "_base")
    )
    filas: list[dict] = []
    for estado, col in COL_PORCENTAJE.items():
        col_esc, col_base = f"{col}_esc", f"{col}_base"
        diferencia_pp = 100.0 * (pareado[col_esc] - pareado[col_base])
        for tick in TICKS:
            serie = diferencia_pp[pareado[COL_TICK] == tick]
            filas.append(
                {
                    "familia": familia,
                    "escenario": escenario,
                    "escenario_base": base,
                    "estado": estado,
                    "tick": tick,
                    "reporte_principal": tick in TICKS_REPORTE,
                    "diferencia_pp_media": float(serie.mean()),
                    "diferencia_pp_desv": float(serie.std(ddof=1)),
                    "diferencia_pp_mediana": float(serie.median()),
                    "diferencia_pp_p2_5": float(serie.quantile(0.025)),
                    "diferencia_pp_p97_5": float(serie.quantile(0.975)),
                    "n_pares": int(serie.count()),
                }
            )
    return pd.DataFrame(filas)


def _resumen_flujo(
    familia: str,
    escenario: str,
    nombre: str,
    tick: int,
    tasa: pd.Series,
    n_observaciones: int,
) -> dict:
    """Construye una fila de resumen de una tasa de transición."""
    return {
        "familia": familia,
        "escenario": escenario,
        "flujo": nombre,
        "tick": tick,
        **_resumen(tasa),
        "n_observaciones": n_observaciones,
    }


def calcular_flujos(df: pd.DataFrame, familia: str, escenario: str) -> pd.DataFrame:
    """Tasas de transición cuando las columnas existen (sin el tick 0).

    El denominador es el número de agentes del estado de origen.
    """
    filas: list[dict] = []
    for tick in TICKS[1:]:  # no se calculan tasas para el tick 0
        sub = df[df[COL_TICK] == tick]
        for nombre, col_num, col_den in FLUJOS:
            if col_num not in df.columns or col_den not in df.columns:
                continue
            denominador = sub[col_den].replace(0, np.nan)
            tasa = sub[col_num] / denominador
            filas.append(
                _resumen_flujo(familia, escenario, nombre, tick, tasa, len(sub))
            )
        # Salida total desde formalidad.
        cols_num = FLUJO_SALIDA_FORMAL[1]
        col_den = FLUJO_SALIDA_FORMAL[2]
        if all(c in df.columns for c in cols_num) and col_den in df.columns:
            numerador = sub[cols_num].sum(axis=1)
            denominador = sub[col_den].replace(0, np.nan)
            tasa = numerador / denominador
            filas.append(
                _resumen_flujo(
                    familia, escenario, FLUJO_SALIDA_FORMAL[0], tick, tasa, len(sub)
                )
            )
    return pd.DataFrame(filas)


def _tasas_cuartil(
    df: pd.DataFrame, q: int, nombre: str, col_num_fn: callable
) -> pd.Series | None:
    """Tasa por cuartil (por réplica) si la columna existe; si no, None."""
    col_num = col_num_fn(q)
    col_den = _col_den_cuartil(q)
    if col_num not in df.columns or col_den not in df.columns:
        return None
    denominador = df[col_den].replace(0, np.nan)
    return df[col_num] / denominador


def calcular_cuartiles(df: pd.DataFrame, familia: str, escenario: str) -> pd.DataFrame:
    """Tasas por cuartil (Q1..Q4) cuando las métricas existen.

    No genera combinaciones cluster por cuartil.
    """
    filas: list[dict] = []
    for q in CUARTILES:
        for nombre, col_num_fn in METRICAS_CUARTIL:
            if _tasas_cuartil(df, q, nombre, col_num_fn) is None:
                continue
            for tick in TICKS[1:]:
                sub = df[df[COL_TICK] == tick]
                tasa = _tasas_cuartil(sub, q, nombre, col_num_fn)
                if tasa is None:
                    continue
                filas.append(
                    {
                        "familia": familia,
                        "escenario": escenario,
                        "escenario_base": "",
                        "tipo": "tasa",
                        "cuartil": f"Q{q}",
                        "metrica": nombre,
                        "tick": tick,
                        **_resumen(tasa),
                    }
                )
    return pd.DataFrame(filas)


def calcular_diferencias_cuartiles(
    df_esc: pd.DataFrame, df_base: pd.DataFrame, familia: str, escenario: str
) -> pd.DataFrame:
    """Diferencia pareada (por semilla y tick) frente a la base, por cuartil.

    La comparación es: tasa_escenario(cuartil, tick) - tasa_base(cuartil, tick),
    expresada en puntos porcentuales.
    """
    cfg = FAMILIAS[familia]
    base = cfg["base"]
    filas: list[dict] = []
    for q in CUARTILES:
        for nombre, col_num_fn in METRICAS_CUARTIL:
            # Verifica que la métrica exista en ambos archivos.
            if _tasas_cuartil(df_esc, q, nombre, col_num_fn) is None:
                continue
            if _tasas_cuartil(df_base, q, nombre, col_num_fn) is None:
                continue
            col_num = col_num_fn(q)
            col_den = _col_den_cuartil(q)
            esc = df_esc[["semilla-modelo", COL_TICK, col_num, col_den]].copy()
            bas = df_base[["semilla-modelo", COL_TICK, col_num, col_den]].copy()
            esc[col_den] = esc[col_den].replace(0, np.nan)
            bas[col_den] = bas[col_den].replace(0, np.nan)
            pareado = pd.merge(
                esc, bas, on=[COL_SEMILLA, COL_TICK], suffixes=("_esc", "_base")
            )
            tasa_esc = pareado[f"{col_num}_esc"] / pareado[f"{col_den}_esc"]
            tasa_base = pareado[f"{col_num}_base"] / pareado[f"{col_den}_base"]
            diff = 100.0 * (tasa_esc - tasa_base)
            for tick in TICKS[1:]:
                serie = diff[pareado[COL_TICK] == tick]
                filas.append(
                    {
                        "familia": familia,
                        "escenario": escenario,
                        "escenario_base": base,
                        "tipo": "diferencia_vs_base",
                        "cuartil": f"Q{q}",
                        "metrica": nombre,
                        "tick": tick,
                        **_resumen(serie),
                    }
                )
    return pd.DataFrame(filas)


# ===========================================================================
# Figuras
# ===========================================================================

def generar_figura(
    familia: str, agregados: pd.DataFrame, config: dict, ruta_destino: Path
) -> Path:
    """Genera una figura de 4 paneles (formalidad, informalidad, desocupación,
    inactividad) con la media y la banda de percentiles 2,5/97,5 por escenario.

    - Eje X: tick trimestral (0 a 8).
    - Eje Y: porcentaje ponderado.
    - Línea base en negro y una línea por escenario.
    - En inflación, devaluación y combinado se sombrea la ventana de
      transiciones afectadas entre los ticks 1 y 4.
    - En institucional se indica que el mecanismo permanece activo desde la
      transición 1 a 2.
    """
    fig, axes = plt.subplots(2, 2, figsize=(14, 10), sharex=True)
    ejes = axes.flatten()

    for ax, estado in zip(ejes, ESTADOS):
        for escenario in config["orden"]:
            color = config["colores"][escenario]
            sub = agregados[
                (agregados["escenario"] == escenario)
                & (agregados["estado"] == estado)
            ].sort_values("tick")
            ax.plot(
                sub["tick"],
                sub["media"],
                color=color,
                lw=2,
                marker="o",
                ms=3,
                label=config["etiquetas"][escenario],
            )
            ax.fill_between(
                sub["tick"].to_numpy(dtype=float),
                sub["p2_5"].to_numpy(dtype=float),
                sub["p97_5"].to_numpy(dtype=float),
                color=color,
                alpha=0.15,
            )
        if config["sombreado_ticks"] is not None:
            ax.axvspan(
                config["sombreado_ticks"][0],
                config["sombreado_ticks"][1],
                color="gray",
                alpha=0.20,
                label="Ventana de transiciones afectadas (ticks 1–4)",
            )
        ax.set_title(ETIQUETA_ESTADOS[estado])
        ax.set_xlabel("Tick trimestral")
        ax.set_ylabel("Porcentaje ponderado (%)")
        ax.set_xticks(TICKS)
        ax.grid(alpha=0.3)

    # Leyenda única para toda la figura.
    handles, labels = ejes[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper center", ncol=len(labels), fontsize=9)

    fig.suptitle(config["titulo"], fontsize=14, y=0.98)
    fig.text(0.5, 0.005, config["nota"], ha="center", fontsize=9, style="italic")
    fig.tight_layout(rect=[0, 0.02, 1, 0.94])

    fig.savefig(ruta_destino, dpi=300, bbox_inches="tight")
    plt.close(fig)
    return ruta_destino


# ===========================================================================
# Orquestación principal
# ===========================================================================

def _guardar_tabla(df: pd.DataFrame, nombre: str) -> None:
    """Guarda una tabla en la carpeta de salida (redondeada a 6 decimales)."""
    ruta = RUTA_SALIDAS / nombre
    df.round(6).to_csv(ruta, index=False)
    logging.info("Tabla guardada: %s (%d filas)", nombre, len(df))


def main() -> None:
    """Ejecuta el análisis completo de escenarios del ABM."""
    configurar_logging()
    logging.info("Inicio del análisis de escenarios del ABM.")
    logging.info("Raíz del proyecto: %s", RAIZ)

    bases_comunes: dict[str, pd.DataFrame] = {}
    verificar_salidas()
    RUTA_SALIDAS.mkdir(parents=True, exist_ok=True)

    registro_validacion: list[dict] = []
    tablas_agregados: list[pd.DataFrame] = []
    tablas_diferencias: list[pd.DataFrame] = []
    tablas_flujos: list[pd.DataFrame] = []
    tablas_cuartiles: list[pd.DataFrame] = []
    figuras_generadas: list[Path] = []

    for familia, cfg in FAMILIAS.items():
        logging.info("Procesando familia: %s", familia)
        dfs: dict[str, pd.DataFrame] = {}
        dfs_cuartiles: dict[str, pd.DataFrame] = {}

        # Carga y validación del análisis principal (archivos de 8 ticks).
        for escenario in cfg["orden"]:
            nombre = cfg["archivos"][escenario]
            dfs[escenario] = cargar_y_validar(
                familia, escenario, nombre, "principal", registro_validacion
            )
            logging.info("Archivo validado: %s (%s)", nombre, escenario)

        # Registro de la base de la familia para la comparación entre bases.
        bases_comunes[cfg["base"]] = dfs[cfg["base"]]

        # Archivos de perfiles por cuartil (solo institucional).
        if cfg["perfiles"] is not None:
            for escenario in cfg["orden"]:
                nombre = cfg["perfiles"][escenario]
                dfs_cuartiles[escenario] = cargar_y_validar(
                    familia, escenario, nombre, "perfiles", registro_validacion
                )

        # Tablas de agregados y flujos.
        for escenario in cfg["orden"]:
            tablas_agregados.append(calcular_agregados(dfs[escenario], familia, escenario))
            tablas_flujos.append(calcular_flujos(dfs[escenario], familia, escenario))

        # Diferencias pareadas frente a la base.
        base = cfg["base"]
        for escenario in cfg["orden"]:
            if escenario == base:
                continue
            tabla = calcular_diferencias(dfs[escenario], dfs[base], familia, escenario)
            tablas_diferencias.append(tabla)
            # Reporte principal (ticks 1, 4 y 8) en el log.
            for estado in ESTADOS:
                sub = tabla[(tabla["estado"] == estado) & (tabla["reporte_principal"])]
                for _, fila in sub.sort_values("tick").iterrows():
                    logging.info(
                        "  %s vs %s | %s | tick %d | diff pp media=%.3f "
                        "(p2.5=%.3f, p97.5=%.3f)",
                        escenario, base, estado, fila["tick"],
                        fila["diferencia_pp_media"], fila["diferencia_pp_p2_5"],
                        fila["diferencia_pp_p97_5"],
                    )

        # Cuartiles: institucional usa los perfiles; inflación y devaluación
        # usan sus archivos de 8 ticks (que ya contienen las columnas).
        fuente_cuartiles = dfs_cuartiles if dfs_cuartiles else dfs
        if fuente_cuartiles:
            for escenario in cfg["orden"]:
                tabla = calcular_cuartiles(fuente_cuartiles[escenario], familia, escenario)
                if not tabla.empty:
                    tablas_cuartiles.append(tabla)
                if escenario != base:
                    diff = calcular_diferencias_cuartiles(
                        fuente_cuartiles[escenario],
                        fuente_cuartiles[base],
                        familia,
                        escenario,
                    )
                    if not diff.empty:
                        tablas_cuartiles.append(diff)

        # Figura de la familia.
        agregados_familia = pd.concat(
            [t for t in tablas_agregados if (t["familia"] == familia).any()]
        )
        ruta_figura = RUTA_SALIDAS / f"figura_{familia}.png"
        generar_figura(familia, agregados_familia, cfg, ruta_figura)
        figuras_generadas.append(ruta_figura)
        logging.info("Figura generada: %s", ruta_figura.name)

    # Verificación de que las cuatro bases (I0, M0, D0, C0) coinciden.
    validar_bases_comunes(bases_comunes)

    # ------------------------------------------------------------------
    # Guardado de tablas (orden determinista, sin depender del orden del disco).
    # ------------------------------------------------------------------
    df_agregados = (
        pd.concat(tablas_agregados, ignore_index=True)
        .sort_values(["familia", "escenario", "estado", "tick"])
        .reset_index(drop=True)
    )
    df_diferencias = (
        pd.concat(tablas_diferencias, ignore_index=True)
        .sort_values(["familia", "escenario", "estado", "tick"])
        .reset_index(drop=True)
    )
    df_flujos = (
        pd.concat(tablas_flujos, ignore_index=True)
        .sort_values(["familia", "escenario", "flujo", "tick"])
        .reset_index(drop=True)
    )
    df_cuartiles = (
        pd.concat(tablas_cuartiles, ignore_index=True)
        .sort_values(["familia", "escenario", "cuartil", "metrica", "tick"])
        .reset_index(drop=True)
    )
    df_registro = pd.DataFrame(registro_validacion)

    _guardar_tabla(df_agregados, "tabla_resultados_agregados.csv")
    _guardar_tabla(df_diferencias, "tabla_diferencias_vs_base.csv")
    _guardar_tabla(df_flujos, "tabla_flujos_transicion.csv")
    _guardar_tabla(df_cuartiles, "tabla_resultados_cuartiles.csv")
    _guardar_tabla(df_registro, "registro_validacion_archivos.csv")

    # ------------------------------------------------------------------
    # Resumen final.
    # ------------------------------------------------------------------
    n_archivos = len(registro_validacion)
    n_familias = len(FAMILIAS)
    n_tablas = len(TABLAS_SALIDA)
    n_figuras = len(figuras_generadas)
    print("ANÁLISIS COMPLETADO")
    print(f"Archivos validados: {n_archivos}")
    print(f"Familias analizadas: {n_familias}")
    print(f"Tablas generadas: {n_tablas}")
    print(f"Figuras generadas: {n_figuras}")
    print("Errores críticos: 0")
    logging.info("Fin del análisis.")


if __name__ == "__main__":
    main()
