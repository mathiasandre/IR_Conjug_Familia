/************************************************************************************************/
/*																								*/
/*								3_Prelev_RevPat													*/
/*																								*/
/************************************************************************************************/
/*																								*/
/* Calcul des prélèvements sociaux (CSG, CRDS, prélèvement social etc.) sur les     			*/
/* revenus du patrimoine.																		*/	
/*																								*/
/* En entrée : 	base.foyer&anr1.                      			 								*/
/*				base.foyer&anr2.																*/
/*				base.menage&anr2.																*/
/* En sortie : 	modele.prelev_pat_n1															*/
/*				modele.prelev_pat_n																*/
/*				modele.csg_pat																	*/
/************************************************************************************************/
/* Remarques : 																					*/	
/*  1. programme valide à partir de 1985														*/
/*  2. Lors d'une cession d'une action sur option, le bénéfice se décompose en 2 parties : le 	*/
/*     gain de levée d'option et la plus-value de cession. Le gain de levée d'option est la		*/ 
/*     différence entre la valeur de l'action au moment de la levée d'option et le prix 		*/
/*     d'acquisition. La plus-value de cession est la différence entre le prix de cession et la */
/*     valeur de l'action au moment de la levée d'option. La première partie est imposée au     */
/*     quotient et considéré au même titre qu'un salaire. 										*/
/*	3. csgpatf regroupe tous les prélèvements sur les revenus du patrimoine						*/ 
/*	4. On repère les revenus exonérés de tous prélèvements sociaux (revenu des micro entreprises*/  
/*     et des revenu non CGA non professionnel pour les BIC)									*/
/*	5. Les revenus défiscalisés sont les déficits non professionnels des années antérieures		*/
/*	6. Il y a un problème sur le seuil de recouvrement car il faudrait calculer le seuil de 	*/
/*     recouvrement sur le montant de l impot plus prélèvements et pas séparement				*/
/************************************************************************************************/
/* Plan :																						*/
/* 	I. Prélèvements sociaux sur les revenus du patrimoine prélevés un an plus tard				*/ 
/* 	II. Prélèvements sociaux sur les revenus du patrimoine prélevés l'année de perception		*/	
/*		II.1. information au niveau du foyer fiscal 											*/
/*		II.2. information au niveau du ménage													*/
/************************************************************************************************/

/************************************************************************************/
/* I	Prélèvements sociaux sur les revenus du patrimoine prélevés un an plus tard */
/************************************************************************************/

