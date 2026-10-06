# =====================================================================
# 00_configurar_proyecto.R
# =====================================================================
# Propósito: Configurar el entorno del proyecto, rutas, paquetes y semilla
# =====================================================================

#------------------------------------------------------------
# Establecer semilla para reproducibilidad
#------------------------------------------------------------
set.seed(2025)

#------------------------------------------------------------
# Cargar paquetes necesarios (instalar si no existen)
#------------------------------------------------------------
paquetes <- c(
  "readr",
  "dplyr",
  "purrr",
  "stringr",
  "tidyr",
  "ggplot2",
  "here"
)

for (pkg in paquetes) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

#------------------------------------------------------------
# Definir rutas relativas al proyecto con here::here()
#------------------------------------------------------------
ruta_proyecto <- here::here()
ruta_datos    <- file.path(ruta_proyecto, "Datos", "Bases EPH")
ruta_salidas  <- file.path(ruta_proyecto, "Salidas")

#------------------------------------------------------------
# Verificar que la carpeta de datos existe
#------------------------------------------------------------
if (!dir.exists(ruta_datos)) {
  stop("La carpeta 'Datos/Bases EPH/' no existe.")
}

archivos_txt <- list.files(ruta_datos, pattern = "\\.txt$", full.names = TRUE)

if (length(archivos_txt) == 0) {
  stop("No se encontraron archivos .txt en la carpeta 'Datos/Bases EPH/'.")
}

#------------------------------------------------------------
# Crear carpetas de salida si no existen
#------------------------------------------------------------
dir.create(file.path(ruta_salidas, "01_auditoria"),
           recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(ruta_salidas, "02_descriptivos"),
           recursive = TRUE, showWarnings = FALSE)


cat("Configuración completada.\n")
cat(" Datos   :", ruta_datos, "\n")
cat(" Salidas :", ruta_salidas, "\n")
cat(" Archivos de datos encontrados:", length(archivos_txt), "\n")