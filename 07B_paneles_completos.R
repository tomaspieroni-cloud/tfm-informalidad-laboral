# ============================================================
# 07B_paneles_completos.R
# ============================================================
#
# Objetivo:
# Construir automáticamente los 15 pares trimestrales usando
# organize_panels() del paquete eph.
#
# Salidas:
# - Tabla resumen: reentrevistas_completas.csv
# - Paneles individuales: panel_2022T1_2022T2.rds
# ============================================================

#------------------------------------------------------------
# 1. Cargar configuración y librerías
#------------------------------------------------------------

source(here::here("Scripts", "00_configurar_proyecto.R"))

library(eph)
library(dplyr)
library(tidyr)

#------------------------------------------------------------
# 2. Crear carpeta de salida
#------------------------------------------------------------

ruta_panel <- here::here("Salidas", "05_panel_longitudinal")
dir.create(ruta_panel, recursive = TRUE, showWarnings = FALSE)

#------------------------------------------------------------
# 3. Cargar base convertida (generada en 07)
#------------------------------------------------------------

base_panel <- readRDS(
  file.path(ruta_panel, "base_panel_test.rds")
)

#------------------------------------------------------------
# 4. Seleccionar variables necesarias
#------------------------------------------------------------

vars_panel <- c(
  "CODUSU",
  "NRO_HOGAR",
  "COMPONENTE",
  "ANO4",
  "TRIMESTRE",
  "periodo",
  "CH04",
  "CH06",
  "ESTADO",
  "CAT_OCUP",
  "PONDERA"
)

#------------------------------------------------------------
# 5. Generar lista de bases por período
#------------------------------------------------------------

bases_periodo <- split(
  base_panel[vars_panel],
  base_panel$periodo
)

#------------------------------------------------------------
# 6. Obtener períodos ordenados explícitamente
#------------------------------------------------------------
# Se ordena por ANO4 y TRIMESTRE 

periodos <- base_panel %>%
  distinct(ANO4, TRIMESTRE, periodo) %>%
  arrange(ANO4, TRIMESTRE) %>%
  pull(periodo)

cat("\n========================================\n")
cat("PERÍODOS DISPONIBLES (ORDENADOS)\n")
cat("========================================\n")
print(periodos)

#------------------------------------------------------------
# 7. Construir todos los pares trimestrales
#------------------------------------------------------------

resultados_paneles <- list()

for (i in 1:(length(periodos) - 1)) {
  
  t0 <- periodos[i]
  t1 <- periodos[i + 1]
  
  cat("\nProcesando:", t0, "→", t1, "\n")
  
  # Construir panel
  panel_tmp <- tryCatch({
    
    organize_panels(
      bases = list(
        bases_periodo[[t0]],
        bases_periodo[[t1]]
      ),
      variables = c(
        "ESTADO",
        "CAT_OCUP",
        "PONDERA"
      ),
      window = "trimestral"
    )
    
  }, error = function(e) {
    
    cat(" Error en", t0, "→", t1, ":", e$message, "\n")
    return(NULL)
    
  })
  
  # Si el panel se construyó correctamente
  if (!is.null(panel_tmp)) {
    
    # Calcular métricas
    resumen <- panel_tmp %>%
      summarise(
        transicion = paste0(t0, "-", t1),
        n_t0 = nrow(bases_periodo[[t0]]),
        n_t1 = nrow(bases_periodo[[t1]]),
        enlaces = n(),
        consistentes = sum(consistencia, na.rm = TRUE),
        inconsistentes = enlaces - consistentes,
        pct_consistencia = 100 * consistentes / enlaces
      )
    
    # Guardar resumen
    resultados_paneles[[i]] <- resumen
    
    # Guardar panel individual (como RDS)
    saveRDS(
      panel_tmp,
      file.path(ruta_panel, paste0("panel_", t0, "_", t1, ".rds"))
    )
    
    # Limpiar memoria
    rm(panel_tmp)
    invisible(gc())
    
    cat("ok", t0, "→", t1, 
        "- Enlaces:", resumen$enlaces, 
        "- Consistentes:", resumen$consistentes,
        "- Inconsistentes:", resumen$inconsistentes,
        "- %:", round(resumen$pct_consistencia, 1), "%\n")
    
  }
  
}

#------------------------------------------------------------
# 8. Consolidar tabla resumen
#------------------------------------------------------------

tabla_resumen <- bind_rows(resultados_paneles)

cat("RESUMEN DE PANELES\n")
print(tabla_resumen)

#------------------------------------------------------------
# 9. Guardar tabla resumen
#------------------------------------------------------------

write.csv(
  tabla_resumen,
  file.path(ruta_panel, "paneles_completos.csv"),
  row.names = FALSE
)

#------------------------------------------------------------
# 10. Estadísticas globales
#------------------------------------------------------------

cat("ESTADÍSTICAS\n")

tabla_resumen %>%
  summarise(
    total_enlaces = sum(enlaces),
    promedio_consistencia = mean(pct_consistencia),
    min_consistencia = min(pct_consistencia),
    max_consistencia = max(pct_consistencia),
    total_inconsistentes = sum(inconsistentes)
  ) %>%
  print()


cat("Archivos generados en:", ruta_panel, "\n")
cat(" - reentrevistas_completas.csv\n")
cat("\n Nota: No se generó panel consolidado.\n")
cat("   Los paneles individuales están disponibles\n")