/************************************************************************************/
/*																					*/
/*									6_impot											*/
/*																					*/
/************************************************************************************/

/************************************************************************************/
/* Calcul du montant d'IR					                       					*/
/* En entrée : 	modele.deduc                            							*/
/* 				modele.nbpart 														*/
/* 				modele.rev_imp&anr1.												*/
/* 				modele.rev_imp&anr.													*/
/* En sortie : 	modele.impot_sur_rev&anr1.                         					*/
/************************************************************************************/
/* PLAN										                     					*/
/*	I. 		Quotient familial et imposition au quotient 							*/
/*	II. 	Taux effectif d'imposition pour les autoentrepreneurs       			*/
/*	III. 	Décote                     												*/
/*	IV.		Minoration d avant 1993                     							*/
/*	V. 		Crédit exceptionnel de 2009                     						*/
/*	IV. 	Crédit sur les revenus étrangers imposables en France         			*/
/*	VII. 	Plafonnement des avantages fiscaux                     					*/
/*	VIII. 	Contribution exceptionnelle sur les hauts revenus à partir de 2012    	*/
/*	IX. 	Versements libératoires                     							*/
/*	X. 		Mise en recouvrement                     								*/
/************************************************************************************/
/* REMARQUES

Par souci de simplicité l impot sur les plus values est calculé directement dans
le revenu. On peut, pour les cas-types mettre directement l impot (à 0) 
sinon le calcul est assez simple, on pourrait faire un programme à coté.

Liste des variables nécessaires :
ZFISF(anciennement RISP), RIPV, nbpart, mcdvo,
personne élevant seul leur enfant et plein d autre info pour connaitre le plafond d avantage 
suite au quotient familial,
8TI (+1AC à 1DC et 1AH à 1DH : revenus exoneres en France mais pris en compte pour le taux effectif

quotient = (tsw1+tsw2)/2+(tsx1+tsx2)/3 + _0xx/4 qui se calcul à partir des éléments retardé 
comme levée d option  ou revenu exceptionnel ou différé.
mais je crois qu on peut aussi simplement avoir le revenu actualisé (différence entre les
revenus déclarés et comment ils vont être comptés : tsw1+tsw2+tsx1+tsx2+_0xx)/quotien
en fait risp = ripv+quotient alors on peut ne garder qu une seule information,
je préfère quotient qui est plus parlant.							
*/


/*Ce programme peut tourner avec calcul_impot = normal pour le calcul de l'impôt total (que l'on 
	conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
	de l'impôt HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la définition du revenu
	disponible.
	La macrio variable calcul_impot n'est pas définie ici mais dans l'enchaînement.
	Avant de commencer le programme, on vérifie que cette variable a bien été définie, et on écrit dans la log
	quelle version de l'impôt va être calculée*/
%MACRO test_calcul_impot;
	%IF "&calcul_impot." = "normal" %THEN %DO;
		%PUT Execution du programme 6_impotsas pour calcul impot total;
		%END;
	%ELSE %IF "&calcul_impot." = "impot_revdisp" %THEN %DO;
		%PUT Execution du programme 6_impotsas pour calcul impot_revdisp (< impot total);
		%END;
	%ELSE %DO;
		%PUT ERROR: La macro variable &calcul_impot. est mal définie;
		%END;
	%MEND;

%test_calcul_impot;


%macro AppliqueBaremeIR(Rev,MontantImpot,TxMarg=txmarg);
	/*	@Rev : revenu à imposer
		@MontantImpot : Montant d'impôt calculé par part
		@TxMarg : valeur du taux de la bonne tranche d'imposition */
	&MontantImpot.=0;
	&TxMarg.=0;
	%do i=2 %to %eval(&nbtranche.-1);
		%let j = %eval(&i.-1);
		&MontantImpot.=&MontantImpot.+&&tx&i.*max(min(&Rev.-&&plaf&j.,&&plaf&i.-&&plaf&j.),0);
		if &Rev.>&&plaf&j. then &TxMarg.=&&tx&i.;
		%end;
	%let l=%eval(&nbtranche.-1);
	&MontantImpot.=&MontantImpot.+&&tx&nbtranche.*max((&Rev.-&&plaf&l.),0);
	%mend AppliqueBaremeIR;

