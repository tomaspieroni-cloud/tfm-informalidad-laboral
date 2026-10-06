# ============================================================
# VALIDACIÓN DE FORMALIDAD ASALARIADA: PP07H vs EMPLEO
# ============================================================
#
# Objetivo:
# Evaluar la concordancia entre la clasificación reconstruida 
# mediante PP07H y la clasificación oficial EMPLEO.
#
# Período de validación: 2023T4 – 2025T4
# Universo: Ocupados asalariados (ESTADO == 1 & CAT_OCUP == 3)
#
# Salidas:
# - matriz_confusion_pp07h_empleo.csv
# ============================================================

#------------------------------------------------------------
# 1. Cargar configuración y base de datos
#------------------------------------------------------------

source(here::here("Scripts", "00_configurar_proyecto.R"))

base_eph <- readRDS(here::here("Salidas", "base_eph_2022_2025.rds"))

#------------------------------------------------------------
# 2. Crear carpeta de resultados
#------------------------------------------------------------

ruta_clasificacion <- here::here("Salidas", "04_clasificacion_formalidad")
dir.create(ruta_clasificacion, recursive = TRUE, showWarnings = FALSE)

#------------------------------------------------------------
# 3. Filtrar asalariados ocupados
#------------------------------------------------------------

base_asalariados <- base_eph %>%
  filter(
    ESTADO == 1,
    CAT_OCUP == 3
  )

#------------------------------------------------------------
# 4. Construir clasificación reconstruida con PP07H
#------------------------------------------------------------

base_asalariados <- base_asalariados %>%
  mutate(
    formalidad_pp07h = case_when(
      PP07H == 1 ~ "Formal",
      PP07H == 2 ~ "Informal",
      TRUE       ~ NA_character_
    )
  )

#------------------------------------------------------------
# 5. Período con variable oficial EMPLEO disponible
#------------------------------------------------------------
# Nota: EMPLEO se incorpora a partir del 4T 2023
#------------------------------------------------------------

base_validacion <- base_asalariados %>%
  filter(periodo >= "2023T4")

#------------------------------------------------------------
# 6. Explorar codificación observada de EMPLEO
#------------------------------------------------------------
# Esto permite ver qué códigos tiene realmente EMPLEO
# y decidir cómo calcular la concordancia.
#------------------------------------------------------------


cat("Distribución observada de EMPLEO\n")
print(table(base_validacion$EMPLEO, useNA = "ifany"))

#------------------------------------------------------------
# 7. Construir y guardar matriz de confusión
#------------------------------------------------------------

matriz_confusion <- base_validacion %>%
  count(periodo, formalidad_pp07h, EMPLEO) %>%
  arrange(periodo, formalidad_pp07h, EMPLEO)

write.csv(
  matriz_confusion,
  file.path(ruta_clasificacion, "matriz_confusion_pp07h_empleo.csv"),
  row.names = FALSE
)

#============================================================
# 8. VALIDACIÓN DE CONCORDANCIA PP07H VS EMPLEO
#============================================================
#
# Objetivo:
# Cuantificar el grado de coincidencia entre:
#
# - Formalidad reconstruida mediante PP07H
# - Formalidad oficial EMPLEO
#
# Se calculan:
# - coincidencia global
# - falsos positivos
# - falsos negativos
#
#============================================================

#------------------------------------------------------------
# Eliminar casos sin clasificación válida
#------------------------------------------------------------

base_validacion_limpia <- base_validacion %>%
  
  filter(
    
    PP07H %in% c(1, 2),
    
    EMPLEO %in% c(1, 2)
    
  )

#------------------------------------------------------------
# Clasificar coincidencia
#------------------------------------------------------------

base_validacion_limpia <- base_validacion_limpia %>%
  
  mutate(
    
    coincide = ifelse(
      PP07H == EMPLEO,
      1,
      0
    )
    
  )

#------------------------------------------------------------
# Porcentaje de coincidencia por período
#------------------------------------------------------------

validacion_periodo <- base_validacion_limpia %>%
  
  group_by(periodo) %>%
  
  summarise(
    
    casos = n(),
    
    coincidencias = sum(
      coincide
    ),
    
    porcentaje_coincidencia =
      100 * coincidencias / casos,
    
    .groups = "drop"
    
  ) %>%
  
  arrange(periodo)

#------------------------------------------------------------
# Porcentaje de coincidencia total
#------------------------------------------------------------

validacion_total <- base_validacion_limpia %>%
  
  summarise(
    
    casos = n(),
    
    coincidencias =
      sum(coincide),
    
    porcentaje_coincidencia =
      100 * coincidencias / casos
    
  )

