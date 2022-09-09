/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*																					      */
/*            	             TAUX DE CONSOMMATION ET D'EPARGNE                            */
/*																					      */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

/* Le programme permet de calculer les taux de consommation et d'�pargne � l'issue du 
calage des revenus dans BDF pour v�rifier que les agr�gats 
et les taux de consommation et d'�pargne sont coh�rents avec la CN et BDF */

/* Tables et fichiers d'entr�es : 
		- base20&anr2. (Base BDF avec revenu disponible et d�penses cal�s)   
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
/*                 Calcul des taux de consommation (12 postes et total) et du taux d'�pargne                    */
/*                                                                                                              */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/


/* Base20&anr2. BDF (revenus et conso cal�s) agr�g�e par d�ciles de niveau de vie */
%Sum_by_Class(base20&anr2., dec_aj, pondmen, revdisp_aj, revdisp_aj conso_tot &liste_conso_12.) ;

/***** Calcul des taux de consommation et �pargne *****/
data base20&anr2._dec_aj ; 
	set base20&anr2._dec_aj ; 
	%Calcul_Part(&liste_conso_12., revdisp_aj);
	/* Part dans le revenu disponible BDF cal�"*/
	if revdisp_aj=0 then part_conso_tot = 0;
	else part_conso_tot = conso_tot/revdisp_aj;
	label part_conso_tot= "Part de la consommation totale dans le revenu disponible BDF cal�" ;
	tx_epargne = 1 - part_conso_tot ;
	label tx_epargne = "Taux d'�pargne" ;
	%Calcul_Part(&liste_conso_12., conso_tot, suffixe = _C);
	/* En % de la consommation totale */
run ;

/* Base20&anr2. BDF (revenus et conso cal�s) agr�g�e */
proc means 
		data=  base20&anr2. (where = (revdisp_aj> 0)) noprint;
		var revdisp_aj conso_tot &liste_conso_12. ;
		weight pondmen ;
		output out=base20&anr2._agrege (drop=_type_ _freq_)  sum= ;
	run ;

/***** Calcul des taux de consommation et �pargne *****/
data base20&anr2._agrege; 
	set base20&anr2._agrege ; 
	%Calcul_Part(&liste_conso_12., revdisp_aj);
	/* Part dans le revenu disponible BDF cal�"*/
	if revdisp_aj=0 then part_conso_tot = 0;
	else part_conso_tot = conso_tot/revdisp_aj;
	label part_conso_tot= "Part de la consommation totale dans le revenu disponible BDF cal�" ;
	tx_epargne = 1 - part_conso_tot ;
	label tx_epargne = "Taux d'�pargne" ;
	%Calcul_Part(&liste_conso_12., conso_tot, suffixe = _C);
	/* En % de la consommation totale */
run ;


/* Exportation des r�sultats cl�s sur le taux d'�pargne de BDF cal� */
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

/* sorties dans des onglets sp�cifiques */
proc export data=result_dec	outfile="&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="BDF_deciles"; run;
proc export data=result_agr	outfile="&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="BDF_total"; run;
proc export data=result_conso_dec	outfile="&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="BDF_conso_deciles"; run;
proc export data=result_conso_agr	outfile="&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="BDF_conso_total"; run;



/********** On exporte les prix calcul�s � partir des carnets  **********/
/* TODO : voir si on conserve cette �tape. Pas indispensable si on exporte les tables SAS dans les param�tres */
proc export data = dossier.prix_moyen_&anBDF. outfile="&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace ; sheet = "Prix_moyen_bdf&anBDF." ; run ;
proc export data = dossier.prix_&anBDF._vin (keep = dec_aj effectif px_li_vin)  outfile = "&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace ; sheet = "prix_vin_bdf&anBDF." ; run ;
proc export data = dossier.prix_&anBDF._biere (keep = dec_aj effectif px_li_biere) outfile = "&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace ; sheet = "prix_biere_bdf&anBDF." ; run ;


/** exportation des coefficients de calage sur la CN **/
data coeffs_CN ; set coef_calage (keep = nomen3 CN20&anr2. dep_BDF&anBDF. coef_cal_20&anr2.) ; run ;
proc export data=coeffs_CN	outfile="&sortie_cible.\Sorties_Taxind&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.)).xls" dbms=&excel_exp. replace; sheet="Coef_calage"; run;



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
