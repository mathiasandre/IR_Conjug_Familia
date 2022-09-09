*************************************************************************************;
/*																					*/
/*								Calcul du RSA										*/
/*																					*/
*************************************************************************************;

/* Calcul de l'éligibilité et des montants de RSA                  	*/
/* En entrée : 	base.baserev	                                    */
/* 				modele.baseind                                      */
/*				modele.basefam										*/
/*				base.foyer&anr2.									*/
/*				base.menage&anr2.									*/
/* En sortie : 	modele.basersa                                      */

/*ATTENTION : le calcul du RSA ne sera finalisé qu'après le pgm "application_non_recours_rsa"*/
		
*************************************************************************************;
/* Plan

Partie I : calcul de la base ressources des foyers RSA à partir des revenus des différentes unités
	1. 	revenus individuels : revenus d'activité (y c trimestrialisation, cumul intégral et neutralisation des ressources) 
		et prestations individuelles;
	2. 	revenus de la famille CAF;
	3. 	revenus non individualisables des foyers fiscaux => on les attribue au déclarant 
		(et donc au foyer rsa du déclarant);
	4. 	revenus non individualisables du ménage => on les attribue à la pr du ménage ; 
	5. 	intégration des infos ressources au niveau du foyer rsa => table res_rsa et calcul 
		des bases ressources trimestrielles;

Partie II : Travail sur les foyers rsa
	1. 	récupération des infos familiales.
	2. 	construction de la table foyers rsa éligibles (âge)
	3. 	création de la table des foyers avec toutes les infos pour le calcul du rsa

Partie III : calcul du rsa
	1. 	calcul du rsa et du forfait logement théorique avant exclusion des pac ayant des 
		ressources
	2. 	Repérage des pac ayant des ressources, donc pouvant sortir du foyer rsa 
	3. 	calcul d'un rsa sans la pac en question pour les foyers concernés
	4. 	recalcul du rsa pour les foyers concernés par une exclusion
	5. 	création de la table de sortie modele.basersa */

*************************************************************************************;


*******************************************************************************************
*Partie I : calcul de la base ressources des foyers RSA à partir des ressources des 
différentes unités
*******************************************************************************************;

/*0. Mise en oeuvre dans Ines et écart à la législation
Dans la réalité les ressources d’un trimestre de référence (déclarées lors de la DTR) permettent de calculer le RSA perçu au trimestre 
suivant (de droit). Pour compenser ce décalage, le RSA possède deux mécanismes destinés à ne pas pénaliser les personnes 
sujettes à des changements de situation : le cumul intégral lors de la reprise d’activité et la neutralisation lors d'arret d'activité
Or dans Ines les droits au RSA sont calculés sur les ressources du trimestre en cours, donc trimestre de référence=de droit
Donc pas besoin de coder la neutralisation, et pour le cumul intégral on s'arrange pour retomber sur les bonnes ressources : dans le cas 
d'une reprise d’activité dans l’année, on code le cumul intégral proprement dit mais aussi le décalage trimestre de référence/droit */

/*1. LES RESSOURCES INDIVIDUELLES :
	- les revenus d'activité et de remplacement, trimestrialisés : 
	les salaires sont ensuite modifiés dans le cas d'un reprise d'activité pour permettre de conserver le bénéfice du RSA socle 
	pendant les 3, 4 ou 5 mois qui suivent une reprise d'activité comme c'est le cas dans la réalité du fait du décalage trimestre de 
	référence/droit (3 mois) et du cumul intégral (0,1 ou 2 mois suivant le mois de reprise d'activité)
	- les prestations individuelles: dont l'aah, dont il faut distinguer le titulaire si c'est 1 pac*/

proc sort data=base.baserev
	(keep= ident noi zsali&anr2._t1-zsali&anr2._t4 zchoi&anr2._t1-zchoi&anr2._t4 zrsti&anr2._t1-zrsti&anr2._t4 
				zpii&anr2._t1-zpii&anr2._t4 zindi&anr2._t1-zindi&anr2._t4
		nbmois_salt1-nbmois_salt4 zalri&anr2. zrtoi&anr2.) out=baserev; by ident noi; run;
proc sort data=modele.baseind
	(keep=ident noi cal0 aah caah asi aspa statut_rsa ident_rsa) out=baseind; by ident noi; run;

