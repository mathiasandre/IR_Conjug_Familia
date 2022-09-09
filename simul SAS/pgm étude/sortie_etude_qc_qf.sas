/************************************/
/*									*/
/*	SORTIES SPECIFIQUES A L'ETUDE	*/
/*									*/
/************************************/

%include "&chemin_dossier.\pgm\5Sorties\macro_sortie.sas";

%Macro Initie_Champ_Men;
	/* réduction du champ à celui de l'ERFS, calcul des moyennes par UC */
	data basemen_out;
		set	basemen_synthese ;
		/* Champ ERFS et FPS + condition sur la consommation pour éviter de prendre des ménages sans conso imputées */
		if etud_pr = 'non' & revpos=1 & revdisp>0 & conso_tot^=. ; /* On filtre sur revdisp mais potentiellement, revdisp net de TVA (voire net de dépenses de loyer) négatif */
		/* Agrégats */
		minima=sum(0,aspa,aah,caah,rsasocle,rsaact,rsa_noel,psa,asi,patot,rsa);
		pf_condress=sum(0,paje,comxx,arsxx);
		pf_sansress=sum(0,aeeh,asf,clca);
		pf=pf_condress+pf_sansress;
		pf_tout=sum(0,pf,af);
		alog=sum(0,alogl,alogacc);
		PRESTA=sum(0,pf_tout,alog,minima);
		impot_tot=sum(0,impot,prelev_forf,verslib_autoentr,-pper);
		FinPSoc_=cotred+contred+crds_p;

		/* Poids individuel */
		poiind=poi*nbp;
		/* Pour la suite (taux de pauvreté) */
		NdV=revdisp/uci;

		/* NIVEAU TRES AGREGE : Revdisp=RevNet+Compl_Net_AvRed+Prelev+Presta */
		Compl_Net_AvRed=sum(0,cotred,csgd,-contassu);
		
		/* On construit la variable typmen5 à partir de typmen7, qu'on corrige au préalable à partir de typfam */
		/* Correction (on ne s'occupe pas des ménages complexes car ils ne sont pas catégorisés de la même façon) */
		typmen5='' ;
		if typmen7='1' and typfam in ('I1','I2+') then typmen7='2' ;
		if typmen7='3' and typfam in ('C1','C2') then typmen7='4' ;
		/* Création typmen5 */
		if typmen7 = '1' then typmen5 = '1_celibataire' ;
		else if typmen7 = '2' then typmen5 = '2_monoparentale' ;
		else if typmen7 = '3' then typmen5 = '3_couple_sans_enfant' ;
		else if typmen7 = '4' then typmen5 = '4_couple_avec_enfants' ;
		else if typmen7 in ('5', '6', '9') then typmen5='5_menage_complexe' ;
		/* Classes d'âge de la PR du ménage */ 
		tr_age_pr=1*(age_pr<30)+2*(age_pr>=30)*(age_pr<40)+3*(age_pr>=40)*(age_pr<50)+4*(age_pr>=50)*(age_pr<60)+5*(age_pr>=60)*(age_pr<70)+6*(age_pr>=70)*(age_pr<80)+7*(age_pr>=80)  ; 	
		

		run;
	%Mend Initie_Champ_Men;


