# ============================================================
# 08D_base_analitica_clustering.R
# Base analitica para clustering sobre empleo informal
# ============================================================
#
# Objetivo:
# Construir una base limpia, documentada y reproducible para
# la identificacion de perfiles de informalidad (clustering).
#
# Universo:
# Empleo Informal en t0 (estado_laboral_clasificado_t0 == "Empleo Informal")
# Período: 2023T4–2025T4 (cobertura completa de la opcion de mantener prioridad 
# la variable EMPLEO)
#
# Variables seleccionadas:
# - Identificacion: id_persona (CODUSU_NRO_HOGAR_COMPONENTE)
# - Temporales: ANO4, TRIMESTRE (para auditoria y estabilidad)
# - Demograficas: CH04 (sexo), CH06 (edad), NIVEL_ED
# - Territoriales: REGION, AGLOMERADO
# - Laborales: CAT_OCUP
# - Ingresos: P21, P47T (se crea log_ingreso)
#
# Transformaciones:
# - edad = CH06_t0 (convertido a numeric)
# - log_ingreso = log(as.numeric(P47T_t0) + 1)
# - id_persona = paste(CODUSU, NRO_HOGAR, COMPONENTE, sep = "_")
#
# Salidas:
# - base_clustering_informalidad.csv
# - base_clustering_informalidad.parquet
# - auditoria_base_clustering.csv (varias tablas)
# ============================================================

#------------------------------------------------------------
# 1. Cargar configuracion y librerias
#------------------------------------------------------------

source(here::here("Scripts", "00_configurar_proyecto.R"))

library(dplyr)
library(tidyr)
library(arrow)   # Para escribir Parquet

#------------------------------------------------------------
# 2. Definir rutas
#------------------------------------------------------------

ruta_transiciones <- here::here("Salidas", "06_transiciones")
ruta_clustering <- here::here("Salidas", "07_clustering")
dir.create(ruta_clustering, recursive = TRUE, showWarnings = FALSE)

#------------------------------------------------------------
# 3. Cargar panel con estados auditados
#------------------------------------------------------------

panel <- readRDS(
  file.path(ruta_transiciones, "panel_estados_auditado.rds")
)

cat("\nPanel cargado:", nrow(panel), "enlaces\n")

#------------------------------------------------------------
# 4. Filtrar universo: empleo informal en t0, solo 2023T4–2025T4
#------------------------------------------------------------
# Nota: Se usa as.numeric() para evitar problemas si ANO4 y TRIMESTRE
#       son caracteres en el panel.
#------------------------------------------------------------

base_clustering <- panel %>%
  filter(
    estado_laboral_clasificado_t0 == "Empleo Informal",
    (as.numeric(ANO4) > 2023 |
       (as.numeric(ANO4) == 2023 & as.numeric(TRIMESTRE) >= 4))
  ) %>%
  select(
    # Identificadores
    CODUSU,
    NRO_HOGAR,
    COMPONENTE,
    ANO4,
    TRIMESTRE,
    # Variables de interes en t0
    CH04_t0,
    CH06_t0,
    NIVEL_ED_t0,
    REGION_t0,
    AGLOMERADO_t0,
    CAT_OCUP,        # CAT_OCUP es la misma en t0 (sin sufijo)
    P21_t0,
    P47T_t0
  )

cat("\nRegistros informales en t0 (2023T4-2025T4):", nrow(base_clustering), "\n")

#------------------------------------------------------------
# 5. Transformaciones
#------------------------------------------------------------
# Nota: Se convierte P47T_t0 a numeric antes de calcular log.
#       Si hay caracteres especiales como "-9" se convertirán a NA.
#------------------------------------------------------------

base_clustering <- base_clustering %>%
  mutate(
    id_persona = paste(CODUSU, NRO_HOGAR, COMPONENTE, sep = "_"),
    edad = as.numeric(CH06_t0),
    log_ingreso = log(as.numeric(P47T_t0) + 1)
  )