data RessTrim;
	merge 	baserev (rename= (zsali&anr2._t1=zsaliT1 zsali&anr2._t2=zsaliT2 zsali&anr2._t3=zsaliT3 zsali&anr2._t4=zsaliT4
							  zchoi&anr2._t1=zchoiT1 zchoi&anr2._t2=zchoiT2 zchoi&anr2._t3=zchoiT3 zchoi&anr2._t4=zchoiT4
							  zrsti&anr2._t1=zrstiT1 zrsti&anr2._t2=zrstiT2 zrsti&anr2._t3=zrstiT3 zrsti&anr2._t4=zrstiT4
							  zpii&anr2._t1=zpiiT1 zpii&anr2._t2=zpiiT2 zpii&anr2._t3=zpiiT3 zpii&anr2._t4=zpiiT4
							  zindi&anr2._t1=zindiT1 zindi&anr2._t2=zindiT2 zindi&anr2._t3=zindiT3 zindi&anr2._t4=zindiT4))
	       	baseind (in=a);
	by ident noi; 
	if a & ident_rsa ne '';

	/* repérage des ressources d'aah et de caah des futures pac et des civ des foyers rsa 
	(les pac aah seront exclues en II.2)*/
	%Init_Valeur(aahc_pac aahc_civ);
	if statut_rsa='pac' & aah then aahc_pac = aah+caah;
	if statut_rsa='' & aah then aahc_civ = aah+caah;


	/* CUMUL INTEGRAL: Pour conserver un décalage de 3 mois entre perception d'une nouvelle ressource et son impact sur montant de RSA.
	- Si reprise d'activité le 1er mois du trimestre de référence, alors pas de cumul intégral 
	(car le mécanisme de déclaration trimestrielle permet déjà un décalage de 3 mois entre nouvelle ressource et prise en compte pour RSA).
	- Si reprise d'activité 2ème mois du T réf, on annule les revenus pour le 1er mois du T de droits (en gros rev_T_droits=2/3*rev_T_droits).
	- Si reprise d'activité 3ème mois du T réf, on annule 2 mois de revenus pour le T de droits.

	/*repérage de la 1ère reprise d'emploi au cours de l'année et, selon, le moment où elle intervient, annulation ou diminution 
	des revenus d'activité du ou des trimestres correspondants (pour prendre en compte la DTR ET le cumul intégral)

	Nous n'avons pas décalage T réf et T droit, donc on doit seulement s'occuper de la partie qui neutralise les revenus sur le T droit.

	Repérage de la 1ère reprise d'emploi au cours de l'année et, selon, 
	le moment où elle intervient, annulation ou non des revenus d'activité du trimestre de droits. */

	/* TO DO: Introduction de la limite de 4 mois de cumul intégral par année glissante. */
	
	/* Pour les années avant la disparition du RSA activité, il faut distinguer les salaires rentrants dans la base ressource du RSA socle et du RSA activité
	car ces derniers ne peuvent pas être réduits du fait du cumul intégral ou de la neutralisation. On crée la variable zsali_soc pour le RSA socle (RSA seul depuis 2016) */
	zsali_socT1=zsaliT1 ; zsali_socT2=zsaliT2 ; zsali_socT3=zsaliT3 ; zsali_socT4=zsaliT4 ;
	
	/* A partir de 2017 le cumul intégral est supprimé */
	if &anleg.<=2016 then do; 
	/* Reprise d'activité en février, on neutralise 1 mois de salaire au T suivant. */
	if substr(cal0,11,2) in ('14','16','17','18','19') then do;
		if nbmois_salT2 = 1 then zsali_socT2=0; 
		else if nbmois_salT2 = 2 then zsali_socT2=1/2*zsaliT2;
		else if nbmois_salT2 = 3 then zsali_socT2=2/3*zsaliT2; 
		end;
		/*mars : 2 mois à enlever T2 */
	else if substr(cal0,10,2) in ('14','16','17','18','19') then do;
		if nbmois_salT2 = 3 then zsali_socT2=1/3*zsaliT2;
		else if 0<=nbmois_salT2<3 then zsali_socT2=0; 
		end;
		/*mai : comme février */
	else if substr(cal0,8,2) in ('14','16','17','18','19') then do;
		if nbmois_salT3 = 1 then zsali_socT3=0; 
		else if nbmois_salT3 = 2 then zsali_socT3=1/2*zsaliT3;
		else if nbmois_salT3 = 3 then zsali_socT3=2/3*zsaliT3; 
		end;
		/*juin : comme mars */
	else if substr(cal0,7,2) in ('14','16','17','18','19') then do;
		if nbmois_salT3 = 3 then zsali_socT3=1/3*zsaliT3;
		else if 0<=nbmois_salT3<3 then zsali_socT3=0; 
		end;
		/*aout : comme février */
	else if substr(cal0,5,2) in ('14','16','17','18','19') then do;
		if nbmois_salT4 = 1 then zsali_socT4=0; 
		else if nbmois_salT4 = 2 then zsali_socT4=1/2*zsaliT4;
		else if nbmois_salT4 = 3 then zsali_socT4=2/3*zsaliT4; 
		end;
		/*septembre : comme mars */
	else if substr(cal0,4,2) in ('14','16','17','18','19') then do;
		if nbmois_salT4 = 3 then zsali_socT4=1/3*zsaliT4;
		else if 0<=nbmois_salT4<3 then zsali_socT4=0; 
		end;
		/* Pour le T4 on ne peut pas l'appliquer car on n'a pas accès aux informations du T1 de n+1. */
	end;
	/* NEUTRALISATION: 

	Repérage de la perte de revenus au cours de l'année et neutralisation des revenus dès celle-ci.
	Pour coller à la réalité malgré notre non décalage entre T réf et T droit, on neutralise en partie les revenus du trimestre précédent,
	puis totalement les revenus du trimestre en cours (celui où la perte de revenus apparaît). Ceci permet de neutraliser entre 4 et 6 mois. 

	On repère le changement de situation, puis on applique au trimestre précédent le salaire perçu au trimestre en cours (on réduit la base ressource du RSA), 
	puis on fixe le salaire à 0 pour le trimestre en cours. */
	
	/*On sépare les cas de pertes de revenus salariés et de remplacement (chômage), en commençant par les salariés. */

	/* Pour le premier trimestre, on ne peut pas le coder entièrement car on n’a pas l'info de l'année précédente. 
	Pour janvier on ne peut pas repérer les changements de situation. */
	/* Premier trimestre, perte de revenus en février */
	if &anleg.<=2016 then do;
	if substr(cal0,11,2) in ('41','61','71','81','91') then do 
		zsali_socT1=0;
		end;
	/* Premier trimestre, perte de revenus en mars */
	else if substr(cal0,10,2) in ('41','61','71','81','91') then do 
		zsali_socT1=0;
		end;
	/* Deuxième trimestre, perte de revenus en avril */
	else if substr(cal0,9,2) in ('41','61','71','81','91') then do 
		zsali_socT1= zsaliT2;
		zsali_socT2=0;
		end;
	/* Perte de revenus en mai */
	else if substr(cal0,8,2) in ('41','61','71','81','91') then do 
		zsali_socT1= zsaliT2;
		zsali_socT2=0;
		end;
	/* Perte de revenus en juin */
	else if substr(cal0,7,2) in ('41','61','71','81','91') then do 
		zsali_socT1= zsaliT2;
		zsali_socT2=0;
		end;
	/* Troisième trimestre, perte de revenus en juillet */
	else if substr(cal0,6,2) in ('41','61','71','81','91') then do 
		zsali_socT2= zsaliT3;
		zsali_socT3=0;
		end;
	/* Perte de revenus en aout */
	else if substr(cal0,5,2) in ('41','61','71','81','91') then do 
		zsali_socT2= zsaliT3;
		zsali_socT3=0;
		end;
	/* Perte de revenus en septembre */
	else if substr(cal0,4,2) in ('41','61','71','81','91') then do 
		zsali_socT2= zsaliT3;
		zsali_socT3=0;
		end;
	/* Quatrième trimestre, perte de revenus en octobre */
	else if substr(cal0,3,2) in ('41','61','71','81','91') then do 
		zsali_socT3= zsaliT4;
		zsali_socT4=0;
		end;
	/* Perte de revenus en novembre */
	else if substr(cal0,2,2) in ('41','61','71','81','91') then do 
		zsali_socT3= zsaliT4;
		zsali_socT4=0;
		end;
	/* Perte de revenus en décembre */
	else if substr(cal0,1,2) in ('41','61','71','81','91') then do 
		zsali_socT3= zsaliT4;
		zsali_socT4=0;
		end;

	/*Perte d'allocations chômage (seul revenu de remplacement affecté).*/
	/* Premier trimestre, perte de revenus en février */
	if substr(cal0,11,2) in ('74','84','94') then do 
		zchoiT1=0;
		end;
	/* Premier trimestre, perte de revenus en mars */
	else if substr(cal0,10,2) in ('74','84','94')then do 
		zchoiT1=0;
		end;
	/* Deuxième trimestre, perte de revenus en avril */
	else if substr(cal0,9,2) in ('74','84','94') then do 
		zchoiT1= zchoiT2;
		zchoiT2=0;
		end;
	/* Perte de revenus en mai */
	else if substr(cal0,8,2) in ('74','84','94') then do 
		zchoiT1= zchoiT2;
		zchoiT2=0;
		end;
	/* Perte de revenus en juin */
	else if substr(cal0,7,2) in ('74','84','94') then do 
		zchoiT1= zchoiT2;
		zchoiT2=0;
		end;
	/* Troisième trimestre, perte de revenus en juillet */
	else if substr(cal0,6,2) in ('74','84','94') then do 
		zchoiT2= zchoiT3;
		zchoiT3=0;
		end;
	/* Perte de revenus en aout */
	else if substr(cal0,5,2) in ('74','84','94') then do 
		zchoiT2= zchoiT3;
		zchoiT3=0;
		end;
	/* Perte de revenus en septembre */
	else if substr(cal0,4,2) in ('74','84','94') then do 
		zchoiT2=zchoiT3;
		zchoiT3=0;
		end;
	/* Quatrième trimestre, perte de revenus en octobre */
	else if substr(cal0,3,2) in ('74','84','94') then do 
		zchoiT3= zchoiT4;
		zchoiT4=0;
		end;
	/* Perte de revenus en novembre */
	else if substr(cal0,2,2) in ('74','84','94') then do 
		zchoiT3=zchoiT4;
		zchoiT4=0;
		end;
	/* Perte de revenus en décembre */
	else if substr(cal0,1,2) in ('74','84','94') then do 
		zchoiT3=zchoiT4;
		zchoiT4=0;
		end;
	end;
	/* Pour le moment on ne considère pas les indépendants. */
	run;
	
