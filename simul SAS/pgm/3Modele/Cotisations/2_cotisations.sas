/************************************************************************************/
/*																					*/
/*								2_cotisations										*/
/*																					*/
/************************************************************************************/
/*																					*/
/* Calcul des pr�l�vements sociaux obligatoires assis sur les revenus du travail.	*/
/* + autres pr�l�vements (taxe sur les salaires, taxe � 75%) et subventions (CICE)	*/
/* pay�s par l'entreprises mais assis sur la masse salairiale						*/
/* Calcul du suppl�ment familial de traitement pour les fonctionnaires.				*/
/************************************************************************************/
/* En entr�e : 	modele.baseind														*/
/*				base.baserev														*/
/*				base.baseind														*/
/*				modele.impot_sur_rev&anr.											*/
/* En sortie :  modele.cotis														*/
/************************************************************************************/
/*	PLAN :																			*/
/*	I.	Traitements pr�alables														*/
/*	II.	Salari�s																	*/
/*		1	Taux de cotisations														*/
/*		2 	Suppl�ment familial de traitement										*/
/*		3	Des plafonds bruts au plafonds "�quivalent d�clar�"						*/
/*		4	Calcul du salaire brut													*/
/*		5 	Calcul des cotisations � proprement parler								*/
/*		6   Arr�ts maladie															*/
/*		7	Exon�rations du r�gime g�n�ral											*/
/*			7.1	Exo heures sup' sur cotisations salariales							*/
/*			7.2	Exo heures sup' sur cotisations patronales							*/
/*			7.3	Exo bas salaires													*/
/*			7.4	CICE																*/
/*			7.5 Apprentis															*/
/*		8 Taxe sur les salaires														*/
/*		9 Regroupement des cotisations												*/
/*	III.Ch�meurs et preretrait�s													*/
/*	IV.	Retrait�s																	*/
/*	V.	Travailleurs ind�pendants : r�gime micro-social (micro-entrepreneurs)		*/
/*	VI.	BNC	(hors micro-social)														*/
/*	VII.BIC (hors micro-social)														*/
/*	VIII. BA																		*/
/*	IX.	Traitements finaux 															*/
/************************************************************************************/

%global smichnet smic_brut;
/* Moyenne annuelle du SMIC horaire net de l'ann�e n */
%let smichnet=%sysevalf(&smich.*(1-(&tcomaRG_S.+&tcoviRG_deplaf_S.+&tcoviRG_plaf_S.+&tcoasRG_S.+&tcoarRG1_S.+&Tcsgd.)));
/* Moyenne annuelle du SMIC brut mensuel de l'ann�e n */
%let smic_brut =%sysevalf(&smich.*&tpstra.*52/12);


/************************************************************************************/
/*	I.	Traitements pr�alables														*/
/************************************************************************************/

%Macro Cotis_Prepa;

	/* 1	Rep�rage de qui est non imposable sur le revenu (derni�re d�claration si plusieurs dans l'ann�e)
	et qui est non taxable d'habitation */

	proc sort data=base.baseind(keep=declar1 ident noi naia quelfic acteu6 naia cal0) out=baseind; by declar1; run;
	proc sort data=modele.impot_sur_rev&anr.(keep=declar impot6 npart RFR rename=(declar=declar1 impot6=impot)) out=impot; by declar1; run;
	/*La condition d'exon�ration de TH s'applique � une RFR sur l'ann�e pr�c�dente alors que la condition d'exon�ration de CSG pour revenus
	 de remplacement s'applique au RFR sur l'avant derni�re ann�e, donc on fait la manip suivante pour prendre les param�tres d�cal�s
	cf http://bofip.impots.gouv.fr/bofip/5738-PGP.html pour TH et https://www.service-public.fr/particuliers/vosdroits/F2971 */
	%CreeParametreRetarde(th_lim2_lag1,dossier.th,th_lim2,Ines,&anleg.,1);
	%CreeParametreRetarde(th_lim2_pac_lag1,dossier.th,th_lim2_pac,Ines,&anleg.,1);
	%CreeParametreRetarde(seuilcofaredRGP_lag1,dossier.Param_soc,seuilcofaredRGP,Ines,&anleg.,1);/*r�forme en avril 2016 : modification de taux*/
	data impot_ind;
		merge	baseind(in=a)
				impot; 
		by declar1;
		if a;
		label pth="Sous seuil d'exon�ration de TH"; /* Indicatrice */ /*attention li� au RFR de N-2 car on s'en sert pour l'exo de CSG donc diff�rent de l'exo de TH, cf. commentaire ci dessus */
		pth=0;
		%if &anleg.>1998 %then %do; /* Art 136-8 du CSS */
			if RFR<&th_lim2_lag1.*(npart>0)+&th_lim2_pac_lag1.*2*max(0,npart-1) then pth=1;
			%end;
		label pir="Sous seuil d'exon�ration de l'IR";
		pir=(impot<&p0960.);
		label reduc_csg="condition pour le taux r�duit de CSG sur les revenus de remplacement"; /*la condition change en 2015*/
		reduc_csg=(&anleg.<2015)*pir + (&anleg.>=2015)*(RFR<&plaf_csg_remp.*(npart>0)+&plaf_csg_remp_pac.*4*max(0,npart-1));
		label exo_csg="condition pour l'exon�ration de CSG sur les revenus de remplacement"; /*la condition change en 2015*/
		exo_csg=(&anleg.<2015)*pth + (&anleg.>=2015)*(RFR<&exo_csg_remp.*(npart>0)+&exo_csg_remp_pac.*4*max(0,npart-1));
		if quelfic='EE_NRT' then do;/* Exon�ration par d�faut des EE_NRT */
			pir=1;
			pth=1;
			end;
		run;

	/* 2	R�cup�ration du chiffre d'affaires de l'ann�e en cours pour les ind�pendants soumis au r�gime micro-fiscal */
	/* (les agr�gats zrnci, zrici et zragi issus de l'ERFS repr�sentent les revenus professionnels (b�n�fices), apr�s abattement pour charges si micro-fiscal ;
		ils correspondent bien � l'assiette des cotisations pour les non-salari�s "classiques" ;
		mais ce n'est pas la bonne assiette pour les auto-entrepreneurs, pour lesquels des taux forfaitaires sont appliqu�s directement au CA.) 
		Note : le r�gime micro-social ne concerne pas les exploitants agricoles */

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

	/* 3	Modification des informations sur l'activit� pour certains cas sp�ciaux */
	proc sort data=impot_ind 
		(keep=ident noi impot pth pir reduc_csg exo_csg acteu6 naia cal0) 
		out=impot_ind nodupkey; by ident noi; run; /* On retire d'�ventuels doublons de baseind */
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
		/* Indicatrice de micro-entrepreneur ; on assimile micro-fiscal � micro-social � partir de 2016 */
		MicEnt=(&anleg.>=2016)*(CAbicventi&anr2.+CAbicservi&anr2.+CAbnci&anr2.>0) ;
		run;
	%Mend Cotis_Prepa;
%Cotis_Prepa;


/************************************************************************************/
/*	II.	Salari�s																	*/
/************************************************************************************/

