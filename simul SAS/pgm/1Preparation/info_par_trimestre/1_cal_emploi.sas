/********************************************************************************************/
/*																							*/
/*									1_cal_emploi											*/
/*								 															*/
/********************************************************************************************/

/************************************************************************************************/
/* Constitution d'un récapitualif individuel trimestriel des réponses à l'enquête emploi 		*/
/* En entrée : 	travail.infos_trim (créée dans 3_recup_infos_trim)											*/
/*				travail.irf&anr.e&anr.															*/ 
/* En sortie : 	travail.cal_indiv																*/
/************************************************************************************************/
/* PLAN :																						*/
/* A. Initialisation de calend0 uniquement à partir des variables SPxx							*/
/* B. Enrichissement de calend0 avec toutes les variables de &liste. -> calend1					*/
/* C. Enrichissement de calend1 avec toutes les variables de &ancien. -> calend2				*/
/* D. Enrichissement de calend2 en bouchant les trous avec ce qui suit/précède -> cal_activite	*/
/************************************************************************************************/
/* Remarques : 																					*/
/* On choisit d'utiliser ancchomm (durée au chomage) plutôt que drem (durée de recherche 		*/
/*	d'emploi) pour définir le calendrier puisque cette durée est plus pertinentes pour le 		*/
/*	calcul des cotisations+CSG et pour trimestrialiser les ressources.							*/
/************************************************************************************************/


/* Liste des variables EE pertinentes pour le calendrier sur l'emploi */
%let liste=acteu6 RETOUPRERET amois adfdap; 
%let ancien=ancentr ancinatm ancchomm;

/********************************************************************************************/
/* A. Initialisation de calend0 à partir des variables sp: 									*/
/********************************************************************************************/

/* On ne garde que les individus d'au moins 16 ans, à qui les questions de calendriers sont posées */
proc sort data=travail.irf&anr.e&anr.(keep=ident noi naia where=(&anref.-input(naia,4.)>15)) out=irfAdultes; by ident noi; run;
%macro sp;
	data sp(drop= sp: statu ancoll moiscoll);
		merge 	travail.infos_trim(rename=(ident&anr.=ident)) 
				irfAdultes(in=a);
		by ident noi;
		if a;

		/* On crée une variable dans laquelle chaque caractère correspond à un mois, le premier étant le mois 
		le plus récent (décembre de &anref+1) et ensuite en ordre antichronologique (le second est 
		novembre &anref+1). On remonte jusqu'à quatre ans en arrière (janvier &anref-2), ce qui fait 60 caractères. */
		format calend0 $60.; 
		calend0='000000000000000000000000000000000000000000000000000000000000';

		/* On itère sur chaque trimestre d'enquête */ 
		%let l=1;
		%do %while(%scan(&liste_trim.,&l.)> );
			%let trim=%scan(&liste_trim.,&l.);
		    %let l=%eval(&l.+1);
			if datqi_&trim. ne '' then do;
				/* on récupère l'année et le mois de chaque interrogation */
				ancoll=		input(substr(datqi_&trim.,1,4),4.);
				moiscoll=	input(substr(datqi_&trim.,5,2),4.);

				%do i=0 %to 11; 
					place=12*(%eval(&anref.+1)-ancoll)+12-moiscoll+1+&i.;
					%if &i.<10 %then %do;
						statu=sp0&i._&trim.;
						%end; 
					%else %do; 
						statu=sp&i._&trim.;
						%end;
					/* recodification des variables SPxx selon les modalités de la dernière codification en vigueur : EEC 2013 */
					/* 1. recodage de la nomenclature avant 2008 comme 2013 */ 
					if ancoll<2008 then do;
						if statu in ('1','2','3','6') then statu='1';/*salarié */
						if statu in ('5') then statu='3';			/* Études ou stage non rémunéré */
						if statu in ('4') then statu='4';			/* Chômage (inscrit ou non à Pôle Emploi) */
						if statu in ('7') then statu='5';			/* Retraite ou préretraite*/
						if statu in ('8') then statu='7';			/* Au foyer*/
						if statu in ('9') then statu='9';			/* Autre situation (sous entendu d'inactivité) */
						end;
					/* 2. recodage de la nomenclature en vigueur entre 2008 et 2012 comme 2013 */
					else if ancoll<2013 then do;
						if statu in ('1') then statu='1';			/*salarié */
						if statu in ('2') then statu='3';			/* Études ou stage non rémunéré */
						if statu in ('3') then statu='4';			/* Chômage (inscrit ou non à Pôle Emploi) */
						if statu in ('4') then statu='5';			/* Retraite ou préretraite*/
						if statu in ('5') then statu='7';			/* Au foyer*/
						if statu in ('6') then statu='9';			/* Autre situation (sous entendu d'inactivité) */
						end;
				   	%calend(calend0,statu,place,1);
					%end;
				end;
			%end;
		output sp;
		run;
	%mend sp;