/* Regroupement des revenus individuels par foyer rsa => table res_ind */
proc sort data=RessTrim; by ident_rsa; run;
proc means data=RessTrim noprint nway;
	class ident_rsa;
	var zsaliT1-zsaliT4 zsali_socT1-zsali_socT4 zchoiT1-zchoiT4 zrstiT1-zrstiT4 zpiiT1-zpiiT4 zindiT1-zindiT4
		aahc_pac aahc_civ caah asi aspa zalri&anr2. zrtoi&anr2.;
	output out=res_ind(drop=_type_ _freq_) sum=;
	run;


/*2. LES RESSOURCES DE LA FAMILLE CAF 
	- les prestations familiales + récupération de variables famille utiles (p_iso age_enf)*/

%Macro RessourcesFamille;
	data famille(drop = mpaje mois00);
		set modele.basefam(keep=ident_fam afxx0 asf_horsReval2014 paje_base droit_ab comxx majo_comxx clca pers_iso age_enf mois00);
		/* déduction des ressources familiales d'une partie de l'AB de la paje la 1ère année : 3 mois pour le RSA majoré */
		if paje_base>0 & mois00 ne '' AND pers_iso = 1 then do; 

			%if &anleg. <= 2013 %then %do ; /* Jusqu'en 2013, l'allocation de base de la PAJE est exprimée en fonction de la BMAF */
				if droit_AB='plein' then mpaje=&bmaf.*&paje_t.;
				%end ;
			%if &anleg. = 2014 %then %do ; /* A partir du 1er avril 2014, l'AB de la PAJE est gelée et surtout déconnectée de la BMAF */ 
				mpaje=((3*&bmaf_n.*&paje_t.)+(9*&paje_m.))/12; 
				/* pour les 3 premiers mois de l'année, l'AB est encore exprimée en fonction de la BMAF (valeur de celle-ci au 1er janvier).
				On fait une moyenne sur l'année, même si en pratique le montant mensuel n'est pas modifié à partir d'avril (malgré la déconnection de la Bmaf */
				mpaje_partiel=&paje_m_partiel.; /* Pas de moyenne sur l'année car le montant partiel ne concerne que les enfants nés à partir du 1er avril */
			%end ;
			%if &anleg. >= 2015 %then %do ; 
				if droit_AB='plein' then mpaje=&paje_m.; 
				if droit_AB='partiel' then mpaje=&paje_m_partiel.;
				%end ;

			if mois00='11' then  paje_base=paje_base - mpaje; 
			else if mois00='10' then  paje_base=paje_base - 2*mpaje; 
			else paje_base=paje_base - 3*mpaje; 
			end;


		%if &anleg.<2004 %then %do;
			paje_base=0; /*on supprimait toute l'aide avant 2004*/
			%end;
		run;
	%Mend RessourcesFamille;
