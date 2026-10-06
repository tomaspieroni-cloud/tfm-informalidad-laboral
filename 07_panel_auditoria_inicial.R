# ============================================================
# 07_panel_auditoria_inicial.R
# ============================================================
#
# Objetivo:
# Auditar el funcionamiento de organize_panels() del paquete eph
# sobre la base consolidada 2022T1–2025T4.
#
# - organize_panels() utiliza CODUSU, NRO_HOGAR y COMPONENTE
#   para enlazar individuos entre trimestres.
# - Genera automáticamente variables _t1 y un indicador de
#   consistencia (sexo y edad).
# - Antes de construir el panel completo, se debe verificar que
#   funciona correctamente con los datos y que las tasas de
#   consistencia son aceptables.
#
# Período de prueba: 2022T1 → 2022T2
#
# Salidas (temporales, para validación):
# - base_panel_test.rds (base con tipos numéricos, solo para prueba)
# - panel_test_2022T1_2022T2.rds
# - diagnostico_edad_2022T1_2022T2.csv
# - resumen_consistencia_panel.csv
# ============================================================

#------------------------------------------------------------
# 1. Cargar configuración y librerías
#------------------------------------------------------------

source(here::here("Scripts", "00_configurar_proyecto.R"))

library(eph)
library(dplyr)
library(tidyr)

#------------------------------------------------------------
# 2. Crear carpeta de salida para paneles
#------------------------------------------------------------

ruta_panel <- here::here("Salidas", "05_panel_longitudinal")
dir.create(ruta_panel, recursive = TRUE, showWarnings = FALSE)

#------------------------------------------------------------
# 3. Cargar base consolidada
#------------------------------------------------------------

base_eph <- readRDS(
  here::here("Salidas", "base_eph_2022_2025.rds")
)

#------------------------------------------------------------
# 4. Crear copia temporal para paneles
#------------------------------------------------------------
# No modificar la base maestra original.
#------------------------------------------------------------

base_panel <- base_eph

#------------------------------------------------------------
# 5. CONVERSIÓN DE TIPOS
#------------------------------------------------------------
# Diagnóstico: CH04, CH06, ESTADO, CAT_OCUP son character.
# organize_panels() necesita variables numéricas para:
#------------------------------------------------------------

base_eph %>%
  select(CH04, CH06, ESTADO, CAT_OCUP) %>%
  summarise(
    CH04 = class(CH04)[1],
    CH06 = class(CH06)[1],
    ESTADO = class(ESTADO)[1],
    CAT_OCUP = class(CAT_OCUP)[1]
  ) %>%
  print()

#------------------------------------------------------------
# 6. Verificar formato de los períodos
#------------------------------------------------------------

print(table(base_panel$periodo))

#------------------------------------------------------------
# 7. Convertir variables a numérico
#------------------------------------------------------------

base_panel <- base_panel %>%
  mutate(
    CH04 = as.numeric(CH04),
    CH06 = as.numeric(CH06),
    ESTADO = as.numeric(ESTADO),
    CAT_OCUP = as.numeric(CAT_OCUP),
    PONDERA = as.numeric(PONDERA)
  )

#------------------------------------------------------------
# 8. Verificar pérdidas por conversión
#------------------------------------------------------------
# Se espera 0 o cercano a 0.
#------------------------------------------------------------

perdidas <- base_panel %>%
  summarise(
    na_CH04 = sum(is.na(CH04)),
    na_CH06 = sum(is.na(CH06)),
    na_ESTADO = sum(is.na(ESTADO)),
    na_CAT_OCUP = sum(is.na(CAT_OCUP)),
    na_PONDERA = sum(is.na(PONDERA))
  )

print(perdidas)

if (sum(perdidas) == 0) {
  cat("Sin pérdidas por conversión.\n")
} else {
  cat("Se detectaron", sum(perdidas), "NAs. Revisar.\n")
}

#------------------------------------------------------------
# 9. Verificar estructura final
#------------------------------------------------------------

base_panel %>%
  select(CH04, CH06, ESTADO, CAT_OCUP, PONDERA) %>%
  str()

#------------------------------------------------------------
# 10. Guardar copia de prueba
# Se guarda como base_panel_test.rds para validación.
# No reemplazar la base maestra.
#------------------------------------------------------------

saveRDS(
  base_panel,
  file.path(ruta_panel, "base_panel_test.rds")
)

#------------------------------------------------------------
# 11. Seleccionar variables necesarias para el panel
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
# 12. Generar lista de bases por período 
#------------------------------------------------------------

bases_periodo <- split(
  base_panel[vars_panel],
  base_panel$periodo
)

#------------------------------------------------------------
# 13. Verificar que los períodos esperados existen
#------------------------------------------------------------

