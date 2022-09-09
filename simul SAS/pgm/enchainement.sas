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

Le fait que vous puissiez accéder à cet en-tête signifie que vous avez pris 
connaissance de la licence CeCILL V2.1, et que vous en avez accepté les
termes.
****************************************************************/

/************************************************************************************************/
/* 										ENCHAINEMENT 											*/
/*																								*/
/* Ce programme constitue l'enchaînement de l'ensemble des programmes du modèle Ines. 			*/
/* Il est à exécuter dans son intégralité pour faire tourner le modèle. 						*/
/* En entrée : tables de l'ERFS	et fichiers Excel de paramètres									*/
/* En sortie : tables Sas et sorties Excel												 		*/
/* Dans l'utilisation classique d'Ines, seul le premier bloc est à modifier par l'utilisateur. 	*/
/*																								*/
/* DERNIERE MISE A JOUR STABLE : 	législation 2017 / ERFS 2015							    */
/* EN COURS DE DEVELOPPEMENT : 	législation 2018 / ERFS 2016		(pour été 2019)				*/
/*																								*/
/************************************************************************************************/

/***********************************************/
/* PARAMETRAGE : BLOC A MODIFIER A CHAQUE FOIS */
/***********************************************/

/* PARAMETRAGE GENERAL */
%let anref=2015;	/*	Millésime ERFS
						Anref+2 correspondra à la population simulée */
%let anleg=2017;	/* 	Année de législation Ines simulée
						Le plus souvent anref+2=anleg mais découplage en principe possible */

/* CONTEXTES PARTICULIERS */
%let casd=non; 				/* Entrer oui pour une utilisation d'Ines dans le cadre du CASD */
%let noyau_uniquement=oui; 	/* Entrer oui sauf si l'on souhaite travailler sur l'élargie pour les ERFS<=2012 */
%let tx=1; 					/* Si anleg<anref+2, entrer variation de l'IPC sur la période (ou quelque chose qui y ressemble). Sinon, entrer 1 */
%let retropole=non;			/* Entrer oui pour utiliser les tables de l'ERFS rétropolées en 2012, 2013 et 2014 ==> non dans le cadre du CASD*/
%let Nowcasting=non; 		/* Ne mettre oui que dans le cadre du nowcasting */
%let inclusion_TaxInd=non; 	/* Avec ou sans simulations des taxes indirectes (pseudo-appariement avec Budget Des Familles). */
							/* Si oui, il faut avoir fait tourner Ines au préalable 1 fois (avec "non" renseigné) */
%let anBDF=2011; 			/* Année de l'enquête BDF pour taxation indirecte */
%let module_ASS=non;   /* Ne mettre oui que dans le cadre d'études sur l'ASS */

/* EVENTUELLES PREMIERES EXECUTIONS (programmes qui ne doivent tourner qu'une fois par couplet [anref ; anleg]) */
%let Anref_Ech_prem=non; 	/* Est-ce la 1ère fois qu'Ines tourne sur ce millésime ERFS ? Entrer oui ou non */
%let imputEnf_prem=non; 	/* L'imputation des enfants à naître tourne-t-elle pour la 1ère fois ? Sera mis d'office à non après exécution du programme (si casd, mettre toujours à non) */
%let accedant_prem=non; 	/* L'imputation des AL accédants tourne-t-elle pour la 1ère fois ? Sera mis d'office à non après exécution du programme */
%let imputHsup_prem=non; 	/* L'imputation des rémunérations d'heures supplémentaires tourne-t-elle pour la 1ère fois ? Sera mis d'office à non après exécution du programme */

/* CONFIGURATION SELON VERSION DU LOGICIEL ET PREFERENCES */
%let excel=xls; 	/* Pour l'import du fichier de config (Config_chemin.xls). Exemples : xls ou excels à la Drees, excel2000 sur les postes Insee, xls sous AUS */
%let import=oui; 	/* Import des paramètres (entrer oui sauf exception) */
options source2; 	/* Options pour que les codes des fichiers en %include s'affichent dans la log */
options mprint; 	/* ou nomprint en fonction des préférences */

/* Programme permettant d'analyser les performances du modèle. Tourne en 2 temps et nécessite une version de SAS en anglais */
/* %include "&chemin_dossier.\pgm\99utiles\PerformanceAnalysis.sas"; */ /* ouvrir ce programme pour plus d'informations */


/****************************************************/
/* 0	CHEMINS, LIBRAIRIES, MACROS, PARAMETRES		*/
/****************************************************/

%let anr=%substr(&anref.,3,2);
%let anr1=%substr(%eval(&anref.+1),3,2);
%let anr2=%substr(%eval(&anref.+2),3,2);

