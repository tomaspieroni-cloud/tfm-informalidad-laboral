# ============================================================
# 07F_panel_enriquecido.R
# Construccion del panel analitico enriquecido
# ============================================================
#
# Objetivo:
# Construir un panel longitudinal enriquecido que contenga
# las variables minimas necesarias para:
# - definicion de estados (Camino 1 y Camino 2)
# - clustering
# - calibracion del ABM
#
# Insumos:
# - panel_consistente_2022_2025.rds
# - base_clasificada_final (estado_laboral_clasificado)
#
# Producto:
# - panel_enriquecido_2022_2025.rds
# - auditoria_panel_enriquecido.csv
# ============================================================

#------------------------------------------------------------
# 1. Cargar configuracion y librerias
#------------------------------------------------------------

source(here::here("Scripts", "00_configurar_proyecto.R"))

library(dplyr)
library(tidyr)

#------------------------------------------------------------
# 2. Definir rutas
#------------------------------------------------------------

ruta_panel <- here::here("Salidas", "05_panel_longitudinal")
ruta_clasificacion <- here::here("Salidas", "04_clasificacion_formalidad")

#------------------------------------------------------------
# 3. Cargar panel consistente
#------------------------------------------------------------

panel <- readRDS(
  file.path(ruta_panel, "panel_consistente_2022_2025.rds")
)

cat("\nPanel consistente:", nrow(panel), "enlaces\n")

#------------------------------------------------------------
# 4. Verificar variables en panel (especialmente ANO4, TRIMESTRE)
#------------------------------------------------------------

cat("\nNombres de variables en panel (primeras 20):\n")
print(names(panel)[1:20])

#------------------------------------------------------------
# 5. Identificar base con estado_laboral_clasificado
#------------------------------------------------------------

archivo_clasificado <- file.path(
  ruta_clasificacion,
  "estado_laboral_clasificado.rds"
)

if (file.exists(archivo_clasificado)) {
  base_clasificada <- readRDS(archivo_clasificado)
  cat("\nBase clasificada cargada desde:", archivo_clasificado, "\n")
} else {
  stop("No se encontro estado_laboral_clasificado. Ejecutar 06_auditoria_codigos_independientes.R primero.")
}

#------------------------------------------------------------
# 6. Verificar que la base tiene estado_laboral_clasificado
#------------------------------------------------------------

if (!"estado_laboral_clasificado" %in% names(base_clasificada)) {
  stop("La base cargada no contiene estado_laboral_clasificado.")
}

#------------------------------------------------------------
# 7. Crear variable periodo en base_clasificada si no existe
#------------------------------------------------------------
# (por si se necesita mas adelante, pero no para el merge)
if (!"periodo" %in% names(base_clasificada)) {
  base_clasificada <- base_clasificada %>%
    mutate(periodo = paste0(ANO4, "T", TRIMESTRE))
  cat("\nVariable periodo creada en base_clasificada.\n")
}

#------------------------------------------------------------
# 8. Seleccionar variables para enriquecimiento
#------------------------------------------------------------

vars_enriquecimiento <- c(
  "CODUSU",
  "NRO_HOGAR",
  "COMPONENTE",
  "periodo",
  "estado_laboral_clasificado",
  "CH04",
  "CH06",
  "NIVEL_ED",
  "REGION",
  "AGLOMERADO",
  "P21",
  "P47T"
)

vars_presentes <- intersect(vars_enriquecimiento, names(base_clasificada))
vars_faltantes <- setdiff(vars_enriquecimiento, names(base_clasificada))

if (length(vars_faltantes) > 0) {
  cat("\nVariables faltantes en base_clasificada:\n")
  print(vars_faltantes)
  cat("\nSe continuara con las variables disponibles.\n")
}

vars_final <- vars_presentes

#------------------------------------------------------------
# 9. Construir base t0 con ANO4 y TRIMESTRE como clave
#------------------------------------------------------------

