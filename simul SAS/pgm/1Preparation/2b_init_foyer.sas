/************************************************/
/*          Programme 2b_init_foyer             */ 
/************************************************/

/********************************************************************************/
/* Table en entrée :															*/
/*  cd.foyer&anr._ela pour l'élargi												*/
/*	rpm.foyer&anr. pour l'échantillon classique									*/     
/*																				*/
/* Table en sortie :															*/
/*  travail.foyer&anr.															*/
/*																				*/
/* Objectif : Ce programme a vocation à uniformiser les déclarations de 		*/
/* chaque année, en prenant le modèle de la déclaration la plus récente. 		*/
/* On crée les cases qui ont existé ou qui vont exister l'année prochaine.		*/
/* Un mode d'emploi est détaillé dans le Wiki. 									*/
/*																				*/
/* PLAN																			*/
/* - Initialisation de la table FOYER											*/
/* - Initialisation des cases inutiles											*/
/* - Gestion du SIF																*/
/* - Une macro de modifications par année										*/
/* - Un appel successif à toutes les macros de modifications					*/
/********************************************************************************/

/************************************/
/* Initialisation de la table foyer */
/************************************/

%macro initialisation_table_foyer;
	data foyer&anr.(drop = sif); 
		%if &noyau_uniquement.=oui %then %do;
    		set rpm.foyer&anr.; 
			%end;
		%if &noyau_uniquement.=non %then %do;
    		set cd.foyer&anr._ela; 
			%end;
  		length sif1 $100.; 
   	 	length declar1 $79;
	    sif1=sif; 
   	 	declar1=declar;
    	/* On corrige dès maintenant un décalage qui arrive réguliérement sur le sif, ça 
   		permet de ne pas multiplier ses conséquences */
    	if substr(sif1,1,1)='' then sif1=substr(sif1,2,99);
    	drop declar;
    	rename declar1=declar;
   		run; 
	%mend;

%initialisation_table_foyer;

/*************************************/
/* Initialisation des cases inutiles */
/*************************************/

/*  La macro-variable casesInutiles permet de gérer le fait qu'une variable qui disparaît
    puis réapparaît dans le formulaire fiscal ne doit pas être droppée au moment de sa disparition
    sinon le programme génère une erreur.
    Lors de la disparition d'une case, on la met dans la liste casesInutiles. Si elle réapparaît
    ultérieurement on l'enlève de la liste.
    Une fois tous les changements de formulaire effectués on supprime les variables présentes
    dans casesInutiles (macro suppressionVariablesInutiles).
    On initialise casesInutiles par la liste des variables de l'ERFS qui sont inutiles pour Ines.
    */
%let casesInutiles=idec&anr anrev enffjn ;

/******************/
/* Gestion du SIF */
/******************/

%macro GererSIF;

	/*	IMPORTANT : la définition du SIF doit être stable selon le millésime utilisé, 
		car plusieurs programmes utilisent le sif (par des substr avec des paramètres entrés en dur : 
		on peut citer parmi ces programmes elig_asf, 3_handicaps, 2_charges, ou encore des programmes de correction ... */

    /* La case H (et donc I) pour les résidences alternées apparait en 2003 
       Cette modification n'a pas été testée sur les ERF antérieure à 2003 */
    %if &anref.<2003 %then %do; sif= substr(sif,1,79)!!'H00I00'!!substr(sif,80,length(sif)-79); %end;
    /* Dates de conclusion et de rupture de PACS inutiles
       Les cases R (année de déclaration de pacs) et J (année de rupture de PACS) 
       subsistent jusqu'en 2003.
       En 2004, il n'existe plus que la case R. Ensuite les deux sont supprimées */
    %if &anref.=2003 %then %do; sif= substr(sif,1,63)!!substr(sif,82,length(sif)-81); %end;
    %if &anref.=2004 %then %do; sif= substr(sif,1,63)!!substr(sif,73,length(sif)-72); %end;
    /* Législation : suppression de la case L (un au moins  de vos enfants à charge 
       ou rattaché est issu du mariage avec votre conjoint décédé en 2008. Réapparition 
       avec un autre sens en 2009 (Vous vivez seul(e) et vous avez élevé vos enfants 
       remplissant l’une des conditions ci-dessus pendant au moins cinq années au cours
       desquelles vous viviez seul(e)).
       Pour les déclaration à partir de 2008, on recrée l'ancienne case L et on décale 
       la nouvelle case L en position 25 pour ne pas écraser l'ancienne.
       On crée dans un premier temps, l'espace puis on la remplit dans un second temps 
       (dans partie 3). */ 
    %if &anref.=2009 %then %do; sif= substr(sif,1,24)!!'0000'!!substr(sif,25,length(sif)-24); %end;
    /* Création de l'ancien case L en 2008 */ 
    %if &anref.=2008 %then %do; sif= substr(sif,1,19)!!'0'!!substr(sif,20,length(sif)-19); %end;
    /* Création de la nouvelle case L pour les années avant 2009 */
    %if &anref.<2009 %then %do; sif= substr(sif,1,24)!!'0'!!substr(sif,25,length(sif)-24); %end;
    /* Création de l'ancienne case L et deplacement de la nouvelle pour les années 
       après 2009 */ 
    %if &anref.=2009 %then %do; sif= substr(sif,1,19)!!'0'!!substr(sif,21,4)!!substr(sif,20,1)!!substr(sif,25,length(sif)-24); %end;
    /* Pendant trois années successives (revenus 2009,2010,2011), il y a de nombreuses variations dans la partie 
	concernant les demi-parts supplémentaires en cas de célibat, séparation ou veuvage.
       Pour 2009 : il existe trois cases : E, K et L.
       Pour 2010 : il n'en existe plus que 2, L et EK. 
			En 2009, la situation avec E ou K cochée et L cochée correspond à une situation en 2010 avec L cochée seulement. 
			En 2009, la situation avec E ou K cochée et L non cochée correspond à la situation avec la case EK cochée.
       Pour 2011 : la case EK devient la case E. 
	   Pour 2013 : disparition de la case E puisqu'elle ne procure plus aucun avantage */

    %if &anref.>=2010 and &anref.<2014 %then %do;
		/* On commence par recrééer la case K dans les déclarations à partir de 2010 */
		sif=substr(sif,1,18)!!'0'!!substr(sif,19,length(sif)-18);
	    /* On recréée l'ancienne case L et on déplace la nouvelle comme on l'avait fait pour 2009*/
		sif=substr(sif,1,24)!!'0000'!!substr(sif,25,70);
		sif=substr(sif,1,19)!!'0'!!substr(sif,21,4)!!substr(sif,20,1)!!substr(sif,25,length(sif)-24);
		%end;

	%if &anref.=2014 %then %do;
		/* en 2013 la case E disparaît de la déclaration mais le sif livré de l'ERFS 2013 conserve la position dédiée à la case E 
		==> Aucune modification n'était à effectuer,
		Dans l'ERFS 2014 le SIF est modifié (raccourci) suite à cette disparition : on recrée donc la case E en 2014 
		pour revenir à la taille précédente du sif*/
		sif= substr(sif,1,15)!!'0'!!substr(sif,16,length(sif)-15);
		/*puis on refait les changements antérieurs à 2014*/
		sif=substr(sif,1,18)!!'0'!!substr(sif,19,length(sif)-18);
		sif=substr(sif,1,24)!!'0000'!!substr(sif,25,70);
		sif=substr(sif,1,19)!!'0'!!substr(sif,21,4)!!substr(sif,20,1)!!substr(sif,25,length(sif)-24);
		%end;
	/* Remplissage de l'ancienne case L dans le SIF ==>  TODO : code à mettre plutot après? */ 
    if mcdvo='V' & (nbf>0 ! nbj>0) then case_l='L'; else case_l='0';

	%if &anref.=2015 %then %do;
		/* on fait en sorte que le sif2015 soit homogène au sif2014 (ils diffèrent à partir de la position 62) */
sif= substr(sif,1,61)!!substr(sif,63,3)!!substr(sif,67,3)!!substr(sif,71,3)!!substr(sif,75,3)!!substr(sif,79,3)!!substr(sif,83,3)!!substr(sif,87,length(sif)-86);

		/* en 2013 la case E disparaît de la déclaration mais le sif livré de l'ERFS 2013 conserve la position dédiée à la case E 
		==> Aucune modification n'était à effectuer,
		Dans l'ERFS 2014 le SIF est modifié (raccourci) suite à cette disparition : on recrée donc la case E en 2014 
		pour revenir à la taille précédente du sif*/
		sif= substr(sif,1,15)!!'0'!!substr(sif,16,length(sif)-15);
		/*puis on refait les changements antérieurs à 2014*/
		sif=substr(sif,1,18)!!'0'!!substr(sif,19,length(sif)-18);
		sif=substr(sif,1,24)!!'0000'!!substr(sif,25,70);
		sif=substr(sif,1,19)!!'0'!!substr(sif,21,4)!!substr(sif,20,1)!!substr(sif,25,length(sif)-24);
		
		/* en 2015, le sif livré dans l'erfs est tronqué à partir de la position 88, mais l'information manquante sur les positions 89 à 95 est contenue dans
		   les variables sif_nbpfa et sif_nbalim*/
		sif=substr(sif,1,88)!!'0'!!''!!SIF_NBPFA!!SIF_NBALIM;

		%end;
	/* Remplissage de l'ancienne case L dans le SIF ==>  TODO : code à mettre plutot après? */ 
    if mcdvo='V' & (nbf>0 ! nbj>0) then case_l='L'; else case_l='0';

	%if &anref.=2016 %then %do;
		/* en 2013 la case E disparaît de la déclaration mais le sif livré de l'ERFS 2013 conserve la position dédiée à la case E 
		==> Aucune modification n'était à effectuer,
		Dans l'ERFS 2014 le SIF est modifié (raccourci) suite à cette disparition : on recrée donc la case E en 2014 
		pour revenir à la taille précédente du sif*/
		sif= substr(sif,1,15)!!'0'!!substr(sif,16,length(sif)-15);
		/*puis on refait les changements antérieurs à 2014*/
		sif=substr(sif,1,18)!!'0'!!substr(sif,19,length(sif)-18);
		sif=substr(sif,1,24)!!'0000'!!substr(sif,25,70);
		sif=substr(sif,1,19)!!'0'!!substr(sif,21,4)!!substr(sif,20,1)!!substr(sif,25,length(sif)-24);
		%end;
	/* Remplissage de l'ancienne case L dans le SIF ==>  TODO : code à mettre plutot après? */ 
    if mcdvo='V' & (nbf>0 ! nbj>0) then case_l='L'; else case_l='0';


    %if &anref.>=2008 %then substr(sif,20,1)=case_l;

    %mend;

/****************************************/
/* Une macro de modifications par année */
/****************************************/

%macro modificationsERFS2004();
*	%apparitionSimple(anneeApparition=2004,listeCases=
		 _5sr /*deficit antérieur à l'année n-1 : on fait l'hypothèse que par défaut les déficits sont ceux de l'année n-1 */ 
		 _6rs _6rt _6ru _6ss _6st _6su _6ps _6pt _6pu /*épargne retraite : épargne versée en 2004*/ 
		 _7cm /*année 2003 report de versements pour souscription aux PME (c'est depuis l'année n-2)*/
		 _7qz /*année 2003, investissment outre-mer dans le cadre d'une entreprise (c'est depuis l'année n-3)*/
		 _7uh /*intérêt prêt d'emprunt à la consommation */
		 _7wj /*équipement pour personne âgées ou handicapée*/
		 _7xh _7xl /*montant des travaux de reconstruction, disparition des cases 7gu et 7gv voir plus bas*/
		 _7xs /*2003, report années antérieures pour le don(une case par année)*/
		 _8tz /*crédit d'impot apprentissage*/
		 _8uz /*crédit d'impot famille*/
		 _8cy /*indémnités élus locaux, conjoint*/
		);
*	%transfererCases(_3vq -> _3vn,2004);/*transfert du domicile hors de france (remplace _3vq)*/
	/*investissement locatif*/
*	%transfererCases(_7gs -> _7gs2,2004);
*	%transfererCases(_6cc -> _7gs,2004);
*	%transfererCases(_7gs2 -> _7xc,2004);
*	%transfererCases(_7gt-> _7xd,2004);/* NON a changer*/
	/*montant des travaux de reconstruction*/
*	%transfererCases(_7xi-> _7gu,2004);
*	%transfererCases(_7xj-> _7gv,2004);
*	%disparitionSimple(anneeDisparition=2005,listeCases=
		_3va _3vb _3vc /*plus-values sur biens meubles et immeubles*/
		_7gw _7gx /*part des primes d'assurance-vie*/
		/*subtilité investissement DOM entreprise*/
		_7uk /*attention, c'est plus bas pour les prêts étudiants*/
		_7um /*attention, c'est plus bas pour les intérets aux agriculteurs*/
		_7nz /*année 2002, investissment outre-mer dans le cadre d'une entreprise non^professionnel*/
		);
   %mend;
%macro modificationsERFS2005();
    %apparitionSimple(anneeApparition=2005,listeCases=
        _1ar _1br _1cr _1dr _1er /* déménagement de plus de 200 km pour trouver un emploi*/
        _2bg /*crédit d'impôt "directive épargne"*/
        _4bf /*prime d'assurance des loyers impayés*/
        _5rw /*année 2004 pour les déficits industriels et commerciaux (c'est depuis l'année n-1)*/
        _6fl /*année 2004 dans les charges et imputations diverses (c'est depuis l'année n-1)*/
        _7cn /*année 2004 report de versements pour souscription aux PME (c'est depuis l'année n-1)*/
        _7dl /*nb d'ascendants bénéficiaires de l'APA de +65 ans pour lesquels on a engagé des dépenses.*/
        _7rz /*année 2004, investissment outre-mer dans le cadre d'une entreprise  (c'est depuis l'année n-2)*/
        _7um /*intérêt paiement différé accordé aux agriculteurs*/
        _7uk /*intérêt prets étudiants*/
        _7wf _7wg /*dépense en faveur des économies d'énérgie*/
        _7xf _7xk _7xm /*subtilité dans l'investissement locatif dans le tourisme lié à 2004*/
        _7xt /*report années antérieures pour le don(une case par année)*/
        _8wa _8wb _8wc _8we /*credit agriculture biologique, prospection commerciale, 
	nouvelle technologies et relocalisation en france*/
        );        
    %transfererCases(_7uc -> _7uj,2005,cumulAvecArrivee=O); /*voir notice : cas particulier 1*/ 
	/* 7uc réapparaissant il ne faudrait pas la supprimer */
    %transfererCases(_7xi -> _7xj,2005,cumulAvecArrivee=O); /*subtilité dans l'investissement locatif dans le tourisme lié à 2004*/ 

    %if &anref.<2005 %then %do;
        /*dépense en faveur des économies d'énérgie*/ 
        /*_7wh=0;/*problème sur wh non présente en 2005, voir plus bas en 2006*/
        %end; 

    %disparitionSimple(anneeDisparition=2005,listeCases=
        _1fk _1fi _1rx _1rv /*disparition d'un pac*/
        _7gy /*part d'épargne des prime d'assurance vie conclus du 01/01/96 au 04/09/96*/
        );

    %mend;
%macro modificationsERFS2006();
    %apparitionSimple(anneeApparition=2006,listeCases=        
        _3vc /*produit et plus values exonérés provenant de structure de capital-risque*/
        _5hg _5ig /*plus-values exonérés en cas de départ en retraite 
	(dans les revenus à imposer aux contributions sociales*/
        _5ns _5nt _5nu _5sw _5os _5ot _5ou _5sx /*regime de la déclaration contrôlée pour les non comm non prof 
	(ajout des cases conjoints et pac)*/
        _5ql _5rl _5sl /*abattement jeunes créateurs, RNCP*/
        _5sv _5sw _5sx /*abattement jeunes créateurs, RNCNP*/
        _5qm _5rm /*indémnités de cessations d'activitié agent d'assurance*/
        _6el _6em _6gu /*info sur les pensions alimentaires; *note : il y a certainement mieux à faire sur le réarangement*/
        _6qw /*épargne retraitre : retour de l'étranger*/
        _7fn _7gn /*souscription au capital de sofica*/
        _7uc /*cotisation pour la defense des forets contre l'incendie*/
        _7vo /*interet prêt étudiant, un cas particulier*/ 
        _7wq /*acquisition chaudière*/
        _7xu /*report années antérieures pour le don(une case par année)*/
        _7wh /*chaudière : cette case est créée en 2005 mais n'apparait qu'à partir de l'ERF2006*/
        _3va _3vb /* abattement sur les plus-values pour durée de détention en cas de départ à la retraite d'un dirigeant */);
    /*année 2008, report investissment outre-mer dans le cadre d'une entreprise (c'est depuis l'année n-1)*/
    %transfererCases(_6eh -> _report_RI_dom_entr,2006);
    /*cas 2*/
    %transfererCases(_7uh -> _interet_pret_conso,2006); 
	/*cas 3*/
    %transfererCases(_5hd -> _5hc,2006,cumulAvecArrivee=O);
    %transfererCases(_5id -> _5ic,2006,cumulAvecArrivee=O);
    %transfererCases(_5jd -> _5jc,2006,cumulAvecArrivee=O);
    %transfererCases(_5hj -> _5hi,2006,cumulAvecArrivee=O);
    %transfererCases(_5ij -> _5ii,2006,cumulAvecArrivee=O);
    %transfererCases(_5jj -> _5ji,2006,cumulAvecArrivee=O);
    /*souscription au capital de sofica*/
    /*Comme on ne sais pas si les sofica s'engagent ou non à réaliser au moins 10% des investissements 
    dans les sociétés de production ou pas, on en met la moitié dans une case, la moitié dans l'autre*/
    %transfererCases(_6aa -> _7fn _7gn,2006,cumulAvecArrivee=O);

	/*gain de levée d'option (suppression de la précision entre 4 et 5 ans)*/ 
	%transfererCases(_1ty -> _glovSup4ansVous,2006);
	%transfererCases(_1uy -> _glovSup4ansConj,2006);
	%transfererCases(_8td -> _credFormation,2006);

    %mend;
%macro modificationsERFS2007();
    %apparitionSimple(anneeApparition=2007,listeCases=
        _1au _1bu _1cu _1du /*heures supplémentaires*/
        _2bh /*autres revenus déjà soumis aux prélèvements sociaux*/
        _2aa /*deficit de l'année antérieure non encore déduit*/
        _3vp /*plus-values exonérées de cession de titres de jeunes entreprises innovantes*/
        _5hd _5id _5jd /*revenus des exploitants forrestiers*/
        _5qf _5qg _5qn _5qo _5qp _5ht _5it _5jt _5kt _5lt /*deficit non encore déduit pour les revenus agricoles 
	et le NCNP (remplace une case unique) */
        _5jg _5jj _5rf _5rg _5sf _5sg /*apparition du régime avec AA pour les revenus NCNP*/
        _6eh /*versement sur un compte codeveloppement*/
        _7db /*activité pour le crédit pour emploi à domicile, ATTENTION cette imputation est très mauvaise 
	car pour beaucoup on devrait avoir _7db=_7df et _7df=0 */
        _7fm /*souscription part de FIP en corse*/
        _7xn /*investissement dans le locatif social*/
        _7xw /*report années antérieures pour le don(une case par année)*/
        _8wv /*renovation des débits de tabacs*/
        _8wx /*formation des salariés (à l'économie d'entreprise)*/);

    /*deficit non encore déduit pour les revenus agricoles et le NCNP (remplace une case unique);
    /*il faut verifier que le régime de la dernière année correspond à celui précédant quand 
    il n'y avait qu'une seule case*/
    %transfererCases(_5sq -> _5qq,2007);
    %transfererCases(_5sr -> _5mt,2007);
    /*beneficier du plafond du conjoint pour le plan epargne retraite*/
    /*on met l'option d'optimisation par défaut même si peu de gens se soucient 
    vraiment de cette case.; */
    %transfererCases(1 -> _6qr,2007);
    /*pour les agriculteurs, les plus-values ne sont plus séparées entre avec CGA et sans CGA*/
    %transfererCases(_5hk -> _5he,2007,cumulAvecArrivee=O);
    %transfererCases(_5ik -> _5ie,2007,cumulAvecArrivee=O);
    %transfererCases(_5jk -> _5je,2007,cumulAvecArrivee=O);
    %transfererCases(_5kk -> _5ke,2007,cumulAvecArrivee=O);
    %transfererCases(_5lk -> _5le,2007,cumulAvecArrivee=O);
    %transfererCases(_5mk -> _5me,2007,cumulAvecArrivee=O);
    %transfererCases(_5nk -> _5ne,2007,cumulAvecArrivee=O);
    %transfererCases(_5ok -> _5oe,2007,cumulAvecArrivee=O);
    %transfererCases(_5pk -> _5pe,2007,cumulAvecArrivee=O);
    %transfererCases(_5qj -> _5qd,2007,cumulAvecArrivee=O);
    %transfererCases(_5rj -> _5rd,2007,cumulAvecArrivee=O);
    %transfererCases(_5sj -> _5sd,2007,cumulAvecArrivee=O);
    /*souscription au capital de sofipêche*/
    %transfererCases(_6cc -> _7gs,2007);
    /*cas 7*/
    /*perte en capital : attention la case _6cb est affectée aux dépenses par les nus 
    propriétaires pas la suite*/
    %transfererCases(_6cb -> _perte_capital_passe,2007);
    %transfererCases(_6da -> _perte_capital,2007);
    %transfererCases(_8we -> _relocalisation,2007);
    /*subtilité de l'investissement locatif dans le tourisme, c'est une approximation 
    relativement grossière mais le gain à gérer cette subtilité est très faible pour un coût 
    relativement élevé*/
    %transfererCases(_7xd -> _7xf,2007,cumulAvecArrivee=O); 

	/* Changement à la marge du contenu des cases _2ab et _2bg : 
	/*	Avant = _2ab contenait les CI en contrepartie de retenues à la source pour valeurs mobilières étrangères 
		+ d'autres CI non restituables (obligations émises avant 1987, titres d'emprunt négociables et 
	bons de caisse sans option pour le prélèvement libératoire) et _2bg contenait le CI directive "épargne" */
	/*	Après = les autres CI sont déplacés dans _2bg et deviennent restituables */
	/* On ne fait pas d'hypothèse pour transférer une partie de _2ab dans _2bg. Comme les deux cases sont 
	ajoutées telles quelles aux CI, on choisit de ne faire aucun traitement */
    %disparitionSimple(anneeDisparition=2007,listeCases=
        _1er _1qx _1qv /*disparition d'un pac*/
        _4bl /*contribution sur les revenus locatifs*/ /*on peut faire mieux c'est sur*/
        );

    %mend;