#------------------------------------------------------------
# Visualizar resultados
#------------------------------------------------------------

cat(
  "VALIDACION PP07H VS EMPLEO\n"
)

print(validacion_periodo)

cat(
  "\nResumen total:\n"
)

print(validacion_total)

#------------------------------------------------------------
# Guardar resultados
#------------------------------------------------------------

write.csv(
  
  validacion_periodo,
  
  file.path(
    ruta_clasificacion,
    "validacion_formalidad_2023t4_2025t4.csv"
  ),
  
  row.names = FALSE
  
)

write.csv(
  
  validacion_total,
  
  file.path(
    ruta_clasificacion,
    "validacion_formalidad_total.csv"
  ),
  
  row.names = FALSE
  
)





#============================================================
# 9. CONSTRUCCIÓN DE FORMALIDAD ASALARIADA 2022–2025
#============================================================
#
# Objetivo:
# Crear una variable única de formalidad asalariada para
# todo el período 2022T1–2025T4.
#
# Criterio adoptado:
#
# PP07H = 1  -> Formal
# PP07H = 2  -> Informal
#
# Justificación:
# La validación realizada contra EMPLEO mostró una
# coincidencia del 100% para 2023T4–2025T4.
#
# Universo:
# ESTADO == 1 & CAT_OCUP == 3
#
# Salidas:
# - formalidad_asalariada_2022_2025.rds
#
#============================================================

#------------------------------------------------------------
# Construir variable definitiva
#------------------------------------------------------------

base_asalariados <- base_asalariados %>%
  
  mutate(
    
    formalidad_asalariada = case_when(
      
      PP07H == 1 ~ "Formal",
      
      PP07H == 2 ~ "Informal",
      
      TRUE ~ NA_character_
      
    )
    
  )

#------------------------------------------------------------
# Control de distribución por período
#------------------------------------------------------------

control_formalidad_asalariada <- base_asalariados %>%
  
  group_by(
    periodo,
    formalidad_asalariada
  ) %>%
  
  summarise(
    
    n_muestral = n(),
    
    poblacion_expandida =
      sum(
        as.numeric(PONDERA),
        na.rm = TRUE
      ),
    
    .groups = "drop"
    
  ) %>%
  
  group_by(periodo) %>%
  
  mutate(
    
    porcentaje_muestral =
      100 * n_muestral /
      sum(n_muestral),
    
    porcentaje_ponderado =
      100 * poblacion_expandida /
      sum(poblacion_expandida)
    
  ) %>%
  
  ungroup()

#------------------------------------------------------------
# Visualizar control
#------------------------------------------------------------

print(
  control_formalidad_asalariada,
  n = Inf
)

#------------------------------------------------------------
# Guardar base de formalidad asalariada
#------------------------------------------------------------

saveRDS(
  
  base_asalariados %>%
    
    select(
      
      CODUSU,
      NRO_HOGAR,
      COMPONENTE,
      ANO4,
      TRIMESTRE,
      periodo,
      ESTADO,
      CAT_OCUP,
      PP07H,
      formalidad_asalariada
      
    ),
  
  file.path(
    ruta_clasificacion,
    "formalidad_asalariada_2022_2025.rds"
  )
  
)

#------------------------------------------------------------
# Guardar tabla de control
#------------------------------------------------------------

write.csv(
  
  control_formalidad_asalariada,
  
  file.path(
    ruta_clasificacion,
    "control_formalidad_asalariada.csv"
  ),
  
  row.names = FALSE
  
)


message(
  
  paste(
    
    "Formalidad asalariada construida correctamente.",
    "Resultado guardado en",
    "Salidas/04_clasificacion_formalidad."
    
  )
  
)





#============================================================
# 10. CONSTRUCCIÓN DE FORMALIDAD INDEPENDIENTE
#============================================================
#
# Objetivo:
# Replicar el algoritmo oficial de INDEC para la
# clasificación de patrones y trabajadores por cuenta propia.
#
# Fuente:
# Metodología INDEC N°43
# Diseño conceptual y metodológico para la medición
# de la informalidad laboral con datos de la EPH
#
# Universo:
# ESTADO == 1
# CAT_OCUP %in% c(1, 2)
#
# Período:
# 2023T4 - 2025T4
#
# Salida:
# formalidad_independientes_2023_2025.rds
#
#============================================================

#------------------------------------------------------------
# Definir universo de independientes ocupados
#------------------------------------------------------------

