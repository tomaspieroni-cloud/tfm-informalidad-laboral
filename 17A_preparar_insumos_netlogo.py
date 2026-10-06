# ============================================================
# 17A_preparar_insumos_netlogo.py
# Preparación y auditoría de insumos del ABM base
# ============================================================
#
# Objetivo:
#   1. Leer los cinco insumos empíricos originales.
#   2. Normalizar encabezados, estados, clusters y cuartiles.
#   3. Verificar probabilidades, sumas y claves.
#   4. Exportar copias operativas para NetLogo.
#
# No modifica ni sobrescribe los archivos originales.
# ============================================================

from pathlib import Path
import json

import numpy as np
import pandas as pd


# ============================================================
# 1. Configuración
# ============================================================

RAIZ = Path.cwd()

RUTA_PROB_INFORMALES = (
    RAIZ
    / "Salidas"
    / "11_calibracion_abm"
    / "probabilidades_operativas_abm.csv"
)

RUTA_PROB_GENERAL_INFORMAL = (
    RAIZ
    / "Salidas"
    / "11_calibracion_abm"
    / "probabilidades_transicion_generales.csv"
)

RUTA_OTROS_ESTADOS = (
    RAIZ
    / "Salidas"
    / "12_insumos_abm"
    / "transiciones_generales_otros_estados_operativa.csv"
)

RUTA_ENTRANTES_ORIGEN = (
    RAIZ
    / "Salidas"
    / "12_insumos_abm"
    / "distribucion_entrantes_informalidad_por_origen.csv"
)

RUTA_ENTRANTES_GENERAL = (
    RAIZ
    / "Salidas"
    / "12_insumos_abm"
    / "distribucion_general_entrantes_informalidad.csv"
)

OUT_DIR = (
    RAIZ
    / "Salidas"
    / "13_abm_base"
    / "insumos_netlogo"
)

OUT_DIR.mkdir(
    parents=True,
    exist_ok=True
)

TOLERANCIA = 1e-8


# ============================================================
# 2. Funciones auxiliares
# ============================================================

def leer_csv(ruta: Path) -> pd.DataFrame:
    """
    Lee un CSV con UTF-8-SIG y limpia posibles marcas BOM
    y espacios en los nombres de columnas.
    """

    if not ruta.exists():
        raise FileNotFoundError(
            f"No se encontró el archivo requerido:\n{ruta}"
        )

    datos = pd.read_csv(
        ruta,
        encoding="utf-8-sig"
    )

    datos.columns = (
        datos.columns
        .astype(str)
        .str.replace("\ufeff", "", regex=False)
        .str.strip()
    )

    return datos


def exigir_columnas(
    datos: pd.DataFrame,
    columnas: list[str],
    nombre: str
) -> None:
    """
    Detiene el script si faltan columnas requeridas.
    """

    faltantes = [
        columna
        for columna in columnas
        if columna not in datos.columns
    ]

    if faltantes:
        raise ValueError(
            f"{nombre}: faltan columnas: {faltantes}"
        )


def verificar_unicidad(
    datos: pd.DataFrame,
    clave: list[str],
    nombre: str
) -> None:
    """
    Verifica que no existan claves duplicadas.
    """

    duplicados = datos.duplicated(
        subset=clave,
        keep=False
    )

    if duplicados.any():
        ejemplo = datos.loc[
            duplicados,
            clave
        ].head(10)

        raise ValueError(
            f"{nombre}: existen claves duplicadas.\n"
            f"Ejemplos:\n{ejemplo}"
        )


def verificar_probabilidades(
    datos: pd.DataFrame,
    columnas: list[str],
    nombre: str
) -> None:
    """
    Verifica valores numéricos entre cero y uno.
    """

    for columna in columnas:

        datos[columna] = pd.to_numeric(
            datos[columna],
            errors="coerce"
        )

        if datos[columna].isna().any():
            raise ValueError(
                f"{nombre}: {columna} contiene NA "
                "o valores no numéricos."
            )

        fuera_rango = (
            (datos[columna] < 0)
            | (datos[columna] > 1)
        )

        if fuera_rango.any():
            raise ValueError(
                f"{nombre}: {columna} contiene "
                "probabilidades fuera de [0, 1]."
            )