%let ListeParam_Valeurs=&anref. &anleg. &sysuserid. &casd. &noyau_uniquement. &tx. &module_ASS. &Nowcasting. &inclusion_TaxInd. &Anref_Ech_Prem. &imputEnf_prem. &accedant_prem. &imputHsup_prem. &retropole.;

/* Paramètres de configuration pour chaque utilisateur, en deux temps */
%macro Config_chemin;
	/* Config-1 : En sortie : &chemin_ines. (où aller chercher le fichier Config_perso.sas) */
	proc sql noprint;
		select xpath into :progname
		from sashelp.vextfl where xpath like '%enchainement.sas'; /* Répertoire racine */
		quit;
	%let progpathroot=%sysfunc(substr(&progname.,1,%sysfunc(find(&progname.,\enchainement.sas))-1)); /* Donne le chemin absolu de enchainement.sas */
	%let my_id = %sysfunc(compress(&sysuserid., ".")); /*on enlève les points dans les identifiants*/
	%let my_id = %sysfunc(compress(&my_id., "-")); /*on enlève les tirets dans les identifiants*/
	proc import datafile="&progpathroot.\..\parametres\config_chemin.xls" out=config_chemin(keep=sysuserID &my_id.) dbms=&excel. replace; run;
	data _null_; set config_chemin; call symputx(strip(sysuserid),strip(&my_id.),'G');run; /* MV globales */
	proc delete data=config_chemin; run;
	%put Répertoire pour &my_id. : &chemin_ines.;
	%mend Config_chemin;
%Config_chemin;

%include "&chemin_ines.\pgm\config_perso.sas"; /* Config-2 : En sortie : &chemin_dossier. et &chemin_bases. */
%include "&chemin_dossier.\pgm\chemins.sas"; /* Définit d'autres chemins plus détaillés */
%include "&chemin_dossier.\pgm\libname.sas";
%include "&chemin_dossier.\pgm\macros.sas"; /* Compilation des macros qui serviront dans la suite d'Ines */
%include "&chemin_dossier.\pgm\macros_OrgaCases.sas"; /* Compilation de macros spécifiques */
%include "&chemin_dossier.\pgm\parametres.sas"; /* Import des paramètres législatifs */


/********************************/
/*	1	PREPARATION	(Amont)		*/
/********************************/

/* Préparation */
%include "&init.\0_initialisation_ERFS.sas";
%include "&init.\1_initialisation.sas";
%include "&init.\2a_macros_init_foyer.sas";
%include "&init.\2b_init_foyer.sas";
%include "&init.\3_recup_infos_trim.sas";
%include "&init.\4_FoyerVarType.sas";
%include "&chemin_dossier.\pgm\99utiles\ordre_foyer.sas";

/* Corrections ad hoc de certaines observations */
%include "&init.\Corrections\1_correction_FIP_declarant.sas";
%include "&init.\Corrections\2_correction_irf.sas";
%include "&init.\Corrections\macro_corrections.sas";
%include "&init.\Corrections\3_suppression.sas";
%include "&init.\Corrections\4_correction_foyer.sas";
%include "&init.\Corrections\5_correction_indivi.sas";
%include "&init.\Corrections\6_correction_declar.sas";

/* Organisation des données par trimestre de l'enquête emploi */
%include "&info_trim.\1_cal_emploi.sas";
%include "&info_trim.\2_cal_tp.sas";
%include "&info_trim.\3_cal_rev.sas";
%include "&info_trim.\4_cal_rais_non_emploi.sas";

/* Remplissage de déclarations fiscales pour les EE (individus présents uniquement dans l'Enquête Emploi) et intégration des bébés EE_FIP */
%include "&init.\5a_ee_foyer.sas";
%include "&init.\5b_XYZ_foyer.sas";
%include "&init.\6_enfant_fip.sas";
%include "&init.\7_type_menage_Insee.sas";

/* Vieillissement - étape 1 : Calage sur marges */
%include "&init.\8_ponderations.sas";
%include "&chemin_dossier.\pgm\5Sorties\stat_calage.sas";

/********************************/
/*	2	IMPUTATION (Amont)		*/
/********************************/

%include "&imputation.\0_majo_retraites.sas";
%include "&imputation.\01_imput_effectif.sas";
%include "&imputation.\02_imputation_contrats_collectifs.sas";
%include "&imputation.\03a_modele_imputation_hsup.sas";
%include "&imputation.\03b_application_imputation_hsup.sas";

	/*	-> POINT D'ARRET 1 <-	*/

/* Vieillissement - étape 2 : dérive individuelle des revenus */
%include "&imputation.\1_evol_revenus.sas";

%include "&imputation.\2_baseind_ini.sas";

%include "&imputation.\temps de travail\1_cal_anref.sas";
%include "&imputation.\temps de travail\2_coherence cal-rev.sas";
%include "&imputation.\temps de travail\3_correction temps de travail.sas";

