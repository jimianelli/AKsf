# Run after installing the package. Simplification here is display-only.
library(AKsf)
library(ggplot2)
library(sf)
dir.create("docs", showWarnings = FALSE)
land <- st_simplify(get_coast(), dTolerance = 300)
fmp <- st_simplify(get_fmp_areas(), dTolerance = 300)
labels <- c(BSAI_GF = "BSAI groundfish", GOA_GF = "Gulf of Alaska groundfish",
            BSAI_CRAB = "BSAI king and Tanner crab", SCALLOP = "Scallop",
            SALMON = "Salmon: East, West and Cook Inlet", ARCTIC = "Arctic")
fmp$plan <- factor(labels[fmp$fmp_id], levels = unname(labels))
colours <- c(BSAI_GF = "#237f97", GOA_GF = "#56a6ae", BSAI_CRAB = "#bb713e",
             SCALLOP = "#796eb0", SALMON_EAST = "#44a191", SALMON_WEST = "#e2b558",
             SALMON_COOK_INLET = "#c94855", ARCTIC = "#6d91ba")
p <- ggplot() +
  geom_sf(data = fmp, aes(fill = area_code), colour = "#456373", linewidth = 0.15) +
  geom_sf(data = land, fill = "#e8e9e3", colour = "#9babae", linewidth = 0.12) +
  facet_wrap(~plan, ncol = 2) + coord_aksf() +
  scale_fill_manual(values = colours, guide = "none") +
  theme_aksf(base_size = 11) +
  theme(strip.text = element_text(face = "bold", hjust = 0, size = 12),
        panel.background = element_rect(fill = "#f6fafb", colour = NA),
        panel.grid.major = element_line(colour = "#dee7eb", linewidth = 0.15),
        plot.title = element_text(face = "bold", size = 23),
        plot.subtitle = element_text(colour = "#49616a", size = 12),
        plot.caption = element_text(hjust = 0, colour = "#49616a", size = 9),
        plot.margin = margin(18, 20, 18, 20)) +
  labs(title = "AKsf | Alaska fisheries spatial features",
       subtitle = "Six NPFMC fishery management plans, with fishery-specific reference coverage",
       caption = "Sources: NOAA Fisheries, ADF&G, NPFMC definitions; Natural Earth land.\nDerived cartographic reference areas; not regulatory boundaries. Source vintages and methods: DATA_SOURCES.md.")
ggsave("docs/fmp-overview.png", p, width = 12, height = 11, dpi = 160, bg = "white")

salmon <- get_fmp_areas("SALMON")
cook <- salmon[salmon$area_code == "SALMON_COOK_INLET", ]
bb <- st_bbox(cook)
p2 <- ggplot() +
  geom_sf(data = salmon, aes(fill = area_code), colour = "#456373", linewidth = 0.2) +
  geom_sf(data = get_coast(), fill = "#e8e9e3", colour = "#9babae", linewidth = 0.2) +
  coord_sf(crs = proj_aksf(), xlim = c(bb['xmin']-40000, bb['xmax']+40000),
           ylim = c(bb['ymin']-50000, bb['ymax']+40000), expand = FALSE) +
  scale_fill_manual(values = colours, breaks = c("SALMON_COOK_INLET", "SALMON_WEST"),
                    labels = c("Cook Inlet EEZ Area", "West Area"), name = NULL) +
  theme_aksf() + labs(title = "Cook Inlet salmon management",
    subtitle = "Separate EEZ area north of 59 degrees 46.15 minutes N",
    caption = "AKsf reference geometry. Generalized Natural Earth land; use agency baselines for detailed coastal work.")
ggsave("docs/salmon-cook-inlet.png", p2, width = 8, height = 8, dpi = 160, bg = "white")