#------------------------------------------------------------
# 6. Auditoria de missingness
#------------------------------------------------------------
# Nota: Se extrae n_total antes de pivotar para evitar que
#       la columna n_total se convierta en una fila.
#------------------------------------------------------------

auditoria_missing <- base_clustering %>%
  summarise(
    n_total = n(),
    across(
      c(CH04_t0, CH06_t0, NIVEL_ED_t0, REGION_t0,
        AGLOMERADO_t0, CAT_OCUP, P21_t0,
        P47T_t0, edad, log_ingreso),
      ~ sum(is.na(.))
    )
  )

n_total <- auditoria_missing$n_total

auditoria_missing <- auditoria_missing %>%
  select(-n_total) %>%
  pivot_longer(
    cols = everything(),
    names_to = "variable",
    values_to = "n_na"
  ) %>%
  mutate(
    pct_na = 100 * n_na / n_total
  )

#------------------------------------------------------------
# 7. Resumen estadistico de variables numericas
#------------------------------------------------------------

resumen_numericas <- base_clustering %>%
  select(CH06_t0, edad, P21_t0, P47T_t0, log_ingreso) %>%
  summary()

#------------------------------------------------------------
# 8. Tablas de frecuencia para categoricas
#------------------------------------------------------------

tabla_cat_ocup <- base_clustering %>%
  count(CAT_OCUP) %>%
  mutate(pct = 100 * n / sum(n))

tabla_nivel_ed <- base_clustering %>%
  count(NIVEL_ED_t0) %>%
  mutate(pct = 100 * n / sum(n))

tabla_region <- base_clustering %>%
  count(REGION_t0) %>%
  mutate(pct = 100 * n / sum(n))

tabla_sexo <- base_clustering %>%
  count(CH04_t0) %>%
  mutate(pct = 100 * n / sum(n))

#------------------------------------------------------------
# 9. Distribucion temporal (para ver estabilidad)
#------------------------------------------------------------

distribucion_periodo <- base_clustering %>%
  count(ANO4, TRIMESTRE) %>%
  mutate(pct = 100 * n / sum(n))

#------------------------------------------------------------
# 10. Guardar auditorias
#------------------------------------------------------------

write.csv(auditoria_missing, file.path(ruta_clustering, "auditoria_missing.csv"), row.names = FALSE)
write.csv(tabla_cat_ocup, file.path(ruta_clustering, "auditoria_cat_ocup.csv"), row.names = FALSE)
write.csv(tabla_nivel_ed, file.path(ruta_clustering, "auditoria_nivel_ed.csv"), row.names = FALSE)
write.csv(tabla_region, file.path(ruta_clustering, "auditoria_region.csv"), row.names = FALSE)
write.csv(tabla_sexo, file.path(ruta_clustering, "auditoria_sexo.csv"), row.names = FALSE)
write.csv(distribucion_periodo, file.path(ruta_clustering, "auditoria_distribucion_periodo.csv"), row.names = FALSE)
write.csv(as.data.frame(resumen_numericas), file.path(ruta_clustering, "auditoria_resumen_numerico.csv"), row.names = TRUE)

#------------------------------------------------------------
# 11. Guardar base en CSV y Parquet
#------------------------------------------------------------

write.csv(
  base_clustering,
  file.path(ruta_clustering, "base_clustering_informalidad.csv"),
  row.names = FALSE
)

write_parquet(
  base_clustering,
  file.path(ruta_clustering, "base_clustering_informalidad.parquet")
)

#------------------------------------------------------------
# 12. Mensaje final
#------------------------------------------------------------

cat("\nBase de clustering generada.\n")
cat("Registros:", nrow(base_clustering), "\n")
cat("Variables:", ncol(base_clustering), "\n")
cat("Archivos guardados en:", ruta_clustering, "\n")
cat(" - base_clustering_informalidad.csv\n")
cat(" - base_clustering_informalidad.parquet\n")
cat(" - auditoria_*.csv (6 archivos)\n")