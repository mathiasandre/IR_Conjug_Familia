library(haven)
library(ggplot2)
library(descr)
library(Hmisc) # pour les fonctions wtd.XX
library(microbenchmark)
library(dplyr)
library(tidyr)

# Lecture de la base de synthèse des scénarios
setwd("D:/hwsdmo/QC_QF")
impot_all <- read_sas("impot_sur_rev16_synthese.sas7bdat")
names(impot_all)

impot_diff <- transmute(impot_all,
  ident = ident,
  parts = npart_sc0,
  i1_0 = impot11_sc0 + impot12_sc0 + impot13_sc0 + impot14_sc0 + impot15_sc0,
  i2_0 = impot21_sc0 + impot22_sc0 + impot23_sc0 + impot24_sc0 + impot25_sc0,
  i3_0 = impot31_sc0 + impot32_sc0 + impot33_sc0 + impot34_sc0 + impot35_sc0,
  i4_0 = impot41_sc0 + impot42_sc0 + impot43_sc0 + impot44_sc0 + impot45_sc0,
  i5_0 = impot51_sc0 + impot52_sc0 + impot53_sc0 + impot54_sc0 + impot55_sc0,
  i6_0 = impot61_sc0 + impot62_sc0 + impot63_sc0 + impot64_sc0 + impot65_sc0,
  i7_0 = impot71_sc0 + impot72_sc0 + impot73_sc0 + impot74_sc0 + impot75_sc0,
  i8_0 = impot81_sc0 + impot82_sc0 + impot83_sc0 + impot84_sc0 + impot85_sc0,
  i9_0 = impot91_sc0 + impot92_sc0 + impot93_sc0 + impot94_sc0 + impot95_sc0,
  i1_1 = impot11_sc1 + impot12_sc1 + impot13_sc1 + impot14_sc1 + impot15_sc1,
  i2_1 = impot21_sc1 + impot22_sc1 + impot23_sc1 + impot24_sc1 + impot25_sc1,
  i3_1 = impot31_sc1 + impot32_sc1 + impot33_sc1 + impot34_sc1 + impot35_sc1,
  i4_1 = impot41_sc1 + impot42_sc1 + impot43_sc1 + impot44_sc1 + impot45_sc1,
  i5_1 = impot51_sc1 + impot52_sc1 + impot53_sc1 + impot54_sc1 + impot55_sc1,
  i6_1 = impot61_sc1 + impot62_sc1 + impot63_sc1 + impot64_sc1 + impot65_sc1,
  i7_1 = impot71_sc1 + impot72_sc1 + impot73_sc1 + impot74_sc1 + impot75_sc1,
  i8_1 = impot8_sc1,
  i9_1 = impot9_sc1,
  i1_2 = impot1_sc2,
  i2_2 = impot2_sc2,
  i3_2 = impot3_sc2,
  i4_2 = impot4_sc2,
  i5_2 = impot5_sc2,
  i6_2 = impot6_sc2,
  i7_2 = impot7_sc2,
  i8_2 = impot8_sc2,
  i9_2 = impot9_sc2,
  diff_i1_01 = i1_0 - i1_1,
  diff_i2_01 = i2_0 - i2_1,
  diff_i3_01 = i3_0 - i3_1,
  diff_i4_01 = i4_0 - i4_1,
  diff_i5_01 = i5_0 - i5_1,
  diff_i6_01 = i6_0 - i6_1,
  diff_i7_01 = i7_0 - i7_1,
  diff_i8_01 = i8_0 - i8_1,
  diff_i9_01 = i9_0 - i9_1,
  diff_i1_12 = i1_1 - i1_2,
  diff_i2_12 = i2_1 - i2_2,
  diff_i3_12 = i3_1 - i3_2,
  diff_i4_12 = i4_1 - i4_2,
  diff_i5_12 = i5_1 - i5_2,
  diff_i6_12 = i6_1 - i6_2,
  diff_i7_12 = i7_1 - i7_2,
  diff_i8_12 = i8_1 - i8_2,
  diff_i9_12 = i9_1 - i9_2,
  diff_i1_02 = i1_0 - i1_2,
  diff_i2_02 = i2_0 - i2_2,
  diff_i3_02 = i3_0 - i3_2,
  diff_i4_02 = i4_0 - i4_2,
  diff_i5_02 = i5_0 - i5_2,
  diff_i6_02 = i6_0 - i6_2,
  diff_i7_02 = i7_0 - i7_2,
  diff_i8_02 = i8_0 - i8_2,
  diff_i9_02 = i9_0 - i9_2,
  gag_bareme_QC = diff_i1_01 > 0,
  per_bareme_QC = diff_i1_01 < 0, 
  gag_bareme_QF = diff_i1_12 > 0, 
  per_bareme_QF = diff_i1_12 < 0, 
  gag_rexcep_QC = diff_i2_01 > 0,
  per_rexcep_QC = diff_i2_01 < 0,
  gag_rexcep_QF = diff_i2_12 > 0,
  per_rexcep_QF = diff_i2_12 < 0,
  gag_decote_QC = diff_i3_01 > 0, 
  per_decote_QC = diff_i3_01 < 0,
  gag_decote_QF = diff_i3_12 > 0,
  per_decote_QF = diff_i3_12 < 0,
  gag_reduct_QC = diff_i5_01 > 0, 
  per_reduct_QC = diff_i5_01 < 0,
  gag_reduct_QF = diff_i5_12 > 0,
  per_reduct_QF = diff_i5_12 < 0,
  gag_credit_QC = diff_i7_01 > 0, 
  per_credit_QC = diff_i7_01 < 0,
  gag_credit_QF = diff_i7_12 > 0,
  per_credit_QF = diff_i7_12 < 0,
  gag_plafon_QC = diff_i8_01 > 0, 
  per_plafon_QC = diff_i8_01 < 0,
  gag_plafon_QF = diff_i8_12 > 0,
  per_plafon_QF = diff_i8_12 < 0
  # i4 c'est les PV de cession
  # i6 c'est avant 93
  # i7 c'est revenu à l'étranger
  # i9 c'est CEHR et prélèvements libératoires
)
attr(impot_diff$ident, "label") <- NULL

