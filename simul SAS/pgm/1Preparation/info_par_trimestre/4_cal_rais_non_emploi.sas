/************************************************************************************************/
/*																								*/
/*									4_cal_rais_non_emploi										*/
/*								 																*/
/************************************************************************************************/

/* Construction d'un calendrier sur la raison du non-emploi qui sert notamment � d�terminer		*/
/* l'�ligibilit� au CLCA de rang 1 et de rang 2 												*/
/*																								*/
/* En entr�e :	travail.irf&anr.e&anr.															*/
/*				travail.infos_trim (cr��e dans 3_recup_infos_trim)											*/
/*				travail.cal_indiv																*/
/* En sortie : 	travail.cal_indiv														*/
/************************************************************************************************/

/* La liste &liste. comprend les variables de l'EE disponibles pour compl�ter le calendrier.    */
/* On collecte l'information de chaque variable de cette liste de mani�re automatis�e, cad quel */
/* que soit le nom et le nombre des variables de la liste. De cette fa�on, si elles changent de */
/* nom, ou si de nouvelles apparaissent, leur prise en compte sera imm�diate par le biais d'un  */
/* simple changement dans le libell� de la liste. 												*/

/* Les variables retenues sont :																*/
/* - nondic = Raison de non disponibilit� pour travailler dans un d�lai de deux semaines,  		*/
/*	dont 4 = garder des enfants et 5 = responsabilit�s personnelles ou familiales (jusqu'en 2009)*/
/*	dont 3 = garder des enfants et 4 = responsabilit�s personnelles ou familiales (� partir de 2010)*/
/*	dont 3 = Garde des enfants (y compris cong� maternit�) ou s'occupe d'une personne d�pendante (2013)*/
/* - rabs = Raison de l'absence au travail la sem de r�f�rence, pour les personnes qui ont un emploi    */
/*	dont 3=Cong� de maternit� ou de paternit� et 5=Cong� parental										*/			
/* - SOCCUPENF = non recherche d'un emploi pour s'occuper de son/ses enfants ou d'un autre membre de sa famille */
/* - dimtyp = Cause de la r�duction d'horaires (dont 1=maternit�)                                        */
/* - TPENF = Raison principale du travail � temps partiel = S'occuper de son/ses enfants, ou un autre membre de sa famille) */
/* - rdem = Raison de la d�mission de l'emploi ant�rieur (dont 2=Pour s'occuper de son/ses enfants, ou d'un autre membre de sa famille) */

%let liste= nondic rabs SOCCUPENF TPENF dimtyp rdem;

/* On ne garde que les individus d'au moins 16 ans, � qui les questions de calendriers sont pos�es */
proc sort data=travail.irf&anr.e&anr.(keep=ident noi naia where=(&anref.-input(naia,4.)>15)) out=irfAdultes; by ident noi; run;
%macro info;
	data rais_non_emploi(keep=ident noi cal_:);
		merge 	travail.infos_trim(rename=(ident&anr.=ident))
				irfAdultes(in=a);
		by ident noi;
		if a;

		%if &anref.>2012 %then %do;
		%let liste=%sysfunc(TRANWRD(&liste.,rdem,)); /* rdem n'existe plus dans l'EEC � partir de 2013 */
		%end;

		/* Initialisation des calendriers */
		format %do i=1 %to %sysfunc(countw(&liste.)); cal_%scan(&liste.,%eval(&i.)) %end; $40.;
		%do i=1 %to %sysfunc(countw(&liste.));
			cal_%scan(&liste.,%eval(&i.))='0000000000000000000000000000000000000000';
			%end;

		/* On it�re sur chaque trimestre d'enqu�te */ 
		%let l=1;
		%do %while(%scan(&liste_trim.,&l.)> );
			%let trim=%scan(&liste_trim.,&l.);
			%if &l.>1 %then %do; %let trim_1=%scan(&liste_trim.,%eval(&l.-1));%end;
		    %let l=%eval(&l.+1);

			if datqi_&trim. ne '' then do;
				/* on r�cup�re l'ann�e et le mois de chaque interrogation */
				ancoll=		input(substr(datqi_&trim.,1,4),4.);
				moiscoll=	input(substr(datqi_&trim.,5,2),4.);

				place=12*(%eval(&anref.+1)-ancoll)+12-moiscoll+1;
				%do i=1 %to %sysfunc(countw(&liste.));
					/* r�cup�ration du nom de la variable de la liste */
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
		label cal_nondic = "calendrier des raisons de non disponibilit� pour travailler";
		label cal_rabs = "calendrier des raisons de l'absence au travail pour les personnes en emploi";
		label cal_SOCCUPENF = "calendrier de la raison principale de non recherche d'emploi";
		label cal_TPENF = "calendrier de la raison principale de travail � temps partiel";
		label cal_dimtyp = "calendrier de la nature de la r�duction d'horaires";
		run;
	%mend info;
%info;

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
