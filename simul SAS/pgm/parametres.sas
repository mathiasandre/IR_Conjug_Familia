/********************************************************************************/
/*																				*/
/*								PARAMETRES										*/
/*																				*/
/********************************************************************************/

/* Ce programme importe des param�tres de la l�gislation et les transforme en macrovariables globales */

/* En entr�e : fichiers Excel "param_prelev.xls", "param_presta.xls", "derive_revenu.xls", "param_baseERFS.xls" et "param_revalo.xls" */
/* En sortie : autant de macrovariables que de param�tres diff�rents dans tous ces fichiers Excel */

/****************************************************************************************************************/
/*	PLAN 										      															*/
/* 1 : Import des param�tres de la l�gislation 	      														    */
/* 2 : Transformation des param�tres en macrovariables et revalorisation �ventuelle pour param�tres l�gislatifs */
/****************************************************************************************************************/

/********************************************************************************/

/************************************************/
/* 1 : Import des param�tres de la l�gislation 	*/
/************************************************/
%Macro importFichier(doc,feuille,table);
	/* @doc : nom du fichier .xls � importer
	   @feuille : nom de l'onglet � importer
	   @table : nom de la table sas cr��e */
	PROC IMPORT DATAFILE = "&dossier.\&doc..xls"  
		OUT=dossier.&table. 
		dbms=&excel_imp. REPLACE;
		sheet=&feuille.;
		RUN;
		%Mend importFichier;

%Macro importParametres; 
	%if &import.=oui %then %do;
		%importFichier(param_prelev,IR,imp_calc);
		%importFichier(param_presta,af,af);
		%importFichier(param_presta,minima,minima);
		%importFichier(param_presta,aeeh,aeeh);
		%importFichier(param_presta,al,al);
		%importFichier(param_presta,apa,apa);
		%importFichier(param_presta,bourses,bourses);
		%importFichier(param_presta,cmuc,cmuc);
		%importFichier(param_prelev,TH,TH);
		%importFichier(param_prelev,cotis,param_soc);
		%importFichier(param_prelev,smic,smic);
		%importFichier(param_prelev,Imput,imput_cotis);
		%importFichier(derive_revenu,param_derive,param_derive); 
		%importFichier(param_baseERFS,base,init);
		%importFichier(derive_revenu,acemo,acemo);
		%importFichier(param_revalo,base_revalo,revalo);
		%importFichier(departement_GJ,departement_2016,dep_gj_2016);
		%end;
	%Mend;
%importParametres;

/************************************************/
/* 2 : D�rive 									*/
/************************************************/
/* cr�ation des MV associ�es aux param�tres 	
(i)	de l'ann�e de l'ERFS pour param_derive, Marges_Calage et param_baseERFS
(ii) de l'ann�e de l�gislation pour les param�tres l�gislatifs
pour (ii), revalorisation �ventuelle par un param�tre tx entr� � la main dans l'encha�nement, 
� condition que la d�rive soit indiqu�e par un 11, 12, 2, 3, 4, 5, 6 ou 7 dans l'Excel */

%Macro creeMacrovarAnref(table,FinNomColonne);
	/* Diff�rent de %CreeMacrovarAPartirTable qui ne cr�e qu'une seule macrovar � la fois alors que l� �a cr�e autant de MV que de noms non-vides */
	/* @table : nom de la table contenant les param�tres � transformer en macrovariables
	   @FinNomColonne : Fin du nom de la colonne. Typiquement &anref.  */
	data _null_;
		set dossier.&table. (KEEP = nom valeur_ERFS_&FinNomColonne. derive);
		if nom ne '';
		call symputx(nom,valeur_ERFS_&FinNomColonne.,'G');
		run;
	%if &table.=param_derive %then %do;
		%CreeParametreRetarde(plaf_pa1_an1,dossier.param_derive,plaf_pa1_an2,ERFS,&FinNomColonne.,1);
		%CreeParametreRetarde(plaf_pa1_an0,dossier.param_derive,plaf_pa1_an2,ERFS,&FinNomColonne.,2);
		%CreeParametreRetarde(plaf_pa2_an1,dossier.param_derive,plaf_pa2_an2,ERFS,&FinNomColonne.,1);
		%CreeParametreRetarde(plaf_pa2_an0,dossier.param_derive,plaf_pa2_an2,ERFS,&FinNomColonne.,2);
		%end;
	%else %if &table.=init %then %do;
		%CreeParametreRetarde(pop_an1,dossier.init,pop_an2,ERFS,&FinNomColonne.,1);
		%CreeParametreRetarde(pop_an,dossier.init,pop_an2,ERFS,&FinNomColonne.,2);
		%end;
	%Mend creeMacrovarAnref;

%Macro creeMacrovarAnleg(table,FinNomColonne,tx);
	/* Diff�rent de %CreeMacrovarAPartirTable qui ne cr�e qu'une seule macrovar � la fois alors que l� �a cr�e autant de MV que de noms non-vides */
	/* @table : nom de la table contenant les param�tres � transformer en macrovariables
	   @FinNomColonne : Fin du nom de la colonne. Typiquement &anleg.  */
	data _null_;
		set dossier.&table. (KEEP = nom valeur_INES_&FinNomColonne. derive);
		if nom ne '';
		if derive not in (0 99) then valeur_INES_&FinNomColonne.=valeur_INES_&FinNomColonne.*&tx.;
		call symputx(nom,valeur_INES_&FinNomColonne.,'G');
		run;
	%if &table.=smic %then %do;
		%CreeParametreRetarde(smich_lag1,dossier.smic,smich,Ines,&FinNomColonne.,1);
		%end;
	%else %if &table.=param_soc %then %do;
		%CreeParametreRetarde(deflaplafss2,dossier.param_soc,deflaplafss1,Ines,&FinNomColonne.,1);
		%end;
	%Mend creeMacrovarAnleg;

%creeMacrovarAnref(param_derive,&anref.); 
%creeMacrovarAnref(init,&anref.);
%creeMacrovarAnleg(imp_calc,&anleg.,&tx.);
%creeMacrovarAnleg(af,&anleg.,&tx.);
%creeMacrovarAnleg(minima,&anleg.,&tx.);
%creeMacrovarAnleg(al,&anleg.,&tx.);
%creeMacrovarAnleg(apa,&anleg.,&tx.);
%creeMacrovarAnleg(aeeh,&anleg.,&tx.);
%creeMacrovarAnleg(bourses,&anleg.,&tx.);
%creeMacrovarAnleg(cmuc,&anleg.,&tx.);
%creeMacrovarAnleg(param_soc,&anleg.,&tx.);
%creeMacrovarAnleg(th,&anleg.,&tx.);
%creeMacrovarAnleg(smic,&anleg.,&tx.);
%creeMacrovarAnleg(imput_cotis,&anleg.,&tx.);
%creeMacrovarAnleg(revalo,&anleg.,&tx.);

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
