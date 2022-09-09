/************************************************************************************/
/* 								enchainement_Etude_QC_QF								*/
/************************************************************************************/

/********************************************************************************************************************************/
/*	0)  imp�t individualis�	                     */
/*	1) imp�t avec QC		                         */
/*	2) imp�t avec QC+QF (Ines 2016)	 */
/* 3) imp�t avec QC et CI                      */		
/********************************************************************************************************************************/

/*********************************/
/* BLOC A MODIFIER A CHAQUE FOIS */
/*********************************/

%let allocation_revfoyer=propor; /* declarant = on alloue les revenus du foyer non individualisables au d�clarant
														   conjoint = on les alloue � son (sa) conjoint(e)
															partage = on donne 50% � chacun 
															propor = on attribue en fonction de la part du RBG individuel dans le rbg du couple */

/* PARAMETRAGE GENERAL */
%let anref=2015;	/*	Mill�sime ERFS
						Anref+2 correspondra � la population simul�e */
%let anleg=2017;	/* 	Ann�e de l�gislation Ines simul�e
						Le plus souvent anref+2=anleg mais d�couplage en principe possible */

/* CONTEXTES PARTICULIERS */
%let casd=non; 				/* Entrer oui pour une utilisation d'Ines dans le cadre du CASD */
%let noyau_uniquement=oui; 	/* Entrer oui sauf si l'on souhaite travailler sur l'�largie pour les ERFS<=2012 */
%let tx=1; 					/* Si anleg<anref+2, entrer variation de l'IPC sur la p�riode (ou quelque chose qui y ressemble). Sinon, entrer 1 */
%let retropole=non;			/* Entrer oui pour utiliser les tables de l'ERFS r�tropol�es en 2012, 2013 et 2014 ==> non dans le cadre du CASD*/
%let Nowcasting=non; 		/* Ne mettre oui que dans le cadre du nowcasting */
%let inclusion_TaxInd=non; 	/* Avec ou sans simulations des taxes indirectes (pseudo-appariement avec Budget Des Familles). */
							/* Si oui, il faut avoir fait tourner Ines au pr�alable 1 fois (avec "non" renseign�) */
%let anBDF=2011; 			/* Ann�e de l'enqu�te BDF pour taxation indirecte */
%let module_ASS=non;   /* Ne mettre oui que dans le cadre d'�tudes sur l'ASS */

/* EVENTUELLES PREMIERES EXECUTIONS (programmes qui ne doivent tourner qu'une fois par couplet [anref ; anleg]) */
%let Anref_Ech_prem=oui; 	/* Est-ce la 1�re fois qu'Ines tourne sur ce mill�sime ERFS ? Entrer oui ou non */
%let imputEnf_prem=oui; 	/* L'imputation des enfants � na�tre tourne-t-elle pour la 1�re fois ? Sera mis d'office � non apr�s ex�cution du programme (si casd, mettre toujours � non) */
%let accedant_prem=oui; 	/* L'imputation des AL acc�dants tourne-t-elle pour la 1�re fois ? Sera mis d'office � non apr�s ex�cution du programme */

/* CONFIGURATION SELON VERSION DU LOGICIEL ET PREFERENCES */
%let excel=xls; 	/* Pour l'import du fichier de config (Config_chemin.xls). Exemples : xls ou excels � la Drees, excel2000 sur les postes Insee, xls sous AUS */
%let import=oui; 	/* Import des param�tres (entrer oui sauf exception) */
options source2; 	/* Options pour que les codes des fichiers en %include s'affichent dans la log */
options mprint; 	/* ou nomprint en fonction des pr�f�rences */

/* Programme permettant d'analyser les performances du mod�le. Tourne en 2 temps et n�cessite une version de SAS en anglais */
/* %include "&chemin_dossier.\pgm\99utiles\PerformanceAnalysis.sas"; */ /* ouvrir ce programme pour plus d'informations */


/****************************************************/
/* 0	CHEMINS, LIBRAIRIES, MACROS, PARAMETRES		*/
/****************************************************/

%let anr=%substr(&anref.,3,2);
%let anr1=%substr(%eval(&anref.+1),3,2);
%let anr2=%substr(%eval(&anref.+2),3,2);

%let ListeParam_Valeurs=&anref. &anleg. &sysuserid. &casd. &noyau_uniquement. &tx. &module_ASS. &Nowcasting. &inclusion_TaxInd. &Anref_Ech_Prem. &imputEnf_prem. &accedant_prem. &retropole.;

