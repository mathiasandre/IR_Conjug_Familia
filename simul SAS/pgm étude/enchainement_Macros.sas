
/****************************************************************************************/
/* 		Ensemble des macros de listes et d'enchainement pour l'effet N et le consolid� 	*/
/****************************************************************************************/

/* 		1. Enchainement des programmes pour le CTF 										*/
/* 		2. Enchainement de programmes pour QC et QF	*/


/********************************************************/
/*  	 Enchainement des programmes pour le CTF 	    */
/********************************************************/

/* POINT METHODO : Pour l'�tude on cr�e 4 macros : 
	- pr�paration_imputation : ne sera appel� qu'une seule fois en d�but d'exercice, pour la constitution du contrefactuel
	- bloc_impot_CTF : construction d'un imp�t individualis� : dans l'�tude c'est la seule partie qui bouge
	- bloc_impot_CTF1 : construction d'un imp�t conjugalis�
	- bloc_impot : imp�t tel qu'il existe actuellement
	- suite_mod�le : suite du mod�le apr�s imp�t qui tournera apr�s chaque impot_ctf */

%Macro Preparation_Imputation;
/********************************/
/*	1	PREPARATION	(Amont)		*/
/********************************/

/* Pr�paration */
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

/* Organisation des donn�es par trimestre de l'enqu�te emploi */
%include "&info_trim.\1_cal_emploi.sas";
%include "&info_trim.\2_cal_tp.sas";
%include "&info_trim.\3_cal_rev.sas";
%include "&info_trim.\4_cal_rais_non_emploi.sas";

/* Remplissage de d�clarations fiscales pour les EE (individus pr�sents uniquement dans l'Enqu�te Emploi) et int�gration des b�b�s EE_FIP */
%include "&init.\5a_ee_foyer.sas";
%include "&init.\5b_XYZ_foyer.sas";
%include "&init.\6_enfant_fip.sas";
%include "&init.\7_type_menage_Insee.sas";

/* Vieillissement - �tape 1 : Calage sur marges */
%include "&init.\8_ponderations.sas";
%include "&chemin_dossier.\pgm\5Sorties\stat_calage.sas";

/********************************/
/*	2	IMPUTATION (Amont)		*/
/********************************/

%include "&imputation.\0_majo_retraites.sas";
%include "&imputation.\01_imput_effectif.sas";
%include "&imputation.\02_imputation_contrats_collectifs.sas";

	/*	-> POINT D'ARRET 1 <-	*/

/* Vieillissement - �tape 2 : d�rive individuelle des revenus */
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
%include "&imputation.\imputation enfant\probabilit�_imputation_enfant.sas";

/* Imputation d'une structure de consommation ssi &inclusion_TaxInd.=oui */
%include "&imputation.\imputation BDF\imputation_consommation.sas";

%include "&imputation.\7_baseind_fin.sas";
%include "&info_trim.\5_trimestrialisation_ressources.sas";

%include "&presta.\AL\simul.sas";
%include "&presta.\AL\AL_accedant.sas"; %let accedant_prem=non;
/* WARNING : v�rifier si m�mes sorties Insee/Drees quand utilise l'�largi (d�pend version de Sas)*/

/*****************************************************************************************
 MODULE ASS (neutre sur les sorties si module_ass=non)
ATTENTION! Il faut faire tourner depuis le point d'arr�t 1 � chaque fois que l'on relance le module,
sinon l'ASS se calcul sur la base de personnes � qui l'on a d�j� imput� de l'ASS */
/* 1. Cr�ation de la table sur laquelle tournera le mod�le R d'imputation de probas d'�tre � l'ASS */
/* N'a besoin de tourner qu'une fois par anleg-anref, sauf en cas de modifs du programme R ou de modifs importantes de l'aval */
%include "&imputation.\12_table_tirage_ASS.sas";
/* 2. Calcul et imputation de l'ASS. */
/* Ne peut tourner que si le mod�le de pr�diction a tourn� au moins une fois pour un anleg et un anref donn� */
%include "&presta.\minima\ASS.sas";
/*****************************************************************************************/

	%Mend Preparation_Imputation;


