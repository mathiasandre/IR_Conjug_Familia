library(haven)
library(ggplot2)
library(descr)
library(Hmisc) # pour les fonctions wtd.XX
library(dineq) # pour ntiles.wtd et gini.wtd
library(microbenchmark)
library(dplyr)
library(tidyr)
library(kableExtra) # pour les tableaux en .tex ou .html
library(xlsx) # pour les sorties en excel
library(knitr)
library(viridis)
options(knitr.table.format = "latex")
theme_update(plot.title = element_text(hjust = 0.5))

#position = position_fill(reverse = TRUE)
#scale_fill_discrete(guide=guide_legend(reverse=T))

# Lecture de la base de synthèse des scénarios
setwd("D:/hwsdmo/sorties_qc_qf")
basemen_all <- read_sas("basemen_synthese_2017.sas7bdat")
impot_sur_rev16_synthese <- read_sas("impot_sur_rev16_synthese.sas7bdat")
# on ajoute saturationeffetsqf à basemen_all
basemen_all <- basemen_all %>% left_join(impot_sur_rev16_synthese %>% group_by(ident) %>% 
                                           summarize(SaturationEffetsQF = max(SaturationEffetsQF_sc2))) %>% 
  mutate(SaturationEffetsQF = tidyr::replace_na(SaturationEffetsQF, 0))
# on remplace les NA par des 0

setwd("D:/hwsdmo/QC_QF/2017")
#basemen_all <- read_sas("basemen_synthese_2012.sas7bdat")
#setwd("D:/hwsdmo/QC_QF/2012")
#basemen_all <- read_sas("basemen_synthese_2017_partage.sas7bdat")
#setwd("D:/hwsdmo/QC_QF/2017_partage")
#basemen_all <- read_sas("basemen_synthese_2012_partage.sas7bdat")
#setwd("D:/hwsdmo/QC_QF/2012_partage")
#basemen_all <- read_sas("basemen_synthese_2017_conjoint.sas7bdat")
#setwd("D:/hwsdmo/QC_QF/2017_conjoint")

str(basemen_all)
names(basemen_all)
head(basemen_all)
tail(basemen_all)

# Restriction au champ Ines
champ <- basemen_all$etud_pr_0=='non' & basemen_all$revpos_0==1 & basemen_all$revdisp_0>0
basemen_champ <- basemen_all[champ,]

#jointure avec la table impôt pour récupérer le statut marié ou pacsé
# un ménage est marié ou pacsé si un des foyers l'est
impot_men <- impot_sur_rev16_synthese %>% 
  mutate(mcdvo = mcdvo_sc2 %in% c("M", "O")) %>% 
  group_by(ident) %>% 
  transmute(mar_pacs = max(mcdvo)) %>% 
  distinct()

basemen_champ <- left_join(basemen_champ, impot_men, by = "ident")
basemen_champ$mar_pacs[is.na(basemen_champ$mar_pacs)] <- 1

# Création de nouvelles variables 
basemen_champ <- within(basemen_champ,{
  poiind <- poi_0*nbp_0
  Ndv_0 <- revdisp_0/uci_0
  Ndv_1 <- revdisp_1/uci_0
  Ndv_2 <- revdisp_2/uci_0
  Ndv_3 <- revdisp_3/uci_0
  Ndv_4 <- revdisp_4/uci_0
  # on recrée typmen6 : 1/ celib, 2/ monop, 3/ Coup SE, 4/ coup 1E ou 2E, 5/ coup 3E, 6/ complexe
  typmen6 <- ifelse(typmen_Insee_0 %in% "10", "1. Célibataires",
                    ifelse(typmen_Insee_0 %in% c("11", "12", "13"), "2. Familles monop.",
                           ifelse(typmen_Insee_0 %in% c("20", "30"), "3. Couples sans enfant",
                                  ifelse(typmen_Insee_0 %in% c("21", "22"), "4. Couples avec 1 ou 2 enf.",
                                         ifelse(typmen_Insee_0 %in% c("23"), "5. Couples avec 3 enf. ou plus",
                                                ifelse(typmen_Insee_0 %in% "31", "6. Ménages complexes", NA))))))
  uci_group1 <- uci_0 * (uci_0 < 1.25) 
  uci_group15 <- 1.5 * (uci_0 >= 1.25) * (uci_0 < 1.75) 
  uci_group2 <- 2 * (uci_0 >= 1.75) * (uci_0 < 2.25)
  uci_group25 <- 2.5 * (uci_0 >= 2.25) * (uci_0 < 2.75)
  uci_group3 <- 3 * (uci_0 >= 2.75) * (uci_0 < 3.25)
  uci_group35 <- 3.5 * (uci_0 >= 3.25) 
  uci_group <- uci_group1 + uci_group15 + uci_group2 + uci_group25 + uci_group3 + uci_group35 
  # percentiles de NdV du CTF (scénario 2 = Ines normal)
  rang_centile = ntiles.wtd(Ndv_2, 100, w = poiind)
  rang_vingtile = trunc((rang_centile - 1)/5) + 1
  rang_decile = trunc((rang_centile - 1)/10) + 1
  # gagnants, perdants et neutres : 
  delta_01  <-  (impot_0 - impot_1) * (abs(impot_0 - impot_1) > 10) 
  delta_02  <-  (impot_0 - impot_2) * (abs(impot_0 - impot_2) > 10) 
  delta_12  <-  (impot_1 - impot_2) * (abs(impot_1 - impot_2) > 10) 
  delta_23  <-  (impot_2 - impot_3) * (abs(impot_2 - impot_3) > 10) 
  delta_24  <-  (impot_2 - impot_4) * (abs(impot_2 - impot_4) > 10) 
  delta_20  <-  (impot_2 - impot_0) * (abs(impot_2 - impot_0) > 10) 
  delta_21  <-  (impot_2 - impot_1) * (abs(impot_2 - impot_1) > 10) 
  gag_01  <-  delta_01 > 0
  gag_02  <-  delta_02 > 0
  gag_12  <-  delta_12 > 0
  gag_23  <-  delta_23 > 0
  gag_24  <-  delta_24 > 0
  gag_20  <-  delta_20 > 0
  gag_21  <-  delta_21 > 0
  per_01  <-  delta_01 < 0
  per_02  <-  delta_02 < 0
  per_12  <-  delta_12 < 0
  per_23  <-  delta_23 < 0
  per_24  <-  delta_24 < 0
  per_20  <-  delta_20 < 0
  per_21  <-  delta_21 < 0
  neu_01  <-  delta_01 == 0
  neu_02  <-  delta_02 == 0
  neu_12  <-  delta_12 == 0
  neu_23  <-  delta_23 == 0
  neu_24  <-  delta_24 == 0
  neu_20  <-  delta_20 == 0
  neu_21  <-  delta_21 == 0
  # typologie des neutres : jamais imposables, les autres
  neu_typ1_01 <- (delta_01 == 0) * (impot_0 == 0) * (impot_1 ==0)
  neu_typ2_01 <- neu_01 * (neu_typ1_01 == 0)
  # gains et pertes à un pourcent de revenu disponible du ménage
  gag_01_1p  <-  (delta_01 > 0) * (abs(delta_01) > 0.01 * revdisp_0)
  gag_02_1p  <-  (delta_02 > 0) * (abs(delta_02) > 0.01 * revdisp_0)
  gag_12_1p  <-  (delta_12 > 0) * (abs(delta_12) > 0.01 * revdisp_1)
  gag_23_1p  <-  (delta_23 > 0) * (abs(delta_23) > 0.01 * revdisp_2)
  gag_24_1p  <-  (delta_24 > 0) * (abs(delta_24) > 0.01 * revdisp_2)
  gag_20_1p  <-  (delta_20 > 0) * (abs(delta_20) > 0.01 * revdisp_2)
  gag_21_1p  <-  (delta_21 > 0) * (abs(delta_21) > 0.01 * revdisp_2)
  per_01_1p  <-  (delta_01 < 0) * (abs(delta_01) > 0.01 * revdisp_0)
  per_02_1p  <-  (delta_02 < 0) * (abs(delta_02) > 0.01 * revdisp_0)
  per_12_1p  <-  (delta_12 < 0) * (abs(delta_12) > 0.01 * revdisp_1)
  per_23_1p  <-  (delta_23 < 0) * (abs(delta_23) > 0.01 * revdisp_2)
  per_24_1p  <-  (delta_24 < 0) * (abs(delta_24) > 0.01 * revdisp_2)
  per_20_1p  <-  (delta_20 < 0) * (abs(delta_20) > 0.01 * revdisp_2)
  per_21_1p  <-  (delta_21 < 0) * (abs(delta_21) > 0.01 * revdisp_2)
  neu_01_1p  <-  (abs(delta_01) > 0.01 * revdisp_0)
  neu_02_1p  <-  (abs(delta_02) > 0.01 * revdisp_0)
  neu_12_1p  <-  (abs(delta_12) > 0.01 * revdisp_1)
  neu_23_1p  <-  (abs(delta_23) > 0.01 * revdisp_2)
  neu_24_1p  <-  (abs(delta_24) > 0.01 * revdisp_2)
  neu_20_1p  <-  (abs(delta_20) > 0.01 * revdisp_2)
  neu_21_1p  <-  (abs(delta_21) > 0.01 * revdisp_2)
  }
)

