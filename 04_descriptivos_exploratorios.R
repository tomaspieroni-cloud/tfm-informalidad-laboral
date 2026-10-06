#============================================================
# 04) ANÁLISIS DESCRIPTIVO Y EXPLORATORIO
#============================================================

#------------------------------------------------------------
# Cargar configuración general del proyecto
#------------------------------------------------------------

source(
  here::here(
    "Scripts",
    "00_configurar_proyecto.R"
  )
)

#------------------------------------------------------------
# Cargar objetos procesados
#------------------------------------------------------------

source(
  here::here(
    "Scripts",
    "02_cargar_datos.R"
  )
)

#------------------------------------------------------------
# Crear carpetas de salida si no existen
#------------------------------------------------------------

dir.create(
  here::here(
    "Salidas",
    "02_descriptivos"
  ),
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  here::here(
    "Graficos"
  ),
  recursive = TRUE,
  showWarnings = FALSE
)

#------------------------------------------------------------
# Definir objetos necesarios para el análisis exploratorio
#------------------------------------------------------------

objetos_requeridos <- c(
  "base_informalidad_total",
  "tasa_informalidad_total",
  "indicadores_mercado",
  "tasa_informalidad_asalariada",
  "informalidad_sexo",
  "informalidad_edad",
  "informalidad_educacion",
  "informalidad_region"
)

#------------------------------------------------------------
# Identificar objetos ausentes
#------------------------------------------------------------

objetos_ausentes <- setdiff(
  objetos_requeridos,
  ls()
)

#------------------------------------------------------------
# Interrumpir la ejecución si faltan objetos
#------------------------------------------------------------

if (length(objetos_ausentes) > 0) {
  
  stop(
    paste0(
      "No se puede continuar. Objetos ausentes: ",
      paste(
        objetos_ausentes,
        collapse = ", "
      )
    )
  )
  
} else {
  
  message(
    "Todos los objetos requeridos están disponibles."
  )
  
}

#------------------------------------------------------------
# Definir períodos esperados para la serie completa
#------------------------------------------------------------

periodos_esperados <- c(
  "2022T1",
  "2022T2",
  "2022T3",
  "2022T4",
  "2023T1",
  "2023T2",
  "2023T3",
  "2023T4",
  "2024T1",
  "2024T2",
  "2024T3",
  "2024T4",
  "2025T1",
  "2025T2",
  "2025T3",
  "2025T4"
)

#------------------------------------------------------------
# Verificar cobertura temporal de los indicadores generales
#------------------------------------------------------------

periodos_indicadores <- sort(
  unique(
    indicadores_mercado$periodo
  )
)

periodos_ausentes_indicadores <- setdiff(
  periodos_esperados,
  periodos_indicadores
)

if (length(periodos_ausentes_indicadores) > 0) {
  
  warning(
    paste0(
      "Faltan períodos en indicadores_mercado: ",
      paste(
        periodos_ausentes_indicadores,
        collapse = ", "
      )
    )
  )
  
} else {
  
  message(
    "Los indicadores generales contienen los 16 trimestres."
  )
  
}

#------------------------------------------------------------
# Definir períodos esperados para la informalidad total
#------------------------------------------------------------

periodos_informalidad_total_esperados <- c(
  "2023T4",
  "2024T1",
  "2024T2",
  "2024T3",
  "2024T4",
  "2025T1",
  "2025T2",
  "2025T3",
  "2025T4"
)

#------------------------------------------------------------
# Verificar cobertura temporal de la informalidad total
#------------------------------------------------------------

periodos_informalidad_total <- sort(
  unique(
    tasa_informalidad_total$periodo
  )
)

periodos_ausentes_informalidad_total <- setdiff(
  periodos_informalidad_total_esperados,
  periodos_informalidad_total
)

if (length(periodos_ausentes_informalidad_total) > 0) {
  
  warning(
    paste0(
      "Faltan períodos en tasa_informalidad_total: ",
      paste(
        periodos_ausentes_informalidad_total,
        collapse = ", "
      )
    )
  )
  
} else {
  
  message(
    paste(
      "La informalidad total contiene los nueve trimestres",
      "comprendidos entre 2023T4 y 2025T4."
    )
  )
  
}

#------------------------------------------------------------
# Verificar estructura mínima de la base de informalidad total
#------------------------------------------------------------

