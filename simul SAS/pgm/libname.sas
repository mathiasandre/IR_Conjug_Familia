/********************************************************************************/
/*																				*/
/*								 LIBNAME										*/
/*																				*/
/********************************************************************************/

/* Définition des librairies SAS du modèle */

%let dossier=&chemin_dossier.\parametres;

/* Emplacement des données sources : tables de l'ERFS noyau et élargie */
libname noyau  	    "&chemin_bases.\ERFS &anref.\noyau";
libname elargi 	    "&chemin_bases.\ERFS &anref.\elargi";

/* Emplacement des tables modifiées indépendamment de l'année de législation */
libname RPM  	    "&chemin_bases.\Base &anref.\RPM";
libname CD  	    "&chemin_bases.\Base &anref.\CD";
libname travail	    "&chemin_bases.\Base &anref.\travaillées";
libname imput	 	"&chemin_bases.\Base &anref.\imputées";
libname base		"&chemin_bases.\Base &anref.\base";

/* Emplacement des tables de sortie du modèle pour un millésime ERFS et une année de législation donnée */
libname modele		"&chemin_bases.\Leg &anleg. Base &anref.";

/* Emplacement des paramètres et de la table typocomm*/
libname dossier 	"&dossier.";

/* Emplacement des données BDF pour module de taxation indirecte*/
libname BDF&anBDF. "&chemin_bases.\BDF &anBDF." access=readonly;

/*Emplacement des bases de travail et de sortie du module de taxation indirecte*/
libname taxind	"&chemin_bases.\Leg &anleg. Base &anref.\TaxInd";

options sasmstore=lib mstored;
options sasmstore=maccomp mstored; /* Librairie comprenant la macro CALMAR nécessaire au calage sur marge */

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