%macro modificationsERFS2008();
    /*apparition*/
    %apparitionSimple(anneeApparition=2008,listeCases=
        _1dn _1sm /*somme exonérées transférées du CET au PERCO ou à un régime supplémentaire de retraite d'entreprise*/
        _2da /*revenus soumis au prélèvement libératoire*/
        _2al /*deficit de l'année 2007 non encore déduit*/
        _2dm /*impatriés : revenus perçus à l'étranger exonéré à hauteur de 50%*/
        _3vq _3vr /*cession de titre : plus-values et moins values*/ 
        _3vd /*gains de levée d'option à 18%*/
        _3vs /*gains de levée d'option acquis sur titres et gains... 
	à compter du 16-10-2007 soumis à contribution salariale à 2,5%*/
        _5hk _5jk _5lk _5ik _5kk _5mk /*revenus exonérés de la déclaration controlée des non commerciaux non professionnel*/
		_7fy _7gy /*aides aux créateurs d'entreprises*/
        _7nz /*travaux de conservation ou de restauration d'objets classés monuments historique*/
        _7td /*interet prêt étudiant, un cas particulier*/
        _7vz /*interet d'emprunt pour l'acquisition de l'habitation principale*/
        _7xy /*report années antérieures pour le don*/
        _7xo /*report investissement dans le locatif social*/
        _8we /*réapparition : interessement*/
        );
    /* investissement outre-mer dans le logement */
    %transfererCases(_7ua _7ub _7uj -> _7ui,2008,cumulAvecArrivee=O,ponderations=0.2*0.25 0.2*0.25 0.2*0.4);
    %transfererCases(_7up -> _nb_vehicpropre_simple,2008);
    %transfererCases(_7uq -> _nb_vehicpropre_destr,2008);
    %transfererCases(_7xf _7xj _7xk -> _7xf,2008);

    %if &anref. < 2008 %then %do; 
        /*interet prêt étudiant, un cas particulier*/
        /* 7vo change aussi un peu*/ _7vo=(_7vo>0);
        /*interet d'emprunt pour l'acquisition de l'habitation principale*/
        _7vy=sum(_7uh,0);/*on a l'info en 2007 mais pas avant, du coup 7uh n'existe 
        que si anref=2007, de cette manière, on conserve cette info pour 2007 et on a zéro avant, 
        7uh est droppé plus haut quand elle n'a pas de lien avec l'habitation principale*/
         %end;
     /*disparition*/
    %if &anref.>2007 %then %do; 
        /*subtilité de l'investissement locatif dans le tourisme*/ 
        %end;
    %mend;

%macro modificationsERFS2009();
    %apparitionSimple(anneeApparition=2009,listeCases=
        _1bl _1cb _1dq /*case RSA*/
        _2am /*deficit anterieur 2008*/
        _4by /*amortissement robien ou borloo*/
        /* Apparition d'un régime spécial pour les locations meublées;
        /*professionnel*/
        _5ha _5ia _5ja /*revenu imposable pour les rev indus et comm avec cga*/
        _5ka _5la _5ma /*revenu imposable pour les rev indus et comm sans cga*/
        _5qa _5ra _5sa /*déficit pour les rev indus et comm avec cga*/
        _5qj _5rj _5sj /*déficit pour les rev indus et comm sans cga*/
        /*non professionnel*/
        _5na _5oa _5pa /*revenu imposable pour les rev indus et comm avec cga*/
        _5nk _5ok _5pk /*revenu imposable pour les rev indus et comm sans cga*/
        _5ny _5oy _5py /*déficit pour les rev indus et comm avec cga*/
        _5nz _5oz _5pz /*déficit pour les rev indus et comm sans cga*/
        /* apparition du régime de l'auto-entrepreneur*/
        _5ta _5ua _5va _5tb _5ub _5vb /*revenu industriel et commerciaux prof*/
        _5tc _5uc _5vc _5td _5ud _5vd /*revenu industriel et commerciaux non prof*/ 
        _5te _5ue _5ve /*revenu non commerciaux prof*/
        _5tg _5ug _5vg /*revenu non commerciaux non prof*/ 
        _5tf _5uf _5vf /*horaires de prospection comerciale exonérés, avec cga*/
        _5ti _5ui _5vi /*horaires de prospection comerciale exonérés, sans cga*/
        _5th _5uh _5vh /*revenu net exonérés des micro BNC non commerciaux non professionnel*/
        _6cb /*dépense de grosses réparations effectuées par les nus-propriétaires*/
        _7cu /*subtilité de la souscription au capital de PME*/
        _7dq /*subtilité de l'emploi à domicile (première fois)*/
        _7hj _7hk /* investissement locatif neuf : dispositif Scellier*/ 
        _7ij /* investissement immobilier destinés à la location meublée non professionnelle*/ 
        _7hy _7jy _7iy _7ky /* aide aux créateurs d'entreprise*/
        _7qa _7qb _7qc _7qd _7qe _7qf _7qg _7qh _7qi _7qj _7qk /*investissement outre-mer*/
        _7ra _7rb /* travaux de restauration immobilière*/
        _7sa _7sb _7sc _7sd _7se /*dépenses en faveur de la qualité environnementale des logements donnés en location*/
        _7up _7uq _7ut /*investissements forestiers*/
        _7vx /*subtilité intérêt emprunt pour acquisition principale*/
        _7we _7wk /*modif dans les dépenses en faveur de l'environnement*/
        _7xd _7xe /*investissement dans le locatif touristique : option pour étaler sur 6 ans*/
        _8uy /*auto-entrepreneur*/
        );

    %transfererCases(_6eh -> _7uh,2009); /*versement sur un compte épargne codéveloppement*/
    %disparitionSimple(anneeDisparition=2009,listeCases=_6eh);
    /* souscription au capital de sofipêche(disparu deux ans plus tôt);*/ 
     %transfererCases(0 -> _7gs,2009,cumulAvecArrivee=O);/*on a créé _7gs jusqu'à l'ERFS 2006 plus haut 
	 parce qu'on avait l'info, en 2007 et 2008 on ne l'a pas ( 6cc n'existe pas) on créé comme ceci _7gs=0 pour ces 
     deux années sans supprimer ce qu'il y avait avant*/

	%transfererCases(_7ui -> _7qd,2009); /*investissement outre-mer logement */
    %transfererCases(_7ur -> _7qf,2009); /*investissement outre-mer entreprise */

	/* CI recherche pour les années antérieures : le nom _8tc sera repris en 2010 */
	%transfererCases(_8tc -> _CIRechAnt,2009);
	/* CI nouvelles technologies : le nom _8wc sera repris en 2012 */
	%transfererCases(_8wc -> _CINouvTechn,2009);

	/* Déménagement à plus de 200 km pour trouver un emploi */
	%transfererCases(_1ar -> _demenage_emploiVous,2009); 
	%transfererCases(_1br -> _demenage_emploiConj,2009);
	%transfererCases(_1cr -> _demenage_emploiPac1,2009);
	%transfererCases(_1dr -> _demenage_emploiPac2,2009);
	/*%disparitionSimple(anneeDisparition=2009,listeCases=_1ar _1br _1cr _1dr);*/

    %disparitionSimple(anneeDisparition=2009,listeCases=
        _7wq /* chaudière basse température */ 
        );
    %mend;



%macro modificationsERFS2010();
    %apparitionSimple(anneeApparition=2010,listeCases=
        _1ny _1oy /* gains et distributions provenant de parts ou actions de carried-interest, déclarés cases _1aj ou_1bj, */
	/*soumis à la contribution salariale de 30 % */
		/* _2an devrait apparaître mais n'apparaît que l'année suivante dans l'ERFS */
		_3vt _3vu /* gains soumis aux prélèvements sociaux (gains et pertes) */
        _3vv /* pertes ouvrant droit au crédit d'impôt de 19 % */
        _5ga _5gb _5gc _5gd _5ge _5gf _5gg _5gh _5gi _5gj /* déficits des locations meublées non professionnelles */
	/*des années antérieures */
        _5tj _5tk _5tl _5tm _5uj _5uk _5ul _5um /* ensemble du cadre 5G : personnes affiliées au régime social des */
	/*indépendants, informations pour transmission aux organismes sociaux pour le calcul et l'appel des cotisations */
        _6hj /* report de dépenses de grosses réparations effectuées par les nus-propriétaires */
        _7hn _7ho /* investissements Scellier en métropole ou dans les DOM avec promesse d'achat avant le 1.1.2010 */
        _7hl _7hm /* investissements Scellier réalisés en 2009 et achevés en 2010 */
        _7hr _7hs _7la /* reports concernant les investissements réalisés en 2009 et achevés en 2009 */
        _7il _7im _7ik _7is /* investissements immobiliers destinés à la location meublée non professionnelle */ 
	/*(sauf investissements réalisés et achevés en 2010 */
        _7ka /* dépenses de protection du patrimoine naturel */
        _7ly _7my /* aide aux créateurs d'entreprises, conventions signées en 2009 ayant pris fin en 2010 */
        _7sh /* dépenses en faveur de la qualité environnementale des logements donnés en location ouvrant 
	droit au crédit d'impôt au taux de 15 % */
        _7sf /* travaux de prévention des risques technologiques dans les logements donnés en location */
        _7uu _7te /* report des dépenses d'investissements forestiers de l'année 2009 */
        _7vw /* interêts des emprunts contractés pour l'acquisition ou la construction d'un logement */
	/*neuf non labellisé BBC à compter du 1.1.2010 */
        _7wl /* dépense de travaux de prévention des risques technologiques réalisés pour l'habitation principale */
        _7xi _7xj _7xk /* investissements locatifs dans le secteur touristique, report des dépenses effectuées en 2009 */
		_7ql _7qm _7qt /* investissement outre-mer dans le logement */
		_7qn _7kg /* investissement outre-mer dans le logement social*/
		_7qo _7qp _7qq _7qr _7qs _7lg _7ma _7ks _7ls /* investissement outre-mer dans le cadre d'une entreprise*/
		_7wq /* réapparition : dépenses qualité environnementale habitation principale */
		_8tc /* réapparition : CI recherche pour entreprises ne bénéficiant pas de la restitution immédiate */
        );
	%transfererCases(_report_RI_dom_entr -> _7mm,2010);

	/* Anciennement 2 cases (régime général et régime simplifié), regroupées en une en 2010. 
	5nd, 5od, 5pd, 5ng, 5og et 5pg prendront un nouveau sens en 2011 
	5kj, 5lj et 5mj, comme 5nj, 5oj et 5pj, 5nm, 5om et 5pm, 5km, 5lm et 5mm prendront un nouveau sens en 2012 */
	%transfererCases(_5kd -> _5kc,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5kd,2010);
	%transfererCases(_5kj -> _5ki,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5kj,2010);
	%transfererCases(_5ld -> _5lc,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5ld,2010);
	%transfererCases(_5lj -> _5li,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5lj,2010);
	%transfererCases(_5md -> _5mc,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5md,2010);
	%transfererCases(_5mj -> _5mi,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5mj,2010);

	%transfererCases(_5kg -> _5kf,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5kg,2010);
	%transfererCases(_5km -> _5kl,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5km,2010);
	%transfererCases(_5lg -> _5lf,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5lg,2010);
	%transfererCases(_5lm -> _5ll,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5lm,2010);
	%transfererCases(_5mg -> _5mf,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5mg,2010);
	%transfererCases(_5mm -> _5ml,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5mm,2010);

	%transfererCases(_5nd -> _5nc,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5nd,2010);		
	%transfererCases(_5nj -> _5ni,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5nj,2010);	
	%transfererCases(_5od -> _5oc,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5od,2010);		
	%transfererCases(_5oj -> _5oi,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5oj,2010);	
	%transfererCases(_5pd -> _5pc,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5pd,2010);		
	%transfererCases(_5pj -> _5pi,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5pj,2010);	

	%transfererCases(_5ng -> _5nf,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5ng,2010);
	%transfererCases(_5nm -> _5nl,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5nm,2010);
	%transfererCases(_5og -> _5of,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5og,2010);
	%transfererCases(_5om -> _5ol,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5om,2010);
	%transfererCases(_5pg -> _5pf,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5pg,2010);
	%transfererCases(_5pm -> _5pl,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5pm,2010);

	/* Fusion de cases auto-entrepreneurs (avant RIC professionnels ou non) */
	%transfererCases(_5tc -> _5ta,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5tc,2010);
	%transfererCases(_5uc -> _5ua,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5uc,2010); 	
	%transfererCases(_5vc -> _5va,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5vc,2010);	

	%transfererCases(_5td -> _5tb,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5td,2010);
	%transfererCases(_5ud -> _5ub,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5ud,2010);	
	%transfererCases(_5vd -> _5vb,2010,cumulAvecArrivee=O); %transfererCases(0 -> _5vd,2010);		
	
	%transfererCases(_5tg -> _5te,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5tg,2010);
	%transfererCases(_5ug -> _5ue,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5ug,2010);
	%transfererCases(_5vg -> _5ve,2010,cumulAvecArrivee=O);	%transfererCases(0 -> _5vg,2010);

	/* Versements sur un compte épargne codéveloppement */
	%transfererCases(_7uh -> _epargneCodev,2010);

	/* Revenus distribués dans le PEA pour le calcul du crédit d'impôt de 50 % : supprimé mais on conserve l'information */
	%transfererCases(_2gr -> _revPEA,2010); %disparitionSimple(anneeDisparition=2010,listeCases=_2gr) ;

	/* Crédit d'impôt en faveur des entreprises, formation des salariés : supprimé mais on conserve l'information */
	%transfererCases(_8wx -> _CIFormationSalaries,2010); %disparitionSimple(anneeDisparition=2010,listeCases=_8wx) ;

	%disparitionSimple(anneeDisparition=2010,listeCases=
        _5hz _5iz _5jz /* plus-values taxable à 16 % à imposer aux prélèvements sociaux */
        _report_RI_dom_entr /* investissements outre mer */
        _7sc /* dépenses en faveur de la qualité environnementale des logements donnés en location, chaudières à condensation (...)
	installées au plus tard le 31.12 de la 2ème année d'acquisition d'un logement achevé avant le 1.1.1977 */
        _7wg /* dépenses en faveur de la qualité environnementale de l'habitation principale, chaudières à condensation (...)
	installées au plus tard le 31.12 de la 2ème année d'acquisition d'un logement achevé avant le 1.1.1977 */
        _8ws /* crédit d'impôt en faveur des entreprises, emploi de salariés réservistes */
        );
	/* On remplit la _revPEA avec _2fu pour les ERFS postérieures, plutôt que de mettre à blanc. */
	%if &anref.>=2010 %then %do;
		_revPEA=_2fu;
		%end;
    %mend;


%macro modificationsERFS2011();
    %apparitionSimple(anneeApparition=2011,listeCases=
		_1at _1bt /* pensions de retraite en capital */
		_2an /* deficit anterieur 2009 : variable livrée en retard d'un an, on fait l'approximation de 
	la mettre à 0 pour l'ERFS 2010 où elle aurait dû être présente*/
		_2aq /*deficit anterieur 2010*/
		_3vo /* gains de levees d'option sur titre soumis à la contribution salariale et réalisés après le 01/01/2011 */
		_3vy /* plus-values exonérées de cession de participation au sein d'un groupe familial */
		_3vz /* plus-values de cession d'immeubles ou de bien meubles */
		_3wa _3wb /* plus values et creances dans le cas d'un transfert du domicile fiscal hors de France */
		_3we /* Plus values en report d'imposition */
		_5tc _5uc _5vc /* Inventeurs et auteurs de logiciels */
		_6hk /* dépenses de grosses réparation effectuees par les nus-propriétaires : report 2010 */
		_7vu _7vv /* Intérêts d'emprunts contractés pour l'acquisition de l'habitation principale*/
		_7qv _7pa _7pb _7pc _7pd _7pe _7pf _7pg _7ph _7pi _7pj _7pk _7pl _7mn _7lh _7mb _7kt _7li _7mc _7ku 
	/* DOM : réduction d'impot pour investissement dans le cadre d'une entreprise */
		_7oa _7ob _7oc _7oh _7oi _7oj _7ok /* DOM : réduction d'impot pour investissement dans le logement */
		_7qu _7kh _7ki /* DOM : réduction d'impot pour investissement dans le logement social*/
		_7fl /* DOM : FIP investis outre-mer par des personnes domiciliées outre-mer*/
		_7rd _7rc /* Dépenses de restauration (loi Malraux) effectuées avant le 1.1.2011 */
		_7xa _7xb /* Investissements locatifs dans le secteur touristique, travaux engagés avant le 1.1.2011 */
		_7cq /* Investissements au capital de PME non cotées, reports de dépenses */
		_7dd /* Dépenses emploi à domicile pour ascendant bénéficiaire de l'APA */
		_7hv _7hw _7hx _7hz _7ht _7hu /* investissements achevés en 2010 : report de 1/9 de l'investissement */
		_7na _7nf _7nk _7np _7nb _7ng _7nl _7nq _7nc _7nh _7nm _7nr _7nd _7ni _7nn _7ns _7ne _7nj _7no _7nt 
	/* investissements scelliers réalisés en 2011 et achevés en 2011 */
		_7va _7vb _7vc _7vd /* dons à des organismes d'interêt général établis dans un Etat européen */
		_7ul /* Investissements forestiers, dépense d'assurance */
		_7uv _7tf /* investissements forestiers, report de dépenses 2010 */
		_7in _7iv _7iw _7io _7ip _7iq _7ir _7iu _7it /* Investissements destinés à la location meublée 
	non professionnelle : loi Censi-Bouvard */
		_7lb _7lc /* report du solde de réduction d'impôt non encore imputé */
		_7kb /* dépenses de protection de patrimoine naturel, report de dépenses */
		_8tq _8tv _8tw _8tx /* revenus de source étrangère */
		_9hi _9mn _9mo /* ISF */
		_8td /* Contributuion exceptionnelle sur les hauts revenus (case à cocher) */
 		_5hz _5iz _5jz /* Abattements pour jeunes agriculteurs : distinction sans CGA */
   	);

	/* Investissement locatif dans une résidence hotelière à vocation sociale */
	%transfererCases(_7xn -> _7xr,2011); /* Investissements locatifs, reports de dépenses effectuées en 2010 */
	%transfererCases(0 -> _7xn,2011); 

	/* Investissement locatif dans le secteur touristique */
	%transfererCases(_7xi -> _7xp,2011);
	%transfererCases(_7xf -> _7xi,2011, ponderations=0.25);
	%transfererCases(_7xf -> _7xf,2011, ponderations=0.75);
	%transfererCases(_7xj -> _7xq,2011);
	%transfererCases(_7xm -> _7xj,2011, ponderations=0.25);
	%transfererCases(_7xm -> _7xm,2011, ponderations=0.75);

	/* Locations meublées non professionnelles, régime micro-entreprise */
	/* _nd, _5od et _5pd avant incluses dans 5np, 5op et 5pp => ne pas les séparer dans les programmes car l'hypothèse 50/50 est un peu grosse */
	%transfererCases(_5np -> _5nd _5np,2011); %transfererCases(_5op -> _5od _5op,2011); %transfererCases(_5pp -> _5pd _5pp,2011);
	/* _ng, _5og et _5pg avant incluses dans 5no, 5oo et 5po => ne pas les séparer dans les programmes car l'hypothèse 50/50 est un peu grosse */
	%transfererCases(_5no -> _5ng _5no,2011); %transfererCases(_5oo -> _5og _5oo,2011); %transfererCases(_5po -> _5pg _5po,2011);

	/* Disparition de _3vv : pertes ouvrant droit au crédit d'impôt de 19 % */
	/* Non codé et nom repris en 2013 donc on ne fait pas de DisparitionSimple et on ne crée pas de nom explicite */

	/* Investissement dans les DOM dans le cadre d'une entreprise */
	%transfererCases(_7qs -> _InvDomAut1,2011); %transfererCases(_7qj -> _InvDomAut2,2011); /* noms repris en 2012 */
	%disparitionSimple(anneeDisparition=2011,listeCases=_7ls); /* _7rz disparait aussi mais est réutilisé en 2014 */

	/* Dépenses dans le développement durable (avoir bénéficié d'un prêt à taux zéro) */
	%transfererCases(_7we -> _7wg,2011);	%transfererCases(0 -> _7we,2011);

	/* Gains de levée d'option soumis à la contribution salariale de 8% pour celles perçues à partir du 01/01/2011 */
	/* On transfert le contenu de _3vs dans _3vo et on suppose que les gains encore soumis au taux de 2,5 % seront négligeables */
	%transfererCases(_3vs -> _3vo,2011);	%transfererCases(0 -> _3vs,2011);

	/* Plus-values imposées immédiatemment en sursis de paiement quand transfert du domicile hors de France avant le 01/01.2005 */
	/* La case disparait et on ne conserve pas l'information. Comme elle est réutilisée dès 2012 on ne la fait pas disparaitre, on la met à 0 */ 
	%transfererCases(0 -> _3vn,2011); 
	%mend;