%macro Sorties_qc_qf;

	/* 1 Fichier de sortie par scénario, portant le nom du scénario */
	/* Dans chaque onglet (sauf le 1), trois colonnes pour les trois années de simulation */

	/************************************************************************************************************/
	/* Onglet 0 : Paramétrage																					*/
	/* Onglet 1 : Niveau de vie moyen, min et max par décile de niveau de vie									*/
	/* Onglet 3 : Indicateurs d'inégalité et de pauvreté														*/
	/* Onglet 4 : Agrégats (agrégats ERFS, cotis, somme presta, somme prélèv ...) moyens par décile				*/
	/* Onglet 5 : Plus détaillé : transferts moyens par décile													*/
	/* Onglet 6 : Agrégats (agrégats ERFS, cotis, somme presta, somme prélèv ...) moyens par type de ménages	*/
	/* Onglet 7 : Plus détaillé : transferts moyens par type de ménages											*/
	/************************************************************************************************************/

	/************************/
	/* T0	PARAMETRAGE		*/
	/************************/
	/* On modifie quelques paramètres pour les fichiers */
	
	%let ListeParam_qc_qf=
					anref anleg inclusion_TaxInd sysuserid casd noyau_uniquement tx Nowcasting Anref_Ech_Prem imputEnf_prem accedant_prem
					;
		proc sql; create table t0 (parametre varchar(20), valeur varchar(20)); quit;
		%do i=1 %to %sysfunc(countw(&ListeParam_qc_qf.));
			%let Var=%scan(&ListeParam_qc_qf.,&i.);
			%let Val=&&&Var.;
			proc sql; insert into t0 values ("&Var.","&Val."); quit;
			%end;

	/************************************************************************/
	/* T1 DECILES DE NIVEAU DE VIE : SEUILS ET MOYENNES  		*/
	/*		(situation CTF)   				*/
	/************************************************************************/

	%quantile(10,Pour_Deciles_CTF,NdV,poiind,decile); /* Déciles de niveau de vie */
	proc means data=Pour_Deciles_CTF;
		var NdV;
		class decile;
		output out=t1 mean=NdVMoy min=NdVMin max=NdVMax;
		weight poiind;
		run;

	/***************************====*********************/
	/* T2	INDICATEURS D'INEGALITES ET DE PAUVRETE 	*/
	/* 	Dépend du scénario de simulation A2 ou A3 	*/
	/****************************************************/

	%do A=1 %to 3;
		%Initie_Champ_Men(a&A., qcqf_&A., Deciles_A&A.);
		proc univariate data=Deciles_A&A. noprint;
			var NdV;
			freq poiind;
			output out=S_Deciles
			pctlpts=5 10 20 25 30 40 50 60 70 75 80 90 95 pctlpre=p;
			run;
		proc transpose data=S_Deciles out=S_Deciles; run;
	   	data _null_;
	      	set S_Deciles;
		  	call symput(_NAME_,col1);
			run;

		/* Ratio interpercentiles et seuil et taux de pauvreté */
		%let seuil_pauvrete60=%sysevalf(0.6*&p50.); /* Pauvreté à 60 % */
		%let seuil_pauvrete50=%sysevalf(0.5*&p50.); /* Pauvreté à 50 % */
		%let inter_deciles=%sysevalf(&p90./&p10.);
		%let d9_d5=%sysevalf(&p90./&p50.);
		%let d5_d1=%sysevalf(&p50./&p10.);
		%let inter_quartiles=%sysevalf(&p75./&p25.);
		%let inter_quintiles=%sysevalf(&p80./&p20.);
		data Deciles_A&A.; set Deciles_A&A.; pauvre60=NdV<&seuil_pauvrete60.; pauvre50=NdV<&seuil_pauvrete50.; run;
		proc means data=Deciles_A&A.; var pauvre60 pauvre50; weight poiind; output out=t3 mean=; run;
		proc transpose data=t3 (drop=_type_ _freq_) out=t3; run;
		data _null_; set t3; call symput(_NAME_,col1); run;

		/* Intensité de la pauvreté */
		/* 60 % */
		proc means data=Deciles_A&A. noprint;
			var NdV;
			weight poiind;
			where pauvre60; 
			output out=tab3_wP60_A&A. (drop=_type_ _freq_) median=NdV_Median_pauvre60;
			run;
		proc transpose data=tab3_wP60_A&A. out=tab3_wP60_A&A. ; run;
	   	data _null_; set tab3_wP60_A&A. ; call symput(_NAME_,col1); run;
		%let intPauvrete60=%sysevalf((&seuil_pauvrete60.-&NdV_Median_pauvre60.)/&seuil_pauvrete60.); 
		/* 50 % */
		proc means data=Deciles_A&A. noprint;
			var NdV;
			weight poiind;
			where pauvre50; 
			output out=tab3_wP50_A&A. (drop=_type_ _freq_) median=NdV_Median_pauvre50;
			run;
		proc transpose data=tab3_wP50_A&A. out=tab3_wP50_A&A. ; run;
	   	data _null_; set tab3_wP50_A&A. ; call symput(_NAME_,col1); run;
		%let intPauvrete50=%sysevalf((&seuil_pauvrete50.-&NdV_Median_pauvre50.)/&seuil_pauvrete50.); 

		/* Coefficient de Gini */
		%Gini(data=Deciles_A&A.,var=NdV,pond=poiind,out=gini);
	   	data _null_; set gini; call symput('Gini',gini); run;

		%let liste_mv=p5 p10 p20 p25 p30 p40 p50 p60 p70 p75 p80 p90 p95 inter_deciles d9_d5 d5_d1 inter_quartiles inter_quintiles gini 
						seuil_pauvrete60 pauvre60 intPauvrete60 seuil_pauvrete50 pauvre50 intPauvrete50 ;
		%let liste_v=p5 d1 d2 q1 d3 d4 d5 d6 d7 q3 d8 d9 p95 d9_d1 d9_d5 d5_d1 q3_q1 d8_d2 gini sp60 tp60 intp60 sp50 tp50 intp50 ;
		proc sql;
			create table t3_A&A. (nom_SAS varchar(20), valeur_A&A. float);
			%do i=1 %to %sysfunc(countw(&liste_v.));
			%let mv=%scan(&liste_mv.,&i.);
			insert into t3_A&A. (nom_SAS,valeur_A&A.) values ("%scan(&liste_v.,&i.)",&&&mv.);
					%end;
			quit;
		%end;
	data t3 ; merge t3_a0 t3_a1 t3_a2 t3_a3; run; /* Prêt à l'export */

	/****************************************************/
	/* T4	MASSES PAR ANNEE (niveau détaillé)  		*/
	/****************************************************/

	%do A=1 %to 3;
		/* On va chercher les tables qui ont servi plus haut */
		proc means data=Deciles_A&A.;
			var	revavred revdisp NdV 
				/* Premier niveau d'agrégation */
				/* Revenus */
				zsalm zchom zrstm zpim zalrm zrtom zragm zricm zrncm zfonm zracm zetrm zvamm zvalm zalvm produitfin_i /* zalvm doit être soustrait aux autres revenus sinon double compte avec produitfi_i */
				/*Presta et prelev */
				af paje comxx arsxx aeeh asf clca
				alogl alogacc
				aspa aah caah /*rsasocle rsaact */ rsa_noel /*psa*/ asi rsa patot
				impot prelev_forf verslib_autoentr pper th
				cotred contred crds_p 
				/* Deuxième niveau d'agrégation */
				zperm rev_inde rev_fon_acc rev_fin
				pf_condress pf_sansress pf pf_tout alog minima impot_tot finpsoc_  
				/* Cotisations et contributions*/
				cotis_patro tot_cotis tot_cont 
				/* Troisième niveau d'agrégation */
				revnet revbrut Compl_Net_AvRed prelev presta;
			weight poi;
			output out=t4_A&A. sum=;
			run;
		data t4_A&A.; set t4_A&A.; Annee="A&A."; run;
		%end;
	data t4; set t4_a0 t4_a1 t4_a2 t4_a3; run;
	proc transpose data=t4 out=t4; id annee ; run; /* Prêt à l'export (plus lisible / exploitable avec la proc transpose) */


	/******************************************************/
	/* T5	PREMIER NIVEAU DE SORTIES PAR DECILE (AGREGE) */
	/******************************************************/

	/* On réutilise les tables Deciles_&A&A. créées par la macro %Initie_Champ_Men dans la partie précédente */
	%do A=1 %to 3;
		/* On va chercher le décile contrefactuel (variable de la table Pour_Deciles_CTF calculée par la macro %Quantile plus haut */
		data Deciles_A&A.; merge Deciles_A&A. Pour_Deciles_CTF(keep=ident decile); by ident; run;
		proc means data=Deciles_A&A.;
			var RevAvRed RevNet Compl_Net_AvRed PRELEV  PRESTA RevDisp NdV ;
			class decile;
			weight poiind;
			output out=t5_a&A. mean=;
			run;
		data t5_A&A.; set t5_A&A.; Annee="A&A."; if decile ="" then decile="XX"; run;
		%end;
	data t5 (drop = _type_) ;
		retain decile _freq_ Annee RevAvRed RevNet Compl_Net_AvRed PRELEV PRESTA RevDisp NdV;
		set t5_a0 t5_a1 t5_a2 t5_a3; 
		run; /* Prêt à l'export (pas de transpose car plus lisible comme ça) */

	/*********************************************************/
	/* T6	DEUXIEME NIVEAU DE SORTIES PAR DECILE (DETAILLE) */
	/*********************************************************/

	%do A=1 %to 3;
		/* On va chercher les tables qui ont servi plus haut */
		proc means data=Deciles_A&A.;
			var	revavred revdisp NdV 
				/* Premier niveau d'agrégation */
				/* Revenus */
				zsalm zchom zrstm zpim zalrm zrtom zragm zricm zrncm zfonm zracm zetrm zvamm zvalm zalvm produitfin_i /* zalvm doit être soustrait aux autres revenus sinon double compte avec produitfi_i */
				/*Presta et prelev */
				af paje comxx arsxx aeeh asf clca
				alogl alogacc
				aspa aah caah /*rsasocle rsaact */ rsa_noel /*psa*/ asi rsa patot
				impot prelev_forf verslib_autoentr pper th
				cotred contred crds_p 
				/* Deuxième niveau d'agrégation */
				zperm rev_inde rev_fon_acc rev_fin
				pf_condress pf_sansress pf pf_tout alog minima impot_tot finpsoc_  
				/* Cotisations et contributions*/
				cotis_patro tot_cotis tot_cont 
				/* Troisième niveau d'agrégation */
				revnet revbrut Compl_Net_AvRed prelev presta;
			class decile;
			weight poiind;
			output out=t6_A&A. mean=;
			run;
		data t6_A&A.; set t6_A&A.; Annee="A&A."; if decile ="" then decile="XX"; run;
		%end;
	data t6; set t6_a0 t6_a1 t6_a2 t6_a3; run;
	proc transpose data=t6 out=t6; id annee decile; run; /* Prêt à l'export (plus lisible / exploitable avec la proc transpose) */

	/******************************************************/
	/* T7	PREMIER NIVEAU DE SORTIES PAR TYPMEN (AGREGE) */
	/******************************************************/

	/* On réutilise les tables Deciles_&A&A. créées par la macro %Initie_Champ_Men dans la partie précédente */
	%do A=1 %to 3;
		/* On va chercher le typmen5 dans la table Pour_Deciles_CTF */
		data Deciles_A&A.; merge Deciles_A&A. Pour_Deciles_CTF(keep=ident typmen5); by ident; run;
		proc means data=Deciles_A&A.;
			var RevAvRed RevNet Compl_Net_AvRed PRELEV montant_tva PRELEV_tout PRESTA RevDisp NdV;
			class typmen5;
			weight poiind;
			output out=t7_a&A. mean=;
			run;
		data t7_A&A.; set t7_A&A.; Annee="A&A."; if typmen5 ="" then typmen5="XX"; run;
		%end;
	data t7 (drop = _type_) ;
		retain typmen5 _freq_ Annee RevAvRed RevNet Compl_Net_AvRed PRELEV montant_tva PRELEV_tout PRESTA RevDisp NdV;
		set t7_a0 t7_a1 t7_a2 t7_a3; 
		run; /* Prêt à l'export (pas de transpose car plus lisible comme ça) */

	/*********************************************************/
	/* T8	DEUXIEME NIVEAU DE SORTIES PAR TYPMEN (DETAILLE) */
	/*********************************************************/

	%do A=1 %to 3;
		/* On va chercher les tables qui ont servi plus haut */
		proc means data=Deciles_A&A.;
			var	revavred revdisp NdV
				/* Premier niveau d'agrégation */
				/* Revenus */
				zsalm zchom zrstm zpim zalrm zrtom zragm zricm zrncm zfonm zracm zetrm zvamm zvalm zalvm produitfin_i /* zalvm doit être soustrait aux autres revenus sinon double compte avec produitfi_i */
				/*Presta et prelev */
				af paje comxx arsxx aeeh asf clca
				alogl alogacc
				aspa aah caah /*rsasocle rsaact */ rsa_noel /*psa*/ asi rsa patot
				impot prelev_forf verslib_autoentr pper th
				cotred contred crds_p 
				/* Deuxième niveau d'agrégation */
				zperm rev_inde rev_fon_acc rev_fin
				pf_condress pf_sansress pf pf_tout alog minima impot_tot finpsoc_  
				/* Cotisations et contributions*/
				cotis_patro tot_cotis tot_cont 
				/* Troisième niveau d'agrégation */
				revnet revbrut Compl_Net_AvRed prelev presta;
			class typmen5;
			weight poiind;
			output out=t8_A&A. mean=;
			run;
		data t8_A&A.; set t8_A&A.; Annee="A&A."; if typmen5 ="" then typmen5="XX"; run;
		%end;
	data t8; set t8_a0 t8_a1 t8_a2 t8_a3; run;
	proc transpose data=t8 out=t8; id annee typmen5; run; /* Prêt à l'export (plus lisible / exploitable avec la proc transpose) */

	/****************************************************************************************/
	/* T13 A Quintiles des pertes de revenu disponible (net TVA et loyer) à l'issue des 3 ans */
	/****************************************************************************************/
	%let liste_agregats=RevAvRed PRELEV montant_tva PRESTA RevDisp RevDisp_nettva loyer RevDisp_nettva_loyer NdV NdV_nettva NdV ;
	data Deciles_A0_A3_pertes (where=(delta_RevDisp_nettva_loyer <0))  ;
		merge 	Deciles_A0 (keep= 	ident poi poiind &liste_agregats.
							rename=(RevAvRed=RevAvRed_CTF PRELEV=PRELEV_CTF montant_tva=montant_tva_CTF PRESTA=PRESTA_CTF RevDisp=RevDisp_CTF RevDisp_nettva=RevDisp_nettva_CTF 
									loyer=loyer_CTF RevDisp_nettva_loyer=RevDisp_nettva_loyer_CTF NdV=NdV_CTF NdV_nettva=NdV_nettva_CTF NdV=NdV_CTF))                                     
		  		Deciles_A3 (keep= 	ident &liste_agregats.) ;
		by ident ;
		%macro delta_agreg(liste) ;
			%do i=1 %to %sysfunc(countw(&liste.));
				%let agreg=%scan(&liste.,&i.);
				delta_&agreg.=&agreg.-&agreg._CTF ;	
				%end;
			%mend ;
		%delta_agreg(&liste_agregats.) ;
		run ;
	%quantile(5,Deciles_A0_A3_pertes,delta_RevDisp_nettva_loyer,poi,quintile_perte_revdisp);
	/* Niveau de sorties détaillé par quintiles de perte */
	proc means data=Deciles_A0_A3_pertes ;
		var delta_RevAvRed delta_PRELEV delta_montant_tva delta_PRESTA delta_RevDisp delta_RevDisp_nettva delta_loyer delta_RevDisp_nettva_loyer 
			delta_NdV delta_NdV_nettva delta_NdV ;
		class quintile_perte_revdisp ;
		weight poiind ;
		output out=t13A mean=;
		run;

	/******************************************************************************************/
	/* T13 B	PREMIER NIVEAU DE SORTIES PAR QUINTILES DE PERTE ABSOLUE DE REV DISP (AGREGE) */
	/******************************************************************************************/

	/* On réutilise les tables Deciles_&A&A. créées par la macro %Initie_Champ_Men dans la partie précédente */
	%do A=1 %to 3;
		/* On va chercher quintile_perte_revdisp dans la table Deciles_A0_A3_pertes  */
		data Deciles_A&A.; merge Deciles_A&A. Deciles_A0_A3_pertes (keep=ident quintile_perte_revdisp); by ident ; run;
		proc means data=Deciles_A&A.;
			var RevAvRed RevNet Compl_Net_AvRed PRELEV montant_tva PRELEV_tout PRESTA RevDisp NdV;
			class quintile_perte_revdisp;
			weight poiind;
			where quintile_perte_revdisp ne "";
			output out=t13B_a&A. mean=;
			run;
		data t13B_A&A.; set t13B_A&A.; Annee="A&A."; if quintile_perte_revdisp ="" then quintile_perte_revdisp="XX"; run;
		%end;
	data t13B (drop = _type_) ;
		retain quintile_perte_revdisp _freq_ Annee RevAvRed RevNet Compl_Net_AvRed PRELEV montant_tva PRELEV_tout PRESTA RevDisp NdV;
		set t13B_a0 t13B_a1 t13B_a2 t13B_a3; 
		run; /* Prêt à l'export (pas de transpose car plus lisible comme ça) */

	/*********************************************************************************************/
	/* T13 C	DEUXIEME NIVEAU DE SORTIES PAR QUINTILES DE PERTE ABSOLUE DE REV DISP (DETAILLE) */
	/*********************************************************************************************/

	%do A=1 %to 3;
		/* On va chercher les tables qui ont servi plus haut */
		proc means data=Deciles_A&A.;
			var	revavred revdisp RevDisp_nettva ndv NdV_nettva RevDisp_nettva_loyer NdV
				/* Premier niveau d'agrégation */
				/* Revenus */
				zsalm zchom zperm rev_inde rev_fon_acc rev_fin
				/*Presta et prelev */
				af paje comxx arsxx aeeh asf clca
				alogl alogacc
				aspa aah caah /*rsasocle rsaact */ rsa_noel /*psa*/ asi rsa patot
				impot prelev_forf verslib_autoentr pper th
				cotred contred crds_p montant_tva_N montant_tva_I montant_tva_R montant_tva_SR
				/* Deuxième niveau d'agrégation */
				pf_condress pf_sansress pf pf_tout alog minima impot_tot finpsoc_ impot_direct_ montant_tva
				/* Loyers */
				loyer 
				/* Troisième niveau d'agrégation */
				revnet Compl_Net_AvRed prelev prelev_tout presta;
			class quintile_perte_revdisp;
			weight poiind;
			where quintile_perte_revdisp ne "";
			output out=t13C_A&A. mean=;
			run;
		data t13C_A&A.; set t13C_A&A.; Annee="A&A."; if quintile_perte_revdisp ="" then quintile_perte_revdisp="XX"; run;
		%end;
	data t13C; set t13C_a0 t13C_a1 t13C_a2 t13C_a3; run;
	proc transpose data=t13C out=t13C; id annee quintile_perte_revdisp; run; /* Prêt à l'export (plus lisible / exploitable avec la proc transpose) */

	/**********************************************************************************************/
	/* T14 A Quintiles de % de pertes de revenu disponible (net TVA et loyer) à l'issue des 3 ans */
	/**********************************************************************************************/
	/* On reprend la table Deciles_A0_A3_pertes */
	data Deciles_A0_A3_pertes ;
		set Deciles_A0_A3_pertes ;
		%macro delta_perct_agreg(liste) ;
			%do i=1 %to %sysfunc(countw(&liste.));
				%let agreg=%scan(&liste.,&i.);
				delta_perct_&agreg.=0 ;
				if &agreg._CTF ne 0 then do ;
					delta_perct_&agreg.=(&agreg.-&agreg._CTF)/(&agreg._CTF) ;	
					end;
				%end ;
			%mend ;
		%delta_perct_agreg(&liste_agregats.) ;
		run ;
	%quantile(5,Deciles_A0_A3_pertes,delta_perct_RevDisp_nettva_loyer,poi,quint_perct_perte_revdisp);
	/* Niveau de sorties détaillé par quintiles de perte */
	proc means data=Deciles_A0_A3_pertes ;
		var delta_perct_RevAvRed delta_perct_PRELEV delta_perct_montant_tva delta_perct_PRESTA delta_perct_RevDisp delta_perct_RevDisp_nettva delta_perct_loyer 
			delta_perct_RevDisp_nettva_loyer 
			delta_perct_NdV delta_perct_NdV_nettva delta_perct_NdV ;
		class quint_perct_perte_revdisp ;
		weight poiind ;
		output out=t14A mean=;
		run;
	
	/******************************************************************************************/
	/* T14 B	PREMIER NIVEAU DE SORTIES PAR QUINTILES DE % de PERTE DE REV DISP (AGREGE) 	  */
	/******************************************************************************************/

	/* On réutilise les tables Deciles_&A&A. créées par la macro %Initie_Champ_Men dans la partie précédente */
	%do A=1 %to 3;
		/* On va chercher quintile_perte_revdisp dans la table Deciles_A0_A3_pertes  */
		data Deciles_A&A.; merge Deciles_A&A. Deciles_A0_A3_pertes (keep=ident quint_perct_perte_revdisp); by ident ; run;
		proc means data=Deciles_A&A.;
			var RevAvRed RevNet Compl_Net_AvRed PRELEV montant_tva PRELEV_tout PRESTA RevDisp NdV;
			class quint_perct_perte_revdisp;
			weight poiind;
			where quint_perct_perte_revdisp ne "";
			output out=t14B_a&A. mean=;
			run;
		data t14B_A&A.; set t14B_A&A.; Annee="A&A."; if quint_perct_perte_revdisp ="" then quint_perct_perte_revdisp="XX"; run;
		%end;
	data t14B (drop = _type_) ;
		retain quint_perct_perte_revdisp _freq_ Annee RevAvRed RevNet Compl_Net_AvRed PRELEV montant_tva PRELEV_tout PRESTA RevDisp NdV;
		set t14B_a0 t14B_a1 t14B_a2 t14B_a3; 
		run; /* Prêt à l'export (pas de transpose car plus lisible comme ça) */

	/*********************************************************************************************/
	/* T14 C	DEUXIEME NIVEAU DE SORTIES PAR QUINTILES DE % de PERTE DE REV DISP (DETAILLE)    */
	/*********************************************************************************************/

	%do A=1 %to 3;
		/* On va chercher les tables qui ont servi plus haut */
		proc means data=Deciles_A&A.;
			var	revavred revdisp RevDisp_nettva ndv NdV_nettva RevDisp_nettva_loyer NdV
				/* Premier niveau d'agrégation */
				/* Revenus */
				zsalm zchom zperm rev_inde rev_fon_acc rev_fin
				/*Presta et prelev */
				af paje comxx arsxx aeeh asf clca
				alogl alogacc
				aspa aah caah /*rsasocle rsaact */ rsa_noel /*psa*/ asi rsa patot
				impot prelev_forf verslib_autoentr pper th
				cotred contred crds_p montant_tva_N montant_tva_I montant_tva_R montant_tva_SR
				/* Deuxième niveau d'agrégation */
				pf_condress pf_sansress pf pf_tout alog minima impot_tot finpsoc_ impot_direct_ montant_tva
				/* Loyers */
				loyer 
				/* Troisième niveau d'agrégation */
				revnet Compl_Net_AvRed prelev prelev_tout presta;
			class quint_perct_perte_revdisp;
			weight poiind;
			where quint_perct_perte_revdisp ne "";
			output out=t14C_A&A. mean=;
			run;
		data t14C_A&A.; set t14C_A&A.; Annee="A&A."; if quint_perct_perte_revdisp ="" then quint_perct_perte_revdisp="XX"; run;
		%end;
	data t14C; set t14C_a0 t14C_a1 t14C_a2 t14C_a3; run;
	proc transpose data=t14C out=t14C; id annee quint_perct_perte_revdisp; run; /* Prêt à l'export (plus lisible / exploitable avec la proc transpose) */


	/****************************************************************************************/
	/* T15 A Médiane des gains de revenu disponible (net TVA et loyer) à l'issue des 3 ans  */
	/****************************************************************************************/
	%let liste_agregats=RevAvRed PRELEV montant_tva PRESTA RevDisp RevDisp_nettva loyer RevDisp_nettva_loyer NdV NdV_nettva NdV ;
	data Deciles_A0_A3_gains (where=(delta_RevDisp_nettva_loyer >0)) ;
		merge 	Deciles_A0 (keep= 	ident poi poiind &liste_agregats.
							rename=(RevAvRed=RevAvRed_CTF PRELEV=PRELEV_CTF montant_tva=montant_tva_CTF PRESTA=PRESTA_CTF RevDisp=RevDisp_CTF RevDisp_nettva=RevDisp_nettva_CTF 
									loyer=loyer_CTF RevDisp_nettva_loyer=RevDisp_nettva_loyer_CTF NdV=NdV_CTF NdV_nettva=NdV_nettva_CTF NdV=NdV_CTF))                                     
		  		Deciles_A3 (keep= 	ident &liste_agregats.) ;
		by ident ;
		%macro delta_agreg(liste) ;
			%do i=1 %to %sysfunc(countw(&liste.));
				%let agreg=%scan(&liste.,&i.);
				delta_&agreg.=&agreg.-&agreg._CTF ;	
				%end;
			%mend ;
		%delta_agreg(&liste_agregats.) ;
		run ;
	%quantile(2,Deciles_A0_A3_gains,delta_RevDisp_nettva_loyer,poi,med_gain_revdisp);
	/* Niveau de sorties détaillé par groupe sous et au dessus médiane de gain */
	proc means data=Deciles_A0_A3_gains ;
		var delta_RevAvRed delta_PRELEV delta_montant_tva delta_PRESTA delta_RevDisp delta_RevDisp_nettva delta_loyer delta_RevDisp_nettva_loyer 
			delta_NdV delta_NdV_nettva delta_NdV ;
		class med_gain_revdisp ;
		weight poiind ;
		output out=t15A mean=;
		run;
	
	/**************************************************************************************************/
	/* T15 B	PREMIER NIVEAU DE SORTIES PAR GROUPE "médians" DE gain absolu DE REV DISP (AGREGE) 	  */
	/**************************************************************************************************/

	/* On réutilise les tables Deciles_&A&A. créées par la macro %Initie_Champ_Men dans la partie précédente */
	%do A=1 %to 3;
		/* On va chercher quintile_perte_revdisp dans la table Deciles_A0_A3_pertes  */
		data Deciles_A&A.; merge Deciles_A&A. Deciles_A0_A3_gains (keep=ident med_gain_revdisp); by ident ; run;
		proc means data=Deciles_A&A.;
			var RevAvRed RevNet Compl_Net_AvRed PRELEV montant_tva PRELEV_tout PRESTA RevDisp NdV;
			class med_gain_revdisp;
			weight poiind;
			where med_gain_revdisp ne "";
			output out=t15B_a&A. mean=;
			run;
		data t15B_A&A.; set t15B_A&A.; Annee="A&A."; if med_gain_revdisp ="" then med_gain_revdisp="XX"; run;
		%end;
	data t15B (drop = _type_) ;
		retain med_gain_revdisp _freq_ Annee RevAvRed RevNet Compl_Net_AvRed PRELEV montant_tva PRELEV_tout PRESTA RevDisp NdV;
		set t15B_a0 t15B_a1 t15B_a2 t15B_a3; 
		run; /* Prêt à l'export (pas de transpose car plus lisible comme ça) */

	/*****************************************************************************************************/
	/* T15 C	DEUXIEME NIVEAU DE SORTIES PAR GROUPE "médians" DE gain absolu DE REV DISP (DETAILLE)    */
	/*****************************************************************************************************/

	%do A=1 %to 3;
		/* On va chercher les tables qui ont servi plus haut */
		proc means data=Deciles_A&A.;
			var	revavred revdisp RevDisp_nettva ndv NdV_nettva RevDisp_nettva_loyer NdV
				/* Premier niveau d'agrégation */
				/* Revenus */
				zsalm zchom zperm rev_inde rev_fon_acc rev_fin
				/*Presta et prelev */
				af paje comxx arsxx aeeh asf clca
				alogl alogacc
				aspa aah caah /*rsasocle rsaact */ rsa_noel /*psa*/ asi rsa patot
				impot prelev_forf verslib_autoentr pper th
				cotred contred crds_p montant_tva_N montant_tva_I montant_tva_R montant_tva_SR
				/* Deuxième niveau d'agrégation */
				pf_condress pf_sansress pf pf_tout alog minima impot_tot finpsoc_ impot_direct_ montant_tva
				/* Loyers */
				loyer 
				/* Troisième niveau d'agrégation */
				revnet Compl_Net_AvRed prelev prelev_tout presta;
			class med_gain_revdisp;
			weight poiind;
			where med_gain_revdisp ne "";
			output out=t15C_A&A. mean=;
			run;
		data t15C_A&A.; set t15C_A&A.; Annee="A&A."; if med_gain_revdisp ="" then med_gain_revdisp="XX"; run;
		%end;
	data t15C; set t15C_a0 t15C_a1 t15C_a2 t15C_a3; run;
	proc transpose data=t15C out=t15C; id annee med_gain_revdisp; run; /* Prêt à l'export (plus lisible / exploitable avec la proc transpose) */


	/******************************************************************************************/
	/* T16 A Médiane des % de gains de revenu disponible (net TVA et loyer) à l'issue des 3 ans */
	/******************************************************************************************/
	/* On reprend la table Deciles_A0_A3_gains */
	data Deciles_A0_A3_gains ;
		set Deciles_A0_A3_gains ;
		%macro delta_perct_agreg(liste) ;
			%do i=1 %to %sysfunc(countw(&liste.));
				%let agreg=%scan(&liste.,&i.);
				delta_perct_&agreg.=0 ;	
				if &agreg._CTF ne 0 then do ;
					delta_perct_&agreg.=(&agreg.-&agreg._CTF)/(&agreg._CTF) ;
					end;
				%end;
			%mend ;
		%delta_perct_agreg(&liste_agregats.) ;
		run ;
	%quantile(2,Deciles_A0_A3_gains,delta_perct_RevDisp_nettva_loyer,poi,med_perct_gain_revdisp);
	/* Niveau de sorties détaillé par groupe sous et au dessus médiane de % de gain */
	proc means data=Deciles_A0_A3_gains ;
		var delta_perct_RevAvRed delta_perct_PRELEV delta_perct_montant_tva delta_perct_PRESTA delta_perct_RevDisp delta_perct_RevDisp_nettva delta_perct_loyer 
			delta_perct_RevDisp_nettva_loyer 
			delta_perct_NdV delta_perct_NdV_nettva delta_perct_NdV ;
		class med_perct_gain_revdisp ;
		weight poiind ;
		output out=t16A mean=;
		run;

	/******************************************************************************************************************/
	/* T16 B	PREMIER NIVEAU DE SORTIES PAR GROUPE "médians" DE % de gains de REV DISP (AGREGE) 		  */
	/******************************************************************************************************************/

	/* On réutilise les tables Deciles_&A&A. créées par la macro %Initie_Champ_Men dans la partie précédente */
	%do A=1 %to 3;
		/* On va chercher quintile_perte_revdisp dans la table Deciles_A0_A3_pertes  */
		data Deciles_A&A.; merge Deciles_A&A. Deciles_A0_A3_gains (keep=ident med_perct_gain_revdisp); by ident ; run;
		proc means data=Deciles_A&A.;
			var RevAvRed RevNet Compl_Net_AvRed PRELEV montant_tva PRELEV_tout PRESTA RevDisp NdV;
			class med_perct_gain_revdisp;
			weight poiind;
			where med_perct_gain_revdisp ne "";
			output out=t16B_a&A. mean=;
			run;
		data t16B_A&A.; set t16B_A&A.; Annee="A&A."; if med_perct_gain_revdisp ="" then med_perct_gain_revdisp="XX"; run;
		%end;
	data t16B (drop = _type_) ;
		retain med_perct_gain_revdisp _freq_ Annee RevAvRed RevNet Compl_Net_AvRed PRELEV montant_tva PRELEV_tout PRESTA RevDisp NdV;
		set t16B_a0 t16B_a1 t16B_a2 t16B_a3; 
		run; /* Prêt à l'export (pas de transpose car plus lisible comme ça) */

	/*****************************************************************************************************/
	/* T16 C	DEUXIEME NIVEAU DE SORTIES PAR GROUPE "médians" DE % de gains de REV DISP (DETAILLE)     */
	/*****************************************************************************************************/

	%do A=1 %to 3;
		/* On va chercher les tables qui ont servi plus haut */
		proc means data=Deciles_A&A.;
			var	revavred revdisp RevDisp_nettva ndv NdV_nettva RevDisp_nettva_loyer NdV
				/* Premier niveau d'agrégation */
				/* Revenus */
				zsalm zchom zperm rev_inde rev_fon_acc rev_fin
				/*Presta et prelev */
				af paje comxx arsxx aeeh asf clca
				alogl alogacc
				aspa aah caah /*rsasocle rsaact */ rsa_noel /*psa*/ asi rsa patot
				impot prelev_forf verslib_autoentr pper th
				cotred contred crds_p montant_tva_N montant_tva_I montant_tva_R montant_tva_SR
				/* Deuxième niveau d'agrégation */
				pf_condress pf_sansress pf pf_tout alog minima impot_tot finpsoc_ impot_direct_ montant_tva
				/* Loyers */
				loyer 
				/* Troisième niveau d'agrégation */
				revnet Compl_Net_AvRed prelev prelev_tout presta;
			class med_perct_gain_revdisp;
			weight poiind;
			where med_perct_gain_revdisp ne "";
			output out=t16C_A&A. mean=;
			run;
		data t16C_A&A.; set t16C_A&A.; Annee="A&A."; if med_perct_gain_revdisp ="" then med_perct_gain_revdisp="XX"; run;
		%end;
	data t16C; set t16C_a0 t16C_a1 t16C_a2 t16C_a3; run;
	proc transpose data=t16C out=t16C; id annee med_perct_gain_revdisp; run; /* Prêt à l'export (plus lisible / exploitable avec la proc transpose) */

	%mend Sorties_qc_qf;

