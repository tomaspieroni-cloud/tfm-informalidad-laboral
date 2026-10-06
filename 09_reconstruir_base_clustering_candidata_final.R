# ============================================================
# 09_reconstruir_base_clustering_candidata.R
# ============================================================
#
# Objetivo:
# Construir la base candidata para clustering a partir de la
# base madre (base_eph_2022_2025), incorporando:
# - Demográficas: CH04, CH06, NIVEL_ED
# - Territorial: REGION
# - Laborales: CAT_OCUP, CAES (1 dígito), TAM_EST, INTENSI
# - Ingresos: P21 (nominal, se deflactará después)
#
# Universo: Ocupados informales (ESTADO == 1 & EMPLEO == 2)
#
# Transformaciones clave:
# 1. CAES: normalización de códigos PP04B_COD (101->0101, 200->0200, etc.)
# 2. TAM_EST: PP04C=0 como "No aplica"
# 3. INTENSI: se mantiene como categórica
#
# Salidas:
# - base_clustering_candidata.parquet
# - base_clustering_candidata.csv
# - auditoria_cobertura.csv
# - freq_cat_ocup.csv
# - freq_caes.csv
# - freq_tam_est.csv
# - freq_intensi.csv
# ============================================================

#------------------------------------------------------------
# 1. CONFIGURACIÓN Y LIBRERÍAS
#------------------------------------------------------------

library(dplyr)
library(tidyr)
library(arrow)   # Para Parquet

source(here::here("Scripts", "00_configurar_proyecto.R"))

ruta_base <- here::here()
ruta_datos <- here::here("Salidas")
ruta_clustering <- here::here("Salidas", "07_clustering")

#------------------------------------------------------------
# 2. CARGA DE DATOS
#------------------------------------------------------------

base_eph <- readRDS(file.path(ruta_datos, "base_eph_2022_2025.rds"))
cat("Base cargada:", nrow(base_eph), "registros\n")

#------------------------------------------------------------
# 3. DEFINIR UNIVERSO: OCUPADOS INFORMALES (EMPLEO == 2)
#------------------------------------------------------------

base_informal <- base_eph %>%
  filter(
    ESTADO == 1,
    EMPLEO == 2
  )

cat("Informales (EMPLEO==2):", nrow(base_informal), "registros\n")

#------------------------------------------------------------
# 4. DICCIONARIO DE RECODIFICACIÓN CAES
#------------------------------------------------------------

# 4.1 Diccionario PP04B_COD → CAES2 (códigos normalizados a 4 dígitos)
caes2_dict <- tribble(
  ~PP04B_COD, ~CAES2,
  "0101", 1, "0102", 1, "0103", 1, "0104", 1, "0105", 1,
  "0200", 2,
  "0300", 3,
  "0500", 5,
  "0600", 6,
  "0700", 7,
  "0800", 8,
  "0900", 9,
  "1001", 10, "1002", 10, "1003", 10, "1009", 10,
  "1100", 11,
  "1200", 12,
  "1300", 13,
  "1400", 14,
  "1501", 15, "1502", 15,
  "1600", 16,
  "1700", 17,
  "1800", 18,
  "1901", 19, "1902", 19,
  "2001", 20, "2002", 20, "2009", 20,
  "2100", 21,
  "2201", 22, "2202", 22,
  "2301", 23, "2309", 23,
  "2400", 24,
  "2500", 25,
  "2601", 26, "2602", 26, "2603", 26, "2604", 26,
  "2701", 27, "2709", 27,
  "2800", 28,
  "2900", 29,
  "3001", 30, "3002", 30, "3003", 30, "3009", 30,
  "3100", 31,
  "3200", 32,
  "3300", 33,
  "3501", 35, "3502", 35,
  "3600", 36,
  "3700", 37,
  "3800", 38,
  "3900", 39,
  "4000", 40,
  "4501", 45, "4502", 45, "4503", 45, "4504", 45,
  "4801", 48, "4802", 48, "4803", 48, "4804", 48,
  "4805", 48, "4806", 48, "4807", 48, "4808", 48, "4809", 48,
  "4810", 48, "4811", 48,
  "4901", 49, "4902", 49, "4903", 49, "4904", 49,
  "4905", 49, "4909", 49,
  "5000", 50,
  "5100", 51,
  "5201", 52, "5202", 52,
  "5300", 53,
  "5500", 55,
  "5601", 56, "5602", 56,
  "5800", 58,
  "5900", 59,
  "6000", 60,
  "6100", 60,
  "6200", 62,
  "6300", 63,
  "6400", 64,
  "6500", 65,
  "6600", 66,
  "6800", 68,
  "6900", 69,
  "7000", 70,
  "7100", 71,
  "7200", 72,
  "7301", 73, "7302", 73,
  "7400", 74,
  "7500", 75,
  "7701", 77, "7702", 77,
  "7800", 78,
  "7900", 79,
  "8000", 80,
  "8101", 81, "8102", 81,
  "8200", 82,
  "8300", 83,
  "8401", 84, "8402", 84, "8403", 84,
  "8501", 85, "8509", 85,
  "8600", 86,
  "8700", 87,
  "8800", 88,
  "9000", 90,
  "9100", 91,
  "9200", 92,
  "9301", 93, "9302", 93,
  "9401", 94, "9402", 94, "9409", 94,
  "9501", 95, "9502", 95, "9503", 95,
  "9601", 96, "9602", 96, "9603", 96, "9609", 96,
  "9700", 97,
  "9800", 98,
  "9900", 99,
  "C", 666, "V", 888, "W", 777, "Z", 999
)

