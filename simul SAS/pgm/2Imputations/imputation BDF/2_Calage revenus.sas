/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*																					   */
/*       CALAGE DU REVENU DISPONIBLE ET PREPARATION AVANT ETAPE D'APPARIEMENT	       */
/*																					   */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

/* Le programme pr�pare la table avec revenus et d�penses de consommation avant le 
calcul des taux de consommation � imputer : revenu disponible par d�ciles de niveau de 
vie dans BDF et INES, calcul des coefficients de calage du revenu et ajustement sur INES 
et enfin fusion avec la table de consommation  */

/* Tables d'entr�es : 
		- bdf&anBDF..menage (donn�es socio-d�mo et de revenu - 1 obs = 1 m�nage)
		- bdf&anBDF..C05 
		- bdf&anBDF..depmen (d�penses du m�nage recueillies dans le questionnaire - 1 obs = 1 m�nage)
		- conso_aj  (du programme 1_calage consommation)
		- rpm.menage&anr.*/

/* Fichier en entr�e : revdisp_ines_taxind.xls (revenu disponible par d�cile de niveau de vie, issu d'INES 
						(1 onglet par ann�e) */

/* Tables de sortie : 
		- base20&anr2. (base BDF avec consommation et revenu disponible cal�s et 
		  variables socio-d�mo pour constituer les strates avant l'appariement ; 
		  obs = m�nage)	
		- ressources_erfs
		- coef_calage_rev	*/ 

/* Le programme comporte 2 �tapes : 	
/*	I   - On agr�ge le revenu disponible par d�ciles de niveau de vie, on calcule les 
		  coefficients de calage et on ajuste le revenu de BDF sur celui d'ERFS ajust�        */ 
/* 	II  - On fusionne les tables depenses et ressources qui contiennent le revenu et
		  les d�penses cal�s															*/  
                       											                    
/****************************************************************************************/


/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                                                                                              */  
/*                          I - Calage des revenus de BDF sur les revenus d'ERFS ajust�                               */
/*                                                                                                              */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/


/*ZZZZZZZZZZZZZZZZZZZZ Pr�paration de la table des revenus dans BDF ZZZZZZZZZZZZZZZZZZZZ*/

/***** On ne conserve que revtot total et imp�ts et les variables utiles � la construction des d�ciles 
de niveau de vie (en m�tropole, pour �tre sur le m�me champ qu'ERFS) *****/
data ressources (where =(zeat not in ("0")) rename = (ident_men = ident)); 
	merge bdf&anBDF..menage (keep = ident_men pondmen npers coeffuc zeat revtot rev701 rev702 revact revsoc revpat rev700 rev999)  
		  bdf&anBDF..C05 (keep = ident_men C13141 C14111) 
		  bdf&anBDF..depmen (keep = ident_men mhab_d);
	by ident_men ;
	if mhab_d = . then mhab_d=0;
 	/***** On construit le revenu disponible et les variables n�cessaires aux d�ciles de niveau de vie *****/
	revdisp_BDF = revtot - C13141 - mhab_d ; /*moins l'IR et TH */
	/* on enl�ve les transferts libres entre m�nages (non obligatoires, r�guliers ou non :: rev701 et rev702)*/
	revdisp_BDF=revdisp_BDF - rev701 - rev702 ;
	label revdisp_BDF = "Ressources totales de BDF (y compris prestations sociales et pensions alimentaires) nettes de IR et TH " ;
	poidsindiv = pondmen*npers ;
	nv = revdisp_BDF/coeffuc ; 
run ; 

/* construction des d�ciles de niveau de vie, �chelle individus */
/*on a renomm� temporairement ident_men ci-dessus pour pouvoir utiliser la macro quantile*/
%quantile(10,ressources,nv,poidsindiv,dec);
data ressources (rename = ident = ident_men) ;
	set ressources;
run;

