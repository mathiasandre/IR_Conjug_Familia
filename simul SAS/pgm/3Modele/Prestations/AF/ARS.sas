*************************************************************************************;
/*																					*/
/*								ARS													*/
/*																					*/
*************************************************************************************;

/* Modélisation de l'Allocation de Rentrée Scolaire					*/
/* En entrée : modele.baseind 
			   modele.basefam					                 	*/
/* En sortie : modele.basefam                                     	*/

*********************************************************************;
/* 
Plan
A. Calcul du mois de naissance de l'enfant
B. Calcul du montant de l'ARS 
	B.1 Montant de base de l'ARS
	B.2 Plafond de l'ARS
	B.3 Montant de l'ARS différentielle
	B.4 Montant final de l'ARS
*/
********************************************************************;

/**********************************************/
/* A. Calcul du mois de naissance de l'enfant */
/**********************************************/

/* Le mois de naissance des enfants de 5 et 18 ans est essentiel car l'ARS est versée en 
fonction de l'âge de l'enfant en septembre pour la rentrée. */

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
		/*Montant exceptionnel de 1993 à 2000*/
		%if 1993<=&anleg. and &anleg.<=2000 %then %do;
			arsxx=int(ars/&rs003.)*&rs006.;
			%end;

		/********************************/
		/* B.2 Plafond de l'ARS			*/
		/********************************/

		%nb_enf(e_c,0,&age_pf.,age_enf);
		plafond=(&rs001.-&rs002.)+e_c*&rs002.;

		/***************************************/
		/* B.3 Montant de l'ARS différentielle */
		/***************************************/

		/*Définition: depuis 2002, en cas de léger dépassement du plafond, 1 allocation 
		différentielle,	calculée en fonction des revenus, peut être versée*/

		arsdiff=0;
		%if &anleg.>=2002 %then %do;
			if res_paje>plafond then arsdiff=max(0,(arsxx-(res_paje-plafond)));
			%end;
		/*Seuil minimal de versement de l'ARS différentielle*/
		if arsdiff<&seuil_arsdiff. then arsdiff=0; 

		/********************************/
		/* B.4 Montant final de l'ARS  */
		/********************************/
		/*Famille au dessus du plafond*/ 
		if res_paje>plafond then arsxx=0; 
		/*Montant final*/
		arsxx=arsxx+arsdiff; 
		/*Mesure exceptionnelle de 2009 : prime de 150€*/
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
