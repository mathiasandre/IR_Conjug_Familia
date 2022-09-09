/************************************************************************************/
/*																					*/
/*								2_cotisations										*/
/*																					*/
/************************************************************************************/
/*																					*/
/* Calcul des prélèvements sociaux obligatoires assis sur les revenus du travail.	*/
/* + autres prélèvements (taxe sur les salaires, taxe à 75%) et subventions (CICE)	*/
/* payés par l'entreprises mais assis sur la masse salairiale						*/
/* Calcul du supplément familial de traitement pour les fonctionnaires.				*/
/************************************************************************************/
/* En entrée : 	modele.baseind														*/
/*				base.baserev														*/
/*				base.baseind														*/
/*				modele.impot_sur_rev&anr.											*/
/* En sortie :  modele.cotis														*/
/************************************************************************************/
/*	PLAN :																			*/
/*	I.	Traitements préalables														*/
/*	II.	Salariés																	*/
/*		1	Taux de cotisations														*/
/*		2 	Supplément familial de traitement										*/
/*		3	Des plafonds bruts au plafonds "équivalent déclaré"						*/
/*		4	Calcul du salaire brut													*/
/*		5 	Calcul des cotisations à proprement parler								*/
/*		6   Arrêts maladie															*/
/*		7	Exonérations du régime général											*/
/*			7.1	Exo heures sup' sur cotisations salariales							*/
/*			7.2	Exo heures sup' sur cotisations patronales							*/
/*			7.3	Exo bas salaires													*/
/*			7.4	CICE																*/
/*			7.5 Apprentis															*/
/*		8 Taxe sur les salaires														*/
/*		9 Regroupement des cotisations												*/
/*	III.Chômeurs et preretraités													*/
/*	IV.	Retraités																	*/
/*	V.	Travailleurs indépendants : régime micro-social (micro-entrepreneurs)		*/
/*	VI.	BNC	(hors micro-social)														*/
/*	VII.BIC (hors micro-social)														*/
/*	VIII. BA																		*/
/*	IX.	Traitements finaux 															*/
/************************************************************************************/

%global smichnet smic_brut;
/* Moyenne annuelle du SMIC horaire net de l'année n */
%let smichnet=%sysevalf(&smich.*(1-(&tcomaRG_S.+&tcoviRG_deplaf_S.+&tcoviRG_plaf_S.+&tcoasRG_S.+&tcoarRG1_S.+&Tcsgd.)));
/* Moyenne annuelle du SMIC brut mensuel de l'année n */
%let smic_brut =%sysevalf(&smich.*&tpstra.*52/12);


/************************************************************************************/
/*	I.	Traitements préalables														*/
/************************************************************************************/

%Macro Cotis_Prepa;

	/* 1	Repérage de qui est non imposable sur le revenu (dernière déclaration si plusieurs dans l'année)
	et qui est non taxable d'habitation */

	proc sort data=base.baseind(keep=declar1 ident noi naia quelfic acteu6 naia cal0) out=baseind; by declar1; run;
	proc sort data=modele.impot_sur_rev&anr.(keep=declar impot6 npart RFR rename=(declar=declar1 impot6=impot)) out=impot; by declar1; run;
	/*La condition d'exonération de TH s'applique à une RFR sur l'année précédente alors que la condition d'exonération de CSG pour revenus
	 de remplacement s'applique au RFR sur l'avant dernière année, donc on fait la manip suivante pour prendre les paramétres décalés
	cf http://bofip.impots.gouv.fr/bofip/5738-PGP.html pour TH et https://www.service-public.fr/particuliers/vosdroits/F2971 */
	%CreeParametreRetarde(th_lim2_lag1,dossier.th,th_lim2,Ines,&anleg.,1);
	%CreeParametreRetarde(th_lim2_pac_lag1,dossier.th,th_lim2_pac,Ines,&anleg.,1);
	%CreeParametreRetarde(seuilcofaredRGP_lag1,dossier.Param_soc,seuilcofaredRGP,Ines,&anleg.,1);/*réforme en avril 2016 : modification de taux*/
	data impot_ind;
		merge	baseind(in=a)
				impot; 
		by declar1;
		if a;
		label pth="Sous seuil d'exonération de TH"; /* Indicatrice */ /*attention lié au RFR de N-2 car on s'en sert pour l'exo de CSG donc différent de l'exo de TH, cf. commentaire ci dessus */
		pth=0;
		%if &anleg.>1998 %then %do; /* Art 136-8 du CSS */
			if RFR<&th_lim2_lag1.*(npart>0)+&th_lim2_pac_lag1.*2*max(0,npart-1) then pth=1;
			%end;
		label pir="Sous seuil d'exonération de l'IR";
		pir=(impot<&p0960.);
		label reduc_csg="condition pour le taux réduit de CSG sur les revenus de remplacement"; /*la condition change en 2015*/
		reduc_csg=(&anleg.<2015)*pir + (&anleg.>=2015)*(RFR<&plaf_csg_remp.*(npart>0)+&plaf_csg_remp_pac.*4*max(0,npart-1));
		label exo_csg="condition pour l'exonération de CSG sur les revenus de remplacement"; /*la condition change en 2015*/
		exo_csg=(&anleg.<2015)*pth + (&anleg.>=2015)*(RFR<&exo_csg_remp.*(npart>0)+&exo_csg_remp_pac.*4*max(0,npart-1));
		if quelfic='EE_NRT' then do;/* Exonération par défaut des EE_NRT */
			pir=1;
			pth=1;
			end;
		run;

	/* 2	Récupération du chiffre d'affaires de l'année en cours pour les indépendants soumis au régime micro-fiscal */
	/* (les agrégats zrnci, zrici et zragi issus de l'ERFS représentent les revenus professionnels (bénéfices), après abattement pour charges si micro-fiscal ;
		ils correspondent bien à l'assiette des cotisations pour les non-salariés "classiques" ;
		mais ce n'est pas la bonne assiette pour les auto-entrepreneurs, pour lesquels des taux forfaitaires sont appliqués directement au CA.) 
		Note : le régime micro-social ne concerne pas les exploitants agricoles */

	proc sql;
		create table CAmicro_ind as
			select ident,noi,
				case 	when a.persfip='vous' then (_5ko+_5ta)
						when a.persfip='conj' then 	(_5lo+_5ua)
						when a.persfip='pac' then 	(_5mo+_5va)
						else 0 end as CAbicventi&anr2.,
				case	when a.persfip='vous' then 	(_5kp+_5tb)
						when a.persfip='conj' then 	(_5lp+_5ub)
						when a.persfip='pac' then 	(_5mp+_5vb)
						else 0 end as CAbicservi&anr2.,
				case 	when a.persfip='vous' then 	(_5hq+_5te)
						when a.persfip='conj' then 	(_5iq+_5ue)
						when a.persfip='pac' then 	(_5jq+_5ve)
						else 0 end as CAbnci&anr2.
			from base.baseind (keep=ident noi declar1 persfip) as a 
			inner join base.foyer&anr2.(keep=declar zricf zrncf &cbncf_. &cbicf_.) as b
			on a.declar1=b.declar 
			order by ident, noi;
		quit;

	/* 3	Modification des informations sur l'activité pour certains cas spéciaux */
	proc sort data=impot_ind 
		(keep=ident noi impot pth pir reduc_csg exo_csg acteu6 naia cal0) 
		out=impot_ind nodupkey; by ident noi; run; /* On retire d'éventuels doublons de baseind */
	proc sort data=modele.baseind
		(keep=ident noi champ_cotis hsup&anr2. p statut csa effi pub3fp temps hor cst2 NbEnf_SFT 
			contractuel emploi_particulier cotis_special nbmois_sal nbmois_cho nafg088un echpub cal0) 
		out=prof; by ident noi; run;
	proc sort data=base.baserev 
		(keep=ident noi zsali&anr2. zchoi&anr2. zrsti&anr2. zrici&anr2. zrnci&anr2. zrici&anr1. zrnci&anr1. zragi&anr1.
			zchoi&anr. part_salar&anr2. part_employ&anr2. montant_ass) 
		out=baserev; by ident noi; run;

	data prof; 
		merge	prof
				baserev	
				impot_ind
				CAmicro_ind (in=b); 
		by ident noi;
		if champ_cotis=1;
		if not b then do;
			CAbicventi&anr2.=0;
			CAbicservi&anr2.=0;
			CAbnci&anr2.=0;
			end;
		/* Indicatrice de micro-entrepreneur ; on assimile micro-fiscal à micro-social à partir de 2016 */
		MicEnt=(&anleg.>=2016)*(CAbicventi&anr2.+CAbicservi&anr2.+CAbnci&anr2.>0) ;
		run;
	%Mend Cotis_Prepa;
%Cotis_Prepa;


/************************************************************************************/
/*	II.	Salariés																	*/
/************************************************************************************/