%RessourcesFamille;

/*récupération du numéro ident_rsa de baseind pour le mettre dans la table famille (création de la table lien ident_fam<=>ident_rsa)*/
proc sort data=famille nodupkey; by ident_fam;
proc sort data=modele.baseind(keep=ident_fam ident_rsa) out=lien nodupkey; by ident_fam; run;
data famille;
	merge famille (in=a) lien;
	comxx=comxx-majo_comxx;/* on enlève la majoration du complément familial de la base ressources (si pas de majorations alors majo_comxx=0) */
	by ident_fam;
	if a;
	run;
/* somme des ressources familiales par foyer rsa => table res_fam */
proc sort data=famille; by ident_rsa; run;
proc means data=famille noprint nway;
	class ident_rsa;
	var afxx0 asf_horsReval2014 paje_base comxx clca;
	output out=res_fam(drop=_type_ _freq_) sum=;
	run;


/*3. LES RESSOURCES DU FOYER FISCAL
	- toutes les ressources non individualisables du foyer (ressources de l'année simulée)
	HYPOTHESE : on les attribue au déclarant du foyer fiscal, donc à son foyer rsa*/

data foyer(keep=ident noi declar zvalf zetrf zvamf zfonf zracf separation);
	set base.foyer&anr2.;
	/* omission dans les agrégats des foyers des revenus imputés par ailleurs à leurs ménages
	et qui seront comptabilisés à l'étape 4 */
	zvamf=sum(0,zvamf,-_2ch,-_2fu);
	zvalf=zvalf-max(0,_2dh);
	/* repérage des divorces ou ruptures de pacs dans l'année pour simuler du RSA majoré */
	separation=(xyz='Y');
	run;
/* récupération du numéro ident_rsa de baseind pour le mettre dans la table foyer*/
proc sort data=foyer; by ident noi;
proc sort data=modele.baseind; by ident noi; run;
data foyer;
	merge 	foyer (in=a) 	
			modele.baseind (keep=ident noi ident_rsa);
	by ident noi;
	if a;
	run;
/* somme des ressources du foyer fiscal par foyer rsa => table res_foy*/
proc sort data=foyer; by ident_rsa; run;
proc means data=foyer noprint nway;
	class ident_rsa;
	var zracf zfonf zetrf zvamf zvalf separation;
	output out=res_foy(drop=_type_ _freq_) sum=;
	run;


/*4. LES RESSOURCES DU MENAGE 
	- les produits financiers imputés au ménage l'année simulée :
	En théorie, il faut prendre en compte dans la BR du rsa 
	les revenus du capital (lorsqu'ils sont déclarés) et à défaut 3% (par an, soit 0,75% par trimestre) du capital détenu
	(y compris l'épargne disponible, type livret A et l'épargne non placée, type compte courant).
	cela n'étant pas possible, on utilise les revenus des produits financiers imputés aux ménages par RPM.
	HYPOTHESE : on les attribue à la personne de référence du ménage, donc à son foyer rsa*/