%macro modificationsERFS2012();
   	%apparitionSimple(anneeApparition=2012,listeCases=
		_1ty _1uy /* agents de l'Etat en service à l'étranger : suppléments de rémunérations exonérés */
		_1tt _1ut /* gains de levée d'options sur titres et gains d'acquisitions d'actions gratuites */
		_2ar /*deficit anterieur 2011*/
		_3vn /* les gains sur options et actions gratuites soumis à la contribution salariale au taux de 30% */
		_3sa /* plus-values de cession de titres réalisées par un entrepreneur */
		_3se /* plus-values de cession de droits sociaux réalisées par les non-résidents */
		_3sb _3sc _3wh/* plus-values en report d'imposition */
		_3sj _3sk /* Gain des cessions de bons de souscription de parts de créateur d'entreprise */
		_3wd /* abattement pour durée de détention en cas départ retraite d'un dirigeant (non codé) */
		_3vw /* plus-value exonérée au titre 1ère cession logement, sous conditions (non codé) */
		_4bh /* montant calculé de la taxe sur les loyers élevés de logement de petite surface */
		_6hl /* dépenses de grosses réparation effectuees par les nus-propriétaires : report 2011 */
		_7rf _7re /* dépenses de restauration (loi Malraux) effectuées en 2012 */
		_7qs _7qj _7qw _7qx /* RI Dom : investissements dans logement social réalisés en 2012 */
		_7xn _7xv /*investissements locatifs, reports de dépenses effectuées en 2012 */
		_7uw _7tg /* investissements forestiers, report de dépenses 2011 */
		_7le _7ld _7lf /* report du solde de réduction d'impôt non encore imputé */
		_7kc /* dépenses de protection de patrimoine naturel, report de dépenses */
		_7vt /* interêts d'emprunts contractés pour l'acquistion ou la construction de l'habitation principale */
		_7sz /* montant du CI calculé pour les dépenses en faveur du développement durable pour un logement donné en location*/
		_8ts /* investissement en Corse : entreprises bénéficiant de la réduction immédiate */
		_8tr /* salaires de source étrangère : taux de 7.5 % */
		_8wc /* réapparition : CI prêts sans intérêt */
		_9fg _9pv /* ISF */
		);
	%transfererCases(_3vm -> _3vt,2012,ponderations=1.5);/* gains à la cloture PEA entre la 2ème et la 5ème année : porte sur 3 ans au lieu de 2 pour _3vm */
	%transfererCases(_3wa -> _3wf _3wa,2012);%transfererCases(_3wb -> _3wg _3wb,2012);/* Plus values transfert domicile fiscal hors de France */
	/* revenus des locations meublées non professionnelles : déjà soumis aux prélèvements sociaux ou non */
	%transfererCases(_5ng -> _5nj _5ng,2012);
	%transfererCases(_5og -> _5oj _5og,2012);
	%transfererCases(_5pg -> _5pj _5pg,2012);
	%transfererCases(_5na -> _5nm _5na,2012);
	%transfererCases(_5nk -> _5km _5nk,2012);
	%transfererCases(_5oa -> _5om _5oa,2012);
	%transfererCases(_5ok -> _5lm _5ok,2012);
	%transfererCases(_5pa -> _5pm _5pa,2012);
	%transfererCases(_5pk -> _5mm _5pk,2012);
	/* souscription au capital de PME : on intervertit _7cu et _7cf */
	%echangerCases(_7cu <-> _7cf,2012);
	/* dépenses de restauration (loi Malraux) effectuées en 2012 */
	%transfererCases(_7rb -> _7rf,2012);%transfererCases(_7rd -> _7rb,2012);%transfererCases(0 -> _7rd,2012);
	%transfererCases(_7ra -> _7re,2012);%transfererCases(_7rc -> _7ra,2012);%transfererCases(0 -> _7rc,2012);
	/*investissements locatifs dans le secteur touristique, travaux engagés en 2012 */
	%transfererCases(_7xg -> _7xx,2012);%transfererCases(_7xa -> _7xg,2012);%transfererCases(0 -> _7xa,2012);
	%transfererCases(_7xh -> _7xz,2012);%transfererCases(_7xb -> _7xh,2012);%transfererCases(0 -> _7xb);
	/* investissements locatifs Scellier réalisés en 2012 */
	%transfererCases(_7na -> _7ja,2012);%transfererCases(0 -> _7na,2012);
	%transfererCases(_7nf -> _7jf,2012);%transfererCases(0 -> _7nf,2012);
	%transfererCases(_7nk -> _7jk,2012);%transfererCases(0 -> _7nk,2012);
	%transfererCases(_7np -> _7jo,2012);%transfererCases(0 -> _7np,2012);
	%transfererCases(_7nb -> _7jb,2012);%transfererCases(0 -> _7nb,2012);
	%transfererCases(_7ng -> _7jg,2012);%transfererCases(0 -> _7ng,2012);
	%transfererCases(_7nl -> _7jl,2012);%transfererCases(0 -> _7nl,2012);
	%transfererCases(_7nq -> _7jp,2012);%transfererCases(0 -> _7nq,2012);
	%transfererCases(_7nc _7nd -> _7jd,2012);%transfererCases(0 -> _7nc,2012);%transfererCases(0 -> _7nd,2012);
	%transfererCases(_7ni _7nh -> _7jh,2012);%transfererCases(0 -> _7ni,2012);%transfererCases(0 -> _7nh,2012);
	%transfererCases(_7nm _7nn -> _7jm,2012);%transfererCases(0 -> _7nm,2012);%transfererCases(0 -> _7nn,2012);
	%transfererCases(_7nr _7ns -> _7jq,2012);%transfererCases(0 -> _7nr,2012);%transfererCases(0 -> _7ns,2012);
	%transfererCases(_7ne -> _7je,2012);%transfererCases(0 -> _7ne,2012);
	%transfererCases(_7nj -> _7jj,2012);%transfererCases(0 -> _7nj,2012);
	%transfererCases(_7no -> _7jn,2012);%transfererCases(0 -> _7no,2012);
	%transfererCases(_7nt -> _7jr,2012);%transfererCases(0 -> _7nt,2012);
	/* Reports d'investissements dans les Dom/Com (màj ici mais non codés dans deduc donc pas nécessaire) */
	%apparitionSimple(anneeApparition=2012,listeCases=_7ha _7hb _7hd _7he _7hf);

	/* investissements destinés à la location en meublé (loi censi-bouvard) réalisés en 2012 */
	%transfererCases(_7ij -> _7id,2012);%transfererCases(0 -> _7ij,2012);
	%transfererCases(_7il -> _7ie,2012);%transfererCases(0 -> _7il,2012);
	%transfererCases(_7in -> _7if,2012);%transfererCases(0 -> _7in,2012);
	%transfererCases(_7iv -> _7ig,2012);%transfererCases(0 -> _7iv,2012);
	/* investissements destinés à la location en meublé (loi censi-bouvard) réalisés les années antérieures */
	/* les cases décrivant les investissements achevés l'année précédente correspondent à 1/9 de la réduction d'impot 
	et plus 1/9 de l'investissement */
	%transfererCases(0.18/9*(min(9*_7ip,300000)) -> _7ia,2012);%transfererCases(0 -> _7ip,2012);
	%transfererCases(0.20/9*(min(9*_7iq,300000)) -> _7ib,2012);%transfererCases(0 -> _7iq,2012);
	%transfererCases(0.25/9*(min(9*_7ir,300000)) -> _7ic,2012);%transfererCases(0 -> _7ir,2012);
	/*gains de levée d'option à 18% : vous et conj sont distingués. On fait l'hypothèse 50/50.
	De plus, les options cédées après le 28-09-12 ne peuvent plus bénéficier de l'imposition
	au forfait. Au 31/12/12, on fait l'hypothèse qu'aucune des options cédées après le 28-08-12
	n'aient fait l'objet d'une levée d'option (ie 1tt et 1ut=0)*/
	%transfererCases(_3vd -> _3sd _3vd, 2012);
	%transfererCases(_3vi -> _3si _3vi, 2012);
	%transfererCases(_3vf -> _3sf _3vf, 2012);
	%transfererCases(_3vs -> _3ss _3vs, 2012);
	/* Hypothèse : 	- on met les cases relatives au "conj" à 0 (sans conséquence dans le programme puisque c'est la somme de vous+conj qui est calculée)
					- le taux de contribution salariale est passé de 8 à 10 % au 18/08 (63% de l'année) : on répartit au pro-rata 3vo sur 3vo et 3vn */
	%apparitionSimple(anneeApparition=2012,listeCases=_3so _3sn);
	%transfererCases(0.37*_3vo -> _3vn, 2012);
	%transfererCases(0.63*_3vo -> _3vo, 2012);

	/* Dépenses en faveur du développement durable pour un logement donné en location */
	/* obligés de procéder de cette façon car d'autres cases existent sous ce nom la même année ! */
	/* ce qu'il ne faut pas faire : ApparitionSimple(_7sh) plus haut, car alors on transfèrerait ici un contenu nul */
	%transfererCases(_7sh -> _dep_devldura_loc1,2012);%transfererCases(0 -> _7sh,2012); 
/* équivalent ApparitionSimple, mais doit avoir lieu ici et non pas plus haut */
	%transfererCases(_7sb -> _dep_devldura_loc2,2012);
	%transfererCases(_7sd -> _dep_devldura_loc3,2012);%transfererCases(0 -> _7sd,2012);
	%transfererCases(_7se -> _dep_devldura_loc4,2012);%transfererCases(0 -> _7se,2012);

	/* Travaux de prévention des risques technologiques dans les logements donnés en location */
	%transfererCases(_7sf -> _7wr, 2012);

	/* Dépenses en faveur du développement durable dans l'habitation principale */
	/* Nouveautés déclaration 2012 :
		- le détail des dépenses est déclaré (spécificités législatives), là où avant seul un total par taux différent était déclaré
		- les dépenses sont déclarées dans des cases différentes selon que bouquet de travaux ou non (commencent soit par 7t, soit par 7w) */
	%echangerCases(_7we <-> _7wg,2012); /* on donne aux cases le sens : prêt à taux zéro en N-1 et en N */
	/* Noms de cases qui ont changé de sens entre l'année dernière et cette année */
	/* Hypothèse des transferts ci-dessous : 
			- personne n'engage de bouquet de travaux (BT), autrement dit ques des actions seules
			- tout le monde est en immeuble collectif (nouvelle signification de _7wk = maison individuelle ; on la met à 0 faut d'information)
			- les travaux sont faits sur moins de la moitié des fenêtres, murs, ou pas sur toute la toiture
			- date d'engagement des dépenses : aucune case cochée donc pas de donnée sur ce point
		Pour les anref antérieures, on répartit la case totale (la seule qui existait avant) entre les cases détaillées de la manière suivante: 
		Puisqu'il n'y a pas BT (hypothèse), on impute le total à l'une des cases du même taux. 
		Puisqu'il n'y a pas de date, on choisit la première case pour laquelle il n'y a pas de spécificité relative à la date en 2013. 
		Ainsi on assure que le code de 4_deduc fonctionne pour anleg<2013 (il est équivalent d'avoir le total dans une sous-case ou dans un total) */
	%transfererCases(_7wq -> _7tt, 2012);%transfererCases(0 -> _7wq, 2012);		/* taux de 10 % en action seule */
	%transfererCases(_7wh -> _7tv, 2012);%transfererCases(0 -> _7wh, 2012);		/* 15 % */
	%transfererCases(_7wk -> _7tx, 2012);%transfererCases(0 -> _7wk, 2012);		/* 26 % */
	%transfererCases(_7wf -> _7ty, 2012);%transfererCases(0 -> _7wf, 2012);		/* 32 % */
	%apparitionSimple(anneeApparition=2012,listeCases=_7ws _7wt _7wu _7wv _7ww _7wx _7wa _7wb _7wc _7ve _7vf _7vg);
	%apparitionSimple(anneeApparition=2012,listeCases=	_7sd _7se _7sf
														_7sg _7sh _7si _7sj _7sk _7sl
														_7sm _7sn _7so _7sp
														_7sq _7sr _7ss _7st
														_7su _7sv _7sw); /* Cases si bouquet de travaux */

	/* Revenus de source étrangère soumis à la CSG et à la CRDS */
	%transfererCases(_8tq -> _8tr _8tq, 2012); /* revenus salariaux et non salariaux, taux de 7.5 % */
	/* Revenus ind. et com/ professionnels, moins-values nettes à court terme */
	%transfererCases(_5hu -> _5kj _5lj _5mj, 2012);
	/* Revenus non commerciaux professionnels, moins-values nettes à court terme */
	%transfererCases(_5kz -> _5lz _5mz _5kz, 2012);

	/* Plus-values de cession de droits sociaux réalisés par les personnes domiciliées dans les DOM */
	%transfererCases(_3ve -> _PVCessionDom,2012); %transfererCases(0 -> _3ve,2012); /* Nom sera repris en 2013 avec un autre sens */

	/* Investissement DOM dans une entreprise */
	%transfererCases(_7qv -> _7pm _7pn _7po _7pp _7pq _7pr, 2012);
	%transfererCases(_7qo -> _7ps, 2012); %transfererCases(_7qp -> _7pt, 2012);
	%transfererCases(_7qq -> _7pu _7pv, 2012);
	%transfererCases(_7qr -> _7pw, 2012);
	%transfererCases(_7qf -> _7px, 2012); %transfererCases(_7qg -> _7py, 2012);
	%transfererCases(_7qh -> _7rg _7rh, 2012);
	%transfererCases(_7qi -> _7ri, 2012);
	%transfererCases(_7qe -> _7rj _7rk _7rl _7rm _7rn _7ro, 2012);
	%transfererCases(_7pa -> _7rp, 2012); %transfererCases(_7pb -> _7rq, 2012);
	%transfererCases(_7pc -> _7rr _7rs, 2012);
	%transfererCases(_7pd -> _7rt, 2012);
	%transfererCases(_7pe -> _7ru, 2012); %transfererCases(_7pf -> _7rv, 2012);
	%transfererCases(_7pg -> _7rw _7rx, 2012);
	%transfererCases(_7ph -> _7ry, 2012);
	%transfererCases(_7pi -> _7nu, 2012); %transfererCases(_7pj -> _7nv, 2012);
	%transfererCases(_7pk -> _7nw _7nx, 2012);
	%transfererCases(_7pl -> _7ny, 2012);
	%transfererCases(_7qq -> _7pq, 2012); %transfererCases(_7qq -> _7pq, 2012);
	%transfererCases(_7mn -> _7qe _7pa _7pb _7pd, 2012);
	%transfererCases(_7lh -> _7pe, 2012); %transfererCases(_7mb -> _7pf, 2012);
	%transfererCases(_7kt -> _7ph, 2012);
	%transfererCases(_7li -> _7pi, 2012); %transfererCases(_7mc -> _7pj, 2012);
	%transfererCases(_7ku -> _7pl, 2012);
	%transfererCases(_7mm -> _7mn _7lh _7mb _7kt, 2012);
	%transfererCases(_7lg -> _7li, 2012); %transfererCases(_7ma -> _7mc, 2012);
	%transfererCases(_7ks -> _7ku, 2012);
	%transfererCases(_7qz -> _7mm _7lg _7ma _7ks, 2012);
	%transfererCases(_7pz -> _7qz, 2012);
	%transfererCases(_7oz -> _7pz, 2012);

	/* Souscription au capital de sofipêche : la case _7gs disparait mais elle réapparait en 2013 avec un autre sens. Donc pas de DisparitionSimple */
	%transfererCases(_7gs -> _souscSofipeche, 2012);

	/* Revenus imposables à la CRDS : disparait mais réapparait en 2013 donc pas de DisparitionSimple */
	%transfererCases(_8tl -> _revImpCRDS, 2012);

	%disparitionSimple(anneeDisparition=2012,listeCases=
		_5hu /* RIc pro, moins-values nettes à court terme du foyer */
		_7fy _7gy _7hy _7ky /* Aides aux créateurs et aux repreneurs d'entreprises ; _7jy et _7iy sont réutilisées en 2013 
	donc on les enlève de la DisparitionSimple */
		_7sa /* cases relatives aux dépenses en faveur du développement durable pour les logements donnés en location ;
	_7sb réutilisée en 2014 doncdonc on l'enlève de DisparitionSimple */
		_7qq _7pc _7pk _7oz /*  Investissement DOM dans une entreprise */
		_9mn _9mo /* ISF */
		);

    %mend;


