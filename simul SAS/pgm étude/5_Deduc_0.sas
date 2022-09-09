/****************************************************************************************/
/*																						*/
/*									5_Deduc												*/
/*																						*/
/****************************************************************************************/
/*																						*/		
/* Calcul des d�ductions d'impot							                       		*/
/* En entr�e : 	base.foyer&anr1.                 				           				*/
/* 				modele.rev_imp&anr1.													*/
/*				modele.nbpart															*/
/*				modele.Prelev_Forf&anr1. (si besoin)									*/
/* En sortie : 	modele.deduc                                      						*/
/****************************************************************************************/
/*																						*/	
/* PLAN DU PROGRAMME : 																	*/
/*	1	Constitution d'une table modele.deduc avec toutes les informations          	*/
/*      n�cessaires au calcul des CI et RI												*/	
/*	2	Calcul des diff�rents CI et RI													*/
/*		2.1	R�ductions d'imp�t															*/				
/*		2.2	Cr�dits d'imp�t																*/
/*		2.3	Imputations																	*/		
/*	3	Agr�gation des cr�dits et r�ductions d'imp�t 									*/
/*																						*/
/****************************************************************************************/
/* NOTE IMPORTANTE :  travail � faire par un courageux un jour : 
il serait bon d'harmoniser les noms des param�tres : chaque �l�ment � un nom don, sofica, etc. 
Il faut aussi pr�ciser s'il sagit d'une d�duction(=abattement), d'une r�duction ou d'un cr�dit. 
Enfin, il faut savoir si le param�tre est un montant, un taux � appliquer, ou un taux limite 
de RNG : 
On peut retenir la forme suivante : 
"nom_role_type"
le role s'�crivant m ou t si pour un montant ou un taux, �ventuellement t1 t2, etc. si on 
a besoin de plusieurs taux pour le m�me dispositifs, le type �tant d,r ou c.
Il n'y a plus qu'� le faire ! */
/****************************************************************************************/
/* Remarques : 																			*/
/*	- le cr�dit d'impot li� � la t�l�d�claration n'est pas pris en compte				*/ 
/*		(20 euros pour la permi�re declaration sur internet jusqu'en 2009) 				*/
/****************************************************************************************/

%Macro Plafonnement_ordonne(cases_ordonnees,plafond);
/* Lorsqu'un plafonnement concerne la somme de plusieurs cases, on veut parfois les plafonner 
   selon un certain ordre (traduit un comportement d'optimisation individuelle : 
   d�pense la plus grosse=celle qui donne droit au tx le plus fort
		@cases_ordonnees : liste des cases � plafonner, par ordre DECROISSANT du taux de RI auquel elles donnent lieu
		@plafond : plafond total appliqu� � la somme de toutes les cases list�es */

	/* 1 - Initialisation */
	%let vnonplaf=%scan(&cases_ordonnees.,1); 	/* nom de la case � plafonner */
	%let vplaf=&vnonplaf._plaf;					/* nom de la case plafonn�e (_plaf � la fin) */
	&vplaf.=min(&vnonplaf.,&plafond.);			/* on plafonne */
	s=0;										/* s=somme des cases d�j� trait�es */
	/* 2 - Plafonnement it�ratif */
	%do k=2 %to %sysfunc(countw(&cases_ordonnees.));
		%let vnonplaf=%scan(&cases_ordonnees.,&k.);				/* nom de la case courante � plafonner */
		%let vplaf=&vnonplaf._plaf;								/* nom de la case courante plafonn�e */
		%let vnonplaf_m1=%scan(&cases_ordonnees.,%eval(&k.-1));	/* nom de la variable non plafonn�e pr�c�dente dans la liste (sert en-dessous) */
		%let vplaf_m1=&vnonplaf_m1._plaf;						/* nom de la variable plafonn�e pr�c�dente dans la liste */
		s=s+&vplaf_m1.;											/* s=somme des cases d�j� trait�es */
		&vplaf.=max(min(&vnonplaf.,&plafond.-s),0);				/* plafonnement de la case courante */
		%end;
	drop s;
	%Mend Plafonnement_ordonne;


/**************************************************************************************************************/
/*	1	Constitution d'une table modele.deduc avec toutes les informations n�cessaires au calcul des CI et RI */
proc sql;
	create table modele.deduc as
	select c.*, d.npart from
		(select a.*, b.rng, b.rng1, b.rng2, b.rnga, b.chiffaff, b.RFR
				from base.foyer&anr1. (drop=rng) as a inner join modele.rev_imp&anr1. as b
				on a.declar=b.declar) as c inner join modele.nbpart as d
			on c.declar=d.declar;
	quit;

%macro Merge_PF;
	/* On ne r�cup�re l'information contenue dans Prelev_Forf&anr1. que dans le cas o� on en a besoin (pas encore la case _2ck) */
	%if	(&anleg.>=2014 and &anref.<2013) %then %do;
		data modele.deduc;
			merge modele.deduc modele.Prelev_Forf&anr1. (keep=declar PF_Obligatoire);
			by declar;
			run;
		%end;
	%mend Merge_PF;
%Merge_PF;

