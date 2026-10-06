#============================================================
# 05) AUDITORIA EXPLORATORIA DEL DATASET
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
# Definir archivo de la base consolidada
#------------------------------------------------------------

archivo_base_eph <- here::here(
  "Salidas",
  "base_eph_2022_2025.rds"
)

#------------------------------------------------------------
# Verificar existencia de la base consolidada
#------------------------------------------------------------

if (!file.exists(archivo_base_eph)) {
  
  stop(
    paste(
      "No se encontró la base consolidada.",
      "Ejecutar previamente Scripts/01_procesar_datos.R."
    )
  )
  
}

#------------------------------------------------------------
# Crear carpeta para resultados exploratorios
#------------------------------------------------------------

ruta_exploratorios <- here::here(
  "Salidas",
  "03_exploratorios"
)

dir.create(
  ruta_exploratorios,
  recursive = TRUE,
  showWarnings = FALSE
)

#------------------------------------------------------------
# Cargar temporalmente la base consolidada
#------------------------------------------------------------

base_eph_exploratoria <- readRDS(
  archivo_base_eph
)

#------------------------------------------------------------
# Definir variables relevantes para el TFM
#------------------------------------------------------------

variables_tfm <- c(
  
  # Identificación y período
  "CODUSU",
  "NRO_HOGAR",
  "COMPONENTE",
  "ANO4",
  "TRIMESTRE",
  "periodo",
  
  # Condición laboral
  "ESTADO",
  "CAT_OCUP",
  
  # Formalidad general
  "EMPLEO",
  "SECTOR",
  
  # Formalidad asalariada
  "PP07H",
  "PP07G1",
  "PP07G2",
  "PP07G3",
  "PP07G4",
  "PP07K",
  "PP07C",
  
  # Formalidad independiente
  "PP05I",
  "PP05J",
  "PP05K",
  "PP06A",
  "PP06E",
  "PP06E1",
  
  # Características sociodemográficas
  "CH04",
  "CH06",
  "NIVEL_ED",
  
  # Características territoriales
  "REGION",
  "AGLOMERADO",
  
  # Intensidad y estabilidad laboral
  "PP3E_TOT",
  "PP3F_TOT",
  "PP04B3_ANO",
  "PP04B3_MES",
  
  # Características productivas
  "PP04B_COD",
  "PP04C",
  "PP04C99",
  
  # Ingresos
  "P21",
  "P47T",
  "ITF",
  "IPCF",
  
  # Ponderadores
  "PONDERA",
  "PONDII",
  "PONDIIO",
  "PONDIH"
)

#------------------------------------------------------------
# Identificar variables presentes y ausentes
#------------------------------------------------------------

variables_presentes <- intersect(
  variables_tfm,
  names(base_eph_exploratoria)
)

variables_ausentes <- setdiff(
  variables_tfm,
  names(base_eph_exploratoria)
)

#------------------------------------------------------------
# Informar variables ausentes
#------------------------------------------------------------

if (length(variables_ausentes) > 0) {
  
  warning(
    paste0(
      "Variables no encontradas: ",
      paste(
        variables_ausentes,
        collapse = ", "
      )
    )
  )
  
}



#============================================================
# A) DIMENSIÓN Y COBERTURA TEMPORAL
#============================================================

#------------------------------------------------------------
# Calcular dimensión general de la base
#------------------------------------------------------------

dimension_general <- tibble::tibble(
  
  indicador = c(
    "Número de registros",
    "Número de variables",
    "Número de trimestres",
    "Primer período",
    "Último período"
  ),
  
  valor = c(
    nrow(base_eph_exploratoria),
    ncol(base_eph_exploratoria),
    dplyr::n_distinct(base_eph_exploratoria$periodo),
    min(base_eph_exploratoria$periodo),
    max(base_eph_exploratoria$periodo)
  )
  
)

#------------------------------------------------------------
# Calcular cantidad de registros por trimestre
#------------------------------------------------------------

