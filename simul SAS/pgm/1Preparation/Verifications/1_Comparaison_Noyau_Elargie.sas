/****************************************************************************/
/*																			*/
/*  Ce programme compare les ERFS noyau et �largie pour une ann�e donn�e	*/
/*																			*/
/****************************************************************************/

/* Ce programme : 
	- est compl�tement ind�pendant de l'encha�nement d'Ines
	- est � faire tourner � chaque r�ception d'une nouvelle ERFS �largie (pour les anref<=2012)
	- a pour objectif de d�tecter le plus t�t possible des �ventuelles erreurs de production de l'ERFS �largie */

/* On compare une ERFS noyau et une ERFS �largie, POUR UNE MEME ANNEE */
/* Si l'on souhaite comparer plusieurs noyaux ou plusieurs �largies entre elles, il faut faire tourner l'autre programme */

/* En entr�e : librairies RPM et CD contenant les ERFS noyau et �largie livr�es par RPM � l'automne de l'ann�e N+2 */
/* En sortie : fichiers Excel v�rifiant la bonne qualit�									*/

/* PLAN
	1	Liste des variables (� r�exploiter dans l'Excel)
	2	Nombre d'individus et de m�nages en pond�r�
	3	Agr�gats en pond�r�
	4	Comparaison de moyennes entre noyau et �largi pour les loyers imput�s
*/

options mprint nosymbolgen nomlogic;
%let excel=xls;
%let chemin_bases=X:\HAB-INES\Tables INES;	/* A compl�ter (chemin des librairies cd et rpm) */
%let chemin_verif=Z:\Verif_ERFS; /* A compl�ter (chemin des fichiers de sortie) */
%let annee_ERFS=2012;
 
/*********************************************************/
/* 1	Liste des variables (� r�exploiter dans l'Excel) */
/*********************************************************/

%macro Comparaison_Noy_Ela(annee=&annee_ERFS.,export=oui,videWork=oui);

	/* Pour trois tables d'int�r�t, on compare le nombre d'observations et la liste des variables */

	%let a=%substr(&annee_ERFS.,3,2);
	libname LibNoy "&chemin_bases.\ERFS &annee_ERFS.\noyau";
	libname LibEla "&chemin_bases.\ERFS &annee_ERFS.\elargi";
	/* Dans les deux listes ci-dessous, le i�me �l�ment de la liste 1 est � comparer avec le i�me �l�ment de la liste 2 */
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
/*	2	Nombre d'individus et de m�nages en pond�r� */
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
/*	3	Agr�gats en pond�r� */
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

/* 2012 : �carts > 2 %
VariableLabel											Ela					Noy	
zalrm	Pensions alimentaires re�ues du m�nage			4�775�174�281		4�647�104�851	2,76%
zricm	Revenus ind, et commerciaux du m�nage			16�265�916�097		15�676�685�116	3,76%
zrncm	Revenus non commerciaux du m�nage				30�057�781�109		30�818�137�009	-2,47%
zvalm	Revenu d�clar� de val, mob soumises au pr�l lib	12�232�428�507		11�420�663�268	7,11%
zetrm	Revenus de l �tranger du m�nage					3�297�081�945		3�414�294�131	-3,43%
zdivm	Plus-values et gains divers du m�nage			3�699�034�591		5�288�279�864	-30,05%
zquom	Revenus impos�s au quotient du m�nage			472�367�939			423�155�729		11,63%
zglom	Gains de lev�e d'options du m�nage				594�549�860			483�392�078		23,00%
zavfm	Avoirs fiscaux du m�nage						56�494�178			75�412�953		-25,09%
*/


/* 4	Comparaison de moyennes entre noyau et �largi pour les loyers imput�s */

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
