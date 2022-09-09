/****************************************************************************************/
/*																						*/
/*								ressources												*/
/*																						*/
/****************************************************************************************/

/* Calcul des ressources des prestations famille et logement			   				*/
/* En entrée : 	modele.rev_imp&anr.                                    					*/
/*				base.foyer&anr2.                                    					*/ 
/*				modele.baseind                                      					*/
/*				modele.basersa                                     						*/
/*				base.baserev                                     						*/
/*				modele.basefam                                     						*/
/*				base.menage&anr2.                                     					*/
/* En sortie :  modele.basefam                                     						*/
/*				modele.baselog                                     						*/
/****************************************************************************************/
/* PLAN :																				*/
/* I - PREPARATION DES DONNEES 															*/
/* 	I.A Récupération des informations nécessaires dans les déclarations fiscales		*/
/* 	I.B - Données individuelles : ressources et abattement 								*/
/* 		I.B.1 - Ressources individuelles 												*/
/* 		I.B.2 - Données de revenus individuels pour prendre en compte les imputations 	*/
/* des revenus ERFS et les abattements pour la situation sur le marche de l'emploi		*/
/* 	I.C - Attribution des données de chaque déclaration du ménage à un et un seul membre*/
/* du logement ou de la famille 														*/
/* 		I.C.1 - Suppression du revenu des FIP dans RBG caf 								*/
/* 		I.C.2 - Données de revenus individuels pour prendre en compte les imputations 	*/
/* des revenus ERFS et les abattements pour la situation sur le marche de l'emploi		*/
/* II - CALCUL DES RESSOURCES CAF 														*/
/* 	II.A - Calcul des ressources au niveau de la famille CAF							*/
/* 		II.A.1 - Initialisation des variables 											*/
/* 		II.A.2 - Agrégation des abattements 											*/
/* 		II.A.3 - Définition des ressources au niveau de la famille 						*/
/* II.B - Neutralisation et abattements pour les enfants 								*/
/* III - CALCUL DES RESSOURCES LOGEMENT 												*/
/* 	III.A - Calcul des ressources au niveau de la famille au des AL 					*/
/* 	III.B - Calcul du loyer payé par unité logement du ménage							*/
/****************************************************************************************/
/* EXPLICATION INTRODUCTIVE :															*/
/* Les ressources pour les prestations (famille et logement) sont calculées au niveau de*/
/* la famille ou du logement mais elles utilisent la notion de revenu fical RBG qui est	*/
/* définie au niveau du foyer fiscal. Des RBG "compatible CAF" et individuels ont été 	*/
/* calculés lors du calcul de l'impôt (programmme RBG).									*/
/* Le revenu CAF est calculé selon cette formule : 										*/
/* 	revenu au niveau de la famille (partie I.B et II.A.3 et II.B)						*/
/*	+ imputation des revenus ERFS (partie I.B)											*/
/*	- déduction des aides à la garde (partie I.A et II.B)								*/
/*	- déduction des revenus des personnes à charges (parties I.B et II.A.b)				*/
/*	- abattement due à la situation sur le marche de l'emploi (I.B et II.B)				*/
/*	- déduction de revenu (pension alim, CSG pat etc) (partie I.A)						*/
/****************************************************************************************/




/****************************************************************************************/
/* I - PREPARATION DES DONNEES 															*/
/****************************************************************************************/

/****************************************************************************************/
/* 	I.A Récupération des informations nécessaires dans les déclarations fiscales		*/
/****************************************************************************************/
/*	Il s'agit des pensions alimentaires, abattements spéciaux, CSG_pat, revenu caf, frais de garde.*/	