/***** Agr�gation du revenu disponible de BDF par d�ciles de niveau de vie *****/
proc means 
		data=ressources noprint;
		var revdisp_BDF;
		class dec ;
		weight pondmen;
		output out=rev_agr_BDF (drop=_type_ _freq_ where = (dec not in (" ")))  sum= ;
run ;

/*ZZZZZZZZZZZZZZZZZZZZ Pr�paration de la table des revenus ERFS ZZZZZZZZZZZZZZZZZZZZ*/

/***** Variables de revenu disponible de l'ERFS *****/
data ressources_erfs;
	set rpm.menage&anr. (rename = (ident&anr.=ident wpri=poidsindiv wprm = poi));
	keep ident poidsindiv poi nb_uci revdispm zthabm zimpom csgdm csgim crdsm nv revdisp_erfs ; 
	revdisp_erfs= revdispm;
	label revdisp_erfs = "Ressources totales (y compris prestations sociales et pensions alimentaires) nettes de l'imp�t sur le revenu et de TH dans (revdisp ERFS)" ;
	nv = revdisp_erfs/nb_uci ;   
run ;

/***** Construction des d�ciles de niveau de vie dans ERFS *****/
%quantile(10,ressources_erfs,nv,poidsindiv,dec);

/*Il est n�cessaire d'appliquer une rustine sur la distribution par d�cile du revenu disponible ERFS car : 
	1) il faut tenir compte de l'inflation entre &anr. (ERFS) et &anr2. (Ines / BDF actualis�)
	2) la structure par d�cile du revenu disponible ERFS et Ines sont diff�rentes (prestations nulles dans le D1 par exemple */
/* On utilise la distribution par d�cile du revenu disponible Ines (calcul� sans taxation indirecte : faire tourner Ines avant l'utilisation du module) */

/* D�ciles ERFS avant rustine */
proc means 
		data=ressources_erfs noprint;
		var revdisp_erfs;
		class dec ;
		weight poi;
		output out=rev_dec_ERFS&anr. (drop=_type_ _freq_ where = (dec not in (" ")))  sum= ;
run ;
/* On importe les d�ciles Ines */
%importFichier(revdisp_ines_taxind,feuille=rev_disp&anr2.,table=revdisp_ines); 
/* Ratio de calage par d�cile */
data coef_calage_ines ; 
	merge rev_dec_ERFS&anr. (in =a)  dossier.revdisp_ines  ; 
	by dec ; 
	coef_cal_dec = revdisp_ines&anr2./revdisp_erfs ; 
run ;
/* Application de la rustine sur la variable revdisp de l'ERFS */
proc sort data=ressources_erfs; by dec ; run;
data ressources_erfs; 
	merge ressources_erfs (in =a) coef_calage_ines (keep = dec coef_cal_dec)   ; 
	by dec ; 
	if a ; 
	revdisp_erfs_aj = revdisp_erfs * coef_cal_dec;
	nv_aj=revdisp_erfs_aj/nb_uci ;  
run;
/* D�ciles ERFS apr�s rustine*/
/* On recalcule la distribution apr�s le premier calage entre ERFS et INES ; servira pour la cosntruction des strates d'imputation */
%quantile(10,ressources_erfs,nv_aj,poidsindiv,dec_aj); 
proc means 
		data=ressources_erfs noprint;
		var revdisp_erfs_aj;
		class dec_aj ;
		weight poi;
		output out=rev_ERFS_aj (drop=_type_ _freq_ where = (dec_aj not in (" ")))  sum= ;
run ;

/*ZZZZZZZZZZZZZZZZZZZZ Calcul des coefficients de calage pour BDF ZZZZZZZZZZZZZZZZZZZZ*/ 

/***** Fusion des 2 tables de revenus agr�g�s et calcul des coefficients de calage *****/
data coef_calage_rev ; 
	merge rev_agr_BDF rev_ERFS_aj (rename=(dec_aj=dec)) ; /* on renomme pour la fusion dec_aj en dec */ 
	by dec ; 
	coef_20&anr2. = revdisp_erfs_aj / revdisp_BDF  ; 
