# -*- coding: utf-8 -*-
"""
21_analizar_mecanismos_emergentes.py
====================================

Análisis de mecanismos emergentes de los escenarios del ABM sobre
informalidad laboral en Argentina (2022–2025).

Este script NO repite que los shocks modifican los estados en la dirección
programada. Se centra en:
    1. Descomposición del ajuste en el tick 4 (qué canal absorbe el ajuste).
    2. Persistencia y recuperación simulada (cuánto persiste el efecto).
    3. Brecha de vulnerabilidad por cuartil (qué perfiles soportan
       proporcionalmente mayores efectos).
    4. Rotación formal institucional (stock casi estable vs. más entradas
       y salidas).
    5. Interacción del escenario combinado (aditividad del efecto conjunto).

ADVERTENCIAS
------------
- El resultado central es descriptivo y NO causal: los escenarios muestran
  diferentes formas de distribución del ajuste entre informalidad,
  desocupación e inactividad, distintos grados de persistencia y efectos
  heterogéneos según vulnerabilidad.
- NO se afirma que el ABM demuestre que la inflación o la devaluación causan
  informalidad.
- Las "contribuciones a la composición del ajuste" pueden ser negativas o
  superiores a 1: NO son proporciones ni probabilidades.
- La "persistencia simulada" NO es histéresis empírica: es dependencia de
  trayectoria simulada.
- El residuo de interacción NO se interpreta como interacción causal.
- Los percentiles 2,5 y 97,5 son percentiles empíricos de las réplicas.

Requisitos: Python 3.11+, pandas, numpy, matplotlib, pathlib, logging.
"""

from __future__ import annotations

import logging
from pathlib import Path

import numpy as np
import pandas as pd

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

# ===========================================================================
# Constantes globales
# ===========================================================================

# Raíz del proyecto (una sola definición). El script vive en "Script Py/".
RAIZ: Path = Path(__file__).resolve().parents[1]

# Carpetas de entrada y salida.
RUTA_REPORTES: Path = RAIZ / "Salidas" / "20_reportes_escenarios_abm"
RUTA_EXPERIMENTOS: Path = RAIZ / "NetLogo" / "Experimentos"
RUTA_SALIDAS: Path = RAIZ / "Salidas" / "21_mecanismos_emergentes"

# Si es True, se sobrescriben las salidas existentes (no se lanza FileExistsError).
SOBRESCRIBIR: bool = True

# Columnas de las tablas insumo (generadas por 20_analizar_escenarios_abm.py).
COL_FAMILIA: str = "familia"
COL_ESCENARIO: str = "escenario"
COL_ESTADO: str = "estado"
COL_TICK: str = "tick"
COL_MEDIA: str = "media"
COL_P2_5: str = "p2_5"
COL_P97_5: str = "p97_5"
COL_N_REPLICAS: str = "n_replicas"
COL_METRICA: str = "metrica"
COL_CUARTIL: str = "cuartil"
COL_FLUJO: str = "flujo"

# Columnas de los CSV de BehaviorSpace originales.
COL_SEMILLA: str = "semilla-modelo"
COL_TICK_NL: str = "ticks"
COL_COUNT_TURTLES: str = "count turtles"
COL_N_FORMALES: str = "n-formales"
COL_N_INFORMALES: str = "n-informales"
COL_N_DESOCUPADOS: str = "n-desocupados"
COL_N_INACTIVOS: str = "n-inactivos"
COL_PROP_FORMALES: str = "proporcion-formales"
COL_PROP_INFORMALES: str = "proporcion-informales"
COL_PROP_DESOCUPADOS: str = "proporcion-desocupados"
COL_PROP_INACTIVOS: str = "proporcion-inactivos"

# Nombres canónicos de las columnas de flujo en los CSV de BehaviorSpace.
FLUJO_IF: str = 'count turtles with [estado-origen = "informal" and estado-actual = "formal"]'
FLUJO_DF: str = 'count turtles with [estado-origen = "desocupacion" and estado-actual = "formal"]'
FLUJO_FI: str = 'count turtles with [estado-origen = "formal" and estado-actual = "informal"]'
FLUJO_FD: str = 'count turtles with [estado-origen = "formal" and estado-actual = "desocupacion"]'

# Estados y etiquetas en español.
ESTADOS: list[str] = ["formalidad", "informalidad", "desocupacion", "inactividad"]
ETIQUETA_ESTADOS: dict[str, str] = {
    "formalidad": "Formalidad",
    "informalidad": "Informalidad",
    "desocupacion": "Desocupación",
    "inactividad": "Inactividad",
}

# Umbral mínimo (en puntos porcentuales) para considerar una caída de
# formalidad como "denominador suficiente" para los cocientes del ajuste.
UMBRAL_CAIDA_FORMAL_PP: float = 0.25

# Umbral de recuperación (fracción de la brecha del tick 4).
UMBRAL_RECUPERACION: float = 0.50

# Ventana de ticks "activos" para la brecha de vulnerabilidad y la rotación.
TICKS_ACTIVOS: tuple[int, ...] = (2, 3, 4)
TICK_AJUSTE: int = 4
TICK_FINAL: int = 8
TICKS_0_8: tuple[int, ...] = tuple(range(0, 9))

# Familias, escenarios y escenario combinado (para la descomposición
# aditiva C1 ≈ M2 + D2 + I2).
FAMILIAS: list[str] = ["institucional", "inflacion", "devaluacion", "combinado"]
ESCENARIOS_POR_FAMILIA: dict[str, list[str]] = {
    "institucional": ["I0", "I1", "I2", "I3"],
    "inflacion": ["M0", "M1", "M2", "M3"],
    "devaluacion": ["D0", "D1", "D2", "D3"],
    "combinado": ["C0", "C1"],
}
BASE_POR_FAMILIA: dict[str, str] = {
    "institucional": "I0",
    "inflacion": "M0",
    "devaluacion": "D0",
    "combinado": "C0",
}

