/********************************************************************************/
/*																				*/
/*								2_CHARGES										*/
/*																				*/
/********************************************************************************/
/* Ce programme calcule les charges sur les revenus et permet de passer du 		*/
/* revenu brut global (calcul� dans le programme 1_rbg) au revenu fiscal de 	*/
/* r�f�rence																	*/
/*																				*/
/* En entr�e : 	modele.rbg&anr1.												*/
/* En sortie : 	modele.rev_imp&anr1.											*/
/********************************************************************************/
/* PLAN 																		*/
/*	A	D�ductions																*/
/*		A1	CSG DEDUCTIBLE SUR REVENUS DU PATRIMOINE							*/
/*		A2	DEDUCTIONS PENSIONS ALIMENTAIRES									*/
/*		A3	DEDUCTIONS FRAIS D ACCUEIL											*/
/*		A4	DEDUCTIONS DIVERSES													*/
/*		A5	PERTES EN CAPITAL													*/	
/*		A6	EPARGNE RETRAITE													*/	
/*		A7	Grosses r�parations effectu�es par les nus propri�taires			*/
/*		A8	INVESTISSEMENT DOM TOM dans le cadre d une entreprise				*/
/*		A9	Versement sur un compte codeveloppement								*/
/*		A10	SOUSCRIPTION SOFIPECHE												*/
/*		A11	SOUSCRIPTION AU CAPITAL DE SOFICA									*/
/*	B	Revenu net global														*/		
/*	C	Abattements sp�ciaux => RIB (revenu imposable)							*/
/*	D	Revenu fiscal de r�f�rence												*/
/********************************************************************************/