%sp;

/********************************************************************************************/
/* B. Enrichissement de calend0 avec toutes les variables de &liste. : calend1				*/
/********************************************************************************************/
/* On crée une variable de calendrier pour chaque variables de &liste. avec l'historique de ces variables. 
Comme il s'agit ici d'informations individuelles au moment de l'enquête et non retrospective, la variable
de calendrier est moins longue : on va du début de T1 de &anref.-1 à la fin de T3 de &anref+1 ce qui fait 
12 trimestres et 36 mois qu'on complète à 40 mois pour finir &anref+1 et avoir une correspondance simple avec calend.*/
%macro acteu;
	data enrichi(drop=i);
		set sp;
		/* Initialisation des variables de calendrier */
		format %do i=1 %to %sysfunc(countw(&liste.)); cal_%scan(&liste.,%eval(&i.)) %end; $40.;
		%do i=1 %to %sysfunc(countw(&liste.)); 
			cal_%scan(&liste,%eval(&i.))='0000000000000000000000000000000000000000';
			%end;

		/* On itère sur chaque trimestre d'enquête */ 
		%let l=1;
		%do %while(%scan(&liste_trim.,&l.)> );
			%let trim=%scan(&liste_trim.,&l.);
			%if &l.>1 %then %do; %let trim_1=%scan(&liste_trim.,%eval(&l.-1));;%end;
		    %let l=%eval(&l.+1);

			if datqi_&trim. ne '' then do;
				/* on récupère l'année et le mois de chaque interrogation */
				ancoll=		input(substr(datqi_&trim.,1,4),4.);
				moiscoll=	input(substr(datqi_&trim.,5,2),4.);

				/* Recodification de la variable acteu6 pour avoir les mêmes modalités que les SPxx (qui constituent calend0) */
				if acteu6_&trim. in ('1') then acteu6_&trim.='1';		/* Salarié */ 
				if acteu6_&trim. in ('5') then acteu6_&trim.='3';		/* Études ou stage non rémunéré */
				if acteu6_&trim. in ('3','4') then acteu6_&trim.='4';	/* Chômage (inscrit ou non à Pôle Emploi) */
				if acteu6_&trim. in ('6') then acteu6_&trim.='9';		/* Autre situation (sous entendu d'inactivité)  */
			
				/* On remplit les variables de calendrier */
				place=12*(%eval(&anref.+1)-ancoll)+12-moiscoll+1;
				%do i=1 %to %sysfunc(countw(&liste.)); 
					%let variable=%scan(&liste.,%eval(&i.));
			   		%calend(cal_&variable.,&variable._&trim.,place,1);
					%end;
				end;
			%end;

		/* Construction de calend1 à partir de calend0 en enrichissant avec les variables de &liste */
		calend1=calend0;
		do i=1 to 40; 
			/* Retraite ou préretraite au mois i : lorsque l'information d'activité était manquante ('0' ou ' '), 
			l'individu est considéré comme retraité pour tous les mois postérieurs (donc les positions 
			avant &i. dans le calendrier d'activité) */
			if substr(cal_RETOUPRERET,i,1) in ('1','2') then do; 
				do k=1 to i;
					if substr(calend1,k,1) in ('0',' ') then do; substr(calend1,k,1)='5'; end;
					end;
				end;
			/* Remplissage de calend1 lorsque l'on a l'information dans acteu6 */
			if substr(calend1,i,1) in ('0',' ') & substr(cal_acteu6,i,1) ne '0' then do; 			
				substr(calend1,i,1)=substr(cal_acteu6,i,1);
				end;
			end; 
		drop acteu6: place ancoll moiscoll;
	run;
	%mend acteu; 
%acteu;

