/****************************************************************************************/
/*																						*/
/*							6_CORRECTION_DECLAR											*/
/*																						*/
/****************************************************************************************/

/* Correction des declar pour qu'ils soient cohérents avec les naia						*/
/****************************************************************************************/
/* En entrée : 	travail.indivi&anr.														*/
/*				travail.irf&anr.e&anr.													*/
/*				travail.foyer&anr.														*/
/* En sortie : 	travail.indivi&anr.														*/
/*				travail.foyer&anr. 														*/
/****************************************************************************************/
/* PLAN : 																				*/
/* 1	Identification et correction des incohérences entre declar et naia 				*/
/* 2	Correction de la table indivi&anr. 												*/
/* 3	Correction de la table indfip&anr. 												*/
/* 4	Correction de la table foyer&anr. 												*/
/****************************************************************************************/
/* Remarque : 																			*/
/* On ne corrige pas declar2 parce que le persfip ne correspond qu'à declar1. 			*/
/****************************************************************************************/


/****************************************************************************************/
/* 1	Identification et correction des incohérences entre declar et naia 				*/
/****************************************************************************************/
proc sql;
	/* 1.1	POUR LES VOUS */
	/* Repérage des incohérences individuelles (une ligne par individu, avec declar1) */
	create table Incoherences_Vous as
		select 	a.ident, a.noi, a.declar1, a.persfip, b.naia, substr(declar1,14,4) ne naia as pb1
		from travail.indivi&anr.(keep=ident noi declar: persfip) as a join travail.irf&anr.e&anr.(keep=ident noi naia) as b
		on a.ident=b.ident and a.noi=b.noi
		having persfip='vous' and pb1;

	/* Correction des incohérences */
	alter table Incoherences_Vous
		add declar1_corr varchar(100);
	update Incoherences_Vous /* Incohérence sur declar1 */
		set declar1_corr=substr(declar1,1,13)!!naia!!substr(declar1,18,61)
		where pb1;
	/* TODO : je n'arrive pas à enlever les Warning générés */

	/* Une ligne par declar */
	create table Incoherences_Vous_Corr as
		select * from
			/* Incohérence sur declar1 */
			(select a.ident, a.noi, a.declar1 as declar, a.declar1_corr as declar_corr from
			Incoherences_Vous as a left join travail.foyer&anr.(keep=declar) as b
			on a.declar1=b.declar
			where a.pb1);

	/* 1.2	POUR LES CONJ */
	/* Repérage des incohérences individuelles (une ligne par individu, avec declar1) */
	create table Incoherences_Conj as
		select 	a.ident, a.noi, a.declar1, a.persfip, b.naia, substr(declar1,19,4) ne naia as pb1
		from travail.indivi&anr.(keep=ident noi declar: persfip) as a join travail.irf&anr.e&anr.(keep=ident noi naia) as b
		on a.ident=b.ident and a.noi=b.noi
		having persfip='conj' and pb1;

	/* Correction des incohérences */
	alter table Incoherences_Conj
		add declar1_corr varchar(100);
	/* On met à jour le declar1 si jamais ils étaient déjà concernés par une correction sur 'vous' */
	update Incoherences_Conj as a
		set declar1_corr=(select b.declar_corr from Incoherences_Vous_Corr as b where a.declar1=b.declar) 
			where (a.declar1 in (select declar from Incoherences_Vous_Corr));
	/* Puis on met à jour avec l'année de naissance de l'EE */
	update Incoherences_Conj /* Incohérence sur declar1 */
		set declar1_corr= case 	when declar1_corr='' then substr(declar1,1,18)!!naia!!substr(declar1,23,56)
								else substr(declar1_corr,1,18)!!naia!!substr(declar1_corr,23,56)
								end
		where pb1;

	/* Une ligne par declar à problème */
	create table Incoherences_Conj_Corr as
		select * from
			/* Incohérence sur declar1 */
			(select a.ident, a.noi, a.declar1 as declar, a.declar1_corr as declar_corr from
			Incoherences_Conj as a left join travail.foyer&anr.(keep=declar) as b
			on a.declar1=b.declar
			where a.pb1);

	create table Incoherences_Corr as
		select coalesce(a.ident,b.ident) as ident,
				coalesce(a.noi,b.noi) as noi,
				coalesce(a.declar,b.declar) as declar,
				coalesce(a.declar_corr,b.declar_corr) as declar_corr
		from Incoherences_Vous_Corr as a full outer join Incoherences_Conj_Corr as b on a.declar=b.declar;

