/****************************************************************************************/
/*																						*/
/*									1_RBG												*/
/*																						*/
/****************************************************************************************/
/* Calcul du revenu brut global															*/
/* En entr�e : 	base.foyer&anr1.														*/
/* En sortie : 	modele.rbg&anr1.														*/
/****************************************************************************************/



/****************************************************************************************/
/* PLAN 																				*/
/*	A - traitements salaires et pensions 												*/
/*		1 	salaires + salaires d'associ�s + ....+ indemnit�s journali�res				*/
/*		2 	frais professionnels														*/
/*		3 	pensions retraites et rentes � titre gratuit								*/
/*		4 	rentes viag�res � titre on�reux												*/
/*	B - revenus des valeurs et capitaux mobiliers										*/
/*		1	Produits des contrats d'assurance-vie d'au moins 6 ou 8 ans					*/
/*		2	Revenus ouvrant droit � l'abattement de 40 %								*/
/*		3	Revenus bruts des capitaux mobiliers n'ouvrant pas droit � abattement		*/
/*		4	D�ficit RCM ant�rieur � d�duire												*/
/*	C - Plus-values																		*/
/*	D - revenus fonciers																*/
/*	E - revenus des professions non salari�es											*/
/*		1	Revenus agricoles															*/
/*		2	Revenus industriels et commerciaux professionnel							*/
/*		3	Revenus industriels et commerciaux non professionnels						*/
/*		4	Revenus non commerciaux professionnels										*/
/*		5	Revenus non commerciaux non professionnels									*/
/*		6	Ensemble : regroupements interm�diaires (rev5)								*/
/*		7	Plus values des r�gimes micros												*/
/*	F - D�finition de RBG																*/
/*	G - Agr�gats et variables utiles pour la suite										*/
/*	H - D�finition d'un RBG individuel													*/	
/****************************************************************************************/
/* REMARQUE : 																			*/
/* Ce programme suit la section "calcul de l'imp�t", en particulier la fiche facultative*/ 
/* de calculs, de la Brochure Pratique de la d�claration des revenus.					*/						
/* Article 13 du CGI : Le revenu global net annuel servant de base � l'imp�t sur le 	*/
/* revenu est d�termin� en totalisant les b�n�fices ou revenus nets vis�s aux I � VII bis*/ 
/* de la 1�re sous-section de la pr�sente section, compte tenu, le cas �ch�ant, du		*/ 
/* montant des d�ficits vis�s aux I et I bis de l'article 156, des charges �num�r�es au */
/* II dudit article et de l'abattement pr�vu � l'article 157 bis						*/
/****************************************************************************************/