variables_informalidad_total <- c(
  "periodo",
  "ESTADO",
  "EMPLEO",
  "PONDERA",
  "CAT_OCUP",
  "CH04",
  "CH06",
  "NIVEL_ED",
  "REGION",
  "formalidad_empleo"
)

variables_ausentes_informalidad_total <- setdiff(
  variables_informalidad_total,
  names(base_informalidad_total)
)

if (length(variables_ausentes_informalidad_total) > 0) {
  
  stop(
    paste0(
      "Faltan variables en base_informalidad_total: ",
      paste(
        variables_ausentes_informalidad_total,
        collapse = ", "
      )
    )
  )
  
} else {
  
  message(
    "La base de informalidad total contiene las variables requeridas."
  )
  
}

#------------------------------------------------------------
# Verificar valores observados en la clasificación de formalidad
#------------------------------------------------------------

control_formalidad_empleo <- base_informalidad_total %>%
  
  count(
    periodo,
    formalidad_empleo,
    name = "n_muestral"
  ) %>%
  
  arrange(
    periodo,
    formalidad_empleo
  )

#------------------------------------------------------------
# Visualizar control de formalidad
#------------------------------------------------------------

print(
  control_formalidad_empleo,
  n = Inf
)

#------------------------------------------------------------
# Verificar tasas generales del último período
#------------------------------------------------------------

control_indicadores_ultimo_periodo <- indicadores_mercado %>%
  
  filter(
    periodo == "2025T4"
  ) %>%
  
  select(
    periodo,
    tasa_actividad,
    tasa_empleo,
    tasa_desocupacion
  )

print(
  control_indicadores_ultimo_periodo
)

#------------------------------------------------------------
# Verificar informalidad total del último período
#------------------------------------------------------------

control_informalidad_total_ultimo_periodo <-
  tasa_informalidad_total %>%
  
  filter(
    periodo == "2025T4"
  ) %>%
  
  select(
    periodo,
    n_muestral_ocupados,
    n_muestral_informales,
    poblacion_ocupada,
    poblacion_informal,
    tasa_informalidad_total
  )

print(
  control_informalidad_total_ultimo_periodo
)

#------------------------------------------------------------
# Guardar controles iniciales del análisis exploratorio
#------------------------------------------------------------

write.csv(
  control_formalidad_empleo,
  here::here(
    "Salidas",
    "02_descriptivos",
    "control_formalidad_empleo.csv"
  ),
  row.names = FALSE
)

write.csv(
  control_indicadores_ultimo_periodo,
  here::here(
    "Salidas",
    "02_descriptivos",
    "control_indicadores_2025T4.csv"
  ),
  row.names = FALSE
)

write.csv(
  control_informalidad_total_ultimo_periodo,
  here::here(
    "Salidas",
    "02_descriptivos",
    "control_informalidad_total_2025T4.csv"
  ),
  row.names = FALSE
)

#------------------------------------------------------------
# Informar finalización de los controles iniciales
#------------------------------------------------------------

message(
  paste(
    "Controles iniciales finalizados.",
    "El entorno está preparado para continuar",
    "con los descriptivos de informalidad total."
  )
)






#============================================================
# 1) INFORMALIDAD TOTAL POR SEXO
#============================================================

#------------------------------------------------------------
# Calcular informalidad total por sexo
#------------------------------------------------------------

informalidad_total_sexo <- base_informalidad_total %>%
  
  # Conservar períodos con clasificación válida
  filter(
    !is.na(formalidad_empleo),
    CH04 %in% c(1, 2)
  ) %>%
  
  # Incorporar etiquetas de sexo
  mutate(
    sexo = case_when(
      CH04 == 1 ~ "Varón",
      CH04 == 2 ~ "Mujer"
    )
  ) %>%
  
  # Agrupar por período, sexo y condición de formalidad
  group_by(
    periodo,
    sexo,
    formalidad_empleo
  ) %>%
  
  # Calcular casos muestrales y población expandida
  summarise(
    n_muestral = n(),
    poblacion = sum(
      PONDERA,
      na.rm = TRUE
    ),
    .groups = "drop"
  ) %>%
  
  # Separar formalidad en columnas
  pivot_wider(
    names_from = formalidad_empleo,
    values_from = c(
      n_muestral,
      poblacion
    ),
    values_fill = 0
  ) %>%
  
  # Calcular totales y tasa de informalidad
  mutate(
    n_muestral_total =
      n_muestral_Formal + n_muestral_Informal,
    
    poblacion_ocupada =
      poblacion_Formal + poblacion_Informal,
    
    tasa_informalidad_total =
      100 * poblacion_Informal / poblacion_ocupada
  ) %>%
  
  # Ordenar columnas
  select(
    periodo,
    sexo,
    n_muestral_Formal,
    n_muestral_Informal,
    n_muestral_total,
    poblacion_Formal,
    poblacion_Informal,
    poblacion_ocupada,
    tasa_informalidad_total
  ) %>%
  
  arrange(
    periodo,
    sexo
  )

