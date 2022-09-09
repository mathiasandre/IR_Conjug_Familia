/************************************************************************************************/
/*																								*/
/*									4_cal_rais_non_emploi										*/
/*								 																*/
/************************************************************************************************/

/* Construction d'un calendrier sur la raison du non-emploi qui sert notamment à déterminer		*/
/* l'éligibilité au CLCA de rang 1 et de rang 2 												*/
/*																								*/
/* En entrée :	travail.irf&anr.e&anr.															*/
/*				travail.infos_trim (créée dans 3_recup_infos_trim)											*/
/*				travail.cal_indiv																*/
/* En sortie : 	travail.cal_indiv														*/
/************************************************************************************************/

/* La liste &liste. comprend les variables de l'EE disponibles pour compléter le calendrier.    */
/* On collecte l'information de chaque variable de cette liste de manière automatisée, cad quel */
/* que soit le nom et le nombre des variables de la liste. De cette façon, si elles changent de */
/* nom, ou si de nouvelles apparaissent, leur prise en compte sera immédiate par le biais d'un  */
/* simple changement dans le libellé de la liste. 												*/

/* Les variables retenues sont :																*/
/* - nondic = Raison de non disponibilité pour travailler dans un délai de deux semaines,  		*/
/*	dont 4 = garder des enfants et 5 = responsabilités personnelles ou familiales (jusqu'en 2009)*/
/*	dont 3 = garder des enfants et 4 = responsabilités personnelles ou familiales (à partir de 2010)*/
/*	dont 3 = Garde des enfants (y compris congé maternité) ou s'occupe d'une personne dépendante (2013)*/
/* - rabs = Raison de l'absence au travail la sem de référence, pour les personnes qui ont un emploi    */
/*	dont 3=Congé de maternité ou de paternité et 5=Congé parental										*/			
/* - SOCCUPENF = non recherche d'un emploi pour s'occuper de son/ses enfants ou d'un autre membre de sa famille */
/* - dimtyp = Cause de la réduction d'horaires (dont 1=maternité)                                        */
/* - TPENF = Raison principale du travail à temps partiel = S'occuper de son/ses enfants, ou un autre membre de sa famille) */
/* - rdem = Raison de la démission de l'emploi antérieur (dont 2=Pour s'occuper de son/ses enfants, ou d'un autre membre de sa famille) */

%let liste= nondic rabs SOCCUPENF TPENF dimtyp rdem;

/* On ne garde que les individus d'au moins 16 ans, à qui les questions de calendriers sont posées */
proc sort data=travail.irf&anr.e&anr.(keep=ident noi naia where=(&anref.-input(naia,4.)>15)) out=irfAdultes; by ident noi; run;
%macro info;
	data rais_non_emploi(keep=ident noi cal_:);
		merge 	travail.infos_trim(rename=(ident&anr.=ident))
				irfAdultes(in=a);
		by ident noi;
		if a;

		%if &anref.>2012 %then %do;
		%let liste=%sysfunc(TRANWRD(&liste.,rdem,)); /* rdem n'existe plus dans l'EEC à partir de 2013 */
		%end;

		/* Initialisation des calendriers */
		format %do i=1 %to %sysfunc(countw(&liste.)); cal_%scan(&liste.,%eval(&i.)) %end; $40.;
		%do i=1 %to %sysfunc(countw(&liste.));
			cal_%scan(&liste.,%eval(&i.))='0000000000000000000000000000000000000000';
			%end;

		/* On itère sur chaque trimestre d'enquête */ 
		%let l=1;
		%do %while(%scan(&liste_trim.,&l.)> );
			%let trim=%scan(&liste_trim.,&l.);
			%if &l.>1 %then %do; %let trim_1=%scan(&liste_trim.,%eval(&l.-1));%end;
		    %let l=%eval(&l.+1);

			if datqi_&trim. ne '' then do;
				/* on récupère l'année et le mois de chaque interrogation */
				ancoll=		input(substr(datqi_&trim.,1,4),4.);
				moiscoll=	input(substr(datqi_&trim.,5,2),4.);

				place=12*(%eval(&anref.+1)-ancoll)+12-moiscoll+1;
				%do i=1 %to %sysfunc(countw(&liste.));
					/* récupération du nom de la variable de la liste */
					%let variable=%scan(&liste.,%eval(&i.));
			   		%calend(cal_&variable.,&variable._&trim.,place,1);
					%end;
				end;
			%end;
		run;
	/* sauvegarde */
	data travail.cal_indiv;
		merge	travail.cal_indiv (in=a)
				rais_non_emploi;
		by ident noi;
		if a;
		label cal_nondic = "calendrier des raisons de non disponibilité pour travailler";
		label cal_rabs = "calendrier des raisons de l'absence au travail pour les personnes en emploi";
		label cal_SOCCUPENF = "calendrier de la raison principale de non recherche d'emploi";
		label cal_TPENF = "calendrier de la raison principale de travail à temps partiel";
		label cal_dimtyp = "calendrier de la nature de la réduction d'horaires";
		run;
	%mend info;
%info;

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