%Macro Prelev_AnneeSuivante;
	data modele.prelev_pat_n1 	(keep=csg: crds: autreps: ident declar contrib_sal); 
		set base.foyer&anr1.	(keep=	_5: ident declar zracf zglof _2ca _4be  _6de _8sa _8sb _revImpCRDS _8tq _8tr _8tv _8tw _8tx _8sc _8sw _8sx
										_glo1_2ansVous _glo2_3ansVous _1tx _glo1_2ansConj _1tt _1ut _glo2_3ansConj _1ux 
										/*zglof*/ _3vf _3vi _3vj _3vk _3vd _3vn _1tt _1ut _1tz _3sj _3sk _3wm _glo_tx:
										/*RV*/ _1aw _1bw _1cw _1dw _1ar _1br _1cr _1dr
 										/*rev4*/ _4ba _4bb _4bc _4bd _4be _3wm);
										/* _glo1_2ansVous _glo2_3ansVous _1tx _glo1_2ansConj _1tt _1ut _glo2_3ansConj _1ux : ces cases correspondent au gain
										de levee d'option ou d'acquisition d'actions gratuites et sont taxés comme les salaires, soumis au système du quotient */

		RV1=(sum(_1aw,_1ar,0)*&rvto_tx1.);
		RV2=(sum(_1bw,_1br,0)*&rvto_tx2.);
		RV3=(sum(_1cw,_1cr,0)*&rvto_tx3.);
		RV4=(sum(_1dw,_1dr,0)*&rvto_tx4.);
		RV=sum(0,RV1,RV2,RV3,RV4);

		%Init_Valeur(foncplus microfonc microfonc_caf);
		if _4be <= &plafmicrof. then do; 
			microfonc		=max((_4be*(1-&tx_microfonc.)-_4bd),0);
			microfonc_caf	=_4be*(1-&tx_microfonc.);
			/* option pour le micro-foncier exclut l'application des deficits de l'annee. 
			Mais les deficits des annees anterieures peuvent etre imputes sur les revenus nets determines selon le regime micro-foncier */
			end;
		else do; 
			foncplus		=_4be - &plafmicrof.;
			microfonc_caf	=&plafmicrof.*(1-&tx_microfonc.);
			end;

		_4bc  =min(_4bc,&max_deficit_fonc.);	/* on passe parfois au dessus de la limite à cause de la dérive */
		rev4c =_4ba+foncplus-_4bb;				/* 4c correspond à la case c de la brochure pratique */
		rev4e =0;
		if rev4c>=0 then do;
			rev4e=rev4c-_4bc;
			if rev4e>=0 then rev4e=max(rev4e-_4bd,0);
			end;
		else if rev4c<0 then do;
			if _4bc>0 then rev4e=-_4bc; 
			else rev4=0;
			end;
		rev4=rev4e+microfonc;

		%if &anleg.>1985 %then %do; 
			exozacc=	sum(_5nn,_5on,_5pn,_5nb,_5ob,_5pb, _5nh, _5oh, _5ph,_5tc,_5uc,_5vc );
			defizacc=	sum(_5rn,_5ro,_5rp,_5rq,_5rr,_5rw);
			csgpatf=	&csg_pat_janv.*(RV+max(0,rev4+zracf-exozacc-defizacc));
			crdspatf=	&crds_pat_janv.*(RV+max(0,rev4+zracf-exozacc-defizacc));
			autrepspatf=(&ps_pat_janv.+&casa_pat_janv.+&prsa_pat_janv.+&psol_pat_janv.)*(RV+max(0,rev4+zracf-exozacc-defizacc));
			if csgpatf+crdspatf+autrepspatf<&recouv. then csgpatf=0;
			csgdpatf=	_6de; 
			/* Séparation de zglof entre cases soumises aux prélèvements à 15,5% (revenu du capital, zglofcap) et celles soumises à 8% (revenu du travail, zgloftrav) */
			zglofcap = sum(_glo1_2ansVous, _glo2_3ansVous, _1tx, _glo1_2ansConj, _glo2_3ansConj, _1ux, _1tz, _3vd, _3vi, _3vf, _3vj, _3vk);
			zgloftrav = sum(_1tt, _1ut);
			csgglof=	&csg_pat_janv.*zglofcap + (&Tcsgi.+&Tcsgd.)*zgloftrav;
			crdsglof=	&crds_pat_janv.*zglofcap + &Tcrds.*zgloftrav;
			autrepsglof=(&ps_pat_janv.+&casa_pat_janv.+&prsa_pat_janv.+&psol_pat_janv.)*zglofcap;
			crds_etr=	&tcrdsBN.*(_8tr+_8tq+_8tv+_8tw+_8tx+_8sa+_8sb+_8sc+_8sw+_8sx); /* taux de CRDS sur l'assiette */
			/* Avant l'ERFS 2012 on avait de l'info en plus dans la case _8tl (transférée dans le nom explicite _revImpCRDS). 
			La case a disparu en 2012 (réapparue en 2013 avec un autre sens). 
			On n'utilise pas cette info dans Ines, on prend plutôt l'ensemble des revenus soumis à la CSG puisqu'ils le sont aussi à la CRDS. 
			Avant l'ERFS 2012 on pourrait utiliser le contenu de _revImpCRDS mais cela demanderait de faire référence à ANREF ici. 
			Depuis l'ERFS 2014, apparition des pensions en capital de l'étranger soumises au PL qui sont redevables de CSG et CRDS (8sa et 8sb)*/
			csg_etr=	(&tcsgi.+&tcsgd.)*(_8tq+_8tr+_8sc) + (&tcsgPRd2.+&tcsgPRi.)*(_8tv+_8sa) +(&tcsgchd.+&tcsgchi.)*(_8tw+_8sw) + &TcsgPRd1.*(_8tx+_8sb+_8sx);

			/* Contribution salariale */
			/* En général : un taux unique */
			contrib_sal=&contrib_saltx1.*(	_3vn /* Attribuées avant le 28/09/2012 */
											+_1tt+_1ut /* Attribuées entre 28/09/2012 et 08/08/2015 */);
			/* Le taux de contribution salariale pour les actions gratuites attribuées après le 08/08/2015 est de 0% */

			/* Mais en 2013 et 2012 particulier car cohabitation de 2 ou 3 taux */
			%if &anleg.=2013 %then %do;
				contrib_sal=	&contrib_saltx1.*(_3vn+_1tt+_1ut-_glo_txmoyen-_glo_txfaible)
								/* Soustraction liée à ce qui est fait dans init_foyer où tout est transféré dans _3vn */
							+ 	&contrib_saltx2.*_glo_txmoyen
							+	&contrib_saltx3.*_glo_txfaible;
				%end;
			%else %if &anleg.=2012 %then %do;
				contrib_sal=	&contrib_saltx1.*(_3vn-_glo_txfaible)
							+ 	&contrib_saltx2.*_glo_txfaible;
				%end;
			%end;
		run;

	%Mend Prelev_AnneeSuivante;
