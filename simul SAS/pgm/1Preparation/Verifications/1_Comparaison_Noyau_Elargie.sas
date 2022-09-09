/****************************************************************************/
/*																			*/
/*  Ce programme compare les ERFS noyau et élargie pour une année donnée	*/
/*																			*/
/****************************************************************************/

/* Ce programme : 
	- est complètement indépendant de l'enchaînement d'Ines
	- est à faire tourner à chaque réception d'une nouvelle ERFS élargie (pour les anref<=2012)
	- a pour objectif de détecter le plus tôt possible des éventuelles erreurs de production de l'ERFS élargie */

/* On compare une ERFS noyau et une ERFS élargie, POUR UNE MEME ANNEE */
/* Si l'on souhaite comparer plusieurs noyaux ou plusieurs élargies entre elles, il faut faire tourner l'autre programme */

/* En entrée : librairies RPM et CD contenant les ERFS noyau et élargie livrées par RPM à l'automne de l'année N+2 */
/* En sortie : fichiers Excel vérifiant la bonne qualité									*/

/* PLAN
	1	Liste des variables (à réexploiter dans l'Excel)
	2	Nombre d'individus et de ménages en pondéré
	3	Agrégats en pondéré
	4	Comparaison de moyennes entre noyau et élargi pour les loyers imputés
*/

options mprint nosymbolgen nomlogic;
%let excel=xls;
%let chemin_bases=X:\HAB-INES\Tables INES;	/* A compléter (chemin des librairies cd et rpm) */
%let chemin_verif=Z:\Verif_ERFS; /* A compléter (chemin des fichiers de sortie) */
%let annee_ERFS=2012;
 
/*********************************************************/
/* 1	Liste des variables (à réexploiter dans l'Excel) */
/*********************************************************/

%macro Comparaison_Noy_Ela(annee=&annee_ERFS.,export=oui,videWork=oui);

	/* Pour trois tables d'intérêt, on compare le nombre d'observations et la liste des variables */

	%let a=%substr(&annee_ERFS.,3,2);
	libname LibNoy "&chemin_bases.\ERFS &annee_ERFS.\noyau";
	libname LibEla "&chemin_bases.\ERFS &annee_ERFS.\elargi";
	/* Dans les deux listes ci-dessous, le ième élément de la liste 1 est à comparer avec le ième élément de la liste 2 */
	%let ListeNoy=foyer&a. irf&a.e&a.t4 mrf&a.e&a.t4 menage&a. indivi&a. ;
	%let ListeEla=foyer&a._ela irf&a.e&a.t4 mrf&a.e&a.t4 men&annee_ERFS._ela indiv&annee_ERFS._ela ;

	%do i=1 %to %sysfunc(countw(&ListeNoy.));
		%let t1=LibNoy.%scan(&ListeNoy.,&i.);
		%let t2=LibEla.%scan(&ListeEla.,&i.);
		proc contents data=&t1. out=temp1(keep=name label) noprint; run;
		proc contents data=&t2. out=temp2(keep=name label) noprint; run;
		data temp1; set temp1; name=upcase(name); run;
		data temp2; set temp2; name=upcase(name); run;
		proc sort data=temp1; by name; run;
		proc sort data=temp2; by name; run;
		data temp_%scan(&ListeNoy.,&i.); merge temp1(in=a) temp2(in=b); by name; Presence_Noy=a; Presence_Ela=b; run;

		%if &export. = oui %then %do;
			proc export data=temp_%scan(&ListeNoy.,&i.) outfile="&chemin_verif.\Comparaison_Variables_Noy_Ela_&annee." dbms=&excel. replace; sheet="%scan(&ListeNoy.,&i.)"; run;
			%end;
		%end;
	%if &videWork. = oui %then %do;
		proc delete data=temp1 temp2 temp_foyer&a. temp_irf&a.e&a.t4 temp_menage&a.; run;
		%end;
	%mend Comparaison_Noy_Ela;

%Comparaison_Noy_Ela(annee=2012);


/****************************************************/
/*	2	Nombre d'individus et de ménages en pondéré */
/****************************************************/

%let a=%substr(&annee_ERFS.,3,2);
proc means data=LibNoy.indivi&a. sum;
	var wprm;
	output out=temp1 sum=NbIndNoy;
	run;
/* 2011 : 61 874 829 */
/* 2012 : 62 133 003 */
proc means data=LibNoy.menage&a. sum;
	var wprm;
	output out=temp1 sum=NbIndNoy;
	run;
/* 2011 : 27 617 531 */
/* 2012 : 27 796 133 */
proc means data=LibEla.indiv&annee_ERFS._ela sum;
	var wpela;
	run;
/* 2011 : 61 874 829 */
/* 2012 : 62 127 212 */
proc means data=LibEla.men&annee_ERFS._ela sum;
	var wpela;
	run;
/* 2011 : 27 617 479 */
/* 2012 : 27 793 469 */


/****************************/
/*	3	Agrégats en pondéré */
/****************************/

proc means data=LibNoy.menage&a. sum;
	var revdecm ztsam zsalm zchom zperm zrtom zretm zrstm zalrm zalvm zricm zrncm zragm
	zfonm zvamm zvalm zetrm zdivm zquom zglom zavfm; *zaccm zimpvalm zthabm;
	weight wprm;
	output out=temp1;
	run;
proc means data=LibEla.men&annee_ERFS._ela sum;
	var revdecm ztsam zsalm zchom zperm zrtom zretm zrstm zalrm zalvm zricm zrncm zragm
	zfonm zvamm zvalm zetrm zdivm zquom zglom zavfm; *zaccm zimpvalm zthabm;
	weight wpela;
	output out=temp2;
	run;

/* 2012 : écarts > 2 %
VariableLabel											Ela					Noy	
zalrm	Pensions alimentaires reçues du ménage			4 775 174 281		4 647 104 851	2,76%
zricm	Revenus ind, et commerciaux du ménage			16 265 916 097		15 676 685 116	3,76%
zrncm	Revenus non commerciaux du ménage				30 057 781 109		30 818 137 009	-2,47%
zvalm	Revenu déclaré de val, mob soumises au prél lib	12 232 428 507		11 420 663 268	7,11%
zetrm	Revenus de l étranger du ménage					3 297 081 945		3 414 294 131	-3,43%
zdivm	Plus-values et gains divers du ménage			3 699 034 591		5 288 279 864	-30,05%
zquom	Revenus imposés au quotient du ménage			472 367 939			423 155 729		11,63%
zglom	Gains de levée d'options du ménage				594 549 860			483 392 078		23,00%
zavfm	Avoirs fiscaux du ménage						56 494 178			75 412 953		-25,09%
*/


/* 4	Comparaison de moyennes entre noyau et élargi pour les loyers imputés */

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
