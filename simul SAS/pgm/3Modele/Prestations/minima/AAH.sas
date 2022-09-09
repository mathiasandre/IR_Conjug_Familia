/************************************************************************/
/*																		*/
/*								AAH										*/
/*																		*/
/************************************************************************/

/* Modélisation de l'AAH    											*/
/* En entrée : 	modele.baseind 											*/
/*				travail.cal_indiv										*/
/*				base.baserev											*/
/*				modele.basefam 											*/
/*				base.foyer&anr.											*/
/* En sortie : 	modele.baseind                                     		*/
/*																		*/
/* Plan																	*/
/* 	I - Construction d'une base individuelle sur les handicapés et		*/
/*		leurs ressources 												*/ 
/* 	II - Construction de la base ressources	et calcul des abattements	*/
/* 	III - Calcul de l'AAH												*/
/* 	IV - Sauvegarde des montants d'AAH dans modele.baseind				*/

/************************************************************************/
/* 	I - Construction d'une base individuelle sur les handicapés et		*/
/*		leurs ressources 												*/ 
/************************************************************************/

PROC SQL;
	CREATE TABLE handicapes_1
	AS SELECT a.ident, a.noi, a.noicon, a.naia, a.handicap, a.quelfic, a.aspa, a.asi, a.cal0, a.nbmois_sal,
			  a.declar1, a.declar2, a.elig_aspa_asi, a.ident_fam,
			  b.zsali&anr., SUM(zragi&anr., zrici&anr., zrnci&anr.) AS zindi&anr., 
			  b.zchoi&anr., b.zrtoi&anr., b.zalri&anr., b.zrsti&anr., b.zpii&anr.,
			  MAX(0,b.zsali&anr2.*(1-&Tcsgi.)/a.nbmois_sal) AS salnet_mens,
			  b.zchoi&anr2.*(1-&Tcsgchi.) AS chomage_net, a.persfip1, a.persfip2,
			  /*RQ: le fait de prendre &anr2 plutôt que &anr pour le salaire net et le chômage net 
			  est hérité de la précédente version du programme, mais je ne sais pas trop pourquoi on fait ça,
			  peut-être parce que pour les gens qui travaillent en milieu ordinaire est trimestrielle et pas
			  basée sur les revenus n-2*/
			  c.cal_tp&anref.
	FROM (modele.baseind AS a LEFT JOIN base.baserev AS b ON a.ident = b.ident AND a.noi = b.noi) 
	LEFT JOIN travail.cal_indiv AS c
	ON a.ident = c.ident AND a.noi = c.noi
	WHERE handicap NE 0 AND quelfic NOT IN ('FIP','EE_NRT') AND enf_1 NE 1;
	QUIT;

/*Ajout des ressources individuelles et autres infos du conjoint*/
PROC SQL;
	CREATE TABLE handicapes_2
	AS SELECT a.*,
			  b.zsali&anr. AS zsali&anr._conj, 
			  SUM(zragi&anr., zrici&anr., zrnci&anr.) AS zindi&anr._conj, 
			  b.zchoi&anr. AS zchoi&anr._conj, b.zrtoi&anr. AS zrtoi&anr._conj,
			  b.zalri&anr. AS zalri&anr._conj, b.zrsti&anr. AS zrsti&anr._conj, 
			  b.zpii&anr. AS zpii&anr._conj, 
			  c.declar1 AS declar1_conj, c.declar2 AS declar2_conj, c.naia AS naia_conj, c.persfip1 AS persfip1_conj, c.persfip2 AS persfip2_conj,
			  c.elig_aspa_asi AS elig_aspa_asi_conj, c.handicap AS handicap_conj
	FROM (handicapes_1 AS a LEFT JOIN base.baserev AS b ON a.ident = b.ident AND a.noicon = b.noi)
		 LEFT JOIN modele.baseind AS c ON a.ident = c.ident AND a.noicon = c.noi;
	QUIT;

/*On rajoute les ressources non individualisables de la BR, en prenant toutes les déclarations fiscales de
	l'handicapé et de son conjoint éventuel (il peut y en avoir plusieurs si décès en cours d'année, ou
	si les deux conjoints n'ont pas la même déclaration).*/