%Macro Cotis_Salaries;
	data Salaries (keep=ident noi zsalbrut COtsCHs COtsCHp COtsAGSp COtsREs COtsREp COtsFA
			 	COtsMAL_SAL COtsMAL_PAT ContribExcSol COtsTAXp COtsACP COtsS COtsP CSGtsD CSGtsI CSGts_MAL CRDSts
				exo exo_BasSal exo_heursup exo_app sftba sftna: pop1 COtsRES_bpl COtsRES_bdepl COtsRES_compl CICE taxe_salaire taxe_75);
		set prof (where=(zsali&anr2.-hsup&anr2.>1));
		/* Il arrive que des déclarations ne mentionnent que des heures sup et pas de salaire de base,
		ce qui est possible dans la mesure d'un retard de paye de l'employeur. Dans ce cas, on ne veut pas calculer les cotisations salariales. */

		if nbmois_sal=0 then nbmois_sal=12; /* Lissage sur les 12 mois en cas d'absence d'information plus précise. C'est 
		cohérent avec la trimestrialisation des ressources.*/

		/************************************************************************************************************/
		/* Variables intermédiaires : définition des différentes sous-populations 									*/
		/* On définit 	- un premier niveau (pop1) : FPT, FPNT ou RG												*/
		/*				- un deuxième niveau pour la FPT (pop2) : collectivités territoriales ou hôpital, ou non	*/
		/*				- un troisième niveau pour FPT et FPNT (pop3) : en fonction de la qualification 			*/
		/************************************************************************************************************/
		length pop1 $4. pop2 $3. pop3 $2. pop $7.;
		
		if statut='45' then do;
			pop1="FPT";							/* Fonctionnaires titulaires */
			if pub3fp in('2','3') then 	pop2="CLH"; 	/* Collectivités locales ou hôpital // TODO la séparation pourrait être utile pour séparer la cotisation FCCPA et FEH */
			else 						pop2="Aut"; 	/* Autres FPT */
			end;
		else if contractuel=1	then pop1="FPNT";	/* Fonctionnaires non titulaires */
		else pop1="RG";							/* Salariés du régime général */
		if pop1 in ("FPT" "FPNT") then do;
			if substr(p,1,2) in ('21','22','23','33','37','38') then pop3="1";
			else if substr(p,1,2) in ('31','34','35')           then pop3="2";
			else if substr(p,1,2)='42'                          then pop3="3";
			else if substr(p,1,2) in ('43','44')                then pop3="4";
			else if p='452b'                                    then pop3="5";
			else if substr(p,1,2)='45'                          then pop3="6";
			else if substr(p,1,2) in ('46','47')                then pop3="7";
			else if substr(p,1,2)='48'                          then pop3="8";
			else if p in ('531a','531b','532a','532b')          then pop3="9";
			else if p in ('532c')                               then pop3="10";
			else if substr(p,1,2) in ('52','53','54','55','56') then pop3="11";
			else if p=:'6'                                      then pop3="12";
			end;
		if pop2="" then pop=pop1; else pop=compress(pop1!!pop2);

		/* Calcul du salaire mensuel déclaré */
		if hsup&anr2.=. then hsup&anr2.=0;
		%Init_Valeur(hsupm hsupm_eqDecl prohsup);
		if nbmois_sal>0 then do;
			HSupM=hsup&anr2./nbmois_sal; 							/* Rémuneration heures sup mensuelle nette */
			HSupM_eqDecl=HSupM/(1-&Tcsgi.-&Tcrds.);			/* En équivalent déclaré (ajout CSG imposable et CRDS) */
			zsali_m=((zsali&anr2.+part_salar&anr2. - part_employ&anr2.)/nbmois_sal)-HSupM+HSupM_eqDecl;	
			/* Salaire mensuel déclaré (yc heures sup). 
			On inclut aussi la part salariale pour les contrats collectifs obligatoires (pas la part employeur, exonérée
			de cotisations)*/
			proHSup=HSupM_eqDecl/zsali_m; 					/* Prorata pour la suite */
			end;

		/* Part de primes */
		%Init_Valeur(tprim);
		if pop1 in ("FPT" "FPNT") then tprim=symgetn(compress('tprim'!!pop1!!pop3));


		/****************************/
		/* 1	TAUX DE COTISATIONS */
		/****************************/
		/* Principe : 
			- initialisation à 0 de tous les taux (pas de valeurs manquantes pour les besoins de la suite)
			- ces taux prennent la valeur de différentes macro-variables en fonction du régime (FPT, FPNT ou RG), grâce à la fonction symgetn */

		%Init_Valeur(	tcomaS tcomaP tcoviS tcoviP tcoviS_plaf tcoviS_deplaf tcoviP_plaf tcoviP_deplaf
					tcofaP tcofnP tcofnP2 tcofnP3 tcosoS tcodiP	tcoaccP ttaxP);

		/* Maladie */
		tcomaS=	symgetn(compress('tcoma'!!pop1!!'_S'));
		tcomaP=	symgetn(compress('tcoma'!!pop!!'_P'));

		/* Vieillesse */
		if pop1="FPT" then do;
			tcoviS=	symgetn(compress('tcovi'!!pop!!'_S'));
			tcoviP=	symgetn(compress('tcovi'!!pop!!'_P'));
			end;
		/*écart à la législation : 
		la cotisation patronale vieillesse pour les titulaires de la fonction publique territoriale + hospitalière n'est pas séparée 
		entre FCCPA et FEH (on prend une moyenne entre les deux taux) pour plus de simplicité (les taux sont faibles)*/
		else do;
			tcoviS_plaf=	symgetn(compress('tcovi'!!pop1!!'_plaf_S'));
			tcoviS_deplaf=	symgetn(compress('tcovi'!!pop1!!'_deplaf_S'));
			tcoviP_plaf=	symgetn(compress('tcovi'!!pop1!!'_plaf_P'));
			tcoviP_deplaf=	symgetn(compress('tcovi'!!pop1!!'_deplaf_P'));
			tcoviS=	tcoviS_plaf+tcoviS_deplaf;
			tcoviP=	tcoviP_plaf+tcoviP_deplaf;
			end;

		/* Allocations familiales */
		tcofaP=	symgetn(compress('tcofa'!!pop!!'_P'));

		/* Fonds national d'aide au logement (FNAL) */
		tcofnP=	symgetn(compress('tcofn'!!pop1!!'_P'));
		if pop1="RG" then tcofnP2=	symgetn(compress('tcofn'!!pop1!!'_P2')) and tcofnP3=	symgetn(compress('tcofn'!!pop1!!'_P3')) ;

		/* Solidarité */
		if pop1 in ("FPT" "FPNT") then tcosoS=	symgetn(compress('tcoso'!!pop1!!'_S'))*(zsali_m>=&plafsoli.);

		/* Transport */
		if pop1 in ("FPT" "FPNT") then tcodiP=	symgetn(compress('tcotr'!!pop1!!'_P'));

		/* Accident */
		if pop1 in ("FPNT" "RG") then tcoaccP=	symgetn(compress('tcoacc'!!pop1!!'_P'));

		/* Retraites complémentaires */
		if pop1="FPNT" then do; /* IRCANTEC */
			/* TcoarP=	&TcoarFPNT_P.; */  /* Ne sert pas pour le moment */
			/* TcoagbP=&TcoagbFPNT_P.; */  /* Ne sert pas pour le moment */
			end;

		/* Taxes */
		if pop1="RG" then do;
			/* taxeprem= &taxepremrg.*(effi>=10); */  /* Ne sert pas pour le moment */
			ttaxP=	sum(&taxeaprerg.,
						&contribSyndicatRG_P., /*c'est une contribution patronale, mais on le met ici par commodité*/
						%IF &anleg. < 2016 %THEN %DO;
							&taxeformrg1.*(effi<=9)+&taxeformrg2.*(10<=effi<=19)+&taxeformrg3.*(effi>=20),
							%END;
						%ELSE %DO;
							&taxeformrg1.*(effi<=10)+&taxeformrg2.*(11<=effi<=19)+&taxeformrg3.*(effi>=20),
							%END;
						&taxeparmrg.*(effi>=20),
						%IF &anleg. < 2016 %THEN %DO;							
							&taxetramrg.*(effi>=10));
							%END;
						%ELSE %DO;
							&taxetramrg.*(effi>=11));
							%END;
			end;

		/******************************************/
		/* 2	SUPPLEMENT FAMILIAL DE TRAITEMENT */
		/******************************************/
		%Init_Valeur(SFTBMin SFTBMax SFTB);
		if NbEnf_SFT>0 then do;

			/* 2.1	SFT brut minimum et maximum */
			SFTBMin=	&sft1.*(NbEnf_SFT=1)
					+(&sft21.+&in449.*&sft22.)*(NbEnf_SFT=2)
					+(&sft31.+&in449.*&sft32.)*(NbEnf_SFT>=3)
					+(&sftp31.+&in449.*&sftp32.)*(NbEnf_SFT>=3)*(NbEnf_SFT-3);
			SFTBMax=	&sft1.*(NbEnf_SFT=1)
					+(&sft21.+&in717.*&sft22.)*(NbEnf_SFT=2)
					+(&sft31.+&in717.*&sft32.)*(NbEnf_SFT>=3)
					+(&sftp31.+&in717.*&sftp32.)*(NbEnf_SFT>=3)*(NbEnf_SFT-3);

			/* 2.2	Distinction temps partiel temps incomplet */
			DurTPlein=&TpsTra.;

			/* Référence temps plein 18 h pour les enseignants du secondaire et du supérieur */
			if p in ('341a','342a','422b','422c') & temps='partiel' & hor<&ORS_ens_sec. then DurTPlein=&ORS_ens_sec.;
			/* Référence temps plein 26 h pour les enseignants du primaire, CPE, surveillants ... */
			else if p in ('421a','422d','422e','425a') & temps='partiel' & hor<&ORS_ens_prim. then DurTPlein=&ORS_ens_prim.;
			saltp=zsali_m*(DurTPlein/hor);
			if hor<(DurTPlein/2) then tpinc='1'; 

			/* 2.3	Calcul du SFT Brut annuel */
			if pop1="FPT" then do;
				/* Min et Max : SFT et salaire net correspondants */
				sn448=	(&in449.*(1+tprim)+sftbmin)*(1-&Tcsgd.)*(1-tcosos)-&in449.*tcoviS*(1-tcosoS);
				sn716=	(&in717.*(1+tprim)+sftbmax)*(1-&Tcsgd.)*(1-tcosos)-&in717.*tcoviS*(1-tcosoS);
				end;
			else if pop1="FPNT" then do;
				/* Min et Max : SFT et salaire net correspondants */
			    sn448=	(&in449.*(1+tprim)+sftbmin)*(1-tcomaS-tcoviS-&TcoarFPNT_S.)*(1-tcosos);
			    sn716=	(&in717.*(1+tprim)+sftbmax-&plafondssa./12)*(1-tcomaS-tcoviS_deplaf-&TcoagbFPNT_S.)*(1-tcosos)
			         	+&plafondssa./12*(1-tcomaS-tcoviS-&TcoarFPNT_S.)*(1-tcosos);
				end;
			SftB=min(max(SftBMin,SftBMin+(SftBMax-SftBMin)*(saltp-sn448)/(sn716-sn448)),SftBMax);
			SftB=max(SftBMin*(tpinc ne '1'),SftB*hor/DurTPlein);
			end;
		label SftBA="SFT brut annuel";
		SftBA=SftB*nbmois_sal;

		/**********************************************/
		/* 3	Calcul du PASS sur du salaire déclaré */
		/**********************************************/
		%Init_Valeur(SftMni);
		if pop1="FPT" then do;
			SftMni=	SftB*(1-&Tcsgd.-tcosos);
			pfd_4=	(4*&plafondssa./12-SftB)*((1-(1-tprim)*tcoviS)*(1-TcosoS)- &Tcsgd.) + SftMni; /* TODO : retrouver la référence légale sur le pfd_4 */
			end;

		else if pop1="FPNT" then do;
			pfd_1=	&plafondssa./12*((1-tcomaS-tcoviS-&TcoarFPNT_S.)*(1-TcosoS)-&Tcsgd.);					/* Sous le plafond */
			pfd_4=	pfd_1+3*&plafondssa./12*((1-tcomaS-tcoviS_deplaf-&TcoagbFPNT_S.)*(1-TcosoS)- &Tcsgd.);	/* Entre 1 et 4 pfd */			
			pfd_8=	pfd_4+4*&plafondssa./12*(1-tcomaS-tcoviS_deplaf-&TcoagbFPNT_S.-&Tcsgd.); 				/* Entre 4 et 8 pfd */
			end;

		else if pop1="RG" then do; /* Taux synthétiques + plafond équivalent déclaré, pour les cadres et non cadres. */
			/* Sous le plafond */
			TxSNC0=	&Tcsgd.+&Tcomarg_S.+&tcoviRG_deplaf_S.+&tcoviRG_plaf_S.+&Tcoasrg_S.+&TcoarRG1_S.+&TcoarRG2_S.*(&anleg.<=1998);
			TxSC0=	&Tcsgd.*(1+&Tprevrg_P.)+&Tcomarg_S.+&tcoviRG_deplaf_S.+&tcoviRG_plaf_S.+&Tcoaprg_S.+&Tcoasrg_S.+&TcoarRG1_S. +&Tcoctrg_S.;
			PfdNC_1=&plafondssa./12*(1-TxSNC0);
			PfdC_1=	&plafondssa./12*(1-TxSC0);
			/* Entre 1 et 3 pfd */
			TxSNC1=	&Tcsgd.+&Tcomarg_S.+&tcoviRG_deplaf_S.+&Tcoasrg_S98.*(&anleg.<=1998)+&Tcoasrg_S.*(&anleg.>=2006)+&TcoarRG1_S.*(&anleg.<=1998)+&TcoarRG2_S.;
			TxSC1=	&Tcsgd.+&Tcomarg_S.+&tcoviRG_deplaf_S.+&Tcoaprg_S.+&TcoagbRG_S.+&Tcoctrg_S.+&Tcoasrg_S98.*(&anleg.<=1998)+&Tcoasrg_S.*(&anleg.>=2006);
			PfdNC_3=PfdNC_1	+2*&plafondssa./12*(1-TxSNC1);
			PfdC_3= PfdC_1	+2*&plafondssa./12*(1-TxSC1);
			/* Entre 3 et 4 pfd */
			TxSNC2=	&Tcsgd.+&Tcomarg_S.+&tcoviRG_deplaf_S.+&Tcoasrg_S98.*(&anleg.<=1998)+&Tcoasrg_S.*(&anleg.>=2006);
			TxSC2=	&Tcsgd.+&Tcomarg_S.+&tcoviRG_deplaf_S.+&Tcoaprg_S.+&TcoagbRG_S.+&Tcoctrg_S.+&Tcoasrg_S98.*(&anleg.<=1998)+&Tcoasrg_S.*(&anleg.>=2006);
			PfdNC_4=PfdNC_3	+&plafondssa./12*(1-TxSNC2);
			PfdC_4=	PfdC_3	+&plafondssa./12*(1-TxSC2);
			/* Entre 4 et 8 pfd */
			TxSNC3=	&Tcsgd.+&Tcomarg_S.+&tcoviRG_deplaf_S.;
			TxSC3= 	&Tcsgd.+&Tcomarg_S.+&tcoviRG_deplaf_S.+&TcoagcRG_S.+&Tcoctrg_S.;
			PfdNC_8=	PfdNC_4	+4*&plafondssa./12*(1-TxSNC3);
			PfdC_8=		PfdC_4	+4*&plafondssa./12*(1-TxSC3);
			/* Supérieur à 8 pfd */
			TxSNC4=	&Tcsgd.+&Tcomarg_S.+&tcoviRG_deplaf_S.;
			TxSC4=	&Tcsgd.+&Tcomarg_S.+&tcoviRG_deplaf_S.;
			end;

		/******************************/
		/* 4 - CALCUL DU SALAIRE BRUT */
		/******************************/
		if pop1="FPT" then do; 
			%if &anleg.<=1998 %then %do;
				salbrut=(zsali_m-SftMni)/((1-(1-tprim)*tcoviS)*(1-TcosoS)- &Tcsgd.) + sftb;
				%end;
			%if &anleg.>=1999 %then %do;
				if zsali_m<pfd_4 then salbrut=(zsali_m-SftMni)/((1-(1-tprim)*tcoviS)*(1-TcosoS)- &Tcsgd.) + sftb;
				else salbrut=4*&plafondssa./12+(zsali_m-pfd_4-sftmni)/(1-(1-tprim)*tcoviS- &Tcsgd.) + sftb;
				%end;
			end;

		else if pop1="FPNT" then do;
			%if &anleg.<=1998 %then %do; 
				if zsali_m<pfd_1 			then salbrut=zsali_m/((1-tcomaS-tcoviS-&TcoarFPNT_S.)*(1-TcosoS)-&Tcsgd.);
				else if zsali_m<pfd_8 	then salbrut=&plafondssa./12+(zsali_m-pfd_1)/(1-tcomaS-tcoviS_deplaf-&TcoagbFPNT_S.-&Tcsgd.);
				else if zsali_m>=pfd_8 	then salbrut=8*&plafondssa./12+(zsali_m-pfd_8)/(1-tcomaS-tcoviS_deplaf-&Tcsgd.);
				%end; 
			%if &anleg.>=1999 %then %do; 
				if zsali_m<pfd_1 			then salbrut=zsali_m/((1-tcomaS-tcoviS-&TcoarFPNT_S.)*(1-TcosoS)-&Tcsgd.);
				else if zsali_m<pfd_4 	then salbrut=&plafondssa./12+(zsali_m-pfd_1)/((1-tcomaS-tcoviS_deplaf-&TcoagbFPNT_S.)*(1-TcosoS)-&Tcsgd.);
				else if zsali_m<pfd_8 	then salbrut=4*&plafondssa./12+(zsali_m-pfd_4)/(1-tcomaS-tcoviS_deplaf-&TcoagbFPNT_S.-&Tcsgd.);
				else if zsali_m>=pfd_8 	then salbrut=8*&plafondssa./12+(zsali_m-pfd_8)/(1-tcomaS-tcoviS_deplaf-&Tcsgd.);
				%end; 
			end;

		else if pop1="RG" then do;
			if cst2='cadpriv' then do;
				if zsali_m<=pfdc_1 then 		salbrut=zsali_m/(1-txsc0);
				else if zsali_m<=pfdc_3 then 	salbrut=&plafondssa./12+(zsali_m-pfdc_1)/(1-txsc1);
				else if zsali_m<=pfdc_4 then 	salbrut=3*&plafondssa./12+(zsali_m-pfdc_3)/(1-txsc2);
				else if zsali_m<=pfdc_8 then 	salbrut=4*&plafondssa./12+(zsali_m-pfdc_4)/(1-txsc3);
				else 			 			salbrut=8*&plafondssa./12+(zsali_m-pfdc_8)/(1-txsc4);
				end;
			else do;
				if zsali_m<=pfdnc_1 then 		salbrut=zsali_m/(1-txsnc0);
				else if zsali_m<=pfdnc_3 then salbrut=&plafondssa./12+(zsali_m-pfdnc_1)/(1-txsnc1);
				else if zsali_m<=pfdnc_4 then salbrut=3*&plafondssa./12+(zsali_m-pfdnc_3)/(1-txsnc2);
				else if zsali_m<=pfdnc_8 then salbrut=4*&plafondssa./12+(zsali_m-pfdnc_4)/(1-txsnc3);
				else 			 			salbrut=8*&plafondssa./12+(zsali_m-pfdnc_8)/(1-txsnc4);
			 	end;
			end;

		/**************************************************/
		/* 5 - CALCUL DES COTISATIONS (Montants mensuels) */
		/**************************************************/
		/* Principe : 
			- initialisation à 0 de tous les montants de cotisations (pas de valeurs manquantes pour les besoins de la suite)
			- formules communes à tous les régimes autant que possible, les taux ayant été mis à zéro plus haut */

		%Init_Valeur(	ComaS ComaP	CofaP CoviS CoviP CofnP	taxP CoacP CoveS CorcS CorcP CoasS CoasP CocetS CocetP
					CoprevP CoSoS csgtsdM csgtsiM crdstsM CSGts_malM);

		/* Maladie */
		COmaS=salbrut*tcomaS;
		COmaP=salbrut*tcomaP*(1-tprim*(pop1="FPT"));

		/* Famille */
		COfaP=salbrut*tcofaP*(1-tprim*(pop1="FPT"));
		/*réduction de taux de cotisation d'allocations familiales pour les bas salaire depuis 2015*/
		%if &anleg=2015 or &anleg>2016 %then %do ;
			if statut in ('21','33','34','35') & emploi_particulier=0 & (pub3fp='4' or (pub3fp='' and echpub in ('','1'))) then do; /*meme condition que les exo Fillon*/
				if (salbrut-HSBrut)<=&seuilcofaredRGP.*&smic_brut. then do; 
					tcofaP=&tcofaredRGP.;
					COfaP=salbrut*tcofaP*(1-tprim*(pop1="FPT"));
					end;
				end;
			%end;
		%if &anleg=2016 %then %do ; /*la hausse de plafond a lieu en avril, donc on fait un traitement particulier*/
			if statut in ('21','33','34','35') & emploi_particulier=0 & (pub3fp='4' or (pub3fp='' and echpub in ('','1'))) then do; 
				if (salbrut-HSBrut)<=&seuilcofaredRGP_lag1.*&smic_brut. then do; 
					tcofaP=&tcofaredRGP.;
					COfaP=salbrut*tcofaP*(1-tprim*(pop1="FPT"));
					end;
				else if (salbrut-HSBrut)<=&seuilcofaredRGP.*&smic_brut. and (salbrut-HSBrut)>&seuilcofaredRGP_lag1.*&smic_brut.then do; 
					COfaP=salbrut*(tcofaP*3/12+&tcofaredRGP.*9/12)*(1-tprim*(pop1="FPT"));
					/*on proratise en faisant comme si la personne a travaillé tous les mois de manière identique*/
					end;
				end;
			%end;

		/* Accident du travail */
		coacP=salbrut*tcoaccP*(pop1 in ("FPNT" "RG"));

		/* Vieillesse */
		COviS=	(pop1="FPT")*	(salbrut-sftb)*(1-tprim)*tcoviS 
				+(pop1="FPT")*	min((salbrut-sftb)*(tprim),&plafRAFP.*(salbrut-sftb)*(1-tprim))*&tRAFP_S. 
				/*Le plafond de l’assiette est de 20 % du traitement indiciaire brut total*/
				+(pop1="FPNT")*	min(salbrut,&plafondssa./12)*&tcoviFPNT_plaf_S.
				+(pop1="RG")*	min(salbrut,&plafondssa./12)*&tcoviRG_plaf_S.;
		COviP=	(pop1="FPT")*	salbrut*(1-tprim)*0   /*normalement il faudrait mettre tcoviP (qui correspond à tcoviFPTAut_P)
		mais comme l'Etat ne paye pas directement de cotisations, c'est un taux implicite très élevé qu'on ne souhaite pas mettre*/
				+(pop1="FPT")*	min((salbrut-sftb)*(tprim),&plafRAFP.*(salbrut-sftb)*(1-tprim))*&tRAFP_P. 
				+(pop1="FPNT")*	min(salbrut,&plafondssa./12)*&tcoviFPNT_plaf_P.
				+(pop1="RG")*	(min(salbrut,&plafondssa./12)*&TcoviRG_plaf_P. + salbrut*&TcoviRG_deplaf_P.);

		/* Veuvage */
		COveS= (pop1='FPNT')* 	salbrut*&tcoviFPNT_deplaf_S.
				+(pop1='RG')*	salbrut*&tcoviRG_deplaf_S.;

		/* Retraite complémentaire */
		corcS=(pop1="FPNT")*	(min(salbrut,&plafondssa./12)*&TcoarFPNT_S.
								+(salbrut>&plafondssa./12)*min(7*&plafondssa./12,salbrut-&plafondssa./12)*&TcoagbFPNT_S.);

		/* Régime général : non-cadres */
		if pop1="RG" and cst2='ncadpri' then do;
			%if &anleg.<=2000 %then %do; 
				corcS=	min(salbrut,3*&plafondssa./12)*(&TcoarRG1_S.+&TcoarRG2_S.);
		   		corcP=	min(salbrut,3*&plafondssa./12)*(&TcoarRG1_P.+&TcoarRG2_P.);
				%end;
			%else %do; 
		   		corcS=	min(salbrut,&plafondssa./12)*&TcoarRG1_S.+
		        		(salbrut>&plafondssa./12) * min(salbrut-&plafondssa./12,2*&plafondssa./12) *&TcoarRG2_S.;
		   		corcP=	min(salbrut,&plafondssa./12)*&TcoarRG1_P.+
		        		(salbrut>&plafondssa./12) * min(salbrut-&plafondssa./12,2*&plafondssa./12) *&TcoarRG2_P.;
				%end;
			end;

		/* Régime général : cadres */
		else if pop1="RG" then do;
		    corcS=	min(salbrut,&plafondssa./12)*&TcoarRG1_S.
					+(salbrut>&plafondssa./12)*min(salbrut-&plafondssa./12,3*&plafondssa./12)*&TcoagbRG_S.
					+(salbrut>4*&plafondssa./12)*min(salbrut-4*&plafondssa./12,4*&plafondssa./12)*&TcoagcRG_S.
					+min(salbrut,4*&plafondssa./12)*&Tcoaprg_S.;
		    corcP=	min(salbrut,&plafondssa./12)*&TcoarRG1_P.
					+(salbrut>&plafondssa./12)*min(salbrut-&plafondssa./12,3*&plafondssa./12)*&TcoagbRG_P.
					+(salbrut>4*&plafondssa./12)*min(salbrut-4*&plafondssa./12,4*&plafondssa./12)*&TcoagcRG_P.
					+min(salbrut,4*&plafondssa./12)*&Tcoaprg_P.;
			end;

		/* Cotisation Chomage */
		if pop1="RG" then do;
			%if &anleg.=1990 %then %do;
				coasS=min(salbrut,&plafondssa./12)*&Tcoasrg_S. + max(0,min(salbrut-&plafondssa./12,4*&plafondssa./12))*&Tcoasrg_S98.;
				coasP=min(salbrut,4*&plafondssa./12)*&Tcoasrg_P.; 
				%end;
			%if 1998<=&anleg. and &anleg.<=2004 %then %do;
				coasS=min(salbrut,&plafondssa./12)*&Tcoasrg_S. + max(0,min(salbrut-&plafondssa./12,4*&plafondssa./12))*&Tcoasrg_S98.;
				coasP=min(salbrut,&plafondssa./12)*&Tcoasrg_P. + max(0,min(salbrut-&plafondssa./12,4*&plafondssa./12))*&Tcoasrg_S98.; 
				%end; 
			%if &anleg.>=2005 %then %do;
				coasS=min(salbrut,4*&plafondssa./12)*&Tcoasrg_S.;
				coasP=min(salbrut,4*&plafondssa./12)*&Tcoasrg_P.;
				%end;
			end;

		if pop1="RG" and cst2='cadpriv' then do;
		    cocetS=min(salbrut,8*&plafondssa./12)*&Tcoctrg_S.;
		    cocetP=min(salbrut,8*&plafondssa./12)*&Tcoctrg_P.;
		    coprevP=min(salbrut,&plafondssa./12)*&Tprevrg_P.;
			end;

		if statut="21" and nafg088un='78' then do; /*écart à la législation : on est un peu large sur 78, en fait il faudrait cibler 7820Z */
			coagsP=min(salbrut,4*&plafondssa./12)*&Tcoags2_P.;
			end;
		else do; 
			coagsP=min(salbrut,4*&plafondssa./12)*&Tcoags_P.;
			end;

		/* Cotisation solidarité */
		if pop1 in ("FPT" "FPNT") then do;
			cosoS=0;
			%if &anleg.>=1982 %then %do;
				if zsali_m>&plafsoli. then cosoS=(salbrut-comaS-coviS)*tcosoS;
				%if &anleg.>=1995 %then %do; /* Art 2 de la loi 82-934 du 4 nov 1982 */
					if salbrut>=4*&plafondssa./12 then cosoS=(4*&plafondssa./12*(1-(1-tprim)*(tcomaS+tcoviS)))*tcosoS;
					%end;
				%end;
			end;

		/* Logement */
		COfnP=	min(&plafondssa./12,salbrut*(1-tprim*(pop1="FPT")))*tcofnP*(effi<&effiMax_P2.)
				+salbrut*tcofnP3*(effi>=&effiMax_P2.)*(pop1="RG");

		/* Taxes */
		taxP=salbrut*(tcodiP*(1-tprim)*(pop1="FPT")+tcodiP*(pop1="FPNT")+ttaxP*(pop1="RG"));

		/* CSG et CRDS */
		if pop1="RG" then do;
			csgtsdM=	(salbrut+coprevp)*&Tcsgd.;
			csgtsiM=	(salbrut+coprevp)*&Tcsgi.;
			crdstsM=	(salbrut+coprevp)*&Tcrds.;
			CSGts_malM=	(salbrut+coprevp)*&Tcsg_mal.;
			end;

		/*************************************/
		/* 6 - ARRETS MALADIE 				 */
		/*************************************/
		if  cotis_special='indemnite maladie' or cotis_special='indemnite maternite' then do; 
			/* les indemnites journalieres maladie versés par la sécu sont déclarés mais exonérées de charges sociales*/
			/* à l'inverse, les compléments de salaires versé par les complémentaires de prévoyance y sont soumis*/
			/* à défaut on prévoit le cas le plus simple*/
			/* les indemnite journalieres de conges maternite sont exonérees de cotisations sociales mais soumises à la CSG et la CRDS*/
			/* en 1990, il semble qu'il n'y avait pas de cotisations à la place*/
			%Init_Valeur(comaS comaP cofaP coviS coviP cofnP coacP coasS coasP corcS corcP cocetS coprevP cocetP taxp);
			csgtsd=		(salbrut+coprevp)*&Tcsgijd.;
			csgtsi=		(salbrut+coprevp)*&Tcsgiji.;
			crdsts=		(salbrut+coprevp)*&tcrdsij.;
			CSGts_mal=	(salbrut+coprevp)*&Tcsgij_mal.;
			end;


		/**************************************/
		/* 7 - EXONERATIONS DU REGIME GENERAL */
		/**************************************/

		%Init_Valeur(exoCPHS exo_BSM exo_AppM CICE taxe_salaire taxe_75); /* Non codé : employés de maison */
		%Init_Valeur(HSBrut HSupM_HorsMajo NbHSupM);
		%Init_Valeur(hscomaS hscoveS hscoviS hscoasS hscorcS hscocetS hscsgtsd hscsgtsi hscrdsts hsCSGts_mal);

		if pop1="RG" then do;
			HSBrut=max(0,sum(hscomaS,hscoveS,hscoviS,hscoasS,hscorcS,hscocetS,hscsgtsd,hsupm));

			/* 7.1 - Exonération des cotisations salariales sur heures sup */
			/* Ecart à la législation : normalement le taux de réduction ne doit pas excèder 21,5 % */
			/* cf http://www.urssaf.fr/employeurs/dossiers_reglementaires/dossiers_reglementaires/questions-reponses_sur_les_heures_supplementaires_01.html*/
			%if 2007<=&anleg. and &anleg.<=2012 %then %do;

				%let ratio=%sysevalf(	3/12*(&anleg.=2007) 	/* introduction de l'exonération au 01/10/07 */
										+8/12*(&anleg.=2012) 	/* suppression de l'exonération au 01/09/12 */
										+1*(&anleg.>2007 and &anleg.<2012));

				array co1 	comaS coveS coviS coasS corcS cocetS;
				array HSco1 HScomaS HScoveS HScoviS HScoasS HScorcS HScocetS;
				array co2 	csgtsdM csgtsiM crdstsM CSGts_malM;
				array HSco2 HScsgtsd HScsgtsi HScrdsts HSCSGts_mal;

				if proHSup>0 then do;
					do i=1 to dim(co1);
						HSco1(i)=co1(i)*proHSup;
						end;
					do j=1 to dim(co2);
						HSco2(j)=(co2(j)-coprevp*&Tcsgi.)*proHSup;
						end;
					drop i j;
					HSBrut=max(0,sum(hscomaS,hscoveS,hscoviS,hscoasS,hscorcS,hscocetS,hscsgtsd,hsupm));
					end;

				array co 	comaS coveS coviS coasS corcS cocetS csgtsdM csgtsiM crdstsM CSGts_malM;
				array HSco 	HScomaS HScoveS HScoviS HScoasS HScorcS HScocetS HScsgtsd HScsgtsi HScrdsts HSCSGts_mal;
				do i=1 to dim(co);
					co(i)=max(0,co(i)-&ratio.*HSco(i));
					end;
				drop i;
				%end;

			/* 7.2 - Réduction des cotisations patronales */
			if temps='complet' and HSupM_eqDecl>0 then do;

				/* Suppression de l'allègement pour les grosses entreprises en 2012, mais reste pour les petites entreprises */
				/* Comme plus haut, on définit un ratio qui servira pour la partie "grosses entreprises" */
				%let ratio=%sysevalf(	3/12*(&anleg.=2007) 	/* introduction de l'exonération au 01/10/07 */
										+8/12*(&anleg.=2012) 	/* suppression de l'exonération au 01/09/12 */
										+1*(&anleg.>2007 and &anleg.<2012)); /* 0 sinon */

				/* Approximation du nombre d'heures supplémentaires pour les concernés */
				/* Ecart : 	on considère que toutes les heures sup sont majorées de 25 % alors qu'au-delà 
							de 43 heures elles le sont de 50 % ou qu'il peut y avoir des conventions collectives*/
				HSupM_HorsMajo=	HSupM_eqDecl*(1/(1+&MajoSalHSup.));	/* Revenu mensuel des heures sup, hors majoration de salaire */
				SalHor_HN=		max(&smich.,((zsali&anr2./nbmois_sal)-HSupM_eqDecl)/((52/12)*&TpsTra.)); /* Salaire horaire des heures normales */;
				NbHSupM=		round((HSupM_HorsMajo)/SalHor_HN,1); /* Nombre mensuel d'heures sup */
		 		exoCPHS=		NbHSupM*(	&ratio.*&Forf_HSup1.*(effi>=&effi_Hsup. or effi=.)
									+&Forf_HSup2.*(1<=effi<&effi_Hsup.)); /* exonération mensuelle */
				cotsP1=sum(comaP,cofaP,coviP,coacP);
				if 0<exoCPHS<cotsP1 then do;
					comaP= comaP-exoCPHS*(comaP/cotsP1);
					cofaP= cofaP-exoCPHS*(cofaP/cotsP1);
					coviP= coviP-exoCPHS*(coviP/cotsP1);
					coacP= coacP-exoCPHS*(coacP/cotsP1);
					end;
				end;

			/* 7.3 - Exo bas salaires */

			/* Dispositif "Juppé" */
			%if &anleg.=1998 %then %do; 
				if salbrut<&smic_brut. 				then exo_BSM=salbrut*&tredcoP1.; 
				else if salbrut<1.30*&smic_brut. 	then exo_BSM=(salbrut-1.30*&smic_brut.)*&tredcoP2.; 
				else exo_BSM=0; 
				if temps='partiel' and hor<&TpsTra. then exo_BSM= exo_BSM*hor/&TpsTra.;
				exo_BSM= min(exo_BSM,&smic_brut./12*1/5.5); 
				/* Le max est compté en Smic (5,5 Smic) plutôt qu'en valeur nominale */
				%end;

			/* Dispositif "Fillon" */
			%if &anleg.>=2006 %then %do;
				/* cas général temps complet  (ajout des CDD en 2008) */
				if statut in ('21','33','34','35') & emploi_particulier=0 & (pub3fp='4' or (pub3fp='' and echpub in ('','1'))) then do;
					/* nouvel allègement supplémentaire 2008 pour les entreprises de moins de 20 salariés */
					%if &anleg.>=2008 %then %do;
						if 1<=effi<20 then exo_BSM=min(max(0,(&tauxall19./(&salmaxexo.-1))*(&salmaxexo.*&smic_brut./(salbrut-HSBrut)-1)),&tauxall19.)*(salbrut-HSBrut); 
						/* pour les entreprises de 20 salariés et + et toutes celles dont l'effectif est inconnu */
						else exo_BSM=min(max(0,(&tauxall./(&salmaxexo.-1))*(&salmaxexo.*&smic_brut./(salbrut-HSBrut)-1)),&tauxall.)*(salbrut-HSBrut); 
						%end;

					/* proratisation temps partiel */
					if temps='partiel' then exo_BSM=max(0,(&tauxall./(&salmaxexo.-1))*(&salmaxexo.*&smic_brut.*(hor/&TpsTra.)/(salbrut-HSBrut)-1))*(salbrut-HSBrut);
					end;
				%end;

			/* Répartition de la réduction Fillon au prorata des diverses cotisations */
			%if &anleg.<2015 %then %do;
				%let cot_Fillon=comaP cofaP coviP;
				%end;
			%else %if &anleg.>=2015 %then %do;
				%let cot_Fillon=comaP cofaP coviP coacP cofnP; /* 2015 : Ajout des cotisations FNAL et AT-MP */
				/* Ecart à la législation : normalement ajout aussi CSA mais cette cotisation est regroupée avec Maladie dans Ines : déjà comptée même avant 2015 */
				%end;
			cot_Fillon=max(0,sum(of &cot_Fillon.));
			exo_BSM=min(exo_BSM,cot_Fillon); /* On borne exo_BSM, en bas par 0, et en haut par le montant total de cotis concernées en haut */
			if cot_Fillon>0 then do;
				%do k=1 %to %sysfunc(countw(&cot_Fillon.));
					%let cot=%scan(&cot_Fillon.,&k.);
					&cot.=&cot.-exo_BSM*(&cot./cot_Fillon);
					/* Ecart à la législation (non codé) : pour les cotis AT-MP à partir de 2015, c'est dans la limite de 1 % de la rémunération */
					%end;
				end;

			/* 7.4 - CICE */
			%if &anleg.>=2013 %then %do;
				/* cas général temps complet (il faudrait exclure les stagiaires rémunérés) + depuis 2015 la mesure s'étend pour les exploitants d'entreprises imposées au régime réel (donc sur l'IR : non codé)*/
				if statut in ('21','22','33','34','35') & cotis_special ne 'trav+retraite' then do;
					if salbrut<&NbSmic_CICE.*&smich.*(52/nbmois_sal*hor+NbHSupM) then CICE=&tauxCICE.*salbrut*nbmois_sal;
					end;
				%end;

			/* 7.5 - Apprentis */
			if (statut='22') then do;
				exo_AppM=comaS+comaP+coveS+cofaP+coviS+coviP+coasS+coasP+corcS+corcP+cocetS+coprevP+cocetP;
				%Init_Valeur(comaS comaP coveS cofaP coviS coviP coasS coasP corcS corcP cocetS coprevP cocetP);
				%Init_Valeur(csgtsdM csgtsiM crdstsM csgts_malM);
				salbrut=zsali_m;
				end;
			end;


		/*************************************************/
		/* 8 - TAXE SUR LES SALAIRES	(+ taxe à 75%)	 */
		/**************************************************/
			/* La taxe sur les salaires concerne les entreprises dont 90% minimum du chiffre d'affaires n'est pas soumis à la TVA.
			Cela correspond à peu près aux entreprises dont l'activité est la suivante (Liste d'activités appuyée par un rapport du Sénat : http://www.senat.fr/rap/r01-008/r01-00821.html) */
		if pop1="RG" and nafg088un in ('64','65','66','68','82','84','85','86','87','88','94','99') then do;
			if salbrut*nbmois_sal<=&taxeSal_lim1. 		then taxe_salaire=&taxeSal_tx1.*salbrut*nbmois_sal;
			else if salbrut*nbmois_sal<=&taxeSal_lim2. then taxe_salaire=&taxeSal_tx2.*(salbrut*nbmois_sal-&taxeSal_lim1.)+&taxeSal_tx1.*&taxeSal_lim1.;
			else if salbrut*nbmois_sal<=&taxeSal_lim3. then taxe_salaire=&taxeSal_tx3.*(salbrut*nbmois_sal-&taxeSal_lim2.)+&taxeSal_tx2.*(&taxeSal_lim2.-&taxeSal_lim1.)+&taxeSal_tx1.*&taxeSal_lim1.;
			else taxe_salaire=&taxeSal_tx4.*(salbrut*nbmois_sal-&taxeSal_lim3.)+&taxeSal_tx3.*(&taxeSal_lim3.-&taxeSal_lim2.)+&taxeSal_tx2.*(&taxeSal_lim2.-&taxeSal_lim1.)+&taxeSal_tx1.*&taxeSal_lim1.;
			end;
			/* Ecarts à la législation : on ne prend pas en compte : 
				- la franchise pour les montants annuels n’excèdant pas 1 200 €
				- la décote entre 1 200 € et 2 040 € 
				- l'abattement spécifique pour association car on ne connait pas la somme de la taxe payée par l'entreprise */

			/*"taxe à 75%" en 2013 et 2014 qui est une taxe à 50% sur les rémunérations brutes supérieures à 50%*/
			%if &anleg.=2013 or &anleg.=2014 %then %do;
				if salbrut*nbmois_sal>=&seuil_taxe75. 		then taxe_75=&taux_taxe75.*(&seuil_taxe75.-salbrut*nbmois_sal);
				%end;
			/* Ecarts à la législation : normalement la taxe s'applique à l'ensemble des rémunérations y compris 
				attribution d’actions, participation, intéressement et avantages en argnet ou nature
				+ Le montant de la taxe est plafonné à hauteur de 5 % du chiffre d'affaires réalisé l'année au titre de laquelle la taxe est due*/
			
		/*************************************/
		/* 9 - REGROUPEMENT ET ANNUALISATION */
		/*************************************/

		/* Principe : autant que possible, codé de façon commune à tous les régimes, les différences ayant été gérées plus haut*/
		%Init_Valeur(CotsMAL_sal CotsMAL_pat COtsRES_bpl COtsRES_bdepl COtsRES_compl COtsRES COtsREP COtsFA ContribExcSol COtsTAXP
					COtsCHS COtsCHP COtsAGSP COtsACP SftNA exo_BasSal exo_heursup exo_app exo);
		/* Maladie */
		CotsMAL_sal=nbmois_sal*comaS;
		CotsMAL_pat=nbmois_sal*comaP;

		/* Vieillesse */

		COtsRES_bpl=	nbmois_sal*(coviS);
		COtsRES_bdepl=	nbmois_sal*(coveS);
		COtsRES_compl=	nbmois_sal*(corcS);
		COtsRES=		nbmois_sal*(coviS+corcS+coveS+cocetS);
		COtsREP=		nbmois_sal*(coviP+corcP+coprevP+cocetP);

		/* Famille */
		COtsFA=		nbmois_sal*cofaP;

		/* Taxe */
		ContribExcSol=nbmois_sal*cosoS*(pop1 in ("FPT" "FPNT")); /* Contribution pour le financement de l'ASS */
		CotsTAXP=	nbmois_sal*sum(taxP,cofnP); /* taxes + contribution logement */

		/* Chômage */
		COtsCHS= 	nbmois_sal*coasS;
		COtsCHP= 	nbmois_sal*coasp;
		COtsAGSP= 	nbmois_sal*coagsP;

		/* Accident du travail */
		COtsACP= 	nbmois_sal*coacP; /* Cot patronales théoriques dans la FP, yc pour les contractuels de l'Etat */

		/* Agrégations */
		if pop1 in ("FPT" "FPNT") then do;
			COtsS=		sum(COtsRES,CotsMAL_sal);
			COtsP=		sum(COtsREP,COtsFA,COtsACP,CotsMAL_pat);
			CSGtsD=		nbmois_sal*salbrut*&Tcsgd.*(1-tprim*(&anleg.=1998)*(pop1="FPT"));
			CSGtsI=		nbmois_sal*salbrut*&Tcsgi.;
			CSGts_mal=	nbmois_sal*salbrut*&Tcsg_mal.;
			CRDSts=		nbmois_sal*salbrut*&Tcrds.;
			end;

		if pop1="RG" then do;
			COtsS=		sum(COtsCHS,COtsRES,COtsMal_sal);
			COtsP=		sum(COtsCHP,COtsAGSP,COtsREP,COtsACP,CotsMAL_pat,COtsFA);
			CSGtsD= 	nbmois_sal*csgtsdM;
			CSGtsI= 	nbmois_sal*csgtsiM;
			CSGts_mal=	nbmois_sal*csgts_malM;
			CRDSts= 	nbmois_sal*crdstsM;
			end;
	
		label SftNA="SFT net annuel";
		SftNA=	SftBA*(1-tcosos-&Tcsgi.-&Tcsgd.-&Tcrds.);
		label zsalbrut="Salaire annuel brut de 20&anr2.";
		zsalbrut=	sum(zsali&anr2.,part_salar&anr2., -part_employ&anr2., csgtsd,cotsS);

		/* Annualisation des montants d'exonération */
		exo_BasSal=	nbmois_sal*exo_BSM;
		exo_heursup=max(0,nbmois_sal*sum(HSBrut,exoCPHS,-HSupM)); /* les heures sup brutes moins les heures sup nettes */
		exo_app=	nbmois_sal*exo_AppM;
		exo=		sum(0,exo_BasSal,exo_heursup,exo_app);

		label pop1=			'sous-population de salariés' 
			  COtsCHs=		'cot soc-chomage/salarial'
		      COtsCHp=		'cot soc-chomage/patronal'
		      COtsAGSp=		'cot soc-garanti salaire/patronal'
		      COtsREs=		'cot soc-retraite/salarial'
			  COtsRES_bpl=	'cot soc-retraite/salarial de base plafonnée'
			  COtsRES_bdepl='cot soc-retraite/salarial de base déplafonnée (dite veuvage)'
			  COtsRES_compl='cot soc-retraite/salarial complémentaire'
		      COtsREp=		'cot soc-retraite/patronal'
		      COtsFA= 		'cot soc-famille /patronal'
		      COtsACP= 		'cot soc-accident du travail/patronal'
		      COtsMAL_SAL=	'Cot soc mal/salarial'
			  COtsMAL_PAT=	'Cot soc mal/patronal'
		      ContribExcSol='Contribution exceptionnelle de solidarité'
		      COtsTAXp=		'Taxes et contribution logement et syndicat/patronal'
		      COtsS=  		'cot soc-toutes/salarial'
		      COtsP=  		'cot soc-toutes/patronal'
		      CSGtsD= 		'CSG deduc/salaire'
		      CSGtsI= 		'CSG impos/salaire'
		      CSGts_MAL=	'CSG maladie/salaire'
		      CRDSts= 		'CRDS/salaire'
			  CICE=			'Créance au titre du CICE'
			  taxe_salaire=	'Taxe sur les salaires'
			  taxe_75=	'Taxe à 75% (en 2013 et 2014)';
		run;
	%mend Cotis_Salaries;
