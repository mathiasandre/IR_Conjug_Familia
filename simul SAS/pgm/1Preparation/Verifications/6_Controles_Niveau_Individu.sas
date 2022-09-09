/************************************************************************************/
/*																					*/
/*							6_Controles_niveau_individu								*/
/*																					*/
/************************************************************************************/

/* Vérifications au niveau des individus sur les variables noi, ident, naia, persfip et declar 
   ainsi que sur les revenus contenus dans les tables indivi et indfip.				*/ 
/************************************************************************************/
/* En entrée : 	travail.indivi&anr. 				                                */
/* 				travail.irf&anr.e&anr. 				                                */
/* 				travail.indfip&anr. 				                                */
/************************************************************************************/
/* PLAN : 																			*/
/* 0. Préparation table avec tous les individus, yc les FIP 						*/
/* 1. Cohérence entre les declar, le persfip, ident et noi (A&M)					*/
/* 2. Cohérence d'évènement entre declar1 et declar2 (M)							*/
/* 3. Cohérence entre declar et naia (M&A)											*/
/* 4. Cohérence entre les variables persfip et persfipd	(A&M)						*/
/* 5. Cohérence des revenus imputés													*/
/* 6. Controle des ident, noi et poids négatifs	(M)									*/
/************************************************************************************/
/* Remarque : 																		*/
/* - A indique que la correction est automatique dans les pgms de corrections 		*/
/* - M indique un traitement manuel à faire (par exemple modifier un declar)		*/
/************************************************************************************/


/************************************************************************************/
/* 0. Préparation table avec tous les individus, yc les FIP 						*/
/************************************************************************************/
proc sql;
	create table tous_les_individus as
		select a.*, b.naia, b.sexe
		from travail.indivi&anr. as a 
		inner join travail.irf&anr.e&anr. as b 
		on a.ident=b.ident and a.noi=b.noi
		outer union corr 
		select * from travail.indfip&anr. ;
	quit;


/************************************************************************************/
/* 1. Cohérence entre les declar, le persfip, ident et noi (A&M)					*/
/************************************************************************************/
data pb_persfip_declar;
	set tous_les_individus(keep=ident noi noindiv wp: persfip quelfic declar1 declar2 naia);
	if quelfic in ('EE&FIP','FIP')  then do; 
		if substr(declar1,4,8) ne ident then output;	/* correspondance declar et ident */
		if declar2 ne '' & substr(declar2,4,8) ne ident then output;
		if persfip in ('vous','vopa')					/* correspondance declar et noi (A)*/
			& noi ne substr(declar1,1,2)
			& noi ne substr(declar2,1,2) then output;
		if  persfip not in ('vous','vopa') & declar2='' & noi=substr(declar1,1,2) then output;
	 	if  persfip='conj'								/* présence de conj uniquement sur des déclarations de mariés/pacsés */
			& substr(declar1,13,1) not in('M','O')
			& substr(declar2,13,1) not in('M','O') then output;
		if  persfip='pac'								/* présence de pac uniquement si le declar contient des pac */
			& substr(declar1,30,1) not in ('F' 'G' 'H' 'I' 'J' 'N' 'R') then output;
		end; 
	run;
/*	ERFS 2010 : 61 cas (problèmes de cohérence entre declar et noi);
	ERFS 2011 : 49 cas
	ERFS 2012 : 52 cas : 26 pb de cohérence declar/noi de déclarants dont 25 FIP avec noi=71 et 26 pb de cohérence declar/noi de conjoints
	ERFS 2013 : 0 cas 
	ERFS 2014 : 656 cas avant corrections ; 0 cas après 
	ERFS 2015 :
	ERFS 2016 : 0 cas après correction */

/************************************************************************************/
/* 2. Cohérence d'évènement entre declar1 et declar2 (M)							*/
/************************************************************************************/
/* Exemple d'erreur : gens déclarant être divorcés alors qu'en réalité ils sont veufs */
data pb_even_declar;
	set tous_les_individus(keep=ident noi noindiv wp: persfip quelfic declar1 declar2);
	where quelfic in ('EE&FIP','FIP') & declar2 ne '' & substr(declar1,24,3) ne substr(declar2,24,3);
	run;