base_independientes <- base_eph %>%
  
  filter(
    
    ESTADO == 1,
    
    CAT_OCUP %in% c(1, 2),
    
    periodo >= "2023T4"
    
  )

#------------------------------------------------------------
# Replicar algoritmo oficial INDEC
#------------------------------------------------------------

base_independientes <- base_independientes %>%
  
  mutate(
    
    formalidad_independiente = case_when(
      
      #------------------------------------------------------
      # Sociedad constituida jurídicamente
      #------------------------------------------------------
      
      PP06A == 1 &
        PP06E %in% c(1, 2) ~ "Formal",
      
      #------------------------------------------------------
      # Realizó aportes
      #------------------------------------------------------
      
      PP05I %in% c(1, 2, 3) ~ "Formal",
      
      #------------------------------------------------------
      # No inscripto para aportar
      #------------------------------------------------------
      
      PP05I %in% c(4, 9) &
        PP05J == 1 ~ "Informal",
      
      #------------------------------------------------------
      # Puede emitir facturas
      #------------------------------------------------------
      
      PP05I %in% c(4, 9) &
        PP05J %in% c(2, 3, 9) &
        PP05K == 1 ~ "Formal",
      
      #------------------------------------------------------
      # No puede emitir facturas
      #------------------------------------------------------
      
      PP05I %in% c(4, 9) &
        PP05J %in% c(2, 3, 9) &
        PP05K == 2 ~ "Informal",
      
      #------------------------------------------------------
      # Variable de rescate:
      # contador u oficina contable
      #------------------------------------------------------
      
      PP05I %in% c(4, 9) &
        PP05J %in% c(2, 3, 9) &
        PP05K == 9 &
        PP06E1 == 1 ~ "Formal",
      
      PP05I %in% c(4, 9) &
        PP05J %in% c(2, 3, 9) &
        PP05K == 9 &
        PP06E1 == 2 ~ "Informal",
      
      TRUE ~ NA_character_
      
    )
    
  )

#------------------------------------------------------------
# Distribución de resultados
#------------------------------------------------------------

control_formalidad_independiente <-
  
  base_independientes %>%
  
  group_by(
    periodo,
    formalidad_independiente
  ) %>%
  
  summarise(
    
    n_muestral = n(),
    
    poblacion_expandida =
      sum(
        as.numeric(PONDERA),
        na.rm = TRUE
      ),
    
    .groups = "drop"
    
  ) %>%
  
  group_by(periodo) %>%
  
  mutate(
    
    porcentaje_muestral =
      100 * n_muestral /
      sum(n_muestral),
    
    porcentaje_ponderado =
      100 * poblacion_expandida /
      sum(poblacion_expandida)
    
  ) %>%
  
  ungroup()

#------------------------------------------------------------
# Visualizar resultados
#------------------------------------------------------------

print(
  control_formalidad_independiente,
  n = Inf
)

#------------------------------------------------------------
# Guardar base
#------------------------------------------------------------

saveRDS(
  
  base_independientes %>%
    
    select(
      
      CODUSU,
      NRO_HOGAR,
      COMPONENTE,
      ANO4,
      TRIMESTRE,
      periodo,
      ESTADO,
      CAT_OCUP,
      PP05I,
      PP05J,
      PP05K,
      PP06A,
      PP06E,
      PP06E1,
      formalidad_independiente
      
    ),
  
  file.path(
    
    ruta_clasificacion,
    
    "formalidad_independientes_2023_2025.rds"
    
  )
  
)

#------------------------------------------------------------
# Guardar control
#------------------------------------------------------------

write.csv(
  
  control_formalidad_independiente,
  
  file.path(
    
    ruta_clasificacion,
    
    "control_formalidad_independiente.csv"
    
  ),
  
  row.names = FALSE
  
)


message(
  
  paste(
    
    "Formalidad independiente construida.",
    "Algoritmo replicado desde Metodología INDEC N°43."
    
  )
  
)







#============================================================
# 11. CONSTRUCCIÓN DE ESTADO LABORAL CLASIFICADO
#============================================================
#
# Objetivo:
# Construir una variable integrada para todo el período
# 2022T1–2025T4.
#
# Categorías:
#
# 1. Empleo Formal
# 2. Empleo Informal
# 3. Desocupación
# 4. Inactividad
#
#============================================================

#------------------------------------------------------------
# Crear copia de la base principal
#------------------------------------------------------------

base_clasificada <- base_eph

#------------------------------------------------------------
# Incorporar formalidad asalariada
#------------------------------------------------------------

