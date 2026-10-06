# -*- coding: utf-8 -*-
"""
19_construir_insumo_macroeconomico_trimestral.py
================================================

Construye el insumo macroeconomico trimestral para el TFM sobre
informalidad laboral en Argentina y simulacion basada en agentes (2022-2025).

Decisiones metodologicas
------------------------
1. IPC nacional
   - Nivel general, Region Nacional, Codigo "0".
   - Cierre del ultimo mes de cada trimestre.
   - Inflacion trimestral = IPC_t / IPC_t-1 - 1.
   - Diciembre de 2021 se usa como rezago de 2022T1.

2. Tipo de cambio
   - Cotizacion minorista vendedora.
   - Ultimo dia habil disponible de cada trimestre.
   - Devaluacion trimestral = dolar_t / dolar_t-1 - 1.
   - Diciembre de 2021 se usa como rezago de 2022T1.

3. SMVM
   - Se mantiene el ultimo valor vigente por mes. No se interpola.
   - Promedio nominal de los tres meses del trimestre.
   - Indice real deflactado con IPC nacional, diciembre de 2021 = 100.
   - Variacion trimestral = indice_real_t / indice_real_t-1 - 1.

4. Alcance
   - La salida final contiene exactamente 2022T1-2025T4.
   - 2021 se usa solo para rezagos y base.
   - No clasifica shocks, no genera multiplicadores y no prepara NetLogo.
"""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd


# =============================================================================
# CONFIGURACION
# =============================================================================

RAIZ_PROYECTO = Path(
    r"C:\Users\tomas\OneDrive\Master Granada\TFM"
)

CARPETA_DATOS = RAIZ_PROYECTO / "Datos"
CARPETA_SALIDA = (
    RAIZ_PROYECTO / "Salidas" / "14_escenarios_macroeconomicos"
)

ARCHIVO_IPC = CARPETA_DATOS / "serie_ipc_divisiones.csv"
ARCHIVO_DOLAR = (
    CARPETA_DATOS / "cierre_de_cotizaciones_DOLAR_2026-08-12.csv"
)
ARCHIVO_SMVM = (
    CARPETA_DATOS / "Salario mínimo en Argentina (2000–2026).txt"
)

SALIDA_TRIMESTRAL = (
    CARPETA_SALIDA
    / "insumo_macroeconomico_trimestral_2022_2025.csv"
)
SALIDA_AUDITORIA = (
    CARPETA_SALIDA
    / "auditoria_macroeconomica_mensual_2021_2025.csv"
)
SALIDA_RESUMEN = (
    CARPETA_SALIDA
    / "resumen_distribucion_shocks_2022_2025.csv"
)

ANIO_INICIO = 2022
ANIO_FIN = 2025
MES_INICIO_AUDITORIA = "2021-01"
MES_FIN_ANALISIS = "2025-12"
MES_BASE_REAL = pd.Period("2021-12", freq="M")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("insumo_macroeconomico")


# =============================================================================
# FUNCIONES AUXILIARES
# =============================================================================

def verificar_archivo(ruta: Path) -> None:
    """Comprueba que un archivo de entrada exista."""
    if not ruta.exists():
        raise FileNotFoundError(f"No se encontro el archivo: {ruta}")


def crear_carpeta_salida(ruta: Path) -> None:
    """Crea la carpeta de salida si no existe."""
    ruta.mkdir(parents=True, exist_ok=True)
    logger.info("Carpeta de salida lista: %s", ruta)


def convertir_numero_argentino(valor: object) -> float:
    """
    Convierte texto con punto de miles y coma decimal a float.

    Ejemplo: "1.517,887" se convierte en 1517.887.
    """
    if pd.isna(valor):
        return float("nan")

    texto = str(valor).strip()
    if texto.upper() in {"", "NA", "NAN", "-", "S/D", "SD"}:
        return float("nan")

    texto = texto.removesuffix(",")
    texto = texto.replace(".", "").replace(",", ".")

    try:
        return float(texto)
    except (TypeError, ValueError):
        return float("nan")


def convertir_valor_smvm(valor: object) -> float:
    """Convierte valores como '286711 ARS' a float."""
    if pd.isna(valor):
        return float("nan")

    texto = (
        str(valor)
        .strip()
        .upper()
        .replace("ARS", "")
        .replace(" ", "")
    )

    if texto in {"", "NA", "NAN", "-", "S/D", "SD"}:
        return float("nan")

    try:
        return float(texto)
    except (TypeError, ValueError):
        return float("nan")


