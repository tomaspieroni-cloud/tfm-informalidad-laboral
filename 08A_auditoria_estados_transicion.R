# ============================================================
# 08A_auditoria_estados_transicion.R
# Auditoria de estados para matrices de transicion
# ============================================================
#
# Objetivo:
# Crear y auditar los estados para los dos caminos de transicion
# definidos metodologicamente, sin calcular matrices ni probabilidades.
#
# Salidas:
# - dist_estados_camino1.csv
# - dist_estados_camino2.csv
# - auditoria_periodo_camino1.csv
# - auditoria_periodo_camino2.csv
# - resumen_faltantes_estados.csv
# - resumen_general_estados.csv
# - panel_estados_auditado.rds
# - na_estado_independientes.csv
# - na_camino2_estado.csv
# ============================================================

#------------------------------------------------------------
# 1. Cargar configuracion y librerias
#------------------------------------------------------------

source(here::here("Scripts", "00_configurar_proyecto.R"))

library(dplyr)
library(tidyr)
library(purrr)

#------------------------------------------------------------
# 2. Definir rutas
#------------------------------------------------------------

ruta_panel <- here::here("Salidas", "05_panel_longitudinal")
ruta_transiciones <- here::here("Salidas", "06_transiciones")
dir.create(ruta_transiciones, recursive = TRUE, showWarnings = FALSE)

#------------------------------------------------------------
# 3. Cargar panel enriquecido
#------------------------------------------------------------

panel <- readRDS(
  file.path(ruta_panel, "panel_enriquecido_2022_2025.rds")
)

cat("\nPanel enriquecido cargado:", nrow(panel), "enlaces\n")

#------------------------------------------------------------
# 4. Verificar estructura de variables
#------------------------------------------------------------

cat("\nVariables disponibles en panel:\n")
print(names(panel))

vars_required <- c(
  "ESTADO",
  "ESTADO_t1",
  "CAT_OCUP",
  "CAT_OCUP_t1",
  "estado_laboral_clasificado_t0",
  "estado_laboral_clasificado_t1",
  "ANO4",
  "TRIMESTRE",
  "ANO4_t1",
  "TRIMESTRE_t1"
)

missing_vars <- setdiff(vars_required, names(panel))
if (length(missing_vars) > 0) {
  cat("\nVariables faltantes:", paste(missing_vars, collapse = ", "), "\n")
  stop("Revisar nombres de variables en el panel.")
}

cat("\nTodas las variables requeridas estan presentes.\n")

#------------------------------------------------------------
# 5. Auditar valores de estado_laboral_clasificado
#------------------------------------------------------------

cat("\nValores unicos observados en estado_laboral_clasificado_t0:\n")
print(sort(unique(panel$estado_laboral_clasificado_t0)))

cat("\nValores unicos observados en estado_laboral_clasificado_t1:\n")
print(sort(unique(panel$estado_laboral_clasificado_t1)))

#------------------------------------------------------------
# 6. Funciones para crear estados
#------------------------------------------------------------

# Camino 1: Formal, Informal, Desocupado, Inactivo
# Nota: Se usa el valor observado directamente, sin asumir nombres.
crear_estado_camino1 <- function(x) {
  as.character(x)
}

# Camino 2: Asalariado formal, Asalariado informal, No asalariado, Desocupado, Inactivo
# No asalariado agrupa: CAT_OCUP = 1 (patron), 2 (cuentapropista), 4 (familiar sin remuneracion)
crear_estado_camino2 <- function(estado, cat_ocup, estado_clasificado) {
  
  case_when(
    estado == 2 ~ "Desocupado",
    estado == 3 ~ "Inactivo",
    estado == 1 & cat_ocup == 3 & estado_clasificado == "Empleo Formal" ~ "Asalariado formal",
    estado == 1 & cat_ocup == 3 & estado_clasificado == "Empleo Informal" ~ "Asalariado informal",
    estado == 1 & cat_ocup %in% c(1, 2, 4) ~ "No asalariado",
    TRUE ~ NA_character_
  )
  
}