as_tibble(basemen_champ)

# Indicateur d'inégalités 
indic_ineg <- function(my_df, my_var, my_pond){
  my_tbl <- as_tibble(my_df) %>% 
    mutate(my_var = !!sym(my_var), my_pond = !!sym(my_pond), my_var_pond = my_var * my_pond) 
  centiles <- wtd.quantile(my_tbl$my_var, probs = 1:99/100, w = my_tbl$my_pond)
  vingtiles <- centiles[5 * 1:19]
  deciles <- centiles[10 * 1:9]
  inter_deci <- deciles[9] / deciles[1]
  inter_vingti <- vingtiles[19] / vingtiles[1]
  ind_gini <-  gini.wtd(my_tbl$my_var, weights = my_tbl$my_pond)
  seuil_pauvre <- 0.6 * deciles[5]
  nb_pauvre <- sum(transmute(my_tbl, (my_var < seuil_pauvre) * my_pond))
  nb_men <- sum(my_tbl$my_pond)
  taux_pauvre <- nb_pauvre / nb_men
  med_pauvre <- my_tbl %>%
    filter(my_var < seuil_pauvre) %>%
      summarise(., my_med = wtd.quantile(my_var, probs = 0.5, w=my_pond))
  intens_pauvre <- (seuil_pauvre - as.numeric(med_pauvre))/seuil_pauvre
  list_ineg <- list(taux_pauvre, intens_pauvre, ind_gini, inter_deci, inter_vingti, seuil_pauvre)
  names(list_ineg) <- c("taux_pauvre", "intens_pauvre", "ind_gini", "inter_deci", "inter_vingti", "seuil_pauvre")
  return(as_tibble(list_ineg))
}

ineg_pauv_ind <- indic_ineg(basemen_champ, "Ndv_0", "poiind")
ineg_pauv_con <- indic_ineg(basemen_champ, "Ndv_1", "poiind")
ineg_pauv_fam <- indic_ineg(basemen_champ, "Ndv_2", "poiind")
ineg_pauv_sc1 <- indic_ineg(basemen_champ, "Ndv_3", "poiind")
ineg_pauv_sc2 <- indic_ineg(basemen_champ, "Ndv_4", "poiind")

ineg_pauv_fam - ineg_pauv_sc1
ineg_pauv_fam - ineg_pauv_sc2