/*On va chercher dans modele.rbg&anr., pour tenir compte des abattements caculés dans cette base et qui doivent être inclus dans la BR 
	de l'AAH*/

PROC SQL;
	CREATE TABLE handicapes_3
	AS SELECT a.*, 
	b.RV AS RV_declar1, b.rev2 AS rev2_declar1, b._PVCessionDom AS _PVCessionDom_declar1, b._3vm AS _3vm_declar1,
	b._3vt AS _3vt_declar1, b._PVCession_entrepreneur AS _PVCess_entr_declar1,
	b.RevCessValMob_PostAbatt AS RCVM_PAb_declar1, b.RevCessValMob_Abatt AS RCVM_Ab_declar1,
	b._3vi AS _3vi_declar1, b._3vf AS _3vf_declar1, b._3vd AS _3vd_declar1, b._3vz AS _3vz_declar1, b._2ee AS _2ee_declar1,
	b._2dh AS _2dh_declar1, b._2fa AS _2fa_declar1, b.rev4_caf AS rev4_caf_declar1, b._6gh AS _6gh_declar1, b._8tm AS _8tm_declar1,
	c.RV AS RV_declar2, c.rev2 AS rev2_declar2, c._PVCessionDom AS _PVCessionDom_declar2, c._3vm AS _3vm_declar2,
	c._3vt AS _3vt_declar2, c._PVCession_entrepreneur AS _PVCess_entr_declar2,
	c.RevCessValMob_PostAbatt AS RCVM_PAb_declar2, c.RevCessValMob_Abatt AS RCVM_Ab_declar2,
	c._3vi AS _3vi_declar2, c._3vf AS _3vf_declar2, c._3vd AS _3vd_declar2, c._3vz AS _3vz_declar2, c._2ee AS _2ee_declar2,
	c._2dh AS _2dh_declar2, c._2fa AS _2fa_declar2, c.rev4_caf AS rev4_caf_declar2, c._6gh AS _6gh_declar2, c._8tm AS _8tm_declar2,
	d.RV AS RV_declar1_conj, d.rev2 AS rev2_declar1_conj, d._PVCessionDom AS _PVCessionDom_declar1_conj, d._3vm AS _3vm_declar1_conj,
	d._3vt AS _3vt_declar1_conj, d._PVCession_entrepreneur AS _PVCess_entr_declar1_conj,
	d.RevCessValMob_PostAbatt AS RCVM_PAb_declar1_conj, d.RevCessValMob_Abatt AS RCVM_Ab_declar1_conj,
	d._3vi AS _3vi_declar1_conj, d._3vf AS _3vf_declar1_conj, d._3vd AS _3vd_declar1_conj, d._3vz AS _3vz_declar1_conj, d._2ee AS _2ee_declar1_conj,
	d._2dh AS _2dh_declar1_conj, d._2fa AS _2fa_declar1_conj, d.rev4_caf AS rev4_caf_declar1_conj, d._6gh AS _6gh_declar1_conj, d._8tm AS _8tm_declar1_conj,
	e.RV AS RV_declar2_conj, e.rev2 AS rev2_declar2_conj, e._PVCessionDom AS _PVCessionDom_declar2_conj, e._3vm AS _3vm_declar2_conj,
	e._3vt AS _3vt_declar2_conj, e._PVCession_entrepreneur AS _PVCess_entr_declar2_conj,
	e.RevCessValMob_PostAbatt AS RCVM_PAb_declar2_conj, e.RevCessValMob_Abatt AS RCVM_Ab_declar2_conj,
	e._3vi AS _3vi_declar2_conj, e._3vf AS _3vf_declar2_conj, e._3vd AS _3vd_declar2_conj, e._3vz AS _3vz_declar2_conj, e._2ee AS _2ee_declar2_conj,
	e._2dh AS _2dh_declar2_conj, e._2fa AS _2fa_declar2_conj, e.rev4_caf AS rev4_caf_declar2_conj, e._6gh AS _6gh_declar2_conj, e._8tm AS _8tm_declar2_conj
	FROM ((((handicapes_2 AS a 
		LEFT JOIN modele.rbg&anr. AS b ON a.declar1 = b.declar)
		LEFT JOIN modele.rbg&anr. AS c ON a.declar2 = c.declar)
		LEFT JOIN modele.rbg&anr. AS d ON (a.declar1_conj = d.declar AND a.declar1_conj NE a.declar1 AND a.declar1_conj NE a.declar2))
		LEFT JOIN modele.rbg&anr. AS e ON (a.declar2_conj = e.declar AND a.declar2_conj NE a.declar1 AND a.declar2_conj NE a.declar2)); /*Cette dernière condition est sûrement inutile 
																																		car si le conjoint a 2 déclarations je ne pense
																																		pas que la personne handicapée peut en avoir 2*/
