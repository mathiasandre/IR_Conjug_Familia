/************************************************/
/*          Programme 4_FoyerVarType           */ 
/************************************************/

/********************************************************************************/
/* Table en entrée :															*/
/*  travail.foyer&anr.															*/     
/* Table en sortie :															*/
/*  dossier.foyerVarList														*/
/********************************************************************************/

/********************************************************************************/
/*	Ce programme utilise les macros définies et mises à jour chaque année 		*/
/*	dans le programme macros_OrgaCases, mais intervient ici car		*/
/*	le programme Init_Foyer doit avoir tourné (-> table travail.foyer&anr.		*/

/* 	Ce programme crée une table dossier.FoyerVarList, qui vise à déterminer 	*/
/*	pour chaque case fiscale de la table foyer du millésime ERFS utilisé : 
	- dans quel agrégat la case est englobée (en lien avec la macro %ListeCasesAgregatsERFS du programme macros)
	- à quel individu la case se réfère (vous, conjoint, pàc1 ou 2, ou "ensemble du foyer fiscal"). 

	En fonction des listes définies par les deux macros ci-dessus, on crée la table dossier.FoyerVarList
	Cette table n'est pas utilisée en tant que telle dans le modèle Ines (sauf programme XYZ_foyer avant 2013), mais elle peut s'avérer
	très utile pour des fins d'étude (dès que l'on veut individualiser une opération à un niveau plus fin que l'agrégat ERFS). 
	Elle est également utile pour rapidement retrouver des informations sur les variables fiscales. */

/********************************************************************************/



/************************************************/
/* Création de la table dossier.FoyerVarList */
/************************************************/

proc contents data=travail.foyer&anr.(keep=_:) out=FoyerVarList(keep=name length label) noprint; run;



options noquotelenmax; /* Pour prévenir le warning sur la longueur des chaines de caractères */
data dossier.FoyerVarList;
	set FoyerVarList;	
	length TypeContenu $100;
	length AgregatERFS $5.;
	if index("&ListVousRev.",lowcase(strip(name)))>0 then TypeContenu="Montant concernant le déclarant (vous)";
	if index("&ListVousAutres.",lowcase(strip(name)))>0 then TypeContenu="Autre case concernant le déclarant (vous)";
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
	if index("&NomsExpliRev.",lowcase(strip(name)))>0 then TypeContenu="Montant de cases disparues dont on a transféré le contenu dans un nom explicite";
	if index("&NomsExpliAutres.",lowcase(strip(name)))>0 then TypeContenu="Autres cases disparues dont on a transféré le contenu dans un nom explicite";
	if index("&listVarDisp.",lowcase(strip(name)))>0 then TypeContenu="Cases ne faisant plus partie de la brochure fiscale la plus récente";
	if index("&listVarInconnues.",lowcase(strip(name)))>0 then TypeContenu="Variable présente mais dont on ne connaît pas la signification";
	if TypeContenu='' then ERROR "Le type de case fiscale n'est pas renseigné";

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