proc sort data=base.menage&anr2.; by ident; run;
proc sort data=modele.baseind; by ident; run;
data prodfin;
	merge 	modele.baseind (in=a) 
			base.menage&anr2. (keep=ident produitfin_i);
	by ident;
	if a;
	if lprm='1' then prodfin=produitfin_i;
	else prodfin=0;
	run;
/* somme des ressources du ménage par foyer rsa => table res_men*/
proc means data=prodfin noprint nway;
	class ident_rsa;
	var prodfin;
	output out=res_men(drop=_type_ _freq_) sum=;
	run;


/*5. CONSTRUCTION DE LA BR DU RSA A PARTIR DES 4 ORIGINES DES RESSOURCES
	- création de la table res_rsa qui regroupe les ressources au niveau du foyer rsa
	- calcul des bases ressources trimestrielles*/

proc sort data=res_ind; by ident_rsa;
proc sort data=res_fam; by ident_rsa;
proc sort data=res_foy; by ident_rsa; 
proc sort data=res_men; by ident_rsa; run;
data res_rsa;
	merge 	res_ind (in=a) 
			res_fam 
			res_foy 
			res_men;
	by ident_rsa;
	if a ;
	array num _numeric_; do over num; if num=. then num=0; end;

	/* calcul des revenus d'activité pris en compte chaque trimestre dans la base ressources du rsa */
	rce1_rsa1=sum(0,zsaliT1,zindiT1);
	rce1_rsa2=sum(0,zsaliT2,zindiT2);
	rce1_rsa3=sum(0,zsaliT3,zindiT3);
	rce1_rsa4=sum(0,zsaliT4,zindiT4);

	rce1_soc_rsa1=sum(0,zsali_socT1,zindiT1);
	rce1_soc_rsa2=sum(0,zsali_socT2,zindiT2);
	rce1_soc_rsa3=sum(0,zsali_socT3,zindiT3);
	rce1_soc_rsa4=sum(0,zsali_socT4,zindiT4);

	/* TO DO : logiquement il faudrait aussi appliquer le cumul intégral sur le revenu d'activité des indépendants.. */


	/* calcul de toutes les autres ressources prises en compte chaque trimestre : les 
	revenus du chômage et de la retraite sont considérés par trimestre et les autres 
	ressources sont lissées sur l'année en divisant par 4.
	Pour l'aah et le caah, on ne retient pas celui des pac, qui seront exclues du foyer 
	dans la partie III*/
	rce2_rsa1=max(0,sum(0,zchoiT1,zrstiT1,zpiiT1)+
		1/4*sum(0,zrtoi&anr2.,zalri&anr2.,zracf,zfonf,zvamf,zetrf,zvalf,prodfin,
				clca,afxx0,paje_base,comxx,asf_horsReval2014,aahc_civ,asi,aspa));
	rce2_rsa2=max(0,sum(0,zchoiT2,zrstiT2,zpiiT2)+
		1/4*sum(0,zrtoi&anr2.,zalri&anr2.,zracf,zfonf,zvamf,zetrf,zvalf,prodfin,
				clca,afxx0,paje_base,comxx,asf_horsReval2014,aahc_civ,asi,aspa));
	rce2_rsa3=max(0,sum(0,zchoiT3,zrstiT3,zpiiT3)+
		1/4*sum(0,zrtoi&anr2.,zalri&anr2.,zracf,zfonf,zvamf,zetrf,zvalf,prodfin,
				clca,afxx0,paje_base,comxx,asf_horsReval2014,aahc_civ,asi,aspa));
	rce2_rsa4=max(0,sum(0,zchoiT4,zrstiT4,zpiiT4)+
		1/4*sum(0,zrtoi&anr2.,zalri&anr2.,zracf,zfonf,zvamf,zetrf,zvalf,prodfin,
				clca,afxx0,paje_base,comxx,asf_horsReval2014,aahc_civ,asi,aspa));
	run; 


/**************************************
Partie II : CREATION DE LA TABLE FOYERS_RSA
**************************************/

/* 1. construction d'une table de foyers rsa à partir de la table famille */
proc sort data=famille; by ident_rsa ident_fam;run; 
data foyer_rsa (keep=ident_rsa ident_fam age_enf pers_iso); 
	set famille;  
	by ident_rsa ident_fam;
	if first.ident_rsa; 
	run; 
/*PB : dans les cas où 2 familles composent un foyer rsa, on ne prend les infos que d'une famille */

/*2. construction d'une table de foyers rsa à partir des individus de baseind en deux temps
	- décompte des adultes et des personnes à charge par foyer (hors pac aah)
	- construction de la table foyers en ne gardant que les foyers éligibles de par leur âge 
	ou la présence d'enfant*/
