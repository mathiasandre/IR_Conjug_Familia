/************************************************************************************/
/*																					*/
/*							Calcul de la Garantie Jeunes							*/
/*																					*/
/************************************************************************************/

/* Programme ayant pour objectif de simuler la Garantie Jeunes						*/
/* En entr�e : 	modele.baseind	                                    				*/
/* 				base.baserev                                     				    */
/*				modele.rsa															*/
/*				modele.pa															*/
/*				base.menage&anr2.													*/
/* En sortie : 	modele.base_gj	                                      				*/

/* PLAN :																			*/
/* I) On commence par pr�parer les ressources										*/
/* II) On construit ensuite l'�ligibilit�											*/
/* III) On calcule la GJ															*/
/* IV) Tirage des b�n�ficaires														*/
/* V) On cr�e modele.base_gj en sortie (on sauvegarde aussi Base_GJ_tirage, 		*/
/*	  utile parfois pour les debug)													*/
/************************************************************************************/

/************************************************************************************/
/* I) On commence par pr�parer les ressources										*/
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
/* II) On construit ensuite l'�ligibilit�											*/
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
/*Remarque : on prend impot6 car c'est l'imp�t avant cr�dits et seuil de mise en recouvrement qui est utilis�
	pour juger de l'imposabilit� (voir FPS �dition 2014). Il faudrait peut �tre ajouter � impot6 les pr�l�vements
	lib�ratoires (qui sont calcul�s � la fin du programme 6_impot).*/
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
																			  ch�mage sont inclus dans ract*/
																			  /*Remarque : les bourses d'�tude sont incluses dans la BR,
																			  mais on n'a que les bourses coll�ge/lyc�e dans Ines*/
	AutreR_GJ = SUM(OF zpiiT1-zpiiT4 asi aah caah zalri&anr2. rsa patot);

	age = &anref. - input(naia,4.);

	foyer_pa = substr(ident_pa,11,1);
	option_pa = (foyer_pa not in ("1","") and age>18 and age<25); /*option_pa permet d'identifier les jeunes qui sont sortis du foyer PA de leurs parents
																  alors qu'ils sont toujours dans le foyer RSA*/

	/*decret 2016-1855 ART D 5131-24 et ART D 5131-25 => pas de cumul avec RSA ou PA sauf (cf. infra) pour les jeunes � charges
	/*Exclusion si perception de RSA/PA :*/
	cumul_pa_rsa = (STATUT_RSA="" and rsa>0) 					/*Si le jeune touche le RSA sans �tre une personne � charge*/
				    or ( patot>0 								/*Ou si le jeune touche la PA...*/
					and (STATUT_RSA="" or option_pa=1)); 		/*...sans �tre une personne � charge au sens de la PA 
																(i.e. pas une pac au sens du RSA, et pas un foyer PA 
																exclu du foyer PA des parents)...*/
						
	/*Crit�re d'autonomie : on s'appuie sur la fiche sur la GJ du BLEX (qui semble coh�rente avec
							le Rapport final d�e�valuation de la Garantie Jeunes de J�r�me Gauti�)
					        pour identifier les jeunes autonomes en prenant 2 crit�res :
								(i)  faire partie d'un foyer fiscal non imposable (celui des parents ou pas)
								(ii) faire partie d'un foyer b�n�ficiaire du RSA (en tant que PAC, 
									 puiqu'on exclut par ailleurs ceux qui touchent le RSA sans �tre PAC)*/
	/*REMARQUES : a) En 2017 le crit�re (ii) ne sert � rien car les jeunes dans un foyer RSA sont aussi
					 dans un foyer fiscal non imposable.
				  b) Ce crit�re d'autonomie ne colle pas exactement � la description faite, par exemple, sur
					 le site service-public.fr (https://www.service-public.fr/particuliers/vosdroits/F32700)
					 o� il est indiqu� qu'il faut "soit ne pas vivre chez vos parents, soit vivre chez vos parents, 
					 mais sans recevoir d'aide financi�re de leur part." Mais le crit�re de service-pubic.fr
					 semble trop large, puisqu'il permet � un jeune qui ne vit pas chez ses parents, m�me si son m�nage
					 est tr�s riche (via les revenus de son conjoint par exemple) d'�tre �ligible (les revenus du conjoint
					 ne faisant pas partie de la base ressources si on a bien compris).*/
	autonomie = (/*(i)*/ ((impot_declar1 <= 0 OR impot_declar1 = .) AND (impot_declar2 <= 0 OR impot_declar2 = .)) OR /*(ii)*/ rsa>0);

	gj_eli = (age>15 and age<26			/*Condition d'�ge*/
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
		
		%IF &anleg. >= 2016 %THEN %DO; /*La g�n�ralisation a eu lieu en janvier 2017 mais des exp�rimentation ont lieu depuis 2013/2014 
		on prend en compte seulement depuis 2016, date � laquelle plus de la moiti� des d�partements ont mis en oeuvre des exp�rimentations (on consid�re que c'est n�gligeable avant)*/

			/*Alloc cumulable avec revenus d'activit� tant que ne d�passe pas 300 � ensuite, 
			lin�airement d�gressive et s'annule d�s que >80% smic brut annulation*/

			GJ_seuil_haut=151.67*&smich.*&GJ_plafond.;/*decret 2016-1855 ART D 5131-21*/
			GJ_seuil_bas=&GJ_seuil_cumul.;
			MR_GJ=(1-&forf_log1.)*&rsa.;
			coeffa=MR_GJ/(GJ_seuil_haut-GJ_seuil_bas); /*coeff a et b sont les param�tres de la droite correspondant au montant de GJ entre 300 euros et 0.8 SMIC de revenus d'activit�*/
			b=MR_GJ+coeffa*GJ_seuil_bas;

			/*Revenus d'activit� (mensuels) entrant dans le calcul de la GJ (i.e. apr�s abattement)*/
			IF 0 <= Ract_GJ/12 < GJ_seuil_bas THEN Ract_GJ_calc = 0;
			ELSE Ract_GJ_calc = MIN(MR_GJ, MR_GJ - (b-coeffa*(Ract_GJ/12)));
			
			gj_th = 12*MAX(0, MR_GJ - AutreR_GJ/12 - Ract_GJ_calc);

			%END;

		%ELSE %DO;
			gj = 0;
			%END;
		
		WHERE gj_eli = 1;
		RUN;

		%IF &anleg. = 2016 %THEN %DO; /*en 2016, on ne prend que les d�partements qui ont exp�riment�e la GJ*/
		PROC SQL;
			CREATE TABLE Base_GJ_th
			AS SELECT a.*, b.dep  /*on r�cup�re le d�partement*/
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
/* IV) Tirage des b�n�ficaires														*/
/************************************************************************************/

/*Le nombre de jeunes b�n�ficiaires de la GJ dans les donn�es des missions locales est beaucoup plus faible que celui 
  que l'on a dans Ines, donc on fait un tirage des b�n�ficiaires*/
/*REMARQUE : La cible du tirage est un effectif en fin d'ann�e. Comme dans le mod�le on donne � tous les b�n�ficiaires la GJ pour toute l'ann�e :
			 - On rate toutes les p�riodes de GJ avec sortie avant la fin de l'ann�e,
			 - A l'inverse pour les b�n�ficaires en fin d'ann�e, on a la GJ sur toute l'ann�e alors qu'ils ont pu entrer en cours d'ann�e,
			 -> On peut esp�rer que ces deux effets se compensent plus ou moins.*/

/*On rajoute les poids*/
PROC SQL;
	CREATE TABLE Base_GJ_tirage
	AS SELECT a.*, b.wpela&anr2.
	FROM Base_GJ_th AS a LEFT JOIN base.menage&anr2. AS b
	ON a.ident = b.ident;
	QUIT;

/*On trie la table avant le tirage des variables al�atoires pour bien toujours avoir le m�me tirage*/
PROC SORT DATA = Base_GJ_tirage; BY ident noi; RUN;

DATA Base_GJ_tirage;
	SET Base_GJ_tirage;
	proba_tirage = MIN(0.8, gj_th/(MR_GJ*12));/*On cr�e une proba de tirage d'autant plus proche de 1 que le montant th�orique de GJ est �lev�. 
												Mais on ne veut pas non plus que la proba de tirage soit 1 pour ceux qui ont le montant max (sinon
												j'ai peur qu'on ne tire que des montants max, je ne suis pas s�r que �a soit conforme � la r�alit�), 
												donc on borne � 0.8 plut�t que prendre directement gj_th/max(gj_th)*/
	alea_tri = ranuni(1989); /*On cr�e une premi�re variable choisie au hasard entre 0 et 1, qui sert juste � m�langer la table (parce qu'ensuite on va
							  s�lectionner les observations en prenant prioritairement celles qui arrivent en premier dans la table)*/
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

	/*Cas de la derni�re observation tir�e*/
	IF somme_poids >= &nb_benef_gj. AND somme_poids - wpela&anr2. < &nb_benef_gj. THEN DO;
		/*On conserve la derni�re observation tir�e seulement si le total tir� est plus proche de la cible avec elle*/
		IF somme_poids - &nb_benef_gj. > &nb_benef_gj. - (somme_poids - wpela&anr2.) THEN gj = 0;					
		END;

	RUN;


/************************************************************************************/
/* V) On cr�e modele.base_gj en sortie (on sauvegarde aussi Base_GJ_tirage, 		*/
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
� Logiciel �labor� par l��tat, via l�Insee, la Drees et la Cnaf, 2018. 

Ce logiciel est un programme informatique initialement d�velopp� par l'Insee 
et la Drees. Il permet d'ex�cuter le mod�le de microsimulation Ines, simulant 
la l�gislation sociale et fiscale fran�aise.

Ce logiciel est r�gi par la licence CeCILL V2.1 soumise au droit fran�ais et 
respectant les principes de diffusion des logiciels libres. Vous pouvez utiliser, 
modifier et/ou redistribuer ce programme sous les conditions de la licence 
CeCILL V2.1 telle que diffus�e par le CEA, le CNRS et l'Inria sur le site 
http://www.cecill.info. 

En contrepartie de l'accessibilit� au code source et des droits de copie, de 
modification et de redistribution accord�s par cette licence, il n'est offert aux 
utilisateurs qu'une garantie limit�e. Pour les m�mes raisons, seule une 
responsabilit� restreinte p�se sur l'auteur du programme, le titulaire des 
droits patrimoniaux et les conc�dants successifs.

� cet �gard l'attention de l'utilisateur est attir�e sur les risques associ�s au 
chargement, � l'utilisation, � la modification et/ou au d�veloppement et � 
la reproduction du logiciel par l'utilisateur �tant donn� sa sp�cificit� de logiciel 
libre, qui peut le rendre complexe � manipuler et qui le r�serve donc � des 
d�veloppeurs et des professionnels avertis poss�dant des connaissances 
informatiques approfondies. Les utilisateurs sont donc invit�s � charger et 
tester l'ad�quation du logiciel � leurs besoins dans des conditions permettant 
d'assurer la s�curit� de leurs syst�mes et ou de leurs donn�es et, plus 
g�n�ralement, � l'utiliser et l'exploiter dans les m�mes conditions de s�curit�.

Le fait que vous puissiez acc�der � ce pied de page signifie que vous avez pris 
connaissance de la licence CeCILL V2.1, et que vous en avez accept� les
termes.
****************************************************************/