%Sorties_qc_qf;

proc format; picture hm other=%0H%0M (datatype=time); run;

proc export data=t0	outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Param"; run;
proc export data=t1	outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Deciles_CTF"; run;
proc export data=t2	outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Consommation_CTF"; run;
proc export data=t3	outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Ineg"; run;
proc export data=t4	outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Masses"; run;
proc export data=t5	outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Agrege_deciles"; run;
proc export data=t6	outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Detaille_deciles"; run;
proc export data=t7	outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Agrege_typmen"; run;
proc export data=t8	outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Detaille_typmen"; run;
proc export data=t9	outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Agrege_age_pr"; run;
proc export data=t10 outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Detaille_age_pr"; run;
proc export data=t11 outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Agrege_occlog"; run;
proc export data=t12 outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Detaille_occlog"; run;

proc export data=t13A outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Deltas_quintile_perte"; run;
proc export data=t13B outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Agrege_quintperte"; run;
proc export data=t13C outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Detaille_quintperte"; run;

proc export data=t14A outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Deltas_quintile_perct_perte"; run;
proc export data=t14B outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Agrege_quint_perctperte"; run;
proc export data=t14C outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Detaille_quint_perctperte"; run;

proc export data=t15A outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Deltas_median_gain"; run;
proc export data=t15B outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Agrege_medgain"; run;
proc export data=t15C outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Detaille_medgain"; run;

proc export data=t16A outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Deltas_median_perct_gain"; run;
proc export data=t16B outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Agrege_med_perctgain"; run;
proc export data=t16C outfile="&sortie_TVA.\Sorties_Etude_Scenario&scenario._&Scenario_TVA._&passthrough._%sysfunc(putn(%sysfunc(date()), yymmddn8.))_%sysfunc(time(),hm4.)" dbms=&excel. replace; sheet="Detaille_med_perctgain"; run;