proc sort data=modele.baseind; by ident_rsa; run;
data nb_pac; 
	set modele.baseind (keep=ident wpela&anr2. noi ident_rsa ident_fam noicon noienf01 naia quelfic 
			statut_rsa aah acteu6 in=a where=(ident_rsa ne ''));
	by ident_rsa;
	/* on enlève les pac aah de la table individuelle servant à fabriquer les foyers rsa*/
	if statut_rsa='pac' & aah then delete;
	retain pac nbciv agemax_foyer etud_ou_pac par_iso nbenf; 
	if first.ident_rsa then do; pac=0; nbciv=0; agemax_foyer=0; etud_ou_pac=0; par_iso=0; nbenf=0; end;
	if statut_rsa='pac' then pac=pac+1;
	else nbciv=nbciv+1;
	/* astuces pour déterminer l'éligibilité de chaque foyer à partir de l'âge ou la présence d'enfant à charge :
	- on crée une variable agemax_foyer donnant l'âge de la personne la plus âgée du foyer
	- on compte dans le foyer le nombre de pacs et d'étudiants (sans double compte)
	- on repère les parents isolés (ils sont éligibles au RSA même s'ils sont étudiants et jeunes) */
	agemax_foyer=max(agemax_foyer,&anref.-input(naia,4.));
	etud_ou_pac=etud_ou_pac+(acteu6='5' or statut_rsa='pac');
	par_iso=par_iso+(noicon='' and noienf01 ne '');
	nbenf=nbenf+(noienf01 ne '');
	run;

proc sort data=nb_pac; by ident_rsa; run;
data pac; 
	set nb_pac(where = (agemax_foyer>=&age_rsa_l. or nbenf ne 0)); /* on ne garde pas les foyers trop jeunes, sauf s'ils sont jeunes parents */
	by ident_rsa;
	if (etud_ou_pac = nbciv+pac) and (par_iso ne 0) then delete;  /* on enlève les foyers composés uniquement d'étudiants, sauf s'ils sont parents isolés*/
	/*Écart à la législation : on n'inclut pas les jeunes ayant travaillé deux années sur les trois dernières années
	ni ceux en stages rémunérés, alors qu'ils sont normalement éligibles au RSA même en ne respectant pas la condition d'âge*/
	if last.ident_rsa; 
	run; 

/*3. fusion des 3 tables de niveau foyer rsa constituées jusqu'à maintenant */
data rsa1;
	merge 	res_rsa 
			foyer_rsa 
			pac(in=a keep=ident_rsa pac nbciv wpela&anr2.);
	by ident_rsa; 
	if a; 
	run;


/***************************
*Partie III : calcul du rsa
***************************/

/*1. calcul du rsa en incluant toutes les pac du foyer (certaines seront exclues plus tard)
	- a. calcul du montant forfaitaire et du forfait logement théorique pour toutes les configuations
	- b. calcul du rsa et du rsa socle */

%macro Calcul_RSA(nbciv,pac,m_rsa,m_rsa_socle);
	nb_foyer=&nbciv.+&pac.; 
	if nb_foyer=1 then do; 
		rsa=&rsa.; 
		FL_theorique=&rsa.*&forf_log1.; end;
	if nb_foyer=2 then do; 
		rsa=&rsa.*(1+&rsa2.); 
		FL_theorique=&rsa.*(1+&rsa2.)*&forf_log2.; end;
	if nb_foyer>2 then do; 
		rsa=&rsa.*(1+&rsa2.+&rsa3.*(nb_foyer-2)+ &rsa4.*(&pac-2)*(&pac>2)); 
		FL_theorique=&rsa.*(1+&rsa2.+&rsa3.)*&forf_log3.; end;
	rsa_noel=&rmi_noel.*rsa/&rsa.;
	/* éligibilité et application du rsa majoré et ses législations antérieures (api) */
	%nb_enf(enf03,0,3,age_enf);
	%nb_enf(e_c,0,&age_pf.,age_enf);
	if (enf03>0 & pers_iso=1) ! (e_c>0 & separation>0) then do;
		/* RSA majoré */
		rsa=(&mrsa1.+&pac*&mrsa2.)*&rsa.;
		/* API */
		%if &anleg.<2007 %then %do;
			FL_theorique = &bmaf.*	(&forf_log_api1.*(e_c=0) 
								+ &forf_log_api2.*(e_c=1) 
								+ &forf_log_api2.*(e_c>1));
			%end;
		%if &anleg.<2009 %then %do;
			rsa=(&mapi1.+e_c*&mapi2.)*&bmaf.;
			%end;
		end;
	/*b. calul du rsa et du rsa socle sans tenir compte du forfait logement
	mise à 0 des montants de prestation trimestriels et vectorisation*/
	&m_rsa.1=0; &m_rsa.2=0; &m_rsa.3=0; &m_rsa.4=0;
	&m_rsa_socle.1=0; &m_rsa_socle.2=0; &m_rsa_socle.3=0; &m_rsa_socle.4=0;
	array rce1_rsa rce1_rsa1-rce1_rsa4;
	array rce1_soc_rsa rce1_soc_rsa1-rce1_soc_rsa4;
	array rce2_rsa rce2_rsa1-rce2_rsa4;
	array &m_rsa &m_rsa.1-&m_rsa.4;
	array &m_rsa_socle &m_rsa_socle.1-&m_rsa_socle.4;
	/* calcul par trimestre */
	do over &m_rsa;

		&m_rsa_socle = max(0, 3*(rsa) - rce1_soc_rsa - rce2_rsa) ; /* avec salaires abattus dans la BR */

		/* pour le droit au RSA activité, on considère le revenu réel et non celui neutralisé pour le RSA socle */
		/* le calcul du RSA total sera différent selon que les ressources se situent en deça ou au delà du MF du RSA */

		if rce1_rsa + rce2_rsa < 3*(rsa)  /* ressources (avant neutralisation) inférieures au MF */ 
			then &m_rsa = &trsa.*rce1_rsa + &m_rsa_socle  ; 
		else if rce1_rsa + rce2_rsa >= 3*(rsa) /* ressources supérieures au MF */ 
			then &m_rsa = max(0, 3*(rsa) - (1-&trsa.)*rce1_rsa - rce2_rsa) + &m_rsa_socle ; 
			/* à noter que dans ce cas, si le ménage touche du RSA socle, les ressources hors revenus d'activité sont comptées 2 fois 
				(comme pour la PA) */

		/* TO DO : il faudrait inclure le forfait logement dans la base ressources, ce qui n'est pas possible ici puisque
			le FL est calculé après le bloc AL. Celà supposerait de faire comme avec la PA, cad calculer ici le RSA socle
			et dans un 2ème temps (après les AL), le RSA activité et total */

		%if &anleg.<2009 or &anleg.>= 2016  %then %do; /*pas de RSA activité*/
			&m_rsa=&m_rsa_socle;
			%end;
		end;

	%if &anleg.=2009 %then %do;
		m_rsa1=m_rsa_socle1;
		m_rsa2=m_rsa_socle2+(m_rsa2-m_rsa_socle2)/3; /* Le RSA est distribué à partir du mois de juin */
		%end;
	%mend Calcul_RSA;

