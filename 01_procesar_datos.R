# =====================================================================
# 01_procesar_datos.R
# =====================================================================
# Propósito: Leer, auditar y procesar los datos de la EPH 2022-2025.
#            Genera tablas de indicadores y perfiles de informalidad.
# Ejecutar: Una vez
# =====================================================================

#------------------------------------------------------------
# 1. Cargar configuración del proyecto
#------------------------------------------------------------
source("Scripts/00_configurar_proyecto.R")

#------------------------------------------------------------
# 2. Definir variables 
#------------------------------------------------------------
vars_interes <- c(
  "PP05I", "PP05J", "PP05K", "PP06A", "PP06E", "PP06E1",
  "EMPLEO", "SECTOR", "PP07H"
)

#------------------------------------------------------------
# 3. Obtener lista de archivos (rutas relativas)
#------------------------------------------------------------
archivos <- list.files(ruta_datos, pattern = "usu_individual.*\\.txt$", full.names = TRUE)

#------------------------------------------------------------
# 4. Auditoría de variables
#------------------------------------------------------------

# Función 
auditar_archivo <- function(archivo) {
  cat("\nProcesando:", basename(archivo))
  
  datos <- read_delim(archivo, delim = ";", show_col_types = FALSE, progress = FALSE)
  n <- nrow(datos)
  
  purrr::map_dfr(vars_interes, function(v) {
    existe <- v %in% names(datos)
    if (existe) {
      tibble(
        archivo = basename(archivo),
        variable = v,
        existe = TRUE,
        tipo = class(datos[[v]])[1],
        missing_pct = round(mean(is.na(datos[[v]]) | datos[[v]] == "") * 100, 2),
        n_registros = n
      )
    } else {
      tibble(
        archivo = basename(archivo),
        variable = v,
        existe = FALSE,
        tipo = NA,
        missing_pct = NA,
        n_registros = n
      )
    }
  })
}

# Ejecutar auditoría
resultado <- map_dfr(archivos, auditar_archivo)

# Guardar resultado de auditoría en CSV
write.csv(
  resultado,
  file.path(ruta_salidas, "01_auditoria", "auditoria_variables.csv"),
  row.names = FALSE
)

# Mostrar vista resumida
resultado %>%
  select(archivo, variable, existe) %>%
  pivot_wider(names_from = archivo, values_from = existe) %>%
  print(n = Inf)

#------------------------------------------------------------
# 5. Unir todas las bases en un solo data frame
#------------------------------------------------------------

# Función para leer un trimestre de la EPH
leer_eph <- function(archivo) {
  datos <- read_delim(archivo, delim = ";", col_types = cols(.default = col_character()), show_col_types = FALSE)
  datos <- datos %>% mutate(periodo = paste0(ANO4, "T", TRIMESTRE))
  return(datos)
}

# Construir base consolidada
base_eph <- map_dfr(archivos, leer_eph)

# Verificar dimensión y registros por trimestre
dim(base_eph)
base_eph %>% count(periodo) %>% arrange(periodo)

# Guardar base completa en RDS (para futuras cargas rápidas)
saveRDS(base_eph, file.path(ruta_salidas, "base_eph_2022_2025.rds"))

#------------------------------------------------------------
# 6. Preparar base de estados (condición de actividad)
#------------------------------------------------------------
base_estado <- base_eph %>%
  select(periodo, ESTADO, PONDERA) %>%
  mutate(
    ESTADO  = as.numeric(ESTADO),
    PONDERA = as.numeric(PONDERA)
  )

