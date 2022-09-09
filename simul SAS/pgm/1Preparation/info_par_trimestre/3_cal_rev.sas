/****************************************************************************/
/*																			*/
/*							3_cal_rev										*/
/*								 											*/
/****************************************************************************/

/****************************************************************************/
/* Constitution d'un calendrier trimestriel individuel de réponses à l'EE	*/
/* En entrée : 	travail.irf&anr.e&anr.										*/ 
/*				travail.infos_trim (créée dans 3_recup_infos_trim)						*/
/*				travail.cal_indiv											*/
/* En sortie : 	travail.cal_indiv											*/
/****************************************************************************/


/* On ne garde que les individus d'au moins 16 ans, à qui les questions de calendriers sont posées */
proc sort data=travail.irf&anr.e&anr.(keep=ident noi naia where=(&anref.-input(naia,4.)>15)) out=irfAdultes; by ident noi; run;

/* On crée une variable de calendrier pour chaque variables de &rc1. avec l'historique de perception de ces transferts.*/
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

		/* On itère sur chaque trimestre d'enquête */ 
		%let l=1;
		%do %while(%scan(&liste_trim.,&l.)> );
			%let trim=%scan(&liste_trim.,&l.);
		    %let l=%eval(&l.+1);

			if datqi_&trim. ne '' then do;
				/* on récupère l'année et le mois de chaque interrogation */
				ancoll=		input(substr(datqi_&trim.,1,4),4.);
				moiscoll=	input(substr(datqi_&trim.,5,2),4.);

				place=12*(%eval(&anref.+1)-ancoll)+12-moiscoll+1;

				/* On code une indicatrice pour chaque mois où l'individu a perçu un des transferts de rc1 */
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
		label cal_aah = "calendrier de perception de l'aah selon l'enquête emploi";
		label cal_minv = "calendrier de perception de l'aspa selon l'enquête emploi";
		run;
	%mend rev;
%rev;

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