data rsa1; 
	set rsa1;
	/*a. calcul du montant forfaitaire du rsa, du forfait logement et de la prime de noel */
	%Calcul_RSA(nbciv,pac,m_rsa,m_rsa_socle);
	/*création d'une variable rsa annuel qui sera utilisée seulement à l'étape 3 pour déterminer l'éventuelle exclusion de pac*/
	rsa_an = sum(0,of m_rsa1-m_rsa4);
	run;


/*2. Repérage des pac qui peuvent sortir du foyer rsa : pac de 20 à 25 ans avec des ressources personnelles*/
proc sort data=RessTrim; by ident noi;
proc sort data=nb_pac; by ident noi;
data exclu; 
	merge RessTrim nb_pac;
	by ident noi;
	if ident_rsa ne '' & statut_rsa='pac' & (&anref.-input(naia,4.)>=&age_pl.);
	/* dès une pac ayant des ressources personnelles au moins 1 trimestre, elle est excluable*/
	%macro Exclusion_Potentielle;
		%do i=1 %to 4; 
			if  sum(0,zsaliT&i.,zindiT&i.,zchoiT&i.,zrstiT&i.,zpiiT&i.,
					1/4*sum(0,zrtoi&anr2.,zalri&anr2.,asi))>0 
				then pot_excluT&i.=1;
			else pot_excluT&i.=0; %end; 
		%mend Exclusion_Potentielle;
	%Exclusion_Potentielle;
	run; 

/*3. Calcul du rsa pour les foyers concernés par une exclusion potentielle
- HYPOTHESE : une seule exclusion par foyer : dans le cas d'exclusions multiples, on garde la plus avantageuse pour le foyer*/
proc sort data=exclu; by ident_rsa noi; run;
data exclusion; 
	merge	exclu (in=a)
			rsa1(keep= ident_rsa m_rsa: rce1: rce2: pac nbciv age_enf pers_iso rsa_an separation);
	by ident_rsa;
	if a;
	if pot_excluT1 = 1 ! pot_excluT2 = 1 ! pot_excluT3 = 1 ! pot_excluT4 = 1 then do;
		/* calcul des ressources du foyer en otant les ressources personnelles de la pac*/
		rce1_rsa1 = rce1_rsa1-sum(0,zsaliT1,zindiT1);	
		rce1_rsa2 = rce1_rsa2-sum(0,zsaliT2,zindiT2);
		rce1_rsa3 = rce1_rsa3-sum(0,zsaliT3,zindiT3);
		rce1_rsa4 = rce1_rsa4-sum(0,zsaliT4,zindiT4);
		rce1_soc_rsa1 = rce1_soc_rsa1-sum(0,zsali_socT1,zindiT1);	
		rce1_soc_rsa2 = rce1_soc_rsa2-sum(0,zsali_socT2,zindiT2);
		rce1_soc_rsa3 = rce1_soc_rsa3-sum(0,zsali_socT3,zindiT3);
		rce1_soc_rsa4 = rce1_soc_rsa4-sum(0,zsali_socT4,zindiT4);
		rce2_rsa1 = rce2_rsa1-(asi+zalri&anr2.+zrtoi&anr2.)/4;
		rce2_rsa2 = rce2_rsa2-(asi+zalri&anr2.+zrtoi&anr2.)/4;
		rce2_rsa3 = rce2_rsa3-(asi+zalri&anr2.+zrtoi&anr2.)/4;
		rce2_rsa4 = rce2_rsa4-(asi+zalri&anr2.+zrtoi&anr2.)/4;
		/*calcul du rsa du foyer si la pac était exclue du foyer*/
		%Calcul_RSA(nbciv,pac-1,m_rsa_exclu,m_rsasocl_exclu);
		rsa_exclu_an = sum(0,of m_rsa_exclu1-m_rsa_exclu4);
		/*comparaison du rsa du foyer avec et sans la pac : si le rsa sans la pac est plus élevé, on on fixe exclu à 1*/
		exclu=(rsa_exclu_an > rsa_an); 
		end;
	if exclu;
	run;
