*************************************************************************************;
/*																					*/
/*								ARS													*/
/*																					*/
*************************************************************************************;

/* Mod�lisation de l'Allocation de Rentr�e Scolaire					*/
/* En entr�e : modele.baseind 
			   modele.basefam					                 	*/
/* En sortie : modele.basefam                                     	*/

*********************************************************************;
/* 
Plan
A. Calcul du mois de naissance de l'enfant
B. Calcul du montant de l'ARS 
	B.1 Montant de base de l'ARS
	B.2 Plafond de l'ARS
	B.3 Montant de l'ARS diff�rentielle
	B.4 Montant final de l'ARS
*/
********************************************************************;

/**********************************************/
/* A. Calcul du mois de naissance de l'enfant */
/**********************************************/

/* Le mois de naissance des enfants de 5 et 18 ans est essentiel car l'ARS est vers�e en 
fonction de l'�ge de l'enfant en septembre pour la rentr�e. */

proc sort data=modele.baseind(keep=ident_fam naia naim civ quelfic where=(civ='' and quelfic ne 'FIP'))
	out=mois; 
	by ident_fam;
	run;

data mois;
	set mois;
	by ident_fam;
	retain ars_fam;
	age_mois_sept=12*(&anref.-input(naia,4.))+10-input(naim,4.);
	ars=0;
	if age_mois_sept<=&age4_ars.*12 then ars=&rs005.;
	if age_mois_sept<=&age3_ars.*12 then ars=&rs004.;
	if age_mois_sept<=&age2_ars.*12 then ars=&rs003.;
	if age_mois_sept<=&age1_ars.*12 then ars=0;
	if first.ident_fam then ars_fam=0;
	ars_fam=ars_fam+ars; 
	if last.ident_fam;
	run;

/**********************************************/
/* B. Calcul du montant de l'ARS			  */
/**********************************************/

%Macro ARS;
	data tot;
		merge modele.basefam(keep=ident_fam age_enf res_paje) 
			  mois(in=a); 
		by ident_fam;
		if a;
		arsxx=0;

		/********************************/
		/* B.1 Montant de base de l'ARS */
		/********************************/

		arsxx=ars_fam*&bmaf.;
		/*Montant exceptionnel de 1993 � 2000*/
		%if 1993<=&anleg. and &anleg.<=2000 %then %do;
			arsxx=int(ars/&rs003.)*&rs006.;
			%end;

		/********************************/
		/* B.2 Plafond de l'ARS			*/
		/********************************/

		%nb_enf(e_c,0,&age_pf.,age_enf);
		plafond=(&rs001.-&rs002.)+e_c*&rs002.;

		/***************************************/
		/* B.3 Montant de l'ARS diff�rentielle */
		/***************************************/

		/*D�finition: depuis 2002, en cas de l�ger d�passement du plafond, 1 allocation 
		diff�rentielle,	calcul�e en fonction des revenus, peut �tre vers�e*/

		arsdiff=0;
		%if &anleg.>=2002 %then %do;
			if res_paje>plafond then arsdiff=max(0,(arsxx-(res_paje-plafond)));
			%end;
		/*Seuil minimal de versement de l'ARS diff�rentielle*/
		if arsdiff<&seuil_arsdiff. then arsdiff=0; 

		/********************************/
		/* B.4 Montant final de l'ARS  */
		/********************************/
		/*Famille au dessus du plafond*/ 
		if res_paje>plafond then arsxx=0; 
		/*Montant final*/
		arsxx=arsxx+arsdiff; 
		/*Mesure exceptionnelle de 2009 : prime de 150�*/
		arsxx=arsxx+&rs006.*(arsxx>0)*(&anleg.=2009);
		run;
	%Mend ARS;

%ARS;

data modele.basefam; 
	merge modele.basefam(in=a)
	    tot(keep=ident_fam arsxx);
	by ident_fam; 
	if a; 
	if arsxx=. then arsxx=0;
	run;

proc datasets mt=data kill; run; quit;


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