def verificar_suma_filas(
    datos: pd.DataFrame,
    columnas: list[str],
    nombre: str
) -> None:
    """
    Comprueba que las probabilidades de cada fila sumen uno.
    """

    suma = datos[columnas].sum(axis=1)

    error = np.abs(suma - 1)

    if (error > TOLERANCIA).any():
        filas = datos.loc[
            error > TOLERANCIA
        ].copy()

        filas["suma_calculada"] = suma[
            error > TOLERANCIA
        ]

        raise ValueError(
            f"{nombre}: hay filas que no suman uno.\n"
            f"{filas.head(10)}"
        )


def verificar_suma_grupos(
    datos: pd.DataFrame,
    grupo: list[str],
    columna_probabilidad: str,
    nombre: str
) -> None:
    """
    Comprueba que una distribución larga sume uno
    dentro de cada grupo.
    """

    sumas = (
        datos
        .groupby(
            grupo,
            dropna=False
        )[columna_probabilidad]
        .sum()
        .reset_index(name="suma")
    )

    error = np.abs(sumas["suma"] - 1)

    if (error > TOLERANCIA).any():
        raise ValueError(
            f"{nombre}: hay grupos que no suman uno.\n"
            f"{sumas.loc[error > TOLERANCIA]}"
        )


def recodificar_estado(valor: object) -> str:
    """
    Recodifica los cuatro estados laborales a nombres
    simples para NetLogo.
    """

    mapa = {
        "Empleo Formal": "formal",
        "Empleo Informal": "informal",
        "Desocupación": "desocupacion",
        "Inactividad": "inactividad",
    }

    valor_limpio = str(valor).strip()

    if valor_limpio not in mapa:
        raise ValueError(
            f"Estado laboral no reconocido: {valor!r}"
        )

    return mapa[valor_limpio]


def recodificar_cuartil(valor: object) -> int:
    """
    Convierte las etiquetas de cuartil a 1, 2, 3 o 4.
    """

    mapa = {
        "Q1 menor vulnerabilidad": 1,
        "Q2": 2,
        "Q3": 3,
        "Q4 mayor vulnerabilidad": 4,
    }

    valor_limpio = str(valor).strip()

    if valor_limpio not in mapa:
        raise ValueError(
            f"Cuartil no reconocido: {valor!r}"
        )

    return mapa[valor_limpio]


def recodificar_cluster(valor: object) -> str:
    """
    Conserva clusters 1 a 5 y convierte el faltante
    estructural en 'sin_cluster'.
    """

    valor_limpio = str(valor).strip()

    if valor_limpio == "Sin cluster":
        return "sin_cluster"

    try:
        cluster_num = int(float(valor_limpio))
    except ValueError as error:
        raise ValueError(
            f"Cluster no reconocido: {valor!r}"
        ) from error

    if cluster_num not in {1, 2, 3, 4, 5}:
        raise ValueError(
            f"Cluster fuera del rango 1-5: {valor!r}"
        )

    return str(cluster_num)


def exportar(
    datos: pd.DataFrame,
    nombre: str
) -> Path:
    """
    Exporta un CSV operativo con UTF-8-SIG.
    """

    ruta = OUT_DIR / nombre

    datos.to_csv(
        ruta,
        index=False,
        encoding="utf-8-sig"
    )

    return ruta


# ============================================================
# 3. Leer los cinco archivos originales
# ============================================================

prob_informales = leer_csv(
    RUTA_PROB_INFORMALES
)

prob_general_informal = leer_csv(
    RUTA_PROB_GENERAL_INFORMAL
)

otros_estados = leer_csv(
    RUTA_OTROS_ESTADOS
)

entrantes_origen = leer_csv(
    RUTA_ENTRANTES_ORIGEN
)