proc sql;
	create table optim as
	select distinct *
	from exclusion
	group by ident_rsa
	having rsa_exclu_an=max(rsa_exclu_an);
	quit;

/*4. recalcul du rsa pour les foyers concernés par une exclusion*/
proc sort data=rsa1;by ident_rsa;run;
data rsa2; 
	merge 	rsa1(in=a) 
			optim; 
	by ident_rsa; 
	if a;
	/*on affecte aux foyers qui perdent une pac les montants de rsa trimestriels calculés après son exclusion en on enlève une pac */
	if exclu then do; 
		m_rsa_socle1=m_rsasocl_exclu1; 
		m_rsa_socle2=m_rsasocl_exclu2;
		m_rsa_socle3=m_rsasocl_exclu3; 
		m_rsa_socle4=m_rsasocl_exclu4;
		m_rsa1=m_rsa_exclu1; 
		m_rsa2=m_rsa_exclu2;
		m_rsa3=m_rsa_exclu3; 
		m_rsa4=m_rsa_exclu4;
		pac=pac-1;
	end;
	/* Repérage des foyers potentiellement concernés par le cumul intégral */
	cum_int1=(rce1_rsa1 ne rce1_soc_rsa1) ;
	cum_int2=(rce1_rsa2 ne rce1_soc_rsa2) ;
	cum_int3=(rce1_rsa3 ne rce1_soc_rsa3) ;
	cum_int4=(rce1_rsa4 ne rce1_soc_rsa4) ;
	length cum_int $4 ; cum_int = compress(cum_int1 !! cum_int2 !! cum_int3 !! cum_int4);

	run;

/*5. création de la table de sortie modele.basersa*/
data modele.basersa;
	set rsa2(keep=ident_rsa m_rsa1-m_rsa4 m_rsa_socle1-m_rsa_socle4 FL_theorique rsa_noel enf03 pers_iso e_c separation wpela&anr2. rsa cum_int
		rename=(m_rsa1-m_rsa4 = m_rsa_th1-m_rsa_th4 m_rsa_socle1-m_rsa_socle4 = m_rsa_socle_th1-m_rsa_socle_th4 rsa=rsa_forf)); 
	format ident $8.;
	ident=substr(ident_rsa,1,8);
	label	m_rsa_th1='montant de RSA theorique au T1 avant calcul du FL'
			m_rsa_th2='montant de RSA theorique au T2 avant calcul du FL'
			m_rsa_th3='montant de RSA theorique au T3 avant calcul du FL'
			m_rsa_th4='montant de RSA theorique au T4 avant calcul du FL'
			m_rsa_socle_th1='montant de RSA socle theorique au T1 avant calcul du FL'
			m_rsa_socle_th2='montant de RSA socle theorique au T2 avant calcul du FL'
			m_rsa_socle_th3='montant de RSA socle theorique au T3 avant calcul du FL'
			m_rsa_socle_th4='montant de RSA socle theorique au T4 avant calcul du FL'
			rsa_forf='Montant forfaitaire du RSA'
			cum_int='foyer potentiellement concerné par le cumul intégral de T1 à T4'
			FL_theorique='forfait logement theorique avant calcul des AL'
			rsa_noel='prime de Noel du RSA'
			enf03='enfants de moins de 3 ans dans le foyer'
			pers_iso='pas de conjoint'
			e_c='enfants à charge dans le foyer'
			separation='une separation conjugale au sens fiscal est intervenue cette annee';
	run;


/****************************************************************
© Logiciel élaboré par l’État, via l’Insee, la Drees et la Cnaf, 2018. 

Ce logiciel est un programme informatique initialement développé par l'Insee 
et la Drees. Il permet d'exécuter le modèle de microsimulation Ines, simulant 
la législation sociale et fiscale française.

Ce logiciel est régi par la licence CeCILL V2.1 soumise au droit français et 
respectant les principes de diffusion des logiciels libres. Vous pouvez utiliser, 
modifier et/ou redistribuer ce programme sous les conditions de la licence 
CeCILL V2.1 telle que diffusée par le CEA, le CNRS et l'Inria sur le site 
http://www.cecill.info. 

En contrepartie de l'accessibilité au code source et des droits de copie, de 
modification et de redistribution accordés par cette licence, il n'est offert aux 
utilisateurs qu'une garantie limitée. Pour les mêmes raisons, seule une 
responsabilité restreinte pèse sur l'auteur du programme, le titulaire des 
droits patrimoniaux et les concédants successifs.

À cet égard l'attention de l'utilisateur est attirée sur les risques associés au 
chargement, à l'utilisation, à la modification et/ou au développement et à 
la reproduction du logiciel par l'utilisateur étant donné sa spécificité de logiciel 
libre, qui peut le rendre complexe à manipuler et qui le réserve donc à des 
développeurs et des professionnels avertis possédant des connaissances 
informatiques approfondies. Les utilisateurs sont donc invités à charger et 
tester l'adéquation du logiciel à leurs besoins dans des conditions permettant 
d'assurer la sécurité de leurs systèmes et ou de leurs données et, plus 
généralement, à l'utiliser et l'exploiter dans les mêmes conditions de sécurité.

Le fait que vous puissiez accéder à ce pied de page signifie que vous avez pris 
connaissance de la licence CeCILL V2.1, et que vous en avez accepté les
termes.
****************************************************************/