# Calculs par percentile de l'impôt moyen, taux d'imposition, individus imposables et GPN
## Attention, si on prend impot_tot : ça inclue prelev_forf et verslib_autoentre, 
ir_ptile <- function(my_tbl, my_tile, varsup = ''){
  # @my_tbl : table sur laquelle on agrège par percentile
  # @my_tile : 100, 20 ou 10 (percentiles)
  # @varsup : variable supplémentaire pour les sous groupes d'agrégation
  my_rang <- ifelse(my_tile == 100, "cent",
                    ifelse(my_tile == 20, "vingt",
                           ifelse(my_tile==10, "dec", NA)))
  if(varsup == ''){
    tbl_ptile <- my_tbl %>% 
      group_by(!!sym(paste("rang_", my_rang, "ile", sep='')))
  } else{
    tbl_ptile <- my_tbl %>% 
      group_by(!!sym(paste("rang_", my_rang, "ile", sep='')), !!sym(varsup))
    }
  tbl_ptile <- tbl_ptile  %>% 
        summarise(
          # IR total et moyen
          ir_tot0 = sum(impot_0 * poi_0),
          ir_tot1 = sum(impot_1 * poi_0),
          ir_tot2 = sum(impot_2 * poi_0),
          ir_tot3 = sum(impot_3 * poi_0),
          ir_tot4 = sum(impot_4 * poi_0),
          ir_moy0 = wtd.mean(impot_0, w=poi_0),
          ir_moy1 = wtd.mean(impot_1, w=poi_0),
          ir_moy2 = wtd.mean(impot_2, w=poi_0),
          ir_moy3 = wtd.mean(impot_3, w=poi_0),
          ir_moy4 = wtd.mean(impot_4, w=poi_0),
          # part d'IR payé dans le NdV Ines classique
          ir_part0 = wtd.mean(impot_0 / Ndv_2, w=poi_0), 
          ir_part1 = wtd.mean(impot_1 / Ndv_2, w=poi_0), 
          ir_part2 = wtd.mean(impot_2 / Ndv_2, w=poi_0), 
          ir_part3 = wtd.mean(impot_3 / Ndv_2, w=poi_0), 
          ir_part4 = wtd.mean(impot_4 / Ndv_2, w=poi_0),
          impos0 = sum((impot_0 > 0) * poi_0),
          impos1 = sum((impot_1 > 0) * poi_0),
          impos2 = sum((impot_2 > 0) * poi_0),
          impos3 = sum((impot_3 > 0) * poi_0),
          impos4 = sum((impot_4 > 0) * poi_0),
          poiind_sum = sum(poiind),
          poi_sum = sum(poi_0),
          ir_nb0 = impos0 / poi_sum,
          ir_nb1 = impos1 / poi_sum,
          ir_nb2 = impos2 / poi_sum,
          ir_nb3 = impos3 / poi_sum,
          ir_nb4 = impos4 / poi_sum,  
          nb_per_01 = sum(per_01 * poi_0),
          nb_per_02 = sum(per_02 * poi_0),    
          nb_per_12 = sum(per_12 * poi_0),  
          nb_per_23 = sum(per_23 * poi_0),  
          nb_per_24 = sum(per_24 * poi_0),  
          nb_per_20 = sum(per_20 * poi_0),  
          nb_per_21 = sum(per_21 * poi_0), 
          nb_gag_01 = sum(gag_01 * poi_0), 
          nb_gag_02 = sum(gag_02 * poi_0),  
          nb_gag_12 = sum(gag_12 * poi_0),  
          nb_gag_23 = sum(gag_23 * poi_0),  
          nb_gag_24 = sum(gag_24 * poi_0),  
          nb_gag_20 = sum(gag_20 * poi_0), 
          nb_gag_21 = sum(gag_21 * poi_0), 
          nb_neu_01 = sum(neu_01 * poi_0), 
          nb_neu_02 = sum(neu_02 * poi_0),  
          nb_neu_12 = sum(neu_12 * poi_0),  
          nb_neu_23 = sum(neu_23 * poi_0),  
          nb_neu_24 = sum(neu_24 * poi_0),  
          nb_neu_20 = sum(neu_20 * poi_0),  
          nb_neu_21 = sum(neu_21 * poi_0),
          # 2 types de neutres mariés ou pacsés (MP) et non concernés (NC)
          nb_neu_NC_01 = sum(neu_01 * poi_0 * (1- mar_pacs)), 
          nb_neu_MP_01 = sum(neu_01 * poi_0 * mar_pacs),
          nb_neu_NC_12 = sum(neu_12 * poi_0 * (1- mar_pacs)),   
          nb_neu_MP_12 = sum(neu_12 * poi_0 * mar_pacs), 
          nb_neu_NC_02 = sum(neu_02 * poi_0 * (1- mar_pacs)),   
          nb_neu_MP_02 = sum(neu_02 * poi_0 * mar_pacs), 
          nb_neu_typ1_MP_01 = sum(neu_01 * poi_0 * mar_pacs*(impot_0 == 0) * (impot_1 ==0)),
          nb_per_01_1p = sum(per_01_1p * poi_0),
          nb_per_02_1p = sum(per_02_1p * poi_0),
          nb_per_12_1p = sum(per_12_1p * poi_0),
          nb_per_23_1p = sum(per_23_1p * poi_0),
          nb_per_24_1p = sum(per_24_1p * poi_0),
          nb_per_20_1p = sum(per_20_1p * poi_0),
          nb_per_21_1p = sum(per_21_1p * poi_0), 
          nb_gag_01_1p = sum(gag_01_1p * poi_0), 
          nb_gag_02_1p = sum(gag_02_1p * poi_0),
          nb_gag_12_1p = sum(gag_12_1p * poi_0),
          nb_gag_23_1p = sum(gag_23_1p * poi_0),
          nb_gag_24_1p = sum(gag_24_1p * poi_0),
          nb_gag_20_1p = sum(gag_20_1p * poi_0),
          nb_gag_21_1p = sum(gag_21_1p * poi_0),
          nb_neu_01_1p = sum(neu_01_1p * poi_0),
          nb_neu_02_1p = sum(neu_02_1p * poi_0),
          nb_neu_12_1p = sum(neu_12_1p * poi_0),
          nb_neu_23_1p = sum(neu_23_1p * poi_0),
          nb_neu_24_1p = sum(neu_24_1p * poi_0),
          nb_neu_20_1p = sum(neu_20_1p * poi_0),
          nb_neu_21_1p = sum(neu_21_1p * poi_0),
          # Gains et pertes en euros
          tot_gain_01 = sum(gag_01 * delta_01 * poi_0),
          tot_gain_12  = sum(gag_12 * delta_12 * poi_0),
          tot_gain_02 = sum(gag_02 * delta_02 * poi_0),
          tot_pert_01 = sum(per_01 * delta_01 * poi_0),
          tot_pert_12  = sum(per_12 * delta_12 * poi_0),
          tot_pert_02 = sum(per_02 * delta_02 * poi_0),
          # Calcul des gains/pertes en part de NdV avec le NdV Ines classique
          par_gag_01 = wtd.mean(delta_01 * gag_01 / Ndv_2, w=poi_0), 
          par_gag_02 = wtd.mean(delta_02 * gag_02 / Ndv_2, w=poi_0), 
          par_gag_12 = wtd.mean(delta_12 * gag_12 / Ndv_2, w=poi_0), 
          par_gag_23 = wtd.mean(delta_23 * gag_23 / Ndv_2, w=poi_0), 
          par_gag_24 = wtd.mean(delta_24 * gag_24 / Ndv_2, w=poi_0), 
          par_gag_20 = wtd.mean(delta_20 * gag_20 / Ndv_2, w=poi_0), 
          par_gag_21 = wtd.mean(delta_21 * gag_21 / Ndv_2, w=poi_0),
          par_per_01 = wtd.mean(delta_01 * per_01 / Ndv_2, w=poi_0), 
          par_per_02 = wtd.mean(delta_02 * per_02 / Ndv_2, w=poi_0), 
          par_per_12 = wtd.mean(delta_12 * per_12 / Ndv_2, w=poi_0), 
          par_per_23 = wtd.mean(delta_23 * per_23 / Ndv_2, w=poi_0), 
          par_per_24 = wtd.mean(delta_24 * per_24 / Ndv_2, w=poi_0), 
          par_per_20 = wtd.mean(delta_20 * per_20 / Ndv_2, w=poi_0), 
          par_per_21 = wtd.mean(delta_21 * per_21 / Ndv_2, w=poi_0),
          nb_plaf_qf = sum(SaturationEffetsQF * poi_0),
          par_plaf_qf = sum(SaturationEffetsQF * poi_0) / sum(poi_0)  
        )
  return(tbl_ptile)
} 

ir_cent <- ir_ptile(basemen_champ, 100)
ir_vingt <- ir_ptile(basemen_champ, 20)
ir_dec <- ir_ptile(basemen_champ, 10)
ir_vingt_typ <- ir_ptile(basemen_champ, 20, varsup = "typmen6")
ir_dec_uc <- ir_ptile(basemen_champ, 10, varsup = "uci_group")

## part de ménages imposables
nb_impos <- ir_cent %>% 
  select(poi_sum, starts_with("impos")) %>%
  replace(is.na(.),0) %>%
  summarise_all(funs(sum))  
as.vector(nb_impos) / as.numeric(nb_impos[1])

## gplot par percentile 
gplot_ptile <- function(my_tile, my_var){
  # my_tile : 100, 20 ou 10 (percentiles)
  # my_var : variable de la table ir_'my_tile'
  my_rang <- ifelse(my_tile == 100, "cent",
                    ifelse(my_tile == 20, "vingt",
                           ifelse(my_tile==10, "dec", NA)))
  tbl_ptile <- get(paste("ir", my_rang, sep='_')) %>%   
    mutate(my_var = !!sym(my_var)) %>% 
      select(my_var, paste("rang_", my_rang, "ile", sep='')) 
  gplot_ptile <- ggplot(tbl_ptile, aes(x=!!sym(paste("rang_", my_rang,"ile", sep='')), y=my_var)) +
    geom_bar(stat = "identity") 
  return(gplot_ptile)
}

# vérification pondérations et percentiles
#gplot_ptile(100, "poiind_sum")
gplot_ptile(20, "poiind_sum")

#impôt ines 
gplot_ptile(100, "impos2")
gplot_ptile(100, "ir_nb2")
gplot_ptile(20, "ir_nb2")
gplot_ptile(10, "ir_nb2")

# figure empilée des parts d'imposables
tbl_ir_part <- ir_cent %>% 
  select(ir_part0, ir_part1, ir_part2, rang_centile) %>%
  gather(starts_with("ir_part"), key = type_IR, value = part_ir)
gplot_ir_part <- ggplot(tbl_ir_part, aes(x=rang_centile, y=part_ir, fill=type_IR)) +
  geom_line(aes(color = type_IR), size = 0.6, show.legend = FALSE)  +
  geom_point(aes(color = type_IR), show.legend = FALSE) + 
  scale_colour_viridis_d(option = "plasma", direction = -1, labels = NULL, name = NULL) + 
  scale_fill_viridis_d (option = "plasma", direction = -1,
                        name = "Type d'impôt", 
                        labels = c("Individuel", "Conjugal", "Familial")) +
  theme(legend.position = "bottom", legend.text = element_text(size = 16), 
        legend.title = element_text(size = 16, face = "bold"),
        plot.title = element_text(size=18, face = "bold")) +
  labs(title = "Part d'impôt payé selon le niveau de vie", x = "Centile de niveau de vie", y = "Proportion de niveau de vie")
