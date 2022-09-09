/************************************************************************************/
/*																					*/
/*							6_Controles_niveau_individu								*/
/*																					*/
/************************************************************************************/

/* V�rifications au niveau des individus sur les variables noi, ident, naia, persfip et declar 
   ainsi que sur les revenus contenus dans les tables indivi et indfip.				*/ 
/************************************************************************************/
/* En entr�e : 	travail.indivi&anr. 				                                */
/* 				travail.irf&anr.e&anr. 				                                */
/* 				travail.indfip&anr. 				                                */
/************************************************************************************/
/* PLAN : 																			*/
/* 0. Pr�paration table avec tous les individus, yc les FIP 						*/
/* 1. Coh�rence entre les declar, le persfip, ident et noi (A&M)					*/
/* 2. Coh�rence d'�v�nement entre declar1 et declar2 (M)							*/
/* 3. Coh�rence entre declar et naia (M&A)											*/
/* 4. Coh�rence entre les variables persfip et persfipd	(A&M)						*/
/* 5. Coh�rence des revenus imput�s													*/
/* 6. Controle des ident, noi et poids n�gatifs	(M)									*/
/************************************************************************************/
/* Remarque : 																		*/
/* - A indique que la correction est automatique dans les pgms de corrections 		*/
/* - M indique un traitement manuel � faire (par exemple modifier un declar)		*/
/************************************************************************************/


/************************************************************************************/
/* 0. Pr�paration table avec tous les individus, yc les FIP 						*/
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
/* 1. Coh�rence entre les declar, le persfip, ident et noi (A&M)					*/
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
	 	if  persfip='conj'								/* pr�sence de conj uniquement sur des d�clarations de mari�s/pacs�s */
			& substr(declar1,13,1) not in('M','O')
			& substr(declar2,13,1) not in('M','O') then output;
		if  persfip='pac'								/* pr�sence de pac uniquement si le declar contient des pac */
			& substr(declar1,30,1) not in ('F' 'G' 'H' 'I' 'J' 'N' 'R') then output;
		end; 
	run;
/*	ERFS 2010 : 61 cas (probl�mes de coh�rence entre declar et noi);
	ERFS 2011 : 49 cas
	ERFS 2012 : 52 cas : 26 pb de coh�rence declar/noi de d�clarants dont 25 FIP avec noi=71 et 26 pb de coh�rence declar/noi de conjoints
	ERFS 2013 : 0 cas 
	ERFS 2014 : 656 cas avant corrections ; 0 cas apr�s 
	ERFS 2015 :
	ERFS 2016 : 0 cas apr�s correction */

/************************************************************************************/
/* 2. Coh�rence d'�v�nement entre declar1 et declar2 (M)							*/
/************************************************************************************/
/* Exemple d'erreur : gens d�clarant �tre divorc�s alors qu'en r�alit� ils sont veufs */
data pb_even_declar;
	set tous_les_individus(keep=ident noi noindiv wp: persfip quelfic declar1 declar2);
	where quelfic in ('EE&FIP','FIP') & declar2 ne '' & substr(declar1,24,3) ne substr(declar2,24,3);
	run;
/*	ERFS 2009 : reste une erreur normale car on ne sait pas comment la corriger
	ERFS 2010 : 27 cas
	ERFS 2011 : 10 cas
	ERFS 2012 : 0 cas
	ERFS 2013 : 1 cas normal (enfant de 18 ans qui se met � faire sa d�claration tout seul et dont le parent �tait divorc� dans l'ann�e) 
	ERFS 2014 : 1 cas normal (enfant de 18 ans qui se met � faire sa d�claration tout seul et dont le parent �tait divorc� dans l'ann�e) 
				+ 2 cas (1 seul foyer fiscal) avec 1 mariage et un d�c�s (mariage pas renseign� dans declar1). On ne corrige pas car ce qui importe = veuf sur la d�claration la plus r�cente */
				/* TODO : v�rification demand�e sur ce choix de ne pas corriger (en lien avec macro %standard_foyer o� X prime en cas de double d�claration) 
	ERFS 2015 : 1 cas normal (enfant de 18 ans qui se met � faire sa d�claration tout seul et dont le parent �tait divorc� dans l'ann�e) 
				+ 2 cas (1 seul foyer fiscal) comme l'an dernier 2014 ;
	ERFS 2016 : 0 cas*/