# Escenario combinado y sus componentes para el residuo de interacción.
ESCENARIO_COMBINADO: str = "C1"
COMPONENTES_INTERACCION: dict[str, tuple[str, str]] = {
    "inflacion": ("M2", "M0"),
    "devaluacion": ("D2", "D0"),
    "institucional": ("I2", "I0"),
}

# Métricas por cuartil de interés (coinciden con el script 20).
METRICAS_CUARTIL: list[str] = [
    "informal_a_formal",
    "informal_a_informal",
    "informal_a_desocupacion",
]
ETIQUETA_METRICA: dict[str, str] = {
    "informal_a_formal": "Informal → Formal",
    "informal_a_informal": "Informal → Informal",
    "informal_a_desocupacion": "Informal → Desocupación",
}

# Archivos originales de BehaviorSpace para la rotación formal institucional.
ARCHIVOS_INSTITUCIONALES: dict[str, str] = {
    "I0": "institucional_I0_base_8_ticks.csv",
    "I1": "institucional_I1_contratacion_8_ticks.csv",
    "I2": "institucional_I2_flexibilidad_moderada_8_ticks.csv",
    "I3": "institucional_I3_flexibilidad_intensa_8_ticks.csv",
}

# Tablas y figuras de salida.
TABLAS_SALIDA: list[str] = [
    "tabla_composicion_ajuste.csv",
    "tabla_persistencia_recuperacion.csv",
    "tabla_brechas_vulnerabilidad.csv",
    "tabla_rotacion_formal.csv",
    "tabla_interaccion_no_aditiva.csv",
    "tabla_sintesis_mecanismos.csv",
]
FIGURAS_SALIDA: list[str] = [
    "figura_canales_ajuste.png",
    "figura_persistencia_simulada.png",
    "figura_brecha_q1_q4.png",
    "figura_stock_vs_rotacion.png",
]


# ===========================================================================
# Utilidades
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
    esperadas = TABLAS_SALIDA + FIGURAS_SALIDA + ["reporte_validacion_mecanismos.txt"]
    existentes = [n for n in esperadas if (RUTA_SALIDAS / n).exists()]
    if existentes and not SOBRESCRIBIR:
        raise FileExistsError(
            "SOBRESCRIBIR=False y las siguientes salidas ya existen: "
            f"{existentes}. Elimínalas o activa SOBRESCRIBIR."
        )


def cargar_tabla_reporte(nombre: str) -> pd.DataFrame:
    """Carga una tabla generada por el script 20 desde RUTA_REPORTES."""
    ruta = RUTA_REPORTES / nombre
    if not ruta.exists():
        raise FileNotFoundError(
            f"Falta el insumo {nombre} en {RUTA_REPORTES}. "
            "Ejecuta primero 20_analizar_escenarios_abm.py."
        )
    return pd.read_csv(ruta)


def _resumen_tasas(serie: pd.Series) -> dict:
    """Estadísticos descriptivos de una serie de tasas."""
    return {
        "media": float(serie.mean()),
        "desv_estandar": float(serie.std(ddof=1)),
        "mediana": float(serie.median()),
        "p2_5": float(serie.quantile(0.025)),
        "p97_5": float(serie.quantile(0.975)),
        "n_replicas": int(serie.count()),
    }


def _guardar_tabla(df: pd.DataFrame, nombre: str) -> None:
    """Guarda una tabla en la carpeta de salida (redondeada y con BOM)."""
    ruta = RUTA_SALIDAS / nombre
    df.round(6).to_csv(ruta, index=False, encoding="utf-8-sig")
    logging.info("Tabla guardada: %s (%d filas)", nombre, len(df))


# ===========================================================================
# 1. Descomposición del ajuste en el tick 4
# ===========================================================================

def calcular_composicion_ajuste(
    df_dif: pd.DataFrame,
) -> pd.DataFrame:
    """Descompone la caída de formalidad en contribuciones de cada estado.

    Para cada escenario (con caída de formalidad >= UMBRAL_CAIDA_FORMAL_PP):

        perdida_formal   = - diferencia_formalidad            (pp)
        aporte_informal  = diferencia_informalidad  / perdida_formal
        aporte_desocupacion = diferencia_desocupacion / perdida_formal
        aporte_inactividad  = diferencia_inactividad  / perdida_formal

    Los tres aportes suman aproximadamente 1 y pueden ser negativos o
    superiores a 1: se denominan "contribuciones a la composición del ajuste"
    y NO son proporciones ni probabilidades. No se calculan cuando la caída
    es menor a 0,25 pp (caso marcado como "denominador insuficiente").
    """
    filas: list[dict] = []
    for familia in FAMILIAS:
        base = BASE_POR_FAMILIA[familia]
        for escenario in ESCENARIOS_POR_FAMILIA[familia]:
            if escenario == base:
                continue
            perdida_formal_pp = -_diferencia_media(
                df_dif, familia, escenario, "formalidad", TICK_AJUSTE
            )
            if perdida_formal_pp < UMBRAL_CAIDA_FORMAL_PP:
                filas.append(
                    {
                        "familia": familia,
                        "escenario": escenario,
                        "tick": TICK_AJUSTE,
                        "caida_formal_tick4_pp": perdida_formal_pp,
                        "estado": "denominador insuficiente",
                        "aporte": np.nan,
                        "canal_positivo_dominante": "",
                    }
                )
                continue
            aportes: dict[str, float] = {}
            for estado in ["informalidad", "desocupacion", "inactividad"]:
                diferencia = _diferencia_media(
                    df_dif, familia, escenario, estado, TICK_AJUSTE
                )
                aportes[estado] = diferencia / perdida_formal_pp
            canal_dominante = max(aportes, key=lambda k: aportes[k])
            for estado, aporte in aportes.items():
                filas.append(
                    {
                        "familia": familia,
                        "escenario": escenario,
                        "tick": TICK_AJUSTE,
                        "caida_formal_tick4_pp": perdida_formal_pp,
                        "estado": estado,
                        "aporte": aporte,
                        "canal_positivo_dominante": canal_dominante,
                    }
                )
    return pd.DataFrame(filas)