%let FraisDeGarde=_7df _7ga _7gb _7gc _7ge _7gf _7gg _7db;
%macro Calcul_ressources;
/* On conserve les frais de garde en &anr2. pour le programme 9_garde d'imputation du mode de garde */
data Garde&anr2.(keep=declar gardehdom&anr2. gardeadom&anr2.);
	set base.foyer&anr2.(keep=declar anaisenf &FraisDeGarde.);
	pres_enf=0;
	do i=0 to ((length(anaisenf)-5)/5) ; 
		an=input(substr(anaisenf,i*5+2,4),4.); 
		if an=. then an=0; 
		if &anref.-an<6 then pres_enf=1; 
		end;
	gardeadom&anr2.=(_7db+_7df)*pres_enf;
	gardehdom&anr2.	=_7ga+_7gb+_7gc+_7ge+_7gf+_7gg;
	run;
proc sort data=modele.rev_imp&anr. (keep=ident declar anaisenf  rev_cat: rbg_caf _6de 
		DED_pension abat_spec &FraisDeGarde. _1ao _1bo _1co _1do _1eo _1as _1bs _1cs _1ds _1es  
		_1al _1bl _1cl _1dl _1el _1am _1bm _1cm _1dm _1em _1az _1bz _1cz _1dz rename=(declar=declar1)) 
		out=revenu_caf; 
		by declar1; 
	run;
proc sort data=Garde&anr2.(rename=(declar=declar1)); by declar1; run;
data revenu_caf(drop=_1ao _1bo _1co _1do _1eo _1as _1bs _1cs _1ds _1es 
				_1al _1bl _1cl _1dl _1el _1am _1bm _1cm _1dm _1em _1az _1bz _1cz _1dz &FraisDeGarde. _6de anaisenf pres_enf an i); 
	merge 	revenu_caf
			Garde&anr2.;
	by declar1;
	pensrecu 		=sum(_1ao,_1bo,_1co,_1do,_1eo);
	penspercu		=sum(_1as,_1bs,_1cs,_1ds,_1es,_1al,_1bl,_1cl,_1dl,_1el,_1am,_1bm,_1cm,_1dm,_1em,_1az,_1bz,_1cz,_1dz);
	gardehdom&anr.	=_7ga+_7gb+_7gc+_7ge+_7gf+_7gg;
	csgdpat			=_6de;
	pres_enf		=0;
	
	pres_enf=0;
	do i=0 to ((length(anaisenf)-5)/5) ; 
		an=input(substr(anaisenf,i*5+2,4),4.); 
		if an=. then an=0; 
		if &anref.-an<6 then pres_enf=1; 
		end;
	gardeadom&anr.=(_7db+_7df)*pres_enf;

	/*on ote les revenus individuels des rgb_caf */
	rbg_caf=max(0,rbg_caf-rev_cat1-rev_cat2-rev_cat3-rev_cat4);
	format ident $8. noi $2.;
	noi=substr(declar1,1,2); 
	run;


/****************************************************************************************/
/* 	I.B - Données individuelles : ressources et abattement 								*/
/****************************************************************************************/

/* 		I.B.1 - Ressources individuelles 												*/
proc sort 	data=modele.baseind(keep=declar1 declar2 persfip1 persfip2 ident noi naia quelfic 
				civ ident_fam ident_log statut_fam statut_log ident_rsa acteu6 cal0 aah lprm) 
			out=baseind; 
	by declar1; 
	run;
data rbg_ind;
	merge 	baseind(in=a) 
			revenu_caf (keep=declar1 rev_cat: rbg_caf DED_pension abat_spec gardeadom&anr. gardehdom&anr. pensrecu penspercu csgdpat); 
	by declar1;
	if a;
	run;
proc sort data=rbg_ind; by declar2; run;
data rbg_ind2;
	merge 	rbg_ind(in=a)
			revenu_caf (keep=declar1 rev_cat: rbg_caf DED_pension abat_spec gardeadom&anr. gardehdom&anr. pensrecu penspercu csgdpat
				rename=(declar1=declar2 rev_cat1=rev_cat12 rev_cat2=rev_cat22 
				rev_cat3=rev_cat32 rev_cat4=rev_cat42 rbg_caf=rbg_caf2
				DED_pension=DED_pension2 abat_spec=abat_spec2 gardeadom&anr.=gardeadom&anr.2
				gardehdom&anr.=gardehdom&anr.2 pensrecu=pensrecu2 penspercu=penspercu2 csgdpat=csgdpat2)); 
	by declar2; 
	if a;
	run;