/************************************************************************************/
/* 3. Coh�rence entre declar et naia (M&A)											*/
/************************************************************************************/
/* Les ann�es de naissance doivent �tre coh�rentes : pas de personne de plus de 110 ans ni de d�clarant mineur (M), 
	les mariages avec les mineurs sont � examiner et les ann�es de naissance des fichiers fiscaux doivent 
	correspondre aux ann�es de naissance de l'enqu�te emploi (naia) */
data pb_anfip pb_naia;
	set tous_les_individus (keep=ident noi noindiv wp: persfip quelfic declar1 declar2 naia);
	if quelfic in ('EE&FIP','FIP') then do;
		anfip1_d1 = put(substr(declar1,14,4),4.); /* Ann�e de naissance du d�clarant */
		anfip2_d1 = put(substr(declar1,19,4),4.); /* Ann�e de naissance du conjoint  */
		if declar2 ne '' then do;				  /* M�me chose pour declar2 si �ch�ant */
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
	ERFS 2009 : 936 incoh�rences entre naia de l'EE et l'information fiscale dont 2 FIP qui 
devraient pourtant �tre coh�rents parce qu'on devrait leur cr�er un naia � partir du declar
	ERFS 2010 : 3 cas de pb sur naia : 1 valeur manquante pour un EE et 2 valeurs aberrantes pour des FIP
	ERFS 2010 : 1 erreur evidente sur l'ann�e de naissance d'un declar (cons�quence sur 2 pac) et 1143 incoh�rences entre le naia 
	et le declar
	ERFS 2011 : 1 individu n� en 1854
	ERFS 2011 : 1298 incoh�rences entre l'ann�e de naissance pour le fisc et selon l'EE
	ERFS 2012 : 1 individu n� en 1854 et 1 individu EE sans naia (corrig� avec l'ann�e de naissance fiscale 
	ERFS 2012 : 877 incoh�rences entre l'ann�e de naissance pour le fisc et selon l'EE
	ERFS 2013 : 10 individus dans pb_anfip, appartenant � 3 m�nages diff�rents
				-> 13009267 supprim� car trop d'erreurs (confusions conjoint / enfants + enfant F en Fip)
				-> 1 couple de 17 et 27 ans (on laisse)
				-> 1 incoh�rence entre anais et naia (13048432) : naia corrig�e dans correction_indivi
	ERFS 2013 : 0 pb de naia	
	ERFS 2014 : 401 individus dans pb_anfip + 1 pb de naia avant corrections. 0 cas apr�s
	ERFS 2015 : 5 individus dans pb_anfip apr�s correction (automatique dans 6_correction_declar). Corrig�s manuellement dans 5_correction_individu 
	ERFS 2016 : pb_anfip -> 2 cas avant correction ; 0 apr�s */


/************************************************************************************/
/* 4. Coh�rence entre les variables persfip et persfipd	(A&M)						*/
/************************************************************************************/
data pb_persfip;
	set tous_les_individus(keep=ident noi noindiv wp: persfip persfipd quelfic sexe naia);
	/*On ne devrait pas avoir d'individus tels que persfip='vous' ou 'conj' et un persfipd non renseign� */
	if quelfic in ('EE&FIP','FIP') & (persfip in ('vous','conj') & persfipd='');
	/* Il faut verifier que les non d�clarants n'ont pas de valeur pour persfipd */
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
/* 5. Coh�rence des revenus imput�s													*/
/************************************************************************************/
/* Les revenus positifs doivent �tre positifs et certains doivent �tre renseign�s */
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
/* 6. Controle des ident, noi et poids n�gatifs	(M)									*/
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
/* 	ERFS 2010 : 0 individu concern� avant les corrections (480 individus concern�s par noi>='20'& quelfic ne 'FIP' apr�s);
	ERFS 2012 : 0 cas
	ERFS 2013 : 0 cas	
	ERFS 2014 : 0 cas 
	ERFS 2015 : 
	ERFS 2016 : 0 cas*/

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
