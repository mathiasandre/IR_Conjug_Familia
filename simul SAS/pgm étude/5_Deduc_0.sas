/****************************************************************************************/
/*																						*/
/*									5_Deduc												*/
/*																						*/
/****************************************************************************************/
/*																						*/		
/* Calcul des déductions d'impot							                       		*/
/* En entrée : 	base.foyer&anr1.                 				           				*/
/* 				modele.rev_imp&anr1.													*/
/*				modele.nbpart															*/
/*				modele.Prelev_Forf&anr1. (si besoin)									*/
/* En sortie : 	modele.deduc                                      						*/
/****************************************************************************************/
/*																						*/	
/* PLAN DU PROGRAMME : 																	*/
/*	1	Constitution d'une table modele.deduc avec toutes les informations          	*/
/*      nécessaires au calcul des CI et RI												*/	
/*	2	Calcul des différents CI et RI													*/
/*		2.1	Réductions d'impôt															*/				
/*		2.2	Crédits d'impôt																*/
/*		2.3	Imputations																	*/		
/*	3	Agrégation des crédits et réductions d'impôt 									*/
/*																						*/
/****************************************************************************************/
/* NOTE IMPORTANTE :  travail à faire par un courageux un jour : 
il serait bon d'harmoniser les noms des paramètres : chaque élément à un nom don, sofica, etc. 
Il faut aussi préciser s'il sagit d'une déduction(=abattement), d'une réduction ou d'un crédit. 
Enfin, il faut savoir si le paramètre est un montant, un taux à appliquer, ou un taux limite 
de RNG : 
On peut retenir la forme suivante : 
"nom_role_type"
le role s'écrivant m ou t si pour un montant ou un taux, éventuellement t1 t2, etc. si on 
a besoin de plusieurs taux pour le même dispositifs, le type étant d,r ou c.
Il n'y a plus qu'à le faire ! */
/****************************************************************************************/
/* Remarques : 																			*/
/*	- le crédit d'impot lié à la télédéclaration n'est pas pris en compte				*/ 
/*		(20 euros pour la permière declaration sur internet jusqu'en 2009) 				*/
/****************************************************************************************/

%Macro Plafonnement_ordonne(cases_ordonnees,plafond);
/* Lorsqu'un plafonnement concerne la somme de plusieurs cases, on veut parfois les plafonner 
   selon un certain ordre (traduit un comportement d'optimisation individuelle : 
   dépense la plus grosse=celle qui donne droit au tx le plus fort
		@cases_ordonnees : liste des cases à plafonner, par ordre DECROISSANT du taux de RI auquel elles donnent lieu
		@plafond : plafond total appliqué à la somme de toutes les cases listées */

	/* 1 - Initialisation */
	%let vnonplaf=%scan(&cases_ordonnees.,1); 	/* nom de la case à plafonner */
	%let vplaf=&vnonplaf._plaf;					/* nom de la case plafonnée (_plaf à la fin) */
	&vplaf.=min(&vnonplaf.,&plafond.);			/* on plafonne */
	s=0;										/* s=somme des cases déjà traitées */
	/* 2 - Plafonnement itératif */
	%do k=2 %to %sysfunc(countw(&cases_ordonnees.));
		%let vnonplaf=%scan(&cases_ordonnees.,&k.);				/* nom de la case courante à plafonner */
		%let vplaf=&vnonplaf._plaf;								/* nom de la case courante plafonnée */
		%let vnonplaf_m1=%scan(&cases_ordonnees.,%eval(&k.-1));	/* nom de la variable non plafonnée précédente dans la liste (sert en-dessous) */
		%let vplaf_m1=&vnonplaf_m1._plaf;						/* nom de la variable plafonnée précédente dans la liste */
		s=s+&vplaf_m1.;											/* s=somme des cases déjà traitées */
		&vplaf.=max(min(&vnonplaf.,&plafond.-s),0);				/* plafonnement de la case courante */
		%end;
	drop s;
	%Mend Plafonnement_ordonne;


/**************************************************************************************************************/
/*	1	Constitution d'une table modele.deduc avec toutes les informations nécessaires au calcul des CI et RI */
proc sql;
	create table modele.deduc as
	select c.*, d.npart from
		(select a.*, b.rng, b.rng1, b.rng2, b.rnga, b.chiffaff, b.RFR
				from base.foyer&anr1. (drop=rng) as a inner join modele.rev_imp&anr1. as b
				on a.declar=b.declar) as c inner join modele.nbpart as d
			on c.declar=d.declar;
	quit;

%macro Merge_PF;
	/* On ne récupère l'information contenue dans Prelev_Forf&anr1. que dans le cas où on en a besoin (pas encore la case _2ck) */
	%if	(&anleg.>=2014 and &anref.<2013) %then %do;
		data modele.deduc;
			merge modele.deduc modele.Prelev_Forf&anr1. (keep=declar PF_Obligatoire);
			by declar;
			run;
		%end;
	%mend Merge_PF;
%Merge_PF;

/*MODIF ICI : on récupère les variables part1 part2 anaisenf et on crée la variable pres_enf*/
data modele.deduc (drop=i);
	merge modele.deduc modele.rbg&anr1. (keep=declar part1 part2 anaisenf);
	by declar;
	pres_enf=0;
	do i=0 to ((length(anaisenf)-5)/5) ; 
		an=input(substr(anaisenf,i*5+2,4),4.); 
		if an=. then an=0; 
		if &anref.-an<6 then pres_enf=1; 
		end;
	run;