/* Param�tres de configuration pour chaque utilisateur, en deux temps */
%macro Config_chemin;
	/* Config-1 : En sortie : &chemin_ines. (o� aller chercher le fichier Config_perso.sas) */
	proc sql noprint;
		select xpath into :progname
		from sashelp.vextfl where xpath like '%enchainement_Etude_QC_QF.sas'; /* R�pertoire racine */
		quit;
	%let progpathroot=%sysfunc(substr(&progname.,1,%sysfunc(find(&progname.,\enchainement_Etude_QC_QF.sas))-1)); /* Donne le chemin absolu de enchainement.sas */
	%let my_id = %sysfunc(compress(&sysuserid., ".")); /*on enl�ve les points dans les identifiants*/
	%let my_id = %sysfunc(compress(&my_id., "-")); /*on enl�ve les tirets dans les identifiants*/
	proc import datafile="&progpathroot.\..\parametres\config_chemin.xls" out=config_chemin(keep=sysuserID &my_id.) dbms=&excel. replace; run;
	data _null_; set config_chemin; call symputx(strip(sysuserid),strip(&my_id.),'G');run; /* MV globales */
	proc delete data=config_chemin; run;
	%put R�pertoire pour &my_id. : &chemin_ines.;
	%mend Config_chemin;
%Config_chemin;

%include "&chemin_ines.\pgm\config_perso.sas"; /* Config-2 : En sortie : &chemin_dossier. et &chemin_bases. */
%include "&chemin_dossier.\pgm\chemins.sas"; /* D�finit d'autres chemins plus d�taill�s */
%let chemin_etude=&chemin_dossier.\pgm �tude;
%include "&chemin_dossier.\pgm\libname.sas";
%include "&chemin_dossier.\pgm\macros.sas"; /* Compilation des macros qui serviront dans la suite d'Ines */
%include "&chemin_dossier.\pgm\macros_OrgaCases.sas"; /* Compilation de macros sp�cifiques */

%macro Autre_Libname;
	%do j=0 %to 4;
		libname modele&j. "&chemin_bases.\Leg &anleg. Base &anref.\Etude QC QF\&j.";
		%end;
	%mend;
%Autre_Libname;

/* Import des param�tres l�gislatifs */
libname modele "&chemin_bases.\Leg &anleg. Base &anref.\Etude QC QF"; /* A cet endroit les tables seront �cras�es � chaque �tape. */
%include "&chemin_dossier.\pgm\parametres.sas";

/* D�finition des param�tres sp�cifiques � la commande */
%let ci_pac=0;
%let ctf=oui;

/* Macros permettant de faire appel � des bouts de l'encha�nement */
%include "&chemin_dossier.\pgm �tude\enchainement_Macros.sas";

/************************************************/
/*			DEROULEMENT POUR L'ARTICLE			*/
/************************************************/

%Preparation_Imputation;
/* Sur cette base on fait tourner diff�rentes variantes d'Ines */

/*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*>*<>*<>*<>*>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*/
/* 									(1)	INES 2015 MESURE 0 : IMP�T INDIVIDUEL					   						*/

/* On se trouve maintenant dans la l�gislation contrefactuelle : imp�t individualis� */
%Bloc_Impot_0;
%Suite_Modele;
proc copy in=modele out=modele0; run;

%let sortie_cible= &chemin_bases.\Leg &anleg. Base &anref.\sortie;
%include "&chemin_dossier.\pgm\5Sorties\Cibles_Ines.sas";

%let ctf=non; /* on sort du cas contrefactuel (macrovariable pour tirage RSA) */
/*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*/


/*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<*<>*<>*<>*<>*<>*<>*/
/*									De (1) � (2) : S�QUENTIALIT� DES MESURES											*/

/*	MESURE 1 : Mise en place du quotient conjugal		*/
%Bloc_Impot_1;
%Suite_Modele;
proc copy in=modele out=modele1; run;

/*	MESURE 2 : Imp�t Ines 2016 (QC + QF)	*/
%Bloc_Impot;
%Suite_Modele;
proc copy in=modele out=modele2; run;

/* MESURE 3 : Remplacement QF par cr�dit d'imp�t */

/* On d�duit le co�t du quotient familial des mesures 1 et 2 , ce co�t va permettre 
d'en d�duire le montant du cr�dit unique par personne � charge ci_pac */
proc sql noprint;
	select sum(b.impot_tot*b.poi)-sum(a.impot_tot*a.poi)
		into :cout_qf
		from modele2.basemen as a inner join modele1.basemen as b
		on a.ident=b.ident;
		quit;
%put &cout_qf.;
/* on r�cup�re maintenant le nombre de personnes � charge */
%cumul(	basein=modele0.impot_sur_rev&anr1.,
       	baseout=npchamen,
       	varin= npcha,
       	varout=npcha,
		varAgregation=ident);
proc sql noprint;
	select sum(unique(a.npcha)*b.poi)
		into :nb_pac
		from npchamen as a left join modele.basemen as b
		on a.ident=b.ident;
		quit;
%put &nb_pac.;
/* on en d�duit le montant du cr�dit d'imp�t */
%let ci_pac=%sysevalf(&cout_qf./&nb_pac.);
%put &ci_pac.;

%Bloc_Impot_3;
%Suite_Modele;
proc copy in=modele out=modele3; run;

/* on r�initialise le CI � 0 */
%let ci_pac=0;