%Cotis_Salaries;

/************************************************************************************/
/*	III.	Chômeurs et préretraités												*/
/************************************************************************************/

%Macro Cotis_Chomeurs_preretraites;
	data Chomeurs_preretraites (keep=ident noi zchoBRUT COchRE COchMAL CSGchd CSGchi CRDSch CSGch_mal casaPR);
		set prof (where=(zchoi&anr2.>0)); 
		/*******************/
		/* A. LES CHOMEURS */
		/*******************/
		if cotis_special not in ('preretraite','preretraite+retraite') then do;
		
			/* 1	Calcul des indemnités brutes et du salaire de référence */
			label zchom="allocations mensuelles en net déclaré";
			if nbmois_cho>0 then zchom=(zchoi&anr2./nbmois_cho);

			/* 1.1	Calcul du salaire de référence */
			%if &anleg.=1998 or &anleg.=1990 %then %do; 
				salref=zchom*1.24*(1/0.75);
				%end; 

			%if &anleg.>=2006 %then %do; 
				if zchom <= &montantAREmin.*30/&tauxAREmax. 					then salref=	zchom/&tauxAREmax.; 
				else if zchom <=(&montantAREmin.-&socleAREint.)*30/&tauxAREint. then salref=	&montantAREmin.*30;
				else if zchom <= &socleAREint.*30/(&tauxAREsup. -&tauxAREint.) 	then salref=	(zchom-&socleAREint.*30)/&tauxAREint.;
				else if zchom <= &plafondssm.*4 								then salref=	zchom/&tauxAREsup.;
				else 																 salref=	zchom/&tauxAREsup.;
				%end;

			/*Remarques préliminaires sur le calcul :
				Zchom = ZchomNet + CRDS + CSG_Imposable
				ZchomBrut = Zchom + CSG_déductible + Cotisation_Ret_Comp = ZchomNet + CRDS + CSG_Imposable + CSG_déductible + Cotisation_Ret_Comp
				Donc ZchomBrut = (Zchom + Cotisation_Ret_Comp)/(1-Taux_CSG_déductible)*/

			/* 1.2	Calcul de la retraite complémentaire (VIchS) */
			
			/*Il existe un minimum en dessous duquel l'allocation après VIchS ne peut pas aller. On procède ainsi : 
				- si zchom (montant d'allocation chômage déclaré) est inférieur ou égal au minimum, on 
				  considère qu'il y a eu exonération de VIchS.
				- si zchom est strictement supérieur au minimum, on considère qu'il n'y a pas eu exonération.
			  3 remarques :
				- On pourrait se dire que même si zchom est strictement supérieur au minimum, zchom_net est peut être inférieur
				  au minimum, après soustraction de la CRDS et de la CSG_Imp. Mais dans ce cas zchom_net serait également inférieur
				  au minimum en dessous duquel CSG et CRDS ne peuvent faire descendre l'allocation, et donc il est impossible que 
				  CRDS et CSG_imp soit >0.
				- Le cas zchom = montant minimal peut aussi correspondre à des cas où il y a eu paiement de VIchS
				  mais avec un "écrêtement" (i.e. le montant de VIchS payé est égal à la différence entre le montant
				  brut d'allocation et le montant minimal). Je ne suis pas sûr à 100 % que c'est comme ça que ça fonctionne
				  mais quoi qu'il en soit on ne peut pas en tenir compte étant donné qu'on ne dispose que de zchom déclaré.
				  Cette approximation conduit à sous-estimer VIchS.
				- en réalité la comparaison avec le minimum se fait pour l'allocation journalière. Ici on regarde en mensuel, i.e.
				  implicitement on considère que le montant journalier moyen est égal au montant mensuel moyen divisé par 365/12,
				  or certains bénéficiaires de l'ARE peuvent avoir un faible nombre mensuel de jours de droits, et donc une allocation
				  journalière élevée bien que l'allocation mensuelle soit faible. Dans ces cas là on risque d'exonérer dans Ines alors
				  qu'il n'y a pas exonération en réalité. Cette approximation conduit également à sous-estimer VIchS. Et ça vaut aussi pour CSG-CRDS plus bas.*/

			VIchS 	= (zchom>&mcocrCHmin.*(365/12))*&tcocrCH.*salref;

			/* 1.3	Calcul de la CSG et CRDS */

			%if &anleg.>=1998 %then %do;
				if exo_csg=1 then do;
					CSG_CRDS = 0; 
					CRDSch = 0;
					CSGCHd = 0;
					CSGCHi = 0;
					CSGch_mal = 0;
					CSGTch = 0;
				end;

			/*Pour la suite, comme pour VIchS, il existe un minimum en dessous duquel l'allocation après CSG-CRDS
			ne peut pas aller. 
				On utilise la même méthode que pour VIchS : 
				Si Zchom est inférieur ou égal au minimum, on considère qu'il n'y a pas eu de CSG-CRDS payée,
				Si Zchom > minimum, on considère qu'il y a eu CSG CRDS payé. 
				En réalité il y a une complexité en plus par rapport à VIchS, dont on ne tient pas compte, c'est
				que comme la CRDS et la CSG imposable sont déjà incluses dans zchom, il y a sûrement des cas où Zchom est
				strictement supérieur au minimum, mais Zchom_net est inférieur. Dans ce cas là, il y a écrêtement dans la
				réalité, ce dont on ne tient pas compte ici (on considère qu'il y a paiement plein pot). 
					--> Ca pourrait sûrement être amélioré en rajoutant le calcul de l'écrêtement.

			Remarque complémentaire : 
			il me semble que l'assiette de CSG/CRDS est l'allocation chomage avant VIchS, mais
			cette page (https://www.unedic.org/indemnisation/fiches-thematiques/retenues-sociales-sur-les-allocations)
			dit le contraire */


				else if reduc_csg then do;

			/*Si reduc_csg, il n'y a pas de CSG imposable*/
					CSG_CRDS = (zchom>&mcocrCHmax.*(365/12))*(&TcsgCHd.+&tcrdsCH.)*(zchom+VIchS)/(1-&Tcsgchd.);
					CRDSch=	(&tcrdsCH./(&TcsgCHd.+&tcrdsCH.))*CSG_CRDS; /* prorata - RQ : exactement équivalent à appliquer 
																						le taux &tcrdsCH. au revenu brut (zchom+VIchS)/(1-&Tcsgchd.)*/
					CSGCHd= (&TcsgCHd./(&TcsgCHd.+&tcrdsCH.))*CSG_CRDS; /* prorata */
					CSGCHi = 0;
					CSGTch= CSGCHd;
					CSGCH_mal=	CSGCHd;

				end;

				else do;

					CSG_CRDS = (zchom>&mcocrCHmax.*(365/12))*(&TcsgCHd.+&tcrdsCH.+&TcsgCHi.)*(zchom+VIchS)/(1-&Tcsgchd.);
					CRDSch=	(&tcrdsCH./(&TcsgCHd.+&tcrdsCH.+&TcsgCHi.))*CSG_CRDS; /* prorata - RQ : exactement équivalent à appliquer 
																						le taux &tcrdsCH. au revenu brut (zchom+VIchS)/(1-&Tcsgchd.)*/
					CSGCHd= (&TcsgCHd./(&TcsgCHd.+&tcrdsCH.+&TcsgCHi.))*CSG_CRDS; /* prorata */
					CSGCHi= (&TcsgCHi./(&TcsgCHd.+&tcrdsCH.+&TcsgCHi.))*CSG_CRDS; /* prorata */
					CSGTch= CSGCHd + CSGCHi;
					CSGCH_mal=	CSGTch*&TcsgCH_mal./(&TcsgCHd.+&TcsgCHi.);

				end;
				comal=0;
				MALchS=0;
				%end; 

			%if &anleg.=1990 %then %do; 
				comal=max(0,min(zchom-&Tcochmal.*(365/12),&tcomalCH.*salref));
				%Init_Valeur(CSG_CRDS CSGTch CSGCHd CSGCHi CSGch_mal); 
				%end;

			zchoBRUTm=sum(0,zchom,VIchS,CSGCHd,comal); /* Indemnités brutes mensuelles :  */

			%if &anleg.=1990 %then %do;
				MALchS=max(0,min(zchoBRUTm-&Tcochmal.*(365/12),&tcomalCH.*salref));
				%Init_Valeur(CSGTch CSGCHd CSGCHi CSGch_mal); 
				%end; /* Cotisation maladie et CSG */

			/* 3	Annualisation des cotisations */
			COchRE=		VIchS*nbmois_cho;
			COchMAL=	MALchS*nbmois_cho;
			
			CSGchd=		CSGchd*nbmois_cho;
			CSGchi=		CSGchi*nbmois_cho;
			CSGch_mal=	CSGch_mal*nbmois_cho;

			CRDSch=		CRDSch*nbmois_cho;

			/* 4 On annule les cotisations pour les bénéficiaires de l'ASS */
			if montant_ass>0 then do;
				%Init_valeur(COchRE COchMAL CSGchd CSGchi CSGch_mal CRDSch);
				end; 

			end;
		
		/***********************/
		/* B. LES PRERETRAITES */
		/***********************/
		else if cotis_special in ('preretraite','preretraite+retraite') then do;
			
			/* le cas est assez compliqué puisque il y a une multitude de préretraites différentes*/
			/* on choisit de suivre la fiscalité appliquée au préretraite publique*/
			/* (préretraite progressive, CAATA et FNE (supprimé en 2012))*/
			/* plutôt que les préretraite d'entreprises*/

			/* il y a un changement de taxation qui s'applique sur les contrats signé après le 01/11/10*/
			/* la législation est la même depuis 1985, voir L 131-2*/

			/*Pour l'exonération de prélèvements si ces derniers font baisser l'allocation nette
			  en dessous du SMIC brut : on utilise la même méthode que pour le chômage, donc les limites mentionnées
			  plus haut s'appliquent aussi ici pour la plupart d'entre elles. Une différence : on n'a pas de nombre de mois 
			  de préretraite, donc on considère qu'on est en préretraite tous les mois où il y a 5 dans cal0 (ça n'est pas parfait, 
			  car on peut être en retraire - et pas en préretraite - en ayant 5, mais c'est mieux que de prendre 12 mois de préretraite
		      pour tout le monde)*/
			nb_5 = COUNT(cal0,'5');

			/*1 Calcul du revenu de préretraite brut*/
			zchoibrut=zchoi&anr2.*(1-&tcsgpred.-&tcomalpre.); 
			zchoBRUTm = zchoibrut/12; /*revenu de préretraite brut mensuel*/
			/*Remarque : zchoibrut et zchoBRUTm sont des variables intermédiaires qui servent à calculer les prélèvements, elles
						sont fausses pour les gens qui sont exonérés (pour ne pas faire descendre leurs allocations nettes en dessous 
						du SMIC brut), mais ça n'est pas grave car on ne conserve dans la table finale que zchoBRUT qui est recalculé
						comme somme de zchoi&anr2 (déclaré), et de CRDSch, CSGchd, COchMAL et COchRE qui sont calculées en tenant compte
						de l'exonération.*/
						

			/*2 Calcul de la cotisation maladie*/
			COchMAL= (zchoi&anr2.>nb_5*&mcocrCHmin.*(365/12))*zchoibrut*&tcomalpre.;
			COchRE=0;

			/*3 Calculs de la CRDS et CSG*/
			CRDSch=		(zchoi&anr2.>nb_5*&mcocrCHmin.*(365/12))*zchoibrut*&tcrdspre.;
			CSGchd=		(zchoi&anr2.>nb_5*&mcocrCHmin.*(365/12))*zchoibrut*&Tcsgpred.;	
			CSGchi=		(zchoi&anr2.>nb_5*&mcocrCHmin.*(365/12))*zchoibrut*&Tcsgprei.;
			CSGch_MAL=	(zchoi&anr2.>nb_5*&mcocrCHmin.*(365/12))*zchoibrut*&Tcsgpre_mal.;
			CASApr=		(zchoi&anr2.>nb_5*&mcocrCHmin.*(365/12))*zchoibrut*&tcasa.;        /*création en 2013*/
				
			%if  &anleg.>=1998 and &anleg.<=2007 %then %do; 
				if pth=1 then do; 
					%Init_Valeur(CSGchd CSGchi CSGch_MAL);
					end;
				else if pir=1 then do;
			   		CSGchd=		zchoibrut*&Tcsgprd1.;	
			   		CSGchi=		0;
			   		CSGch_MAL=CSGchd;	
					end;
				%end; 
			
			/* Exoneration totale de CSG et CRDS car non imposable à TH */
			%if &anleg.>=1998 %then %do;	
				if exo_csg=1 then do; 
					%Init_Valeur(CSGchd CSGchi CRDSch CRDSch CASApr);
					end;
			%end; 

			END;

		/******************/
		/* C. AGREGATIONS */
		/******************/
		label zchoBRUT="Chômage annuel brut de 20&anr2.";
		zchoBRUT=sum(zchoi&anr2.,CRDSch,CSGchd,COchMAL,COchRE);

		label COchRE=	'cot soc-retraite/chomage'
		      COchMAL=	'Cot soc mal/chômage'
		      CSGchD=	'CSG deduc/chomage'
		      CSGchI=	'CSG impos/chomage'
		 	  CSGch_MAL='CSG maladie/chômage'
			  CASApr ='CASA sur revenu de remplacement'
		      CRDSch=	'CRDS/chomage';
		run;
	%Mend Cotis_Chomeurs_preretraites;