def normalizar_fecha_periodo(periodo: object) -> pd.Period:
    """Convierte AAAAMM del IPC en un periodo mensual."""
    texto = str(periodo).strip()
    if len(texto) != 6 or not texto.isdigit():
        raise ValueError(f"Periodo IPC invalido: {periodo}")
    return pd.Period(texto, freq="M")


def filtrar_rango_mensual(
    datos: pd.DataFrame,
    columna_fecha: str,
    inicio: str,
    fin: str,
) -> pd.DataFrame:
    """Filtra periodos mensuales en el intervalo cerrado [inicio, fin]."""
    inicio_periodo = pd.Period(inicio, freq="M")
    fin_periodo = pd.Period(fin, freq="M")

    return datos.loc[
        datos[columna_fecha].between(inicio_periodo, fin_periodo)
    ].copy()


def periodos_trimestrales_objetivo(
    anio_inicio: int,
    anio_fin: int,
) -> pd.PeriodIndex:
    """Devuelve el PeriodIndex trimestral exacto del analisis."""
    return pd.period_range(
        start=f"{anio_inicio}Q1",
        end=f"{anio_fin}Q4",
        freq="Q-DEC",
    )


def etiqueta_trimestre(periodo: pd.Period) -> str:
    """Convierte 2022Q1 en 2022T1."""
    return f"{periodo.year}T{periodo.quarter}"


# =============================================================================
# CARGA DE FUENTES
# =============================================================================

def cargar_ipc_nacional(ruta: Path) -> pd.DataFrame:
    """Carga el IPC nacional mensual de nivel general."""
    verificar_archivo(ruta)

    ipc = pd.read_csv(
        ruta,
        sep=";",
        dtype={"Codigo": str},
        encoding="latin-1",
    )
    logger.info("IPC crudo: %d filas x %d columnas.", *ipc.shape)

    columnas_requeridas = {
        "Codigo",
        "Descripcion",
        "Periodo",
        "Indice_IPC",
        "Region",
    }
    faltantes = columnas_requeridas.difference(ipc.columns)
    if faltantes:
        raise ValueError(f"IPC: faltan columnas: {sorted(faltantes)}")

    ipc = ipc.loc[
        (ipc["Codigo"].str.strip() == "0")
        & (ipc["Descripcion"].str.strip() == "NIVEL GENERAL")
        & (ipc["Region"].str.strip() == "Nacional")
    ].copy()

    if ipc.empty:
        raise ValueError(
            "IPC: no se encontro Nivel General, Codigo 0, Region Nacional."
        )

    ipc["mes"] = ipc["Periodo"].map(normalizar_fecha_periodo)
    ipc["ipc_nacional"] = ipc["Indice_IPC"].map(
        convertir_numero_argentino
    )

    ipc = (
        ipc[["mes", "ipc_nacional"]]
        .sort_values("mes")
        .reset_index(drop=True)
    )

    if ipc["mes"].duplicated().any():
        duplicados = ipc.loc[ipc["mes"].duplicated(False), "mes"].tolist()
        raise ValueError(f"IPC: meses duplicados: {duplicados}")
    if ipc["ipc_nacional"].isna().any():
        raise ValueError("IPC: existen indices no numericos o ausentes.")
    if (ipc["ipc_nacional"] <= 0).any():
        raise ValueError("IPC: existen indices no positivos.")

    logger.info(
        "IPC nacional: %d meses (%s a %s).",
        len(ipc),
        ipc["mes"].min(),
        ipc["mes"].max(),
    )
    return ipc


