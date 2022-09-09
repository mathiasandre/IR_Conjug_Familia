/****************************************************************************************************/
/*																									*/
/*									4_Prelev_Forf													*/
/*																									*/
/****************************************************************************************************/
/*																									*/
/*	En entr�e :		modele.rev_imp&anr1.															*/
/*					modele.nbpart																	*/
/*					modele.rev_imp&anr.																*/
/*	En sortie : 	modele.rev_imp&anr1.															*/
/*					modele.Prelev_Forf&anr2.														*/
/****************************************************************************************************/
/*	Plan :																							*/ 
/*	A	Calcul de l'�ligibilit� des autoentrepreneurs au pr�l�vement forfaitaire lib�ratoire 		*/
/*	B	Calcul de l'�ligibilit� au pr�l�vement forfaitaire obligatoire et du montant de ce PFO  	*/
/****************************************************************************************************/
/* Remarques :																						*/ 
/* 	Ce programme est appel� deux fois dans l'encha�nement : 										*/	
/*	 - d'abord dans le premier "bloc imp�t", qui permet de calculer le RFR N-2, mais aussi 			*/
/*	   l'�ligibilit� en N-1 au PF qui en d�coule													*/
/*	 - puis dans le deuxi�me "bloc imp�t", qui calcule le RFR N-1, et aussi l'�ligibilit� en N-1 au */
/*     PF qui en d�coule																			*/
/*																									*/
/*	Dans le premier bloc, on a anr=anr1=anref, anr2=anref+1, et anleg=anleg-1. 						*/
/*	Donc la condition sur le RFR en N-2 est en fait une condition sur le RFR en N-1 				*/
/*	(mais on ne peut pas faire mieux). 																*/
/*																									*/
/*	Dans le deuxi�me bloc, on a anr=anref, anr1=anref+1, anr2=anref+2, et anleg=anleg. Donc la 		*/
/*  condition sur le RFR en N-2 est juste. 															*/
/****************************************************************************************************/


/***********************************************************************************************************************************/
/*	A	Calcul de l'�ligibilit� des autoentrepreneurs au pr�l�vement forfaitaire lib�ratoire (d�pend du RFR et du nombre de parts) */
/***********************************************************************************************************************************/

/* L�gislation : 
	Afin de ne pas diff�rer d'un an la perception des revenus d'autoentreprenariat de leur imposition, 
	les AE dont le RFR de N-2 n'exc�de pas le seuil sup de la troisi�me tranche peuvent opter ou non 
	pour un pr�l�vement forfaitaire lib�ratoire de l'IR. 
	Du coup ces revenus ne sont plus impos�s au bar�me de l'IR l'ann�e suivante. 
	Effet de bord : les autres revenus du foyer seraient alors impos�s � un taux marginal plus faible (ou �gal)
	D'o� le principe du taux effectif : le taux moyen d'imposition est calcul� comme si le revenu imposable 
	incluait les revenus des AE; ie comme s'il n'y avait pas eu d'option pour le PF */

/* Pour Ines : 
	En ann�e N est pay� : 
	- le PFL de ceux qui ont opt� pour sur les revenus AE de l'ann�e N
		-> cod� dans Prelev_Forf.sas en fonction de l'�ligibilit� en N
	- l'IR de ceux qui avaient opt� pour le PFL en N-1
		-> cod� dans 5_impot.sas en fonction de l'�ligibilit� en N-1
	- l'IR de ceux qui n'avaient pas opt� pour le PFL en N-1
		-> cod� dans 5_impot.sas en fonction de l'�ligibilit� en N-1
	Hypoth�ses : 
	- tous ceux qui peuvent opter pour le PFL le font (rationalit�)
	- pour l'�ligibilit� en N on regarde le RFR N-1 au lieu de N-2 et on le compare � AE_PF_plaf de N au lieu de N-1
	- de m�me, pour l'�ligibilit� en N-1 on regarde le RFR N-2 au lieu de N-3 et AE_PF_plaf de N-1 au lieu de N-2 */

/* Eligibles en &anr2. : le RFR de &anr1. est < au plafond de la troisi�me tranche d'IR (d'anleg) */
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
/*	B	Calcul du pr�l�vement forfaitaire lib�ratoire / obligatoire � partir de 2013 */
/*************************************************************************************/

/* Remarques : 
	- 	� partir de 2013, les dividendes et produits de placements � revenu fixe deviennent imposables
		au bar�me � la place du pr�l�vement forfaitaire lib�ratoire. L'imposition se fait en deux temps : un 
		pr�l�vement forfaitaire obligatoire pr�lev� � la source et une r�gularisation l'ann�e suivante avec la 
		d�claration d'imp�t. Ce pr�l�vement n'est pas obligatoire pour les foyers dont le RFR est en dessous d'un 
		certain seuil (diff�rent pour les dividendes et pour les revenus de placement). 
	- 	pour la case 2ee, le taux n'est pas unique. Par manque d'information, on applique un taux moyen fixe de 20 % 
		(source : Bilan de production de l'ERFS) % */

