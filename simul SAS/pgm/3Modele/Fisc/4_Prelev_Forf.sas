/****************************************************************************************************/
/*																									*/
/*									4_Prelev_Forf													*/
/*																									*/
/****************************************************************************************************/
/*																									*/
/*	En entrée :		modele.rev_imp&anr1.															*/
/*					modele.nbpart																	*/
/*					modele.rev_imp&anr.																*/
/*	En sortie : 	modele.rev_imp&anr1.															*/
/*					modele.Prelev_Forf&anr2.														*/
/****************************************************************************************************/
/*	Plan :																							*/ 
/*	A	Calcul de l'éligibilité des autoentrepreneurs au prélèvement forfaitaire libératoire 		*/
/*	B	Calcul de l'éligibilité au prélèvement forfaitaire obligatoire et du montant de ce PFO  	*/
/****************************************************************************************************/
/* Remarques :																						*/ 
/* 	Ce programme est appelé deux fois dans l'enchaînement : 										*/	
/*	 - d'abord dans le premier "bloc impôt", qui permet de calculer le RFR N-2, mais aussi 			*/
/*	   l'éligibilité en N-1 au PF qui en découle													*/
/*	 - puis dans le deuxième "bloc impôt", qui calcule le RFR N-1, et aussi l'éligibilité en N-1 au */
/*     PF qui en découle																			*/
/*																									*/
/*	Dans le premier bloc, on a anr=anr1=anref, anr2=anref+1, et anleg=anleg-1. 						*/
/*	Donc la condition sur le RFR en N-2 est en fait une condition sur le RFR en N-1 				*/
/*	(mais on ne peut pas faire mieux). 																*/
/*																									*/
/*	Dans le deuxième bloc, on a anr=anref, anr1=anref+1, anr2=anref+2, et anleg=anleg. Donc la 		*/
/*  condition sur le RFR en N-2 est juste. 															*/
/****************************************************************************************************/


/***********************************************************************************************************************************/
/*	A	Calcul de l'éligibilité des autoentrepreneurs au prélèvement forfaitaire libératoire (dépend du RFR et du nombre de parts) */
/***********************************************************************************************************************************/

/* Législation : 
	Afin de ne pas différer d'un an la perception des revenus d'autoentreprenariat de leur imposition, 
	les AE dont le RFR de N-2 n'excède pas le seuil sup de la troisième tranche peuvent opter ou non 
	pour un prélévement forfaitaire libératoire de l'IR. 
	Du coup ces revenus ne sont plus imposés au barème de l'IR l'année suivante. 
	Effet de bord : les autres revenus du foyer seraient alors imposés à un taux marginal plus faible (ou égal)
	D'où le principe du taux effectif : le taux moyen d'imposition est calculé comme si le revenu imposable 
	incluait les revenus des AE; ie comme s'il n'y avait pas eu d'option pour le PF */

/* Pour Ines : 
	En année N est payé : 
	- le PFL de ceux qui ont opté pour sur les revenus AE de l'année N
		-> codé dans Prelev_Forf.sas en fonction de l'éligibilité en N
	- l'IR de ceux qui avaient opté pour le PFL en N-1
		-> codé dans 5_impot.sas en fonction de l'éligibilité en N-1
	- l'IR de ceux qui n'avaient pas opté pour le PFL en N-1
		-> codé dans 5_impot.sas en fonction de l'éligibilité en N-1
	Hypothèses : 
	- tous ceux qui peuvent opter pour le PFL le font (rationalité)
	- pour l'éligibilité en N on regarde le RFR N-1 au lieu de N-2 et on le compare à AE_PF_plaf de N au lieu de N-1
	- de même, pour l'éligibilité en N-1 on regarde le RFR N-2 au lieu de N-3 et AE_PF_plaf de N-1 au lieu de N-2 */

/* Eligibles en &anr2. : le RFR de &anr1. est < au plafond de la troisième tranche d'IR (d'anleg) */
proc sql;
	create table AE_eliPFL as
		select 	a.declar, a.AE & (a.rfr/b.npart)<&PF_AE_plaf. as AE_eliPFL&anr2.
		from modele.rev_imp&anr1. as a inner join modele.nbpart as b
		on a.declar=b.declar
		having AE_eliPFL&anr2.
		order by declar;
	quit;


data modele.rev_imp&anr1.;
	merge	modele.rev_imp&anr1. (in=a)
			AE_eliPFL (in=b);
	if a;
	by declar;
	AE_eliPFL&anr2.=b;
	label AE_eliPFL&anr2.="S'agit-il d'un autoentrepreneur qui opte pour le PFL en &anr2. ? ";
	run;

proc delete data=AE_eliPFL; run;



/*************************************************************************************/
/*	B	Calcul du prélèvement forfaitaire libératoire / obligatoire à partir de 2013 */
/*************************************************************************************/

/* Remarques : 
	- 	à partir de 2013, les dividendes et produits de placements à revenu fixe deviennent imposables
		au barème à la place du prélèvement forfaitaire libératoire. L'imposition se fait en deux temps : un 
		prélèvement forfaitaire obligatoire prélevé à la source et une régularisation l'année suivante avec la 
		déclaration d'impôt. Ce prélèvement n'est pas obligatoire pour les foyers dont le RFR est en dessous d'un 
		certain seuil (différent pour les dividendes et pour les revenus de placement). 
	- 	pour la case 2ee, le taux n'est pas unique. Par manque d'information, on applique un taux moyen fixe de 20 % 
		(source : Bilan de production de l'ERFS) % */