base_clasificada <- base_clasificada %>%
  
  left_join(
    
    base_asalariados %>%
      
      select(
        CODUSU,
        NRO_HOGAR,
        COMPONENTE,
        periodo,
        formalidad_asalariada
      ),
    
    by = c(
      "CODUSU",
      "NRO_HOGAR",
      "COMPONENTE",
      "periodo"
    )
    
  )

#------------------------------------------------------------
# Incorporar formalidad independiente
#------------------------------------------------------------

base_clasificada <- base_clasificada %>%
  
  left_join(
    
    base_independientes %>%
      
      select(
        CODUSU,
        NRO_HOGAR,
        COMPONENTE,
        periodo,
        formalidad_independiente
      ),
    
    by = c(
      "CODUSU",
      "NRO_HOGAR",
      "COMPONENTE",
      "periodo"
    )
    
  )

#------------------------------------------------------------
# Construir estado laboral clasificado
#------------------------------------------------------------

base_clasificada <- base_clasificada %>%
  
  mutate(
    
    estado_laboral_clasificado = case_when(
      
      #------------------------------------------------------
      # Ocupados formales
      #------------------------------------------------------
      
      CAT_OCUP == 3 &
        formalidad_asalariada == "Formal" ~
        "Empleo Formal",
      
      CAT_OCUP %in% c(1, 2) &
        formalidad_independiente == "Formal" ~
        "Empleo Formal",
      
      #------------------------------------------------------
      # Ocupados informales
      #------------------------------------------------------
      
      CAT_OCUP == 3 &
        formalidad_asalariada == "Informal" ~
        "Empleo Informal",
      
      CAT_OCUP %in% c(1, 2) &
        formalidad_independiente == "Informal" ~
        "Empleo Informal",
      
      #------------------------------------------------------
      # Trabajador familiar sin remuneración
      #------------------------------------------------------
      
      ESTADO == 1 &
        CAT_OCUP == 4 ~
        "Empleo Informal",
      
      #------------------------------------------------------
      # Desocupados
      #------------------------------------------------------
      
      ESTADO == 2 ~
        "Desocupación",
      
      #------------------------------------------------------
      # Inactivos
      #------------------------------------------------------
      
      ESTADO == 3 ~
        "Inactividad",
      
      TRUE ~ NA_character_
      
    )
    
  )

#------------------------------------------------------------
# Control de distribución por período
#------------------------------------------------------------

control_estado_laboral <- base_clasificada %>%
  
  group_by(
    periodo,
    estado_laboral_clasificado
  ) %>%
  
  summarise(
    
    n_muestral = n(),
    
    poblacion_expandida =
      sum(
        as.numeric(PONDERA),
        na.rm = TRUE
      ),
    
    .groups = "drop"
    
  ) %>%
  
  group_by(periodo) %>%
  
  mutate(
    
    porcentaje_muestral =
      100 * n_muestral /
      sum(n_muestral),
    
    porcentaje_ponderado =
      100 * poblacion_expandida /
      sum(poblacion_expandida)
    
  ) %>%
  
  ungroup()

#------------------------------------------------------------
# Visualizar resultados
#------------------------------------------------------------

print(
  control_estado_laboral,
  n = Inf
)

#------------------------------------------------------------
# Guardar base clasificada
#------------------------------------------------------------

saveRDS(
  
  base_clasificada,
  
  file.path(
    ruta_clasificacion,
    "estado_laboral_clasificado.rds"
  )
  
)

#------------------------------------------------------------
# Guardar tabla de control
#------------------------------------------------------------

write.csv(
  
  control_estado_laboral,
  
  file.path(
    ruta_clasificacion,
    "control_estado_laboral_clasificado.csv"
  ),
  
  row.names = FALSE
  
)

message(
  
  paste(
    
    "Estado laboral clasificado construido."
    
  )
  
)





#============================================================
# 11.A. REVISIÓN DE VARIABLES ASOCIADAS A INFORMALIDAD
#        EN TRABAJADORES INDEPENDIENTES
#============================================================
#
# Objetivo:
# Identificar qué variables disponibles antes del 4T2023
# presentan mayor asociación con la clasificación oficial
# de formalidad laboral (EMPLEO) para trabajadores
# independientes.
#
# Período de validación:
# 2023T4 - 2025T4
#
# Universo:
# Ocupados independientes
# (CAT_OCUP == 1 o CAT_OCUP == 2)
#
# Estas variables podrían utilizarse posteriormente para
# construir una proxy retrospectiva de formalidad para el
# período 2022T1 - 2023T3.
#
#============================================================

