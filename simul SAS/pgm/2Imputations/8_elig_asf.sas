/************************************************************************************/
/*																					*/	
/*       				 8_elig_asf													*/
/*																					*/
/************************************************************************************/

/* Identification des éligibles à l'ASF			                	*/
/********************************************************************/
/* En entrée : modele.basefam										*/
/*			   modele.baseind										*/	
/* En sortie : modele.basefam                    	                  	*/
/********************************************************************/
/* PLAN : 															*/
/* 1. repérage des veufs											*/
/* 2. repérage des familles potentiellement bénéficiaires			*/
/* 3. création de catégories d'éligibles potentiels par nombre 		*/
/* d'enfants à charge et d'un aléa									*/
/* 4. détermination des bénéficiaires en fonction de l'aléa         */
/********************************************************************/
/* REMARQUES : 																		*/
/* Dans la législation, il y a deux types de bénéficiaires de l'ASF :				*/
/*	- des familles de parents isolés, veufs (a) ou en déficit de pension 			*/
/* alimentaire (b) (ASF à 22,5% de la Bmaf)											*/
/*	- des enfants orphelins des deux parents (ASF à 30% de la Bmaf) : situation non */
/* traitée pour l'instant															*/
/* (a) les parents veufs															*/
/* HYPOTHESE : les parents veufs sans pension alimentaire sont considérés comme 	*/
/* veufs de l'autre parent et sont donc tous éligibles à l'ASF : le tirage sera 	*/
/* conçu de telle façon qu'ils seront tous bénéficiaires 							*/
/* (b) les parents isolés															*/
/* HYPOTHESES : comme on ne connait pas les droits à pensions alimentaires des 		*/
/*	parents isolés, on considère que :												*/
/* - il n'y a pas de paiement partiel de pension : ceux qui perçoivent une pension 	*/
/* n'ont pas de droits à l'ASF														*/
/* - il existe des défauts de pension (dans son intégralité) : on tire aléatoirement*/
/* un nombre de bénéficiaires parmi une population de parents isolés ne percevant 	*/
/* pas de pension																	*/


/********************************************************************/
/* 1. repérage des veufs 											*/
/********************************************************************/
data veuf(keep=ident_fam); /* On garde les veufs selon l'EE et selon les déclarations fiscales*/
	set modele.baseind; 
	if civ in ('mon','mad') & (matri='3' ! substr(declar1,13,1)='V' ! substr(declar2,13,1)='V');
	run;
proc sort data=veuf; by ident_fam; run;

/********************************************************************/
/* 2. repérage des familles potentiellement bénéficiaires 			*/
/********************************************************************/
data asf; 
	merge 	modele.basefam (keep=ident_fam age_enf pensrecu pers_iso wpela&anr2.)
			veuf(in=a); 
	by ident_fam;
	%nb_enf(e_c,0,&age_pf.,age_enf);
	if pers_iso=1 & substr(ident_fam,9,1) ne '9' & e_c;
	/* Avant 2016 les personnes recevant une pension n'étaient pas éligibles à l'ASF (sauf en cas de non paiement).
	Depuis 2016 si cette pension est inférieure au montant de l'ASF, ces personnes sont éligibles et perçoivent la différence entre l'ASF et leur pension
	au titre de l'ASF. */
	if &anleg.<2016 then do;
		if a then do;
			veuf=1;
			if pensrecu=0 then possible_asf=1; /* On introduit possible_asf par nécessité de code, pour pouvoir introduire le else delete qui suit */
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
/* 3. création de catégories d'éligibles potentiels par nombre 		*/
/* d'enfants à charge et d'un aléa 									*/
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
/* tri de la base des éligibles potentiels. Au sein de chaque catégorie, le tri est
- decsendant par le critère veuf car ils doivent tous être bénéficiaires
- descendant selon l'aléa pour sélectionner le reste des bénéficiaires  */
proc sort data=asf; by tri descending veuf descending alea; run;

/********************************************************************/
/* 4. détermination des bénéficiaires en fonction de l'aléa 		*/
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
	label elig_asf="Famille éligible à l'ASF";
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
