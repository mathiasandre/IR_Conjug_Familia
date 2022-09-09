/****************************************************************************/
/*																			*/
/*							01_imput_effectif								*/
/*								 											*/
/****************************************************************************/

/* Imputation des effectifs des entreprises : tirage al�atoire 				*/

/* En entr�e : 	travail.indivi&anr.											*/ 
/*				travail.irf&anr.e&anr.										*/ 
/*				travail.menage&anr.											*/
/* En sortie : 	imput.effectif												*/

/* Ce programme impute des effectifs de taille des entreprises lorsque l'information 
est manquante dans la variable trefen. La nouvelle variable d'effectifs s'appelle effi, 
les valeurs manquantes sont imput�es selon la r�partition de la variable trefen sur les valeurs non manquantes*/

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
	de la r�partition de effi lorsque la valeur n'est pas
	manquante */
proc freq noprint data=imput.effectif;
	table effi/ out=freq (keep=percent);
	weight wpela&anr.;
	where effi ne .;
	run;
/* la transposition de la table permet de stocker les
r�sultats plus facilement dans des macrovariables */
proc transpose data=freq out=freq (drop=_name_ _label_); run; 

/* On calcule des fr�quences cumul�es � partir des fr�quences
et on les attribue � des macrovariables */
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

/* on r�partit enfin les valeurs de effi dans les valeurs manquantes
en respectant les fr�quences de chaque modalit� */
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
		label effi="Effectifs de l'entreprise (apr�s imputation)";
	run;

/* suppression des tables interm�diaires */
proc datasets mt=data library=work kill;run;quit;


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