ggsave("ir_pay.pdf")

tbl_ir_nb <- ir_cent %>% 
  select(ir_nb0, ir_nb1, ir_nb2, rang_centile) %>%
  gather(starts_with("ir_nb"), key = type_IR, value = nb_imp)
gplot_ir_nb <- ggplot(tbl_ir_nb, aes(x=rang_centile, y=nb_imp, fill=type_IR)) +
  geom_line(aes(color = type_IR), size = 0.6, show.legend = FALSE)  +
  geom_point(aes(color = type_IR), show.legend = FALSE) + 
  scale_colour_viridis_d(option = "plasma", direction = -1, labels = NULL, name = NULL) + 
  geom_area(position="identity",alpha=.35) + 
  scale_fill_viridis_d(option = "plasma", direction = -1,
                        name = "Type d'impôt", 
                        labels = c("Individuel", "Conjugal", "Familial")) +
  theme(legend.position = "bottom", legend.text = element_text(size = 16), 
        legend.title = element_text(size = 16, face = "bold"),
        plot.title = element_text(size=18, face = "bold")) +
  labs(title = "Ménages imposables selon le niveau de vie", x = "Centile de niveau de vie", y = "Part de ménages")
ggsave("ir_imp.pdf")
tbl_ir_nb_xl <- ir_cent %>% 
  select(ir_nb0, ir_nb1, ir_nb2, rang_centile)
write.xlsx(tbl_ir_nb_xl, sheetName="centiles", file = "ir_imp.xlsx", append = TRUE)

# Total IR en euros par centile
tbl_ir_tot <- ir_cent %>% 
  select(ir_tot0, ir_tot1, ir_tot2, rang_centile) %>%
  gather(starts_with("ir_tot"), key = type_IR, value = tot_ir)
gplot_ir_tot <- ggplot(tbl_ir_tot, aes(x=rang_centile, y=tot_ir, fill=type_IR)) +
  geom_line(aes(color = type_IR), size = 0.6, show.legend = FALSE)  +
  geom_point(aes(color = type_IR), show.legend = FALSE) + 
  scale_colour_viridis_d(option = "plasma", direction = -1, labels = NULL, name = NULL) + 
  geom_area(position="identity",alpha=.35) + 
  scale_fill_viridis_d (option = "plasma", direction = -1,
                        name = "Type d'impôt", 
                        labels = c("Individuel", "Conjugal", "Familial")) +
  theme(legend.position = "bottom", legend.title = element_text(face = "bold"),
        plot.title = element_text(face = "bold")) +
  labs(x = "Centile de niveau de vie", y = "Montant (en euros)")
ggsave("ir_tot.pdf")

# graphes des gagnants perdants neutres par centiles
gplot_GPN_scenar <- function(my_tbl, num_sc){
  tbl_GPN <- my_tbl %>% 
    select(paste("nb_per", num_sc, sep='_'), paste("nb_neu", num_sc, sep='_'), 
                 paste("nb_gag", num_sc, sep='_'), rang_centile) %>%
        gather(ends_with(num_sc), key = GPN, value = nb_delta)
  gplot_GPN_scenar <- ggplot(tbl_GPN, aes(x=rang_centile, y=nb_delta, fill=GPN)) +
    geom_bar(stat = "identity", position = "fill") + 
      theme(legend.position = "bottom", legend.text = element_text(size = 16), 
            legend.title = element_text(size = 16, face = "bold"),
            plot.title = element_text(size=18, face = "bold")) +
    scale_fill_manual(values = c("#F15854", "#FAA43A", "#0072B2"), 
                      name="Situation", labels=c("Gagnant", "Neutre", "Perdant")) +
    labs(x = "Centile de niveau de vie", y = "Part de ménages")
  return(gplot_GPN_scenar)
}

# Figures de gagnants - perdants - neutres en partant du cas individuel:
gplot_GPN_scenar(ir_cent, "02") 
ggsave("GPN_ind_fam.pdf")

gplot_GPN_scenar(ir_cent, "01") 
ggsave("GPN_ind_conj.pdf")
tbl_GPN_xl <- ir_cent %>% 
  select(nb_per_01, nb_neu_01, nb_gag_01, rang_centile)
write.xlsx(tbl_GPN_xl, sheetName="centiles", file = "GPN_ind_conj.xlsx", append = TRUE)

gplot_GPN_scenar(ir_cent, "12") 
ggsave("GPN_conj_fam.pdf")

gplot_GPN_scenar(ir_cent, "23") 
ggsave("GPN_sc_CI.pdf")

gplot_GPN_scenar(ir_cent, "24") 
ggsave("GPN_sc_augtra.pdf")

# avec seuil à 1% et avec référence l'IR actuel
gplot_GPN_scenar(ir_cent, "02_1p")
gplot_GPN_scenar(ir_cent, "01_1p")
gplot_GPN_scenar(ir_cent, "12_1p")  
gplot_GPN_scenar(ir_cent, "20_1p")
gplot_GPN_scenar(ir_cent, "21_1p")
gplot_GPN_scenar(ir_cent, "23_1p")
gplot_GPN_scenar(ir_cent, "24_1p")

# graphes des gagnants perdants avec 2 types de neutres
gplot_GPN_scenar_2N <- function(my_tbl, num_sc){
  tbl_GPN <- my_tbl %>% 
    select(paste("nb_per", num_sc, sep='_'), paste("nb_neu_MP", num_sc, sep='_'), 
           paste("nb_neu_NC", num_sc, sep='_'), 
           paste("nb_gag", num_sc, sep='_'), rang_centile) %>%
    gather(ends_with(num_sc), key = GPN, value = nb_delta)
  gplot_GPN_scenar <- ggplot(tbl_GPN, aes(x=rang_centile, y=nb_delta, fill=GPN)) +
    geom_bar(stat = "identity", position = "fill") +
    scale_fill_manual(values = c("#F15854", "#FAA43A", "#999999", "#0072B2"), name = NULL, 
                          labels=c("Gagnants", "Neutres concernés",
                                   "Neutres non concernés", "Perdants")) +
    theme(legend.position = "bottom", legend.text = element_text(size = 13), 
          legend.title = element_text(size = 16, face = "bold"),
          plot.title = element_text(size=18, face = "bold")) +
    labs(x = "Centile de niveau de vie", y = "Part de ménages")
  return(gplot_GPN_scenar)
}
gplot_GPN_scenar_2N(ir_cent, "02") 

# bleu clair #56B4E9
# bleu clair léger #77AADD
# bleu foncé #0072B2
# bleu foncé léger #0072B2
# orange #D55E00
# moutarde #E69F00
# orange léger #FAA43A
# vert #009F73
# gris #999999
# saumon #CC79A7
# framboise #BB4444
# rose léger #EE9988
# rouge léger #F15854
# violet #B276B2

