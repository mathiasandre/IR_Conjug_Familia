/************************************************************************************/
/*																					*/
/* 								Cibles_Ines 								        */
/*																					*/
/************************************************************************************/

/*		               *    *
	               *            *
	             *   *        *   *
               *      *      *      *
              *        *    *        *           
   -------->           MASSES                   
                      EFFECTIFS         <--------
              *        *    *        *   
               *      *      *      *
	             *   *        *   *
	               *            *
		               *    *
*/
/************************************************************************************/
/* Ce programme calcule les masses des différents transferts simulés par le modèle ainsi que les effectifs et le nombre d'observations
concernés
Les calculs sont faits à partir des unités concernées : familles, foyers fiscaux... */

/************************************************************************************/
/* Tables en entrée :   modele.basefam                                              */
/*						modele.baseind   											*/
/*						base.menage&anr2.  											*/
/*						modele.rsa 													*/
/*						modele.pa 													*/
/*						modele.impot_sur_rev&anr1. 									*/
/*						modele.ppe 													*/
/* 						modele.basemen 												*/
/* 						modele.prelev_forf&anr2. 									*/
/*						modele.cotis 												*/
/* 						modele.cotis_menage 										*/
/*						base.baserev 												*/
/*																					*/
/* Fichier en entrée :  &dossier.\Cibles_Ines.xls 									*/
/*																					*/
/* Fichiers de sortie :  															*/
/* &sortie_cible.\Sorties_Ines&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.).xlsx */
/* &sortie_cible.\Comp_&libelle1._&libelle2..xlsx (pour comparaison de 2 fichiers de sortie ci-dessus) 		*/ 
/*																					*/
/************************************************************************************/
/* PREALABLE : avoir rempli l'onglet correspondant à la bonne année (&anleg. simulée) dans le fichier Excel Cibles_Ines (sous paramètres) */

%include "&chemin_dossier./pgm/5Sorties/macro_sortie.sas";