entrantes_general = leer_csv(
    RUTA_ENTRANTES_GENERAL
)

print("Cinco archivos originales leídos correctamente.")


# ============================================================
# 4. Transiciones desde informalidad con cuartil
# ============================================================

columnas_prob = [
    "p_empleo_formal",
    "p_empleo_informal",
    "p_desocupacion",
    "p_inactividad",
]

exigir_columnas(
    prob_informales,
    [
        "cluster_calibracion",
        "cuartil_ivlr_ampliado",
        "usar_nivel",
        *columnas_prob,
    ],
    "probabilidades_operativas_abm"
)

if len(prob_informales) != 24:
    raise ValueError(
        "probabilidades_operativas_abm debe tener "
        f"24 filas, pero tiene {len(prob_informales)}."
    )

verificar_unicidad(
    prob_informales,
    [
        "cluster_calibracion",
        "cuartil_ivlr_ampliado",
    ],
    "probabilidades_operativas_abm"
)

verificar_probabilidades(
    prob_informales,
    columnas_prob,
    "probabilidades_operativas_abm"
)

verificar_suma_filas(
    prob_informales,
    columnas_prob,
    "probabilidades_operativas_abm"
)

transiciones_informales = pd.DataFrame({
    "cluster": (
        prob_informales["cluster_calibracion"]
        .map(recodificar_cluster)
    ),
    "cuartil": (
        prob_informales["cuartil_ivlr_ampliado"]
        .map(recodificar_cuartil)
        .astype(int)
    ),
    "p_formal": prob_informales["p_empleo_formal"],
    "p_informal": prob_informales["p_empleo_informal"],
    "p_desocupacion": prob_informales["p_desocupacion"],
    "p_inactividad": prob_informales["p_inactividad"],
    "fuente": prob_informales["usar_nivel"].astype(str),
})


# ============================================================
# 5. Fallback general desde informalidad sin cuartil
# ============================================================

exigir_columnas(
    prob_general_informal,
    [
        "estado_laboral_clasificado_t1",
        "probabilidad_ponderada",
    ],
    "probabilidades_transicion_generales"
)

if len(prob_general_informal) != 4:
    raise ValueError(
        "La tabla general desde informalidad debe "
        "tener exactamente cuatro filas."
    )

prob_general_informal[
    "probabilidad_ponderada"
] = pd.to_numeric(
    prob_general_informal[
        "probabilidad_ponderada"
    ],
    errors="coerce"
)

if (
    prob_general_informal[
        "probabilidad_ponderada"
    ].isna().any()
):
    raise ValueError(
        "La tabla general desde informalidad contiene "
        "probabilidades no numéricas."
    )

prob_general_informal["destino"] = (
    prob_general_informal[
        "estado_laboral_clasificado_t1"
    ].map(recodificar_estado)
)

destinos_esperados = {
    "formal",
    "informal",
    "desocupacion",
    "inactividad",
}

if set(
    prob_general_informal["destino"]
) != destinos_esperados:
    raise ValueError(
        "La tabla general desde informalidad no contiene "
        "exactamente los cuatro destinos."
    )

suma_general = (
    prob_general_informal[
        "probabilidad_ponderada"
    ].sum()
)

if abs(suma_general - 1) > TOLERANCIA:
    raise ValueError(
        "Las probabilidades generales desde informalidad "
        f"suman {suma_general}, no uno."
    )

mapa_general = dict(
    zip(
        prob_general_informal["destino"],
        prob_general_informal[
            "probabilidad_ponderada"
        ]
    )
)

fila_general = pd.DataFrame({
    "cluster": ["general"],
    "cuartil": [0],
    "p_formal": [mapa_general["formal"]],
    "p_informal": [mapa_general["informal"]],
    "p_desocupacion": [
        mapa_general["desocupacion"]
    ],
    "p_inactividad": [
        mapa_general["inactividad"]
    ],
    "fuente": ["general"],
})

transiciones_informales = pd.concat(
    [
        transiciones_informales,
        fila_general,
    ],
    ignore_index=True
)