%Macro modificationsERFS2013();
	
	%apparitionSimple(anneeApparition=2013,listeCases=
		_2ck		/* Prélèvement forfaitaire de l'année précédente : crédit d'impôt */
		_3ve _3vv	/* Plus-values des non-résidents */
					/* 2014 : possibilité de se faire rembourser de la différence entre le PF à 45 % sur ces PV et l'imposition au barème de l'IR */
					/* Cette modification législative de 2013 n'est pas codée car non-résidents a priori hors champ d'Ines */
		_3wi _3wj	/* PV ayant fait l'objet d'un report d'imposition dans le cadre du transfert du domicile fiscal hors de France */
		_7ux _7th	/* Report de dépenses investissements forestiers en 2012 (non codé) */
		_6hm 		/* Dépenses de grosses réparation effectuees par les nus-propriétaires : report 2012 */
		_7wh 		/* Réalisation ou non d'un bouquet de travaux. Attention, cette variable avait auparavant une autre signficiation 
					(dépenses qualité environnementale) mais avait été transféré dans une autre case en 2012 */
		_8tl _8uw	/* Cases de CICE */
		_7uh		/* Dons et cotisations versés aux partis politiques (nom déjà utilisé par le passé) */
		_1fc		/* Salaires exonérés perçus à l'étranger du pac4, reçu pour la première fois cette année */
		);

	/* Revenus valeurs et capitaux mobiliers : fusion de 2 cases en 1, normalement 2 taux (21 et 24 %) mais dans Ines on mettait déjà tout à 21 % */
	/* Produits de placement à revenu fixe (dont ceux qui sont inférieurs à 2 000 € sont taxables sur option à 24 %) */
	/* Les traitements suivants suivent une discussion entre l'équipe Ines. 
		Il s'agit de prendre en compte des mécanismes de reports d'une case vers une autre en anticipant au mieux ce qu'on aura dans l'ERFS 2013. 
		Réflexion basée sur les états fiscaux, de manière à retrouver les bons ordres de grandeur, mais ce choix reste arbitraire */
	%transfererCases(_2ee _2da -> _2ee,2013);
	%transfererCases(_2tr+0.6*_2ee -> _2tr,2013);
	%transfererCases(0.4*_2ee -> _2ee,2013);
	%apparitionSimple(anneeApparition=2013,listeCases=_2fa); /* Seuls 5 % semblent opter pour l'option du PF à 24 % : on néglige */
	%disparitionSimple(anneeDisparition=2013,listeCases=_2da);

	/* Revenus exonérés de source étrangère : beaucoup plus de détail que dans la brochure précédente */
	/* ERFS 2012 : 8ti contenait les revenus perçus à l'étranger exonérés mais retenus pour le calcul du tx effectif */
	/* ERFS 2013 : 8ti est dépouillée des revenus des individus qui ne perçoivent QUE des revenus exonérés, déclarés en 1ac à 1dc */
	%transfererCases(_8ti -> _1ac _8ti,2013); /* on divise la case en deux */
	%apparitionSimple(anneeApparition=2013,listeCases=		 _1bc _1cc _1dc /* Salaires exonérés de source étrangère (_1ac géré au-dessus)*/
														_1ad _1bd _1cd _1dd /* Impôt acquitté à l'étranger */
														_1ae _1be _1ce _1de /* Frais réels de source étrangère */
														_1ag _1bg _1cg _1dg /* Nb heures payées à l'étranger dans l'année */
														_1ah _1bh _1ch _1dh /* Pensions nettes exonérées de source étrangère */
											/* 1ax à 1dx devraient être nouvelles mais portent le même nom que dans la 2042K : on ne fait rien */);

	/* Abattements pour durée de détention sur les plus-values */
	/*	1\	Droit commun : 50 % pour titres détenus depuis 2 à 8 ans, 65 % si plus de 8 ans
		2\	Renforcé : pour PME, sous conditions : 50 % entre 1 et 4 ans, 65 % entre 4 et 8 ans, 85 % au-delà
		3\	Pour départ dirigeant à la retraite : 1/3 par an après 5 ans, donc exonération totale après 8 ans
	Pour mettre des valeurs dans ces cases, on fait les hypothèses suivantes : 
		- tout est du droit commun
		- la durée de détention suit une loi uniforme sur 10 ans : dans ce cas taux moyen d'abattement =43 % : on met 40 % */
	/* NB : au regard de l'ERFS 2013, il faudrait mieux mettre un taux 30/70 pour les plus-values et 10/90 sur les moins-values, mais on ne le fait
	pas car ce serait "tricher" par rapport à la logique d'Ines, et en plus l'année 2013 est sans doute particulière sur ces revenus. 
	Une telle hypothèse augmenterait l'IR de 0,2 % (150 millions d'euros), + effet négligeable sur les CSG et CRDS sur dividendes. */
	%transfererCases(0.4*_3vg -> _3sg,2013); %transfererCases(0.6*_3vg -> _3vg,2013);
	%transfererCases(0.4*_3vh -> _3sh,2013); %transfererCases(0.6*_3vh -> _3vh,2013);
	%apparitionSimple(anneeApparition=2013,listeCases=_3sl _3sm);

	/* Investissements locatifs Scellier et Duflot */
		/* On décale tous les investissements Scellier d'un an pour les années où 
			c'est important de la faire à cause de la façon dont c'est codé dans deduc.sas */
			%transfererCases(_7na -> _7ja,2013);%transfererCases(0 -> _7na,2013);
			%transfererCases(_7nf -> _7jf,2013);%transfererCases(0 -> _7nf,2013);
			%transfererCases(_7nk -> _7jk,2013);%transfererCases(0 -> _7nk,2013);
			%transfererCases(_7np -> _7jo,2013);%transfererCases(0 -> _7np,2013);
			%transfererCases(_7nb -> _7jb,2013);%transfererCases(0 -> _7nb,2013);
			%transfererCases(_7ng -> _7jg,2013);%transfererCases(0 -> _7ng,2013);
			%transfererCases(_7nl -> _7jl,2013);%transfererCases(0 -> _7nl,2013);
			%transfererCases(_7nq -> _7jp,2013);%transfererCases(0 -> _7nq,2013);
			%transfererCases(_7nc _7nd -> _7jd,2013);%transfererCases(0 -> _7nc,2013);%transfererCases(0 -> _7nd,2013);
			%transfererCases(_7ni _7nh -> _7jh,2013);%transfererCases(0 -> _7ni,2013);%transfererCases(0 -> _7nh,2013);
			%transfererCases(_7nm _7nn -> _7jm,2013);%transfererCases(0 -> _7nm,2013);%transfererCases(0 -> _7nn,2013);
			%transfererCases(_7nr _7ns -> _7jq,2013);%transfererCases(0 -> _7nr,2013);%transfererCases(0 -> _7ns,2013);
			%transfererCases(_7ne -> _7je,2013);%transfererCases(0 -> _7ne,2013);
			%transfererCases(_7nj -> _7jj,2013);%transfererCases(0 -> _7nj,2013);
			%transfererCases(_7no -> _7jn,2013);%transfererCases(0 -> _7no,2013);
			%transfererCases(_7nt -> _7jr,2013);%transfererCases(0 -> _7nt,2013);
		/* 1	Loi de finances proroge le bénéfice RI Scellier pour achat neuf du 1/01 au 31/03/2013 si l'engagement avait été pris en 2012 */
		%apparitionSimple(anneeApparition=2013,listeCases=_7fa _7fb _7fc _7fd);
		/* 2	Reports d'investissements dans les Dom/Com (màj ici mais non codés dans deduc donc pas nécessaire) */
		%apparitionSimple(anneeApparition=2013,listeCases=_7gj _7gk _7gl _7gp _7gs _7gt _7gu _7gv _7gw _7gx);
		/* 3	Report du solde de réduction d'impôt non encore imputé (màj ici mais non codés dans deduc) */
		%apparitionSimple(anneeApparition=2013,listeCases=_7lm _7ls _7lz _7mg);

	/* Puis on code le Duflot : on choisit la règle : investissements Duflot en 2013 = idem que investissements Scellier BBC */
	%transfererCases(_7ja _7jb _7jd _7je -> _7gh,2013);
	%transfererCases(0 -> _7ja,2013); %transfererCases(0 -> _7jb,2013); %transfererCases(0 -> _7jd,2013); %transfererCases(0 -> _7je,2013);
	%transfererCases(_7jk _7jl _7jo _7jp _7jm _7jn _7jq _7jr -> _7gi,2013);
	%transfererCases(0 -> _7jk,2013); %transfererCases(0 -> _7jl,2013); %transfererCases(0 -> _7jo,2013); %transfererCases(0 -> _7jp,2013);
	%transfererCases(0 -> _7jm,2013); %transfererCases(0 -> _7jn,2013); %transfererCases(0 -> _7jq,2013); %transfererCases(0 -> _7jr,2013);

	/* Investissements destinés à la location en meublé (Censi-Bouvard) réalisés en 2013 */
	%apparitionSimple(anneeApparition=2013,listeCases=	_7jt _7ju	/* taux 2013 = 11 % comme en 2012 : pas besoin de calculs savants */
														_7jv _7jw _7jx _7jy	/* report des investissements antérieurs */
														_7iy _7jc _7ji _7js /* màj ici mais non codé dans deduc */);

	/* Travaux de restauration immobilière engagés en 2013 (Malraux) */
	%apparitionSimple(anneeApparition=2013,listeCases=_7sy _7sx); /* Taux de 2013 = ceux de 2012 (22 et 30 %) donc pas besoin de calculs savants */

	/* Dépenses de protection du patrimoine naturel (non codé dans Ines) */
	%transfererCases(_7kc -> _7kd,2013);%transfererCases(_7kb -> _7kc,2013);%transfererCases(0 -> _7kb,2013);

	/* Investissement DOM dans une entreprise */
	/* Ici il y a trop de transferts de cases à effectuer */
	/* Choix de ne faire que les transferts jugés les plus importants (au regard des masses contenues dans les cases de la "vraie" ERFS un an plus tard) */
	/* Les autres cases sont gérées par des %apparition et %disparition au lieu de %Transferts adaptés : 
	par approximation on met un peu trop de cases à zéro pour les ERFS<2013 : RED_DOM n'est pas calculé dans Deduc */
	%transfererCases(_7qa -> _hqa,2013);
	%transfererCases(_7qj -> _hra,2013); %transfererCases(_7qs -> _hrb,2013); %transfererCases(_7qw -> _hrc,2013); %transfererCases(_7qx -> _hrd,2013);
	%transfererCases(_7qb -> _hqc,2013); %transfererCases(_7ql -> _hqd,2013);
	%transfererCases(_7nu -> _hsz,2013); %transfererCases(_7nv -> _hta,2013); %transfererCases(_7nw -> _htb,2013);
	%transfererCases(_7nx -> _htc,2013); %transfererCases(_7ny -> _htd,2013);
	%apparitionSimple(anneeApparition=2013,listeCases=	_HKG _HKH _HKI _HKS _HKT _HKU _HLG _HLH _HLI _HMA _HMB _HMC _HMM
														_HMN _HNU _HNV _HNW _HNY _HOA _HOB _HOC _HOD _HOE _HOF _HOG _HOH
														_HOI _HOJ _HOK _HOL _HOM _HON _HOO _HOP _HOQ _HOR _HOS _HOT _HOU
														_HOV _HOW _HOX _HOY _HOZ _HPA _HPB _HPD _HPE _HPF _HPH _HPI _HPJ
														_HPL _HPM _HPN _HPO _HPP _HPR _HPS _HPT _HPU _HPW _HPX _HPY
														_HQB _HQE _HQF _HQG _HQI _HQJ _HQK _HQL _HQM _HQN _HQO
														_HQP _HQR _HQS _HQT _HQU _HQV _HQW _HQX _HQZ
														_HRG _HRI _HRJ _HRK _HRL _HRM _HRO _HRP _HRQ _HRR _HRT _HRU _HRV
														_HRW _HRY _HSA _HSB _HSC _HSD _HSE _HSF _HSG _HSH _HSI _HSJ _HSK
														_HSL _HSM _HSN _HSO _HSP _HSQ _HSR _HSS _HST _HSU _HSV _HSW _HSX
														_HSY);
	%disparitionSimple(anneeDisparition=2013,listeCases=_7kg _7kh _7ki _7qn _7qu _7qk
														_7qy _7qm
														_7op _7oq _7or _7os _7ot
														_7pm _7pn _7po _7pp _7pq _7pr _7ps _7pt _7pu _7pv _7pw
														_7px _7py _7ry
														_7pz _7qz _7mm _7ma _7ks _7mn _7mb _7kt
														_7mc _7ku _7qv _7qo _7qp _7qr _7qi _7pl);
	%transfererCases(0 -> _7ow,2013);/*On ne fait pas disparaitre 7OW car elle réapparaît en 2016*/
	%transfererCases(0 -> _7ok,2013);/*On ne fait pas disparaitre 7OK car elle réapparaît en 2016*/
	%transfererCases(0 -> _7ol,2013);/*On ne fait pas disparaitre 7OL car elle réapparaît en 2016*/
	%transfererCases(0 -> _7om,2013);/*On ne fait pas disparaitre 7OM car elle réapparaît en 2016*/
	%transfererCases(0 -> _7on,2013);/*On ne fait pas disparaitre 7ON car elle réapparaît en 2016*/
	%transfererCases(0 -> _7oo,2013);/*On ne fait pas disparaitre 7OO car elle réapparaît en 2016*/

	/* Plus-values réalisées par un entrepreneur taxables à 19 % */
	%transfererCases(_3sc _3wa -> _3wa,2013);
	%transfererCases(0 -> _3sc,2013);
	/* Abattement sur les plus-values pour durée de détention en cas de départ à la retraite d'un dirigeant */
    %transfererCases(_3wc _3va -> _3va,2013);
 	%transfererCases(0 -> _3wc,2013);

	/* Souscription au capital de PME en phase d'amorçage : dépenses de 2012 */
	%transfererCases(_7cq -> _7cc _7cq,2013); /* hypothèse de 50/50 pour les dépenses entre les PME en phase d'amorçage ou non */

	/* Dépenses qualité environnementale de l'habitation principale */
		/* Qu'il y ait bouquet de travaux ou non, les dépenses sont déclarées dans les mêmes cases */
	%transfererCases(_7tt -> _7sd,2013,cumulAvecArrivee=O); %transfererCases(0 -> _7tt,2013);
	%transfererCases(_7tu -> _7sm,2013,cumulAvecArrivee=O); %transfererCases(0 -> _7tu,2013);
	%transfererCases(_7tv -> _7sf,2013,cumulAvecArrivee=O); %transfererCases(0 -> _7tv,2013);
	%transfererCases(_7tw -> _7se,2013,cumulAvecArrivee=O); %transfererCases(0 -> _7tw,2013);
	%transfererCases(_7tx -> _7sn,2013,cumulAvecArrivee=O); %transfererCases(0 -> _7tx,2013);
	%transfererCases(_7ty -> _7ss,2013,cumulAvecArrivee=O); %transfererCases(0 -> _7ty,2013);
		/* Plus de distinction sur la date d'engagement des dépenses */
	%disparitionSimple(anneeDisparition=2013,listeCases=_7wf _7wq _7ws _7wu _7wx _7wa _7wb _7ve _7vf);

	/* Crédit d'impôt en faveur entreprises : débitants de tabac (la case disparaît) */
	%transfererCases(_8wv -> _CI_debitant_tabac,2013);
	%disparitionSimple(anneeDisparition=2013,listeCases=_8wv);

	/* Ascenseurs électriques à traction (dépenses engagées avant 2012) : la case disparaît mais on conserve l'information */
	%transfererCases(_7wi -> _dep_Asc_Traction,2013);

	/* Plus-values de cession de titres réalisées par un entrepreneur */
	%transfererCases(_3sa -> _PVCession_entrepreneur,2013);
	/* Pas de disparition simple car la case réapparaît en 2016 avec une autre signification */

	/* Investissements locatifs secteur touristique : reconstruction, agrandissement, réparation */
	/* 6 cases ont disparu en 2013 */
	%transfererCases(_7xg -> _depinvloctour_2011_1,2013);
	%transfererCases(_7xa -> _depinvloctour_av2011_1,2013);
	%transfererCases(_7xx -> _depinvloctour_ap2011_1,2013);
	%transfererCases(_7xh -> _depinvloctour_2011_2,2013);
	%transfererCases(_7xb -> _depinvloctour_av2011_2,2013);
	%transfererCases(_7xz -> _depinvloctour_ap2011_2,2013);
	%disparitionSimple(anneeDisparition=2013,listeCases=_7xg _7xa _7xx _7xh _7xz);

	/* Agents de l'Etat à l'étranger : suppléments de rémunération */
	%disparitionSimple(anneeDisparition=2013,listeCases=_1ty _1uy);

	/* Investissements locatifs secteur touristique : dépenses de 2012 */
	%transfererCases(_7xn -> _7uy,2013);
	%transfererCases(_7xp -> _7xn,2013);
	%transfererCases(_7xi -> _7xp,2013);
	%transfererCases(_7xf -> _7xi,2013);
	%transfererCases(0 -> _7xf,2013);

	%transfererCases(_7xv -> _7uz,2013);
	%transfererCases(_7xq -> _7xv,2013);
	%transfererCases(_7xj -> _7xq,2013);
	%transfererCases(_7xm -> _7xj,2013);
	%transfererCases(0 -> _7xm,2013);

	/* Contribution salariale : désormais un seul taux à 10 % */
	%transfererCases(_3vo _3vn _3vs -> _3vn,2013);
	%transfererCases(_3so _3sn _3ss -> _3sn,2013);
	/* Pour les anciens taux les cases disparaissent mais on garde l'info avec des
	noms explicites si l'on souhaite appliquer une vieille législation */
	%transfererCases(_3vs _3ss -> _glo_txfaible,2013);
	%transfererCases(_3vo _3so -> _glo_txmoyen,2013);
	%disparitionSimple(anneeDisparition=2013,listeCases= _3so _3vs _3ss); /* _3vo est réutilisée en 2015 donc pas de DisparitionSimple */

	/* Traitement de la fin d'exonération d'impôt des heures supplémentaires. Il peut rester des montants non nuls dans l'ERFS 2013
	mais il s'agit d'heures sup réalisées en 2012 et payées en 2013 donc imposées en 2014... */
	%transfererCases(_1au -> _hsupVous,2013);
	%transfererCases(_1bu -> _hsupConj,2013);
	%transfererCases(_1cu -> _hsupPac1,2013);
	%transfererCases(_1du -> _hsupPac2,2013);
	
	%transfererCases(_1au -> _1aj,2013,cumulAvecArrivee=O); %transfererCases(0 -> _1au,2013);
	%transfererCases(_1bu -> _1bj,2013,cumulAvecArrivee=O); %transfererCases(0 -> _1bu,2013);
	%transfererCases(_1cu -> _1cj,2013,cumulAvecArrivee=O); %transfererCases(0 -> _1cu,2013);
	%transfererCases(_1du -> _1dj,2013,cumulAvecArrivee=O); %transfererCases(0 -> _1du,2013);

	%if &anref.=2012 %then %do;
		/* heures sup : sur la déclaration des revenus 2012, il n'y a que 7 mois dans la case.
			Le contenu de _hsupVous and co sont harmonisés à 1an d'heures sup, de manière à ne pas trainer de conditions sur anref=2012
			à chaque fois que l'on manipule ces cases. On n'effectue cette transformation que si la rémunération des heures sup 
			ainsi déduite reste inférieur aux revenus déclarés */
		if _hsupVous*12/7<_1aj then _hsupVous=_hsupVous*12/7;
		if _hsupConj*12/7<_1bj then _hsupConj=_hsupConj*12/7;
		if _hsupPac1*12/7<_1cj then _hsupPac1=_hsupPac1*12/7;
		if _hsupPac2*12/7<_1dj then _hsupPac2=_hsupPac2*12/7;
		%end;
	%if &anref.=2008 %then %do;
		/* heures sup : sur la déclaration des revenus 2007, il n'y a que 3 mois dans la case. */
		if _hsupVous*12/7<_1aj then _hsupVous=_hsupVous*12/3;
		if _hsupConj*12/7<_1bj then _hsupConj=_hsupConj*12/3;
		if _hsupPac1*12/7<_1cj then _hsupPac1=_hsupPac1*12/3;
		if _hsupPac2*12/7<_1dj then _hsupPac2=_hsupPac2*12/3;
		%end;

		/*Dons à des organismes d’aide aux personnes en difficulté établis en France : non codé dans ines */
	%disparitionSimple(anneeDisparition=2013,listeCases= _7ue _7ug);  

	%Mend;


