/************************************************/
/*			programme ordre_foyer   			*/ 
/************************************************/

/******************************************************************************************/
/* Tables en entr�e :                                                                     */
/*	travail.foyer&anr.																      */
/*																						  */	
/* Tables en sortie :																	  */
/*	travail.foyer&anr.																	  */
/*																						  */
/* Objectif : Cette �tape permet de mettre les variables des tables foyers dans un 		  */
/* ordre pr�cis: ident, noindiv, declar, sif, anaisenf, nbenf, les autres infos de la	  */ 
/* table foyer en finissant par les cases fiscales, par ordre alphab�tique.				  */
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
