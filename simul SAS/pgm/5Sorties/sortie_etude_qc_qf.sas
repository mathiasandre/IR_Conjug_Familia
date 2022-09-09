/************************************************************************/
/*																		*/
/*       	SORTIES POUR LA VUE D'ENSEMBLE FPS 2016                   	*/
/* 		Sert à la fois pour l'effet en N et pour l'effet consolidé 		*/
/*																		*/
/************************************************************************/

%let sortie_cible=&chemin_bases.\Leg &anleg Base &anref\sortie;
%put &sortie_etude_qc_qf.;
%include "&chemin_dossier.\pgm\5Sorties\macro_sortie.sas";
options nomprint nosymbolgen nomlogic;

/************************************************************************************/
/* I	Création des tables sortie_qc_qf et sortie_qc_qfuc à partir de ctf.basemen_synthese	*/
/************************************************************************************/

/*	1	Définition des mesures dans l'ordre */
%let Nb_Mesures=2;
/*%let mesureI=Signe Variable_Avant Variable_Apres Nom_Mesure Type_Mesure; */
/* 	Pour signe : il s'agit du signe des deux variables (Avant et Après) : , cf ligne 80 environ ci-dessous
	En gros il faut mettre toujours p (positif), sauf si on décide de mesurer l'effet de la mesure comme différence sur une variable d'impôt */
%let mesure1=	p revdisp_0 revdisp_1 Conjug	Fiscale;
%let mesure2=	p revdisp_1 revdisp_2 Famil		Fiscale;


/*	2	Définition des revenus disponibles à chaque étape */

%macro Prep_table(table,sortie,sortieuc);

	%macro Gagnant_Perdant_Mesure(Mesure);
		Gagnants_&Mesure.=(&Mesure. gt 1);
		Perdants_&Mesure.=(&Mesure. lt -1);
		effet_Gagnants_&Mesure.=(&Mesure. gt 1)*&Mesure.;
		effet_Perdants_&Mesure.=(&Mesure. lt -1)*&Mesure.;
		%mend;

	/* 3	Champ des ménages retenus */
	data &sortie.;
		set &table.;

		%Init_Valeur(cumul Mes_Fiscale);

		/* Champ de la redistribution RETENU POUR LA VUE FPS */
		if etud_pr_0 = 'non' & revpos_0=1 & revdisp_0>0;
		poidind=poi_0*nbp_0;
		poi_x_uci=poi_0*uci_0;
		poi=poi_0;
		run;

	data &sortie.;
		set &sortie.;
		cumul=0;
		RevDisp_Apres_Mesure0=revdisp_0; 
		%do NumMesure=1 %to &Nb_Mesures.;
			%let Signe=%scan(&&mesure&NumMesure.,1);
			%let VarAvant=%scan(&&mesure&NumMesure.,2);
			%let VarApres=%scan(&&mesure&NumMesure.,3);
			%let NomMesure=%scan(&&mesure&NumMesure.,4);
			%let TypeMesure=%scan(&&mesure&NumMesure.,5);
			%let j=%eval(&NumMesure.-1);

			%if &Signe.=n %then %do;
				RevDisp_Apres_Mesure&NumMesure.=RevDisp_Apres_Mesure&j.+&VarAvant.-&VarApres.;
				%end;
			%else %if &Signe.=p %then %do;
				RevDisp_Apres_Mesure&NumMesure.=RevDisp_Apres_Mesure&j.-&VarAvant.+&VarApres.;
				%end;
			
			Mes&NumMesure._&NomMesure.=RevDisp_Apres_Mesure&NumMesure.-RevDisp_Apres_Mesure&j.;
			%Gagnant_Perdant_Mesure(Mes&NumMesure._&NomMesure.);
			cumul=cumul+Mes&NumMesure._&NomMesure.;
			Mes_&TypeMesure.=Mes_&TypeMesure.+Mes&NumMesure._&NomMesure.;
			%end;

		verif=round(revdisp_&Nb_Mesures.-revdisp_0-cumul);
		Mes_tot=Mes_Fiscale;
		%Gagnant_Perdant_Mesure(Mes_Fiscale);
		run;

	/* 4	Mise en unités de consommation de toutes les variables numériques */
	proc contents DATA=&sortie. out=sortie(where=(TYPE=1)) noprint; run;
	data sortie1;
		set sortie;
		if name in ('age_pr','age_cj','nbfam','nbp_0','poi_0','poidind','poi_x_uci','revpos_0','uci_0') then delete;
		run;
		%let var1= ; 
	proc sql noprint;
		select name into : var1 separated by ' '
		from work.sortie1
		order by name;
		quit;
	data &sortieuc.; 
		set &sortie.;
		array montant &var1.; 
		do over montant; montant=montant/uci_0; end;
		run;
	%mend Prep_table;


