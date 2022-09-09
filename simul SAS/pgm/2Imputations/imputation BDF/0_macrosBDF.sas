/***************************/
/* MACROS UTILES POUR le module de taxation indirecte seul */ 
/***************************/

%MACRO ListXVar(ListeVar, my_var, ListeNom) ;
/* Multiplie une variable à une liste de variables à l'intérieur d'une étape data  */
/*@ListeVar : liste des variables à multiplier*/
/*@my_var : nom de la variable multiplicande*/
/*@ListeNom : liste des noms des nouvelles variables*/
/*attention : ListeNom doit être au moins aussi long que ListeVar*/ 
	%do i=1 %to %sysfunc(countw(&ListeVar.));
		%scan(&ListeNom.,&i.) = %scan(&ListeVar.,&i.)*&my_var. ;
	%end;
%MEND ListXVar;

%MACRO Calcul_Part(ListeVar, my_var,suffixe= ) ;
/* Divise une liste de variables par une même variable à l'intérieur d'une étape data */
/*@ListeVar : liste des variables à diviser*/
/*@my_var : nom de la variable au dénominateur*/
/*@suffixe : suffixe accolé aux nouvelles variables ; par défaut, c'est une espace vide qu'on efface avec trim*/
	%do i=1 %to %sysfunc(countw(&ListeVar.));
		%if &my_var. = 0 %then %do ; part_%scan(&ListeVar.,&i.)%trim(&suffixe.) = 0 ; %end;
		%else %do; part_%scan(&ListeVar.,&i.)%trim(&suffixe.) = %scan(&ListeVar.,&i.)/&my_var. ; %end;
	%end;
%MEND Calcul_Part;

%MACRO Sum_by_Class(table, classe, poids, var_select, var_agreg) ;
/*Somme pondérée par classe avec possibilité de sélectionner sur une variable positive*/
/*@table : table en entrée*/
/*@classe : variable de catégories */
/*@poids : variable de pondération*/
/*@var_select : variable de condition (positive, typiquement un revenu)*/
/*@var_agreg : variable qui est agrégée*/
	proc means 
		data=&table. (where = (&var_select. > 0)) noprint  ;
		var &var_agreg.   ;
		class &classe. ;
		weight &poids. ;
		output out=&table._&classe. (drop=_type_ _freq_ where = (&classe. not in (" ")))  sum= ;
	run ;
%MEND Sum_by_Class;

%MACRO sum_conso(var, fin); 
/*Calcul des sommes de variables de consommation à différents niveaux dans une étape data*/
	%do i = 1 %to &fin. ; &var.&i. = sum (of &var.&i.:); %end; 
%MEND sum_conso;

%MACRO Keep_list(Liste, my_var);
/*Garde uniquement la liste des valeurs pour une variable donnée dans une étape data*/
/*@Liste : liste de variables à sélectionner*/
/*@var : variable contenant les valeurs à conserver*/
	%do i=1 %to %sysfunc(countw(&Liste.));
		if &my_var.= %scan(&Liste.,&i.) then output ;
	%end;
%MEND Keep_list;

%MACRO Cree_Liste_MV(table, ListeNomsMV, VarValues, VarIdent, ListeIdent, Prefixe);
/*Crée une liste de macrovariable à partir d'une liste de noms de MV et de valeurs*/
/*@table : table de travail*/
/*@ListeNomsMV : liste des noms des futures macrovariables*/
/*@VarValues : nom de la variable des valeurs */
/*@VarIdent : nom de la variable des noms */
/*@ListeIdent : liste des valeurs de la variable à retenir */
/*@Prefixe : préfixe des macrovariables */
	%do i=1 %to %sysfunc(countw(&ListeNomsMV.));
			%CreeMacrovarAPartirTable(&Prefixe.%scan(&ListeNomsMV.,&i.) , &table., &VarValues., &VarIdent., %scan(&ListeIdent.,&i.))
	%end;
%MEND Cree_Liste_MV;


/****************************************************/
/*Macro-variables pour module taxation indirecte*/
/****************************************************/