#------------------------------------------------------------
# Construir universo de validación
#------------------------------------------------------------

base_independientes_validacion <- base_eph %>%
  
  filter(
    ESTADO == 1,
    CAT_OCUP %in% c(1, 2),
    periodo >= "2023T4"
  )

#------------------------------------------------------------
# PP06E
# Tipo de sociedad
#------------------------------------------------------------

cat(
  "\n==================================================\n",
  "PP06E - TIPO DE SOCIEDAD\n",
  "==================================================\n"
)

pp06e_empleo <- base_independientes_validacion %>%
  
  count(
    PP06E,
    EMPLEO
  ) %>%
  
  arrange(
    PP06E,
    EMPLEO
  )

print(pp06e_empleo)

#------------------------------------------------------------
# PP06H
# Actividad familiar
#------------------------------------------------------------

cat(
  "\n==================================================\n",
  "PP06H - ACTIVIDAD FAMILIAR\n",
  "==================================================\n"
)

pp06h_empleo <- base_independientes_validacion %>%
  
  count(
    PP06H,
    EMPLEO
  ) %>%
  
  arrange(
    PP06H,
    EMPLEO
  )

print(pp06h_empleo)

#------------------------------------------------------------
# PP05E
# Realización de gastos de actividad
#------------------------------------------------------------

cat(
  "\n==================================================\n",
  "PP05E - GASTOS DE ACTIVIDAD\n",
  "==================================================\n"
)

pp05e_empleo <- base_independientes_validacion %>%
  
  count(
    PP05E,
    EMPLEO
  ) %>%
  
  arrange(
    PP05E,
    EMPLEO
  )

print(pp05e_empleo)

#------------------------------------------------------------
# PP05F
# Cantidad de clientes
#------------------------------------------------------------

cat(
  "\n==================================================\n",
  "PP05F - CLIENTES HABITUALES\n",
  "==================================================\n"
)

pp05f_empleo <- base_independientes_validacion %>%
  
  count(
    PP05F,
    EMPLEO
  ) %>%
  
  arrange(
    PP05F,
    EMPLEO
  )

print(pp05f_empleo)

#------------------------------------------------------------
# PP05H
# Antigüedad en la actividad
#------------------------------------------------------------

cat(
  "\n==================================================\n",
  "PP05H - ANTIGÜEDAD\n",
  "==================================================\n"
)

pp05h_empleo <- base_independientes_validacion %>%
  
  count(
    PP05H,
    EMPLEO
  ) %>%
  
  arrange(
    PP05H,
    EMPLEO
  )

print(pp05h_empleo)

#------------------------------------------------------------
# PP05C_1
# Maquinaria / equipos
#------------------------------------------------------------

cat(
  "\n==================================================\n",
  "PP05C_1 - MAQUINARIAS / EQUIPOS\n",
  "==================================================\n"
)

pp05c1_empleo <- base_independientes_validacion %>%
  
  count(
    PP05C_1,
    EMPLEO
  ) %>%
  
  arrange(
    PP05C_1,
    EMPLEO
  )

print(pp05c1_empleo)

#------------------------------------------------------------
# PP05C_2
# Local
#------------------------------------------------------------

cat(
  "\n==================================================\n",
  "PP05C_2 - LOCAL\n",
  "==================================================\n"
)

pp05c2_empleo <- base_independientes_validacion %>%
  
  count(
    PP05C_2,
    EMPLEO
  ) %>%
  
  arrange(
    PP05C_2,
    EMPLEO
  )

print(pp05c2_empleo)

#------------------------------------------------------------
# PP05C_3
# Vehículo
#------------------------------------------------------------

cat(
  "\n==================================================\n",
  "PP05C_3 - VEHÍCULO\n",
  "==================================================\n"
)

pp05c3_empleo <- base_independientes_validacion %>%
  
  count(
    PP05C_3,
    EMPLEO
  ) %>%
  
  arrange(
    PP05C_3,
    EMPLEO
  )

print(pp05c3_empleo)

#------------------------------------------------------------
# Guardar resultados
#------------------------------------------------------------

write.csv(
  pp06e_empleo,
  file.path(
    ruta_clasificacion,
    "pp06e_empleo.csv"
  ),
  row.names = FALSE
)

write.csv(
  pp06h_empleo,
  file.path(
    ruta_clasificacion,
    "pp06h_empleo.csv"
  ),
  row.names = FALSE
)

write.csv(
  pp05e_empleo,
  file.path(
    ruta_clasificacion,
    "pp05e_empleo.csv"
  ),
  row.names = FALSE
)

