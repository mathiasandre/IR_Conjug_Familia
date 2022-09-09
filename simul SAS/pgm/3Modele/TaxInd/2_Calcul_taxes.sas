/********************************************************************************************/
/*																							*/
/*	                          CALCUL DES TAXES INDIRECTES DANS INES		                    */
/*																							*/
/********************************************************************************************/

/* Table d'entrée : 
				- work.basemen_BDF 
				- dossier.prix_moyen_&anBDF. 
				- dossier.prix_&anBDF._vin
				- dossier.prix_&anBDF._biere  												*/

/* Fichiers paramètre : 
		- prix.xls (prix moyens et taux d'inflation)
		- Taux_TVA_nomen5.xls (taux de taxe applicables)                                    */
		                                              
/* Table de sortie : 
		- taxind.basemen_taxes																*/
 
/* Le programme comporte 2 étapes :		
/* I  - Importation des prix et des taux									                */
/* II - Calcul des quantités et des taxes (TVA, TCA, droits sur le tabac,       			*/
/*                                     les alcools et TICPE)     							*/

/********************************************************************************************/


/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                                                                     	     */
/*  	I - Importation des prix et des taux de taxes et création des macrovariables         */
/*                                                                                           */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

/***** Transformation des prix issus des carnets BDF 2011 en macro-variables *****/

/*on créé la liste de MV à partir de la table et des listes de liquides*/
%Cree_Liste_MV(dossier.prix_moyen_&anBDF. , &liste_liquides.,  prix_&anBDF., nomen6, &liste_liquides_nomen., px_li_);

data _null_ ;
	set dossier.prix_&anBDF._vin  ;
	decile = 'v'!!dec_aj ;
	call symputx(decile, px_li_vin, 'G');
run ;

data _null_ ;
	set dossier.prix_&anBDF._biere  ;
	decile = 'b'!!dec_aj ;
	call symputx(decile, px_li_biere, 'G');
run ;

/***** Importation des prix issus de sources externes et transformation en macro-variables *****/
PROC IMPORT OUT=px_moyen_ext DATAFILE="&dossier.\prix.xls" replace dbms=&excel_imp. ; sheet = "PRIX_MOYEN_EXTERNE" ;RUN;
data _null_  ;
	set px_moyen_ext  ;
	call symputx(Produits, Prix_moyen_20&anr2., 'G');
run ;

/***** Importation des taux d'inflation et transformation en macro-variables *****/
PROC IMPORT OUT=taux_inflation DATAFILE="&dossier.\prix.xls" replace dbms=&excel_imp. ; sheet = "TAUX_INFLATION_ANNUEL" ; RUN;
data _null_  ;
	set taux_inflation ;
	call symputx(produit, infl_20&anr2., 'G');
run ;

/***** Importation des taux de TVA *****/
PROC IMPORT OUT=taux_tva DATAFILE="&dossier.\Taux_TVA_nomen5.xls" replace dbms=&excel_imp.; sheet = "Taux TVA" ; RUN;

%MACRO taux_nomen(Liste, table, colonne, taxe);
	%do i=1 %to %sysfunc(countw(&Liste.));
		%let n5_temp= %scan(&Liste.,&i.); /*nomen5*/
		%let nomen_temp = %substr(&n5_temp.,2) ; /*on enléve le C en début */
		%CreeMacrovarAPartirTable(taux_&taxe._&n5_temp., &table.,&colonne. , nomen, &nomen_temp.);
	%end;
%MEND taux_nomen;
%taux_nomen(&liste_conso., taux_tva, tva_20&anr2.,tva);

/***** Importation des types de taux de TVA *****/
%MACRO type_taux_nomen(Liste, table, colonne, taxe);
	%do i=1 %to %sysfunc(countw(&Liste.));
		%let n5_temp= %scan(&Liste.,&i.); /*nomen5*/
		%let nomen_temp = %substr(&n5_temp.,2) ; /*on enlève le C en début */
		%CreeMacrovarAPartirTable(type_&taxe._&n5_temp., &table.,&colonne. , nomen, &nomen_temp.);
	%end;