/* Les macrolistes ci-dessous doivent être rendues globales pour être utilisables dans l'amont et l'aval */
%global liste_conso_12 liste_conso liste_part liste_taxes liste_taux liste_liquides_nomen liste_liquides;

/* Liste des catégories des taxes indirectes */
%let liste_taxes = montant_tva montant_tva_N montant_tva_I montant_tva_R montant_tva_SR montant_assu montant_tabac montant_alcool montant_alcool_secu montant_ticpe;

/* Liste des types de taux de TVA */
%let liste_taux = N I R SR ;

/* Liste des 12 fonctions principales de consommation */
%let liste_conso_12=C01 C02 C03 C04 C05 C06 C07 C08 C09 C10 C11 C12;

/* Listes des 247 postes */
%let liste_conso=C01111 C01112 C01113 C01114 C01115 C01121 C01122 C01123 C01124 
	C01125 C01126 C01127 C01130 C01131 C01132 C01133 C01134 C01141 C01142 C01143 
	C01144 C01145 C01146 C01147 C01151 C01152 C01153 C01154 C01155 C01161 C01162 
	C01163 C01164 C01165 C01166 C01167 C01168 C01169 C01171 C01172 C01173 C01174 
	C01175 C01176 C01177 C01178 C01179 C01181 C01182 C01183 C01184 C01185 C01186 
	C01191 C01192 C01193 C01194 C01195 C01211 C01212 C01213 C01221 C01222 C01223 
	C01224 C021111 C021112 C021113 C021114 C021115 C021116 C021117 C021118 C02111Z 
	C021211 C021212 C02121Z C021221 C021222 C021223 C02122Z C02131 C02211 C02212 
	C022131 C022132 C03111 C03121 C03122 C03123 C03131 C03141 C03211 C03212 C03213 
	C03221 C04111 C04121 C04311 C04321 C04411 C04421 C04431 C04441 C04500 C04511 
	C04521 C04522 C04531 C04541 C04551 C04552 C05110 C05111 C05112 C05113 C05114 
	C05115 C05116 C05121 C05131 C05211 C05212 C05311 C05312 C05313 C05314 C05315 
	C05316 C05317 C05321 C05331 C05411 C05412 C05413 C05414 C05511 C05512 C05513 
	C05521 C05522 C05523 C05611 C05612 C05621 C05622 C06111 C06112 C06113 C06211 
	C06221 C06231 C06232 C06233 C06311 C06411 C06412 C07111 C07112 C07121 C07131 
	C07141 C07211 C072211 C072212 C072213 C072215 C07221Z C07231 C07241 C07242 
	C07311 C07321 C07331 C07341 C07351 C07361 C08111 C08121 C08131 C08141 C09111 
	C09112 C09121 C09122 C09131 C09141 C09151 C09211 C09221 C09222 C09231 C09311 
	C09312 C09321 C09331 C09341 C09411 C09421 C09422 C09423 C09424 C09431 C09511 
	C09521 C09531 C09541 C09611 C10111 C10121 C10131 C10141 C10151 C10152 C11111 
	C11112 C11121 C11131 C11132 C11211 C12111 C12121 C12122 C12311 C12321 C12322 
	C12331 C12411 C12511 C12521 C12531 C12541 C125511 C125512 C125513 C125514 
	C125515 C125516 C125517 C125518 C125519 C12551A C12551B C12551C C12611 C12711 C12712;

