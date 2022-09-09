/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*																					      */
/*            	             TAUX DE CONSOMMATION ET D'EPARGNE                            */
/*																					      */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

/* Le programme permet de calculer les taux de consommation et d'épargne à l'issue du 
calage des revenus dans BDF pour vérifier que les agrégats 
et les taux de consommation et d'épargne sont cohérents avec la CN et BDF */

/* Tables et fichiers d'entrées : 
		- base20&anr2. (Base BDF avec revenu disponible et dépenses calés)   
		- dossier.prix_moyen_&anBDF. 
		- dossier.prix_&anBDF._vin 
		- dossier.prix_&anBDF._biere
		- coef_calage
*/

/* Fichier de sortie :
		- Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls  */	
/******************************************************************************************/

/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                                                                                              */  
/*                 Calcul des taux de consommation (12 postes et total) et du taux d'épargne                    */
/*                                                                                                              */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/


/* Base20&anr2. BDF (revenus et conso calés) agrégée par déciles de niveau de vie */
%Sum_by_Class(base20&anr2., dec_aj, pondmen, revdisp_aj, revdisp_aj conso_tot &liste_conso_12.) ;

/***** Calcul des taux de consommation et épargne *****/
data base20&anr2._dec_aj ; 
	set base20&anr2._dec_aj ; 
	%Calcul_Part(&liste_conso_12., revdisp_aj);
	/* Part dans le revenu disponible BDF calé"*/
	if revdisp_aj=0 then part_conso_tot = 0;
	else part_conso_tot = conso_tot/revdisp_aj;
	label part_conso_tot= "Part de la consommation totale dans le revenu disponible BDF calé" ;
	tx_epargne = 1 - part_conso_tot ;
	label tx_epargne = "Taux d'épargne" ;
	%Calcul_Part(&liste_conso_12., conso_tot, suffixe = _C);
	/* En % de la consommation totale */
run ;

/* Base20&anr2. BDF (revenus et conso calés) agrégée */
proc means 
		data=  base20&anr2. (where = (revdisp_aj> 0)) noprint;
		var revdisp_aj conso_tot &liste_conso_12. ;
		weight pondmen ;
		output out=base20&anr2._agrege (drop=_type_ _freq_)  sum= ;
	run ;

/***** Calcul des taux de consommation et épargne *****/
data base20&anr2._agrege; 
	set base20&anr2._agrege ; 
	%Calcul_Part(&liste_conso_12., revdisp_aj);
	/* Part dans le revenu disponible BDF calé"*/
	if revdisp_aj=0 then part_conso_tot = 0;
	else part_conso_tot = conso_tot/revdisp_aj;
	label part_conso_tot= "Part de la consommation totale dans le revenu disponible BDF calé" ;
	tx_epargne = 1 - part_conso_tot ;
	label tx_epargne = "Taux d'épargne" ;
	%Calcul_Part(&liste_conso_12., conso_tot, suffixe = _C);
	/* En % de la consommation totale */
run ;


/* Exportation des résultats clés sur le taux d'épargne de BDF calé */
data result_dec ;
 	set base20&anr2._dec_aj (keep = dec_aj revdisp_aj conso_tot part_C01 part_C02 part_C03 part_C04 part_C05 part_C06 part_C07 part_C08 part_C09 part_C10 part_C11 part_C12 part_conso_tot tx_epargne) ;
run ;

data result_agr ;
 	set base20&anr2._agrege (keep = revdisp_aj conso_tot part_C01 part_C02 part_C03 part_C04 part_C05 part_C06 part_C07 part_C08 part_C09 part_C10 part_C11 part_C12 part_conso_tot tx_epargne) ;
run ;

data result_conso_dec ;
 	set base20&anr2._dec_aj (keep = dec_aj conso_tot &liste_conso_12. part_C01_C part_C02_C part_C03_C part_C04_C part_C05_C part_C06_C part_C07_C part_C08_C part_C09_C part_C10_C part_C11_C part_C12_C) ;
run ;

data result_conso_agr ;
 	set base20&anr2._agrege (keep = conso_tot &liste_conso_12. part_C01_C part_C02_C part_C03_C part_C04_C part_C05_C part_C06_C part_C07_C part_C08_C part_C09_C part_C10_C part_C11_C part_C12_C) ;
run ;

/* sorties dans des onglets spécifiques */
proc export data=result_dec	outfile="&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="BDF_deciles"; run;
proc export data=result_agr	outfile="&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="BDF_total"; run;
proc export data=result_conso_dec	outfile="&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="BDF_conso_deciles"; run;
proc export data=result_conso_agr	outfile="&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="BDF_conso_total"; run;



/********** On exporte les prix calculés à partir des carnets  **********/
/* TODO : voir si on conserve cette étape. Pas indispensable si on exporte les tables SAS dans les paramètres */
proc export data = dossier.prix_moyen_&anBDF. outfile="&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace ; sheet = "Prix_moyen_bdf&anBDF." ; run ;
proc export data = dossier.prix_&anBDF._vin (keep = dec_aj effectif px_li_vin)  outfile = "&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace ; sheet = "prix_vin_bdf&anBDF." ; run ;
proc export data = dossier.prix_&anBDF._biere (keep = dec_aj effectif px_li_biere) outfile = "&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace ; sheet = "prix_biere_bdf&anBDF." ; run ;


/** exportation des coefficients de calage sur la CN **/
data coeffs_CN ; set coef_calage (keep = nomen3 CN20&anr2. dep_BDF&anBDF. coef_cal_20&anr2.) ; run ;
proc export data=coeffs_CN	outfile="&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="Coef_calage"; run;



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