%Prep_table(ctf.basemen_synthese,sortie_qc_qf,sortie_qc_qfuc);



/****************************************/
/* II	Sorties pour la vue d'ensemble	*/
/****************************************/


/*	FIGURE 1 : RESULTATS GLOBAUX DE LA LEGISLATION
	Onglet Indic_CTF  -->  colonne Contrefactuel 2015  */
%quantile(10,sortie_qc_qfuc,revdisp_0,poidind,decile_c); 
proc transpose data=quantile out=quantile_c (drop=_name_ rename=(_label_=lib col1=stat)); run;

%Gini(data=sortie_qc_qfuc,var=revdisp_0,pond=poidind,crit=,pseudo=,out=gini_c); 
proc transpose data=gini_c (drop=moyenne effectif) out=gini_c (drop=_name_ rename=(_label_=lib col1=stat)); run;

%Pauvrete(sortie_qc_qfuc,revdisp_0,0.6,tx_c);
data tx_c; set tx_c; lib="Taux de pauvreté"; rename taux=stat; run;

proc means data=sortie_qc_qfuc mean noprint;
	var revavred_0 revbrut_0 revdisp_0 revdisp_&Nb_Mesures.;
	class decile_c;
	weight poidind; 
	output out=NdV_mean_c (drop=_type_ _freq_) mean=;
	run;
data NdV_mean_c; set NdV_mean_c; lib=compress("Revdisp_0 Mean Poids Indiv"||decile_c);
keep lib revdisp_0; rename revdisp_0=stat; run;

proc means data=sortie_qc_qfuc mean noprint;
	var revavred_0 revbrut_0 revdisp_0 revdisp_&Nb_Mesures.;
	class decile_c;
	weight poi; 
	output out=NdV_meanMenage_c (drop=_type_ _freq_) mean=;
	run;
data NdV_meanMenage_c; set NdV_meanMenage_c; lib=compress("Revdisp_0 Mean Poids Ménage"||decile_c); 
keep lib revdisp_0; rename revdisp_0=stat; run;

data Indic_CTF; set quantile_c gini_c tx_c NdV_mean_c NdV_meanMenage_c; run;
proc export 
	dbms=&excel_exp. replace 
	data=Indic_CTF
	outfile="&sortie_etude_qc_qf";
	sheet="Indic_CTF";
	run;


/*	FIGURE 1 : RESULTATS GLOBAUX DE LA LEGISLATION
	Onglet Indic_Leg2015  -->  colonne Législation 2015, effet l'année même  */
%quantile(10,sortie_qc_qfuc,revdisp_&Nb_Mesures.,poidind,decile_i);
proc transpose data=quantile out=quantile_i (drop=_name_ rename=(_label_=lib col1=stat)); run;

%Gini(data=sortie_qc_qfuc,var=revdisp_&Nb_Mesures.,pond=poidind,crit=,pseudo=,out=gini_i); 
proc transpose data=gini_i (drop=moyenne effectif) out=gini_i (drop=_name_ rename=(_label_=lib col1=stat)); run;

%Pauvrete(sortie_qc_qfuc,revdisp_&Nb_Mesures.,0.6,tx_i);
data tx_i; set tx_i; lib="Taux de pauvreté"; rename taux=stat; run;