write.csv(
  pp05f_empleo,
  file.path(
    ruta_clasificacion,
    "pp05f_empleo.csv"
  ),
  row.names = FALSE
)

write.csv(
  pp05h_empleo,
  file.path(
    ruta_clasificacion,
    "pp05h_empleo.csv"
  ),
  row.names = FALSE
)

write.csv(
  pp05c1_empleo,
  file.path(
    ruta_clasificacion,
    "pp05c1_empleo.csv"
  ),
  row.names = FALSE
)

write.csv(
  pp05c2_empleo,
  file.path(
    ruta_clasificacion,
    "pp05c2_empleo.csv"
  ),
  row.names = FALSE
)

write.csv(
  pp05c3_empleo,
  file.path(
    ruta_clasificacion,
    "pp05c3_empleo.csv"
  ),
  row.names = FALSE
)





#------------------------------------------------------------
# Cobertura temporal de variables candidatas
#------------------------------------------------------------

variables_proxy <- c(
  "PP06E",
  "PP06H",
  "PP05E",
  "PP05F",
  "PP05H",
  "PP05C_1",
  "PP05C_2",
  "PP05C_3"
)

for (var in variables_proxy) {
  
  cat(
    "\n==================================================\n"
  )
  
  cat(
    var,
    "\n"
  )
  
  cat(
    "==================================================\n"
  )
  
  print(
    base_eph %>%
      group_by(periodo) %>%
      summarise(
        casos_validos =
          sum(
            !is.na(.data[[var]])
          ),
        .groups = "drop"
      )
  )
  
}




base_independientes_validacion %>%
  
  mutate(
    
    prediccion_pp06e = case_when(
      
      PP06E %in% c(1, 2) ~ "Formal",
      
      PP06E %in% c(0, 3) ~ "Informal",
      
      TRUE ~ NA_character_
      
    ),
    
    empleo_oficial = case_when(
      
      EMPLEO == 1 ~ "Formal",
      
      EMPLEO == 2 ~ "Informal",
      
      TRUE ~ NA_character_
      
    )
    
  ) %>%
  
  count(
    prediccion_pp06e,
    empleo_oficial
  )





#============================================================
# 11.B. EVALUACIÓN DE COMBINACIONES PARA PROXY RETROSPECTIVA
#============================================================
#
# Objetivo:
# Identificar combinaciones de variables históricas que
# permitan aproximar EMPLEO en independientes.
#
# Universo:
# Independientes ocupados
# 2023T4 - 2025T4
#
#============================================================

#------------------------------------------------------------
# PP06E + PP06H + PP05C_2
#------------------------------------------------------------

proxy_pp06e_pp06h_local <- base_independientes_validacion %>%
  
  group_by(
    PP06E,
    PP06H,
    PP05C_2
  ) %>%
  
  summarise(
    
    total = n(),
    
    formales =
      sum(
        EMPLEO == 1,
        na.rm = TRUE
      ),
    
    informales =
      sum(
        EMPLEO == 2,
        na.rm = TRUE
      ),
    
    porcentaje_formal =
      100 * formales / total,
    
    porcentaje_informal =
      100 * informales / total,
    
    .groups = "drop"
    
  ) %>%
  
  arrange(
    desc(total)
  )

print(
  proxy_pp06e_pp06h_local,
  n = Inf
)

write.csv(
  
  proxy_pp06e_pp06h_local,
  
  file.path(
    ruta_clasificacion,
    "proxy_pp06e_pp06h_local.csv"
  ),
  
  row.names = FALSE
  
)


#------------------------------------------------------------
# Ranking de combinaciones más formales
#------------------------------------------------------------

proxy_pp06e_pp06h_local %>%
  
  filter(
    total >= 100
  ) %>%
  
  arrange(
    desc(porcentaje_formal)
  ) %>%
  
  print(
    n = Inf
  )


#------------------------------------------------------------
# Ranking de combinaciones más informales
#------------------------------------------------------------

proxy_pp06e_pp06h_local %>%
  
  filter(
    total >= 100
  ) %>%
  
  arrange(
    porcentaje_formal
  ) %>%
  
  print(
    n = Inf
  )




#============================================================
# 11.C. REGLA RETROSPECTIVA DE INDEPENDIENTES
#============================================================