/* Bloc Impot avec individualisation de l'IR */
%Macro Bloc_Impot_0;	
/***********************************************************************************/
/* BLOC A NE PAS SEPARER : Calcul du revenu fiscal de r�f�rence de anref(=anleg-2) */
%let anr2=&anr1.; %let anr1=&anr.; %let anleg=%eval(&anleg.-1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
%let Appel=1;
%include "&chemin_etude.\1_rbg_0.sas";
%include "&chemin_etude.\2_charges_0.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_0.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'imp�t total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'imp�t HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la d�finition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_0.sas";
%let anr1=%substr(%eval(&anref.+1),3,2); %let anr2=%substr(%eval(&anref.+2),3,2);
%let anleg=%eval(&anleg.+1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
/* Fin du bloc et retour � la normale **********************************************/
/* Calcul de l'imp�t pay� en anleg sur revenus de anr1 */
%let Appel=2;
%include "&chemin_etude.\1_rbg_0.sas";
%include "&chemin_etude.\2_charges_0.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_0.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'imp�t total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'imp�t HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la d�finition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_0.sas";
%let calcul_impot = impot_revdisp;
%include "&chemin_etude.\6_Impot_0.sas";
%include "&fiscal.\7_VersLib_Autoentrepreneurs.sas";
%Mend Bloc_Impot_0;

/* Bloc Impot avec conjugalisation de l'IR */
%Macro Bloc_Impot_1;	
/***********************************************************************************/
/* BLOC A NE PAS SEPARER : Calcul du revenu fiscal de r�f�rence de anref(=anleg-2) */
%let anr2=&anr1.; %let anr1=&anr.; %let anleg=%eval(&anleg.-1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
%let Appel=1;
%include "&chemin_etude.\1_rbg_1.sas";
%include "&chemin_etude.\2_charges_1.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_1.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'imp�t total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'imp�t HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la d�finition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_1.sas";
%let anr1=%substr(%eval(&anref.+1),3,2); %let anr2=%substr(%eval(&anref.+2),3,2);
%let anleg=%eval(&anleg.+1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
/* Fin du bloc et retour � la normale **********************************************/
/* Calcul de l'imp�t pay� en anleg sur revenus de anr1 */
%let Appel=2;
%include "&chemin_etude.\1_rbg_1.sas";
%include "&chemin_etude.\2_charges_1.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_1.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'imp�t total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'imp�t HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la d�finition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_1.sas";
%let calcul_impot = impot_revdisp;
%include "&chemin_etude.\6_Impot_1.sas";
%include "&fiscal.\7_VersLib_Autoentrepreneurs.sas";
%Mend Bloc_Impot_1;

/* Bloc Impot avec IR 2016 */
%Macro Bloc_Impot;
/***********************************************************************************/
/* BLOC A NE PAS SEPARER : Calcul du revenu fiscal de r�f�rence de anref(=anleg-2) */
%let anr2=&anr1.; %let anr1=&anr.; %let anleg=%eval(&anleg.-1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
%let Appel=1;
%include "&fiscal.\1_rbg.sas";
%include "&fiscal.\2_charges.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; /* Pour anleg-1 : �ligibilit� des autoentrepreneurs au versement lib�ratoire + PFO (cr�dit d'imp�t) */
%include "&fiscal.\5_Deduc.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'imp�t total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'imp�t HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la d�finition du revenu
											disponible.*/
%include "&fiscal.\6_Impot.sas";
%let anr1=%substr(%eval(&anref.+1),3,2); %let anr2=%substr(%eval(&anref.+2),3,2);
%let anleg=%eval(&anleg.+1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
/* Fin du bloc et retour � la normale **********************************************/

/* Calcul de l'imp�t pay� en anleg sur revenus de anr1 */
%let Appel=2;
%include "&fiscal.\1_rbg.sas";
%include "&fiscal.\2_charges.sas";
%include "&fiscal.\3_npart.sas"; /* �crase la table modele.nbpart cr��e dans le premier bloc */
%include "&fiscal.\4_Prelev_Forf.sas"; /* PF pay� en anleg sur les revenus de anleg */
%include "&fiscal.\5_Deduc.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'imp�t total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'imp�t HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la d�finition du revenu
											disponible.*/
%include "&fiscal.\6_Impot.sas";
%let calcul_impot = impot_revdisp;
%include "&fiscal.\6_Impot.sas";
%include "&fiscal.\7_VersLib_Autoentrepreneurs.sas";
%Mend Bloc_Impot;

/* Bloc Impot avec IR sans QF (scenario 1) mais avec cr�dit d'imp�t */
%Macro Bloc_Impot_3;
/***********************************************************************************/
/* BLOC A NE PAS SEPARER : Calcul du revenu fiscal de r�f�rence de anref(=anleg-2) */
%let anr2=&anr1.; %let anr1=&anr.; %let anleg=%eval(&anleg.-1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
%let Appel=1;
%include "&chemin_etude.\1_rbg_1.sas";
%include "&chemin_etude.\2_charges_1.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_1.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'imp�t total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'imp�t HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la d�finition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_3.sas";
%let anr1=%substr(%eval(&anref.+1),3,2); %let anr2=%substr(%eval(&anref.+2),3,2);
%let anleg=%eval(&anleg.+1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
/* Fin du bloc et retour � la normale **********************************************/

/* Calcul de l'imp�t pay� en anleg sur revenus de anr1 */
%let Appel=2;
%include "&chemin_etude.\1_rbg_1.sas";
%include "&chemin_etude.\2_charges_1.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_1.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'imp�t total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'imp�t HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la d�finition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_3.sas";
%let calcul_impot = impot_revdisp;
%include "&chemin_etude.\6_Impot_3.sas";
%include "&fiscal.\7_VersLib_Autoentrepreneurs.sas";
%Mend Bloc_Impot_3;

/* Bloc Impot avec IR sans QF (scenario 1) mais avec cr�dit d'imp�t */
%Macro Bloc_Impot_4;
/***********************************************************************************/
/* BLOC A NE PAS SEPARER : Calcul du revenu fiscal de r�f�rence de anref(=anleg-2) */
%let anr2=&anr1.; %let anr1=&anr.; %let anleg=%eval(&anleg.-1); %creeMacrovarAnleg(imp_calc,&anleg.,1);

/* On cr�e ici les plafonds baiss�s propres � ce sc�nario */
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
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'imp�t total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'imp�t HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la d�finition du revenu
											disponible.*/
%include "&chemin_etude.\6_Impot_0.sas";
%let anr1=%substr(%eval(&anref.+1),3,2); %let anr2=%substr(%eval(&anref.+2),3,2);
%let anleg=%eval(&anleg.+1); %creeMacrovarAnleg(imp_calc,&anleg.,1);
/* Fin du bloc et retour � la normale **********************************************/

/* On cr�e ici les plafonds baiss�s propres � ce sc�nario */
%let plaf1=%sysevalf(&plaf1.*&augment_tranche.);
%let plaf2=%sysevalf(&plaf2.*&augment_tranche.);
%let plaf3=%sysevalf(&plaf3.*&augment_tranche.);
%let plaf4=%sysevalf(&plaf4.*&augment_tranche.);

/* Calcul de l'imp�t pay� en anleg sur revenus de anr1 */
%let Appel=2;
%include "&chemin_etude.\1_rbg_0.sas";
%include "&chemin_etude.\2_charges_0.sas";
%include "&fiscal.\3_npart.sas";
%include "&fiscal.\4_Prelev_Forf.sas"; 
%include "&chemin_etude.\5_Deduc_0.sas";
%LET calcul_impot = normal;			/*Le programme 6_Impot peut tourner avec calcul_impot = normal pour le calcul de l'imp�t total (que l'on 
											conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
											de l'imp�t HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la d�finition du revenu
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

/* Initialisation � blanc de modele.basersa et de aah dans modele.baseind, dont on a besoin pour le programme ressources */
data modele.basersa; set modele.baseind; if _n_=1; %Init_Valeur(m_rsa_socle_th1 m_rsa_socle_th2 m_rsa_socle_th3 m_rsa_socle_th4);	run;
data modele.baseind; set modele.baseind; %Init_Valeur(aah); run;
%include "&crea_basefam.\ressources.sas";

	/************************************ Incise ****************************************************/
	/*	Retour sur des imputations qui ne peuvent pas avoir lieu plus haut 							*/
	/*	car elles n�cessitent soit des param�tres l�gislatifs (CLCA), soit des 						*/
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
%include "&presta.\AF\CMG.sas"; /* TODO : faire un programme qui g�re l'exclusion de CMG et de CLCA, etc */
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

/* Prime d'activit� et non-recours RSA et PA */
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
%include "&presta.\AF\bourses_college_lyc�e.sas";/* a besoin de l'AAH pour tourner;*/ 
%include "&presta.\minima\caah.sas"; /* doit tourner apr�s les AL */
/* TODO : le RSA devrait retourner car la CAAH entre dans la base ressource du rsa */
%include "&presta.\APA.sas"; /* ind�pendant des autres programmes */
%include "&presta.\eligibilite_CMUc_ACS.sas";
%include "&presta.\tirage_CMUc_ACS.sas";

%include "&presta.\minima\gj.sas";

	/*	-> POINT D'ARRET 4 <-	*/

/************************************************************/
/*	4	REGROUPEMENT DES DONNEES AU NIVEAU MENAGE (Aval)	*/
/************************************************************/
%include "&menage.\agregation_cotis.sas"; /* calcul des cotisations patrimoine */
%include "&menage.\basemen.sas";

/* Taxation indirecte, ex�cute le module ssi &inclusion_TaxInd.=oui */
%include "&taxind.\module_taxind.sas";

	/*	-> POINT D'ARRET 5 <-	*/


/********************************/
/*	5	RESULTATS D'INES (Aval)	*/
/********************************/
%include "&chemin_dossier.\pgm\5Sorties\cibles_Ines.sas";

	%Mend Suite_Modele;


/* macro non utilis�e pour cette �tude mais potentiellement utile */
/* %macro VideLibrairiesIntermediaires;
	%do i=0 %to 2;
		libname l1 "&chemin_bases.\Leg &anleg. Base &anref.\Effet_Conso\&i.";
		libname l2 "&chemin_bases.\Leg &anleg. Base &anref.\Effet_N\&i.";
		proc datasets mt=data library=l1 kill; run; quit;
		proc datasets mt=data library=l2 kill; run; quit;
		%end;
	%mend VideLibrairiesIntermediaires; */

