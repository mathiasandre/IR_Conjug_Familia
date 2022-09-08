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
library(hexbin)
options(knitr.table.format = "latex")
theme_update(plot.title = element_text(hjust = 0.5))


setwd("D:/hwsdmo/sorties_qc_qf")
impot_all <- read_sas("impot_sur_rev16_synthese.sas7bdat")
baseind <- read_sas("baseind2017.sas7bdat")
setwd("D:/hwsdmo/QC_QF/2017")

impot_all <- tbl_df(impot_all)
baseind <- tbl_df(baseind)
str(impot_all)
names(impot_all)
# on ne se restreint pas au champ Ines (on aurait pu via une jointure avec basemen)
# on raisonne au niveau foyer

nb_foy <- sum(impot_all$poi_0)

tib_rbg_small <- impot_all %>% 
  select(ident, declar, mcdvo_sc0, poi_0, starts_with("RBG")) %>% 
  filter(mcdvo_sc0 %in% c("M", "O")) %>% 
  filter(percent_rank(RBG_1_sc0) < 0.999 & percent_rank(RBG_2_sc0) < 0.999)
  # on enlève le top 0,1% pour les graphes
  # il n'y a pas de na dans les variables RBG
#names(tib_rbg)

# attention le graphique suivant n'est pas pondéré
ggplot(tib_rbg_small, aes(RBG_1_sc0, RBG_2_sc0)) +
  geom_bin2d(bins = 100)  + 
  scale_fill_continuous(type = "viridis")

tib_rbg_xl <- impot_all %>% 
  mutate(rgb_foy_moy = (RBG_1_sc0 + RBG_2_sc0)/2,
         ving_rbgf = ntiles.wtd(rgb_foy_moy, 20, w = poi_0),
         ving_rbg1 = ntiles.wtd(RBG_1_sc0, 20, w = poi_0),
         ving_rbg2 = ntiles.wtd(RBG_2_sc0, 20, w = poi_0))

# vingtiles/déciles de RBG moyen des foyers des couples
ving_rbg <- wtd.quantile(tib_rbg_xl$rgb_foy_moy, 
                      probs = 5 * (1:19)/100, w = tib_rbg_xl$poi_0)
dec_rbg <- wtd.quantile(tib_rbg_xl$rgb_foy_moy, 
                        probs = 1:9/10, w = tib_rbg_xl$poi_0)

# fonction qui donne le rang du percentile selon ces seuils calculés avant
mon_rang <- function(ma_var, mes_seuils){
  ifelse(
    ma_var > max(mes_seuils), ma_pos <- length(mes_seuils) + 1,
    ma_pos <- which.max(ma_var <= mes_seuils)
  )
  return(as.integer(ma_pos))
}

# vérification de la fonction mon_ving :
# vv = sapply(tib_rbg_xl$rgb_foy_moy, mon_ving)
# sum(vv - tib_rbg_xl$ving_rbgf) = 0 
# on a recalculé les vingtiles donc on peut classer d'autres variables

# calcul des rangs de vingtile des membres du couple :
tib_rbg_xl$rg20_rbg1 <- sapply(tib_rbg_xl$RBG_1_sc0, mon_rang, mes_seuils = ving_rbg)
tib_rbg_xl$rg20_rbg2 <- sapply(tib_rbg_xl$RBG_2_sc0, mon_rang, mes_seuils = ving_rbg)

# on regroupe par rangs des deux membres :
tib_rbg20_xl <- tib_rbg_xl %>% 
  group_by(rg20_rbg1, rg20_rbg2) %>% 
  summarise(par_foy = sum(poi_0)/nb_foy)

ggplot(tib_rbg20_xl, aes(rg20_rbg1, rg20_rbg2, fill = par_foy)) +
  geom_tile() + 
  scale_fill_viridis()

tib_rbg_xl$rg10_rbg1 <- sapply(tib_rbg_xl$RBG_1_sc0, mon_rang, mes_seuils = dec_rbg)
tib_rbg_xl$rg10_rbg2 <- sapply(tib_rbg_xl$RBG_2_sc0, mon_rang, mes_seuils = dec_rbg)
tib_rbg_xl <- tib_rbg_xl %>% 
  group_by(rg10_rbg1) %>% 
  mutate(nb_foy1 = sum(poi_0))
tib_rbg_xl <- tib_rbg_xl %>% 
  group_by(rg10_rbg2) %>% 
  mutate(nb_foy2 = sum(poi_0))
tib_rbg10_xl <- tib_rbg_xl %>% 
  group_by(rg10_rbg1, rg10_rbg2) %>% 
  summarise(par_foy = sum(poi_0)/nb_foy,
            par_foy1 = sum(poi_0/nb_foy1),
            par_foy2 = sum(poi_0/nb_foy2))
write.xlsx(as.data.frame(tib_rbg10_xl), sheetName = "RBG_dec", file = "sorties_qc_qf.xlsx")

# heatmap par décile des parts de foyers
ggplot(tib_rbg10_xl, aes(rg10_rbg1, rg10_rbg2, fill = par_foy)) +
  geom_tile() + 
 #scale_fill_continuous(type = "gradient")
  scale_fill_viridis(direction = -1, option = "magma")

ggplot(tib_rbg10_xl, aes(rg10_rbg1, rg10_rbg2, fill = par_foy1)) +
  geom_tile() + 
  #scale_fill_continuous(type = "gradient")
  scale_fill_viridis(direction = -1, option = "magma")

ggplot(tib_rbg10_xl, aes(rg10_rbg1, rg10_rbg2, fill = par_foy2)) +
  geom_tile() + 
  #scale_fill_continuous(type = "gradient")
  scale_fill_viridis(direction = -1, option = "magma")

