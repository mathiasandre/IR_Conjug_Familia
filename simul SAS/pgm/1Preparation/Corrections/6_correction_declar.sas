/****************************************************************************************/
/*																						*/
/*							6_CORRECTION_DECLAR											*/
/*																						*/
/****************************************************************************************/

/* Correction des declar pour qu'ils soient coh�rents avec les naia						*/
/****************************************************************************************/
/* En entr�e : 	travail.indivi&anr.														*/
/*				travail.irf&anr.e&anr.													*/
/*				travail.foyer&anr.														*/
/* En sortie : 	travail.indivi&anr.														*/
/*				travail.foyer&anr. 														*/
/****************************************************************************************/
/* PLAN : 																				*/
/* 1	Identification et correction des incoh�rences entre declar et naia 				*/
/* 2	Correction de la table indivi&anr. 												*/
/* 3	Correction de la table indfip&anr. 												*/
/* 4	Correction de la table foyer&anr. 												*/
/****************************************************************************************/
/* Remarque : 																			*/
/* On ne corrige pas declar2 parce que le persfip ne correspond qu'� declar1. 			*/
/****************************************************************************************/


/****************************************************************************************/
/* 1	Identification et correction des incoh�rences entre declar et naia 				*/
/****************************************************************************************/
proc sql;
	/* 1.1	POUR LES VOUS */
	/* Rep�rage des incoh�rences individuelles (une ligne par individu, avec declar1) */
	create table Incoherences_Vous as
		select 	a.ident, a.noi, a.declar1, a.persfip, b.naia, substr(declar1,14,4) ne naia as pb1
		from travail.indivi&anr.(keep=ident noi declar: persfip) as a join travail.irf&anr.e&anr.(keep=ident noi naia) as b
		on a.ident=b.ident and a.noi=b.noi
		having persfip='vous' and pb1;

	/* Correction des incoh�rences */
	alter table Incoherences_Vous
		add declar1_corr varchar(100);
	update Incoherences_Vous /* Incoh�rence sur declar1 */
		set declar1_corr=substr(declar1,1,13)!!naia!!substr(declar1,18,61)
		where pb1;
	/* TODO : je n'arrive pas � enlever les Warning g�n�r�s */

	/* Une ligne par declar */
	create table Incoherences_Vous_Corr as
		select * from
			/* Incoh�rence sur declar1 */
			(select a.ident, a.noi, a.declar1 as declar, a.declar1_corr as declar_corr from
			Incoherences_Vous as a left join travail.foyer&anr.(keep=declar) as b
			on a.declar1=b.declar
			where a.pb1);

	/* 1.2	POUR LES CONJ */
	/* Rep�rage des incoh�rences individuelles (une ligne par individu, avec declar1) */
	create table Incoherences_Conj as
		select 	a.ident, a.noi, a.declar1, a.persfip, b.naia, substr(declar1,19,4) ne naia as pb1
		from travail.indivi&anr.(keep=ident noi declar: persfip) as a join travail.irf&anr.e&anr.(keep=ident noi naia) as b
		on a.ident=b.ident and a.noi=b.noi
		having persfip='conj' and pb1;

	/* Correction des incoh�rences */
	alter table Incoherences_Conj
		add declar1_corr varchar(100);
	/* On met � jour le declar1 si jamais ils �taient d�j� concern�s par une correction sur 'vous' */
	update Incoherences_Conj as a
		set declar1_corr=(select b.declar_corr from Incoherences_Vous_Corr as b where a.declar1=b.declar) 
			where (a.declar1 in (select declar from Incoherences_Vous_Corr));
	/* Puis on met � jour avec l'ann�e de naissance de l'EE */
	update Incoherences_Conj /* Incoh�rence sur declar1 */
		set declar1_corr= case 	when declar1_corr='' then substr(declar1,1,18)!!naia!!substr(declar1,23,56)
								else substr(declar1_corr,1,18)!!naia!!substr(declar1_corr,23,56)
								end
		where pb1;

	/* Une ligne par declar � probl�me */
	create table Incoherences_Conj_Corr as
		select * from
			/* Incoh�rence sur declar1 */
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

	/* Incoh�rence entre naia et declar (rep�r� dans programme controle niv_individu) */
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

data travail.foyer&anr.; /* TODO : A optimiser (une seule �tape possible) */
	set Foyer_Corr;
	vousconj=substr(declar,14,9);
	run;

%macro correction_foyer15 ;

	%if &anref.=2015 %then %do;
			data travail.foyer&anr.; 
		 	set travail.foyer&anr.; 

	/* Incoh�rence entre naia et declar (rep�r� dans programme controle niv_individu) */
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