%Macro Sorties_Ines;
	/* Cette macro est prévue pour faire les sorties sur Ines &anleg. construit sur ERFS &anref. (appelé en toute fin du programme enchaînement) */
	/* Elle calcule les sorties d'Ines et les compare avec les cibles importées depuis le fichier Excel Cibles_Ines. */
	/* Des extensions en brouillon permettent de comparer deux à deux les sorties de deux Ines */

	/********************/
	/* 1	PRESTATIONS */
	/********************/
	data basefam;
		set modele.basefam;
		AF_=afxx0+majafxx+alocforxx;
		PAJE_=Paje_nais+Paje_base;
		run;
	data baseind;
		set modele.baseind;
		AAHtot_=aah+caah;
		run;

	/* Sorties simples */
	%Masses_Effectifs_Obs(transfert=AF_ afxx0 majafxx alocforxx comxx aeeh arsxx PAJE_ paje_nais paje_base asf,tableentree=basefam,tablesortie=s_PF,ponderation=wpela&anr2.);
	%Masses_Effectifs_Obs(transfert=AAHtot_ AAH CAAH,tableentree=baseind,tablesortie=s_AAH,ponderation=wpela&anr2.);
	%Masses_Effectifs_Obs(transfert=APA,tableentree=modele.apa,tableSortie=s_Apa,ponderation=wpela&anr2.);
	%Masses_Effectifs_Obs(transfert=al,tableentree=modele.baselog,tablesortie=s_ALloc,pondpresente=N,ponderation=wpela&anr2.,tablepond=base.menage&anr2.); /* AL location */
	%Masses_Effectifs_Obs(transfert=creche,tableentree=modele.basemen,tablesortie=s_Creche,pondpresente=N,ponderation=wpela&anr2.,tablepond=base.menage&anr2.);
	%Masses_Effectifs_Obs(transfert=bourse_col bourse_lyc,tableentree=modele.bourses,tablesortie=s_bourses,ponderation=wpela&anr2.);
	%Masses_Effectifs_Obs(transfert=gj,tableentree=modele.base_gj,tablesortie=s_gj,ponderation=wpela&anr2.);

	/* Détail CMG */
	/* La ventilation par type de garde ne prend pas en compte la garde en structure 
	(micro-crèche et assistant maternel employé par une structure) car c'est négligeable. Donc CMG_tot > CMGtot_am + CMGtot_dom  */
	data cmg;
		set modele.basefam;
		CMGtot=CMG+CMG_exo;
		CMGtot_am=(CMGtot*(garde='assmat'));
		CMGtot_dom=(CMGtot*(garde='saldom'));
		CMGexo_am=(CMG_exo*(garde='assmat'));
		CMGexo_dom=(CMG_exo*(garde='saldom'));
		run;
	%Masses_Effectifs_Obs(transfert=CMGtot CMG CMG_exo CMGtot_am CMGtot_dom CMGexo_am CMGexo_dom,tableentree=cmg,tablesortie=s_CMG,ponderation=wpela&anr2.);

	/* Détail CLCA */
	data clca;
		set modele.baseind;
		clca1=0;clca2=0;clca3=0;clca4=0;
		if clca_tp=1 then clcaTPl=clca;		/* CLCA taux plein */
		if clca_tp=2 then clcaTPa1=clca;	/* CLCA taux partiel */
		if clca_tp=3 then clcaTPa2=clca;	/* CLCA taux partiel */
		if clca_tp=4 then clcaOptTPl=clca;	/* CLCA optionnel -> taux plein */
		CLCATPl_=sum(CLCATPl,CLCAOptTpl);
		CLCATPa_=sum(CLCATPa1,CLCATpa2);
		CLCA_=sum(CLCATpl_,CLCATPa_);
		run;
	%Masses_Effectifs_Obs(transfert=CLCA_ CLCATPl_ CLCATPa_ clcaTPl clcaTPa1 clcaTPa2 clcaOptTPl,tableentree=clca,tablesortie=s_CLCA,ponderation=wpela&anr2.);

	/* AL accession */
	data alacc ;
		set base.menage&anr2. (keep = ident wpela&anr2. alaccedant) ;
		rename alaccedant = AL_accedant ; 
		if AL_accedant=. then AL_accedant=0;
		run ;
	%Masses_Effectifs_Obs(transfert=AL_accedant,tableentree=alacc,tablesortie=s_ALacc,ponderation=wpela&anr2.);

	/* Aspa Asi */
	proc means data=modele.baseind noprint nway;
		class ident_fam;
		var aspa asi;
		output out=aspa_asi(drop=_type_ _freq_) sum=;
		run;
	data aspa_asi; set aspa_asi; ident=substr(ident_fam,1,8);run;
	%Masses_Effectifs_Obs(transfert=aspa asi,tableentree=aspa_asi,tablesortie=s_AspaAsi,ponderation=wpela&anr2.,pondpresente=N,tablepond=base.menage&anr2.);

	/* CMUC-ACS */
	%Masses_Effectifs_Obs(transfert=elig_cmuc elig_acs avantage_monetaire_cmuc cheque_acs,tableentree=modele.baseind,tablesortie=s_CmucAcs,ponderation=wpela&anr2.);
	/*data s_CmucAcs; set s_CmucAcs; masse=0; run; *//* on n'a pas de masse pour cette variable, juste des effectifs d'éligibles */
	
	/* ASS */
	%Masses_Effectifs_Obs(transfert=montant_ass ass_noel,tableentree=modele.baseind,tablesortie=s_ASS,ponderation=wpela&anr2.);
	/* Détail RSA */
	/* On distingue le bénéfice du socle seul, de l'activité seul, des deux, ou du RSA majoré
	Par ailleurs, on donne deux types de sorties : 
		- les masses et les effectifs en annuel
		- les masses et les effectifs pour le T4 */

	data rsa;
		set modele.rsa;
	/*En 2015 et avant, les variables sont RSA socle et RSA activité*/
		/*découpage du rsa sur l'année : l'addition des 3 masses donne le montant total de rsa distribué sur l'année*/
		RSA_socle=(rsasocle>0)*rsasocle;
		RSA_act=(rsaact>0)*rsaact;
		RSA_socle_seul=(rsasocle>0 & rsaact=0)*rsasocle;
		RSA_act_seul=(rsasocle=0 & rsaact>0)*rsaact;
		RSA_deux=(rsasocle>0 & rsaact>0)*(rsasocle+rsaact);
		/*rsa majoré sur l'année et au T4(socle et activité confondus avant la création de la PA - uniquement RSA après)*/
		RSA_majore=((rsasocle>0 ! rsaact>0 ! rsa>0) & ((enf03>0 & pers_iso=1) ! (e_c>0 & separation>0)))*(rsasocle+rsaact+rsa);
		RSA_majore_T4 = ((enf03>0 & pers_iso=1) ! (e_c>0 & separation>0))*(m_rsa_socle4+rsaact4+m_rsa4);
		/*éligibilités sur l'année */
			RSA_socle_eli = sum(of rsasocle_eli1-rsasocle_eli4);
			RSA_act_eli=rsaact_eli;
		/*En 2016 et après, il n'y a plus que le RSA (tout court, qui correspond à l'ancien socle) et la PA (ci-dessous)*/
		RSA = (rsa>0)*rsa;
		RSA_eli = sum(of rsa_eli1-rsa_eli4);
		%do i=1 %to 4 ;
			/*découpage du rsa sur l'année pour les bénéficiaires à chacun des trimestres */
			%if m_rsa_socle&i.>0 ! rsaact&i.>0 %then %do; 
				RSA_socle_seul_T&i.=(m_rsa_socle&i.>0 & rsaact&i.=0)*m_rsa_socle&i.;
				RSA_act_seul_T&i.=(m_rsa_socle&i.=0 & rsaact&i.>0)*rsaact&i.;
				RSA_deux_T&i.=(m_rsa_socle&i.>0 & rsaact&i.>0)*(m_rsa_socle&i.+rsaact&i.);
				%end; 
			/*éligibilités à chacun des trimestres */
			RSA_socle_eli_T&i. = rsasocle_eli&i.;
			RSA_act_eli_T&i.=rsaact_eli&i.;
			/* Après 2016 à chacun des trimestres */
			RSA_T&i. =  (m_rsa&i.>0)*m_rsa&i.;
			RSA_eli_T&i. =  (rsa_eli&i.>0)*rsa_eli&i.;
			%end ;
	/* RSA total (avant et après 2016 car non simultanément non nuls)*/
		RSAtot = RSA_socle_seul+RSA_act_seul+RSA_deux+RSA;
		run;
	/* Masses et effectifs sur l'année */
	%Masses_Effectifs_Obs(transfert=RSAtot RSA_socle RSA_act RSA_socle_seul RSA_act_seul RSA_deux RSA_majore RSA_noel psa RSA ,tableentree=rsa,tablesortie=s_rsaAnn,ponderation=wpela&anr2.);
	/* Masses et effectifs pour le T1 */
	%Masses_Effectifs_Obs(transfert=RSA_socle_seul_T1 RSA_act_seul_T1 RSA_deux_T1 RSA_T1,tableentree=rsa,tablesortie=s_rsaT1,ponderation=wpela&anr2.);
	/* Masses et effectifs pour le T2 */
	%Masses_Effectifs_Obs(transfert=RSA_socle_seul_T2 RSA_act_seul_T2 RSA_deux_T2 RSA_T2,tableentree=rsa,tablesortie=s_rsaT2,ponderation=wpela&anr2.);
	/* Masses et effectifs pour le T3 */
	%Masses_Effectifs_Obs(transfert=RSA_socle_seul_T3 RSA_act_seul_T3 RSA_deux_T3 RSA_T3, tableentree=rsa,tablesortie=s_rsaT3,ponderation=wpela&anr2.);
	/* Masses et effectifs pour le T4 */
	%Masses_Effectifs_Obs(transfert=RSA_socle_seul_T4 RSA_act_seul_T4 RSA_deux_T4 RSA_majore_T4 RSA_T4, tableentree=rsa,tablesortie=s_rsaT4,ponderation=wpela&anr2.);
	/* Masses et effectifs éligibles */
	%Masses_Effectifs_Obs(transfert=RSA_socle_eli RSA_act_eli RSA_socle_eli_T1 RSA_act_eli_T1 RSA_eli RSA_eli_T1 RSA_socle_eli_T2 RSA_act_eli_T2 RSA_eli RSA_eli_T2
									RSA_socle_eli_T3 RSA_act_eli_T3 RSA_eli RSA_eli_T3 RSA_socle_eli_T4 RSA_act_eli_T4 RSA_eli RSA_eli_T4,
									tableentree=rsa,tablesortie=s_rsaElig,ponderation=wpela&anr2.);
	/* Détail PA */
	/* On donne deux types de sorties : 
		- les masses et les effectifs en annuel
		- les masses et les effectifs pour chacun des trimestres */
	data pa;
		set modele.pa;
		PATOT_ = (patot>0)*patot;
		PA_eli = sum(of pa_eli1-pa_eli4);
		%do i=1 %to 4 ;
			PA_T&i. =  (pa&i.>0)*pa&i.;
			PA_eli_T&i. =  (pa_eli&i.>0)*pa_eli&i.;
			%end ;
			run;
			
	%if &anleg.>= 2016 %then %do;
		%Masses_Effectifs_Obs(transfert=PATOT_ PA_eli PA_T1 PA_eli_T1 PA_T2 PA_eli_T2 PA_T3 PA_eli_T3 PA_T4 PA_eli_T4,tableentree=pa,tablesortie=s_PA ,ponderation=wpela&anr2.);
		%end;
	%if &anleg.< 2016 %then %do;
		data s_PA; 
			_NAME_="PA_eli_T1"; masse=0; eff=0; obs=0; output; 
			_NAME_="PA_eli_T2"; masse=0; eff=0; obs=0; output; 
			_NAME_="PA_eli_T3"; masse=0; eff=0; obs=0; output; 
			_NAME_="PA_eli_T4"; masse=0; eff=0; obs=0; output; 
			_NAME_="PATOT_"; masse=0; eff=0; obs=0; output; 
			_NAME_="PA_eli"; masse=0; eff=0; obs=0; output; 
			_NAME_="PA_T1"; masse=0; eff=0; obs=0; output; 
			_NAME_="PA_T2"; masse=0; eff=0; obs=0; output; 
			_NAME_="PA_T3"; masse=0; eff=0; obs=0; output; 
			_NAME_="PA_T4"; masse=0; eff=0; obs=0; output; 
		run;
		%end;

	/*********************/
	/* 2	PRELEVEMENTS */
	/*********************/

	/* on récupère la liste des crédits et réductions d'impôt pour les mettre dans une macrovariable */
	proc contents data=modele.impot_sur_rev&anr1. noprint out=liste_CI_RI (keep=name where=(substr(name,1,4) eq "CRED" or substr(name,1,3) eq "RED")); run;
	data liste_CI_RI;
		length l $1000.;
		set liste_CI_RI end=fin;
		retain l;
		if _N_=1 then l=name;
		else l=compbl(l)||' '||name;
		if fin;
		call symput('liste_CI_RI',l);
		run;

	data impot;
		set modele.impot_sur_rev&anr1.;
		CRED_devldura_tot_=sum(0,CRED_devldura_habprinc,CRED_devldura_loc);
		CI_RI_tot_NonPlaf_=AvantageTotal_APlafonner;
		CI_RI_tot_Plaf_=AvantageTotal_APlafonner-excedant_plafglobal1-excedant_plafglobal2;
		impot_brutCIRI_brutPPE=impot+CI_RI_tot_Plaf_;
		run;

	/* IMPOT (et CI/RI), PPE, TH */
	%Masses_Effectifs_Obs(transfert=impot impot_brutCIRI_brutPPE CI_RI_tot_nonPlaf_ CI_RI_tot_Plaf_ CRED_devldura_tot_ &liste_CI_RI.,tableentree=impot,tablesortie=s_impot,ponderation=wpela&anr2.,pondpresente=N,tablepond=base.menage&anr2.);
	%Masses_Effectifs_Obs(transfert=ppef,tableentree=modele.ppe,tablesortie=s_ppe,ponderation=wpela&anr2.,pondpresente=N,tablepond=base.menage&anr2.);
	%Masses_Effectifs_Obs(transfert=th,tableentree=modele.basemen,tablesortie=s_TH,ponderation=wpela&anr2.,pondpresente=N,tablepond=base.menage&anr2.);
	%Masses_Effectifs_Obs(transfert=prelev_forf PF_liberatoire PF_obligatoire,tableentree=modele.prelev_forf&anr2.,tablesortie=s_Prelev_forf,ponderation=wpela&anr2.,pondpresente=N,tablepond=base.menage&anr2.);

	/* COTISATIONS ET CONTRIBUTIONS SOCIALES */
	data cotis_contrib (keep=ident CO: CSG: CRDS: co: csg: crds: exo:);
		set modele.cotis;
		cotsP=  sum(cotsP,-CotsTAXP); 	/* cotisations sociales patronales */
		coInd= 	sum(0,CObnRE,CObnFA,CObnMAL,CObiRE,CObiFA,CObiMAL,CObaRE,CObaFA,CobaMAL,coMicro);	/* cotisations sociales indépendants (yc micro) */
		coIndRE=sum(0,CObnRE,CObiRE,CObaRE);	
		coIndac=0;
		coIndFA=sum(0,CObnFA,CObiFA,CObaFA);
		coIndMal=sum(0,CObnMAL,CObiMAL,CobaMAL);	/* cotisations sociales indépendants */
		coIna=	sum(0,CoprMAL,COchRE,COchMAL);
		coInaMal=sum(0,CoprMAL,COchMAL);
		coInaRe=sum(0,COchRE);
		csgAct=	sum(0,CSGtsD,CSGtsI,CSGbnd,CSGbni,CSGBId,CSGBIi,CSGbAd,CSGbAi);	/* CSG sur revenus d'activité */
		csgIna=	sum(0,CSGchD,CSGchI,CSGprd,CSGpri);								/* CSG sur les revenus de remplacement */
		run;

	%Masses_Effectifs_Obs(transfert=
			/* Cotisations */
			COtsCHs COtsREs COtsMAL_SAL COtsCHp COtsREp COtsMAL_PAT COtsFA COtsACP COchRE COchMAL COprMAL	
			CObnRE CObnFA CObnMAL COBIRE COBIFA CObiMAL CObaRE CObaFA CObaMAL coMicro
			/* Exonérations */
			exo_BasSal exo_heursup exo_App exo
			/* Contributions */
			CSGtsD CSGtsI CSGchD CSGchI	CSGprd CSGpri CSGbnd CSGbni	CSGBId CSGBIi CSGbAd CSGbAi CRDSts CRDSch CRDSpr CRDSbn CRDSBI CRDSBA
			/* Agrégé */
			cotsS cotsP coInd coIndRE coIndac coIndFA coIndMal coIna coInaMal coInaRe csgAct csgIna crdsi /* csgpat_im */,
		tableentree=cotis_contrib,tablesortie=s_CotisContrib,ponderation=wpela&anr2.,pondPresente=N,tablepond=base.menage&anr2.);

	/* PRELEVEMENTS SOCIAUX SUR LE PATRIMOINE */
	data cotis_menage;
		set modele.cotis_menage;
		Prelev_Pat_yc_Exc_=csgPatM+crdspatm+autrepspatm+csgvalmob+crdsvalmob+autrepsvalmob
					      +csgvalm+crdsvalm+autrepsvalm+csgPat_im+crdspat_im+autrepspat_im 
                          +csgglom+crdsglom/*+autrepsglom*/+csgdivm+crdsdivm+autrepsdivm+contrib_salm;
		run;
	%Masses_Effectifs_Obs(transfert=
						csgPatM crdsPatM autrePSPatM csgvalmob crdsvalmob autrepsvalmob
						csgvalm crdsvalm autrepsvalm csgPat_im crdspat_im autrepspat_im
						csgglom crdsglom autrepsglom csgdivm crdsdivm autrepsdivm
						contrib_salM Prelev_Pat_yc_Exc_,
		tableentree=cotis_menage,tablesortie=s_prelevPat,ponderation=poi,pondpresente=N,tablepond=modele.basemen);

	/*********************************************************************/
	/* 3	CHAMP FPS (BASEMEN AVEC FILTRES) : MASSES ET MOYENNES PAR UC */
	/*********************************************************************/

	/* AGREGATS SUR BASEMEN */
	data basemen;
		set modele.basemen;
		/* Agrégats */
		pf_condress=sum(0,paje,comxx,arsxx,bcol,blyc); /* agrégat différent du pgm basemen : ajout des pf hors revenu disponible */
		pf_sansress=sum(0,aeeh,asf,cmg,clca,creche); /* agrégat différent du pgm basemen : ajout des pf hors revenu disponible */
		pf_tout_revdispaj=sum(0,pf_condress,pf_sansress,af); /* total pf yc pf hors revenu disponible */
		/* pf_tout existe déjà dans basemen mais sans les pf hors revenus disponible. On souhaite garder les 2 dans les sorties */
		pf_tout_horsrevdisp=pf_tout_revdispaj - pf_tout ; 
		alog=sum(alogl,alogacc);
		impot_tot=sum(impot,prelev_forf,verslib_autoentr,-pper);
		ir_netCI_netPPE=impot-pper;
		tot_presta=sum(af,pf_condress,pf_sansress,alog,minima,apa);
		FinPSoc_=cotred+contred+crds_p;
		Impot_direct_=impot_tot+th;
		Prelevtot_=FinPSoc_+Impot_direct_;

		/* Poids individuel */
		poiind=poi*nbp;
		/* Pour la suite (taux de pauvreté) */
		NdV=revdisp/uci;
		run;

	data champ;
		set basemen;
		/* Restriction du champ */
		if etud_pr = 'non' & revpos=1 & revdisp>0;
		run;
	%ListeVariablesDUneTable(table=champ,mv=VarBasemen,except=ident acteu_pr acteu_cj age_enf etud_pr typfam typmen_insee poi poiind);

	/* 3.1 - Masses */
	%Masses_Effectifs_Obs(transfert=&VarBasemen.,tableentree=basemen,tablesortie=s_masses,ponderation=poi);

	/* 3.2 - Moyennes par UC */
	%Moy_UC(transfert=&VarBasemen.,tableentree=champ,tablesortie=s_moyUC,ponderation=poiind);

	/* On suffixe les variables par '_champFPS' pour spécifier le champ car pour certaines il y a déjà une sortie sur un champ différent */
	data s_masses; length _NAME_ $30.; set s_masses (keep=_name_ masse: obs: eff:); _NAME_=compress(_NAME_||'_champFPS'); run;
	data s_moyUC; length _NAME_ $30.; set s_moyUC (keep=_name_ moyUC:); _NAME_=compress(_NAME_||'_champFPS'); run;


	/*********************************************/
	/* 4	PAUVRETE ET INDICATEURS D'INEGALITES */
	/*********************************************/

	proc univariate data=champ noprint;
		var NdV;
		freq poiind;
		output out=decile_NdV
		pctlpts=10 20 25 30 40 50 60 70 75 80 90 pctlpre=p;
		run;
	proc transpose data=decile_NdV out=decile_NdV; run;

   	data _null_;
      	set decile_NdV;
	  	call symput(_NAME_,col1);
		run;
	%let seuil_pauvrete=%sysevalf(0.6*&p50.); /* Pauvreté à 60 % */
	%let inter_deciles=%sysevalf(&p90./&p10.);
	%let d9_d5=%sysevalf(&p90./&p50.);
	%let d5_d1=%sysevalf(&p50./&p10.);
	%let inter_quartiles=%sysevalf(&p75./&p25.);

	data champ;
		set champ;
		decile_NdV=	1*(NdV<=&p10.)+			2*(&p10.<NdV<=&p20.)+	3*(&p20.<NdV<=&p30.)+	4*(&p30.<NdV<=&p40.)+
	      			5*(&p40.<NdV<=&p50.)+	6*(&p50.<NdV<=&p60.)+	7*(&p60.<NdV<=&p70.)+	8*(&p70.<NdV<=&p80.)+
	       			9*(&p80.<NdV<=&p90.)+	10*(&p90.<NdV);
		pauvre=(NdV<=&seuil_pauvrete.);
		/* Tranches d'âge de la personne de référence du ménage */
		tra_age_pr=	1*(age_pr<18)+2*(18<=age_pr<25)+3*(25<=age_pr<35)+4*(35<=age_pr<45)+5*(45<=age_pr<55)+6*(55<=age_pr<65)+7*(65<=age_pr<75)+8*(age_pr>=75);
		run;

	/* Ecart entre le niveau de vie médian des ménages pauvres et le seuil de pauvreté */
	proc means data=champ noprint; var NdV; weight poiind; where pauvre; output out=int (drop=_type_ _freq_) median=; run;
   	data _null_;
      	set int;
	  	call symput('NdVMedSous',NdV);
   		run;
	%let intensite_pauvrete=%sysevalf((&seuil_pauvrete.-&NdVMedSous.)/&seuil_pauvrete.);

	/* 	4.1		PAR TRANCHE D'AGE ET STATUT D'ACTIVITE*/
	/* Travail en amont pour pourvoir calculer le taux de pauvreté par tranche d'age et statut d'activité*/
	/* on doit revenir à une base individuelle pour avoir l'âge de la personne et non de la personne de référence de son ménage */
	proc sort data=modele.baseind; by ident; run;
	data champ_ind;
		merge champ (in=a) modele.baseind (keep=ident noi naia naim acteu6);
		by ident;
		if a;
		age=%eval(&anref.)-naia; /* leur âge l'année de l'ERFS */
		tra_age=1*(age<18)+2*(18<=age<25)+3*(25<=age<35)+4*(35<=age<45)+5*(45<=age<55)+6*(55<=age<65)+7*(65<=age<75)+8*(age>=75);
		run;
	proc sql;
		create table champ_ind2 as
		select a.*, b.acteu5
		from champ_ind as a
		left join rpm.Indivi&anr. as b
		on a.ident=b.ident&anr and a.noi=b.noi;
		quit; 
	data champ_ind2;
		set champ_ind2;
		/*tra_act=1*(acteu5='1')+2*(acteu5='2')+3*(acteu5='3')+4*(acteu5='4')+5*(acteu5='5')+99*(acteu5='');*/
		if age>=18 then do; /*on prend la même définition que dans l'IP niveau de vie*/
			if acteu5 in ('1') then tra_act='10';					/*salariés*/	
			if acteu5 in ('2') then tra_act='11';					/*indépendants*/
			if acteu5 ='3' then tra_act='2';						/*chomeurs*/
			if acteu6 ='5' then tra_act='3'; 						/*étudiants*/
			if acteu5 ='4' then tra_act='4'; 						/*retraités*/
			if (acteu5 ='5' and acteu6 ne '5') then tra_act='5'; 
			end;
		if (age<18) then do;tra_act='6';end; 
		if tra_act='' then do;tra_act='99';end; 
		run; 

	/* Intensité de la pauvreté */
	proc means data=champ noprint;
		var NdV;
		weight poiind;
		where pauvre; 
		output out=s_wP(drop=_type_ _freq_) median=NdV_Median_where_pauvre;
		run;

	/* calcul de la part de pauvre selon l'age */
	proc means data=champ_ind noprint;
		var pauvre NdV;
		class tra_age;
		weight poi;
		output out=s_Pauv(drop=_type_ _freq_) mean=part_pauvre NdV_mean median=pauvre_median NdV_Median;
		run;

	/* mise en forme en ajoutant intensité de la pauvreté */
	data s_Pauvrete;
		merge s_Pauv s_wP;
		intPauvrete=(&seuil_pauvrete.-NdV_Median_where_pauvre)/&seuil_pauvrete.; 
		if tra_age eq . then tra_age=0;
		run;
	proc transpose data=s_Pauvrete out=s_Pauvrete; by tra_age; run;
	data s_Pauvrete; set s_Pauvrete(rename=(col1=v)); nom_SAS=compress("T"||tra_age||"_"||_NAME_); keep nom_SAS v; if v ne . and v ne 0; run;

	/* calcul du taux de pauvreté selon le statut */
	proc summary data=champ_ind2 noprint;
		class 	tra_act;
		var 	NdV pauvre; 
		weight 	poi; 
		output out=s_Pauv2
		sumwgt=effectifpop
		median(NdV)=NdV_med