%Prelev_AnneeSuivante;


/******************************************************************************************/
/* II	Prélèvements sociaux sur les revenus du patrimoine prélevés l'année de perception */
/******************************************************************************************/

%Macro Prelev_AnneeCourante;

	/* II.1	Niveau foyer */
	data modele.prelev_pat_n 	(keep=csg: crds: autreps: ident declar _2ck Assiette_ValMob); 
		set base.foyer&anr2.	(keep=	ident declar
										zdivpf _3se _3vw _3wg _3vc _3vz _3wi _3wj
										_abatt_moinsval _abatt_moinsval_renfor _abatt_moinsval_dirpme
										zvamf _2dc _2ts _2go _2tr _2tt _2fa _2dm
										zavff _2ab _2ck _2bg
										_2ca
										_2ee);
		Assiette_Div=zdivpf 
					- ((_abatt_moinsval_renfor + _abatt_moinsval+_abatt_moinsval_dirpme)*(&anleg.<2016)) /* Avant 2016 les abattements 
					s'appliquant aux moins values étaient inclus dans l'assiette des prélèvements sur le patrimoine (par soustraction) */
					- _3se /* incluse uniquement pour le calcul du RFR */
					- _3vw /* plus-values exonérées */
					- _3wg - (_3wi+_3wj)/* plus-values en report d'imposition */
					/* - (_3vc+_3vz)*/ /* exonération car déjà imposées à la source. TODO : vérifier qu'on code bien cette imposition, ici ou ailleurs */
					;
		csgdivf=		Max(0,&csg_pat_moy.*Assiette_Div);
		crdsdivf=		Max(0,&crds_pat_moy.*Assiette_Div);
		autrepsdivf=	Max(0,(&ps_pat_moy.+&casa_pat_moy.+&prsa_pat_moy.+&psol_pat_moy.)*Assiette_Div);

		Assiette_ValMob=max(0,
						 (_2dc+_2ts+_2go+_2tr+_2tt+_2fa+_2dm)/* =zvamf-_2fu-_2ch */
						+(_2ab+_2ck+_2bg)				/* =zavff-_8ta */
						-_2ca);							/* frais et charges déductibles */
		CsgValMob=		&csg_pat_moy.*Assiette_ValMob;
		CrdsValMob=		&crds_pat_moy.*Assiette_ValMob;
		AutrePSValMob=	(&ps_pat_moy.+&casa_pat_moy.+&prsa_pat_moy.+&psol_pat_moy.)*Assiette_ValMob;

		csgvalf=		&csg_pat_moy.*_2ee;
		crdsvalf=		&crds_pat_moy.*_2ee;
		autrepsvalf=	(&ps_pat_moy.+&casa_pat_moy.+&prsa_pat_moy.+&psol_pat_moy.)*_2ee;
		run;

	/* Cas où on n'a pas encore l'information dans la case _2ck mais on a calculé quelque chose d'équivalent dans un premier appel au programme Prelev_Forf */
	%if	(&anleg.>=2014 and &anref.<2013) %then %do;
		data modele.prelev_pat_n (drop=PF_Obligatoire);
			merge	modele.prelev_pat_n
					modele.Prelev_Forf&anr1. (keep=declar PF_Obligatoire);
			by declar;
			Assiette_ValMob=Assiette_ValMob-_2ck+PF_Obligatoire;
			/* On écrase les valeurs des trois variables suivantes */
			CsgValMob=		&csg_pat_moy.*Assiette_ValMob;
			CrdsValMob=		&crds_pat_moy.*Assiette_ValMob;
			AutrePSValMob=	(&ps_pat_moy.+&casa_pat_moy.+&prsa_pat_moy.+&psol_pat_moy.)*Assiette_ValMob;
			run;
		%end;

	/* II.2	Niveau ménage */
	data modele.csg_pat ; 
		set base.menage&anr2.	(keep=ident pelm peam celm assviem nbind nb_uci); 
		csgpat_im=		&csg_pat_moy.*sum(pelm,peam,celm,assviem);
		crdspat_im=		&crds_pat_moy.*sum(pelm,peam,celm,assviem);
		autrepspat_im=	(&ps_pat_moy.+&casa_pat_moy.+&prsa_pat_moy.+&psol_pat_moy.)*sum(pelm,peam,celm,assviem);
		run;

	%Mend Prelev_AnneeCourante;
%Prelev_AnneeCourante;



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