%macro Decote(impot);
	/* Cette macro crée DECOTE, calculée sur le montant d'impôt passé en paramètre */
	decote=0;
	%if &anleg.>=2016 %then %do;
		if mcdvo in ('C','D', 'V') & &impot.<&decote. 	then decote=3/4*(&decote.-&impot.);
		if mcdvo in ('M','O')  & &impot.<&decote_couple. 	then decote=3/4*(&decote_couple.-&impot.);
		%end; 
	%if &anleg.=2015 %then %do;
		if mcdvo in ('C','D', 'V') & &impot.<&decote. 	then decote=&decote.-&impot.;
		if mcdvo in ('M','O')  & &impot.<&decote_couple. 	then decote=&decote_couple.-&impot.;
		%end; 
	%if 2001<=&anleg. & &anleg.<2015 %then %do;
		if &impot. <= 2*&decote. then decote=&decote.-&impot./2;
		%end; 
	%if 1986<=&anleg. & &anleg.<2001 %then %do;
		if &impot. <= &decote. then decote=&decote.-&impot.;
		%end;
	%if &anleg.<1986 %then %do;
		if npart = 1 & &impot.<&decote. 	then decote=&decote.-&impot.;
		if npart = 1.5 & &impot.<&decote2. 	then do;
			decote=&decote2.-&impot.;
			end;
		%end;
	decote=min(decote,&impot.);
	%mend Decote;

%macro Minoration(impot); 
	/*article 197 du CGI alinea 6 ou 4 plus récemment*/
	mino=0;
	if &impot. < &minoplaf1. 							then mino=&minotx1.*&impot.;
	if &minoplaf1. <= &impot. and &impot. < &minoplaf2. then mino=&minocalc2.-&minotx.*&impot.;
	if &minoplaf2. <= &impot. and &impot. < &minoplaf3. then mino=&minotx3.*&impot.;
	if &minoplaf3. <= &impot. and &impot. < &minoplaf4. then mino=&minocalc4.-&minotx.*&impot.;
	if &minoplaf4. <= &impot. and &impot. < &minoplaf5. then mino=&minotx5.*&impot.;
	%mend Minoration;

proc sort data=modele.deduc; by declar; run;
proc sort data=modele.nbpart; by declar; run;
proc sort data=modele.rev_imp&anr1.; by declar; run;