/*MODIF ICI : on r�cup�re les variables part1 part2 anaisenf et on cr�e la variable pres_enf*/
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
/*	2	Calcul des diff�rents CI et RI */
%macro Deduc;

	data modele.deduc (keep=declar deduc_av_decote deduc_ap_decote deduc_ap_decote1 deduc_ap_decote2 credit credit1 credit2 RED: CRED: plaf_esd nb_trav_devldura part1 part2);
		/*MODIF ICI : ajout des variables 1 et 2 dans le keep*/
		set	modele.deduc;

		npchai=sum(nbg,nbr);
		/*MODIF ICI : on met � 0 le nombre d'enfants � charge*/ 
		nec=0;
		/*MODIF ICI : on enl�ve toutes les personnes � charges m�me les invalides (nbf: handicap�s / nbr : invalides / nbj : c�libataires majeurs / nbf : mineurs ou handicap�s */
		pchar=0; 
		/*MODIF ICI : on met � 0 le nombre d'enfants ou handicap�s � charge en garde altern�e*/
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
		/* Initialisation � z�ro de toutes les r�ductions d'imp�t que l'on codera dans Ines */
		%Init_Valeur(&Reduc_Codes_Ines.);

		/* DONS */
		/* Dons - 1 : Aide aux personnes en difficult� */
		Dons1=_7ud+_7va; /* Taux le plus avantageux, avec plafond */
		Dons1_Plaf=min(Dons1,&don_mlim_r1.);
		RED_dons1=&don_t_r1.*Dons1_Plaf;
		label RED_dons1="Dons � des organismes d'aide aux personnes en difficult�";

		/* Dons - 2 : Organismes d'int�r�t g�n�ral + r�sidu de Dons1 */
		Excedent_Dons1=Dons1-Dons1_Plaf; /* D�penses exc�dant le plafond (0 si <) : taux moins avantageux + dans la limite d'une fraction du revenu */
		Dons2=_7uf+min(_7uh,&don_mlim_r3.)+_7vc+_7xs+_7xt+_7xu+_7xw+_7xy;
		/* Plafond sp�cifique pour dons aux partis politiques
		Ecart � la l�gislation : on code uniquement le plafond au niveau du foyer, il existe �galement un plafond individuel */
		RED_dons2=&don_t_r2.*(min(Dons2+Excedent_Dons1,&don_tlim_r2.*RNG2));
		label RED_dons2="Autres dons";

		/*RENTE-SURVIE----------------------------------------------------------*/
		RED_rente_survie=&rente_t_r.*min(_7gz,(&rente_lim1_r.+&rente_lim2_r.*(nec+0.5*nbh)));
		label RED_rente_survie="Primes de rentes survie, contrats d'�pargne handicap";

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
		label RED_syndic="Cotisations syndicales des salari�s et pensionn�s";

		/*EMPLOI D UN SALARIE A DOMICILE----------------------------------------*/
		/* plafond : 12 000 + 3 000 si premi�re fois + 1 500 par pac dans la limite de 3 000 ou 20 000 si carte invalidit� */
		if _7dg=0 then
			plaf_esd=	&saldom_lim1_r.+
						&saldom_lim2_r.*max(((aged>65)+(agec>65)+nec+0.5*nbh+_7dl*(&anleg>2005)),2)+
						(&saldom_lim4_r.-&saldom_lim1_r.)*_7dq;
		else plaf_esd=&saldom_lim3_r.;
		/* MODIF ICI : ajout de * (1-pres_enf)*/
		RED_sal_domicile=&saldom_t_r.*min(sum(_7df,_7dd),plaf_esd)*(1-pres_enf); 
		CRED_sal_domicile=&saldom_t_r.*min(_7db,plaf_esd)*(1-pres_enf); 

		/*REDuction actuelle, anciennement cr�dit*/
		%if &anleg.<2007 %then %do; 
			RED_sal_domicile=RED_sal_domicile+CRED_sal_domicile; 
			CRED_sal_domicile=0; 
			%end; 
		label 	RED_sal_domicile="Emploi d'un salari� � domicile"
				CRED_sal_domicile="Emploi d'un salari� � domicile";

		/*HEBERGEMENT LONG SEJOUR ou plus r�cemment accueil dans un �tablissement pour personne d�pendante */
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
		label RED_long_sejour="D�penses d'accueil dans un �tablissement pour personnes d�pendantes";

		/*ENFANTS SCOLARISES--------------------------------------------------*/
		RED_secondaire   =(_7ea+0.5*_7eb)*&scol_m1_r.+(_7ec+0.5*_7ed)*&scol_m2_r.;
		RED_superieur    =(_7ef+0.5*_7eg)*&scol_m3_r.;
		RED_enfants_ecole=RED_secondaire+RED_superieur;
		/*MODIF ICI : on met � z�ro*/
		RED_enfants_ecole = 0;
		label RED_enfants_ecole="Enfants � charge poursuivant leurs �tudes";


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
		/*On ne peut pas simuler les ann�es pr�c�dentes de l�gislation car les montants de la base de la r�duction d'imp�t n'ont pas �t� conserv�s
		dans des variables explicites*/
		%IF &anleg. = 2017 %THEN %DO; 

			%Plafonnement_ordonne (_7gi _7el _7gh _7ek, &duflot_mlim.); 
			/*on prend ce qui avantage le plus le foyer, avec le taux le plus �lev�, donc en 1er la case pour les DOM ici
			cf. exemple 1 � 4 paragraphe 250 et 260 de http://bofip.impots.gouv.fr/bofip/8505-PGP.html?identifiant=BOI-IR-RICI-360-30-10-20150611*/
			RED_duflot=sum(&duflot_tx_metro.*(_7gh_plaf + _7ek_plaf),&duflot_tx_dom.*(_7gi_plaf + _7el_plaf))/9;
			
			/*On ajoute les reports des ann�es pr�c�dentes*/
			RED_duflot=sum(RED_duflot, _7fi, _7fk, _7fr);
			%END;

		label RED_Duflot="Investissement locatif neuf : loi Duflot";

		/* INVESTISSEMENT LOCATIF PINEL */
		/* NON-CODE faute d'information : plafonnement � 5500 euros par m� 
						(ou 95 % montant souscription SCPI) en plus du plafond global � 300 000 � */
		%IF &anleg. = 2015 %THEN %DO; 
			/*L�gislation 2015 : la r�duction d'imp�t s'applique aux investissements N-1 r�alis�s de septembre � d�cembre*/
			_7qi_apSept = _7qi*4/12;
			_7qj_apSept = _7qj*4/12;
			_7qk_apSept = _7qk*4/12;
			_7ql_apSept = _7ql*4/12;

			%Plafonnement_ordonne (_7qi_apSept _7qj_apSept _7qk_apSept _7ql_apSept, &pinel_mlim.); 
			/*on prend ce qui avantage le plus le foyer, avec le taux le plus �lev� 
			cf. exemple 1 � 4 paragraphe 250 et 260 de http://bofip.impots.gouv.fr/bofip/8505-PGP.html?identifiant=BOI-IR-RICI-360-30-10-20150611*/
			/* La r�duction porte au maximun sur deux logements par ann�e d'investissement. Pour �tre parcimonieux, on consid�re que cette r�gle 
				de d�claration est bien respect�e et on ne v�rifie pas que les contribuables remplissent bien 2 cases maximum sur 4
				(ce qui ne serait en plus qu'une condition n�cessaire car une seule case remplie pourrait correspondre � plusieurs logements acquis) */ 	
	 		
			/* On distingue la r�duction sur les investissements dans les DOM de celle en France m�tro 
			car la RI pour les DOM b�n�ficie du plafond major� des avantages fiscaux globaux � partir de la l�gislation 2016  */
			RED_pinel_metro = SUM(&pinel_tx_metro6ans.*_7qi_apSept_plaf/6, 
								  &pinel_tx_metro9ans.*_7qj_apSept_plaf/9);
			RED_pinel_dom = SUM(&pinel_tx_dom6ans.*_7qk_apSept_plaf/6,
								&pinel_tx_dom9ans.*_7ql_apSept_plaf/9);
			%END;
		
		%ELSE %IF &anleg. = 2016 %THEN %DO;
			/*L�gislation 2016 : la r�duction d'imp�t s'applique aux investissements N-1 + les investissements N-2 r�alis�s de septembre � d�cembre*/
			_7qe_apSept = _7qe*4/12;
			_7qf_apSept = _7qf*4/12;
			_7qg_apSept = _7qg*4/12;
			_7qh_apSept = _7qh*4/12;

			%Plafonnement_ordonne (_7qi _7qe_apSept _7qj _7qf_apSept _7qk _7qg_apSept _7ql _7qh_apSept, &pinel_mlim.); 

			RED_pinel_metro = SUM(&pinel_tx_metro6ans.*(_7qi_plaf+_7qe_apSept_plaf)/6, 
								  &pinel_tx_metro9ans.*(_7qj_plaf+_7qf_apSept_plaf)/9);
			RED_pinel_dom = SUM(&pinel_tx_dom6ans.*(_7qk_plaf+_7qg_apSept_plaf)/6,
								&pinel_tx_dom9ans.*(_7ql_plaf+_7qh_apSept_plaf)/9);

			/*La r�duction d'imp�t est r�partie sur six ou neuf ann�es � raison du sixi�me ou du neuvi�me de son montant chaque ann�e 
			selon la dur�e d'engagement de location -> https://www3.impots.gouv.fr/simulateur/calcul_impot/2017/aides/reductions.htm (voir aussi
			http://bofip.impots.gouv.fr/bofip/8425-PGP.html). Donc on rajoute aussi les reports des ann�es pr�c�dentes*/
			RED_pinel_metro=RED_pinel_metro+sum(_7bz, _7cz);
			RED_pinel_dom=RED_pinel_dom+sum(_7dz, _7ez);
			%END;

		%ELSE %IF &anleg. = 2017 %THEN %DO;
			/*L�gislation 2017 : la r�duction d'imp�t s'applique aux investissements N-1, N-2, + les investissements N-3 r�alis�s de septembre � d�cembre
				(qui sont dans les cases 7qa � 7qd, pas besoin de multiplier par 4/12 ici)*/

			%Plafonnement_ordonne (_7qi _7qe _7qa _7qj _7qf _7qb _7qk _7qg _7qc _7ql _7qh _7qd, &pinel_mlim.); 

			RED_pinel_metro = SUM(&pinel_tx_metro6ans.*(_7qi_plaf+_7qe_plaf+_7qa_plaf)/6, 
								  &pinel_tx_metro9ans.*(_7qj_plaf+_7qf_plaf+_7qb_plaf)/9);
			RED_pinel_dom = SUM(&pinel_tx_dom6ans.*(_7qk_plaf+_7qg_plaf+_7qc_plaf)/6,
								&pinel_tx_dom9ans.*(_7ql_plaf+_7qh_plaf+_7qd_plaf)/9);

			/*Ajout des reports des ann�es pr�c�dentes*/
			RED_pinel_metro=RED_pinel_metro+sum(_7bz, _7cz, _7ai, _7bi);
			RED_pinel_dom=RED_pinel_dom+sum(_7dz, _7ez, _7ci, _7di);
			%END;

		label RED_pinel_metro="Investissement locatif neuf en France m�tropolitaine : loi Pinel";
		label RED_pinel_dom="Investissement locatif neuf dans les DOM : loi Pinel";

		/* INVESTISSEMENT LOCATIF SCELLIER */
		/* On n�glige les investissements Scellier dans les DOM */
		/* Ecart � la l�gislation : on n'�crit pas d'ann�es dans le code mais qu'on fait tout en relatif (d�penses de N-1 ou N-2 et non en 2011/2012...) */
		/* A reprendre si l'on souhaite �tudier cette r�duction d'imp�t dans le d�tail */
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

		/* Investissement location meubl�e non professionnelle (Censi-Bouvard) */
		/* TODO : retravailler la l�gislation 2011 qui est plus complexe */
		/* Dans l'id�al il faudrait adapter le code pour faire varier les taux en fonction de anleg : par exemple, en anleg 2017 
		le taux avant 2010 doit s�appliquer aux investissements N-7 (c'est ce qui est cod� ci-dessous), mais en anleg 2016 le taux avant 2010 
		devrait d�appliquer aux investissements N-7 et aussi N-6.*/
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
		label RED_meuble_non_prof="Investissement location meubl�e non professionnelle";


		/*TRAVAUX DE RESTAURATION "MALRAUX"--------------------------------------------*/
		RED_malraux=sum(	&malraux_ap2011_t1.*min(&malraux_mlim.,_7re+_7sx+_7ny),
							&malraux_ap2011_t2.*min(&malraux_mlim.,_7rf+_7sy+_7nx));
		label RED_malraux="Travaux de restauration immobili�re";


		/*SOUSCRIPTION D IMPOT AU CAPITAL DE PME NON COTEES ou DE PETITES ENTREPRISES EN PHASE D'EXPANSION --------*/
		/* le plafond le plus �lev� s'applique � l'ensemble des versements, sachant que les souscriptions au capital de PME avant 2012 sont aussi plafonn�es avec une limite plus faible */ 
		/*MODIF ICI : on enl�ve le plafond pour les couples et on r�partit proportionnellement les cases*/
		sousc_pme1=	 min((min((_7cu +_7cl+_7cm+_7cn+_7cc)*part1, /* PME non cot�es */
							&pme_lim1_r.))+_7cf*part1*(&anleg.>=2010)+(_7cq+_7cr+_7cv)*part1*(&anleg.>=2014),&pme_lim2_r.);
		sousc_pme2=	 min((min((_7cu +_7cl+_7cm+_7cn+_7cc)*part2, /* PME non cot�es */
							&pme_lim1_r.))+_7cf*part2*(&anleg.>=2010)+(_7cq+_7cr+_7cv)*part2*(&anleg.>=2014),&pme_lim2_r.); 
							/* PE en expansion : pas de RI sur les souscription au capital des start-up jusqu'� anleg 2009 et pas de reports de ce type de d�penses avant anleg 2014 */
		/* Ecart � la l�gislation : pour les cases correspondant � des reports de versements effectu�s avant 2012, 
		le taux de RI n'est pas le m�me mais on applique un taux unique */
		/*MODIF ICI : suite de RED_PME*/
		RED_PME1=&pme_t_r.*sousc_pme1;
		RED_PME2=&pme_t_r.*sousc_pme2;
		label RED_PME1="Souscription au capital de PME en phase d'amor�age ou non c�t�es";


		/*SOUSCRIPTIONS PARTS FCP INNOVATION, FIP et FIP en Corse-----------------------*/
		/*MODIF ICI : on enl�ve le plafond pour les couples et on r�partit proportionnellement les cases*/
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
		label RED_FIP1="Souscription de parts de fonds d'investissement de proximit�";

		/* SOUSCRIPTION AU CAPITAL D'ENTREPRISES DE PRESSE */
		/* Dispositif apparaissant en 2016 */
		/* Le plafond s'applique � des d�penses b�n�ficiant de 2 taux diff�rents, donc on maximise les d�penses b�n�ficiant du taux le plus avantageux 
		(entreprises ayant le statut d'entreprise solidaire de presse d'information) */
		/*MODIF ICI : on enl�ve le plafond pour les couples et on r�partit proportionnellement les cases*/
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
		/*Pour l'appr�ciation du plafond, les souscriptions d�clar�es case GN sont retenues en priorit�*/
		_7gn_plaf=Min(_7gn,Min(&sofica_tlim.*RNG,&sofica_mlim.)); 
		_7fn_plaf=Min(_7fn,Min(&sofica_tlim.*RNG,&sofica_mlim.)-_7gn_plaf);
		RED_sofica=(&sofica_t1.*_7fn_plaf+&sofica_t2.*_7gn_plaf)*(&anleg.>2006);
		label RED_sofica="Souscription au capital de SOFICA";


		/*SOUSCRIPTION AU CAPITAL DE sofip�che----------------------------------------------*/
		/*MODIF ICI : on enl�ve le plafond pour les couples et on r�partit proportionnellement les cases*/
		RED_sofipeche1=&sofipeche_t_r.*min(_souscSofipeche*part1,&sofipeche_tlim_r.*RNG*part1,&sofipeche_mlim_r.);
		RED_sofipeche2=&sofipeche_t_r.*min(_souscSofipeche*part2,&sofipeche_tlim_r.*RNG*part2,&sofipeche_mlim_r.);
		label RED_sofipeche1="Souscription au capital de SOFIPECHE";


		/*INTERETS D'EMPRUNTS POUR REPRISE DE SOCIETE---------------------------*/
		/*MODIF ICI : on enl�ve le plafond pour les couples et on r�partit proportionnellement les cases*/
		RED_reprise_societe1=&reprise_t_r.*Min(_7fh*part1,&reprise_mlim_r.);
		RED_reprise_societe2=&reprise_t_r.*Min(_7fh*part2,&reprise_mlim_r.);
		label RED_reprise_societe1="Inter�t d'emprunts pour reprise de soci�t�";

		/*INVESTISSEMENT DOM-TOM---------------------------------------------*/
		/* Cette RI �tait auparavant cod�e dans Ines mais de fa�on tr�s imparfaite. 
		Etant donn�e la complexit� importante et croissante de la brochure fiscale sur ce point, et le peu d'observations concern�es 
		(une trentaine pour l'ERFS 2012), on d�cide pendant la campagne 2016 de renoncer � vouloir coder ce dispositif. */

		/*INVESTISSEMENTS FORESTIERS--------------------------------------------*/
		/* Ecart � la l�gislation : on ne code pas les r�ductions d'imp�ts calcul�es sur les d�penses d'assurance et les d�penses de travaux des ann�es pr�c�dentes report�es. 
		Pourrait �ventuellement �tre fait mais trop peu d'observations et montants faibles voire nuls pour de nombreuses cases � mobiliser. 
		De plus, manque d'information sur la taille des exploitations foresti�res assur�es : plafond par hectare assur� pour les d�penses d'assurance, en plus du plafond global. */
		/*MODIF ICI : on enl�ve le plafond pour les couples et on r�partit proportionnellement les cases*/
		RED_foret_acquis1 =&foret_t_r.*Min(_7un*part1,&foret_mlim1_r.);
		RED_foret_acquis2 =&foret_t_r.*Min(_7un*part2,&foret_mlim1_r.);
		RED_foret1=RED_foret_acquis1;
		RED_foret2=RED_foret_acquis2;
		label RED_foret1="Investissement forestier";


		/*PROTECTION DU PATRIMOINE NATUREL--------------------------------------*/
		/* Report des d�penses des ann�es pass�es non cod� */ 
		RED_nature=&nature_t_r.*min(_protect_patnat,&nature_mlim_r.);
		label RED_nature="Protection du patrimoine naturel";


		/*INVESTISSEMENT LOCATIF RESIDENCE de TOURISME en ZONE RURALE------------*/
		/* TODO : � reprendre pour les ann�es pass�es*/
		%Init_Valeur(RED_neuf RED_rehab RED_invloc_ant1 RED_invloc_ant2 RED_invloc_const1 RED_invloc_const2);
		%if &anleg.<2012 %then %do; 
			RED_neuf	=&invloc_tour_tneuf.
					*min(_7xc,&invloc_tour_mlim.*(1+(mcdvo in ('M','O'))));/*logement acquis ou achev� ann�e n*/
			RED_rehab	=&invloc_tour_trehab.
					*min(_7xl,&invloc_tour_mlim.*(1+(mcdvo in ('M','O'))));/*logement acquis ou achev� ann�e n*/
			%end;
		/*on ne fait pas le calcul des r�ductions � venir parce qu'elles influent sur les ann�es � venir mais on pourrait*/
		/*on suppose qu'on n'a pas les deux remplies parce qu'en th�orie ce n'est qu'une seule r�duction avec un seul plafond*/
		RED_invloc_ant1			=&invloc_tour_tneuf.*sum(_7xp,_7xn,_7uy);
		RED_invloc_ant2			=&invloc_tour_trehab.*sum(_7xq,_7xv,_7uz);

		RED_invloc_tour_achat	=max((RED_neuf+RED_rehab)/&invloc_tour_etal.,RED_invloc_ant1+RED_invloc_ant2 );
		/*travaux village r�sidentiel tourisme : plus de r�duction � partir de 2013 (taux nuls) */
		RED_invloc_const1=sum(	&invloc_tour_2011_tconst1.*min(&invloc_tour_mlim.*(1+(mcdvo in ('M','O'))),_depinvloctour_2011_1),
								&invloc_tour_avt2011_tconst1.*min(&invloc_tour_mlim.*(1+(mcdvo in ('M','O'))),_depinvloctour_av2011_1),
								&invloc_tour_ap2011_tconst1.*min(&invloc_tour_mlim.*(1+(mcdvo in ('M','O'))),_depinvloctour_ap2011_1));
		/*travaux r�sidence tourisme class�e: plus de r�duction � partir de 2013 (taux nuls) */
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
		label RED_codev="Versement sur un compte cod�veloppement";


		/*DEFENSE DES FORETS CONTRE L'INCENDIE--------------------------------*/
		RED_foret_incendie=&foret_incendie_t_r.*Min(_7uc,&foret_incendie_mlim_r.);
		label RED_foret_incendie="D�fense des forets contre l'incendie";


		/*INTERETS POUR PAIEMENT DIFFERE ACCORDE AUX AGRICULTEURS-------------*/
		RED_interet_agriculteur=&interet_agri_t_r.*Min(_7um,&interet_agri_mlim_r.*(1+(mcdvo in ('M','O'))));
		label RED_interet_agriculteur="interets pour paiement diff�r� accord� aux agriculteurs";


		/*AIDE AUX CREATEURS ET REPRENEURS D'ENTREPRISE-----------------------*/
		/* Hypoth�se : Le demandeur re�oit l'int�gralit� de sa r�duction la m�me ann�e (normalement versement en deux fois) */ 
		/* Dispositif qui disparait � partir de anleg 2016 */
		label RED_crea_entre="Aide aux cr�ateurs et repreneurs d'entreprise";
		RED_crea_entre=	&crea_entr_m1.*(_nb_convention)+&crea_entr_m2.*(_nb_convention_hand); 	

		/*FRAIS DE COMPTABILITE------------------------------------------------*/
		/* Le montant minimun &comptagest_m_r. est multipli� par le nombre d'exploitation */
		RED_compta_gestion=MIN((&comptagest_t_r.*_7ff),(&comptagest_m_r.*_7fg));
		label RED_compta_gestion="Frais de comptabilit�";


		/*DEPENSES MECENAT ENTREPRISE------------------------------------------*/
		/*Le plafond de 5% des revenus impos�s au b�n�fice r�el est appliqu� par pr�caution, mais ce n'est peut �tre pas n�cessaire
		puisque le d�clarant fait ce travail de plafonnement en amont dans une d�claration remplie par le d�clarant */
		RED_mecenat=min(&mecenant_t_r.*_7us,&mecenat_tlim1_r. * chiffaff);
		label RED_mecenat="M�c�nat";


		/*ACQUISITION DE BIENS CULTURELS---------------------------------------*/
		RED_biencult=&biencult_t_r.*_7uo;
		label RED_biencult="Acquisition de biens culturels";


		/*PRETS A LA CONSOMMATION----------------------------------------------*/
		RED_pret_conso=min(&interet_pret_conso_m.,(&interet_pret_conso_t.*_interet_pret_conso));
		label RED_pret_conso="Pr�t � la consommation";

		/* REDUCTION EXCEPTIONNELLE (2014 sur revenus 2013) -------------------*/
		%if &anleg.=2014 %then %do;
			seuil1=&excep_lim1_r.*(1 +(mcdvo in ('M','O')))+&excep_lim3_r.*(npart-(1 +(mcdvo in ('M','O'))));
			seuil2=&excep_lim2_r.*(1 +(mcdvo in ('M','O')))+&excep_lim3_r.*(npart-(1 +(mcdvo in ('M','O'))));
			if RFR<seuil1 then RED_Excep=&excep_montmax_r.*(1 +(mcdvo in ('M','O')));
			else if RFR<seuil2 then RED_Excep=(seuil2-RFR)*(1 +(mcdvo in ('M','O'))); /* Calcul diff�rentiel */
			/* Normalement on a seuil2-seuil1=montant max */
			drop seuil1 seuil2;
			%end;


		/*--------------------------------*/
		/*--	2.2	CREDITS D IMPOT		--*/
		/*--------------------------------*/
