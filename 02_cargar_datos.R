# =====================================================================
# 02_cargar_datos.R
# =====================================================================
# Propósito: Cargar todos los objetos procesados desde la carpeta Salidas.
# Ejecutar: CADA VEZ que se abra R y se quiera trabajar con los datos.
# =====================================================================

#------------------------------------------------------------
# 1. Configurar rutas (usando here)
#------------------------------------------------------------
library(here)
ruta_salidas <- file.path(here::here(), "Salidas")

#------------------------------------------------------------
# 2. Cargar todos los objetos guardados
#------------------------------------------------------------
load(file.path(ruta_salidas, "todos_los_datos.RData"))

#------------------------------------------------------------
# Cargar base liviana de informalidad total
#------------------------------------------------------------

archivo_informalidad_total <- here::here(
  "Salidas",
  "base_informalidad_total.rds"
)

if (file.exists(archivo_informalidad_total)) {
  
  base_informalidad_total <- readRDS(
    archivo_informalidad_total
  )
  
} else {
  
  warning(
    paste(
      "No se encontró base_informalidad_total.rds.",
      "Ejecutar Scripts/01b_crear_base_informalidad_total.R."
    )
  )
  
}

#------------------------------------------------------------
# 3. Verificar que se cargaron correctamente
#------------------------------------------------------------
cat("Datos cargados exitosamente\n")
cat("Objetos disponibles:\n")
print(ls())

#------------------------------------------------------------
# 4. Mostrar resumen rápido
#------------------------------------------------------------
cat("\n Resumen de indicadores disponibles:\n")
cat("- Períodos:", paste(unique(indicadores_mercado$periodo), collapse = ", "), "\n")
cat("- Última tasa de informalidad asalariada:", 
    round(tail(tasa_informalidad_asalariada$tasa_informalidad_asalariada, 1), 2), "%\n")
cat("- Última tasa de informalidad total:", 
    round(tail(tasa_informalidad_total$tasa_informalidad_total, 1), 2), "%\n")

#------------------------------------------------------------
# 5. Cargar librerías comunes para análisis
#------------------------------------------------------------
library(dplyr)
library(ggplot2)
library(tidyr)