base_t0 <- base_clasificada %>%
  select(
    CODUSU,
    NRO_HOGAR,
    COMPONENTE,
    ANO4,
    TRIMESTRE,
    all_of(setdiff(vars_final,
                   c("CODUSU", "NRO_HOGAR", "COMPONENTE", "periodo")))
  ) %>%
  rename_with(
    ~ paste0(.x, "_t0"),
    .cols = -c(CODUSU, NRO_HOGAR, COMPONENTE, ANO4, TRIMESTRE)
  )

#------------------------------------------------------------
# 10. Construir base t1 con ANO4_t1 y TRIMESTRE_t1 como clave
#------------------------------------------------------------

base_t1 <- base_clasificada %>%
  select(
    CODUSU,
    NRO_HOGAR,
    COMPONENTE,
    ANO4,
    TRIMESTRE,
    all_of(setdiff(vars_final,
                   c("CODUSU", "NRO_HOGAR", "COMPONENTE", "periodo")))
  ) %>%
  rename(
    ANO4_t1 = ANO4,
    TRIMESTRE_t1 = TRIMESTRE
  ) %>%
  rename_with(
    ~ paste0(.x, "_t1"),
    .cols = -c(CODUSU, NRO_HOGAR, COMPONENTE, ANO4_t1, TRIMESTRE_t1)
  )

#------------------------------------------------------------
# 11. Enriquecer panel con variables t0 y t1
#------------------------------------------------------------

panel_enriquecido <- panel %>%
  left_join(
    base_t0,
    by = c("CODUSU", "NRO_HOGAR", "COMPONENTE", "ANO4", "TRIMESTRE")
  ) %>%
  left_join(
    base_t1,
    by = c("CODUSU", "NRO_HOGAR", "COMPONENTE", "ANO4_t1", "TRIMESTRE_t1")
  )

#------------------------------------------------------------
# 12. Auditoria de cobertura
#------------------------------------------------------------

auditoria_cobertura <- panel_enriquecido %>%
  summarise(
    n_total = n(),
    pct_estado_t0 = 100 * sum(!is.na(estado_laboral_clasificado_t0)) / n_total,
    pct_estado_t1 = 100 * sum(!is.na(estado_laboral_clasificado_t1)) / n_total,
    pct_ch04_t0 = 100 * sum(!is.na(CH04_t0)) / n_total,
    pct_ch06_t0 = 100 * sum(!is.na(CH06_t0)) / n_total,
    pct_nivel_ed_t0 = 100 * sum(!is.na(NIVEL_ED_t0)) / n_total,
    pct_p21_t0 = 100 * sum(!is.na(P21_t0)) / n_total,
    pct_p47t_t0 = 100 * sum(!is.na(P47T_t0)) / n_total
  )

cat("\nAuditoria de cobertura:\n")
print(auditoria_cobertura)

#------------------------------------------------------------
# 13. Verificar duplicados
#------------------------------------------------------------

duplicados <- panel_enriquecido %>%
  group_by(CODUSU, NRO_HOGAR, COMPONENTE, ANO4, TRIMESTRE) %>%
  filter(n() > 1) %>%
  nrow()

if (duplicados > 0) {
  cat("\nAdvertencia: Se encontraron", duplicados, "registros duplicados.\n")
} else {
  cat("\nNo hay registros duplicados.\n")
}

#------------------------------------------------------------
# 14. Verificar tamaño del panel
#------------------------------------------------------------

cat("\nTamaño del panel enriquecido:", nrow(panel_enriquecido), "enlaces\n")

if (nrow(panel_enriquecido) == nrow(panel)) {
  cat("El tamaño se mantiene correctamente.\n")
} else {
  cat("Advertencia: El tamaño del panel cambio.\n")
}

#------------------------------------------------------------
# 15. Guardar panel enriquecido
#------------------------------------------------------------

saveRDS(
  panel_enriquecido,
  file.path(ruta_panel, "panel_enriquecido_2022_2025.rds")
)

write.csv(
  auditoria_cobertura,
  file.path(ruta_panel, "auditoria_panel_enriquecido.csv"),
  row.names = FALSE
)