data rbg_ind3;
	set rbg_ind2;
	rbg_ind=0;
	if persfip1='decl' 	then rbg_ind=rbg_ind+rev_cat1;
	if persfip1='conj' 	then rbg_ind=rbg_ind+rev_cat2;
	if persfip1='p1' 	then rbg_ind=rbg_ind+rev_cat3;
	if persfip1='p2' 	then rbg_ind=rbg_ind+rev_cat4;
	if persfip2='decl' 	then rbg_ind=rbg_ind+rev_cat12;
	if persfip2='conj' 	then rbg_ind=rbg_ind+rev_cat22;
	if persfip2='p1' 	then rbg_ind=rbg_ind+rev_cat32;
	if persfip2='p2' 	then rbg_ind=rbg_ind+rev_cat42;
	run;

/* 		I.B.2 - Données de revenus individuels pour prendre en compte les imputations 	*/
/* des revenus ERFS et les abattements pour la situation sur le marche de l'emploi		*/

data rsa_socle(keep=ident_rsa m_rsa_socle:); /* Repérage des bénéficiaires de rsa socle lors de la 2e exécution du programme */
	set modele.basersa; 
	if sum(of m_rsa_socle_th1-m_rsa_socle_th4)>=0; 
	run;
proc sort data=rsa_socle; by ident_rsa; run; 
proc sort data= rbg_ind3; by ident_rsa; run;
data rbg_ind4;
	merge 	rbg_ind3(in=a) 
			rsa_socle(in=b);
	by ident_rsa;
	run; 

proc sort data=base.baserev; by ident noi; run;
proc sort data=rbg_ind4; by ident noi; run;