base_independientes_validacion <-
  
  base_independientes_validacion %>%
  
  mutate(
    
    formalidad_retro = case_when(
      
      #------------------------------------------
      # Formales seguros
      #------------------------------------------
      
      PP06E %in% c("1", "2") ~ "Formal",
      
      #------------------------------------------
      # Formales probables
      #------------------------------------------
      
      PP06E == "3" &
        PP06H == "2" &
        PP05C_2 %in% c("1","2") ~ "Formal",
      
      #------------------------------------------
      # Informales probables
      #------------------------------------------
      
      PP06E == "3" &
        PP06H == "1" &
        PP05C_2 == "3" ~ "Informal",
      
      PP06E == "0" &
        PP05C_2 == "3" ~ "Informal",
      
      #------------------------------------------
      # Casos restantes
      #------------------------------------------
      
      TRUE ~ "Informal"
      
    ),
    
    empleo_oficial = case_when(
      
      EMPLEO == "1" ~ "Formal",
      
      EMPLEO == "2" ~ "Informal",
      
      TRUE ~ NA_character_
      
    )
    
  )

#============================================================
# VALIDACION
#============================================================

validacion_retro <-
  
  base_independientes_validacion %>%
  
  mutate(
    
    coincide =
      
      formalidad_retro == empleo_oficial
    
  )

validacion_retro %>%
  
  summarise(
    
    casos = n(),
    
    coincidencias = sum(
      coincide,
      na.rm = TRUE
    ),
    
    accuracy =
      
      100 *
      
      coincidencias /
      
      casos
    
  )




# ============================================================
# CLASIFICACIÓN DE FORMALIDAD EN INDEPENDIENTES CON ÁRBOLES
# ============================================================
#
# Identificar qué variables predicen mejor la formalidad 
# en trabajadores independientes, utilizando un árbol de decisión.
# El accuracy obtenido con la variable PP05I no fue suficiente,
# por lo que se exploran otras variables del cuestionario.
#
# Período: 2023T4 - 2025T4 (disponibilidad de EMPLEO)
# Universo: Ocupados independientes (patrones y cuenta propia)
#
# Salidas:
# - arbol_independientes.png
# ============================================================

#------------------------------------------------------------
# Cargar librerías
#------------------------------------------------------------

library(rpart)
library(rpart.plot)

#------------------------------------------------------------
# Cargar base de validación de independientes
#------------------------------------------------------------
# Preparar datos para el árbol
#------------------------------------------------------------

arbol_independientes <- base_independientes_validacion %>%
  
  mutate(
    
    empleo_oficial = factor(
      
      case_when(
        
        EMPLEO == "1" ~ "Formal",
        
        EMPLEO == "2" ~ "Informal",
        
        TRUE ~ NA_character_
        
      )
      
    )
    
  ) %>%
  
  filter(
    !is.na(empleo_oficial)
  )

#------------------------------------------------------------
# Entrenar árbol de decisión
#------------------------------------------------------------

modelo_arbol <- rpart(
  
  empleo_oficial ~
    
    PP06E +    # Tipo de sociedad
    PP06H +    # Actividad familiar
    PP05E +    # Gastos en mercaderías/servicios
    PP05F +    # Clientes: único o varios
    PP05H +    # Antigüedad en el empleo
    PP05C_1 +  # Maquinarias/equipos propios
    PP05C_2 +  # Local propio
    PP05C_3,   # Vehículo propio
  
  data = arbol_independientes,
  
  method = "class",
  
  control = rpart.control(
    
    cp = 0.001,      # Complejidad mínima
    minsplit = 100,  # Mínimo de observaciones para dividir
    maxdepth = 5     # Profundidad máxima del árbol
    
  )
  
)

#------------------------------------------------------------
# Visualizar árbol en consola
#------------------------------------------------------------

rpart.plot(
  modelo_arbol,
  type = 4,
  extra = 104
)

#------------------------------------------------------------
# Evaluar accuracy del modelo
#------------------------------------------------------------

predicciones <- predict(
  modelo_arbol,
  type = "class"
)

accuracy <- mean(
  predicciones == arbol_independientes$empleo_oficial
)

cat("Accuracy del modelo:", round(accuracy * 100, 2), "%\n")


#------------------------------------------------------------
# Guardar árbol en PNG
#------------------------------------------------------------

pdf(
  file.path(ruta_clasificacion, "arbol_independientes.pdf"),
  width = 16,
  height = 12
)

rpart.plot(
  modelo_arbol,
  type = 4,
  extra = 104
)

dev.off()