/********************************************************************************************/
/* C. Enrichissement de calend1 avec les infos de la liste &ancien. -> calend2				*/
/*    (ancienneté dans l'emploi, le chômage et l'inactivité) 								*/
/********************************************************************************************/
%macro anciennete;
	data enrichi2(keep=ident noi naia calend: cal:);
		set enrichi;

		/* Initialisation des variables de calendrier */
		format %do i=1 %to %sysfunc(countw(&ancien.)); cal_%scan(&ancien.,%eval(&i.)) %end; $60.;
		%do i=1 %to %sysfunc(countw(&ancien.)); 
			cal_%scan(&ancien.,%eval(&i.))='000000000000000000000000000000000000000000000000000000000000';
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
				/* remplissage des 3 calendriers (1 par situation) de façon binaire :
				1 lorsque de l'anciennenté déclarée est strictement positive, 0 sinon */
				%do i=1 %to %sysfunc(countw(&ancien.)); 
					%let variable=%scan(&ancien.,%eval(&i.));
				 	if &variable._&trim. not in (0,.,-1) then do; 	
						do k=1 to min(60,&variable._&trim.);
							place=12*(%eval(&anref.+1)-ancoll)+12-moiscoll+1 + k;
							%calend(cal_&variable.,'1',place,1);
							end;
						end; 
				 	%end;
				/* On substitue le statut en retraite dans calend1 en utilisant l'ancienneté en tant que retraité */
				if (RETOUPRERET_&trim.='1' ! index(calend1,'5')>0) & adfdap_&trim. ne '' then do; 
					anret=	input(adfdap_&trim.,4.);
					moisret=sum(input(amois_&trim.,4.),0);
					place_ret=12*(%eval(&anref.+1)-anret)+12-moisret+1;
					place=12*(%eval(&anref.+1)-ancoll)+12-moiscoll+1;
					do j=max(place+1,1) to min(place_ret,59);
						substr(calend1,j,1)='5';
						end;
					end;
				end;
			%end;

		calend2=calend1;
		do i=1 to 60;
			if substr(calend2,i,1) in ('0',' ') then do;
				if substr(cal_ancinatm,i,1)='1' then substr(calend2,i,1)='7'; 	/* inactivité (pourquoi 7 en particulier?) */
				if substr(cal_ancchomm,i,1)='1' then substr(calend2,i,1)='4';	/* Chômage (inscrit ou non à Pôle Emploi) */
				if substr(cal_ancentr,i,1)='1' then substr(calend2,i,1)='1';	/* Salarié */
				end;
			/* on efface les blancs dûs aux variables manquantes */ 
			if substr(calend2,i,1)=' ' then do;
				substr(calend2,i,1)='0';
				end;
			end;
		run;
	%mend anciennete;
%anciennete;

/********************************************************************************************/
/* D. Construction de calend3 à partir de calend2 en bouchant les trous intermédiaires		*/
/********************************************************************************************/
/* On complète désormais les valeurs non renseignées (0) qui ne sont pas en tête ni en fin de calendrier : 
on n'a pas d'information dans l'EE pour ces mois-là.*/ 
data travail.cal_indiv (keep=ident noi cal_activite); 
	set enrichi2;
	cal_activite=calend2;
	do i=1 to 59;
		if substr(cal_activite,i,1) ne '0' &  substr(cal_activite,i+1,1)='0' then do; 
			apres=substr(cal_activite,i,1); /* On remonte dans le temps dans calend */
			avant=substr(cal_activite,i+1,1);
			mois_ap=i+1;
			do while (avant='0' & i<59); 
				i=i+1;
				avant=substr(cal_activite,i+1,1);
				end;
			/* De mois_ap à i inclus, on a 0 dans le calendrier : on remplit la moitié de ces mois avec l'activité de avant et
				l'autre moitié avec l'activité de apres */	
			do k=0 to round((i-mois_ap)/2,1);
				substr(cal_activite,mois_ap+k,1)=apres;
				end; 
			do k=round((i-mois_ap)/2,1) to i-mois_ap;
				substr(cal_activite,mois_ap+k,1)=avant;
				end;
			end;
		end;
	/* On ajuste les 7 qui sont encerclés par une même valeur d'inactivité. */
	do j=1 to 59;
		if substr(cal_activite,j,1) not in ('0','7') &  substr(cal_activite,j+1,1)='7' then do; 
			apres=substr(cal_activite,j,1);
			avant=substr(cal_activite,j+1,1);
			mois_ap=j+1;
			do while (avant='7' & j<59); 
				j=j+1;
				avant=substr(cal_activite,j+1,1);
				end;	
			if avant=apres then do; 
				do l=mois_ap to j;
					substr(cal_activite,l,1)=avant;
					end;
				end;
			end;
		end;
	label cal_activite="calendrier d'activité mensuel reconstitué à partir de l'enquête emploi";
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
