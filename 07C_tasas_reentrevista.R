# ============================================================
# 07C_tasas_reentrevista.R
# ============================================================
#
# Objetivo:
# Calcular tasas de reentrevista para cada par trimestral
# a partir de la tabla resumen generada en 07B.
#
# Entrada:
# - reentrevistas_completas.csv (generado en 07B)
#
# Salidas:
# - tasas_reentrevista.csv
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

#------------------------------------------------------------
# 3. Cargar tabla de reentrevistas
#------------------------------------------------------------

tabla_resumen <- read.csv(
  file.path(ruta_panel, "paneles_completos.csv")
)

#------------------------------------------------------------
# 4. Calcular tasa de reentrevista
#------------------------------------------------------------

tasas_reentrevista <- tabla_resumen %>%
  mutate(
    tasa_reentrevista = 100 * enlaces / n_t0
  ) %>%
  select(
    transicion,
    n_t0,
    enlaces,
    tasa_reentrevista
  )

#------------------------------------------------------------
# 5. Mostrar resultados
#------------------------------------------------------------

cat("\nTasas de paneles por transicion\n")
print(tasas_reentrevista)

#------------------------------------------------------------
# 6. Estadisticas resumen
#------------------------------------------------------------

resumen_tasas <- tasas_reentrevista %>%
  summarise(
    promedio = mean(tasa_reentrevista),
    minimo = min(tasa_reentrevista),
    maximo = max(tasa_reentrevista)
  )

cat("\nEstadisticas globales\n")
print(resumen_tasas)

#------------------------------------------------------------
# 7. Guardar resultados
#------------------------------------------------------------

write.csv(
  tasas_reentrevista,
  file.path(ruta_panel, "tasas_reentrevista.csv"),
  row.names = FALSE
)