def cargar_dolar_minorista(ruta: Path) -> pd.DataFrame:
    """Carga el cierre mensual del dolar minorista vendedor."""
    verificar_archivo(ruta)

    dolar = pd.read_csv(ruta, encoding="utf-8-sig")
    logger.info("Dolar crudo: %d filas x %d columnas.", *dolar.shape)

    columnas_requeridas = {"Fecha", "Vendedor"}
    faltantes = columnas_requeridas.difference(dolar.columns)
    if faltantes:
        raise ValueError(f"Dolar: faltan columnas: {sorted(faltantes)}")

    dolar["fecha_diaria"] = pd.to_datetime(
        dolar["Fecha"],
        format="%d-%m-%Y",
        errors="coerce",
    )
    dolar["dolar_vendedor"] = dolar["Vendedor"].map(
        convertir_numero_argentino
    )

    if dolar["fecha_diaria"].isna().any():
        raise ValueError("Dolar: existen fechas no interpretables.")
    if dolar["fecha_diaria"].duplicated().any():
        raise ValueError("Dolar: existen fechas diarias duplicadas.")
    if dolar["dolar_vendedor"].isna().any():
        raise ValueError("Dolar: existen cotizaciones no numericas o ausentes.")
    if (dolar["dolar_vendedor"] <= 0).any():
        raise ValueError("Dolar: existen cotizaciones no positivas.")

    dolar = dolar.sort_values("fecha_diaria").copy()
    dolar["mes"] = dolar["fecha_diaria"].dt.to_period("M")

    # Como los datos estan ordenados, last conserva la cotizacion de la
    # ultima fecha efectivamente disponible del mes.
    dolar_mensual = (
        dolar.groupby("mes", as_index=False)
        .agg(
            fecha_dolar_cierre=("fecha_diaria", "last"),
            dolar_vendedor=("dolar_vendedor", "last"),
        )
        .sort_values("mes")
        .reset_index(drop=True)
    )

    if dolar_mensual["mes"].duplicated().any():
        raise ValueError("Dolar: existen cierres mensuales duplicados.")

    logger.info(
        "Dolar minorista vendedor: %d meses (%s a %s).",
        len(dolar_mensual),
        dolar_mensual["mes"].min(),
        dolar_mensual["mes"].max(),
    )
    return dolar_mensual


def cargar_smvm(ruta: Path) -> pd.DataFrame:
    """Carga vigencias del SMVM y construye una serie mensual completa."""
    verificar_archivo(ruta)

    smvm = pd.read_csv(ruta, encoding="latin-1")
    logger.info("SMVM crudo: %d filas x %d columnas.", *smvm.shape)

    columnas_requeridas = {"Desde", "Valor Nominal", "Normativa"}
    faltantes = columnas_requeridas.difference(smvm.columns)
    if faltantes:
        raise ValueError(f"SMVM: faltan columnas: {sorted(faltantes)}")

    smvm["fecha_vigencia"] = pd.to_datetime(
        smvm["Desde"],
        format="%d/%m/%Y",
        errors="coerce",
    )
    smvm["smvm_nominal"] = smvm["Valor Nominal"].map(
        convertir_valor_smvm
    )
    smvm["smvm_normativa"] = smvm["Normativa"].fillna("-")

    if smvm["fecha_vigencia"].isna().any():
        raise ValueError("SMVM: existen fechas de vigencia no interpretables.")
    if smvm["smvm_nominal"].isna().any():
        raise ValueError("SMVM: existen valores nominales no numericos.")
    if (smvm["smvm_nominal"] <= 0).any():
        raise ValueError("SMVM: existen valores nominales no positivos.")

    smvm = smvm.sort_values("fecha_vigencia").copy()
    smvm["mes"] = smvm["fecha_vigencia"].dt.to_period("M")

    # Si hubiera varias vigencias en un mes, se conserva la ultima.
    smvm_por_mes = (
        smvm.groupby("mes", as_index=False)
        .last()
        [["mes", "smvm_nominal", "smvm_normativa"]]
        .set_index("mes")
    )

    grilla = pd.period_range(
        start=smvm_por_mes.index.min(),
        end=smvm_por_mes.index.max(),
        freq="M",
    )

    smvm_mensual = (
        smvm_por_mes
        .reindex(grilla)
        .ffill()
        .rename_axis("mes")
        .reset_index()
    )

    if smvm_mensual["smvm_nominal"].isna().any():
        raise ValueError("SMVM: el forward-fill dejo valores ausentes.")

    logger.info(
        "SMVM mensual: %d meses (%s a %s).",
        len(smvm_mensual),
        smvm_mensual["mes"].min(),
        smvm_mensual["mes"].max(),
    )
    return smvm_mensual


# =============================================================================
# CONSTRUCCION TRIMESTRAL
# =============================================================================

def validar_cobertura_mensual(
    datos: pd.DataFrame,
    columna_mes: str,
    inicio: str,
    fin: str,
    nombre: str,
) -> None:
    """Exige un registro por cada mes del rango indicado."""
    esperados = pd.period_range(inicio, fin, freq="M")
    observados = pd.PeriodIndex(datos[columna_mes].dropna().unique(), freq="M")
    faltantes = esperados.difference(observados)

    if len(faltantes) > 0:
        raise ValueError(
            f"{nombre}: faltan meses en la cobertura: "
            f"{faltantes.astype(str).tolist()}"
        )