registros_por_periodo <- base_eph_exploratoria %>%
  
  count(
    periodo,
    name = "n_registros"
  ) %>%
  
  arrange(periodo)

#------------------------------------------------------------
# Visualizar resultados generales
#------------------------------------------------------------

dimension_general

registros_por_periodo

#------------------------------------------------------------
# Guardar dimensión general
#------------------------------------------------------------

write.csv(
  dimension_general,
  file.path(
    ruta_exploratorios,
    "dimension_general_dataset.csv"
  ),
  row.names = FALSE
)

#------------------------------------------------------------
# Guardar registros por período
#------------------------------------------------------------

write.csv(
  registros_por_periodo,
  file.path(
    ruta_exploratorios,
    "registros_por_periodo.csv"
  ),
  row.names = FALSE
)


#============================================================
# B) DISPONIBILIDAD Y TIPO DE VARIABLES
#============================================================

#------------------------------------------------------------
# Construir inventario general de variables
#------------------------------------------------------------

inventario_variables <- tibble::tibble(
  
  variable = variables_tfm,
  
  disponible = variables_tfm %in%
    names(base_eph_exploratoria),
  
  tipo_almacenado = purrr::map_chr(
    variables_tfm,
    function(variable) {
      
      if (variable %in% names(base_eph_exploratoria)) {
        
        class(
          base_eph_exploratoria[[variable]]
        )[1]
        
      } else {
        
        NA_character_
        
      }
      
    }
  )
  
)

#------------------------------------------------------------
# Construir disponibilidad por trimestre
#------------------------------------------------------------

disponibilidad_periodo <- purrr::map_dfr(
  
  variables_presentes,
  
  function(variable) {
    
    base_eph_exploratoria %>%
      
      group_by(periodo) %>%
      
      summarise(
        
        variable = variable,
        
        n_registros = n(),
        
        n_con_dato = sum(
          !is.na(.data[[variable]]) &
            .data[[variable]] != ""
        ),
        
        disponible = n_con_dato > 0,
        
        .groups = "drop"
      )
    
  }
  
) %>%
  
  select(
    periodo,
    variable,
    n_registros,
    n_con_dato,
    disponible
  ) %>%
  
  arrange(
    variable,
    periodo
  )

#------------------------------------------------------------
# Guardar inventario de variables
#------------------------------------------------------------

write.csv(
  inventario_variables,
  file.path(
    ruta_exploratorios,
    "inventario_variables_tfm.csv"
  ),
  row.names = FALSE
)

#------------------------------------------------------------
# Guardar disponibilidad temporal
#------------------------------------------------------------

write.csv(
  disponibilidad_periodo,
  file.path(
    ruta_exploratorios,
    "disponibilidad_variables_periodo.csv"
  ),
  row.names = FALSE
)


#============================================================
# C) VALORES AUSENTES GLOBALES
#============================================================

#------------------------------------------------------------
# Calcular valores ausentes por variable y período
#------------------------------------------------------------

faltantes_globales <- purrr::map_dfr(
  
  variables_presentes,
  
  function(variable) {
    
    base_eph_exploratoria %>%
      
      group_by(periodo) %>%
      
      summarise(
        
        variable = variable,
        
        n_total = n(),
        
        n_ausentes = sum(
          is.na(.data[[variable]]) |
            .data[[variable]] == ""
        ),
        
        porcentaje_ausentes =
          100 * n_ausentes / n_total,
        
        n_valores_distintos = n_distinct(
          .data[[variable]],
          na.rm = TRUE
        ),
        
        .groups = "drop"
      )
    
  }
  
) %>%
  
  select(
    periodo,
    variable,
    n_total,
    n_ausentes,
    porcentaje_ausentes,
    n_valores_distintos
  ) %>%
  
  arrange(
    variable,
    periodo
  )

#------------------------------------------------------------
# Guardar auditoría global de valores ausentes
#------------------------------------------------------------