data table;
	merge 	base.baserev (keep=ident noi zsali&anr. zrsti&anr. zpii&anr. zchoi&anr. zragi&anr. zrici&anr. zrnci&anr. &RevObserves. montant_ass) 
			rbg_ind4(in=a); 
	by ident noi;
	if a; 
	/* revenu individuel */
	revi=max(0,sum(0,zsali&anr.,zrsti&anr., zpii&anr.,zchoi&anr.,zragi&anr.,zrici&anr.,zrnci&anr.));
	revo=max(0,sum(0,zsalo,zrsto,zpio,zchoo,zrago,zrico,zrnco));
	/* C'est a priori fait pour gérer les imputations de revenus des gens qui se marient et à qui il manque la déclaration avant mariage.
	Pour eux, l'erfs leur impute un revenu avant mariage qu'on doit comptabilisé dans les ressources.
	Il y a peut-être une incohérence avec le fait que l'on reconstruit une déclaration dans ce cas normalement dans les premières étapes. */ 
	if quelfic ='EE&FIP' & (index(substr(declar1,24,3),'X') >0 & declar2='') then ress_impute=revi-revo; 
	else ress_impute=0;

	/* Neutralisation et abattements des revenus d'activité (pour la paje et pour les aides au logement). cf. Art R532-7 et D542-10 du Code la Sécurité Sociale */
	rev_activite=max(0,revi-zrsti&anr.-zpii&anr.); /*on garde zchoi*/
	abattement_chom=0 ; /* Abattement/neutralisation au titre de la perception de l'ARE ou de l'ASS */
	abattement_rsa=0 ; /* neutralisation au titre de la perception du RSA */
	abattement=0 ; /* Abattement au titre de la perception de l'AAH ou de pensions d'invalidité */
	abattement_paje=0;
	/* Abattement ou neutralisation selon perception d'allocations chômage */
	nbmois_cho=count(substr(cal0,1,12),'4'); /* Nombre de mois de chômage au cours de l'année */
	if index(cal0,'44')>0 and (zchoi&anr.>0) then do; /* Si 2 mois consécutifs de chômage. */
		if zchoi&anr.>nbmois_cho*&ass_mont. then abattement_chom=0.3*max(0,(rev_activite-zchoi&anr.)); /* chômage indemnisé : abattement */
		if zchoi&anr.<=nbmois_cho*&ass_mont. or montant_ass>0 then abattement_chom=rev_activite;	/* chômage non indemnisé, ARE minimum ou ASS. */
		end;
		/* Remarque : lorsque module_ass=OUI (imputation d'ASS), même si le montant moyen d'allocations chômage (ARE ou ASS) par mois passé au chômage est supérieur au montant d'ASS mensuel, 
			on attribue la neutralisation totale des revenus d'activité en cas de perception d'ASS (même pour un moins ou une période plus courte que la perception d'ARE). 
			Pour ces cas, on maximise donc l'abattement dû. En toute rigueur, il faudrait utiliser le nombre de mois à l'ASS et au chômage sans ASS. */

	/* Autres conditions d'abattement ou de neutralisation */
	/* Neutralisation en cas de perception du RSA */  
	if lprm in ('1', '2') then do ;
		abattement_rsa=rev_activite*(sum(of m_rsa_socle_th1-m_rsa_socle_th4,0)>0);
		end ;
		/* Spécificité du RSA : prestation non individuelle. On ajoute donc la condition sur lprm, pour ne pas neutraliser les éventuels revenus d'activité de tout le foyer RSA. 
			Mais risque de surestimation en neutralisant probablement les rev act les plus importants du foyer. */
	/* Abattement en cas de cessation d'activité pour perception d'AAH, de pensions d'invalidité etc... */
	/* Ecart à la législation : s'applique aussi en cas de cessation d'activité pour retraite (article R.532-5 du CSS) */
	if (aah>0 & acteu6^='1') or (zpii&anr.>0 & acteu6^='1') then abattement=0.3*rev_activite; 	
		
	/* Abattement utilisé dans la base ressources des prestations familiales : on le conserve dans une variable spécifique, 
	avant l'arbitrage entre abattement_chom et abattement */
	abattement_paje=max(0,abattement_chom, abattement_rsa, abattement) ; 
	/* Ecart à la législation : la neutralisation des revenus d'activité ne devrait s'appliquer que le temps de perception des allocations ou minima.
		Or, on le fait pour toute l'année, à la différence de ce qui est fait pour les AL selon les mois passés au chômage (calcul de 4 bases ressources) ou les trimestres de RSA. 
		On tend donc à surestimer le temps de neutralisation des revenus d'activités.*/ 

	/* On annule les abattements moins favorables (sera utile pour les aides au logement) */
	if (abattement_chom>=abattement and abattement_chom>=abattement_rsa) then abattement_rsa=0 and abattement=0; /* en cas d'abattement potentiellement identique au titre de l'ASS 
	et du RSA, ou de l'ARE et de l'AAH, on considère que c'est au titre des allocations chômage pour pouvoir pondérer les situations et ne pas neutraliser les revenus d'activités 
	trop longtemps. */
	if (abattement_rsa>abattement and abattement_rsa>abattement_chom) then abattement_chom=0 and abattement=0;
	if (abattement>abattement_chom and abattement>abattement_rsa) then abattement_chom=0 and abattement_rsa=0;

	/* Non prise en compte du revenu des personnes à charge pour la paje : l'abattement est donc égal au rbg individuel du pac */ 
	if statut_fam='pac' then abatt_pac=rbg_ind;
	else abatt_pac=0;

	/* Pour les aides au logement, les revenus des pac sont abattues en partie */
	if statut_log='pac' then do; 
		abatt_pac_log=max(0,min(&mv_plfi.*&E2001.,rbg_ind)); 
		pac_log=1;
		stud=0;
		end;
	else do; 
		abatt_pac_log=0;
		pac_log=0;
		stud=0;
		end;

	/* Caractéristiques du ménage */ 
	nbtravailleur=0;
	nbciv=0;
	if (civ in ('mon','mad') & substr(ident_fam,9,2) ne '99') or (substr(ident_fam,9,2) = '99' and lprm='1') then do; 
		nbciv=1;
		nbciv_log=(statut_log ne 'pac');
		%if &anleg.>=2012 %then %do;
		if revi>=0.136*&plafondssa. then do; 
			nbtravailleur=1;
			nbtravailleur_log=(statut_log ne 'pac');
			end; 
			%end;
		%if &anleg.<2012 %then %do; 
		if revi>=12*&bmaf. then do; 
			nbtravailleur=1;
			nbtravailleur_log=(statut_log ne 'pac');
			end; 
			%end;
		stud=0;
		if (statut_log ne 'pac') and acteu6='5' then stud=1;
		end; 

	run; 
	