run ;

/***** On ajoute les coefficients de calage et on ajuste les revenus de BDF *****/ 
/*Les deux calages successifs sont �quivalents � un seul calage 
mais on laisse les deux �tapes distinctes si une am�lioration post�rieure 
souhaiterait affiner le premier sur l'ERFS en conservant le minima sur Ines
*/
proc sort data=ressources; by dec ; run;
data ressources (drop= coef_20&anr2. revtot C13141 revact revsoc revpat rev700 rev999 revdisp_bdf); 
	merge ressources (in=a rename=(ident_men=ident)) coef_calage_rev (keep = dec coef_20&anr2.)   ; 
	by dec ; 
	if a ; 
	revdisp_aj=revdisp_BDF*coef_20&anr2. ;
	C14111_aj=C14111*coef_20&anr2.; /*Allocation logement re�u*/
	revact_aj=revact*coef_20&anr2.;
	revsoc_aj=revsoc*coef_20&anr2.;
	revpat_aj=revpat*coef_20&anr2.;
	rev700_aj=rev700*coef_20&anr2.; /*revenus per�us par autres m�nages (vers�s obligatoirement)*/
	rev999_aj=rev999*coef_20&anr2.; /*autres ressources*/
	label revdisp_aj = "Ressources totales (y compris prestations sociales et pensions alimentaires) nettes de IR, TF et TH (BDF cal� sur Ines par d�ciles)" ;
	nv_aj = revdisp_aj/coeffuc ; 
run;
%quantile(10,ressources,nv_aj,poidsindiv,dec_aj); /* d�cile de nv apr�s ajustement */
/*on a renomm� temporairement ident_men ci-dessus pour pouvoir utiliser la macro quantile*/
data ressources (rename = (ident = ident_men)) ;
	set ressources;
run;

/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                                                                                              */  
/*                        II - Fusion des tables de d�penses et de revenus cal�s                               */
/*                                                                                                              */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

/***** Fusion des tables d�penses et ressources (cal�s) et choix des variables socio-d�mographiques utiles � la
construction des strates pour l'appariement *****/

proc sort data = conso_aj ; by ident_men ; run ;
proc sort data = ressources ; by ident_men ; run ;

data base20&anr2. ; 
	merge ressources (in =a ) conso_aj  	
			bdf&anBDF..menage (keep = ident_men pondmen typmen5 tuu cs42pr varia varib varic varif agepr exrecr sexepr revact revsoc revpat rev700 rev999 rename = (typmen5 = typmen7)) 
			bdf&anBDF..depmen (keep = ident_men stalog)  
			bdf&anBDF..c05 (keep=ident_men C14111 C13111 C13121);
	by ident_men ;
	if a ; 
/*R�int�gration des APL dans la consommation (exclus des loyers BDF)*/
	C04111 = C04111  + C14111_aj ; /*loyers hors charge + APL*/
run ;

data base20&anr2.;
/*on renomme temporairement ident_men pour pouvoir utiliser la macro quantile*/
	set base20&anr2. ;
/* Agr�gation des d�penses en grandes fonctions de consommation */
	%sum_conso(C0,9);
	C10 = sum(of C10:);
	C11 = sum(of C11:);
	C12 = sum(of C12:);
	/* Consommation totale */
	conso_tot = sum(0, C01, C02, C03, C04, C05, C06, C07, C08, C09, C10, C11, C12) ;

/***** Construction des classes d'�ge *****/
	  	 	 if (agepr<30) 		then tranche_age="01"; 
		else if (30<=agepr<40) 	then tranche_age="02";
	  	else if (40<=agepr<50) 	then tranche_age="03";
		else if (50<=agepr<60) 	then tranche_age="04";
		else if (60<=agepr<70) 	then tranche_age="05";
		else if (70<=agepr) 	then tranche_age="06";
		else tranche_age="07"; 
run ;


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
