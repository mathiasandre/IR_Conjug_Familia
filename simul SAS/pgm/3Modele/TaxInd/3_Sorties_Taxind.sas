/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*																					      */
/*            	             TAUX D'EFFORT et TAXES PAYEES                         		  */
/*																					      */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

 
/* Tables d'entrée : basemen_taxes                                                        */
			
/******************************************************************************************/

/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                      */
/*     I - Taux d'effort                */
/*                                      */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

/* Calcul des taux d'effort (en % du revenu disponible et de la consommation totale) 
des taxes indirectes dans INES, agrégés, par déciles de niveau de vie et par types de ménage, 
pour les exporter et les représenter graphiquement dans un fichier excel. */

/* Agrégation de la table contenant les taxes au niveau ménage par déciles de niveau de vie */
%Sum_by_Class(basemen_taxes, decile, poi, revdisp, revdisp conso_tot &liste_taxes.) ;

/* Agrégation de la table contenant les taxes au niveau ménage par type de ménage */
/* On construit la variable typmen5 à partir de typmen7 (regroupement des modalités 5 à 9 pour avoir une seule catégorie de ménages complexes) */
data basemen_taxes  ;
	set basemen_taxes;
	typmen5='                      ' ;
	/* Reconstruction de typmen5 */
	if typmen7 = '1' then typmen5 = '1_celibataire' ;
	else if typmen7 = '2' then typmen5 = '2_monoparentale' ;
	else if typmen7 = '3' then typmen5 = '3_couple_sans_enfant' ;
	else if typmen7 = '4' then typmen5 = '4_couple_avec_enfants' ;
	else if typmen7 in ('5', '6', '9') then typmen5='5_menage_complexe' ;
	run ;

%Sum_by_Class(basemen_taxes, typmen5, poi, revdisp, revdisp conso_tot &liste_taxes.) ;

proc means 
		data=basemen_taxes (where = (revdisp> 0)) noprint  ;
		var  revdisp conso_tot montant:;
		weight poi ;
		output out=basemen_taxes_agrege(drop=_type_ _freq_)  sum= ;
	run ;

/***** Calcul des taux d'effort *****/
%MACRO effort_taxes(table) ;
data &table. ; 
	set &table. ; 
	/* taux d'effort en fonction du revenu disponible */
	%Calcul_Part(&liste_taxes., revdisp, suffixe = _R);
	/* taux d'effort en fonction de la consommation totale */
	%Calcul_Part(&liste_taxes., conso_tot, suffixe = _C);
run ;
%MEND effort_taxes ;

%effort_taxes(basemen_taxes_decile) ;
%effort_taxes(basemen_taxes_typmen5) ;
%effort_taxes(basemen_taxes_agrege) ;



/* Exportation des résultats clés sur le taux d'épargne dans INES */
data result_ines_dec ;
 	set basemen_BDF_decile (keep = decile revdisp conso_tot part_C01 part_C02 part_C03 part_C04 part_C05 part_C06 part_C07 part_C08 part_C09 part_C10 part_C11 part_C12 part_conso_tot tx_epargne) ;
run ;

data result_ines_agr ;
 	set basemen_BDF_agrege (keep = revdisp conso_tot part_C01 part_C02 part_C03 part_C04 part_C05 part_C06 part_C07 part_C08 part_C09 part_C10 part_C11 part_C12 part_conso_tot tx_epargne) ;
run ;

data result_ines_conso_dec ;
 	set basemen_BDF_decile  (keep = decile conso_tot &liste_conso_12. part_C01_C part_C02_C part_C03_C part_C04_C part_C05_C part_C06_C part_C07_C part_C08_C part_C09_C part_C10_C part_C11_C part_C12_C) ;
run ;

data result_ines_conso_agr ;
 	set basemen_BDF_agrege (keep = conso_tot &liste_conso_12. part_C01_C part_C02_C part_C03_C part_C04_C part_C05_C part_C06_C part_C07_C part_C08_C part_C09_C part_C10_C part_C11_C part_C12_C) ;
run ;

proc export data=result_ines_dec	outfile="&sortie_cible./Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="Ines_deciles"; run;
proc export data=result_ines_agr 	outfile="&sortie_cible./Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="Ines_total"; run;
proc export data=result_ines_conso_dec	outfile="&sortie_cible./Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="Ines_conso_deciles"; run;
proc export data=result_ines_conso_agr 	outfile="&sortie_cible./Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="Ines_conso_total"; run;


/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                                                                           */
/*                        II - Exportation des estimations de taxes                          */
/*                                                                                           */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/


