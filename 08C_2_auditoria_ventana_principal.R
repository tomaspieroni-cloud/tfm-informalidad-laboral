# ============================================================
# 08C_2_auditoria_ventana_principal.R
# Auditoria de la ventana analitica principal (2023T4–2025T4)
# ============================================================
#
# Objetivo:
# - Diferenciar claramente los distintos universos analíticos.
# - Verificar tamaño de la ventana principal.
# - Recalcular matrices y persistencias para 2023T4–2025T4.
# - Documentar qué base alimentará clustering y ABM.
# ============================================================

#------------------------------------------------------------
# 1. Cargar datos
#------------------------------------------------------------

source(here::here("Scripts", "00_configurar_proyecto.R"))

library(dplyr)

ruta_transiciones <- here::here(
  "Salidas",
  "06_transiciones"
)

panel <- readRDS(
  file.path(
    ruta_transiciones,
    "panel_estados_auditado.rds"
  )
)

#------------------------------------------------------------
# 2. Universos
#------------------------------------------------------------

n_panel_consistente <- nrow(panel)

panel_camino1 <- panel %>%
  filter(
    !is.na(estado_laboral_clasificado_t0),
    !is.na(estado_laboral_clasificado_t1)
  )

n_camino1 <- nrow(panel_camino1)

panel_ventana <- panel_camino1 %>%
  filter(
    as.numeric(ANO4) > 2023 |
      (
        as.numeric(ANO4) == 2023 &
          as.numeric(TRIMESTRE) >= 4
      )
  )

n_ventana <- nrow(panel_ventana)

#------------------------------------------------------------
# 3. Resumen de universos
#------------------------------------------------------------

universos <- tibble(
  universo = c(
    "Panel consistente completo",
    "Camino 1 (estados validos)",
    "Ventana principal 2023T4-2025T4"
  ),
  n = c(
    n_panel_consistente,
    n_camino1,
    n_ventana
  )
)

print(universos)

#------------------------------------------------------------
# 4. Matriz de conteos
#------------------------------------------------------------

matriz_ventana <- table(
  panel_ventana$estado_laboral_clasificado_t0,
  panel_ventana$estado_laboral_clasificado_t1
)

cat("\nMatriz ventana principal:\n")
print(matriz_ventana)

#------------------------------------------------------------
# 5. Matriz de probabilidades
#------------------------------------------------------------

prob_ventana <- prop.table(
  matriz_ventana,
  margin = 1
)

#------------------------------------------------------------
# 6. Persistencia
#------------------------------------------------------------

persistencia <- tibble(
  estado = rownames(prob_ventana),
  persistencia = diag(prob_ventana)
)

print(persistencia)

#------------------------------------------------------------
# 7. Diagnostico de densidad
#------------------------------------------------------------

diagnostico <- tibble(
  celdas_totales = length(matriz_ventana),
  celdas_cero = sum(matriz_ventana == 0),
  celdas_menor_10 = sum(matriz_ventana < 10),
  celdas_menor_30 = sum(matriz_ventana < 30),
  celdas_menor_50 = sum(matriz_ventana < 50)
)

print(diagnostico)

#------------------------------------------------------------
# 8. Guardar resultados
#------------------------------------------------------------

write.csv(
  universos,
  file.path(
    ruta_transiciones,
    "auditoria_ventana_principal_universos.csv"
  ),
  row.names = FALSE
)

write.csv(
  as.data.frame.matrix(matriz_ventana),
  file.path(
    ruta_transiciones,
    "matriz_ventana_principal.csv"
  )
)

write.csv(
  persistencia,
  file.path(
    ruta_transiciones,
    "persistencia_ventana_principal.csv"
  ),
  row.names = FALSE
)

write.csv(
  diagnostico,
  file.path(
    ruta_transiciones,
    "diagnostico_ventana_principal.csv"
  ),
  row.names = FALSE
)

#------------------------------------------------------------
# 9. Mensaje final
#------------------------------------------------------------

cat("\nAuditoria completada.\n")