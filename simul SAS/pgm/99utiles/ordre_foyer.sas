/************************************************/
/*			programme ordre_foyer   			*/ 
/************************************************/

/******************************************************************************************/
/* Tables en entrée :                                                                     */
/*	travail.foyer&anr.																      */
/*																						  */	
/* Tables en sortie :																	  */
/*	travail.foyer&anr.																	  */
/*																						  */
/* Objectif : Cette étape permet de mettre les variables des tables foyers dans un 		  */
/* ordre précis: ident, noindiv, declar, sif, anaisenf, nbenf, les autres infos de la	  */ 
/* table foyer en finissant par les cases fiscales, par ordre alphabétique.				  */
/******************************************************************************************/
	
   
proc contents DATA=travail.foyer&anr. out=VarFoyer&anr.(keep=name) noprint; run;
%let list_exclu = 'ident' 'noindiv' 'declar' 'sif' 'anaisenf' 'nbenf';
%let list_exclu2 = ident noindiv declar sif anaisenf nbenf; 

DATA AutresVarFisc;
	SET VarFoyer&anr.;
	if name in (&list_exclu.) ! substr(name,1,1)='_' ! substr(name,1,2) in ('tx','mn','mb','mx','for')
	then delete;
	RUN; 

DATA CaseFiscale;
	SET VarFoyer&anr.;
	if substr(name,1,1)='_';
	RUN; 

proc sql noprint;
	select name into :var1 separated by ' ' from AutresVarFisc order by name;
	select name into :var2 separated by ' ' from CaseFiscale order by name;
	quit;

%let var= &list_exclu2. &var1. &var2.; 
data travail.foyer&anr.;
	retain &var.;
	set travail.foyer&anr.;
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