%Cotis_Chomeurs_preretraites;


/************************************************************************************/
/*	IV.	Retraités																	*/
/************************************************************************************/

%Macro Cotis_Retraites; /* Calcul annualisé */
	data Retraites(keep=ident noi zrstBRUT COprMAL CSGprd CSGpr_mal CSGpri CRDSpr casaPR);
		set prof(where=(zrsti&anr2.>0));

		/****************************/
		/* 1	Ancienne profession */
		/****************************/
		ancienne_prof="Non cadre du privé";
		if (csa in ('23','35','37','38')) or (csa='' and substr(p,1,2) in ('23','35','37','38')) or (csa='' and p='' and zrsti&anr2.>30000*&inflat05.) 
			then ancienne_prof="Cadre du privé";
		if (csa in ('33','34','42','43','44','45','52','53')) or (csa='' and substr(p,1,2) in ('33','34','42','43','44','45','52','53'))
			then ancienne_prof="Fonctionnaire";
		if (csa in ('10','11','12','13','21','22','31')) or (csa='' and substr(p,1,2) in ('10','11','12','21','22','31'))
			then ancienne_prof="Indépendant";

		/**********************************************************************************/
		/* 2	Calcul des retraites brutes ZPENU (retraites générales + complémentaires) */
		/**********************************************************************************/
		/* 2.1	Ancien fonctionnaire */
		if ancienne_prof="Fonctionnaire" then do;
			zpenu=	zrsti&anr2./(1-(&tcomaRFonx.+&TcsgPRd1.*(pth=0)*(pir=1) + &TcsgPRd2.*(pth=0)*(pir=0)));
			zpenuG=	zpenu; /* general */
			zpenuC=	0;     /* complementaire */ 
			end;
		/* 2.2	Ancien indépendant */
		else if ancienne_prof="Indépendant" then do; 
			%if &anleg.>=1998 %then %do;
				zpenu=	zrsti&anr2./(1-(&TcsgPRd1.*(pth=0)*(pir=1) + &TcsgPRd2.*(pth=0)*(pir=0)));
				%end; 
			%if &anleg.=1990 %then %do; 
				zpenu=	zrsti&anr2./(1-&tcomaRind.);
				%end; 
			zpenuG=	zpenu;
			zpenuC=	0;
			end;
		/* 2.3	Ancien cadre du privé */
		else if ancienne_prof="Cadre du privé" then do;
			if zrsti&anr2.<=&retrCP_q1. 		then partRetrCompl=&retrCP_t1.;
			else if zrsti&anr2.<=&retrCP_q2. 	then partRetrCompl=&retrCP_t2.;
			else if zrsti&anr2.<=&retrCP_q3. 	then partRetrCompl=&retrCP_t3.;
			else if zrsti&anr2.<=&retrCP_q4. 	then partRetrCompl=&retrCP_t4.;
			else partRetrCompl=&retrCP_t5.;
			zpenu=	zrsti&anr2./(1 - partRetrCompl*&tcomaPR. - (&TcsgPRd1.*(pth=0)*(pir=1) + &TcsgPRd2.*(pth=0)*(pir=0)));
			zpenuG=	zpenu*(1-partRetrCompl); 	/* retraite régime général */
			zpenuC=	zpenu*partRetrCompl;		/* retraite complémentaire */
			end;
		/* 2.4	Ancien non cadre du privé */
 		else if ancienne_prof="Non cadre du privé" then do;
			if zrsti&anr2.<=&retrNCP_q1. 		then partRetrCompl=&retrNCP_t1.;
			else if zrsti&anr2.<=&retrNCP_q2. 	then partRetrCompl=&retrNCP_t2.;
			else if zrsti&anr2.<=&retrNCP_q3. 	then partRetrCompl=&retrNCP_t3.;
			else if zrsti&anr2.<=&retrNCP_q4. 	then partRetrCompl=&retrNCP_t4.;
			else partRetrCompl=&retrNCP_t5.;
			zpenu=	zrsti&anr2./(1 - partRetrCompl*&tcomaPR. - (&TcsgPRd1.*(pth=0)*(pir=1) + &TcsgPRd2.*(pth=0)*(pir=0)));
			zpenuG=	zpenu*(1-partRetrCompl); 	/* retraite régime général */
			zpenuC=	zpenu*partRetrCompl;		/* retraite complémentaire */
			end;

		/****************************************/
		/* 3	Calcul des cotisations sociales */
		/****************************************/
		/* 3.1	Cotisation maladie */
		%if &anleg.=1990 %then %do;
			if ancienne_prof="Fonctionnaire" 	then coprMAL=	zpenu*&tcomaRFonx.;
			else if ancienne_prof="Indépendant" then coprMAL=	min(&ScomaRind*&tcomaRind.,&tcomaRind.*zpenu);
			else									 coprMAL=	zpenug*&tcomaRprinc.+zpenuc*&tcomaPR.;
			%Init_Valeur(csgPRd csgPRi csgPR_mal csgPR);
			%end;
		%if &anleg.=1998 %then %do;
			if ancienne_prof="Fonctionnaire" 	then coprMAL=	zpenu*&tcomaRFonx.;
			else if ancienne_prof="Indépendant" then coprMAL=	&tcomaRind.*zpenu;
			else                 					 coprMAL=	zpenug*&tcomaRprinc.+zpenuc*&tcomaPR.;
			%end;
		%if &anleg.>=2006 %then %do;
			coprMAL=zpenuc*&tcomaPR.*(ancienne_prof not in ("Fonctionnaire","Indépendant"));
			%end;

		/* 3.2	CRDS et CSG */
		crdsPR=zpenu*&tcrdsPR.;
		casaPR=zpenu*&tcasa.;

		/* 	Exonération totale de la CSG et CRDS sur les pensions de retraite et d'invalidité si non imposabilité de la TH (sur RFR N-2 et non N-1 comme sur la TH) avant 2015 et condition sur RFR après
			écart à la législation : Normalement il y a un 2e cas d'exonération pour les bénéficiaires de l'ASPA ou l'ASI (mais on ne peut pas le coder car l'ASPA et l'ASI sont calculés après dans l'enchainement)*/
		%if &anleg.>=1998 %then %do;
			if exo_csg=1 then do; 
				%Init_Valeur(csgPRd csgPRi csgPR_mal crdsPR casaPR);
				end;
		/* 	Exonération partielle de la CSG (si non imposabilité de l'IR à partir de 1998 et si RFR en dessous d'un seuil depuis 2015)
			De la même manière exonération de cotisation à l'assurance maladie si non imposabilité (avant 2015, et depuis condition sur le RFR comme pour la CSG) */
			else if reduc_csg then do;
				csgPRd=		zpenu*&TcsgPRd1.;
		   		csgPRi=		0;
		   		csgPR_mal=	csgPRd;
				coprMAL=	0;
				end;
				/* Cas normal */
			else do;
				csgPRd=		zpenu*&TcsgPRd2.;	
				csgPRi=		zpenu*&TcsgPRi.;
				csgPR_mal=	zpenu*&TcsgPR_mal.;
				end;
			%end;

		label zrstBRUT="Retraite annuelle brute de 20&anr2.";
		zrstBRUT=sum(0,zrsti&anr2.+COprMAL+csgprd+crdsPR);

		label COprMAL=	'Cot soc mal/retraite'
		      CSGprd=	'CSG deduc/retraite'
		      CSGpri=	'CSG impos/retraite'
		 	  CSGpr_MAL='CSG maladie/retraite'
		      CRDSpr=	'CRDS/retraite';
		run;
	%Mend Cotis_Retraites;
