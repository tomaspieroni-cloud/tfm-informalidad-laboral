# ============================================================
# 07E_panel_analitico_final.R
# ============================================================
#
# Objetivo:
# Consolidar todos los paneles trimestrales en un unico dataset
# de enlaces (panel bruto) y su version consistente.
#
# Salidas:
# - panel_bruto_2022_2025.rds
# - panel_consistente_2022_2025.rds
# - resumen_panel_consolidado.csv
# ============================================================

#------------------------------------------------------------
# 1. Cargar configuracion y librerias
#------------------------------------------------------------

source(here::here("Scripts", "00_configurar_proyecto.R"))

library(dplyr)
library(purrr)
library(tidyr)

#------------------------------------------------------------
# 2. Definir rutas
#------------------------------------------------------------

ruta_panel <- here::here("Salidas", "05_panel_longitudinal")

#------------------------------------------------------------
# 3. Obtener lista de archivos de panel (excluyendo test)
#------------------------------------------------------------

archivos_panel <- list.files(
  ruta_panel,
  pattern = "^panel_[0-9]{4}T[0-9]_[0-9]{4}T[0-9]\\.rds$",
  full.names = TRUE
)

#------------------------------------------------------------
# 4. Leer y consolidar todos los paneles
#------------------------------------------------------------

panel_bruto <- map_dfr(archivos_panel, function(archivo) {
  
  nombre <- basename(archivo)
  transicion <- gsub("^panel_|\\.rds$", "", nombre)
  transicion <- gsub("_", "-", transicion)
  
  df <- readRDS(archivo)
  df$transicion <- transicion
  
  return(df)
  
})

#------------------------------------------------------------
# 5. Generar panel consistente
#------------------------------------------------------------

panel_consistente <- panel_bruto %>%
  filter(consistencia == TRUE)

#------------------------------------------------------------
# 6. Tabla resumen
#------------------------------------------------------------

resumen_panel <- data.frame(
  panel = c("bruto", "consistente"),
  observaciones = c(
    nrow(panel_bruto),
    nrow(panel_consistente)
  ),
  transiciones = c(
    length(unique(panel_bruto$transicion)),
    length(unique(panel_consistente$transicion))
  )
) %>%
  mutate(
    porcentaje_retenido = 100 * observaciones / observaciones[1]
  )

#------------------------------------------------------------
# 7. Guardar resultados
#------------------------------------------------------------

saveRDS(
  panel_bruto,
  file.path(ruta_panel, "panel_bruto_2022_2025.rds")
)

saveRDS(
  panel_consistente,
  file.path(ruta_panel, "panel_consistente_2022_2025.rds")
)

write.csv(
  resumen_panel,
  file.path(ruta_panel, "resumen_panel_consolidado.csv"),
  row.names = FALSE
)



cat("\nPanel consolidado generado.\n")
cat("Bruto:", nrow(panel_bruto), "enlaces,", length(unique(panel_bruto$transicion)), "transiciones\n")
cat("Consistente:", nrow(panel_consistente), "enlaces,", length(unique(panel_consistente$transicion)), "transiciones\n")
cat("Retenido:", round(resumen_panel$porcentaje_retenido[2], 1), "%\n")