/*Remarque : Ici on ne garde que les valeurs pour le conjoint lorsque la déclaration du conjoint n'est pas une des déclarations de la personne 
		handicapée, pour ensuite faire la somme et ne pas comptabiliser deux fois les valeurs si le conjoint est sur une déclaration fiscale de 
		la personne handicapée*/
	QUIT;

DATA handicapes_3;
	SET handicapes_3;
	ressources_non_indiv = SUM(RV_declar1, rev2_declar1, _PVCessionDom_declar1, _3vm_declar1, _3vt_declar1,
							   _PVCess_entr_declar1, RCVM_PAb_declar1, RCVM_Ab_declar1,
							   _3vi_declar1, _3vf_declar1, _3vd_declar1, _3vz_declar1, _2ee_declar1, _2dh_declar1,
							   _2fa_declar1, rev4_caf_declar1, _6gh_declar1, _8tm_declar1,
							   RV_declar2, rev2_declar2, _PVCessionDom_declar2, _3vm_declar2, _3vt_declar2,
							   _PVCess_entr_declar2, RCVM_PAb_declar2, RCVM_Ab_declar2,
							   _3vi_declar2, _3vf_declar2, _3vd_declar2, _3vz_declar2, _2ee_declar2, _2dh_declar2,
							   _2fa_declar2, rev4_caf_declar2, _6gh_declar2, _8tm_declar2,
 							   RV_declar1_conj, rev2_declar1_conj, _PVCessionDom_declar1_conj, _3vm_declar1_conj, _3vt_declar1_conj,
							   _PVCess_entr_declar1_conj, RCVM_PAb_declar1_conj, RCVM_Ab_declar1_conj,
							   _3vi_declar1_conj, _3vf_declar1_conj, _3vd_declar1_conj, _3vz_declar1_conj, _2ee_declar1_conj, _2dh_declar1_conj,
							   _2fa_declar1_conj, rev4_caf_declar1_conj, _6gh_declar1_conj, _8tm_declar1_conj,
 							   RV_declar2_conj, rev2_declar2_conj, _PVCessionDom_declar2_conj, _3vm_declar2_conj, _3vt_declar2_conj,
							   _PVCess_entr_declar2_conj, RCVM_PAb_declar2_conj, RCVM_Ab_declar2_conj,
							   _3vi_declar2_conj, _3vf_declar2_conj, _3vd_declar2_conj, _3vz_declar2_conj, _2ee_declar2_conj, _2dh_declar2_conj,
							   _2fa_declar2_conj, rev4_caf_declar2_conj, _6gh_declar2_conj, _8tm_declar2_conj);
	RUN;