%Macro RBG;

	data modele.rbg&anr1.	(keep=	declar rbg: rev: assuvie rev2abat rev2ssabat deficit2
									_6: _2bh _2dh _2ch _2fa nb: sif age: case_t case_k case_l 
									mcdvo _2dc _2fu FraisDeductibles_Restants _7uh _perte_capital _perte_capital_passe 
									quotient: rev2: _3va _3vb _3vo _3vp _3vz _3wb _5:
									_hsupVous _hsupConj _hsupPac1 _hsupPac2 EXO _8ti _1ac _1bc _1cc _1dc _1ah _1bh _1ch _1dh
									_8by _8th _8cy _2ee _2tr _2ts _2tt PVmicro
									_1tt _1ut _1tz
									PVT _PVCessionDom _3vm _3vt _PVCession_entrepreneur _3vg _3vh _3sg _3sl _3vi _3vf _3vj _3vk
									_abatt_moinsval _abatt_moinsval_renfor _abatt_moinsval_dirpme
									chiffaff _interet_pret_conso _nb_vehicpropre_simple _nb_vehicpropre_destr 
									_relocalisation ident _8tk _4by _4bh _4bc
									anaisenf rev_cat:
									_7db _7df _7g: _souscSofipeche _cred_loc _7fn _1ao _1bo _1co _1do _1eo 

									_1as _1bs _1cs _1ds _1es
									_1al _1bl _1cl _1dl _1el
									_1am _1bm _1cm _1dm _1em
									_1az _1bz _1cz _1dz	_3se _3wa _3vd _3sb
									_1at _1bt AE: RevCessValMob_PostAbatt RevCessValMob_Abatt _3sj _3sk _8tm
									_bouquet_travaux _cred_loc _protect_patnat
									_epargneCodev _credFormation
									_demenage_emploivous _demenage_emploiconj _demenage_emploipac1 _demenage_emploipac2
									_revPEA _CIFormationSalaries
									_rachatretraite_vous _rachatretraite_conj

									/*variables conserv�es car utiles pour le calcul de la base ressources de l'AAH :*/
									abatt1-abatt5 /*d�ductions de 10% sur retraites, pensions alimentaires, pensions d'invalidit�*/
									deduc1-deduc5 /*D�duction de 10 % de frais professionnels ou des frais r�els*/
									revind1-revind4 /*Revenus des ind�pendants apr�s abattements*/
									RV /*rentes viag�res � titre on�reux*/

									);
		set base.foyer&anr1.;

		%Init_Valeur(rev1 rev2 rev3 rev3_cess rev4 rev5);

		/*************************************************************************/
		/* A - Traitements, salaires, pensions (Cadre 1 D�claration de revenus)  */
		/*************************************************************************/

		/***********************************************************************/
		/* A1	Salaires + salaires d'associ�s + ....+ indemnit�s journali�res */
		/* Salaires, traitements, gains de lev�e d'options dans cat�gories des salaires ... */

		%let sal1=	_1aj _1tp _1nx _1pm _1ap _3vj _glo1_2ansVous _1tt _glovSup4ansVous _1af _1ag;
		%let sal2=	_1bj _1up _1ox _1qm _1bp _3vk _glo1_2ansConj _1ut _glovSup4ansConj _1bf _1bg;
		%let sal3=	_1cj _1cp _1cf _1cg; 
		%let sal4=	_1dj _1dp _1df _1dg;
		%let sal5=	_1ej _1ep _1ef _1eg;

		/* Pensions, retraites et rentes et pensions alimentaires re�ues  */ 
		%let prb1=	_1as _1az _1ao _1al _1am;
		%let prb2=	_1bs _1bz _1bo _1bl _1bm;
		%let prb3=	_1cs _1cz _1co _1cl _1cm;
		%let prb4=	_1ds _1dz _1do _1dl _1dm;
		%let prb5=	_1es  _1eo _1el _1em;
		/* Frais r�els */
		%let FraisReels=_1ak _1bk _1ck _1dk _1ek;
		/* Etre demandeur d'emploi depuis plus d'un an (cases qui se cochent) */ 
		%let Chomeur=	_1ai _1bi _1ci _1di _1ei;

		%do i=1 %to 5;
			sal&i.=sum(of &&sal&i.);
			FraisReels&i.=%scan(&FraisReels.,&i.);
			Chomeur&i.=%scan(&Chomeur.,&i.)>0;
			PRB&i.=sum(of &&prb&i.);
			%end;

		/* D�fiscalisation compl�te des heures sup r�alis�es entre octobre 2007 (anleg=2008) et ao�t 2012 (anleg=2013) */
		%if &anleg.=2008 %then %do;
			sal1=sal1-_hsupVous*3/12;
			sal2=sal2-_hsupConj*3/12;
			sal3=sal3-_hsupPac1*3/12;
			sal4=sal4-_hsupPac2*3/12;
			%end;
		%else %if &anleg.>2008 and &anleg.<2013 %then %do;
			sal1=sal1-_hsupVous;
			sal2=sal2-_hsupConj;
			sal3=sal3-_hsupPac1;
			sal4=sal4-_hsupPac2;
			%end;
		%else %if &anleg.=2013 %then %do;
			sal1=sal1-_hsupVous*7/12;
			sal2=sal2-_hsupConj*7/12;
			sal3=sal3-_hsupPac1*7/12;
			sal4=sal4-_hsupPac2*7/12;
			%end;
		
		/* Fiscalisation de la participation employeur au contrat collectif � partir de 2014 (sur revenus 2013) */
	   	 %if &anleg.<2014 %then %do;
			 sal1=sal1-part_employ_vous;
			 sal2=sal2-part_employ_conj;
			 sal3=sal3-part_employ_pac1;
			 sal4=sal4-part_employ_pac2;
			 sal5=sal5-part_employ_pac3;

			 _1aj=_1aj-part_employ_vous;
			 _1bj=_1bj-part_employ_conj;
			 _1cj=_1cj-part_employ_pac1;
			 _1dj=_1dj-part_employ_pac2;
			 _1ej=_1ej-part_employ_pac3;
			 %end;

		/*********************************************************************/
		/* A2	D�duction de 10 % de frais professionnels ou des frais r�els */
		%do i=1 %to 5; /* On cr�e deduc1 � deduc5 */
			/* Abattement de 10 % avec un minimum */
			minimum=&abat10_min.;
			%if &anleg.>1998 %then %do;
				if chomeur&i. ne 0 then minimum=&abat10_min_deld.;
				%end;
			deduc&i.=max(&abat10.*sal&i.,minimum); drop minimum;
			/* Plafonnement de l'abattement */
			deduc&i.=min(deduc&i.,&abat10_plaf.);
			/* Possibilit� de choix de d�duire les frais r�els � la place */
			deduc&i.=max(deduc&i.,fraisreels&i.);
			/* On ne peut pas avoir plus de d�duc que de salaire */
			deduc&i.=min(deduc&i.,sal&i.);
			%end;
		SAL=sum(of sal1-sal5)-sum(of deduc1-deduc5);

		/*****************************************************/
		/* A3	Pensions retraites et rentes � titre gratuit */

		/* Imposition des majorations de pension de retraite � partir de 2014
		Note : la variable majo_vous (& majo_conj) n'est cr��e que pour les ann�es o� la majoration 
		n'est pas dans la d�claration fiscale, c'est � dire avant 2013 */
		%if &anleg.<2014 %then %do;
			_1as=_1as-majo_vous;
			_1bs=_1bs-majo_conj;
			_1cs=_1cs-majo_pac1;

			prb1=prb1-majo_vous;
			prb2=prb2-majo_conj;
			prb3=prb3-majo_pac1;
			%end;

		/* D�duction de 10 % avec un minimum calcul� pour chaque individu */
		/* On cr�e ABATT et PRB */
		%do i=1 %to 5;
			/* Abattement de 10 % avec un minimum */
			abatt&i.=min(max(&abat10.*PRB&i.,&min_abatt_prb_indiv.),PRB&i.);
			%end;
		/* l'abattement maximal se calcule sur l'ensemble et non pas par d�clarant */
		Abatt=min(sum(of abatt1-abatt5),&max_abatt_prb_foyer.);
		PRB=sum(of prb1-prb5)-abatt;
		%do i=1 %to 5;
			/* Les abattements sont r�partis sur chaque individu au prorata */
			if sum(of prb1-prb5) ne 0 then abatt&i.=abatt*prb&i./sum(of prb1-prb5);
			/* On ne peut pas avoir plus d'abattement que de montant */
			abatt&i.=min(abatt&i.,prb&i.);
			%end;

		/**************************************/
		/* A4 Rentes viag�res � titre on�reux */
		RV1=sum(_1aw,_1ar,0)*&rvto_tx1.;
		RV2=sum(_1bw,_1br,0)*&rvto_tx2.;
		RV3=sum(_1cw,_1cr,0)*&rvto_tx3.;
		RV4=sum(_1dw,_1dr,0)*&rvto_tx4.;
		RV=sum(of RV1-RV4);

		/* Abattement de 20 % avant 2006 (et 2 taux possibles au d�but des ann�es 90 */
		if 0<SAL+PRB<&abat_avt2006_lim1. then abattement=&abat_avt2006_t1.*(SAL+PRB);
		else if 0<SAL+PRB<&abat_avt2006_lim2. then abattement=&abat_avt2006_t1.*&abat_avt2006_lim1.+&abat_avt2006_t2.*(SAL+PRB-&abat_avt2006_lim1.);
		else abattement=0;

		rev1=Sal+PRB+RV-abattement;



		/********************************************************************************/
		/* B Revenus des valeurs et capitaux mobiliers (Cadre 2 D�claration de revenus) */
		/********************************************************************************/
		
		/********************************************************************/
		/* B1	Produits des contrats d'assurance-vie d'au moins 6 ou 8 ans */
		assuvie=max(_2ch-&abatassvie_plaf.*(1+(mcdvo in ('M','O'))),0);

		/* R�partition des frais d�ductibles (_2ca) entre les revenus des cat�gories ci-dessous (appel�es ici B2 et B3) */
		%Init_Valeur(r_b2 r_b3);
		if _2dc+_2ts>0 then do;
			r_b2=(_2dc+_2fu)/(_2dc+_2fu+_2ts+_2go+_2tr+_2tt);
			r_b3=1-r_b2;
			end;
		FraisDeductibles_B2=_2ca*r_b2;
		FraisDeductibles_B3=_2ca*r_b3;
		drop r_b2 r_b3;
		
		/*****************************************************/
		/* B2	Revenus ouvrant droit � l'abattement de 40 % */
		rev2abat=_2dc+_2fu;
		FraisDeductibles_Res2=max(0,FraisDeductibles_B2-(1-&abat_rev_mob.)*rev2abat);
		/* Si FraisDeductibles n'est pas utilis� enti�rement (parce que major� par AutRev_Abatt-40%), 
		l'exc�dent pourra �tre utilis� dans les revenus sans abattement */
		rev2abat=max((1-&abat_rev_mob.)*rev2abat-FraisDeductibles_B2,0);
		rev2abat=max(rev2abat-&P0285.*(1+(mcdvo in ('M' 'O'))),0); /* abattement forfaitaire avant 2013 */

		/******************************************************************************/
		/* B3	Revenus bruts des capitaux mobiliers n'ouvrant pas droit � abattement */
		rev2ssabat=_2ts+_2go*&E2001.+_2tr+_2tt;
		/* on ne met pas la case _2fa car pour ces revenus <2000 euros option pour le PF � 24 % sans condition sur le RFR */
		/* Reprise des frais d�ductibles non enti�rement utilis�s en limitant si frais sup�rieurs aux revenus */
		rev2ssabat=max(rev2ssabat-FraisDeductibles_B3,0);
		FraisDeductibles_Res3=max(0,FraisDeductibles_B3-rev2ssabat);
		FraisDeductibles_Restants=FraisDeductibles_Res2+FraisDeductibles_Res3;

		/**************************************************************************************************/
		/* B4	D�ficits ant�rieurs � d�duire (mais on ne peut pas d�duire plus que la somme des revenus) */
		deficit2=min(_2aa+_2al+_2am+_2an+_2aq+_2ar,assuvie+rev2abat+rev2ssabat);

		/* FINAL	Revenus de capitaux mobiliers nets imposables*/
		rev2=assuvie+rev2abat+rev2ssabat-deficit2;


		/**************************************************/
		/* C Plus values (Cadre 3 D�claration de revenus) */
		/**************************************************/

		/* Plus-values de cession de valeurs mobili�res  */
		/* A partir de 2016 les abattements ne s'appliquent plus aux moins-values */
		RevCessValMob_PostAbatt=_3vg+_3wa+_3wb+_3sb; /* plus-values nettes (moins-values d�j� imput�es auxplus-values) mais apr�s abattements fixes et pour dur�e de d�tention d�duits */
		RevCessValMob_Abatt=	_3sg+_3sl+_3va+_3vb+_3vo+_3vp /*-((_abatt_moinsval_renfor+_abatt_moinsval+_abatt_moinsval_dirpme)*(&anleg.<2016))*/; /* Abattements fixes et pour dur�e de d�tention */

		/* Avant 2014 ces plus-values ne sont pas soumises au bar�me : elles sont trait�es directement dans 6_impot */
		%if &anleg.>=2014 %then %do;
			rev3_cess=RevCessValMob_PostAbatt;
			%end;

		/* Les gains d'acquisition d'actions gratuites attribu�es apr�s ao�t 2015 sont aussi impos�s au bar�me */
		rev3 = rev3_cess + _1tz;

		/*******************************************************/
		/* D Revenus fonciers (Cadre 4 D�claration de revenus) */
		/*******************************************************/

		/*********************/
		/* D1	Microfoncier */
		%Init_Valeur(foncplus microfonc microfonc_caf);
		if _4be <= &plafmicrof. then do; 
			microfonc=max((_4be*(1-&tx_microfonc.)-_4bd),0);
			microfonc_caf=_4be*(1-&tx_microfonc.);
			end;
		/* Opter pour le micro-foncier exclut l'application des d�ficits de l'ann�e. 
		Mais les d�ficits des ann�es ant�rieures peuvent �tre imput�s sur les revenus nets
		d�termin�s selon le r�gime micro-foncier (brochure pratique IR 2002 rev 2001 : bas de page 124)*/
		else do; 
			foncplus=_4be - &plafmicrof.;
			microfonc_caf=&plafmicrof.*(1-&tx_microfonc.);
			end;
		/*si on est au dessus du plafond (comme quand ce r�gime n'existait pas) alors on bascule 
		du c�t� des revenus fonciers.*/

		/*************************/
		/* D2	Revenus fonciers */
		/* Se r�f�rer � la fiche facultative de calculs dans la brochure pratique pour suivre chaque �tape */
		_4bc=min(_4bc,&max_deficit_fonc.);/*limite au d�ficit global, on passe parfois au dessus � cause de la d�rive*/
		rev4c =_4ba+foncplus-_4bb;
		rev4e=0;
		if rev4c >=0 then do;
			rev4e=rev4c-_4bc;
			if rev4e >=0 then rev4e=max(rev4e-_4bd,0);
			end;
		else if rev4c<0 then do;
			if _4bc>0 then rev4e=-_4bc; 
			else rev4=0;
			end;

		rev4=rev4e+microfonc;
		rev4_caf=microfonc_caf+max(_4ba-_4bb-_4bc,0);


		/***********************************************************************/
		/* E	Revenus des professions non salari�es (D�claration 2042 C PRO) */
		/***********************************************************************/

		/************************************************/
		/* E1	Revenus agricoles						*/
		 
		/* Forfait agricole (jusqu'en 2016) */
		BA_forfait	=&E2001.*(_5xb+_5yb+_5zb)*(1-0.87) ;	/* remplac� par micro-BA en 2017 (cases _5ho _5io _5jo supprim�es) */

		/* R�gime micro-BA (� partir de 2017) sur le m�me mod�le que micro BIC et micro BNC mais avec moyenne triennale des revenus */
		/* � mettre � jour en 2018 puis 2019 avec la disparition du forfait agricole en n-2 puis n-3 */
		/* l�ger �cart � la l�gislation : l'abattement minimum &E2000 s'applique normalement sur la moyenne des ann�es concern�es */
		XBtax=max((_5xb-max(&E2000.,(_5xb*&abatagri.))),0); 
		YBtax=max((_5yb-max(&E2000.,(_5yb*&abatagri.))),0);
		ZBtax=max((_5zb-max(&E2000.,(_5zb*&abatagri.))),0);
		XFtax=max((_5xf-max(&E2000.,(_5xf*&abatagri.))),0); /* recettres brutes n-3 (=0 en 2017) */
		YFtax=max((_5yf-max(&E2000.,(_5yf*&abatagri.))),0);
		ZFtax=max((_5zf-max(&E2000.,(_5zf*&abatagri.))),0);
		XGtax=max((_5xg-max(&E2000.,(_5xg*&abatagri.))),0); /* recettres brutes n-2 (=0 en 2017) */
		YGtax=max((_5yg-max(&E2000.,(_5yg*&abatagri.))),0);
		ZGtax=max((_5zg-max(&E2000.,(_5zg*&abatagri.))),0);
		/* Nombre d'ann�es d'exercice : calcul � revoir pour 2018 (donn�e par _5xc mais inconnue dans ERFS 2015). 
		Pour 2017 ce sera en fait toujours 3 ans (exp_3an=1, exp_1an=0, exp_2an=0), sauf si le FA (_5ho) �tait � 0, en ce cas ce sera 0 */ 
		exp_3an = (_5xb+_5yb+_5zb>0 and _5xd+_5yd+_5zd+_5xf+_5yf+_5zf>0 and _5xe+_5ye+_5ze+_5xg+_5yg+_5zg>0) ;
		exp_1an = (_5xb+_5yb+_5zb>0 and _5xd+_5yd+_5zd+_5xf+_5yf+_5zf+_5xe+_5ye+_5ze+_5xg+_5yg+_5zg<=0) ;
		exp_2an = (_5xb+_5yb+_5zb>0 and exp_3an=0 and exp_1an=0) ;

		BAMicro=(exp_3an/3+exp_2an/2+exp_1an)*(XBtax+YBtax+ZBtax+XFtax+YFtax+ZFtax+XGtax+YGtax+ZGtax+_5XD+_5YD+_5ZD+_5XE+_5YE+_5ZE);

		/* forfait pour les exploitation foresti�res (revenu cadastral) */
		BA_forfait_foret=_5hd+_5id+_5jd;

		/* plus-values de court-terme (pour BA forfait ou micro-BA) */
		BA_forfait_PV	=_5hw-_5xo+_5iw-_5yo+_5jw-_5zo;

		/* b�n�fice r�el (hors d�ficits) */
		BA_reel1 	=&E2001.*(_5hi+_5ii+_5ji+_5al+_5bl+_5cl);	/* non adh�rent CGA */
		BA_reel2	=_5hc+_5ak+_5ic+_5bk+_5jc+_5ck;			/* adh�rent CGA */
		/* on g�re les d�ficits agricoles plus bas car ils ne sont imputables au b�n�fice global de l'ann�e en cours 
		  qu'en de�a d'un certain RBG */

		/* Apr�s 2016 une partie des revenus impos�s au r�gime r�el est soumis au taux marginal d'imposition (au bar�me) */
		BA_marg1	=&E2001.*(_5xv+_5xw) ;	/* non adh�rent CGA */
		BA_marg2	=_5xt+_5xu ; 			/* adh�rent CGA */

		/**********************************************************/
		/* E2	Revenus industriels et commerciaux professionnels */

		/*benef r��l sans cga*/
		BICRns		=&E2001.*(_5ki+_5dg+_5li+_5eg+_5mi+_5fg)-(_5kl+_5ll+_5ml);
		/*benef r��l avec cga*/
		BICRcgans	=(_5kc+_5df+_5lc+_5ef+_5mc+_5ff)-(_5kf+_5lf+_5mf);	

		/*regime micro*/
		KOtax=max((_5ko-max(&E2000.,(_5ko*&abatmicmarch.))),0);
		LOtax=max((_5lo-max(&E2000.,(_5lo*&abatmicmarch.))),0);
		MOtax=max((_5mo-max(&E2000.,(_5mo*&abatmicmarch.))),0);
		KPtax=max((_5kp-max(&E2000.,(_5kp*&abatmicserv.))),0);
		LPtax=max((_5lp-max(&E2000.,(_5lp*&abatmicserv.))),0);
		MPtax=max((_5mp-max(&E2000.,(_5mp*&abatmicserv.))),0);

		BicMicP=KOtax+LOtax+MOtax+KPtax+LPtax+MPtax;

		/*Auto-entrepreneurs (devenus "micro-entrepreneurs" en 2016) ayant opt� pour le versement lib�ratoire de l'IR*/
		TAtax=max((_5ta-max(&E2000.,(_5ta*&abatmicmarch.))),0);
		UAtax=max((_5ua-max(&E2000.,(_5ua*&abatmicmarch.))),0);
		VAtax=max((_5va-max(&E2000.,(_5va*&abatmicmarch.))),0);
		TBtax=max((_5tb-max(&E2000.,(_5tb*&abatmicserv.))),0);
		UBtax=max((_5ub-max(&E2000.,(_5ub*&abatmicserv.))),0);
		VBtax=max((_5vb-max(&E2000.,(_5vb*&abatmicserv.))),0);

		BicAuto=TAtax+UAtax+VAtax+TBtax+UBtax+VBtax;

		/**************************************************************/
		/* E3	Revenus industriels et commerciaux non professionnels */

		/*regime micro*/
		NONGtax=max(((_5no+_5ng+_5nj)-max(&E2000.,((_5no+_5ng+_5nj)*&abatmicmarch.))),0);
		OOOGtax=max(((_5oo+_5og+_5oj)-max(&E2000.,((_5oo+_5og+_5oj)*&abatmicmarch.))),0);
		POPGtax=max(((_5po+_5pg+_5pj)-max(&E2000.,((_5po+_5pg+_5pj)*&abatmicmarch.))),0);
		NPNDtax=max(((_5np+_5nd)-max(&E2000.,((_5np+_5nd)*&abatmicserv.))),0);
		OPODtax=max(((_5op+_5od)-max(&E2000.,((_5op+_5od)*&abatmicserv.))),0);
		PPPDtax=max(((_5pp+_5pd)-max(&E2000.,((_5pp+_5pd)*&abatmicserv.))),0);

		BicMicNP=NONGtax+OOOGtax+POPGtax+NPNDtax+OPODtax+PPPDtax;

		/* Benef r��l sans cga*/
		BICnPns	=max(&E2001.*(_5ni+_5us+_5oi+_5vs+_5pi+_5ws)-(_5nl+_5ol+_5pl),0); /*normal ou simplifi�*/
		BICnPl	=&E2001.*(_5nk+_5ez+_5km+_5ok+_5fz+_5lm+_5pk+_5gz+_5mm)-(_5nz+_5oz+_5pz); /*locations meubl�es*/

		/* Benef r��l avec cga*/
		BICnPcgans	=max(_5nc+_5ur+_5oc+_5vr+_5pc+_5wr-(_5nf+_5of+_5pf),0); /*normal ou simplifi�*/
		BICnPcgal	=(_5na+_5ey+_5nm+_5oa+_5fy+_5om+_5pa+_5gy+_5pm)-(_5ny+_5oy+_5py); /*locations meubl�es*/

		/*Note : pour les RIC non prof. hors locations meubl�es, les d�ficits en n ne sont imputables que sur des b�n�fices de m�me nature*/

		/***********************************************/
		/* E4	Revenus non commerciaux professionnels */

		/*regime micro*/
		Hqtax=max((_5hq-max(&E2000.,(_5hq*&abatmicbnc.))),0);
		Iqtax=max((_5iq-max(&E2000.,(_5iq*&abatmicbnc.))),0);
		Jqtax=max((_5jq-max(&E2000.,(_5jq*&abatmicbnc.))),0);

		BNCSPEP=Hqtax+Iqtax+Jqtax;

		/* Autoentrepreneurs (devenus "micro-entrepreneurs") ayant opt� pour le versement lib�ratoire de l'IR */
		TEtax=max((_5te-max(&E2000.,(_5te*&abatmicbnc.))),0);
		UEtax=max((_5ue-max(&E2000.,(_5ue*&abatmicbnc.))),0);
		VEtax=max((_5ve-max(&E2000.,(_5ve*&abatmicbnc.))),0);

		BncAuto=TEtax+UEtax+VEtax;

		AE_Rev=BicAuto+BncAuto;

		/*benef r��l sans aa*/
		Bncp	=&E2001.*(_5qi+_5xk+_5ri+_5yk+_5si+_5zk)-(_5qk+_5rk+_5sk);
		/*benef r��l avec aa*/
		Bncpaa	=_5qc+_5xj+_5rc+_5yj+_5sc+_5zj-(_5qe+_5re+_5se);

		/***************************************************/
		/* E5	Revenus non commerciaux non professionnels */

		/*regime micro*/
		Kutax=max((_5ku-max(&E2000.,(_5ku*&abatmicbnc.))),0);
		Lutax=max((_5lu-max(&E2000.,(_5lu*&abatmicbnc.))),0);
		Mutax=max((_5mu-max(&E2000.,(_5mu*&abatmicbnc.))),0);
		BNCSPEnP=kutax+lutax+mutax;

		/*benef r��l sans aa*/
		bncnp	=max(&E2001.*(_5sn+_5xx+_5ns+_5yx+_5os+_5zx)-(_5sp+_5nu+_5ou),0);
		/*benef r��l avec aa*/
		bncnpaa	=max(_5jg+_5xs+_5rf+_5ys+_5sf+_5zs-(_5jj+_5rg+_5sg),0)+(_5tc+_5uc+_5vc); /* yc produits taxables � 16% (?) */

		/*Note : comme pour les RIC non prof., les d�ficits en n ne sont imputables que sur des b�n�fices de m�me nature*/

		/*******************************************************/
		/* E6	Ensemble : regroupements interm�diaires (rev5) */

		rev5b=BA_reel2+BA_marg2+BICRcgans+BICnPcgans+BICnPcgal+bncpaa+bncnpaa; /* R�gime r�el avec cga */

		if 0<rev5b<&abat_avt2006_lim1. then rev5b=(1-&abat_avt2006_t1.)*rev5b;
		else if 0<rev5b<&abat_avt2006_lim2. then rev5b=rev5b-&abat_avt2006_t1.*&abat_avt2006_lim1.-&abat_avt2006_t2.*(rev5b-&abat_avt2006_lim1.);

		revagr	=(&anleg.<=2016)*BA_forfait +BA_forfait_foret +(&anleg.<=2016)*BA_forfait_PV
				+BA_reel1+BA_reel2 +BA_marg1+BA_marg2;
		revbic	=BICRcgans+BICRns;
		revbicnp=BICnPcgans+BICnPcgal+BICnPns+BICnPl;
		revbncp	=bncp+bncpaa;
		revbncnp=bncnp+bncnpaa;

		/* TO DO : la gestion des d�ficits est � revoir par rapport � l'abattement, par rapport aux revenus CAF, etc. (2011)*/
		/* + V�rifier la prise en compta des revenus exon�r�s et des PV taxables � 16% */

		revagr_caf	=revagr;
		revbicnp_caf=revbicnp;

		/*D�ficits ant�rieurs (n'ayant pas pu �tre imput�s les ann�es pr�cedentes)*/
		/*ne peuvent �tre imput�s en n que s'ils sont inf�rieurs au b�n�fice r�alis� en n sur les activit�s de m�me nature*/ 

		/*agricole*/
		deficitagr=_5qf+_5qg+_5qn+_5qo+_5qp+_5qq;
		revagr=max(revagr-deficitagr,0);
		/*RICnonP*/
		deficitric=_5rn+_5ro+_5rp+_5rq+_5rr+_5rw;
		revbicnp=max(revbicnp-deficitric,0);
		/*RnonCnonP*/
		deficitrinc=_5ht+_5it+_5jt+_5kt+_5lt+_5mt;
		revbncnp=max(revbncnp-deficitrinc,0);

		rev5= revbncnp+bncspenp +revbncp+bncspep +revbicnp+bicmicnp +revbic+bicmicp +revagr+(&anleg.>=2017)*BAmicro
				-BA_reel2-BA_marg2 -BICRcgans-BICnPcgans-BICnPcgal -bncpaa-bncnpaa
				+rev5b +BicAuto+BncAuto;

		rev5_caf= revbncnp+bncspenp +revbncp+bncspep +revbicnp_caf+bicmicnp +revbic+bicmicp +revagr_caf+(&anleg.>=2017)*BAmicro
				-BA_reel2-BA_marg2 -BICRcgans-BICnPcgans-BICnPcgal -bncpaa-bncnpaa
				+rev5b +BicAuto+BncAuto;

		AE=(_5ta+_5ua+_5va+_5tb+_5ub+_5vb+_5te+_5ue+_5ve)>0;

		/******************************************************/
		/* E7	Plus values de court terme des r�gimes micros */
		/* Les d�ficits ne peuvent pas �tre plus grands que le revenu li� � l'activit�*/

		PVCTBA		=(&anleg.>=2017)*(_5hw+_5iw+_5jw-_5xo-_5yo-_5zo);	/*micro-ba */
		PVCTBICP	=_5kx+_5lx+_5mx-_5kj-_5lj-_5mj;		/*bicp*/
		PVCTBICnP	=_5nx+_5ox+_5px-(_5iu+_5rz+_5sz);	/*bicnp*/
		PVCTBICnP	=max(PVCTBICnP,-bicmicnp);
		PVCTBnCP	=_5hv+_5iv+_5jv-_5kz-_5lz-_5mz;		/*bncp*/
		PVCTBInCnP	=_5ky+_5ly+_5my-(_5ju+_5ld+_5md);	/*bncnp*/
		PVCTBInCnP	=max(PVCTBInCnP,-BNCSPEnP);
		PVmicro		= PVCTBA+PVCTBICP+PVCTBICnP+PVCTBnCP+PVCTBInCnP;


		/************************************************/
		/****** F -  D�finition de RBG ******************/
		/************************************************/

		/* Revenus exon�r�s */
		exo1   =(_5xa+_5ya+_5za);					/*Revenus agricoles au forfait ou micro BA*/
		exo2   =(_5hb+_5ib+_5jb +_5hh+_5ih+_5jh); 	/*Revenus agricoles au b�n�f r�el*/
		exo3   =(_5kn+_5ln+_5mn);					/*bicp micro entreprise*/
		exo4   =(_5kb+_5lb+_5mb +_5kh+_5lh+_5mh);	/*ricp b�n�fice r��l*/
		exo5   =(_5nn+_5on+_5pn);					/*bicnp micro entreprise*/
		exo6   =(_5nb+_5ob+_5pb+_5nh+_5oh+_5ph);	/*ricnp*/
		exo7   =(_5hp+_5ip+_5jp);					/*rncp r�gime sp�cial ou micro*/
		exo8   =(_5qb+_5rb+_5sb +_5qh+_5rh+_5sh);	/*rncp d�cl control�e*/
		exo9   =(_5th+_5uh+_5vh);					/*rncnp sp�cial ou micro*/
		exo10  =(_5hk+_5jk+_5lk +_5ik+_5kk+_5mk);	/*rncnp d�cl control�e*/
		exo11  =(_8ti+_1ac+_1bc+_1cc+_1dc+_1ah+_1bh+_1ch+_1dh); /* Revenus de source �trang�re */
		EXO=sum(of exo1-exo11);
		label EXO="EXO : Revenus exon�r�s";

		/* Plus values taxables � 16% */
		pvt1 =&P0750.*((_5hx+_5ix+_5jx)-(_5xn+_5yn+_5zn));	/*agri au forfait ou micro-ba*/
		pvt2 =&P0750.*(_5he+_5ie+_5je);						/*agr au b�n�f r��l*/
		pvt3 =&P0750.*((_5kq+_5lq+_5mq)-(_5kr+_5lr+_5mr));	/*bicp micro entreprise*/
		pvt4 =&P0750.*(_5ke+_5le+_5me);						/*ricp b�n�fice r��l*/
		pvt5 =&P0750.*((_5nq+_5oq+_5pq)-(_5nr+_5or+_5pr));	/*bicnp micro entreprise*/
		pvt6 =&P0750.*(_5ne+_5oe+_5pe);						/*ricnp*/
		pvt7 =&P0750.*((_5kv+_5lv+_5mv)-(_5kw+_5lw+_5mw));	/*rncnp r�gime sp�cial ou micro*/
		pvt8 =&P0750.*(_5so+_5nt+_5ot);						/*rncnp d�cl control�e*/
		pvt9 =&P0750.*((_5hr+_5ir+_5jr)-(_5hs+_5is+_5js));	/*rncnp r�gime sp�cial ou micro*/
		pvt10=&P0750.*(_5qd+_5rd+_5sd);						/*rncp d�cl control�e*/
		PVT=sum( of pvt1-pvt10);
		label PVT="PVT : Imp�t sur plus-values taxables � 16 %";

		RBG=rev1+rev2+rev3+rev4+rev5+_6gh+_8tk+PVmicro;
		RBG_caf= RBG 
				- rev4 + rev4_caf
				- rev5 + rev5_caf
				+ _8tm
				+ PVT/&P0750. /* montant total des PVT (calcul inverse) */
				+_PVCessionDom+_3vm+_3vt+_PVCession_entrepreneur
				+RevCessValMob_Abatt
				+(RevCessValMob_PostAbatt*(&anleg.<2014)) /* sinon d�j� inclus dans rev3 donc dans RBG */
				+_3vi+_3vf+_3vd		/* Gains de levee d'option au pr�l�vement liberatoire */
				+_3vz+_3sj+_3sk
				+_2ee+_2dh+_2fa
				+(_hsupVous+_hsupConj+_hsupPac1+_hsupPac2)*((2008<&anleg.<2013)+7/12*(&anleg.=2013)+3/12*(&anleg.=2008))
				+EXO;

		/* D�ficits agricoles (d�ductibles du revenu global en de�a d'un certain RBG uniquement)*/
		%Init_Valeur(retir);
		defagr=(_5hf+_5if+_5jf)+(_5hl+_5il+_5jl);

		IF RBG<=&P0320. AND defagr>0 THEN do; 
			RBG=RBG-defagr;
			retir=1;
			end;
		/*au del� d'un certain niveau de revenu, les deficits agricoles sont imputables au BA des 6 ann�es suivantes */

		deficit_ant=_6fa+_6fb+_6fc+_6fd+_6fe+_6fl;
		RBG=max(RBG-deficit_ant,0);


		/******************************************************************/
		/****** G -  Agr�gats et variables utiles pour la suite ***********/
		/******************************************************************/

		/* Autres revenus imposables selon le syst�me du quotient */
		/* Gains de lev�e d'options sur titre */
		quotient2=_glo2_3ansVous+_glo2_3ansConj;
		quotient3=_1tx+_1ux;
		/* Revenus exceptionnels ou diff�r�s */
		quotient4=_0xx; 

		/*on garde ici le chiffre d'affaire (des professionnels) -> sert pour RED_mecenat dans Deduc */
		chiffaff= BA_reel1 + BA_reel2+BA_marg1+BA_marg2+_5kc+_5df+_5lc+_5ef+_5mc+_5ff+_5ki+_5dg+_5li+_5eg+_5mi+_5fg
				+_5qi+_5xk+_5ri+_5yk+_5si+_5zk+_5qc+_5xj+_5rc+_5yj+_5sc+_5zj+_5xj+_5xk+_5yj+_5yk+_5zj+_5zk;
		/*on garde aussi le montant des plus-values*/


		/***********************************************/
		/****** H -  D�finition d'un RBG individuel ****/
		/***********************************************/

		/* 	Par rapport � ce qui pr�c�de, dans la d�claration d'imp�t on ne cherche plus 
			� sommer les cases en lignes mais en colonnes (donc individuellement) */

		%Macro CalculRevind(declarant);
		/* 	Le param�tre declarant doit �tre renseign� � v si on s'int�resse au vous, c au conjoint, et p1 pour la 1�re pac. 
			Cette macro calcule les variables
				zbag, zbag_cga, zbic, zbic_np, zbicnp_cga, zbncnp, znbcnp_cga, zbnc, zbnc_cga, 
				zbicmicro, zbicmicronp, zbncmicro, zbncmicronp, pvind, rev5ind et rev5ind_cga
			� chaque fois relatives au declarant pass� en param�tre. 
			Elle cr�e enfin les variables REVIND&i. et REV_CAT&i., o� i vaut 1 pour d, 2 pour c et 3 pour p1 */

		/*  PRINCIPE : 	� la fin, on veut �crire une formule comme si c'�tait le vous, et disons que la case pour le vous s'appelle A. 
						Seulement la case A s'appelle B pour le conj et C pour le pac1. 
						-> On va cr�er une variable qui s'appelle A_ (nom de la case du vous suivi d'un '_'), 
						et qui vaut A, B ou C selon le cas (le d�clarant sera pass� en param�tre d'une macro). 
						Ensuite les calculs de revenus sont fait � partir de A_ pour simplifier. 

			EXEMPLE : 	cas d'un calcul o� on n'a besoin que de la case de l'individu
						si d�clarant=vous(d) alors _5hn_=_5hn, si d�clarant=conjoint(c) alors _5hn_=_5in

			TODO : 	� �ventuellement g�n�raliser � l'ensemble du programme */
				
			/************************************************************************************/
			/* Pr�alable : &indice. servira pour indexer les noms des variables revind � la fin */
			%if &declarant.=v %then %let indice=1;
			%else %if &declarant.=c %then %let indice=2;
			%else %if &declarant.=p1 %then %let indice=3;

			/******************************************************************************************************/
			/* Etape 1 : D�finition des cases fiscales : on ne va pas chercher les m�mes en fonction du d�clarant */
			%if &declarant. = v %then %do;
				_1ac_=_1ac; _1ah_=_1ah; /* pour revenus de l'�tranger */
				_5xa_=_5xa;	_5hb_=_5hb;	_5hh_=_5hh;	_5hd_=_5hd; _5hi_=_5hi;	_5al_=_5al; _5hl_=_5hl;	_5hx_=_5hx;	_5xn_=_5xn; _5xv_=_5xv; /* pour calcul zbag */
				_5hc_=_5hc; _5ak_=_5ak; _5hf_=_5hf;	_5he_=_5he; _5xt_=_5xt; /* pour calcul zbag_cga */
				_5xb_=_5xb;	_5xd_=_5xd;	_5xe_=_5xe;	_5xf_=_5xf;	_5xg_=_5xg;	 /* pour calcul zbamicro */
				_exp_3an_ = (_5xb>0 and _5xd+_5xf>0 and _5xe+_5xg>0) ;
				_exp_1an_ = (_5xb>0 and _5xd+_5xf+_5xe+_5xg<=0) ;
				_exp_2an_ = (_5xb>0 and _exp_3an_=0 and _exp_1an_=0) ;
				_5kn_=_5kn; _5kb_=_5kb; _5kh_=_5kh; _5ki_=_5ki; _5dg_=_5dg;	_5kl_=_5kl; _5kq_=_5kq; _5kr_=_5kr; /* pour calcul zbic */
				_5kc_=_5kc; _5df_=_5df; _5ke_=_5ke; _5kf_=_5kf; /* pour calcul zbic_cga */
				_5nh_=_5nh; _5ni_=_5ni; _5us_=_5us; _5nk_=_5nk; _5ez_=_5ez; _5km_=_5km; _5nl_=_5nl; _5nz_=_5nz; _5nq_=_5nq; _5nr_=_5nr; /* pour calcul zbicnp */
				_5nb_=_5nb; _5nc_=_5nc; _5ur_=_5ur; _5ne_=_5ne; _5nf_=_5nf; _5na_=_5na; _5ey_=_5ey; _5nm_=_5nm; _5ny_=_5ny; /* pour calcul zbicnp_cga */
				 _5th_=_5th; _5hk_=_5hk; _5ik_=_5ik;
				_5hp_=_5hp; _5qb_=_5qb; _5qh_=_5qh; _5qi_=_5qi; _5xk_=_5xk;_5qk_=_5qk; _5hr_=_5hr; _5hs_=_5hs; /* pour calcul zbnc */
				_5qc_=_5qc; _5xj_=_5xj; _5qe_=_5qe; _5qd_=_5qd; /* pour calcul zbnc_cga */
				_5sn_=_5sn; _5xx_=_5xx; _5sp_=_5sp; _5kv_=_5kv; _5kw_=_5kw; /* pour calcul zbncnp */
				_5jg_=_5jg; _5xs_=_5xs; _5jj_=_5jj; _5so_=_5so; _5tc_=_5tc; /* pour calcul zbncnp_cga */
				_5ko_=_5ko; _5kp_=_5kp; _5ta_=_5ta;	_5tb_=_5tb;	/* pour calcul zbicmicro */
				_5nn_=_5nn; _5no_=_5no; _5ng_=_5ng; _5nj_=_5nj; _5np_=_5np; _5nd_=_5nd; /* pour calcul zbicmicronp */
				_5hq_=_5hq; _5te_=_5te;	/* pour calcul zbncmicro */
				_5ku_=_5ku;	/* pour calcul zbicmicronp */
				_5hw_=_5hw; _5xo_=_5xo; _5kx_=_5kx; _5hv_=_5hv; _5kj_=_5kj; _5kz_=_5kz; /* pour calcul pvind */
				_hsupVous_=_hsupVous; /* pour calcul rev_cat */
				%end;
			%else %if &declarant. = c %then %do;
				_1ac_=_1bc; _1ah_=_1bh; /* pour revenus de l'�tranger */
				_5xa_=_5ya;	_5hb_=_5ib;	_5hh_=_5ih;	_5hd_=_5id; _5hi_=_5ii;	_5al_=_5bl; _5hl_=_5il; _5hx_=_5ix; _5xn_=_5yn; _5xv_=_5xw; /* pour calcul zbag */
				_5hc_=_5ic; _5ak_=_5bk; _5hf_=_5if;	_5he_=_5ie; _5xt_=_5xu; /* pour calcul zbag_cga */
				_5xb_=_5yb;	_5xd_=_5yd;	_5xe_=_5ye;	_5xf_=_5yf;	_5xg_=_5yg;	 /* pour calcul zbamicro */
				_exp_3an_ = (_5yb>0 and _5yd+_5yf>0 and _5ye+_5yg>0) ;
				_exp_1an_ = (_5yb>0 and _5yd+_5yf+_5ye+_5yg<=0) ;
				_exp_2an_ = (_5yb>0 and _exp_3an_=0 and _exp_1an_=0) ;
				_5kn_=_5ln; _5kb_=_5lb; _5kh_=_5lh; _5ki_=_5li; _5dg_=_5eg; _5kl_=_5ll; _5kq_=_5lq; _5kr_=_5lr; /* pour calcul zbic */
				_5kc_=_5lc; _5df_=_5ef; _5ke_=_5le; _5kf_=_5lf; /* pour calcul zbic_cga */
				_5nh_=_5oh; _5ni_=_5oi; _5us_=_5vs; _5nk_=_5ok; _5ez_=_5fz; _5km_=_5lm; _5nl_=_5ol; _5nz_=_5oz; _5nq_=_5oq; _5nr_=_5or; /* pour calcul zbicnp */
				_5nb_=_5ob; _5nc_=_5oc; _5ur_=_5vr; _5ne_=_5oe; _5nf_=_5of; _5na_=_5oa; _5ey_=_5fy; _5nm_=_5om; _5ny_=_5oy; /* pour calcul zbicnp_cga */
				  _5th_=_5uh; _5hk_=_5jk; _5ik_=_5kk;
				_5hp_=_5ip; _5qb_=_5rb; _5qh_=_5rh; _5qi_=_5ri; _5xk_=_5yk; _5qk_=_5rk; _5hr_=_5ir; _5hs_=_5is; /* pour calcul zbnc */
				_5qc_=_5rc; _5xj_=_5yj; _5qe_=_5re; _5qd_=_5rd; /* pour calcul zbnc_cga */
				_5sn_=_5ns; _5xx_=_5yx; _5sp_=_5nu; _5kv_=_5lv; _5kw_=_5lw; /* pour calcul zbncnp */
				_5jg_=_5rf; _5xs_=_5ys; _5jj_=_5rg; _5so_=_5nt; _5tc_=_5uc; /* pour calcul zbncnp_cga */
				_5ko_=_5lo; _5kp_=_5lp; _5ta_=_5ua;	_5tb_=_5ub;	/* pour calcul zbicmicro */
				_5nn_=_5on; _5no_=_5oo; _5ng_=_5og; _5nj_=_5oj; _5np_=_5op; _5nd_=_5od; /* pour calcul zbicmicronp */
				_5hq_=_5iq; _5te_=_5ue; /* pour calcul zbncmicro */
				_5ku_=_5lu;	/* pour calcul zbicmicronp */
				_5hw_=_5iw; _5xo_=_5yo; _5kx_=_5lx; _5hv_=_5iv; _5kj_=_5lj; _5kz_=_5lz; /* pour calcul pvind */
				_hsupVous_=_hsupConj; /* pour calcul rev_cat */
				%end;
			%else %if &declarant. = p1 %then %do;
				_1ac_=_1cc; _1ah_=_1ch; /* pour revenus de l'�tranger */
				_5xa_=_5za; _5hb_=_5jb;	_5hh_=_5jh;	_5hd_=_5jd;	_5hi_=_5ji;	_5al_=_5cl; _5hl_=_5jl; _5hx_=_5jx; _5xn_=_5zn;
				_5hc_=_5jc; _5ak_=_5ck; _5hf_=_5jf; _5he_=_5je;
				_5xb_=_5zb;	_5xd_=_5zd;	_5xe_=_5ze;	_5xf_=_5zf;	_5xg_=_5zg;	
				_exp_3an_ = (_5zb>0 and _5zd+_5zf>0 and _5ze+_5zg>0);
				_exp_1an_ = (_5zb>0 and _5zd+_5zf+_5ze+_5zg<=0);
				_exp_2an_ = (_5zb>0 and _exp_3an_=0 and _exp_1an_=0);
				_5kn_=_5mn; _5kb_=_5mb; _5kh_=_5mh; _5ki_=_5mi; _5dg_=_5fg; _5kl_=_5ml; _5kq_=_5mq; _5kr_=_5mr;
				_5kc_=_5mc; _5df_=_5ff; _5ke_=_5me; _5kf_=_5mf;
				_5nh_=_5ph; _5ni_=_5pi; _5us_=_5ws; _5nk_=_5pk; _5ez_=_5gz; _5km_=_5mm; _5nl_=_5pl; _5nz_=_5pz; _5nq_=_5pq; _5nr_=_5pr;
				_5nb_=_5pb; _5nc_=_5pc; _5ur_=_5wr; _5ne_=_5pe; _5nf_=_5pf; _5na_=_5pa; _5ey_=_5gy; _5nm_=_5pm; _5ny_=_5py;
					_5th_=_5vh; _5hk_=_5lk; _5ik_=_5mk;
				_5hp_=_5jp; _5qb_=_5sb; _5qh_=_5sh; _5qi_=_5si; _5xk_=_5zk; _5qk_=_5sk; _5hr_=_5jr; _5hs_=_5js;
				_5qc_=_5sc; _5xj_=_5zj; _5qe_=_5se; _5qd_=_5sd;
				_5sn_=_5os; _5xx_=_5zx; _5sp_=_5ou; _5kv_=_5mv; _5kw_=_5mw;
				_5jg_=_5sf; _5xs_=_5zs; _5jj_=_5sg; _5so_=_5ot; _5tc_=_5vc;
				_5ko_=_5mo; _5kp_=_5mp; _5ta_=_5va;	_5tb_=_5vb;
				_5nn_=_5pn; _5no_=_5po; _5ng_=_5pg; _5nj_=_5pj; _5np_=_5pp; _5nd_=_5pd;
				_5hq_=_5jq; _5te_=_5ve;
				_5ku_=_5mu;
				_5hw_=_5jw;_5xo_=_5zo; _5kx_=_5mx; _5hv_=_5jv; _5kj_=_5mj; _5kz_=_5mz; 
				_hsupVous_=_hsupPac1;
			%end;


			/********************************************************************************/
			/* Etape 2 : Calcul des revenus des ind�pendants et des revenus de l'�tranger 	*/

			/* Rq LO 2018 : certains regroupements sont �tranges (notament pour les PV) mais la somme semble ok */
			/* Par ailleurs on ne g�re pas sp�cialement bien les d�ficits ici */

			/* Gr�ce � l'�tape 1 on n'�crit qu'une seule fois les calculs, comme s'il 
			s'agissait du vous, mais les noms des cases sont suivis d'un '_' */

			/* R�gime agricole sans CGA (hors micro BA) + revenus exon�r�s avec CGA */
			zbag_&declarant.= _5xa_+(&anleg.<=2016)*_5xb_*&E2001.*(1-0.87)+_5hb_+_5hd_+_5hh_+_5hi_*&E2001.+_5al_*&E2001.-_5hl_+_5xv_+_5hx_-_5xn_;
			/* R�gime agricole avec CGA : revenus imposables (b�n�fices r�els) */
			zbag_&declarant._cga= _5hc_+_5ak_+_5xt_+_5he_-_5hf_;
			/* R�gime BIC professionnel r�gime du b�n�fice r�el sans CGA + revenus exon�r�s avec CGA  */
			zbic_&declarant.= _5kn_+_5kb_+_5kh_+_5ki_*&E2001.+_5dg_*&E2001.-_5kl_+_5kq_-_5kr_;
			/* R�gime BIC professionnel r�gime du b�n�fice r�el avec CGA : revenus imposables */
			zbic_&declarant._cga= _5kc_+_5df_+_5ke_-_5kf_;
			/* R�gime BIC non professionnel au benefice r�el normal et simplifi� sans CGA + plus et moins values du r�gime de micro entreprise */
			zbicnp_&declarant.=_5nh_+&E2001.*(_5ni_+_5us_+_5nk_+_5ez_+_5km_+-_5nl_-_5nz_)+_5nq_-_5nr_;
			/* R�gime BIC non professionnel au benefice r�el normal et simplifi� avec CGA */
			zbicnp_&declarant._cga=_5nb_+_5nc_+_5ur_+_5ne_-_5nf_+_5na_+_5ey_+_5nm_-_5ny_;
			/* R�gime BNC professionnel hors micro et plus value avec declaration controlee + revenus exon�r�s avec CGA */
			zbnc_&declarant.=_5hp_+_5qb_+_5qh_+_5qi_*&E2001.+_5xk_*&E2001.-_5qk_*&E2001.;
			/* R�gime BNC professionnel r�gime du b�n�fice r�el avec CGA : revenus imposables */
			zbnc_&declarant._cga=_5qc_+_5xj_-_5qe_+_5qd_;
			/* R�gime BNC non professionnel hors micro et plus value avec declaration controlee + revenus exon�r�s avec CGA */
			zbncnp_&declarant.=_5ik_+&E2001.*_5sn_+&E2001.*_5xx_-&E2001.*_5sp_+_5kv_-_5kw_;
			/* R�gime BNC non professionnel r�gime du b�n�fice r�el avec CGA : revenus imposables */
			zbncnp_&declarant._cga=_5hk_+_5jg_+_5xs_-_5jj_+_5so_+_5tc_;

			/* R�gimes micro : calcul des correctifs abattements fiscaux a appliquer aux chiffres d'affaires pour retrouver des benefices */
			zbamicro_&declarant.=	_5xb_-max(&abatagri.*_5xb_,min(_5xb_,&E2000.))
									+ _5xf_-max(&abatagri.*_5xf_,min(_5xf_,&E2000.))
									+ _5xg_-max(&abatagri.*_5xg_,min(_5xg_,&E2000.))
									+ _5xd_+_5xe_;
			zbamicro_&declarant.=(&anleg>=2017)*(_exp_3an_/3+_exp_2an_/2+_exp_1an_)*zbamicro_&declarant. ;

			zbicmicro_&declarant.=	_5ko_+_5kp_+_5ta_+_5tb_
									-max(&abatmicmarch.*(_5ko_+_5ta_)+&abatmicserv.*(_5kp_+_5tb_),min(_5ko_+_5kp_+_5ta_+_5tb_,&E2000.));
			zbicmicronp_&declarant.=_5nn_+_5no_+_5ng_+_5nj_+_5np_+_5nd_
									-max(&abatmicmarch.*(_5no_+_5ng_+_5nj_)+&abatmicserv.*(_5np_+_5nd_),min(_5no_+_5np_+_5ng_+_5nj_+_5nd_,&E2000.));
			zbncmicro_&declarant.=(_5hq_+_5te_)-max(&abatmicbnc.*(_5hq_+_5te_),min(_5hq_+_5te_,&E2000.));
			zbncmicronp_&declarant.	=_5th_+_5ku_-max(&abatmicbnc.*_5ku_,min(_5ku_,&E2000.))+_5hr_-_5hs_;
			pvind_&declarant.=_5hw_+_5kx_+_5hv_-_5xo_-_5kj_-_5kz_;

			/* Application de l'abattement avec CGA (avant 2006) */
			revind_&declarant._cga	=zbag_&declarant._cga+zbic_&declarant._cga+zbicnp_&declarant._cga+zbncnp_&declarant._cga+zbnc_&declarant._cga;

			if revind_&declarant._cga<&abat_avt2006_lim1. then revind_&declarant._cga=(1-&abat_avt2006_t1.)*revind_&declarant._cga;
			else if 0<revind_&declarant._cga<&abat_avt2006_lim2. then revind_&declarant._cga=
				revind_&declarant._cga-&abat_avt2006_t1.*&abat_avt2006_lim1.-&abat_avt2006_t2.*(revind_&declarant._cga-&abat_avt2006_lim1.);


			/* Regroupement des revenus des independants */
			revind&indice.=zbag_&declarant.+zbic_&declarant.+zbnc_&declarant.+zbicnp_&declarant.+zbncnp_&declarant.
							+zbicmicro_&declarant.+zbicmicronp_&declarant.+zbncmicro_&declarant.+zbncmicronp_&declarant.+zbamicro_&declarant.
							+pvind_&declarant.+revind_&declarant._cga;
			
			/* Revenus de l'�tranger */
			revetr_&indice.=_1ac_+_1ah_;

			/**************************/
			/* 2 - Revenu Global Brut */
			/**************************/

			/* on rajoute les revenus exoneres de la definition (� verifier)
			on fait sans l'abattement de 20 % sur les cga (� changer plus tard) */

			/********************************************************************************/
			/* Etape 3 : Calcul du revenu global brut cat�goriel							*/

			/* TODO : 	- v�rifier pour l'ajout des revenus exon�r�s
						- ajouter l'abattement de 20 % sur les CGA */
			rev_cat&indice.=(sal&indice.
							+_hsupVous_*((2008<&anleg.<2013)+7/12*(&anleg.=2013)+3/12*(&anleg.=2008))
							-deduc&indice.
							+PRB&indice.
							-abatt&indice.)
							+revind&indice.
							-&abat_avt2006_t1.*max(0,min(sal&indice.+_hsupVous_*((2008<&anleg.<2013)+7/12*(&anleg.=2013)+3/12*(&anleg.=2008))-deduc&indice.+PRB&indice.-abatt&indice.,&abat_avt2006_lim1.))
							+revetr_&indice.;
			%Mend CalculRevind;

		%CalculRevind(v);
		%CalculRevind(c);
		%CalculRevind(p1);

		/* Ajustements pour le vous et calcul pour la pac2 */
		rev_cat1=	rev_cat1+RV+rev2+
					_PVCessionDom+_3vm+_3vt+_PVCession_entrepreneur+RevCessValMob_PostAbatt+RevCessValMob_Abatt
					+_3vi+_3vf+_3vd+_3vz+_2ee+_2dh+_2fa
					+rev4_caf+_6gh+_8tm;
		revind4=0;
		revetr_4=_1dc+_1dh;
		rev_cat4=(sal4
					+_hsupPac2*((2008<&anleg.<2013)+7/12*(&anleg.=2013)+3/12*(&anleg.=2008))
					-deduc4
					+PRB4
					-abatt4)
					+revind4
					-&abat_avt2006_t1.*max(0,min((sal4+_hsupPac2*((2008<&anleg.<2013)+7/12*(&anleg.=2013)+3/12*(&anleg.=2008))-deduc4+PRB4-abatt4),&abat_avt2006_lim1.))
					+revetr_4;
		run;
	%Mend RBG;
%RBG;


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