write.csv(
  faltantes_globales,
  file.path(
    ruta_exploratorios,
    "faltantes_globales_por_periodo.csv"
  ),
  row.names = FALSE
)


#============================================================
# D) DISTRIBUCIÓN DE VARIABLES CATEGÓRICAS
#============================================================

#------------------------------------------------------------
# Definir variables categóricas para la exploración
#------------------------------------------------------------

variables_categoricas <- c(
  "ESTADO",
  "CAT_OCUP",
  "EMPLEO",
  "SECTOR",
  "PP07H",
  "PP07C",
  "CH04",
  "NIVEL_ED",
  "REGION",
  "PP04C99"
)

#------------------------------------------------------------
# Conservar variables categóricas disponibles
#------------------------------------------------------------

variables_categoricas <- intersect(
  variables_categoricas,
  names(base_eph_exploratoria)
)

#------------------------------------------------------------
# Calcular distribución muestral y ponderada
#------------------------------------------------------------

distribucion_categoricas <- purrr::map_dfr(
  
  variables_categoricas,
  
  function(variable) {
    
    base_eph_exploratoria %>%
      
      mutate(
        valor = as.character(
          .data[[variable]]
        ),
        ponderador = as.numeric(PONDERA)
      ) %>%
      
      filter(
        !is.na(valor),
        valor != ""
      ) %>%
      
      group_by(
        periodo,
        valor
      ) %>%
      
      summarise(
        
        variable = variable,
        
        n_muestral = n(),
        
        poblacion_expandida = sum(
          ponderador,
          na.rm = TRUE
        ),
        
        .groups = "drop"
      ) %>%
      
      group_by(
        periodo,
        variable
      ) %>%
      
      mutate(
        
        porcentaje_muestral =
          100 * n_muestral /
          sum(n_muestral),
        
        porcentaje_ponderado =
          100 * poblacion_expandida /
          sum(poblacion_expandida)
        
      ) %>%
      
      ungroup()
    
  }
  
) %>%
  
  select(
    periodo,
    variable,
    valor,
    n_muestral,
    porcentaje_muestral,
    poblacion_expandida,
    porcentaje_ponderado
  ) %>%
  
  arrange(
    variable,
    periodo,
    valor
  )

#------------------------------------------------------------
# Guardar distribución de variables categóricas
#------------------------------------------------------------

write.csv(
  distribucion_categoricas,
  file.path(
    ruta_exploratorios,
    "distribucion_variables_categoricas.csv"
  ),
  row.names = FALSE
)


#============================================================
# 5) CIERRE DE LA AUDITORÍA
#============================================================

#------------------------------------------------------------
# Eliminar base temporal de la memoria
#------------------------------------------------------------

rm(base_eph_exploratoria)

#------------------------------------------------------------
# Liberar memoria
#------------------------------------------------------------

invisible(
  gc()
)


message(
  paste(
    "analisi exploratorio finalizado",
    "Los resultados se guardaron en",
    "Salidas/03_exploratorios."
  )
)







#============================================================
# 2) FALTANTES EN VARIABLES DE ASALARIADOS
#============================================================

#------------------------------------------------------------
# Definir universo de asalariados ocupados
#------------------------------------------------------------

# Cargar base si no está en memoria
if (!exists("base_eph")) {
  base_eph <- readRDS(file.path(ruta_proyecto, "Salidas", "base_eph_2022_2025.rds"))
}

# Crear copia para exploración
base_asalariados <- base_eph %>%
  
  filter(
    ESTADO == "1",
    CAT_OCUP == "3"
  )

#------------------------------------------------------------
# Variables a auditar
#------------------------------------------------------------

variables_asalariados <- c(
  "PP07H",
  "PP07C",
  "PP07G1",
  "PP07G2",
  "PP07G3",
  "PP07G4",
  "PP07K"
)

#------------------------------------------------------------
# Calcular faltantes dentro del universo aplicable
#------------------------------------------------------------

