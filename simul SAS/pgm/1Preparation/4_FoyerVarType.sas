/************************************************/
/*          Programme 4_FoyerVarType           */ 
/************************************************/

/********************************************************************************/
/* Table en entr�e :															*/
/*  travail.foyer&anr.															*/     
/* Table en sortie :															*/
/*  dossier.foyerVarList														*/
/********************************************************************************/

/********************************************************************************/
/*	Ce programme utilise les macros d�finies et mises � jour chaque ann�e 		*/
/*	dans le programme macros_OrgaCases, mais intervient ici car		*/
/*	le programme Init_Foyer doit avoir tourn� (-> table travail.foyer&anr.		*/

/* 	Ce programme cr�e une table dossier.FoyerVarList, qui vise � d�terminer 	*/
/*	pour chaque case fiscale de la table foyer du mill�sime ERFS utilis� : 
	- dans quel agr�gat la case est englob�e (en lien avec la macro %ListeCasesAgregatsERFS du programme macros)
	- � quel individu la case se r�f�re (vous, conjoint, p�c1 ou 2, ou "ensemble du foyer fiscal"). 

	En fonction des listes d�finies par les deux macros ci-dessus, on cr�e la table dossier.FoyerVarList
	Cette table n'est pas utilis�e en tant que telle dans le mod�le Ines (sauf programme XYZ_foyer avant 2013), mais elle peut s'av�rer
	tr�s utile pour des fins d'�tude (d�s que l'on veut individualiser une op�ration � un niveau plus fin que l'agr�gat ERFS). 
	Elle est �galement utile pour rapidement retrouver des informations sur les variables fiscales. */

/********************************************************************************/



/************************************************/
/* Cr�ation de la table dossier.FoyerVarList */
/************************************************/

proc contents data=travail.foyer&anr.(keep=_:) out=FoyerVarList(keep=name length label) noprint; run;



options noquotelenmax; /* Pour pr�venir le warning sur la longueur des chaines de caract�res */
data dossier.FoyerVarList;
	set FoyerVarList;	
	length TypeContenu $100;
	length AgregatERFS $5.;
	if index("&ListVousRev.",lowcase(strip(name)))>0 then TypeContenu="Montant concernant le d�clarant (vous)";
	if index("&ListVousAutres.",lowcase(strip(name)))>0 then TypeContenu="Autre case concernant le d�clarant (vous)";
	if index("&ListConjRev.",lowcase(strip(name)))>0 then TypeContenu="Montant concernant le conjoint (conj)";
	if index("&ListConjAutres.",lowcase(strip(name)))>0 then TypeContenu="Autre case concernant le conjoint (conj)";
	if index("&ListPac1Rev.",lowcase(strip(name)))>0 then TypeContenu="Montant concernant pac1";
	if index("&ListPac1Autres.",lowcase(strip(name)))>0 then TypeContenu="Autre case concernant pac1";
	if index("&ListPac2Rev.",lowcase(strip(name)))>0 then TypeContenu="Montant concernant pac2";
	if index("&ListPac2Autres.",lowcase(strip(name)))>0 then TypeContenu="Autre case concernant pac2";
	if index("&ListPac3Rev.",lowcase(strip(name)))>0 then TypeContenu="Montant concernant pac3";
	if index("&ListPac3Autres.",lowcase(strip(name)))>0 then TypeContenu="Autre case concernant pac3";
	if index("&ListPac4Rev.",lowcase(strip(name)))>0 then TypeContenu="Montant concernant pac4";
	if index("&ListNonIndivRev.",lowcase(strip(name)))>0 then TypeContenu="Montant concernant le foyer";
	if index("&ListNonIndivAutres.",lowcase(strip(name)))>0 then TypeContenu="Autre case concernant le foyer";
	if index("&NomsExpliRev.",lowcase(strip(name)))>0 then TypeContenu="Montant de cases disparues dont on a transf�r� le contenu dans un nom explicite";
	if index("&NomsExpliAutres.",lowcase(strip(name)))>0 then TypeContenu="Autres cases disparues dont on a transf�r� le contenu dans un nom explicite";
	if index("&listVarDisp.",lowcase(strip(name)))>0 then TypeContenu="Cases ne faisant plus partie de la brochure fiscale la plus r�cente";
	if index("&listVarInconnues.",lowcase(strip(name)))>0 then TypeContenu="Variable pr�sente mais dont on ne conna�t pas la signification";
	if TypeContenu='' then ERROR "Le type de case fiscale n'est pas renseign�";

	if index("&zsalfP.",lowcase(strip(name)))>0 then AgregatERFS="zsalf";
	else if index("&zchofP.",lowcase(strip(name)))>0 then AgregatERFS="zchof";
	else if index("&zrstfP.",lowcase(strip(name)))>0 then AgregatERFS="zrstf";
	else if index("&zpifP.",lowcase(strip(name)))>0 then AgregatERFS="zpif";
	else if index("&zalrfP.",lowcase(strip(name)))>0 then AgregatERFS="zalrf";
	else if index("&zrtofP.",lowcase(strip(name)))>0 then AgregatERFS="zrtof";
	else if index("&zragfP.",lowcase(strip(name)))>0 then AgregatERFS="zragf";
	else if index("&zragfN.",lowcase(strip(name)))>0 then AgregatERFS="zragf";
	else if index("&cbicf_.",lowcase(strip(name)))>0 then AgregatERFS="zricf";
	else if index("&zricfP.",lowcase(strip(name)))>0 then AgregatERFS="zricf";
	else if index("&zricfN.",lowcase(strip(name)))>0 then AgregatERFS="zricf";
	else if index("&cbncf_.",lowcase(strip(name)))>0 then AgregatERFS="zrncf";
	else if index("&zrncfP.",lowcase(strip(name)))>0 then AgregatERFS="zrncf";
	else if index("&zrncfN.",lowcase(strip(name)))>0 then AgregatERFS="zrncf";
	else if index("&zvalfP.",lowcase(strip(name)))>0 then AgregatERFS="zvalf";
	else if index("&zavffP.",lowcase(strip(name)))>0 then AgregatERFS="zavff";
	else if index("&zvamfP.",lowcase(strip(name)))>0 then AgregatERFS="zvamf";
	else if index("&zvamfN.",lowcase(strip(name)))>0 then AgregatERFS="zvamf";
	else if index("&zfonfP.",lowcase(strip(name)))>0 then AgregatERFS="zfonf";
	else if index("&zfonfN.",lowcase(strip(name)))>0 then AgregatERFS="zfonf";
	else if index("&caccf_.",lowcase(strip(name)))>0 then AgregatERFS="zracf";
	else if index("&zracfP.",lowcase(strip(name)))>0 then AgregatERFS="zracf";
	else if index("&zracfN.",lowcase(strip(name)))>0 then AgregatERFS="zracf";
	else if index("&zetrfP.",lowcase(strip(name)))>0 then AgregatERFS="zetrf";
	else if index("&zalvfP.",lowcase(strip(name)))>0 then AgregatERFS="zalvf";
	else if index("&zglofP.",lowcase(strip(name)))>0 then AgregatERFS="zglof";
	else if index("&zquofP.",lowcase(strip(name)))>0 then AgregatERFS="zquof";
	else if index("&zdivfP.",lowcase(strip(name)))>0 then AgregatERFS="zdivf";
	else if index("&zdivfN.",lowcase(strip(name)))>0 then AgregatERFS="zdivf";
	run;
options quotelenmax;

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