#------------------------------------------------------------
# Calcular brecha de informalidad por sexo
#------------------------------------------------------------

brecha_informalidad_sexo <- informalidad_total_sexo %>%
  
  select(
    periodo,
    sexo,
    tasa_informalidad_total
  ) %>%
  
  pivot_wider(
    names_from = sexo,
    values_from = tasa_informalidad_total
  ) %>%
  
  mutate(
    brecha_mujer_varon =
      Mujer - Varón
  ) %>%
  
  arrange(periodo)

#------------------------------------------------------------
# Visualizar resultados del último período
#------------------------------------------------------------

informalidad_total_sexo %>%
  filter(
    periodo == "2025T4"
  )

brecha_informalidad_sexo %>%
  filter(
    periodo == "2025T4"
  )

#------------------------------------------------------------
# Guardar informalidad total por sexo
#------------------------------------------------------------

write.csv(
  informalidad_total_sexo,
  here::here(
    "Salidas",
    "02_descriptivos",
    "informalidad_total_sexo.csv"
  ),
  row.names = FALSE
)

#------------------------------------------------------------
# Guardar brecha de informalidad por sexo
#------------------------------------------------------------

write.csv(
  brecha_informalidad_sexo,
  here::here(
    "Salidas",
    "02_descriptivos",
    "brecha_informalidad_sexo.csv"
  ),
  row.names = FALSE
)




#============================================================
# 2) INFORMALIDAD TOTAL POR EDAD
#============================================================

#------------------------------------------------------------
# Construir grupos etarios
#------------------------------------------------------------

informalidad_total_edad <- base_informalidad_total %>%
  
  mutate(
    
    grupo_edad = case_when(
      
      CH06 >= 10 & CH06 <= 24 ~ "10-24",
      
      CH06 >= 25 & CH06 <= 34 ~ "25-34",
      
      CH06 >= 35 & CH06 <= 49 ~ "35-49",
      
      CH06 >= 50 & CH06 <= 64 ~ "50-64",
      
      CH06 >= 65 ~ "65+",
      
      TRUE ~ NA_character_
      
    )
    
  ) %>%
  
  filter(
    !is.na(formalidad_empleo),
    !is.na(grupo_edad)
  ) %>%
  
  group_by(
    periodo,
    grupo_edad,
    formalidad_empleo
  ) %>%
  
  summarise(
    
    n_muestral = n(),
    
    poblacion = sum(
      PONDERA,
      na.rm = TRUE
    ),
    
    .groups = "drop"
    
  ) %>%
  
  pivot_wider(
    
    names_from = formalidad_empleo,
    values_from = c(
      n_muestral,
      poblacion
    ),
    values_fill = 0
    
  ) %>%
  
  mutate(
    
    n_muestral_total =
      n_muestral_Formal +
      n_muestral_Informal,
    
    poblacion_ocupada =
      poblacion_Formal +
      poblacion_Informal,
    
    tasa_informalidad_total =
      100 *
      poblacion_Informal /
      poblacion_ocupada
    
  ) %>%
  
  arrange(
    periodo,
    grupo_edad
  )

#------------------------------------------------------------
# Visualizar último período disponible
#------------------------------------------------------------

informalidad_total_edad %>%
  
  filter(
    periodo == "2025T4"
  ) %>%
  
  arrange(
    desc(
      tasa_informalidad_total
    )
  )

#------------------------------------------------------------
# Guardar informalidad total por edad
#------------------------------------------------------------

write.csv(
  
  informalidad_total_edad,
  
  here::here(
    "Salidas",
    "02_descriptivos",
    "informalidad_total_edad.csv"
  ),
  
  row.names = FALSE
  
)



#============================================================
# 3) INFORMALIDAD TOTAL POR EDUCACION
#============================================================