# 4.2 Normalización de PP04B_COD para cubrir códigos sin ceros a la izquierda
# Ejemplo: 101 -> 0101, 200 -> 0200, 9999 -> 99 (según sintaxis oficial)
base_informal <- base_informal %>%
  mutate(
    PP04B_COD_norm = case_when(
      PP04B_COD %in% c("101", "102", "103", "104") ~ paste0("0", PP04B_COD),
      PP04B_COD %in% c("200", "300", "500", "600", "700", "800", "900") ~ paste0("0", PP04B_COD),
      PP04B_COD == "9999" ~ "99",
      TRUE ~ PP04B_COD
    )
  )

# 4.3 Auditoría de cobertura del diccionario (opcional, pero se mantiene)
cat("\nVerificando cobertura del diccionario CAES2...\n")

cobertura_caes <- base_informal %>%
  left_join(caes2_dict, by = c("PP04B_COD_norm" = "PP04B_COD")) %>%
  summarise(
    total = n(),
    na_caes2 = sum(is.na(CAES2)),
    pct_na = round(100 * na_caes2 / total, 2)
  )

print(cobertura_caes)

if (cobertura_caes$na_caes2 > 0) {
  cat("\nCódigos PP04B_COD sin mapeo (aún después de normalización):\n")
  codigos_faltantes <- base_informal %>%
    left_join(caes2_dict, by = c("PP04B_COD_norm" = "PP04B_COD")) %>%
    filter(is.na(CAES2)) %>%
    distinct(PP04B_COD_norm) %>%
    pull(PP04B_COD_norm)
  print(codigos_faltantes)
  cat("\nTotal de códigos faltantes:", length(codigos_faltantes), "\n")
}

# 4.4 Diccionario CAES2 → CAES (1 dígito)
caes_dict <- tribble(
  ~CAES2_min, ~CAES2_max, ~CAES,
  1, 3, 1,
  5, 9, 2,
  10, 33, 3,
  35, 35, 4,
  36, 39, 5,
  40, 40, 6,
  45, 48, 7,
  49, 53, 8,
  55, 56, 9,
  58, 63, 10,
  64, 66, 11,
  68, 68, 12,
  69, 75, 13,
  77, 82, 14,
  83, 84, 15,
  85, 85, 16,
  86, 88, 17,
  90, 93, 18,
  94, 96, 19,
  97, 98, 20,
  99, 99, 21
)

#------------------------------------------------------------
# 5. TRANSFORMACIONES DE LA BASE CANDIDATA
#------------------------------------------------------------

base_candidata <- base_informal %>%
  
  # 5.1 Unir con diccionario para obtener CAES2
  left_join(caes2_dict, by = c("PP04B_COD_norm" = "PP04B_COD")) %>%
  
  # 5.2 Calcular CAES (1 dígito) a partir de CAES2
  mutate(
    CAES2 = as.numeric(CAES2),
    CAES = case_when(
      CAES2 %in% 1:3 ~ 1,
      CAES2 %in% 5:9 ~ 2,
      CAES2 %in% 10:33 ~ 3,
      CAES2 == 35 ~ 4,
      CAES2 %in% 36:39 ~ 5,
      CAES2 == 40 ~ 6,
      CAES2 %in% 45:48 ~ 7,
      CAES2 %in% 49:53 ~ 8,
      CAES2 %in% 55:56 ~ 9,
      CAES2 %in% 58:63 ~ 10,
      CAES2 %in% 64:66 ~ 11,
      CAES2 == 68 ~ 12,
      CAES2 %in% 69:75 ~ 13,
      CAES2 %in% 77:82 ~ 14,
      CAES2 %in% 83:84 ~ 15,
      CAES2 == 85 ~ 16,
      CAES2 %in% 86:88 ~ 17,
      CAES2 %in% 90:93 ~ 18,
      CAES2 %in% 94:96 ~ 19,
      CAES2 %in% 97:98 ~ 20,
      CAES2 == 99 ~ 21,
      TRUE ~ NA_real_
    )
  ) %>%
  
  # 5.3 TAM_EST (tamaño del establecimiento a partir de PP04C)
  mutate(
    TAM_EST = case_when(
      PP04C == 0 ~ "No aplica",
      PP04C == 1 ~ "1",
      PP04C %in% 2:5 ~ "2-5",
      PP04C %in% c(6,7) ~ "6-25",
      PP04C %in% c(8,9,10,11,12) ~ "26+",
      PP04C == 99 ~ "NS/NR",
      TRUE ~ NA_character_
    )
  ) %>%
  
  # 5.4 INTENSI como factor con etiquetas
  mutate(
    INTENSI = factor(
      INTENSI,
      levels = c(1, 2, 3, 4),
      labels = c("Subocupado", "Ocupado pleno", "Sobreocupado", "No trabajó")
    )
  ) %>%
  
  # 5.5 Identificador único
  mutate(
    id_persona = paste(CODUSU, NRO_HOGAR, COMPONENTE, sep = "_")
  ) %>%
  
  # 5.6 Seleccionar y reordenar columnas finales (excluyendo variables auxiliares)
  select(
    id_persona, CODUSU, NRO_HOGAR, COMPONENTE,
    ANO4, TRIMESTRE,
    CH04, CH06, NIVEL_ED,
    REGION,
    CAT_OCUP,
    CAES,
    TAM_EST,
    INTENSI,
    P21,
    PONDERA,
    PP04B_COD   # Conservar para trazabilidad (original)
  )