%Macro modificationsERFS2014();

	%apparitionSimple(anneeApparition=2014,listeCases=_2la _2lb); /* Régularisation des prélèvements sociaux sur
	certains produits d’assurance-vie : complément à verser */
	%disparitionSimple(anneeDisparition=2014,listeCases=_3vv); /* Plus-values réalisées par les non-résidents : 
	montant du prélèvement de 45 % versé en 2013 */
	%disparitionSimple(anneeDisparition=2014,listeCases=_1au _1bu _1cu _1du); /* pour revenus 2013 : heures 
	supplémentaires exonérées effectuées en 2012, payées en 2013 : revenus connus */
	/* Les heures supplémentaires avaient déjà été stockées dans _hsup: l'année dernière et les cases _1au à __1du mises à 0 */

	/* Les pensions d'invalidité, auparavant déclarées avec les retraites, ont maintenant leur propre case fiscale
	On ne souhaite pas cependant les distinguer des pensions de retraites avant leur arrivée dans la base (imputation
	trop complexe), on met donc les nouvelles cases à 0 par défaut. Le cas est donc traité ici comme une apparition
	simple, mais il aurait été trompeur de le présenter comme tel puisque l'information fiscale était déjà bien présente */
 	%transfererCases(_1as -> _1az _1as,2014,ponderations=2);%transfererCases(0 -> _1az,2014);
	%transfererCases(_1bs -> _1bz _1bs,2014,ponderations=2);%transfererCases(0 -> _1bz,2014);
	%transfererCases(_1cs -> _1cz _1cs,2014,ponderations=2);%transfererCases(0 -> _1cz,2014);
	%transfererCases(_1ds -> _1dz _1ds,2014,ponderations=2);%transfererCases(0 -> _1dz,2014);
	%transfererCases(_1es -> _1ez _1es,2014,ponderations=2);%transfererCases(0 -> _1ez,2014);
	 /*_1fs n'est pas dans l'ERFS par erreur (apparue en 2012 mais pas livrée depuis) mais on force son apparition simple 
	à partir de ERFS 2012, donc on fait le même traitement pour _1fz que pour _1az à _1ez */ 
	%transfererCases(_1fs -> _1fz _1fs,2014,ponderations=2);%transfererCases(0 -> _1fz,2014);

	/* Les cases correspondantes à la case fiscale des intérêts contractés pour l'acquisition de l'habitation principale lors de la 1ere annuité
	disparaissent (puisqu'il n'est mathématiquement plus possible d'être éligible au crédit dans ce cas sur les revenus 2014); on a tout de même 
	envie de garder l'info pour les ERFS précédentes donc on crée une variable au nom explicite */
	%transfererCases(_7vy -> _1annui_lgtancien,2014); /*1ere annuité Logements anciens acquis du 6.5.2007 au 30.9.2011 
	logements neufs acquis ou construits du 6.5.2007 au 31.12.2009.*/
	%transfererCases(_7vw -> _1annui_lgtneuf,2014);
	%disparitionSimple(anneeDisparition=2014,listeCases=_7vy _7vw);
	
	/* PLUS-VALUES ET GAINS DIVERS */
	/*Suppression de _3vl : distributions provenant de structures de capital risque, imposées au barème en 2014, 
	à 24% en 2013 et 19% avant (avec application d'abattement), si l'actionnaire ne s'est pas engagé à cinq ans de détention*/
	%disparitionSimple(anneeDisparition=2014,listeCases=_3vl);
	/* Plus-values des dirigeants de PME lors du départ à la retraite : nouvel abattement de 500 000€, les cases _3vg et
	_3va incluent maintenant ce nouvel abattement fixe */
	/* Apparition de la case _3ua : plus-values après abattement fixe et pour durée de détention. Cette case est quasi identique
	à _3vg sauf que _3vg inclut les autres cessions.  
	_3ua ne sert qu'à calculer l'exonération de CSG sur ces plus-values, qui n'est pas simulée dans Ines */
	%apparitionSimple(anneeApparition=2014,listeCases=_3ua); 
	/*Suppression de _3vp et _3vy : les exonérations des plus-values de cession de titres de jeunes entreprises innovantes et 
	de titres au profit d'un membre de la famille sont supprimées
	au 01.01.2014. L'abattement pour détention prolongée s'applique alors aux gains de cession de titres dans une famille*/
	%disparitionSimple(anneeDisparition=2014,listeCases=_3vp _3vy);
	/*distribution de plus-value des sociétés à capital risque pour les non résidents à 30% (on pourrait utiliser l'information 
	de _3vl avec un pourcentage mais non résidents sont hors-champ*/
	%disparitionSimple(anneeDisparition=2014,listeCases=_3uv);
	/* Transfert du domicile fiscal hors de France */
	%transfererCases(_3wa -> _3wa _3wm,2014,ponderations=2); /*plus-values en sursis de paiement : apparition de _3wm pour les
	prélèvements sociaux qu'on approxime à _3wa au montant de l'abattement près */
	%transfererCases(_3wb+_3wd-> _3wd,2014); /* _3wd, dont la valeur était égale au montant de l'abattement, devient le montant de
	la plus-value avant abattement */
	%disparitionSimple(anneeDisparition=2014,listeCases=_3wf _3wg _3wj _3wi ); /* suppression des cases correspondant aux 
	plus-values taxées à taux unique (19%) et de _3wi*/

	/* CREDITS D'IMPOTS QUALITE ENVIRONNEMENTALE */
	/* Suppression de la case indiquant si l'on a fait ou non un bouquet de travaux, que l'on souhaite conserver tout de même 
	et à laquelle on donne donc un nom explicite */
	%transfererCases(_7wh -> _bouquet_travaux, 2014); 
	/* Suppression de _7sz (la case avait été oubliée dans l'excel de suivi des modification des cases fiscales), où était 
	renseigné le montant du crédit d'impôt qualité environnementale pour les propriétaires louant le bien concerné par 
	les travaux. Ces derniers n'ont plus le droit au crédit */
	%transfererCases(_7sz -> _cred_loc, 2014); 
	/* Apparition de la case 7rx dont on ne sait pas quand elle intervient dans le calcul de l'impôt... */
	%apparitionSimple(anneeApparition=2014,listeCases=_7rx); /*Situation de famille changée + dépenses du 1er janvier au 31 aout*/
	/* 7wt, 7wc et 7vg étaient auparavant des cases à cocher si les travaux avaient été réalisés sur moins de la moitié des surfaces, elles deviennent 
	maintenant les cases dans lesquelles les dépenses sont déclarées lorsque les travaux sont réalisés sur moins de la moitié des surfaces. on stocke 
	leur information pour imputer les bonnes cases puis on supprime les variables indicatrices créées */
	%transfererCases(_7wt -> _moit_fenetres, 2014);	%transfererCases(_7wc -> _moit_murs, 2014);	%transfererCases(_7vg -> _moit_toits, 2014);
	%transfererCases(_moit_fenetres*_7sj -> _7wt, 2014); %transfererCases((1-_moit_fenetres)*_7sj -> _7sj, 2014); 
	%transfererCases(_moit_murs*_7sg -> _7wc, 2014); %transfererCases((1- _moit_murs)*_7sg -> _7sg, 2014); 
	%transfererCases(_moit_toits*_7sh -> _7vg, 2014); %transfererCases((1-_moit_toits)*_7sh -> _7sh, 2014); 
	%disparitionSimple(anneeDisparition=2014,listeCases=_moit_fenetres _moit_murs _moit_toits);
	/* Les dépenses d'appareils de chauffage au bois ne sont plus distingués entre le cas où ils remplacent un matériel existant ou non */
	%transfererCases(_7so -> _7sn,2014,cumulAvecArrivee=O); 

	/* toutes les cases où les dépenses sont déclarées sont dispatchées en deux cases cette année : une pour les dépenses 
	à partir du 1er septembre (=les nouvelles cases) et l'autre pour les dépenses avant le 31 août (les cases déjà existantes). 
	Pour pouvoir simuler correctement la législation de transition, on fait l'hypothèse que chacune 
	des dépenses se répartit de manière linéaire sur l'année (1/3 - 2/3)*/
	%transfererCases((1/3)*_7sd -> _7sa,2014); %transfererCases((2/3)*_7sd -> _7sd,2014);
	%transfererCases((1/3)*_7se -> _7sb,2014); %transfererCases((2/3)*_7se -> _7se,2014);
	%transfererCases((1/3)*_7sf -> _7sc,2014); %transfererCases((2/3)*_7sf -> _7sf,2014);
	%transfererCases((1/3)*_7wc -> _7wb,2014); %transfererCases((2/3)*_7wc -> _7wc,2014);
	%transfererCases((1/3)*_7sg -> _7rg,2014); %transfererCases((2/3)*_7sg -> _7sg,2014);
	%transfererCases((1/3)*_7vg -> _7vh,2014); %transfererCases((2/3)*_7vg -> _7vg,2014);
	%transfererCases((1/3)*_7sh -> _7rh,2014); %transfererCases((2/3)*_7sh -> _7sh,2014);
	%transfererCases((1/3)*_7si -> _7ri,2014); %transfererCases((2/3)*_7si -> _7si,2014);
	%transfererCases((1/3)*_7wt -> _7wu,2014); %transfererCases((2/3)*_7wt -> _7wt,2014);
	%transfererCases((1/3)*_7sj -> _7rj,2014); %transfererCases((2/3)*_7sj -> _7sj,2014);
	%transfererCases((1/3)*_7sk -> _7rk,2014); %transfererCases((2/3)*_7sk -> _7sk,2014);
	%transfererCases((1/3)*_7sl -> _7rl,2014); %transfererCases((2/3)*_7sl -> _7sl,2014);
	%transfererCases((1/3)*_7sn -> _7rn,2014); %transfererCases((2/3)*_7sn -> _7sn,2014);
	%transfererCases((1/3)*_7sp -> _7rp,2014); %transfererCases((2/3)*_7sp -> _7sp,2014);
	%transfererCases((1/3)*_7sr -> _7rr,2014); %transfererCases((2/3)*_7sr -> _7sr,2014);
	%transfererCases((1/3)*_7ss -> _7rs,2014); %transfererCases((2/3)*_7ss -> _7ss,2014);
	%transfererCases((1/3)*_7sq -> _7rq,2014); %transfererCases((2/3)*_7sq -> _7sq,2014);
	%transfererCases((1/3)*_7st -> _7rt,2014); %transfererCases((2/3)*_7st -> _7st,2014);
	%transfererCases((1/3)*_7sv -> _7tv,2014); %transfererCases((2/3)*_7sv -> _7sv,2014);
	%transfererCases((1/3)*_7sw -> _7tw,2014); %transfererCases((2/3)*_7sw -> _7sw,2014);
	/* Apparition de certaines cases pour des nouvelles dépenses bénéficiant du crédit */
	%apparitionSimple(anneeApparition=2014,listeCases=_7rv _7rw _7rz); /* 7rz hors champ car uniquement pour les DOM */

	/* Réduction d'impot Duflot et Pinel */
	/*7gh et 7gi sont les dépenses en Duflot en 2013 (pour metro et dom). Pour anleg 2015, ces cases ont la même signification 
	mais on a en plus deux cases pour Duflot (_7ek _7el pour metro et dom) sur les 8 premières mois de 2014 et 4 pour le 
	dispositif Pinel (metro/dom et selon taux) pour les 4 mois suivants : on remplit ces nouvelles cases au prorata mais 
	en gardant les valeurs de 7gh et 7gi. on duplique donc les montants, ce qui n'est pas classique dans init_foyer mais 
	on préfère faire l'hypothèse que chaque année il y a autant d'investissements nouveaux.
	Le dispositif Pinel comporte deux choix suivant le nombre d'année sur lequel on loue (en plus de la distinction metro/dom) 
	==> on suppose une répartition 50/50 pour le 6 ans et le 9 ans. */
	%apparitionSimple(anneeApparition=2014,listeCases=_7fi); /*on ne fait rien de particulier de cette case*/
	/*7ek à la meme signification que 7gh (prix d'acquisition pour disposotif Duflot) l'année suivante entre le 01/01 et 31/08, 
	donc on met dans la case le montant de 7gh proratisé; pareil pour les DOM pour 7gi et 7el*/
	%transfererCases(_7gh*8/12 -> _7ek, 2014); %transfererCases(_7gi*8/12 -> _7el, 2014); 
	/*le reste du prorata de 7gh et 7gi est mis dans le dispositif pinel (avec une répartition de 50/50 pour le 6 ans et le 9 ans) 
	pour le reste de l'année 2014; pareil pour les DOM*/
	%transfererCases(_7gh*4/12 -> _7qa _7qb, 2014); %transfererCases(_7gi*4/12 -> _7qc _7qd, 2014); 

	/* Investissements locatifs  loi Scellier : report concernant les investissements achevés ou acquis au cours des années antérieures
	Cette année de nouvelles années correspondantes aux report apparaissent et donc de nouvelles cases : omme les reports ne sont 
	pas codés dans deduc une apparition simple suffit */
	%apparitionSimple(anneeApparition=2014,listeCases=_7ya _7yb _7yc _7yd _7ye _7yf _7yg _7yh _7yi _7yj _7yk _7yl _7ln _7lt _7lx _7mh); 

	/* Suppression des cases _1lz et _1mz qui représentaient les salaires touchés à l'étranger, exonérés en France mais servant au calcul de la PPE 
	On considère qu'il n'est pas utile de les stocker dans une variable au nom explicite (29 observations concernées seulement) */
	%disparitionSimple(anneeDisparition=2014,listeCases=_1lz _1mz);
 
	/* REDUCTIONS ET CREDITS D'IMPOT POUR INVESTISSEMENTS FORESTIERS */
	/* _7ut était une case à cocher, en cas de travaux consécutifs à un sinistre, et devient une case où le montant 
	de ce type de travaux doit être renseigné.	On crée donc une indicatrice de manière temporaire, qui la remplace, et 
	on transfère le montant des travaux dans les cases _7up et _7ut selon le cas (respectivement sans ou après sinistre) */
	%transfererCases(_7ut -> _sinistre, 2014);	
	%transfererCases(_sinistre*_7up -> _7ut, 2014); %transfererCases((1-_sinistre)*_7up -> _7up, 2014); 
	%disparitionSimple(anneeDisparition=2014,listeCases=_sinistre);
	/* Apparition des cases _7ua, _7ub et _7ui qui correspondent à des cas particuliers de dépenses de travaux et de 
	contrat de gestion : adhésion ou non à une organisation de producteurs.
	On transfère donc la moitié de ces dépenses de travaux et de contrat dans les cases de même type de dépenses mais avec 
	adhésion à une organisation de producteur. */
	%transfererCases(_7up -> _7ua _7up, 2014); 
	%transfererCases(_7ut -> _7ub _7ut, 2014); 
	%transfererCases(_7uq -> _7ui _7uq, 2014);
	/* Pour les dépenses de travaux des années antérieures APRES SINISTRE : apparition de la case _7ti pour les dépenses de 2013. 
	Les autres cases en remontant jusqu'à 2009 sont inchangées par rapport à l'an dernier.
	On effectue donc un transfert de case d'une année sur l'autre et on met à 0 celle relative aux dépenses de 2009. 
	Ne pose pas de problème car dispositif NON CODE et case très probablement à 0 ou d'un montant très faible */ 
	%transfererCases(_7th -> _7ti, 2014); /* _7ti : nouvelle case */
	%transfererCases(_7tg -> _7th, 2014); 
	%transfererCases(_7tf -> _7tg, 2014); 
	%transfererCases(_7te -> _7tf, 2014); 
	%transfererCases(0 -> _7te, 2014); 
	
	/* Investissements locatifs dans une résidence hôtelière à vocatin sociale */
	/* On considère qu'il s'agit d'une disparition simple car dans deduc, le taux est appliqué à une somme de case indistinctement.
	C'est un dispositif qui s'éteint et la perte d'information est minime */ 
	%disparitionSimple(anneeDisparition=2014,listeCases=_7xo); 

	/* Investissements locatifs dans le secteur touristique : disparition de 7xf, on décale d'un an toutes les dépenses */
	%transfererCases(_7xn -> _7uy,2014);
	%transfererCases(_7xp -> _7xn,2014);
	%transfererCases(_7xi -> _7xp,2014);
	%transfererCases(_7xf -> _7xi,2014);
	%disparitionSimple(anneeDisparition=2014,listeCases=_7xf); 

	%transfererCases(_7xv -> _7uz,2014);
	%transfererCases(_7xq -> _7xv,2014);
	%transfererCases(_7xj -> _7xq,2014);
	%transfererCases(_7xm -> _7xj,2014);
	%disparitionSimple(anneeDisparition=2014,listeCases=_7xm); 

	/* Dépenses de protection du patrimoine naturel */
	%transfererCases(_7ka ->_protect_patnat, 2014) ; %disparitionSimple(anneeDisparition=2014,listeCases=_7ka); 
	/* Dispositif qui s'arrête à partir du 01/01/2014. Mais on souhaite le conserver pour les années antérieures, 
	d'où la création d'une variable au nom explicite */ 
	%transfererCases(_7kd ->_7ke, 2014) ; %transfererCases(_7kc ->_7kd, 2014) ; 
	%transfererCases(_7kb ->_7kc, 2014) ; %transfererCases(0 ->_7kb, 2014) ; /* Apparition de _7ke. On décale les cases. Mais pas codé. */

	/* Investissements location - Loi Censi-Bouvard */
	%apparitionSimple(anneeApparition=2014,listeCases=_7ou /*investissements réalisés en 2014 : codé dans deduc, même taux que ceux réalisés en 2013  */
													_7oa _7ob _7oc _7od _7oe 
						/* investissements achevés en 2013 : codé dans deduc, mêmes taux que ceux achevés en 2012 (en fonction de l'année de réalisation) */
													_7pa _7pb _7pc _7pd _7pe); /* report des soldes de réductions non imputées : non codé dans deduc */
	
	/* RI : souscription au capital de petites entreprises */
	%apparitionSimple(anneeApparition=2014,listeCases=_7cr _7cy); /* _7cr est une nouvelle année de report de versements, codée dans deduc. 
																	_7cy est le report de RI de l'année précédente, non codé dans deduc */
	/* Revenus d'activité et de remplacement de source étrangère soumis aux contributions sociales */
	%apparitionSimple(anneeApparition=2014,listeCases=_8sa _8sb);

	/* RI pour Investissements outre-mer dans le logement et autres secteurs d'activité et le logement social */
	%apparitionSimple(anneeApparition=2014,listeCases=_hua _hub _huc _hud _hue _huf _hug /* Investissements réalisés en 2014 (logement et autres secteurs) */
													  _hxa _hxb _hxc _hxe); /* Investissements réalisés en 2014 (logement social) */

													  /* RI : Investissements DOM dans une entreprise */
	/* Même dilemme que l'année dernière : on pourrait faire des transferts de case mais il y a beaucoup de cases et 
													  elles ne sont de toute façon pas traitées en aval */
	%apparitionSimple(anneeApparition=2014,listeCases=_haa _hab _hac _had _hae _haf _hag _hah _hai _haj _hak _hal _ham _han _hao _hap 
														_haq _har _has _hat _hau _hav _haw _hax _hay
														_hba _hbb _hbe _hbf _hbg);
	%disparitionSimple(anneeDisparition=2014,listeCases=_hsd _hsi _hsn _hss _hsx _htc _hqz); 
	/* cette dernière case concerne les investissements réalisés en 2008, elle était appelée dans deduc mais est
	supprimée du calcul qui devra de toute façon être refondu ou supprimé */
	/* dépenses de grosses réparation effectuees par les nus-propriétaires : report 2013 */																																
	%apparitionSimple(anneeApparition=2014,listeCases=_6hn);
	%disparitionSimple(anneeDisparition=2014,listeCases=_1fc); /* salaires exonérés perçus à l'étranger du pac4 qu'on n'a pas reçu finalement */ 
%Mend;