#------------------------------------------------------------
# Construir niveles educativos
#------------------------------------------------------------

informalidad_total_educacion <- base_informalidad_total %>%
  
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
  
  filter(
    !is.na(formalidad_empleo),
    !is.na(nivel_educativo)
  ) %>%
  
  group_by(
    periodo,
    nivel_educativo,
    formalidad_empleo
  ) %>%
  
  summarise(
    
    n_muestral = n(),
    
    poblacion = sum(
      PONDERA,
      na.rm = TRUE
    ),
    
    .groups = "drop"
    
  ) %>%
  
  pivot_wider(
    
    names_from = formalidad_empleo,
    
    values_from = c(
      n_muestral,
      poblacion
    ),
    
    values_fill = 0
    
  ) %>%
  
  mutate(
    
    n_muestral_total =
      n_muestral_Formal +
      n_muestral_Informal,
    
    poblacion_ocupada =
      poblacion_Formal +
      poblacion_Informal,
    
    tasa_informalidad_total =
      100 *
      poblacion_Informal /
      poblacion_ocupada
    
  ) %>%
  
  arrange(
    periodo,
    nivel_educativo
  )

#------------------------------------------------------------
# Visualizar último período disponible
#------------------------------------------------------------

informalidad_total_educacion %>%
  
  filter(
    periodo == "2025T4"
  ) %>%
  
  arrange(
    desc(
      tasa_informalidad_total
    )
  )

#------------------------------------------------------------
# Guardar resultado
#------------------------------------------------------------

write.csv(
  
  informalidad_total_educacion,
  
  here::here(
    "Salidas",
    "02_descriptivos",
    "informalidad_total_educacion.csv"
  ),
  
  row.names = FALSE
  
)



#============================================================
# 4) INFORMALIDAD TOTAL POR REGION
#============================================================

#------------------------------------------------------------
# Incorporar etiquetas de región
#------------------------------------------------------------

informalidad_total_region <- base_informalidad_total %>%
  
  mutate(
    
    region_nombre = case_when(
      
      REGION == 1 ~ "GBA",
      
      REGION == 40 ~ "NOA",
      
      REGION == 41 ~ "NEA",
      
      REGION == 42 ~ "Cuyo",
      
      REGION == 43 ~ "Pampeana",
      
      REGION == 44 ~ "Patagonia",
      
      TRUE ~ NA_character_
      
    )
    
  ) %>%
  
  filter(
    !is.na(formalidad_empleo),
    !is.na(region_nombre)
  ) %>%
  
  group_by(
    periodo,
    region_nombre,
    formalidad_empleo
  ) %>%
  
  summarise(
    
    n_muestral = n(),
    
    poblacion = sum(
      PONDERA,
      na.rm = TRUE
    ),
    
    .groups = "drop"
    
  ) %>%
  
  pivot_wider(
    
    names_from = formalidad_empleo,
    
    values_from = c(
      n_muestral,
      poblacion
    ),
    
    values_fill = 0
    
  ) %>%
  
  mutate(
    
    n_muestral_total =
      n_muestral_Formal +
      n_muestral_Informal,
    
    poblacion_ocupada =
      poblacion_Formal +
      poblacion_Informal,
    
    tasa_informalidad_total =
      100 *
      poblacion_Informal /
      poblacion_ocupada
    
  ) %>%
  
  arrange(
    periodo,
    region_nombre
  )

#------------------------------------------------------------
# Visualizar último período disponible
#------------------------------------------------------------

informalidad_total_region %>%
  
  filter(
    periodo == "2025T4"
  ) %>%
  
  arrange(
    desc(
      tasa_informalidad_total
    )
  )

#------------------------------------------------------------
# Guardar resultado
#------------------------------------------------------------

write.csv(
  
  informalidad_total_region,
  
  here::here(
    "Salidas",
    "02_descriptivos",
    "informalidad_total_region.csv"
  ),
  
  row.names = FALSE
  
)





#============================================================
# C1.1) EVOLUCION TEMPORAL DE LA BRECHA DE GENERO
#============================================================

#------------------------------------------------------------
# Resumir evolución de la brecha de género
#------------------------------------------------------------