/*	ERFS 2009 : reste une erreur normale car on ne sait pas comment la corriger
	ERFS 2010 : 27 cas
	ERFS 2011 : 10 cas
	ERFS 2012 : 0 cas
	ERFS 2013 : 1 cas normal (enfant de 18 ans qui se met à faire sa déclaration tout seul et dont le parent était divorcé dans l'année) 
	ERFS 2014 : 1 cas normal (enfant de 18 ans qui se met à faire sa déclaration tout seul et dont le parent était divorcé dans l'année) 
				+ 2 cas (1 seul foyer fiscal) avec 1 mariage et un décès (mariage pas renseigné dans declar1). On ne corrige pas car ce qui importe = veuf sur la déclaration la plus récente */
				/* TODO : vérification demandée sur ce choix de ne pas corriger (en lien avec macro %standard_foyer où X prime en cas de double déclaration) 
	ERFS 2015 : 1 cas normal (enfant de 18 ans qui se met à faire sa déclaration tout seul et dont le parent était divorcé dans l'année) 
				+ 2 cas (1 seul foyer fiscal) comme l'an dernier 2014 ;
	ERFS 2016 : 0 cas*/

/************************************************************************************/
/* 3. Cohérence entre declar et naia (M&A)											*/
/************************************************************************************/
/* Les années de naissance doivent être cohérentes : pas de personne de plus de 110 ans ni de déclarant mineur (M), 
	les mariages avec les mineurs sont à examiner et les années de naissance des fichiers fiscaux doivent 
	correspondre aux années de naissance de l'enquête emploi (naia) */
data pb_anfip pb_naia;
	set tous_les_individus (keep=ident noi noindiv wp: persfip quelfic declar1 declar2 naia);
	if quelfic in ('EE&FIP','FIP') then do;
		anfip1_d1 = put(substr(declar1,14,4),4.); /* Année de naissance du déclarant */
		anfip2_d1 = put(substr(declar1,19,4),4.); /* Année de naissance du conjoint  */
		if declar2 ne '' then do;				  /* Même chose pour declar2 si échéant */
			anfip1_d2 = put(substr(declar2,14,4),4.);
			anfip2_d2 = put(substr(declar2,19,4),4.);
			end;
		if input(anfip1_d1,4.)<1900 
		or  input(anfip1_d1,4.)>&anref.-18
		or  (input(anfip2_d1,4.) ne 9999 & (input(anfip2_d1,4.)<1900 or input(anfip2_d1,4.)>&anref.-18) )
		or  (declar2 ne '' & (input(anfip1_d2,4.)<1900 or input(anfip1_d2,4.)>20&anr1.))
		or  (declar2 ne '' & (input(anfip2_d2,4.) ne 9999 & (input(anfip2_d2,4.)<1900 or input(anfip2_d2,4.)>&anref.-18)) )
		or  (persfip='vous' & input(anfip1_d1,4.) ne input(naia,4.))
		or  (persfip='conj' & input(anfip2_d1,4.) ne input(naia,4.)) then output pb_anfip;
		end;
	if naia='' ! input(naia,4.)>%eval(&anref.+1) ! input(naia,4.)<%eval(&anref.-110) then output pb_naia ;
	run;
/*	ERFS 2009 : pas de pb sur naia seul
	ERFS 2009 : 5 cas d'adultes se marient avec une personne de 15 ou 16 ans
	ERFS 2009 : 936 incohérences entre naia de l'EE et l'information fiscale dont 2 FIP qui 
devraient pourtant être cohérents parce qu'on devrait leur créer un naia à partir du declar
	ERFS 2010 : 3 cas de pb sur naia : 1 valeur manquante pour un EE et 2 valeurs aberrantes pour des FIP
	ERFS 2010 : 1 erreur evidente sur l'année de naissance d'un declar (conséquence sur 2 pac) et 1143 incohérences entre le naia 
	et le declar
	ERFS 2011 : 1 individu né en 1854
	ERFS 2011 : 1298 incohérences entre l'année de naissance pour le fisc et selon l'EE
	ERFS 2012 : 1 individu né en 1854 et 1 individu EE sans naia (corrigé avec l'année de naissance fiscale 
	ERFS 2012 : 877 incohérences entre l'année de naissance pour le fisc et selon l'EE
	ERFS 2013 : 10 individus dans pb_anfip, appartenant à 3 ménages différents
				-> 13009267 supprimé car trop d'erreurs (confusions conjoint / enfants + enfant F en Fip)
				-> 1 couple de 17 et 27 ans (on laisse)
				-> 1 incohérence entre anais et naia (13048432) : naia corrigée dans correction_indivi
	ERFS 2013 : 0 pb de naia	
	ERFS 2014 : 401 individus dans pb_anfip + 1 pb de naia avant corrections. 0 cas après
	ERFS 2015 : 5 individus dans pb_anfip après correction (automatique dans 6_correction_declar). Corrigés manuellement dans 5_correction_individu 
	ERFS 2016 : pb_anfip -> 2 cas avant correction ; 0 après */