# graphe des gains et pertes : d'abord en part puis en euros
gplot_GP_scenar <- function(my_tbl, num_sc){
  tbl_GP <- my_tbl %>% 
    select(paste("par_per", num_sc, sep='_'), paste("par_gag", num_sc, sep='_'), 
           rang_vingtile) %>%
    gather(ends_with(num_sc), key = GP, value = val_par)
  gplot_GP_scenar <- ggplot(tbl_GP, aes(x=rang_vingtile, y=val_par, fill=GP)) +
    geom_bar(stat = "identity", position = "dodge") + 
    theme(legend.position = "bottom", legend.text = element_text(size = 16), 
          legend.title = element_text(size = 16, face = "bold"),
          plot.title = element_text(size=18, face = "bold")) +
    scale_fill_manual(values = c("#F15854", "#0072B2"), name = NULL, labels=c("Gain", "Perte")) +
    labs(x = "Vingtile de niveau de vie", y = "Proportion de niveau de vie")
  return(gplot_GP_scenar)
}
gplot_GP_scenar(ir_vingt, "02") 
ggsave("GP_ind_fam.pdf")

gplot_GP_scenar(ir_vingt, "01") 
ggsave("GP_ind_conj.pdf")
tbl_GP_xl <- ir_vingt %>% 
  select("par_per_01", "par_gag_01", rang_vingtile)
write.xlsx(tbl_GP_xl, sheetName="vingtiles", file = "GP_ind_conj.xlsx", append = TRUE)

gplot_GP_scenar(ir_vingt, "12") 
ggsave("GP_conj_fam.pdf")

gplot_GP_scenar(ir_vingt, "23") 
ggsave("GP_sc_CI.pdf")

gplot_GP_scenar(ir_vingt, "24") 
ggsave("GP_sc_augtra.pdf")

gplot_GP_sc_eur <- function(my_tbl, num_sc){
  tbl_GP <- my_tbl %>% 
    select(paste("tot_pert", num_sc, sep='_'), paste("tot_gain", num_sc, sep='_'), 
           rang_vingtile) %>%
    gather(ends_with(num_sc), key = GP, value = val_eff)
  gplot_GP_scenar <- ggplot(tbl_GP, aes(x=rang_vingtile, y=val_eff, fill=GP)) +
    geom_bar(stat = "identity", position = "dodge") + 
    theme(legend.position = "bottom", legend.title = element_text(face = "bold"),
          plot.title = element_text(face = "bold")) +
    scale_fill_manual(values = c("#F15854", "#0072B2"), name = NULL, labels=c("Gains", "Pertes")) +
    labs(x = "Vingtile de niveau de vie", y = "Montants totaux (en euros)")
  return(gplot_GP_scenar)
}
gplot_GP_sc_eur(ir_vingt, "02") 
ggsave("GP_ind_fam_eur.pdf")

gplot_GP_sc_eur(ir_vingt, "01") 
ggsave("GP_ind_conj_eur.pdf")

gplot_GP_sc_eur(ir_vingt, "12") 
ggsave("GP_conj_fam_eur.pdf")

# Montants moyens et quartiles d'IR sur les imposables
ir_impos <- function(my_tbl, my_var){
  my_dist <- my_tbl %>% 
    mutate(my_var = !!sym(my_var)) %>% 
    filter(my_var > 0) %>%
    summarise(
      moy_pos = wtd.mean(my_var, w=poi_0),
      med_pos = wtd.quantile(my_var, probs = 0.5, w=poiind),
      Q1_pos = wtd.quantile(my_var, probs = 0.25, w=poiind),
      Q3_pos = wtd.quantile(my_var, probs = 0.75, w=poiind),
      P95_pos = wtd.quantile(my_var, probs = 0.95, w=poiind),
      P99_pos = wtd.quantile(my_var, probs = 0.99, w=poiind))
  names(my_dist) <- c("moy", "med", "Q1", "Q3", "P95", "P99")
  return(my_dist)
}

dist_ind <- ir_impos(basemen_champ, "impot_0")/12
dist_QC <- ir_impos(basemen_champ, "impot_1")/12
dist_QCQF <- ir_impos(basemen_champ, "impot_2")/12

#Table 1 : description par type d'impôt 
tbl_eff <- summarise(basemen_champ,
                     # Masses des effets
                     delta_QC = sum(delta_01 * poi_0),  
                     delta_QF = sum(delta_12 * poi_0), 
                     delta_QCQF = sum(delta_02 * poi_0),
                     # Total IR
                     tot_ind = sum(impot_0 * poi_0),
                     tot_QC = sum(impot_1 * poi_0),
                     tot_QCQF = sum(impot_2 * poi_0),
                     # Montant moyen d'IR sur tous les ménages
                     ir_moy_men_ind = wtd.mean(impot_0, w=poi_0),
                     ir_moy_men_QC = wtd.mean(impot_1, w=poi_0),
                     ir_moy_men_QCQF = wtd.mean(impot_2, w=poi_0),
                     # Nombre de ménages GPN
                     nb_gag_QC = sum(gag_01 * poi_0),  
                     nb_gag_QF = sum(gag_12 * poi_0), 
                     nb_gag_QCQF = sum(gag_02 * poi_0),
                     nb_per_QC = sum(per_01 * poi_0),  
                     nb_per_QF = sum(per_12 * poi_0), 
                     nb_per_QCQF = sum(per_02 * poi_0),
                     nb_neu_QC = sum(neu_01 * poi_0),  
                     nb_neu_QF = sum(neu_12 * poi_0), 
                     nb_neu_QCQF = sum(neu_02 * poi_0),
                     nb_neu_typ1_QC = sum(neu_typ1_01 * poi_0),
                     nb_neu_typ2_QC = sum(neu_typ2_01 * poi_0), 
                     # Valeurs maximales des gains et pertes
                     gain_max_QC = max(gag_01 * delta_01),
                     gain_max_QF = max(gag_12 * delta_12),
                     gain_max_QCQF = max(gag_02 * delta_02),
                     pert_max_QC = min(per_01 * delta_01),
                     pert_max_QF = min(per_12 * delta_12),
                     pert_max_QCQF = min(per_02 * delta_02),
                     # Ménages imposés
                     impos_ind = sum((impot_0 > 0) * poi_0),
                     impos_QC = sum((impot_1 > 0) * poi_0),
                     impos_QCQF = sum((impot_2 > 0) * poi_0),
                     part_impos_ind = impos_ind / sum(poi_0),
                     part_impos_QC = impos_QC / sum(poi_0),
                     part_impos_QCQF = impos_QCQF / sum(poi_0)
)

moy_gag_QC <- basemen_champ %>%
  select(ident, poi_0, delta_01, gag_01) %>% 
  filter(gag_01 == TRUE) %>% 
  transmute(moy_gag_QC = wtd.mean(delta_01, w=poi_0)) %>% 
  distinct()

moy_gag_QF <- basemen_champ %>% 
  select(ident, poi_0, delta_12, gag_12) %>% 
  filter(gag_12 == TRUE) %>% 
  transmute(moy_gag_QF = wtd.mean(gag_12 * delta_12, w=poi_0)) %>% 
  distinct()

moy_gag_QCQF <- basemen_champ %>% 
  select(ident, poi_0, delta_02, gag_02) %>% 
  filter(gag_02 == TRUE) %>%  
  transmute(moy_gag_QCQF = wtd.mean(gag_02 * delta_02, w=poi_0)) %>% 
  distinct()

moy_per_QC <- basemen_champ %>% 
  select(ident, poi_0, delta_01, per_01) %>% 
  filter(per_01 == TRUE) %>% 
  transmute(moy_per_QC = wtd.mean(per_01 * delta_01, w=poi_0)) %>% 
  distinct()

moy_per_QF <- basemen_champ %>% 
  select(ident, poi_0, delta_12, per_12) %>% 
  filter(per_12 == TRUE) %>% 
  transmute(moy_per_QF = wtd.mean(per_12 * delta_12, w=poi_0)) %>% 
  distinct()

moy_per_QCQF <- basemen_champ %>% 
  select(ident, poi_0, delta_02, per_02) %>% 
  filter(per_02 == TRUE) %>% 
  transmute(moy_per_QCQF = wtd.mean(per_02 * delta_02, w=poi_0)) %>% 
  distinct()

