#============================================================
# CREAR BASE LIVIANA PARA INFORMALIDAD TOTAL
#============================================================

#------------------------------------------------------------
# Cargar configuración del proyecto
#------------------------------------------------------------

source(
  here::here(
    "Scripts",
    "00_configurar_proyecto.R"
  )
)

#------------------------------------------------------------
# Verificar existencia de la base consolidada
#------------------------------------------------------------

archivo_base_eph <- here::here(
  "Salidas",
  "base_eph_2022_2025.rds"
)

if (!file.exists(archivo_base_eph)) {
  stop(
    "No se encontró Salidas/base_eph_2022_2025.rds."
  )
}

#------------------------------------------------------------
# Cargar temporalmente la base consolidada
#------------------------------------------------------------

base_eph <- readRDS(
  archivo_base_eph
)

#------------------------------------------------------------
# Verificar variables necesarias
#------------------------------------------------------------

variables_requeridas <- c(
  "periodo",
  "ESTADO",
  "EMPLEO",
  "PONDERA",
  "CAT_OCUP",
  "CH04",
  "CH06",
  "NIVEL_ED",
  "REGION"
)

variables_ausentes <- setdiff(
  variables_requeridas,
  names(base_eph)
)

if (length(variables_ausentes) > 0) {
  stop(
    "Variables ausentes: ",
    paste(
      variables_ausentes,
      collapse = ", "
    )
  )
}

#------------------------------------------------------------
# Construir base liviana de población ocupada
#------------------------------------------------------------

base_informalidad_total <- base_eph %>%
  
  transmute(
    periodo = periodo,
    ESTADO = as.numeric(ESTADO),
    EMPLEO = as.numeric(EMPLEO),
    PONDERA = as.numeric(PONDERA),
    CAT_OCUP = as.numeric(CAT_OCUP),
    CH04 = as.numeric(CH04),
    CH06 = as.numeric(CH06),
    NIVEL_ED = as.numeric(NIVEL_ED),
    REGION = as.numeric(REGION)
  ) %>%
  
  # Seleccionar población ocupada
  filter(
    ESTADO == 1
  ) %>%
  
  # Clasificar formalidad del empleo
  mutate(
    formalidad_empleo = case_when(
      EMPLEO == 1 ~ "Formal",
      EMPLEO == 2 ~ "Informal",
      TRUE        ~ NA_character_
    )
  )

#------------------------------------------------------------
# Verificar dimensión de la base resultante
#------------------------------------------------------------

dim(base_informalidad_total)

#------------------------------------------------------------
# Verificar cobertura temporal de EMPLEO
#------------------------------------------------------------

base_informalidad_total %>%
  group_by(periodo) %>%
  summarise(
    n_ocupados = n(),
    n_clasificados = sum(
      EMPLEO %in% c(1, 2),
      na.rm = TRUE
    ),
    cobertura_pct = 100 * n_clasificados / n_ocupados,
    .groups = "drop"
  ) %>%
  arrange(periodo)

#------------------------------------------------------------
# Guardar base liviana
#------------------------------------------------------------

saveRDS(
  base_informalidad_total,
  here::here(
    "Salidas",
    "base_informalidad_total.rds"
  )
)

#------------------------------------------------------------
# Eliminar base consolidada temporal
#------------------------------------------------------------

rm(base_eph)

#------------------------------------------------------------
# Liberar memoria
#------------------------------------------------------------

invisible(gc())

message(
  "Base de informalidad total creada correctamente."
)