# on regroupe par rang du déclarant
tib_rbg20_decl_xl <- tib_rbg_xl %>% 
  group_by(rg20_rbg1) %>% 
  summarise(par_foy = sum(poi_0)/nb_foy,
            Q25_rbg2 = wtd.quantile(RBG_2_sc0, probs = 0.25, w=poi_0),
            Q50_rbg2 = wtd.quantile(RBG_2_sc0, probs = 0.5, w=poi_0),
            Q75_rbg2 = wtd.quantile(RBG_2_sc0, probs = 0.75, w=poi_0),
            moy_rbg2 = weighted.mean(RBG_2_sc0, poi_0)
            )

ggplot(tib_rbg_xl, aes(x=rg20_rbg1, y=RBG_2_sc0, group = rg20_rbg1)) + 
  geom_boxplot()

tib_tx <- impot_all %>% 
  select(ident, declar, mcdvo_sc0, poi_0, starts_with("Tx"), starts_with("rib")) %>% 
  filter(mcdvo_sc0 %in% c("M", "O")) 
names(tib_tx)  

tib_tx <- tib_tx %>% 
  mutate(delta_txmar_1 = TxMarginal1_sc0 - TxMarginal_sc1,
         delta_txmar_2 = TxMarginal2_sc0 - TxMarginal_sc1,
         moy_txmar = (TxMarginal1_sc0 + TxMarginal2_sc0)/2
        # delta_txeff_f = TxEffectif_sc0 - TxEffectif_sc1,
        # delta_txeff_1 = TxEffectif1_sc0 - TxEffectif1_sc1,
        # delta_txeff_2 = TxEffectif2_sc0 - TxEffectif2_sc1
         )

# graphique du taux marginal en fonction du RIB
plot(tib_tx$RIB_sc0, tib_tx$TxMarginal_sc1)
plot(tib_tx$RIB_sc0, tib_tx$delta_txmar_1)
plot(tib_tx$delta_txmar_2)

tt=filter(tib_tx, delta_txmar_1*delta_txmar_2!=0)
table(tt$delta_txmar_1)
table(tt$delta_txmar_2)

plot(tib_tx$TxMarginal_sc1)

summary(tt$delta_txmar_1)
summary(tt$delta_txmar_2)



weighted.mean(x = tt$delta_txmar_1, w = tt$poi_0)
weighted.mean(x = tt$delta_txmar_2, w = tt$poi_0)

wtd.quantile(tt$delta_txmar_1, probs = 0:4/4, w =tt$poi_0)
wtd.quantile(tt$delta_txmar_2, probs = 0:4/4, w =tt$poi_0)

weighted.mean(x = tib_tx$moy_txmar, w = tib_tx$poi_0)
weighted.mean(x = tib_tx$TxMarginal_sc1, w = tib_tx$poi_0)
wtd.quantile(tib_tx$moy_txmar, probs = 0:4/4, w =tib_tx$poi_0)
wtd.quantile(tib_tx$TxMarginal_sc1, probs = 0:4/4, w =tib_tx$poi_0)

count(tib_tx, TxMarginal_sc1, wt = poi_0)/nb_foy

## diférence de revenus avant impôt entre F et H:

baseind_HF <- baseind %>% 
  select(declar1, declar2, civ, starts_with("sexe")) %>% 
  filter(civ != "" & SEXEPRMCJ != "") %>% 
  distinct() %>% 
  rename(declar = declar1)

sexe_HF <- baseind_HF %>% 
  select(declar, SEXEPRM, SEXEPRMCJ) %>% 
  distinct()

tib_rib <- impot_all %>% 
  select(ident, declar, mcdvo_sc0, poi_0, starts_with("RBG"), starts_with("RFR")) %>% 
  filter(mcdvo_sc0 %in% c("M", "O")) 
names(tib_rib)  

tib_rib <- left_join(tib_rib, sexe_HF, by = "declar") 
tib_rib <- tib_rib %>% 
  filter(SEXEPRM != "") %>% 
  mutate(sexe_eg = (SEXEPRMCJ == SEXEPRM))

wtd.mean(tib_rib$sexe_eg, w =tib_rib$poi_0)

cinq_smic_brut <- 17762/12/5
tib_rib_HF <- tib_rib %>% 
  filter(SEXEPRMCJ != SEXEPRM) %>% 
  mutate(delta_rfr = RFR1_sc0 - RFR2_sc0,
         delta_rbg = RBG_1_sc0 - RBG_2_sc0,
         coup = (delta_rbg > cinq_smic_brut)  + 2*(delta_rbg < -cinq_smic_brut),
         part_f = RBG_2_sc0 / (RBG_1_sc0 + RBG_2_sc0))

nb_mo <- sum(tib_rib_HF$poi_0)
nb_mo/nb_foy

summary(tib_rib_HF$RBG_1_sc0)
summary(tib_rib_HF$delta_rfr)
summary(tib_rib_HF$delta_rbg)

axe_x <- wtd.quantile(tib_rib_HF$delta_rbg, probs = c(0.01, 0.99), w =tib_rib_HF$poi_0)
qplot(tib_rib_HF$delta_rbg, xlim = axe_x, bins = 500)

wtd.mean(tib_rib_HF$part_f, w =tib_rib_HF$poi_0)
wtd.quantile(tib_rib_HF$part_f, probs = (1:99)/100, w =tib_rib_HF$poi_0)

count(tib_rib_HF, coup, wt = poi_0)/nb_mo



