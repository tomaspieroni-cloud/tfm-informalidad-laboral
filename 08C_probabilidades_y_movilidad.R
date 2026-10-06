# ============================================================
# 08C_probabilidades_y_movilidad.R
# Probabilidades de transicion y movilidad laboral
# ============================================================
#
# Objetivo:
# - Calcular probabilidades de transicion (p_ij).
# - Analizar persistencia diagonal.
# - Medir entradas y salidas de la informalidad.
# - Comparar Camino 1 vs Camino 2.
#
# Camino 1 (principal)
# Período: 2023T4–2025T4
# Estados:
#   Empleo Formal
#   Empleo Informal
#   Desocupación
#   Inactividad
# Ventaja: mantiene exactamente el objeto central de la tesis: la informalidad laboral.
#
# Camino 2 (alternativo)
# Período: 2022T1–2025T4
# Estados:
#   Asalariado formal
#   Asalariado informal
#   No asalariado
#   Desocupado
#   Inactividad
# Ventaja: aprovecha toda la serie temporal.
# Desventaja: pierde la distinción formal/informal entre independientes.
#
# Salidas:
# - matriz_probabilidades_camino1.csv
# - matriz_probabilidades_camino2.csv
# - persistencia_estados.csv
# - movilidad_informalidad.csv
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

ruta_transiciones <- here::here("Salidas", "06_transiciones")

#------------------------------------------------------------
# 3. Cargar panel con estados auditados
#------------------------------------------------------------

panel <- readRDS(
  file.path(ruta_transiciones, "panel_estados_auditado.rds")
)

cat("\nPanel cargado:", nrow(panel), "enlaces\n")

#------------------------------------------------------------
# 4. Reconstruir paneles validos
#------------------------------------------------------------

panel_c1 <- panel %>%
  filter(
    !is.na(estado_laboral_clasificado_t0),
    !is.na(estado_laboral_clasificado_t1)
  ) %>%
  mutate(
    estado_c1_t0 = estado_laboral_clasificado_t0,
    estado_c1_t1 = estado_laboral_clasificado_t1
  )

panel_c2 <- panel %>%
  filter(
    !is.na(estado_c2_t0),
    !is.na(estado_c2_t1)
  )

cat("Camino 1 - enlaces validos:", nrow(panel_c1), "\n")
cat("Camino 2 - enlaces validos:", nrow(panel_c2), "\n")

#------------------------------------------------------------
# 5. Matrices de probabilidades
#------------------------------------------------------------

matriz_c1 <- table(
  panel_c1$estado_c1_t0,
  panel_c1$estado_c1_t1
)

matriz_c2 <- table(
  panel_c2$estado_c2_t0,
  panel_c2$estado_c2_t1
)

prob_c1 <- prop.table(matriz_c1, margin = 1)
prob_c2 <- prop.table(matriz_c2, margin = 1)

#------------------------------------------------------------
# 6. Guardar matrices de probabilidades
#------------------------------------------------------------

write.csv(
  as.data.frame.matrix(prob_c1),
  file.path(ruta_transiciones, "matriz_probabilidades_camino1.csv"),
  row.names = TRUE
)

write.csv(
  as.data.frame.matrix(prob_c2),
  file.path(ruta_transiciones, "matriz_probabilidades_camino2.csv"),
  row.names = TRUE
)

#------------------------------------------------------------
# 7. Persistencia diagonal
#------------------------------------------------------------

persistencia_c1 <- tibble(
  modelo = "Camino1",
  estado = rownames(prob_c1),
  persistencia = diag(prob_c1)
)

persistencia_c2 <- tibble(
  modelo = "Camino2",
  estado = rownames(prob_c2),
  persistencia = diag(prob_c2)
)

persistencia_estados <- bind_rows(persistencia_c1, persistencia_c2)

cat("\nPersistencia de estados:\n")
print(persistencia_estados)

write.csv(
  persistencia_estados,
  file.path(ruta_transiciones, "persistencia_estados.csv"),
  row.names = FALSE
)

#------------------------------------------------------------
# 8. Movilidad de informalidad (Camino 1)
#------------------------------------------------------------

entrada_informal <- panel_c1 %>%
  filter(
    estado_c1_t0 != "Empleo Informal",
    estado_c1_t1 == "Empleo Informal"
  ) %>%
  nrow()

salida_informal <- panel_c1 %>%
  filter(
    estado_c1_t0 == "Empleo Informal",
    estado_c1_t1 != "Empleo Informal"
  ) %>%
  nrow()

persistencia_informal <- panel_c1 %>%
  filter(
    estado_c1_t0 == "Empleo Informal",
    estado_c1_t1 == "Empleo Informal"
  ) %>%
  nrow()

movilidad_informalidad <- tibble(
  entrada_informal = entrada_informal,
  salida_informal = salida_informal,
  persistencia_informal = persistencia_informal
)

cat("\nMovilidad de informalidad (Camino 1):\n")
print(movilidad_informalidad)

write.csv(
  movilidad_informalidad,
  file.path(ruta_transiciones, "movilidad_informalidad.csv"),
  row.names = FALSE
)

#------------------------------------------------------------
# 9. Resumen final
#------------------------------------------------------------

cat("\nProbabilidades y movilidad calculadas.\n")
cat("Archivos generados en:", ruta_transiciones, "\n")
cat(" - matriz_probabilidades_camino1.csv\n")
cat(" - matriz_probabilidades_camino2.csv\n")
cat(" - persistencia_estados.csv\n")
cat(" - movilidad_informalidad.csv\n")