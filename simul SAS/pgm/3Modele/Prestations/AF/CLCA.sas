/************************************************************************************/
/*																					*/
/*								CLCA												*/
/*																					*/
/************************************************************************************/

/************************************************************************************/
/* Modélisation du Complément Libre Choix d'Activité     							*/
/* En entrée : modele.baseind 														*/
/*			   base.baseind															*/
/*			   modele.basefam														*/
/* En sortie : modele.baseind                                     					*/
/************************************************************************************/
/* PLAN :																			*/
/* A. Selection des familles éligible au CLCA										*/
/* B. Montant annuel de CLCA														*/
/*	B.1 Nombre de mois où la personne est bénéficiaire du CLCA						*/
/*	B.2 Montant du CLCA 															*/
/************************************************************************************/
/* REMARQUE : */
 /* 1) L'éligibilité au CLCA a été simulée dans les imputations (10_travail_clca),                                    */
/* avec les variables clca_tp  et cal_nai                                                                                                                         */
/* 2) Le CLCA est calculé au niveau individuel. Les cas de double CLCA dans 1 famille sont gérés  */
/* par le  pgm synthèse_garde (de même que l'exclusion ou la combinaison 	CLCA/CMG)              */
/************************************************************************************/


/**********************************************/
/* A. Selection des familles éligible au CLCA */
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
		/* Nb d'enfants de 0 à 19 ans inclus */
		%nb_enf(e_c,0,&age_pf.,age_enf);

		/**************************************************************/
		/* B.1 Nombre de mois où la personne est bénéficiaire du CLCA */
		/**************************************************************/
		/*Le versement du CLCA dure jusqu'au 6ème mois s'il y a un seul enfant à charge, 
		jusqu'aux 3 ans du plus jeune s'il y a au moins deux enfants à charge*/
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
		/* En 2014 suppression de la majoration de la CLCA seulement pour les enfants nés à partir d'Avril
			La réforme concerne donc tout le monde seulement à partir d'Avril 2017. On code ici toutes les 
			années de transition */
		%if &anleg.=2014 %then %do;
			/*  On enlève le bénéfice du CLCA majoré  pour toutes les familles éligibles avec un enfant
			né après le premier Avril. C'est une simplification : en théorie on ne devrait pas l'enlever pour
			les familles ayant eu un enfant né après le premier Avril mais bénéficiant du CLCA au titre d'enfants
			plus âgés.*/
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
