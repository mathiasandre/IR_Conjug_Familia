# un programme où on copie-colle les sorties pour FPS

# On a besoin d'avoir chargé des objets du programme général
setwd("D:/hwsdmo/QC_QF/sorties_FPS")

# part de ménages imposables dans les trois situations
tbl_ir_nb_xl <- ir_cent %>% 
  select(ir_nb0, ir_nb1, ir_nb2, rang_centile)
write.xlsx(tbl_ir_nb_xl, sheetName="centiles", file = "ir_imp.xlsx", append = TRUE)

# nombre de ménages GPN
tbl_GPN_xl <- ir_cent %>% 
  select(nb_per_01, nb_neu_01_MP, nb_neu_01_NC, nb_gag_01, rang_centile)
write.xlsx(tbl_GPN_xl, sheetName="centiles", file = "GPN_ind_conj.xlsx", append = TRUE)

# Part des pertes et gains dans le NdV
tbl_GP_xl <- ir_vingt %>% 
  select("par_per_01", "par_gag_01", rang_vingtile)
write.xlsx(tbl_GP_xl, sheetName="vingtiles", file = "GP_ind_conj.xlsx", append = TRUE)

# Calcul des effets moyens
moy_gag_QC <- basemen_champ %>%
  select(ident, poi_0, delta_01, gag_01) %>% 
  filter(gag_01 == TRUE) %>% 
  transmute(moy_gag_QC = wtd.mean(delta_01, w=poi_0)) %>% 
  distinct() %>% 
  as.numeric()

moy_per_QC <- basemen_champ %>% 
  select(ident, poi_0, delta_01, per_01) %>% 
  filter(per_01 == TRUE) %>% 
  transmute(moy_per_QC = wtd.mean(per_01 * delta_01, w=poi_0)) %>% 
  distinct() %>% 
  as.numeric()

eff_moy_QC <- basemen_champ %>% 
  select(ident, poi_0, delta_01) %>% 
  filter(delta_01 != 0) %>% 
  transmute(eff_moy_QC = wtd.mean(delta_01, w=poi_0)) %>% 
  distinct() %>% 
  as.numeric()

# Tab1 : Effets moyens par décile
col_gain_dec <- transmute(ir_dec, tot_gain_01/nb_gag_01)
col_gag_dec <- ir_dec$nb_gag_01
col_pert_dec <- transmute(ir_dec, tot_pert_01/nb_per_01)
col_per_dec <- ir_dec$nb_per_01

my_tab_eff_dec <- cbind(col_gain_dec, col_gag_dec, col_pert_dec, col_per_dec)
ens_tab_eff_dec <- c(moy_gag_QC, sum(col_gag_dec), moy_per_QC, sum(col_per_dec))
my_tab_eff_dec <- rbind(my_tab_eff_dec, ens_tab_eff_dec)
write.xlsx(my_tab_eff_dec, sheetName = "T1_Eff_dec", file = "sorties_fps.xlsx", append = TRUE)

col_t1_1 <- round(select(tbl_eff, starts_with("impos"))/10^6, d = 1)
col_t1_2 <- round(select(tbl_eff, starts_with("part_impos"))*100, d = 1)
col_t1_3 <- round(select(tbl_eff, starts_with("tot"))/10^9, d = 1)
col_t1_4 <- round(c(dist_ind$moy, dist_QC$moy, dist_QCQF$moy), d = 0)
col_t1_5 <- round(c(dist_ind$med, dist_QC$med, dist_QCQF$med), d = 0)
col_t1_6 <- round(c(dist_ind$Q1, dist_QC$Q1, dist_QCQF$Q1), d = 0)
col_t1_7 <- round(c(dist_ind$Q3, dist_QC$Q3, dist_QCQF$Q3), d = 0) 

names(col_t1_1) <- c("Individuel", "Conjugal", "Familial")
names(col_t1_2) <- c("Individuel", "Conjugal", "Familial")
names(col_t1_3) <- c("Individuel", "Conjugal", "Familial") 
names(col_t1_4) <- c("Individuel", "Conjugal", "Familial") 
names(col_t1_5) <- c("Individuel", "Conjugal", "Familial") 
names(col_t1_6) <- c("Individuel", "Conjugal", "Familial") 
names(col_t1_7) <- c("Individuel", "Conjugal", "Familial")

my_tab_impo <- t(rbind(col_t1_1, col_t1_2, col_t1_3, col_t1_4, col_t1_5, col_t1_6, col_t1_7))
write.xlsx(my_tab_impo, sheetName = "MenImpo", file = "sorties_fps.xlsx", append = TRUE)

# Tab 2 : Effets agrégés du QC

my_tab_eff <- c(
  tbl_eff$tot_ind - tbl_eff$tot_QC,
  eff_moy_QC,
  tbl_eff$nb_gag_QC,
  tbl_eff$nb_gag_QC/nb_men,
  tbl_eff$nb_per_QC,
  tbl_eff$nb_per_QC/nb_men,
  moy_gag_QC,
  moy_per_QC,  
  tbl_eff$nb_neu_QC,
  tbl_eff$nb_neu_QC/nb_men,    
  tbl_eff$nb_neu_typ1_QC,   
  tbl_eff$nb_neu_typ1_QC/tbl_eff$nb_neu_QC,
  tbl_eff$nb_neu_typ1_QC/nb_men,
  tbl_eff$nb_neu_typ2_QC,
  tbl_eff$nb_neu_typ2_QC/tbl_eff$nb_neu_QC,
  tbl_eff$nb_neu_typ2_QC/nb_men)
