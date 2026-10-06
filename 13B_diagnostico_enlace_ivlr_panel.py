# -*- coding: utf-8 -*-
"""Diagnóstico de enlace IVLR (preliminar) ↔ panel de transiciones.

Uso:
    python 14_diagnostico_enlace_ivlr_panel.py

Solo lectura.  No modifica archivos, no exporta resultados, no calcula
modelos, no clasifica el IVLR y no usa información del IVLR en t+1.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import warnings
from pathlib import Path

import pandas as pd

warnings.filterwarnings("ignore")

# ============================================================
PROJECT_ROOT = Path(
    os.getenv(
        "TFM_PROJECT_ROOT",
        r"C:\Users\tomas\OneDrive\Master Granada\TFM",
    )
).expanduser().resolve()

IVLR_PATH = (
    PROJECT_ROOT
    / "Salidas"
    / "09_ivlr"
    / "base_ivlr_preliminar.parquet"
)

PANEL_RDS = (
    PROJECT_ROOT
    / "Salidas"
    / "06_transiciones"
    / "panel_estados_auditado.rds"
)

# ============================================================
ESTADOS_VALIDOS = {
    "Empleo Formal",
    "Empleo Informal",
    "Desocupación",
    "Inactividad",
}

CLAVES = ["id_persona", "ANO4", "TRIMESTRE"]

COLUMNAS_IVLR = CLAVES + [
    "ivlr_basico",
    "ivlr_ampliado",
    "ivlr_ampliado_pesos_iguales",
]


# ============================================================
def leer_rds(ruta: Path) -> pd.DataFrame:  # pragma: no cover
    """Lee .rds: pyreadr (si está) o Rscript + arrow."""
    r = ruta.resolve()
    if not r.exists():
        raise FileNotFoundError(str(r))

    try:
        import pyreadr  # type: ignore[import-untyped]
        return list(pyreadr.read_r(str(r)).values())[0]
    except Exception:
        pass

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td) / "tmp.parquet"
        subprocess.run(
            [
                "Rscript",
                "-e",
                (
                    "suppressMessages(library(arrow)); "
                    f"x <- readRDS({str(r)!r}); "
                    f"write_parquet(as.data.frame(x), {str(tmp)!r})"
                ),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        return pd.read_parquet(tmp)


# ============================================================
def main() -> None:
    # 1. Versión del diagnóstico
    print("VERSION DIAGNOSTICO: IVLR + CUATRO ESTADOS, 2026-08-04")
    print(f"Script ejecutado: {Path(__file__).resolve()}")

    # 2. Cargar IVLR
    ivlr = pd.read_parquet(IVLR_PATH)
    assert ivlr.duplicated(CLAVES).sum() == 0, "IVLR tiene claves duplicadas"
    assert set(COLUMNAS_IVLR).issubset(ivlr.columns), (
        "Faltan columnas IVLR esperadas"
    )

    for columna in ["ANO4", "TRIMESTRE"]:
        ivlr[columna] = pd.to_numeric(
            ivlr[columna],
            errors="raise",
        ).astype("Int64")

    ivlr_merge = ivlr[COLUMNAS_IVLR].copy().assign(enlazado_ivlr=True)

    # 3. Cargar panel
    panel = leer_rds(PANEL_RDS)

    # 4. Construir id_persona
    panel["id_persona"] = (
        panel["CODUSU"].astype(str)
        + "_"
        + panel["NRO_HOGAR"].astype(str)
        + "_"
        + panel["COMPONENTE"].astype(str)
    )

    # 5. Estados laborales
    estado_t = "estado_laboral_clasificado_t0"
    estado_t1 = "estado_laboral_clasificado_t1"

    for col in (estado_t, estado_t1):
        assert col in panel.columns, f"Falta columna {col} en el panel"

    panel[estado_t] = panel[estado_t].astype("string").str.strip()
    panel[estado_t1] = panel[estado_t1].astype("string").str.strip()

    for columna in [
        "ANO4",
        "TRIMESTRE",
        "ANO4_t1",
        "TRIMESTRE_t1",
    ]:
        panel[columna] = pd.to_numeric(
            panel[columna],
            errors="coerce",
        )

    assert panel["ANO4"].notna().all()
    assert panel["TRIMESTRE"].notna().all()

    panel["ANO4"] = panel["ANO4"].astype("Int64")
    panel["TRIMESTRE"] = panel["TRIMESTRE"].astype("Int64")
    panel["ANO4_t1"] = panel["ANO4_t1"].astype("Int64")
    panel["TRIMESTRE_t1"] = panel["TRIMESTRE_t1"].astype("Int64")

    print("\n--- Categorías observadas en t ---")
    print(panel[estado_t].value_counts(dropna=False).to_string())
    print("\n--- Categorías observadas en t+1 ---")
    print(panel[estado_t1].value_counts(dropna=False).to_string())

    # 6. Consistencia
    print("\n--- consistencia ---")
    print(panel["consistencia"].value_counts(dropna=False).to_string())

    # 7. Ventana temporal: orígenes 2023T4-2025T3
    mask_ventana = (
        (panel["ANO4"].eq(2023) & panel["TRIMESTRE"].eq(4))
        | panel["ANO4"].eq(2024)
        | (panel["ANO4"].eq(2025) & panel["TRIMESTRE"].le(3))
    )
    panel_ventana = panel.loc[mask_ventana].copy()

    # 8. Origen = Empleo informal, destino en ESTADOS_VALIDOS
    mask_origen = panel_ventana[estado_t].eq("Empleo Informal")
    mask_destino = panel_ventana[estado_t1].isin(ESTADOS_VALIDOS)
    panel_final = panel_ventana.loc[mask_origen & mask_destino].copy()

    # 7. Normalización de id_persona en ambas bases
    panel_final["id_persona"] = (
        panel_final["id_persona"]
        .astype("string")
        .str.strip()
    )

    ivlr["id_persona"] = (
        ivlr["id_persona"]
        .astype("string")
        .str.strip()
    )

    # 6. Verificación previa al merge
    print("\nTipos de claves del panel:")
    print(
        panel_final[
            ["id_persona", "ANO4", "TRIMESTRE"]
        ].dtypes
    )

    print("\nTipos de claves del IVLR:")
    print(
        ivlr[
            ["id_persona", "ANO4", "TRIMESTRE"]
        ].dtypes
    )

    # 9. Emparejamiento many-to-one
    merged = panel_final.merge(
        ivlr_merge,
        on=CLAVES,
        how="left",
        validate="many_to_one",
        indicator=True,
    )
    merged["enlazado"] = merged["_merge"].eq("both")

    # 10. Cobertura
    enlazados = int(merged["enlazado"].sum())
    no_enlazados = int((~merged["enlazado"]).sum())
    n_basico = int(merged["ivlr_basico"].notna().sum())
    n_ampliado = int(merged["ivlr_ampliado"].notna().sum())
    n_iguales = int(merged["ivlr_ampliado_pesos_iguales"].notna().sum())

    print("\n" + "=" * 70)
    print("COBERTURA")
    print("=" * 70)
    print(f"Enlaces en ventana temporal  : {len(panel_ventana)}")
    print(f"Origen empleo informal       : {mask_origen.sum()}")
    print(f"Destino en ESTADOS_VALIDOS   : {mask_destino.sum()}")
    print(f"  (origen informal + destino válido) : {len(panel_final)}")
    print(f"Enlazados con IVLR           : {enlazados}")
    print(f"No enlazados                 : {no_enlazados}")
    print(f"  ivlr_basico observados     : {n_basico}")
    print(f"  ivlr_ampliado observados   : {n_ampliado}")
    print(f"  ivlr_pesos_iguales obs.    : {n_iguales}")

    # 11. Distribución de destinos
    dist = (
        merged[estado_t1]
        .value_counts()
        .rename_axis("estado_destino")
        .reset_index(name="n")
    )
    dist["pct"] = (100 * dist["n"] / dist["n"].sum()).round(2)
    print("\nDISTRIBUCIÓN DE DESTINOS")
    print(dist.to_string(index=False))

    # 12. No enlazados: diagnóstico
    no_enlazados_df = merged.loc[~merged["enlazado"]]
    print(f"\n--- DIAGNÓSTICO DE NO ENLAZADOS ({len(no_enlazados_df)}) ---")
    if len(no_enlazados_df):
        print(
            no_enlazados_df.groupby(["ANO4", "TRIMESTRE"], dropna=False)
            .size()
            .rename("n")
            .reset_index()
            .to_string(index=False)
        )
        print("\nEjemplos de claves no enlazadas:")
        print(
            no_enlazados_df[CLAVES]
            .drop_duplicates()
            .head(5)
            .to_string(index=False)
        )
        print(
            "\nEvaluación: probablemente diferencia temporal o de universo "
            "(personas fuera de 2023T4-2025T3 en la base IVLR)."
        )

    # 13. Resumen final (sección 12 del instructivo)
    print("\n" + "=" * 70)
    print("SALIDA FINAL OBLIGATORIA")
    print("=" * 70)
    print(f"1. Ruta del script          : {Path(__file__).resolve()}")
    print(f"2. Versión                  : IVLR + CUATRO ESTADOS, 2026-08-04")
    print(f"3. Consistencia (categorías): {panel['consistencia'].unique().tolist()}")
    print(f"4. Enlaces ventana temporal : {len(panel_ventana)}")
    print(f"5. Origen empleo informal   : {mask_origen.sum()}")
    print(f"6. Destino válido (4 est.)  : {mask_destino.sum()}")
    print(f"7. Enlazados                : {enlazados}")
    print(f"8. No enlazados             : {no_enlazados}")
    print(f"9. Cobertura ivlr_basico    : {n_basico}")
    print(f"10. Cobertura ivlr_ampliado : {n_ampliado}")
    print(f"11. Cobertura ivlr_iguales  : {n_iguales}")
    print("12. Distribución destinos   :")
    print(dist.to_string(index=False))
    print(f"13. Diagnóstico no enlazados: {len(no_enlazados_df)} casos")


if __name__ == "__main__":
    main()