proc means data=sortie_qc_qfuc mean noprint;
	var revdisp_&Nb_Mesures.;
	class decile_c;
	weight poidind; 
	output out=NdV_mean_i (drop=_type_ _freq_) mean=;
	run;
data NdV_mean_i; set NdV_mean_i; lib=compress("Revdisp Mean Poids Indiv"||decile_c);
	keep lib revdisp_&Nb_Mesures.; rename revdisp_&Nb_Mesures.=stat; run;

proc means data=sortie_qc_qfuc mean noprint;
	var revdisp_&Nb_Mesures.;
	class decile_c;
	weight poi; 
	output out=NdV_meanMenage_i (drop=_type_ _freq_) mean=;
	run;
data NdV_meanMenage_i; set NdV_meanMenage_i; lib=compress("Revdisp Mean Poids Ménage"||decile_c);
	keep lib revdisp_&Nb_Mesures.; rename revdisp_&Nb_Mesures.=stat; run;

data Indic_&anleg.; set quantile_i gini_i tx_i NdV_mean_i NdV_meanMenage_i; run;
proc export
	dbms=&excel_exp. replace 
	data=Indic_&anleg.
	outfile="&sortie_etude_qc_qf";
	sheet="Indic_Leg&anleg.";
	run;


/*	FIGURE 2 : DECOMPOSITION DE LA VARIATION DES INEGALITES PAR CATEGORIES DE TRANSFERTS 
	Onglet Ctr_PG  -->  Colonne contribution à la réduction des inégalités, effet l'année même */

%macro GenereTexte;
	%global texte;
	%let texte=revdisp_&Nb_Mesures.=revdisp_0;
	%do i=1 %to &Nb_Mesures.;
		%let NomMesure=Mes&i._%scan(&&mesure&i.,4);
		%let texte=&texte.+&NomMesure.;
		%end;
	%put &texte.;
	%mend;
%GenereTexte;

%decomposition_Gini(formule="&texte.",
					table=sortie_qc_qfuc,
					pond=poidind,
					outTable=DecompGini);
proc export 
	dbms=&excel_exp. replace 
	data=DecompGini
	outfile="&sortie_etude_qc_qf";
	sheet="Ctr_PG";
	run; 


/* FIGURE 3 : RENDEMENT ET EFFET MOYEN DES MESURES 
Onglets	Effet_total  -->   effet total sur le revenu disponible
		Gagnants   -->  nombre de ménages gagnants 
		Effet_Gagnants  -->  effet total sur les ménages gagnants 
		Perdants   -->  nombre de ménages perdants 
		Effet_Perdants   -->  effet total sur les ménages perdants 	*/

proc means data=sortie_qc_qf noprint;
	var Mes:;
	weight poi;
	output out=Mesures_Total sum=;
	run;
proc transpose data=Mesures_Total out=Mesures_Total_; run;
proc means data=sortie_qc_qf noprint;
	var Gagnants:;
	weight poi;
	output out=Mesures_G sum=;
	run;
proc transpose data=Mesures_G out=Mesures_G_ ; run;
proc means data=sortie_qc_qf noprint;
	var effet_Gagnants:;
	weight poi;
	output out=Mesures_effet_G sum=;
	run;
proc transpose data=Mesures_effet_G out=Mesures_effet_G_ ; run;
proc means data=sortie_qc_qf noprint;
	var Perdants:;
	weight poi;
	output out=Mesures_P sum=;
	run;
proc transpose data=Mesures_P out=Mesures_P_ ; run;
proc means data=sortie_qc_qf noprint;
	var effet_Perdants:;
	weight poi;
	output out=Mesures_effet_p sum=;
	run;
proc transpose data=Mesures_effet_P out=Mesures_effet_P_ ; run;