eff_moy_QC <- basemen_champ %>% 
  select(ident, poi_0, delta_01) %>% 
  filter(delta_01 != 0) %>% 
  transmute(eff_moy_QC = wtd.mean(delta_01, w=poi_0)) %>% 
  distinct()

eff_moy_QF <- basemen_champ %>% 
  select(ident, poi_0, delta_12) %>% 
  filter(delta_12 != 0) %>% 
  transmute(eff_moy_QF = wtd.mean(delta_12, w=poi_0)) %>% 
  distinct()

eff_moy_QCQF <- basemen_champ %>% 
  select(ident, poi_0, delta_02) %>% 
  filter(delta_02 != 0) %>% 
  transmute(eff_moy_QCQF = wtd.mean(delta_02, w=poi_0)) %>% 
  distinct()

col_t1_1 <- round(select(tbl_eff, starts_with("impos"))/10^6, d = 1)
col_t1_2 <- round(select(tbl_eff, starts_with("part_impos"))*100, d = 1)
col_t1_3 <- round(select(tbl_eff, starts_with("tot"))/10^9, d = 1)
col_t1_4 <- round(c(dist_ind$moy, dist_QC$moy, dist_QCQF$moy), d = 0)
col_t1_5 <- round(c(dist_ind$med, dist_QC$med, dist_QCQF$med), d = 0)
col_t1_6 <- round(c(dist_ind$Q1, dist_QC$Q1, dist_QCQF$Q1), d = 0)
col_t1_7 <- round(c(dist_ind$Q3, dist_QC$Q3, dist_QCQF$Q3), d = 0) 

names(col_t1_1) <- c("Individuel", "Conjugal", "Réel")
names(col_t1_2) <- c("Individuel", "Conjugal", "Réel")
names(col_t1_3) <- c("Individuel", "Conjugal", "Réel") 
names(col_t1_4) <- c("Individuel", "Conjugal", "Réel") 
names(col_t1_5) <- c("Individuel", "Conjugal", "Réel") 
names(col_t1_6) <- c("Individuel", "Conjugal", "Réel") 
names(col_t1_7) <- c("Individuel", "Conjugal", "Réel")

my_tab1 <- t(rbind(col_t1_1, col_t1_2, col_t1_3, col_t1_4, col_t1_5, col_t1_6, col_t1_7))
write.xlsx(my_tab1, sheetName = "MenImpo", file = "sorties_qc_qf.xlsx", append = TRUE)
kable(my_tab1, booktabs = T)

# Table 2 : effets des QC et QF

col_t2_1 <- round(select(tbl_eff, starts_with("nb_gag"))/10^3, d = 0)
col_t2_2 <- round(select(tbl_eff, starts_with("nb_per"))/10^3, d = 0)
col_t2_3 <- round(cbind(moy_gag_QC, moy_gag_QF, moy_gag_QCQF), d = 0)
col_t2_4 <- round(cbind(moy_per_QC, moy_per_QF, moy_per_QCQF), d = 0)
col_t2_5 <- round(cbind(eff_moy_QC, eff_moy_QF, eff_moy_QCQF), d = 0)

names(col_t2_1) <- c("QC", "QF", "QC + QF")
names(col_t2_2) <- c("QC", "QF", "QC + QF") 
names(col_t2_3) <- c("QC", "QF", "QC + QF") 
names(col_t2_4) <- c("QC", "QF", "QC + QF") 
names(col_t2_5) <- c("QC", "QF", "QC + QF") 

my_tab2 <- t(rbind(col_t2_1, col_t2_2, col_t2_3, col_t2_4, col_t2_5))
write.xlsx(my_tab2, sheetName = "Effets", file = "sorties_qc_qf.xlsx", append = TRUE)
kable(my_tab2, booktabs = T)

## ggplots par type de ménage : on enlève les ménages complexes pour les graphiques
ir_vingt_typ5 <- filter(ir_vingt_typ, typmen6 != "6. Ménages complexes")
  
gplot_poi_typ <- ggplot(ir_vingt_typ5, aes(x=rang_vingtile, y=poi_sum, fill=typmen6)) +
  geom_bar(stat = "identity", position = "dodge") + 
  theme(legend.position = "bottom",         plot.title = element_text(size=18, face = "bold")) +
  scale_fill_discrete(name="") +
  guides(fill = guide_legend(nrow = 2, byrow = TRUE)) +
  labs(title = "Nombres de ménages", 
       x = "Vingtile de niveau de vie", y = "") 
ggsave("poi_typ.pdf")

gplot_ind_typ <- ggplot(ir_vingt_typ5, aes(x=rang_vingtile, y=poiind_sum, fill=typmen6)) +
  geom_bar(stat = "identity", position = "dodge") + 
  theme(legend.position = "bottom",
        plot.title = element_text(size=18, face = "bold")) +
  scale_fill_discrete(name="") +
  guides(fill = guide_legend(nrow = 2,byrow = TRUE)) +
  labs(title = "Nombres de personnes", 
       x = "Vingtile de niveau de vie", y = " ")
ggsave("ind_typ.pdf")

tbl_typ5_xl <- ir_vingt_typ5 %>% 
  select(poi_sum, poiind_sum, typmen6, rang_vingtile) %>% 
  arrange(typmen6)
write.xlsx(as.data.frame(tbl_typ5_xl), sheetName="vingtiles", file = "config_typ.xlsx")

# graphes d'impot séparés pour chaque configuration 
gplot_config <- function(my_tbl, my_config){
  tbl_cfg <- my_tbl %>% 
    filter(typmen6 == my_config) %>% 
    select(ir_tot0, ir_tot1, ir_tot2, typmen6, rang_vingtile) %>%
    gather(starts_with("ir_tot"), key = config, value = ir_tot)
  gplot_config <- ggplot(tbl_cfg, aes(x=rang_vingtile, y=ir_tot, fill=config)) +
    geom_bar(stat = "identity", position = "dodge") + 
    theme(legend.position = "bottom", legend.text = element_text(size = 16), 
          legend.title = element_text(size = 16, face = "bold"),
          plot.title = element_text(size=18, face = "bold")) +
    scale_fill_viridis_d(option = "viridis", name="Impôt", 
                          labels=c("Individuel", "Conjugal", "Familial")) +
    labs(title = my_config, x = "Vingtile de niveau de vie", y = "Montants totaux (en euros)")
  return(gplot_config)
}
gplot_config(ir_vingt_typ, "1. Célibataires") 
#ggsave("ir_config1.pdf")

gplot_config(ir_vingt_typ, "2. Familles monop.") 
#ggsave("ir_config2.pdf")

gplot_config(ir_vingt_typ, "3. Couples sans enfant") 
#ggsave("ir_config3.pdf")

gplot_config(ir_vingt_typ, "4. Couples avec 1 ou 2 enf.") 
#ggsave("ir_config4.pdf")

gplot_config(ir_vingt_typ, "5. Couples avec 3 enf. ou plus") 
#ggsave("ir_config5.pdf")

# graphes avec des vignettes
ir_config_part <- ir_vingt_typ5 %>% 
  select(ir_part0, ir_part1, ir_part2, typmen6, rang_vingtile) %>%
  gather(starts_with("ir_part"), key = scenar, value = ir_part)