%MEND type_taux_nomen;
%type_taux_nomen(&liste_conso., taux_tva, I_tva_20&anr2., tva);

/* Importation des taux de TCA */
PROC IMPORT OUT=taux_assu (keep = nomen taxes_assu_20&anr2. I_assu_20&anr2.) 
DATAFILE="&dossier.\Taux_TVA_nomen5.xls" replace dbms=&excel_imp.; sheet = "Taux assurances" ; RUN;
%let liste_assu = C12511 C12521 C12531 C12541 C125511 C125512 C125513 C125514 C125515 C125516 C125517 C125518 C125519 C12551A C12551B C12551C;
%taux_nomen(&liste_assu., taux_assu, taxes_assu_20&anr2., assu);

/***** Importation des taux de TICPE *****/
PROC IMPORT OUT=taux_ticpe  (keep = nomen ticpe_20&anr2.)
DATAFILE="&dossier.\Taux_TVA_nomen5.xls" replace dbms=&excel_imp.; sheet = "TICPE" ; RUN;
%let liste_ticpe = C04531 C072211 C072212;
%taux_nomen(&liste_ticpe., taux_ticpe, ticpe_20&anr2.,ticpe);

/* Importation des taux d'accises sur les tabacs */
PROC IMPORT OUT=taux_tabac (keep = nomen Tx_tabac_20&anr2. Tx_spec_tabac_20&anr2. Tx_min_tabac_20&anr2.) 
DATAFILE="&dossier.\Taux_TVA_nomen5.xls" replace dbms=&excel_imp.; sheet = "Acc_tabac" ; RUN;
%taux_nomen(C02211 C02212 C022131, taux_tabac, Tx_tabac_20&anr2.,tabac);
data _null_  ;
	set taux_tabac ;
	name_mvmin = 'Tx_min_tabac_C'!!nomen ;
	name_mvspec = 'Tx_spec_tabac_C'!!nomen ;
	call symputx(name_mvmin, Tx_min_tabac_20&anr2., 'G');
	call symputx(name_mvspec, Tx_spec_tabac_20&anr2., 'G');
run ;

/***** Importation des taux d'accises sur les alcools *****/
PROC IMPORT OUT=taux_alcool (keep = nomen Accises_alcool_20&anr2. Cotisation_20&anr2. Premix_20&anr2.) 
DATAFILE="&dossier.\Taux_TVA_nomen5.xls" replace dbms=&excel_imp.; sheet = "Acc_alcool" ; RUN;
%let liste_alco = C021111 C021112 C021113 C021114 C021115 C021116 C021117 C021118 C021211 C021212 C021221 C021222 C021223 C02131;
%taux_nomen(&liste_alco., taux_alcool, Accises_alcool_20&anr2., alcool);
data _null_  ;
	set taux_alcool ;
	name_mv1 = 'Cotisation_C'!!nomen ;
	name_mv2 = 'Premix_C'!!nomen ;
	call symputx(name_mv1, Cotisation_20&anr2., 'G');
	call symputx(name_mv2, Premix_20&anr2., 'G');
run ;

/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                                                                           */
/*             II - Calcul des quantités et des taxes (TVA, TCA, droits sur le tabac,        */
/*                                     les alcools et TICPE)                                 */
/*                                                                                           */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

