# =====================================================================
# 03_graficos.R
# =====================================================================
# Propósito: Generar y guardar gráficos a partir de los datos procesados.
# Ejecutar: Después de cargar los datos con 02_cargar_datos.R
# =====================================================================

#------------------------------------------------------------
# 1. Cargar datos (si no están en memoria)
#------------------------------------------------------------
if (!exists("indicadores_mercado")) {
  source("Scripts/02_cargar_datos.R")
}

#------------------------------------------------------------
# 2. Definir carpeta para guardar gráficos (ruta relativa)
#------------------------------------------------------------
ruta_graficos <- file.path(ruta_proyecto, "Graficos")

dir.create(ruta_graficos, recursive = TRUE, showWarnings = FALSE)

#------------------------------------------------------------
# 3. Generar y guardar gráficos
#------------------------------------------------------------

# Gráfico 1: Tasa de actividad
p1 <- ggplot(indicadores_mercado, aes(x = periodo, y = tasa_actividad, group = 1)) +
  geom_line(linewidth = 1, color = "steelblue") +
  geom_point(size = 2, color = "steelblue") +
  labs(
    title = "Tasa de actividad",
    subtitle = "Total de la población",
    x = "Período",
    y = "Porcentaje (%)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave(
  filename = file.path(ruta_graficos, "tasa_actividad.png"),
  plot = p1,
  width = 10,
  height = 6,
  dpi = 300
)

# Gráfico 2: Tasa de empleo
p2 <- ggplot(indicadores_mercado, aes(x = periodo, y = tasa_empleo, group = 1)) +
  geom_line(linewidth = 1, color = "darkgreen") +
  geom_point(size = 2, color = "darkgreen") +
  labs(
    title = "Tasa de empleo",
    subtitle = "Total de la población",
    x = "Período",
    y = "Porcentaje (%)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave(
  filename = file.path(ruta_graficos, "tasa_empleo.png"),
  plot = p2,
  width = 10,
  height = 6,
  dpi = 300
)

# Gráfico 3: Tasa de informalidad asalariada
p3 <- ggplot(tasa_informalidad_asalariada, aes(x = periodo, y = tasa_informalidad_asalariada, group = 1)) +
  geom_line(linewidth = 1, color = "darkred") +
  geom_point(size = 2, color = "darkred") +
  labs(
    title = "Tasa de informalidad asalariada",
    subtitle = "Asalariados ocupados",
    x = "Período",
    y = "Porcentaje (%)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave(
  filename = file.path(ruta_graficos, "tasa_informalidad_asalariada.png"),
  plot = p3,
  width = 10,
  height = 6,
  dpi = 300
)

# Gráfico 4: Informalidad por sexo (último período)
ultimo_periodo <- max(informalidad_sexo$periodo)

p4 <- informalidad_sexo %>%
  filter(periodo == ultimo_periodo) %>%
  ggplot(aes(x = sexo, y = tasa_informalidad_asalariada, fill = sexo)) +
  geom_col() +
  labs(
    title = paste("Informalidad por sexo -", ultimo_periodo),
    x = "",
    y = "Tasa de informalidad (%)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "none"
  ) +
  scale_fill_manual(values = c("Varón" = "steelblue", "Mujer" = "darkred"))

ggsave(
  filename = file.path(ruta_graficos, "informalidad_sexo_ultimo_periodo.png"),
  plot = p4,
  width = 8,
  height = 6,
  dpi = 300
)

# Gráfico 5: Evolución de informalidad por sexo (serie temporal)
p5 <- informalidad_sexo %>%
  ggplot(aes(x = periodo, y = tasa_informalidad_asalariada, color = sexo, group = sexo)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.5) +
  labs(
    title = "Evolución de la informalidad por sexo",
    x = "Período",
    y = "Tasa de informalidad (%)",
    color = "Sexo"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom"
  )

ggsave(
  filename = file.path(ruta_graficos, "informalidad_sexo_evolucion.png"),
  plot = p5,
  width = 10,
  height = 6,
  dpi = 300
)


cat("GRÁFICOS GUARDADOS EXITOSAMENTE\n")
cat("========================================\n")
cat("Ubicación:", ruta_graficos, "\n")