%macro PFO;
	/* Prélèvement forfaitaire libératoire jusqu'en 2012 et obligatoire à partir de 2013 sur les placements bancaires */
	/* Ce calcul doit être effectué si : 
		- on est dans le deuxième appel de l'enchaînement (dans ce cas on le calcule pour l'année anleg)
		- on est dans le premier appel ET on a besoin de cette info parce qu'on n'en a pas encore dans la case _2ck */

	%put APPEL : &Appel. / ANLEG : &anleg. / ANREF : &anref.;
	%if	(&Appel.=2) or (&Appel.=1 and (&anleg.+1)>=2014 and &anref.<2013) %then %do;
		/* Deuxième condition : on doit	créer une information pour "remplacer" la case _2ck que l'on n'a pas encore (cf. deduc.sas) */
		%put Le calcul du prélèvement forfaitaire pour l année &anr2. est effectué.;

		proc sql;
			create table modele.Prelev_Forf&anr2. as
			select 	a.declar, a.RFR as RFR&anr., b.ident, b.mcdvo, b._2dh, b._2dc, b._2tr, b._2tt, b._2ee, b._2fa, b._2fu, b._2ch, b._2ts, b._2go
			from modele.rev_imp&anr. as a
				inner join base.foyer&anr2. as b on a.declar=b.declar;
			quit;

		data modele.Prelev_Forf&anr2. (keep=Prelev_Forf ident declar PF:);
			set modele.Prelev_Forf&anr2.;

			%Init_Valeur(PF_Liberatoire PF_Obligatoire);
			/* PF obligatoire pourrait s'appeler non libératoire mais ce n'est le cas que depuis 2013 donc on met un nom plus général */

			/* 1	Assurances-vie : prélèvement forfaitaire toujours libératoire même après 2013
					à 7,5 % pour les produits détenus depuis 6/8 ans ou plus (2dh) */
			PF_Liberatoire=&prel_lib_t2.*max(0,_2dh);

			/* 2	Autres produits de placement soumis à un prélèvement libératoire (même après 2013) */
			PF_Liberatoire=PF_Liberatoire+&tx_moy_2ee.*_2ee; /* imposition moyenne à 20 % (taux moyen d'après le bilan de production ERFS */
			/* 	Problème ici : la case 2ee est mixte entre : 
				- des produits d'Assurance-vie détenus depuis moins de 6 ans avant 1989 / 8 ans après 1990 : taux de 15 ou 35 %
				- des produits d'épargne solidaire : taux de 5 %
				- des produits de placement payés dans un Etat non coopératif : taux de 75 %
				Ecarts à la législation : 
				- on met tout au taux moyen estimé à 20 %
				- une partie de ce PF est effectué sur option du contribuable, on considère que tous choisissent cette option */

			/* 3	Actions et parts, et autres produits de placement soumis au prélèvement obligatoire */

			%if &anleg.>=2013 %then %do;
				/* A partir de 2013 : Prélèvement forfaitaire obligatoire non libératoire, avec différentes possibilités d'exemption : 
					1\ Possibilité d'exemption du PFO sur les revenus distribués (_2dc) si RFR suffisamment faible
					2\ Possibilité d'exemption du PFO sur les produits de placement à revenu fixe (_2tr) si RFR suffisamment faible
					3\ Possibilité d'option pour un PF à 24 % pour les revenus <2000 euros (_2fa), sans condition sur le RFR */

				/* Cas 1 et 2 : deux possibilités polaires possibles : 
					(i)		Hypothèse rationnelle : personne ne souhaite être soumis au PFO s'il a le choix de capitaliser sur ces revenus un an de plus
					(ii)	Hypothèse réaliste : personne ne demande l'exemption du PFO car c'est trop compliqué. 
				Dans un premier temps nous avions pris la première option pour Ines, mais au vu des montants de restitution d'impôt 
				de PFO pour l'impôt 2014 (case _2ck), on pense que la deuxième hypothèse est préférable car beaucoup plus réaliste. 
				=> conclusion : on opte pour la solution (ii) : on met le PFO à tout le monde */
				PF_Obligatoire=PF_Obligatoire+&prel_lib_t1.*_2dc;
					/* la condition était : if RFR&anr.>&PFO_divid_lim1.*(mcdvo not in ('M','O')) + &PFO_divid_lim2.*(mcdvo in ('M','O')) */

			/*TO DO 2018: changement législatif sur les prélèvements libératoire forfaitaires*/
				PF_Obligatoire=PF_Obligatoire+(&prel_lib_t3.*(_2tr + _2tt));
	
				
					/* la condition était : if RFR&anr.>&PFO_autres_lim.*(1+(mcdvo in ('M','O'))) */
					/* NB : pour le premier appel à ce programme le RFR de N-2 serait alors approché par le RFR de N-1, puisqu'on n'a pas mieux */
				%end;

			/* Cas 3 : Possibilité d'opter pour un prélèvement forfaitaire à 24 % pour les revenus <2000 euros (sans condition sur le RFR) */
			PF_Liberatoire=PF_Liberatoire+&prel_lib_t3.*_2fa;

			/* On ne calcule pas de prélèvement forfaitaire sur la case _2ts */

			Prelev_Forf=PF_Liberatoire+PF_Obligatoire;
			label Prelev_Forf="Prélèvement forfaitaire sur les revenus de placement";
			run;
		%end;
	%Mend PFO;

%PFO;


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