/***** Calcul des quantités et des montants de taxes *****/
data basemen_taxes  ;
	set basemen_BDF (drop = part:  C01--C12);
	
	/***** Calcul des quantités pour les produits sur lesquels il y a des accises *****/
	/*tabac*/
	q_C02211 = C02211 / &px_paq_cigtte. ; /* prix externe donc pas besoin de taux d'inflation (au moins pour 2012) */
	q_C02212 = C02212 / &px_cigare. ; /* prix externe donc pas besoin de taux d'inflation (au moins pour 2012) */
	q_C022131 = C022131 / &px_kilo_tabac. ; /* prix externe donc pas besoin de taux d'inflation (au moins pour 2012) */
	/* carburants */
	q_C04531 = C04531 / &px_litre_fioul. ; 
	q_C072211 = C072211 / (&px_li_essence.*&essence.) ; /* prise en compte de l'inflation */
	q_C072212  = C072212 / (&px_li_diesel.*&gazole.)  ; /* prise en compte de l'inflation */
	/*TODO : il y a px_li_essence et px_li_diesel é partir de prix_moyen_BDF211 et px_litre_diesel é partir de prix_moyen_externe*/
	/* q_C072212  = C072212 / &px_litre_diesel.  ; */

	/* alcool */
	q_C021111 = C021111 / (&px_li_anisette.*&alcool.) ; /* prix issu de la table carnet 2011 donc on applique l'inflation (taux fixé à 0 pr 2011) */
	q_C021112 = C021112 / (&px_li_apero.*&alcool.) ; 
	q_C021113 = C021113 / (&px_li_whisky.*&alcool.) ; 
	q_C021114 = C021114 / (&px_li_eaudevie.*&alcool.) ;
	q_C021115 = C021115 / (&px_li_rhum.*&alcool.) ;
	q_C021116 = C021116 / (&px_li_punch.*&alcool.) ; 
	q_C021117 = C021117 / (&px_li_liqueur.*&alcool.) ;
	q_C021118 = C021118 / (&px_li_cocktail.*&alcool.) ;
	q_C021212 = C021212 / (&px_li_cidre.*&alcool.) ;
	q_C021221 = C021221 / (&px_li_mousseux.*&alcool.) ;
	q_C021222 = C021222 / (&px_li_champ.*&alcool.) ; 
	q_C021223 = C021223 /(&px_li_vindoux.*&alcool.) ;

	/*vin et bière : quantité par déciles */
	%MACRO quantite_dec;
		%do i=1 %to 9;
			if decile =  %str(0&i.) then do ;
				q_C021211 = C021211 / (&&v0&i..*&alcool.) ;	
				q_C02131 = C02131 / (&&b0&i..*&alcool.) ;
			end;
		%end;
	%mend;
	%quantite_dec;
	if decile = '10' then do;
		q_C021211 = C021211 / (&v10.*&alcool.) ;	
		q_C02131 = C02131 / (&b10.*&alcool.) ;
	end;
run;