/****************************************************************************************/
/* 	I.C - Attribution des données de chaque déclaration du ménage à un et un seul membre*/
/* du logement ou de la famille 														*/
/****************************************************************************************/

/*	Pour chaque déclaration, on regarde le noi du déclarant principal et ce sera à son logement et sa famille 
	qu'on attribuera rbg_caf résiduel et le reste */

proc sort data=revenu_caf; by ident noi; run; 
proc sort data=baseind; by ident noi; run;

data foyer_attribue; 
	merge 	revenu_caf(in=a) 
			baseind(keep=ident: noi);
	by ident noi;
	if a;
	run;
proc means data=foyer_attribue noprint nway;
	class ident noi;
	var rbg_caf ded_pension gardeadom: gardehdom: pensrecu penspercu abat_spec csgdpat ;
	output out=foyer_famille(drop=_type_ _freq_) sum=;
	run;


/****************************************************************************************/
/* II - CALCUL DES RESSOURCES CAF 														*/
/****************************************************************************************/

/****************************************************************************************/
/* 	II.A - Calcul des ressources au niveau de la famille CAF							*/
/****************************************************************************************/

proc means data=foyer_attribue noprint nway;
	class ident_fam;
	var rbg_caf ded_pension gardeadom: gardehdom: pensrecu penspercu abat_spec csgdpat;
	output out=foyer_famille(drop=_type_ _freq_) sum=;
	run;

proc means data=table noprint nway;
	class ident_fam;
	var rbg_ind ress_impute abatt_pac abattement_paje nbtravailleur nbciv;
	output out=rbg_ind_famille(drop=_type_ _freq_) sum=;
	run;
data rev_fam; 
	merge rbg_ind_famille foyer_famille; 
	by ident_fam;
	array tout _numeric_; do over tout; if tout=. then tout=0; end;
	/* On fait le max ici et pas avant au niveau de rbg_ind parcequ'on suppose que les déficits d'une personne peuvent se 
	déduire des revenus d'une autre personne de la famille comme lorsqu'on calcule le revenu imposable d'un foyer fiscal */
	res_paje=max(0,rbg_caf+rbg_ind-abatt_pac+ress_impute-abat_spec-csgdpat-ded_pension); 	/* on retire la csg sur le patrimoine, l'abattement invalidité et les pensions alimentaires versées  */
	run; 

/****************************************************************************************/
/* II.B - Neutralisation et abattements pour les enfants 								*/
/****************************************************************************************/
proc sort data=modele.basefam; by ident_fam; run; 
data modele.basefam(drop=nbtravailleur abattement_paje); 
	merge 	modele.basefam(in=a) 
			rev_fam(keep=ident_fam res_paje nbtravailleur gardeadom: gardehdom: abattement_paje nbciv pensrecu); 
	by ident_fam; 
	if a;
	/* Neutralisation des ressources : la deduction des frais de garde est appliquée jusqu'en 2004 (&abat02.=0 après 2004) */
	%nb_enf(enf0_6,0,5,age_enf);
	res_paje=max(0,int(res_paje-min(gardeadom&anr.+gardehdom&anr.,&abat02.*enf0_6)-abattement_paje));
	men_paje='L';
	if nbtravailleur>=2 then men_paje='H'; /*verifier que nbtravailleur n'est jamais plus grand que 2*/ 
	if nbciv=1 then do; 
		pers_iso=1; 
		if nbtravailleur=1|nbtravailleur=0 then men_paje='H';
		end;
	if pers_iso=. then pers_iso=0; 
	run; 