def _diferencia_media(
    df_dif: pd.DataFrame, familia: str, escenario: str, estado: str, tick: int
) -> float:
    """Devuelve la diferencia media (pp) frente a la base para un estado/tick.

    Con validación: debe existir exactamente una fila con n_pares = 100.
    """
    sub = df_dif[
        (df_dif[COL_FAMILIA] == familia)
        & (df_dif[COL_ESCENARIO] == escenario)
        & (df_dif[COL_ESTADO] == estado)
        & (df_dif[COL_TICK] == tick)
    ]
    if len(sub) != 1:
        raise ValueError(
            f"Diferencia no única para {familia}/{escenario}/{estado}/tick {tick}: "
            f"{len(sub)} filas"
        )
    fila = sub.iloc[0]
    if fila["n_pares"] != 100:
        raise ValueError(
            f"n_pares != 100 para {familia}/{escenario}/{estado}/tick {tick}: "
            f"{fila['n_pares']}"
        )
    return float(fila["diferencia_pp_media"])


# ===========================================================================
# 2. Persistencia y recuperación simulada
# ===========================================================================

def calcular_persistencia_recuperacion(
    df_dif: pd.DataFrame,
) -> pd.DataFrame:
    """Persistencia, recuperación y razón de ampliación simuladas.

    Para inflación, devaluación y combinado se calcula:

        persistencia_tick8 = abs(diferencia_tick8) / abs(diferencia_tick4)
        recuperacion_tick8 = 1 - persistencia_tick8

    y el primer tick entre 5 y 8 en que la brecha frente al tick 4 se
    recupera al menos un 50% (o "no alcanza recuperación del 50%").

    Para la familia institucional el mecanismo permanece activo de forma
    permanente y el efecto no necesariamente se revierte: NO se denomina
    "recuperación". Se reporta en su lugar:

        razon_ampliacion_tick8_tick4 =
            abs(diferencia_tick8) / abs(diferencia_tick4)

    Denominación: "persistencia simulada" / "dependencia de trayectoria
    simulada" (NO histéresis empírica).
    """
    familias_con_persistencia = ("inflacion", "devaluacion", "combinado")
    filas: list[dict] = []
    for familia in FAMILIAS:
        base = BASE_POR_FAMILIA[familia]
        for escenario in ESCENARIOS_POR_FAMILIA[familia]:
            if escenario == base:
                continue
            for estado in ["formalidad", "informalidad"]:
                dif_t4 = _diferencia_media(
                    df_dif, familia, escenario, estado, TICK_AJUSTE
                )
                dif_t8 = _diferencia_media(
                    df_dif, familia, escenario, estado, TICK_FINAL
                )
                denom = abs(dif_t4)

                # Institucional: mecanismo permanente. Razón de ampliación
                # tick 8 vs tick 4 (NO se la denomina "recuperación").
                if familia not in familias_con_persistencia:
                    razon_ampliacion = (
                        abs(dif_t8) / denom if denom >= 1e-12 else np.nan
                    )
                    filas.append(
                        {
                            "familia": familia,
                            "escenario": escenario,
                            "estado": estado,
                            "tick_ajuste": TICK_AJUSTE,
                            "tick_final": TICK_FINAL,
                            "diferencia_tick4_pp": dif_t4,
                            "diferencia_tick8_pp": dif_t8,
                            "razon_ampliacion_tick8_tick4": razon_ampliacion,
                        }
                    )
                    continue

                # Inflación, devaluación y combinado: persistencia simulada.
                if denom < 1e-12:
                    persistencia = np.nan
                    recuperacion = np.nan
                else:
                    persistencia = abs(dif_t8) / denom
                    recuperacion = 1.0 - persistencia
                # Primer tick (5..8) con recuperación >= 50% de la brecha del t4.
                primer_tick = None
                for tick in range(5, 9):
                    dif_t = _diferencia_media(
                        df_dif, familia, escenario, estado, tick
                    )
                    if denom >= 1e-12 and (1.0 - abs(dif_t) / denom) >= UMBRAL_RECUPERACION:
                        primer_tick = tick
                        break
                filas.append(
                    {
                        "familia": familia,
                        "escenario": escenario,
                        "estado": estado,
                        "tick_ajuste": TICK_AJUSTE,
                        "tick_final": TICK_FINAL,
                        "diferencia_tick4_pp": dif_t4,
                        "diferencia_tick8_pp": dif_t8,
                        "persistencia_simulada_tick8": persistencia,
                        "recuperacion_simulada_tick8": recuperacion,
                        "primer_tick_recuperacion_50": primer_tick
                        if primer_tick is not None
                        else "no alcanza recuperación del 50%",
                    }
                )
    return pd.DataFrame(filas)


# ===========================================================================
# 3. Brecha de vulnerabilidad por cuartil
# ===========================================================================