proc sort data = basemen_taxes; by ident; run;
data basemen_taxes (keep = ident poi revdisp NdV conso_tot decile typmen7 occlog strate montant: )  ;
	set basemen_taxes;
	by ident;
	if first.ident then do ;
		montant_tva=0; montant_tva_N=0; montant_tva_I=0; montant_tva_R=0;  montant_tva_SR=0;
		montant_conso_N=0 ; montant_conso_I=0 ; montant_conso_R=0 ; montant_conso_SR=0 ; montant_conso_E=0 ; 
		montant_assu=0; montant_ticpe=0; montant_tabac=0; montant_alcool=0; montant_alcool_secu=0;
	end;
	
	/*macro pour calculer le montant de tva, total et par type de taux */
	%MACRO montant_tva(Liste, Taux, taxe);
		%do i=1 %to %sysfunc(countw(&Taux.)); 
			%let taux_temp= %scan(&Taux.,&i.); /* type de taux de TVA */	
				%do j=1 %to %sysfunc(countw(&Liste.));
					%let n5_temp= %scan(&Liste.,&j.); /*nomen5*/
					%if &taux_temp.=&&type_&taxe._&n5_temp.. %then %do ;
						montant_&taxe._&taux_temp.=montant_&taxe._&taux_temp.+ &n5_temp.*&&taux_&taxe._&n5_temp../(1+&&taux_&taxe._&n5_temp..) ;
						%end;
					%end;
			montant_&taxe. = montant_&taxe. + montant_&taxe._&taux_temp. ;
			%end;
	%MEND montant_tva;
	/***** Calcul des montants de TVA pour chaque ménage *****/ 
	%montant_tva(&liste_conso.,&liste_taux., tva) ;
	label montant_tva_N = "Montant annuel de TVA acquitté au taux normal" ;
	label montant_tva_I = "Montant annuel de TVA acquitté au taux intermédiaire" ;
	label montant_tva_R = "Montant annuel de TVA acquitté au taux réduit" ;
	label montant_tva_SR = "Montant annuel de TVA acquitté au taux super réduit" ;

	/* Macro pour calculer les dépenses de consommation par type de taux */
	%MACRO montant_conso_tva(Liste, Taux, taxe);
		%do i=1 %to %sysfunc(countw(&Taux.)); 
			%let taux_temp= %scan(&Taux.,&i.); /* type de taux de TVA */	
				%do j=1 %to %sysfunc(countw(&Liste.));
					%let n5_temp= %scan(&Liste.,&j.); /*nomen5*/
					%if &taux_temp.=&&type_&taxe._&n5_temp.. %then %do ;
						montant_conso_&taux_temp.=montant_conso_&taux_temp.+ &n5_temp. ;
						%end;
					%end;	
			%end;
	%MEND montant_conso_tva;
	/***** Calcul des dépenses de consommation par type de taux de TVA *****/ 
	%global liste_taux_exo;
	%let liste_taux_exo = N I R SR E ; 
	%montant_conso_tva(&liste_conso.,&liste_taux_exo., tva) ;
	label montant_conso_N = "Dépenses de consommation imposées au taux normal de TVA" ;
	label montant_conso_I = "Dépenses de consommation imposées au taux intermédiaire de TVA" ;
	label montant_conso_R = "Dépenses de consommation imposées au taux réduit de TVA" ;
	label montant_conso_SR = "Dépenses de consommation imposées au taux super réduit de TVA" ;
	label montant_conso_E = "Dépenses de consommation exonérées de TVA" ;
	
	/***** Calcul des montants de taxes sur les assurances *****/ 
	%MACRO montant_tca(Liste, taxe);
		%do i=1 %to %sysfunc(countw(&Liste.));
			%let n5_temp= %scan(&Liste.,&i.); /*nomen5*/
			montant_&taxe.= montant_&taxe.+ &n5_temp.*&&taux_&taxe._&n5_temp../(1+&&taux_&taxe._&n5_temp..) ;
		%end;
	%MEND montant_tca;
	%montant_tca(&liste_assu.,assu) ;
	label montant_assu = "Montant annuel de cotisation spéciale sur les conventions d'assurance acquitté" ; 
	/***** Calcul des montants de TICPE *****/ 
	%MACRO montant_ticpe(Liste, taxe);
		%do i=1 %to %sysfunc(countw(&Liste.));
			%let n5_temp= %scan(&Liste.,&i.); /*nomen5*/
			montant_&taxe.= montant_&taxe.+ q_&n5_temp.*&&taux_&taxe._&n5_temp../100 ; /*montants en hecto-litres*/
		%end;
	%MEND montant_ticpe;
	%montant_ticpe(&liste_ticpe., ticpe);
	label montant_ticpe = "Montant annuel de taxe intérieure sur les produits énergétiques acquitté" ;
	/***** Calcul des montants de droits sur le tabac *****/ 
	mtab1= max(&Tx_min_tabac_C02211.*q_C02211*(20/1000),C02211*&taux_tabac_C02211.+&Tx_spec_tabac_C02211.*q_C02211*(20/1000)); /* cigarette */
	mtab2= max(&Tx_min_tabac_C02212.*q_C02212/1000,C02212*&taux_tabac_C02212.+&Tx_spec_tabac_C02212.*q_C02212/1000); /* cigares et cigarillos */
	mtab3= max(&Tx_min_tabac_C022131.*q_C022131,C022131*&taux_tabac_C022131.+&Tx_spec_tabac_C022131.*q_C022131); /* Tabac */
	montant_tabac = mtab1+mtab2+mtab3 ;
	label montant_tabac = "Montant annuel de droits sur le tabac (cigarettes, cigares et cigarillos et tabac) acquitté" ;
	drop mtab1-mtab3;
	/***** Calcul des montants de droits de consommation et de cotisations sur les alcools *****/ 
	/** Produits dont l'assiette est le hlap : on suppose le  degré d'alcool à 40° **/
	/* Jusqu'en 2011, l'assiette de la part cotisation est l'hectolitre ; après, uniformisée avec celle des droits de consommation */ 
	%MACRO montant_alcool1(Liste);
		%do i=1 %to %sysfunc(countw(&Liste.));
			%let n5_temp= %scan(&Liste.,&i.); /*nomen5*/
			montant_alcool = montant_alcool + (&&taux_alcool_&n5_temp..*q_&n5_temp.*0.01*0.40); 
			%if &anleg.<=2011 %then %do ;
				montant_alcool_secu = montant_alcool_secu +(&&Cotisation_&n5_temp.*q_&n5_temp.*0.01);
				%end ;
			%if &anleg.>=2012 %then %do ;
				montant_alcool_secu = montant_alcool_secu +(&&Cotisation_&n5_temp.*q_&n5_temp.*0.01*0.40);
				%end ;
		%end;
	%MEND montant_alcool1;
	%let list_alc1 = C021111 C021112 C021113 C021114 C021115;
	%montant_alcool1(&list_alc1.);
	/** Autres produits (hors bière et produit soumis à taxe premix) y compris les vins non soumis à part cotisation **/
	/* Assiette : hectolitre */ 
	%MACRO montant_alcool2(Liste);
		%do i=1 %to %sysfunc(countw(&Liste.));
			%let n5_temp= %scan(&Liste.,&i.); /*nomen5*/
			montant_alcool = montant_alcool + (&&taux_alcool_&n5_temp..*q_&n5_temp.*0.01); 
			montant_alcool_secu = montant_alcool_secu +(&&Cotisation_&n5_temp.*q_&n5_temp.*0.01);
			%end;
	%MEND montant_alcool2;
	%let list_alc2 = C021116 C021117 C021211 C021212 C021221 C021222 C021223;
	%montant_alcool2(&list_alc2.);
	/** Autre produit : cocktails et   soumis à taxe premix  **/
	/* taxe premix : assiette = décilitre d'alcool pur, en supposant une boisson à 10° (limite maximale de la taxe = 12°) */
	/* On l'inclut dans la partie "securité sociale" car reversée à la CNAMTS ; il n'y a pas d'autre cotisation sociale, car s'applique au delà de 18° */
	montant_alcool_secu = montant_alcool_secu +(&Premix_C021118.*q_C021118*10*0.1) ;
	/* Droits de consommation : on applique le taux des produits intermédiaires */
	montant_alcool = montant_alcool +(&taux_alcool_C021118.*q_C021118*0.01);  
	/** Bières : on suppose le degré d'alcool à 6° et seulement des bières industrielles **/
	/* Pas de part cotisation car degré d'alcool supposé < 18 % */
	montant_alcool = montant_alcool +(&taux_alcool_C02131.*q_C02131*0.01*6) ;
	label montant_alcool = "Montant annuel des droits de consommation sur les alcools acquitté (hors cotisation sécurité sociale)" ;
	label montant_alcool_secu = "Montant annuel des cotisations de sécurité sociale sur les alcools acquitté" ;
	run ;

/*copie de la table dans la librairie taxind*/
data taxind.basemen_taxes ;	set basemen_taxes; run;


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