%Cotis_Retraites;


/********************************************************************************************************************/
/*	V.	Travailleurs indépendants : régime micro-social (auto-entrepreneurs, devenus micro-entrepreneurs en 2016) 	*/
/********************************************************************************************************************/

/* faute d'éléments suffisant pour repérer correctement les auto-entrepreneurs (ou microentrepreneurs à partir de 2016), 
	on assimile les bénéficiaires du régime micro-fiscal (microbic ou microbnc) aux micro-entrepreneurs (les 2 ont vocation à être fusionnés en 2020).
	Cette approximation est toutefois abusive sur la période de montée en charge du régime micro-social (ie statut auto-entrepreneur, créé en 2009) */

/* On fait donc le choix ici d'appliquer la législation pour le micro-social à partir de 2016 seulement 
	(mise en place du statut de micro-entrepreneur et application pas défaut du régime micro-social pour les bénéficiaires du micro-fiscal */
/* A voir si on l'élargit à des années de législation antérieure */

	data microsocial (keep=ident noi CAbnci&anr2. CAbicventi&anr2. CAbicservi&anr2. COmicrobnc COmicrovent COmicroserv);
		set prof (where=(MicEnt=1));
		COmicrovent=CAbicventi&anr2.*&tcmicrovent. ;
		COmicroserv=CAbicservi&anr2.*&tcmicroserv. ;
		COmicrobnc=CAbnci&anr2.*&tcmicrobnc. ;
		label COmicrovent=	'cot-cont micro-entrepreneur BIC/ventes'
		      COmicroserv=	'cot-cont micro-entrepreneur BIC/serv'
		      COmicrobnc=	'cot-cont micro-entrepreneur BNC' ;
	run ;