def construir_tabla_trimestral(
    ipc_original: pd.DataFrame,
    dolar_original: pd.DataFrame,
    smvm_original: pd.DataFrame,
    anio_inicio: int,
    anio_fin: int,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """
    Construye la tabla trimestral final y la base mensual integrada.

    Las variaciones se calculan antes de restringir a los 16 trimestres
    objetivo. Luego se selecciona explicitamente 2022Q1-2025Q4.
    """
    objetivo = periodos_trimestrales_objetivo(anio_inicio, anio_fin)

    ipc = filtrar_rango_mensual(
        ipc_original, "mes", MES_INICIO_AUDITORIA, MES_FIN_ANALISIS
    )
    dolar = filtrar_rango_mensual(
        dolar_original, "mes", MES_INICIO_AUDITORIA, MES_FIN_ANALISIS
    )
    smvm = filtrar_rango_mensual(
        smvm_original, "mes", MES_INICIO_AUDITORIA, MES_FIN_ANALISIS
    )

    validar_cobertura_mensual(
        ipc, "mes", MES_INICIO_AUDITORIA, MES_FIN_ANALISIS, "IPC"
    )
    validar_cobertura_mensual(
        dolar, "mes", MES_INICIO_AUDITORIA, MES_FIN_ANALISIS, "Dolar"
    )
    validar_cobertura_mensual(
        smvm, "mes", MES_INICIO_AUDITORIA, MES_FIN_ANALISIS, "SMVM"
    )

    for fuente, datos in {
        "IPC": ipc,
        "Dolar": dolar,
        "SMVM": smvm,
    }.items():
        if MES_BASE_REAL not in set(datos["mes"]):
            raise ValueError(f"{fuente}: falta diciembre de 2021.")

    # Integracion mensual para el SMVM real y la auditoria.
    mensual = (
        ipc.merge(dolar, on="mes", how="inner")
        .merge(smvm, on="mes", how="inner")
        .sort_values("mes")
        .reset_index(drop=True)
    )

    if len(mensual) != 60:
        raise ValueError(
            "La auditoria 2021-2025 debe contener exactamente 60 meses "
            f"y contiene {len(mensual)}."
        )
    if mensual.isna().any().any():
        columnas = mensual.columns[mensual.isna().any()].tolist()
        raise ValueError(f"Auditoria mensual: faltantes en {columnas}.")

    mensual["inflacion_mensual"] = mensual["ipc_nacional"].pct_change()
    mensual["smvm_real"] = (
        mensual["smvm_nominal"] * 100.0 / mensual["ipc_nacional"]
    )

    base_real = mensual.loc[
        mensual["mes"] == MES_BASE_REAL,
        "smvm_real",
    ]
    if len(base_real) != 1:
        raise ValueError("No existe una unica base real para diciembre de 2021.")

    mensual["smvm_real_indice"] = (
        mensual["smvm_real"] / float(base_real.iloc[0]) * 100.0
    )
    mensual["periodo_q"] = mensual["mes"].dt.asfreq("Q-DEC")

    # Valida tres meses por trimestre en los 16 trimestres finales.
    meses_por_trimestre = (
        mensual.groupby("periodo_q")["mes"].nunique().reindex(objetivo)
    )
    if meses_por_trimestre.isna().any():
        faltantes = meses_por_trimestre[meses_por_trimestre.isna()]
        raise ValueError(
            "Faltan trimestres de SMVM: "
            f"{faltantes.index.astype(str).tolist()}"
        )
    if (meses_por_trimestre != 3).any():
        problemas = meses_por_trimestre[meses_por_trimestre != 3].to_dict()
        raise ValueError(
            "Cada trimestre debe contener tres meses de SMVM. "
            f"Problemas: {problemas}"
        )

    # IPC trimestral, calculado con el cierre de cada trimestre.
    ipc_tri = (
        mensual.groupby("periodo_q", as_index=False)
        .agg(ipc_nacional_cierre=("ipc_nacional", "last"))
        .sort_values("periodo_q")
    )
    ipc_tri["inflacion_trimestral"] = (
        ipc_tri["ipc_nacional_cierre"].pct_change()
    )

    # Dolar trimestral, con la fecha y cotizacion del ultimo mes.
    dolar_tri = (
        mensual.groupby("periodo_q", as_index=False)
        .agg(
            dolar_minorista_vendedor_cierre=("dolar_vendedor", "last"),
            fecha_dolar_cierre=("fecha_dolar_cierre", "last"),
        )
        .sort_values("periodo_q")
    )
    dolar_tri["devaluacion_trimestral"] = (
        dolar_tri["dolar_minorista_vendedor_cierre"].pct_change()
    )

    # SMVM trimestral.
    smvm_tri = (
        mensual.groupby("periodo_q", as_index=False)
        .agg(
            smvm_nominal_promedio_trimestral=("smvm_nominal", "mean"),
            smvm_nominal_cierre_trimestre=("smvm_nominal", "last"),
            smvm_real_indice_cierre=("smvm_real_indice", "last"),
        )
        .sort_values("periodo_q")
    )
    smvm_tri["variacion_smvm_real_trimestral"] = (
        smvm_tri["smvm_real_indice_cierre"].pct_change()
    )

    tabla = (
        ipc_tri.merge(dolar_tri, on="periodo_q", how="inner")
        .merge(smvm_tri, on="periodo_q", how="inner")
        .sort_values("periodo_q")
        .reset_index(drop=True)
    )

    # Correccion central: conservar solo los 16 trimestres objetivo.
    tabla = tabla.loc[
        tabla["periodo_q"].isin(objetivo)
    ].copy()
    tabla = (
        tabla
        .set_index("periodo_q")
        .reindex(objetivo)
        .rename_axis("periodo_q")
        .reset_index()
    )

    tabla["periodo"] = tabla["periodo_q"].map(etiqueta_trimestre)
    tabla["ano"] = tabla["periodo_q"].dt.year.astype(int)
    tabla["trimestre"] = tabla["periodo_q"].dt.quarter.astype(int)

    columnas_finales = [
        "periodo",
        "ano",
        "trimestre",
        "ipc_nacional_cierre",
        "inflacion_trimestral",
        "dolar_minorista_vendedor_cierre",
        "fecha_dolar_cierre",
        "devaluacion_trimestral",
        "smvm_nominal_promedio_trimestral",
        "smvm_nominal_cierre_trimestre",
        "smvm_real_indice_cierre",
        "variacion_smvm_real_trimestral",
    ]
    tabla = tabla[columnas_finales]

    logger.info("Tabla trimestral construida: %d trimestres.", len(tabla))
    return tabla, mensual


# =============================================================================
# VALIDACIONES Y SALIDAS COMPLEMENTARIAS
# =============================================================================

def validar_tabla_trimestral(
    tabla: pd.DataFrame,
    anio_inicio: int,
    anio_fin: int,
) -> None:
    """Aplica los controles finales de integridad."""
    objetivo = periodos_trimestrales_objetivo(anio_inicio, anio_fin)
    etiquetas_esperadas = [etiqueta_trimestre(p) for p in objetivo]

    if len(tabla) != 16:
        raise ValueError(
            f"Se esperaban 16 trimestres y se obtuvieron {len(tabla)}."
        )
    if tabla["periodo"].duplicated().any():
        raise ValueError("Existen periodos duplicados.")
    if tabla["periodo"].tolist() != etiquetas_esperadas:
        raise ValueError(
            "Los periodos no coinciden exactamente con 2022T1-2025T4."
        )
    if tabla.isna().any().any():
        columnas = tabla.columns[tabla.isna().any()].tolist()
        raise ValueError(f"Tabla final: valores faltantes en {columnas}.")

    positivas = [
        "ipc_nacional_cierre",
        "dolar_minorista_vendedor_cierre",
        "smvm_nominal_promedio_trimestral",
        "smvm_nominal_cierre_trimestre",
        "smvm_real_indice_cierre",
    ]
    for columna in positivas:
        if (tabla[columna] <= 0).any():
            raise ValueError(f"Valores no positivos en {columna}.")

    fechas = pd.to_datetime(tabla["fecha_dolar_cierre"], errors="coerce")
    if fechas.isna().any():
        raise ValueError("Existen fechas cambiarias no interpretables.")
    if (fechas > pd.Timestamp("2025-12-31")).any():
        raise ValueError("Existen fechas posteriores a diciembre de 2025.")

    for posicion, fila in tabla.iterrows():
        trimestre_fecha = fechas.iloc[posicion].to_period("Q-DEC")
        trimestre_fila = pd.Period(
            year=int(fila["ano"]),
            quarter=int(fila["trimestre"]),
            freq="Q-DEC",
        )
        if trimestre_fecha != trimestre_fila:
            raise ValueError(
                f"La fecha {fechas.iloc[posicion].date()} no corresponde "
                f"a {fila['periodo']}."
            )

    logger.info("Validacion trimestral completada sin errores.")


def construir_auditoria_mensual(mensual: pd.DataFrame) -> pd.DataFrame:
    """Prepara la auditoria mensual integrada de 2021-2025."""
    auditoria = mensual.copy()
    auditoria["mes"] = auditoria["mes"].astype(str)
    auditoria["fuente_ipc"] = "INDEC IPC nacional"
    auditoria["fuente_dolar"] = "BCRA dolar minorista vendedor"
    auditoria["fuente_smvm"] = "SMVM segun archivo normativo"

    columnas = [
        "mes",
        "ipc_nacional",
        "inflacion_mensual",
        "fecha_dolar_cierre",
        "dolar_vendedor",
        "smvm_nominal",
        "smvm_normativa",
        "smvm_real",
        "smvm_real_indice",
        "fuente_ipc",
        "fuente_dolar",
        "fuente_smvm",
    ]
    return auditoria[columnas]


def construir_resumen_shocks(tabla: pd.DataFrame) -> pd.DataFrame:
    """Resume las tres variaciones trimestrales sin clasificarlas."""
    variables = {
        "inflacion_trimestral": "Inflacion trimestral",
        "devaluacion_trimestral": "Devaluacion trimestral",
        "variacion_smvm_real_trimestral": "Variacion del SMVM real trimestral",
    }

    filas: list[dict[str, float | int | str]] = []
    for columna, etiqueta in variables.items():
        serie = tabla[columna].astype(float)
        filas.append(
            {
                "variable": etiqueta,
                "n": int(serie.count()),
                "media": float(serie.mean()),
                "desviacion_estandar": float(serie.std(ddof=1)),
                "minimo": float(serie.min()),
                "p25": float(serie.quantile(0.25)),
                "mediana": float(serie.median()),
                "p75": float(serie.quantile(0.75)),
                "maximo": float(serie.max()),
            }
        )

    return pd.DataFrame(filas)


def imprimir_resumen_validacion(
    tabla: pd.DataFrame,
    resumen: pd.DataFrame,
) -> None:
    """Imprime un resumen breve de la ejecucion."""
    logger.info("=" * 60)
    logger.info("VALIDACION COMPLETADA")
    logger.info("Periodos: %d", len(tabla))
    logger.info("Inicio: %s", tabla["periodo"].iloc[0])
    logger.info("Fin: %s", tabla["periodo"].iloc[-1])
    logger.info("Valores ausentes: %d", int(tabla.isna().sum().sum()))
    logger.info("Resumen de variaciones:\n%s", resumen.to_string(index=False))
    logger.info("=" * 60)


# =============================================================================
# ORQUESTACION
# =============================================================================

def main() -> None:
    """Ejecuta la construccion completa del insumo macroeconomico."""
    crear_carpeta_salida(CARPETA_SALIDA)

    logger.info("Cargando IPC nacional...")
    ipc = cargar_ipc_nacional(ARCHIVO_IPC)

    logger.info("Cargando dolar minorista vendedor...")
    dolar = cargar_dolar_minorista(ARCHIVO_DOLAR)

    logger.info("Cargando SMVM...")
    smvm = cargar_smvm(ARCHIVO_SMVM)

    logger.info("Construyendo tabla trimestral...")
    tabla, mensual = construir_tabla_trimestral(
        ipc,
        dolar,
        smvm,
        ANIO_INICIO,
        ANIO_FIN,
    )

    validar_tabla_trimestral(tabla, ANIO_INICIO, ANIO_FIN)
    auditoria = construir_auditoria_mensual(mensual)
    resumen = construir_resumen_shocks(tabla)

    tabla.to_csv(SALIDA_TRIMESTRAL, index=False, encoding="utf-8-sig")
    auditoria.to_csv(SALIDA_AUDITORIA, index=False, encoding="utf-8-sig")
    resumen.to_csv(SALIDA_RESUMEN, index=False, encoding="utf-8-sig")

    logger.info("Guardado: %s", SALIDA_TRIMESTRAL)
    logger.info("Guardado: %s", SALIDA_AUDITORIA)
    logger.info("Guardado: %s", SALIDA_RESUMEN)

    imprimir_resumen_validacion(tabla, resumen)


if __name__ == "__main__":
    main()