verificar_suma_filas(
    transiciones_informales,
    [
        "p_formal",
        "p_informal",
        "p_desocupacion",
        "p_inactividad",
    ],
    "transiciones_informales operativas"
)


# ============================================================
# 6. Transiciones desde los otros tres estados
# ============================================================

exigir_columnas(
    otros_estados,
    [
        "estado_origen",
        "p_empleo_formal",
        "p_empleo_informal",
        "p_desocupacion",
        "p_inactividad",
    ],
    "transiciones_generales_otros_estados"
)

if len(otros_estados) != 3:
    raise ValueError(
        "La tabla de otros estados debe tener "
        "exactamente tres filas."
    )

verificar_unicidad(
    otros_estados,
    ["estado_origen"],
    "transiciones_generales_otros_estados"
)

verificar_probabilidades(
    otros_estados,
    columnas_prob,
    "transiciones_generales_otros_estados"
)

verificar_suma_filas(
    otros_estados,
    columnas_prob,
    "transiciones_generales_otros_estados"
)

transiciones_otros = pd.DataFrame({
    "origen": (
        otros_estados["estado_origen"]
        .map(recodificar_estado)
    ),
    "p_formal": otros_estados["p_empleo_formal"],
    "p_informal": otros_estados["p_empleo_informal"],
    "p_desocupacion": otros_estados["p_desocupacion"],
    "p_inactividad": otros_estados["p_inactividad"],
    "fuente": "estado_general",
})

if set(transiciones_otros["origen"]) != {
    "formal",
    "desocupacion",
    "inactividad",
}:
    raise ValueError(
        "La tabla de otros estados no contiene exactamente "
        "formal, desocupacion e inactividad."
    )


# ============================================================
# 7. Perfiles de entrada por estado de origen
# ============================================================

exigir_columnas(
    entrantes_origen,
    [
        "estado_origen",
        "cluster_final_t1",
        "cuartil_ivlr_t1",
        "probabilidad_ponderada",
        "usar_nivel",
    ],
    "distribucion_entrantes_por_origen"
)

entrantes_origen[
    "probabilidad_ponderada"
] = pd.to_numeric(
    entrantes_origen[
        "probabilidad_ponderada"
    ],
    errors="coerce"
)

if entrantes_origen[
    "probabilidad_ponderada"
].isna().any():
    raise ValueError(
        "La distribución por origen contiene "
        "probabilidades no numéricas."
    )

perfiles_origen = pd.DataFrame({
    "origen": (
        entrantes_origen["estado_origen"]
        .map(recodificar_estado)
    ),
    "cluster": (
        entrantes_origen["cluster_final_t1"]
        .map(recodificar_cluster)
    ),
    "cuartil": (
        entrantes_origen["cuartil_ivlr_t1"]
        .map(recodificar_cuartil)
        .astype(int)
    ),
    "probabilidad": (
        entrantes_origen[
            "probabilidad_ponderada"
        ]
    ),
    "fuente": (
        entrantes_origen["usar_nivel"]
        .astype(str)
    ),
})

verificar_unicidad(
    perfiles_origen,
    [
        "origen",
        "cluster",
        "cuartil",
    ],
    "perfiles_entrada_por_origen"
)

verificar_probabilidades(
    perfiles_origen,
    ["probabilidad"],
    "perfiles_entrada_por_origen"
)

verificar_suma_grupos(
    perfiles_origen,
    ["origen"],
    "probabilidad",
    "perfiles_entrada_por_origen"
)

if set(perfiles_origen["origen"]) != {
    "formal",
    "desocupacion",
    "inactividad",
}:
    raise ValueError(
        "Los perfiles de entrada no contienen exactamente "
        "los tres estados de origen esperados."
    )


# ============================================================
# 8. Distribución general de perfiles de entrada
# ============================================================

exigir_columnas(
    entrantes_general,
    [
        "cluster_final_t1",
        "cuartil_ivlr_t1",
        "probabilidad_ponderada",
    ],
    "distribucion_general_entrantes"
)