/*Enfin, on va aussi chercher les variables abatt et deduc dans modele.rbg&anr., car ces abattements sont parfois appliqués dans la BR de l'AAH*/
/*On récupère aussi revind, qui remplacera zindi pour les conjoints, car il inclut des abattements qu'on veut avoir dans la BR pour les conjoints*/
PROC SQL;
	CREATE TABLE handicapes_4
	AS SELECT a.*,
			  b.abatt1 AS abatt1_declar1, b.abatt2 AS abatt2_declar1, b.abatt3 AS abatt3_declar1, b.abatt4 AS abatt4_declar1, b.abatt5 AS abatt5_declar1,
			  c.abatt1 AS abatt1_declar2, c.abatt2 AS abatt2_declar2, c.abatt3 AS abatt3_declar2, c.abatt4 AS abatt4_declar2, c.abatt5 AS abatt5_declar2,
			  d.abatt1 AS abatt1_declar1_conj, d.abatt2 AS abatt2_declar1_conj, d.abatt3 AS abatt3_declar1_conj, d.abatt4 AS abatt4_declar1_conj, d.abatt5 AS abatt5_declar1_conj,
			  e.abatt1 AS abatt1_declar2_conj, e.abatt2 AS abatt2_declar2_conj, e.abatt3 AS abatt3_declar2_conj, e.abatt4 AS abatt4_declar2_conj, e.abatt5 AS abatt5_declar2_conj,
			  b.deduc1 AS deduc1_declar1, b.deduc2 AS deduc2_declar1, b.deduc3 AS deduc3_declar1, b.deduc4 AS deduc4_declar1, b.deduc5 AS deduc5_declar1,
			  c.deduc1 AS deduc1_declar2, c.deduc2 AS deduc2_declar2, c.deduc3 AS deduc3_declar2, c.deduc4 AS deduc4_declar2, c.deduc5 AS deduc5_declar2,
			  d.deduc1 AS deduc1_declar1_conj, d.deduc2 AS deduc2_declar1_conj, d.deduc3 AS deduc3_declar1_conj, d.deduc4 AS deduc4_declar1_conj, d.deduc5 AS deduc5_declar1_conj,
			  e.deduc1 AS deduc1_declar2_conj, e.deduc2 AS deduc2_declar2_conj, e.deduc3 AS deduc3_declar2_conj, e.deduc4 AS deduc4_declar2_conj, e.deduc5 AS deduc5_declar2_conj,
			  b.revind1 AS revind1_declar1, b.revind2 AS revind2_declar1, b.revind3 AS revind3_declar1, b.revind4 AS revind4_declar1, 
			  c.revind1 AS revind1_declar2, c.revind2 AS revind2_declar2, c.revind3 AS revind3_declar2, c.revind4 AS revind4_declar2, 
			  d.revind1 AS revind1_declar1_conj, d.revind2 AS revind2_declar1_conj, d.revind3 AS revind3_declar1_conj, d.revind4 AS revind4_declar1_conj, 
			  e.revind1 AS revind1_declar2_conj, e.revind2 AS revind2_declar2_conj, e.revind3 AS revind3_declar2_conj, e.revind4 AS revind4_declar2_conj
	FROM ((((handicapes_3 AS a 
		LEFT JOIN modele.rbg&anr. AS b ON a.declar1 = b.declar)
		LEFT JOIN modele.rbg&anr. AS c ON a.declar2 = c.declar)
		LEFT JOIN modele.rbg&anr. AS d ON a.declar1_conj = d.declar)
		LEFT JOIN modele.rbg&anr. AS e ON a.declar2_conj = e.declar);
	QUIT;