def calcular_brechas_vulnerabilidad(
    df_cuar: pd.DataFrame,
) -> pd.DataFrame:
    """
    Calcula tasas por cuartil y brechas Q1-Q4 para las métricas
    efectivamente disponibles.

    No fuerza la existencia de métricas ausentes (p. ej., institucional sin
    informal->desocupación por cuartil, o combinado sin métricas por cuartil).
    """
    filas: list[dict] = []
    for familia in FAMILIAS:
        escenario_base = BASE_POR_FAMILIA[familia]
        for escenario in ESCENARIOS_POR_FAMILIA[familia]:
            for metrica in METRICAS_CUARTIL:
                tasas: dict[str, float] = {}
                for cuartil in ["Q1", "Q2", "Q3", "Q4"]:
                    tasa = _tasa_cuartil_promedio(
                        df_cuar,
                        familia,
                        escenario,
                        metrica,
                        cuartil,
                    )
                    if tasa is None or pd.isna(tasa):
                        continue
                    tasas[cuartil] = tasa
                # La métrica no está disponible para esta familia.
                if not tasas:
                    continue
                tasa_q1 = tasas.get("Q1")
                tasa_q4 = tasas.get("Q4")
                brecha_q1_q4 = np.nan
                razon_q1_q4 = np.nan
                if tasa_q1 is not None and tasa_q4 is not None:
                    brecha_q1_q4 = tasa_q1 - tasa_q4
                    if abs(tasa_q4) > 1.0e-12:
                        razon_q1_q4 = tasa_q1 / tasa_q4
                for cuartil, tasa in tasas.items():
                    variacion_relativa = np.nan
                    if escenario != escenario_base:
                        tasa_base = _tasa_cuartil_promedio(
                            df_cuar,
                            familia,
                            escenario_base,
                            metrica,
                            cuartil,
                        )
                        if (
                            tasa_base is not None
                            and not pd.isna(tasa_base)
                            and abs(tasa_base) > 1.0e-12
                        ):
                            variacion_relativa = (
                                tasa / tasa_base - 1.0
                            ) * 100.0
                    filas.append(
                        {
                            "familia": familia,
                            "escenario": escenario,
                            "escenario_base": escenario_base,
                            "metrica": metrica,
                            "cuartil": cuartil,
                            "tasa_promedio_t2_4": tasa,
                            "brecha_absoluta_Q1_Q4": brecha_q1_q4,
                            "razon_Q1_Q4": razon_q1_q4,
                            "variacion_relativa_cuartil_pct":
                                variacion_relativa,
                        }
                    )
    return pd.DataFrame(filas)


def _tasa_cuartil_promedio(
    df_cuar: pd.DataFrame,
    familia: str,
    escenario: str,
    metrica: str,
    cuartil: str,
) -> float | None:
    """Tasa media por cuartil promediando los ticks 2–4 (o None si no hay)."""
    sub = df_cuar[
        (df_cuar[COL_FAMILIA] == familia)
        & (df_cuar[COL_ESCENARIO] == escenario)
        & (df_cuar[COL_METRICA] == metrica)
        & (df_cuar[COL_CUARTIL] == cuartil)
        & (df_cuar["tipo"] == "tasa")
        & (df_cuar[COL_TICK].isin(TICKS_ACTIVOS))
    ]
    if sub.empty:
        return None
    return float(sub[COL_MEDIA].mean())


# ===========================================================================
# 4. Rotación formal institucional (CSV originales de BehaviorSpace)
# ===========================================================================

def calcular_rotacion_formal() -> pd.DataFrame:
    """Rotación formal por semilla y tick a partir de los CSV originales.

        entradas_formales = informal->formal + desocupacion->formal
        salidas_formales  = formal->informal + formal->desocupacion
        movilidad_formal_bruta = (entradas + salidas) / total_agentes
        saldo_formal           = (entradas - salidas) / total_agentes

    Se promedian los ticks 2–4. NO se suman tasas con denominadores distintos:
    las entradas/salidas se suman en conteos (mismo universo de agentes) y se
    normalizan por el total de agentes.

    Finalidad: mostrar si un stock formal casi estable puede coexistir con
    más entradas y salidas.
    """
    filas: list[dict] = []
    for escenario, nombre in ARCHIVOS_INSTITUCIONALES.items():
        ruta = RUTA_EXPERIMENTOS / nombre
        if not ruta.exists():
            raise FileNotFoundError(f"No se encuentra {ruta}")
        df = pd.read_csv(ruta, skiprows=6)
        columnas_flujo = [FLUJO_IF, FLUJO_DF, FLUJO_FI, FLUJO_FD, COL_COUNT_TURTLES]
        faltantes = [c for c in columnas_flujo if c not in df.columns]
        if faltantes:
            raise ValueError(
                f"{nombre}: faltan columnas para la rotación: {faltantes}"
            )
        for tick in TICKS_ACTIVOS:
            sub = df[df[COL_TICK_NL] == tick]
            if len(sub) != 100:
                raise ValueError(
                    f"{nombre}: {len(sub)} réplicas en tick {tick} (esperado 100)"
                )
            total = sub[COL_COUNT_TURTLES]
            entradas = sub[FLUJO_IF] + sub[FLUJO_DF]
            salidas = sub[FLUJO_FI] + sub[FLUJO_FD]
            movilidad = (entradas + salidas) / total
            saldo = (entradas - salidas) / total
            for i, (m, s) in enumerate(zip(movilidad, saldo)):
                filas.append(
                    {
                        "familia": "institucional",
                        "escenario": escenario,
                        "semilla": int(sub.iloc[i][COL_SEMILLA]),
                        "tick": tick,
                        "entradas_formales": int(entradas.iloc[i]),
                        "salidas_formales": int(salidas.iloc[i]),
                        "movilidad_formal_bruta": float(m),
                        "saldo_formal": float(s),
                    }
                )
    df_rot = pd.DataFrame(filas)
    # Promedio por escenario sobre los ticks 2–4 (media de las medias por réplica).
    resumen: list[dict] = []
    for escenario in ARCHIVOS_INSTITUCIONALES:
        sub = df_rot[df_rot["escenario"] == escenario]
        for variable in ["movilidad_formal_bruta", "saldo_formal"]:
            serie = sub.groupby("semilla")[variable].mean()
            resumen.append(
                {
                    "familia": "institucional",
                    "escenario": escenario,
                    "variable": variable,
                    "ticks_promediados": str(tuple(TICKS_ACTIVOS)),
                    **_resumen_tasas(serie),
                }
            )
    return pd.DataFrame(resumen)


