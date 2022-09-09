/****************************************************************************/
/*																			*/
/*							01_imput_effectif								*/
/*								 											*/
/****************************************************************************/

/* Imputation des effectifs des entreprises : tirage aléatoire 				*/

/* En entrée : 	travail.indivi&anr.											*/ 
/*				travail.irf&anr.e&anr.										*/ 
/*				travail.menage&anr.											*/
/* En sortie : 	imput.effectif												*/

/* Ce programme impute des effectifs de taille des entreprises lorsque l'information 
est manquante dans la variable trefen. La nouvelle variable d'effectifs s'appelle effi, 
les valeurs manquantes sont imputées selon la répartition de la variable trefen sur les valeurs non manquantes*/

proc sort data=travail.indivi&anr.; by ident noi; run; 
proc sort data=travail.irf&anr.e&anr.; by ident noi; run; 

data work.effectif;
	merge 	travail.irf&anr.e&anr(keep=ident noi trefen) 
			travail.indivi&anr.(keep=ident noi zsali in=a);
	by ident noi;
	if a;
	effi=input(trefen,2.);
		if effi=00 then effi=0;
	else if effi=01 then effi=1;
	else if effi=02 then effi=3;
	else if effi=03 then effi=6;
	else if effi=11 then effi=10;
	else if effi=12 then effi=20;
	else if effi=21 then effi=50;
	else if effi=22 then effi=100;
	else if effi=31 then effi=200;
	else if effi=32 then effi=250;
	else if effi=41 then effi=500;
	else if effi=42 then effi=1000;
	else if effi=51 then effi=2000;
	else if effi=52 then effi=5000;
	else if effi=53 then effi=10000;
	run;

proc sort data=travail.menage&anr.; by ident; run; 
data imput.effectif;
	merge 	travail.menage&anr. (keep=ident wpela&anr.)
			work.effectif (keep=ident noi zsali effi in=a);
	by ident;
	if a;
	run;


/* pour imputer les valeurs manquantes, on se sert
	de la répartition de effi lorsque la valeur n'est pas
	manquante */
proc freq noprint data=imput.effectif;
	table effi/ out=freq (keep=percent);
	weight wpela&anr.;
	where effi ne .;
	run;
/* la transposition de la table permet de stocker les
résultats plus facilement dans des macrovariables */
proc transpose data=freq out=freq (drop=_name_ _label_); run; 

/* On calcule des fréquences cumulées à partir des fréquences
et on les attribue à des macrovariables */
%macro freq_cumul;
data freq;
	set freq;
	%do i=2 %to 14;
	col&i.=col&i.+col%eval(&i.-1);
			%end;
	%mend;
%freq_cumul;
data _null_;
	set freq;	
		call symput('t1',col1/100);
		call symput('t2',col2/100);
		call symput('t3',col3/100);
		call symput('t4',col4/100);
		call symput('t5',col5/100);
		call symput('t6',col6/100);
		call symput('t7',col7/100);
		call symput('t8',col8/100);
		call symput('t9',col9/100);
		call symput('t10',col10/100);
		call symput('t11',col11/100);
		call symput('t12',col12/100);
		call symput('t13',col13/100);
		call symput('t14',col14/100);
	run;

/* on répartit enfin les valeurs de effi dans les valeurs manquantes
en respectant les fréquences de chaque modalité */
data imput.effectif(keep=ident noi effi);
	set imput.effectif;
		if zsali>0 and effi=. then do; 
		     alea=ranuni(1);
		     effi=1*(alea<=&t1.)+3*(&t1.<alea<=&t2.)+6*(&t2.<alea<=&t3.)
			 +10*(&t3.<alea<=&t4.)+20*(&t4.<alea<=&t5.)+50*(&t5.<alea<=&t6.)
			 +100*(&t6.<alea<=&t7.)+200*(&t7.<alea<=&t8.)+250*(&t8.<alea<=&t9.)
			 +500*(&t9.<alea<=&t10.)+1000*(&t10.<alea<=&t11.)+2000*(&t11.<alea<=&t12.)
			 +5000*(&t12.<alea<=&t13.)+10000*(&t13.<alea<=&t14.);
			end;
		label effi="Effectifs de l'entreprise (après imputation)";
	run;

/* suppression des tables intermédiaires */
proc datasets mt=data library=work kill;run;quit;


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