DATA handicapes_4;
	SET handicapes_4;
	abatt = 	  SUM((persfip1 = "decl")*abatt1_declar1, (persfip1 = "conj")*abatt2_declar1, 
				  	  (persfip1 = "p1")*abatt3_declar1, (persfip1 = "p2")*abatt4_declar1, 
				  	  (persfip1 = "p3")*abatt5_declar1, 
				  	  (persfip2 = "decl")*abatt1_declar2, (persfip2 = "conj")*abatt2_declar2, 
				  	  (persfip2 = "p1")*abatt3_declar2, (persfip2 = "p2")*abatt4_declar2, 
				 	  (persfip2 = "p3")*abatt5_declar2);
	abatt_conj =  SUM((persfip1_conj = "decl")*abatt1_declar1_conj, (persfip1_conj = "conj")*abatt2_declar1_conj, 
				 	  (persfip1_conj = "p1")*abatt3_declar1_conj, (persfip1_conj = "p2")*abatt4_declar1_conj, 
				 	  (persfip1_conj = "p3")*abatt5_declar1_conj, 
				 	  (persfip2_conj = "decl")*abatt1_declar2_conj, (persfip2_conj = "conj")*abatt2_declar2_conj, 
				 	  (persfip2_conj = "p1")*abatt3_declar2_conj, (persfip2_conj = "p2")*abatt4_declar2_conj, 
				 	  (persfip2_conj = "p3")*abatt5_declar2_conj);
	deduc = 	  SUM((persfip1 = "decl")*deduc1_declar1, (persfip1 = "conj")*deduc2_declar1, 
				 	  (persfip1 = "p1")*deduc3_declar1, (persfip1 = "p2")*deduc4_declar1, 
				 	  (persfip1 = "p3")*deduc5_declar1, 
				 	  (persfip2 = "decl")*deduc1_declar2, (persfip2 = "conj")*deduc2_declar2, 
				 	  (persfip2 = "p1")*deduc3_declar2, (persfip2 = "p2")*deduc4_declar2, 
				 	  (persfip2 = "p3")*deduc5_declar2);
	deduc_conj =  SUM((persfip1_conj = "decl")*deduc1_declar1_conj, (persfip1_conj = "conj")*deduc2_declar1_conj, 
				 	  (persfip1_conj = "p1")*deduc3_declar1_conj, (persfip1_conj = "p2")*deduc4_declar1_conj, 
				 	  (persfip1_conj = "p3")*deduc5_declar1_conj, 
				 	  (persfip2_conj = "decl")*deduc1_declar2_conj, (persfip2_conj = "conj")*deduc2_declar2_conj, 
				 	  (persfip2_conj = "p1")*deduc3_declar2_conj, (persfip2_conj = "p2")*deduc4_declar2_conj, 
				 	  (persfip2_conj = "p3")*deduc5_declar2_conj);
	revind_conj = SUM((persfip1_conj = "decl")*revind1_declar1_conj, (persfip1_conj = "conj")*revind2_declar1_conj, 
				 	  (persfip1_conj = "p1")*revind3_declar1_conj, (persfip1_conj = "p2")*revind4_declar1_conj, 
				 	  (persfip2_conj = "decl")*revind1_declar2_conj, (persfip2_conj = "conj")*revind2_declar2_conj, 
				 	  (persfip2_conj = "p1")*revind3_declar2_conj, (persfip2_conj = "p2")*revind4_declar2_conj);
	RUN;

/*Création de la variable elig_aah*/

DATA handicapes_4;
	SET handicapes_4;
	LENGTH elig_aah $8.;
	IF noicon NE '' AND handicap_conj NE 0 THEN elig_aah = 'Bi AAH';
	ELSE elig_aah = 'Mono AAH';
	RUN;

/************************************************************************/
/* 	II - Construction de la base ressources	et calcul des abattements	*/
/************************************************************************/