/************************************************************************************/
/* 4. Cohérence entre les variables persfip et persfipd	(A&M)						*/
/************************************************************************************/
data pb_persfip;
	set tous_les_individus(keep=ident noi noindiv wp: persfip persfipd quelfic sexe naia);
	/*On ne devrait pas avoir d'individus tels que persfip='vous' ou 'conj' et un persfipd non renseigné */
	if quelfic in ('EE&FIP','FIP') & (persfip in ('vous','conj') & persfipd='');
	/* Il faut verifier que les non déclarants n'ont pas de valeur pour persfipd */
	if (quelfic not in ('EE&FIP','FIP') & (persfip ne '' !  persfipd ne ''));
	run;
/*	ERFS 2010 : A recalculer;
	ERFS 2011 : 763 cas;
	ERFS 2012 : 747 cas (que des FIP)
	ERFS 2013 : 0 cas	
	ERFS 2014 : 0 cas 
	ERFS 2015 : 
	ERFS 2016 : 0 cas*/


/************************************************************************************/
/* 5. Cohérence des revenus imputés													*/
/************************************************************************************/
/* Les revenus positifs doivent être positifs et certains doivent être renseignés */
data pb_rev;
	set tous_les_individus;
	where zalri<0 or zalro<0 or zrtoi<0 or zrtoo<0 or zsali<0 or zchoi<0
		or zragi=. or zrici=. or zrnci=. or zrago=. or zrico=. or zrnco=. ; 
	run;
/*	ERFS 2009 : 0 cas
	ERFS 2010 : 0 cas
	ERFS 2011 : 0 cas
	ERFS 2012 : 0 cas
	ERFS 2013 : 0 cas	
	ERFS 2014 : 0 cas 
	ERFS 2015 : 
	ERFS 2016 : 0 cas*/

/* Les imputations ne doivent pas diminuer le revenu */
data pb_imputation;
	set tous_les_individus;
	where zalri<zalro or zrtoi<zrtoo or zragi<zrago or zrici<zrico or zrnci<zrnco ;
	run;
/*	ERFS 2009 : 1 cas
	ERFS 2011 : 0 cas
	ERFS 2012 : 0 cas
	ERFS 2013 : 0 cas	
	ERFS 2014 : 0 cas 
	ERFS 2015 : 
	ERFS 2016 : 0 cas*/

/************************************************************************************/
/* 6. Controle des ident, noi et poids négatifs	(M)									*/
/************************************************************************************/
data pb_ident;
	set tous_les_individus(keep=ident noi noindiv wp: persfip quelfic declar1 declar2);
	if substr(ident,1,2) ne &anr.
		or input(noi,4.)<0 
		or (input(noi,4.)>=20 & quelfic ne 'FIP')
		or noindiv ne compress(ident||noi) 
		or wprm<=0
		or (quelfic in ('EE','EE_NRT','EE_CAF') & (declar1 ne '' & declar2 ne ''));
	run;
/* 	ERFS 2010 : 0 individu concerné avant les corrections (480 individus concernés par noi>='20'& quelfic ne 'FIP' après);
	ERFS 2012 : 0 cas
	ERFS 2013 : 0 cas	
	ERFS 2014 : 0 cas 
	ERFS 2015 : 
	ERFS 2016 : 0 cas*/

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