%macro PFO;
	/* Pr�l�vement forfaitaire lib�ratoire jusqu'en 2012 et obligatoire � partir de 2013 sur les placements bancaires */
	/* Ce calcul doit �tre effectu� si : 
		- on est dans le deuxi�me appel de l'encha�nement (dans ce cas on le calcule pour l'ann�e anleg)
		- on est dans le premier appel ET on a besoin de cette info parce qu'on n'en a pas encore dans la case _2ck */

	%put APPEL : &Appel. / ANLEG : &anleg. / ANREF : &anref.;
	%if	(&Appel.=2) or (&Appel.=1 and (&anleg.+1)>=2014 and &anref.<2013) %then %do;
		/* Deuxi�me condition : on doit	cr�er une information pour "remplacer" la case _2ck que l'on n'a pas encore (cf. deduc.sas) */
		%put Le calcul du pr�l�vement forfaitaire pour l ann�e &anr2. est effectu�.;

		proc sql;
			create table modele.Prelev_Forf&anr2. as
			select 	a.declar, a.RFR as RFR&anr., b.ident, b.mcdvo, b._2dh, b._2dc, b._2tr, b._2tt, b._2ee, b._2fa, b._2fu, b._2ch, b._2ts, b._2go
			from modele.rev_imp&anr. as a
				inner join base.foyer&anr2. as b on a.declar=b.declar;
			quit;

		data modele.Prelev_Forf&anr2. (keep=Prelev_Forf ident declar PF:);
			set modele.Prelev_Forf&anr2.;

			%Init_Valeur(PF_Liberatoire PF_Obligatoire);
			/* PF obligatoire pourrait s'appeler non lib�ratoire mais ce n'est le cas que depuis 2013 donc on met un nom plus g�n�ral */

			/* 1	Assurances-vie : pr�l�vement forfaitaire toujours lib�ratoire m�me apr�s 2013
					� 7,5 % pour les produits d�tenus depuis 6/8 ans ou plus (2dh) */
			PF_Liberatoire=&prel_lib_t2.*max(0,_2dh);

			/* 2	Autres produits de placement soumis � un pr�l�vement lib�ratoire (m�me apr�s 2013) */
			PF_Liberatoire=PF_Liberatoire+&tx_moy_2ee.*_2ee; /* imposition moyenne � 20 % (taux moyen d'apr�s le bilan de production ERFS */
			/* 	Probl�me ici : la case 2ee est mixte entre : 
				- des produits d'Assurance-vie d�tenus depuis moins de 6 ans avant 1989 / 8 ans apr�s 1990 : taux de 15 ou 35 %
				- des produits d'�pargne solidaire : taux de 5 %
				- des produits de placement pay�s dans un Etat non coop�ratif : taux de 75 %
				Ecarts � la l�gislation : 
				- on met tout au taux moyen estim� � 20 %
				- une partie de ce PF est effectu� sur option du contribuable, on consid�re que tous choisissent cette option */

			/* 3	Actions et parts, et autres produits de placement soumis au pr�l�vement obligatoire */

			%if &anleg.>=2013 %then %do;
				/* A partir de 2013 : Pr�l�vement forfaitaire obligatoire non lib�ratoire, avec diff�rentes possibilit�s d'exemption : 
					1\ Possibilit� d'exemption du PFO sur les revenus distribu�s (_2dc) si RFR suffisamment faible
					2\ Possibilit� d'exemption du PFO sur les produits de placement � revenu fixe (_2tr) si RFR suffisamment faible
					3\ Possibilit� d'option pour un PF � 24 % pour les revenus <2000 euros (_2fa), sans condition sur le RFR */

				/* Cas 1 et 2 : deux possibilit�s polaires possibles : 
					(i)		Hypoth�se rationnelle : personne ne souhaite �tre soumis au PFO s'il a le choix de capitaliser sur ces revenus un an de plus
					(ii)	Hypoth�se r�aliste : personne ne demande l'exemption du PFO car c'est trop compliqu�. 
				Dans un premier temps nous avions pris la premi�re option pour Ines, mais au vu des montants de restitution d'imp�t 
				de PFO pour l'imp�t 2014 (case _2ck), on pense que la deuxi�me hypoth�se est pr�f�rable car beaucoup plus r�aliste. 
				=> conclusion : on opte pour la solution (ii) : on met le PFO � tout le monde */
				PF_Obligatoire=PF_Obligatoire+&prel_lib_t1.*_2dc;
					/* la condition �tait : if RFR&anr.>&PFO_divid_lim1.*(mcdvo not in ('M','O')) + &PFO_divid_lim2.*(mcdvo in ('M','O')) */

			/*TO DO 2018: changement l�gislatif sur les pr�l�vements lib�ratoire forfaitaires*/
				PF_Obligatoire=PF_Obligatoire+(&prel_lib_t3.*(_2tr + _2tt));
	
				
					/* la condition �tait : if RFR&anr.>&PFO_autres_lim.*(1+(mcdvo in ('M','O'))) */
					/* NB : pour le premier appel � ce programme le RFR de N-2 serait alors approch� par le RFR de N-1, puisqu'on n'a pas mieux */
				%end;

			/* Cas 3 : Possibilit� d'opter pour un pr�l�vement forfaitaire � 24 % pour les revenus <2000 euros (sans condition sur le RFR) */
			PF_Liberatoire=PF_Liberatoire+&prel_lib_t3.*_2fa;

			/* On ne calcule pas de pr�l�vement forfaitaire sur la case _2ts */

			Prelev_Forf=PF_Liberatoire+PF_Obligatoire;
			label Prelev_Forf="Pr�l�vement forfaitaire sur les revenus de placement";
			run;
		%end;
	%Mend PFO;

%PFO;


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
