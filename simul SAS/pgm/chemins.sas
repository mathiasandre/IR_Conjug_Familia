/************************************************************************************
																					
								 CHEMINS											
																				
*************************************************************************************/


/* D�finition des chemins des dossiers de programmes */

%let init			=&chemin_dossier.\pgm\1preparation;
%let info_trim		=&chemin_dossier.\pgm\1preparation\info_par_trimestre;
%let imputation		=&chemin_dossier.\pgm\2imputations; 
%let fiscal			=&chemin_dossier.\pgm\3Modele\fisc;
%let crea_basefam	=&chemin_dossier.\pgm\3Modele\Prestations;
%let chemin_cotis	=&chemin_dossier.\pgm\3Modele\Cotisations;
%let presta			=&chemin_dossier.\pgm\3Modele\Prestations;
%let taxind			=&chemin_dossier.\pgm\3Modele\TaxInd;
%let chemin_ass= &chemin_dossier.\pgm\2imputations\imputation ASS; 
%let menage			=&chemin_dossier.\pgm\4basemen;
%let sortie_cible	=&chemin_bases.\Leg &anleg. Base &anref.\sortie;
%let sortie_fps		=&chemin_bases.\Leg &anleg. Base &anref.\sortie\stat_bilan_%sysfunc(putn(%sysfunc(date()), yymmddn8.));
%let sortie_pqe		=&chemin_bases.\Leg &anleg. Base &anref.\sortie\tableaux_pqe_%sysfunc(putn(%sysfunc(date()), yymmddn8.));
%let sortie_cps		=&chemin_bases.\Leg &anleg. Base &anref.\sortie\tableaux_cps_%sysfunc(putn(%sysfunc(date()), yymmddn8.));

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