gplot_cfg_part_vig <- ggplot(ir_config_part, aes(x=rang_vingtile, y=ir_part, fill=scenar)) 
gplot_cfg_part_vig + geom_bar(stat = "identity", position = "dodge") + facet_wrap(typmen6 ~ .) +
  theme(legend.position = "bottom", legend.text = element_text(size = 16),
        legend.title = element_text(size = 16, face = "bold"),
        plot.title = element_text(size=18, face = "bold")) +
  scale_fill_viridis_d(option = "viridis", name="Impôt", 
                       labels=c("Individuel", "Conjugal", "Réel")) +
  labs(x = "Vingtile de niveau de vie", y = "Proportion de niveau de vie")
ggsave("ir_par_typ.pdf")

ir_config_impos <- ir_vingt_typ5 %>% 
  select(ir_nb0, ir_nb1, ir_nb2, typmen6, rang_vingtile) %>%
  gather(starts_with("ir_nb"), key = scenar, value = ir_nb)

gplot_cfg_impos_vig <- ggplot(ir_config_impos, aes(x=rang_vingtile, y=ir_nb, fill=scenar)) 
gplot_cfg_impos_vig + geom_bar(stat = "identity", position = "dodge") + facet_wrap(typmen6 ~ .) +
  theme(legend.position = "bottom", legend.text = element_text(size = 16),
        legend.title = element_text(size = 16, face = "bold"),
        plot.title = element_text(size=18, face = "bold")) +
  scale_fill_viridis_d(option = "viridis", name="Impôt", 
                       labels=c("Individuel", "Conjugal", "Réel")) +
  labs(x = "Vingtile de niveau de vie", y = "Part de ménages")
ggsave("ir_imp_typ.pdf")

ir_config_tot <- ir_vingt_typ5 %>% 
  select(ir_tot0, ir_tot1, ir_tot2, typmen6, rang_vingtile) %>%
  gather(starts_with("ir_tot"), key = scenar, value = ir_tot)

gplot_cfg_tot_vig <- ggplot(ir_config_tot, aes(x=rang_vingtile, y=ir_tot, fill=scenar)) 
gplot_cfg_tot_vig + geom_bar(stat = "identity", position = "dodge") + facet_wrap(typmen6 ~ .) +
  theme(legend.position = "bottom", legend.text = element_text(size = 16),
        legend.title = element_text(size = 16, face = "bold"),
        plot.title = element_text(size=18, face = "bold")) +
  scale_fill_discrete(name="Impôt", labels=c("Individuel", "Conjugal", "Familial")) +
  labs(title = "Impôt payé selon le niveau de vie", 
       x = "Vingtile de niveau de vie", y = "Montants (en euros)")
#ggsave("ir_ir_typ.pdf")
       
# Tableaux 2 et 3 : effets par configuration familiale
tbl_eff_typ <- basemen_champ %>% 
  group_by(typmen6) %>% 
  summarise(
    poi_sum = sum(poi_0),
    # Masses des effets
    delta_QC = sum(delta_01 * poi_0),  
    delta_QF = sum(delta_12 * poi_0), 
    delta_QCQF = sum(delta_02 * poi_0),
    gain_QC = sum(delta_01 * gag_01 * poi_0),  
    gain_QF = sum(delta_12 * gag_12 * poi_0), 
    gain_QCQF = sum(delta_02 * gag_02 * poi_0),
    pert_QC = sum(delta_01 * per_01 * poi_0),  
    pert_QF = sum(delta_12 * per_12 * poi_0), 
    pert_QCQF = sum(delta_02 * per_02 * poi_0),
    # Total IR
    tot_ind = sum(impot_0 * poi_0),
    tot_QC = sum(impot_1 * poi_0),
    tot_QCQF = sum(impot_2 * poi_0),
    # Montant moyen d'IR sur tous les ménages
    ir_moy_men_ind = wtd.mean(impot_0, w=poi_0),
    ir_moy_men_QC = wtd.mean(impot_1, w=poi_0),
    ir_moy_men_QCQF = wtd.mean(impot_2, w=poi_0),
    # Nombre de ménages GPN
    nb_gag_QC = sum(gag_01 * poi_0),  
    nb_gag_QF = sum(gag_12 * poi_0), 
    nb_gag_QCQF = sum(gag_02 * poi_0),
    nb_per_QC = sum(per_01 * poi_0),  
    nb_per_QF = sum(per_12 * poi_0), 
    nb_per_QCQF = sum(per_02 * poi_0)
    )

tbl_gag_sc <- function(my_tbl, num_sc){
  tbl_gag <- my_tbl %>%
    group_by(typmen6) %>%  
    select(ident, poi_0, typmen6, 
           paste("delta", num_sc, sep='_'), paste("gag", num_sc, sep='_')) %>%
    filter(!!sym(paste("gag", num_sc, sep='_')) == TRUE) %>% 
    transmute(moy_gag = wtd.mean(!!sym(paste("delta", num_sc, sep='_')), w=poi_0)) %>% 
    distinct() 
    tbl_gag <- tbl_gag[order(tbl_gag$typmen6),]
  return(tbl_gag)
}

tbl_gag_QC <- tbl_gag_sc(basemen_champ, "01")
tbl_gag_QF <- tbl_gag_sc(basemen_champ, "12")
tbl_gag_QCQF <- tbl_gag_sc(basemen_champ, "02")

tbl_per_sc <- function(my_tbl, num_sc){
  tbl_per <- my_tbl %>%
    group_by(typmen6) %>%  
    select(ident, poi_0, typmen6, 
           paste("delta", num_sc, sep='_'), paste("per", num_sc, sep='_')) %>%
    filter(!!sym(paste("per", num_sc, sep='_')) == TRUE) %>% 
    transmute(moy_per = wtd.mean(!!sym(paste("delta", num_sc, sep='_')), w=poi_0)) %>% 
    distinct() 
  tbl_per <- tbl_per[order(tbl_per$typmen6),]
  return(tbl_per)
}

tbl_per_QC <- tbl_per_sc(basemen_champ, "01")
tbl_per_QF <- tbl_per_sc(basemen_champ, "12")
tbl_per_QCQF <- tbl_per_sc(basemen_champ, "02")

nb_men <- sum(tbl_eff_typ$poi_sum)
nb_gQC <- sum(tbl_eff_typ$nb_gag_QC)
nb_gQF <- sum(tbl_eff_typ$nb_gag_QF)
nb_gQCQF <- sum(tbl_eff_typ$nb_gag_QCQF)
nb_pQC <- sum(tbl_eff_typ$nb_per_QC)
nb_pQF <- sum(tbl_eff_typ$nb_per_QF)
nb_pQCQF <- sum(tbl_eff_typ$nb_per_QCQF)

col_t3_1 <- round(tbl_eff_typ$poi_sum/10^3, d = 0)
col_t3_2 <- round(tbl_eff_typ$poi_sum/nb_men, d = 3)*100
col_t3_3 <- round(tbl_eff_typ$nb_gag_QC/10^3, d = 0)
col_t3_4 <- round(tbl_eff_typ$nb_gag_QC/nb_gQC, d = 3)*100
col_t3_5 <- round(tbl_eff_typ$nb_gag_QF/10^3, d = 0)
col_t3_6 <- round(tbl_eff_typ$nb_gag_QF/nb_gQF, d = 3)*100
col_t3_7 <- round(tbl_eff_typ$nb_gag_QCQF/10^3, d = 0)
col_t3_8 <- round(tbl_eff_typ$nb_gag_QCQF/nb_gQCQF, d = 3)*100
col_t3_9 <- round(tbl_eff_typ$nb_per_QCQF/10^3, d = 0)
col_t3_10 <- round(tbl_eff_typ$nb_per_QCQF/nb_pQCQF, d = 3)*100
col_t3_11 <- round(tbl_eff_typ$nb_per_QC/10^3, d = 0)
col_t3_12 <- round(tbl_eff_typ$nb_per_QC/nb_pQC, d = 3)*100