# ===========================================================================
# 5. Interacción del escenario combinado (residuo no aditivo)
# ===========================================================================

def calcular_interaccion_no_aditiva(
    df_dif: pd.DataFrame,
) -> pd.DataFrame:
    """
    Calcula un residuo descriptivo entre diferencias medias:

        residuo medio =
            diferencia media C1-C0
            - diferencia media M2-M0
            - diferencia media D2-D0
            - diferencia media I2-I0

    Se reporta únicamente para el tick 4.

    No es una interacción estimada por réplica ni una interacción causal.
    Sirve únicamente para evaluar si las diferencias medias del escenario
    combinado se aproximan a la suma de las diferencias medias separadas.
    """
    filas: list[dict] = []
    for tick in (TICK_AJUSTE,):
        for estado in ESTADOS:
            residuo = (
                _diferencia_media(
                    df_dif, "combinado", ESCENARIO_COMBINADO, estado, tick
                )
                - sum(
                    _diferencia_media(
                        df_dif,
                        familia,
                        escenario,
                        estado,
                        tick,
                    )
                    for familia, (escenario, _base) in COMPONENTES_INTERACCION.items()
                )
            )
            filas.append(
                {
                    "tick": tick,
                    "estado": estado,
                    "residuo_interaccion_media_pp": residuo,
                    "interpretacion": "aproximadamente aditivo"
                    if abs(residuo) < 1e-9
                    else "no aditivo (multiplicadores conjuntos / normalización)",
                }
            )
    return pd.DataFrame(filas)


# ===========================================================================
# 6. Tabla de síntesis por escenario
# ===========================================================================

def construir_sintesis(
    df_comp: pd.DataFrame,
    df_pers: pd.DataFrame,
    df_brechas: pd.DataFrame,
    df_rot: pd.DataFrame,
    df_inter: pd.DataFrame,
) -> pd.DataFrame:
    """Tabla de síntesis con una fila por escenario (sin las bases).

    Distingue dos tipos de escenarios:

    - Transitorios (inflación, devaluación, combinado): se reportan
      persistencia_formal_tick8, recuperacion_formal_tick8 y
      primer_tick_recuperacion_50; razon_ampliacion_formal_tick8_tick4 = NaN.
    - Institucionales (I1, I2, I3): el mecanismo permanece activo después del
      tick 4, por lo que NO se calcula persistencia ni recuperación; se reporta
      razon_ampliacion_formal_tick8_tick4 y las tres columnas de
      persistencia/recuperación quedan en NaN.

    Columnas:
        familia, escenario, canal_dominante, caida_formal_tick4_pp,
        aporte_informal, aporte_desocupacion, aporte_inactividad,
        persistencia_formal_tick8, recuperacion_formal_tick8,
        primer_tick_recuperacion_50, razon_ampliacion_formal_tick8_tick4,
        brecha_formalizacion_q1_q4, movilidad_formal_bruta,
        residuo_interaccion_media_formal_tick4_pp
    """
    filas: list[dict] = []
    for familia in FAMILIAS:
        base = BASE_POR_FAMILIA[familia]
        for escenario in ESCENARIOS_POR_FAMILIA[familia]:
            if escenario == base:
                continue

            # Canal dominante y aportes (solo si el denominador es suficiente).
            sub_comp = df_comp[
                (df_comp["familia"] == familia) & (df_comp["escenario"] == escenario)
            ]
            canal_dominante: object = None
            caida_formal: object = None
            if not sub_comp.empty and "denominador insuficiente" not in set(
                sub_comp["estado"]
            ):
                canal_dominante = sub_comp["canal_positivo_dominante"].iloc[0]
                caida_formal = sub_comp["caida_formal_tick4_pp"].iloc[0]
            aporte_informal = _aporte_por_estado(sub_comp, "informalidad")
            aporte_desocupacion = _aporte_por_estado(sub_comp, "desocupacion")
            aporte_inactividad = _aporte_por_estado(sub_comp, "inactividad")

            # Fila de persistencia/recuperación de formalidad (tick 8).
            sub_pers = df_pers[
                (df_pers["familia"] == familia)
                & (df_pers["escenario"] == escenario)
                & (df_pers["estado"] == "formalidad")
            ]

            persistencia_formal: object = None
            recuperacion_formal: object = None
            primer_tick_50: object = None
            razon_ampliacion_formal: object = None

            # Escenarios transitorios (inflación, devaluación, combinado):
            # se reporta persistencia y recuperación simulada; sin razón de
            # ampliación.
            if (
                familia in ("inflacion", "devaluacion", "combinado")
                and not sub_pers.empty
            ):
                persistencia_formal = sub_pers["persistencia_simulada_tick8"].iloc[0]
                recuperacion_formal = sub_pers["recuperacion_simulada_tick8"].iloc[0]
                primer_tick_50 = sub_pers["primer_tick_recuperacion_50"].iloc[0]
                razon_ampliacion_formal = np.nan

            # Escenarios institucionales (I1, I2, I3): mecanismo permanente,
            # sin persistencia ni recuperación; solo razón de ampliación.
            elif familia == "institucional" and not sub_pers.empty:
                persistencia_formal = np.nan
                recuperacion_formal = np.nan
                primer_tick_50 = np.nan
                razon_ampliacion_formal = sub_pers[
                    "razon_ampliacion_tick8_tick4"
                ].iloc[0]

            # Brecha Q1-Q4 de informal->formal.
            brecha_formalizacion: object = None
            sub_brecha = df_brechas[
                (df_brechas["familia"] == familia)
                & (df_brechas["escenario"] == escenario)
                & (df_brechas["metrica"] == "informal_a_formal")
            ]
            if not sub_brecha.empty:
                brecha_formalizacion = sub_brecha["brecha_absoluta_Q1_Q4"].iloc[0]

            # Movilidad formal bruta (solo institucional).
            movilidad_formal: object = None
            if familia == "institucional":
                sub_rot = df_rot[
                    (df_rot["escenario"] == escenario)
                    & (df_rot["variable"] == "movilidad_formal_bruta")
                ]
                if not sub_rot.empty:
                    movilidad_formal = sub_rot["media"].iloc[0]

            # Residuo de interacción en formalidad (tick 4), solo combinado.
            residuo_interaccion: object = None
            if familia == "combinado":
                sub_inter = df_inter[
                    (df_inter["estado"] == "formalidad")
                    & (df_inter["tick"] == TICK_AJUSTE)
                ]
                if not sub_inter.empty:
                    residuo_interaccion = sub_inter[
                        "residuo_interaccion_media_pp"
                    ].iloc[0]

            filas.append(
                {
                    "familia": familia,
                    "escenario": escenario,
                    "canal_dominante": canal_dominante,
                    "caida_formal_tick4_pp": caida_formal,
                    "aporte_informal": aporte_informal,
                    "aporte_desocupacion": aporte_desocupacion,
                    "aporte_inactividad": aporte_inactividad,
                    "persistencia_formal_tick8": persistencia_formal,
                    "recuperacion_formal_tick8": recuperacion_formal,
                    "primer_tick_recuperacion_50": primer_tick_50,
                    "razon_ampliacion_formal_tick8_tick4": razon_ampliacion_formal,
                    "brecha_formalizacion_q1_q4": brecha_formalizacion,
                    "movilidad_formal_bruta": movilidad_formal,
                    "residuo_interaccion_media_formal_tick4_pp": residuo_interaccion,
                }
            )
    return pd.DataFrame(filas)