# on agrége au niveau ménage : on somme les impôts et on compte les foyers GP et les parts
impot_diff_men <- impot_diff %>% group_by(ident) %>% summarise_all(funs(sum))

# on détecte les gagnants et perdants pour les principaux cas
eff_bare_QC <- impot_diff_men %>% filter(gag_bareme_QC + per_bareme_QC > 0)
eff_deco_QC <- impot_diff_men %>% filter(gag_decote_QC + per_decote_QC > 0)
eff_ciri_QC <- impot_diff_men %>% filter(gag_reduct_QC + gag_reduct_QC + gag_credit_QC + per_credit_QC > 0)
eff_bare_QF <- impot_diff_men %>% filter(gag_bareme_QF + per_bareme_QF > 0)
eff_deco_QF <- impot_diff_men %>% filter(gag_decote_QF + per_decote_QF > 0)
eff_ciri_QF <- impot_diff_men %>% filter(gag_reduct_QF + gag_reduct_QF + gag_credit_QF + per_credit_QF > 0)

# on merge avec basemen_champ du programme compagnon gplot.R
basemen_diff <- basemen_champ %>% 
  select(ident, poi_0, uci_0, nbp_0, typmen6, poiind, 
         starts_with("rang"), starts_with("Ndv"), starts_with("imp"),
         starts_with("per"), starts_with("gag"), starts_with("neu"), starts_with("delt"))

eff_bare_QC <- inner_join(basemen_diff, eff_bare_QC, by = "ident")
eff_deco_QC <- inner_join(basemen_diff, eff_deco_QC, by = "ident")
eff_ciri_QC <- inner_join(basemen_diff, eff_ciri_QC, by = "ident")
eff_bare_QF <- inner_join(basemen_diff, eff_bare_QF, by = "ident")
eff_deco_QF <- inner_join(basemen_diff, eff_deco_QF, by = "ident")
eff_ciri_QF <- inner_join(basemen_diff, eff_ciri_QF, by = "ident")


##  vérifications 
imp_tot_men <- sum((basemen_champ$impot_tot_2 > 0) * basemen_champ$poi_0)
nb_men <- sum(basemen_champ$poi_0)
imp_tot_men/nb_men

imp_men <- sum((basemen_champ$impot_2 > 0) * basemen_champ$poi_0)
nb_men <- sum(basemen_champ$poi_0)
imp_men/nb_men

ident_poi <- select(basemen_champ, poi_0, ident)
tbl_foy <- left_join(impot_all, ident_poi, by = "ident")
imp_foy <- sum((tbl_foy$impot_sc2 > 0) * tbl_foy$poi_0, na.rm = T)
nb_foy <- sum(tbl_foy$poi_0, na.rm = T)
imp_foy/nb_foy

base_verif <- basemen_champ %>% 
  select(starts_with("impot"), rang_centile) %>% 
  filter(rang_centile<99)
base_verif2 <- mutate(base_verif, diff_imp = impot_tot_0 - impot_0) %>% filter(diff_imp>0)

ggplot(base_verif, aes(x=rang_centile, y=impot_0)) + geom_jitter(alpha=0.1)
ggplot(base_verif, aes(x=rang_centile, y=impot_tot_0)) + geom_jitter(alpha=0.1)
ggplot(base_verif2, aes(x=rang_centile, y=diff_imp)) + geom_jitter(alpha=0.1)