/****************************************************************************************/
/* III - CALCUL DES RESSOURCES LOGEMENT 												*/
/****************************************************************************************/

/* La définition des ressources au sens des allocations logement diffère de celle au sens des prestations familiales 
	sur les personnes à charges, notamment les ascendants. 
	On crée également un ident_log différent de l'ident_fam pour rattacher les ascendants */ 

/****************************************************************************************/
/* 	III.A - Calcul des ressources au niveau de la famille au sens des AL 					*/
/****************************************************************************************/

proc means data=foyer_attribue noprint nway;
	class ident_log;
	var rbg_caf ded_pension gardeadom&anr. gardehdom&anr. pensrecu penspercu abat_spec csgdpat ;
	output out=foyer_log(drop=_type_ _freq_) sum=;
	run;

proc means data=table noprint nway; /*donc attention rbg_ind n'est plus vraiment individuel, il est sommé sur le logement*/
	class ident_log;
	var rbg_ind ress_impute abatt_pac_log abattement nbtravailleur_log nbciv_log pac_log stud;
	output out=rbg_ind_log(drop=_type_ _freq_) sum=;
	run;

data rev_log; 
	merge rbg_ind_log foyer_log; 
	by ident_log;
	array tout _numeric_;
	do over tout;
		if tout=. then tout=0;
		end;
	res_log=max(0,rbg_caf+rbg_ind-abatt_pac_log+ress_impute-abat_spec-csgdpat-ded_pension); 	/* on retire la csg sur le patrimoine, l'abattement invalidité et les pensions alimentaires versées  */
	run; 
 
/* On récupère les abattements chômage et les calendriers d'activité pour faire des calculs d'AL différenciés avec ou sans l'abattement ou la neutralisation.
	Si une personne avec un abattement chômage est au chômage une partie de l'année, on lui calcule des AL avec cet abattement pour la période pendant laquelle elle est au chômage 
	et des AL sans abattement pour la période pendant laquelle elle n'y est pas.
	Ainsi pour un couple dont les deux personnes sont dans cette situation, il y a quatre AL à calculer selon que l'une, l'autre, les deux ou aucun des deux ne sont aux chômage. */
proc sql;
	create table abattementcho as
	select distinct ident_log, abattement_chom, cal0 
	from table
	where abattement_chom>0 ;
	run;

proc sort data=abattementcho; by ident_log; run;
data abattementcho (drop=abattement_chom);
	set abattementcho;
	by ident_log;
	abattement_chom1=0;
	abattement_chom2=0;
	if first.ident_log then do; abattement_chom1=abattement_chom; cal01=cal0; end;
	else do; abattement_chom2=abattement_chom; cal02=cal0; end;
	run;
data abattementcho1 (keep=ident_log abattement_chom1 cal01);set abattementcho; where abattement_chom1>0; run;
data abattementcho2 (keep=ident_log abattement_chom2 cal02);set abattementcho; where abattement_chom2>0; run;
data abattementcho (drop=i);
	merge abattementcho1 abattementcho2;
	by ident_log;
	if abattement_chom2=. then abattement_chom2=0;
	if cal02='' then cal0='000000000000';

	p1=0; p2=0; p3=0; p4=0;
	/*les p(i) seront utilisés pour pondérer les différents montant d'AL calculés*/
	retain p1 p2 p3 p4;
	do i=1 to 12;
		if (substr(cal01,i,1) ne '4')&(substr(cal02,i,1) ne '4')then p1=p1+1;
		if (substr(cal01,i,1) = '4')&(substr(cal02,i,1) ne '4') then p2=p2+1;
		if (substr(cal01,i,1) ne '4')&(substr(cal02,i,1) = '4') then p3=p3+1;
		if (substr(cal01,i,1) = '4')&(substr(cal02,i,1) = '4') 	then p4=p4+1;
		end;
	run;