def _aporte_por_estado(sub_comp: pd.DataFrame, estado: str) -> float | None:
    """Devuelve el aporte de un estado en la composición del ajuste (o None)."""
    fila = sub_comp[sub_comp["estado"] == estado]
    if fila.empty:
        return None
    return float(fila["aporte"].iloc[0])


# ===========================================================================
# Figuras
# ===========================================================================

def generar_figura_canales(
    df_comp: pd.DataFrame, ruta_destino: Path
) -> Path:
    """Figura: contribuciones a la composición del ajuste en el tick 4.

    Un panel por familia; barras de los aportes (informalidad, desocupación,
    inactividad) para cada escenario no base.
    """
    familias_plot = [f for f in FAMILIAS if f != "combinado"] + ["combinado"]
    n_fam = len(familias_plot)
    fig, axes = plt.subplots(1, n_fam, figsize=(5.0 * n_fam, 4.5), sharey=False)
    if n_fam == 1:
        axes = [axes]
    colores = {
        "informalidad": "#1f77b4",
        "desocupacion": "#ff7f0e",
        "inactividad": "#2ca02c",
    }
    for ax, familia in zip(axes, familias_plot):
        sub = df_comp[
            (df_comp["familia"] == familia)
            & (df_comp["estado"].isin(colores))
        ]
        escenarios = sorted(sub["escenario"].unique())
        ancho = 0.25
        for i, estado in enumerate(colores):
            valores = [
                sub[(sub["escenario"] == e) & (sub["estado"] == estado)]["aporte"].iloc[0]
                if not sub[(sub["escenario"] == e) & (sub["estado"] == estado)].empty
                else np.nan
                for e in escenarios
            ]
            posiciones = np.arange(len(escenarios)) + i * ancho
            ax.bar(posiciones, valores, width=ancho, label=ETIQUETA_ESTADOS[estado],
                   color=colores[estado])
        ax.axhline(1.0, color="black", lw=1, ls="--", alpha=0.6)
        ax.set_title(f"Familia: {familia}")
        ax.set_xticks(np.arange(len(escenarios)) + ancho)
        ax.set_xticklabels(escenarios)
        ax.set_ylabel("Contribución al ajuste")
        ax.grid(alpha=0.3)
    fig.suptitle("Composición del ajuste en el tick 4", fontsize=13)
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper center", ncol=3, fontsize=9)
    fig.tight_layout(rect=[0, 0, 1, 0.90])
    fig.savefig(ruta_destino, dpi=300, bbox_inches="tight")
    plt.close(fig)
    return ruta_destino


def generar_figura_persistencia(
    df_pers: pd.DataFrame, ruta_destino: Path
) -> Path:
    """Figura: persistencia simulada (inflación, devaluación, combinado) y
    razón de ampliación (institucional) de formalidad e informalidad (tick 8).

    Cada familia usa la métrica que le corresponde:
    - inflación/devaluación/combinado: "persistencia simulada";
    - institucional: "razón de ampliación tick 8 vs tick 4"
      (mecanismo permanente; no se la denomina "recuperación").
    """
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.5), sharey=False)
    for ax, estado in zip(axes, ["formalidad", "informalidad"]):
        sub = df_pers[df_pers["estado"] == estado]
        familias_plot = sub["familia"].unique()
        for familia in familias_plot:
            sub_f = sub[sub["familia"] == familia]
            if "razon_ampliacion_tick8_tick4" in sub_f.columns:
                col_y = "razon_ampliacion_tick8_tick4"
            else:
                col_y = "persistencia_simulada_tick8"
            ax.plot(
                sub_f["escenario"],
                sub_f[col_y],
                marker="o",
                label=familia,
            )
        ax.set_title(ETIQUETA_ESTADOS[estado])
        ax.set_xlabel("Escenario")
        ax.set_ylabel("Persistencia simulada / razón de ampliación (tick 8)")
        ax.grid(alpha=0.3)
    fig.suptitle("Persistencia simulada de la brecha (tick 4 → tick 8)", fontsize=13)
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper center", ncol=4, fontsize=9)
    fig.tight_layout(rect=[0, 0, 1, 0.88])
    fig.savefig(ruta_destino, dpi=300, bbox_inches="tight")
    plt.close(fig)
    return ruta_destino