%Macro modificationsERFS2015();
	
	/* ACTIONS GRATUITES */
	/* Création de la case _1tz pour les actions gratuites attribuées après le 08/08/2015 
	La période d'acquisition minimale (1 an) fait en sorte que les gains d'acquisition des actions gratuites attribuées après 
le 08/08/2015 n'apparaitront qu'après 08/2016 
	Pour le moment on crée la case _1tz mais on la laisse à 0 */
	%apparitionSimple(anneeApparition=2015, listeCases=_1tz);
	/* Disparition des cases du dec2 pour les gains d'acquisition d'actions gratuites,  donc on fusionne avec la case du dec1
	Les trois premiers sont des gains taxables à trois taux différents, le dernier concerne les actions attribuées avant 
	16/10/07 soumis à contrib salariale 10% */
	%transfererCases(_3sd -> _3vd, 2015, cumulAvecArrivee=O); %transfererCases(_3si -> _3vi, 2015, cumulAvecArrivee=O); 
	%transfererCases(_3sf -> _3vf, 2015, cumulAvecArrivee=O); %transfererCases(_3sn -> _3vn, 2015, cumulAvecArrivee=O); 
	%disparitionSimple(anneeDisparition=2015, listeCases=_3sd _3sf _3si _3sn); 
	/* Maintenant que dec2 est regroupé avec dec1 on supprime les cases de dec2 */

	/* ASSURANCE VIE */
	/* Suppression de la case "Régularisation des prélèvements sociaux sur certains produits d’assurance-vie : complément à verser" _2la
	et de la case "Régularisation des prélèvements sociaux sur certains produits d'assurance-vie : trop versé" _2lb,
	elles n'apparaissaient que dans init_foyer et macroOrgaCases, pas d'utilisation dans Ines. */
	%disparitionSimple(anneeDisparition=2015, listeCases=_2la _2lb);

	/* CESSIONS DE VALEURS MOBILIERES */
	/* Les abattements pour durée de détention appliqués aux moins-values sont maintenant supprimés 
	On fait un transfert case pour annuler l'abattement des moins values (case _3vh) et on crée variable nom explicite 
	contenant l'abattement (_abatt_moinsval)*/
	%transfererCases(_3sh -> _3vh, 2015, cumulAvecArrivee=O); %transfererCases(_3sh -> _abatt_moinsval, 2015);
	/* De la même manière on supprime _3sm: abattement pour durée de détention renforcée appliqué sur les moins-values
	On crée la variable nom explicite _abatt_moinsval_renfor */
	%transfererCases(_3sm -> _3vh, 2015, cumulAvecArrivee=O); %transfererCases(_3sm -> _abatt_moinsval_renfor, 2015);
	/* On fait disparaitre les cases _3sh et _3sm */
	%disparitionSimple(anneeDisparition=2015, listeCases=_3sh _3sm);
	/* La case _3vb qui avant 2016 regroupait des abattements sur moins-values des dirigeants de PME contient à présent 
	des abattements sur plus values pour ces mêmes dirigeants.
	On crée une variable nom explicite pour y transférer les abattements sur moins-values, et on met _3vb à 0, car elle 
	sera remplie à partir de 2016 avec des abattements sur plus values. */
	%transfererCases(_3vb -> _abatt_moinsval_dirpme, 2015); %transfererCases(0 -> _3vb, 2015);
	/* Apparition des cases _3vo et _3vp abattement fixe et abattement pour durée de détention renforcé (plus-value 3 et 4). */
	%apparitionSimple(anneeApparition=2015, listeCases=_3vo _3vp);
	/* Apparition de la case _3sc: plus values de 2012 ou 2013 dont le report a expiré en 2015 à l'issue du délai de réinvestissement */
	%apparitionSimple(anneeApparition=2015, listeCases=_3sc);
	/* Apparition des cases _3ub, _3uo et _3up pour les plus values réalisées par les dirigeants de PME lors de leur départ à la retraite. 
	Pas d'ajout dans le reste du code car ces cases sont sommées par le déclarant dans _3vg. */
	%apparitionSimple(anneeApparition=2015, listeCases=_3ub _3uo _3up);
	
	/* SALAIRES PERCUS A L'ETRANGER */
	/* Suppression des cases impôt acquitté à l'étranger pour déclarant1 à PAC2 (cases _1ad à _1dd). 
	On soustrait ces cases à salaire perçus à l'étranger qui doivent devenir nets d'impôts (cases _1ac à _1dc). */
	%transfererCases(-_1ad -> _1ac, 2015, cumulAvecArrivee=O); %transfererCases(-_1bd -> _1bc, 2015, cumulAvecArrivee=O);
	%transfererCases(-_1cd -> _1cc, 2015, cumulAvecArrivee=O); %transfererCases(-_1dd -> _1dc, 2015, cumulAvecArrivee=O);
	/* On crée variable nom explicite pour pouvoir simuler législation précédente (notamment pour des programmes comme PPE). */
	%transfererCases(_1ad -> _impot_etr_dec1, 2015); %transfererCases(_1bd -> _impot_etr_dec2, 2015);
	%transfererCases(_1cd -> _impot_etr_pac1, 2015); %transfererCases(_1dd -> _impot_etr_pac2, 2015);
	/* Disparition des cases. */
	%disparitionSimple(anneeDisparition=2015, listeCases= _1ad _1bd _1cd _1dd);

	/* DISPARITION DE LA PPE */
	/* Suppression des cases _1ax à _1fx, cases à cocher en cas d'activité à temps plein au cours de l'année (pour le calcul de la PPE). 
	On crée variables nom explicite _tpsplein_ppe_dec1 à _tpsplein_ppe_pac2. */
	%transfererCases(_1ax -> _tpsplein_ppe_dec1, 2015); %transfererCases(_1bx -> _tpsplein_ppe_dec2, 2015);
	%transfererCases(_1cx -> _tpsplein_ppe_pac1, 2015); %transfererCases(_1dx -> _tpsplein_ppe_pac2, 2015);
	/* Disparition simple des cases, avec cases pour pac3 et 4 à rajouter ici car apparaissant dans macro_OrgaCases (mais nulle part ailleurs). */
	%disparitionSimple(anneeDisparition=2015, listeCases= _1ax _1bx _1cx _1dx _1ex _1fx);

	/* Suppression des cases _1av à _1fv, cases pour nombre d'heures travaillées(hors temps plein, pour le calcul de la PPE). 
	On crée variables nom explicite _nbheur_ppe_dec1 à _nbheur_ppe_pac2. */
	%transfererCases(_1av -> _nbheur_ppe_dec1, 2015); %transfererCases(_1bv -> _nbheur_ppe_dec2, 2015);
	%transfererCases(_1cv -> _nbheur_ppe_pac1, 2015); %transfererCases(_1dv -> _nbheur_ppe_pac2, 2015);
	/* Disparition simple des cases, avec cases pour pac3 et 4 à rajouter ici car apparaissant dans macro_OrgaCases (mais nulle part ailleurs). */
	%disparitionSimple(anneeDisparition=2015, listeCases= _1av _1bv _1cv _1dv _1ev _1fv);

	/* Suppression des cases _1bl, _1cb et _1dq montant RSA "complément d'activité" pour foyer, PAC1 et PAC2 respectivement.
	On crée variables nom explicite _rsa_compact_ppe_f _pac1 et _pac2. */
	%transfererCases(_1bl -> _rsa_compact_ppe_f, 2015); %transfererCases(_1cb -> _rsa_compact_ppe_pac1, 2015); 
	%transfererCases(_1dq -> _rsa_compact_ppe_pac2, 2015);
	/* Disparition des cases */
	%disparitionSimple(anneeDisparition=2015, listeCases= _1bl _1cb _1dq);

	/* Suppression des cases _1ag à _1dg, nombre d'heures travaillées à l'étranger (hors temps plein, pour le calcul de la PPE). 
	Variables non utilisées donc disparition simple sans création de variable nom explicite. */
	/*%disparitionSimple(anneeDisparition=2015, listeCases= _1ag _1bg _1cg _1dg);*/

	/* Pour les revenus d'activité non salariée, suppression des cases _5nw à _5pw, cases à cocher activité exercée toute l'année pour calcul de la PPE.
	On crée variables nom explicite _pro_act_annee_dec1 à pac. */
	%transfererCases(_5nw -> _pro_act_annee_dec1, 2015); %transfererCases(_5ow -> _pro_act_annee_dec2, 2015);
	%transfererCases(_5pw -> _pro_act_annee_pac, 2015); 
	/* Disparition simple des cases */
	%disparitionSimple(anneeDisparition=2015, listeCases= _5nw _5ow _5pw);
	/* Pour les revenus d'activité non salariée, suppression des cases _5nv à _5pv, nombre de jours d'exercice de l'activité pour calcul de la PPE.
	On crée variables nom explicite _pro_act_jour_dec1 à pac. */
	%transfererCases(_5nv -> _pro_act_jour_dec1, 2015); %transfererCases(_5ov -> _pro_act_jour_dec2, 2015);
	%transfererCases(_5pv -> _pro_act_jour_pac, 2015); 
	/* Disparition simple des cases */
	%disparitionSimple(anneeDisparition=2015, listeCases= _5nv _5ov _5pv);

	/* INVESTISSEMENTS OUTRE-MER */
	/* Ces cases sont juste traitées dans init_foyer et macro_OrgaCases, donc on ne fait que des apparitions et disparitions simples. */
	/* Suppression de la case _hkg, report de réductions d'impôts non imputées les années antérieures 
	(investissement réalisés en 2009 dans le logement social) */
	%disparitionSimple(anneeDisparition=2015, listeCases= _hkg);
	/* Suppression des cases _hmm _hlg _hma et _hks, investissements réalisés en 2009, réduction d'impôt pour investissement 
	dans le cadre d'une entreprise. */
	%disparitionSimple(anneeDisparition=2015, listeCases= _hmm _hlg _hma _hks);
	/* Suppression des cas _had _hai _han _has _hax et _hbf, investissements réalisés en 2014, réduction d'impôt pour investissement 
	dans le cadre d'une entreprise. */
	%disparitionSimple(anneeDisparition=2015, listeCases= _had _hai _han _has _hax _hbf);
	/* Création de l'ensemble des cases pour investissements en 2015, dans le logement et autres secteurs d'activité, apparition simple. */
	%apparitionSimple(anneeApparition=2015, listeCases= _huh _hui _huj _huk _hul _hum _hun);
	/* Création de l'ensemble des cases pour investissements en 2015, dans le logement social, apparition simple. */
	%apparitionSimple(anneeApparition=2015, listeCases= _hxf _hxg _hxh _hxi _hxk);
	/* Création de l'ensemble des cases pour investissements en 2015, dans le cadre d'une entreprise, apparition simple. */
	%apparitionSimple(anneeApparition=2015, listeCases= _hbi _hbj _hbn _hbo _hbk _hbp _hbl _hbq _hbm _hbr _hbs _hbt 
														_hbx _hby _hbu _hbz _hbv _hca _hbw _hcb _hcc _hcd _hce _hcf _hcg);
	/* Création de la case _hja, crédit d'impôt pour investissement dans les DOM dans le cadre d'une entreprise, investissement 
														réalisé dans votre entreprise */
	%apparitionSimple(anneeApparition=2015, listeCases= _hja);
	
	/* REVENUS AGRICOLES */
	/* Apparition des cases _5xt (CGA ou tireur) et _5xv (sans), régime du bénéfice réel - revenus imposables au taux marginal, pour le déclarant 1.
	Apparition des cases _5xu (CGA ou tireur) et _5xw (sans), régime du bénéfice réel - revenus imposables au taux marginal, pour le déclarant 2. 
	Ces revenus comprennent la part des benéfices qui excèdent la moyenne triennale l'année de la csession ou de la cessation d'activité,
	ou même la dernière année de l'application de la moyenne triennale en cas de reconciation à ce système.
	C'est une nouvelle case donc on fait une apparition simple. */
	%apparitionSimple(anneeApparition=2015, listeCases= _5xt _5xv _5xu _5xw);

	/* CRÉDIT D'IMPÔT TRANSITION ÉNERGÉTIQUE */
	/* 7wk, qui renseignait si l'habitation principale était une maison individuelle ou non, disparaît. L'information n'est 
	en effet plus utilisée pour le crédit d'impôt. On conserve cependant l'information dans une variable au nom explicite */
	%transfererCases(_7wk -> _maison_indivi, 2015); %disparitionSimple(anneeDisparition=2015, listeCases= _7wk);
	/* disparition de 7rx : Situation de famille changée + dépenses du 1er janvier au 31 aout. Non utilisée dans le modèle*/
	%disparitionSimple(anneeDisparition=2015, listeCases= _7rx);

	/* Dans la brochure pratique 2016, les dépenses de 2015 éligibles au CITE sont maintenant déclarées dans les cases 7aa à 7bl. Cependant, 
	si il y a eu des dépenses avant le 31 août 2014 réalisée dans le cadre d'un bouquet de travaux sur deux années (2014 et 2015), alors les dépenses 
	de 2014 doivent être déclarées dans les mêmes cases que précédemment (7sd à 7sw pour avant le 31 août et 7sa à 7rz pour après le 1er septembre) 
	et les dépenses de 2015 sont déclarées dans les cases 7ta à 7sz. Pour 7sd à 7sw et 7sa à 7rz, ça revient à un changement de signification :
	on les fusionne donc dans la nouvelle case 7aa à 7bl, qui corresponde aux anciennes cases 7sd à 7sw et 7sa à 7rz (à peu près, en réalité il n'y a pas les dépenses 
	au sein d'un bouquet qui sont dans 7ta à 7su, mais on n'est pas capable de faire la différence). Puis on recrée 7sd à 7sw et 7sa à 7rz.*/

	%apparitionSimple(anneeApparition=2015,listeCases=_7ta _7tb _7tc _7xb _7xc _7wh _7wi _7vi _7wv _7ww _7vk _7vl 
														_7tn _7tp _7tr _7ts _7tq _7tt _7tx _7ty _7ru _7su _7sm _7so _7sz);

	%transfererCases(_7sd _7sa -> _7aa, 2015);
	%transfererCases(_7se _7sb -> _7ad, 2015);
	%transfererCases(_7sf _7sc -> _7af, 2015);

	%transfererCases(_7wc _7wb _7sg _7rg -> _7ah, 2015);
	%transfererCases(_7vg _7vh _7sh _7rh -> _7ak, 2015);
	%transfererCases(_7si _7ri -> _7al, 2015);
	%transfererCases(_7wt _7wu _7sj _7rj -> _7am, 2015);
	%transfererCases(_7sk _7rk -> _7an, 2015);
	%transfererCases(_7sl _7rl -> _7aq, 2015);

	%transfererCases(_7sn _7rn -> _7ar, 2015);
	%transfererCases(_7sp _7rp -> _7av, 2015);
	%transfererCases(_7sr _7rr -> _7ax, 2015);
	%transfererCases(_7ss _7rs -> _7ay, 2015);
	%transfererCases(_7sq _7rq -> _7az, 2015);
	%transfererCases(_7st _7rt -> _7bb, 2015);

	%transfererCases(_7sv _7tv -> _7bc, 2015);
	%transfererCases(_7sw _7tw -> _7bd, 2015);
	%transfererCases(_7rv -> _7be, 2015);
	%transfererCases(_7rw -> _7bf, 2015);
	%transfererCases(_7rm -> _7bh, 2015);
	%transfererCases(_7ro -> _7bk, 2015);
	%transfererCases(_7rz -> _7bl, 2015);

	%apparitionSimple(anneeApparition=2015,listeCases=_7sd _7sa _7se _7sb _7sf _7sc _7wc _7wb _7sg _7rg _7vg _7vh _7sh _7rh _7si _7ri
														_7wt _7wu _7sj _7rj _7sk _7rk _7sl _7rl _7sn _7rn _7sp _7rp _7sr _7rr _7sq _7rq
															_7st _7rt _7sv _7tv _7sw _7tw _7rv _7rw _7rm _7ro _7rz);

	/* Réduction d'impot DUFLOT et PINEL */
	/*les cases de 2014 ne changent pas mais les cases pour 2015 sont créées pour le Pinel : pour les remplir on somme les 
	cases de l'année précédente Pinel pour une partie de l'année et Duflot pour l'autre (on suppose une répartition 50/50 pour le 6 ans et le 9 ans.)*/
	%transfererCases(_7qa _7ek*0.5-> _7qe, 2015); 
	%transfererCases(_7qb _7ek*0.5-> _7qf, 2015); 
	%transfererCases(_7qc _7el*0.5-> _7qg, 2015); 
	%transfererCases(_7qd _7el*0.5-> _7qh, 2015); 
	/*puis on fait le cas classique de décalage d'année (exemple 4 cas 3.1 du wiki)
	/*pour le Duflot les cases ne changent pas mais l'année d'achevement oui donc il faut modifier les valeurs dedans (par prorata)*/
	/*7ek à la meme signification que 7gh (prix d'acquisition pour disposotif Duflot) l'année suivante entre le 01/01 et 31/08, 
	donc on met dans la case le montant de 7gh proratisé; pareil pour les DOM pour 7fi et 7el*/
	%transfererCases(_7gh*8/12 -> _7ek, 2015); %transfererCases(_7gi*8/12 -> _7el, 2015); 
	/*le reste du prorata de 7gh et 7gi est mis dans le dispositif pinel (avec une répartition de 50/50 pour le 6 ans et le 9 ans) 
	pour le reste de l'année 2014; pareil pour les DOM*/
	%transfererCases(_7gh*4/12 -> _7qa _7qb, 2015); %transfererCases(_7gi*4/12 -> _7qc _7qd, 2015); 
	/*pour le Duflot les cases ne changent pas mais l'année d'achevement oui donc il faut modifier les valeurs dedans (par prorata)*/
	/*7ek à la meme signification que 7gh (prix d'acquisition pour disposotif Duflot) l'année suivante entre le 01/01 et 31/08, 
	donc on met dans la case le montant de 7gh proratisé; pareil pour les DOM pour 7fi et 7el*/
	/*puis on met à 0 7gh et 7gi ?? l'année dernière non*/
	%transfererCases(0 -> _7gh, 2015); 
	%transfererCases(0 -> _7gi, 2015);

	/*on crée de nouvelle case sans traitement particulier car c'est du report et on ne traite pas le report dans deduc*/
	%apparitionSimple(anneeApparition=2015,listeCases=_7ai _7bi _7ci _7di); 
	/*pour les report on fait le cas classique de décalage d'année (exemple 4 cas 3.1 du wiki), sinon les autres cases sont inchangées*/
	%transfererCases(_7fi -> _7fk, 2015);  
	%transfererCases(0 -> _7fi, 2015); 
	
	/* INVESTISSEMENTS LOCATIFS */
	/* Loi Scellier: création de l'ensemble des cases sur le report concernant les investissements de l'année 2014 cases _7ym à _7ys. 
	Apparition simple des cases. */
	%apparitionSimple(anneeApparition=2015, listeCases=_7ym _7yn _7yo _7yp _7yq _7yr _7ys);
	/* Disparition des cases concernant le report des investissements des années 2011, 2012 et 2013.
	Disparition simple des cases. */
	%disparitionSimple(anneeDisparition=2015, listeCases=_7hb _7he _7gk _7gp _7gt _7ya _7yc _7ye _7yg _7yi);
	%disparitionSimple(anneeDisparition=2015, listeCases=_7nm);
	/* Création des cases pour 2014 pour le report du solde de réduction d'impôt non encore imputé selon année de réalisation et d'achèvement.
	Apparition simple des cases. */
	%apparitionSimple(anneeApparition=2015, listeCases=_7lg _7lh _7li _7lj);

	/* Loi Censi-Bouvard */
	/* Apparition de la case _7ov, investissements réalisés en 2015 - apparition simple. */
	%apparitionSimple(anneeApparition=2015, listeCases=_7ov);
	/* Création des cases _7of à _7oj concernant les investissements achevés en 2014 et réalisés entre 2009 et 2014 - apparition simple. */
	%apparitionSimple(anneeApparition=2015, listeCases=_7of _7og _7oh _7oi _7oj);
	/* Création de l'ensemble des cases pour 2014: report du solde de réduction d'impôt non encore imputé selon 
	l'année de réalisation et d'achèvement - apparition simple. */
	%apparitionSimple(anneeApparition=2015, listeCases=_7pf _7pg _7ph _7pi _7pj);
	/* Disparition de la case _7xk : investissements locatifs dans une résidence hôtelière à vocation sociale pour l'année 2009. */
	%transfererCases(_7xk -> _deduc_invest_loc2009, 2015); %disparitionSimple(anneeDisparition=2015, listeCases=_7xk);
	
	/* Charges deductibles */
	/* Disparition des cases _6ss, _6st et _6su : rachats de cotisations retraites (resp. dec1, dec2 et pac).*/
	/* On conserve cependant l'information dans une variable au nom explicite pour les dec1 et dec2 (case nul pour les pac dans les erfs précédentes) */
	%transfererCases(_6ss -> _rachatretraite_vous, 2015); %disparitionSimple(anneeDisparition=2015, listeCases=_6ss);
	%transfererCases(_6st -> _rachatretraite_conj, 2015); %disparitionSimple(anneeDisparition=2015, listeCases=_6st);
	%disparitionSimple(anneeDisparition=2015, listeCases=_6su);

	/* dépenses de grosses réparation effectuees par les nus-propriétaires : report 2014 */																																
	%apparitionSimple(anneeApparition=2015,listeCases=_6ho);

	/* Revenus d'activité et de remplacement de source étrangère soumis aux contributions sociales */																																
	%apparitionSimple(anneeApparition=2015,listeCases=_8sc _8sw _8sx);

	/* CREDIT D'IMPOT INTERETS EMPRUNT HABITATION PRINCIPALE */
	/* La case _7vu, correspondant à la première annuité des intérêts contractés pour l'acquisition d'un logement neuf non BBC 
	entre 01/01/2011 et 30/09/2011, disparait.
	Comme en 2014 pour les cases _7vy et _7vw, on conserve l'info en créant une variable au nom explicite */
 	%transfererCases(_7vu -> _1annui_lgtneufnonBBC,2015); /*1ere annuité logements neufs non BBC acquis ou construits du 01/01/2011 et 30/09/2011 */
	%disparitionSimple(anneeDisparition=2015,listeCases=_7vu);

	/* Report de versements pour souscription au capital de petites entreprises en phase d’amorçage, de démarrage ou d’expansion réalisée à compter du 1.1.2012 */
	/* Apparition de la case _7cv pour l'année 2014 : on décale simplement d'une année */ 
	%transfererCases(_7cr -> _7cv, 2015);  
	%transfererCases(_7cq -> _7cr, 2015);
	%transfererCases(0 -> _7cq, 2015); 

	/* Souscription au capital de petites entreprises en phase d’amorçage, de démarrage ou d’expansion et de PME non cotées : 
	report de réduction d’impôt au titre du plafonnement global de l'année. NON CODE */ 
	/* Apparition de la case _7dy : décalage simple d'une année */
	%transfererCases(_7cy -> _7dy, 2015);
	%transfererCases(0 -> _7cy, 2015); 

	/* INVESTISSEMENTS FORESTIERS */
	/* Reports des dépenses de travaux des années antérieures avec adhésion à une organisation de producteurs, hors et après sinistre */
	/* On se contente d'une apparition simple car NON CODE (mais on pourrait transférer une partie des autres reports de dépenses dans ces 2 cases) */
	%apparitionSimple(anneeApparition=2015,listeCases=_7vp _7tk);
	/* Apparition d'une nouvelle année (2014) de report des dépenses de travaux après sinistre : décalage d'année simple. NON CODE */
	%transfererCases(_7ti -> _7tj, 2015);
	%transfererCases(_7th -> _7ti, 2015);
	%transfererCases(_7tg -> _7th, 2015);
	%transfererCases(_7tf -> _7tg, 2015);
	%transfererCases(_7te -> _7tf, 2015);
	%transfererCases(0 -> _7te, 2015);

	/* Aide aux créateurs et repreneurs d'entreprises : disparition du dispositif mais on conserve l'information dans des variables au nom explicite */
	%transfererCases(_7ly -> _nb_convention,2015); 
	%transfererCases(_7my -> _nb_convention_hand,2015);
	%disparitionSimple(anneeDisparition=2015,listeCases=_7ly _7my);

	/* Souscription au capital d'entreprises de presse */ 
	/* Nouveau dispositif fiscal donc apparition simple de _7bx et _7by */
	%apparitionSimple(anneeApparition=2015,listeCases=_7bx _7by);
	
%Mend;

%Macro modificationsERFS2016();

/* ======= Exemple ======= 
	%apparitionSimple(anneeApparition=2014,listeCases=_2la _2lb);
 	%transfererCases(_1as -> _1az _1as,2014,ponderations=2);%transfererCases(0 -> _1az,2014);
	%disparitionSimple(anneeDisparition=2014,listeCases=_7vy _7vw);
	
	%disparitionSimple(anneeDisparition=2014,listeCases=_moit_fenetres _moit_murs _moit_toits);
	%transfererCases(_7so -> _7sn,2014,cumulAvecArrivee=O); 
	%transfererCases((1/3)*_7sd -> _7sa,2014); %transfererCases((2/3)*_7sd -> _7sd,2014);
/* ======================= */

/* ================================================================================================================================================= */
/* On fait les modifications dans l'ordre de la note RPM du 5 avril 2018 de "Veille fiscale sur les revneus pour l'année 2016 pour ERFS et Filosofi" */
/* ================================================================================================================================================= */

/* ==================================================================================================================== */
/* I. Changements avec impact sur la formule de calcul des agrégats mais sans impact sur le contour des agrégats		*/