entrantes_general[
    "probabilidad_ponderada"
] = pd.to_numeric(
    entrantes_general[
        "probabilidad_ponderada"
    ],
    errors="coerce"
)

if entrantes_general[
    "probabilidad_ponderada"
].isna().any():
    raise ValueError(
        "La distribución general de entrantes contiene "
        "probabilidades no numéricas."
    )

perfiles_general = pd.DataFrame({
    "cluster": (
        entrantes_general["cluster_final_t1"]
        .map(recodificar_cluster)
    ),
    "cuartil": (
        entrantes_general["cuartil_ivlr_t1"]
        .map(recodificar_cuartil)
        .astype(int)
    ),
    "probabilidad": (
        entrantes_general[
            "probabilidad_ponderada"
        ]
    ),
    "fuente": "distribucion_general",
})

verificar_unicidad(
    perfiles_general,
    [
        "cluster",
        "cuartil",
    ],
    "perfiles_entrada_general"
)

verificar_probabilidades(
    perfiles_general,
    ["probabilidad"],
    "perfiles_entrada_general"
)

suma_perfiles_general = (
    perfiles_general["probabilidad"].sum()
)

if abs(
    suma_perfiles_general - 1
) > TOLERANCIA:
    raise ValueError(
        "La distribución general de perfiles suma "
        f"{suma_perfiles_general}, no uno."
    )


# ============================================================
# 9. Exportar archivos operativos
# ============================================================

ruta_trans_inf = exportar(
    transiciones_informales,
    "transiciones_informales.csv"
)

ruta_trans_otros = exportar(
    transiciones_otros,
    "transiciones_otros_estados.csv"
)

ruta_perfiles_origen = exportar(
    perfiles_origen,
    "perfiles_entrada_por_origen.csv"
)

ruta_perfiles_general = exportar(
    perfiles_general,
    "perfiles_entrada_general.csv"
)


# ============================================================
# 10. Crear auditoría resumida
# ============================================================

auditoria = pd.DataFrame([
    {
        "insumo": "transiciones_informales",
        "filas": len(transiciones_informales),
        "grupos": len(transiciones_informales),
        "suma_minima": (
            transiciones_informales[
                [
                    "p_formal",
                    "p_informal",
                    "p_desocupacion",
                    "p_inactividad",
                ]
            ].sum(axis=1).min()
        ),
        "suma_maxima": (
            transiciones_informales[
                [
                    "p_formal",
                    "p_informal",
                    "p_desocupacion",
                    "p_inactividad",
                ]
            ].sum(axis=1).max()
        ),
        "resultado": "aprobado",
    },
    {
        "insumo": "transiciones_otros_estados",
        "filas": len(transiciones_otros),
        "grupos": len(transiciones_otros),
        "suma_minima": (
            transiciones_otros[
                [
                    "p_formal",
                    "p_informal",
                    "p_desocupacion",
                    "p_inactividad",
                ]
            ].sum(axis=1).min()
        ),
        "suma_maxima": (
            transiciones_otros[
                [
                    "p_formal",
                    "p_informal",
                    "p_desocupacion",
                    "p_inactividad",
                ]
            ].sum(axis=1).max()
        ),
        "resultado": "aprobado",
    },
    {
        "insumo": "perfiles_entrada_por_origen",
        "filas": len(perfiles_origen),
        "grupos": perfiles_origen["origen"].nunique(),
        "suma_minima": (
            perfiles_origen
            .groupby("origen")["probabilidad"]
            .sum()
            .min()
        ),
        "suma_maxima": (
            perfiles_origen
            .groupby("origen")["probabilidad"]
            .sum()
            .max()
        ),
        "resultado": "aprobado",
    },
    {
        "insumo": "perfiles_entrada_general",
        "filas": len(perfiles_general),
        "grupos": 1,
        "suma_minima": suma_perfiles_general,
        "suma_maxima": suma_perfiles_general,
        "resultado": "aprobado",
    },
])

