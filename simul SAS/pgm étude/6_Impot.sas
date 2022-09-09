/************************************************************************************/
/*																					*/
/*									6_impot											*/
/*																					*/
/************************************************************************************/

/************************************************************************************/
/* Calcul du montant d'IR					                       					*/
/* En entr�e : 	modele.deduc                            							*/
/* 				modele.nbpart 														*/
/* 				modele.rev_imp&anr1.												*/
/* 				modele.rev_imp&anr.													*/
/* En sortie : 	modele.impot_sur_rev&anr1.                         					*/
/************************************************************************************/
/* PLAN										                     					*/
/*	I. 		Quotient familial et imposition au quotient 							*/
/*	II. 	Taux effectif d'imposition pour les autoentrepreneurs       			*/
/*	III. 	D�cote                     												*/
/*	IV.		Minoration d avant 1993                     							*/
/*	V. 		Cr�dit exceptionnel de 2009                     						*/
/*	IV. 	Cr�dit sur les revenus �trangers imposables en France         			*/
/*	VII. 	Plafonnement des avantages fiscaux                     					*/
/*	VIII. 	Contribution exceptionnelle sur les hauts revenus � partir de 2012    	*/
/*	IX. 	Versements lib�ratoires                     							*/
/*	X. 		Mise en recouvrement                     								*/
/************************************************************************************/
/* REMARQUES

Par souci de simplicit� l impot sur les plus values est calcul� directement dans
le revenu. On peut, pour les cas-types mettre directement l impot (� 0) 
sinon le calcul est assez simple, on pourrait faire un programme � cot�.

Liste des variables n�cessaires :
ZFISF(anciennement RISP), RIPV, nbpart, mcdvo,
personne �levant seul leur enfant et plein d autre info pour connaitre le plafond d avantage 
suite au quotient familial,
8TI (+1AC � 1DC et 1AH � 1DH : revenus exoneres en France mais pris en compte pour le taux effectif

quotient = (tsw1+tsw2)/2+(tsx1+tsx2)/3 + _0xx/4 qui se calcul � partir des �l�ments retard� 
comme lev�e d option  ou revenu exceptionnel ou diff�r�.
mais je crois qu on peut aussi simplement avoir le revenu actualis� (diff�rence entre les
revenus d�clar�s et comment ils vont �tre compt�s : tsw1+tsw2+tsx1+tsx2+_0xx)/quotien
en fait risp = ripv+quotient alors on peut ne garder qu une seule information,
je pr�f�re quotient qui est plus parlant.							
*/


/*Ce programme peut tourner avec calcul_impot = normal pour le calcul de l'imp�t total (que l'on 
	conserve dans les sorties et que l'on compare aux cibles) OU calcul_impot = impot_revdisp pour le calcul
	de l'imp�t HORS revenus exceptionnels et plus-values, qui est celui qui entre dans la d�finition du revenu
	disponible.
	La macrio variable calcul_impot n'est pas d�finie ici mais dans l'encha�nement.
	Avant de commencer le programme, on v�rifie que cette variable a bien �t� d�finie, et on �crit dans la log
	quelle version de l'imp�t va �tre calcul�e*/
%MACRO test_calcul_impot;
	%IF "&calcul_impot." = "normal" %THEN %DO;
		%PUT Execution du programme 6_impotsas pour calcul impot total;
		%END;
	%ELSE %IF "&calcul_impot." = "impot_revdisp" %THEN %DO;
		%PUT Execution du programme 6_impotsas pour calcul impot_revdisp (< impot total);
		%END;
	%ELSE %DO;
		%PUT ERROR: La macro variable &calcul_impot. est mal d�finie;
		%END;
	%MEND;

%test_calcul_impot;