/*		mean(NdV)=NdV_mean*/
		sum(pauvre)=nbpauvre60;
		run;

	data _null_;
		set s_Pauv2;
		if _type_=0 then call symput('tot_pop',effectifpop);
		run;
	%put tot_pop=&tot_pop;

	data s_Pauv2;
		set	s_Pauv2	(in=a) ;
		txp60=nbpauvre60/effectifpop*100;
		NdV_med=round(NdV_med/10)*10;
		effectifpop=effectifpop/&tot_pop.*100;
		nbpauvre60=round(nbpauvre60/1000);
		if tra_act eq . then tra_act=0;
		drop _type_ _freq_;
		run;

	proc transpose data=s_Pauv2 out=s_Pauv2; by tra_act; run;
	data s_Pauvrete2; set s_Pauv2(rename=(col1=v)); nom_SAS=compress("T"||tra_act||"_"||_NAME_); keep nom_SAS v; if v ne . and v ne 0; run;

	/* 	4.2		PAR DECILE DE NIVEAU DE VIE */

	/* Répartition de masses par décile */
	/* Revdisp */		proc means data=champ noprint; var revdisp; class decile_NdV; weight poiind; output out=s_Rep_revdisp(drop=_type_ _freq_) sum=; run;
	/* Niveau de vie */	proc means data=champ noprint; var NdV; class decile_NdV; weight poiind; output out=s_Rep_NdV(drop=_type_ _freq_) sum=; run;
	data s_Rep_Rev;	merge s_Rep_revdisp s_Rep_NdV; if decile_NdV eq . then decile_NdV=0; run;
	proc transpose data=s_Rep_Rev out=s_Rep_Rev; by decile_NdV; run;
	data s_Rep_Rev; set s_Rep_Rev(rename=(col1=v)); nom_SAS=compress("D"||decile_NdV||"_"||_NAME_); keep nom_SAS v; run;
	data _null_;
    set s_Rep_Rev;
	call symput(nom_SAS,v);
	run;
	%let S20_NIVVIE=%sysevalf((&D1_NdV.+&D2_NdV.)/(&D0_NdV.));
	%let S50_NIVVIE=%sysevalf((&D1_NdV.+&D2_NdV.+&D3_NdV.+&D4_NdV.+&D5_NdV.)/(&D0_NdV.));
	%let S80_NIVVIE=%sysevalf(1-(&D9_NdV.+&D10_NdV.)/(&D0_NdV.));
	%let QSR=%sysevalf((&D10_NdV.+&D9_NdV.)/(&D1_NdV.+&D2_NdV.));
	%let part40_moyen=%sysevalf((&D6_NdV.+&D7_NdV.+&D8_NdV.+&D9_NdV.)/(&D0_NdV.));
	%let part10_riche=%sysevalf((&D10_NdV.)/(&D0_NdV.));

	/* 	4.3		INDICATEURS D'INEGALITES (dont COEFFICIENT DE GINI) */
	%Gini(data=champ,var=NdV,pond=poiind,out=gini);
   	data _null_; set gini; call symput('Gini',gini); run;

	%let liste_mv=p10 p20 p30 p40 p50 p60 p70 p80 p90 p25 p75 inter_deciles d9_d5 d5_d1 inter_quartiles gini seuil_pauvrete intensite_pauvrete S20_NIVVIE S50_NIVVIE S80_NIVVIE QSR part40_moyen part10_riche;
	%let liste_v=d1 d2 d3 d4 d5 d6 d7 d8 d9 q1 q3 d9_d1 d9_d5 d5_d1 q3_q1 gini seuil_pauvrete intensite_pauvrete S20_NIVVIE S50_NIVVIE S80_NIVVIE QSR part40_moyen part10_riche;
	proc sql;
		create table s_MV
		(nom_SAS varchar(20), v float);
		%do i=1 %to %sysfunc(countw(&liste_v.));
		%let mv=%scan(&liste_mv.,&i.);
		insert into s_MV (nom_SAS,v) values ("%scan(&liste_v.,&i.)",&&&mv.);
				%end;
		quit;

	/********************************************/
	/* MISE EN FORME DES RESULTATS AVANT EXPORT */
	/*  dans une table appelée TABLEAU&ANLEG.   */
	/********************************************/

	/* On met dans une table tous les résultats */
	/* On veut que le programme tourne si l'une des tables de sortie n'a pas été créée */

	/* Liste_s : sorties qui devraient avoir été créées par le programme ci-dessus */
	/* Liste_s2 : sorties qui ont effectivement été créées par le programme ci-dessus */
	/* Attention ne pas couper en deux la ligne ci-dessous */
	%let liste_s=s_PF s_AAH s_Apa s_ALloc S_ALacc s_CMG s_CLCA s_Creche s_bourses s_gj s_AspaAsi s_rsaAnn s_rsaT1 s_rsaT2 s_rsaT3 s_rsaT4 s_rsaElig s_PA s_impot s_PPE s_CmucAcs s_ASS s_TH s_Prelev_forf s_CotisContrib s_PrelevPat s_masses s_moyUC;
	%let liste_s2=; /* initialisée à blanc, on y ajoutera toutes les sorties de liste_s ayant bien été créées */
	data liste; /* table [1;1] */
		set s_PF; /* en fait n'importe quelle table, c'est juste pour créer une data et l'instruction datalines ne fonctionne qu'en code ouvert */
		if _N_ eq 1;
		liste=upcase("&liste_s.");
		drop _NAME_ masse eff;
		run;

	/* Liste des tables contenues dans la Work : MV liste_w et string de la table LISTE_WORK [1;1] */
	ods output Members=liste_work;
		proc datasets lib=work; quit; run;
		ods output close;
	data liste_work;
		length l $10000.;
		set liste_work end=fin;
		retain l;
		if _N_=1 then l=name;
		else l=compbl(l)||' '||name;
		if fin;
		call symput('liste_w',l);
		run;

	/* Chacune des tables de liste_s est-elle contenue dans la Work ? */
	%do k=1 %to %sysfunc(countw(&liste_s.));
		data liste_work;
			set liste_work;
			indice=find(l,upcase("%scan(&liste_s.,&k.)"));
			run;
		data _null_; set liste_work; call symput("Indice",indice); run;
		%if %eval(&Indice.)>0 %then %do;
			%let liste_s2=&liste_s2. %scan(&liste_s.,&k.);
			%end;
		%end;
	/*%put &liste_s. -> &liste_s2.;*/

	%do i=1 %to %sysfunc(countw(&liste_s2.));
		proc sort data=%scan(&liste_s2.,&i.); by _NAME_; run;
		%end;

	data tableau&anleg.;
		length _NAME_ $30.;
		merge &liste_s2.;
		by _NAME_;
		masse_&anleg.=round(masse,1); drop masse;
		nom_SAS=upcase(_NAME_); drop _NAME_;
		rename eff=effectif_&anleg. moyUC=moyUC_&anleg. obs=obs_&anleg.;
		run;

	data tableau&anleg. (rename = (v=v_&anleg.));
	length nom_SAS $30.;
		set tableau&anleg. s_Pauvrete s_Rep_Rev s_MV s_Pauvrete2;
		nom_SAS=upcase(nom_SAS);
		run;

	/* Import du fichier contenant les cibles pour l'année &anleg. (à la fois masses et effectifs) */
	proc import datafile="&dossier./Cibles_Ines.xls" out=cibles dbms=&excel_imp. replace; sheet="Cibles_&anleg."; run;
	data cibles; set cibles; c=_N_; nom_SAS=upcase(nom_SAS); run;

	/* On merge les cibles avec les sorties du modèle et on calcule les écarts */
	proc sort data=tableau&anleg.; by Nom_SAS; run;
	proc sort data=cibles; by Nom_SAS; run;
	data tableau&anleg.;
		merge tableau&anleg. cibles (in=a);
		by nom_SAS;
		if a;
		run;

	/* Calcul des sommes pour comparer à des cibles agrégées */
	proc transpose data=tableau&anleg. out=t;
		id nom_SAS;
		var obs_&anleg. masse_&anleg. effectif_&anleg. moyUC_&anleg. v_&anleg. ;
		run;

	data t; /* le forfait cotis des micro-entrepreneurs n'est dans aucune catégorie ; voir s'il faut l'intégrer dans l'une ou l'autre */
		set t;
		AL_=AL_accedant+AL;
		CotSocRet_=CObaRE+CObiRE+CObnRE+COtsRES+COtsREP;
		CotSocATMP_=CotsACP;
		CotSocFam_=CObaFA+CObiFA+CObnFA+COtsFA;
		CotSocSan_=CObaMAL+CobiMAL+CobnMAL+CoprMAL+cotsMAL_sal+cotsMAL_pat;
		CotSoc_HC_=CotSocRet_+CotSocATMP_+CotSocFam_+CotSocSan_;
		COtsS_HC_=cotsRES+cotsMAL_sal;
		COtsP_HC_=cotsREP+cotsFA+cotsACP+cotsMAL_pat;
		CotSoc_HC2_=cotsS_HC_+cotsP_HC_+coInd+CoprMAL;
		CotSocCho_=COtsCHP+COtsCHS;
		CSGSal_=CSGtsD+CSGtsI;
		CSGNonSal_=csgbad+csgbai+CSGbid+CSGbii+CSGbnd+CSGbni;
		CSGRet_=csgPRd+csgPRi;
		CSGChoPre_=CSGCHd+CSGCHi;
		CSGd_=CSGtsD+csgbad+CSGbid+CSGbnd+csgPRd+CSGCHd;
		CSGi_=CSGtsI+csgbai+CSGbii+CSGbni+csgPRi+CSGCHi;
		CSGtot_=CSGSal_+CSGNonSal_+CSGRet_+CSGChoPre_;
		CRDSNonSal_=crdsba+crdsbi+crdsbn;
		CRDSAct_=CRDSts+CRDSNonSal_;
		CRDSRempl_=CRDSch+CRDSPR;
		CRDStot_=CRDSAct_+CRDSRempl_;
		Bourses_=bcol_champFPS+blyc_champFPS;
		Bourse_tot=bourse_col+bourse_lyc;
		run;

	proc transpose data=t out=t_ (rename=(_NAME_=Nom_SAS)); run;
	proc sort data=tableau&anleg.; by nom_SAS; run;
	proc sort data=t_; by nom_SAS; run;

	data tableau&anleg.;
		merge tableau&anleg. t_;
		by Nom_SAS;
		run;

	/* Mise en forme finale */
	proc sort data=tableau&anleg.; by c; run;

	data tableau&anleg. (keep=transfert nom_SAS obs: masse: moy: v_: valeur_cible_: ecart: eff: quel_tab);
		retain transfert nom_SAS obs_&anleg. masse_&anleg. effectif_&anleg. moyUC_&anleg. v_&anleg. masse_cible_&anleg. effectif_annuel_cible_&anleg. effectif_3112_cible_&anleg. valeur_cible_&anleg. ;
		set tableau&anleg.;
		%if &anleg. >=2013 %then %do ; 
			rename valeur_cible_&anleg. = valeur_cible_%sysevalf(&anleg.-1) ; 
			%end ;
		if masse_cible_&anleg.>0 then ecart_masse=(masse_&anleg.-masse_cible_&anleg.)/masse_cible_&anleg.;
		if effectif_annuel_cible_&anleg.>0 then ecart_eff_annuel=(effectif_&anleg.-effectif_annuel_cible_&anleg.)/effectif_annuel_cible_&anleg.;
		if effectif_3112_cible_&anleg.>0 then ecart_eff_3112=(effectif_&anleg.-effectif_3112_cible_&anleg.)/effectif_3112_cible_&anleg.;
		run;


	/*********************/
	/* Onglets de sortie */
	/*********************/
	%let ListeParam=anref anleg sysuserid casd noyau_uniquement tx module_ASS Nowcasting inclusion_TaxInd Anref_Ech_Prem imputEnf_prem accedant_prem imputHsup_prem retropole;
	/* Attention : liste dans le même ordre que ListeParam_Valeurs dans l'enchainement */
	proc sql; 
		create table t0 (parametre varchar(20), valeur varchar(20));
		%do i=1 %to %sysfunc(countw(&ListeParam.));
			insert into t0
			values ("%scan(&ListeParam.,&i.)","%scan(&ListeParam_Valeurs.,&i.)");
			/* &ListeParam_Valeurs. initialisée en début d'enchaînement, avant que les valeurs ne soient éventuellement modifiées */
			%end;
		quit;

	data 	t1 (drop=moyUC: v_: valeur_cible_: quel_tab)
			t2 (drop=moyUC: v_: valeur_cible_: quel_tab)
			t3 (drop=v_: quel_tab)
			t4 (%if &anleg. >=2013 %then %do ; rename =(valeur_cible_&anleg. = valeur_cible_%sysevalf(&anleg.-1))  %end ; keep=transfert nom_SAS v_: valeur_cible_:);
		set tableau&anleg.;
		if quel_tab='1' then output t1;
		if quel_tab='2' then output t2;
		if quel_tab='3' then output t3;
		if quel_tab='4' then output t4;
		run;

	proc format; picture hm other=%0H%0M (datatype=time); run;
	proc export data=t0	outfile="&sortie_cible./Sorties_Ines&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel_exp. replace; sheet="Param"; run;

	/* Export de l'onglet détaillé uniquement si on n'est pas dans le cadre d'une exploitation sur le CASD */
	%if &casd.=non %then %do;
		proc export data=tableau&anleg. (keep=transfert nom_SAS obs: masse: eff: ecart: moy: v:)
			outfile="&sortie_cible./Sorties_Ines&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel_exp. replace;
			sheet="Detail";
			run;
		%end;
	proc export data=t1	outfile="&sortie_cible./Sorties_Ines&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel_exp. replace; sheet="Presta"; run;
	proc export data=t2	outfile="&sortie_cible./Sorties_Ines&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel_exp. replace; sheet="Prelev"; run;
	proc export data=t3	outfile="&sortie_cible./Sorties_Ines&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel_exp. replace; sheet="Basemen"; run;
	proc export data=t4	outfile="&sortie_cible./Sorties_Ines&anleg._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel_exp. replace; sheet="Ineg"; run;

	/*** Ajout d'une sortie nécessaire au module TaxInd : répartition des masses de revenu disponible par décile ***/
	/* On recalcule les déciles de niveau de vie, avec un poids ménage et champ basemen pour être aligné sur le module TaxInd */
	%quantile(10,basemen,NdV,poiind,dec);
	proc means data=basemen noprint; var revdisp; class dec; weight poi; output out=dec_revdisp_ines (drop=_type_ _freq_) sum=; run;
	data dec_revdisp_ines ; set dec_revdisp_ines (rename = (revdisp=revdisp_ines&anr2.))  ; if dec eq . then delete; run; 
	/* exportation */
	proc export data=dec_revdisp_ines outfile="&dossier./revdisp_ines_taxind" dbms=&excel_exp. replace; sheet="rev_disp&anr2."; run;

	/* On vide la work des tables intermédiaires */
	

	%Mend;