DATA handicapes_BR;
	SET handicapes_4;

	%Init_Valeur(nbmois_abat nbh_avant nbh_apres reduc);

	/*1) Base ressources avant les abattements*/
	res_aah_avant_abatt = SUM(zsali&anr., zindi&anr., zchoi&anr., zrtoi&anr., zalri&anr., 
							  zsali&anr._conj, revind_conj, zchoi&anr._conj, zrtoi&anr._conj, zalri&anr._conj,
							  zrsti&anr._conj, zpii&anr._conj,
							  (persfip1 IN ('decl' 'conj'))*ressources_non_indiv /*On ne met les ressources non individualisables que pour la PH ou son conjoint
							  														pour conserver ce qui est fait dans l'ancien programme, ça pourrait être utile
							  														de vérifier que c'est bien ce qu'il faut faire*/
							  ); 


	/*RQ : Les pensions de retraite taxables en capital à 7,5 % sont inclues dans la BR de l'AAH dans Ines, mais je ne suis pas sûr
	que ça soit le cas dans la réalité car elles ne sont pas incluses dans le revenu qui sert à déterminer l'impôt*/ 

	/*2) Calcul des abattements*/

	/* A. Abattement de 20 % appliqué aux pensions et rentes viagères à titre gratuit perçues par l'allocataire,
		et aux revenus perçus par le conjoint*/
	abat_20 = MAX(0,0.2*SUM(zalri&anr., zsali&anr._conj, zindi&anr._conj, zchoi&anr._conj, zrtoi&anr._conj,
					zalri&anr._conj, zrsti&anr._conj, zpii&anr._conj));

	/*on ne sait pas identifier les rentes viagères à titre gratuit, qui sont déclarées
	dans la même case que les retraites. On pourrait dire que cette case correspond uniquement
	à des rentes viagères à titre gratuit quand l'individu n'est pas retraité dans l'enquête emploi. Mais la
	variable qui permettrait de faire ça dans l'enquête emploi n'est plus posée qu'en première 
	et dernière interrogation depuis 2013 donc elle ne permet pas d'identifier proprement les retraités. Du coup 
	on ne comptabilise pas les rentes viagères à titre gratuit dans l'abattement (elles ne sont d'ailleurs
	pas non plus incluses dans la base ressource au début, s'il y en a elles sont dans zrsti et elles seront déduites
	du montant d'AAH à la fin, c'est plutôt défavorable aux bénéficiaires d'AAH par rapport à la réalité)*/

	/* B. On simule ici 4 abattements sur les revenus d'activité en place à partir de 2011 :  */

	/* REMARQUES IMPORTANTES :
		- Dans la législation ces abattements ne s'appliquent qu'aux handicapés travaillant en milieu ordinaire, dans Ines on
		  les applique à tous les handicapés qui travaillent.
		- On n'applique aparemment pas ces abattements aux revenus des indépendants (en particulier, l'abattement
		  80/40 s'appuie sur salnet_mens, calculé au début du programme en partnat de zsali, donc pas pour les revenus des 
		  indépendants), je pense qu'il faudrait le faire.
		- Écart à la législation : Depuis 2011, l'examen des ressources des bénéficiaires AAH touchant des revenus
		  d'activité est réalisé sur une base trimestrielle : ça n'est pas le cas dans Ines */
 
	/* a) Cumul intégral sur 6 mois après une reprise d'emploi 
	   b) Cumul partiel ("abattement 80/40") pour tous les revenus salariaux du bénéficiaire en dehors du cumul intégral  */
	if  find(substr(cal0,1,11),"1") ne 0 and substr(cal0,12,1) ne "1" then do; /* On repère les reprises d'emploi en cours d'année */
		abat_salaire_ab=min(nbmois_sal,6)*salnet_mens*(&seuil_abat. ne 0) /* cumul intégral sur 6 mois. L'indicatrice seuil_abat ne 0 permet de ne pas appliquer le cumul avant anleg=2011*/
		+ &tx_abat1.*max(0,nbmois_sal-6)*(min(salnet_mens,&seuil_abat.*&b_smica./12)) /* au delà des 6 mois de salaire cumulées, 80% d'abattement sur la part en dessous de 0,3 smic brut... */
		+ &tx_abat2.*max(0,nbmois_sal-6)*(max(salnet_mens-&seuil_abat.*&b_smica./12,0)); /*...et 40% d'abattement au delà de 0,3 smic brut */
		end;
	else do; /* Pour les salariés qui ne sont pas en reprise d'emploi, on applique l'abattement 80/40 sur tout leur salaire */
		abat_salaire_ab=&tx_abat1.*nbmois_sal*(min(salnet_mens,&seuil_abat.*&b_smica./12))
		+&tx_abat2.*nbmois_sal*(max(salnet_mens-&seuil_abat.*&b_smica./12,0));
		end;
	abat_salaire_ab = MAX(0, abat_salaire_ab);

	/* c) Abattement pour réduction quotité travail. Pour repérer une telle baisse,
	 	on utilise ici cal_tp qui donne le nombre d'heures hebdomadaires travaillées
		sur une semaine de référence par mois. Attention : un cal_tp renseigné sur un mois
		ne signifie pas que la personne a travaillé tout le mois (pas comparable à nbmois_sal) */

	do i=0 to 10; /* une boucle sur les 12 mois de l'année */
		/* on corrige les valeurs manquantes */
		if input(substr(cal_tp&anref.,i*2+1,2),2.) =. then substr(cal_tp&anref.,i*2+1,2) ='00';
		if input(substr(cal_tp&anref.,(i+1)*2+1,2),2.) =. then substr(cal_tp&anref.,(i+1)*2+1,2) ='00';
		/* 1er cas : 1er mois où on constate une baisse de la quotité */
		if input(substr(cal_tp&anref.,i*2+1,2),2.)>input(substr(cal_tp&anref.,(i+1)*2+1,2),2.)>0 and reduc=0 then do;
			nbmois_abat=nbmois_abat+1; /* nbmois_abat ne sert que parce qu'il faut que la réduction concerne au moins deux mois consécutifs*/
			/* nbh_avant et nbh_apres permettent ensuite d'observer l'ampleur de la réduction du tps de travail */
			nbh_avant=input(substr(cal_tp&anref.,i*2+1,2),2.);
			nbh_apres=input(substr(cal_tp&anref.,(i+1)*2+1,2),2.);
			reduc=1; /* il y a eu une réduction de temps de travail dans l'année */
			end;
		/* 2e cas : la quotité de travail avait déja baissé auparavant mais elle remonte */
		else if 0<input(substr(cal_tp&anref.,i*2+1,2),2.)<input(substr(cal_tp&anref.,(i+1)*2+1,2),2.) and reduc=1 then do;
			reduc=0;
			if nbmois_abat<2 then nbmois_abat=0;
			end;
		/* 3e cas : la quotité de travail avait déja baissé auparavant et elle est confirmée */
		else if input(substr(cal_tp&anref.,i*2+1,2),2.)>=input(substr(cal_tp&anref.,(i+1)*2+1,2),2.) and reduc=1 then do;
			nbmois_abat=nbmois_abat+1;	
			end;
		end;
	drop i;
	/* on calcule maintenant l'abattement à proprement parler. Écart à la législation : si il y a deux réductions du temps de travail
	le code n'en prend en compte qu'une seule pour calculer l'ampleur de la réduction de la quotité de travail (mais prend bien en 
	compte le nb de mois total durant lequel il y a eu des réductions). */
	/* on applique l'abattement au nombre de mois durant lesquels le salaire n'a pas baissé, majoré par 3. En effet, dans une évaluation
	trimestrielle des ressources qui est censée s'appliquer dans ce cas, l'abattement n'aurait eu lieu que sur 3 mois maximum. */
	if nbh_avant>0 then prop_reduc=(nbh_avant-nbh_apres)/nbh_avant; 
	else prop_reduc=0;
	/* l'abattement est égal au pourcentage de réduction du temps de travail arrondi à la dizaine inférieure et de 80% max */
	/*Remarque : il arrive que l'abattement soit négatif car nbmois_sal-nbmois_abat est négatif, en raison 
	d'incohérences entre cal_tp (à partir duquel est calculé nbmois_abat) et nbmois_sal. Du coup on rajoute un max entre
	0 et le calcul de l'abattement pour éviter d'avoir des abattements négatifs*/
	abat_salaire_c=max(0,min(&tx_abat3.,floor(prop_reduc*10)/10)*salnet_mens*min(3,nbmois_sal-nbmois_abat)*(nbmois_abat>=2));

	/* d) Abattement de 30% appliqué : 
		- aux revenus d'activité en cas de chômage total ou partiel */
	if  find(substr(cal0,1,12),"14") ne 0 then do;
		abat_salaire_d1	= MAX(0,&tx_abat4.*salnet_mens*nbmois_sal);
		end;
	/* - aux revenus d'activité et de chômage en cas d'arrêt du travail pour invalidité ou vieillesse */
	if  find(substr(cal0,1,12),"15") ne 0 or find(substr(cal0,1,12),"18") ne 0 then do;
		abat_salaire_d2	= MAX(0,&tx_abat4.*salnet_mens*nbmois_sal);
		abat_chomage	= MAX(0,&tx_abat4.*chomage_net);
		end;

	/* C. On rajoute les abattements calculés dans 1_rbg.sas sur certaines ressources, et qui doivent aussi être pris
		en compte dans la base ressources de l'AAH : Déduction de 10 % sur les pensions, retraites et rentes et pensions 
		alimentaires reçues (en l'occurrence seulement les pensions alimentaires) */
	abat_10 = MAX(0, SUM(abatt_conj, deduc_conj));

	/*IMPRECISIONS :
		- On ne met pas 'abatt' pour la personne handicapée (abattement sur retraites, pensions d'invalidité, pensions alimentaires) :
		  -> pour retraites et pensions d'invalidité c'est voulu, comme l'AAH vient en complément de ces prestations je ne pense pas
			 qu'il faille tenir compte de l'abattement.
		  -> pour les pensions alimentaires de la personne handicapée, je pense qu'il faudrait tenir compte de l'abattement, 
			 mais il n'existe pas dans Ines un abattement portant seulement sur les pensions alimentaires (abatt est un abattement global 
			 sur l'agrégat PRB dans 1_rbg.sas), et je ne sais même pas comment ça peut être calculé dans la réalité par les administrations...
		- On n'inclut pas d'abattement pour les revenus des indépendants des personnes handicapées -> c'est normal, 
		     ce sont des revenus d'activité donc ce sont les  abattements spécifiques (80/40, etc.) qui s'appliquent, 
		     mais comme par ailleurs on n'applique pas ces abattements spécifiques aux
		     revenus des indépendants, ils sont au total "sous-abattus".
		     Pour les revenus des indépendants du conjoint, ils sont abattus cas on a pris revind_conj plutôt que
			 zindi dans la BR*/

	/* C. Abattement sur les rentes viagères à titre onéreux*/
	abat_RV = MIN(&plafRV, zrtoi&anr.);
	/* REMARQUE :
		- Il y a aussi des abattements appliqués aux rentes viagères dans 1_rbg.sas, dont on ne tient pas compte ici*/

	res_aah = MAX(0, SUM(res_aah_avant_abatt, - abat_20,
									  		  - abat_salaire_ab,
									  		  - abat_salaire_c,
									  		  - abat_salaire_d1,
									  		  - abat_salaire_d2,
									  		  - abat_chomage,
											  - abat_10
											  - abat_RV));

	RUN;

