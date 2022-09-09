/************************************************************************************/
/*																					*/
/*							Calcul de la Garantie Jeunes							*/
/*																					*/
/************************************************************************************/

/* Programme ayant pour objectif de simuler la Garantie Jeunes						*/
/* En entrée : 	modele.baseind	                                    				*/
/* 				base.baserev                                     				    */
/*				modele.rsa															*/
/*				modele.pa															*/
/*				base.menage&anr2.													*/
/* En sortie : 	modele.base_gj	                                      				*/

/* PLAN :																			*/
/* I) On commence par préparer les ressources										*/
/* II) On construit ensuite l'éligibilité											*/
/* III) On calcule la GJ															*/
/* IV) Tirage des bénéficaires														*/
/* V) On crée modele.base_gj en sortie (on sauvegarde aussi Base_GJ_tirage, 		*/
/*	  utile parfois pour les debug)													*/
/************************************************************************************/

/************************************************************************************/
/* I) On commence par préparer les ressources										*/
/************************************************************************************/

proc sort data=modele.baseind
	(keep=ident noi ident_rsa ident_pa noiper noimer persfip naia  aah caah asi aspa statut_rsa acteu6 lprm declar1 declar2) 
	 out=baseind; by ident noi; run;

proc sort data=base.baserev
	(keep= ident noi zsali&anr2._t1-zsali&anr2._t4 zchoi&anr2._t1-zchoi&anr2._t4 
			zpii&anr2._t1-zpii&anr2._t4 zindi&anr2._t1-zindi&anr2._t4 zalri&anr2. zrtoi&anr2.) 
	 out=baserev; by ident noi; run;

proc sort data=modele.rsa  (keep= ident  rsa ident_rsa)  out=basersa; by ident;run;
proc sort data=modele.pa  (keep= ident patot  ident_pa)  out=basepa; by ident;run;

/************************************************************************************/
/* II) On construit ensuite l'éligibilité											*/
/************************************************************************************/

/*On merge toutes les tables ensemble*/
PROC SQL;
	CREATE TABLE Base_GJ_temp
	AS SELECT a.*, b.zsali&anr2._t1 AS zsaliT1, b.zsali&anr2._t2 AS zsaliT2, b.zsali&anr2._t3 AS zsaliT3, b.zsali&anr2._t4 AS zsaliT4,
				   b.zchoi&anr2._t1 AS zchoiT1, b.zchoi&anr2._t2 AS zchoiT2, b.zchoi&anr2._t3 AS zchoiT3, b.zchoi&anr2._t4 AS zchoiT4,
				   b.zpii&anr2._t1 AS zpiiT1, b.zpii&anr2._t2 AS zpiiT2, b.zpii&anr2._t3 AS zpiiT3, b.zpii&anr2._t4 AS zpiiT4,
				   b.zindi&anr2._t1 AS zindiT1, b.zindi&anr2._t2 AS zindiT2, b.zindi&anr2._t3 AS zindiT3, b.zindi&anr2._t4 AS zindiT4,
				   b.zalri&anr2.,
				   c.*, d.*
	FROM ((baseind AS a LEFT JOIN baserev AS b ON a.ident = b.ident AND a.noi = b.noi)
					    LEFT JOIN basersa AS c ON a.ident_rsa = c.ident_rsa)
						LEFT JOIN basepa AS d ON a.ident_pa = d.ident_pa;
	QUIT;

/*On veut aussi identifier les foyers fiscaux non imposables*/
/*Remarque : on prend impot6 car c'est l'impôt avant crédits et seuil de mise en recouvrement qui est utilisé
	pour juger de l'imposabilité (voir FPS édition 2014). Il faudrait peut être ajouter à impot6 les prélèvements
	libératoires (qui sont calculés à la fin du programme 6_impot).*/
PROC SQL;
	CREATE TABLE Base_GJ_th
	AS SELECT a.*, b.impot6 AS impot_declar1, c.impot6 AS impot_declar2
	FROM (Base_GJ_temp AS a LEFT JOIN modele.Impot_sur_rev&anr1. AS b ON a.declar1 = b.declar)
							LEFT JOIN modele.Impot_sur_rev&anr1. AS c ON a.declar2 = c.declar;
	QUIT;

