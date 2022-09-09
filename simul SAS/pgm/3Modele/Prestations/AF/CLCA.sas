/************************************************************************************/
/*																					*/
/*								CLCA												*/
/*																					*/
/************************************************************************************/

/************************************************************************************/
/* Mod�lisation du Compl�ment Libre Choix d'Activit�     							*/
/* En entr�e : modele.baseind 														*/
/*			   base.baseind															*/
/*			   modele.basefam														*/
/* En sortie : modele.baseind                                     					*/
/************************************************************************************/
/* PLAN :																			*/
/* A. Selection des familles �ligible au CLCA										*/
/* B. Montant annuel de CLCA														*/
/*	B.1 Nombre de mois o� la personne est b�n�ficiaire du CLCA						*/
/*	B.2 Montant du CLCA 															*/
/************************************************************************************/
/* REMARQUE : */
 /* 1) L'�ligibilit� au CLCA a �t� simul�e dans les imputations (10_travail_clca),                                    */
/* avec les variables clca_tp  et cal_nai                                                                                                                         */
/* 2) Le CLCA est calcul� au niveau individuel. Les cas de double CLCA dans 1 famille sont g�r�s  */
/* par le  pgm synth�se_garde (de m�me que l'exclusion ou la combinaison 	CLCA/CMG)              */
/************************************************************************************/


/**********************************************/
/* A. Selection des familles �ligible au CLCA */
/**********************************************/
proc sql;
	create table eligibles_ as
		select a.ident, a.noi, a.clca_tp, b.ident_fam
		from base.baseind(keep=ident noi clca_tp where=(clca_tp ne 0)) as a inner join modele.baseind(keep=ident noi ident_fam) as b
		on a.ident=b.ident and a.noi=b.noi
		order by ident_fam;
	create table eligibles as
		select a.*, b.age_enf, b.paje_base, b.cal_nai, b.naissance_apres_avril
		from eligibles_ as a 
		inner join modele.basefam (keep=ident_fam age_enf paje_base cal_nai naissance_apres_avril) as b
		on a.ident_fam=b.ident_fam;
	quit;

/**********************************************/
/* B. Montant annuel de CLCA				  */
/**********************************************/
%Macro CLCA;
	data clca; 
		set eligibles;
		/* Nb d'enfants de 0 � 19 ans inclus */
		%nb_enf(e_c,0,&age_pf.,age_enf);

		/**************************************************************/
		/* B.1 Nombre de mois o� la personne est b�n�ficiaire du CLCA */
		/**************************************************************/
		/*Le versement du CLCA dure jusqu'au 6�me mois s'il y a un seul enfant � charge, 
		jusqu'aux 3 ans du plus jeune s'il y a au moins deux enfants � charge*/
		nbMoisCLCA=0; 
		do i= 1 to 12; 
			if e_c>1 and substr(cal_nai,i,1) in ('1','2','3') then nbMoisCLCA=nbMoisCLCA+1;
			if e_c=1 and substr(cal_nai,i,1) in ('1','2') then nbMoisCLCA=nbMoisCLCA+1;
			end; 
		if e_c=1 then nbMoisCLCA=min(nbMoisCLCA,6);

		/**************************************************************/
		/* B.2 Montant du CLCA                                        */
		/**************************************************************/

		if paje_base>0 then do;
			if clca_tp=1 then clca=nbMoisCLCA*&cca1_si_paje.*&bmaf.;
			if clca_tp=2 then clca=nbMoisCLCA*&cca2_si_paje.*&bmaf.;
			if clca_tp=3 then clca=nbMoisCLCA*&cca3_si_paje.*&bmaf.;
			end;
			else do;
			if clca_tp=1 then clca=nbMoisCLCA*&cca1.*&bmaf.;
			if clca_tp=2 then clca=nbMoisCLCA*&cca2.*&bmaf.;
			if clca_tp=3 then clca=nbMoisCLCA*&cca3.*&bmaf.;
			end;
		%if &anleg.<2004 %then %do;
			if e_c=1 then clca=0;
			%end;
		%if &anleg.<1995 %then %do;
			if (e_c<3!clca_tp=2!clca_tp=3) then clca=0;
			%end;
		/* En 2014 suppression de la majoration de la CLCA seulement pour les enfants n�s � partir d'Avril
			La r�forme concerne donc tout le monde seulement � partir d'Avril 2017. On code ici toutes les 
			ann�es de transition */
		%if &anleg.=2014 %then %do;
			/*  On enl�ve le b�n�fice du CLCA major�  pour toutes les familles �ligibles avec un enfant
			n� apr�s le premier Avril. C'est une simplification : en th�orie on ne devrait pas l'enlever pour
			les familles ayant eu un enfant n� apr�s le premier Avril mais b�n�ficiant du CLCA au titre d'enfants
			plus �g�s.*/
			if naissance_apres_avril=1 then do; 
				if clca_tp=1 then clca=nbMoisCLCA*&cca1_si_paje.*&bmaf.;
				if clca_tp=2 then clca=nbMoisCLCA*&cca2_si_paje.*&bmaf.;
				if clca_tp=3 then clca=nbMoisCLCA*&cca3_si_paje.*&bmaf.;
				end;
			%end;
		%if &anleg.=2015 %then %do;
			if naissance_apres_avril in (1,2) then do; 
			if clca_tp=1 then clca=nbMoisCLCA*&cca1_si_paje.*&bmaf.;
			if clca_tp=2 then clca=nbMoisCLCA*&cca2_si_paje.*&bmaf.;
			if clca_tp=3 then clca=nbMoisCLCA*&cca3_si_paje.*&bmaf.;
				end;
			%end;
		%if &anleg.=2016 %then %do;
			if naissance_apres_avril in (1,2,3) then do; 
			if clca_tp=1 then clca=nbMoisCLCA*&cca1_si_paje.*&bmaf.;
			if clca_tp=2 then clca=nbMoisCLCA*&cca2_si_paje.*&bmaf.;
			if clca_tp=3 then clca=nbMoisCLCA*&cca3_si_paje.*&bmaf.;
				end;
			%end;
		%if &anleg.=2017 %then %do;
			if naissance_apres_avril in (1,2,3,4) then do; 
			if clca_tp=1 then clca=nbMoisCLCA*&cca1_si_paje.*&bmaf.;
			if clca_tp=2 then clca=nbMoisCLCA*&cca2_si_paje.*&bmaf.;
			if clca_tp=3 then clca=nbMoisCLCA*&cca3_si_paje.*&bmaf.;
				end;
			%end;
		drop i;
		run;
	%Mend CLCA;
%CLCA;

proc sort data=clca; by ident noi; run;
proc sort data=modele.baseind; by ident noi; run;
data modele.baseind;
	merge modele.baseind 
		  clca (in=a keep=ident noi clca clca_tp);
	by ident noi; 
	if not a then do;
		clca=0;
		end;
	label clca="CLCA";
	run;


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