/***** Montants par déciles de niveau de vie *****/
proc means 
	data = basemen_taxes ;
	var montant_conso_N montant_conso_I montant_conso_R montant_conso_SR montant_conso_E montant_tva montant_tva_N montant_tva_I montant_tva_R montant_tva_SR montant_assu montant_tabac montant_alcool montant_alcool_secu montant_ticpe ;
	class decile ;
	weight poi ;
	output out = taxes_bydec (drop = _type_ _freq_ ) sum = ; 
run ;
proc export data = taxes_bydec outfile="&sortie_cible./Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls"  dbms=&excel_exp. replace ; sheet = "Montants_deciles" ;run ;

/***** Montants par type de ménages *****/
proc means 
	data = basemen_taxes ;
	var montant_conso_N montant_conso_I montant_conso_R montant_conso_SR montant_conso_E montant_tva montant_tva_N montant_tva_I montant_tva_R montant_tva_SR montant_assu montant_tabac montant_alcool montant_alcool_secu montant_ticpe ;
	class typmen5 ;
	weight poi ;
	output out = taxes_bymenage (drop = _type_ _freq_ ) sum = ; 
run ;
proc export data = taxes_bymenage outfile="&sortie_cible./Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls"  dbms=&excel_exp. replace ; sheet = "Montants_type_menages" ;run ;


/***** Exportation des résultats des taux d'effort *****/
data taxes_rev_dec ;
 	set basemen_taxes_decile (keep = decile part_montant_tva_R part_montant_tva_N_R part_montant_tva_I_R part_montant_tva_R_R part_montant_tva_SR_R part_montant_assu_R part_montant_tabac_R part_montant_alcool_R part_montant_alcool_secu_R part_montant_ticpe_R) ;
run ;
data taxes_rev_men ;
 	set basemen_taxes_typmen5 (keep = typmen5 part_montant_tva_R part_montant_tva_N_R part_montant_tva_I_R part_montant_tva_R_R part_montant_tva_SR_R part_montant_assu_R part_montant_tabac_R part_montant_alcool_R part_montant_alcool_secu_R part_montant_ticpe_R) ;
run ;
data taxes_rev_agr ;
 	set basemen_taxes_agrege (keep = part_montant_tva_R part_montant_tva_N_R part_montant_tva_I_R part_montant_tva_R_R part_montant_tva_SR_R part_montant_assu_R part_montant_tabac_R part_montant_alcool_R part_montant_alcool_secu_R part_montant_ticpe_R) ;
run ;
data taxes_conso_dec ;
 	set basemen_taxes_decile (keep = decile part_montant_tva_C part_montant_tva_N_C part_montant_tva_I_C part_montant_tva_R_C part_montant_tva_SR_C part_montant_assu_C part_montant_tabac_C part_montant_alcool_C part_montant_alcool_secu_C part_montant_ticpe_C) ;
run ;
data taxes_conso_men ;
 	set basemen_taxes_typmen5 (keep = typmen5 part_montant_tva_C part_montant_tva_N_C part_montant_tva_I_C part_montant_tva_R_C part_montant_tva_SR_C part_montant_assu_C part_montant_tabac_C part_montant_alcool_C part_montant_alcool_secu_C part_montant_ticpe_C) ;
run ;
data taxes_conso_agr ;
 	set basemen_taxes_agrege (keep = part_montant_tva_C part_montant_tva_N_C part_montant_tva_I_C part_montant_tva_R_C part_montant_tva_SR_C part_montant_assu_C part_montant_tabac_C part_montant_alcool_C part_montant_alcool_secu_C part_montant_ticpe_C) ;
run ;

proc export 
		data=taxes_rev_dec
		outfile="&sortie_cible./Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls"  dbms=&excel_exp. replace ; 
		sheet ="Part Rev Deciles" ;
	run ;
proc export 
	data=taxes_rev_men
	outfile="&sortie_cible./Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls"  dbms=&excel_exp. replace ; 
	sheet ="Part Rev Menages" ;
run ;
proc export 
	data=taxes_rev_agr
	outfile="&sortie_cible./Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls"  dbms=&excel_exp. replace ; 	
	sheet ="Part Revenus" ;
run ;
proc export 
		data=taxes_conso_dec
		outfile="&sortie_cible./Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls"  dbms=&excel_exp. replace ; 
		sheet ="Part conso deciles" ;
	run ;
proc export 
	data=taxes_conso_men
	outfile="&sortie_cible./Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls"  dbms=&excel_exp. replace ; 
	sheet ="Part conso menages" ;
run ;
proc export 
	data=taxes_conso_agr
	outfile="&sortie_cible./Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls"  dbms=&excel_exp. replace ; 	
	sheet ="Part conso" ;
run ;



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