stopifnot(
  "2022T1" %in% names(bases_periodo),
  "2022T2" %in% names(bases_periodo)
)

cat("\n Períodos 2022T1 y 2022T2 encontrados.\n")

#------------------------------------------------------------
# 14. Prueba: 2022T1 → 2022T2 con organize_panels()
#------------------------------------------------------------

panel_test <- tryCatch({
  
  organize_panels(
    bases = list(
      bases_periodo[["2022T1"]],
      bases_periodo[["2022T2"]]
    ),
    variables = c(
      "ESTADO",
      "CAT_OCUP",
      "PONDERA"
    ),
    window = "trimestral"
  )
  
}, error = function(e) {
  
  cat("\n Error en organize_panels():\n")
  cat(e$message, "\n")
  
  # Diagnóstico adicional: ver qué variables tiene bases_periodo
  cat("\nNombres de variables en bases_periodo[['2022T1']]:\n")
  print(names(bases_periodo[["2022T1"]]))
  
  cat("\nEstructura de bases_periodo[['2022T1']]:\n")
  str(bases_periodo[["2022T1"]])
  
  return(NULL)
  
})

#------------------------------------------------------------
# 15. Si el panel se construyó correctamente, auditar
#------------------------------------------------------------

if (!is.null(panel_test)) {
  
  #----------------------------------------------------------
  # 15.1. Cantidad de registros enlazados
  #----------------------------------------------------------
  
  cat("RESUMEN DEL PANEL\n")

  n_enlazados <- nrow(panel_test)
  cat("Registros enlazados:", n_enlazados, "\n")
  
  #----------------------------------------------------------
  # 15.2. Consistencia de sexo y edad
  #----------------------------------------------------------
  
  cat("CONSISTENCIA DE SEXO Y EDAD\n")

  resumen_consistencia <- panel_test %>%
    summarise(
      n_total = n(),
      n_consistentes = sum(consistencia, na.rm = TRUE),
      pct_consistencia = 100 * n_consistentes / n_total
    )
  
  print(resumen_consistencia)
  
  #----------------------------------------------------------
  # 15.3. Diagnóstico: diferencias de edad
  #----------------------------------------------------------
  

  cat("DISTRIBUCIÓN DE DIFERENCIAS DE EDAD\n")
  cat("(CH06_t1 - CH06)\n")

  diagnostico_edad <- panel_test %>%
    mutate(
      dif_edad = CH06_t1 - CH06
    ) %>%
    count(dif_edad) %>%
    arrange(dif_edad)
  
  print(diagnostico_edad, n = Inf)
  
  #----------------------------------------------------------
  # 15.4. Resumen ejecutivo 
  #----------------------------------------------------------
  

  cat("RESUMEN EJECUTIVO DE LA AUDITORÍA\n")

  cat("Tasa de consistencia observada:", 
      round(resumen_consistencia$pct_consistencia, 1), "%\n")
  
  cat("\nDistribución de diferencias de edad:\n")
  print(diagnostico_edad, n = Inf)
  
  cat("\nNota: Este es un diagnóstico exploratorio.\n")
  cat("No se declara aún si el panel es válido.\n")
  cat("Se requiere revisar la definición de 'consistencia'\n")
  cat("en la documentación de organize_panels() antes de decidir.\n")
  
  #----------------------------------------------------------
  # 15.5. Guardar resultados (temporales)
  #----------------------------------------------------------
  
  saveRDS(
    panel_test,
    file.path(ruta_panel, "panel_test_2022T1_2022T2.rds")
  )
  
  write.csv(
    diagnostico_edad,
    file.path(ruta_panel, "diagnostico_edad_2022T1_2022T2.csv"),
    row.names = FALSE
  )
  
  write.csv(
    resumen_consistencia,
    file.path(ruta_panel, "resumen_consistencia_panel.csv"),
    row.names = FALSE
  )
  
}

#------------------------------------------------------------
# 16. Mensaje final
#------------------------------------------------------------

if (!is.null(panel_test)) {
  cat("Panel construido correctamente.\n")
  cat("Archivos generados en:", ruta_panel, "\n")
  cat(" - base_panel_test.rds (copia de prueba, NO definitiva)\n")
  cat(" - panel_test_2022T1_2022T2.rds\n")
  cat(" - diagnostico_edad_2022T1_2022T2.csv\n")
  cat(" - resumen_consistencia_panel.csv\n")
  cat("\n Reecordar: revisar la definición de 'consistencia'\n")
  cat("   en la documentación de organize_panels() antes de\n")
  cat("   tomar decisiones sobre el panel completo.\n")
} else {
  cat("el panel no pudo construirse.\n")
  cat("Revisar el mensaje de error y la estructura de bases_periodo.\n")
}