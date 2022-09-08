# un programme où on copie-colle les sorties pour l'ER Drees

library(haven)
library(ggplot2)
library(dplyr)
library(Hmisc) # pour les fonctions wtd.XX
library(xlsx) # pour les sorties en excel
library(viridis)
library(svglite)
theme_update(plot.title = element_text(hjust = 0.5))

# On a besoin d'avoir chargé des objets du programme général

setwd("D:/hwsdmo/QC_QF/sorties_ER")

#Graphique ménages imposables
tbl_ir_nb_ER <- ir_cent %>% 
  select(ir_nb0, ir_nb1, ir_nb2, rang_centile) %>%
  gather(starts_with("ir_nb"), key = type_IR, value = nb_imp)
gplot_ir_nb_ER <- ggplot(tbl_ir_nb_ER, aes(x=rang_centile, y=nb_imp, fill=type_IR)) +
  geom_line(aes(color = type_IR), size = 0.6)  +
  geom_point(aes(color = type_IR), show.legend = FALSE) + 
  scale_colour_viridis_d(option = "cividis", direction = -1, name = "Scénario d'impôt", 
                         labels = c("Individualisé", "Conjugal" , "Conjugal et Familial (réel)")) + 
  theme(legend.position = "bottom", legend.text = element_text(size = 13), 
        legend.title = element_text(size = 15, face = "bold"),
        plot.title = element_text(size=18, face = "bold")) +
  labs(x = "Centile de niveau de vie", y = "Part de ménages")
ggsave("G1_ir_imp_ER.png")
ggsave("graphique1.pdf")
ggsave("graphique1.svg")


# imposabilité et recettes
col_tER1_1 <- as.numeric(round(select(tbl_eff, starts_with("impos"))/10^6, d = 1))
col_tER1_2 <- as.numeric(round(select(tbl_eff, starts_with("part_impos"))*100, d = 1))
col_tER1_4 <- as.numeric(round(c(dist_ind$moy, dist_QC$moy, dist_QCQF$moy), d = 0))

# gagnants et perdants
col_tER2_1 <- as.numeric(round(select(tbl_eff, starts_with("nb_gag"))/10^3, d = 0))
col_tER2_2 <- as.numeric(round(select(tbl_eff, starts_with("nb_per"))/10^3, d = 0))
col_tER2_3 <- as.numeric(round(cbind(moy_gag_QC, moy_gag_QF, moy_gag_QCQF), d = 0))
col_tER2_4 <- as.numeric(round(cbind(moy_per_QC, moy_per_QF, moy_per_QCQF), d = 0))
col_tER2_5 <- as.numeric(round(cbind(eff_moy_QC, eff_moy_QF, eff_moy_QCQF), d = 0))

my_tab_ER1 <- t(rbind(col_tER1_1, col_tER1_2, col_tER1_3, col_tER1_4))
my_tab_ER2 <- t(rbind(col_tER2_1, col_tER2_2, col_tER2_3, col_tER2_4, col_tER2_5))
my_tab_ER_IR <- cbind(my_tab_ER1, my_tab_ER2) 
rownames(my_tab_ER_IR) <- c("Individuel", "Conjugal", "Conjugal et familial") 

write.xlsx(my_tab_ER_IR, sheetName = "Effets_QC_QF", file = "sorties_ER.xlsx", append = TRUE)

# Graphique gagnants-perdants-neutres
gplot_GPN_scenar(ir_cent, "02") 
ggsave("G2_GPN_QCQF.png")
ggsave("graphique2.pdf")
ggsave("graphique2.svg")

# Graphique gains-pertes
gplot_GP_scenar(ir_vingt, "02") 
ggsave("G3_GP_QCQF.png")
ggsave("graphique3.pdf")
ggsave("graphique3.svg")

# Tableau effets par configuration familiale
nb_gQCQF <- sum(tbl_eff_typ$nb_gag_QCQF)
nb_pQCQF <- sum(tbl_eff_typ$nb_per_QCQF)
tot_gQCQF <- sum(tbl_eff_typ$gain_QCQF)
tot_pQCQF <- sum(tbl_eff_typ$pert_QCQF)