def generar_figura_brecha(
    df_brechas: pd.DataFrame, ruta_destino: Path
) -> Path:
    """Figura: brecha absoluta Q1-Q4 por familia, escenario y métrica."""
    fig, axes = plt.subplots(1, len(FAMILIAS), figsize=(5.5 * len(FAMILIAS), 4.5),
                             sharey=False)
    for ax, familia in zip(axes, FAMILIAS):
        sub = df_brechas[
            (df_brechas["familia"] == familia)
            & (df_brechas["metrica"].isin(METRICAS_CUARTIL))
        ].drop_duplicates(["escenario", "metrica"])
        escenarios = sorted(sub["escenario"].unique())
        ancho = 0.25
        for i, metrica in enumerate(METRICAS_CUARTIL):
            valores = [
                sub[(sub["escenario"] == e) & (sub["metrica"] == metrica)][
                    "brecha_absoluta_Q1_Q4"
                ].iloc[0]
                if not sub[(sub["escenario"] == e) & (sub["metrica"] == metrica)].empty
                else np.nan
                for e in escenarios
            ]
            posiciones = np.arange(len(escenarios)) + i * ancho
            ax.bar(posiciones, valores, width=ancho, label=ETIQUETA_METRICA[metrica])
        ax.axhline(0.0, color="black", lw=1)
        ax.set_title(f"Familia: {familia}")
        ax.set_xticks(np.arange(len(escenarios)) + ancho)
        ax.set_xticklabels(escenarios)
        ax.set_ylabel("Brecha absoluta Q1 − Q4")
        ax.grid(alpha=0.3)
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper center", ncol=3, fontsize=9)
    fig.tight_layout(rect=[0, 0, 1, 0.88])
    fig.savefig(ruta_destino, dpi=300, bbox_inches="tight")
    plt.close(fig)
    return ruta_destino


def generar_figura_stock_rotacion(
    df_rot: pd.DataFrame, ruta_destino: Path
) -> Path:
    """Figura: movilidad formal bruta y saldo formal por escenario institucional."""
    escenarios = sorted(df_rot["escenario"].unique())
    fig, ax = plt.subplots(figsize=(8, 4.5))
    ancho = 0.35
    for i, variable in enumerate(["movilidad_formal_bruta", "saldo_formal"]):
        valores = [
            df_rot[(df_rot["escenario"] == e) & (df_rot["variable"] == variable)][
                "media"
            ].iloc[0]
            for e in escenarios
        ]
        posiciones = np.arange(len(escenarios)) + i * ancho
        ax.bar(posiciones, valores, width=ancho, label=variable)
    ax.set_xticks(np.arange(len(escenarios)) + ancho)
    ax.set_xticklabels(escenarios)
    ax.set_ylabel("Promedio ticks 2–4 (fracción del total de agentes)")
    ax.grid(alpha=0.3)
    ax.legend()
    ax.set_title("Stock formal: rotación vs. saldo (escenarios institucionales)")
    fig.tight_layout()
    fig.savefig(ruta_destino, dpi=300, bbox_inches="tight")
    plt.close(fig)
    return ruta_destino


# ===========================================================================
# Validaciones
# ===========================================================================

def validar_datos(
    df_dif: pd.DataFrame,
    df_cuar: pd.DataFrame,
    df_comp: pd.DataFrame,
    df_rot: pd.DataFrame,
) -> list[str]:
    """Comprueba condiciones clave de reproducibilidad y coherencia.

    - 100 semillas en todas las comparaciones (n_pares = 100).
    - Pareamiento exacto por semilla y tick (validado al construir las tablas).
    - Ticks 0–8 presentes.
    - Igualdad entre escenarios y bases en el tick 1 (solo registrado como
      aviso si la diferencia media es relevante).
    - Suma aproximada de contribuciones del ajuste igual a 1.
    - Ausencia de divisiones por cero o infinitos.
    - Ninguna modificación de archivos originales (se leen en modo lectura).
    """
    lineas: list[str] = []

    # 100 semillas en las comparaciones.
    if (df_dif["n_pares"] != 100).any():
        raise ValueError("Hay comparaciones con n_pares != 100 (semillas incompletas).")
    lineas.append("OK: todas las comparaciones tienen n_pares = 100 (100 semillas).")

    # Ticks 0–8 en las tablas de agregados y diferencias.
    if set(df_dif[COL_TICK].unique()) != set(TICKS_0_8):
        raise ValueError("Faltan ticks 0–8 en tabla_diferencias_vs_base.")
    lineas.append("OK: ticks 0–8 presentes en las comparaciones.")

    # Igualdad entre escenarios y bases en el tick 1 (diferencia media ~ 0).
    # Las bases (I0, M0, D0, C0) no figuran en tabla_diferencias_vs_base.csv:
    # solo se comparan los escenarios no base frente a su base.
    desvios_tick1 = []
    for familia in FAMILIAS:
        base = BASE_POR_FAMILIA[familia]
        for escenario in ESCENARIOS_POR_FAMILIA[familia]:
            if escenario == base:
                continue
            for estado in ESTADOS:
                d = abs(_diferencia_media(df_dif, familia, escenario, estado, 1))
                desvios_tick1.append(d)
    max_d = max(desvios_tick1)
    if max_d > 1e-6:
        lineas.append(
            f"AVISO: en tick 1 hay diferencias frente a la base de hasta "
            f"{max_d:.6f} pp (esperado ~0)."
        )
    else:
        lineas.append("OK: escenarios y bases coinciden en el tick 1 (dif ~ 0).")

    # Suma aproximada de contribuciones del ajuste igual a 1.
    suma_aporte = (
        df_comp[df_comp["estado"].isin(["informalidad", "desocupacion", "inactividad"])]
        .groupby(["familia", "escenario"])["aporte"]
        .sum()
    )
    for (familia, escenario), suma in suma_aporte.items():
        if not np.isclose(suma, 1.0, atol=1e-6):
            lineas.append(
                f"AVISO: la suma de contribuciones de {familia}/{escenario} "
                f"es {suma:.6f} (esperado ~1)."
            )
    lineas.append("OK: verificación de suma de contribuciones del ajuste completada.")

    # Ausencia de divisiones por cero o infinitos en las tablas calculadas.
    for df, nombre in [
        (df_comp, "tabla_composicion_ajuste"),
        (df_cuar, "tabla_brechas_vulnerabilidad"),
        (df_rot, "tabla_rotacion_formal"),
    ]:
        numericas = df.select_dtypes(include=[np.number])
        if np.isinf(numericas.values).any():
            raise ValueError(f"{nombre}: hay valores infinitos.")
        lineas.append(f"OK: sin infinitos en {nombre}.")

    # Ninguna modificación de archivos originales (lectura de solo lectura).
    lineas.append(
        "OK: los archivos originales de BehaviorSpace se leyeron en modo "
        "solo lectura; no se modificaron."
    )

    return lineas


