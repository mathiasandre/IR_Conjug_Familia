/****************************************************************************/
/*																			*/
/*							3_cal_rev										*/
/*								 											*/
/****************************************************************************/

/****************************************************************************/
/* Constitution d'un calendrier trimestriel individuel de r�ponses � l'EE	*/
/* En entr�e : 	travail.irf&anr.e&anr.										*/ 
/*				travail.infos_trim (cr��e dans 3_recup_infos_trim)						*/
/*				travail.cal_indiv											*/
/* En sortie : 	travail.cal_indiv											*/
/****************************************************************************/


/* On ne garde que les individus d'au moins 16 ans, � qui les questions de calendriers sont pos�es */
proc sort data=travail.irf&anr.e&anr.(keep=ident noi naia where=(&anref.-input(naia,4.)>15)) out=irfAdultes; by ident noi; run;

/* On cr�e une variable de calendrier pour chaque variables de &rc1. avec l'historique de perception de ces transferts.*/
%macro rev;
	data rev(keep=ident noi cal:);
		merge travail.infos_trim(rename=(ident&anr.=ident)) 
				irfAdultes(in=a);
		by ident noi;
		if a;

		/* info dans rc1*/ 
		%let rc1=aah minv;

		/* Initialisation des calendriers */
		format %do i=1 %to %sysfunc(countw(&rc1.)); cal_%scan(&rc1.,%eval(&i.)) %end; $40.;
		%do i=1 %to %sysfunc(countw(&rc1.)); 
			cal_%scan(&rc1.,%eval(&i.))='0000000000000000000000000000000000000000';
			%end;

		/* On it�re sur chaque trimestre d'enqu�te */ 
		%let l=1;
		%do %while(%scan(&liste_trim.,&l.)> );
			%let trim=%scan(&liste_trim.,&l.);
		    %let l=%eval(&l.+1);

			if datqi_&trim. ne '' then do;
				/* on r�cup�re l'ann�e et le mois de chaque interrogation */
				ancoll=		input(substr(datqi_&trim.,1,4),4.);
				moiscoll=	input(substr(datqi_&trim.,5,2),4.);

				place=12*(%eval(&anref.+1)-ancoll)+12-moiscoll+1;

				/* On code une indicatrice pour chaque mois o� l'individu a per�u un des transferts de rc1 */
				if RECOITAAH_&trim.='1' then do;  %calend(cal_aah,'1',place,1);end;
				if RECOITASPA_&trim.='1' then do;  %calend(cal_minv,'1',place,1);end;
				end;
			%end;
		run;
	/* sauvegarde */
	data travail.cal_indiv;
		merge	travail.cal_indiv (in=a)
				rev;
		by ident noi;
		if a;
		label cal_aah = "calendrier de perception de l'aah selon l'enqu�te emploi";
		label cal_minv = "calendrier de perception de l'aspa selon l'enqu�te emploi";
		run;
	%mend rev;
%rev;

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