#------------------------------------------------------------
# 6. AUDITORÍA DE COBERTURA (missingness)
#------------------------------------------------------------

auditoria_cobertura <- base_candidata %>%
  summarise(
    total = n(),
    across(
      c(CH04, CH06, NIVEL_ED, REGION, CAT_OCUP,
        CAES, TAM_EST, INTENSI, P21),
      ~ sum(is.na(.))
    )
  )

n_total <- auditoria_cobertura$total
auditoria_cobertura <- auditoria_cobertura %>%
  select(-total) %>%
  pivot_longer(
    cols = everything(),
    names_to = "variable",
    values_to = "n_na"
  ) %>%
  mutate(
    pct_na = 100 * n_na / n_total,
    n_total = n_total
  )

cat("\nAuditoría de cobertura:\n")
print(auditoria_cobertura)

#------------------------------------------------------------
# 7. AUDITORÍA DE CATEGORÍAS (frecuencias separadas)
#------------------------------------------------------------

freq_cat_ocup <- base_candidata %>%
  count(CAT_OCUP) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  arrange(desc(n))

freq_caes <- base_candidata %>%
  count(CAES) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  arrange(desc(n))

freq_tam_est <- base_candidata %>%
  count(TAM_EST) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  arrange(desc(n))

freq_intensi <- base_candidata %>%
  count(INTENSI) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  arrange(desc(n))

cat("\nFrecuencia CAT_OCUP:\n")
print(freq_cat_ocup)

cat("\nFrecuencia CAES:\n")
print(freq_caes)

cat("\nFrecuencia TAM_EST:\n")
print(freq_tam_est)

cat("\nFrecuencia INTENSI:\n")
print(freq_intensi)

#------------------------------------------------------------
# 8. VERIFICACIÓN FINAL DE CAES (cobertura tras normalización)
#------------------------------------------------------------

cobertura_final <- base_candidata %>%
  summarise(
    total = n(),
    na_caes = sum(is.na(CAES)),
    pct_na_caes = round(100 * na_caes / total, 2)
  )

cat("\nCobertura final de CAES tras normalización:\n")
print(cobertura_final)

if (cobertura_final$na_caes > 0) {
  cat("\nAdvertencia: aún hay NA en CAES. Revisar códigos no cubiertos.\n")
}

#------------------------------------------------------------
# 9. GUARDAR RESULTADOS
#------------------------------------------------------------

write_parquet(
  base_candidata,
  file.path(ruta_clustering, "base_clustering_candidata.parquet")
)

write.csv(
  base_candidata,
  file.path(ruta_clustering, "base_clustering_candidata.csv"),
  row.names = FALSE
)

write.csv(
  auditoria_cobertura,
  file.path(ruta_clustering, "auditoria_cobertura.csv"),
  row.names = FALSE
)

write.csv(
  freq_cat_ocup,
  file.path(ruta_clustering, "freq_cat_ocup.csv"),
  row.names = FALSE
)

write.csv(
  freq_caes,
  file.path(ruta_clustering, "freq_caes.csv"),
  row.names = FALSE
)

write.csv(
  freq_tam_est,
  file.path(ruta_clustering, "freq_tam_est.csv"),
  row.names = FALSE
)

write.csv(
  freq_intensi,
  file.path(ruta_clustering, "freq_intensi.csv"),
  row.names = FALSE
)

#------------------------------------------------------------
# 10. MENSAJE FINAL
#------------------------------------------------------------

cat("\n========================================\n")
cat("Base candidata para clustering generada.\n")
cat("========================================\n")
cat("Registros:", nrow(base_candidata), "\n")
cat("Variables:", ncol(base_candidata), "\n")
cat("Archivos guardados en:", ruta_clustering, "\n")
cat(" - base_clustering_candidata.parquet\n")
cat(" - base_clustering_candidata.csv\n")
cat(" - auditoria_cobertura.csv\n")
cat(" - freq_cat_ocup.csv\n")
cat(" - freq_caes.csv\n")
cat(" - freq_tam_est.csv\n")
cat(" - freq_intensi.csv\n")