# Tabla de condición de actividad
tabla_estado <- base_estado %>%
  group_by(periodo, ESTADO) %>%
  summarise(poblacion = sum(PONDERA, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    estado_laboral = case_when(
      ESTADO == 0 ~ "Entrevista no realizada",
      ESTADO == 1 ~ "Ocupado",
      ESTADO == 2 ~ "Desocupado",
      ESTADO == 3 ~ "Inactivo",
      ESTADO == 4 ~ "Menor de 10 años",
      TRUE ~ "Sin clasificar"
    )
  )

# Verificar resultado
tabla_estado %>%
  select(periodo, estado_laboral, poblacion) %>%
  arrange(periodo)

#------------------------------------------------------------
# 7. Indicadores generales del mercado de trabajo
#------------------------------------------------------------
indicadores_mercado <- base_estado %>%
  group_by(periodo) %>%
  summarise(
    poblacion_total = sum(PONDERA, na.rm = TRUE),
    poblacion_10ymas = sum(PONDERA[ESTADO %in% c(1, 2, 3)], na.rm = TRUE),
    pea = sum(PONDERA[ESTADO %in% c(1, 2)], na.rm = TRUE),
    ocupados = sum(PONDERA[ESTADO == 1], na.rm = TRUE),
    desocupados = sum(PONDERA[ESTADO == 2], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    tasa_actividad = 100 * pea / poblacion_total,
    tasa_empleo = 100 * ocupados / poblacion_total,
    tasa_desocupacion = 100 * desocupados / pea,
    tasa_actividad_10ymas = 100 * pea / poblacion_10ymas,
    tasa_empleo_10ymas = 100 * ocupados / poblacion_10ymas
  ) %>%
  arrange(periodo)

#------------------------------------------------------------
# 8. Base de asalariados ocupados y formalidad
#------------------------------------------------------------
base_asalariados <- base_eph %>%
  mutate(
    ESTADO   = as.numeric(ESTADO),
    CAT_OCUP = as.numeric(CAT_OCUP),
    PP07H    = as.numeric(PP07H),
    PONDERA  = as.numeric(PONDERA),
    CH04     = as.numeric(CH04),
    CH06     = as.numeric(CH06),
    NIVEL_ED = as.numeric(NIVEL_ED),
    REGION   = as.numeric(REGION)
  ) %>%
  filter(ESTADO == 1, CAT_OCUP == 3) %>%
  mutate(
    formalidad = case_when(
      PP07H == 1 ~ "Formal",
      PP07H == 2 ~ "Informal",
      TRUE ~ NA_character_
    )
  )

#------------------------------------------------------------
# 9. Tasa de informalidad asalariada (global)
#------------------------------------------------------------
tasa_informalidad_asalariada <- base_asalariados %>%
  filter(!is.na(formalidad)) %>%
  group_by(periodo, formalidad) %>%
  summarise(poblacion = sum(PONDERA, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = formalidad, values_from = poblacion) %>%
  mutate(
    total_asalariados = Formal + Informal,
    tasa_informalidad_asalariada = 100 * Informal / total_asalariados
  )

#------------------------------------------------------------
# 10. Perfil por sexo
#------------------------------------------------------------
informalidad_sexo <- base_asalariados %>%
  filter(!is.na(formalidad), CH04 %in% c(1, 2)) %>%
  group_by(periodo, CH04, formalidad) %>%
  summarise(poblacion = sum(PONDERA, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = formalidad, values_from = poblacion) %>%
  mutate(
    total_asalariados = Formal + Informal,
    tasa_informalidad_asalariada = 100 * Informal / total_asalariados,
    sexo = case_when(CH04 == 1 ~ "Varón", CH04 == 2 ~ "Mujer")
  ) %>%
  select(periodo, sexo, Formal, Informal, total_asalariados, tasa_informalidad_asalariada)

#------------------------------------------------------------
# 11. Perfil por edad
#------------------------------------------------------------
informalidad_edad <- base_asalariados %>%
  mutate(
    grupo_edad = case_when(
      CH06 >= 10 & CH06 <= 24 ~ "10-24",
      CH06 >= 25 & CH06 <= 34 ~ "25-34",
      CH06 >= 35 & CH06 <= 49 ~ "35-49",
      CH06 >= 50 & CH06 <= 64 ~ "50-64",
      CH06 >= 65             ~ "65+",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(formalidad), !is.na(grupo_edad)) %>%
  group_by(periodo, grupo_edad, formalidad) %>%
  summarise(poblacion = sum(PONDERA, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = formalidad, values_from = poblacion) %>%
  mutate(
    total_asalariados = Formal + Informal,
    tasa_informalidad_asalariada = 100 * Informal / total_asalariados
  )

#------------------------------------------------------------
# 12. Perfil por nivel educativo
#------------------------------------------------------------
informalidad_educacion <- base_asalariados %>%
  mutate(
    nivel_educativo = case_when(
      NIVEL_ED == 1 ~ "Primario incompleto",
      NIVEL_ED == 2 ~ "Primario completo",
      NIVEL_ED == 3 ~ "Secundario incompleto",
      NIVEL_ED == 4 ~ "Secundario completo",
      NIVEL_ED == 5 ~ "Superior incompleto",
      NIVEL_ED == 6 ~ "Superior completo",
      NIVEL_ED == 7 ~ "Sin instrucción",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(formalidad), !is.na(nivel_educativo)) %>%
  group_by(periodo, nivel_educativo, formalidad) %>%
  summarise(poblacion = sum(PONDERA, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = formalidad, values_from = poblacion) %>%
  mutate(
    total_asalariados = Formal + Informal,
    tasa_informalidad_asalariada = 100 * Informal / total_asalariados
  )

#------------------------------------------------------------
# 13. Perfil por región
#------------------------------------------------------------
informalidad_region <- base_asalariados %>%
  mutate(
    region_nombre = case_when(
      REGION == 1  ~ "GBA",
      REGION == 40 ~ "NOA",
      REGION == 41 ~ "NEA",
      REGION == 42 ~ "Cuyo",
      REGION == 43 ~ "Pampeana",
      REGION == 44 ~ "Patagonia",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(formalidad), !is.na(region_nombre)) %>%
  group_by(periodo, region_nombre, formalidad) %>%
  summarise(poblacion = sum(PONDERA, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = formalidad, values_from = poblacion) %>%
  mutate(
    total_asalariados = Formal + Informal,
    tasa_informalidad_asalariada = 100 * Informal / total_asalariados
  )

#------------------------------------------------------------
# 14. Informalidad total (variable EMPLEO)
#------------------------------------------------------------

# Auditar cobertura de EMPLEO
auditoria_empleo <- base_eph %>%
  mutate(ESTADO = as.numeric(ESTADO), EMPLEO = as.numeric(EMPLEO)) %>%
  filter(ESTADO == 1) %>%
  group_by(periodo) %>%
  summarise(
    n_ocupados = n(),
    n_empleo_clasificado = sum(EMPLEO %in% c(1, 2), na.rm = TRUE),
    n_empleo_nsnr = sum(EMPLEO == 9, na.rm = TRUE),
    n_empleo_faltante = sum(is.na(EMPLEO)),
    cobertura_empleo = 100 * n_empleo_clasificado / n_ocupados,
    .groups = "drop"
  ) %>%
  arrange(periodo)

# Guardar auditoría de EMPLEO
write.csv(
  auditoria_empleo,
  file.path(ruta_salidas, "01_auditoria", "auditoria_cobertura_empleo.csv"),
  row.names = FALSE
)

# Calcular tasa de informalidad total
base_informalidad_total <- base_eph %>%
  mutate(
    ESTADO = as.numeric(ESTADO),
    EMPLEO = as.numeric(EMPLEO),
    PONDERA = as.numeric(PONDERA)
  ) %>%
  filter(ESTADO == 1) %>%
  mutate(
    formalidad_empleo = case_when(
      EMPLEO == 1 ~ "Formal",
      EMPLEO == 2 ~ "Informal",
      TRUE ~ NA_character_
    )
  )

tasa_informalidad_total <- base_informalidad_total %>%
  filter(!is.na(formalidad_empleo)) %>%
  group_by(periodo) %>%
  summarise(
    n_muestral_ocupados = n(),
    n_muestral_informales = sum(formalidad_empleo == "Informal"),
    poblacion_ocupada = sum(PONDERA, na.rm = TRUE),
    poblacion_informal = sum(PONDERA[formalidad_empleo == "Informal"], na.rm = TRUE),
    poblacion_formal = sum(PONDERA[formalidad_empleo == "Formal"], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(tasa_informalidad_total = 100 * poblacion_informal / poblacion_ocupada) %>%
  arrange(periodo)

#------------------------------------------------------------
# 15. Guardar todas las tablas en RDS y CSV
#------------------------------------------------------------

# Lista de objetos a guardar
objetos <- list(
  tabla_estado                = tabla_estado,
  indicadores_mercado         = indicadores_mercado,
  tasa_informalidad_asalariada = tasa_informalidad_asalariada,
  informalidad_sexo           = informalidad_sexo,
  informalidad_edad           = informalidad_edad,
  informalidad_educacion      = informalidad_educacion,
  informalidad_region         = informalidad_region,
  tasa_informalidad_total     = tasa_informalidad_total,
  base_asalariados            = base_asalariados,
  auditoria_empleo            = auditoria_empleo
)

# Guardar cada objeto como RDS
for (nombre in names(objetos)) {
  saveRDS(objetos[[nombre]], file.path(ruta_salidas, paste0(nombre, ".rds")))
}

# Guardar versiones CSV de las principales tablas
write.csv(indicadores_mercado, file.path(ruta_salidas, "02_descriptivos", "indicadores_mercado.csv"), row.names = FALSE)
write.csv(tasa_informalidad_asalariada, file.path(ruta_salidas, "02_descriptivos", "tasa_informalidad_asalariada.csv"), row.names = FALSE)
write.csv(informalidad_sexo, file.path(ruta_salidas, "02_descriptivos", "informalidad_asalariada_sexo.csv"), row.names = FALSE)
write.csv(informalidad_edad, file.path(ruta_salidas, "02_descriptivos", "informalidad_asalariada_edad.csv"), row.names = FALSE)
write.csv(informalidad_educacion, file.path(ruta_salidas, "02_descriptivos", "informalidad_asalariada_educacion.csv"), row.names = FALSE)
write.csv(informalidad_region, file.path(ruta_salidas, "02_descriptivos", "informalidad_asalariada_region.csv"), row.names = FALSE)
write.csv(tasa_informalidad_total, file.path(ruta_salidas, "02_descriptivos", "tasa_informalidad_total.csv"), row.names = FALSE)

# Guardar todos los objetos en un único archivo .RData para carga rápida
save(
  tabla_estado,
  indicadores_mercado,
  tasa_informalidad_asalariada,
  informalidad_sexo,
  informalidad_edad,
  informalidad_educacion,
  informalidad_region,
  tasa_informalidad_total,
  base_asalariados,
  auditoria_empleo,
  file = file.path(ruta_salidas, "todos_los_datos.RData")
)

cat("Todos los objetos guardados en:\n", ruta_salidas, "\n")