faltantes_asalariados <- purrr::map_dfr(
  
  variables_asalariados,
  
  function(variable) {
    
    base_asalariados %>%
      
      group_by(periodo) %>%
      
      summarise(
        
        variable = variable,
        
        n_elegibles = n(),
        
        n_con_dato = sum(
          !is.na(.data[[variable]]) &
            .data[[variable]] != ""
        ),
        
        n_ausentes = sum(
          is.na(.data[[variable]]) |
            .data[[variable]] == ""
        ),
        
        porcentaje_ausentes =
          100 * n_ausentes / n_elegibles,
        
        n_valores_distintos =
          n_distinct(
            .data[[variable]],
            na.rm = TRUE
          ),
        
        .groups = "drop"
        
      )
    
  }
  
) %>%
  
  arrange(
    variable,
    periodo
  )

#------------------------------------------------------------
# Resumen promedio por variable
#------------------------------------------------------------

resumen_faltantes_asalariados <- faltantes_asalariados %>%
  
  group_by(variable) %>%
  
  summarise(
    
    promedio_ausentes =
      mean(
        porcentaje_ausentes,
        na.rm = TRUE
      ),
    
    minimo =
      min(
        porcentaje_ausentes,
        na.rm = TRUE
      ),
    
    maximo =
      max(
        porcentaje_ausentes,
        na.rm = TRUE
      ),
    
    .groups = "drop"
    
  ) %>%
  
  arrange(
    desc(promedio_ausentes)
  )

#------------------------------------------------------------
# Visualizar resultados
#------------------------------------------------------------

faltantes_asalariados

resumen_faltantes_asalariados

#------------------------------------------------------------
# Guardar resultados
#------------------------------------------------------------

write.csv(
  
  faltantes_asalariados,
  
  file.path(
    ruta_exploratorios,
    "faltantes_asalariados_universo_valido.csv"
  ),
  
  row.names = FALSE
  
)

write.csv(
  
  resumen_faltantes_asalariados,
  
  file.path(
    ruta_exploratorios,
    "resumen_faltantes_asalariados.csv"
  ),
  
  row.names = FALSE
  
)




#============================================================
# 2.1) CALIDAD DE RESPUESTA EN VARIABLES DE ASALARIADOS
#============================================================

#------------------------------------------------------------
# Definir códigos válidos por variable
#------------------------------------------------------------

codigos_validos_asalariados <- list(
  
  # Identificar empleo con o sin tiempo de finalización
  PP07C = c("1", "2"),
  
  # Identificar acceso a vacaciones pagadas
  PP07G1 = c("1", "2"),
  
  # Identificar acceso a aguinaldo
  PP07G2 = c("1", "2"),
  
  # Identificar días pagados por enfermedad
  PP07G3 = c("1", "2"),
  
  # Identificar cobertura de obra social
  PP07G4 = c("1", "2"),
  
  # Identificar descuento jubilatorio
  PP07H = c("1", "2"),
  
  # Identificar modalidad de comprobante de pago
  PP07K = c("1", "2", "3", "4", "5")
  
)

#------------------------------------------------------------
# Construir distribución de códigos observados
#------------------------------------------------------------