/* ============== 2042 ============== */

	/* Les revenus perçu par les non résidents et de sources étrangère (salaires, poensions, rentes viagères à titre onéreux
	, auparavant déclarées avec les cases de revenus correspondantes, sont désormais distingués.
	On ne souhaite pas les distinguer avant leur arrivée dans la base (imputation trop complexe), 
	on met donc les nouvelles cases à 0 par défaut. Le cas est donc traité ici comme une apparition
	simple, mais il aurait été trompeur de le présenter comme tel puisque l'information fiscale était déjà bien présente */

	/*Salaires de source française perçus par les non-résidents et salaires de source étrangère ouvrant droit à un crédit d’impôt*/
 	%transfererCases(_1aj -> _1aj _1af _1ag,2016,ponderations=3);%transfererCases(0 -> _1af,2016);%transfererCases(0 -> _1ag,2016);
 	%transfererCases(_1bj -> _1bj _1bf _1bg,2016,ponderations=3);%transfererCases(0 -> _1bf,2016);%transfererCases(0 -> _1bg,2016);
 	%transfererCases(_1cj -> _1cj _1cf _1cg,2016,ponderations=3);%transfererCases(0 -> _1cf,2016);%transfererCases(0 -> _1cg,2016);
 	%transfererCases(_1dj -> _1dj _1df _1dg,2016,ponderations=3);%transfererCases(0 -> _1df,2016);%transfererCases(0 -> _1dg,2016);
 	%transfererCases(_1ej -> _1ej _1ef _1eg,2016,ponderations=3);%transfererCases(0 -> _1ef,2016);%transfererCases(0 -> _1eg,2016);
	%transfererCases(_1fj -> _1fj _1ff _1fg,2016,ponderations=3);%transfererCases(0 -> _1ff,2016);%transfererCases(0 -> _1fg,2016);

	/*Pensions de source française perçues par les non-résidents et pensions de source étrangère ouvrant droit à un crédit d’impôt*/
 	%transfererCases(_1as -> _1as _1al _1am,2016,ponderations=3);%transfererCases(0 -> _1al,2016);%transfererCases(0 -> _1am,2016);
 	%transfererCases(_1bs -> _1bs _1bl _1bm,2016,ponderations=3);%transfererCases(0 -> _1bl,2016);%transfererCases(0 -> _1bm,2016);
 	%transfererCases(_1cs -> _1cs _1cl _1cm,2016,ponderations=3);%transfererCases(0 -> _1cl,2016);%transfererCases(0 -> _1cm,2016);
 	%transfererCases(_1ds -> _1ds _1dl _1dm,2016,ponderations=3);%transfererCases(0 -> _1dl,2016);%transfererCases(0 -> _1dm,2016);
 	%transfererCases(_1es -> _1es _1el _1em,2016,ponderations=3);%transfererCases(0 -> _1el,2016);%transfererCases(0 -> _1em,2016);
	%transfererCases(_1fs -> _1fs _1fl _1fm,2016,ponderations=3);%transfererCases(0 -> _1fl,2016);%transfererCases(0 -> _1fm,2016);
	
	/*Rentes viagères à titre onéreux. Crédit d’impôt égal à l’impôt français*/
 	%transfererCases(_1aw -> _1aw _1ar,2016,ponderations=2);%transfererCases(0 -> _1ar,2016);
	%transfererCases(_1bw -> _1bw _1br,2016,ponderations=2);%transfererCases(0 -> _1br,2016);
	%transfererCases(_1cw -> _1cw _1cr,2016,ponderations=2);%transfererCases(0 -> _1cr,2016);
	%transfererCases(_1dw -> _1dw _1dr,2016,ponderations=2);%transfererCases(0 -> _1dr,2016);


	/* Le credit d'impot n'est pas appliqué avant et on ne dispose pas du détail on fait donc une apparition simple*/
	%apparitionSimple(anneeApparition=2016,listeCases=_2tt); /*Revenus n’ouvrant pas droit à abattement : intérêts des prêts participatifs*/

	/* Non-résidents : retenue à la source prélevée en France*/
	%transfererCases(_8ta -> _8ta _8vl _8vm _8wm _8um,2016,ponderations=5);
	%transfererCases(0 -> _8vl,2016);%transfererCases(0 -> _8vm,2016);%transfererCases(0 -> _8wm,2016);%transfererCases(0 -> _8um,2016);

/* ============== 2042C ============== */

	/*Suppression des cases 1TV, 1UV, 1TW, 1UW (revenus du patrimoine : gains de levée d’options sur titres attribuées avant 
	le 28/09/2012 en cas de cession ou de conversion au porteur dans le délai d’indisponibilité entre 1 et 2 ans, ou entre 2 et 3 ans). 
	On les conserve dans des variables explicites (pourrait être utile dans le cadre du futur module patrimoine)*/
	%transfererCases(_1tv -> _glo1_2ansVous, 2016);
	%transfererCases(_1uv -> _glo1_2ansConj, 2016);
	%transfererCases(_1tw -> _glo2_3ansVous, 2016);
	%transfererCases(_1uw -> _glo2_3ansConj, 2016);
	%disparitionSimple(anneeDisparition = 2016, listeCases = _1tv _1uv _1tw _1uw);

	/*Ajout des cases 1TP et 1UP : Rabais excédentaire sur option sur titres (auparavant déclarés dans 1AJ et 1DJ)*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _1tp _1up);
	/*Ajout des cases 1NX et 1OX : Gains et distributions provenant de parts ou actions de carried interest (auparavant déclarés dans 1AJ et 1DJ)*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _1nx _1ox);
	/*Ajout des cases 1PM et 1QM : Indemnités pour préjudice moral (fraction supérieure à 1 million d'euros) (auparavant déclarés dans 1AJ et 1DJ)*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _1pm _1qm);
	
	/*Suppression de la case 3SC : Plus-values de 2012 ou 2013 non réinvesties dont le délai de réinvestissement venait à expiration en 2015.
	Cette case correspond à une partie de 3sb, déclarée dans une case distincte pour les revenus 2015. Pour le passage de 2015 à 2016, ça correspond
	donc à une fusion de cases.*/
	%transfererCases(_3sc _3sb -> _3sb, 2016);
	%disparitionSimple(anneeDisparition = 2016, listeCases = _3sc);

	/*Plus-values en report d’imposition réalisé en 2016 (avant abattement) mis dans avant et après abattement*/
	%transfererCases(_3wh -> _3wg _3wh, 2016,ponderations=2); /*pas d'hypothèse sur l'abattement*/
	/*Ajout de la case 3SA : Plus-values en report d’imposition : plus-values dont le report a expiré en 2016 (avant abattement)*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _3sa);

	/*Ajout des cases 3WN et 3WO : Plus-values réalisées à partir du 1.1.2013 : plus-values avant abattement (plus-value1 et plus-values2)*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _3wn _3wo);
	/*Ajout des cases 3Wi et 3Wj : plus-values dont le report a expiré en 2016 realisé au 14/11/2012 au 31/12/2012*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _3wi _3wj);
	/*plus-values dont le report a expiré en 2016 réalisé à compté de 2013 autres*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _3wp _3wq _3wr _3ws _3wt _3wu);
	/*Plus-values de cession de titres d'OPC monétaires*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _3tz _3uz);


/* ============== 2042C Pro ============== */

	/* Revenus agricoles */
	%transfererCases(_5hn -> _5xa, 2016);
	%transfererCases(_5in -> _5ya, 2016);
	%transfererCases(_5jn -> _5za, 2016);
	
	%transfererCases((_5ho/(1-0.87)) -> _5xb,2016);
	%transfererCases((_5io/(1-0.87)) -> _5yb,2016);
	%transfererCases((_5jo/(1-0.87)) -> _5zb,2016);

	%disparitionSimple(anneeDisparition = 2016, listeCases = _5hn _5in _5jn);

	%transfererCases(_5hw -> _5hw _5xo, 2016,ponderations=2);%transfererCases(0 -> _5xo,2016);
	%transfererCases(_5iw -> _5iw _5yo, 2016,ponderations=2);%transfererCases(0 -> _5yo,2016);
	%transfererCases(_5jw -> _5jw _5zo, 2016,ponderations=2);%transfererCases(0 -> _5zo,2016);

	%transfererCases(_5hx -> _5hx _5xn, 2016,ponderations=2);%transfererCases(0 -> _5xn,2016);
	%transfererCases(_5ix -> _5ix _5yn, 2016,ponderations=2);%transfererCases(0 -> _5yn,2016);
	%transfererCases(_5jx -> _5jx _5zn, 2016,ponderations=2);%transfererCases(0 -> _5zn,2016);

	%transfererCases(_5hc -> _5hc _5ak, 2016,ponderations=2);%transfererCases(0 -> _5ak,2016);
	%transfererCases(_5hi -> _5hi _5al, 2016,ponderations=2);%transfererCases(0 -> _5al,2016);
	%transfererCases(_5ic -> _5ic _5bk, 2016,ponderations=2);%transfererCases(0 -> _5bk,2016);
	%transfererCases(_5ii -> _5ii _5bl, 2016,ponderations=2);%transfererCases(0 -> _5bl,2016);
	%transfererCases(_5jc -> _5jc _5ck, 2016,ponderations=2);%transfererCases(0 -> _5ck,2016);
	%transfererCases(_5ji -> _5ji _5cl, 2016,ponderations=2);%transfererCases(0 -> _5cl,2016);

	/* Revenus industriels */

	/*Fusion des cases 5HA, 5KA, 5IA, 5LA, 5JA et 5MA (locations meublées professionnelles) dans les cases 5KC à 5MI
	  	  et des cases 5QA, 5QJ, 5RA, 5RJ, 5SA et 5SJ (locations meublées, déficit)			dans les cases 5KF à 5ML*/
	%transfererCases(_5ha _5kc -> _5kc, 2016);
	%transfererCases(_5ka _5ki -> _5ki, 2016);
	%transfererCases(_5ia _5lc -> _5lc, 2016);
	%transfererCases(_5la _5li -> _5li, 2016);
	%transfererCases(_5ja _5mc -> _5mc, 2016);
	%transfererCases(_5ma _5mi -> _5mi, 2016);

	%transfererCases(_5qa _5kf -> _5kf, 2016);
	%transfererCases(_5qj _5kl -> _5kl, 2016);
	%transfererCases(_5ra _5lf -> _5lf, 2016);
	%transfererCases(_5rj _5ll -> _5ll, 2016);
	%transfererCases(_5sa _5mf -> _5mf, 2016);
	%transfererCases(_5sj _5ml -> _5ml, 2016);

	%disparitionSimple(anneeDisparition = 2016, listeCases = _5ha _5ka _5ia _5la _5ja _5ma _5qa _5qj _5ra _5rj _5sa _5sj);

	/*Ajout des cases 5DF, 5DG, 5EF, 5EG, 5FF et 5FG : revenus imposables de source étrangère, ouvrant droit à un crédit 
	d'impôt égal à l'impôt français et revenus de source française perçus par les non-résidents.
	Ces cases étaient dans les cases 5KC à 5MI avant*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5df _5dg _5ef _5eg _5ff _5fg);

	/*Ajout des cases 5EY, 5EZ, 5FY, 5FZ, 5GY et 5GZ : revenus imposables de source étrangère, ouvrant droit à un crédit 
	d'impôt égal à l'impôt français.
	Ces cases étaient dans les cases 5NA à 5PK avant*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5ey _5ez _5fy _5fz _5gy _5gz);

	/*Ajout des cases 5UR, 5US, 5VR, 5VS, 5WR et 5WS : dans le régime du bénéfice réel, revenus imposables de source étrangère, 
	ouvrant droit à un crédit d'impôt égal à l'impôt français et revenus de source française perçus par les non-résidents*/
	/*Ces cases étaient dans les cases 5NC à 5PI avant*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5ur _5us _5vr _5vs _5wr _5ws);

	/*Ajout des cases 5XJ, 5XK, 5YJ, 5YK, 5ZJ et 5ZK : sous le régime de la déclaration contrôlée (correspond au régime réel 
	d’imposition des professionnels qui exercent une activité BNC et qui ne relève pas du régime micro), revenus imposables de source étrangère, 
	ouvrant droit à un crédit d'impôt égal à l'impôt français et revenus de source française perçus par les non-résidents*/
	/*Ces cases étaient dans les cases 5QC à 5SI avant*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5xj _5xk _5yj _5yk _5zj _5zk);

	/*Ajout des cases 5XS, 5XX, 5YS, 5YX, 5ZS et 5ZX : dsous le régime de la déclaration contrôlée, revenus imposables de source étrangère,
	ouvrant droit à un crédit d'impôt égal à l'impôt français et revenus de source française perçus par les non-résidents*/
	/*Ces cases étaient dans les cases 5JG à 5OS avant*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5xs _5xx _5ys _5yx _5zs _5zx);

	/*Ajout des cases 5RZ et 5SZ : Moins-values nettes à court terme (pour le déclarant 2 et les personnes à charge)*/
	/*5IU, qui était pour tout le foyer, devient la case du declarant 1. On fait l'hypothèse que les déclarants 1 et 2
	se partagent la case du foyer*/
	/*Dans la partie "autres revenus industriels et commerciaux non professionnels"*/
	%transfererCases(_5iu -> _5rz _5iu, 2016);
	%apparitionSimple(anneeApparition = 2016, listeCases = _5sz);
	/*Idem pour _5ju, _5ld, _5md, équivalent à _5iu, _5rz et _5sz pour la partie "Revenus non commerciaux non professionnels"*/
	%transfererCases(_5ju -> _5ld _5ju, 2016);
	%apparitionSimple(anneeApparition = 2016, listeCases = _5md);

/* ==================================================================================================================== */
/* III. Pour information																								*/

/* ============== 2042 ============== */

	/* Créations de cases contenant de l'information déjà présente dans d'autres cases :
	- 1GA, 1HA, 1IA, 1JA, 1KA et 1LA -> Abattement forfaitaire : assistants maternels et journalistes -> Déjà comptabilisé dans 1AJ à 1FJ
	- 4BK							 -> Micro-foncier. Recette brutes sans abattement...			  -> Déjà comptabilisé dans 4BE
	- 4BL							 -> Revenus fonciers imposables : dont revenus...				  -> Déjà comptabilisé dans 4BA */
	%apparitionSimple(anneeApparition = 2016, listeCases = _1ga _1ha _1ia _1ja _1ka _1la _4bk _4bl);

	/* Création de cases à cocher pour préparer le prélèvement à la source : 4BN, 8VA, 8VB */
	%apparitionSimple(anneeApparition = 2016, listeCases = _4bn _8va _8vb);

/* ============== 2042 RICI ============== */

	/* Modifications pour la déclaration des dépenses éligibles au CITE */
	/* Dans la déclaration de 2015, il y a avait 4 cases pour chaque type de dépenses :
	   -	7AA à 7BL : dépenses éligibles au CITE en 2015 (sauf si c’est dans le cadre d’un bouquet de travaux sur 2 ans)
	   -	7SD à 7SW : dépenses éligibles au CITE début 2014 dans le cadre d’un bouquet de travaux sur 2 ans
	   -	7SA à 7RZ : dépenses éligibles au CITE fin 2014 dans le cadre d’un bouquet de travaux sur 2 ans
	   -	7TA à 7SZ : dépenses éligibles au CITE en 2015 dans le cadre d’un bouquet de travaux sur 2 ans
	   Dans la déclaration 2016, les 3 dernières catégories sont supprimées, ne restent que 7AA à 7BL, qui correspondent à la fusion 
		de 7AA à 7BL et 7TA à 7SZ*/


	%transfererCases(_7ta _7aa -> _7aa, 2016);
	%transfererCases(_7tb _7ad -> _7ad, 2016);
	%transfererCases(_7tc _7af -> _7af, 2016);

	%transfererCases(_7xb _7xc _7ah -> _7ah, 2016);
	%transfererCases(_7wh _7wi _7ak -> _7ak, 2016);
	%transfererCases(_7vi _7al -> _7al, 2016);
	%transfererCases(_7wv _7ww _7am -> _7am, 2016);
	%transfererCases(_7vk _7an -> _7an, 2016);
	%transfererCases(_7vl _7aq -> _7aq, 2016);

	%transfererCases(_7tn _7ar -> _7ar, 2016);
	%transfererCases(_7tp _7av -> _7av, 2016);
	%transfererCases(_7tr _7ax -> _7ax, 2016);
	%transfererCases(_7ts _7ay -> _7ay, 2016);
	%transfererCases(_7tq _7az -> _7az, 2016);
	%transfererCases(_7tt _7bb -> _7bb, 2016);

	%transfererCases(_7tx _7bc -> _7bc, 2016);
	%transfererCases(_7ty _7bd -> _7bd, 2016);
	%transfererCases(_7ru _7be -> _7be, 2016);
	%transfererCases(_7su _7bf -> _7bf, 2016);
	%transfererCases(_7sm _7bh -> _7bh, 2016);
	%transfererCases(_7so _7bk -> _7bk, 2016);
	%transfererCases(_7sz _7bl -> _7bl, 2016);

	%disparitionSimple(anneeDisparition = 2016, listeCases = _7sd _7sa _7ta
															 _7se _7sb _7tb
															 _7sf _7sc _7tc
															 _7wc _7wb _7xb
															 _7sg _7rg _7xc
															 _7vg _7vh _7wh
															 _7sh _7rh _7wi
															 _7si _7ri _7vi
															 _7wt _7wu _7wv
															 _7sj _7rj _7ww
															 _7sk _7rk _7vk
															 _7sl _7rl _7vl
															 _7sn _7rn _7tn
															 _7sp _7rp _7tp
															 _7sr _7rr _7tr
															 _7ss _7rs _7ts
															 _7sq _7rq _7tq
															 _7st _7rt _7tt
															 _7sv _7tv _7tx
															 _7sw _7tw _7ty
															 	  _7rv _7ru
															 	  _7rw _7su
															 	  _7rm _7sm
															 	  _7ro _7so
															 	  _7rz _7sz);
	
	/*Création de : 
		7CB, dépenses pour les chaudières à haute performance énergétique, nouvelle dépense éligible au CITE
		7BM, dépenses énergie éolienne avant le 1.1.2016). Dépense qui était auparavant éligible et incluse 
		dans 7BB, qui ne l’est plus. La nouvelle case concerne les dépenses pour lesquelles le devis a été signé 
		avant 2016 qui restent éligibles. La case disparaît dans la déclaration	des revenus 2017 donc on ne l’ajoute pas
		dans le champ du CITE dans deduc*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7cb _7bm);

	/*Suppression de la case 7VV : intérêts des emprunts contractés pour l’acquisition ou la construction de l’habitation principale 
	pour les logements neufs non BBC acquis ou construits du 1.1.2010 au 31.12.2010. On conserve l'info dans une variable explicite.*/
	%transfererCases(_7vv -> _nonBBC_2010, 2016); 
	%disparitionSimple(anneeDisparition = 2016, listeCases = _7vv);

	/*Création des cases 7ZW, 7ZX, 7ZY et 7ZZ : Aide à la personne, dépenses retenues respectivement pour 2014, 2013, 2012 et 2011 
	  (non répertoriées dans la brochure pratique, 
	   mais cases toujours nulles dans l'erfs 2016, on utilise les cases 7wj, 7wl et 7wr pour le crédit d'impot de l'année) */
	%apparitionSimple(anneeApparition = 2016, listeCases = _7zw _7zx _7zy _7zz);