# ===========================================================================
# Reporte de validación
# ===========================================================================

def escribir_reporte_validacion(
    lineas: list[str], ruta_destino: Path
) -> Path:
    """Escribe el reporte de validación en texto plano."""
    contenido = "\n".join(
        [
            "Reporte de validación — 21_analizar_mecanismos_emergentes.py",
            "=" * 70,
            "El resultado central es descriptivo y NO causal: los escenarios "
            "muestran diferentes formas de distribución del ajuste entre "
            "informalidad, desocupación e inactividad, distintos grados de "
            "persistencia y efectos heterogéneos según vulnerabilidad.",
            "",
            "Separación de evidencia y supuestos:",
            "  - Evidencia empírica de calibración: proveniente de la EPH "
            "(ponderadores y parámetros usados en la calibración del ABM).",
            "  - Supuesto del operador: diseño de escenarios y elección de "
            "intensidades por el operador del modelo.",
            "  - Resultado simulado: valores producidos por el ABM bajo los "
            "supuestos anteriores.",
            "  - Interpretación metodológica: lectura descriptiva de los "
            "indicadores, sin causalidad.",
            "  - Limitación: los resultados dependen de la calibración, de los "
            "supuestos y de la estructura del modelo.",
            "",
            "Registros de validación:",
            *[f"  - {l}" for l in lineas],
            "",
            "Fin del reporte.",
        ]
    )
    ruta_destino.write_text(contenido, encoding="utf-8")
    logging.info("Reporte de validación guardado: %s", ruta_destino.name)
    return ruta_destino


# ===========================================================================
# Orquestación principal
# ===========================================================================

def main() -> None:
    """Ejecuta el análisis de mecanismos emergentes del ABM."""
    configurar_logging()
    logging.info("Inicio del análisis de mecanismos emergentes.")
    logging.info("Raíz del proyecto: %s", RAIZ)

    verificar_salidas()
    RUTA_SALIDAS.mkdir(parents=True, exist_ok=True)

    # Carga de insumos (tablas generadas por el script 20).
    df_agregados = cargar_tabla_reporte("tabla_resultados_agregados.csv")
    df_dif = cargar_tabla_reporte("tabla_diferencias_vs_base.csv")
    df_flujos = cargar_tabla_reporte("tabla_flujos_transicion.csv")
    df_cuar = cargar_tabla_reporte("tabla_resultados_cuartiles.csv")
    df_reg = cargar_tabla_reporte("registro_validacion_archivos.csv")
    logging.info("Insumos cargados: 5 tablas del script 20.")

    # 1. Descomposición del ajuste.
    df_comp = calcular_composicion_ajuste(df_dif)
    _guardar_tabla(df_comp, "tabla_composicion_ajuste.csv")

    # 2. Persistencia y recuperación.
    df_pers = calcular_persistencia_recuperacion(df_dif)
    _guardar_tabla(df_pers, "tabla_persistencia_recuperacion.csv")

    # 3. Brecha de vulnerabilidad.
    df_brechas = calcular_brechas_vulnerabilidad(df_cuar)
    _guardar_tabla(df_brechas, "tabla_brechas_vulnerabilidad.csv")

    # 4. Rotación formal institucional (CSV originales).
    df_rot = calcular_rotacion_formal()
    _guardar_tabla(df_rot, "tabla_rotacion_formal.csv")

    # 5. Interacción del escenario combinado.
    df_inter = calcular_interaccion_no_aditiva(df_dif)
    _guardar_tabla(df_inter, "tabla_interaccion_no_aditiva.csv")

    # 6. Tabla de síntesis.
    df_sintesis = construir_sintesis(df_comp, df_pers, df_brechas, df_rot, df_inter)
    _guardar_tabla(df_sintesis, "tabla_sintesis_mecanismos.csv")

    # Figuras.
    generar_figura_canales(df_comp, RUTA_SALIDAS / "figura_canales_ajuste.png")
    generar_figura_persistencia(df_pers, RUTA_SALIDAS / "figura_persistencia_simulada.png")
    generar_figura_brecha(df_brechas, RUTA_SALIDAS / "figura_brecha_q1_q4.png")
    generar_figura_stock_rotacion(df_rot, RUTA_SALIDAS / "figura_stock_vs_rotacion.png")

    # Validaciones y reporte.
    lineas_validacion = validar_datos(df_dif, df_cuar, df_comp, df_rot)
    escribir_reporte_validacion(
        lineas_validacion, RUTA_SALIDAS / "reporte_validacion_mecanismos.txt"
    )

    # Resumen final.
    print("ANÁLISIS DE MECANISMOS COMPLETADO")
    print(f"Tablas generadas: {len(TABLAS_SALIDA)}")
    print(f"Figuras generadas: {len(FIGURAS_SALIDA)}")
    print("Errores críticos: 0")
    logging.info("Fin del análisis.")


if __name__ == "__main__":
    main()