DATA Base_GJ_th;
	SET Base_GJ_th;
	IF rsa = . THEN rsa = 0;
	IF patot = . THEN patot = 0;

	Ract_GJ = SUM(OF zsaliT1-zsaliT4, OF zindiT1-zindiT4, OF zchoiT1-zchoiT4);/*decret 2016-1855 ART D 5131-22 : les revenus du 
																			  chômage sont inclus dans ract*/
																			  /*Remarque : les bourses d'étude sont incluses dans la BR,
																			  mais on n'a que les bourses collège/lycée dans Ines*/
	AutreR_GJ = SUM(OF zpiiT1-zpiiT4 asi aah caah zalri&anr2. rsa patot);

	age = &anref. - input(naia,4.);

	foyer_pa = substr(ident_pa,11,1);
	option_pa = (foyer_pa not in ("1","") and age>18 and age<25); /*option_pa permet d'identifier les jeunes qui sont sortis du foyer PA de leurs parents
																  alors qu'ils sont toujours dans le foyer RSA*/

	/*decret 2016-1855 ART D 5131-24 et ART D 5131-25 => pas de cumul avec RSA ou PA sauf (cf. infra) pour les jeunes à charges
	/*Exclusion si perception de RSA/PA :*/
	cumul_pa_rsa = (STATUT_RSA="" and rsa>0) 					/*Si le jeune touche le RSA sans être une personne à charge*/
				    or ( patot>0 								/*Ou si le jeune touche la PA...*/
					and (STATUT_RSA="" or option_pa=1)); 		/*...sans être une personne à charge au sens de la PA 
																(i.e. pas une pac au sens du RSA, et pas un foyer PA 
																exclu du foyer PA des parents)...*/
						
	/*Critère d'autonomie : on s'appuie sur la fiche sur la GJ du BLEX (qui semble cohérente avec
							le Rapport final d’e´valuation de la Garantie Jeunes de Jérôme Gautié)
					        pour identifier les jeunes autonomes en prenant 2 critères :
								(i)  faire partie d'un foyer fiscal non imposable (celui des parents ou pas)
								(ii) faire partie d'un foyer bénéficiaire du RSA (en tant que PAC, 
									 puiqu'on exclut par ailleurs ceux qui touchent le RSA sans être PAC)*/
	/*REMARQUES : a) En 2017 le critère (ii) ne sert à rien car les jeunes dans un foyer RSA sont aussi
					 dans un foyer fiscal non imposable.
				  b) Ce critère d'autonomie ne colle pas exactement à la description faite, par exemple, sur
					 le site service-public.fr (https://www.service-public.fr/particuliers/vosdroits/F32700)
					 où il est indiqué qu'il faut "soit ne pas vivre chez vos parents, soit vivre chez vos parents, 
					 mais sans recevoir d'aide financière de leur part." Mais le critère de service-pubic.fr
					 semble trop large, puisqu'il permet à un jeune qui ne vit pas chez ses parents, même si son ménage
					 est très riche (via les revenus de son conjoint par exemple) d'être éligible (les revenus du conjoint
					 ne faisant pas partie de la base ressources si on a bien compris).*/
	autonomie = (/*(i)*/ ((impot_declar1 <= 0 OR impot_declar1 = .) AND (impot_declar2 <= 0 OR impot_declar2 = .)) OR /*(ii)*/ rsa>0);

	gj_eli = (age>15 and age<26			/*Condition d'âge*/
			  AND ACTEU6="6"			/*Pour les NEET*/
			  AND autonomie=1 			/*Pour l'exclusion du foyer parental*/  
			  AND cumul_pa_rsa=0);		/*Pour le non cumul RSA pa*/

	RUN;

/************************************************************************************/
/* III) On calcule la GJ															*/
/************************************************************************************/

%MACRO calcul_gj;

	DATA Base_GJ_th (/*KEEP = ident Ract_GJ AutreR_GJ ress_GJ_ELI foyer_pa age cumul_pa_rsa ACTEU6 autonomie option_pa GJ GJ_ELI*/);
		SET Base_GJ_th ; 
		
		%IF &anleg. >= 2016 %THEN %DO; /*La généralisation a eu lieu en janvier 2017 mais des expérimentation ont lieu depuis 2013/2014 
		on prend en compte seulement depuis 2016, date à laquelle plus de la moitié des départements ont mis en oeuvre des expérimentations (on considère que c'est négligeable avant)*/

			/*Alloc cumulable avec revenus d'activité tant que ne dépasse pas 300 € ensuite, 
			linéairement dégressive et s'annule dès que >80% smic brut annulation*/

			GJ_seuil_haut=151.67*&smich.*&GJ_plafond.;/*decret 2016-1855 ART D 5131-21*/
			GJ_seuil_bas=&GJ_seuil_cumul.;
			MR_GJ=(1-&forf_log1.)*&rsa.;
			coeffa=MR_GJ/(GJ_seuil_haut-GJ_seuil_bas); /*coeff a et b sont les paramètres de la droite correspondant au montant de GJ entre 300 euros et 0.8 SMIC de revenus d'activité*/
			b=MR_GJ+coeffa*GJ_seuil_bas;

			/*Revenus d'activité (mensuels) entrant dans le calcul de la GJ (i.e. après abattement)*/
			IF 0 <= Ract_GJ/12 < GJ_seuil_bas THEN Ract_GJ_calc = 0;
			ELSE Ract_GJ_calc = MIN(MR_GJ, MR_GJ - (b-coeffa*(Ract_GJ/12)));
			
			gj_th = 12*MAX(0, MR_GJ - AutreR_GJ/12 - Ract_GJ_calc);

			%END;

		%ELSE %DO;
			gj = 0;
			%END;
		
		WHERE gj_eli = 1;
		RUN;

		%IF &anleg. = 2016 %THEN %DO; /*en 2016, on ne prend que les départements qui ont expérimentée la GJ*/
		PROC SQL;
			CREATE TABLE Base_GJ_th
			AS SELECT a.*, b.dep  /*on récupère le département*/
			FROM Base_GJ_th AS a LEFT JOIN base.menage&anr2. AS b ON a.ident = b.ident;
			QUIT;
		PROC SQL;
			CREATE TABLE Base_GJ_th
			AS SELECT a.*, b.departement
			FROM Base_GJ_th AS a LEFT JOIN dossier.dep_gj_2016	AS b ON a.dep = b.numero_departement;
			QUIT;							 
		DATA Base_GJ_th ;
			SET Base_GJ_th ; 
			if departement='' then delete;
			drop dep departement;
			run;
			%END;

	%MEND;

