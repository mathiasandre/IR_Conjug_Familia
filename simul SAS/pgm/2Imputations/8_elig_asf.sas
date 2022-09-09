/************************************************************************************/
/*																					*/	
/*       				 8_elig_asf													*/
/*																					*/
/************************************************************************************/

/* Identification des �ligibles � l'ASF			                	*/
/********************************************************************/
/* En entr�e : modele.basefam										*/
/*			   modele.baseind										*/	
/* En sortie : modele.basefam                    	                  	*/
/********************************************************************/
/* PLAN : 															*/
/* 1. rep�rage des veufs											*/
/* 2. rep�rage des familles potentiellement b�n�ficiaires			*/
/* 3. cr�ation de cat�gories d'�ligibles potentiels par nombre 		*/
/* d'enfants � charge et d'un al�a									*/
/* 4. d�termination des b�n�ficiaires en fonction de l'al�a         */
/********************************************************************/
/* REMARQUES : 																		*/
/* Dans la l�gislation, il y a deux types de b�n�ficiaires de l'ASF :				*/
/*	- des familles de parents isol�s, veufs (a) ou en d�ficit de pension 			*/
/* alimentaire (b) (ASF � 22,5% de la Bmaf)											*/
/*	- des enfants orphelins des deux parents (ASF � 30% de la Bmaf) : situation non */
/* trait�e pour l'instant															*/
/* (a) les parents veufs															*/
/* HYPOTHESE : les parents veufs sans pension alimentaire sont consid�r�s comme 	*/
/* veufs de l'autre parent et sont donc tous �ligibles � l'ASF : le tirage sera 	*/
/* con�u de telle fa�on qu'ils seront tous b�n�ficiaires 							*/
/* (b) les parents isol�s															*/
/* HYPOTHESES : comme on ne connait pas les droits � pensions alimentaires des 		*/
/*	parents isol�s, on consid�re que :												*/
/* - il n'y a pas de paiement partiel de pension : ceux qui per�oivent une pension 	*/
/* n'ont pas de droits � l'ASF														*/
/* - il existe des d�fauts de pension (dans son int�gralit�) : on tire al�atoirement*/
/* un nombre de b�n�ficiaires parmi une population de parents isol�s ne percevant 	*/
/* pas de pension																	*/


/********************************************************************/
/* 1. rep�rage des veufs 											*/
/********************************************************************/
data veuf(keep=ident_fam); /* On garde les veufs selon l'EE et selon les d�clarations fiscales*/
	set modele.baseind; 
	if civ in ('mon','mad') & (matri='3' ! substr(declar1,13,1)='V' ! substr(declar2,13,1)='V');
	run;
proc sort data=veuf; by ident_fam; run;

/********************************************************************/
/* 2. rep�rage des familles potentiellement b�n�ficiaires 			*/
/********************************************************************/
data asf; 
	merge 	modele.basefam (keep=ident_fam age_enf pensrecu pers_iso wpela&anr2.)
			veuf(in=a); 
	by ident_fam;
	%nb_enf(e_c,0,&age_pf.,age_enf);
	if pers_iso=1 & substr(ident_fam,9,1) ne '9' & e_c;
	/* Avant 2016 les personnes recevant une pension n'�taient pas �ligibles � l'ASF (sauf en cas de non paiement).
	Depuis 2016 si cette pension est inf�rieure au montant de l'ASF, ces personnes sont �ligibles et per�oivent la diff�rence entre l'ASF et leur pension
	au titre de l'ASF. */
	if &anleg.<2016 then do;
		if a then do;
			veuf=1;
			if pensrecu=0 then possible_asf=1; /* On introduit possible_asf par n�cessit� de code, pour pouvoir introduire le else delete qui suit */
			else delete;
			end;
		if not a then do;
			veuf=0;
			if pensrecu=0 then possible_asf=1;
			else delete;
			end; 
		end;
	if &anleg.>=2016 then do;
		if a then do;
			veuf=1;
			if pensrecu<=&asf1.*&bmaf.*e_c then possible_asf=1; 
			else delete;
			end;
		if not a then do;
			veuf=0;
			if pensrecu<=&asf1.*&bmaf.*e_c then possible_asf=1;
			else delete;
			end; 
		end;
	run; 

/********************************************************************/
/* 3. cr�ation de cat�gories d'�ligibles potentiels par nombre 		*/
/* d'enfants � charge et d'un al�a 									*/
/********************************************************************/
data asf; 
	set asf;
	length tri $1;
    if e_c=1 then tri='1';
	else if e_c=2 then tri='2';
	else if e_c=3 then tri='3';
	else tri='4';
	alea=ranuni(1);
	run;
/* tri de la base des �ligibles potentiels. Au sein de chaque cat�gorie, le tri est
- decsendant par le crit�re veuf car ils doivent tous �tre b�n�ficiaires
- descendant selon l'al�a pour s�lectionner le reste des b�n�ficiaires  */
proc sort data=asf; by tri descending veuf descending alea; run;

/********************************************************************/
/* 4. d�termination des b�n�ficiaires en fonction de l'al�a 		*/
/********************************************************************/
data asf; 
	set asf;
	by tri;
	elig_asf='oui';
	retain ben;
	if first.tri then ben=0;
	ben=ben+wpela&anr2.;
	if tri='1' & ben > &tirage_asf1. then elig_asf='non';
	if tri='2' & ben > &tirage_asf2. then elig_asf='non';
	if tri='3' & ben > &tirage_asf3. then elig_asf='non';
	if tri='4' & ben > &tirage_asf4. then elig_asf='non';
	run;

/****************************************************************************/
/* 5. Rajout de la variable elig_asf dans modele.basefam					*/
/****************************************************************************/
proc sort data=modele.basefam; by ident_fam; run;
proc sort data=asf(keep=ident_fam elig_asf); by ident_fam; run;
data modele.basefam;
	merge 	modele.basefam(in=a)
			asf(in=b);
	by ident_fam;
	if a;
	if not b then elig_asf='non';
	label elig_asf="Famille �ligible � l'ASF";
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