/* ============== 2042C ============== */

	/*Ajout des cases 1UZ et 1VZ : abattements sur les gains d'acquisition d'actions gratuites attribuées à partir du 8.8.15.
	Rien à faire dans le modèle car 1TZ (le montant des gains d'acquisition d'actions gratuites attribuées à partir du 8.8.15)
	tient compte de ces abattements*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _1uz _1vz);

	/*Ajout de la case 2TU : Pertes en capital sur prêts participatifs. Déjà déduit de la case 2TT (intérêts des prêts participatifs)*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _2tu);

	/*Ajout des cases 3TA et 3TB : IR et CEHR sur les plus-values et créances dont l’imposition est en sursis de paiement 
	ou ne bénéficie pas de sursis de paiement dans le cas d’un transfert du domicile fiscal hors de France*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _3ta _3tb);

	/*Ajout de la case 6HP : dépenses de grosses réparation effectuees par les nus-propriétaires (report 2015) */																																
	%apparitionSimple(anneeApparition = 2016, listeCases = _6hp);

	/*Loi Pinel*/

	/*Ajout des cases 7QI, 7QJ, 7QK et 7QL dans le cadre de la prorogation de la loi Pinel (décalage d'année, ce sont les 
	cases pour les investissements N-1, donc équivalentes à 7QE, 7QF, 7QG, 7QH dans l'ERFS 2015)*/
	%transfererCases(_7qe -> _7qi, 2016); 
	%transfererCases(_7qf -> _7qj, 2016); 
	%transfererCases(_7qg -> _7qk, 2016); 
	%transfererCases(_7qh -> _7ql, 2016); 
	/*Du coup 7QE, 7QF, 7QG, 7QH deviennent dans l'ERFS 2016 les investissements N-2 (contre N-1 dans l'ERFS 2015). 
	Pour ça on prend les cases 7QA à 7QD pour une partie de l'année et Duflot pour l'autre, 
	en supposant une répartition 50/50 pour le 6 ans et le 9 ans (même traitement que dans la macro 2015)*/
	%transfererCases(_7qa _7ek*0.5-> _7qe, 2016); 
	%transfererCases(_7qb _7ek*0.5-> _7qf, 2016); 
	%transfererCases(_7qc _7el*0.5-> _7qg, 2016); 
	%transfererCases(_7qd _7el*0.5-> _7qh, 2016); 
	/*Pour 7QA à 7QD (investissements N-3 pour une partie de l'année), on utilise l'information des cases 7GH et 7GI (loi Duflot)
	(même traitement que dans la macro 2015)*/
	%transfererCases(_7gh*4/12 -> _7qa _7qb, 2016); 
	%transfererCases(_7gi*4/12 -> _7qc _7qd, 2016); 

	/*Ajout des cases 7BZ, 7CZ, 7DZ et 7EZ. Idem, décalage d'années*/
	%transfererCases(_7ai -> _7bz, 2016); 
	%transfererCases(_7bi -> _7cz, 2016); 
	%transfererCases(_7ci -> _7dz, 2016); 
	%transfererCases(_7di -> _7ez, 2016); 
	/*Dans l'idéal il faudrait imputer des montants pour les cases 7ai à 7di, mais comme on n'a pas d'information nous permettant
	de le faire on fait une apparition simple*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7ai _7bi _7ci _7di);

	/*Loi Duflot*/

	/*Décalage d'année pour les cases 7GH/7GI et 7EK/7EL (exactement la même situation que dans la macro 2015)*/
	%transfererCases(_7gh*8/12 -> _7ek, 2016); 
	%transfererCases(_7gi*8/12 -> _7el, 2016); 
	/*Pour les cases 7GH/7GI (investissements réalisés en N-4), on ne peut pas trop faire d'imputation, on fait une apparition simple*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7gh _7gi);
	/*Pour les reports des années précédentes, apparition de 7FR et décalage d'année classique*/
	%transfererCases(_7fk -> _7fr, 2016); 
	%transfererCases(_7fi -> _7fk, 2016);  
	%apparitionSimple(anneeApparition = 2016, listeCases = _7fi);

	/*Loi Scellier*/

	/*Suppression des cases des investissements réalisés en 2009 et achevés en 2015. On fait une disparition simple. 
	Remarque : normalement il s’agit plutôt d’un décalage d’année (ce sont les investissements N-7, qui en version 
	revenus 2016 devraient donc être remplacés par les investissements réalisés en 2010 achevés en 2016, i.e. 7HJ, 7HK, 7HN, 7HO), 
	mais ça n’a pas été traité comme ça les années précédentes, je ne modifie pas (de toute façon c’est l’ancien dispositif, 
	remplacé par les lois Duflot puis Pinel, et il n’est pas codé précisément dans Ines).*/
	%disparitionSimple(anneeDisparition = 2016, listeCases = _7hl _7hm);
	/*Création de l’ensemble des cases sur le report concernant les investissements de l’année 2015 (7YT, 7YU, 7YV, 7YW, 7YX, 7YY et 7YZ). 
	Idem, on ne fait pas le décalage d’années, on fait juste une apparition simple comme les années précédentes (les reports ne sont 
	pas du tout codés dans deduc).*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7yt _7yu _7yv _7yw _7yx _7yy _7yz);
	/*Suppression des cases 7HG et 7HH (report des réductions pour les investissements achevés en 2011 en Polynésie française, 
	Nouvelle Calédonie, dans les îles Wallis et Futuna)*/
	%disparitionSimple(anneeDisparition = 2016, listeCases = _7hg _7hh);
	/*Report du solde de réduction d’impôt non encore imputé selon l’année de réalisation et d’achèvement (pas pris en compte dans Ines) : 
	ajout de cases pour 2015 (7LK, 7LL, 7LO, 7LP) et suppression de 7LA pour 2009*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7lk _7ll _7lo _7lp);
	%disparitionSimple(anneeDisparition = 2016, listeCases = _7la);
	/*Création des cases 7ZA, 7ZB, 7ZC et 7ZD : complément de réduction d’impôt : prorogation triennale en 2016 de l’engagement 
	de location dans le secteur intermédiaire : Investissements réalisés et achevés en 2011 en Polynésie française, Nouvelle Calédonie, 
	dans les îles Wallis et Futuna. On fait une apparitionSimple et on n’en tient pas compte deduc (ça semble assez marginal)*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7za _7zb _7zc _7zd);
	/*Suppression de la case : investissement réalisé du 01/02/2011 au 31/03/2011 enPolynésie française, Nouvelle-Calédonie, Wallis et Futuna*/
	%disparitionSimple(anneeDisparition=2016, listeCases=_7ns);

	/*Loi Censi-Bouvard*/

	/*Création de la case 7OW pour les investissements réalisés en 2016 et suppression de 7IO pour ceux de 2009. C’est un décalage d’années,
	et il faut donc décaler toutes les cases (de N-7 à N-1) d'une année.
	Remarque : Dans les macros des années précédentes l'apparition de la case N-1 était traitée comme une apparition simple.*/
	%transfererCases(_7ov -> _7ow, 2016); /*N-1*/
	%transfererCases(_7ou -> _7ov, 2016); /*N-2*/
	%transfererCases(_7jt _7ju -> _7ou, 2016); /*N-3*/
	%transfererCases(_7id _7if -> _7jt, 2016); /*N-4. Pour les cases 7IF et 7IG, on met arbitrairement 7IF avec  7ID et 7IG avec 7IE*/ 
	%transfererCases(_7ie _7ig -> _7ju, 2016); /*N-4*/
	%transfererCases(_7ij -> _7id, 2016); /*N-5*/
	%transfererCases(_7in -> _7if, 2016); /*N-5*/
	%transfererCases(_7iv -> _7ig, 2016); /*N-5*/
	%transfererCases(_7iw -> _7ij _7in, 2016); /*N-6. On met arbitrairement 7iw (resp. 7im) à 50 % dans 7ij (7il) et à 50 % dans 7in (7iv) */
	%transfererCases(_7im -> _7il _7iv, 2016); /*N-6*/
	%transfererCases(_7io -> _7iw _7im, 2016); /*N-7. On suppose que 50 % des investissements ont une promesse d'achat en N-8 (7IW), et 50 % en N-7 (7IM)*/
	%disparitionSimple(anneeDisparition = 2016, listeCases = _7io);

	/* Création des cases 7OK, 7OL, 7OM, 7ON et 7OO : les investissements achevés en 2015 (report de 1/9 de la réduction d'impôt) et réalisés de 2009 à 2015.
	On fait aussi un décalage d'années. 
	Remarque : Ici aussi dans les macros des années précédentes c'est traité avec une apparition simple.*/

	/*Investissements achevés en N-2*/
	%transfererCases(_7of _7og -> _7ok, 2016); /*Réalisés en N-2, N-3 ou N-4*/
	%transfererCases(_7oh -> _7ol, 2016); /*Réalisés en N-5*/
	%transfererCases(_7oi -> _7om, 2016); /*Réalisés en N-6*/
	%transfererCases(_7oj -> _7on, 2016); /*Réalisés en N-7*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7oo); /*Réalisés en N-8. Pour ceux là on n'a pas d'info à décaler de l'année précédente.*/
	/*Investissements achevés en N-3*/
	%transfererCases(_7oa _7ob -> _7of, 2016); /*Réalisés en N-3 ou N-4*/
	%transfererCases(_7oc -> _7og, 2016); /*Réalisés en N-5*/
	%transfererCases(_7od -> _7oh, 2016); /*Réalisés en N-6*/
	%transfererCases(_7oe -> _7oi, 2016); /*Réalisés en N-7*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7oj); /*Réalisés en N-8. Pour ceux là on n'a pas d'info à décaler de l'année précédente.*/
	/*Investissements achevés en N-4*/
	%transfererCases(_7jv -> _7oa, 2016); /*Réalisés en N-4*/
	%transfererCases(_7jw -> _7ob, 2016); /*Réalisés en N-5*/
	%transfererCases(_7jx -> _7oc, 2016); /*Réalisés en N-6*/
	%transfererCases(_7jy -> _7od, 2016); /*Réalisés en N-7*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7oe); /*Réalisés en N-8. Pour ceux là on n'a pas d'info à décaler de l'année précédente.*/
	/*Investissements achevés en N-5*/
	%transfererCases(_7ia -> _7jv, 2016); /*Réalisés en N-5*/
	%transfererCases(_7ib -> _7jw, 2016); /*Réalisés en N-6*/
	%transfererCases(_7ic -> _7jx, 2016); /*Réalisés en N-7*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7jy); /*Réalisés en N-8. Pour ceux là on n'a pas d'info à décaler de l'année précédente.*/
	/*Investissements achevés en N-6*/
	%transfererCases(_7ip -> _7ia, 2016); /*Réalisés en N-6*/
	%transfererCases(_7ir _7iq -> _7ib, 2016); /*Réalisés en N-7*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7ic); /*Réalisés en N-8. Pour ceux là on n'a pas d'info à décaler de l'année précédente.*/
	/*Investissements achevés en N-7*/
	%transfererCases(_7ik -> _7ir _7iq _7ip, 2016); /*Réalisés en N-7; On suppose 33%/33%/33%*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7ic); /*Réalisés en N-8. Pour ceux là on n'a pas d'info à décaler de l'année précédente.*/
	/*Investissements achevés en N-8*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7ik); /*Réalisés en N-8. Pour ceux là on n'a pas d'info à décaler de l'année précédente.*/

	/*Création des cases pour 2015 pour le report du solde de réduction d’impôt non encore imputé selon l’année de réalisation et d’achèvement 
	(7PK, 7PL, 7PM, 7PN et 7PO) + suppression de la case 7IS de report du solde de réduction d’impôt de l’année 2009. 
	En théorie ce sont à nouveau des décalages d’année, mais ces réductions ne sont pas codées dans Ines donc on se contente 
	d’apparitions/disparitions simples*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7pk _7pl _7pm _7pn _7po);
	%disparitionSimple(anneeDisparition = 2016, listeCases = _7is);

	/*Loi Malraux*/

	/*Création des cases pour les actions engagées après le 9.7.2016 (N-1) (7NX et 7NY). Les critères pour entrer dans le champ de la réduction d'impôt
	semblent différents avant et après juillet 2016 (ZPPAUP/AMVAP vs. PSVM), mais on fait l'hypothèse que ce sont les mêmes - ce sont les mêmes
	taux qui s'appliquent à 7sy et 7nx (30 %) et à 7sx et 7ny (22 %).*/
	%transfererCases(1/6*_7sy -> _7nx, 2016);
	%transfererCases(1/6*_7sx -> _7ny, 2016);
	/*Suppression des cases pour les actions engagées avant et en 2011 (7RD, 7RB, 7RC et 7RA) + décalage d'années pour les autres cases*/
	%transfererCases(_7rf 5/6*_7sy -> _7sy, 2016); /*Opérations engagées à compter de N-4 jusqu'au 8 juillet N-1. Le coeff 5/6 sert à ne pas compter la partie après juillet N-1*/
	%transfererCases(_7re 5/6*_7sx -> _7sx, 2016); /*Opérations engagées à compter de N-4 jusqu'au 8 juillet N-1. Le coeff 5/6 sert à ne pas compter la partie après juillet N-1*/
	%transfererCases(_7rb -> _7rf, 2016); /*Opérations engagées en N-5*/
	%transfererCases(_7ra -> _7re, 2016); /*Opérations engagées en N-5*/
	%disparitionSimple(anneeDisparition = 2016, listeCases = _7rd _7rb _7rc _7ra);

	/*Investissements locatifs dans le secteur touristique : Suppression du report des dépenses des années antérieures 
	pour acquisition ou réhabilitation d’un logement en 2009 (7XI et 7XJ) + Décalage pour les autres années*/
	%transfererCases(_7xn -> _7uy, 2016); /*N-5*/
	%transfererCases(_7xv -> _7uz, 2016); /*N-5*/
	%transfererCases(_7xp -> _7xn, 2016); /*N-4*/
	%transfererCases(_7xq -> _7xv, 2016); /*N-4*/
	%transfererCases(_7xi -> _7xp, 2016); /*N-3*/
	%transfererCases(_7xj -> _7xq, 2016); /*N-3*/
	%disparitionSimple(anneeDisparition = 2016, listeCases = _7xi _7xj);

	/*Investissements locatifs dans une résidence hôtelière à vocation sociale : Suppression de la case 7XR du report des dépenses de l’année 2010.*/
	%disparitionSimple(anneeDisparition = 2016, listeCases = _7xr);

	/*Investissements forestiers : reports des dépenses, décalage d'années*/
	%transfererCases(_7ux -> _7vm, 2016); /*N-2*/
	%transfererCases(_7vp -> _7vn, 2016); /*N-2*/
	%transfererCases(_7tj -> _7tm, 2016); /*N-2*/
	%transfererCases(_7tk -> _7to, 2016); /*N-2*/
	%transfererCases(_7uw -> _7ux _7vp, 2016); /*N-3, on fait l'hypothèse 50/50. Attention c'est bien 7uw et pas 7uv.*/
	%transfererCases(_7ti -> _7tj _7tk, 2016); /*N-3, on fait l'hypothèse 50/50*/
	%transfererCases(_7th -> _7ti, 2016); /*N-4*/
	%transfererCases(_7tg -> _7th, 2016); /*N-5*/
	%transfererCases(_7tf -> _7tg, 2016); /*N-6*/
	%transfererCases(_7te -> _7tf, 2016); /*N-7*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7te); /*N-8*/
	%disparitionSimple(anneeDisparition = 2016, listeCases = _7uw);

	/*Souscription au capital de petites et moyennes entreprises, report des années antérieures. Décalage d'années.*/
	%transfererCases(_7cv -> _7cx, 2016); /*N-1*/
	%transfererCases(_7cr -> _7cv, 2016); /*N-2*/
	%transfererCases(_7cq -> _7cr, 2016); /*N-3*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7cq); /*N-4*/
	%transfererCases(_7dy -> _7ey, 2016); /*N-1*/
	%transfererCases(_7cy -> _7dy, 2016); /*N-2*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _7cy); /*N-3*/

	/*Souscription au capital d'entreprises de presse, création des cases 7mx, 7my*/
	%transfererCases(1.5/12*_7bx -> _7mx, 2016);
	%transfererCases(10.5/12*_7bx -> _7bx, 2016);
	%transfererCases(1.5/12*_7by -> _7my, 2016);
	%transfererCases(10.5/12*_7by -> _7by, 2016);

	/*plus-values en report*/



/* ============== 2042C PRO ============== */

	/*Ajout des cases sur la "Durée de l’exercice"*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5ad _5bd); /*Revenus agricoles*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5db _5eb); /*Revenus industriels et commerciaux*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5cd _5dd); /*Revenus des locations meublées non professionnelles*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5up _5vp); /*Autres revenus industriels et commerciaux non professionnels*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5xi _5yi); /*Revenus non commerciaux professionnels*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5xr _5yr); /*Revenus non commerciaux non professionnels*/

	/*Ajout des cases "Cession ou cessation d’activité en 2016" (cases à cocher)*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5af _5ai); /*Revenus agricoles*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5bf _5bi); /*Revenus industriels et commerciaux*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5cf _5ci); /*Revenus des locations meublées non professionnelles*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5an _5bn); /*Autres revenus industriels et commerciaux non professionnels*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5ao _5bo); /*Revenus non commerciaux professionnels*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5ap _5bp); /*Revenus non commerciaux non professionnels*/

	/*Revenus agricoles : régime du micro BA*/
	/*Ajout des cases sur l'année de création de l'activité*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5xc _5yc _5zc);
	/*Ajout des cases sur les revenus des années précédentes : on essaye de reconstituer l'information à partir des cases fiscales de la déclaration 2015.
	En particulier, on fait comme si les revenus de 2016, 2015 et 2014 étaient les mêmes*/

	/*Régime du forfait*/
	%transfererCases(1.25*_5ho -> _5xd, 2016); 	%transfererCases(1.25*_5ho -> _5xe, 2016); /*On multiplie par 1,25 car le montant déclaré en 2015 est 
																							ensuite majoré de 25 % (et c'est bien le montant majoré de 25 % 
																							qui doit être déclaré pour les revneus 2016 d'après la BP page 135)*/
	%transfererCases(1.25*_5io -> _5yd, 2016); 	%transfererCases(1.25*_5io -> _5ye, 2016);
	%transfererCases(1.25*_5jo -> _5zd, 2016); 	%transfererCases(1.25*_5jo -> _5ze, 2016);
	%disparitionSimple(anneeDisparition = 2016, listeCases = _5ho _5io _5jo);
	
	%apparitionSimple(anneeApparition = 2016, listeCases = _5xf _5yf _5zf _5xg _5yg _5zg);

	/*Ajout de cases qui servent pour le prélèvement à la source*/
	%apparitionSimple(anneeApparition = 2016, listeCases = _5aq _5ar _5ay _5az _5dk _5dl _5dm _5dn _5ut _5uu _5uy _5uz _5xp _5xq _5xh _5xl _5xy _5xz _5vm _5vn
														   _5bq _5br _5by _5bz _5ek _5el _5em _5en _5vt _5vu _5vy _5vz _5yp _5yq _5yh _5yl _5yy _5yz _5wm _5wn);


	/* ============== 2042 IOM - Impots pour investissement ============== */
	%apparitionSimple(anneeApparition = 2016, listeCases = _huo _hup _huq _hur _hus _hut _huu); /* investissements réalisés en 2016 */
	%apparitionSimple(anneeApparition = 2016, listeCases = _hxl _hxm _hxn _hxo _hxp); /* investissements réalisés en 2016 */
		
	%disparitionSimple(anneeDisparition=2016,listeCases= _hkh _hki); /*report de réductions d'impôts non imputées les années antérieures*/

	%apparitionSimple(anneeApparition = 2016, listeCases = _hci _hcj _hcn _hco _hck _hcp _hcl _hcq _hcm _hcr _hcs _hct
																_hcu _hcv _hcw);
	%disparitionSimple(anneeDisparition=2016,listeCases= _hmn _hlh _hmb _hkt _hli _hmc _hku); /* Pour les investissements réalisés en 2010 */
	%disparitionSimple(anneeDisparition=2016,listeCases= _hbl _hbq _hbv _hca _hcf); /* Pour les investissements réalisés en 2015 */

	%transfererCases((1/0.5436)*_hbw -> _hbw, 2016);
	%transfererCases((1/0.5436)*_hcb ->  _hcb, 2016);
	%transfererCases((1/0.5436)*_hcg ->  _hcg, 2016);

%Mend;

/************************************************************/
/* 				Appel successif à toutes les macros 		*/
/* pour se conformer à la brochure pratique la plus récente */
/************************************************************/

data travail.foyer&anr.(rename=(ident&anr.=ident) drop=anaisd anaisc anaih);
    set foyer&anr.(rename=(sif1=sif));

	%GererSIF; 
	/* création de variables utiles */
	%standard_foyer; 

	/* Initialisation à 0 des variables aux noms explicites 
	(i.e. anciennes cases fiscales qui ont disparu ou dont les noms actuels portent une information différente) */
	%Init_Valeur(_report_RI_dom_entr _interet_pret_conso _glovSup4ansVous _glovSup4ansConj _perte_capital _perte_capital_passe 
				_relocalisation _nb_vehicpropre_simple _nb_vehicpropre_destr _CIRechAnt _CINouvTechn 
				_dep_devldura_loc1 _dep_devldura_loc2 _dep_devldura_loc3 _dep_devldura_loc4 _InvDomAut1 _InvDomAut2	_PVCessionDom 
				_hsupVous _hsupconj _hsupPac1 _hsuppac2 _CI_debitant_tabac
				_depinvloctour_2011_1 _depinvloctour_av2011_1 _depinvloctour_ap2011_1
				_depinvloctour_2011_2 _depinvloctour_av2011_2 _depinvloctour_ap2011_2
				_dep_Asc_Traction _PVCession_entrepreneur
				_1annui_lgtancien _1annui_lgtneuf _bouquet_travaux _cred_loc _protect_patnat
				_epargneCodev _credFormation
				_demenage_emploiVous _demenage_emploiConj _demenage_emploiPac1 _demenage_emploiPac2
				_revPEA _CIFormationSalaries _souscSofipeche _revImpCRDS
				_glo_txfaible _glo_txmoyen
				_abatt_moinsval _abatt_moinsval_renfor _abatt_moinsval_dirpme
				_impot_etr_dec1 _impot_etr_dec2 _impot_etr_pac1 _impot_etr_pac2
				_tpsplein_ppe_dec1 _tpsplein_ppe_dec2 _tpsplein_ppe_pac1 _tpsplein_ppe_pac2
				_nbheur_ppe_dec1 _nbheur_ppe_dec2 _nbheur_ppe_pac1 _nbheur_ppe_pac2
				_rsa_compact_ppe_f _rsa_compact_ppe_pac1 _rsa_compact_ppe_pac2
				_pro_act_annee_dec1 _pro_act_annee_dec2 _pro_act_annee_pac _pro_act_jour_dec1 _pro_act_jour_dec2 _pro_act_jour_pac
				_maison_indivi _deduc_invest_loc2009 _rachatretraite_vous _rachatretraite_conj _1annui_lgtneufnonBBC 
				_nb_convention _nb_convention_hand 	_glo1_2ansVous _glo1_2ansConj _glo2_3ansVous _glo2_3ansConj _nonBBC_2010
	 );

	/* Remarque : l'appel de %modif_N n'a d'effet que pour anref<N (sauf pour les disparitions de cases) */
	%modificationsERFS2004();
	%modificationsERFS2005();
	%modificationsERFS2006();
	%modificationsERFS2007();
	%modificationsERFS2008();
	%modificationsERFS2009();
	%modificationsERFS2010();
	%modificationsERFS2011();
	%modificationsERFS2012();

	/* Variables que l'on devrait avoir dans l'ERFS mais dont on ne dispose pas par erreur (à signaler à RPM) */
	%apparitionSimple(anneeApparition=2012,listeCases=
		_1ej _1ep _1ek _1ei _1er _1qx _1qv _1es _1eo 
		_1fj _1fp _1fk _1fi _1rx _1rv _1fs _1fo
		_6gk _6gl _6en _6eq _3wc
		);
	%modificationsERFS2013();
	/* Une variable de l'ERFS toujours manquante par erreur (à signaler à RPM) */
	if _7fl=. then _7fl=0;

	%modificationsERFS2014();
	%modificationsERFS2015();
	%modificationsERFS2016();

	%suppressionVariablesInutiles();
	run;


/* Sorties utiles au moment de la mise à jour */
/*
proc contents data=rpm.foyer&anr. out=t1 noprint; run; proc sort data=t1 (keep=name); by name; run;
proc contents data=travail.foyer&anr. out=t2 noprint; run; proc sort data=t2 (keep=name); by name; run;
data t_; merge t1 (in=a) t2 (in=b); by name; Presence_avant=a; Presence_apres=b; run;

proc means data=rpm.foyer&anr. mean sum; var _1ty _1uy _2da _3vo _3so; run;
proc means data=travail.foyer&anr. mean sum; var _1ty _1uy _2da _3vo _3so; run;

proc means data=rpm.foyer&anr. mean sum; var _7gh _7gi; run;
proc means data=travail.foyer&anr. mean sum; var _7gh _7gi _7ek _7el _7qa _7qb _7qc _7qd; run;

proc means data=rpm.foyer&anr. mean sum ; var _7xf _7xm _7xo ; run ;
*/

	
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