distribucion_codigos_asalariados <- purrr::map_dfr(
  
  variables_asalariados,
  
  function(variable) {
    
    base_asalariados %>%
      
      mutate(
        
        valor = as.character(
          .data[[variable]]
        ),
        
        categoria_respuesta = case_when(
          
          is.na(valor) |
            valor == "" ~ "Ausencia física",
          
          valor == "0" ~ "Fuera de secuencia o no aplicable",
          
          valor == "9" ~ "No sabe / no responde",
          
          valor %in%
            codigos_validos_asalariados[[variable]] ~
            "Respuesta válida",
          
          TRUE ~ "Código no previsto"
          
        )
        
      ) %>%
      
      group_by(
        periodo,
        valor,
        categoria_respuesta
      ) %>%
      
      summarise(
        
        variable = variable,
        
        n_muestral = n(),
        
        poblacion_expandida = sum(
          as.numeric(PONDERA),
          na.rm = TRUE
        ),
        
        .groups = "drop"
        
      ) %>%
      
      group_by(
        periodo,
        variable
      ) %>%
      
      mutate(
        
        porcentaje_muestral =
          100 * n_muestral /
          sum(n_muestral),
        
        porcentaje_ponderado =
          100 * poblacion_expandida /
          sum(poblacion_expandida)
        
      ) %>%
      
      ungroup()
    
  }
  
) %>%
  
  select(
    periodo,
    variable,
    valor,
    categoria_respuesta,
    n_muestral,
    porcentaje_muestral,
    poblacion_expandida,
    porcentaje_ponderado
  ) %>%
  
  arrange(
    variable,
    periodo,
    categoria_respuesta,
    valor
  )

#------------------------------------------------------------
# Resumir calidad de respuesta por variable y período
#------------------------------------------------------------

calidad_respuesta_asalariados <- distribucion_codigos_asalariados %>%
  
  group_by(
    periodo,
    variable,
    categoria_respuesta
  ) %>%
  
  summarise(
    
    n_muestral = sum(
      n_muestral
    ),
    
    poblacion_expandida = sum(
      poblacion_expandida
    ),
    
    .groups = "drop"
  ) %>%
  
  group_by(
    periodo,
    variable
  ) %>%
  
  mutate(
    
    porcentaje_muestral =
      100 * n_muestral /
      sum(n_muestral),
    
    porcentaje_ponderado =
      100 * poblacion_expandida /
      sum(poblacion_expandida)
    
  ) %>%
  
  ungroup() %>%
  
  arrange(
    variable,
    periodo,
    categoria_respuesta
  )

#------------------------------------------------------------
# Construir resumen general por variable
#------------------------------------------------------------

resumen_calidad_asalariados <- calidad_respuesta_asalariados %>%
  
  group_by(
    variable,
    categoria_respuesta
  ) %>%
  
  summarise(
    
    n_muestral_total = sum(
      n_muestral
    ),
    
    poblacion_expandida_total = sum(
      poblacion_expandida
    ),
    
    porcentaje_muestral_total =
      100 * n_muestral_total /
      sum(n_muestral_total),
    
    porcentaje_ponderado_total =
      100 * poblacion_expandida_total /
      sum(poblacion_expandida_total),
    
    .groups = "drop_last"
  ) %>%
  
  ungroup() %>%
  
  arrange(
    variable,
    categoria_respuesta
  )

#------------------------------------------------------------
# Identificar códigos no previstos
#------------------------------------------------------------

codigos_no_previstos_asalariados <-
  distribucion_codigos_asalariados %>%
  
  filter(
    categoria_respuesta == "Código no previsto"
  )

#------------------------------------------------------------
# Visualizar resumen de calidad
#------------------------------------------------------------

print(
  resumen_calidad_asalariados,
  n = Inf
)

#------------------------------------------------------------
# Advertir sobre códigos no previstos
#------------------------------------------------------------

if (nrow(codigos_no_previstos_asalariados) > 0) {
  
  warning(
    paste(
      "Se identificaron códigos no previstos.",
      "Revisar codigos_no_previstos_asalariados."
    )
  )
  
} else {
  
  message(
    "No se identificaron códigos fuera de los previstos."
  )
  
}

#------------------------------------------------------------
# Guardar distribución detallada de códigos
#------------------------------------------------------------

write.csv(
  
  distribucion_codigos_asalariados,
  
  file.path(
    ruta_exploratorios,
    "distribucion_codigos_asalariados.csv"
  ),
  
  row.names = FALSE
  
)

#------------------------------------------------------------
# Guardar calidad de respuesta por período
#------------------------------------------------------------