/************************************************************************************/
/*	VI.	Bénéfices Non Commerciaux (BNC)	- hors micro-entrepreneurs					*/
/************************************************************************************/

%Macro Cotis_BNC; /* Professions libérales hors régime micro */
	/* Pas de cotisation chômage ni ATMP sur les revenus non commerciaux */

	data BNC (keep=ident noi CObnRE CObnFA CobnMAL CSGbnd CSGbni CSGbn_mal CRDSbn);
		set prof (where=(zrnci&anr1. not in (.,0) and MicEnt=0));
		label exo_csg_coFA="condition pour l exonération de CSG/CRDS et de cotisation sur les allocations familiales"; /*la condition change en 2013*/
		exo_csg_coFA=(&anleg.<2013)*(zrnci&anr1.<12*&bmaf.) + (&anleg.>=2013)*(zrnci&anr1.<&plafondssa.*&seuilexocofaCsgIndP.);

		/*****************************************/
		/* 1	STATUT DE LA PROFESSION LIBERALE */
		/*****************************************/
		MedecinSpecialiste=(p in ('311a','344a','344b'));
		/* Médecins libéraux spécialiste, 
		   Médecins hospitaliers sans activité libérale,
		   Médecins salariés non hospitaliers */
		MedecinGeneraliste=(p in ('311b'));
		/* Médecins libéraux généralistes */
		AutreProfdeSante=(p in ('311c','431d','431f','431g','431e','432b','432d','432a','432c'));
		/* Chirurgiens dentistes, Infirmiers, Sages-femmes, Masseurs-kinésithérapeutes, rééducateurs */

		if acteu6='1' & statut in ('11','12','13') &
			abs(zrnci&anr1.)>abs(zrici&anr1.) & abs(zrnci&anr1.)>abs(zragi&anr1.) then ActivBNCaccessoire=0;
		else ActivBNCaccessoire=1;

		/* Conventionnement secteur 1 et 2 des médecins */
		secteur1=	(AutreProfdeSante or 
					(MedecinGeneraliste and zrnci&anr1.>=&smedecing.) or 
					(MedecinSpecialiste and zrnci&anr1.<=&smedecinspe.));
		secteur2=	(MedecinGeneraliste and zrnci&anr1.<&smedecing.) or (MedecinSpecialiste and zrnci&anr1.>&smedecinspe.);

		/****************************************/
		/* 2	COTISATIONS MALADIE - MATERNITE */
		/****************************************/
		if secteur1      then mcoBN=max(0,zrnci&anr1.)*&tcoma1BN.;
		else if secteur2 then mcoBN=max(0,zrnci&anr1.)*&tcoma2BN.;
		else do;
			if zrnci&anr1.<=&assMinCoMaRsi.*&plafondssa. & ActivBNCaccessoire then mcoBN=max(0,zrnci&anr1.)*&tcoMArsi1.;
			%if &anleg.<=2012 %then %do;
				else if zrici&anr1.<=&plafondssa. 	then mcoBN=max(&assMinCoMaRsi.*&plafondssa.,zrnci&anr1.)*&tcoMArsi1.;
				else mcoBN=&plafondssa.*&tcoMArsi1.+(min(zrnci&anr1.,&assMaxCoMaRsi.*&plafondssa.)-&plafondssa.)*&tcoMArsi2.;
				%end;
			%else %do; /* L'assiette n'est plus plafonnée à partir de 2013. 
						Ecart à la législation :  
						Afin de compenser le déplafonnement de la cotisation maladie mise en place en 2013, la LFSS pour 2013
						avait introduit la réduction dégressive de la cotisation d’assurance maladie pour les travailleurs indépendants disposant
						de faibles revenus à compter de la 3ème année d’activité : c'est non codé dans Ines car possible de détecter quand a eu lieu la 1er année d'activité*/
				else mcoBN=max(&assMinCoMaRsi.*&plafondssa.,zrnci&anr1.)*&tcoMArsi1.; 
				%end;
			end;
			
		
		/*******************************************/
		/* 3	COTISATIONS ALLOCATIONS FAMILIALES */
		/*******************************************/
		%if &anleg.<2015 %then %do;
			if secteur1 then do;
				if zrnci&anr1.<&plafondssa. 		then CObnFA=	max(zrnci&anr1.*&tcoaf1BN.,0);
				else if zrnci&anr1.>=&plafondssa. 	then CObnFA=	&plafondssa.*&tcoaf1BN.+(zrnci&anr1.-&plafondssa.)*&tcoaf2BN.;
				end;
			else do;
			/*écart à la législation avant 2013 : non prise en compte de la 2e conditions pour avoir l'éxonération de cotisation qui est relative à :
			"ceux qui ont assumé la charge d’au moins quatre enfants jusqu’à l’âge de quatorze ans et qui sont âgés d’au moins soixante cinq ans (article R.242-15 du code de la sécurité sociale)."*/
				if exo_csg_coFA then CObnFA=0;
				else do;
					%if &anleg.>=1990 and &anleg.<1998 %then %do; 
						if zrnci&anr1.>&scoaf1BN. and zrnci&anr1.<&scoaf2BN. then CObnFA=zrnci&anr1.*&tcoaf4BN.;
						else 													  CObnFA=&mcoafBN.+(zrnci&anr1.-12*&bmaf.)*&tcoaf3BN.;
						%end;	
					%if &anleg.>=1998 and &anleg.<2008 %then %do;
						CObnFA=&mcoafBN.+(zrnci&anr1.-12*&bmaf.)*&tcoaf3BN.;
						%end;
					%else %if &anleg.>=2008 %then %do;
						CObnFA=zrnci&anr1.*&tcoaf3BN.;
						%end;
					end;
				end;
			%end;
		/*réduction de taux de cotisations d'allocations familiales pour les bas salaire depuis 2015 pour les indépendants*/
		%if &anleg.>=2015 %then %do;
			if zrnci&anr1.<=&smincofaredindP.*&plafondssa. then CObnFA=max(0,zrnci&anr1.*&tcofaredindP.);
			else if zrnci&anr1.<=&smaxcofaredindP.*&plafondssa. then CObnFA=max(0,zrnci&anr1.*(((&tcofaindP.-&tcofaredindP.)/((&smaxcofaredindP.-&smincofaredindP.)*&plafondssa.))*(zrnci&anr1. - &smincofaredindP.*&plafondssa.)+&tcofaredindP.));
			else CObnFA=max(0,zrnci&anr1.*&tcofaindP.);			
			%end;

		/*************************************/		
		/* 4	COTISATIONS INVALIDITE-DECES */
		/*************************************/
		if MedecinGeneraliste or MedecinSpecialiste	then idcoBN=&mcoid1BN.;
		else if AutreProfdeSante then idcoBN=&mcoid2BN.;
		else idcoBN=&mcoid3BN.;
		
		/**************************************/
		/* 5	COTISATIONS VIEILLESSE (base) */
		/**************************************/
		/* 5.1 COTISATIONS de base */
		/* 5.1.a	Cotisations spécifiques aux médecins : avantage social vieillesse (ASV) et accompagnement au départ à la retraite ADR */
		/* ASV */
		if MedecinGeneraliste & secteur1 		then vcoBN=&mcovb1BN.;
		else if MedecinSpecialiste & secteur1  	then vcoBN=&mcovb2BN.;
		else if (MedecinGeneraliste ! MedecinSpecialiste) & secteur2 then vcoBN=&mcovb3BN.;
		else vcoBN=0;

		%if &anleg.>=1990 and &anleg.<=1998 %then %do; 
			if zrnci&anr1.<=&scov1BN. 		then vcoBN=vcoBN*&tcov1BN.;
			else if zrnci&anr1.<=&scov2BN. 	then vcoBN=vcoBN*&tcov2BN.;
			else if zrnci&anr1.<=&scov3BN. 	then vcoBN=vcoBN*&tcov3BN.;
			else vcoBN=vcoBN; 
			%end; 

		/* Ajout de l'ADR */
		%if &anleg.>=1994 %then %do; 
			ADR=0;
			if MedecinGeneraliste or MedecinSpecialiste then ADR=&tcovbmicamedBN.*max(0,zrnci&anr1.);
			%end; 

		/* 5.1.b	Cotisation pour tous les indépendants (yc medecins)	*/
		%if &anleg.=1990 %then %do; 
			if not MedecinGeneraliste or not MedecinSpecialiste then do; 
				vcoBN=&mcocv14BN. ;
                if zrnci&anr1.<=&scov1BN.       then vbcoBN=vcoBN*&tcov1BN.;
                else if zrnci&anr1.<=&scov2BN.  then vbcoBN=vcoBN*&tcov2BN.;
                else if zrnci&anr1.<=&scov3BN.  then vbcoBN=vcoBN*&tcov3BN.;
                else                        		 vbcoBN=vcoBN;
				end;
			%end;	

		%if &anleg.>=1993 and &anleg.<=2007 %then %do; /*pas sur du tout pour le 2007; avant : 1998*/
			if zrnci&anr1.<=&scovminBI. then vbcoBN=max(zrnci&anr1.,0)*&tcovb1BN.;
			else vbcoBN=vbcoBN+&scovminBI.*&tcovb1BN.;
			%end;

		%if &anleg.>=2008 %then %do; 
			if zrnci&anr1.<=&scovBaseminBI.   			then vbcoBN=&scovBaseminBI.*&tcovb1BN.;  /*on prend &scovBaseminBI. car c'est pareil que pour les BIC*/
			else if zrnci&anr1.<=&scovbBN.*&plafondssa. then vbcoBN=zrnci&anr1.*&tcovb1BN.;
			else if zrnci&anr1.>&scovbBN.*&plafondssa.  then vbcoBN=&scovbBN.*&plafondssa.*&tcovb1BN.+(min(zrnci&anr1.,5*&plafondssa.)-&scovbBN.*&plafondssa.)*&tcovb2BN.;
			%end; 

		/* 5.2 COTISATIONS VIEILLESSE (complementaire) */
		if MedecinGeneraliste or MedecinSpecialiste then do;
			%if &anleg.=1990 %then %do;  
				if zrnci&anr1.<=&scocv12BN. 	 then vccoBN=&mcocv12BN.;
				else if zrnci&anr1.<=&scocv13BN. then vccoBN=&mcocv12BN.+&mcocv13BN.*(zrnci&anr1.-&scocv12BN.);
				else 								  vccoBN=&mcocv12BN.+&mcocv13BN.*(&scocv13BN-&scocv12BN.);
				%end; 
			%if &anleg.>=1998 %then %do;
				vccoBN=min(3.5*&plafondssa.,max(0,zrnci&anr1.))*&tcovc1BN.;
				%end;
			end;

		else if AutreProfdeSante then vccoBN=&mcovc2BN.+&tcovc2BN.*min(&scovc3BN.,max(0,zrnci&anr1.-&scovc2BN.));

		else do;
			if      zrnci&anr1.<=&scovc4BN. 	then vccoBN=&mcovc4BN.;
			else if zrnci&anr1.<=&scovc5BN. 	then vccoBN=&mcovc5BN.;
			else if zrnci&anr1.<=&scovc6BN. 	then vccoBN=&mcovc6BN.;
			else if zrnci&anr1.<=&scovc7BN. 	then vccoBN=&mcovc7BN.;
			else if zrnci&anr1.<=&scovc8BN. 	then vccoBN=&mcovc8BN.;
			else if zrnci&anr1.<=&scovc9BN. 	then vccoBN=&mcovc9BN.;
			else if zrnci&anr1.<=&scovc10BN. 	then vccoBN=&mcovc10BN.;
			else if zrnci&anr1.>&scovc10BN. 	then vccoBN=&mcovc11BN.; 
			end;

			/*écart à la législation : la contribution à la formation professionnelle dont bénéficiaient les travailleurs indépendants et ceux relevantdu régime micro social n'est pas codée, 
			de meme donc que l'exonération pour les revenus professionnel non salarié non agricole inférieur à 13% du plafond annuel de la Sécurité sociale, et de meme que la suppression de l'exo en 2015*/
	
		/*************************************/
		/* 6	REGROUPEMENT DES COTISATIONS */
		/*************************************/
		CObnRE=	sum(vbcoBN,vccoBN,vcoBN,ADR);
		CobnMAL=sum(mcoBN,idcoBN);
		
		/********************/
		/* 7	CSG et CRDS */
		/********************/
		/*Arret de l'exonération de CSG/CRDS en 2015 (article 26 de la loi 2014/626 du 18 juin 2014 ACTPE)*/
		%if &anleg.>=2015 %then %do ;
			CSGbnd=		max(0,zrnci&anr1.+CObnRE+CObnFA+CObnMAL)*&TcsgBNd.;
			CSGbni=		max(0,zrnci&anr1.+CObnRE+CObnFA+CObnMAL)*&TcsgBNi.;
			CSGbn_mal=	max(0,zrnci&anr1.+CObnRE+CObnFA+CObnMAL)*&TcsgBN_mal.;
			CRDSbn=		max(0,zrnci&anr1.+CObnRE+CObnFA+CObnMAL)*&tcrdsBN.;			
			%end;
		/* Exonération de CSG/CRDS dont les conditiosn sont similaires à l'exonération de cotisation d'allocations familiales, et meme écart à la législation avant 2013 */
		%if &anleg.>=1991 and &anleg.<2015 %then %do ;
			if exo_csg_coFA then do ;
				CSGbnd=		0;
				CSGbni=		0;
				CSGbn_mal=	0;
				CRDSbn=		0;			
				end;
			else do ; 			
				CSGbnd=		max(0,zrnci&anr1.+CObnRE+CObnFA+CObnMAL)*&TcsgBNd.;
				CSGbni=		max(0,zrnci&anr1.+CObnRE+CObnFA+CObnMAL)*&TcsgBNi.;
				CSGbn_mal=	max(0,zrnci&anr1.+CObnRE+CObnFA+CObnMAL)*&TcsgBN_mal.;
				CRDSbn=		max(0,zrnci&anr1.+CObnRE+CObnFA+CObnMAL)*&tcrdsBN.;			
				end;
			%end;

		label CObnRE=	'cot soc-retraite/BNC'
		      CObnFA=	'cot soc-famille/BNC'
		      CObnMAL=	'Cot soc mal/BNC'
		      CSGbnd=	'CSG deduc/BNC'
		      CSGbni=	'CSG impos/BNC'
			  CSGbn_MAL='CSG maladie/BNC'
		      CRDSbn=	'CRDS/BNC';
		run;
	%Mend Cotis_BNC;