/* Listes des 247 parts */
%let liste_part =PART_C01111 PART_C01112 PART_C01113 PART_C01114 PART_C01115 PART_C01121 
	PART_C01122 PART_C01123 PART_C01124 PART_C01125 PART_C01126 PART_C01127 PART_C01130 
	PART_C01131 PART_C01132 PART_C01133 PART_C01134 PART_C01141 PART_C01142 PART_C01143 
	PART_C01144 PART_C01145 PART_C01146 PART_C01147 PART_C01151 PART_C01152 PART_C01153 
	PART_C01154 PART_C01155 PART_C01161 PART_C01162 PART_C01163 PART_C01164 PART_C01165 
	PART_C01166 PART_C01167 PART_C01168 PART_C01169 PART_C01171 PART_C01172 PART_C01173 
	PART_C01174 PART_C01175 PART_C01176 PART_C01177 PART_C01178 PART_C01179 PART_C01181
	PART_C01182 PART_C01183 PART_C01184 PART_C01185 PART_C01186 PART_C01191 PART_C01192 
	PART_C01193 PART_C01194 PART_C01195 PART_C01211 PART_C01212 PART_C01213 PART_C01221 
	PART_C01222 PART_C01223 PART_C01224 PART_C021111 PART_C021112 PART_C021113 PART_C021114 
	PART_C021115 PART_C021116 PART_C021117 PART_C021118 PART_C02111Z PART_C021211 PART_C021212 
	PART_C02121Z PART_C021221 PART_C021222 PART_C021223 PART_C02122Z PART_C02131 PART_C02211 
	PART_C02212 PART_C022131 PART_C022132 PART_C03111 PART_C03121 PART_C03122 PART_C03123 
	PART_C03131 PART_C03141 PART_C03211 PART_C03212 PART_C03213 PART_C03221 PART_C04111 
	PART_C04121 PART_C04311 PART_C04321 PART_C04411 PART_C04421 PART_C04431 PART_C04441 
	PART_C04500 PART_C04511 PART_C04521 PART_C04522 PART_C04531 PART_C04541 PART_C04551 
	PART_C04552 PART_C05110 PART_C05111 PART_C05112 PART_C05113 PART_C05114 PART_C05115 
	PART_C05116 PART_C05121 PART_C05131 PART_C05211 PART_C05212 PART_C05311 PART_C05312 
	PART_C05313 PART_C05314 PART_C05315 PART_C05316 PART_C05317 PART_C05321 PART_C05331 
	PART_C05411 PART_C05412 PART_C05413 PART_C05414 PART_C05511 PART_C05512 PART_C05513 
	PART_C05521 PART_C05522 PART_C05523 PART_C05611 PART_C05612 PART_C05621 PART_C05622 
	PART_C06111 PART_C06112 PART_C06113 PART_C06211 PART_C06221 PART_C06231 PART_C06232 
	PART_C06233 PART_C06311 PART_C06411 PART_C06412 PART_C07111 PART_C07112 PART_C07121 
	PART_C07131 PART_C07141 PART_C07211 PART_C072211 PART_C072212 PART_C072213 PART_C072215 
	PART_C07221Z PART_C07231 PART_C07241 PART_C07242 PART_C07311 PART_C07321 PART_C07331 
	PART_C07341 PART_C07351 PART_C07361 PART_C08111 PART_C08121 PART_C08131 PART_C08141 
	PART_C09111 PART_C09112 PART_C09121 PART_C09122 PART_C09131 PART_C09141 PART_C09151 
	PART_C09211 PART_C09221 PART_C09222 PART_C09231 PART_C09311 PART_C09312 PART_C09321 
	PART_C09331 PART_C09341 PART_C09411 PART_C09421 PART_C09422 PART_C09423 PART_C09424 
	PART_C09431 PART_C09511 PART_C09521 PART_C09531 PART_C09541 PART_C09611 PART_C10111 
	PART_C10121 PART_C10131 PART_C10141 PART_C10151 PART_C10152 PART_C11111 PART_C11112 
	PART_C11121 PART_C11131 PART_C11132 PART_C11211 PART_C12111 PART_C12121 PART_C12122 
	PART_C12311 PART_C12321 PART_C12322 PART_C12331 PART_C12411 PART_C12511 PART_C12521 
	PART_C12531 PART_C12541 PART_C125511 PART_C125512 PART_C125513 PART_C125514 PART_C125515 
	PART_C125516 PART_C125517 PART_C125518 PART_C125519 PART_C12551A PART_C12551B PART_C12551C 
	PART_C12611 PART_C12711 PART_C12712;

/*listes des liquides*/
%let liste_liquides_nomen = 021111 021112 021113 021114 021115 021116 021117 021118 021212 021223 072211 072212 021221 021222;
%let liste_liquides = anisette apero whisky eaudevie rhum punch liqueur cocktail cidre vindoux essence diesel mousseux champ;


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