col_tER3_1 <- round(tbl_eff_typ$poi_sum/10^3, d = 0)
col_tER3_2 <- round(tbl_eff_typ$poi_sum/nb_men, d = 3)*100
col_tER3_3 <- round(tbl_eff_typ$nb_gag_QCQF/10^3, d = 0)
col_tER3_4 <- round(tbl_eff_typ$nb_gag_QCQF/nb_gQCQF, d = 3)*100
col_tER3_5 <- round(tbl_eff_typ$nb_per_QCQF/10^3, d = 0)
col_tER3_6 <- round(tbl_eff_typ$nb_per_QCQF/nb_pQCQF, d = 3)*100

col_tER4_1 <- round(tbl_eff_typ$ir_moy_men_QCQF, d = 1)
col_tER4_2 <- round(tbl_gag_QCQF$moy_gag, d = 1)
col_tER4_3 <- round(tbl_per_QCQF$moy_per, d = 1)
col_tER4_4 <- round(tbl_eff_typ$gain_QCQF/10^6, d = 0)
col_tER4_5 <- round(tbl_eff_typ$gain_QCQF/tot_gQCQF, d = 3)*100
col_tER4_6 <- round(tbl_eff_typ$pert_QCQF/10^6, d = 0)
col_tER4_7 <- round(tbl_eff_typ$pert_QCQF/tot_pQCQF, d = 3)*100

my_tabER3 <- t(rbind(col_tER3_1, col_tER3_2, col_tER3_3, col_tER3_4, col_tER3_5, col_tER3_6))
my_tabER3 <- rbind(my_tabER3, round(apply(my_tabER3, 2, sum), d = 0))

my_tabER4 <- t(rbind(col_tER4_1, col_tER4_2, col_tER4_3, col_tER4_4, col_tER4_5, col_tER4_6, col_tER4_7))
my_tabER4 <- rbind(my_tabER4, round(apply(my_tabER4, 2, sum), d = 0))
my_tabER4[7,1] <- round(sum(tbl_eff_typ$tot_QCQF) / nb_men, d = 1)
my_tabER4[7,2] <- round(tot_gQCQF / nb_gQCQF, d = 1) 
my_tabER4[7,3] <- round(tot_pQCQF / nb_pQCQF, d = 1) 

my_tabER_cfg <- cbind(my_tabER3, my_tabER4)
row.names(my_tabER_cfg) <- c("Célibataires", "Familles monop.", "Couples sans enfant",
                             "Couples, 1 ou 2 enf.", "Couples, 3 enf. ou +",
                             "Ménages complexes", "Total")
write.xlsx(my_tabER_cfg, sheetName = "Effets_cfg", file = "sorties_ER.xlsx", append = TRUE)

# Répartition des gains par vingtile
GPvingt_QCQF <- ir_vingt %>% 
  select(rang_vingtile, tot_gain_02, tot_pert_02) %>%
  mutate(part_gain_QCQF = tot_gain_02 / tot_gQCQF,
         part_pert_QCQF = tot_pert_02 / tot_pQCQF) %>% 
  gather(starts_with("part"), key = GP, value = val_eff)

gplot_GPvingt_QCQF <- ggplot(GPvingt_QCQF, aes(x=rang_vingtile, y=val_eff, fill=GP)) +
  geom_bar(stat = "identity", position = "dodge") + 
  theme(legend.position = "bottom", legend.text = element_text(size = 16), 
        legend.title = element_text(size = 16, face = "bold"),
        plot.title = element_text(size=18, face = "bold")) +
  scale_fill_discrete(name="Effet", labels=c("Gains", "Pertes")) +
  labs(x = "Vingtile de niveau de vie", y = "Part dans le total de l'effet")
ggsave("G4_GPdist_QCQF.png")
ggsave("graphique4.pdf")
ggsave("graphique4.svg")
