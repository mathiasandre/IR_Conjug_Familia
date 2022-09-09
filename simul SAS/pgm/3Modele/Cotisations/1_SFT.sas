/****************************************************************************************/
/*																						*/
/*										1_SFT											*/
/*																						*/
/****************************************************************************************/
/*																						*/
/* Ce programme d�termine l'�ligibilit� au Suppl�ment Familial de Traitement et le 		*/
/* nombre d'enfants associ�s. 															*/
/*																						*/
/* En entr�e : 	modele.baseind                                    						*/
/*				modele.basefam                                    						*/ 
/*				base.baserev                                     						*/
/* En sortie :  modele.baseind                                    						*/
/****************************************************************************************/
/* PLAN : 																				*/
/*	1. Calcul du nombre d'enfants														*/
/*	2. S�lection des potentiels candidats au SFT										*/
/*	3. Rep�rage du b�n�ficiaire dans le couple : le mieux r�mun�r�						*/
/****************************************************************************************/


/*********************************/
/* 1. Calcul du nombre d'enfants */
/*********************************/
proc sort data=modele.baseind(keep=ident noi civ ident_fam quelfic sftd where=(quelfic ne 'FIP')) out=baseind; by ident_fam; run; /* les FIP n'ont pas de famille au sens de la CAF */
proc sort data=modele.basefam(keep=ident_fam age_enf) out=basefam; by ident_fam; run; /* Familles au sens des prestations familiales */
data NBenfants; 
	merge	baseind 
			basefam; 
	by ident_fam; 
	%nb_enf(nb_enfant,0,&age_PF.,age_enf); /* nb_enfant donne le nb d'enfants � charge au sens des PF */
	run;


/************************************************/
/* 2. S�lection des potentiels candidats au SFT	*/
/************************************************/
proc sort data=NBenfants; by ident noi; run; 
proc sort data=base.baserev(keep=ident noi zsali&anr2.) out=baserev; by ident noi; run; 
data fonx;
	merge	baserev  
			NBenfants (in=a where=(nb_enfant>0));
	by ident noi;
	if a & sftd=1;
	run;
proc sort data=fonx; by ident_fam; run;


/*******************************************************************/
/* 3. Rep�rage du b�n�ficiaire dans le couple : le mieux r�mun�r�  */
/*******************************************************************/
data fam(keep=ident_fam bensft coupf);
	set fonx;
	by ident_fam;
	retain salm salf coupf;
	if first.ident_fam then do;
		salm=0;
		salf=0;
		coupf=0;
		end;
	if civ='mon' then do;
		salm=zsali&anr2.;
		coupf=coupf+1;
		end;
	if civ='mad' then do;
		salf=zsali&anr2.;
		coupf=coupf+1;
		end;
	if last.ident_fam then do;
		if coupf=2 & salm>salf then bensft='mon';
		else if coupf=2 then bensft='mad';
		output;
		end;
	run;

data fonx(keep=ident noi NbEnf_SFT);
	merge fonx fam;
	by ident_fam;
	if civ in ('mon' 'mad') then NbEnf_SFT=nb_enfant; /* Le filtre if civ in ('mon' 'mad') permet de ne pas attribuer du SFT � des enfants fonctionnaires */
	else NbEnf_SFT = 0;
	if coupf=2 & civ^=bensft then NbEnf_SFT=0; /* on retire la charge des enfants au plus faible salaire */
	run;

proc sort data=modele.baseind; by ident noi; run;
proc sort data=fonx; by ident noi; run;
data modele.baseind;
	merge 	modele.baseind (in=a)
			fonx;
	by ident noi;
	if a;
	if NbEnf_SFT=. then NbEnf_SFT=0;
	label nbenf_SFT="Nombre d'enfants pour le calcul du suppl�ment familial de traitement";
	run;



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
