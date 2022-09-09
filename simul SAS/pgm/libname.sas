/********************************************************************************/
/*																				*/
/*								 LIBNAME										*/
/*																				*/
/********************************************************************************/

/* D�finition des librairies SAS du mod�le */

%let dossier=&chemin_dossier.\parametres;

/* Emplacement des donn�es sources : tables de l'ERFS noyau et �largie */
libname noyau  	    "&chemin_bases.\ERFS &anref.\noyau";
libname elargi 	    "&chemin_bases.\ERFS &anref.\elargi";

/* Emplacement des tables modifi�es ind�pendamment de l'ann�e de l�gislation */
libname RPM  	    "&chemin_bases.\Base &anref.\RPM";
libname CD  	    "&chemin_bases.\Base &anref.\CD";
libname travail	    "&chemin_bases.\Base &anref.\travaill�es";
libname imput	 	"&chemin_bases.\Base &anref.\imput�es";
libname base		"&chemin_bases.\Base &anref.\base";

/* Emplacement des tables de sortie du mod�le pour un mill�sime ERFS et une ann�e de l�gislation donn�e */
libname modele		"&chemin_bases.\Leg &anleg. Base &anref.";

/* Emplacement des param�tres et de la table typocomm*/
libname dossier 	"&dossier.";

/* Emplacement des donn�es BDF pour module de taxation indirecte*/
libname BDF&anBDF. "&chemin_bases.\BDF &anBDF." access=readonly;

/*Emplacement des bases de travail et de sortie du module de taxation indirecte*/
libname taxind	"&chemin_bases.\Leg &anleg. Base &anref.\TaxInd";

options sasmstore=lib mstored;
options sasmstore=maccomp mstored; /* Librairie comprenant la macro CALMAR n�cessaire au calage sur marge */

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
