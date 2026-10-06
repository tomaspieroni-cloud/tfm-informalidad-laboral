# ============================================================
# 07D_atriccion_diagnostico.R
# ============================================================
#
# Objetivo:
# Comparar caracteristicas de individuos reentrevistados vs no
# reentrevistados para el par 2022T1-2022T2, utilizando solo
# enlaces consistentes.
#
# Salidas:
# - attrition_sexo.csv, attrition_edad.csv, attrition_estado.csv,
#   attrition_cat_ocup.csv, attrition_formalidad.csv
# ============================================================

#------------------------------------------------------------
# 1. Cargar configuracion y librerias
#------------------------------------------------------------

source(here::here("Scripts", "00_configurar_proyecto.R"))

library(dplyr)
library(tidyr)

#------------------------------------------------------------
# 2. Definir rutas
#------------------------------------------------------------

ruta_panel <- here::here("Salidas", "05_panel_longitudinal")
ruta_clasificacion <- here::here("Salidas", "04_clasificacion_formalidad")

#------------------------------------------------------------
# 3. Cargar datos necesarios
#------------------------------------------------------------

# Panel 2022T1-2022T2
panel <- readRDS(
  file.path(ruta_panel, "panel_2022T1_2022T2.rds")
)

# Base original del periodo T1
base_t1 <- readRDS(
  here::here("Salidas", "base_eph_2022_2025.rds")
) %>%
  filter(periodo == "2022T1")

# Base con clasificacion de formalidad (estado_laboral_clasificado)
base_clasificada <- readRDS(
  file.path(ruta_clasificacion, "estado_laboral_clasificado.rds")
) %>%
  filter(periodo == "2022T1") %>%
  select(CODUSU, NRO_HOGAR, COMPONENTE, estado_laboral_clasificado)

#------------------------------------------------------------
# 4. Identificar reentrevistados consistentes
#------------------------------------------------------------

reentrevistados <- panel %>%
  filter(consistencia) %>%
  select(CODUSU, NRO_HOGAR, COMPONENTE) %>%
  distinct() %>%
  mutate(reentrevistado = 1)

#------------------------------------------------------------
# 5. Construir base attrition con formalidad
#------------------------------------------------------------

base_attrition <- base_t1 %>%
  left_join(reentrevistados,
            by = c("CODUSU", "NRO_HOGAR", "COMPONENTE")) %>%
  left_join(base_clasificada,
            by = c("CODUSU", "NRO_HOGAR", "COMPONENTE")) %>%
  mutate(
    reentrevistado = ifelse(is.na(reentrevistado), 0, 1),
    CH04 = as.numeric(CH04),
    CH06 = as.numeric(CH06),
    ESTADO = as.numeric(ESTADO),
    CAT_OCUP = as.numeric(CAT_OCUP)
  )

#------------------------------------------------------------
# 6. Verificar distribucion de reentrevistados
#------------------------------------------------------------

cat("\nDistribucion de reentrevistados:\n")
print(table(base_attrition$reentrevistado))

#------------------------------------------------------------
# 7. Tablas comparativas
#------------------------------------------------------------

# Sexo
tabla_sexo <- base_attrition %>%
  group_by(reentrevistado, CH04) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(reentrevistado) %>%
  mutate(prop = 100 * n / sum(n))

# Edad
tabla_edad <- base_attrition %>%
  group_by(reentrevistado) %>%
  summarise(
    media = mean(CH06, na.rm = TRUE),
    mediana = median(CH06, na.rm = TRUE),
    sd = sd(CH06, na.rm = TRUE),
    .groups = "drop"
  )

# Estado laboral
tabla_estado <- base_attrition %>%
  group_by(reentrevistado, ESTADO) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(reentrevistado) %>%
  mutate(prop = 100 * n / sum(n))

# Categoria ocupacional
tabla_cat_ocup <- base_attrition %>%
  group_by(reentrevistado, CAT_OCUP) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(reentrevistado) %>%
  mutate(prop = 100 * n / sum(n))

# Formalidad (estado_laboral_clasificado)
tabla_formalidad <- base_attrition %>%
  filter(!is.na(estado_laboral_clasificado)) %>%
  group_by(reentrevistado, estado_laboral_clasificado) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(reentrevistado) %>%
  mutate(prop = 100 * n / sum(n))

#------------------------------------------------------------
# 8. Guardar resultados
#------------------------------------------------------------

write.csv(tabla_sexo, file.path(ruta_panel, "attrition_sexo.csv"), row.names = FALSE)
write.csv(tabla_edad, file.path(ruta_panel, "attrition_edad.csv"), row.names = FALSE)
write.csv(tabla_estado, file.path(ruta_panel, "attrition_estado.csv"), row.names = FALSE)
write.csv(tabla_cat_ocup, file.path(ruta_panel, "attrition_cat_ocup.csv"), row.names = FALSE)
write.csv(tabla_formalidad, file.path(ruta_panel, "attrition_formalidad.csv"), row.names = FALSE)

cat("\nArchivos generados en:", ruta_panel, "\n")