write.csv(
  
  calidad_respuesta_asalariados,
  
  file.path(
    ruta_exploratorios,
    "calidad_respuesta_asalariados_periodo.csv"
  ),
  
  row.names = FALSE
  
)

#------------------------------------------------------------
# Guardar resumen general de calidad
#------------------------------------------------------------

write.csv(
  
  resumen_calidad_asalariados,
  
  file.path(
    ruta_exploratorios,
    "resumen_calidad_respuesta_asalariados.csv"
  ),
  
  row.names = FALSE
  
)

#------------------------------------------------------------
# Guardar códigos no previstos
#------------------------------------------------------------

write.csv(
  
  codigos_no_previstos_asalariados,
  
  file.path(
    ruta_exploratorios,
    "codigos_no_previstos_asalariados.csv"
  ),
  
  row.names = FALSE
  
)




#============================================================
# 3) FALTANTES EN VARIABLES DE OCUPADOS
#============================================================

#------------------------------------------------------------
# Universo
#------------------------------------------------------------

base_ocupados <- base_eph %>%
  
  filter(
    ESTADO == "1"
  )

#------------------------------------------------------------
# Variables
#------------------------------------------------------------

variables_ocupados <- c(
  "PP04B3_ANO",
  "PP04B3_MES",
  "PP3E_TOT",
  "PP3F_TOT",
  "EMPLEO",
  "SECTOR"
)

#------------------------------------------------------------
# Auditoría básica
#------------------------------------------------------------

faltantes_ocupados <- purrr::map_dfr(
  
  variables_ocupados,
  
  function(variable) {
    
    base_ocupados %>%
      
      group_by(periodo) %>%
      
      summarise(
        
        variable = variable,
        
        n_elegibles = n(),
        
        n_ausentes = sum(
          is.na(.data[[variable]]) |
            .data[[variable]] == ""
        ),
        
        porcentaje_ausentes =
          100 * n_ausentes / n_elegibles,
        
        n_valores_distintos =
          n_distinct(
            .data[[variable]],
            na.rm = TRUE
          ),
        
        .groups = "drop"
        
      )
    
  }
  
)

#------------------------------------------------------------
# Resumen
#------------------------------------------------------------

resumen_faltantes_ocupados <- faltantes_ocupados %>%
  
  group_by(variable) %>%
  
  summarise(
    
    promedio_ausentes =
      mean(
        porcentaje_ausentes,
        na.rm = TRUE
      ),
    
    minimo =
      min(
        porcentaje_ausentes,
        na.rm = TRUE
      ),
    
    maximo =
      max(
        porcentaje_ausentes,
        na.rm = TRUE
      ),
    
    .groups = "drop"
    
  ) %>%
  
  arrange(
    desc(promedio_ausentes)
  )

#------------------------------------------------------------
# Visualizar
#------------------------------------------------------------

faltantes_ocupados

resumen_faltantes_ocupados





#============================================================
# 4) FALTANTES EN VARIABLES DE INDEPENDIENTES
#============================================================

#------------------------------------------------------------
# Universo
#------------------------------------------------------------

base_independientes <- base_eph %>%
  
  filter(
    ESTADO == "1",
    CAT_OCUP %in% c("1", "2")
  )

#------------------------------------------------------------
# Variables
#------------------------------------------------------------

variables_independientes <- c(
  "PP05I",
  "PP05J",
  "PP05K",
  "PP06A",
  "PP06E",
  "PP06E1"
)

#------------------------------------------------------------
# Verificar existencia
#------------------------------------------------------------

variables_independientes <- intersect(
  variables_independientes,
  names(base_independientes)
)

#------------------------------------------------------------
# Auditoría básica
#------------------------------------------------------------