%Cotis_BNC;


/************************************************************************************/
/*	VII.  Bénéfices Industriels et Commerciaux (BIC)- hors micro-entrepreneurs		*/
/************************************************************************************/

%Macro Cotis_BIC; /* Commerçants et artisans */
	/* Pas de cotisation chômage ni ATMP sur les revenus industriels et commerciaux */
	data BIC (keep=ident noi CObiRE CObiFA CobiMAL CSGbid CSGbii CSGbi_mal CRDSbi);
		set prof(where=(zrici&anr1. not in (.,0) and MicEnt=0));
		label exo_csg_coFA="condition pour l exonération de CSG/CRDS et de cotisation sur les allocations familiales"; /*la condition change en 2013*/
		exo_csg_coFA=(&anleg.<2013)*(zrici&anr1.<12*&bmaf.) + (&anleg.>=2013)*(zrici&anr1.<&plafondssa.*&seuilexocofaCsgIndP.);
 
		/****************************************************************/
		/* 1	Statut : artisan, commerçant, ou activité accesoire BIC */
		/****************************************************************/
		artisan=(substr(p,1,2) in ('21','63','68') or csa in ('21','63','68')); /* on rajoute les ouvriers de type artisanal qui déclarent 
		ce type de revenu */
		commercant=1-artisan; /* Par défaut on est commerçant, yc quand ni p ni csa ne sont connues. Il s'agit pour beaucoup de retraites */

		if acteu6='1' & statut in ('11','12','13') &
			abs(zrici&anr1.)>abs(zrnci&anr1.) & abs(zrici&anr1.)>abs(zragi&anr1.) then ActivBICaccessoire=0;
		else ActivBICaccessoire=1;
		
		/****************************************************************/
		/* 2	COTISATIONS MALADIE - MATERNITE - indemnité journalière */
		/****************************************************************/
		/* 2.1 Maladie maternité */
		if zrici&anr1.<=&assMinCoMARsi.*&plafondssa. & ActivBICaccessoire=1 then mcoBI=max(0,zrici&anr1.)*&tcoMArsi1.;
		%if &anleg.<=2012 %then %do;
			else if zrici&anr1.<=&plafondssa. 	then mcoBI=max(&assMinCoMARsi.*&plafondssa.,zrici&anr1.)*&tcoMArsi1.;
			else mcoBI=&plafondssa.*&tcoMArsi1.+(min(zrici&anr1.,&assMaxCoMARsi.*&plafondssa.)-&plafondssa.)*&tcoMArsi2.;
			%end;
		%else %do; 
		/* L'assiette n'est plus plafonnée à partir de 2013. Meme écart à la législation que pour les 
		BNC sur la non prise en compte de la réduction dégressive à partir de la 3e année*/
			else mcoBI=max(&assMinCoMARsi.*&plafondssa.,zrici&anr1.)*&tcoMArsi1.; 
			%end;

		/* 2.2 Indemnités journalières */
		if artisan then do;
			if zrici&anr1.<=&assMinCoMARsiIJ.*&plafondssa. & ActivBICaccessoire=1 then CotisIJ=max(0,zrici&anr1.)*&tcoIJarti.;
			else if zrici&anr1.<=&assMinCoMARsiIJ.*&plafondssa. 	then CotisIJ=&assMinCoMARsiIJ.*&plafondssa.*&tcoIJarti.;
			else CotisIJ=min(zrici&anr1.,&assMaxCoMARsi.*&plafondssa.)*&tcoIJarti.;
			end;
		else if commercant then do;
			if zrici&anr1.<=&assMinCoMARsiIJ.*&plafondssa. & ActivBICaccessoire=1 then CotisIJ=max(0,zrici&anr1.)*&tcoIJcomm.;
			else if zrici&anr1.<=&assMinCoMARsiIJ.*&plafondssa. 	then CotisIJ=&assMinCoMaRsiIJ.*&plafondssa.*&tcoIJcomm.;
			else CotisIJ=min(zrici&anr1.,&assMaxCoMARsi.*&plafondssa.)*&tcoIJcomm.;
			end;
		
		/*******************************************/
		/* 3	COTISATIONS ALLOCATIONS FAMILIALES */
		/*******************************************/
		/*réduction de taux de cotisations d'allocations familiales pour les bas salaire depuis 2015 pour les indépendants*/
		%if &anleg.>=2015 %then %do ;
			if zrici&anr1.<=&smincofaredindP.*&plafondssa. then CObiFA=max(0,zrici&anr1.*&tcofaredindP.);
			else if zrici&anr1.<=&smaxcofaredindP.*&plafondssa. then CObiFA=max(0,zrici&anr1.*(((&tcofaindP.-&tcofaredindP.)/((&smaxcofaredindP.-&smincofaredindP.)*&plafondssa.))*(zrici&anr1. - &smincofaredindP.*&plafondssa.)+&tcofaredindP.));
			else CObiFA=max(0,zrici&anr1.*&tcofaindP.);
			%end;
		/*écart à la législation avant 2013 : non prise en compte de la 2e conditions pour avoir 
			l'éxonération de cotisation qui est relative à :		"ceux qui ont assumé la charge d’au moins 
			quatre enfants jusqu’à l’âge de quatorze ans et qui sont âgés d’au moins soixante cinq ans 
			(article R.242-15 du code de la sécurité sociale)."*/
		%if &anleg.>=2008 and &anleg.<2015 %then %do; 
			if exo_csg_coFA then CObiFA=0;
			else CObiFA=zrici&anr1.*&tcoaf3BN.;
			%end; 
		%if &anleg.>=1998 and &anleg.<2008 %then %do; 
			if zrici&anr1.<=12*&bmaf.     	then CObiFA=0;
			else if zrici&anr1.>12*&bmaf. 	then CObiFA=&mcoaf1BI.+(zrici&anr1.-12*&bmaf.)*&tcoaf3BN.;
			%end; 
		%if &anleg.>=1990 and &anleg.<1998 %then %do; 
			if zrici&anr1.<&scoaf1BN.      	then CObiFA=0;
			else if zrici&anr1.<&scoaf2BN. 	then CObiFA=zrici&anr1.*&tcoafBI.;
			else if zrici&anr1.>=&scoaf2BN. then CObiFA=&mcoaf1BI.+(zrici&anr1.-12*&bmaf.)*&tcoaf3BN.;
			%end; 


		/*************************************/
		/* 4	COTISATIONS INVALIDITE-DECES */
		/*************************************/
		if artisan then do;
			if zrici&anr1.<=&scoIDminBI.      then idcobi=&scoIDminBI.*&tcoIDarti.;
			else idcobi=min(zrici&anr1.,&plafondssa.)*&tcoIDarti.;
			end;
		else if commercant then do;
			%if &anleg.>=1990 and &anleg.<=2007 %then %do; /*pas sur pour le 2007, avant : 1998*/ 
				if zrici&anr1.<=&scoIDminBI.      	then idcobi=0; 
				else if zrici&anr1.>&scoIDminBI.	then idcobi=&mcoinvBI.; 
				%end; 
			%if &anleg.>=2008 %then %do ; 
				if zrici&anr1.<=&scoIDminBI.      then idcobi=&scoIDminBI.*&tcoIDcomm.;
				else if zrici&anr1.<=&plafondssa. then idcobi=zrici&anr1.*&tcoIDcomm.;
				else if zrici&anr1.>&plafondssa.  then idcobi=&plafondssa.*&tcoIDcomm.;
				%end; 
			end;

		/*******************************/
	   	/* 5	COTISATIONS VIEILLESSE */
		/*******************************/
		/* 5.1 COTISATIONS de base */
		if zrici&anr1.<=&scovBaseminBI.   then vbcobi=&scovBaseminBI.*&tcovb1BI.;
		else if zrici&anr1.<=&plafondssa. then vbcobi=zrici&anr1.*&tcovb1BI.;
		else if zrici&anr1.>&plafondssa.  then vbcobi=&plafondssa.*&tcovb1BI.;
		%if &anleg.>=2014 %then %do;
			 if zrici&anr1.>&plafondssa.  then vbcobi=&plafondssa.*&tcovb1BI.+(zrici&anr1.-&plafondssa.)*&tcovb2BI.;	
			 %end;
		 /*écart à la législation : 5,25% du PSS sans pouvoir être inférieure à 200 Smic hoaires en 2014 
			 et 7,7% du PSS sans pouvoir être inférieure à 300 Smic horaires en 2015 : ces conditions ne sont pas codées*/

		/* 5.2 COTISATIONS VIEILLESSE (complementaire) */
		%if &anleg.<2013 %then %do;
			if artisan then do;
				if zrici&anr1.<=&scovminBI.      then vccobi=&scovminBI.*&tcoVCarti.;
				else if zrici&anr1.<=4*&plafondssa. then vccobi=zrici&anr1.*&tcoVCarti.;
				else if zrici&anr1.>4*&plafondssa.  then vccobi=4*&plafondssa.*&tcoVCarti.;
				end;
			else if commercant then do;
				%if &anleg.=1990 or &anleg.=1998 %then %do; 
					if zrici&anr1.<=&scovminBI.      	then vccobi=&scovminBI.*&tcoVCcomm.;
					else if zrici&anr1.<=3*&plafondssa. then vccobi=zrici&anr1.*&tcoVCcomm.;
					else if zrici&anr1.<=&plafondssa. 	then vccobi=3*&plafondssa.*&tcoVCcomm.+(zrici&anr1.-3*&plafondssa.)*&tcovc3BI.;
					else if zrici&anr1.>&plafondssa.  	then vccobi=3*&plafondssa.*&tcoVCcomm.+(&plafondssa.-3*&plafondssa.)*&tcovc3BI.;
					%end;
				%if &anleg.>=2008 %then %do; 
					if zrici&anr1.<=&scovminBI.      	then vccobi=&scovminBI.*&tcoVCcomm.;
					else if zrici&anr1.<=3*&plafondssa. then vccobi=zrici&anr1.*&tcoVCcomm.;
					else if zrici&anr1.>3*&plafondssa.  then vccobi=3*&plafondssa.*&tcoVCcomm.;
					%end; 
				end;
			%end;
		%else %if &anleg.>=2013 %then %do; /* Fusion des régimes complémentaires en 2013 */
			if zrici&anr1.<=&scovminBI.      	then vccobi=&scovminBI.*&tcoVCrsi1.;
			else if zrici&anr1.<=&plafondssa. 	then vccobi=zrici&anr1.*&tcoVCrsi1.;
			else vccobi=&plafondssa.*&tcoVCrsi1.+(min(zrici&anr1.,4*&plafondssa.)-&plafondssa.)*&tcoVCrsi2.;
			%end;

		/*************************************/
		/* 6	Regroupement des cotisations */
		/*************************************/
		CObiRE=	sum(vbcobi,vccobi);
		CobiMAL=sum(mcoBI,idcobi,CotisIJ);
		
		/********************/
		/* 7	CSG et CRDS */
		/********************/
		/*Arret de l'exonération de CSG/CRDS en 2015 (loi 2014/626 du 18 juin 2014 ACTPE)*/
		%if &anleg.>=2015 %then %do ;
			CSGbid=		max(0,sum(zrici&anr1.,CObiRE,CObiFA,CObiMAL))*&TcsgBId.;
			CSGbii=		max(0,sum(zrici&anr1.,CObiRE,CObiFA,CObiMAL))*&TcsgBIi.;
			CSGbi_mal=	max(0,sum(zrici&anr1.,CObiRE,CObiFA,CObiMAL))*&TcsgBI_mal.;
			CRDSbi=		max(0,sum(zrici&anr1.,CObiRE,CObiFA,CObiMAL))*&tcrdsBI.;			
			%end;
		/* Exonération de CSG/CRDS similaire à l'exonération de cotisation d'allocations familiales, et meme écart à la législation avant 2013 */
		%if &anleg.>=1991 /*et 1996 pour la CRDS*/ and &anleg.<2015 %then %do; 
			if exo_csg_coFA then do ;
				CSGbid=		0;
				CSGbii=		0;
				CSGbi_mal=	0;
				CRDSbi=		0;
				end;
			else do ;
				CSGbid=		max(0,sum(zrici&anr1.,CObiRE,CObiFA,CObiMAL))*&TcsgBId.;
				CSGbii=		max(0,sum(zrici&anr1.,CObiRE,CObiFA,CObiMAL))*&TcsgBIi.;
				CSGbi_mal=	max(0,sum(zrici&anr1.,CObiRE,CObiFA,CObiMAL))*&TcsgBI_mal.;
				CRDSbi=		max(0,sum(zrici&anr1.,CObiRE,CObiFA,CObiMAL))*&tcrdsBI.;
				end;
			%end; 

		label COBIRE=	'cot soc-retraite/BIC'
		      COBIFA=	'cot soc-famille/BIC'
		      CObiMAL=	'Cot soc mal/BIC'
		      CSGBId=	'CSG deduc/BIC'
		      CSGBIi=	'CSG impos/BIC'
			  CSGbi_MAL='CSG maladie/BIC'
		      CRDSBI=	'CRDS/BIC';
		run;
	%Mend Cotis_BIC;
