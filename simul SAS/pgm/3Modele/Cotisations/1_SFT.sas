/****************************************************************************************/
/*																						*/
/*										1_SFT											*/
/*																						*/
/****************************************************************************************/
/*																						*/
/* Ce programme détermine l'éligibilité au Supplément Familial de Traitement et le 		*/
/* nombre d'enfants associés. 															*/
/*																						*/
/* En entrée : 	modele.baseind                                    						*/
/*				modele.basefam                                    						*/ 
/*				base.baserev                                     						*/
/* En sortie :  modele.baseind                                    						*/
/****************************************************************************************/
/* PLAN : 																				*/
/*	1. Calcul du nombre d'enfants														*/
/*	2. Sélection des potentiels candidats au SFT										*/
/*	3. Repérage du bénéficiaire dans le couple : le mieux rémunéré						*/
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
	%nb_enf(nb_enfant,0,&age_PF.,age_enf); /* nb_enfant donne le nb d'enfants à charge au sens des PF */
	run;


/************************************************/
/* 2. Sélection des potentiels candidats au SFT	*/
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
/* 3. Repérage du bénéficiaire dans le couple : le mieux rémunéré  */
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
	if civ in ('mon' 'mad') then NbEnf_SFT=nb_enfant; /* Le filtre if civ in ('mon' 'mad') permet de ne pas attribuer du SFT à des enfants fonctionnaires */
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
	label nbenf_SFT="Nombre d'enfants pour le calcul du supplément familial de traitement";
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