%Macro Charges;
	data modele.rev_imp&anr1.;
		set  modele.rbg&anr1.	(keep=	declar rbg: _6: _2bh _2dh _2ch nb: sif age: case_t case_k case_l 
										mcdvo _2dc _2fa _2fu RevCessValMob_PostAbatt RevCessValMob_Abatt
										FraisDeductibles_Restants _7uh _perte_capital _perte_capital_passe 
										quotient: rev2: _5ql _5rl _5sl _5sv _5sw _5sx
										_hsupVous _hsupConj _hsupPac1 _hsupPac2 EXO _8ti _1ah _1bh _1ch _1dh
										_8by _8th _8cy _2ee _2tr _2tt PVmicro _PVCessionDom
										PVT _PVCession_entrepreneur _3vm _3vt _3vg _3sg _3sl _3va _3vi _3vf  _3vz _3wb
										chiffaff _interet_pret_conso _nb_vehicpropre_simple _nb_vehicpropre_destr 
										_relocalisation _epargneCodev ident _8tk _4by _4bh _4bc
										anaisenf rev_cat: 
										_7db _7df _7g: _souscSofipeche _cred_loc _7fn _1ao _1bo 
										_1co _1do _1eo _1as _1bs _1cs _1ds _1es _1al _1bl _1cl _1dl _1el _1am _1bm _1cm _1dm _1em 
										_1az _1bz _1cz _1dz _3se
										_3wa _3vd _3sb
										_1at _1bt AE:
										_rachatretraite_vous _rachatretraite_conj);


		/*-----------------------------------------------------------*/
		/* A - D�ductions -------------------------------------------*/
		/*-----------------------------------------------------------*/


		/* A1	CSG DEDUCTIBLE SUR REVENUS DU PATRIMOINE */
		DEDZ=_6de+&Tcsgd.*_2bh; 
		/* Pas forc�ment optimal : 
		la case _2bh n'est pas consid�r�e comme une charge deductible ds la brochure pratique
		m�me si elle n'est pas deduite pour le RBG
		PB : cette case n'est remplie que si l'administration fiscale a mal prerempli la case, donc il faudrait recalculer cette 
		csg patrimoine � partir des revenus categoriels comme le fait l'ERF (meme s'il s agit de celle de l'annee d'avant) */

		/* A2	DEDUCTIONS PENSIONS ALIMENTAIRES -----------------------------------*/
		/* plafond doubl� pour personnes subvenant seules � l'entretien d'un enfant mari� pacs� ou charg� de famille */
		augm_plaf=0;
		augm_plaf=(case_l='L' or case_t='T' or case_k='K') & nbn>0;
		DED_pension=_6gu+
					&E2001.*_6gp+
					min(&E2001.*_6gi ,&P0490.)+
					min(&E2001.*_6gj ,&P0490.)+
					min(_6el,&P0490.*(1+augm_plaf))+
					min(_6em,&P0490.*(1+augm_plaf));

		/* A3	DEDUCTIONS FRAIS D ACCUEIL------------------------------------------*/
		/* modif : non cumulable avec la majoration du quotient familial li�e � la pr�sence sous 
		le m�me toit d une personne titulaire de la carte d invalidit� >=80% (case R) */ 
		DED_accueil=_6ev*min(&P0535.,_6eu)*(nbr=0);

		/* A4	DEDUCTIONS DIVERSES-------------------------------------------------*/
		DEDd=_6dd;

		/* A5	PERTES EN CAPITAL--------------------------------*/
		ded_perte=	min(_perte_capital,&ded_cap1.*(1+(mcdvo in ('M','O'))))+
					min(_perte_capital_passe,&ded_cap2.*(1+(mcdvo in ('M','O'))));

		/* A6	EPARGNE RETRAITE----------------------------------------------------*/
		/* Il n'y a rien d'indiqu� en _6ps si l'individu n'a pas vers� de cotisations auparavant. Dans ce cas, on calcule
		un plafond approximatif, fonction d'un revenu (qui n'est pas exactement le bon mais devrait s'en rapprocher) born� par
		1 et 8 PASS, cumul� sur 3 ans. On se permet cette approximation d'une part parce que le plafonnement 
		effectif des cotisations devrait etre rare et d'autre part parce qu'on peut cumuler les plafonds sur trois ans et ceux-l� 
		sont eux-m�mes fonction du revenu per�u les ann�es pr�c�dentes, que l'on ne peut pas connaitre. */
		if _6ps=0 then _6ps=3*0.1*max(&plafondssa.,min(rev_cat1,8*&plafondssa.));
		if _6pt=0 then _6pt=3*0.1*max(&plafondssa.,min(rev_cat2,8*&plafondssa.));
		if _6pu=0 then _6pu=3*0.1*max(&plafondssa.,min(rev_cat2,8*&plafondssa.));
		_6RS_plaf=min(_6RS+_rachatretraite_vous,_6ps);
		_6RT_plaf=min(_6RT+_rachatretraite_conj,_6pt);
		_6RU_plaf=min(_6RU,_6pu);
		if _6qr=1 then do; /* mutualisation des plafonds de d�duction des conjoints */
			if _6RS_plaf>0 then do;
				if _6RS_plaf=_6ps and _6RT_plaf ne _6pt then
					/*si le conjoint n'a pas atteint son plafond, le d�clarant l utilise*/
					_6RS_plaf=Max(0,_6RS_plaf-(_6pt-_6RT_plaf));
				end;
			if _6RT_plaf>0 then do;
				if _6RS_plaf ne _6ps and _6RT_plaf=_6pt then
					/*si le d�clarant n a pas atteint son plafond, le conjoint l utilise*/
					_6RT_plaf=Max(0,_6RT_plaf-(_6ps-_6RS_plaf));
				end;
			end;
		DED_perp=_6RS_plaf+_6RT_plaf+_6RU_plaf;
		label DED_perp="D�duction : cotisations et rachats de cotisations d'�pargne retraite";
		%if &anleg.<2002 %then %do;
			DED_perp=0;
			%end; 

		/* A7	Grosses r�parations effectu�es par les nus propri�taires*/
		DED_repar=min(_6cb+_6hj+_6hk+_6hl+_6hm+_6hn+_6ho+_6hp,&ded_repar_plaf.);
		label DED_repar="D�duction : d�penses de grosses r�parations effectu�s par les nus propri�taires";

		/* Ecart � la l�gislation : navires neufs
									d�ductions pour monuments qui �taient dans d�ductions diverses*/

		/* A8	INVESTISSEMENT DOM TOM dans le cadre d une entreprise---------*/
		/* Non cod� */

		/* On calcule un revenu net global "interm�diaire", dont d�pendent certaines charges d�ductibles */ 
		RNG1=max((RBG-(DED_pension+DED_accueil+DED_perp+DEDD+DEDZ)),0);

		/* A9	Versement sur un compte codeveloppement*/
		/* limite de 25% du revenu net global et de 20 000� par personne composant le foyer fiscal */
		pfoy=1+(mcdvo in ('M','O'))+sum(nbf,nbr,nbj,nbn);

		if (_epargneCodev<=&pcodtx.*(RNG1-_epargneCodev)) then DED_CODEV=min(_epargneCodev,pfoy*&pcodplaf.);
		if (_epargneCodev> &pcodtx.*(RNG1-_epargneCodev)) then DED_CODEV=Min(RNG1/5,pfoy*&pcodplaf.);

		/* A10	SOUSCRIPTION SOFIPECHE--------------------------------------------*/
		ded_sofipeche=0;
		ded_sofipeche=Min(_souscSofipeche,&sofipeche_tlim_r.*RNG1);
		ded_sofipeche=min(ded_sofipeche,&sofipeche_mlim_r.*(1+(mcdvo in ('M','O'))))*(&anleg.<=2007);

		/* A11	SOUSCRIPTION AU CAPITAL DE SOFICA */
		ded_sofica=0;
		ded_sofica=(Min(_7gn,Min(&sofica_tlim.*RNG1,&sofica_mlim.))
					+Min(_7fn,Min(&sofica_tlim.*RNG1,&sofica_mlim.)))*(&anleg.<=2006);

		/* Total des d�ductions */
		DEDUC=DED_pension+DED_accueil+DED_perp+DEDD+DEDZ+ded_sofica+ded_sofipeche
			+ded_codev+ded_repar+ded_perte;


		/*--------------------------------------------------------------------*/
		/*B - REVENU NET GLOBAL-----------------------------------------------*/
		/*--------------------------------------------------------------------*/
		
		/* 	RNG1 : d�j� calcul� avant les charges d�ductibles li�es � un versement sur un compte codeveloppement, 
			une souscription sofipeche et une souscription au capital de Sofica */

		RNG=max((RBG-DEDUC),0);

		/* On ajoute au RNG les gains de lev�e d'options sur titre et les revenus exceptionnels ou diff�r�s */
		RNG2=RNG + quotient2 + quotient3 + quotient4;

		/*-----------------------------------------------------------*/
		/* C - ABATTEMENTS SPECIAUX----------------------------------*/
		/*-----------------------------------------------------------*/

		/* ABATTEMENT POUR PERSONNES AGEES-INVALIDES ---------------------------*/
		pfswlt=substr(sif,33,1);
		ABTINV1=0;ABTINV2=0;
		IF (aged>=65 OR index( substr(sif,15,20) ,"P")>0) 
			THEN ABTINV1=1;
			ELSE ABTINV1=0;
		IF (agec>=65 OR (index( substr(sif,15,20) ,"F")>0) ) 
			THEN ABTINV2=1;
			ELSE ABTINV2=0;
		ABTINV=min(ABTINV1+ABTINV2,1+(agec>0));
		/* on ne peut avoir qu un abattement si on est tout seul alors que 
		si on a plus de 65 ans et que le conjoint est d�c�d� dans l ann�e on peut avoir les deux abattements*/
		IF RNG<&P0580. THEN RNGA=max((RNG-&P0590.*ABTINV),0);
		ELSE IF &P0580.<=RNG<=&P0600. THEN RNGA=max((RNG-&P0610.*ABTINV),0);
		ELSE RNGA=RNG;
		abat_spec=RNG-RNGA;

		/* ABATTEMENT POUR ENFANT A CHARGE MARIE -------------------------------*/
		RIB=max((RNGA-nbn*&P0620.),0);
		/* Revenu imposable */

		/*-----------------------------------------------------------*/
		/* D - Revenu Fiscal de R�f�rence ---------------------------*/
		/*-----------------------------------------------------------*/

		rev2abat_prime=0;
		if mcdvo in ('M','O') & _2dc + _2fu>0 
			then rev2abat_prime=max(_2dc+_2fu-FraisDeductibles_Restants-&P0286.,0);
		else if _2dc+_2fu>0
			then rev2abat_prime= max(_2dc + _2fu-FraisDeductibles_Restants-&P0285.,0);

		rev_hsup_exon=(_hsupVous+_hsupConj+_hsupPac1+_hsupPac2)*((2008<&anleg.<2013)+7/12*(&anleg.=2013)+3/12*(&anleg.=2008));
						
		/*  Revenu fiscal de r�f�rence (qui inclut les revenus des autoentrepreneurs): se r�f�rer au CGI, article 1417-IV 
			et � la Brochure Pratique pour le d�tail des revenus � inclure */
		RFR=RIB+
				(quotient2/2 +quotient3/3+quotient4/4)*(&anleg.>2000)+ 
				 dedd+ded_sofica+	/* abattement de 40% sur les revenus distribu�s
											(sous d�duction de la fraction non utilis�e de l'abattement) */
				max(0,-rev2abat+rev2abat_prime)+				
				_5ql+_5rl+_5sl+_5sv+_5sw+_5sx+	/* abattement 50% pour les jeunes cr�ateurs */
				rev_hsup_exon+ 					/* heures et jours suppl�mentaires exon�r�s */
				EXO+							/* revenus exon�r�s, yc revenus de source �trang�re */
				max(&abat10.*_8by,_8by-&abat10_plaf.)*(_8th=0)+
				max(&abat10.*_8cy,_8cy-&abat10_plaf.)*(_8th=0)+
				_2ee+_2dh+_2fa+					/* revenus de VCM ou de plus-values non soumises au bar�me */
				PVT/&P0750.+
				_PVCessionDom+_3vm+_3vt+_PVCession_entrepreneur+_3vi+_3vf+_3vd+_3vz
				+RevCessValMob_Abatt
				+(RevCessValMob_PostAbatt*(&anleg.<2014)) /* sinon d�j� inclus dans rev3 donc dans RBG donc dans RIB */
				+_3se /* pris en compte que pour le RFR (cf. Brochure Pratique, plus-values et distributions des non-r�dients) */ ;
		label RFR="RFR : Revenu fiscal de r�f�rence";

		run;
	%Mend Charges;

%Charges;


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