ruta_auditoria = exportar(
    auditoria,
    "auditoria_insumos_netlogo.csv"
)


# ============================================================
# 11. Guardar metadatos de trazabilidad
# ============================================================

metadatos = {
    "modelo": "ABM base sin shocks",
    "tick": "trimestre",
    "estados": [
        "formal",
        "informal",
        "desocupacion",
        "inactividad",
    ],
    "probabilidades_utilizadas": "ponderadas",
    "tolerancia_sumas": TOLERANCIA,
    "archivos_originales": {
        "probabilidades_operativas_abm": str(
            RUTA_PROB_INFORMALES
        ),
        "probabilidades_generales_informal": str(
            RUTA_PROB_GENERAL_INFORMAL
        ),
        "transiciones_otros_estados": str(
            RUTA_OTROS_ESTADOS
        ),
        "perfiles_entrada_por_origen": str(
            RUTA_ENTRANTES_ORIGEN
        ),
        "perfiles_entrada_general": str(
            RUTA_ENTRANTES_GENERAL
        ),
    },
    "archivos_operativos": {
        "transiciones_informales": str(
            ruta_trans_inf
        ),
        "transiciones_otros_estados": str(
            ruta_trans_otros
        ),
        "perfiles_entrada_por_origen": str(
            ruta_perfiles_origen
        ),
        "perfiles_entrada_general": str(
            ruta_perfiles_general
        ),
        "auditoria": str(
            ruta_auditoria
        ),
    },
}

ruta_metadatos = (
    OUT_DIR
    / "metadatos_insumos_netlogo.json"
)

with open(
    ruta_metadatos,
    "w",
    encoding="utf-8"
) as archivo:
    json.dump(
        metadatos,
        archivo,
        ensure_ascii=False,
        indent=2
    )


# ============================================================
# 12. Resumen final
# ============================================================

print("\n=== PREPARACIÓN FINALIZADA ===")

print(
    "\nTransiciones desde informalidad:",
    len(transiciones_informales)
)

print(
    "Transiciones desde otros estados:",
    len(transiciones_otros)
)

print(
    "Perfiles por origen:",
    len(perfiles_origen)
)

print(
    "Perfiles generales:",
    len(perfiles_general)
)

print(
    "\nArchivos guardados en:",
    OUT_DIR
)

print(
    "\nTodos los controles fueron aprobados."
)


# ============================================================
# 13. Separar reglas específicas y regla general informal
# ============================================================

transiciones_informales_especificas = (
    transiciones_informales
    .loc[
        ~(
            (transiciones_informales["cluster"] == "general")
            & (transiciones_informales["cuartil"] == 0)
        )
    ]
    .copy()
)

transiciones_informales_generales = (
    transiciones_informales
    .loc[
        (
            (transiciones_informales["cluster"] == "general")
            & (transiciones_informales["cuartil"] == 0)
        )
    ]
    .copy()
)

if len(transiciones_informales_especificas) != 24:
    raise ValueError(
        "Se esperaban 24 reglas específicas desde informalidad."
    )

if len(transiciones_informales_generales) != 1:
    raise ValueError(
        "Se esperaba una única regla general desde informalidad."
    )

verificar_suma_filas(
    transiciones_informales_especificas,
    [
        "p_formal",
        "p_informal",
        "p_desocupacion",
        "p_inactividad",
    ],
    "transiciones informales específicas"
)

verificar_suma_filas(
    transiciones_informales_generales,
    [
        "p_formal",
        "p_informal",
        "p_desocupacion",
        "p_inactividad",
    ],
    "transición general desde informalidad"
)

exportar(
    transiciones_informales_especificas,
    "transiciones_informales_especificas.csv"
)

exportar(
    transiciones_informales_generales,
    "transiciones_informales_generales.csv"
)

print(
    "Reglas específicas desde informalidad:",
    len(transiciones_informales_especificas)
)

print(
    "Reglas generales desde informalidad:",
    len(transiciones_informales_generales)
)