%macro Impot;

	%IF "&calcul_impot." = "normal" %THEN %DO;
		DATA modele.impot_sur_rev&anr1.;
		%END;
	%ELSE %IF "&calcul_impot." = "impot_revdisp" %THEN %DO;
		DATA temp_impot_rev&anr1._revdisp;
		%END;

		merge 	modele.nbpart	(keep=declar mcdvo npart plaf_qf reduc_qf)
				modele.deduc	(keep=declar deduc_av_decote deduc_ap_decote credit red: cred:)
				modele.rev_imp&anr1.(keep=	declar ident rbg rng rib
											quotient: _3: PVT _PVCessionDom _PVCession_entrepreneur _8tk _4by _4bh _4bc RFR _1at _1bt)
				modele.rev_imp&anr. (keep=	AE: declar);
		by declar;

		/****************************
		I. Quotient familial
		*****************************/

		/* On calcule l'impôt avec et sans effet du QF et on regarde si la différence dépasse plaf_qf créé dans 3_npart */
		rib_QF=		rib/npart;
		rib_ssQF=	rib/(1+(mcdvo in ('M','O')));
		%AppliqueBaremeIR(rib_QF,impot_part,TxMarg=TxMarginal);
		impot1=impot_part*npart;
		label TxMarginal="Taux de la tranche d'imposition avant plafonnement des effets du QF";
		%AppliqueBaremeIR(rib_ssQF,impotssQF);
		impotssQF=impotssQF*(1+(mcdvo in ('M','O')));
		diffImpotQF=max(0,impotssQF-impot1-plaf_qf);
		label diffImpotQF="Ecart d'impôt avec et sans plafonnement des effets du QF";
		SaturationEffetsQF=(diffImpotQF>0);
		if SaturationEffetsQF then do;
			impot1=impotssQF-plaf_qf-min(diffImpotQF,reduc_qf);
			end;
		label SaturationEffetsQF="Saturation du quotient familial";

		/* Effet d'imposition au quotient */
		/* A. Revenus exceptionnels (coefficient = 4) */
		/* On suppose :
			1) qu'il ne s'agit que de revenus exceptionnels, pas de revenus différés qui supposeraient des hypothèses sur le nombre 
		d'années au titre desquelles ils auraient dû être versés.
			2) qu'aucun foyer n'opte pour l'étalement de l'imposition, donc ces revenus sont imposés en une seule fois. Il y a en effet 
		une option d'étalement possible pour les indemnités de départ volontaire en retraite ou de mise à la retraite ou les indemnités 
		compensatrices de délai-congé (préavis en cas de licenciement). */
		rev_Q4=	sum(rib,quotient4/4)/npart; /* revenus exceptionnels imposables au système du quotient, coef 4 */
		%AppliqueBaremeIR(rev_Q4,impot_part4);
		impot_quot4=impot_part4*npart;
		/* B. Gains de levée d'options sur titre (coefficient = 3) */
		rev_Q3=	sum(rib,quotient3/3)/npart; 
		%AppliqueBaremeIR(rev_Q3,impot_part3);
		impot_quot3=impot_part3*npart;
		/* C. Gains de levée d'options sur titre (coefficient = 2) */
		rev_Q2=	sum(rib,quotient2/2)/npart; 
		%AppliqueBaremeIR(rev_Q2,impot_part2);
		impot_quot2=impot_part2*npart;
		/* on compare l'impot sur rev_Q4, rev_Q3 et rev_Q2 à l'impôt calculé au départ avant même que le plafond du QF ne joue */
		/* On ajoute à l'impôt total la différence d'impôt (si elle est positive uniquement) multipliée par le coefficient */


		
		%IF "&calcul_impot." = "normal" %THEN %DO;
			impot2=impot1-deduc_av_decote
					+max(0,impot_quot4-impot_part*npart)*4 
					+max(0,impot_quot3-impot_part*npart)*3 
					+max(0,impot_quot2-impot_part*npart)*2;
			%END;
		%ELSE %IF "&calcul_impot." = "impot_revdisp" %THEN %DO;
			impot2=impot1-deduc_av_decote
					/*+max(0,impot_quot4-impot_part*npart)*4 
					+max(0,impot_quot3-impot_part*npart)*3 
					+max(0,impot_quot2-impot_part*npart)*2*/;
			%END;

		/****************************
		II. Taux effectif d'imposition pour les autoentrepreneurs
		*****************************/

		/* Cas des autoentrepreneurs ayant opté pour le prélévement forfaitaire en N-1 
			Principe du taux effectif (cf commentaire plus détaillé dans le programme 3_npart (partie B) */
		%if &Appel.=1 %then %do; AE_eliPFL&anr1.=AE_eliPFL&anr2.; %end;
		/* Proxy qui vient du fait que cette variable n'est pas calculée pour l'année N-2 (soit anr1 pour le premier appel) */
		if AE_eliPFL&anr1. then do;
			Rib_horsRevAE=max(0,rib-AE_Rev);
			/* on fait ce proxy après avoir vérifié qu'il n'était pas trop faux sur les concernés
			mais en réalité le Rib découle des diverses déductions d'impôt */
			if Rib ne 0 then TxEffectif=impot2/Rib; else TxEffectif=0;
			impot2=TxEffectif*Rib_horsRevAE;
			end;
		/*	Ainsi s'il n'a pas opté pour le PF l'année précédente, tous les revenus sont soumis au barème
			puisque les revenus d'AE sont inclus dans le Rib */
		
		/****************************
		III. Décote
		****************************/

		%Decote(impot2);
		impot3=max(impot2-decote,0);

		/*Depuis la déclaration de revenus 2011, tous les gains de cessions de valeurs mobilières 
		doivent être déclarés et non seulement ceux au dessus de 25830€ comme avant. Ce changement 
		législatif ne change rien dans le programme puisque dans tous les cas nous prenons 
		l information contenue dans la case.*/
		PVP=	 &pvt_tx1.*((_3vg+_3sg+_3sl+_3sb+_3wa+_3wb)/* Taux à 0 à partir d'anleg 2014 car imposition au barême
							on inclut les abattements (_3sg et _3sl) car avant 2014 il n'y avait pas d'abattements.
							Les sursis de paiement (_3wa) sont aussi inclus  */
							+_PVCessionDom*(&anleg.<2013)) /* Approximation car taux plus faible pour ce type de plus-value */
					/* Ce taux passe de 19 % à 24 % en 2013 puis ne s'applique plus */
					/*	Abattement (de droit commun + renforcé) pour durée de détention à partir de 2014
						L'abattement spécial pour départ à la retraite, lui, existe depuis 2007
						Montant hors abattement pour anleg antérieures = somme des cases (au sens de la brochure la plus récente) */
				+&pvt_tx2.*(_3vi)
				+&pvt_tx3.*(_3vf)
				+&pvt_tx4.*_3vm
				+&pvt_tx5.*(_3vt+_PVCession_entrepreneur) /* taux à 0 avant 2013 */
				+&pvt_tx6.*(_3vd);

		/* Cas de _3vz : PV de cession d'immeubles, imposées à la source */
		/* Pour cet impôt sur les plus-values immobilières, on fait une erreur d'un an dans Ines 
		en incluant en N un prélèvement qui a en fait lieu en N-1 dans le calcul du revenu disponible
		(la déclaration est faite par le notaire au moment de la cession).
		On souhaite en effet laisser une imposition de ces revenus dont les montants ne sont pas négligeables. 
		En revanche, on ne calcule pas la taxe sur les plus-values élevées.*/
		/* Réforme de 2014 sur l'exonération totale au-delà de 22 ans de détention : 
			non codée car on a le montant déclaré par le notaire */
		PVP=PVP+(_3vz*&pv_imm_tx.);
		label PVP="PVP : Autre impôt sur les plus-values";

		%IF "&calcul_impot." = "normal" %THEN %DO;
			impot4=sum(0,impot3,PVP,PVT);
			%END;
		%ELSE %IF "&calcul_impot." = "impot_revdisp" %THEN %DO;
			impot4=sum(0,impot3/*,PVP,PVT*/);
			%END;
		impot5=max(impot4-deduc_ap_decote,0);

		/****************************
		IV. Minoration d avant 1993
		*****************************/

		/*minoration : jusqu en lég 1993, il y avait une minoration de l impot à la fin. */
		%Minoration(impot4);
		impot6=impot5-mino;

		/****************************
		V. Crédit exceptionnel de 2009 et réduction exceptionnelle de 2017
		*****************************/

		credit_exceptionnel_09=0; reduc_exceptionnel_17=0;
		%if &anleg.= 2009 %then %do; 
			/* geste anti-crise, dans la première tranche, on attribut un crédit égal au 2/3 
			de l IR, ensuite, le crédit décroit linéairement jsuqu à 12475=smic fiscal de la ppe
			Loi Numéro 2009-431*/
			if rib_QF <= &excep_lim2_r. & _4bc<10700 & RFR/npart < &excep_lim2_r. then do; 
				if rib_QF <= &plaf2.  then credit_exceptionnel_09=&excep_pourcentmax_r.*impot3; 
				else credit_exceptionnel_09=&excep_pourcentmax_r.*(1/&excep_pourcentmax_r.*&tx2.*(&plaf2.-&plaf1.)*npart-&decote.)
										/*=impot au changement de tranche*/
											*((&excep_lim2_r.-rib_QF)/(&excep_lim2_r.-&plaf2.));  
				end;
			%end;
		%if &anleg.=2017 %then %do; /*réduction exceptionnelle 2017 : article 2 de la LOI n° 2016-1917 LFI 2017 (https://www.legifrance.gouv.fr/eli/loi/2016/12/29/ECFX1623958L/jo) */
			seuil1=&excep_lim1_r.*(1 +(mcdvo in ('M','O')))+&excep_lim3_r.*(npart-(1 +(mcdvo in ('M','O'))));
			seuil2=&excep_lim2_r.*(1 +(mcdvo in ('M','O')))+&excep_lim3_r.*(npart-(1 +(mcdvo in ('M','O'))));
			if RFR<seuil1 then reduc_exceptionnel_17=&excep_pourcentmax_r.*impot3;
			else if RFR<seuil2 then reduc_exceptionnel_17=&excep_pourcentmax_r.*impot3*(seuil2-RFR)/(2000*(1 +(mcdvo in ('M','O')))); /* Calcul différentiel */
			drop seuil1 seuil2;
			%end;

		impot7=max(0,impot6-reduc_exceptionnel_17)-credit-credit_exceptionnel_09;

		/****************************
		VI. Crédit sur les revenus étrangers imposables en France
		*****************************/

		/*Ces revenus deja inclus dans les cases precedentes ouvrent droit a un crédit d impôt 
		représentant le montant de l impôt francais (d apres la convention internationale)*/
		/*ne connaissant pas la nature de ces revenus et les charges deductibles, on applique 10% 
		par defaut comme pour des salaires*/

		cred_etr=0;
		if _8tk>0 & RnG >0 then cred_etr=(0.9*_8tk/RnG)*impot6;
		impot7=impot7-cred_etr;


		/*******************************************/
		/* VII.	Plafonnement des avantages fiscaux */
		/*******************************************/
		
		/* Suivre calcul en bas de la page 263 de la brochure pratique 2013/2014 */
		/* AvantageTotal_APlafonner : tous les avantages sauf Malraux et la liste des CI et RI  à l'article 200-0 A: 2b. */
		Avantages_HorsPlafond= 	RED_Malraux
								+RED_excep 
								+RED_dons1
								+RED_dons2
								+RED_mecenat
								+RED_enfants_ecole 
								+RED_syndic
								+RED_long_sejour
								+RED_compta_gestion 
								+RED_presta_compens 
								+RED_rente_survie
								+RED_foret_incendie
								+RED_biencult
								+CRED_syndic 
								+CRED_conge_agri 
								+CRED_persages
								+CRED_PFO ;
		AvantageTotal_APlafonner=credit+deduc_ap_decote-Avantages_HorsPlafond;
		/* A partir 2014, l'existence d'un plafonnement majoré (de 8000€) pour investissements en outremer et Sofica 
		introduit un calcul emboité décrit dans la brochure pratique. Le calcul reste juste pour les années antérieures. */
		excedant_plafglobal1=	max(AvantageTotal_APlafonner-RED_Sofica-RED_pinel_dom*(&anleg.>=2016)-(&plaf_global_m.+&plaf_global_t.*RNG),0);
		excedant_plafglobal2= 	max(AvantageTotal_APlafonner-excedant_plafglobal1-(&plaf_global_m.+&plaf_global_m2.+&plaf_global_t.*RNG),0);
		label 	excedant_plafglobal1="Excédant d'avantages fiscaux après application du 1er plafonnement"
				excedant_plafglobal2="Excédant d'avantages fiscaux après application du 2e plafonnement";

		/* Indicatrice */
		plaf_av_fisc=(excedant_plafglobal1+excedant_plafglobal2>0);
		label plaf_av_fisc="Plafonnement des avantages fiscaux";

		if plaf_av_fisc then	impot8=impot7+excedant_plafglobal1+excedant_plafglobal2; 
		else 					impot8=impot7;
		/* Ecart à la législation : la fraction de la RI qui excède le plafond peut être reportée sur les 5 années suivantes */

		/****************************
		VIII. Contribution exceptionnelle sur les hauts revenus à partir de 2012
		*****************************/
		%Init_Valeur(CEHR);
		%if &anleg.>=2012 %then %do;
			if &CEHRplaf1.*(1+(mcdvo in ('M','O')))<RFR
				then CEHR=(min(RFR,&CEHRplaf2.*(1+(mcdvo in ('M','O'))))-&CEHRplaf1.*(1+(mcdvo in ('M','O'))))*&CEHRtx1.;
			if &CEHRplaf2.*(1+(mcdvo in ('M','O')))<RFR 
				then CEHR=sum(0,CEHR,(RFR-&CEHRplaf2.*(1+(mcdvo in ('M','O'))))*&CEHRtx2.);	
			%end;

		/***************************
		IX. Prélèvements libératoires
		*****************************/
		impot9=impot8
				+CEHR
				+ &prel_lib_t2.*sum(0,_1at,_1bt)*(1-&abat10_bis.)
				/*Prestations de retraite versées sous forme de capital, 
				soumises à un prélèvement libératoire de l'impôt sur le revenu à partir de 2011 (CGI art 163 bis II) */
				+ _4bh /* taxe sur les loyers élevés des logements de petite surface */;

		/***************************
		X. Mise en recouvrement
		*****************************/
		impot = impot9;
		if 0<impot9<&recouv. then impot=0;

		drop txmarg;

		run;

	/*Dans le cas où on a calculé l'impôt pour le revenu disponible (calcul_impot = impot_revdisp), on 
		rajoute à la fin la variable dans la table modele.impot_sur_rev&anr1.*/
	%IF "&calcul_impot." = "impot_revdisp" %THEN %DO;
		PROC SQL;
			CREATE TABLE modele.impot_sur_rev&anr1. AS
			SELECT a.*, b.impot AS impot_revdisp
			FROM modele.impot_sur_rev&anr1. AS a LEFT JOIN temp_impot_rev&anr1._revdisp AS b
			ON a.declar = b.declar;
			QUIT;

		/*On supprime la table temp_impot_rev&anr1._revdisp*/
		PROC DATASETS LIB = work MEMTYPE = DATA;
			DELETE temp_impot_rev&anr1._revdisp;
			QUIT;

		%END;

	%mend;
%Impot;


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