/****************************************************************************************/
/* 2	Correction de la table indivi&anr. 												*/
/****************************************************************************************/
	create table indivi_c1 as /* Correction des declar1 */
		select a.*, b.declar_corr as declar1_corr from
		travail.indivi&anr. as a left join Incoherences_Corr as b
		on a.declar1=b.declar;
	quit;

data travail.indivi&anr.; /* On remplace declar1*/
	set indivi_c1;
	if declar1_corr ne "" then declar1=declar1_corr;
	drop declar1_corr naia;
	run;

%macro correction_indivi15 ;

	%if &anref.=2015 %then %do;
			data travail.indivi&anr.; 
		 	set travail.indivi&anr.; 

	/* Incohérence entre naia et declar (repéré dans programme controle niv_individu) */
			%RemplaceIndivi(ancien=	'01-15018997-M1930-1930-000  -',
							nouveau='01-15018997-M1930-1927-000  -');
			%RemplaceIndivi(ancien=	'01-15019243-O1979-1979-000  -F2013',
							nouveau='01-15019243-O1979-1983-000  -F2013');
			%RemplaceIndivi(ancien=	'02-15019788-M1936-1936-000  -',
							nouveau='02-15019788-M1936-1933-000  -');
			%RemplaceIndivi(ancien=	'02-15029454-M1966-1966-000  -F1998F2001F2004',
							nouveau='02-15029454-M1966-1965-000  -F1998F2001F2004');		
			%RemplaceIndivi(ancien=	'02-15038127-M1932-1932-000  -',
							nouveau='02-15038127-M1932-1936-000  -');

			run;	
	%end;

%mend; %correction_indivi15;

/****************************************************************************************/
/* 3	Correction de la table indfip&anr. 												*/
/****************************************************************************************/
proc sql;
	create table indivi_c1 as /* Correction des declar1 */
		select a.*, b.declar_corr as declar1_corr from
		travail.indfip&anr. as a left join Incoherences_Corr as b
		on a.declar1=b.declar;
	quit;

data travail.indfip&anr.; /* On remplace declar1*/
	set indivi_c1;
	if declar1_corr ne "" then declar1=declar1_corr;
	drop declar1_corr;
	run;


/****************************************************************************************/
/* 4	Correction de la table foyer&anr. 												*/
/****************************************************************************************/

%ListeVariablesDuneTable(table=travail.foyer&anr.,mv=ListeVarFoyer,except=declar ident noi,separateur=',');
proc sql;
	create table Foyer_Corr as
		select a.ident, a.noi, &ListeVarFoyer., coalesce(b.declar_corr,a.declar) as declar
		from travail.foyer&anr. as a left join Incoherences_Corr as b
		on a.declar=b.declar;
	quit;

data travail.foyer&anr.; /* TODO : A optimiser (une seule étape possible) */
	set Foyer_Corr;
	vousconj=substr(declar,14,9);
	run;

%macro correction_foyer15 ;

	%if &anref.=2015 %then %do;
			data travail.foyer&anr.; 
		 	set travail.foyer&anr.; 

	/* Incohérence entre naia et declar (repéré dans programme controle niv_individu) */
			%RemplaceDeclar(ancien=	'01-15018997-M1930-1930-000  -',
							nouveau='01-15018997-M1930-1927-000  -');
			%RemplaceDeclar(ancien=	'01-15019243-O1979-1979-000  -F2013',
							nouveau='01-15019243-O1979-1983-000  -F2013');
			%RemplaceDeclar(ancien=	'02-15019788-M1936-1936-000  -',
							nouveau='02-15019788-M1936-1933-000  -');
			%RemplaceDeclar(ancien=	'02-15029454-M1966-1966-000  -F1998F2001F2004',
							nouveau='02-15029454-M1966-1965-000  -F1998F2001F2004');		
			%RemplaceDeclar(ancien=	'02-15038127-M1932-1932-000  -',
							nouveau='02-15038127-M1932-1936-000  -');
			run;	
	%end;

%mend; %correction_foyer15;
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