faltantes_independientes <- purrr::map_dfr(
  
  variables_independientes,
  
  function(variable) {
    
    base_independientes %>%
      
      group_by(periodo) %>%
      
      summarise(
        
        variable = variable,
        
        n_elegibles = n(),
        
        n_ausentes = sum(
          is.na(.data[[variable]]) |
            .data[[variable]] == ""
        ),
        
        porcentaje_ausentes =
          100 * n_ausentes / n_elegibles,
        
        n_valores_distintos =
          n_distinct(
            .data[[variable]],
            na.rm = TRUE
          ),
        
        .groups = "drop"
        
      )
    
  }
  
)

#------------------------------------------------------------
# Resumen
#------------------------------------------------------------

resumen_faltantes_independientes <-
  faltantes_independientes %>%
  
  group_by(variable) %>%
  
  summarise(
    
    promedio_ausentes =
      mean(
        porcentaje_ausentes,
        na.rm = TRUE
      ),
    
    minimo =
      min(
        porcentaje_ausentes,
        na.rm = TRUE
      ),
    
    maximo =
      max(
        porcentaje_ausentes,
        na.rm = TRUE
      ),
    
    .groups = "drop"
    
  ) %>%
  
  arrange(
    desc(promedio_ausentes)
  )

#------------------------------------------------------------
# Visualizar
#------------------------------------------------------------

faltantes_independientes

resumen_faltantes_independientes






#============================================================
# 5) AUDITORÍA MÍNIMA DE INGRESOS
#============================================================

variables_ingreso <- c(
  "P21",
  "P47T",
  "ITF",
  "IPCF"
)

auditoria_ingresos <- purrr::map_dfr(
  
  variables_ingreso,
  
  function(variable) {
    
    universo <- if(variable %in% c("P21","P47T")) {
      
      base_eph %>%
        filter(ESTADO == "1")
      
    } else {
      
      base_eph
      
    }
    
    valores <- suppressWarnings(
      as.numeric(universo[[variable]])
    )
    
    tibble::tibble(
      
      variable = variable,
      
      n_registros =
        length(valores),
      
      n_ausentes =
        sum(is.na(valores)),
      
      porcentaje_ausentes =
        100 * mean(is.na(valores)),
      
      n_cero =
        sum(valores == 0, na.rm = TRUE),
      
      porcentaje_cero =
        100 * mean(valores == 0, na.rm = TRUE),
      
      n_negativos =
        sum(valores < 0, na.rm = TRUE),
      
      minimo =
        min(valores, na.rm = TRUE),
      
      mediana =
        median(valores, na.rm = TRUE),
      
      maximo =
        max(valores, na.rm = TRUE)
      
    )
    
  }
  
)

auditoria_ingresos



#============================================================
# codigos -9 (no quiere declarar)
#============================================================

variables_ingreso <- c(
  "P21",
  "P47T",
  "ITF",
  "IPCF"
)

codigos_menos9 <- purrr::map_dfr(
  
  variables_ingreso,
  
  function(variable) {
    
    tibble::tibble(
      
      variable = variable,
      
      n_menos9 =
        sum(
          suppressWarnings(
            as.numeric(base_eph[[variable]])
          ) == -9,
          na.rm = TRUE
        )
      
    )
    
  }
  
)

codigos_menos9


base_eph %>%
  
  filter(
    ESTADO == "1",
    P21 == "-9"
  ) %>%
  
  count(
    CAT_OCUP,
    sort = TRUE
  )

base_eph %>%
  
  filter(
    ESTADO == "1",
    P21 == "-9"
  ) %>%
  
  count(
    ANO4,
    TRIMESTRE
  )

#============================================================
# ¿DE DONDE VIENEN LOS NA DE IPCF?
#============================================================

base_eph %>%
  
  summarise(
    
    n_total = n(),
    
    ipcf_na =
      sum(is.na(IPCF)),
    
    itf_na =
      sum(is.na(ITF)),
    
    ipcf_na_itf_ok =
      sum(
        is.na(IPCF) &
          !is.na(ITF)
      ),
    
    ipcf_na_itf_na =
      sum(
        is.na(IPCF) &
          is.na(ITF)
      )
    
  )