%macro AppliqueBaremeIR(Rev,MontantImpot,TxMarg=txmarg);
	/*	@Rev : revenu � imposer
		@MontantImpot : Montant d'imp�t calcul� par part
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
	if &Rev.>&&plaf&l. then &TxMarg.=&&tx&nbtranche.;
	%mend AppliqueBaremeIR;

%macro Decote(impot);
	/* Cette macro cr�e DECOTE, calcul�e sur le montant d'imp�t pass� en param�tre */
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
	/*article 197 du CGI alinea 6 ou 4 plus r�cemment*/
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

		/* On calcule l'imp�t avec et sans effet du QF et on regarde si la diff�rence d�passe plaf_qf cr�� dans 3_npart */
		rib_QF=		rib/npart;
		rib_ssQF=	rib/(1+(mcdvo in ('M','O')));
		%AppliqueBaremeIR(rib_QF,impot_part,TxMarg=TxMarginal);
		impot1=impot_part*npart;
		label TxMarginal="Taux de la tranche d'imposition avant plafonnement des effets du QF";
		%AppliqueBaremeIR(rib_ssQF,impotssQF);
		impotssQF=impotssQF*(1+(mcdvo in ('M','O')));
		diffImpotQF=max(0,impotssQF-impot1-plaf_qf);
		label diffImpotQF="Ecart d'imp�t avec et sans plafonnement des effets du QF";
		SaturationEffetsQF=(diffImpotQF>0);
		if SaturationEffetsQF then do;
			impot1=impotssQF-plaf_qf-min(diffImpotQF,reduc_qf);
			end;
		label SaturationEffetsQF="Saturation du quotient familial";

		/* Effet d'imposition au quotient */
		/* A. Revenus exceptionnels (coefficient = 4) */
		/* On suppose :
			1) qu'il ne s'agit que de revenus exceptionnels, pas de revenus diff�r�s qui supposeraient des hypoth�ses sur le nombre 
		d'ann�es au titre desquelles ils auraient d� �tre vers�s.
			2) qu'aucun foyer n'opte pour l'�talement de l'imposition, donc ces revenus sont impos�s en une seule fois. Il y a en effet 
		une option d'�talement possible pour les indemnit�s de d�part volontaire en retraite ou de mise � la retraite ou les indemnit�s 
		compensatrices de d�lai-cong� (pr�avis en cas de licenciement). */
		rev_Q4=	sum(rib,quotient4/4)/npart; /* revenus exceptionnels imposables au syst�me du quotient, coef 4 */
		%AppliqueBaremeIR(rev_Q4,impot_part4);
		impot_quot4=impot_part4*npart;
		/* B. Gains de lev�e d'options sur titre (coefficient = 3) */
		rev_Q3=	sum(rib,quotient3/3)/npart; 
		%AppliqueBaremeIR(rev_Q3,impot_part3);
		impot_quot3=impot_part3*npart;
		/* C. Gains de lev�e d'options sur titre (coefficient = 2) */
		rev_Q2=	sum(rib,quotient2/2)/npart; 
		%AppliqueBaremeIR(rev_Q2,impot_part2);
		impot_quot2=impot_part2*npart;
		/* on compare l'impot sur rev_Q4, rev_Q3 et rev_Q2 � l'imp�t calcul� au d�part avant m�me que le plafond du QF ne joue */
		/* On ajoute � l'imp�t total la diff�rence d'imp�t (si elle est positive uniquement) multipli�e par le coefficient */


		
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

		/* Cas des autoentrepreneurs ayant opt� pour le pr�l�vement forfaitaire en N-1 
			Principe du taux effectif (cf commentaire plus d�taill� dans le programme 3_npart (partie B) */
		%if &Appel.=1 %then %do; AE_eliPFL&anr1.=AE_eliPFL&anr2.; %end;
		/* Proxy qui vient du fait que cette variable n'est pas calcul�e pour l'ann�e N-2 (soit anr1 pour le premier appel) */
		if AE_eliPFL&anr1. then do;
			Rib_horsRevAE=max(0,rib-AE_Rev);
			/* on fait ce proxy apr�s avoir v�rifi� qu'il n'�tait pas trop faux sur les concern�s
			mais en r�alit� le Rib d�coule des diverses d�ductions d'imp�t */
			if Rib ne 0 then TxEffectif=impot2/Rib; else TxEffectif=0;
			impot2=TxEffectif*Rib_horsRevAE;
			end;
		/*	Ainsi s'il n'a pas opt� pour le PF l'ann�e pr�c�dente, tous les revenus sont soumis au bar�me
			puisque les revenus d'AE sont inclus dans le Rib */
		
		/****************************
		III. D�cote
		****************************/

		%Decote(impot2);
		impot3=max(impot2-decote,0);

		/*Depuis la d�claration de revenus 2011, tous les gains de cessions de valeurs mobili�res 
		doivent �tre d�clar�s et non seulement ceux au dessus de 25830� comme avant. Ce changement 
		l�gislatif ne change rien dans le programme puisque dans tous les cas nous prenons 
		l information contenue dans la case.*/
		PVP=	 &pvt_tx1.*((_3vg+_3sg+_3sl+_3sb+_3wa+_3wb)/* Taux � 0 � partir d'anleg 2014 car imposition au bar�me
							on inclut les abattements (_3sg et _3sl) car avant 2014 il n'y avait pas d'abattements.
							Les sursis de paiement (_3wa) sont aussi inclus  */
							+_PVCessionDom*(&anleg.<2013)) /* Approximation car taux plus faible pour ce type de plus-value */
					/* Ce taux passe de 19 % � 24 % en 2013 puis ne s'applique plus */
					/*	Abattement (de droit commun + renforc�) pour dur�e de d�tention � partir de 2014
						L'abattement sp�cial pour d�part � la retraite, lui, existe depuis 2007
						Montant hors abattement pour anleg ant�rieures = somme des cases (au sens de la brochure la plus r�cente) */
				+&pvt_tx2.*(_3vi)
				+&pvt_tx3.*(_3vf)
				+&pvt_tx4.*_3vm
				+&pvt_tx5.*(_3vt+_PVCession_entrepreneur) /* taux � 0 avant 2013 */
				+&pvt_tx6.*(_3vd);

		/* Cas de _3vz : PV de cession d'immeubles, impos�es � la source */
		/* Pour cet imp�t sur les plus-values immobili�res, on fait une erreur d'un an dans Ines 
		en incluant en N un pr�l�vement qui a en fait lieu en N-1 dans le calcul du revenu disponible
		(la d�claration est faite par le notaire au moment de la cession).
		On souhaite en effet laisser une imposition de ces revenus dont les montants ne sont pas n�gligeables. 
		En revanche, on ne calcule pas la taxe sur les plus-values �lev�es.*/
		/* R�forme de 2014 sur l'exon�ration totale au-del� de 22 ans de d�tention : 
			non cod�e car on a le montant d�clar� par le notaire */
		PVP=PVP+(_3vz*&pv_imm_tx.);
		label PVP="PVP : Autre imp�t sur les plus-values";

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

		/*minoration : jusqu en l�g 1993, il y avait une minoration de l impot � la fin. */
		%Minoration(impot4);
		impot6=impot5-mino;

		/****************************
		V. Cr�dit exceptionnel de 2009 et r�duction exceptionnelle de 2017
		*****************************/

		credit_exceptionnel_09=0; reduc_exceptionnel_17=0;
		%if &anleg.= 2009 %then %do; 
			/* geste anti-crise, dans la premi�re tranche, on attribut un cr�dit �gal au 2/3 
			de l IR, ensuite, le cr�dit d�croit lin�airement jsuqu � 12475=smic fiscal de la ppe
			Loi Num�ro 2009-431*/
			if rib_QF <= &excep_lim2_r. & _4bc<10700 & RFR/npart < &excep_lim2_r. then do; 
				if rib_QF <= &plaf2.  then credit_exceptionnel_09=&excep_pourcentmax_r.*impot3; 
				else credit_exceptionnel_09=&excep_pourcentmax_r.*(1/&excep_pourcentmax_r.*&tx2.*(&plaf2.-&plaf1.)*npart-&decote.)
										/*=impot au changement de tranche*/
											*((&excep_lim2_r.-rib_QF)/(&excep_lim2_r.-&plaf2.));  
				end;
			%end;
		%if &anleg.=2017 %then %do; /*r�duction exceptionnelle 2017 : article 2 de la LOI n� 2016-1917 LFI 2017 (https://www.legifrance.gouv.fr/eli/loi/2016/12/29/ECFX1623958L/jo) */
			seuil1=&excep_lim1_r.*(1 +(mcdvo in ('M','O')))+&excep_lim3_r.*(npart-(1 +(mcdvo in ('M','O'))));
			seuil2=&excep_lim2_r.*(1 +(mcdvo in ('M','O')))+&excep_lim3_r.*(npart-(1 +(mcdvo in ('M','O'))));
			if RFR<seuil1 then reduc_exceptionnel_17=&excep_pourcentmax_r.*impot3;
			else if RFR<seuil2 then reduc_exceptionnel_17=&excep_pourcentmax_r.*impot3*(seuil2-RFR)/(2000*(1 +(mcdvo in ('M','O')))); /* Calcul diff�rentiel */
			drop seuil1 seuil2;
			%end;

		impot7=impot6-credit-credit_exceptionnel_09-reduc_exceptionnel_17;

		/****************************
		VI. Cr�dit sur les revenus �trangers imposables en France
		*****************************/

		/*Ces revenus deja inclus dans les cases precedentes ouvrent droit a un cr�dit d imp�t 
		repr�sentant le montant de l imp�t francais (d apres la convention internationale)*/
		/*ne connaissant pas la nature de ces revenus et les charges deductibles, on applique 10% 
		par defaut comme pour des salaires*/

		cred_etr=0;
		if _8tk>0 & RnG >0 then cred_etr=(0.9*_8tk/RnG)*impot6;
		impot7=impot7-cred_etr;


		/*******************************************/
		/* VII.	Plafonnement des avantages fiscaux */
		/*******************************************/
		
		/* Suivre calcul en bas de la page 263 de la brochure pratique 2013/2014 */
		/* AvantageTotal_APlafonner : tous les avantages sauf Malraux et la liste des CI et RI  � l'article 200-0 A: 2b. */
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
		/* A partir 2014, l'existence d'un plafonnement major� (de 8000�) pour investissements en outremer et Sofica 
		introduit un calcul emboit� d�crit dans la brochure pratique. Le calcul reste juste pour les ann�es ant�rieures. */
		excedant_plafglobal1=	max(AvantageTotal_APlafonner-RED_Sofica-RED_pinel_dom*(&anleg.>=2016)-(&plaf_global_m.+&plaf_global_t.*RNG),0);
		excedant_plafglobal2= 	max(AvantageTotal_APlafonner-excedant_plafglobal1-(&plaf_global_m.+&plaf_global_m2.+&plaf_global_t.*RNG),0);
		label 	excedant_plafglobal1="Exc�dant d'avantages fiscaux apr�s application du 1er plafonnement"
				excedant_plafglobal2="Exc�dant d'avantages fiscaux apr�s application du 2e plafonnement";

		/* Indicatrice */
		plaf_av_fisc=(excedant_plafglobal1+excedant_plafglobal2>0);
		label plaf_av_fisc="Plafonnement des avantages fiscaux";

		if plaf_av_fisc then	impot8=impot7+excedant_plafglobal1+excedant_plafglobal2; 
		else 					impot8=impot7;
		/* Ecart � la l�gislation : la fraction de la RI qui exc�de le plafond peut �tre report�e sur les 5 ann�es suivantes */

		/****************************
		VIII. Contribution exceptionnelle sur les hauts revenus � partir de 2012
		*****************************/
		%Init_Valeur(CEHR);
		%if &anleg.>=2012 %then %do;
			if &CEHRplaf1.*(1+(mcdvo in ('M','O')))<RFR
				then CEHR=(min(RFR,&CEHRplaf2.*(1+(mcdvo in ('M','O'))))-&CEHRplaf1.*(1+(mcdvo in ('M','O'))))*&CEHRtx1.;
			if &CEHRplaf2.*(1+(mcdvo in ('M','O')))<RFR 
				then CEHR=sum(0,CEHR,(RFR-&CEHRplaf2.*(1+(mcdvo in ('M','O'))))*&CEHRtx2.);	
			%end;

		/***************************
		IX. Pr�l�vements lib�ratoires
		*****************************/
		impot9=impot8
				+CEHR
				+ &prel_lib_t2.*sum(0,_1at,_1bt)*(1-&abat10_bis.)
				/*Prestations de retraite vers�es sous forme de capital, 
				soumises � un pr�l�vement lib�ratoire de l'imp�t sur le revenu � partir de 2011 (CGI art 163 bis II) */
				+ _4bh /* taxe sur les loyers �lev�s des logements de petite surface */;

		/***************************
		X. Mise en recouvrement
		*****************************/
		impot = impot9;
		if 0<impot9<&recouv. then impot=0;

		drop txmarg;

		run;

	/*Dans le cas o� on a calcul� l'imp�t pour le revenu disponible (calcul_impot = impot_revdisp), on 
		rajoute � la fin la variable dans la table modele.impot_sur_rev&anr1.*/
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