#------------------------------------------------------------
# 7. Crear estados para Camino 1 (solo observaciones validas)
#------------------------------------------------------------

panel_c1 <- panel %>%
  filter(
    !is.na(estado_laboral_clasificado_t0),
    !is.na(estado_laboral_clasificado_t1)
  ) %>%
  mutate(
    estado_c1_t0 = crear_estado_camino1(estado_laboral_clasificado_t0),
    estado_c1_t1 = crear_estado_camino1(estado_laboral_clasificado_t1)
  )

cat("\nPanel Camino 1 (sin NA en estados):", nrow(panel_c1), "enlaces\n")

#------------------------------------------------------------
# 8. Crear estados para Camino 2 (aplica a todo el panel)
#------------------------------------------------------------

panel <- panel %>%
  mutate(
    estado_c2_t0 = crear_estado_camino2(ESTADO, CAT_OCUP, estado_laboral_clasificado_t0),
    estado_c2_t1 = crear_estado_camino2(ESTADO_t1, CAT_OCUP_t1, estado_laboral_clasificado_t1)
  )

#------------------------------------------------------------
# 9. Convertir estados Camino 2 a factor ordenado
#------------------------------------------------------------

panel <- panel %>%
  mutate(
    estado_c2_t0 = factor(
      estado_c2_t0,
      levels = c("Asalariado formal", "Asalariado informal", "No asalariado", "Desocupado", "Inactivo")
    ),
    estado_c2_t1 = factor(
      estado_c2_t1,
      levels = c("Asalariado formal", "Asalariado informal", "No asalariado", "Desocupado", "Inactivo")
    )
  )

#------------------------------------------------------------
# 10. Auditoria de NA en estado_laboral_clasificado_t0
#------------------------------------------------------------
# Documenta formalmente la limitacion de independientes pre-2023T4.
#------------------------------------------------------------

na_estado <- panel %>%
  filter(is.na(estado_laboral_clasificado_t0)) %>%
  count(ANO4, TRIMESTRE, CAT_OCUP, sort = TRUE)

cat("\nNA en estado_laboral_clasificado_t0 (limitacion independientes pre-2023T4):\n")
print(na_estado, n = Inf)

#------------------------------------------------------------
# 11. Auditoria de NA en Camino 2 (estructurales, ej. ESTADO=4)
#------------------------------------------------------------

na_camino2_estado <- panel %>%
  filter(is.na(estado_c2_t0)) %>%
  count(ESTADO, CAT_OCUP, sort = TRUE)

cat("\nNA en Camino 2 (t0): distribucion por ESTADO y CAT_OCUP:\n")
print(na_camino2_estado, n = Inf)

#------------------------------------------------------------
# 12. Auditoria de estados perdidos (NA) - Camino 2
#------------------------------------------------------------

resumen_faltantes <- panel %>%
  summarise(
    n_total = n(),
    na_c2_t0 = sum(is.na(estado_c2_t0)),
    na_c2_t1 = sum(is.na(estado_c2_t1)),
    pct_c2_t0 = 100 * na_c2_t0 / n_total,
    pct_c2_t1 = 100 * na_c2_t1 / n_total
  )

cat("\nResumen de valores faltantes (Camino 2):\n")
print(resumen_faltantes)

#------------------------------------------------------------
# 13. Validacion de estados posibles (Camino 1)
#------------------------------------------------------------

cat("\nAuditoria estados Camino 1 (t0):\n")
print(table(panel_c1$estado_c1_t0, useNA = "ifany"))

cat("\nAuditoria estados Camino 1 (t1):\n")
print(table(panel_c1$estado_c1_t1, useNA = "ifany"))

#------------------------------------------------------------
# 14. Validacion de estados posibles (Camino 2)
#------------------------------------------------------------

cat("\nAuditoria estados Camino 2 (t0):\n")
print(table(panel$estado_c2_t0, useNA = "ifany"))

cat("\nAuditoria estados Camino 2 (t1):\n")
print(table(panel$estado_c2_t1, useNA = "ifany"))