%include "&imputation.\3_handicaps.sas";
%include "&imputation.\4_calage_aeeh.sas";
%include "&imputation.\5_elig_ASPA_ASI.sas";
%include "&imputation.\6_educ_enfant.sas";

%include "&imputation.\imputation enfant\modele_imputation_enfant.sas"; %let imputEnf_prem=non;
%include "&imputation.\imputation enfant\probabilité_imputation_enfant.sas";

/* Imputation d'une structure de consommation ssi &inclusion_TaxInd.=oui */
%include "&imputation.\imputation BDF\imputation_consommation.sas";

%include "&imputation.\7_baseind_fin.sas";
%include "&info_trim.\5_trimestrialisation_ressources.sas";

%include "&presta.\AL\simul.sas";
%include "&presta.\AL\AL_accedant.sas"; %let accedant_prem=non;
/* WARNING : vérifier si mêmes sorties Insee/Drees quand utilise l'élargi (dépend version de Sas)*/

/*****************************************************************************************
 MODULE ASS (neutre sur les sorties si module_ass=non)
ATTENTION! Il faut faire tourner depuis le point d'arrêt 1 à chaque fois que l'on relance le module,
sinon l'ASS se calcul sur la base de personnes à qui l'on a déjà imputé de l'ASS */
/* 1. Création de la table sur laquelle tournera le modèle R d'imputation de probas d'être à l'ASS */
/* N'a besoin de tourner qu'une fois par anleg-anref, sauf en cas de modifs du programme R ou de modifs importantes de l'aval */
%include "&imputation.\12_table_tirage_ASS.sas";
/* 2. Calcul et imputation de l'ASS. */
/* Ne peut tourner que si le modèle de prédiction a tourné au moins une fois pour un anleg et un anref donné */
%include "&presta.\minima\ASS.sas";
/*****************************************************************************************/

	/*	-> POINT D'ARRET 2 <-	*/