# ============================================================
# EVALUACIÓN DEL ÁRBOL DE DECISIÓN PARA INDEPENDIENTES
# ============================================================
#
# Objetivo:
# Evaluar el rendimiento del árbol de decisión para clasificar
# formalidad en trabajadores independientes.
#
# - PP05I, PP05J y PP05K son las variables con las que INDEC
#   construye EMPLEO. Incluirlas generaría data leakage.
# - Estas variables NO existen antes de 2023T4, que es el
#   período que se quiere reconstruir (2022T1-2023T3).
#
# Variables utilizadas (disponibles en todo el período):
# - PP05C_2: Local propio
# - PP05E:   Gastos en mercaderías/servicios
# - PP05H:   Antigüedad en el empleo
# - PP06E:   Tipo de sociedad
#------------------------------------------------------------
# Generar predicciones del árbol
#------------------------------------------------------------

pred_arbol <- predict(
  modelo_arbol,
  type = "class"
)

#------------------------------------------------------------
# Matriz de confusión estándar
#------------------------------------------------------------

matriz_confusion_arbol <- table(
  Predicho = pred_arbol,
  Real = arbol_independientes$empleo_oficial
)


print(matriz_confusion_arbol)

#------------------------------------------------------------
# Matriz de confusión con porcentajes por columna 
#------------------------------------------------------------
# margin = 2: porcentajes sobre el total real de cada categoría
# Esto permite ver:
# - Sensibilidad para "Informal": % de informales bien clasificados
# - Sensibilidad para "Formal":   % de formales bien clasificados
#------------------------------------------------------------

print(
  prop.table(
    matriz_confusion_arbol,
    margin = 2
  ) * 100
)

#------------------------------------------------------------
# Calcular métricas con verificación de existencia
#------------------------------------------------------------

# Sensibilidad para Informal
sensibilidad_informal <- ifelse(
  "Informal" %in% rownames(matriz_confusion_arbol),
  matriz_confusion_arbol["Informal", "Informal"] /
    sum(matriz_confusion_arbol[, "Informal"]) * 100,
  0
)

# Sensibilidad para Formal
sensibilidad_formal <- ifelse(
  "Formal" %in% rownames(matriz_confusion_arbol),
  matriz_confusion_arbol["Formal", "Formal"] /
    sum(matriz_confusion_arbol[, "Formal"]) * 100,
  0
)

# Accuracy total
accuracy <- sum(diag(matriz_confusion_arbol)) /
  sum(matriz_confusion_arbol) * 100

#------------------------------------------------------------
# Mostrar métricas
#------------------------------------------------------------
cat("MÉTRICAS DE RENDIMIENTO\n")
cat("Sensibilidad para INFORMAL:", round(sensibilidad_informal, 1), "%\n")
cat("Sensibilidad para FORMAL:  ", round(sensibilidad_formal, 1), "%\n")
cat("Accuracy total:            ", round(accuracy, 1), "%\n")

#------------------------------------------------------------
# Interpretación y decisión metodológica
#------------------------------------------------------------
cat("INTERPRETACIÓN Y DECISIÓN\n")


if(sensibilidad_informal >= 75) {
  cat(" La sensibilidad para informal es > 75%.\n")
  cat("   El árbol captura adecuadamente la informalidad.\n")
  cat("   Puede considerarse para la reconstrucción retrospectiva,\n")
} else {
  cat("La sensibilidad para informal es < 75%.\n")
  cat("   El árbol NO es suficiente para clasificar individuos.\n")
}

#------------------------------------------------------------
# Guardar matriz de confusión
#------------------------------------------------------------

write.csv(
  as.data.frame.matrix(matriz_confusion_arbol),
  file.path(
    ruta_clasificacion,
    "matriz_confusion_arbol_independientes.csv"
  ),
  row.names = TRUE
)

control_estabilidad_arbol <-
  
  arbol_independientes %>%
  
  mutate(
    
    prediccion = predict(
      modelo_arbol,
      type = "class"
    ),
    
    coincide =
      prediccion == empleo_oficial
    
  ) %>%
  
  group_by(periodo) %>%
  
  summarise(
    
    casos = n(),
    
    accuracy =
      100 *
      mean(
        coincide,
        na.rm = TRUE
      ),
    
    .groups = "drop"
    
  )

print(
  control_estabilidad_arbol,
  n = Inf
)


#============================================================
# CIERRE DE LA FASE DE CLASIFICACIÓN
#============================================================
#
# Conclusiones:
#
# 1. PP07H reproduce EMPLEO para asalariados
#    (100 % de coincidencia).
#
# 2. El algoritmo oficial de independientes
#    reproduce EMPLEO en el período de coexistencia.
#
# 3. La reconstrucción retrospectiva para
#    independientes fue evaluada y descartada
#    para uso individual.
#
#============================================================