tot_gQC <- sum(tbl_eff_typ$gain_QC)
tot_gQF <- sum(tbl_eff_typ$gain_QF)
tot_gQCQF <- sum(tbl_eff_typ$gain_QCQF)
tot_pQC <- sum(tbl_eff_typ$pert_QC)
tot_pQCQF <- sum(tbl_eff_typ$pert_QCQF)

col_t4_1 <- round(tbl_eff_typ$ir_moy_men_QCQF, d = 1)
col_t4_2 <- round(tbl_gag_QC$moy_gag, d = 1)
col_t4_3 <- round(tbl_eff_typ$gain_QC/10^6, d = 0)
col_t4_4 <- round(tbl_eff_typ$gain_QC/tot_gQC, d = 3)*100
col_t4_5 <- round(tbl_eff_typ$gain_QF/10^6, d = 0)
col_t4_6 <- round(tbl_eff_typ$gain_QF/tot_gQF, d = 3)*100
col_t4_7 <- round(tbl_eff_typ$gain_QCQF/10^6, d = 0)
col_t4_8 <- round(tbl_eff_typ$gain_QCQF/tot_gQCQF, d = 3)*100

nom_typmen <- c("Célibataires", "Familles monop.", "Couples sans enfant",
                "Couples, 1 ou 2 enf.", "Couples, 3 enf. ou +","Ménages complexes")
names(col_t3_1) <- nom_typmen
names(col_t3_2) <- nom_typmen
names(col_t3_3) <- nom_typmen 
names(col_t3_4) <- nom_typmen 
names(col_t3_5) <- nom_typmen 
names(col_t3_6) <- nom_typmen
names(col_t3_7) <- nom_typmen
names(col_t3_8) <- nom_typmen
names(col_t3_9) <- nom_typmen
names(col_t3_10) <- nom_typmen
names(col_t3_11) <- nom_typmen
names(col_t3_12) <- nom_typmen

names(col_t4_1) <- nom_typmen
names(col_t4_2) <- nom_typmen
names(col_t4_3) <- nom_typmen 
names(col_t4_4) <- nom_typmen 
names(col_t4_5) <- nom_typmen 
names(col_t4_6) <- nom_typmen
names(col_t4_7) <- nom_typmen
names(col_t4_8) <- nom_typmen 

my_tab3 <- t(rbind(col_t3_1, col_t3_2, col_t3_3, col_t3_4, col_t3_5, col_t3_6, 
                   col_t3_7, col_t3_8, col_t3_9, col_t3_10, col_t3_11, col_t3_12))
my_tab3 <- rbind(my_tab3, round(apply(my_tab3, 2, sum), d = 0))
row.names(my_tab3)[7] <- "Total" 
kable(my_tab3, booktabs = T)

my_tab4 <- t(rbind(col_t4_1, col_t4_2, col_t4_3, col_t4_4, col_t4_5, col_t4_6, col_t4_7, col_t4_8))
my_tab4 <- rbind(my_tab4, round(apply(my_tab4, 2, sum), d = 0))
my_tab4[7,1] <- round(sum(tbl_eff_typ$tot_QCQF) / nb_men, d = 1)
my_tab4[7,2] <- round(tot_gQCQF / nb_gQCQF, d = 1) 
row.names(my_tab4)[7] <- "Total" 
kable(my_tab4, booktabs = T)

col_t5_1 <- round(tbl_eff_typ$nb_per_QC/10^3, d = 0)
col_t5_2 <- round(tbl_eff_typ$nb_per_QC/nb_pQC, d = 3)*100
col_t5_3 <- round(tbl_per_QC$moy_per, d = 1)
col_t5_4 <- round(tbl_eff_typ$pert_QC/10^6, d = 0)
col_t5_5 <- round(tbl_eff_typ$pert_QC/tot_pQC, d = 3)*100
col_t5_6 <- round(tbl_eff_typ$pert_QCQF/10^6, d = 0)
col_t5_7 <- round(tbl_eff_typ$pert_QCQF/tot_pQCQF, d = 3)*100

names(col_t5_1) <- nom_typmen
names(col_t5_2) <- nom_typmen
names(col_t5_3) <- nom_typmen 
names(col_t5_4) <- nom_typmen 
names(col_t5_5) <- nom_typmen 
names(col_t5_6) <- nom_typmen
names(col_t5_7) <- nom_typmen

my_tab5 <- t(rbind(col_t5_1, col_t5_2, col_t5_3, col_t5_4, col_t5_5, col_t5_6, col_t5_7))
my_tab5 <- rbind(my_tab5, round(apply(my_tab5, 2, sum), d = 0))

my_tabGP_QC <- my_tab3[, 1:4] # les gagnants 
my_tabGP_QC <- cbind(my_tabGP_QC, my_tab5[, 1:2])# les perdants
my_tabGP_QC <- cbind(my_tabGP_QC, my_tab4[, 2:4]) # les gains.
my_tabGP_QC <- cbind(my_tabGP_QC, my_tab5[, 3:4])# les pertes
my_tabGP_QC <- cbind(my_tabGP_QC, my_tab4[, 1]) # l'IR moyen
write.xlsx(my_tabGP_QC, sheetName = "Eff_cfg_QC", file = "sorties_qc_qf.xlsx", append = TRUE)

my_tabGP_QCQF <- my_tab3[, 7:9] # les gagnants 
my_tabGP_QCQF <- cbind(my_tabGP_QCQF, my_tab3[, 10:12])# les perdants
my_tabGP_QCQF <- cbind(my_tabGP_QCQF, my_tab4[, 7:8]) # les gains.
my_tabGP_QCQF <- cbind(my_tabGP_QCQF, my_tab5[, 6:7])# les pertes
my_tabGP_QCQF <- cbind(my_tabGP_QCQF, my_tab4[, 1]) # l'IR moyen
write.xlsx(my_tabGP_QCQF, sheetName = "Eff_cfg_QCQF", file = "sorties_qc_qf.xlsx", append = TRUE)

# Tableau d'indicateurs pauvreté et inégalité
eff_ineg_ind_fam <- ineg_pauv_fam / ineg_pauv_ind - 1
my_tab_ineg <- t(bind_rows(ineg_pauv_ind, ineg_pauv_con, ineg_pauv_fam, eff_ineg_ind_fam))
colnames(my_tab_ineg) <- c("Individuel", "Conjugal", "Familial", "Effet Ind. - Fam.")
rownames(my_tab_ineg) <- c("Taux de pauvreté", "Intensité de la pauvreté", "Indice de Gini",
                           "D9/D1", "P95/P5", "Seuil de pauvreté")
my_tab_ineg <- round(my_tab_ineg, d=3)
kable(my_tab_ineg, booktabs = T)
write.xlsx(my_tab_ineg, sheetName = "Ineg", file = "sorties_qc_qf.xlsx", append = TRUE)

# distribution des gains par vingtile
col_GP_12 <- round(select(ir_vingt, tot_gain_01, tot_pert_01)/10^6, d = 1)
col_GP_3 <- round(select(ir_vingt, ir_tot0)/10^6, d = 1)

my_tab_GP <- cbind(col_GP_12, col_GP_3)
names(my_tab_GP) <- c("Gains", "Pertes", "IR payé")
write.xlsx(my_tab_GP, sheetName = "Gains_Pertes", file = "sorties_qc_qf.xlsx", append = TRUE)
kable(my_tab_GP, booktabs = T)

# plafonnement du QF
# part des plafonnés dans tous les ménages
ir_vingt$par_plaf_qf
# répartition des ménages plafonnés
ir_vingt$nb_plaf_qf/sum(ir_vingt$nb_plaf_qf)