/***************************************/
/*	2	Calcul des différents CI et RI */
%macro Deduc;

	data modele.deduc (keep=declar deduc_av_decote deduc_ap_decote deduc_ap_decote1 deduc_ap_decote2 credit credit1 credit2 RED: CRED: plaf_esd nb_trav_devldura part1 part2);
		/*MODIF ICI : ajout des variables 1 et 2 dans le keep*/
		set	modele.deduc;

		npchai=sum(nbg,nbr);
		/*MODIF ICI : on met à 0 le nombre d'enfants à charge*/ 
		nec=0;
		/*MODIF ICI : on enlève toutes les personnes à charges même les invalides (nbf: handicapés / nbr : invalides / nbj : célibataires majeurs / nbf : mineurs ou handicapés */
		pchar=0; 
		/*MODIF ICI : on met à 0 le nombre d'enfants ou handicapés à charge en garde alternée*/
		nbh = 0;

		/*------------------------------------------------------------------------------*/
		/*--	2.1	REDUCTIONS D IMPOT (ne sont pas imputees sur l'impot plus-values) --*/
		/*------------------------------------------------------------------------------*/

		%let Reduc_Codes_Ines=	RED_dons1 RED_dons2 RED_rente_survie RED_syndic_vous RED_syndic_conj RED_syndic_pac RED_syndic 
									RED_sal_domicile CRED_sal_domicile RED_long_sejour1 RED_long_sejour2 RED_long_sejour 
									RED_secondaire RED_superieur RED_enfants_ecole
									RED_presta_compens RED_Duflot RED_pinel_metro RED_pinel_dom RED_Scellier RED_meuble_non_prof RED_Malraux 
									RED_PME RED_FIP RED_FCPI RED_FIP_corse RED_FIP_dom RED_FIP RED_presse
									RED_Sofica RED_Sofipeche RED_reprise_societe RED_foret RED_nature RED_foret_acquis RED_foret_travaux RED_foret_contrat
									RED_invloc_tour RED_monument RED_codev RED_foret_incendie RED_interet_agriculteur 
									RED_crea_entre RED_compta_gestion RED_mecenat RED_biencult RED_pret_conso
									RED_Excep;
		/* Initialisation à zéro de toutes les réductions d'impôt que l'on codera dans Ines */
		%Init_Valeur(&Reduc_Codes_Ines.);

		/* DONS */
		/* Dons - 1 : Aide aux personnes en difficulté */
		Dons1=_7ud+_7va; /* Taux le plus avantageux, avec plafond */
		Dons1_Plaf=min(Dons1,&don_mlim_r1.);
		RED_dons1=&don_t_r1.*Dons1_Plaf;
		label RED_dons1="Dons à des organismes d'aide aux personnes en difficulté";

		/* Dons - 2 : Organismes d'intérêt général + résidu de Dons1 */
		Excedent_Dons1=Dons1-Dons1_Plaf; /* Dépenses excédant le plafond (0 si <) : taux moins avantageux + dans la limite d'une fraction du revenu */
		Dons2=_7uf+min(_7uh,&don_mlim_r3.)+_7vc+_7xs+_7xt+_7xu+_7xw+_7xy;
		/* Plafond spécifique pour dons aux partis politiques
		Ecart à la législation : on code uniquement le plafond au niveau du foyer, il existe également un plafond individuel */
		RED_dons2=&don_t_r2.*(min(Dons2+Excedent_Dons1,&don_tlim_r2.*RNG2));
		label RED_dons2="Autres dons";

		/*RENTE-SURVIE----------------------------------------------------------*/
		RED_rente_survie=&rente_t_r.*min(_7gz,(&rente_lim1_r.+&rente_lim2_r.*(nec+0.5*nbh)));
		label RED_rente_survie="Primes de rentes survie, contrats d'épargne handicap";

		/*COTISATIONS SYNDICALES------------------------------------------------*/
		%if &anleg.<2013 %then %do; 
			if _1ak=0 & (sum(_1aj,_1tp,_1nx,_1pm,_1af, _1ag, _1as,_1al, _1am, _1az))>0 then 
				RED_syndic_vous=&syndic_tx.*min(_7ac,&syndic_limit.*(sum(_1aj,_1tp,_1nx,_1pm,_1af, _1ag, _1as,_1al, _1am, _1az)));
			if _1bk=0 & (sum(_1bj,_1up,_1ox,_1qm,_1bf, _1bg, _1bs,_1bl, _1bm, _1bz))>0 then 
				RED_syndic_conj=&syndic_tx.*min(_7ae,&syndic_limit.*(sum(_1bj,_1up,_1ox,_1qm,_1bf, _1bg, _1bs,_1bl, _1bm, _1bz)));
			if _1ck=0 & (sum(_1cj,_1cf, _1cg,_1cs,_1cl, _1cm,_1cz,_1dj,_1df, _1dg,_1ds,_1dz,_1dl, _1dm,_1ej,_1ef, _1eg,_1es,_1el,_1em,_1fj,_1ff, _1fg,_1fs, _1fl, _1fm)) >0 
			then RED_syndic_pac=&syndic_tx.*min(_7ag,&syndic_limit.*(sum(_1cj,_1cf, _1cg,_1cs,_1cl, _1cm,_1cz,_1dj,_1df, _1dg,_1ds,_1dz,_1dl, _1dm,_1ej,_1ef, _1eg,_1es,_1el,_1em,_1fj,_1ff, _1fg,_1fs, _1fl, _1fm))); 
		%end;
		RED_syndic=RED_syndic_vous+RED_syndic_conj+RED_syndic_pac;
		label RED_syndic="Cotisations syndicales des salariés et pensionnés";

		/*EMPLOI D UN SALARIE A DOMICILE----------------------------------------*/
		/* plafond : 12 000 + 3 000 si première fois + 1 500 par pac dans la limite de 3 000 ou 20 000 si carte invalidité */
		if _7dg=0 then
			plaf_esd=	&saldom_lim1_r.+
						&saldom_lim2_r.*max(((aged>65)+(agec>65)+nec+0.5*nbh+_7dl*(&anleg>2005)),2)+
						(&saldom_lim4_r.-&saldom_lim1_r.)*_7dq;
		else plaf_esd=&saldom_lim3_r.;
		/* MODIF ICI : ajout de * (1-pres_enf)*/
		RED_sal_domicile=&saldom_t_r.*min(sum(_7df,_7dd),plaf_esd)*(1-pres_enf); 
		CRED_sal_domicile=&saldom_t_r.*min(_7db,plaf_esd)*(1-pres_enf); 

		/*REDuction actuelle, anciennement crédit*/
		%if &anleg.<2007 %then %do; 
			RED_sal_domicile=RED_sal_domicile+CRED_sal_domicile; 
			CRED_sal_domicile=0; 
			%end; 
		label 	RED_sal_domicile="Emploi d'un salarié à domicile"
				CRED_sal_domicile="Emploi d'un salarié à domicile";

		/*HEBERGEMENT LONG SEJOUR ou plus récemment accueil dans un établissement pour personne dépendante */
		RED_long_sejour1=&dep_t_r.*min(_7cd,&dep_lim_r.);
		RED_long_sejour2=&dep_t_r.*min(_7ce,&dep_lim_r.);
		%if &anleg.<2001 %then %do; 
			RED_long_sejour1=RED_long_sejour1*(aged>=70);
			RED_long_sejour2=RED_long_sejour2*(aged>=70);
			%end;
		RED_long_sejour=RED_long_sejour1+RED_long_sejour2;
		%if (&anleg.<1994) %then %do;
			if mcdvo not in ('M','O') then RED_long_sejour=0;
			%end;
		label RED_long_sejour="Dépenses d'accueil dans un établissement pour personnes dépendantes";

		/*ENFANTS SCOLARISES--------------------------------------------------*/
		RED_secondaire   =(_7ea+0.5*_7eb)*&scol_m1_r.+(_7ec+0.5*_7ed)*&scol_m2_r.;
		RED_superieur    =(_7ef+0.5*_7eg)*&scol_m3_r.;
		RED_enfants_ecole=RED_secondaire+RED_superieur;
		/*MODIF ICI : on met à zéro*/
		RED_enfants_ecole = 0;
		label RED_enfants_ecole="Enfants à charge poursuivant leurs études";


		/*PRESTATION COMPENSATOIRE---------------------------------------------*/
		%Init_Valeur(RED_presta_compens1 RED_presta_compens2);
		if _7wm=0 then do;
			/*normalement _7wn>_7wo est impossible*/
			if _7wn>=_7wo then 
				RED_presta_compens1=&prestacomp_t_r.*Min(_7wn,&prestacomp_lim_r.); 
			else if _7wn<_7wo and _7wo<=&prestacomp_lim_r. then 
				RED_presta_compens1=&prestacomp_t_r.*_7wn;
			else if _7wn<_7wo and _7wo>&prestacomp_lim_r.  then 
				RED_presta_compens1=&prestacomp_t_r.*(_7wn/max(1,_7wo))*&prestacomp_lim_r.;
			end;
		else if _7wm>0 then do;/*en pratique ce cas n'arrive jamais*/
			if _7wn=_7wm and _7wo<=&prestacomp_lim_r. then 
				RED_presta_compens1=&prestacomp_t_r.*_7wm;
			else if _7wn=_7wm and _7wo>&prestacomp_lim_r.  then 
				RED_presta_compens1=&prestacomp_t_r.*(_7wm/max(1,_7wo))*&prestacomp_lim_r.;
			else if _7wn<_7wm and _7wo<=&prestacomp_lim_r. then 
				RED_presta_compens1=&prestacomp_t_r.*_7wn;
			else if _7wn<_7wm and _7wo>&prestacomp_lim_r.  then 
				RED_presta_compens1=&prestacomp_t_r.*(_7wn/max(1,_7wo))*&prestacomp_lim_r.;
			end;
		if _7wp>0 then RED_presta_compens2=&prestacomp_t_r.*_7wp; 
		RED_presta_compens=RED_presta_compens1+RED_presta_compens2;
		label RED_presta_compens="Prestations compensatoires";

		/* INVESTISSEMENT LOCATIF DUFLOT */
		/*On ne peut pas simuler les années précédentes de législation car les montants de la base de la réduction d'impôt n'ont pas été conservés
		dans des variables explicites*/
		%IF &anleg. = 2017 %THEN %DO; 

			%Plafonnement_ordonne (_7gi _7el _7gh _7ek, &duflot_mlim.); 
			/*on prend ce qui avantage le plus le foyer, avec le taux le plus élevé, donc en 1er la case pour les DOM ici
			cf. exemple 1 à 4 paragraphe 250 et 260 de http://bofip.impots.gouv.fr/bofip/8505-PGP.html?identifiant=BOI-IR-RICI-360-30-10-20150611*/
			RED_duflot=sum(&duflot_tx_metro.*(_7gh_plaf + _7ek_plaf),&duflot_tx_dom.*(_7gi_plaf + _7el_plaf))/9;
			
			/*On ajoute les reports des années précédentes*/
			RED_duflot=sum(RED_duflot, _7fi, _7fk, _7fr);
			%END;

		label RED_Duflot="Investissement locatif neuf : loi Duflot";

		/* INVESTISSEMENT LOCATIF PINEL */
		/* NON-CODE faute d'information : plafonnement à 5500 euros par m² 
						(ou 95 % montant souscription SCPI) en plus du plafond global à 300 000 € */
		%IF &anleg. = 2015 %THEN %DO; 
			/*Législation 2015 : la réduction d'impôt s'applique aux investissements N-1 réalisés de septembre à décembre*/
			_7qi_apSept = _7qi*4/12;
			_7qj_apSept = _7qj*4/12;
			_7qk_apSept = _7qk*4/12;
			_7ql_apSept = _7ql*4/12;

			%Plafonnement_ordonne (_7qi_apSept _7qj_apSept _7qk_apSept _7ql_apSept, &pinel_mlim.); 
			/*on prend ce qui avantage le plus le foyer, avec le taux le plus élevé 
			cf. exemple 1 à 4 paragraphe 250 et 260 de http://bofip.impots.gouv.fr/bofip/8505-PGP.html?identifiant=BOI-IR-RICI-360-30-10-20150611*/
			/* La réduction porte au maximun sur deux logements par année d'investissement. Pour être parcimonieux, on considère que cette règle 
				de déclaration est bien respectée et on ne vérifie pas que les contribuables remplissent bien 2 cases maximum sur 4
				(ce qui ne serait en plus qu'une condition nécessaire car une seule case remplie pourrait correspondre à plusieurs logements acquis) */ 	
	 		
			/* On distingue la réduction sur les investissements dans les DOM de celle en France métro 
			car la RI pour les DOM bénéficie du plafond majoré des avantages fiscaux globaux à partir de la législation 2016  */
			RED_pinel_metro = SUM(&pinel_tx_metro6ans.*_7qi_apSept_plaf/6, 
								  &pinel_tx_metro9ans.*_7qj_apSept_plaf/9);
			RED_pinel_dom = SUM(&pinel_tx_dom6ans.*_7qk_apSept_plaf/6,
								&pinel_tx_dom9ans.*_7ql_apSept_plaf/9);
			%END;
		
		%ELSE %IF &anleg. = 2016 %THEN %DO;
			/*Législation 2016 : la réduction d'impôt s'applique aux investissements N-1 + les investissements N-2 réalisés de septembre à décembre*/
			_7qe_apSept = _7qe*4/12;
			_7qf_apSept = _7qf*4/12;
			_7qg_apSept = _7qg*4/12;
			_7qh_apSept = _7qh*4/12;

			%Plafonnement_ordonne (_7qi _7qe_apSept _7qj _7qf_apSept _7qk _7qg_apSept _7ql _7qh_apSept, &pinel_mlim.); 

			RED_pinel_metro = SUM(&pinel_tx_metro6ans.*(_7qi_plaf+_7qe_apSept_plaf)/6, 
								  &pinel_tx_metro9ans.*(_7qj_plaf+_7qf_apSept_plaf)/9);
			RED_pinel_dom = SUM(&pinel_tx_dom6ans.*(_7qk_plaf+_7qg_apSept_plaf)/6,
								&pinel_tx_dom9ans.*(_7ql_plaf+_7qh_apSept_plaf)/9);

			/*La réduction d'impôt est répartie sur six ou neuf années à raison du sixième ou du neuvième de son montant chaque année 
			selon la durée d'engagement de location -> https://www3.impots.gouv.fr/simulateur/calcul_impot/2017/aides/reductions.htm (voir aussi
			http://bofip.impots.gouv.fr/bofip/8425-PGP.html). Donc on rajoute aussi les reports des années précédentes*/
			RED_pinel_metro=RED_pinel_metro+sum(_7bz, _7cz);
			RED_pinel_dom=RED_pinel_dom+sum(_7dz, _7ez);
			%END;

		%ELSE %IF &anleg. = 2017 %THEN %DO;
			/*Législation 2017 : la réduction d'impôt s'applique aux investissements N-1, N-2, + les investissements N-3 réalisés de septembre à décembre
				(qui sont dans les cases 7qa à 7qd, pas besoin de multiplier par 4/12 ici)*/

			%Plafonnement_ordonne (_7qi _7qe _7qa _7qj _7qf _7qb _7qk _7qg _7qc _7ql _7qh _7qd, &pinel_mlim.); 

			RED_pinel_metro = SUM(&pinel_tx_metro6ans.*(_7qi_plaf+_7qe_plaf+_7qa_plaf)/6, 
								  &pinel_tx_metro9ans.*(_7qj_plaf+_7qf_plaf+_7qb_plaf)/9);
			RED_pinel_dom = SUM(&pinel_tx_dom6ans.*(_7qk_plaf+_7qg_plaf+_7qc_plaf)/6,
								&pinel_tx_dom9ans.*(_7ql_plaf+_7qh_plaf+_7qd_plaf)/9);

			/*Ajout des reports des années précédentes*/
			RED_pinel_metro=RED_pinel_metro+sum(_7bz, _7cz, _7ai, _7bi);
			RED_pinel_dom=RED_pinel_dom+sum(_7dz, _7ez, _7ci, _7di);
			%END;

		label RED_pinel_metro="Investissement locatif neuf en France métropolitaine : loi Pinel";
		label RED_pinel_dom="Investissement locatif neuf dans les DOM : loi Pinel";

		/* INVESTISSEMENT LOCATIF SCELLIER */
		/* On néglige les investissements Scellier dans les DOM */
		/* Ecart à la législation : on n'écrit pas d'années dans le code mais qu'on fait tout en relatif (dépenses de N-1 ou N-2 et non en 2011/2012...) */
		/* A reprendre si l'on souhaite étudier cette réduction d'impôt dans le détail */
		%if &anleg.=2010 %then %do; 
			RED_Scellier=&scellier_avt2010.*sum(min(&scellier_mlim.,_7hj),min(&scellier_mlim.,_7hk))/9;
			%end;
		%else %do; 
			RED_Scellier=(&scellier_avt2010.*sum(min(&scellier_mlim.,_7hj),
												min(&scellier_mlim.,_7hn),min(&scellier_mlim.,_7nc),
												min(&scellier_mlim.,_7nd),min(&scellier_mlim.,_7nh),
												min(&scellier_mlim.,_7nb))
						+&scellier_avt2010_dom.*sum(min(&scellier_mlim.,_7ho),
													min(&scellier_mlim.,_7hk),min(&scellier_mlim.,_7nm),
													min(&scellier_mlim.,_7nn),min(&scellier_mlim.,_7no),
													min(&scellier_mlim.,_7nr),min(&scellier_mlim.,_7ns),
													min(&scellier_mlim.,_7nt),min(&scellier_mlim.,_7nl),
													min(&scellier_mlim.,_7nq))
						+&scellier_avt2010_nonbbc.*sum(min(&scellier_mlim.,_7ni),min(&scellier_mlim.,_7ng))
						+&scellier_2011_bbc.*sum(min(&scellier_mlim.,_7ne),min(&scellier_mlim.,_7na),
												 min(&scellier_mlim.,_7jb),min(&scellier_mlim.,_7jd))
						+&scellier_2011_nonbbc.*sum(min(&scellier_mlim.,_7nj),min(&scellier_mlim.,_7nf),
													min(&scellier_mlim.,_7jh),min(&scellier_mlim.,_7jg))
						+&scellier_2011_dom.*sum(min(&scellier_mlim.,_7nk),min(&scellier_mlim.,_7np),
												min(&scellier_mlim.,_7jm),min(&scellier_mlim.,_7jq),
												min(&scellier_mlim.,_7jl),min(&scellier_mlim.,_7jp))
						+&scellier_2012_bbc.*sum(min(&scellier_mlim.,_7ja+_7fa),min(&scellier_mlim.,_7je))
						+&scellier_2012_nonbbc.*sum(min(&scellier_mlim.,_7jf+_7fb),min(&scellier_mlim.,_7jj))
						+&scellier_2012_dom.*sum(min(&scellier_mlim.,_7jk+_7fc),min(&scellier_mlim.,_7jo+_7fd),
												 min(&scellier_mlim.,_7jn),min(&scellier_mlim.,_7jr)))/9;
			%end;
		label RED_Scellier="Investissement locatif neuf : loi Scellier";

		/* Investissement location meublée non professionnelle (Censi-Bouvard) */
		/* TODO : retravailler la législation 2011 qui est plus complexe */
		/* Dans l'idéal il faudrait adapter le code pour faire varier les taux en fonction de anleg : par exemple, en anleg 2017 
		le taux avant 2010 doit s’appliquer aux investissements N-7 (c'est ce qui est codé ci-dessous), mais en anleg 2016 le taux avant 2010 
		devrait d’appliquer aux investissements N-7 et aussi N-6.*/
		RED_meuble_non_prof=&locmeuble_t_avt2010.*
								sum(	1/9*sum(	min(&locmeuble_mlim.,_7iw),
													min(&locmeuble_mlim.,_7im)),
										min(&locmeuble_mlim./9,_7oo),
										min(&locmeuble_mlim./9,_7oj),
										min(&locmeuble_mlim./9,_7oe),
							    		min(&locmeuble_mlim./9,_7ic),
										min(&locmeuble_mlim./9,_7iq),
										min(&locmeuble_mlim./9,_7ir),
										min(&locmeuble_mlim./9,_7ik),
										min(&locmeuble_mlim./9,_7jy))
							+&locmeuble_t_2010.*
								sum(	1/9*sum(	min(&locmeuble_mlim.,_7il),
													min(&locmeuble_mlim.,_7in)),
										min(&locmeuble_mlim./9,_7on),
										min(&locmeuble_mlim./9,_7oi),
										min(&locmeuble_mlim./9,_7od),
										min(&locmeuble_mlim./9,_7ib),
										min(&locmeuble_mlim./9,_7ip),
										min(&locmeuble_mlim./9,_7jx))
							+&locmeuble_t_2011.*
								sum(1/9*sum(	min(&locmeuble_mlim.,_7iv),
												min(&locmeuble_mlim.,_7ij),
												min(&locmeuble_mlim.,_7if),
												min(&locmeuble_mlim.,_7ie)),
									min(&locmeuble_mlim./9,_7om),
									min(&locmeuble_mlim./9,_7oh),
									min(&locmeuble_mlim./9,_7oc),
									min(&locmeuble_mlim./9,_7ia),
									min(&locmeuble_mlim./9,_7jw))
							+&locmeuble_t_aps2011.*
								sum(1/9*sum(	min(&locmeuble_mlim.,_7ow),
												min(&locmeuble_mlim.,_7ov),
												min(&locmeuble_mlim.,_7ou),
												min(&locmeuble_mlim.,_7jt),
												min(&locmeuble_mlim.,_7ju),
												min(&locmeuble_mlim.,_7id),
												min(&locmeuble_mlim.,_7ig)),
									min(&locmeuble_mlim./9,_7ok),
									min(&locmeuble_mlim./9,_7ol),
									min(&locmeuble_mlim./9,_7of),
									min(&locmeuble_mlim./9,_7og),
									min(&locmeuble_mlim./9,_7oa),
									min(&locmeuble_mlim./9,_7ob),
									min(&locmeuble_mlim./9,_7jv));
		label RED_meuble_non_prof="Investissement location meublée non professionnelle";


		/*TRAVAUX DE RESTAURATION "MALRAUX"--------------------------------------------*/
		RED_malraux=sum(	&malraux_ap2011_t1.*min(&malraux_mlim.,_7re+_7sx+_7ny),
							&malraux_ap2011_t2.*min(&malraux_mlim.,_7rf+_7sy+_7nx));
		label RED_malraux="Travaux de restauration immobilière";


		/*SOUSCRIPTION D IMPOT AU CAPITAL DE PME NON COTEES ou DE PETITES ENTREPRISES EN PHASE D'EXPANSION --------*/
		/* le plafond le plus élevé s'applique à l'ensemble des versements, sachant que les souscriptions au capital de PME avant 2012 sont aussi plafonnées avec une limite plus faible */ 
		/*MODIF ICI : on enlève le plafond pour les couples et on répartit proportionnellement les cases*/
		sousc_pme1=	 min((min((_7cu +_7cl+_7cm+_7cn+_7cc)*part1, /* PME non cotées */
							&pme_lim1_r.))+_7cf*part1*(&anleg.>=2010)+(_7cq+_7cr+_7cv)*part1*(&anleg.>=2014),&pme_lim2_r.);
		sousc_pme2=	 min((min((_7cu +_7cl+_7cm+_7cn+_7cc)*part2, /* PME non cotées */
							&pme_lim1_r.))+_7cf*part2*(&anleg.>=2010)+(_7cq+_7cr+_7cv)*part2*(&anleg.>=2014),&pme_lim2_r.); 
							/* PE en expansion : pas de RI sur les souscription au capital des start-up jusqu'à anleg 2009 et pas de reports de ce type de dépenses avant anleg 2014 */
		/* Ecart à la législation : pour les cases correspondant à des reports de versements effectués avant 2012, 
		le taux de RI n'est pas le même mais on applique un taux unique */
		/*MODIF ICI : suite de RED_PME*/
		RED_PME1=&pme_t_r.*sousc_pme1;
		RED_PME2=&pme_t_r.*sousc_pme2;
		label RED_PME1="Souscription au capital de PME en phase d'amorçage ou non côtées";


		/*SOUSCRIPTIONS PARTS FCP INNOVATION, FIP et FIP en Corse-----------------------*/
		/*MODIF ICI : on enlève le plafond pour les couples et on répartit proportionnellement les cases*/
		RED_FCPI1	 =&P0297b.  *min(_7gq*part1,(&P0297.));
		RED_FIP1		 =&P0297b.  *min(_7fq*part1,(&P0297.))*(&anleg.>2003);
		RED_FIP_corse1=&P0298.   *min(_7fm*part1,(&P0297.))*(&anleg.>=2007)*(&anref.>=2006);
		RED_FIP_dom1	 =&fipdom_t.*min(_7fl*part1,(&P0297.))*(&anleg.>=2012)*(&anref.>=2011);

		RED_FCPI2	 =&P0297b.  *min(_7gq*part2,(&P0297.));
		RED_FIP2		 =&P0297b.  *min(_7fq*part2,(&P0297.))*(&anleg.>2003);
		RED_FIP_corse2=&P0298.   *min(_7fm*part2,(&P0297.))*(&anleg.>=2007)*(&anref.>=2006);
		RED_FIP_dom2	 =&fipdom_t.*min(_7fl*part2,(&P0297.))*(&anleg.>=2012)*(&anref.>=2011);
		RED_FIP1=RED_FIP1+RED_FIP_corse1+RED_FIP_dom1;
		RED_FIP2=RED_FIP2+RED_FIP_corse2+RED_FIP_dom2;
		label RED_FIP1="Souscription de parts de fonds d'investissement de proximité";

		/* SOUSCRIPTION AU CAPITAL D'ENTREPRISES DE PRESSE */
		/* Dispositif apparaissant en 2016 */
		/* Le plafond s'applique à des dépenses bénéficiant de 2 taux différents, donc on maximise les dépenses bénéficiant du taux le plus avantageux 
		(entreprises ayant le statut d'entreprise solidaire de presse d'information) */
		/*MODIF ICI : on enlève le plafond pour les couples et on répartit proportionnellement les cases*/
		_7by1 = _7by*part1;
		_7bx1 = _7bx*part1;
		_7by2 = _7by*part2;
		_7bx2 = _7bx*part2;
		%Plafonnement_ordonne(_7by1 _7bx1,&presse_mlim_r.);
		%Plafonnement_ordonne(_7by2 _7bx2,&presse_mlim_r.);
		RED_presse1=_7bx1_plaf*&presse_t1_r. /* Entreprises de presse - RI de 30 % */
					+ _7by1_plaf*&presse_t2_r. ; /* Entreprises de presse au statut d'entreprise solidaire de presse d'information - RI de 50 % */
		RED_presse2=_7bx2_plaf*&presse_t1_r. /* Entreprises de presse - RI de 30 % */
					+ _7by2_plaf*&presse_t2_r. ; /* Entreprises de presse au statut d'entreprise solidaire de presse d'information - RI de 50 % */

		/*SOUSCRIPTION AU CAPITAL DE SOFICA----------------------------------------------*/
		/*Pour l'appréciation du plafond, les souscriptions déclarées case GN sont retenues en priorité*/
		_7gn_plaf=Min(_7gn,Min(&sofica_tlim.*RNG,&sofica_mlim.)); 
		_7fn_plaf=Min(_7fn,Min(&sofica_tlim.*RNG,&sofica_mlim.)-_7gn_plaf);
		RED_sofica=(&sofica_t1.*_7fn_plaf+&sofica_t2.*_7gn_plaf)*(&anleg.>2006);
		label RED_sofica="Souscription au capital de SOFICA";


		/*SOUSCRIPTION AU CAPITAL DE sofipêche----------------------------------------------*/
		/*MODIF ICI : on enlève le plafond pour les couples et on répartit proportionnellement les cases*/
		RED_sofipeche1=&sofipeche_t_r.*min(_souscSofipeche*part1,&sofipeche_tlim_r.*RNG*part1,&sofipeche_mlim_r.);
		RED_sofipeche2=&sofipeche_t_r.*min(_souscSofipeche*part2,&sofipeche_tlim_r.*RNG*part2,&sofipeche_mlim_r.);
		label RED_sofipeche1="Souscription au capital de SOFIPECHE";


		/*INTERETS D'EMPRUNTS POUR REPRISE DE SOCIETE---------------------------*/
		/*MODIF ICI : on enlève le plafond pour les couples et on répartit proportionnellement les cases*/
		RED_reprise_societe1=&reprise_t_r.*Min(_7fh*part1,&reprise_mlim_r.);
		RED_reprise_societe2=&reprise_t_r.*Min(_7fh*part2,&reprise_mlim_r.);
		label RED_reprise_societe1="Interêt d'emprunts pour reprise de société";

		/*INVESTISSEMENT DOM-TOM---------------------------------------------*/
		/* Cette RI était auparavant codée dans Ines mais de façon très imparfaite. 
		Etant donnée la complexité importante et croissante de la brochure fiscale sur ce point, et le peu d'observations concernées 
		(une trentaine pour l'ERFS 2012), on décide pendant la campagne 2016 de renoncer à vouloir coder ce dispositif. */

		/*INVESTISSEMENTS FORESTIERS--------------------------------------------*/
		/* Ecart à la législation : on ne code pas les réductions d'impôts calculées sur les dépenses d'assurance et les dépenses de travaux des années précédentes reportées. 
		Pourrait éventuellement être fait mais trop peu d'observations et montants faibles voire nuls pour de nombreuses cases à mobiliser. 
		De plus, manque d'information sur la taille des exploitations forestières assurées : plafond par hectare assuré pour les dépenses d'assurance, en plus du plafond global. */
		/*MODIF ICI : on enlève le plafond pour les couples et on répartit proportionnellement les cases*/
		RED_foret_acquis1 =&foret_t_r.*Min(_7un*part1,&foret_mlim1_r.);
		RED_foret_acquis2 =&foret_t_r.*Min(_7un*part2,&foret_mlim1_r.);
		RED_foret1=RED_foret_acquis1;
		RED_foret2=RED_foret_acquis2;
		label RED_foret1="Investissement forestier";


		/*PROTECTION DU PATRIMOINE NATUREL--------------------------------------*/
		/* Report des dépenses des années passées non codé */ 
		RED_nature=&nature_t_r.*min(_protect_patnat,&nature_mlim_r.);
		label RED_nature="Protection du patrimoine naturel";


		/*INVESTISSEMENT LOCATIF RESIDENCE de TOURISME en ZONE RURALE------------*/
		/* TODO : à reprendre pour les années passées*/
		%Init_Valeur(RED_neuf RED_rehab RED_invloc_ant1 RED_invloc_ant2 RED_invloc_const1 RED_invloc_const2);
		%if &anleg.<2012 %then %do; 
			RED_neuf	=&invloc_tour_tneuf.
					*min(_7xc,&invloc_tour_mlim.*(1+(mcdvo in ('M','O'))));/*logement acquis ou achevé année n*/
			RED_rehab	=&invloc_tour_trehab.
					*min(_7xl,&invloc_tour_mlim.*(1+(mcdvo in ('M','O'))));/*logement acquis ou achevé année n*/
			%end;
		/*on ne fait pas le calcul des réductions à venir parce qu'elles influent sur les années à venir mais on pourrait*/
		/*on suppose qu'on n'a pas les deux remplies parce qu'en théorie ce n'est qu'une seule réduction avec un seul plafond*/
		RED_invloc_ant1			=&invloc_tour_tneuf.*sum(_7xp,_7xn,_7uy);
		RED_invloc_ant2			=&invloc_tour_trehab.*sum(_7xq,_7xv,_7uz);

		RED_invloc_tour_achat	=max((RED_neuf+RED_rehab)/&invloc_tour_etal.,RED_invloc_ant1+RED_invloc_ant2 );
		/*travaux village résidentiel tourisme : plus de réduction à partir de 2013 (taux nuls) */
		RED_invloc_const1=sum(	&invloc_tour_2011_tconst1.*min(&invloc_tour_mlim.*(1+(mcdvo in ('M','O'))),_depinvloctour_2011_1),
								&invloc_tour_avt2011_tconst1.*min(&invloc_tour_mlim.*(1+(mcdvo in ('M','O'))),_depinvloctour_av2011_1),
								&invloc_tour_ap2011_tconst1.*min(&invloc_tour_mlim.*(1+(mcdvo in ('M','O'))),_depinvloctour_ap2011_1));
		/*travaux résidence tourisme classée: plus de réduction à partir de 2013 (taux nuls) */
		RED_invloc_const2=sum(	&invloc_tour_2011_tconst2.*min(&invloc_tour_mlim.*(1+(mcdvo in ('M','O'))),_depinvloctour_2011_2),
								&invloc_tour_avt2011_tconst2.*min(&invloc_tour_mlim.*(1+(mcdvo in ('M','O'))),_depinvloctour_av2011_2),
								&invloc_tour_ap2011_tconst2.*min(&invloc_tour_mlim.*(1+(mcdvo in ('M','O'))),_depinvloctour_ap2011_2));

		RED_invloc_tour=RED_invloc_tour_achat+RED_invloc_const1+RED_invloc_const2;
		label RED_invloc_tour="Investissements locatifs dans le secteur touristique";


		/*TRAVAUX DE RESTAURATION DE MONUMENTS HISTORIQUES--------------------*/
		RED_monument=&monument_t_r.*min(&monument_mlim_r.,_7nz);
		label RED_monument="Travaux de restauration monuments historiques";


		/*VERSEMENT SUR UN COMPTE DE CODEVELOPPEMENT--------------------------*/
		RED_codev=&codev_t_r.*min(&codev_mlim_r.,&codev_tlim_r.*RNG,_epargneCodev);
		label RED_codev="Versement sur un compte codéveloppement";


		/*DEFENSE DES FORETS CONTRE L'INCENDIE--------------------------------*/
		RED_foret_incendie=&foret_incendie_t_r.*Min(_7uc,&foret_incendie_mlim_r.);
		label RED_foret_incendie="Défense des forets contre l'incendie";


		/*INTERETS POUR PAIEMENT DIFFERE ACCORDE AUX AGRICULTEURS-------------*/
		RED_interet_agriculteur=&interet_agri_t_r.*Min(_7um,&interet_agri_mlim_r.*(1+(mcdvo in ('M','O'))));
		label RED_interet_agriculteur="interets pour paiement différé accordé aux agriculteurs";


		/*AIDE AUX CREATEURS ET REPRENEURS D'ENTREPRISE-----------------------*/
		/* Hypothèse : Le demandeur reçoit l'intégralité de sa réduction la même année (normalement versement en deux fois) */ 
		/* Dispositif qui disparait à partir de anleg 2016 */
		label RED_crea_entre="Aide aux créateurs et repreneurs d'entreprise";
		RED_crea_entre=	&crea_entr_m1.*(_nb_convention)+&crea_entr_m2.*(_nb_convention_hand); 	

		/*FRAIS DE COMPTABILITE------------------------------------------------*/
		/* Le montant minimun &comptagest_m_r. est multiplié par le nombre d'exploitation */
		RED_compta_gestion=MIN((&comptagest_t_r.*_7ff),(&comptagest_m_r.*_7fg));
		label RED_compta_gestion="Frais de comptabilité";


		/*DEPENSES MECENAT ENTREPRISE------------------------------------------*/
		/*Le plafond de 5% des revenus imposés au bénéfice réel est appliqué par précaution, mais ce n'est peut être pas nécessaire
		puisque le déclarant fait ce travail de plafonnement en amont dans une déclaration remplie par le déclarant */
		RED_mecenat=min(&mecenant_t_r.*_7us,&mecenat_tlim1_r. * chiffaff);
		label RED_mecenat="Mécénat";


		/*ACQUISITION DE BIENS CULTURELS---------------------------------------*/
		RED_biencult=&biencult_t_r.*_7uo;
		label RED_biencult="Acquisition de biens culturels";


		/*PRETS A LA CONSOMMATION----------------------------------------------*/
		RED_pret_conso=min(&interet_pret_conso_m.,(&interet_pret_conso_t.*_interet_pret_conso));
		label RED_pret_conso="Prêt à la consommation";

		/* REDUCTION EXCEPTIONNELLE (2014 sur revenus 2013) -------------------*/
		%if &anleg.=2014 %then %do;
			seuil1=&excep_lim1_r.*(1 +(mcdvo in ('M','O')))+&excep_lim3_r.*(npart-(1 +(mcdvo in ('M','O'))));
			seuil2=&excep_lim2_r.*(1 +(mcdvo in ('M','O')))+&excep_lim3_r.*(npart-(1 +(mcdvo in ('M','O'))));
			if RFR<seuil1 then RED_Excep=&excep_montmax_r.*(1 +(mcdvo in ('M','O')));
			else if RFR<seuil2 then RED_Excep=(seuil2-RFR)*(1 +(mcdvo in ('M','O'))); /* Calcul différentiel */
			/* Normalement on a seuil2-seuil1=montant max */
			drop seuil1 seuil2;
			%end;


		/*--------------------------------*/
		/*--	2.2	CREDITS D IMPOT		--*/
		/*--------------------------------*/
