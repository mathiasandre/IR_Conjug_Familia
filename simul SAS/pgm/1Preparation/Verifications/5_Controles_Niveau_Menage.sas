/****************************************************************************************/
/*																						*/
/*							5_Controles_niveau_menage									*/
/*																						*/
/****************************************************************************************/

/* Identification des m�nages qu'il faudra supprimer ou corriger 						*/
/****************************************************************************************/
/* En entr�e : 	travail.indivi&anr.														*/
/*				travail.irf&anr.e&anr.													*/
/****************************************************************************************/
/* PLAN : 																				*/
/* 1. M�nages qui ne contiennent que des individus EE_CAF ou EE_NRT 					*/
/* 2. Coh�rence de la variable noicon (A)							 					*/
/* 3. Coh�rence de la variable noienf (A)							 					*/
/****************************************************************************************/
/* Remarque : 																			*/
/* - A indique que la correction est automatique dans les pgms de corrections 			*/
/* - M indique un traitement manuel � faire (par exemple modifier un declar)			*/
/****************************************************************************************/


/****************************************************************************************/
/* 1. M�nages qui ne contiennent que des individus EE_CAF ou EE_NRT 					*/
/****************************************************************************************/
/* Retrait des individus EE_NRT qui ont �t� mal filtr�s car on n'a pas acteu6prm=5 */
proc sql;
	create table probleme_NRT as
	(select ident, noi, quelfic	from travail.indivi&anr. as a 
	left outer join (select ident as ident_, lprm, acteu6 as acteu6prm from travail.irf&anr.e&anr.) as b 
	on (a.ident=b.ident_ and lprm="1")
	having (a.quelfic="EE_NRT" and b.acteu6prm ne "5"));
	quit;
/* ERFS 2011 : M�nages 11071110, 22018020, 11022595, 11049988, 11056636 */
/*	ERFS 2012 : 148 observations */
/*  ERFS 2013 : 0 observations ==> RAS*/
/*  ERFS 2014 : 0 observations ==> RAS*/
/*  ERFS 2015 : 0 observations ==> RAS*/
/*  ERFS 2016 : 0 observations ==> RAS*/

/* Individus EE_CAF dont le declar1 est vide */
proc sql;
	create table probleme_CAF as
	(select ident, noi, quelfic, declar1 from travail.indivi&anr.
	having (quelfic="EE_CAF" and declar1 eq ""));
	quit;
/* ERFS 2012 : 1470 observations */
/* ERFS 2013 : 919 observations */
/* ERFS 2014 : 1229 observations */
/* ERFS 2015 : 1180 observations */
/* ERFS 2016 : 1449 observations */

/****************************************************************************************/
/* 2. Coh�rence de la variable noicon (A)							 					*/
/****************************************************************************************/
/* V�rification que le conjoint du conjoint est bien la personne de d�part. */
proc sort data=travail.irf&anr.e&anr.(keep=ident noicon noi where=(noicon ne '')) out=indivAvecConjoint;
	by ident noicon;
	run;
data PbNoicon; 
	merge 	indivAvecConjoint(in=a) 
			travail.irf&anr.e&anr.(keep=ident noi noicon rename=(noicon=noicon2 noi=noicon)) ;
	by ident noicon;
	label noicon2='Conjoint du conjoint';
	if a;
	if noi ne noicon2;
	run;
/* ERFS 2012 : 27000 observations mais seulement 24 pour lesquels on a autre chose qu'un noicon indiqu� 00 */
/* ERFS 2013 : RAS*/
/* ERFS 2014 : 3 observations dont 2 avec un noicon2 non renseign� */
/* ERFS 2015 : 2 observations ou noicon=2 et noicon2=1 */
/* ERFS 2016 : 0 observation apr�s corrections */

/****************************************************************************************/
/* 3. Coh�rence de la variable noienf (A)							 					*/
/****************************************************************************************/
/* Probl�me de coh�rence de noienf */
proc sort data=travail.irf&anr.e&anr.(keep=ident noi:) out=pbNoienf;
	by ident noi;
	run;
data pbNoienf2;
	set pbNoienf (where=(noienf01 ne ''));
	array noienf $ noienf01 noienf02 noienf03 noienf04 noienf05 noienf06 noienf07 noienf08 noienf09 noienf10 noienf11 noienf12 noienf13 noienf14;
	if input(noienf01,4.)=input(noi,4.) or input(noienf01,4.)=input(noicon,4.);
	run;
/* ERFS 2012 : 287 observations */
/* ERFS 2013 : 0 observations */
/* ERFS 2014 : 15 observations */
/* ERFS 2015 : 0 observations */
/* ERFS 2016 : 0 observations apr�s corrections*/


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