%Cotis_BIC;


/************************************************************************************/
/*	VIII.	Bénéfices Agricoles (BA)												*/
/************************************************************************************/

%Macro Cotis_BA;
	/* Pas de cotisation chômage ni ATMP sur les revenus agricoles */
	data Agriculteurs (keep=ident noi CObaRE CObaFA CobaMAL CSGbad CSGbai CSGba_MAL CRDSba);
		set prof (where=(zragi&anr1. not in (.,0)));
		/* A	Estimation pour 1990 */
		/*****************************/
		%if &anleg.=1990 %then %do; 
			if zragi&anr2.<0					then coba=&agri_para1.;
			else if zragi&anr1.<&agri_plaf1.    then coba=&agri_para2.;
			else if zragi&anr1.<&agri_plaf2.    then coba=&agri_para3.;
			else if zragi&anr1.<&agri_plaf3.    then coba=&agri_para4.;
			else if zragi&anr1.<&agri_plaf4.    then coba=&agri_para5.;
			else if zragi&anr1.<&agri_plaf5.    then coba=&agri_para6.;
			else if zragi&anr1.<&agri_plaf6.    then coba=&agri_para7.;
			else if zragi&anr1.<&agri_plaf7.    then coba=&agri_para8.;
			else if zragi&anr1.<&agri_plaf8.    then coba=&agri_para9.;
			else if zragi&anr1.>&agri_plaf8.    then coba=&agri_para10.;
			CObaFA=0;
			CObaRE=coba*0.3;
			CObaMAL=coba*0.7;
			%end; 

		/* B	Calcul des cotisations à partir de 1998 */
		/*************************************************/
		%if &anleg.>=1998 %then %do;
			/****************************************************************************/
			/* 1	Statut de la personne: métier principal, secondaire, aide familiale */
			/****************************************************************************/
			if statut='13' & (p=:'1' ! substr(p,1,2)='69') then aidfam1=1;
			else if statut in ('11','12') & (p=:'1' ! substr(p,1,2)='69') then chef1=1;
			else acba1=1; /* chef d'exploitation à titre secondaire */
			
			/************************************************/
			/* 2	le ratio SMI (taille de l'exploitation) */
			/************************************************/
			if substr(p,1,2)='13'		then smi=1;
			else if substr(p,1,2)='12'	then smi=2;
			else if substr(p,1,2)='11'	then smi=3;
			else if chef1=1				then smi=2;
			else if acba1=1				then smi=2;
			else 							 smi=1;

			/***************************************************************************/
			/* 3	COTISATIONS AMEXA maladie-maternité-invalidité (et complémentaire) */
			/***************************************************************************/
			/* 	3.1 chef d'exploitation ou d'entreprise agricole */
			if zragi&anr1.<=&scoax1BA. 		then CobaMAL=&scoax1BA.*&ttamexa.;
				else if zragi&anr1.<=&scoax2BA. then CobaMAL=zragi&anr1.*&ttamexa.;
				else if zragi&anr1.>&scoax2BA.	then CobaMAL=&scoax2BA.*&ttamexa.;
			CobaMAL=max(CobaMAL,(&mcoax1BA.*(smi=1)+&mcoax2BA.*(smi=2)+&mcoax3BA.*(smi=3)));

			%if &anleg.>=2008 %then %do;
				if zragi&anr1.<=&assamexa. then CobaMAL=&assamexa.*&ttamexa.;
					else CobaMAL=zragi&anr1.*&ttamexa.;
				if zragi&anr1.<=&assamexa_inv. then CobaINV=&assamexa_inv.*&ttamexa_inv.;
					else CobaINV=zragi&anr1.*&ttamexa_inv.;
				%end;

			/* 	3.2 si chef d'exploitation à titre secondaire */        		
			if acba1 then do ; 
				CobaMAL=CobaMAL*&ttamexasec./&ttamexa. + &partcamexasec.;
				CobaINV=0 ;
				end ;

			/*	3.4 pour les aides familiaux de plus de 18 ans */
			else if aidfam1 then do ;
				CobaMAL=min((CobaMAL*&partaidamexa.), &plafaidamexa.);
				CobaINV=min((CobaINV*&partaidamexa.), &plafaidamexa_inv.); ;
				end ;

			CobaMAL=sum(CobaMAL,CobaINV) ;
			
			/*************************************************/	
			/* 4	COTISATIONS PFA - allocations familiales */
			/*************************************************/	
			CObaFA=max(0,zragi&anr1.*&tafba.);
			/*réduction de taux de cotisations d'allocations familiales pour les bas salaire depuis 2015 pour les indépendants*/
			%if &anleg.>=2015 %then %do ;
				if zragi&anr1.<=&smincofaredindP.*&plafondssa. then CObaFA=max(0,zragi&anr1.*&tcofaredindP.);
				else if zragi&anr1.<=&smaxcofaredindP.*&plafondssa. then CObaFA=max(0,zragi&anr1.*(((&tcofaindP.-&tcofaredindP.)/((&smaxcofaredindP.-&smincofaredindP.)*&plafondssa.))*(zragi&anr1. - &smincofaredindP.*&plafondssa.)+&tcofaredindP.));
				else CObaFA=max(0,zragi&anr1.*&tcofaindP.);
				%end;
			
			/***************************************************/
			/* 5	COTISATIONS invalidité- décès : voir axema */
			/***************************************************/

			/******************************/
			/* 6	COTISATIONS VIELLESSE */
			/******************************/
			/* 6.1 Cotisations AVA (Assurance vieillesse agricole) plafonnée */
			if acba1 & statut in('11','12') then do; 
				%if &anleg.>=2008 %then %do;
					vpcoba=&cotforfava.;
					%end;
				%else %if &anleg.>=1998 and &anleg.<=2007 %then %do;
					if zragi&anr1.<=&plafondssa. then vpcoba=max(zragi&anr1.*&tpava.,0);
					%end;
				%else %if &anleg.=1988 %then %do;
					if zragi&anr1.>&plafondssa. then vpcoba=&plafondssa.*&tpava.; 
					%end;
				end;
			else do;
				if zragi&anr1.<=&assava.*&smich. 	then vpcoba=&assava.*&smich.*&tpava.; 
				else if zragi&anr1.<=&plafondssa. 	then vpcoba=zragi&anr1.*&tpava.; 
				else if zragi&anr1.>&plafondssa.  	then vpcoba=&plafondssa.*&tpava.; 
				end;
			/* 6.2 Cotisations AVA (Assurance vieillesse agricole) déplafonnée */
			%if &anleg.>=2001 %then %do; 
				if acba1 & statut in('11','12') then vdcoba=0; /* exoneration a compter 2001 */
				else do;
					if zragi&anr1.<=&assava.*&smich. then vdcoba=&assava.*&smich.*&tdava.;
					else vdcoba=zragi&anr1.*&tdava.;
					end;
				%end; 
			%if &anleg.=1998 %then %do; 
				if acba1 & statut in('11','12') then vdcoba=max(zragi&anr1.*&tdava.,0); 
				else do;
					if zragi&anr1.<=&assava.*&smich. then vdcoba=&assava.*&smich.*&tdava.;
					else vdcoba=zragi&anr1.*&tdava.;
					end;
				%end;
			/* 6.3 Cotisations AVI :Assurance Vieillesse individuelle (retraite forfaitaire)*/
			if zragi&anr1.<=&assavi.*&smich. 	then vicoba=&assavi.*&smich.*&tavi.;
			else if zragi&anr1.<=&plafondssa. 	then vicoba=zragi&anr1.*&tavi.;
			else if zragi&anr1.>&plafondssa.  	then vicoba=&plafondssa.*&tavi.;
			/* 6.4 Retraite complémentaire obligatoire (RCO) */
			/* A partir de 2003 pour les chefs d'exploitations et d'entreprises agricoles, 2011 pour les collaborateurs */
			if aidfam1 then rco=&trco_collab.*(max(&assrco_collab.*&smich.,zragi&anr1.));
			else if (acba1 & statut in('11','12')) or chef1 then rco=&trco_chef.*(max(&assrco_chef.*&smich.,zragi&anr1.));
			else rco=0;

			/*******************************/
			/* 7	TOUTES LES COTISATIONS */
			/*******************************/
			CObaRE=sum(vpcoba,vdcoba,vicoba,rco);
			%end;
		
		/*************************/
		/* 8	CSG  et CRDS 	 */
		/*************************/
		csgbai=		max(0,sum(zragi&anr1.,CObaRE,CObaFA,CobaMAL))*&tcsgbai.;
		csgbad=		max(0,sum(zragi&anr1.,CObaRE,CObaFA,CobaMAL))*&tcsgbad.;
		csgba_MAL=	max(0,sum(zragi&anr1.,CObaRE,CObaFA,CobaMAL))*&tcsgba_MAL.;
		crdsba=		max(0,sum(zragi&anr1.,CObaRE,CObaFA,CobaMAL))*&tcrdsba.;

		label CObaRE='cot soc-retraite/BA'
		      CObaFA='cot soc-famille/BA'
		      CObaMAL='Cot soc mal-inv/BA'
		      CSGbAd='CSG deduc/BA'
		      CSGbAi='CSG impos/BA'
			  CSGba_MAL='CSG maladie-inv/BA'
		      CRDSBA='CRDS/BA';
		run;
	%Mend Cotis_BA;
%Cotis_BA;

/************************************************************************************/
/*	IX.		Traitements finaux 														*/
/************************************************************************************/

/* Création de la table modele.cotis */
data modele.cotis;
	merge 	Salaries (in=a)
			Chomeurs_preretraites (in=b)
			Retraites (in=c)
			BNC (in=d)
			BIC (in=e)
			Agriculteurs (in=f)
			microsocial (in=g)
			prof (keep=	ident noi MicEnt
						p statut hor temps cst2 pir pth /* info nécessaire pour la suite même si not a */
						nbmois_cho /* info nécessaire même si not b car ce sont des chômeurs non indemnisés */
						zsali&anr2. zchoi&anr2. zrsti&anr2. zrnci&anr1. zrici&anr1. zragi&anr1. zrnci&anr2. zrici&anr2.); 
	by ident noi;

	if not a then do;
		%Init_Valeur(zsalbrut exo exo_app exo_BasSal exo_heursup COtsCHs COtsCHp COtsAGSp COtsRES_bpl COtsRES_bdepl COtsRES_compl COtsREs COtsREp
				ContribExcSol COtsTAXp COtsFA COtsACP COtsMAL_SAL COtsMAL_PAT COtsS COtsP CSGtsD CSGtsI CSGts_MAL CRDSts sftna sftba cice taxe_salaire taxe_75);
		end;
	if not b then do;
		%Init_Valeur(zchoBRUT COchRE COchMAL CSGchI CSGchD CSGch_MAL CRDSch);
		end;
	if not c then do;
		%Init_Valeur(zrstBRUT COprMAL CSGprd CSGpr_mal CSGpri CRDSpr casapr);
		end;
	if not d then do;
		%Init_Valeur(CObnRE CObnFA CobnMAL CSGbnd CSGbni CSGbn_mal CRDSbn);
		end;
	if not e then do;
		%Init_Valeur(CObiRE CObiFA CobiMAL CSGbid CSGbii CSGbi_mal CRDSbi);
		end;
	if not f then do;
		%Init_Valeur(CObaRE CObaFA CobaMAL CSGbad CSGbai CSGba_MAL CRDSba);
		end;
	if not g then do;
		%Init_Valeur(CAbnci&anr2. CAbicventi&anr2. CAbicservi&anr2. COmicrobnc COmicrovent COmicroserv Micent);
		end;

	/* Agrégation des cotisations de tous les régimes */
	coTAXp=	COtsTAXp;
	coMicro=COmicrobnc+COmicrovent+COmicroserv;
	coMALs=	COBAMAL+COchMAL+COBIMAL+CObnMAL+COprMAL+COtsMAL_sal;
	coMALp=	COtsMAL_pat;
	coFAs=	CObaFA+COBIFA+CObnFA;
	coFAp=	COtsFA;
	coACp=	COtsACP;
	coCHs=	COtsCHS;
	coCHp=	COtsCHP;
	coAGSp=	COtsAGSP;
	coREs=	COBARE+COchRE+COBIRE+CObnRE+CotsREs;
	coREp=	COtsREp;
	csgd=	csgbad+csgbid+csgbnd+csgchd+csgtsd+csgprd; 	/* csg deductible sur revenus individuels */
	csgi=	csgbai+csgbii+csgbni+csgchi+csgtsi+csgpri; 	/* csg imposable=non deductible sur revenus individuels */
	csg_mal=csgba_mal+csgbi_mal+csgbn_mal+csgch_mal+csgts_mal+csgpr_mal; /* CSG affectee a la maladie */
	crdsi=	crdsba+crdsbi+crdsbn+crdsch+crdsts+crdspr;/* crds imposable sur revenus individuels */

	array agregat coTAXp coMALs coMALp coFAs coFAp coACp coCHs coCHp coAGSp coREs coREp coMicro csgd csgi csg_mal crdsi;
	do over agregat;
		if agregat=. then do;
			ERROR "Il y a une erreur de cotisation/contribution manquante";
			abort cancel;
			end;
		end;
	run;


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