%calcul_gj;

/************************************************************************************/
/* IV) Tirage des bénéficaires														*/
/************************************************************************************/

/*Le nombre de jeunes bénéficiaires de la GJ dans les données des missions locales est beaucoup plus faible que celui 
  que l'on a dans Ines, donc on fait un tirage des bénéficiaires*/
/*REMARQUE : La cible du tirage est un effectif en fin d'année. Comme dans le modèle on donne à tous les bénéficiaires la GJ pour toute l'année :
			 - On rate toutes les périodes de GJ avec sortie avant la fin de l'année,
			 - A l'inverse pour les bénéficaires en fin d'année, on a la GJ sur toute l'année alors qu'ils ont pu entrer en cours d'année,
			 -> On peut espérer que ces deux effets se compensent plus ou moins.*/

/*On rajoute les poids*/
PROC SQL;
	CREATE TABLE Base_GJ_tirage
	AS SELECT a.*, b.wpela&anr2.
	FROM Base_GJ_th AS a LEFT JOIN base.menage&anr2. AS b
	ON a.ident = b.ident;
	QUIT;

/*On trie la table avant le tirage des variables aléatoires pour bien toujours avoir le même tirage*/
PROC SORT DATA = Base_GJ_tirage; BY ident noi; RUN;

DATA Base_GJ_tirage;
	SET Base_GJ_tirage;
	proba_tirage = MIN(0.8, gj_th/(MR_GJ*12));/*On crée une proba de tirage d'autant plus proche de 1 que le montant théorique de GJ est élevé. 
												Mais on ne veut pas non plus que la proba de tirage soit 1 pour ceux qui ont le montant max (sinon
												j'ai peur qu'on ne tire que des montants max, je ne suis pas sûr que ça soit conforme à la réalité), 
												donc on borne à 0.8 plutôt que prendre directement gj_th/max(gj_th)*/
	alea_tri = ranuni(1989); /*On crée une première variable choisie au hasard entre 0 et 1, qui sert juste à mélanger la table (parce qu'ensuite on va
							  sélectionner les observations en prenant prioritairement celles qui arrivent en premier dans la table)*/
	RUN;

PROC SORT DATA = Base_GJ_tirage; BY alea_tri; RUN;

DATA Base_GJ_tirage;
	SET Base_GJ_tirage;
	alea1 = ranuni(2);
	RETAIN somme_poids;
	IF _N_ = 1 THEN somme_poids = 0;

	/*Tant qu'on n'a pas atteint la cible*/
	IF somme_poids < &nb_benef_gj. THEN DO;
		IF proba_tirage > alea1 THEN DO;
			gj = gj_th;
			somme_poids = somme_poids + wpela&anr2.;
			END;
		ELSE DO;
			gj = 0;
			END;
		END;
	ELSE DO;
		gj = 0;
		END;

	/*Cas de la dernière observation tirée*/
	IF somme_poids >= &nb_benef_gj. AND somme_poids - wpela&anr2. < &nb_benef_gj. THEN DO;
		/*On conserve la dernière observation tirée seulement si le total tiré est plus proche de la cible avec elle*/
		IF somme_poids - &nb_benef_gj. > &nb_benef_gj. - (somme_poids - wpela&anr2.) THEN gj = 0;					
		END;

	RUN;


/************************************************************************************/
/* V) On crée modele.base_gj en sortie (on sauvegarde aussi Base_GJ_tirage, 		*/
/*	  utile parfois pour les debug)													*/
/************************************************************************************/

DATA modele.base_gj;
	SET Base_GJ_tirage;
	DROP declar1 declar2 somme_poids alea_tri proba_tirage alea1 GJ_seuil_haut GJ_seuil_bas MR_GJ coeffa b;
	RUN;
DATA modele.Base_GJ_tirage;
	SET Base_GJ_tirage;
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