write.xlsx(my_tab_eff, sheetName = "T2_Effets", file = "sorties_fps.xlsx", append = TRUE)

# part de ménages MP neutres non imposables dans les deux cas 
sum(ir_cent$nb_neu_typ1_MP_01)/nb_men

tbl_typ5_xl <- ir_vingt_typ5 %>% 
  select(poi_sum, poiind_sum, typmen6, rang_vingtile) %>% 
  arrange(typmen6)
write.xlsx(as.data.frame(tbl_typ5_xl), sheetName="vingtiles", file = "config_typ.xlsx")

# Tableaux 2 et 3 : effets par configuration familiale

tbl_gag_QC <- tbl_gag_sc(basemen_champ, "01")
tbl_per_QC <- tbl_per_sc(basemen_champ, "01")

nb_men <- sum(tbl_eff_typ$poi_sum)
nb_gQC <- sum(tbl_eff_typ$nb_gag_QC)
nb_pQC <- sum(tbl_eff_typ$nb_per_QC)
tot_gQC <- sum(tbl_eff_typ$gain_QC)
tot_pQC <- sum(tbl_eff_typ$pert_QC)
nom_typmen <- c("Célibataires", "Familles monop.", "Couples sans enfant",
                "Couples, 1 ou 2 enf.", "Couples, 3 enf. ou +","Ménages complexes")

my_tabGP_QC <- tbl_eff_typ$nb_gag_QC
my_tabGP_QC <- cbind(my_tabGP_QC,tbl_eff_typ$nb_per_QC) 
my_tabGP_QC <- cbind(my_tabGP_QC,tbl_eff_typ$gain_QC)
my_tabGP_QC <- cbind(my_tabGP_QC,tbl_eff_typ$pert_QC)
rownames(my_tabGP_QC) <- nom_typmen
write.xlsx(my_tabGP_QC, sheetName = "Eff_cfg_QC", file = "sorties_fps.xlsx", append = TRUE)

# Tableau d'indicateurs pauvreté et inégalité
eff_ineg_ind_fam <- ineg_pauv_fam / ineg_pauv_ind - 1
my_tab_ineg <- t(bind_rows(ineg_pauv_ind, ineg_pauv_con, ineg_pauv_fam, eff_ineg_ind_fam))
colnames(my_tab_ineg) <- c("Individuel", "Conjugal", "Familial", "Effet Ind. - Fam.")
rownames(my_tab_ineg) <- c("Taux de pauvreté", "Intensité de la pauvreté", "Indice de Gini",
                           "D9/D1", "P95/P5", "Seuil de pauvreté")
my_tab_ineg <- round(my_tab_ineg, d=3)
write.xlsx(my_tab_ineg, sheetName = "Ineg", file = "sorties_fps.xlsx", append = TRUE)

# distribution des gains par vingtile
col_GP_12 <- round(select(ir_vingt, tot_gain_01, tot_pert_01)/10^6, d = 1)
col_GP_3 <- round(select(ir_vingt, ir_tot0)/10^6, d = 1)

my_tab_GP <- cbind(col_GP_12, col_GP_3)
names(my_tab_GP) <- c("Gains", "Pertes", "IR payé")
write.xlsx(my_tab_GP, sheetName = "Gains_Pertes", file = "sorties_fps.xlsx", append = TRUE)

# plafonnement du QF
# part des plafonnés dans tous les ménages
ir_vingt$par_plaf_qf
# répartition des ménages plafonnés
ir_vingt$nb_plaf_qf/sum(ir_vingt$nb_plaf_qf)

# typologie des ménages neutres
nb_nQC_MP <- sum(ir_cent$nb_neu_01_MP)
nb_nQC_NC <- sum(ir_cent$nb_neu_01_NC)
nb_nQC <- nb_men - nb_gQC - nb_pQC # c'est bien égal à nb_neu_01_MP + nb_neu_01_NC
nb_nQC_MP / nb_men
nb_nQC_NC / nb_men

nb_nQC_MP_typ1 <- sum(basemen_champ$neu_typ1_01 * basemen_champ$poi_0 * basemen_champ$mar_pacs)
nb_nQC_MP_typ2 <- sum(basemen_champ$neu_typ2_01 * basemen_champ$poi_0 * basemen_champ$mar_pacs)
# on a bien nb_nQC_MP = nb_nQC_MP_typ1 + nb_nQC_MP_typ2
nb_nQC_MP_typ1 / nb_nQC_MP
nb_nQC_MP_typ2 / nb_nQC_MP

setwd("X:/HAB-Ines-D2E/pote")
ir_qc <- read_sas("ir_champ_95_qc.sas7bdat")
str(ir_qc)

irt5_DixMille_seuils <- quantile(ir_qc$RFR, probs = 1:499/500)
ir_qc$irt5_DixMille_class <- ntile(ir_qc$RFR, 500)

irt5_DixMille <- ir_qc %>% 
  group_by(irt5_DixMille_class) %>% 
  summarise(
    nb_per_01 = sum(per_01),
    nb_gag_01 = sum(gag_01),
    tot_gain_01 = sum(gag_01 * delta_01),
    tot_pert_01 = sum(per_01 * delta_01)
  )
write.xlsx(irt5_DixMille, file = "irt5_DixMille.xlsx", append = TRUE)