/* Sur le même modèle que pour les abattements chômage, on récupère les abattements pour RSA et l'info sur la perception de RSA par trimestre, pour faire des calculs d'AL différenciés 
	avec ou sans la neutralisation.
	Si une personne avec un abattement_rsa perçoit le RSA une partie de l'année, on lui calcule des AL avec cette neutralisation pour la période pendant laquelle elle perçoit le RSA et 
	des AL sans neutralisation pour la période pendant laquelle elle ne l'a pas.
	On calcule donc 2 BR (trimestres avec RSA et trimestres sans RSA) */
proc sql;
	create table abattementrsa as
	select distinct ident_log, abattement_rsa, m_rsa_socle_th1, m_rsa_socle_th2, m_rsa_socle_th3, m_rsa_socle_th4 
	from table
	where abattement_rsa>0 ;
	run;

proc sort data=abattementrsa; by ident_log; run;
data abattementrsa (drop=abattement_rsa);
	set abattementrsa;
	by ident_log;
	abattement_rsa1=0;
	abattement_rsa2=0;
	if first.ident_log then do; abattement_rsa1=abattement_rsa; end;
	else do; abattement_rsa2=abattement_rsa; end;
	run;
data abattementrsa1 (keep=ident_log abattement_rsa1 m_rsa_socle_th1-m_rsa_socle_th4);set abattementrsa; where abattement_rsa1>0; run;
data abattementrsa2 (keep=ident_log abattement_rsa2);set abattementrsa; where abattement_rsa2>0; run;
data abattementrsa ;
	merge abattementrsa1 abattementrsa2;
	by ident_log;
	if abattement_rsa2=. then abattement_rsa2=0;
	
	w1=0; w5=0; /* cas 1 sans rsa et cas 5 avec rsa */
	/*les w(i) seront utilisés pour pondérer les différents montant d'AL calculés => on multiplie par 3, car on veut un nombre de mois pour pondérer ensuite un montant d'AL mensuel */
	w5=3*((m_rsa_socle_th1>0)+(m_rsa_socle_th2>0)+(m_rsa_socle_th3>0)+(m_rsa_socle_th4>0)) ;
	w1=max(0,12-w5) ;
	run;

data tablelog(keep= rbg_caf ress_log1-ress_log5 p1-p4 w1 w5 abatt_pac_log ress_impute ident_log 
			abattement_chom1 abattement_chom2 abattement_rsa1 abattement_rsa2 abattement nbciv_log nbtravailleur_log pac_log ident stud); 
	merge rev_log (in=a) abattementcho abattementrsa;
	by ident_log; 
		
		if abattement_chom1=. then abattement_chom1=0;
		if abattement_chom2=. then abattement_chom2=0;
		if p1=. then p1=12;
		if p2=. then p2=0;
		if p3=. then p3=0;
		if p4=. then p4=0;
		if abattement_rsa1=. then abattement_rsa1=0;
		if abattement_rsa2=. then abattement_rsa2=0;
		if w1=. then w1=12;
		if w5=. then w5=0;

		ress_log=max(0,res_log-abattement); /* On prend en compte les abattements ou neutralisations dus au titre du rsa, de pi ou de l'AAH, exclusifs d'abattement_chom, 
		de sorte qu'on n'applique pas ces abattements des revenus d'activité plusieurs fois pour une même personne */ 

		/* abattement pour double activite lorsque les deux membres du menage travaillent et ont reçu 
		chacun un revenu supérieur à 12*bmaf (et dont statut_log ne 'pac')*/
		 %if &anleg.<1992 %then %do;
			if nbtravailleur_log>=2 then ress_log=ress_log-&al_abat_2act.*(1+(pac_log>0)+(pac_log>2));
			%end;
	 	%else %do;
			if nbtravailleur_log>=2 then ress_log=ress_log-&al_abat_2act. ; 
			%end;
	
		/*on définit 4 ress_log selon qu'il y ait un des deux abattements liés au chomage, les deux ou aucun */
		ress_log1=max(0,ress_log);
		ress_log2=max(0,ress_log-abattement_chom1);
		ress_log3=max(0,ress_log-abattement_chom2);
		ress_log4=max(0,ress_log-abattement_chom1-abattement_chom2); 
	 	/* Ajout d'une 5e base avec neutralisation pour RSA */
		ress_log5=max(0,ress_log-abattement_rsa1-abattement_rsa2); 
		
		/* if nbciv=1 then ress_log=ress_log-(pac_log>0)*&al_abat_I12-(pac_log>=3)*(&al_abat_I3-&al_abat_i12); */
		/* Une condition d'abattement pour personne seule ou isolée ne vaut que pour l'APL et ne marche que 
		pour les étudiants en logements-foyer; 
		Une autre ne vaut aussi que pour les logements_foyer (hors ménage ordinaire donc) et pour 
		les accédants et ne vaut que pour les AL et pas l'APL. C'est celle qui est codée au-dessus 
		et justement commentée. */

		/* On ne fait pas d'évaluation forfaitaire des ressources car cela pose problème dans le cadre 
		statique d'INES*/

		/* On ne fait pas non plus d'évaluation forfaitaire des ressources pour les ménages 
		étudiants (Article R*351-7-2) */

		format ident $8.;
		ident=substr(ident_log,1,8);
		run; 