/* MESURE 4 : Imp�t individuel avec une baisse des tranches pour avoir un co�t constant par rapport � l'imp�t familialis� */
/* On augmente les plafonds d'un pourcentage d�termin� � tat�nes */
%let augment_tranche=1.39;
/* On fait tourner l'imp�t individualis� avec la baisse des plafonds */
%Bloc_Impot_4;
%Suite_Modele;
proc copy in=modele out=modele4; run;
/* On r�importe les param�tres de base pour les sc�narios suivants */
%include "&chemin_dossier.\pgm\parametres.sas";

%let sortie_cible= &chemin_bases.\Leg &anleg Base &anref\sortie;
%include "&chemin_dossier.\pgm\5Sorties\Cibles_Ines.sas";
/* 								Effet 2015 : (2) - (1) = Ines 2015 - CTF 2015 											*/
/*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*/


/*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<><>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*/
/*											BASEMEN_FINAL																*/
/*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<><>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*<>*/

%macro Suffixes;
	/* Contrefactuel : on garde toutes les variables de basemen */
	%RenameVarSuffixe(table_input=modele0.basemen,table_output=basemen0,exception='ident',suffixe=_0);
	%RenameVarSuffixe(table_input=modele0.impot_sur_rev&anr1. ,table_output=impot_sur_rev&anr1._0,exception='declar',suffixe=_sc0);
	data impot_sur_rev&anr1._0;
		set impot_sur_rev&anr1._0 (rename = ident_sc0 = ident);
		keep 	ident declar decote: deduc: impot: diffImpotQF: mcdvo: npart: plaf_qf: 
				rbg: RFR: RIB: RNG: SaturationEffetsQF: Tx:;
		run;
	proc sort data = impot_sur_rev&anr1._0; by declar; run;
	%do j=1 %to 4;
	/* l'indice ne doit pas s'appeler i car l'indice est d�j� utilis� dans la macro appel�e plus bas */
		%RenameVarSuffixe(table_input=modele&j..basemen,table_output=basemen&j.,exception='ident',suffixe=_&j.);
		%RenameVarSuffixe(table_input=modele&j..impot_sur_rev&anr1. ,table_output=impot_sur_rev&anr1._&j.,exception='declar',suffixe=_sc&j.);
		/* On tronque un peu la table qui est trop volumineuse sinon */
		data basemen&j.;
			set basemen&j.;
			keep 	ident impot: csg: crds: prelev_pat: th: ppe: tot_cotis: cotis_: rev:
					af: comxx: arsxx: paje: aeeh: asf: clca: aspa: aah: caah: rsa: asi: alogl: prelev_forf: cotred: tot_presta: patot: pf:;
			run;
		data impot_sur_rev&anr1._&j;
		set impot_sur_rev&anr1._&j;
		keep 	declar decote: deduc: impot: diffImpotQF: mcdvo: npart: plaf_qf: 
				rbg: RFR: RIB: RNG: SaturationEffetsQF: Tx:;
		run;
		proc sort data = impot_sur_rev&anr1._&j.; by  declar ; run;
		%end;
	%mend Suffixes;
%Suffixes;

%macro Basemen_Etapes;
	data modele.basemen_synthese;
		merge 	basemen0 (in=a) basemen1 basemen2 basemen3 basemen4/* basemen Ines 2015 */;
		by ident;
		if a;
		%do i=0 %to 4;
			credit_&i.=-min(0,impot_tot_&i.);		/*l'impot quand il est n�gatif*/
			impot_pos_&i.=impot_tot_&i.+credit_&i.;	/*l'impot quand il est positif*/ 
			tot_prelev_&i.=sum(csgi_&i.,csg_etr_&i.,crds_ar_&i.,crds_etr_&i.,prelev_pat_&i.,th_&i.,crds_p_&i.,impot_tot_&i.);
			impot_yc_ppe_&i.=impot_&i.-pper_&i.;
			impose_yc_ppe_&i.=impot_yc_ppe_&i. gt 0;
			cotis_sal_&i.=tot_cotis_&i.-cotis_patro_&i.;
			%end;
		run;
	%mend Basemen_Etapes;

%Basemen_Etapes;

data modele.impot_sur_rev&anr1._synthese;
		merge 	impot_sur_rev&anr1._0 (in=a) impot_sur_rev&anr1._1 impot_sur_rev&anr1._2;
		by declar;
		if a;
		run;

proc sort data = modele.impot_sur_rev&anr1._synthese; by ident ; run;
data modele.impot_sur_rev&anr1._synthese;
		merge 	modele.impot_sur_rev&anr1._synthese (in=a) modele.basemen_synthese (keep = ident poi_0) ;
		by ident;
		if a;
		run;

%let sortie_etude_qc_qf=&sortie_cible.\QC_QF.xls;
/*
%include "&chemin_dossier.\pgm\5Sorties\sortie_etude_qc_qf.sas";
*/
