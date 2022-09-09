/*************************************************************************************/
/*																										  */
/*					Calcul de l'ASS													         */
/*																										*/
/*************************************************************************************/

/* To Do : vérifier tables en entrée et en sortie */

/* En entrée :         	   base.baserev							 					   */
/*									base.baseind													*/
/*									dossier.minima												*/
/*							       base.foyer&anr.				       						   */
/*                                base.foyer&anr1.                 						   */
/*                                base.foyer&anr2.                 						  */
/*                                travail.irf&anr.e&anr. 								*/
/*								  imput.handicap    										 */
/*								  imput.aspa_asi  										*/
/*								  tirage_ass_anr&anref._anleg&anleg..csv       */
/* En sortie : 	           base.baserev											     */
/*							      base.foyer&anr.				    				         */
/*                                base.foyer&anr1.               				        */
/*                                base.foyer&anr2.              					        */
/* 							 modele.baseind                                           */

		
*************************************************************************************;

/* Ce programme vise à calculer à un ensemble de chômeurs une ASS théorique en fonction de leurs conditions 
de ressources et du nombre de mois travaillés dans l'année. On sort de ce programme une table composé d'un ensemble
de potentiels bénéficiaires de l'ASS du fait de ces critères. C'est sur cette table qu'on fera ensuite tourner un l'algortihme
RandomForest (dans le programme R tirage_ASS) à l'aide d'un certain nombre de variables explicatives, pour enfin tirer 
nos bénéficiaires ASS dans le programme ASS.sas. 

Attention : Ce programme ainsi que les autres programmes de ce module ne tournent qu'à la condition que la macrovariable
module_ASS soit égale à oui. En effet, le module remplaçant du chômage observé par de l'ASS simulée, il n'est pas proposé
en usage routinier du modèle. Se reporter à la page wiki correspondante pour plus d'informations. */

/* Plan

Partie I : Constitution de la base ressources de l'ASS au sein des chômeurs 
	1. Création d'un foyer ASS : bénéficiaire potentiel et son conjoint éventuel 
	2. Calcul de l'intéressement sur le salaire (pour le bénéficiaire potentiel, non son conjoint) et des ressources

Partie II : Calcul de l'ASS théorique et export du fichier de tirage
	1. Agrégation au niveau du foyer ASS et calcul de l'éligibilité
	2. Calcul de l' ASS pour chaque trimestre, ajustée en fonction du chômage déclaré et de l'intéressement 
	3. Export des bénéficiaires théoriques au sein desquel aura lieu le tirage

Partie III : Imputation de l'ASS
	1. Imputation en fonction de l'éligibilité et des probas calculées
	2. Substitution de l'ASS aux allocations chômages pour les bénéficiaires tirés
*************************************************************************************;

/* To Do : enlever l'appel de la table travail.irf&anr.e&anr. et de sa variable ag quand elles ne seront plus utiles (elles ne servent qu'à faciliter les stats desc faites pour évaluer l'impact des commits) */
%macro calcul_ass;
%if &module_ASS.=oui %then %do;
/*******************************************************************************************
*Partie I : Constitution de la base ressources de l'ASS au sein des chômeurs 
*******************************************************************************************/

/* 1. CRÉATION D'UN FOYER ASS : POTENTIEL BÉNÉFICIAIRE ET SON CONJOINT ÉVENTUEL */

/* On fait l'hypothèse accomodante et crédible qu'il n'y a qu'un seul foyer ASS par ménage, constitué par la personne de référence 
et son/sa conjoint(e). Vu les critères d'éligibilité de l'ASS, il est quasiment impossible que les parents et les enfants d'un ménage soient 
éligibles à l'ASS. On pourrait rater d'éventuels colocataires éligibles à l'ASS mais cela semble marginal */
proc sort data=base.foyer&anr1.; by ident noi; run;
proc sort data=travail.irf&anr.e&anr.; by ident noi; run;
data potentiel_ass (where=(lprm in ('1','2') or (lprm ='' and persfip in ('vous', 'conj'))) 
					keep=ident noi declar1 declar2 naia wpela&anr2. lprm persfip potentiel_ass salaire_ASS_T1 salaire_ASS_T2 salaire_ASS_T3 
					salaire_ASS_T4 ressources_conjoint ressources_benef prime_ass_T1 prime_ass_T2 prime_ass_T3 prime_ass_T4 reprise_act 
					cal0 conjoint nbmois_cho: z: nbmois_sal: ag potentiel_aah);
	merge 	base.baserev (in=a)
			base.baseind
			base.foyer&anr1.
			travail.irf&anr.e&anr. 
			imput.handicap
			imput.aspa_asi;
	by ident noi; 
	if a;
	%Init_Valeur(potentiel_ass salaire_ASS_T1 salaire_ASS_T2 salaire_ASS_T3 salaire_ASS_T4 ressources_conjoint 
								ressources_benef prime_ass_T1 prime_ass_T2 prime_ass_T3 prime_ass_T4 reprise_act conjoint);
	if zchoi&anr2. ne 0 and find(cal0,"4") ne 0 then potentiel_ass=1; 
/* pour l'instant éligibilité à l'ASS au sens très large : potentiel bénéficiaire du fait qu'il déclare des revenus du chômage et qu'il n'a pas été en préretraite toute l'année*/
	if potentiel_ass=1 then do;

