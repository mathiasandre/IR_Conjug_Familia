###################################################
# Prédiction éligibilité ASS par forêts aléatoires
###################################################

# En entrée : ass_anr&anref._anleg&anleg..csv
# En sortie : tirage_ass_anr&anref._anleg&anleg..csv

# Plan : 
# 1. Packages, anref, anleg et chemin de sortie
# 2. Préparation données
# 3. Sélection du ntree qui donne le meilleur modèle (on teste 20 ntrees, de 500 à 10000)
# 4. Application du modèle avec le ntree optimal sur l'ensemble de l'échantillon
# 5. Prédiction sur l'échantillon des non observés
# 6. Export de la table avec les ident noi et les probas d'être à l'ASS

# 1. Packages, anref, anleg et chemin de sortie
anref <- 2015
anleg <- 2017
anl<-as.numeric(substr(anleg,3,4))

install.packages('randomForest', repos='http://cran.rstudio.com/')
library(randomForest)

# 2. Préparation données
ass<-read.csv(paste('ass_anr',anref,'_anleg', anleg, '.csv', sep=''), sep=';')
chemin_ass <- as.character(ass[1,'chemin_ass'])
ass_mod<-ass[which(ass[,'ass'] != 'NA'), ]
ass_pred<-ass[which(is.na(ass[,'ass']) == T), ]
# 2 bis. Préparation des données d'entraînement du modèle
alea<-runif(nrow(ass_mod))
ass_mod<-cbind(ass_mod,alea)
ass_train<-ass_mod[which(ass_mod[,'alea']>0.3),]
ass_control<-ass_mod[which(ass_mod[,'alea']<=0.3),]
ass_mod<-ass_mod[,-ncol(ass_pred)-1]

# 3. Sélection du ntree qui donne le meilleur modèle (on teste 20 ntrees, de 500 à 10000)
# Possible de passer cette étape en choisissant manuellement le nombre d'arbres ntree_opt (ex : ntree_opt <- 1000)
RES<-matrix(0,nrow=20,ncol=1)
for (i in seq(500, 10000, 500)){
      # Grâce à la table ass_train, on calibre un modèle randomforest en fonction d'un ntree i
      assign(paste("modele_randomforest",i/500,sep=''),randomForest(as.factor(ass)~couple+chom_mens+age+age2+nbmois_sal+duree_ss_emploi+
                                                            pas_diplome+sexe+nbmois_cho+nbmoischo_ant, 
                                                          data=ass_train, ntree=i))
      # On teste maintenant la qualité de ce modèle sur la table ass_control, pour cela
      # on prend comme prédiction non l'appartenance à une classe '1' ou '0' mais la probabilité
      # d'appartenir à la classe '1' (donc d'être à l'ASS) afin de pouvoir contrôler le nombre de
      # bénéficiaires que l'on tirera ensuite en fonction de nos cibles. D'où le type='prob'.
      pred_rf<-predict(get(paste("modele_randomforest",i/500,sep='')),ass_control, type='prob')
      
      # On veut minimiser diff_rf qui compte les "faux 1" (erreur plus gênante que les "faux 0") 
      assign(paste("diff_rf",i/500,sep=''), 
             sum((pred_rf[,2]- ass_control$ass)^2*(pred_rf[,2]- ass_control$ass>0))/nrow(ass_control))
      RES[i/500,1] <- get(paste("diff_rf",i/500,sep=''))
      remove(list=paste("modele_randomforest",i/500,sep=''))
      remove(list=paste("diff_rf",i/500,sep=''))
      }
# Au sein de tous les modèles que l'on a fait tourner, on choisit le ntree de celui minimisant l'erreur
ntree_opt<-as.numeric(which(RES[,1]==min(RES[,1])))*500

# plot(RES[,1])

# 4. Application du modèle avec le ntree optimal sur l'ensemble de l'échantillon
modele_randomforest <- randomForest(as.factor(ass)~couple+chom_mens+age+age2+nbmois_sal+duree_ss_emploi+
                                      pas_diplome+sexe+nbmois_cho+nbmoischo_ant, 
                                    data=ass_mod, ntree=ntree_opt)

print(modele_randomforest)
importance(modele_randomforest)

# 5. Prédiction sur l'échantillon des non observés
# Hypothèse : On ne touche pas aux observations dont on connaît l'observé
# (alors qu'on pourrait aussi leur appliquer le modèle de prédiction)
pred_ass<- predict(modele_randomforest, ass_pred, type='prob')
ass_pred[,'ass']<-pred_ass[,2]
ass_proba<-rbind(ass_pred,ass_mod)[c('ass','ident','noi',paste('wpela',anl,sep=''))]
names(ass_proba)[1]<-"proba_ass"
ass_proba$ident<-as.character(ass_proba$ident)
ass_proba$noi<-as.character(ass_proba$noi)

# 6. Export de la table avec les ident noi et les probas d'être à l'ASS
write.table(ass_proba, paste(chemin_ass,"/tirage_ass_anr",anref,"_anleg", anleg, ".csv",sep=''),
            row.names=F, col.names=T, sep=";")

#str(ass_proba1<-ass_proba[which(ass_proba[,'proba_ass']>=1),])