/****************************/
/*	3	MODELE (Aval)		*/
/****************************/

	/***********************************************************************************/
	/* BLOC A NE PAS SEPARER : Calcul du revenu fiscal de référence de anref(=anleg-2) */
	%let anr2=&anr1.; %let anr1=&anr.; %let anleg=%eval(&anleg.-1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
	%let Appel=1;
	%include "&fiscal.\1_rbg.sas";
	%include "&fiscal.\2_charges.sas";
	%include "&fiscal.\3_npart.sas";
	%include "&fiscal.\4_Prelev_Forf.sas"; /* Pour anleg-1 : éligibilité des autoentrepreneurs au versement libératoire + PFO (crédit d'impôt) */
	%include "&fiscal.\5_Deduc.sas";
	%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'impôt total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'impôt HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la définition du revenu
											disponible.*/
	%include "&fiscal.\6_Impot.sas";
	%let anr1=%substr(%eval(&anref.+1),3,2); %let anr2=%substr(%eval(&anref.+2),3,2);
	%let anleg=%eval(&anleg.+1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
	/* Fin du bloc et retour à la normale **********************************************/

/* Calcul de l'impôt payé en anleg sur revenus de anr1 */
%let Appel=2;
%include "&fiscal.\1_rbg.sas";
%include "&fiscal.\2_charges.sas";
%include "&fiscal.\3_npart.sas"; /* écrase la table modele.nbpart créée dans le premier bloc */
%include "&fiscal.\4_Prelev_Forf.sas"; /* PF payé en anleg sur les revenus de anleg */
%include "&fiscal.\5_Deduc.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'impôt total (que l'on 
										conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
										de l'impôt HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la définition du revenu
										disponible.*/
%include "&fiscal.\6_Impot.sas";
%LET calcul_impot = impot_revdisp;			
%include "&fiscal.\6_Impot.sas";
%include "&fiscal.\7_VersLib_Autoentrepreneurs.sas";

	/*	-> POINT D'ARRET 3 <-	*/

/* Tables au niveau famille */
%include "&crea_basefam.\1_ident_rsa_fam.sas";
%include "&crea_basefam.\2_basefam.sas"; 
%include "&crea_basefam.\3_ident_log.sas"; /* ce programme a besoin de ident_fam et de handicaps pour tourner */

/* Initialisation à blanc de modele.basersa et de aah dans modele.baseind, dont on a besoin pour le programme ressources */
data modele.basersa; set modele.baseind; if _n_=1; %Init_Valeur(m_rsa_socle_th1 m_rsa_socle_th2 m_rsa_socle_th3 m_rsa_socle_th4);	run;
data modele.baseind; set modele.baseind; %Init_Valeur(aah); run;
%include "&crea_basefam.\ressources.sas";

	/************************************ Incise ****************************************************/
	/*	Retour sur des imputations qui ne peuvent pas avoir lieu plus haut 							*/
	/*	car elles nécessitent soit des paramètres législatifs (CLCA), soit des 						*/
	/*	tables ou des variables qui n'existaient pas encore (basefam, rev_paje) 					*/
	%include "&imputation.\8_elig_asf.sas"; 
	%include "&imputation.\9_garde.sas";
	%include "&imputation.\10_travail_clca.sas";
	/********************************** Fin Incise **************************************************/

/* Cotisations */
%include "&chemin_cotis.\1_SFT.sas";
%include "&chemin_cotis.\2_cotisations.sas"; /* calcul des cotisations et revenus nets */
%include "&chemin_cotis.\3_Prelev_RevPat.sas";

/* Calcul des prestations familiales */
%include "&presta.\AF\AF.sas";
%include "&presta.\AF\AEEH.sas";
%include "&presta.\AF\ASF.sas";
%include "&presta.\AF\ARS.sas";
%include "&presta.\AF\PAJE.sas";
%include "&presta.\AF\CLCA.sas";
%include "&presta.\AF\CMG.sas"; /* TODO : faire un programme qui gère l'exclusion de CMG et de CLCA, etc */
%include "&presta.\AF\synthese_garde.sas";
%include "&presta.\AF\creche.sas";

/* Minima sociaux */
%include "&presta.\minima\ASPA_ASI.sas"; 
%include "&presta.\minima\AAH.sas"; 
%include "&presta.\minima\rsa.sas";  

/* Logement */
%include "&crea_basefam.\ressources.sas"; /* Second appel pour prendre en compte RSA et AAH dans les ressources pour les AL */
%include "&presta.\AL\AL.sas";
%include "&presta.\AL\forf_log.sas";

/* Prime d'activité et non-recours RSA et PA */
%include "&presta.\prime_act.sas"; 
%include "&imputation.\11_non_recours_rsa_pa.sas"; 
%include "&presta.\minima\application_non_recours_rsa.sas"; 
%include "&presta.\minima\psa.sas";

/* PPE */
%include "&fiscal.\rev_ppe.sas";
%include "&presta.\minima\rsa_ppe_interaction.sas";
%include "&fiscal.\ppe.sas";

/* Autres prestations */
%include "&presta.\AF\bourses_college_lycée.sas";/* a besoin de l'AAH pour tourner;*/ 
%include "&presta.\minima\caah.sas"; /* doit tourner après les AL */
/* TODO : le RSA devrait retourner car la CAAH entre dans la base ressource du rsa */
%include "&presta.\APA.sas"; /* indépendant des autres programmes */
%include "&presta.\eligibilite_CMUc_ACS.sas";
%include "&presta.\tirage_CMUc_ACS.sas";

%include "&presta.\minima\gj.sas";

	/*	-> POINT D'ARRET 4 <-	*/

/************************************************************/
/*	4	REGROUPEMENT DES DONNEES AU NIVEAU MENAGE (Aval)	*/
/************************************************************/
%include "&menage.\agregation_cotis.sas"; /* calcul des cotisations patrimoine */
%include "&menage.\basemen.sas";

/* Taxation indirecte, exécute le module ssi &inclusion_TaxInd.=oui */
%include "&taxind.\module_taxind.sas";

	/*	-> POINT D'ARRET 5 <-	*/


/********************************/
/*	5	RESULTATS D'INES (Aval)	*/
/********************************/
%include "&chemin_dossier.\pgm\5Sorties\cibles_Ines.sas";


/* Utilisation éventuelle de la macro de comparaison des sorties pour vérification */
/* %CompareSortiesDeuxInes("chemin\nom1","chemin\nom2",annee1,annee2); */
	 /*	@chemin\nom1 : chemin complet et nom de la 1ere sortie à comparer
		@chemin\nom2 : chemin complet et nom de la 2e sortie à comparer
		@annee1 : année de législation simulée dans la 1ere sortie
		@annee2 : année de législation simulée dans la 2e sortie */

/* Exemple d'utilisation */

*%CompareSortiesDeuxInes(	"X:\HAB-INES\Tables INES\Leg 2016 base 2014\sortie\Sorties_Ines2016_20170517_1747.xls",
							"X:\HAB-INES\Tables INES\Leg 2016 base 2014\sortie\Sorties_Ines2016_20170518_1217.xls",
							2016,2016);

*%CompareSortiesDeuxInes(	"X:\HAB-INES\Tables INES\Leg 2017 base 2015\sortie\Sorties_Ines2017_20180831_1602.xls",
							"X:\HAB-INES\Tables INES\Leg 2017 base 2015\sortie\Sorties_Ines2017_20180831_1756.xls",
							2017,2017);