proc export	dbms=&excel_exp. replace data=Mesures_Total_ outfile="&sortie_etude_qc_qf."; sheet="Effet_Total"; run;
proc export	dbms=&excel_exp. replace data=Mesures_G_ outfile="&sortie_etude_qc_qf."; sheet="Gagnants"; run;
proc export	dbms=&excel_exp. replace data=Mesures_effet_G_ outfile="&sortie_etude_qc_qf."; sheet="Effet_Gagnants"; run;
proc export	dbms=&excel_exp. replace data=Mesures_P_ outfile="&sortie_etude_qc_qf."; sheet="Perdants"; run;
proc export	dbms=&excel_exp. replace data=Mesures_effet_P_ outfile="&sortie_etude_qc_qf."; sheet="Effet_Perdants"; run;


/*	FIGURES 4 et 5 : EFFET DES MESURES PRELEVEMENTS PUIS PRESTATIONS SUR LE NIVEAU DE VIE
	Onglet Mesures2014_NdV_effet  --> les 2 figures			*/
proc means data=sortie_qc_qfuc mean noprint;
	var mes:;
	class decile_c;
	weight poidind; 
	output out=NdV_effet_mes (drop=_type_ _freq_) mean=;
	run;
proc export	dbms=&excel_exp. replace data=NdV_effet_mes outfile="&sortie_etude_qc_qf"; sheet="NdV_effet"; run;



/************************************************/
/* 	 III   Sorties complémentaires au cas où    */
/************************************************/

/* 1. Effet_total_NdV  --> effet total sur le niveau de vie */	 
/* Sortie supplémentaire à ajouter éventutellement à la figure : effet total en NdV pour calculer l'effet moyen par ménage concerné en NdV */ 
proc means data=sortie_qc_qfuc noprint;
	var mes:;
	weight poi;
	output out=Mesures_Total_NdV sum=;
	run;
proc transpose data=Mesures_Total_NdV out=Mesures_Total_NdV_; run;
proc export	dbms=&excel_exp. replace data=Mesures_Total_NdV_ outfile="&sortie_etude_qc_qf."; sheet="Effet_Total_NdV"; run;


/* 1.bis Onglets effet min et max */
proc means data=sortie_qc_qf noprint;
	var Mes:;
	weight poi;
	output out=Mesures_Min min=;
	run;
proc transpose data=Mesures_Min out=Mesures_Min_; run;
proc means data=sortie_qc_qf noprint;
	var Mes:;
	weight poi;
	output out=Mesures_Max max=;
	run;
proc transpose data=Mesures_Max out=Mesures_Max_; run;
proc export	dbms=&excel_exp. replace data=Mesures_Min_ outfile="&sortie_etude_qc_qf"; sheet="Effet_Min"; run;
proc export	dbms=&excel_exp. replace data=Mesures_Max_ outfile="&sortie_etude_qc_qf"; sheet="Effet_Max"; run;


/* 2.1	Onglet avec les masses des différents transferts par décile, à chacune des étapes */
%let transferts=revdisp af comxx arsxx paje aeeh asf clca aspa aah caah rsasocle rsaact rsa_noel asi alogl impot pper prelev_forf csgi csgd prelev_pat crds_ar crds_p cotred;
%Macro listeTransferts();
	%global l1;
	%let l1=;
	%do k=1 %to %sysfunc(countw(&transferts.));
		%let l1=&l1. %scan(&transferts.,&k.):;
		%end;
	%Mend;

%macro MassesTransferts(table,sortie,decile,SheetName);
	%listeTransferts;
	proc means data= &table. noprint;
		var &l1.;
		class &decile.;
		weight poi;
		output out=&sortie.(drop=_type_ _freq_) sum=;
		run;
	proc transpose data=&sortie. out=&sortie._; id decile_c; run;
	proc export
		dbms=&excel_exp. replace
		data=&sortie.
		outfile="&sortie_etude_qc_qf";
		sheet=&SheetName.;
		run;
	%mend MassesTransferts;

data sortie_qc_qf; merge sortie_qc_qf (in=a) sortie_qc_qfuc (keep=ident decile_c decile_i); by ident; run;
%MassesTransferts(sortie_qc_qf,tableau_masses_c,decile_c,sheetname=Masses_&anr2.);