/********************************************************************************************************************/
/* 	III.B - Calcul du loyer payé par foyer (au sens AL) et ajout d'information sur le logement dans modele.baselog	*/
/********************************************************************************************************************/

proc sort data=baseind out=uc_log(keep=ident ident_log naia); by ident_log ident; run;

data uc_log;
	set uc_log (where=(ident_log ne ''));
	by ident_log;
	retain uc_log;
	if first.ident_log then	uc_log=0.5; 
		if &anref-input(naia,4.)>=14 then uc_log=uc_log+0.5; 
		else uc_log=uc_log+0.3;
	if last.ident_log;
run;

/* 	Lorsque plusieurs générations cohabitent sous le même toit, seul le foyer de la PR peut percevoir les AL. 
 	Les autres foyers (au sens des AL) sont considérés comme logés gratuitement et n'y ont donc pas droit 
		(notamment les jeunes adultes mais aussi les ascendants qui ne font pas partie du foyer logement).					
	Ces foyers seront exclus de modele.baselog en sortie (et donc non pris en compte dans le pgm AL.sas). 
	S'il reste plusieurs foyers logement dans le ménage (colocataires), on répartit le loyer entre ces foyers restants.	
 	Note : sont aussi considérés comme colocataires les foyers avec un lien de parenté "autre" que parent ou enfant	*/

data compfam ; set baseind (keep=ident_log lprm noi) ;
	id_PR=(lprm in ("1","2")) ;
	id_enfant=(lprm="3") ; /* enfant de la PR ou de son conjoint */
	id_parent=(lprm="4") ; /* parent de la PR ou de son conjoint */
run ;
proc sql;
	create table compfam2 as
	select ident_log, max(id_pr) as id_pr, max(id_enfant) as id_enfant, max(id_parent) as id_parent 
	from compfam
	where ident_log>""
	group by ident_log ;
quit ;

data tablelog2 ;
	merge 	tablelog (in=a)
			uc_log (keep=ident_log uc_log)
			compfam2 ;
	by ident_log ;
	if a;
	if id_pr=0 and (id_enfant=1 or id_parent=1) then delete ;
run;

proc sort data=tablelog2; by ident; run; 
proc sort data=base.menage&anr2.; by ident; run; 

proc sql;
	create table ulogtot as
	select ident, sum(uc_log) as ulogtot
	from tablelog2
	group by ident ;
quit ;

data modele.baselog;
	merge tablelog2(in=a)
	      base.menage&anr2.(in=b keep=ident loyer reg logt TUU2010)
		  ulogtot(in=c) ;
	by ident; 
	if a & b;
	if loyer>0;
	loyer_identlog=loyer*uc_log/ulogtot;
	label loyer_identlog="Loyer par famille au sens des AL";
	drop loyer;
	run;

/* TO DO : supprimer id_pr, id_enfant et id_parent de modele.baselog ? */

%mend Calcul_ressources;

%Calcul_ressources;


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