/*	2. CALCUL DE L'INTÉRESSEMENT */

	/* Jusqu'en août 2017, les conditions ne sont pas les mêmes selon si l'emploi est inférieur à 78h par mois ou pas (on évoque ici les montants 2017):
	- inférieur à 78h par mois :  
	a) Cumul intégral pendant les 6 premiers mois suivant la reprise d'emploi si le salaire mensuel est inférieur à un plafond. 
	Pour les 6 mois suivants, diminution du nombre de jours avec allocation de 40% du revenu brut divisé par l'allocation journalière.
	(revient à diminuer l'allocation de 40 % du revenu brut, modulo l'arrondi à l'unité supérieure pour le calcul du nombre de jours sans allocation.
	b)  Si le salaire mensuel est supérieur au plafond, on diminue l'allocation de 40 % de la rémunération
	au delà du plafond pour les 6 premiers mois puis de 40% de la rémunération pour les 6 mois suivants. 

	- supérieur à 78h par mois : c) Cumul intégral pour les 3 premiers mois suivant la reprise d'emploi. Du 4e au 12e mois, allocation baissée du montant de la rémunération, 
	cependant l'allocataire touche une prime forfaitaire de 150 euros. 

	A partir du 1er septembre 2017, changement de la législation sur l'intéressement : cumul intégral de l'ASS et des revenus d'activités pendant 3 mois.		
	Ecart à la législation : il peut s'agir de 3 mois non consécutifs, mais on ne considère pas ces cas.

	Ecart à la législation : la reprise d'activité peut-être non salariée, mais on ne considère pas ici l'activité des indépendants.
	*/
		salaire_ASS_T1=zsali&anr2._T1;
		salaire_ASS_T2=zsali&anr2._T2;
		salaire_ASS_T3=zsali&anr2._T3;
		salaire_ASS_T4=zsali&anr2._T4;

		%if &anleg.<=2017 %then %do ; 
			/* REPRISE EN FÉVRIER */
			if substr(cal0,11,2) in ('14') then do;
				reprise_act=2;
				/* a) <78h/mois sous le plafond */
				if 0<hor<18 and zsali&anr2./nbmois_sal <%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T1=0;
					salaire_ASS_T2=0;
					if nbmois_salT3=1 then salaire_ASS_T3=0;
					else if nbmois_salT3 = 2 then salaire_ASS_T3=1/2*zsali&anr2._T3*&tx_reduc_ass.;
					else if nbmois_salT3 = 3 then salaire_ASS_T3=2/3*zsali&anr2._T3*&tx_reduc_ass.;
					salaire_ASS_T4= zsali&anr2._T4*&tx_reduc_ass.;
					end;
				/* b) <78h/mois au dessus du plafond */
				if 0<hor<18 and zsali&anr2./nbmois_sal >=%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T1=nbmois_salT1*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					salaire_ASS_T2=nbmois_salT2*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					if nbmois_salT3=1 then salaire_ASS_T3=(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					else if nbmois_salT3 = 2 then salaire_ASS_T3=(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.+1/2*zsali&anr2._T3*&tx_reduc_ass.;
					else if nbmois_salT3 = 3 then salaire_ASS_T3=(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.+2/3*zsali&anr2._T3; 
					salaire_ASS_T4= zsali&anr2._T4*&tx_reduc_ass.;
					end;
				/* c) >78h/mois */
				if hor>18 then do;
					salaire_ASS_T1=0;
					if nbmois_salT2=1 then salaire_ASS_T2=0;
					else if nbmois_salT2 = 2 then salaire_ASS_T2=1/2*zsali&anr2._T2 and prime_ASS_T2=&montant_prime.;
					else if nbmois_salT2 = 3 then salaire_ASS_T2=2/3*zsali&anr2._T2 and prime_ASS_T2=2*&montant_prime.;
					prime_ASS_T3=&montant_prime.*nbmois_salT3;
					salaire_ASS_T3=zsali&anr2._T3;
					prime_ASS_T4=&montant_prime.*nbmois_salT4;
					salaire_ASS_T4=zsali&anr2._T4;
					end;
				end;

			/* REPRISE EN MARS */
			if substr(cal0,10,2) in ('14') and reprise_act=0 then do;
				reprise_act=3;
				/* a) <78h/mois sous le plafond */
				if 0<hor<18 and zsali&anr2./nbmois_sal <%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T1=0;
					salaire_ASS_T2=0;
					if nbmois_salT3 in (1,2) then salaire_ASS_T3=0;
					else if nbmois_salT3 = 3 then salaire_ASS_T3=2/3*zsali&anr2._T3*&tx_reduc_ass.;
					salaire_ASS_T4= zsali&anr2._T4*&tx_reduc_ass.;
					end;
			/* b) <78h/mois au dessus du plafond */
				if 0<hor<18 and zsali&anr2./nbmois_sal >=%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T1=nbmois_salT1*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					salaire_ASS_T2=nbmois_salT2*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					if nbmois_salT3 in (1,2) then salaire_ASS_T3=nbmois_salT3*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					else if nbmois_salT3 = 3 then salaire_ASS_T3=2*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.+1/3*zsali&anr2._T3; 
					salaire_ASS_T4= zsali&anr2._T4*&tx_reduc_ass.;
					end;
			/* c) >78h/mois */
				if hor>18 then do;
					salaire_ASS_T1=0;
					if nbmois_salT2 < 3 then salaire_ASS_T2=0;
					if nbmois_salT2 = 3 then salaire_ASS_T2=1/3*zsali&anr2._T2 and prime_ASS_T2=&montant_prime.;
					prime_ASS_T3=&montant_prime.*nbmois_salT3;
					salaire_ASS_T3=zsali&anr2._T3;
					prime_ASS_T4=&montant_prime.*nbmois_salT4;
					salaire_ASS_T4=zsali&anr2._T4;
					end;
				end;

			/* REPRISE EN AVRIL */
			if substr(cal0,9,2) in ('14') and reprise_act=0 then do;
				reprise_act=4;
				/* a) <78h/mois sous le plafond */
				if 0<hor<18 and zsali&anr2./nbmois_sal <%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T2=0;
					salaire_ASS_T3=0;
					salaire_ASS_T4=zsali&anr2._T4*&tx_reduc_ass.;
					end;
			/* b) <78h/mois au dessus du plafond */
				if 0<hor<18 and zsali&anr2./nbmois_sal >=%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T2=nbmois_salT2*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					salaire_ASS_T3=nbmois_salT3*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					salaire_ASS_T4= zsali&anr2._T4*&tx_reduc_ass.;
					end;
			/* c) >78h/mois */
				if hor>18 then do;
					salaire_ASS_T2=0;
					prime_ASS_T3=&montant_prime.*nbmois_salT3;
					salaire_ASS_T3=zsali&anr2._T3;
					prime_ASS_T4=&montant_prime.*nbmois_salT4;
					salaire_ASS_T4=zsali&anr2._T4;
					end;
				end;

			/* REPRISE EN MAI */
			if substr(cal0,8,2) in ('14') and reprise_act=0 then do;
				reprise_act=5;
				/* a) <78h/mois sous le plafond */
				if 0<hor<18 and zsali&anr2./nbmois_sal <%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T2=0;
					salaire_ASS_T3=0;
					if nbmois_salT4=1 then salaire_ASS_T4=0;
					if nbmois_salT4=2 then salaire_ASS_T4=1/2*zsali&anr2._T4*&tx_reduc_ass.;
					if nbmois_salT4=3 then salaire_ASS_T4=2/3*zsali&anr2._T4*&tx_reduc_ass.;
					end;
			/* b) <78h/mois au dessus du plafond */
				if 0<hor<18 and zsali&anr2./nbmois_sal >=%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T2=nbmois_salT2*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					salaire_ASS_T3=nbmois_salT3*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					if nbmois_salT4=1 then salaire_ASS_T4=(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					if nbmois_salT4=2 then salaire_ASS_T4=(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.+1/2*zsali&anr2._T4*&tx_reduc_ass.;
					if nbmois_salT4=3 then salaire_ASS_T4=(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.+2/3*zsali&anr2._T4*&tx_reduc_ass.;
					end;
			/* c) >78h/mois */
				if hor>18 then do;
					salaire_ASS_T2=0;
					if nbmois_salT3=1 then salaire_ASS_T3=0;
					if nbmois_salT3=2 then prime_ASS_T3=&montant_prime. and salaire_ASS_T3=1/2*zsali&anr2._T3;
					if nbmois_salT3=3 then prime_ASS_T3=2*&montant_prime. and salaire_ASS_T3=2/3*zsali&anr2._T3;
					prime_ASS_T4=&montant_prime.*nbmois_salT4;
					salaire_ASS_T4=zsali&anr2._T4;
					end;
				end;

				/* REPRISE EN JUIN */
			if substr(cal0,7,2) in ('14') and reprise_act=0 then do;
				reprise_act=6;
				/* a) <78h/mois sous le plafond */
				if 0<hor<18 and zsali&anr2./nbmois_sal <%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T2=0;
					salaire_ASS_T3=0;
					if nbmois_salT4<3 then salaire_ASS_T4=0;
					if nbmois_salT4=3 then salaire_ASS_T4=1/3*zsali&anr2._T4*&tx_reduc_ass.;
				end;
			/* b) <78h/mois au dessus du plafond */
				if 0<hor<18 and zsali&anr2./nbmois_sal >=%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T2=nbmois_salT2*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					salaire_ASS_T3=nbmois_salT3*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					if nbmois_salT4 in (1,2) then salaire_ASS_T4=nbmois_salT4*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					if nbmois_salT4=3 then salaire_ASS_T4=2*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.+1/3*zsali&anr2._T4*&tx_reduc_ass.;
					end;
			/* c) >78h/mois */
				if hor>18 then do;
					salaire_ASS_T2=0;
					if nbmois_salT3<3 then salaire_ASS_T3=0;
					if nbmois_salT3=3 then prime_ASS_T3=2*&montant_prime. and salaire_ASS_T3=1/3*zsali&anr2._T3;
					prime_ASS_T4=&montant_prime.*nbmois_salT4;
					salaire_ASS_T4=zsali&anr2._T4;
					end;
				end;

			/* REPRISE EN JUILLET */
			if substr(cal0,6,2) in ('14') and reprise_act=0 then do;
				reprise_act=7;
				/* a) <78h/mois sous le plafond : que du cumul intégral à partir des reprises en juillet*/
				if 0<hor<18 and zsali&anr2./nbmois_sal <%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T3=0;
					salaire_ASS_T4=0;
					end;
				/* b) <78h/mois au dessus du plafond : que réduction au delà du plafond à partir des reprises en juillet*/
				if 0<hor<18 and zsali&anr2./nbmois_sal >=%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T3=nbmois_salT3*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					salaire_ASS_T4=nbmois_salT4*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					end;
				/* c) >78h/mois */
				if hor>18 then do;
					salaire_ASS_T3=0;
					prime_ASS_T4=&montant_prime.*nbmois_salT4;
					salaire_ASS_T4=zsali&anr2._T4;
					end;
				end;

			/* REPRISE EN AOÛT */
			if substr(cal0,5,2) in ('14') and reprise_act=0 then do;
				reprise_act=8;
				/* a) <78h/mois sous le plafond : que du cumul intégral à partir des reprises en juillet*/
				if 0<hor<18 and zsali&anr2./nbmois_sal <%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T3=0;
					salaire_ASS_T4=0;
					end;
				/* b) <78h/mois au dessus du plafond : que réduction au delà du plafond à partir des reprises en juillet*/
				if 0<hor<18 and zsali&anr2./nbmois_sal >=%sysevalf(&plaf_partiel_ass.*&smich.) then do;
					salaire_ASS_T3=nbmois_salT3*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					salaire_ASS_T4=nbmois_salT4*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
					end;
				/* c) >78h/mois */
				if hor>18 then do;
					salaire_ASS_T3=0;
					if nbmois_salT4=1 then salaire_ASS_T4=0;
					if nbmois_salT4=2 then prime_ASS_T4=&montant_prime. and salaire_ASS_T4=1/2*zsali&anr2._T4;
					if nbmois_salT4=3 then prime_ASS_T4=2*&montant_prime. and salaire_ASS_T4=2/3*zsali&anr2._T4;
					end;
				end;

			%if &anleg.<=2016 %then %do ; 
				/* REPRISE EN SEPTEMBRE */
				if substr(cal0,4,2) in ('14') and reprise_act=0 then do;
					reprise_act= 9;
					/* a) <78h/mois sous le plafond : que du cumul intégral à partir des reprises en juillet*/
					if 0<hor<18 and zsali&anr2./nbmois_sal <%sysevalf(&plaf_partiel_ass.*&smich.) then do;
						salaire_ASS_T3=0;
						salaire_ASS_T4=0;
						end;
					/* b) <78h/mois au dessus du plafond : que réduction au delà du plafond à partir des reprises en juillet*/
					if 0<hor<18 and zsali&anr2./nbmois_sal >=%sysevalf(&plaf_partiel_ass.*&smich.) then do;
						salaire_ASS_T3=nbmois_salT3*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
						salaire_ASS_T4=nbmois_salT4*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
						end;
					/* c) >78h/mois */
					if hor>18 then do;
						salaire_ASS_T3=0;
						if nbmois_salT4<3 then salaire_ASS_T4=0;
						if nbmois_salT4=3 then prime_ASS_T4=&montant_prime. and salaire_ASS_T4=1/3*zsali&anr2._T4;
						end;
					end;
				/* REPRISE EN OCTOBRE, NOVEMBRE OU DECEMBRE */
				if find(substr(cal0,1,3),'14') ne 0 and reprise_act=0 then do;
					reprise_act=10;
					/* a) <78h/mois sous le plafond : que du cumul intégral à partir des reprises en juillet*/
					if 0<hor<18 and zsali&anr2./nbmois_sal <%sysevalf(&plaf_partiel_ass.*&smich.) then do;
						salaire_ASS_T4=0;
						end;
					/* b) <78h/mois au dessus du plafond : que réduction au delà du plafond à partir des reprises en juillet*/
					if 0<hor<18 and zsali&anr2./nbmois_sal >=%sysevalf(&plaf_partiel_ass.*&smich.) then do;
						salaire_ASS_T4=nbmois_salT4*(zsali&anr2./nbmois_sal-%sysevalf(&plaf_partiel_ass.*&smich.))*&tx_reduc_ass.;
						end;
					/* c) >78h/mois : que du cumul intégral*/
					if hor>18 then do;
						salaire_ASS_T4=0;
						end;
					end;
				%end ;
			%if &anleg.=2017 %then %do ; 
				/* REPRISE EN SEPTEMBRE */
				if substr(cal0,4,2) in ('14') and reprise_act=0 then do;
					reprise_act= 9;
					salaire_ASS_T3=0;
					if nbmois_salT4<3 then salaire_ASS_T4=0;
					if nbmois_salT4=3 then salaire_ASS_T4=1/3*zsali&anr2._T4;
					end;
				/* REPRISE EN OCTOBRE, NOVEMBRE OU DECEMBRE */
				if find(substr(cal0,1,3),'14') ne 0 and reprise_act=0 then do;
					reprise_act=10;
					salaire_ASS_T4=0;
					end;
				%end ;
			%end ;

		%if &anleg.>=2018 %then %do ; 
			/* REPRISE EN FÉVRIER */
			if substr(cal0,11,2) in ('14') then do;
				reprise_act=2;
				salaire_ASS_T1=0;
				if nbmois_salT2=1 then salaire_ASS_T2=0;
				else if nbmois_salT2 = 2 then salaire_ASS_T2=1/2*zsali&anr2._T2 ;
				else if nbmois_salT2 = 3 then salaire_ASS_T2=2/3*zsali&anr2._T2 ;
				end;
			/* REPRISE EN MARS */
			if substr(cal0,10,2) in ('14') and reprise_act=0 then do;
				reprise_act=3;
				salaire_ASS_T1=0;
				if nbmois_salT2 < 3 then salaire_ASS_T2=0;
				if nbmois_salT2 = 3 then salaire_ASS_T2=1/3*zsali&anr2._T2 ;
				end;
			/* REPRISE EN AVRIL */
			if substr(cal0,9,2) in ('14') and reprise_act=0 then do;
				reprise_act=4;
				salaire_ASS_T2=0;
				end;
			/* REPRISE EN MAI */
			if substr(cal0,8,2) in ('14') and reprise_act=0 then do;
				reprise_act=5;
				salaire_ASS_T2=0;
				if nbmois_salT3=1 then salaire_ASS_T3=0;
				if nbmois_salT3=2 then salaire_ASS_T3=1/2*zsali&anr2._T3;
				if nbmois_salT3=3 then salaire_ASS_T3=2/3*zsali&anr2._T3;
				end;
			/* REPRISE EN JUIN */
			if substr(cal0,7,2) in ('14') and reprise_act=0 then do;
				reprise_act=6;
				salaire_ASS_T2=0;
				if nbmois_salT3<3 then salaire_ASS_T3=0;
				if nbmois_salT3=3 then salaire_ASS_T3=1/3*zsali&anr2._T3;
				end;
			/* REPRISE EN JUILLET */
			if substr(cal0,6,2) in ('14') and reprise_act=0 then do;
				reprise_act=7;
				salaire_ASS_T3=0;
				end;
			/* REPRISE EN AOÛT */
			if substr(cal0,5,2) in ('14') and reprise_act=0 then do;
				reprise_act=8;
				salaire_ASS_T3=0;
				if nbmois_salT4=1 then salaire_ASS_T4=0;
				if nbmois_salT4=2 then salaire_ASS_T4=1/2*zsali&anr2._T4;
				if nbmois_salT4=3 then salaire_ASS_T4=2/3*zsali&anr2._T4;
				end;
			/* REPRISE EN SEPTEMBRE */
			if substr(cal0,4,2) in ('14') and reprise_act=0 then do;
				reprise_act= 9;
				salaire_ASS_T3=0;
				if nbmois_salT4<3 then salaire_ASS_T4=0;
				if nbmois_salT4=3 then salaire_ASS_T4=1/3*zsali&anr2._T4;
				end;
			/* REPRISE EN OCTOBRE, NOVEMBRE OU DECEMBRE */
			if find(substr(cal0,1,3),'14') ne 0 and reprise_act=0 then do;
				reprise_act=10;
				salaire_ASS_T4=0;
				end;
			%end ;

		/* On traite enfin les cas où salaire >0 mais n'apparait pas dans le calendrier d'activité. */ 
		/* TODO : vérifier la construction du calendrier d'activité et à quoi correspondent ces cas */
		if reprise_act = 0 then do ; 
			salaire_ASS_T1=0;
			salaire_ASS_T2=0;
			salaire_ASS_T3=0;
			salaire_ASS_T4=0;
			end ;
			
	/* Reste des revenus du potentiel bénéficiaire pris en compte, ainsi que des revenus non individualisables qu'on lui attribue. 
		On ne lui compte pas son chômage mais on lui compte son salaire avec un abattement comme prévu par la loi : les revenus 
		d'activité sont pris en compte lorsqu'ils ont donné lieu à un revenu de substitution (non pris en compte). On considère que c'est le cas ici, sinon on minore 
		trop les ressources des bénéficiaires. 
		To Do : mettre le 30% en paramètre (même paramètre que dans ressources.sas, où c'est en dur aussi) 

		Attention : les revenus d'activité de N-1 sont comptés ici dans ressources_benef puis on recompte les revenus d'activité de N en tenant compte 
		des règles de l'intéressement : l'hypothèse est que sur anr1 et sur anr2 les revenus d'activité sont les mêmes, qu'en anr1 on les compte entièrement modulo 
		l'abattement et la prise en compte du chômage/ASS et qu'en anr2 on les recompte modulo les règles d'intéressement. En clair, une situation sans intéressement serait bien : « on compte dans leur 
		totalité les revenus d'activité contemporains à l'année de perception de l'ASS, en plus de ceux comptés dans l'examen des ressources N-1 » 

		On ne prend pas en compte les pensions de retraite en N-1 car c'est incompatible avec de l'ASS. La moyenne mensuelle des revenus liés au calendrier 
		d'activité est donc calculée sur 12 mois - le nombre de mois à la retraite. Les autres revenus sont moyennisés sur 12 mois en revanche.  

		Écart à la législation : On compte parfois dans la base ressources les revenus du chômage alors qu'ils ne le sont pas dans la réalité. Cela revient à considérer  
		qu'il s'agit de l''ASS, qui doit être comptée dans la base ressources. On applique cela aux personnes qui ont du chômage dès le début d'année et dont on ne peut pas savoir s'il
	    remplace directement du salaire. */
		%Nb_Mois(cal0,nbmois_retr,5); 
		ressources_benef=(max(0,(1-0.3)*zsali&anr1.)+max(0,zchoi&anr1.*(substr(cal0,12,1)='4'))
							/*+max(0,zrsti&anr1.)*/+max(0,zpii&anr1.)+max(0,zrici&anr1.)+max(0,zrnci&anr1.)+max(0,zragi&anr1.))/(12-nbmois_retr) /* revenus liés au calendrier d'activité. La moyenne mensuelle est calculée hors retraite et mois passés à la retraite */
							+(max(0,zalri&anr1.)+max(0,zrtoi&anr1.)+max(0,zetrf)+max(0,zdivf)+max(0,zfonf)+max(0,zglof)-max(0,zalvf))/12; /* autres revenus, annuels, indépendants du calendrier d'activité. Moyenne mensuelle sur 12 mois. */

	/* On repère les handicapés au sens de l'AAH pour une mesure de 2017 : on ne repère que le handicap du potentiel bénéficiaire de l'ASS, pas de son conjoint, en supposant qu'on 
		peut avoir des cas où un.e bénéficiaire de l'ASS serait en couple avec un.e bénéficiaire de l'AAH (a priori le non cumul est d'ordre individuel, même si la loi ne semble pas explicite) */
		if handicap ne 0 & (&anref.-input(naia,4.)<60 ! (elig_aspa_asi=0 & &anref.-input(naia,4.)<65)) then potentiel_aah=1;
		end;
	/* revenus de l'éventuel conjoint */
	else do;
		conjoint=1;
		ressources_conjoint=(max(0,zsali&anr1.)+max(0,zchoi&anr1.)+max(0,zrsti&anr1.)+max(0,zpii&anr1.)+max(0,zalri&anr1.)+max(0,zrici&anr1.)
										+max(0,zrnci&anr1.)+max(0,zrtoi&anr1.)+max(0,zragi&anr1.))/12;
		/* Note : vu les conditions pour que potentiel_ass=1 le zchoi du conjoint ne peut être que de la préretraite (le chômage n'entre pas dans la base ressources) ou du chômage pour un individu FIP */
	end;
	run;

/*******************************************************************************************
* Partie II : Calcul de l'ASS théorique et export du fichier de tirage
*******************************************************************************************/

/*ATTENTION : l'ASS calculée ici ne sera effectivement appliquée qu'aux bénéficiaires tirés */

/* 1. AGRÉGATION AU NIVEAU DU FOYER  ASS ET CALCUL DE L'ÉLIGIBILITÉ */
/* Attention : on agrège les ressources du ménage mais on garde au niveau individuel les éléments de l'intéressement
	qui nous permettront de calculer une ASS individuelle dans le cas d'un couple de deux bénéficiaires de l'ASS.
	En effet, la prise en compte des ressources annuelles pour l'ASS est au niveau du couple mais le montant versé 
	ainsi que l'intéressement sont au niveau individuel. */
	proc sql;
		create table base_ressources_ass as
		select unique ident, noi, persfip, declar1, declar2, naia, wpela&anr2., cal0, sum(conjoint) as conjoint, salaire_ASS_T1, salaire_ASS_T2, 
		salaire_ASS_T3, salaire_ASS_T4, prime_ass_T1, prime_ass_T2, prime_ass_T3, prime_ass_T4,
		sum(ressources_benef+ressources_conjoint) as ressources_ass, nbmois_choT1, nbmois_choT2, 
		nbmois_choT3, nbmois_choT4, nbmois_cho, nbmois_sal, sum(potentiel_ass) as potentiel_ass, reprise_act, 
		zchoi&anr2._T1, zchoi&anr2._T2, zchoi&anr2._T3, zchoi&anr2._T4, zchoi&anr2., potentiel_aah
		/* pour les couples dont les deux membres sont potentiellement éligibles, on retient la reprise d'activité la plus tôt et le nombre de mois au chômage le plus élevé */
		from potentiel_ass
		group by ident;
		quit;

/*	2. CALCUL DE L'ASS POUR CHAQUE TRIMESTRE  */
	data base_ressources_ass;
		set base_ressources_ass (where=(potentiel_ass ne 0));
		%Init_Valeur(elig_ass nbmois_ASS nbmois_ASST1 nbmois_ASST2 nbmois_ASST3 nbmois_ASST4
					nbmois_chosansASS nbmois_chosansASST1 nbmois_chosansASST2 nbmois_chosansASST3 nbmois_chosansASST4
					montant_ASS montant_ass_T1 montant_ass_T2 montant_ass_T3 montant_ass_T4 ass_noel
					nbmois_cotischo prem_mois_ass );
		if potentiel_ass=2 or conjoint ne 0 then do;
			if ressources_ass=<&plafond_couple. then elig_ass=1;
			end;
		else if potentiel_ass=1 and conjoint = 0 then do;
			if ressources_ass=<&plafond_ass. then elig_ass=1;
			end;
		/* Ci-dessous, on enlève à partir de 2017 les handicapés au sens de l'AAH du bénéfice potentiel de l'ASS car le cumul a été interdit. : 
			On considère implicitement que s'ils sont éligibles à l'ASS sous condition de ressources ils le seront à l'AAH et toucheront un montant 
			plus avantageux, ce qui doit être le cas dans la grande majorité des cas. Il est plus aisé de faire ce traitement ici qu'après le calcul de l'AAH
			car cela nécessiterait d'enlever l'ASS (mais pas forcément tout le chômage, or ils sont confondus à ce stade du modèle) des bénéficiaires de l'AAH 
			qui toucheraient aussi de l'ASS alors que celle-ci serait déjà entrée dans la base ressources de prestations calculées plus en amont... */
		%if &anleg >=2017 %then %do;
			if potentiel_aah=1 then elig_ass=0;
			%end;
		/* On retranche aux potentiels bénéficiaires ayant travaillé le nb de mois de chômage dont on sait qu'ils sont hors
			ASS car ils ont été précédé d'autant de mois de salaire. Écart à la réalité : on minimise le nombre de mois de 
			chômage potentiels puisqu'on ne prend en compte comme mois cotisé que ceux de l'année en cours. 
			Pour essayer de tenir compte de cette sous-estimation structurelle, on considère que tous les 
			potentiels ASS connaissant du travail dans l'année partent avec un trimestre déjà cotisé */
			if find(cal0,"1") ne 0 then nbmois_cotischo=3;
			/*	Méthode utilisée : à partir de janvier on compte en +1 les mois de salaire et en -1 les mois de chômage,
			dès que ce chiffre est négatif on a notre premier mois d'ASS potentiel. */
		%do i=1 %to 12;
			if substr(cal0,%sysevalf(13-&i.),1)='1' then nbmois_cotischo=nbmois_cotischo+1;
			if substr(cal0,%sysevalf(13-&i.),1)='4' then nbmois_cotischo=nbmois_cotischo-1;
			if nbmois_cotischo<0 and prem_mois_ass=0 then prem_mois_ass=&i.; 
			/* prem_mois_ass donne le 1er mois à partir duquel l'individu est potentiellement éligible à l'ASS : chômage non précédé d'une période équivalente de salariat */
			%end;
			array nbmois_choT(4) nbmois_choT1-nbmois_choT4;
		/* On crée le nombre de mois théorique où chacun peut toucher l'ass : chômage potentiellement non cotisé suivie de l'éventuelle période d'intéressement */
			array nbmois_ASST(4) nbmois_ASST1-nbmois_ASST4;
		/* On crée aussi le nombre de mois de chômage sans ASS pour ceux qui touchet l'ASS : nb de mois de chômage moins chômage potentiellement non cotisé 
			Cette variable permet ensuite de ne remplacer le chômage observé par de l'ASS simulée que sur la part du chômage observé considéré comme potentiellement non cotisée */
			array nbmois_chosansASST(4) nbmois_chosansASST1-nbmois_chosansASST4;
			do i=1 to 4;
				if prem_mois_ass ne 0 then do;
					nbmois_ASST(i)=(count(substr(cal0, 13-3*i, min(max(1,3*i+1-prem_mois_ass),3)),"4") /* chômage potentiellement non cotisé */
					+count(substr(cal0, 13-3*i, min(max(1,3*i+1-reprise_act),3)),"1")*(reprise_act<=3*i)*(reprise_act>0)) /* éventuelle période d'intéressement */
					*(prem_mois_ass<=3*i) /* condition sur le fait que l'ASS ait bien commencé avant le trimestre considéré */
					- count(substr(cal0, min(12,13-3*(i-1)), min(max(1,3*(i-1)+1-reprise_act),3)),"1")*(reprise_act<=3*(i-1))*(reprise_act>0) /* éventuelle période d'intéressement au trimestre précédent */
					*(prem_mois_ass<=3*(i-1))*(&anleg.>=2018); /* Période de cumul ASS/revenus d'activité limité à 3 mois à partir de septembre 2017. 
					On soustrait donc le nombre de mois éventuels calculés pour le trimestre précédent. */
					
					/* le nb de mois de chômage hors ass c'est le nb de mois de chômage auquel on retire le chômage potentiellement non cotisé */
					nbmois_chosansASST(i)=max(0,nbmois_choT(i)-(count(substr(cal0, 13-3*i, min(max(1,3*i+1-prem_mois_ass),3)),"4"))*(prem_mois_ass<=3*i)); 
					end;
				else do;
					nbmois_chosansASST(i)=nbmois_choT(i);
					end;
				end;
				drop i;
			/* On ajuste le nombre de mois d'intéressement à l'ASS pour les cas de reprise d'activité à partir du 1er septembre 2017
				(Période de cumul ASS/revenus d'activité limité à 3 mois) */
			%if &anleg.=2017 and reprise_act>=9 %then %do ;  
				%do i=3 %to 4 ;
					nbmois_ASST&i.=nbmois_ASST&i. 
					- count(substr(cal0, min(12,13-3*(&i.-1)), min(max(1,3*(&i.-1)+1-reprise_act),3)),"1")
					*(reprise_act<=3*(&i.-1))*(reprise_act>0) /* éventuelle période d'intéressement au trimestre précédent */
					*(prem_mois_ass<=3*(&i.-1)); 
					%end ;
				%end ;
		nbmois_ASS=sum(of nbmois_ASST1-nbmois_ASST4); 
	
		%do i=1 %to 4;
		/* On donne l'ASS à taux plein ou différentielle en fonction du niveau des ressources,
		auxquelles on ajoute le salaire correspondant à l'intéressement en cas de reprise d'activité (salaire_ASS_T&i.*(reprise_act>0)). 
		On conditionne la perception de la prime au fait d'avoir des mois d'ASS comptabilisés dans le trimestre correspondant */
		if elig_ass=1 then do ;
			/* Pour les couples : Attention, l'ASS est une allocation individuelle mais avec prise en compte des ressources au niveau du couple */
			if conjoint ne 0 or potentiel_ass=2 then do;
				if ressources_ass=<&plafond_txplein_couple. then montant_ass_T&i.=max(0,&ass_mont.*nbmois_ASST&i.-salaire_ASS_T&i.+prime_ASS_T&i.*(nbmois_ASST&i.>0));
				else montant_ass_T&i.=max(0,(&plafond_couple.-ressources_ass)*nbmois_ASST&i.-salaire_ASS_T&i.+prime_ASS_T&i.*(nbmois_ASST&i.>0));
				end;
			/* pour les célibataires */
			else if conjoint=0 and potentiel_ass=1 then do;
				if ressources_ass=<&plafond_txplein_celib. then montant_ass_T&i.=max(0,&ass_mont.*nbmois_ASST&i.-salaire_ASS_T&i.+prime_ASS_T&i.*(nbmois_ASST&i.>0));
				else montant_ass_T&i.=max(0,(&plafond_ass.-ressources_ass)*nbmois_ASST&i.-salaire_ass_T&i.+prime_ASS_T&i.*(nbmois_ASST&i.>0));
				end;
			end ;
		if montant_ass_T&i. < nbmois_ASST&i.*&ass_min. then montant_ass_T&i. = 0 ;
		%end;
		montant_ass=sum(of montant_ASS_T1-montant_ASS_T4);
		ass_noel=&rmi_noel.*(montant_ASS_T4>0);
		 /* Les primes d'intéressement son déjà contenues dans montant_ass mais on aura besoin du détail car la prime n'est pas imposable et pas dans la BR du RSA*/
		prime_ass=sum(of prime_ASS_T1-prime_ASS_T4);
		run;

/*******************************************************************************************
*Partie III : Imputation de l'ASS
*******************************************************************************************/
	/*	1. IMPUTATION EN FONCTION DE L'ÉLIGIBILITÉ ET DES PROBAS CALCULÉES */

		/* On importe le fichier avec les probabilités d'être à l'ASS */
proc import datafile="&imputation.\imputation ASS\tirage_ass_anr&anref._anleg&anleg..csv" 
		dbms=csv
		out=benefs_ass  replace;
 		delimiter=";";
run;
data benefs_ass;
	set benefs_ass;
		/* On résout ici de manière artisanale un problème lié à l'export de SAS vers excel : 
	les premiers "zéros" des noi ont disparu, ce qui empêche les merges nécessaires dans
	la suite du programme */
	if noi ne '10' then noi=cats('0',noi);
	run;
		
proc sql;
	create table table_tirage_ass as
	select a.*, b.montant_ass
	from benefs_ass as a left join base_ressources_ass as b
	on a.ident=b.ident and a.noi=b.noi
	where montant_ass>0
	order by proba_ass desc;
	quit;

data table_tirage_ass ;
	set table_tirage_ass;
   	retain poids 0;
	recours_ass=1;
	poids=poids+wpela&anr2.;
	if poids>&nb_benef_ass. then recours_ass=0;
	run;


/* On impute l'ASS aux bénéficiaires tirés  */
proc sql;
	create table ass as
	select b.ident, b.noi, a.wpela&anr2., b.declar1, b.declar2, b.naia, b.persfip, (a.recours_ass=1)*b.montant_ass as montant_ass, 
	(a.recours_ass=1)*montant_ASS_T1 as montant_ass_T1, (a.recours_ass=1)*montant_ASS_T2 as montant_ass_T2, 
	(a.recours_ass=1)*montant_ASS_T3 as montant_ass_T3, (a.recours_ass=1)*montant_ASS_T4 as montant_ass_T4, 
	(a.recours_ass=1)*ass_noel as ass_noel, a.recours_ass, (a.recours_ass=1)*(nbmois_ASS) 
	as nbmois_ASS, (a.recours_ass=1)*nbmois_ASST1 as nbmois_ASST1, (a.recours_ass=1)*nbmois_ASST2 as nbmois_ASST2,
	(a.recours_ass=1)*nbmois_ASST3 as nbmois_ASST3, (a.recours_ass=1)*nbmois_ASST4 as nbmois_ASST4,
	(a.recours_ass=1)*(nbmois_chosansASST1+nbmois_chosansASST2+nbmois_chosansASST3+nbmois_chosansASST4) as nbmois_chosansASS, 
	(a.recours_ass=1)*nbmois_chosansASST1 as nbmois_chosansASST1, (a.recours_ass=1)*nbmois_chosansASST2 as nbmois_chosansASST2, 
	(a.recours_ass=1)*nbmois_chosansASST3 as nbmois_chosansASST3, (a.recours_ass=1)*nbmois_chosansASST4 as nbmois_chosansASST4,
	(a.recours_ass=1)*max(0,(b.montant_ass-b.prime_ass)) as montant_ass_hors_prime, 
	(a.recours_ass=1)*max(0,(b.montant_ass_T1-b.prime_ass_T1)) as montant_ass_hors_prime_T1, (a.recours_ass=1)*max(0,(b.montant_ass_T2-b.prime_ass_T2)) as montant_ass_hors_prime_T2, 
	(a.recours_ass=1)*max(0,(b.montant_ass_T3-b.prime_ass_T3)) as montant_ass_hors_prime_T3, (a.recours_ass=1)*max(0,(b.montant_ass_T4-b.prime_ass_T4)) as montant_ass_hors_prime_T4, 
	/* On crée montant_ass_hors_prime pour alimenter les tables foyers, car les primes d'intéressement ne sont pas soumis à l'impôt */
	/* To Do : Vérifier si on ne devrait pas supprimer montant_ass au profit de montant_ass_hors prime, quitte à créer une variable qui agrège tout en sortie à la fin */
	((a.recours_ass=1)*(nbmois_chosansASST1+nbmois_chosansASST2+nbmois_chosansASST3+nbmois_chosansASST4)/max(1,nbmois_cho)) as part_chomrest,
	ressources_ass, reprise_act, prem_mois_ass, cal0, proba_ass
	from table_tirage_ass as a right join base_ressources_ass as b 
	on a.ident=b.ident and a.noi=b.noi
	order by ident, noi;
	quit;

	/*	2. SUBSTITUTION DE L'ASS AUX ALLOCATIONS CHÔMAGES POUR LES BÉNÉFICIAIRES TIRÉS */
/* On récupère le montant de l'ASS pour anleg-1 et anleg-2 afin de remplir correctement base.foyer&anr. et base.foyer&anr1. 
	Attention : dans le cas où l'on n'a pas anleg=anref+2, l'ass suit la logique législative pour le vieillissement tout comme les prestations
	qui sont exprimées en euros &anleg., mais contrairement aux autres revenus fiscaux qui sont vieillis en fonction de &anref. 
	Dans les différentes tables, on remplace les allocations chômages par l'ASS simulée. Une variable montant_ass et ass_noel est
	conservée dans baserev pour faire des sorties sur cette prestation uniquement mais en dehors de ça elle est confondue dans les 
	variables des allocations chômage */

%let anl=%eval(&anleg.-2);
%let anl1=%eval(&anleg.-1);

data _null_;
	set dossier.minima (keep=nom valeur_INES_&anl. valeur_INES_&anl1.);
	if nom ne '';
	call symputx(cats(nom,'_',&anl1.),valeur_INES_&anl1.);
	call symputx(cats(nom,'_',&anl.),valeur_INES_&anl.);
	run;

%if &anleg. ne %eval(&anref.+2) %then %put Warning : ASS exprimée en euros &anleg. alors que les allocations chômage et les autres revenus fiscaux sont exprimés en euros %eval(&anref.+2);

/* On impute dans modele.baseind, que l'on crée pour la 1ere fois du modèle ici, afin de faire à la fin de l'enchaïnement des sorties spécifiques */
%varexist(lib=base,table=baseind,var=montant_ass);
	data modele.baseind;
		merge base.baseind (%if &varexist. %then %do; in=a drop=montant_ass montant_ass_hors_prime ass_noel %end; %else %do; in=a %end;)
				  ass (keep=ident noi recours_ass montant_ass montant_ass_hors_prime ass_noel);
		by ident noi;
		if a;
		if recours_ass=. then recours_ass=0 ;
		if montant_ass=. then montant_ass=0 ;
		if montant_ass_hors_prime=. then montant_ass_hors_prime=0 ;
		if ass_noel=. then ass_noel=0 ;
		run;

/* Imputation dans baserev : on remplace les zcho par l'ass simulée quand les individus sont recourants */
	data base.baserev (drop=recours_ass /*montant_ass_T1 montant_ass_T2 montant_ass_T3 montant_ass_T4*/ nbmois_cho); 
	/* To Do : droper toutes les variables relatives à l'ASS, sauf les 3 variables montant_ass montant_ass_hors_prime et ass_noel */
		merge base.baserev (%if &varexist. %then %do; in=a drop=montant_ass: ass_noel montant_ass: ass_noel reprise_act nbmois_ass: nbmois_chosansASS: %end; %else %do; in=a %end;)
					  ass (keep=ident noi montant_ass: recours_ass ass_noel reprise_act proba_ass nbmois_ass: nbmois_chosansASS:);
		by ident noi;
		if a;
		nbmois_cho=sum(of nbmois_choT1-nbmois_choT4);
	/* L'ASS Noël et la prime d'intéressement n'entrant pas en compte dans le calcul des différentes bases ressources, on ne les met pas dans zchoi */
		if recours_ass=1 then do;
			zchoi&anr2.=(montant_ass_hors_prime)+zchoi&anr2.*(nbmois_chosansASS/max(1,nbmois_cho));
			zchoi&anr1.=%sysevalf(&&ass_mont_&anl1../&ass_mont.)*(montant_ass_hors_prime)+zchoi&anr1.*(nbmois_chosansASS/max(1,nbmois_cho));
			zchoi&anr.=%sysevalf(&&ass_mont_&anl../&ass_mont.)*(montant_ass_hors_prime)+zchoi&anr.*(nbmois_chosansASS/max(1,nbmois_cho));
				%do i=1 %to 4;
					zchoi&anr2._T&i.=montant_ASS_hors_prime_T&i.+zchoi&anr2._T&i.*(nbmois_chosansASST&i./max(1,nbmois_choT&i.));
					%end;
			end;
		else do;
			%Init_Valeur(montant_ass ass_noel montant_ass_hors_prime);
			end;
	run;

/* Imputation des bases foyer : on suppose que dans le cas des doubles déclarations, la moitié de l'ASS est déclarée dans declar1 et l'autre moitié dans declar2 
	De plus, on impute le montant d'ASS hors primes d'intéressement, car celles-ci ne sont pas imposables */
proc sql;
	/* Dans les tables ass_ind_declar1 et ass_ind_declar2 on a une ligne par ident noi */
	create table ass_ind_declar1(keep=declar1 ass: ident noi part_chom: recours_ass:) as
		select unique *, (declar2 = '')*(persfip='vous')*(recours_ass=1)*(montant_ass_hors_prime) + (declar2 ne '')*(persfip='vous')*(recours_ass=1)*(montant_ass_hors_prime)/2 as ass_vous,
		(persfip='vous')*(recours_ass=1)*(part_chomrest) as part_chomrest_vous,
		(persfip='vous')*(recours_ass=1) as recours_ass_vous,
		(declar2 = '')*(persfip='conj')*(recours_ass=1)*(montant_ass_hors_prime) + (declar2 ne '')*(persfip='conj')*(recours_ass=1)*(montant_ass_hors_prime)/2 as ass_conj,
		(persfip='conj')*(recours_ass=1)*(part_chomrest) as part_chomrest_conj,
		(persfip='conj')*(recours_ass=1) as recours_ass_conj,
		(declar2 = '')*(persfip='pac' and substr(declar1,31,4)=naia)*(recours_ass=1)*(montant_ass_hors_prime) + (declar2 ne '')*(persfip='pac' and substr(declar1,31,4)=naia)*(recours_ass=1)*(montant_ass_hors_prime)/2 as ass_pac1,
		(persfip='pac' and substr(declar1,31,4)=naia)*(recours_ass=1)*(part_chomrest) as part_chomrest_pac1,
		(persfip='pac' and substr(declar1,31,4)=naia)*(recours_ass=1) as recours_ass_pac1
		from ass;
	create table ass_ind_declar2(keep=declar2 ass: ident noi part_chom: recours_ass:) as
		select unique *, (persfip='vous')*(recours_ass=1)*(montant_ass_hors_prime)/2 as ass_vous,
		(persfip='vous')*(recours_ass=1)*(part_chomrest) as part_chomrest_vous,
		(persfip='vous')*(recours_ass=1) as recours_ass_vous,
		(persfip='conj')*(recours_ass=1)*(montant_ass_hors_prime)/2 as ass_conj,
		(persfip='conj')*(recours_ass=1)*(part_chomrest) as part_chomrest_conj,
		(persfip='conj')*(recours_ass=1) as recours_ass_conj,
		(persfip='pac' and substr(declar2,31,4)=naia)*(recours_ass=1)*(montant_ass_hors_prime)/2 as ass_pac1,
		(persfip='pac' and substr(declar1,31,4)=naia)*(recours_ass=1)*(part_chomrest) as part_chomrest_pac1,
		(persfip='pac' and substr(declar1,31,4)=naia)*(recours_ass=1) as recours_ass_pac1
		from ass
		where declar2 ne '';
	/* On peut avoir plusieurs fois le même individu dans ass_ind s'il apparait sur plusieurs déclarations */
	create table ass_ind as
		select coalesce(a.declar1,b.declar2) as declar, coalesce(a.part_chomrest_vous,b.part_chomrest_vous) as part_chomrest_vous, 
		coalesce(a.part_chomrest_conj,b.part_chomrest_conj) as part_chomrest_conj, 
		coalesce(a.part_chomrest_pac1,b.part_chomrest_pac1) as part_chomrest_pac1, 
		coalesce(a.recours_ass_vous,b.recours_ass_vous) as recours_ass_vous, 
		coalesce(a.recours_ass_conj,b.recours_ass_conj) as recours_ass_conj, 
		coalesce(a.recours_ass_pac1,b.recours_ass_pac1) as recours_ass_pac1, 
		sum(a.ass_vous,b.ass_vous) as ass_vous, sum(a.ass_conj,b.ass_conj) as ass_conj, 
		sum(a.ass_pac1,b.ass_pac1) as ass_pac1
		from ass_ind_declar1 as a full join ass_ind_declar2 as b
		on a.declar1=b.declar2;
	/* On regroupe les lignes appartenant à un même foyer, ie les conjoints */
		create table ass_decl as
		select declar, sum(ass_vous) as ass_vous, sum(ass_conj) as ass_conj, sum(ass_pac1) as ass_pac1,
		sum(part_chomrest_vous) as part_chomrest_vous, sum(part_chomrest_conj) as part_chomrest_conj,
		sum(part_chomrest_pac1) as part_chomrest_pac1,
		sum(recours_ass_vous) as recours_ass_vous, sum(recours_ass_conj) as recours_ass_conj,
		sum(recours_ass_pac1) as recours_ass_pac1
		from ass_ind
		group by declar
		order by declar;
quit;

/* Imputation dans base.foyer&anr2. */
proc sort data=base.foyer&anr2.; by declar; run;
data base.foyer&anr2. (drop=ass_vous ass_conj ass_pac1 part_chomrest: recours_ass:);
	merge base.foyer&anr2. (in=a) ass_decl;
	by declar;
	if a;
	if recours_ass_vous>0 then _1ap=ass_vous+part_chomrest_vous*_1ap;
	if recours_ass_conj>0 then _1bp=ass_conj+part_chomrest_conj*_1bp;
	if recours_ass_pac1>0 then _1cp=ass_pac1+part_chomrest_pac1*_1cp;
	if recours_ass_vous>0 or recours_ass_conj>0 or recours_ass_pac1>0 then zchof=_1ap+_1bp+_1cp;
	run;

/* Imputation dans base.foyer&anr1. */
proc sort data=base.foyer&anr1.; by declar; run;
data base.foyer&anr1. (drop=ass_vous ass_conj ass_pac1 part_chomrest: recours_ass:);
	merge base.foyer&anr1. (in=a) ass_decl;
	by declar;
	if a;
	if recours_ass_vous>0 then _1ap=%sysevalf(&&ass_mont_&anl1../ &ass_mont.)*ass_vous+part_chomrest_vous*_1ap;
	if recours_ass_conj>0 then _1bp=%sysevalf(&&ass_mont_&anl1../ &ass_mont.)*ass_conj+part_chomrest_conj*_1bp;
	if recours_ass_pac1>0 then _1cp=%sysevalf(&&ass_mont_&anl1../ &ass_mont.)*ass_pac1+part_chomrest_pac1*_1cp;
	if recours_ass_vous>0 or recours_ass_conj>0 or recours_ass_pac1>0 then zchof=_1ap+_1bp+_1cp;
	run;

/* Imputation dans base.foyer&anr. */
proc sort data=base.foyer&anr.; by declar; run;
data base.foyer&anr. (drop=ass_vous ass_conj ass_pac1 part_chomrest: recours_ass:);
	merge base.foyer&anr. (in=a) ass_decl;
	by declar;
	if a;
	if recours_ass_vous>0 then _1ap=%sysevalf(&&ass_mont_&anl../ &ass_mont.)*ass_vous+part_chomrest_vous*_1ap;
	if recours_ass_conj>0 then _1bp=%sysevalf(&&ass_mont_&anl../ &ass_mont.)*ass_conj+part_chomrest_conj*_1bp;
	if recours_ass_pac1>0 then _1cp=%sysevalf(&&ass_mont_&anl../ &ass_mont.)*ass_pac1+part_chomrest_pac1*_1cp;
	if recours_ass_vous>0 or recours_ass_conj>0 or recours_ass_pac1>0 then zchof=_1ap+_1bp+_1cp;
	run;

%end;

%else %do; 
/* Dans le cas où l'on ne souhaite pas faire tourner le module ass, on met les variables spécifiques ASS dans modele.baseind à zéro (variables appelées dans cible_ines) */
data modele.baseind;
	set base.baseind;
	%Init_Valeur(recours_ass montant_ass ass_noel montant_ass_hors_prime);
	run;
data base.baserev;
	set base.baserev;
	%Init_Valeur(montant_ass ass_noel montant_ass_hors_prime);
	run;
	%end;

/* suppression des tables intermédiaires */

proc datasets mt=data library=work kill; run; quit; 

%mend;
%calcul_ass;

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