%Sorties_Ines;

%Macro CompareSortiesDeuxInes(fSortie1,fSortie2,annee1,annee2);
	/* Cette macro importe simplement les fichiers Excel de sortie d'Ines et les compare deux à deux */
	/* Les deux fichiers doivent avoir la même forme (pas de modif du programme Cibles entre les deux), sinon génère probablement erreurs */
	/* Annee1 doit correspondre au fichier 1 (idem 2). ATTENTION ANNEE1<=ANNEE2 (pour calculer évol correctement) */

	%let libelle1=Ines&annee1._%substr(&fSortie1.,%index(&fSortie1.,&annee1._)+5,13);
	%let libelle2=Ines&annee2._%substr(&fSortie2.,%index(&fSortie2.,&annee2._)+5,13);
	%put &libelle1. &libelle2. ;
	%let onglets=Detail Presta Prelev Basemen Ineg;
	/* Liste des colonnes à garder par tableau (diffère) */
	%let toKeep1=obs_2: masse_2: effectif_2: ;
	%let toKeep2=obs_2: masse_2: effectif_2:;
	%let toKeep3=obs_2: masse_2: effectif_2:;
	%let toKeep4=obs_2: masse_2: effectif_2: moyUC_2:;
	%let toKeep5=v_2:;

	%do i=1 %to 5;
	%let ongletCourant=%scan(&onglets.,&i.);
		/* Import du premier fichier */
		proc import datafile=&fSortie1. out=fs1_&i.
					dbms=&excel_imp. replace; sheet="&ongletCourant.";	run;
		data fs1_&i.; set fs1_&i. (keep=transfert nom_SAS &&toKeep&i.); n=_N_; run;
		proc sort data=fs1_&i.; by nom_SAS; run;

		/* Import du deuxième fichier */
		proc import datafile=&fSortie2. out=fs2_&i.
					dbms=&excel_imp. replace; sheet="&ongletCourant."; run;
		data fs2_&i.; set fs2_&i. (keep=transfert nom_SAS &&toKeep&i.); n=_N_; run;
		proc sort data=fs2_&i.; by nom_SAS; run;

		/* Ajustements de mise en forme (pb si on compare 2 versions du même Ines) */
		%if &annee1.=&annee2. %then %do;
			proc contents data=fs1_&i. out=_var1 (keep=name); run;
			data _var1;	length l $1000.; set _var1 ; if name not in ('transfert' 'n' 'nom_SAS'); retain l; if _N_=1 then l=name; else l=compbl(l)||' '||name; run;
			data _var1;	set _var1 end=fin; if fin; call symput('lVar1',l); run ;
			proc contents data=fs2_&i. out=_var2 (keep=name); run;
			data _var2;	length l $1000.;  set _var2 ; if name not in ('transfert' 'n' 'nom_SAS'); retain l; if _N_=1 then l=name; else l=compbl(l)||' '||name; run;
			data _var2;	set _var2 end=fin; if fin; call symput('lVar2',l); run ;
			data fs1_&i.;
				set fs1_&i.;
				%do j=1 %to %sysfunc(countw(&lVar1.));
					rename %scan(&lVar1.,&j.)=%substr(%scan(&lVar1.,&j.),1,2)_&libelle1.;
					%end;
				run;
			data fs2_&i.;
				set fs2_&i.;
				%do j=1 %to %sysfunc(countw(&lVar2.));
					rename %scan(&lVar2.,&j.)=%substr(%scan(&lVar2.,&j.),1,2)_&libelle2.;
					%end;
				run;
			%end;

		/* Export d'un fichier de synthèse */
		data fs_&i.;
			merge fs1_&i. fs2_&i.;
			by Nom_Sas;
			%do j=1 %to %sysfunc(countw(&lVar2.));
				%let var = %substr(%scan(&lVar2.,&j.),1,2) ;
				diff_&var. = (&var._&libelle2.-&var._&libelle1.) ;
				if &var._&libelle1. ne 0 and &var._&libelle1. ne . then do ; 
					perct_&var.= (&var._&libelle2./&var._&libelle1.)-1 ; 
					end ;
				%end ;
			run;
		proc sort data=fs_&i.; by n; run;
		proc export data=fs_&i. (drop=n)
			outfile="&sortie_cible./Comp_&libelle1._&libelle2."
			dbms=&excel_exp. replace; sheet="&ongletCourant."; run;
		proc delete data=fs1_&i. fs2_&i. fs_&i.; run;
		%end;
	%Mend CompareSortiesDeuxInes;


/* Exemple d'utilisation */
*%CompareSortiesDeuxInes(	"X:\HAB-INES\Tables INES\Leg 2014 base 2012\sortie\Sorties_Ines2014_20160127_1521.xls",
							"X:\HAB-INES\Tables INES\Leg 2014 base 2012\sortie\Sorties_Ines2014_20160127_1511.xls",
							2014,2014);


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