%Macro Cotis_Salaries;
	data Salaries (keep=ident noi zsalbrut COtsCHs COtsCHp COtsAGSp COtsREs COtsREp COtsFA
			 	COtsMAL_SAL COtsMAL_PAT ContribExcSol COtsTAXp COtsACP COtsS COtsP CSGtsD CSGtsI CSGts_MAL CRDSts
				exo exo_BasSal exo_heursup exo_app sftba sftna: pop1 COtsRES_bpl COtsRES_bdepl COtsRES_compl CICE taxe_salaire taxe_75);
		set prof (where=(zsali&anr2.-hsup&anr2.>1));
		/* Il arrive que des d�clarations ne mentionnent que des heures sup et pas de salaire de base,
		ce qui est possible dans la mesure d'un retard de paye de l'employeur. Dans ce cas, on ne veut pas calculer les cotisations salariales. */

		if nbmois_sal=0 then nbmois_sal=12; /* Lissage sur les 12 mois en cas d'absence d'information plus pr�cise. C'est 
		coh�rent avec la trimestrialisation des ressources.*/

		/************************************************************************************************************/
		/* Variables interm�diaires : d�finition des diff�rentes sous-populations 									*/
		/* On d�finit 	- un premier niveau (pop1) : FPT, FPNT ou RG												*/
		/*				- un deuxi�me niveau pour la FPT (pop2) : collectivit�s territoriales ou h�pital, ou non	*/
		/*				- un troisi�me niveau pour FPT et FPNT (pop3) : en fonction de la qualification 			*/
		/************************************************************************************************************/
		length pop1 $4. pop2 $3. pop3 $2. pop $7.;
		
		if statut='45' then do;
			pop1="FPT";							/* Fonctionnaires titulaires */
			if pub3fp in('2','3') then 	pop2="CLH"; 	/* Collectivit�s locales ou h�pital // TODO la s�paration pourrait �tre utile pour s�parer la cotisation FCCPA et FEH */
			else 						pop2="Aut"; 	/* Autres FPT */
			end;
		else if contractuel=1	then pop1="FPNT";	/* Fonctionnaires non titulaires */
		else pop1="RG";							/* Salari�s du r�gime g�n�ral */
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

		/* Calcul du salaire mensuel d�clar� */
		if hsup&anr2.=. then hsup&anr2.=0;
		%Init_Valeur(hsupm hsupm_eqDecl prohsup);
		if nbmois_sal>0 then do;
			HSupM=hsup&anr2./nbmois_sal; 							/* R�muneration heures sup mensuelle nette */
			HSupM_eqDecl=HSupM/(1-&Tcsgi.-&Tcrds.);			/* En �quivalent d�clar� (ajout CSG imposable et CRDS) */
			zsali_m=((zsali&anr2.+part_salar&anr2. - part_employ&anr2.)/nbmois_sal)-HSupM+HSupM_eqDecl;	
			/* Salaire mensuel d�clar� (yc heures sup). 
			On inclut aussi la part salariale pour les contrats collectifs obligatoires (pas la part employeur, exon�r�e
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
			- initialisation � 0 de tous les taux (pas de valeurs manquantes pour les besoins de la suite)
			- ces taux prennent la valeur de diff�rentes macro-variables en fonction du r�gime (FPT, FPNT ou RG), gr�ce � la fonction symgetn */

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
		/*�cart � la l�gislation : 
		la cotisation patronale vieillesse pour les titulaires de la fonction publique territoriale + hospitali�re n'est pas s�par�e 
		entre FCCPA et FEH (on prend une moyenne entre les deux taux) pour plus de simplicit� (les taux sont faibles)*/
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

		/* Solidarit� */
		if pop1 in ("FPT" "FPNT") then tcosoS=	symgetn(compress('tcoso'!!pop1!!'_S'))*(zsali_m>=&plafsoli.);

		/* Transport */
		if pop1 in ("FPT" "FPNT") then tcodiP=	symgetn(compress('tcotr'!!pop1!!'_P'));

		/* Accident */
		if pop1 in ("FPNT" "RG") then tcoaccP=	symgetn(compress('tcoacc'!!pop1!!'_P'));

		/* Retraites compl�mentaires */
		if pop1="FPNT" then do; /* IRCANTEC */
			/* TcoarP=	&TcoarFPNT_P.; */  /* Ne sert pas pour le moment */
			/* TcoagbP=&TcoagbFPNT_P.; */  /* Ne sert pas pour le moment */
			end;

		/* Taxes */
		if pop1="RG" then do;
			/* taxeprem= &taxepremrg.*(effi>=10); */  /* Ne sert pas pour le moment */
			ttaxP=	sum(&taxeaprerg.,
						&contribSyndicatRG_P., /*c'est une contribution patronale, mais on le met ici par commodit�*/
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

			/* R�f�rence temps plein 18 h pour les enseignants du secondaire et du sup�rieur */
			if p in ('341a','342a','422b','422c') & temps='partiel' & hor<&ORS_ens_sec. then DurTPlein=&ORS_ens_sec.;
			/* R�f�rence temps plein 26 h pour les enseignants du primaire, CPE, surveillants ... */
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
		/* 3	Calcul du PASS sur du salaire d�clar� */
		/**********************************************/
		%Init_Valeur(SftMni);
		if pop1="FPT" then do;
			SftMni=	SftB*(1-&Tcsgd.-tcosos);
			pfd_4=	(4*&plafondssa./12-SftB)*((1-(1-tprim)*tcoviS)*(1-TcosoS)- &Tcsgd.) + SftMni; /* TODO : retrouver la r�f�rence l�gale sur le pfd_4 */
			end;

		else if pop1="FPNT" then do;
			pfd_1=	&plafondssa./12*((1-tcomaS-tcoviS-&TcoarFPNT_S.)*(1-TcosoS)-&Tcsgd.);					/* Sous le plafond */
			pfd_4=	pfd_1+3*&plafondssa./12*((1-tcomaS-tcoviS_deplaf-&TcoagbFPNT_S.)*(1-TcosoS)- &Tcsgd.);	/* Entre 1 et 4 pfd */			
			pfd_8=	pfd_4+4*&plafondssa./12*(1-tcomaS-tcoviS_deplaf-&TcoagbFPNT_S.-&Tcsgd.); 				/* Entre 4 et 8 pfd */
			end;

		else if pop1="RG" then do; /* Taux synth�tiques + plafond �quivalent d�clar�, pour les cadres et non cadres. */
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
			/* Sup�rieur � 8 pfd */
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
			- initialisation � 0 de tous les montants de cotisations (pas de valeurs manquantes pour les besoins de la suite)
			- formules communes � tous les r�gimes autant que possible, les taux ayant �t� mis � z�ro plus haut */

		%Init_Valeur(	ComaS ComaP	CofaP CoviS CoviP CofnP	taxP CoacP CoveS CorcS CorcP CoasS CoasP CocetS CocetP
					CoprevP CoSoS csgtsdM csgtsiM crdstsM CSGts_malM);

		/* Maladie */
		COmaS=salbrut*tcomaS;
		COmaP=salbrut*tcomaP*(1-tprim*(pop1="FPT"));

		/* Famille */
		COfaP=salbrut*tcofaP*(1-tprim*(pop1="FPT"));
		/*r�duction de taux de cotisation d'allocations familiales pour les bas salaire depuis 2015*/
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
					/*on proratise en faisant comme si la personne a travaill� tous les mois de mani�re identique*/
					end;
				end;
			%end;

		/* Accident du travail */
		coacP=salbrut*tcoaccP*(pop1 in ("FPNT" "RG"));

		/* Vieillesse */
		COviS=	(pop1="FPT")*	(salbrut-sftb)*(1-tprim)*tcoviS 
				+(pop1="FPT")*	min((salbrut-sftb)*(tprim),&plafRAFP.*(salbrut-sftb)*(1-tprim))*&tRAFP_S. 
				/*Le plafond de l�assiette est de 20 % du traitement indiciaire brut total*/
				+(pop1="FPNT")*	min(salbrut,&plafondssa./12)*&tcoviFPNT_plaf_S.
				+(pop1="RG")*	min(salbrut,&plafondssa./12)*&tcoviRG_plaf_S.;
		COviP=	(pop1="FPT")*	salbrut*(1-tprim)*0   /*normalement il faudrait mettre tcoviP (qui correspond � tcoviFPTAut_P)
		mais comme l'Etat ne paye pas directement de cotisations, c'est un taux implicite tr�s �lev� qu'on ne souhaite pas mettre*/
				+(pop1="FPT")*	min((salbrut-sftb)*(tprim),&plafRAFP.*(salbrut-sftb)*(1-tprim))*&tRAFP_P. 
				+(pop1="FPNT")*	min(salbrut,&plafondssa./12)*&tcoviFPNT_plaf_P.
				+(pop1="RG")*	(min(salbrut,&plafondssa./12)*&TcoviRG_plaf_P. + salbrut*&TcoviRG_deplaf_P.);

		/* Veuvage */
		COveS= (pop1='FPNT')* 	salbrut*&tcoviFPNT_deplaf_S.
				+(pop1='RG')*	salbrut*&tcoviRG_deplaf_S.;

		/* Retraite compl�mentaire */
		corcS=(pop1="FPNT")*	(min(salbrut,&plafondssa./12)*&TcoarFPNT_S.
								+(salbrut>&plafondssa./12)*min(7*&plafondssa./12,salbrut-&plafondssa./12)*&TcoagbFPNT_S.);

		/* R�gime g�n�ral : non-cadres */
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

		/* R�gime g�n�ral : cadres */
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

		if statut="21" and nafg088un='78' then do; /*�cart � la l�gislation : on est un peu large sur 78, en fait il faudrait cibler 7820Z */
			coagsP=min(salbrut,4*&plafondssa./12)*&Tcoags2_P.;
			end;
		else do; 
			coagsP=min(salbrut,4*&plafondssa./12)*&Tcoags_P.;
			end;

		/* Cotisation solidarit� */
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
			/* les indemnites journalieres maladie vers�s par la s�cu sont d�clar�s mais exon�r�es de charges sociales*/
			/* � l'inverse, les compl�ments de salaires vers� par les compl�mentaires de pr�voyance y sont soumis*/
			/* � d�faut on pr�voit le cas le plus simple*/
			/* les indemnite journalieres de conges maternite sont exon�rees de cotisations sociales mais soumises � la CSG et la CRDS*/
			/* en 1990, il semble qu'il n'y avait pas de cotisations � la place*/
			%Init_Valeur(comaS comaP cofaP coviS coviP cofnP coacP coasS coasP corcS corcP cocetS coprevP cocetP taxp);
			csgtsd=		(salbrut+coprevp)*&Tcsgijd.;
			csgtsi=		(salbrut+coprevp)*&Tcsgiji.;
			crdsts=		(salbrut+coprevp)*&tcrdsij.;
			CSGts_mal=	(salbrut+coprevp)*&Tcsgij_mal.;
			end;


		/**************************************/
		/* 7 - EXONERATIONS DU REGIME GENERAL */
		/**************************************/

		%Init_Valeur(exoCPHS exo_BSM exo_AppM CICE taxe_salaire taxe_75); /* Non cod� : employ�s de maison */
		%Init_Valeur(HSBrut HSupM_HorsMajo NbHSupM);
		%Init_Valeur(hscomaS hscoveS hscoviS hscoasS hscorcS hscocetS hscsgtsd hscsgtsi hscrdsts hsCSGts_mal);

		if pop1="RG" then do;
			HSBrut=max(0,sum(hscomaS,hscoveS,hscoviS,hscoasS,hscorcS,hscocetS,hscsgtsd,hsupm));

			/* 7.1 - Exon�ration des cotisations salariales sur heures sup */
			/* Ecart � la l�gislation : normalement le taux de r�duction ne doit pas exc�der 21,5 % */
			/* cf http://www.urssaf.fr/employeurs/dossiers_reglementaires/dossiers_reglementaires/questions-reponses_sur_les_heures_supplementaires_01.html*/
			%if 2007<=&anleg. and &anleg.<=2012 %then %do;

				%let ratio=%sysevalf(	3/12*(&anleg.=2007) 	/* introduction de l'exon�ration au 01/10/07 */
										+8/12*(&anleg.=2012) 	/* suppression de l'exon�ration au 01/09/12 */
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

			/* 7.2 - R�duction des cotisations patronales */
			if temps='complet' and HSupM_eqDecl>0 then do;

				/* Suppression de l'all�gement pour les grosses entreprises en 2012, mais reste pour les petites entreprises */
				/* Comme plus haut, on d�finit un ratio qui servira pour la partie "grosses entreprises" */
				%let ratio=%sysevalf(	3/12*(&anleg.=2007) 	/* introduction de l'exon�ration au 01/10/07 */
										+8/12*(&anleg.=2012) 	/* suppression de l'exon�ration au 01/09/12 */
										+1*(&anleg.>2007 and &anleg.<2012)); /* 0 sinon */

				/* Approximation du nombre d'heures suppl�mentaires pour les concern�s */
				/* Ecart : 	on consid�re que toutes les heures sup sont major�es de 25 % alors qu'au-del� 
							de 43 heures elles le sont de 50 % ou qu'il peut y avoir des conventions collectives*/
				HSupM_HorsMajo=	HSupM_eqDecl*(1/(1+&MajoSalHSup.));	/* Revenu mensuel des heures sup, hors majoration de salaire */
				SalHor_HN=		max(&smich.,((zsali&anr2./nbmois_sal)-HSupM_eqDecl)/((52/12)*&TpsTra.)); /* Salaire horaire des heures normales */;
				NbHSupM=		round((HSupM_HorsMajo)/SalHor_HN,1); /* Nombre mensuel d'heures sup */
		 		exoCPHS=		NbHSupM*(	&ratio.*&Forf_HSup1.*(effi>=&effi_Hsup. or effi=.)
									+&Forf_HSup2.*(1<=effi<&effi_Hsup.)); /* exon�ration mensuelle */
				cotsP1=sum(comaP,cofaP,coviP,coacP);
				if 0<exoCPHS<cotsP1 then do;
					comaP= comaP-exoCPHS*(comaP/cotsP1);
					cofaP= cofaP-exoCPHS*(cofaP/cotsP1);
					coviP= coviP-exoCPHS*(coviP/cotsP1);
					coacP= coacP-exoCPHS*(coacP/cotsP1);
					end;
				end;

			/* 7.3 - Exo bas salaires */

			/* Dispositif "Jupp�" */
			%if &anleg.=1998 %then %do; 
				if salbrut<&smic_brut. 				then exo_BSM=salbrut*&tredcoP1.; 
				else if salbrut<1.30*&smic_brut. 	then exo_BSM=(salbrut-1.30*&smic_brut.)*&tredcoP2.; 
				else exo_BSM=0; 
				if temps='partiel' and hor<&TpsTra. then exo_BSM= exo_BSM*hor/&TpsTra.;
				exo_BSM= min(exo_BSM,&smic_brut./12*1/5.5); 
				/* Le max est compt� en Smic (5,5 Smic) plut�t qu'en valeur nominale */
				%end;

			/* Dispositif "Fillon" */
			%if &anleg.>=2006 %then %do;
				/* cas g�n�ral temps complet  (ajout des CDD en 2008) */
				if statut in ('21','33','34','35') & emploi_particulier=0 & (pub3fp='4' or (pub3fp='' and echpub in ('','1'))) then do;
					/* nouvel all�gement suppl�mentaire 2008 pour les entreprises de moins de 20 salari�s */
					%if &anleg.>=2008 %then %do;
						if 1<=effi<20 then exo_BSM=min(max(0,(&tauxall19./(&salmaxexo.-1))*(&salmaxexo.*&smic_brut./(salbrut-HSBrut)-1)),&tauxall19.)*(salbrut-HSBrut); 
						/* pour les entreprises de 20 salari�s et + et toutes celles dont l'effectif est inconnu */
						else exo_BSM=min(max(0,(&tauxall./(&salmaxexo.-1))*(&salmaxexo.*&smic_brut./(salbrut-HSBrut)-1)),&tauxall.)*(salbrut-HSBrut); 
						%end;

					/* proratisation temps partiel */
					if temps='partiel' then exo_BSM=max(0,(&tauxall./(&salmaxexo.-1))*(&salmaxexo.*&smic_brut.*(hor/&TpsTra.)/(salbrut-HSBrut)-1))*(salbrut-HSBrut);
					end;
				%end;

			/* R�partition de la r�duction Fillon au prorata des diverses cotisations */
			%if &anleg.<2015 %then %do;
				%let cot_Fillon=comaP cofaP coviP;
				%end;
			%else %if &anleg.>=2015 %then %do;
				%let cot_Fillon=comaP cofaP coviP coacP cofnP; /* 2015 : Ajout des cotisations FNAL et AT-MP */
				/* Ecart � la l�gislation : normalement ajout aussi CSA mais cette cotisation est regroup�e avec Maladie dans Ines : d�j� compt�e m�me avant 2015 */
				%end;
			cot_Fillon=max(0,sum(of &cot_Fillon.));
			exo_BSM=min(exo_BSM,cot_Fillon); /* On borne exo_BSM, en bas par 0, et en haut par le montant total de cotis concern�es en haut */
			if cot_Fillon>0 then do;
				%do k=1 %to %sysfunc(countw(&cot_Fillon.));
					%let cot=%scan(&cot_Fillon.,&k.);
					&cot.=&cot.-exo_BSM*(&cot./cot_Fillon);
					/* Ecart � la l�gislation (non cod�) : pour les cotis AT-MP � partir de 2015, c'est dans la limite de 1 % de la r�mun�ration */
					%end;
				end;

			/* 7.4 - CICE */
			%if &anleg.>=2013 %then %do;
				/* cas g�n�ral temps complet (il faudrait exclure les stagiaires r�mun�r�s) + depuis 2015 la mesure s'�tend pour les exploitants d'entreprises impos�es au r�gime r�el (donc sur l'IR : non cod�)*/
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
		/* 8 - TAXE SUR LES SALAIRES	(+ taxe � 75%)	 */
		/**************************************************/
			/* La taxe sur les salaires concerne les entreprises dont 90% minimum du chiffre d'affaires n'est pas soumis � la TVA.
			Cela correspond � peu pr�s aux entreprises dont l'activit� est la suivante (Liste d'activit�s appuy�e par un rapport du S�nat : http://www.senat.fr/rap/r01-008/r01-00821.html) */
		if pop1="RG" and nafg088un in ('64','65','66','68','82','84','85','86','87','88','94','99') then do;
			if salbrut*nbmois_sal<=&taxeSal_lim1. 		then taxe_salaire=&taxeSal_tx1.*salbrut*nbmois_sal;
			else if salbrut*nbmois_sal<=&taxeSal_lim2. then taxe_salaire=&taxeSal_tx2.*(salbrut*nbmois_sal-&taxeSal_lim1.)+&taxeSal_tx1.*&taxeSal_lim1.;
			else if salbrut*nbmois_sal<=&taxeSal_lim3. then taxe_salaire=&taxeSal_tx3.*(salbrut*nbmois_sal-&taxeSal_lim2.)+&taxeSal_tx2.*(&taxeSal_lim2.-&taxeSal_lim1.)+&taxeSal_tx1.*&taxeSal_lim1.;
			else taxe_salaire=&taxeSal_tx4.*(salbrut*nbmois_sal-&taxeSal_lim3.)+&taxeSal_tx3.*(&taxeSal_lim3.-&taxeSal_lim2.)+&taxeSal_tx2.*(&taxeSal_lim2.-&taxeSal_lim1.)+&taxeSal_tx1.*&taxeSal_lim1.;
			end;
			/* Ecarts � la l�gislation : on ne prend pas en compte : 
				- la franchise pour les montants annuels n�exc�dant pas 1 200 �
				- la d�cote entre 1 200 � et 2 040 � 
				- l'abattement sp�cifique pour association car on ne connait pas la somme de la taxe pay�e par l'entreprise */

			/*"taxe � 75%" en 2013 et 2014 qui est une taxe � 50% sur les r�mun�rations brutes sup�rieures � 50%*/
			%if &anleg.=2013 or &anleg.=2014 %then %do;
				if salbrut*nbmois_sal>=&seuil_taxe75. 		then taxe_75=&taux_taxe75.*(&seuil_taxe75.-salbrut*nbmois_sal);
				%end;
			/* Ecarts � la l�gislation : normalement la taxe s'applique � l'ensemble des r�mun�rations y compris 
				attribution d�actions, participation, int�ressement et avantages en argnet ou nature
				+ Le montant de la taxe est plafonn� � hauteur de 5 % du chiffre d'affaires r�alis� l'ann�e au titre de laquelle la taxe est due*/
			
		/*************************************/
		/* 9 - REGROUPEMENT ET ANNUALISATION */
		/*************************************/

		/* Principe : autant que possible, cod� de fa�on commune � tous les r�gimes, les diff�rences ayant �t� g�r�es plus haut*/
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

		/* Ch�mage */
		COtsCHS= 	nbmois_sal*coasS;
		COtsCHP= 	nbmois_sal*coasp;
		COtsAGSP= 	nbmois_sal*coagsP;

		/* Accident du travail */
		COtsACP= 	nbmois_sal*coacP; /* Cot patronales th�oriques dans la FP, yc pour les contractuels de l'Etat */

		/* Agr�gations */
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

		/* Annualisation des montants d'exon�ration */
		exo_BasSal=	nbmois_sal*exo_BSM;
		exo_heursup=max(0,nbmois_sal*sum(HSBrut,exoCPHS,-HSupM)); /* les heures sup brutes moins les heures sup nettes */
		exo_app=	nbmois_sal*exo_AppM;
		exo=		sum(0,exo_BasSal,exo_heursup,exo_app);

		label pop1=			'sous-population de salari�s' 
			  COtsCHs=		'cot soc-chomage/salarial'
		      COtsCHp=		'cot soc-chomage/patronal'
		      COtsAGSp=		'cot soc-garanti salaire/patronal'
		      COtsREs=		'cot soc-retraite/salarial'
			  COtsRES_bpl=	'cot soc-retraite/salarial de base plafonn�e'
			  COtsRES_bdepl='cot soc-retraite/salarial de base d�plafonn�e (dite veuvage)'
			  COtsRES_compl='cot soc-retraite/salarial compl�mentaire'
		      COtsREp=		'cot soc-retraite/patronal'
		      COtsFA= 		'cot soc-famille /patronal'
		      COtsACP= 		'cot soc-accident du travail/patronal'
		      COtsMAL_SAL=	'Cot soc mal/salarial'
			  COtsMAL_PAT=	'Cot soc mal/patronal'
		      ContribExcSol='Contribution exceptionnelle de solidarit�'
		      COtsTAXp=		'Taxes et contribution logement et syndicat/patronal'
		      COtsS=  		'cot soc-toutes/salarial'
		      COtsP=  		'cot soc-toutes/patronal'
		      CSGtsD= 		'CSG deduc/salaire'
		      CSGtsI= 		'CSG impos/salaire'
		      CSGts_MAL=	'CSG maladie/salaire'
		      CRDSts= 		'CRDS/salaire'
			  CICE=			'Cr�ance au titre du CICE'
			  taxe_salaire=	'Taxe sur les salaires'
			  taxe_75=	'Taxe � 75% (en 2013 et 2014)';
		run;
	%mend Cotis_Salaries;
%Cotis_Salaries;

/************************************************************************************/
/*	III.	Ch�meurs et pr�retrait�s												*/
/************************************************************************************/

%Macro Cotis_Chomeurs_preretraites;
	data Chomeurs_preretraites (keep=ident noi zchoBRUT COchRE COchMAL CSGchd CSGchi CRDSch CSGch_mal casaPR);
		set prof (where=(zchoi&anr2.>0)); 
		/*******************/
		/* A. LES CHOMEURS */
		/*******************/
		if cotis_special not in ('preretraite','preretraite+retraite') then do;
		
			/* 1	Calcul des indemnit�s brutes et du salaire de r�f�rence */
			label zchom="allocations mensuelles en net d�clar�";
			if nbmois_cho>0 then zchom=(zchoi&anr2./nbmois_cho);

			/* 1.1	Calcul du salaire de r�f�rence */
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

			/*Remarques pr�liminaires sur le calcul :
				Zchom = ZchomNet + CRDS + CSG_Imposable
				ZchomBrut = Zchom + CSG_d�ductible + Cotisation_Ret_Comp = ZchomNet + CRDS + CSG_Imposable + CSG_d�ductible + Cotisation_Ret_Comp
				Donc ZchomBrut = (Zchom + Cotisation_Ret_Comp)/(1-Taux_CSG_d�ductible)*/

			/* 1.2	Calcul de la retraite compl�mentaire (VIchS) */
			
			/*Il existe un minimum en dessous duquel l'allocation apr�s VIchS ne peut pas aller. On proc�de ainsi : 
				- si zchom (montant d'allocation ch�mage d�clar�) est inf�rieur ou �gal au minimum, on 
				  consid�re qu'il y a eu exon�ration de VIchS.
				- si zchom est strictement sup�rieur au minimum, on consid�re qu'il n'y a pas eu exon�ration.
			  3 remarques :
				- On pourrait se dire que m�me si zchom est strictement sup�rieur au minimum, zchom_net est peut �tre inf�rieur
				  au minimum, apr�s soustraction de la CRDS et de la CSG_Imp. Mais dans ce cas zchom_net serait �galement inf�rieur
				  au minimum en dessous duquel CSG et CRDS ne peuvent faire descendre l'allocation, et donc il est impossible que 
				  CRDS et CSG_imp soit >0.
				- Le cas zchom = montant minimal peut aussi correspondre � des cas o� il y a eu paiement de VIchS
				  mais avec un "�cr�tement" (i.e. le montant de VIchS pay� est �gal � la diff�rence entre le montant
				  brut d'allocation et le montant minimal). Je ne suis pas s�r � 100 % que c'est comme �a que �a fonctionne
				  mais quoi qu'il en soit on ne peut pas en tenir compte �tant donn� qu'on ne dispose que de zchom d�clar�.
				  Cette approximation conduit � sous-estimer VIchS.
				- en r�alit� la comparaison avec le minimum se fait pour l'allocation journali�re. Ici on regarde en mensuel, i.e.
				  implicitement on consid�re que le montant journalier moyen est �gal au montant mensuel moyen divis� par 365/12,
				  or certains b�n�ficiaires de l'ARE peuvent avoir un faible nombre mensuel de jours de droits, et donc une allocation
				  journali�re �lev�e bien que l'allocation mensuelle soit faible. Dans ces cas l� on risque d'exon�rer dans Ines alors
				  qu'il n'y a pas exon�ration en r�alit�. Cette approximation conduit �galement � sous-estimer VIchS. Et �a vaut aussi pour CSG-CRDS plus bas.*/

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

			/*Pour la suite, comme pour VIchS, il existe un minimum en dessous duquel l'allocation apr�s CSG-CRDS
			ne peut pas aller. 
				On utilise la m�me m�thode que pour VIchS : 
				Si Zchom est inf�rieur ou �gal au minimum, on consid�re qu'il n'y a pas eu de CSG-CRDS pay�e,
				Si Zchom > minimum, on consid�re qu'il y a eu CSG CRDS pay�. 
				En r�alit� il y a une complexit� en plus par rapport � VIchS, dont on ne tient pas compte, c'est
				que comme la CRDS et la CSG imposable sont d�j� incluses dans zchom, il y a s�rement des cas o� Zchom est
				strictement sup�rieur au minimum, mais Zchom_net est inf�rieur. Dans ce cas l�, il y a �cr�tement dans la
				r�alit�, ce dont on ne tient pas compte ici (on consid�re qu'il y a paiement plein pot). 
					--> Ca pourrait s�rement �tre am�lior� en rajoutant le calcul de l'�cr�tement.

			Remarque compl�mentaire : 
			il me semble que l'assiette de CSG/CRDS est l'allocation chomage avant VIchS, mais
			cette page (https://www.unedic.org/indemnisation/fiches-thematiques/retenues-sociales-sur-les-allocations)
			dit le contraire */


				else if reduc_csg then do;

			/*Si reduc_csg, il n'y a pas de CSG imposable*/
					CSG_CRDS = (zchom>&mcocrCHmax.*(365/12))*(&TcsgCHd.+&tcrdsCH.)*(zchom+VIchS)/(1-&Tcsgchd.);
					CRDSch=	(&tcrdsCH./(&TcsgCHd.+&tcrdsCH.))*CSG_CRDS; /* prorata - RQ : exactement �quivalent � appliquer 
																						le taux &tcrdsCH. au revenu brut (zchom+VIchS)/(1-&Tcsgchd.)*/
					CSGCHd= (&TcsgCHd./(&TcsgCHd.+&tcrdsCH.))*CSG_CRDS; /* prorata */
					CSGCHi = 0;
					CSGTch= CSGCHd;
					CSGCH_mal=	CSGCHd;

				end;

				else do;

					CSG_CRDS = (zchom>&mcocrCHmax.*(365/12))*(&TcsgCHd.+&tcrdsCH.+&TcsgCHi.)*(zchom+VIchS)/(1-&Tcsgchd.);
					CRDSch=	(&tcrdsCH./(&TcsgCHd.+&tcrdsCH.+&TcsgCHi.))*CSG_CRDS; /* prorata - RQ : exactement �quivalent � appliquer 
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

			zchoBRUTm=sum(0,zchom,VIchS,CSGCHd,comal); /* Indemnit�s brutes mensuelles :  */

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

			/* 4 On annule les cotisations pour les b�n�ficiaires de l'ASS */
			if montant_ass>0 then do;
				%Init_valeur(COchRE COchMAL CSGchd CSGchi CSGch_mal CRDSch);
				end; 

			end;
		
		/***********************/
		/* B. LES PRERETRAITES */
		/***********************/
		else if cotis_special in ('preretraite','preretraite+retraite') then do;
			
			/* le cas est assez compliqu� puisque il y a une multitude de pr�retraites diff�rentes*/
			/* on choisit de suivre la fiscalit� appliqu�e au pr�retraite publique*/
			/* (pr�retraite progressive, CAATA et FNE (supprim� en 2012))*/
			/* plut�t que les pr�retraite d'entreprises*/

			/* il y a un changement de taxation qui s'applique sur les contrats sign� apr�s le 01/11/10*/
			/* la l�gislation est la m�me depuis 1985, voir L 131-2*/

			/*Pour l'exon�ration de pr�l�vements si ces derniers font baisser l'allocation nette
			  en dessous du SMIC brut : on utilise la m�me m�thode que pour le ch�mage, donc les limites mentionn�es
			  plus haut s'appliquent aussi ici pour la plupart d'entre elles. Une diff�rence : on n'a pas de nombre de mois 
			  de pr�retraite, donc on consid�re qu'on est en pr�retraite tous les mois o� il y a 5 dans cal0 (�a n'est pas parfait, 
			  car on peut �tre en retraire - et pas en pr�retraite - en ayant 5, mais c'est mieux que de prendre 12 mois de pr�retraite
		      pour tout le monde)*/
			nb_5 = COUNT(cal0,'5');

			/*1 Calcul du revenu de pr�retraite brut*/
			zchoibrut=zchoi&anr2.*(1-&tcsgpred.-&tcomalpre.); 
			zchoBRUTm = zchoibrut/12; /*revenu de pr�retraite brut mensuel*/
			/*Remarque : zchoibrut et zchoBRUTm sont des variables interm�diaires qui servent � calculer les pr�l�vements, elles
						sont fausses pour les gens qui sont exon�r�s (pour ne pas faire descendre leurs allocations nettes en dessous 
						du SMIC brut), mais �a n'est pas grave car on ne conserve dans la table finale que zchoBRUT qui est recalcul�
						comme somme de zchoi&anr2 (d�clar�), et de CRDSch, CSGchd, COchMAL et COchRE qui sont calcul�es en tenant compte
						de l'exon�ration.*/
						

			/*2 Calcul de la cotisation maladie*/
			COchMAL= (zchoi&anr2.>nb_5*&mcocrCHmin.*(365/12))*zchoibrut*&tcomalpre.;
			COchRE=0;

			/*3 Calculs de la CRDS et CSG*/
			CRDSch=		(zchoi&anr2.>nb_5*&mcocrCHmin.*(365/12))*zchoibrut*&tcrdspre.;
			CSGchd=		(zchoi&anr2.>nb_5*&mcocrCHmin.*(365/12))*zchoibrut*&Tcsgpred.;	
			CSGchi=		(zchoi&anr2.>nb_5*&mcocrCHmin.*(365/12))*zchoibrut*&Tcsgprei.;
			CSGch_MAL=	(zchoi&anr2.>nb_5*&mcocrCHmin.*(365/12))*zchoibrut*&Tcsgpre_mal.;
			CASApr=		(zchoi&anr2.>nb_5*&mcocrCHmin.*(365/12))*zchoibrut*&tcasa.;        /*cr�ation en 2013*/
				
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
			
			/* Exoneration totale de CSG et CRDS car non imposable � TH */
			%if &anleg.>=1998 %then %do;	
				if exo_csg=1 then do; 
					%Init_Valeur(CSGchd CSGchi CRDSch CRDSch CASApr);
					end;
			%end; 

			END;

		/******************/
		/* C. AGREGATIONS */
		/******************/
		label zchoBRUT="Ch�mage annuel brut de 20&anr2.";
		zchoBRUT=sum(zchoi&anr2.,CRDSch,CSGchd,COchMAL,COchRE);

		label COchRE=	'cot soc-retraite/chomage'
		      COchMAL=	'Cot soc mal/ch�mage'
		      CSGchD=	'CSG deduc/chomage'
		      CSGchI=	'CSG impos/chomage'
		 	  CSGch_MAL='CSG maladie/ch�mage'
			  CASApr ='CASA sur revenu de remplacement'
		      CRDSch=	'CRDS/chomage';
		run;
	%Mend Cotis_Chomeurs_preretraites;
%Cotis_Chomeurs_preretraites;


/************************************************************************************/
/*	IV.	Retrait�s																	*/
/************************************************************************************/

%Macro Cotis_Retraites; /* Calcul annualis� */
	data Retraites(keep=ident noi zrstBRUT COprMAL CSGprd CSGpr_mal CSGpri CRDSpr casaPR);
		set prof(where=(zrsti&anr2.>0));

		/****************************/
		/* 1	Ancienne profession */
		/****************************/
		ancienne_prof="Non cadre du priv�";
		if (csa in ('23','35','37','38')) or (csa='' and substr(p,1,2) in ('23','35','37','38')) or (csa='' and p='' and zrsti&anr2.>30000*&inflat05.) 
			then ancienne_prof="Cadre du priv�";
		if (csa in ('33','34','42','43','44','45','52','53')) or (csa='' and substr(p,1,2) in ('33','34','42','43','44','45','52','53'))
			then ancienne_prof="Fonctionnaire";
		if (csa in ('10','11','12','13','21','22','31')) or (csa='' and substr(p,1,2) in ('10','11','12','21','22','31'))
			then ancienne_prof="Ind�pendant";

		/**********************************************************************************/
		/* 2	Calcul des retraites brutes ZPENU (retraites g�n�rales + compl�mentaires) */
		/**********************************************************************************/
		/* 2.1	Ancien fonctionnaire */
		if ancienne_prof="Fonctionnaire" then do;
			zpenu=	zrsti&anr2./(1-(&tcomaRFonx.+&TcsgPRd1.*(pth=0)*(pir=1) + &TcsgPRd2.*(pth=0)*(pir=0)));
			zpenuG=	zpenu; /* general */
			zpenuC=	0;     /* complementaire */ 
			end;
		/* 2.2	Ancien ind�pendant */
		else if ancienne_prof="Ind�pendant" then do; 
			%if &anleg.>=1998 %then %do;
				zpenu=	zrsti&anr2./(1-(&TcsgPRd1.*(pth=0)*(pir=1) + &TcsgPRd2.*(pth=0)*(pir=0)));
				%end; 
			%if &anleg.=1990 %then %do; 
				zpenu=	zrsti&anr2./(1-&tcomaRind.);
				%end; 
			zpenuG=	zpenu;
			zpenuC=	0;
			end;
		/* 2.3	Ancien cadre du priv� */
		else if ancienne_prof="Cadre du priv�" then do;
			if zrsti&anr2.<=&retrCP_q1. 		then partRetrCompl=&retrCP_t1.;
			else if zrsti&anr2.<=&retrCP_q2. 	then partRetrCompl=&retrCP_t2.;
			else if zrsti&anr2.<=&retrCP_q3. 	then partRetrCompl=&retrCP_t3.;
			else if zrsti&anr2.<=&retrCP_q4. 	then partRetrCompl=&retrCP_t4.;
			else partRetrCompl=&retrCP_t5.;
			zpenu=	zrsti&anr2./(1 - partRetrCompl*&tcomaPR. - (&TcsgPRd1.*(pth=0)*(pir=1) + &TcsgPRd2.*(pth=0)*(pir=0)));
			zpenuG=	zpenu*(1-partRetrCompl); 	/* retraite r�gime g�n�ral */
			zpenuC=	zpenu*partRetrCompl;		/* retraite compl�mentaire */
			end;
		/* 2.4	Ancien non cadre du priv� */
 		else if ancienne_prof="Non cadre du priv�" then do;
			if zrsti&anr2.<=&retrNCP_q1. 		then partRetrCompl=&retrNCP_t1.;
			else if zrsti&anr2.<=&retrNCP_q2. 	then partRetrCompl=&retrNCP_t2.;
			else if zrsti&anr2.<=&retrNCP_q3. 	then partRetrCompl=&retrNCP_t3.;
			else if zrsti&anr2.<=&retrNCP_q4. 	then partRetrCompl=&retrNCP_t4.;
			else partRetrCompl=&retrNCP_t5.;
			zpenu=	zrsti&anr2./(1 - partRetrCompl*&tcomaPR. - (&TcsgPRd1.*(pth=0)*(pir=1) + &TcsgPRd2.*(pth=0)*(pir=0)));
			zpenuG=	zpenu*(1-partRetrCompl); 	/* retraite r�gime g�n�ral */
			zpenuC=	zpenu*partRetrCompl;		/* retraite compl�mentaire */
			end;

		/****************************************/
		/* 3	Calcul des cotisations sociales */
		/****************************************/
		/* 3.1	Cotisation maladie */
		%if &anleg.=1990 %then %do;
			if ancienne_prof="Fonctionnaire" 	then coprMAL=	zpenu*&tcomaRFonx.;
			else if ancienne_prof="Ind�pendant" then coprMAL=	min(&ScomaRind*&tcomaRind.,&tcomaRind.*zpenu);
			else									 coprMAL=	zpenug*&tcomaRprinc.+zpenuc*&tcomaPR.;
			%Init_Valeur(csgPRd csgPRi csgPR_mal csgPR);
			%end;
		%if &anleg.=1998 %then %do;
			if ancienne_prof="Fonctionnaire" 	then coprMAL=	zpenu*&tcomaRFonx.;
			else if ancienne_prof="Ind�pendant" then coprMAL=	&tcomaRind.*zpenu;
			else                 					 coprMAL=	zpenug*&tcomaRprinc.+zpenuc*&tcomaPR.;
			%end;
		%if &anleg.>=2006 %then %do;
			coprMAL=zpenuc*&tcomaPR.*(ancienne_prof not in ("Fonctionnaire","Ind�pendant"));
			%end;

		/* 3.2	CRDS et CSG */
		crdsPR=zpenu*&tcrdsPR.;
		casaPR=zpenu*&tcasa.;

		/* 	Exon�ration totale de la CSG et CRDS sur les pensions de retraite et d'invalidit� si non imposabilit� de la TH (sur RFR N-2 et non N-1 comme sur la TH) avant 2015 et condition sur RFR apr�s
			�cart � la l�gislation : Normalement il y a un 2e cas d'exon�ration pour les b�n�ficiaires de l'ASPA ou l'ASI (mais on ne peut pas le coder car l'ASPA et l'ASI sont calcul�s apr�s dans l'enchainement)*/
		%if &anleg.>=1998 %then %do;
			if exo_csg=1 then do; 
				%Init_Valeur(csgPRd csgPRi csgPR_mal crdsPR casaPR);
				end;
		/* 	Exon�ration partielle de la CSG (si non imposabilit� de l'IR � partir de 1998 et si RFR en dessous d'un seuil depuis 2015)
			De la m�me mani�re exon�ration de cotisation � l'assurance maladie si non imposabilit� (avant 2015, et depuis condition sur le RFR comme pour la CSG) */
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
/*	V.	Travailleurs ind�pendants : r�gime micro-social (auto-entrepreneurs, devenus micro-entrepreneurs en 2016) 	*/
/********************************************************************************************************************/

/* faute d'�l�ments suffisant pour rep�rer correctement les auto-entrepreneurs (ou microentrepreneurs � partir de 2016), 
	on assimile les b�n�ficiaires du r�gime micro-fiscal (microbic ou microbnc) aux micro-entrepreneurs (les 2 ont vocation � �tre fusionn�s en 2020).
	Cette approximation est toutefois abusive sur la p�riode de mont�e en charge du r�gime micro-social (ie statut auto-entrepreneur, cr�� en 2009) */

/* On fait donc le choix ici d'appliquer la l�gislation pour le micro-social � partir de 2016 seulement 
	(mise en place du statut de micro-entrepreneur et application pas d�faut du r�gime micro-social pour les b�n�ficiaires du micro-fiscal */
/* A voir si on l'�largit � des ann�es de l�gislation ant�rieure */

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
/*	VI.	B�n�fices Non Commerciaux (BNC)	- hors micro-entrepreneurs					*/
/************************************************************************************/

%Macro Cotis_BNC; /* Professions lib�rales hors r�gime micro */
	/* Pas de cotisation ch�mage ni ATMP sur les revenus non commerciaux */

	data BNC (keep=ident noi CObnRE CObnFA CobnMAL CSGbnd CSGbni CSGbn_mal CRDSbn);
		set prof (where=(zrnci&anr1. not in (.,0) and MicEnt=0));
		label exo_csg_coFA="condition pour l exon�ration de CSG/CRDS et de cotisation sur les allocations familiales"; /*la condition change en 2013*/
		exo_csg_coFA=(&anleg.<2013)*(zrnci&anr1.<12*&bmaf.) + (&anleg.>=2013)*(zrnci&anr1.<&plafondssa.*&seuilexocofaCsgIndP.);

		/*****************************************/
		/* 1	STATUT DE LA PROFESSION LIBERALE */
		/*****************************************/
		MedecinSpecialiste=(p in ('311a','344a','344b'));
		/* M�decins lib�raux sp�cialiste, 
		   M�decins hospitaliers sans activit� lib�rale,
		   M�decins salari�s non hospitaliers */
		MedecinGeneraliste=(p in ('311b'));
		/* M�decins lib�raux g�n�ralistes */
		AutreProfdeSante=(p in ('311c','431d','431f','431g','431e','432b','432d','432a','432c'));
		/* Chirurgiens dentistes, Infirmiers, Sages-femmes, Masseurs-kin�sith�rapeutes, r��ducateurs */

		if acteu6='1' & statut in ('11','12','13') &
			abs(zrnci&anr1.)>abs(zrici&anr1.) & abs(zrnci&anr1.)>abs(zragi&anr1.) then ActivBNCaccessoire=0;
		else ActivBNCaccessoire=1;

		/* Conventionnement secteur 1 et 2 des m�decins */
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
			%else %do; /* L'assiette n'est plus plafonn�e � partir de 2013. 
						Ecart � la l�gislation :  
						Afin de compenser le d�plafonnement de la cotisation maladie mise en place en 2013, la LFSS pour 2013
						avait introduit la r�duction d�gressive de la cotisation d�assurance maladie pour les travailleurs ind�pendants disposant
						de faibles revenus � compter de la 3�me ann�e d�activit� : c'est non cod� dans Ines car possible de d�tecter quand a eu lieu la 1er ann�e d'activit�*/
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
			/*�cart � la l�gislation avant 2013 : non prise en compte de la 2e conditions pour avoir l'�xon�ration de cotisation qui est relative � :
			"ceux qui ont assum� la charge d�au moins quatre enfants jusqu�� l��ge de quatorze ans et qui sont �g�s d�au moins soixante cinq ans (article R.242-15 du code de la s�curit� sociale)."*/
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
		/*r�duction de taux de cotisations d'allocations familiales pour les bas salaire depuis 2015 pour les ind�pendants*/
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
		/* 5.1.a	Cotisations sp�cifiques aux m�decins : avantage social vieillesse (ASV) et accompagnement au d�part � la retraite ADR */
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

		/* 5.1.b	Cotisation pour tous les ind�pendants (yc medecins)	*/
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

			/*�cart � la l�gislation : la contribution � la formation professionnelle dont b�n�ficiaient les travailleurs ind�pendants et ceux relevantdu r�gime micro social n'est pas cod�e, 
			de meme donc que l'exon�ration pour les revenus professionnel non salari� non agricole inf�rieur � 13% du plafond annuel de la S�curit� sociale, et de meme que la suppression de l'exo en 2015*/
	
		/*************************************/
		/* 6	REGROUPEMENT DES COTISATIONS */
		/*************************************/
		CObnRE=	sum(vbcoBN,vccoBN,vcoBN,ADR);
		CobnMAL=sum(mcoBN,idcoBN);
		
		/********************/
		/* 7	CSG et CRDS */
		/********************/
		/*Arret de l'exon�ration de CSG/CRDS en 2015 (article 26 de la loi 2014/626 du 18 juin 2014 ACTPE)*/
		%if &anleg.>=2015 %then %do ;
			CSGbnd=		max(0,zrnci&anr1.+CObnRE+CObnFA+CObnMAL)*&TcsgBNd.;
			CSGbni=		max(0,zrnci&anr1.+CObnRE+CObnFA+CObnMAL)*&TcsgBNi.;
			CSGbn_mal=	max(0,zrnci&anr1.+CObnRE+CObnFA+CObnMAL)*&TcsgBN_mal.;
			CRDSbn=		max(0,zrnci&anr1.+CObnRE+CObnFA+CObnMAL)*&tcrdsBN.;			
			%end;
		/* Exon�ration de CSG/CRDS dont les conditiosn sont similaires � l'exon�ration de cotisation d'allocations familiales, et meme �cart � la l�gislation avant 2013 */
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
/*	VII.  B�n�fices Industriels et Commerciaux (BIC)- hors micro-entrepreneurs		*/
/************************************************************************************/

%Macro Cotis_BIC; /* Commer�ants et artisans */
	/* Pas de cotisation ch�mage ni ATMP sur les revenus industriels et commerciaux */
	data BIC (keep=ident noi CObiRE CObiFA CobiMAL CSGbid CSGbii CSGbi_mal CRDSbi);
		set prof(where=(zrici&anr1. not in (.,0) and MicEnt=0));
		label exo_csg_coFA="condition pour l exon�ration de CSG/CRDS et de cotisation sur les allocations familiales"; /*la condition change en 2013*/
		exo_csg_coFA=(&anleg.<2013)*(zrici&anr1.<12*&bmaf.) + (&anleg.>=2013)*(zrici&anr1.<&plafondssa.*&seuilexocofaCsgIndP.);
 
		/****************************************************************/
		/* 1	Statut : artisan, commer�ant, ou activit� accesoire BIC */
		/****************************************************************/
		artisan=(substr(p,1,2) in ('21','63','68') or csa in ('21','63','68')); /* on rajoute les ouvriers de type artisanal qui d�clarent 
		ce type de revenu */
		commercant=1-artisan; /* Par d�faut on est commer�ant, yc quand ni p ni csa ne sont connues. Il s'agit pour beaucoup de retraites */

		if acteu6='1' & statut in ('11','12','13') &
			abs(zrici&anr1.)>abs(zrnci&anr1.) & abs(zrici&anr1.)>abs(zragi&anr1.) then ActivBICaccessoire=0;
		else ActivBICaccessoire=1;
		
		/****************************************************************/
		/* 2	COTISATIONS MALADIE - MATERNITE - indemnit� journali�re */
		/****************************************************************/
		/* 2.1 Maladie maternit� */
		if zrici&anr1.<=&assMinCoMARsi.*&plafondssa. & ActivBICaccessoire=1 then mcoBI=max(0,zrici&anr1.)*&tcoMArsi1.;
		%if &anleg.<=2012 %then %do;
			else if zrici&anr1.<=&plafondssa. 	then mcoBI=max(&assMinCoMARsi.*&plafondssa.,zrici&anr1.)*&tcoMArsi1.;
			else mcoBI=&plafondssa.*&tcoMArsi1.+(min(zrici&anr1.,&assMaxCoMARsi.*&plafondssa.)-&plafondssa.)*&tcoMArsi2.;
			%end;
		%else %do; 
		/* L'assiette n'est plus plafonn�e � partir de 2013. Meme �cart � la l�gislation que pour les 
		BNC sur la non prise en compte de la r�duction d�gressive � partir de la 3e ann�e*/
			else mcoBI=max(&assMinCoMARsi.*&plafondssa.,zrici&anr1.)*&tcoMArsi1.; 
			%end;

		/* 2.2 Indemnit�s journali�res */
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
		/*r�duction de taux de cotisations d'allocations familiales pour les bas salaire depuis 2015 pour les ind�pendants*/
		%if &anleg.>=2015 %then %do ;
			if zrici&anr1.<=&smincofaredindP.*&plafondssa. then CObiFA=max(0,zrici&anr1.*&tcofaredindP.);
			else if zrici&anr1.<=&smaxcofaredindP.*&plafondssa. then CObiFA=max(0,zrici&anr1.*(((&tcofaindP.-&tcofaredindP.)/((&smaxcofaredindP.-&smincofaredindP.)*&plafondssa.))*(zrici&anr1. - &smincofaredindP.*&plafondssa.)+&tcofaredindP.));
			else CObiFA=max(0,zrici&anr1.*&tcofaindP.);
			%end;
		/*�cart � la l�gislation avant 2013 : non prise en compte de la 2e conditions pour avoir 
			l'�xon�ration de cotisation qui est relative � :		"ceux qui ont assum� la charge d�au moins 
			quatre enfants jusqu�� l��ge de quatorze ans et qui sont �g�s d�au moins soixante cinq ans 
			(article R.242-15 du code de la s�curit� sociale)."*/
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
		 /*�cart � la l�gislation : 5,25% du PSS sans pouvoir �tre inf�rieure � 200 Smic hoaires en 2014 
			 et 7,7% du PSS sans pouvoir �tre inf�rieure � 300 Smic horaires en 2015 : ces conditions ne sont pas cod�es*/

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
		%else %if &anleg.>=2013 %then %do; /* Fusion des r�gimes compl�mentaires en 2013 */
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
		/*Arret de l'exon�ration de CSG/CRDS en 2015 (loi 2014/626 du 18 juin 2014 ACTPE)*/
		%if &anleg.>=2015 %then %do ;
			CSGbid=		max(0,sum(zrici&anr1.,CObiRE,CObiFA,CObiMAL))*&TcsgBId.;
			CSGbii=		max(0,sum(zrici&anr1.,CObiRE,CObiFA,CObiMAL))*&TcsgBIi.;
			CSGbi_mal=	max(0,sum(zrici&anr1.,CObiRE,CObiFA,CObiMAL))*&TcsgBI_mal.;
			CRDSbi=		max(0,sum(zrici&anr1.,CObiRE,CObiFA,CObiMAL))*&tcrdsBI.;			
			%end;
		/* Exon�ration de CSG/CRDS similaire � l'exon�ration de cotisation d'allocations familiales, et meme �cart � la l�gislation avant 2013 */
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
/*	VIII.	B�n�fices Agricoles (BA)												*/
/************************************************************************************/

%Macro Cotis_BA;
	/* Pas de cotisation ch�mage ni ATMP sur les revenus agricoles */
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

		/* B	Calcul des cotisations � partir de 1998 */
		/*************************************************/
		%if &anleg.>=1998 %then %do;
			/****************************************************************************/
			/* 1	Statut de la personne: m�tier principal, secondaire, aide familiale */
			/****************************************************************************/
			if statut='13' & (p=:'1' ! substr(p,1,2)='69') then aidfam1=1;
			else if statut in ('11','12') & (p=:'1' ! substr(p,1,2)='69') then chef1=1;
			else acba1=1; /* chef d'exploitation � titre secondaire */
			
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
			/* 3	COTISATIONS AMEXA maladie-maternit�-invalidit� (et compl�mentaire) */
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

			/* 	3.2 si chef d'exploitation � titre secondaire */        		
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
			/*r�duction de taux de cotisations d'allocations familiales pour les bas salaire depuis 2015 pour les ind�pendants*/
			%if &anleg.>=2015 %then %do ;
				if zragi&anr1.<=&smincofaredindP.*&plafondssa. then CObaFA=max(0,zragi&anr1.*&tcofaredindP.);
				else if zragi&anr1.<=&smaxcofaredindP.*&plafondssa. then CObaFA=max(0,zragi&anr1.*(((&tcofaindP.-&tcofaredindP.)/((&smaxcofaredindP.-&smincofaredindP.)*&plafondssa.))*(zragi&anr1. - &smincofaredindP.*&plafondssa.)+&tcofaredindP.));
				else CObaFA=max(0,zragi&anr1.*&tcofaindP.);
				%end;
			
			/***************************************************/
			/* 5	COTISATIONS invalidit�- d�c�s : voir axema */
			/***************************************************/

			/******************************/
			/* 6	COTISATIONS VIELLESSE */
			/******************************/
			/* 6.1 Cotisations AVA (Assurance vieillesse agricole) plafonn�e */
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
			/* 6.2 Cotisations AVA (Assurance vieillesse agricole) d�plafonn�e */
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
			/* 6.4 Retraite compl�mentaire obligatoire (RCO) */
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

/* Cr�ation de la table modele.cotis */
data modele.cotis;
	merge 	Salaries (in=a)
			Chomeurs_preretraites (in=b)
			Retraites (in=c)
			BNC (in=d)
			BIC (in=e)
			Agriculteurs (in=f)
			microsocial (in=g)
			prof (keep=	ident noi MicEnt
						p statut hor temps cst2 pir pth /* info n�cessaire pour la suite m�me si not a */
						nbmois_cho /* info n�cessaire m�me si not b car ce sont des ch�meurs non indemnis�s */
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

	/* Agr�gation des cotisations de tous les r�gimes */
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