/*écart à la législation (non exaustif): 
- Le CICE : depuis 2015 le CICE s'étend pour les exploitants d'entreprises imposées au régime réel 
- le CIR pour les exploitants d'entreprises imposées au régime réel 
... */

		/* il y a CRED_sal_domicile un peu plus haut*/

		%let Credits_Codes_Ines=CRED_garde RED_garde CRED_vehicule CRED_pret_etud CRED_loyimpaye CRED_demenag CRED_persages
								CRED_cred_habrinc CRED_devldura_habprinc CRED_devldura_loc CRED_taxe_bail CRED_assuvie CRED_dividende 
								CRED_PFO CRED_val_etranger CRED_conge_agri CRED_direp CRED_IMPUT;
		%Init_Valeur(&Credits_Codes_Ines.);

		/*FRAIS DE GARDE------------------------------------------------------*/
		CRED_garde=&garde_t_c.*sum(	min(_7ga,&garde_mlim_c.),
									min(_7gb,&garde_mlim_c.),
									min(_7gc,&garde_mlim_c.),
									min(_7ge,0.5*&garde_mlim_c.),
									min(_7gf,0.5*&garde_mlim_c.), 
									min(_7gg,0.5*&garde_mlim_c.));
		/*MODIF ICI : on met à zéro */
		CRED_garde = 0;
		%if &anleg.<2006 %then %do; 
			RED_garde=CRED_garde;
			%end;
		label 	CRED_garde="Frais de garde des enfants de moins de 6 ans"
				RED_garde="Frais de garde des enfants de moins de 6 ans";

		/*Dépenses d'acquisition de véhicules GPL ou  pour destruction ancien vehicule*/
		CRED_vehicule=_nb_vehicpropre_simple*&vehicule_m1_c. 
					+ min(_nb_vehicpropre_destr,_nb_vehicpropre_simple)*&vehicule_m2_c. ;
		label CRED_vehicule="Acquisition de véhicules GPL ou destruction ancien véhicule";

		/*PRET ETUDIANT*/
		plaf_pret_etu=&pret_etud_mlim_c.*(1+_7vo*(&anleg.>2007)+(_7vo>0)*(&anleg.<=2007));
		CRED_pret_etud=&pret_etud_t_c.*Min(_7uk+_7td,plaf_pret_etu);
		/* MODIF ICI : tout au declar1*/
		CRED_pret_etud1 = CRED_pret_etud;
		CRED_pret_etud2 = 0;
		label CRED_pret_etud="Prêt étudiant";

		/*Loyers impayés de propriétaires*/
		CRED_loyimpaye=&loyer_impaye_t_c.*_4bf;
		label CRED_loyimpaye="Loyers impayés";

		/*déménagement à plus de 200 km*/
		CRED_demenag=&demenagement_m_c.*(_demenage_emploiVous+_demenage_emploiConj+_demenage_emploiPac1+_demenage_emploiPac2);
		label CRED_demenag="Déménagement à plus de 200km";

		/*DEPENSES D'EQUIPEMENT EN FAVEUR DE L'AIDE AUX PERSONNES */
		%Init_valeur(plaf_persages plaf_persages_7wl); 
		/* plafond commun selon configuration familiale */
		/*MODIF ICI : on enlève le plafond pour les couples et enfants et on répartit proportionnellement les cases*/
		plaf_persages=	&equip_aide_m0_c.;
		/*MODIF ICI : individualisation du CI en 2014*/
		%if &anleg.<=2015 %then %do ;
			%if &anleg.>=2013 and &anleg.<=2015 %then %do; 
				%Plafonnement_ordonne(_7wj _dep_Asc_Traction _7wl,plaf_persages); /* plafonnement des dépenses pour personnes agées ou handicapées en premier */
				plaf_persages_7wl=2*&equip_aide_m0_c. ; /* Plafond majoré pour PPRT : 
																				pas de majoration pour personnes à charge */
				_7wl_plaf = Min((_7wl-_7wl_plaf),plaf_persages_7wl) + _7wl_plaf ; /* Ajout du surplus de dépenses, plafonné par le plafond majoré */
				%end;
			%else %do ; /* Jusqu'en 2012 */
				%Plafonnement_ordonne(_7wl _7wj _dep_Asc_Traction,plaf_persages); /* Plafonnement du taux le plus favorable au moins favorable */
				%end;
			CRED_persages= &equip_aide_t1_c.*_dep_Asc_Traction_plaf /* ce paramètre est à 0 pour anleg>2013 */
						+&equip_aide_t2_c.*_7wj_plaf /* CI sur les dépenses d'équipements pour personnes âgées ou handicapées */
						+&equip_aide_t3_c.*_7wl_plaf /* CI sur les travaux de PPRT pour habitation principale */
						+&equip_aide_t3_c.*_7wr;
			%end;
		%if &anleg.>=2016 %then %do; 
		/*MODIF ICI : individualisation du CI*/
			CRED_persages1= &equip_aide_t2_c.*min(_7wj*part1,plaf_persages) /* CI sur les dépenses d'équipements pour personnes âgées ou handicapées */
						+&equip_aide_t3_c.*min(_7wl*part1,&equip_aide_m4_c.) /* CI sur les travaux de PPRT pour habitation principale */
						+&equip_aide_t3_c.*_7wr*part1; /* CI sur les travaux de PPRT pour logements données en location. 
													Plafond déjà appliqué à la case fiscale */
			CRED_persages2= &equip_aide_t2_c.*min(_7wj*part2,plaf_persages) /* CI sur les dépenses d'équipements pour personnes âgées ou handicapées */
						+&equip_aide_t3_c.*min(_7wl*part2,&equip_aide_m4_c.) /* CI sur les travaux de PPRT pour habitation principale */
						+&equip_aide_t3_c.*_7wr*part2; /* CI sur les travaux de PPRT pour logements données en location. 
													Plafond déjà appliqué à la case fiscale */
			%end;
		label CRED_persages1="Dépenses en faveur de l'aide aux personnes dans l'habitation principale";

		/*CREDIT INTERET D'EMPRUNTS POUR HABITATION PRINCIPALE */
		plaf_intemp	=&cred_habprinc_m1_c.*(1+(mcdvo in ('M','O')))
					+&cred_habprinc_m2_c.*(pchar+0.5*nbh);
		/* si invalide ds foyer */
		if (case_p='P') ! (case_f='F') ! (npchai>0) ! (nbi>0) then 
		plaf_intemp=	 &cred_habprinc_m3_c.*(1+(mcdvo in ('M','O')))
						+&cred_habprinc_m2_c.*(pchar+0.5*nbh);								
		/* On plafonne les cases de manière ordonnée : par taux et type d'investissement 
		(maximum pour le crédit à 40 % puis les autres annuitées à 20 % ; puis maximum pour l'I à 35 % la 1ere annuité puis 15 % ; 
		puis maximum pour l'I à 25 % pour la 1er annuité et 10 % pour les autres annuités */
		%plafonnement_ordonne(_7vx _1annui_lgtancien _7vz _1annui_lgtneuf _nonBBC_2010 _1annui_lgtneufnonBBC _7vt,plaf_intemp) ;
		CRED_cred_habrinc=	sum(
							&cred_habprinc_t1_c.*(_1annui_lgtancien_plaf + _7vx_plaf),/* 40 % */
							&cred_habprinc_t2_c.*_7vz_plaf, 						  /* 20 % */
							&cred_habprinc_t3_c.*_1annui_lgtneuf_plaf, 				  /* 35 % */
							&cred_habprinc_t4_c.*_nonBBC_2010_plaf, 				  /* 15 % */
							&cred_habprinc_t5_c.*_1annui_lgtneufnonBBC_plaf, 		  /* 25 % */
							&cred_habprinc_t6_c.*_7vt_plaf) ; 						  /* 10 % */
	
		label CRED_cred_habrinc="Intérêts d'emprunts pour l'acquisition ou la construction de l'habitation principale";

		/* CREDIT D'IMPOT POUR INVESTISSEMENTS FORESTIERS */
		/* Crédit créé à partir de &anleg. = 2015 mais pas de condition sur &anleg. car macro %plafonnement_ordonne met les cases à 0 
		quand le plafond est nul. Ce qui est le cas dans les paramètres avant &anleg.=2015 */
		%init_valeur(CRED_foret CRED_foret_travaux_1 CRED_foret_travaux_2 CRED_foret_contrat_1 CRED_foret_contrat_2);
		%Plafonnement_ordonne(_7ua _7ub _7up _7ut,&foret_mlim1_c.*(1+(mcdvo in ('M','O'))));/* On ordonne selon le taux et si sinistre 
		ou pas : d'abord hors sinistre car en cas de sinistre, dépenses peuvent être reportées jusqu'à 8 ans après. */
		CRED_foret_travaux_1=&foret_t1_c.*(_7up_plaf+_7ut_plaf) ; 
		CRED_foret_travaux_2=&foret_t2_c.*(_7ua_plaf+_7ub_plaf);
		%Plafonnement_ordonne(_7ui _7uq,&foret_mlim2_c.*(1+(mcdvo in ('M','O'))));
		CRED_foret_contrat_1=&foret_t1_c.*_7uq_plaf ; 
		CRED_foret_contrat_2=&foret_t2_c.*_7ui_plaf ; 

		CRED_foret=CRED_foret_travaux_1+CRED_foret_travaux_2+CRED_foret_contrat_1+CRED_foret_contrat_2;
		label CRED_foret="Investissement forestier";

		/*MODIF ICI : individualisation du CI*/
		%init_valeur(CRED_foret1 CRED_foret_travaux_11 CRED_foret_travaux_21 CRED_foret_contrat_11 CRED_foret_contrat_21);
		%init_valeur(CRED_foret2 CRED_foret_travaux_12 CRED_foret_travaux_22 CRED_foret_contrat_12 CRED_foret_contrat_22);
		_7ua1 = _7ua*part1;
		_7ub1 = _7ub*part1;
		_7up1 = _7up*part1;
		_7ut1 = _7ut*part1;
		_7ui1 = _7ui*part1;
		_7uq1 = _7uq*part1;

		_7ua2 = _7ua*part2;
		_7ub2 = _7ub*part2;
		_7up2 = _7up*part2;
		_7ut2 = _7ut*part2;
		_7ui2 = _7ui*part2;
		_7uq2 = _7uq*part2;

		%Plafonnement_ordonne(_7ua1 _7ub1 _7up1 _7ut1,&foret_mlim1_c.);
		CRED_foret_travaux_11=&foret_t1_c.*(_7up1_plaf+_7ut1_plaf); 
		CRED_foret_travaux_21=&foret_t2_c.*(_7ua1_plaf+_7ub1_plaf);
		%Plafonnement_ordonne(_7ui1 _7uq1,&foret_mlim2_c.);
		CRED_foret_contrat_11=&foret_t1_c.*_7uq1_plaf; 
		CRED_foret_contrat_21=&foret_t2_c.*_7ui1_plaf; 
		
		%Plafonnement_ordonne(_7ua2 _7ub2 _7up2 _7ut2,&foret_mlim1_c.);
		CRED_foret_travaux_12=&foret_t1_c.*(_7up2_plaf+_7ut2_plaf); 
		CRED_foret_travaux_22=&foret_t2_c.*(_7ua2_plaf+_7ub2_plaf);
		%Plafonnement_ordonne(_7ui2 _7uq2,&foret_mlim2_c.);
		CRED_foret_contrat_12=&foret_t1_c.*_7uq2_plaf; 
		CRED_foret_contrat_22=&foret_t2_c.*_7ui2_plaf; 

		CRED_foret1=CRED_foret_travaux_11+CRED_foret_travaux_21+CRED_foret_contrat_11+CRED_foret_contrat_21;
		CRED_foret2=CRED_foret_travaux_12+CRED_foret_travaux_22+CRED_foret_contrat_12+CRED_foret_contrat_22;
		label CRED_foret1="Investissement forestier";
		
		/*DEPENSES D'EQUIPEMENT DEVELOPPEMENT DURABLE POUR L'HABITATION PRINCIPALE*/
		/*Ecart par rapport à la législation: on ne prend pas en compte les spécificités relatives au crédit à taux zéro*/

		%if &anleg.>1998 %then %do;
			/* fonctionne avant et après la législation 2013 */
			plaf_cige=	&devldura_habprinc_mlim.*(1 + (mcdvo in ('M','O')))
						+&devldura_mlim2.*(pchar+0.5*nbh);

			/* Le système de gammes d'habitation n'a plus de sens pour anleg>=2016 puisque les taux sont harmonisés;
				on le conserve cependant pour faciliter le traitement de tous les anleg
				La seule conséquence est que cela donne l'ordre de priorité pour les plafonnements. */
			%let gamme1_hab=_7aa _7an _7aq _7am;
			%let gamme2_hab=_7af _7ah _7ak _7al _7av _7bd;
			%let gamme3_hab=_7ar _7ax _7az;
			%let gamme4_hab=_7ay _7bb _7bc;
			%let gamme6_hab=_7ad;
			%let gamme0_hab=_7be _7bf /* Apparus à partir de anleg 2015 */ _7cb /* Apparu à partir de anleg 2017 */;

			/*  on crée cases_cred_hab qui va nous permettre de caractériser l'existence ou non d'un bouquet 
			de travaux pour les années où nous ne disposons pas de l'information dans l'ERFS : on est donc
			contraints de faire une condition sur anref dans la partie aval du modèle : l'imputation est en effet
			trop complexe pour être réalisée dans init_foyer */
			%let cases_cred_hab=&gamme0_hab. &gamme1_hab. &gamme2_hab. &gamme3_hab. &gamme4_hab. &gamme6_hab.;
			%init_valeur(nb_trav_devldura);
			%do j=1 %to %sysfunc(countw(&cases_cred_hab.));
				nb_trav_devldura=nb_trav_devldura+(%scan(&cases_cred_hab.,&j.)>0);
				%end;
			%if &anref.>2013 %then %do; _bouquet_travaux=(nb_trav_devldura>1); %end;
			%if &anleg.>=2016 %then %do; _bouquet_travaux=1; %end; /* A partir de 2016, toutes les dépenses déclarées bénéficient du taux plein.
			De plus, pour les revenus 2015 les dépenses anciennes ne sont déclarées que si elles font partie d'un bouquet de travaux,
			et plus de distinction entre dépenses anciennes et dépenses N-1 à partir des revenus 2016*/

			/* Choix pour l'appréciation du plafond : 	on garde les dépenses liées aux travaux ouvrant droit au CI au taux le plus élevé
														on plafonne celles pour lesquelles le taux est le plus faible */
			%Plafonnement_ordonne(&gamme4_hab. &gamme3_hab. &gamme0_hab. &gamme6_hab. &gamme2_hab. &gamme1_hab.,plaf_cige);

			/* 1 : Taux réduit hors bouquet de travaux. Immeuble collectif ou maison individuelle, dépenses en 2012 ou antérieures
				Les cas particuliers  sont traités plus bas	car il y a  des conditions pour avoir droit au CI ( minimum de travaux engagés, habitation collective/individuelle)  */
			if _bouquet_travaux=0 then
				CRED_devldura_habprinc=sum( &devldura_t1.*_7aa_plaf,
											&devldura_t2.*sum(_7af_plaf,_7al_plaf,_7bd_plaf,_7av_plaf),
											&devldura_t3.*sum(_7ar_plaf,_7az_plaf,_7ax_plaf),
											&devldura_t4.*sum(_7bb_plaf,_7bc_plaf,_7ay_plaf),
											&devldura_t6.*_7ad_plaf);

			/* 2 : Taux fort : bouquet de travaux. Immeuble collectif ou maison individuelle, dépenses en 2012 ou antérieures
					Certaines dépenses ne bénéficient pas d'un taux fort en cas de bouquet de travaux, elles sont tout de mêm traitées ici
					Idem : cas particuliers traités plus bas */

			else if _bouquet_travaux>0 then
				CRED_devldura_habprinc=sum( &devldura_bouq_t1.*_7aa_plaf,
											&devldura_bouq_t2.*_7av_plaf+&devldura_t2.*sum(_7af_plaf,_7al_plaf,_7bd_plaf),
											&devldura_bouq_t3.*sum(_7ar_plaf,_7az_plaf,_7ax_plaf),
											&devldura_bouq_t4.*sum(_7bb_plaf,_7ay_plaf)+&devldura_t4.*_7bc_plaf,
											&devldura_bouq_t6.*_7ad_plaf,
											&devldura_bouq_t1.*_7am_plaf, /*Traité différemment (selon maison individuelle...) et séparément 7wt/7wu vs. 7sj/7rj jusqu'à la màj leg 2017*/
											&devldura_bouq_t2.*_7an_plaf, /*Traité différemment (selon maison individuelle...), cases 7sk/7rk jusqu'à la màj leg 2017*/
											&devldura_bouq_t1.*_7aq_plaf, /*Traité différemment (selon maison individuelle...), cases 7sl/7rl jusqu'à la màj leg 2017*/
											&devldura_bouq_t2.*_7ah_plaf, /*Traité différemment (selon maison individuelle...) et séparément 7wc/7wb vs. 7sg/7rg jusqu'à la màj leg 2017*/
											&devldura_bouq_t2.*_7ak_plaf  /*Traité différemment (selon maison individuelle...) et séparément 7vg/7vh vs. 7sh/7rh jusqu'à la màj leg 2017*/
											);

			/* 3 : Taux unique à 30% pour les dépenses à partir du 1er janvier 2015 */
				CRED_devldura_habprinc=CRED_devldura_habprinc+&devldura_txunique.*sum(_7be_plaf, _7bf_plaf, _7cb_plaf);

			/*  4 : Cas particuliers. 
				 A). Leg 2013 : Des types de dépenses ont été identifiés comme des cas particuliers pour la législation 2013 à cause d'une mesure 
				transitoire pour cette année-là, mais ce n'est plus le cas ensuite (n'est plus codé pour coller à la BP la plus récente)
				La mesure transitoire était de différencier (pour les cases SJ, SK et SL) les dépenses en fonction de
				leur date d'engagement : - avant ou après le 04/04/12 pour le bouquet de travaux pour les cases SJ, SG et SH
										 - et en plus et avant ou après le 01/01/12 pour les maisons individuelles pour les cases SJ, SK et SL 
			 Pour Ines 2013 sur ERFS 2011, cela était néanmoins codé : aller chercher le code archivé si besoin */

			/* B) Dépenses où le traitement dépend de l'ampleur des travaux (plus ou moins la moitié) et/ou du type d'habitation (collectif/individuel)  
						: cases 7wc, 7wb, 7sg, 7rg, 7vg, 7vh, 7sh, 7rh, 7wt, 7wu, 7sj, 7rj et 7sk, 7rk, 7sl, 7rl */
				/*A partir de la déclaration des revenus 2016 on n'a plus les distinctions qu'il faudrait dans les revenus pour traiter ces cas, donc on 
				ne fait plus de différence on applique un taux unique (voir les commentaires commençant par "traité différemment" plus haut)*/

			/* C) Pour anleg=2015 on simule la transition où 1 taux unique succède au barème différencié à partir des dépenses de septembre : 
				- Avant septembre, le barème est différencié en fonction de action seule/bouquet, ampleur des travaux et caractère collectif ou individuel du logement
				À noter que le barème des actions seules ne s'applique que sous condition de RFR : sinon les actions seules ne sont pas éligibles au crédit
				Le RFR normalement pris en compte est le N-3 ou le N-2 par rapport à anleg ("avant dernière année avant la dépense"), nous prenons le RFR 
				à disposition en revalorisant les plafonds de la revalorisation opérée entre N-3 et N-2 dans la BP. 
				- À partir du 1er septembre, toutes les dépenses sont éligibles au crédit, à un taux unique de 30%, qu'elles soient ou non dans un bouquet. */
				/*A partir de la déclaration des revenus 2016 on n'a plus les distinctions qu'il faudrait dans les revenus pour traiter cette année de transition*/

	%end;

		%else %if &anleg.<=1998 %then %do;
			CRED_devldura_habprinc= 	&travo_tx. * min( &travo_lim.*(1 + (mcdvo in ('M','O')))
										+ &travo_pac1.*(pchar+0.5*nbh) , _maison_indivi+_bouquet_travaux );
			%end;

		label CRED_devldura_habprinc="Dépenses en faveur de la qualité environnementale de l'habitation principale";

		/* DEPENSES D'EQUIPEMENT DEVELOPPEMENT DURABLE POUR LES LOGEMENTS DONNES EN LOCATION */
		/* Exceptionellement ici condition sur &anref. : à partir de l'IR 2013 (ie ERFS 2012) on n'a que la case donnant le montant
		du crédit (devenue _cred_loc), alors qu'avant on avait le détail des dépenses. 
		On ne peut donc plus faire le calcul dans le détail, on prend la seule information disponible. 
		Si l'on travaille sur les ERFS>=2012 et sur des législations <2013, cela revient à faire l'hypothèse que 
		le montant du CI ne dépend pas de la législation (surestimation du CI). 
		Suppression du crédit d'impôt pour les logements donnés en location à partir de 2015 (prise en compte paramétrique) */
		%if &anref.>=2012 and &anleg.<2015 %then %do;
			CRED_devldura_loc=_cred_loc;
			%end;
		%else %if &anref.<2012  %then %do ;
			CRED_devldura_loc=min( &devldura_loc_mlim.*(1 + (mcdvo in ('M','O'))),
									sum(&devlduraloc_t1.*_dep_devldura_loc1,
										&devlduraloc_t2.*_dep_devldura_loc2,
										&devlduraloc_t3.*_dep_devldura_loc3,
										&devlduraloc_t4.*_dep_devldura_loc4));
			%end;
			%else %do;
			CRED_devldura_loc=0;
			%end;

		label CRED_devldura_loc="Dépenses en faveur de la qualité environnementale de logements donnés en location";


		/*CREDIT D'IMPOT REPRESENTATIF DE LA TAXE ADDITIONNELLE AU DROIT DE BAIL DE 2005*/
		CRED_taxe_bail=_4tq*0.025*(&anleg.>=2001);
		label CRED_taxe_bail="Taxe additionnelle au droit au bail";

		/*ASSURANCE VIE : credit d'impot pour les revenus qui ont ete soumis au prelevement liberatoire
		alors qu'ils pouvaient beneficier de l'abattement*/
		
		/*MODIF ICI : on enlève le plafond pour les couples et on répartit proportionnellement les cases*/
		if _2dh>0 then do;
			if 0<_2ch*part1<&abatassvie_plaf. then 
				CRED_assuvie1=min(_2dh*part1,&prel_lib_t2.*(&abatassvie_plaf.-_2ch*part1));
			if 0<_2ch*part2<&abatassvie_plaf. then 
				CRED_assuvie2=min(_2dh*part2,&prel_lib_t2.*(&abatassvie_plaf.-_2ch*part2));
			end;
		label CRED_assuvie1="Assurance-vie";

		/*CREDIT D'IMPOT DIVIDENDE, entre 2006 et 2009*/
		/*MODIF ICI : on enlève le plafond pour les couples et on répartit proportionnellement les cases*/
		CRED_dividende1=Min(&cred_dividendes_t.*(_2dc+_revPEA)*part1,&cred_dividendes_m.);
		CRED_dividende2=Min(&cred_dividendes_t.*(_2dc+_revPEA)*part2,&cred_dividendes_m.);
		label CRED_dividende1="Dividende";

		/*COTISATION SYNDICALE*/
		%Init_Valeur(CRED_syndic_vous	CRED_syndic_conj CRED_syndic_pac CRED_syndic);
		%if &anleg.>2012 %then %do; 
			if _1ak=0 & (sum(_1aj,_1tp,_1nx,_1pm,_1af, _1ag, _1as,_1al, _1am, _1az))>0 then 
				CRED_syndic_vous=&syndic_tx.*min(_7ac,&syndic_limit.*(sum(_1aj,_1tp,_1nx,_1pm,_1af, _1ag, _1as,_1al, _1am, _1az)));
			if _1bk=0 & (sum(_1bj,_1up,_1ox,_1qm,_1bf, _1bg, _1bs,_1bl, _1bm, _1bz))>0 then 
				CRED_syndic_conj=&syndic_tx.*min(_7ae,&syndic_limit.*(sum(_1bj,_1up,_1ox,_1qm,_1bf, _1bg, _1bs,_1bl, _1bm, _1bz)));
			if _1ck=0 & (sum(_1cj,_1cf, _1cg,_1cs,_1cl, _1cm,_1cz,_1dj,_1df, _1dg,_1ds,_1dz,_1dl, _1dm,_1ej,_1ef, _1eg,_1es,_1el,_1em,_1fj,_1ff, _1fg,_1fs, _1fl, _1fm)) >0 
			then CRED_syndic_pac=&syndic_tx.*min(_7ag,&syndic_limit.*(sum(_1cj,_1cf, _1cg,_1cs,_1cl, _1cm,_1cz,_1dj,_1df, _1dg,_1ds,_1dz,_1dl, _1dm,_1ej,_1ef, _1eg,_1es,_1el,_1em,_1fj,_1ff, _1fg,_1fs, _1fl, _1fm))); 

			CRED_syndic=sum(CRED_syndic_vous,CRED_syndic_conj,CRED_syndic_pac);
			label CRED_syndic="Cotisations syndicales des salariés et pensionnés";
		%end;

		/* PRELEVEMENT FORFAITAIRE VERSE L'ANNEE PRECEDENTE */
		%Init_Valeur(CRED_PFO);
		%if &anref.>=2013 and &anleg.>=2014 %then %do;
			CRED_PFO=_2ck;
			%end;
		%else %if &anleg.>=2014 %then %do;
			CRED_PFO=sum(PF_Obligatoire); /* correspond à ce qui a été versé l'année précédente */
			%end;
		label CRED_PFO="CI : prélèvement forfaitaire non libératoire effectué l'année précédente";

		/*--------------------------------------------------------------------------*/
		/*--	2.3	IMPUTATION DE CREDITS D IMPOT ET AVOIR FISCAL				 -- */
		/*--------------------------------------------------------------------------*/

		CRED_IMPUT=sum(0,					/*credit d'impot en faveur des entreprises*/
				min(_8te,&max_8te.),		/* adhésion à un groupement de prévention agréé */
				_8to,_8tg,_8ts,_8tp,		/* Investissement en Corse */
				_8tb,_CIRechAnt,_8tc,		/* credit d'impot recherche*/
				_8tz, 						/* Apprentissage*/
				_8uz, 						/* Famille */
				_relocalisation*(&anleg.>=2005)*(&anleg.<=2006),
				(_8wa+_8wb)*(&anleg.>=2006),/* Agriculture biologique et prospection commerciale*/
				_8wd*(&anleg. >= 2006),		/* Formation des chefs d'entreprise */
				_8wc*(&anleg. >= 2013),		/* Prêts sans intérêt */
				_8we*(&anleg. >= 2009),		/* intéressement*/
				min(_CINouvTechn,&nouvel_techno_t.*&nouvel_techno_m.),
				_8wr, 						/* métiers d'art*/
				_8wu, 						/* Maître restaurateur*/
				_CI_debitant_tabac*(&anleg.>=2008)*(&anleg.<=2013),	/* Débitant de tabac */
				_CIFormationSalaries*(&anleg.>=2008)*(&anleg.<2011),/* Formation des salariés */
				_credFormation*(&anleg.<=2006),		
				_8th,						/* Retenue à la source élus locaux */
				_8ta,						/* Non résidents : Retenue à la source en France o */
				_8vl,						/*  Impot payé à) l'étrnager sur revenus de capitaux mobiliser et plus values*/
				_8vm,						/* Impot payé à l'étrange DEC1 */
				_8wm,						/* Impot payé à l'étrange DEC2 */
				_8um,						/* Impot payé à l'étrange PAC */
				_8uy,						/* crédit autoentrepreneur: remboursement des impôts déjà versés 
				lorsque la personne n'a plus droit au régime*/
				-_8tf);						/* Reprise de réductions ou de crédits d'impôts */

		/*crédit d'impôt remplacement pour congé des agriculteurs*/
		CRED_conge_agri=_8wt;
		label CRED_conge_agri="Remplacement pour congé des agriculteurs";

		/*credit d'impot sur valeurs étrangères (et autres crédits d'impôts non restituables jusqu'en anleg 2008) */
		CRED_val_etranger=_2ab;
		label CRED_val_etranger="Valeurs étrangères";

		/*credit d'impot "directive epargne" (et autres credits d'impots restituables à partir d'anleg 2008) */
		CRED_direp=_2bg*(&anleg.>=2006);
		label CRED_direp="Directive epargne et autres credits d'impots restituables";