resumen_brecha_genero <- brecha_informalidad_sexo %>%
  
  summarise(
    
    primer_periodo =
      first(periodo),
    
    ultimo_periodo =
      last(periodo),
    
    brecha_inicial =
      first(brecha_mujer_varon),
    
    brecha_final =
      last(brecha_mujer_varon),
    
    brecha_minima =
      min(
        brecha_mujer_varon,
        na.rm = TRUE
      ),
    
    brecha_maxima =
      max(
        brecha_mujer_varon,
        na.rm = TRUE
      ),
    
    variacion_pp =
      brecha_final -
      brecha_inicial
    
  )

#------------------------------------------------------------
# Visualizar resultado
#------------------------------------------------------------

resumen_brecha_genero

#------------------------------------------------------------
# Guardar resultado
#------------------------------------------------------------

write.csv(
  
  resumen_brecha_genero,
  
  here::here(
    "Salidas",
    "02_descriptivos",
    "resumen_brecha_genero.csv"
  ),
  
  row.names = FALSE
  
)


#============================================================
# C1.2) EVOLUCION TEMPORAL POR EDAD
#============================================================

resumen_edad <- informalidad_total_edad %>%
  
  group_by(
    grupo_edad
  ) %>%
  
  summarise(
    
    tasa_inicial =
      first(
        tasa_informalidad_total
      ),
    
    tasa_final =
      last(
        tasa_informalidad_total
      ),
    
    minimo =
      min(
        tasa_informalidad_total,
        na.rm = TRUE
      ),
    
    maximo =
      max(
        tasa_informalidad_total,
        na.rm = TRUE
      ),
    
    variacion_pp =
      tasa_final -
      tasa_inicial,
    
    .groups = "drop"
    
  ) %>%
  
  arrange(
    desc(
      variacion_pp
    )
  )

#------------------------------------------------------------
# Visualizar resultado
#------------------------------------------------------------

resumen_edad

#------------------------------------------------------------
# Guardar resultado
#------------------------------------------------------------

write.csv(
  
  resumen_edad,
  
  here::here(
    "Salidas",
    "02_descriptivos",
    "resumen_evolucion_edad.csv"
  ),
  
  row.names = FALSE
  
)


#============================================================
# C1.3) EVOLUCION TEMPORAL POR EDUCACION
#============================================================

resumen_educacion <- informalidad_total_educacion %>%
  
  group_by(
    nivel_educativo
  ) %>%
  
  summarise(
    
    tasa_inicial =
      first(
        tasa_informalidad_total
      ),
    
    tasa_final =
      last(
        tasa_informalidad_total
      ),
    
    minimo =
      min(
        tasa_informalidad_total,
        na.rm = TRUE
      ),
    
    maximo =
      max(
        tasa_informalidad_total,
        na.rm = TRUE
      ),
    
    variacion_pp =
      tasa_final -
      tasa_inicial,
    
    .groups = "drop"
    
  ) %>%
  
  arrange(
    desc(
      variacion_pp
    )
  )

#------------------------------------------------------------
# Visualizar resultado
#------------------------------------------------------------

resumen_educacion

#------------------------------------------------------------
# Guardar resultado
#------------------------------------------------------------

write.csv(
  
  resumen_educacion,
  
  here::here(
    "Salidas",
    "02_descriptivos",
    "resumen_evolucion_educacion.csv"
  ),
  
  row.names = FALSE
  
)


#============================================================
# C1.4) EVOLUCION TEMPORAL POR REGION
#============================================================

resumen_region <- informalidad_total_region %>%
  
  group_by(
    region_nombre
  ) %>%
  
  summarise(
    
    tasa_inicial =
      first(
        tasa_informalidad_total
      ),
    
    tasa_final =
      last(
        tasa_informalidad_total
      ),
    
    minimo =
      min(
        tasa_informalidad_total,
        na.rm = TRUE
      ),
    
    maximo =
      max(
        tasa_informalidad_total,
        na.rm = TRUE
      ),
    
    variacion_pp =
      tasa_final -
      tasa_inicial,
    
    .groups = "drop"
    
  ) %>%
  
  arrange(
    desc(
      variacion_pp
    )
  )

#------------------------------------------------------------
# Visualizar resultado
#------------------------------------------------------------

resumen_region

#------------------------------------------------------------
# Guardar resultado
#------------------------------------------------------------

write.csv(
  
  resumen_region,
  
  here::here(
    "Salidas",
    "02_descriptivos",
    "resumen_evolucion_region.csv"
  ),
  
  row.names = FALSE
  
)