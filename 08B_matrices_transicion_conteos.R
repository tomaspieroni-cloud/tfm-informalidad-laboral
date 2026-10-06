# ============================================================
# 08B_matrices_transicion_conteos.R
# Matrices observadas de transicion
# ============================================================
#
# Objetivo:
# - Calcular matrices de conteos observados (n_ij) para los dos caminos.
# - Calcular matrices de probabilidades descriptivas (p_ij = n_ij / sum_j n_ij).
# - Diagnosticar celdas con conteos bajos (0, <10, <30, <50).
#
# Salidas:
# - matriz_conteos_camino1.csv, matriz_conteos_camino2.csv (formato ancho)
# - matriz_conteos_camino1_larga.csv, matriz_conteos_camino2_larga.csv (formato largo)
# - matriz_probabilidades_camino1.csv, matriz_probabilidades_camino2.csv
# - diagnostico_celdas.csv
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
# 4. Panel valido para Camino 1
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

cat("Camino 1 - enlaces validos:", nrow(panel_c1), "\n")

#------------------------------------------------------------
# 5. Panel valido para Camino 2
#------------------------------------------------------------

panel_c2 <- panel %>%
  filter(
    !is.na(estado_c2_t0),
    !is.na(estado_c2_t1)
  )

cat("Camino 2 - enlaces validos:", nrow(panel_c2), "\n")

#------------------------------------------------------------
# 6. Matriz de conteos - Camino 1
#------------------------------------------------------------

matriz_c1 <- table(
  panel_c1$estado_c1_t0,
  panel_c1$estado_c1_t1
)

cat("\nMatriz de conteos - Camino 1:\n")
print(matriz_c1)

write.csv(
  as.data.frame.matrix(matriz_c1),
  file.path(ruta_transiciones, "matriz_conteos_camino1.csv"),
  row.names = TRUE
)

#------------------------------------------------------------
# 7. Matriz de conteos - Camino 2
#------------------------------------------------------------

matriz_c2 <- table(
  panel_c2$estado_c2_t0,
  panel_c2$estado_c2_t1
)

cat("\nMatriz de conteos - Camino 2:\n")
print(matriz_c2)

write.csv(
  as.data.frame.matrix(matriz_c2),
  file.path(ruta_transiciones, "matriz_conteos_camino2.csv"),
  row.names = TRUE
)

#------------------------------------------------------------
# 8. Formato largo para graficos
#------------------------------------------------------------

matriz_c1_larga <- as.data.frame(matriz_c1)
names(matriz_c1_larga) <- c("origen", "destino", "n")

matriz_c2_larga <- as.data.frame(matriz_c2)
names(matriz_c2_larga) <- c("origen", "destino", "n")

write.csv(
  matriz_c1_larga,
  file.path(ruta_transiciones, "matriz_conteos_camino1_larga.csv"),
  row.names = FALSE
)

write.csv(
  matriz_c2_larga,
  file.path(ruta_transiciones, "matriz_conteos_camino2_larga.csv"),
  row.names = FALSE
)

#------------------------------------------------------------
# 9. Matrices de probabilidades descriptivas
#------------------------------------------------------------

prob_c1 <- prop.table(matriz_c1, margin = 1)
prob_c2 <- prop.table(matriz_c2, margin = 1)

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
# 10. Diagnostico de celdas
#------------------------------------------------------------

diagnosticar_matriz <- function(matriz) {
  
  tibble(
    celdas_totales = length(matriz),
    celdas_cero = sum(matriz == 0),
    celdas_menor_10 = sum(matriz < 10),
    celdas_menor_30 = sum(matriz < 30),
    celdas_menor_50 = sum(matriz < 50)
  )
  
}

# Calcular diagnosticos sin pipe para evitar conflictos
diag_c1 <- diagnosticar_matriz(matriz_c1)
diag_c1$modelo <- "Camino1"

diag_c2 <- diagnosticar_matriz(matriz_c2)
diag_c2$modelo <- "Camino2"

diagnostico_final <- bind_rows(diag_c1, diag_c2)

cat("\nDiagnostico de celdas:\n")
print(diagnostico_final)

write.csv(
  diagnostico_final,
  file.path(ruta_transiciones, "diagnostico_celdas.csv"),
  row.names = FALSE
)


