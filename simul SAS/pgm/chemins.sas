/************************************************************************************
																					
								 CHEMINS											
																				
*************************************************************************************/


/* Définition des chemins des dossiers de programmes */

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
