
/****************************************************************************************/
/* 		Ensemble des macros de listes et d'enchainement pour l'effet N et le consolidé 	*/
/****************************************************************************************/

/* 		1. Enchainement des programmes pour le CTF 										*/
/* 		2. Enchainement de programmes pour QC et QF	*/


/********************************************************/
/*  	 Enchainement des programmes pour le CTF 	    */
/********************************************************/

/* POINT METHODO : Pour l'étude on crée 4 macros : 
	- préparation_imputation : ne sera appelé qu'une seule fois en début d'exercice, pour la constitution du contrefactuel
	- bloc_impot_CTF : construction d'un impôt individualisé : dans l'étude c'est la seule partie qui bouge
	- bloc_impot_CTF1 : construction d'un impôt conjugalisé
	- bloc_impot : impôt tel qu'il existe actuellement
	- suite_modèle : suite du modèle après impôt qui tournera après chaque impot_ctf */

%Macro Preparation_Imputation;
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

	%Mend Preparation_Imputation;


/* Bloc Impot avec individualisation de l'IR */
%Macro Bloc_Impot_0;	
/***********************************************************************************/
/* BLOC A NE PAS SEPARER : Calcul du revenu fiscal de référence de anref(=anleg-2) */
%let anr2=&anr1.; %let anr1=&anr.; %let anleg=%eval(&anleg.-1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
%let Appel=1;
%include "&chemin_etude.\1_rbg_0.sas";
%include "&chemin_etude.\2_charges_0.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_0.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'impôt total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'impôt HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la définition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_0.sas";
%let anr1=%substr(%eval(&anref.+1),3,2); %let anr2=%substr(%eval(&anref.+2),3,2);
%let anleg=%eval(&anleg.+1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
/* Fin du bloc et retour à la normale **********************************************/
/* Calcul de l'impôt payé en anleg sur revenus de anr1 */
%let Appel=2;
%include "&chemin_etude.\1_rbg_0.sas";
%include "&chemin_etude.\2_charges_0.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_0.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'impôt total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'impôt HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la définition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_0.sas";
%let calcul_impot = impot_revdisp;
%include "&chemin_etude.\6_Impot_0.sas";
%include "&fiscal.\7_VersLib_Autoentrepreneurs.sas";
%Mend Bloc_Impot_0;

/* Bloc Impot avec conjugalisation de l'IR */
%Macro Bloc_Impot_1;	
/***********************************************************************************/
/* BLOC A NE PAS SEPARER : Calcul du revenu fiscal de référence de anref(=anleg-2) */
%let anr2=&anr1.; %let anr1=&anr.; %let anleg=%eval(&anleg.-1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
%let Appel=1;
%include "&chemin_etude.\1_rbg_1.sas";
%include "&chemin_etude.\2_charges_1.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_1.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'impôt total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'impôt HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la définition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_1.sas";
%let anr1=%substr(%eval(&anref.+1),3,2); %let anr2=%substr(%eval(&anref.+2),3,2);
%let anleg=%eval(&anleg.+1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
/* Fin du bloc et retour à la normale **********************************************/
/* Calcul de l'impôt payé en anleg sur revenus de anr1 */
%let Appel=2;
%include "&chemin_etude.\1_rbg_1.sas";
%include "&chemin_etude.\2_charges_1.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_1.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'impôt total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'impôt HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la définition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_1.sas";
%let calcul_impot = impot_revdisp;
%include "&chemin_etude.\6_Impot_1.sas";
%include "&fiscal.\7_VersLib_Autoentrepreneurs.sas";
%Mend Bloc_Impot_1;

/* Bloc Impot avec IR 2016 */
%Macro Bloc_Impot;
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
%let calcul_impot = impot_revdisp;
%include "&fiscal.\6_Impot.sas";
%include "&fiscal.\7_VersLib_Autoentrepreneurs.sas";
%Mend Bloc_Impot;

/* Bloc Impot avec IR sans QF (scenario 1) mais avec crédit d'impôt */
%Macro Bloc_Impot_3;
/***********************************************************************************/
/* BLOC A NE PAS SEPARER : Calcul du revenu fiscal de référence de anref(=anleg-2) */
%let anr2=&anr1.; %let anr1=&anr.; %let anleg=%eval(&anleg.-1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
%let Appel=1;
%include "&chemin_etude.\1_rbg_1.sas";
%include "&chemin_etude.\2_charges_1.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_1.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'impôt total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'impôt HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la définition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_3.sas";
%let anr1=%substr(%eval(&anref.+1),3,2); %let anr2=%substr(%eval(&anref.+2),3,2);
%let anleg=%eval(&anleg.+1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
/* Fin du bloc et retour à la normale **********************************************/

/* Calcul de l'impôt payé en anleg sur revenus de anr1 */
%let Appel=2;
%include "&chemin_etude.\1_rbg_1.sas";
%include "&chemin_etude.\2_charges_1.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_1.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'impôt total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'impôt HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la définition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_3.sas";
%let calcul_impot = impot_revdisp;
%include "&chemin_etude.\6_Impot_3.sas";
%include "&fiscal.\7_VersLib_Autoentrepreneurs.sas";
%Mend Bloc_Impot_3;

/* Bloc Impot avec IR sans QF (scenario 1) mais avec crédit d'impôt */
%Macro Bloc_Impot_4;
/***********************************************************************************/
/* BLOC A NE PAS SEPARER : Calcul du revenu fiscal de référence de anref(=anleg-2) */
%let anr2=&anr1.; %let anr1=&anr.; %let anleg=%eval(&anleg.-1); %creeMacrovarAnleg(imp_calc,&anleg.,1);

/* On crée ici les plafonds baissés propres à ce scénario */
%let plaf1=%sysevalf(&plaf1.*&augment_tranche.);
%let plaf2=%sysevalf(&plaf2.*&augment_tranche.);
%let plaf3=%sysevalf(&plaf3.*&augment_tranche.);
%let plaf4=%sysevalf(&plaf4.*&augment_tranche.);

%let Appel=1;
%include "&chemin_etude.\1_rbg_0.sas";
%include "&chemin_etude.\2_charges_0.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_0.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'impôt total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'impôt HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la définition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_0.sas";
%let anr1=%substr(%eval(&anref.+1),3,2); %let anr2=%substr(%eval(&anref.+2),3,2);
%let anleg=%eval(&anleg.+1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
/* Fin du bloc et retour à la normale **********************************************/

/* On crée ici les plafonds baissés propres à ce scénario */
%let plaf1=%sysevalf(&plaf1.*&augment_tranche.);
%let plaf2=%sysevalf(&plaf2.*&augment_tranche.);
%let plaf3=%sysevalf(&plaf3.*&augment_tranche.);
%let plaf4=%sysevalf(&plaf4.*&augment_tranche.);

/* Calcul de l'impôt payé en anleg sur revenus de anr1 */
%let Appel=2;
%include "&chemin_etude.\1_rbg_0.sas";
%include "&chemin_etude.\2_charges_0.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_0.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'impôt total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'impôt HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la définition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_0.sas";
%let calcul_impot = impot_revdisp;
%include "&chemin_etude.\6_Impot_0.sas";
%include "&fiscal.\7_VersLib_Autoentrepreneurs.sas";
/***********************************************************************************/
%Mend Bloc_Impot_4;

%Macro Suite_Modele;

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
%macro tirage_nonrecours;
%if &ctf.="oui" %then %do;
%include "&imputation.\11_non_recours_rsa_pa.sas"; 
%end;
%mend;
%tirage_nonrecours;
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

	%Mend Suite_Modele;


/* macro non utilisée pour cette étude mais potentiellement utile */
/* %macro VideLibrairiesIntermediaires;
	%do i=0 %to 2;
		libname l1 "&chemin_bases.\Leg &anleg. Base &anref.\Effet_Conso\&i.";
		libname l2 "&chemin_bases.\Leg &anleg. Base &anref.\Effet_N\&i.";
		proc datasets mt=data library=l1 kill; run; quit;
		proc datasets mt=data library=l2 kill; run; quit;
		%end;
	%mend VideLibrairiesIntermediaires; */