/* 2.2	Onglet avec les effectifs des différents transferts par décile, à chacune des étapes */
%macro EffectifsTransferts(table,sortie,decile,SheetName);
	/* Création des indicatrices (nb transferts * nb mesures) */
	data temp;
		set &table.;
		%do i1=1 %to %sysfunc(countw(&transferts.));
			%do i2=0 %to &Nb_mesures.;
				indpos_%scan(&transferts.,&i1.)_&i2.=%scan(&transferts.,&i1.)_&i2. gt 0;
				%end;
			%end;
		run;
	proc means data=temp noprint;
		var indpos_:;
		class &decile.;
		weight poi;
		output out=&sortie.(drop=_type_ _freq_) sum=;
		run;
	proc transpose data=&sortie. out=&sortie._; id decile_c; run;
	proc export
		dbms=&excel_exp. replace
		data=&sortie._
		outfile="&sortie_etude_qc_qf";
		sheet=&SheetName.;
		run;
	%mend EffectifsTransferts;
%EffectifsTransferts(sortie_qc_qf,tableau_eff_c,decile_c,sheetname=Eff_&anr2.);



/* 3	Nombre de ménages imposés et de ménages impactés par chaque réforme */

proc means data=sortie_qc_qf mean sum;
	var impose_yc_ppe:;
	class decile_c;
	weight poi;
	output out=impose_yc_ppe mean=part_imposes_yc_ppe sum=nbmen_imposes_yc_ppe;
	run;
data impose_yc_ppe; set impose_yc_ppe; nbmen_tot=nbmen_imposes_yc_ppe/part_imposes_yc_ppe; run;
proc export 
	dbms=&excel_exp. replace 
	data=impose_yc_ppe
	outfile="&sortie_etude_qc_qf";
	sheet="Impose_yc_ppe";
	run;


/* 4	Nombre de foyers fiscaux */

proc sort data=modele2.impot_sur_rev&anr1.; by ident; run;
data foy_imp;
	merge	sortie_qc_qf (in=a keep=ident decile_c poi)
			modele2.impot_sur_rev&anr1. (keep=ident declar impot impot6 rename=(impot=impot_&Nb_Mesures. impot6=impot6_&Nb_Mesures.));
	by ident;
	if a; /* restriction du champ */
	run;

proc sort data=foy_imp; by declar; run;
proc sort data=modele2.ppe; by declar; run;
proc sort data=modele2.impot_sur_rev&anr1.; by declar; run;
proc sort data=modele1.ppe; by declar; run;

proc contents data=modele1.ppe; run;
proc contents data=foy_imp; run;

data foy_imp;
	merge	foy_imp (in=a)
			modele2.ppe (keep=ident declar ppef rename=(ppef=ppef_&Nb_Mesures.))
			modele1.impot_sur_rev&anr1. (keep=ident declar impot impot6 rename=(impot=impot_0 impot6=impot6_0))
			modele1.ppe (keep=ident declar ppef rename=(ppef=ppef_0));
	by declar;
	if a and declar ne "";
	impose_hors_ppe_ctf=(impot_0 gt 0);
	impose_yc_ppe_ctf=impot_0-ppef_0 gt 0;
	impose_hors_ppe_&Nb_Mesures.=(impot_&Nb_Mesures. gt 0);
	impose_yc_ppe_&Nb_Mesures.=impot_&Nb_Mesures.-ppef_&Nb_Mesures. gt 0;
	imposable_ctf=(impot6_0 gt 0);
	imposable_&Nb_Mesures.=(impot6_&Nb_Mesures. gt 0);
	ind=1;
	run;

proc means data=foy_imp noprint;
	var ind impos:;
	class decile_c;
	weight poi;
	output out=nb_foy_imposes_ables sum=;
	run;
proc export 
	dbms=&excel_exp. replace 
	data=nb_foy_imposes_ables
	outfile="&sortie_etude_qc_qf";
	sheet="Nb_foy_champ";
	run;


