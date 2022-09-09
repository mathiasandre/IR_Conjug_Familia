/********************************************************************************/
/*																				*/
/*								PARAMETRES										*/
/*																				*/
/********************************************************************************/

/* Ce programme importe des paramètres de la législation et les transforme en macrovariables globales */

/* En entrée : fichiers Excel "param_prelev.xls", "param_presta.xls", "derive_revenu.xls", "param_baseERFS.xls" et "param_revalo.xls" */
/* En sortie : autant de macrovariables que de paramètres différents dans tous ces fichiers Excel */

/****************************************************************************************************************/
/*	PLAN 										      															*/
/* 1 : Import des paramètres de la législation 	      														    */
/* 2 : Transformation des paramètres en macrovariables et revalorisation éventuelle pour paramètres législatifs */
/****************************************************************************************************************/

/********************************************************************************/

/************************************************/
/* 1 : Import des paramètres de la législation 	*/
/************************************************/
%Macro importFichier(doc,feuille,table);
	/* @doc : nom du fichier .xls à importer
	   @feuille : nom de l'onglet à importer
	   @table : nom de la table sas créée */
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
/* 2 : Dérive 									*/
/************************************************/
/* création des MV associées aux paramètres 	
(i)	de l'année de l'ERFS pour param_derive, Marges_Calage et param_baseERFS
(ii) de l'année de législation pour les paramètres législatifs
pour (ii), revalorisation éventuelle par un paramètre tx entré à la main dans l'enchaînement, 
à condition que la dérive soit indiquée par un 11, 12, 2, 3, 4, 5, 6 ou 7 dans l'Excel */

%Macro creeMacrovarAnref(table,FinNomColonne);
	/* Différent de %CreeMacrovarAPartirTable qui ne crée qu'une seule macrovar à la fois alors que là ça crée autant de MV que de noms non-vides */
	/* @table : nom de la table contenant les paramètres à transformer en macrovariables
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
	/* Différent de %CreeMacrovarAPartirTable qui ne crée qu'une seule macrovar à la fois alors que là ça crée autant de MV que de noms non-vides */
	/* @table : nom de la table contenant les paramètres à transformer en macrovariables
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