/*�cart � la l�gislation (non exaustif): 
- Le CICE : depuis 2015 le CICE s'�tend pour les exploitants d'entreprises impos�es au r�gime r�el 
- le CIR pour les exploitants d'entreprises impos�es au r�gime r�el 
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
		/*MODIF ICI : on met � z�ro */
		CRED_garde = 0;
		%if &anleg.<2006 %then %do; 
			RED_garde=CRED_garde;
			%end;
		label 	CRED_garde="Frais de garde des enfants de moins de 6 ans"
				RED_garde="Frais de garde des enfants de moins de 6 ans";

		/*D�penses d'acquisition de v�hicules GPL ou  pour destruction ancien vehicule*/
		CRED_vehicule=_nb_vehicpropre_simple*&vehicule_m1_c. 
					+ min(_nb_vehicpropre_destr,_nb_vehicpropre_simple)*&vehicule_m2_c. ;
		label CRED_vehicule="Acquisition de v�hicules GPL ou destruction ancien v�hicule";

		/*PRET ETUDIANT*/
		plaf_pret_etu=&pret_etud_mlim_c.*(1+_7vo*(&anleg.>2007)+(_7vo>0)*(&anleg.<=2007));
		CRED_pret_etud=&pret_etud_t_c.*Min(_7uk+_7td,plaf_pret_etu);
		/* MODIF ICI : tout au declar1*/
		CRED_pret_etud1 = CRED_pret_etud;
		CRED_pret_etud2 = 0;
		label CRED_pret_etud="Pr�t �tudiant";

		/*Loyers impay�s de propri�taires*/
		CRED_loyimpaye=&loyer_impaye_t_c.*_4bf;
		label CRED_loyimpaye="Loyers impay�s";

		/*d�m�nagement � plus de 200 km*/
		CRED_demenag=&demenagement_m_c.*(_demenage_emploiVous+_demenage_emploiConj+_demenage_emploiPac1+_demenage_emploiPac2);
		label CRED_demenag="D�m�nagement � plus de 200km";

		/*DEPENSES D'EQUIPEMENT EN FAVEUR DE L'AIDE AUX PERSONNES */
		%Init_valeur(plaf_persages plaf_persages_7wl); 
		/* plafond commun selon configuration familiale */
		/*MODIF ICI : on enl�ve le plafond pour les couples et enfants et on r�partit proportionnellement les cases*/
		plaf_persages=	&equip_aide_m0_c.;
		/*MODIF ICI : individualisation du CI en 2014*/
		%if &anleg.<=2015 %then %do ;
			%if &anleg.>=2013 and &anleg.<=2015 %then %do; 
				%Plafonnement_ordonne(_7wj _dep_Asc_Traction _7wl,plaf_persages); /* plafonnement des d�penses pour personnes ag�es ou handicap�es en premier */
				plaf_persages_7wl=2*&equip_aide_m0_c. ; /* Plafond major� pour PPRT : 
																				pas de majoration pour personnes � charge */
				_7wl_plaf = Min((_7wl-_7wl_plaf),plaf_persages_7wl) + _7wl_plaf ; /* Ajout du surplus de d�penses, plafonn� par le plafond major� */
				%end;
			%else %do ; /* Jusqu'en 2012 */
				%Plafonnement_ordonne(_7wl _7wj _dep_Asc_Traction,plaf_persages); /* Plafonnement du taux le plus favorable au moins favorable */
				%end;
			CRED_persages= &equip_aide_t1_c.*_dep_Asc_Traction_plaf /* ce param�tre est � 0 pour anleg>2013 */
						+&equip_aide_t2_c.*_7wj_plaf /* CI sur les d�penses d'�quipements pour personnes �g�es ou handicap�es */
						+&equip_aide_t3_c.*_7wl_plaf /* CI sur les travaux de PPRT pour habitation principale */
						+&equip_aide_t3_c.*_7wr;
			%end;
		%if &anleg.>=2016 %then %do; 
		/*MODIF ICI : individualisation du CI*/
			CRED_persages1= &equip_aide_t2_c.*min(_7wj*part1,plaf_persages) /* CI sur les d�penses d'�quipements pour personnes �g�es ou handicap�es */
						+&equip_aide_t3_c.*min(_7wl*part1,&equip_aide_m4_c.) /* CI sur les travaux de PPRT pour habitation principale */
						+&equip_aide_t3_c.*_7wr*part1; /* CI sur les travaux de PPRT pour logements donn�es en location. 
													Plafond d�j� appliqu� � la case fiscale */
			CRED_persages2= &equip_aide_t2_c.*min(_7wj*part2,plaf_persages) /* CI sur les d�penses d'�quipements pour personnes �g�es ou handicap�es */
						+&equip_aide_t3_c.*min(_7wl*part2,&equip_aide_m4_c.) /* CI sur les travaux de PPRT pour habitation principale */
						+&equip_aide_t3_c.*_7wr*part2; /* CI sur les travaux de PPRT pour logements donn�es en location. 
													Plafond d�j� appliqu� � la case fiscale */
			%end;
		label CRED_persages1="D�penses en faveur de l'aide aux personnes dans l'habitation principale";

		/*CREDIT INTERET D'EMPRUNTS POUR HABITATION PRINCIPALE */
		plaf_intemp	=&cred_habprinc_m1_c.*(1+(mcdvo in ('M','O')))
					+&cred_habprinc_m2_c.*(pchar+0.5*nbh);
		/* si invalide ds foyer */
		if (case_p='P') ! (case_f='F') ! (npchai>0) ! (nbi>0) then 
		plaf_intemp=	 &cred_habprinc_m3_c.*(1+(mcdvo in ('M','O')))
						+&cred_habprinc_m2_c.*(pchar+0.5*nbh);								
		/* On plafonne les cases de mani�re ordonn�e : par taux et type d'investissement 
		(maximum pour le cr�dit � 40 % puis les autres annuit�es � 20 % ; puis maximum pour l'I � 35 % la 1ere annuit� puis 15 % ; 
		puis maximum pour l'I � 25 % pour la 1er annuit� et 10 % pour les autres annuit�s */
		%plafonnement_ordonne(_7vx _1annui_lgtancien _7vz _1annui_lgtneuf _nonBBC_2010 _1annui_lgtneufnonBBC _7vt,plaf_intemp) ;
		CRED_cred_habrinc=	sum(
							&cred_habprinc_t1_c.*(_1annui_lgtancien_plaf + _7vx_plaf),/* 40 % */
							&cred_habprinc_t2_c.*_7vz_plaf, 						  /* 20 % */
							&cred_habprinc_t3_c.*_1annui_lgtneuf_plaf, 				  /* 35 % */
							&cred_habprinc_t4_c.*_nonBBC_2010_plaf, 				  /* 15 % */
							&cred_habprinc_t5_c.*_1annui_lgtneufnonBBC_plaf, 		  /* 25 % */
							&cred_habprinc_t6_c.*_7vt_plaf) ; 						  /* 10 % */
	
		label CRED_cred_habrinc="Int�r�ts d'emprunts pour l'acquisition ou la construction de l'habitation principale";

		/* CREDIT D'IMPOT POUR INVESTISSEMENTS FORESTIERS */
		/* Cr�dit cr�� � partir de &anleg. = 2015 mais pas de condition sur &anleg. car macro %plafonnement_ordonne met les cases � 0 
		quand le plafond est nul. Ce qui est le cas dans les param�tres avant &anleg.=2015 */
		%init_valeur(CRED_foret CRED_foret_travaux_1 CRED_foret_travaux_2 CRED_foret_contrat_1 CRED_foret_contrat_2);
		%Plafonnement_ordonne(_7ua _7ub _7up _7ut,&foret_mlim1_c.*(1+(mcdvo in ('M','O'))));/* On ordonne selon le taux et si sinistre 
		ou pas : d'abord hors sinistre car en cas de sinistre, d�penses peuvent �tre report�es jusqu'� 8 ans apr�s. */
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
		/*Ecart par rapport � la l�gislation: on ne prend pas en compte les sp�cificit�s relatives au cr�dit � taux z�ro*/

		%if &anleg.>1998 %then %do;
			/* fonctionne avant et apr�s la l�gislation 2013 */
			plaf_cige=	&devldura_habprinc_mlim.*(1 + (mcdvo in ('M','O')))
						+&devldura_mlim2.*(pchar+0.5*nbh);

			/* Le syst�me de gammes d'habitation n'a plus de sens pour anleg>=2016 puisque les taux sont harmonis�s;
				on le conserve cependant pour faciliter le traitement de tous les anleg
				La seule cons�quence est que cela donne l'ordre de priorit� pour les plafonnements. */
			%let gamme1_hab=_7aa _7an _7aq _7am;
			%let gamme2_hab=_7af _7ah _7ak _7al _7av _7bd;
			%let gamme3_hab=_7ar _7ax _7az;
			%let gamme4_hab=_7ay _7bb _7bc;
			%let gamme6_hab=_7ad;
			%let gamme0_hab=_7be _7bf /* Apparus � partir de anleg 2015 */ _7cb /* Apparu � partir de anleg 2017 */;

			/*  on cr�e cases_cred_hab qui va nous permettre de caract�riser l'existence ou non d'un bouquet 
			de travaux pour les ann�es o� nous ne disposons pas de l'information dans l'ERFS : on est donc
			contraints de faire une condition sur anref dans la partie aval du mod�le : l'imputation est en effet
			trop complexe pour �tre r�alis�e dans init_foyer */
			%let cases_cred_hab=&gamme0_hab. &gamme1_hab. &gamme2_hab. &gamme3_hab. &gamme4_hab. &gamme6_hab.;
			%init_valeur(nb_trav_devldura);
			%do j=1 %to %sysfunc(countw(&cases_cred_hab.));
				nb_trav_devldura=nb_trav_devldura+(%scan(&cases_cred_hab.,&j.)>0);
				%end;
			%if &anref.>2013 %then %do; _bouquet_travaux=(nb_trav_devldura>1); %end;
			%if &anleg.>=2016 %then %do; _bouquet_travaux=1; %end; /* A partir de 2016, toutes les d�penses d�clar�es b�n�ficient du taux plein.
			De plus, pour les revenus 2015 les d�penses anciennes ne sont d�clar�es que si elles font partie d'un bouquet de travaux,
			et plus de distinction entre d�penses anciennes et d�penses N-1 � partir des revenus 2016*/

			/* Choix pour l'appr�ciation du plafond : 	on garde les d�penses li�es aux travaux ouvrant droit au CI au taux le plus �lev�
														on plafonne celles pour lesquelles le taux est le plus faible */
			%Plafonnement_ordonne(&gamme4_hab. &gamme3_hab. &gamme0_hab. &gamme6_hab. &gamme2_hab. &gamme1_hab.,plaf_cige);

			/* 1 : Taux r�duit hors bouquet de travaux. Immeuble collectif ou maison individuelle, d�penses en 2012 ou ant�rieures
				Les cas particuliers  sont trait�s plus bas	car il y a  des conditions pour avoir droit au CI ( minimum de travaux engag�s, habitation collective/individuelle)  */
			if _bouquet_travaux=0 then
				CRED_devldura_habprinc=sum( &devldura_t1.*_7aa_plaf,
											&devldura_t2.*sum(_7af_plaf,_7al_plaf,_7bd_plaf,_7av_plaf),
											&devldura_t3.*sum(_7ar_plaf,_7az_plaf,_7ax_plaf),
											&devldura_t4.*sum(_7bb_plaf,_7bc_plaf,_7ay_plaf),
											&devldura_t6.*_7ad_plaf);

			/* 2 : Taux fort : bouquet de travaux. Immeuble collectif ou maison individuelle, d�penses en 2012 ou ant�rieures
					Certaines d�penses ne b�n�ficient pas d'un taux fort en cas de bouquet de travaux, elles sont tout de m�m trait�es ici
					Idem : cas particuliers trait�s plus bas */

			else if _bouquet_travaux>0 then
				CRED_devldura_habprinc=sum( &devldura_bouq_t1.*_7aa_plaf,
											&devldura_bouq_t2.*_7av_plaf+&devldura_t2.*sum(_7af_plaf,_7al_plaf,_7bd_plaf),
											&devldura_bouq_t3.*sum(_7ar_plaf,_7az_plaf,_7ax_plaf),
											&devldura_bouq_t4.*sum(_7bb_plaf,_7ay_plaf)+&devldura_t4.*_7bc_plaf,
											&devldura_bouq_t6.*_7ad_plaf,
											&devldura_bouq_t1.*_7am_plaf, /*Trait� diff�remment (selon maison individuelle...) et s�par�ment 7wt/7wu vs. 7sj/7rj jusqu'� la m�j leg 2017*/
											&devldura_bouq_t2.*_7an_plaf, /*Trait� diff�remment (selon maison individuelle...), cases 7sk/7rk jusqu'� la m�j leg 2017*/
											&devldura_bouq_t1.*_7aq_plaf, /*Trait� diff�remment (selon maison individuelle...), cases 7sl/7rl jusqu'� la m�j leg 2017*/
											&devldura_bouq_t2.*_7ah_plaf, /*Trait� diff�remment (selon maison individuelle...) et s�par�ment 7wc/7wb vs. 7sg/7rg jusqu'� la m�j leg 2017*/
											&devldura_bouq_t2.*_7ak_plaf  /*Trait� diff�remment (selon maison individuelle...) et s�par�ment 7vg/7vh vs. 7sh/7rh jusqu'� la m�j leg 2017*/
											);

			/* 3 : Taux unique � 30% pour les d�penses � partir du 1er janvier 2015 */
				CRED_devldura_habprinc=CRED_devldura_habprinc+&devldura_txunique.*sum(_7be_plaf, _7bf_plaf, _7cb_plaf);

			/*  4 : Cas particuliers. 
				 A). Leg 2013 : Des types de d�penses ont �t� identifi�s comme des cas particuliers pour la l�gislation 2013 � cause d'une mesure 
				transitoire pour cette ann�e-l�, mais ce n'est plus le cas ensuite (n'est plus cod� pour coller � la BP la plus r�cente)
				La mesure transitoire �tait de diff�rencier (pour les cases SJ, SK et SL) les d�penses en fonction de
				leur date d'engagement : - avant ou apr�s le 04/04/12 pour le bouquet de travaux pour les cases SJ, SG et SH
										 - et en plus et avant ou apr�s le 01/01/12 pour les maisons individuelles pour les cases SJ, SK et SL 
			 Pour Ines 2013 sur ERFS 2011, cela �tait n�anmoins cod� : aller chercher le code archiv� si besoin */

			/* B) D�penses o� le traitement d�pend de l'ampleur des travaux (plus ou moins la moiti�) et/ou du type d'habitation (collectif/individuel)  
						: cases 7wc, 7wb, 7sg, 7rg, 7vg, 7vh, 7sh, 7rh, 7wt, 7wu, 7sj, 7rj et 7sk, 7rk, 7sl, 7rl */
				/*A partir de la d�claration des revenus 2016 on n'a plus les distinctions qu'il faudrait dans les revenus pour traiter ces cas, donc on 
				ne fait plus de diff�rence on applique un taux unique (voir les commentaires commen�ant par "trait� diff�remment" plus haut)*/

			/* C) Pour anleg=2015 on simule la transition o� 1 taux unique succ�de au bar�me diff�renci� � partir des d�penses de septembre : 
				- Avant septembre, le bar�me est diff�renci� en fonction de action seule/bouquet, ampleur des travaux et caract�re collectif ou individuel du logement
				� noter que le bar�me des actions seules ne s'applique que sous condition de RFR : sinon les actions seules ne sont pas �ligibles au cr�dit
				Le RFR normalement pris en compte est le N-3 ou le N-2 par rapport � anleg ("avant derni�re ann�e avant la d�pense"), nous prenons le RFR 
				� disposition en revalorisant les plafonds de la revalorisation op�r�e entre N-3 et N-2 dans la BP. 
				- � partir du 1er septembre, toutes les d�penses sont �ligibles au cr�dit, � un taux unique de 30%, qu'elles soient ou non dans un bouquet. */
				/*A partir de la d�claration des revenus 2016 on n'a plus les distinctions qu'il faudrait dans les revenus pour traiter cette ann�e de transition*/

	%end;

		%else %if &anleg.<=1998 %then %do;
			CRED_devldura_habprinc= 	&travo_tx. * min( &travo_lim.*(1 + (mcdvo in ('M','O')))
										+ &travo_pac1.*(pchar+0.5*nbh) , _maison_indivi+_bouquet_travaux );
			%end;

		label CRED_devldura_habprinc="D�penses en faveur de la qualit� environnementale de l'habitation principale";

		/* DEPENSES D'EQUIPEMENT DEVELOPPEMENT DURABLE POUR LES LOGEMENTS DONNES EN LOCATION */
		/* Exceptionellement ici condition sur &anref. : � partir de l'IR 2013 (ie ERFS 2012) on n'a que la case donnant le montant
		du cr�dit (devenue _cred_loc), alors qu'avant on avait le d�tail des d�penses. 
		On ne peut donc plus faire le calcul dans le d�tail, on prend la seule information disponible. 
		Si l'on travaille sur les ERFS>=2012 et sur des l�gislations <2013, cela revient � faire l'hypoth�se que 
		le montant du CI ne d�pend pas de la l�gislation (surestimation du CI). 
		Suppression du cr�dit d'imp�t pour les logements donn�s en location � partir de 2015 (prise en compte param�trique) */
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

		label CRED_devldura_loc="D�penses en faveur de la qualit� environnementale de logements donn�s en location";


		/*CREDIT D'IMPOT REPRESENTATIF DE LA TAXE ADDITIONNELLE AU DROIT DE BAIL DE 2005*/
		CRED_taxe_bail=_4tq*0.025*(&anleg.>=2001);
		label CRED_taxe_bail="Taxe additionnelle au droit au bail";

		/*ASSURANCE VIE : credit d'impot pour les revenus qui ont ete soumis au prelevement liberatoire
		alors qu'ils pouvaient beneficier de l'abattement*/
		
		/*MODIF ICI : on enl�ve le plafond pour les couples et on r�partit proportionnellement les cases*/
		if _2dh>0 then do;
			if 0<_2ch*part1<&abatassvie_plaf. then 
				CRED_assuvie1=min(_2dh*part1,&prel_lib_t2.*(&abatassvie_plaf.-_2ch*part1));
			if 0<_2ch*part2<&abatassvie_plaf. then 
				CRED_assuvie2=min(_2dh*part2,&prel_lib_t2.*(&abatassvie_plaf.-_2ch*part2));
			end;
		label CRED_assuvie1="Assurance-vie";

		/*CREDIT D'IMPOT DIVIDENDE, entre 2006 et 2009*/
		/*MODIF ICI : on enl�ve le plafond pour les couples et on r�partit proportionnellement les cases*/
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
			label CRED_syndic="Cotisations syndicales des salari�s et pensionn�s";
		%end;

		/* PRELEVEMENT FORFAITAIRE VERSE L'ANNEE PRECEDENTE */
		%Init_Valeur(CRED_PFO);
		%if &anref.>=2013 and &anleg.>=2014 %then %do;
			CRED_PFO=_2ck;
			%end;
		%else %if &anleg.>=2014 %then %do;
			CRED_PFO=sum(PF_Obligatoire); /* correspond � ce qui a �t� vers� l'ann�e pr�c�dente */
			%end;
		label CRED_PFO="CI : pr�l�vement forfaitaire non lib�ratoire effectu� l'ann�e pr�c�dente";

		/*--------------------------------------------------------------------------*/
		/*--	2.3	IMPUTATION DE CREDITS D IMPOT ET AVOIR FISCAL				 -- */
		/*--------------------------------------------------------------------------*/

		CRED_IMPUT=sum(0,					/*credit d'impot en faveur des entreprises*/
				min(_8te,&max_8te.),		/* adh�sion � un groupement de pr�vention agr�� */
				_8to,_8tg,_8ts,_8tp,		/* Investissement en Corse */
				_8tb,_CIRechAnt,_8tc,		/* credit d'impot recherche*/
				_8tz, 						/* Apprentissage*/
				_8uz, 						/* Famille */
				_relocalisation*(&anleg.>=2005)*(&anleg.<=2006),
				(_8wa+_8wb)*(&anleg.>=2006),/* Agriculture biologique et prospection commerciale*/
				_8wd*(&anleg. >= 2006),		/* Formation des chefs d'entreprise */
				_8wc*(&anleg. >= 2013),		/* Pr�ts sans int�r�t */
				_8we*(&anleg. >= 2009),		/* int�ressement*/
				min(_CINouvTechn,&nouvel_techno_t.*&nouvel_techno_m.),
				_8wr, 						/* m�tiers d'art*/
				_8wu, 						/* Ma�tre restaurateur*/
				_CI_debitant_tabac*(&anleg.>=2008)*(&anleg.<=2013),	/* D�bitant de tabac */
				_CIFormationSalaries*(&anleg.>=2008)*(&anleg.<2011),/* Formation des salari�s */
				_credFormation*(&anleg.<=2006),		
				_8th,						/* Retenue � la source �lus locaux */
				_8ta,						/* Non r�sidents : Retenue � la source en France o */
				_8vl,						/*  Impot pay� �) l'�trnager sur revenus de capitaux mobiliser et plus values*/
				_8vm,						/* Impot pay� � l'�trange DEC1 */
				_8wm,						/* Impot pay� � l'�trange DEC2 */
				_8um,						/* Impot pay� � l'�trange PAC */
				_8uy,						/* cr�dit autoentrepreneur: remboursement des imp�ts d�j� vers�s 
				lorsque la personne n'a plus droit au r�gime*/
				-_8tf);						/* Reprise de r�ductions ou de cr�dits d'imp�ts */

		/*cr�dit d'imp�t remplacement pour cong� des agriculteurs*/
		CRED_conge_agri=_8wt;
		label CRED_conge_agri="Remplacement pour cong� des agriculteurs";

		/*credit d'impot sur valeurs �trang�res (et autres cr�dits d'imp�ts non restituables jusqu'en anleg 2008) */
		CRED_val_etranger=_2ab;
		label CRED_val_etranger="Valeurs �trang�res";

		/*credit d'impot "directive epargne" (et autres credits d'impots restituables � partir d'anleg 2008) */
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
		/*CI r�partis proportionnellement � la part dans RIB*/
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
		/*CI r�partis en 2 sauf si le d�clarant 1 d�clare tout*/
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
		/*CI r�partis proportionnellement � la part dans RIB*/
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
		/* le reste des CI est r�parti en 2 sauf si le d�clarant 1 d�clare tout */
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

		/*On oublie les variables interm�diaires pour les calculs*/
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
� Logiciel �labor� par l��tat, via l�Insee et la Drees, 2016. 

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