/* 5 décomposition de l'effet de la mesure 1 par type de ménage cotisant 

%macro decomp_cotis(table);
data cotis&table.;
	merge modele&table..cotis sortie_qc_qf (in=a keep=ident poi);
	by ident; if a;
	if pop1='RG' then do;	cotisRGbplaf=COtsRES_bpl; 
							cotisRGbdeplaf=COtsRES_bdepl;
							cotisRGcomp=COtsRES_compl; 
		end;
	if pop1='FPT' then do;	cotisFPTbplaf=COtsRES_bpl; 
							cotisFPTbdeplaf=COtsRES_bdepl;
							cotisFPTcomp=COtsRES_compl; 
		end;
	if pop1='FPNT' then do;	cotisFPNTbplaf=COtsRES_bpl; 
							cotisFPNTbdeplaf=COtsRES_bdepl;
							cotisFPNTcomp=COtsRES_compl; 
		end;
	cotisCH=sum(0,cochre,cochmal);
	cotisRE=coprmal;
	cotisBA=sum(0,cobafa,cobare,cobamal);
	cotisBN=sum(0,cobnfa,cobnre,cobnmal);
	cotisBI=sum(0,cobifa,cobire,cobimal);
	run;
proc means data=cotis&table. noprint;
	var cotis:;
	weight poi;
	output out=totcot&table. sum=;
	run;	
%mend;
%decomp_cotis(0); %decomp_cotis(1);

data totcot; set totcot0 totcot1; run;
proc export 
	dbms=&excel_exp. replace 
	data=totcot
	outfile="&sortie_etude_qc_qf";
	sheet="decomp_cotis";
	run; */


/* 6 Autres sorties complémentaires */

data sorties_complementaires;
	set _null_;
	run;

/* 	Niveau de vie moyen D1 à D9 : CTF */
proc means data=sortie_qc_qfuc noprint;
	var revdisp_0;
	weight poidind;
	where decile_c ne '10';
	output out=s mean=;
	run;
data s; length type $200.; set s; keep type revdisp_0; rename revdisp_0=stat; type="NdV moyen D1-D9 - CTF"; run;
data sorties_complementaires; set sorties_complementaires s; run;

proc means data=sortie_qc_qfuc noprint;
	var revdisp_&Nb_Mesures.;
	weight poidind;
	output out=s mean=;
	where decile_c ne '10'; /* TODO : c'est bien decile_c ? MC répond oui */
	run;
data s; set s; keep type revdisp_&Nb_Mesures.; rename revdisp_&Nb_Mesures.=stat; type="NdV moyen D1-D9 - Leg &anleg."; run;
data sorties_complementaires; set sorties_complementaires s; run;

/* 	Variation relative des prélèvements et prestations par rapport au contrefactuel */

proc sql;
	select 	sum(poi*tot_presta_0),sum(poi*tot_prelev_0)
		into :tot_presta_ctf, :tot_prelev_ctf
		from sortie_qc_qf;
	select 	sum(poi*tot_presta_&Nb_Mesures.),sum(poi*tot_prelev_&Nb_Mesures.)
		into :tot_presta, :tot_prelev
		from sortie_qc_qf;
	quit;
%let evol_presta=%sysevalf(&tot_presta./&tot_presta_ctf. -1);
%let evol_prelev=%sysevalf(&tot_prelev./&tot_prelev_ctf. -1);


data s; set s; stat=&evol_prelev.; type="Variation relative des prélèvements par rapport au contrefactuel"; run;
data sorties_complementaires; set sorties_complementaires s; run;
data s; set s; stat=&evol_presta.; type="Variation relative des prestations par rapport au contrefactuel"; run;
data sorties_complementaires; set sorties_complementaires s; run;


/************** EXPORT DES SORTIES COMPLEMENTAIRES **************/
proc export 
	dbms=&excel_exp. replace 
	data=sorties_complementaires
	outfile="&sortie_etude_qc_qf";
	sheet="Pour_texte";
	run;