#------------------------------------------------------------
# 15. Distribucion de estados (Camino 1)
#------------------------------------------------------------

dist_c1 <- panel_c1 %>%
  count(estado_c1_t0, sort = TRUE) %>%
  mutate(pct = 100 * n / sum(n))

cat("\nDistribucion Camino 1 (t0):\n")
print(dist_c1)

#------------------------------------------------------------
# 16. Distribucion de estados (Camino 2)
#------------------------------------------------------------

dist_c2 <- panel %>%
  count(estado_c2_t0, sort = TRUE) %>%
  mutate(pct = 100 * n / sum(n))

cat("\nDistribucion Camino 2 (t0):\n")
print(dist_c2)

#------------------------------------------------------------
# 17. Auditoria temporal (Camino 1)
#------------------------------------------------------------

auditoria_periodo_c1 <- panel_c1 %>%
  count(ANO4, TRIMESTRE, estado_c1_t0) %>%
  group_by(ANO4, TRIMESTRE) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  ungroup()

#------------------------------------------------------------
# 18. Auditoria temporal (Camino 2)
#------------------------------------------------------------

auditoria_periodo_c2 <- panel %>%
  count(ANO4, TRIMESTRE, estado_c2_t0) %>%
  group_by(ANO4, TRIMESTRE) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  ungroup()

#------------------------------------------------------------
# 19. Resumen general del panel
#------------------------------------------------------------

resumen_general <- tibble(
  tipo_panel = "enriquecido",
  enlaces_totales = nrow(panel),
  enlaces_camino1 = nrow(panel_c1),
  estados_camino1 = n_distinct(panel_c1$estado_c1_t0, na.rm = TRUE),
  estados_camino2 = n_distinct(panel$estado_c2_t0, na.rm = TRUE),
  na_camino2_t0 = sum(is.na(panel$estado_c2_t0)),
  na_camino2_t1 = sum(is.na(panel$estado_c2_t1))
)

print(resumen_general)

#------------------------------------------------------------
# 20. Guardar resultados
#------------------------------------------------------------

write.csv(
  dist_c1,
  file.path(ruta_transiciones, "dist_estados_camino1.csv"),
  row.names = FALSE
)

write.csv(
  dist_c2,
  file.path(ruta_transiciones, "dist_estados_camino2.csv"),
  row.names = FALSE
)

write.csv(
  auditoria_periodo_c1,
  file.path(ruta_transiciones, "auditoria_periodo_camino1.csv"),
  row.names = FALSE
)

write.csv(
  auditoria_periodo_c2,
  file.path(ruta_transiciones, "auditoria_periodo_camino2.csv"),
  row.names = FALSE
)

write.csv(
  resumen_faltantes,
  file.path(ruta_transiciones, "resumen_faltantes_estados.csv"),
  row.names = FALSE
)

write.csv(
  resumen_general,
  file.path(ruta_transiciones, "resumen_general_estados.csv"),
  row.names = FALSE
)

write.csv(
  na_estado,
  file.path(ruta_transiciones, "na_estado_independientes.csv"),
  row.names = FALSE
)

write.csv(
  na_camino2_estado,
  file.path(ruta_transiciones, "na_camino2_estado.csv"),
  row.names = FALSE
)

#------------------------------------------------------------
# 21. Guardar panel enriquecido para proximos scripts
#------------------------------------------------------------

saveRDS(
  panel,
  file.path(ruta_transiciones, "panel_estados_auditado.rds")
)

#------------------------------------------------------------
# 22. Mensaje final
#------------------------------------------------------------

cat("\nArchivos generados en:", ruta_transiciones, "\n")
cat("  - dist_estados_camino1.csv\n")
cat("  - dist_estados_camino2.csv\n")
cat("  - auditoria_periodo_camino1.csv\n")
cat("  - auditoria_periodo_camino2.csv\n")
cat("  - resumen_faltantes_estados.csv\n")
cat("  - resumen_general_estados.csv\n")
cat("  - na_estado_independientes.csv\n")
cat("  - na_camino2_estado.csv\n")
cat("  - panel_estados_auditado.rds\n")