/************************************************************************/
/* 	III - Calcul de l'AAH												*/
/************************************************************************/

/*On va chercher les infos sur la famille nécessaires au calcul de l'AAH*/
PROC SQL;
	CREATE TABLE aah
	AS SELECT a.*, b.age_enf, b.pers_iso
	FROM handicapes_BR AS a LEFT JOIN modele.basefam AS b
	ON a.ident_fam = b.ident_fam;
	QUIT;

DATA aah;
	SET aah;
	IF pers_iso = . THEN pers_iso = 0;
	%nb_enf(e_c,0,&age_pf.,age_enf); 
	aah = 0;

	IF res_aah < &aah_plf.*(2-pers_iso+0.5*e_c) THEN DO; /*plafond doublé pour un couple i.e. si pers_iso=0*/
		aah = MIN(&aah_mont.,&aah_plf.*(2-pers_iso+0.5*e_c)-res_aah);

		/*L'AAH vient compléter l'ASI, l'ASPA, les pensions d'invalidité ou de retraite*/
		aah = MAX(0, SUM(aah, -asi, -aspa, -zrsti&anr., -zpii&anr.));

		IF aah = 0 THEN aah_taux='';
		ELSE IF aah >=&aah_mont. THEN aah_taux='p';
		ELSE aah_taux='r';;

		END; 

	caah = 0;

	LABEL	aah = "Allocation de l'adulte handicapé"
			caah = "Compléments d'AAH";

	RUN;

/************************************************************************/
/* 	IV - Sauvegarde des montants d'AAH dans modele.baseind				*/
/************************************************************************/

PROC SORT DATA = aah; BY ident noi; RUN; 
PROC SORT DATA = modele.baseind; BY ident noi; RUN; 

DATA modele.baseind;
	MERGE 	modele.baseind 
			aah (IN=a keep=ident noi aah caah aah_taux);
	BY ident noi;
	IF NOT a THEN DO; 
		aah = 0;
		caah = 0;
		aah_taux = '';
		END; 
	RUN;


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