/********************************************************/
/*	3	AGREGATION DES CREDITS ET REDUCTIONS D'IMPOTS	*/
/********************************************************/

		credit = sum(CRED_conge_agri,
					CRED_val_etranger,
					CRED_direp, 
					CRED_dividende,
					CRED_assuvie, 
					CRED_taxe_bail, 
					CRED_foret,
					CRED_devldura_habprinc, 
					CRED_devldura_loc,
					CRED_cred_habrinc, 
					CRED_persages, 
					CRED_demenag, 
					CRED_loyimpaye,
					CRED_pret_etud,
					CRED_vehicule,
					CRED_garde,
					CRED_sal_domicile,
					CRED_syndic,
					CRED_PFO,
					CRED_IMPUT); 
		/* MODIF ICI : on individualise le total des CI */
		/*CI répartis proportionnellement à la part dans RIB*/
		credit_part = sum(CRED_syndic,
							CRED_PFO);
		credit_ind1 = sum(CRED_persages1,
							CRED_foret1, 
							CRED_assuvie1, 
							CRED_dividende1,
							CRED_pret_etud1);
		credit_ind2 = sum(CRED_persages2,
							CRED_foret2, 
							CRED_assuvie2, 
							CRED_dividende2,
							CRED_pret_etud2);  
		credit_part1 = credit_part * part1 + credit_ind1;
		credit_part2 = credit_part * part2 + credit_ind2;
		credit0 = sum(CRED_conge_agri,
					CRED_val_etranger,
					CRED_direp, 
					CRED_taxe_bail, 
					CRED_devldura_habprinc, 
					CRED_devldura_loc,
					CRED_cred_habrinc, 
					CRED_demenag, 
					CRED_loyimpaye,
					CRED_vehicule,
					CRED_garde,
					CRED_sal_domicile,
					CRED_IMPUT); 
		/*CI répartis en 2 sauf si le déclarant 1 déclare tout*/
		credit1 = credit0/2 * (part1 ne 1) + credit0 * (part1 = 1) + credit_part1;
		credit2 = credit0/2 * (part1 ne 1) + credit_part2;

		deduc_ap_decote=sum(RED_garde,
							RED_sal_domicile,
							RED_biencult,
							RED_mecenat,
							RED_compta_gestion,
							RED_crea_entre,
							RED_interet_agriculteur,
							RED_foret_incendie,
							RED_codev,
							RED_monument,
							RED_invloc_tour,
							RED_nature,
							RED_foret,
							RED_reprise_societe,
							RED_sofipeche,
							RED_sofica,
							RED_FCPI,
							RED_FIP,
							RED_PME,
							RED_presse,
							RED_malraux,
							RED_meuble_non_prof,
							RED_duflot,
							RED_pinel_metro,
							RED_pinel_dom,
							RED_scellier,
							RED_presta_compens,
							RED_enfants_ecole,
							RED_long_sejour,
							RED_syndic,
							RED_rente_survie,
							RED_dons1,
							RED_dons2,
							RED_excep);
		/* MODIF ICI : on individualise le total des RI*/
		/*CI répartis proportionnellement à la part dans RIB*/
		deduc_ap_decote_part = sum(RED_dons1,
									RED_dons2,
									RED_rente_survie,
									RED_syndic,
									RED_FCPI,
									RED_sofica,
									RED_nature,
									RED_codev,
									RED_crea_entre,
									RED_garde);
		deduc_ap_decote_ind1 = sum(RED_PME1,
									RED_FIP1,
									RED_FCPI1,
									RED_presse1,
									RED_sofipeche1,
									RED_reprise_societe1,
									RED_foret1,
									RED_presta_compens1);
		deduc_ap_decote_ind2 = sum(RED_PME2,
									RED_FIP2,
									RED_FCPI2,
									RED_presse2,
									RED_sofipeche2,
									RED_reprise_societe2,
									RED_foret2,
									RED_presta_compens2);
		deduc_ap_decote_part1 = deduc_ap_decote_part * part1 + deduc_ap_decote_ind1;
		deduc_ap_decote_part2 = deduc_ap_decote_part * part2 + deduc_ap_decote_ind2;
		/* le reste des CI est réparti en 2 sauf si le déclarant 1 déclare tout */
		deduc_ap_decote0 = sum(RED_sal_domicile,
							RED_biencult,
							RED_mecenat,
							RED_compta_gestion,
							RED_interet_agriculteur,
							RED_foret_incendie,
							RED_monument,
							RED_invloc_tour,
							RED_malraux,
							RED_meuble_non_prof,
							RED_duflot,
							RED_pinel_metro,
							RED_pinel_dom,
							RED_scellier,
							RED_enfants_ecole,
							RED_long_sejour,
							RED_excep);
		deduc_ap_decote1 = deduc_ap_decote0/2 * (part1 ne 1) + deduc_ap_decote0 * (part1 = 1) + deduc_ap_decote_part1;
		deduc_ap_decote2 = deduc_ap_decote0/2 * (part1 ne 1) + deduc_ap_decote_part2;

		deduc_av_decote=0;

		/*On oublie les variables intermédiaires pour les calculs*/
		drop RED_syndic_vous
			RED_syndic_conj
			RED_syndic_pac
			RED_FIP_corse
			RED_FIP_dom
			RED_foret_acquis
			RED_foret_travaux
			RED_foret_contrat
			RED_neuf
			RED_rehab
			RED_invloc_ant:
			RED_invloc_tour_achat
			RED_invloc_const:
			CRED_foret_travaux_:
			CRED_foret_contrat_:
			plaf_persages
			plaf_persages_7wl ;
		run;
	%mend Deduc;

%Deduc;

/* TODO (ancien commentaire) : 
IMPOT SUR LES PLUS-VALUES A TAUX PROPORTIONNELS : LES REDUCTIONS D'IMPOT NE LUI SONT PAS IMPUTEES 
MAIS CE CALCUL EST UTILE POUR DETERMINER LES DROITS A REDUCTION D'IMPOT SUR LA PART D'EPARGNE DES PRIMES D'ASSURANCE VIE */


/****************************************************************
© Logiciel élaboré par l’État, via l’Insee et la Drees, 2016. 

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
