/********************************************************************************/
/*																				*/
/*							Calcul de la prime d'activit�						*/
/*																				*/
/********************************************************************************/

/* Calcul de l'�ligibilit� et des montants de la PA                  	*/
/* En entr�e : 	base.baserev	                                    	*/
/* 				modele.baseind                                      	*/
/*				modele.basefam											*/
/*			   	modele.baselog											*/
/*				base.foyer&anr2.										*/
/*				base.menage&anr2.										*/
/*			   	imput.accedant											*/		
/* En sortie : 	modele.basepa (+ ident_PA dans modele.baseind)			*/

/*ATTENTION : le calcul de la PA ne sera finalis� qu'apr�s le pgm "application_non_recours"	*/
		
/********************************************************************************************/
/* Plan [similaire au calcul du RSA]

Partie I : Calcul de la base ressources des foyers � partir des diff�rents types de revenus :
	1. 	revenus individuels : revenus d'activit� (trimestrialis�s) et prestations individuelles
	2. 	revenus de la famille CAF;
	3. 	revenus non individualisables des foyers fiscaux => on les attribue au d�clarant 
		(et donc au foyer du d�clarant);
	4. 	revenus non individualisables du m�nage => on les attribue � la pr du m�nage ; 
	5. 	int�gration des infos ressources au niveau du foyer 
			=> table res_pa et calcul des bases ressources trimestrielles

Partie II : Travail sur les foyers 
	1. 	r�cup�ration de quelques infos familiales
	2. 	d�compte des adultes et des personnes � charge par foyer
	3. 	cr�ation de la table des foyers avec toutes les infos pour le calcul de la PA
	4. 	r�cup�ration des infos AL (montant et statut) n�cessaires au calcul du forfait logement

Partie III : calcul de la PA
	1. 	Calcul de la PA et du forfait logement avant exclusion des PAC ayant des ressources
	2. 	Rep�rage des pac ayant des ressources, donc pouvant sortir du foyer  
	3. 	S�lection des PAC � exclure
	4. 	Recalcul de la PA sans les PAC en question pour les foyers concern�s par une exclusion
	5. 	Calcul de la PA pour les jeunes exclus du foyer
	6.	Table avec ensemble des foyers PA, mise � z�ro en de�a du seuil de versement 

Partie IV :  Contour des foyers PA (cr�ation ident_pa)										*/
/********************************************************************************************/


/************************************************************************************************
* Partie I : calcul de la base ressources des foyers � partir des diff�rents types de ressources 
			 	> construction de la table RES_PA 
*************************************************************************************************/

/*1. LES RESSOURCES INDIVIDUELLES > table RES_IND :
	- les revenus d'activit� et de remplacement, trimestrialis�s 
	- les prestations individuelles: dont l'AAH */
/* On supprime ici les PAC qui per�oivent l'AAH, qui seront trait�es plus tard avec les PAC exclues */ 

proc sort data=base.baserev
	(keep= ident noi zsali&anr2._t1-zsali&anr2._t4 zchoi&anr2._t1-zchoi&anr2._t4 zrsti&anr2._t1-zrsti&anr2._t4 
			zpii&anr2._t1-zpii&anr2._t4 zindi&anr2._t1-zindi&anr2._t4 zalri&anr2. zrtoi&anr2.) 
	 out=baserev; by ident noi; run;
proc sort data=modele.baseind
	(keep=ident noi ident_rsa ident_fam noicon noienf01 naia quelfic cal0 aah caah asi aspa statut_rsa wpela&anr2. acteu6 lprm) 
	 out=baseind; by ident noi; run;
proc sort data=travail.irf&anr.e&anr. 
	(keep= ident noi contra)	out=irf&anr.e&anr.; by ident noi; run;

data RessTrim;
	merge 	baserev (rename= (zsali&anr2._t1=zsaliT1 zsali&anr2._t2=zsaliT2 zsali&anr2._t3=zsaliT3 zsali&anr2._t4=zsaliT4
							  zchoi&anr2._t1=zchoiT1 zchoi&anr2._t2=zchoiT2 zchoi&anr2._t3=zchoiT3 zchoi&anr2._t4=zchoiT4
							  zrsti&anr2._t1=zrstiT1 zrsti&anr2._t2=zrstiT2 zrsti&anr2._t3=zrstiT3 zrsti&anr2._t4=zrstiT4
							  zpii&anr2._t1=zpiiT1 zpii&anr2._t2=zpiiT2 zpii&anr2._t3=zpiiT3 zpii&anr2._t4=zpiiT4
							  zindi&anr2._t1=zindiT1 zindi&anr2._t2=zindiT2 zindi&anr2._t3=zindiT3 zindi&anr2._t4=zindiT4))
	       	baseind (in=a);
	by ident noi; 
	if a & ident_rsa ne '';

	/* rep�rage des PAC qui touchent l'AAH et des revenus d'activit� 
	(elles formeront un foyer PA ind�pendant)*/
	pac_aah=(statut_rsa='pac' & aah & sum(zsalit1-zsalit4,zindiT1-zindiT4)>0) ;
run;

/* Calcul du bonus individuel pour les personnes de 18 ans ou plus, et ajout de l'info dans la table res_ind */

data resstrim_ind;
	merge	irf&anr.e&anr.  
			resstrim (in=a) ;
	by ident noi;
	if a;
	/* bonus pour tous les actifs d'un foyer quel que soit leur statut mais on enl�ve �tudiants et apprentis*/
	if &anref.-input(naia,4.)>= &age_pa. ;

	%macro bonus;	
		%do i=1 %to 4 ;
		/* on rep�re les �tudiants et apprentis non �ligibles du fait de leur niveau de ressources : 
			variable etud_apprent_noneli donne 1 si on est �tudiant ou apprenti non �ligible et 0 sinon */
			etud_apprent_noneli_T&i.= (acteu6='5' or contra='5') * (sum(zsalit&i.,zindit&i.)/3 < &plaf_exclu_pac.);

			revact&i.=sum(0,zsalit&i.,zindit&i.);

		/* AAH et PI sont consid�r�s comme des revenus d'activit� au del� d'un certain seuil de revenu d'acitivt�*/
		/* �cart � la l�gislation : on n'int�gre pas ATMP et  pensions militaires*/
			revact_presta&i. = (aah+caah)/4 + zpiiT&i.*(&anleg.>2016); 
			revact_presta4 = (aah+caah)/4 + zpiiT4;  /* pensions d'invalidit� int�gr�es � partir d'octobre 2016 seulement*/
			if revact&i.>=3*&seuil_pa_aah.*&smich. then revact&i. = sum(revact&i., revact_presta&i.); 

			bonus&i. = 0;
			actif&i.=(revact&i.>3*&revmin_pa.*&smich.);	/* revenu d'activit� minimum pour b�n�ficier du bonus */
			actiftout&i.=(revact&i.>0); 
			if actif&i. & etud_apprent_noneli_T&i. ne 1 then do;
				if revact&i.<3*&revplat_pa.*&smich. then 
					bonus&i.=(revact&i.-3*&revmin_pa.*&smich.)*(&bmax_pa.*&forf_pa.)/(3*&revplat_pa.*&smich.-3*&revmin_pa.*&smich.);
				if revact&i.>=3*&revplat_pa.*&smich. then 
					bonus&i.=&bmax_pa.*&forf_pa.;
				end;

		/* pour la suite : on rep�re aussi les adultes (hors PAC) �ligibles � la PA */
			civ_eli_T&i=(statut_rsa ne 'PAC' and revact&i.>0 and etud_apprent_noneli_T&i. ne 1) ;
		%end;
	%mend; 

	%bonus;

	age = &anref.-input(naia,4.);
	bonus_an=bonus1+bonus2+bonus3+bonus4;
	eligb=(bonus_an>0);
	actif=(actif1>0!actif2>0!actif3>0!actif4>0);
	actiftout=(actiftout1>0!actiftout2>0!actiftout3>0!actiftout4>0);
run;


/* Regroupement des revenus individuels par foyer rsa => table res_ind */
/* On supprime les PAC qui touche l'AAH, elles seront trait�es plus tard dans la partie III */
/* A CONFIRMER : on ne supprime que celles qui ont des revenus d'activit� */

proc means data=RessTrim (where=(pac_aah ne 1)) noprint nway;
	class ident_rsa;
	var zsaliT1-zsaliT4 zchoiT1-zchoiT4 zrstiT1-zrstiT4 zpiiT1-zpiiT4 zindiT1-zindiT4
		aah caah asi aspa zalri&anr2. zrtoi&anr2.;
	output out=res_ind(drop=_type_ _freq_) sum=;
	run;

proc sort data=resstrim_ind; by ident_rsa; run;
%cumul(basein=	resstrim_ind (where=(pac_aah ne 1)),
       baseout=	bonus_ind,
       varin=	bonus1 bonus2 bonus3 bonus4 civ_eli_T1 civ_eli_T2 civ_eli_T3 civ_eli_T4,
       varout=	bonus1 bonus2 bonus3 bonus4 nbciv_eli_T1 nbciv_eli_T2 nbciv_eli_T3 nbciv_eli_T4,
	   varAgregation=	ident_rsa);

data res_ind;
	merge res_ind (in=a)
		  bonus_ind;
	by ident_rsa;
	if a;
run;

/*2. LES RESSOURCES DE LA FAMILLE CAF > table RES_FAM
	- les prestations familiales + r�cup�ration de variables famille utiles (p_iso age_enf)	*/

data famille(drop = mpaje mois00);
	set modele.basefam(keep=ident_fam afxx0 asf_horsReval2014 paje_base droit_ab comxx majo_comxx clca pers_iso age_enf mois00);
	/* d�duction des ressources familiales d'une partie de l'AB de la paje la 1�re ann�e : 3 mois pour la PA major�e */
	if paje_base>0 & mois00 ne '' AND pers_iso = 1 then do ; 
		if droit_AB='plein' then mpaje=&paje_m.; 
		if droit_AB='partiel' then mpaje=&paje_m_partiel.;
		if mois00='11' then  paje_base=paje_base - mpaje; 
		else if mois00='10' then  paje_base=paje_base - 2*mpaje; 
		else paje_base=paje_base - 3*mpaje; 
		end; 
	run;

/*r�cup�ration du num�ro ident_rsa de baseind pour le mettre dans la table famille (cr�ation de la table lien ident_fam<=>ident_rsa)*/
proc sort data=famille nodupkey; by ident_fam; run;
proc sort data=baseind(keep=ident_fam ident_rsa where=(ident_fam>'')) out=lien nodupkey; by ident_fam; run;
data famille;
	merge famille (in=a) lien;
	comxx=comxx-majo_comxx;/* on enl�ve la majoration du compl�ment familial de la base ressources (si pas de majorations alors majo_comxx=0) */
	by ident_fam;
	if a;
	run;
/* somme des ressources familiales par foyer rsa => table res_fam */
proc means data=famille noprint nway;
	class ident_rsa;
	var afxx0 asf_horsReval2014 paje_base comxx clca;
	output out=res_fam(drop=_type_ _freq_) sum=;
	run;


/*3. LES RESSOURCES DU FOYER FISCAL > table RES_FOY
	- toutes les ressources non individualisables du foyer (ressources de l'ann�e simul�e)
	HYPOTHESE : on les attribue au d�clarant du foyer fiscal, donc � son foyer */

data foyer(keep=ident noi declar zvalf zetrf zvamf zfonf zracf separation);
	set base.foyer&anr2.;
	/* omission dans les agr�gats des foyers des revenus imput�s par ailleurs � leurs m�nages
	et qui seront comptabilis�s � l'�tape 4 */
	zvamf=sum(0,zvamf,-_2ch,-_2fu);
	zvalf=zvalf-max(0,_2dh);
	/* rep�rage des divorces ou ruptures de pacs dans l'ann�e pour simuler du RSA major� */
	separation=(xyz='Y');
	run;
/* r�cup�ration du num�ro ident_rsa de baseind pour le mettre dans la table foyer */
proc sort data=foyer; by ident noi;
proc sort data=baseind; by ident noi; run;
data foyer;
	merge 	foyer (in=a) 	
			baseind (keep=ident noi ident_rsa);
	by ident noi;
	if a;
	run;
/* somme des ressources du foyer fiscal par foyer rsa => table res_foy */
proc means data=foyer noprint nway;
	class ident_rsa;
	var zracf zfonf zetrf zvamf zvalf separation;
	output out=res_foy(drop=_type_ _freq_) sum=;
	run;


/*4. LES RESSOURCES DU MENAGE > table RES_MEN
	- les produits financiers imput�s au m�nage l'ann�e simul�e :
	En th�orie, il faut prendre en compte dans la BR les revenus du capital (lorsqu'ils sont d�clar�s)
	et � d�faut 3% (par an, soit 0,75% par trimestre) du capital d�tenu
	(y compris l'�pargne disponible, type livret A et l'�pargne non plac�e, type compte courant).
	cela n'�tant pas possible, on utilise les revenus des produits financiers imput�s aux m�nages par RPM.
	HYPOTHESE : on les attribue � la personne de r�f�rence du m�nage, donc � son foyer */

proc sort data=base.menage&anr2.; by ident; run;
proc sort data=baseind; by ident noi; run;
data prodfin;
	merge 	baseind (in=a) 
			base.menage&anr2. (keep=ident produitfin_i);
	by ident;
	if a;
	if lprm='1' then prodfin=produitfin_i;
	else prodfin=0;
	run;
/* somme des ressources du m�nage par foyer  => table res_men */
proc means data=prodfin noprint nway;
	class ident_rsa;
	var prodfin;
	output out=res_men(drop=_type_ _freq_) sum=;
	run;


/*5. CONSTRUCTION DE LA BR DE LA PA A PARTIR DES 4 ORIGINES DES RESSOURCES > table RES_PA
	- cr�ation de la table res_pa qui regroupe les ressources au niveau du foyer 
	- calcul des bases ressources trimestrielles */

/* Rappel : les PAC percevant l'AAH et des revenus d'activit� sont exclues de cette table 
	(elles seront trait�s au point III ) */

proc sort data=res_ind; by ident_rsa;
proc sort data=res_fam; by ident_rsa;
proc sort data=res_foy; by ident_rsa; 
proc sort data=res_men; by ident_rsa; run;
data res_pa;
	merge 	res_ind (in=a) 
			res_fam 
			res_foy 
			res_men;
	by ident_rsa;
	if a ;
	array num _numeric_; do over num; if num=. then num=0; end;

	/* calcul des revenus d'activit� pris en compte chaque trimestre dans la base ressources (38%)*/
	rce1_pa1=sum(0,zsaliT1,zindiT1);
	rce1_pa2=sum(0,zsaliT2,zindiT2);
	rce1_pa3=sum(0,zsaliT3,zindiT3);
	rce1_pa4=sum(0,zsaliT4,zindiT4);

	/* calcul de toutes les autres ressources prises en compte chaque trimestre : 
	les	revenus du ch�mage et de la retraite sont consid�r�s par trimestre 
	et les autres ressources sont liss�es sur l'ann�e en divisant par 4. */

	rce2_pa1=max(0,sum(0,zchoiT1,zrstiT1,zpiiT1*(&anleg.<=2016))+
		1/4*sum(0,zrtoi&anr2.,zalri&anr2.,zracf,zfonf,zvamf,zetrf,zvalf,prodfin,
				clca,afxx0,paje_base,comxx,asf_horsReval2014,asi,aspa));
	rce2_pa2=max(0,sum(0,zchoiT2,zrstiT2,zpiiT2*(&anleg.<=2016))+
		1/4*sum(0,zrtoi&anr2.,zalri&anr2.,zracf,zfonf,zvamf,zetrf,zvalf,prodfin,
				clca,afxx0,paje_base,comxx,asf_horsReval2014,asi,aspa));
	rce2_pa3=max(0,sum(0,zchoiT3,zrstiT3,zpiiT3*(&anleg.<=2016))+
		1/4*sum(0,zrtoi&anr2.,zalri&anr2.,zracf,zfonf,zvamf,zetrf,zvalf,prodfin,
				clca,afxx0,paje_base,comxx,asf_horsReval2014,asi,aspa));
	rce2_pa4=max(0,sum(0,zchoiT4,zrstiT4)+
		1/4*sum(0,zrtoi&anr2.,zalri&anr2.,zracf,zfonf,zvamf,zetrf,zvalf,prodfin,
				clca,afxx0,paje_base,comxx,asf_horsReval2014,asi,aspa));

	/* AAH et PI sont soit des prestations soit des revenus d'activit� selon un seuil de revenu d'acitivt�*/
	/*�cart � la l�gislation : on n'int�gre pas ATMP et  pensions militaires*/
	revact_presta1 = (aah+caah)/4 + zpiiT1*(&anleg.>2016);
	revact_presta2 = (aah+caah)/4 + zpiiT2*(&anleg.>2016);
	revact_presta3 = (aah+caah)/4 + zpiiT3*(&anleg.>2016);
	revact_presta4 = (aah+caah)/4 + zpiiT4; /*les pensions invalidit� sont int�gr�es � partir d'octobre 2016*/

	%macro ajout_aah;	
		%do i=1 %to 4 ;
			if rce1_pa&i.<3*&seuil_pa_aah.*&smich. then do ;
				rce2_pa&i.  = sum(0, rce2_pa&i., revact_presta&i) ; /*consid�r�es comme une prestation*/
				end;
			if rce1_pa&i.>=3*&seuil_pa_aah.*&smich. then do;
				rce1_pa&i.  = sum(0, rce1_pa&i., revact_presta&i.); /*consid�r�es comme un revenu d'activit�*/
				end;
		%end;
	%mend; 
	%ajout_aah;
run; 


/***********************************************
* Partie II : cr�ation de la table FOYER_PA
************************************************/
/* 
On construit une table de foyers � partir des individus de baseind en plusieurs �tapes :
	- r�cup�ration de 2 variables de la table famille
	- d�compte des adultes et des personnes � charge par foyer (hors pac aah)
	- construction de la table foyers en supprimant ceux compos�s uniquement de personnes de moins de 18 ans
	- r�cup�ration des infos sur les aides au logement et le statut d'occupation du logt
*/

/* 1. R�cup�ration de variables issues de la table famille */
proc sort data=famille; by ident_rsa ident_fam; run; 
data pa_fam (keep=ident_rsa ident_fam age_enf pers_iso); 
	set famille;  
	by ident_rsa ident_fam;
	if first.ident_rsa; 
	run; 
/*TODO : dans les cas o� 2 familles composent un foyer , on ne prend les infos que d'une famille */

/* 2. D�compte des adultes et des personnes � charge par foyer (hors pac aah) */

proc sort data=baseind; by ident_rsa; run;
data nb_pac; 
	set baseind (keep=ident wpela&anr2. noi ident_rsa ident_fam noicon noienf01 naia quelfic statut_rsa aah acteu6
				 in=a where=(ident_rsa ne ''));
	by ident_rsa;
	/* on enl�ve les pac aah de la table individuelle servant � fabriquer les foyers */
	if statut_rsa='pac' & aah then delete;
	retain nbpac nbciv agemax_foyer; 
	if first.ident_rsa then do; nbpac=0; nbciv=0; agemax_foyer=0; end;
	if statut_rsa='pac' then nbpac=nbpac+1;
	else nbciv=nbciv+1;
	/* agemax_foyer donne l'�ge de la personne la plus �g�e du foyer*/
	agemax_foyer=max(agemax_foyer,&anref.-input(naia,4.));
	run;
proc sort data=nb_pac; by ident_rsa; run;
data nb_pac; 
	set nb_pac(where=(agemax_foyer>=&age_pa.));
	by ident_rsa; 
	if last.ident_rsa; 
run; 

/*3. Fusion des 3 tables de niveau foyer rsa constitu�es jusqu'� maintenant (sans compter les PAC AAH) */
/* On ne garde que les foyers dont tous les membres ont 18 ans ou plus */
data foyer_pa1;
	merge 	res_pa 
			pa_fam 
			nb_pac (in=a keep=ident ident_rsa nbpac nbciv wpela&anr2.);
	by ident_rsa; 
	if a; 
	run;

/*4.  R�cup�ration des infos logement : AL et statut d'occupation (pareil que pour le RSA) */
/* A cette �tape on va aussi modifier le statut d'occupation pour les foyers RSA constitu�s d'enfants de plus de 20 ans 
	qui habitent avec leurs parents (> consid�r�s comme log�s gratuitement) */

proc sql ; 
  	create table pa2_ind as
  	select a.ident_rsa, 
		   b.ident_log,
		   c.AL, 
		   d.alaccedant,
		   e.logt
  	from foyer_pa1 as a
	   	 left join modele.baseind AS b		on 	a.ident_rsa = b.ident_rsa 
  	     left join modele.baselog AS c 		on 	b.ident_log = c.ident_log 
   	     left join imput.accedant AS d 		on 	a.ident = d.ident 
 	     left join base.menage&anr2. AS e	on 	a.ident = e.ident 
	where a.ident_rsa >"" ;
quit ;
/* note : pour les FIP, ident_rsa renseign� mais pas ident_fam ni ident_log > pas de calcul d'AL pour eux */

/* on enl�ve les doublons sur ident_rsa * ident_log */
proc sort data= pa2_ind out=pa2_log nodupkey ; by ident_log ident_rsa ; run ;

/* On modifie le statut d'occupation pour les enfants de plus de 20 ans qui habitent avec leurs parents (absents de modele.baselog) */

proc sort data= modele.baselog ; by ident_log ; run ;
data pa2_log2 ;
	merge pa2_log (in=a )
  		  modele.baselog (in=b keep=ident_log) ;
	by ident_log ;
	if a ;
	if not b and ident_log>"" and logt in ("3","4","5") then logt2="6" ; else logt2=logt ;
	run ; 

/* Calcul des AL per�ues par le foyer ident_rsa */
 
proc sql ;
	create table pa2_log3 as
	select *, max(al) as al_tot, count(distinct ident_log) as nblog 
	from pa2_log2 
	group by ident_rsa ;
	quit ;

/* table au niveau du foyer ident_rsa */
/* Un seul statut d'occupation par foyer : s'il est compos� de 2 foyers logements dont un log� gratuit, on garde l'autre statut */ 

proc sort data=pa2_log3 ; by ident_rsa logt2 ; run ;
data foyer_pa2 ; 
	set pa2_log3 (keep=ident_rsa al_tot alaccedant logt2) ; 
	by ident_rsa logt2 ; 
	if first.ident_rsa ; 
	array tout _numeric_; do over tout; if tout=. then tout=0; end;
	rename al_tot = al ; 
	run ;


/**************************************
* Partie III : calcul de la PA
***************************************/
/* Table de d�part : FOYER_PA avec l'ensemble des ressources par foyer RSA				*/
/* Tables en sortie :  FOYER_PA_HORSEXCLUJ et PAC_EXCLUES avec montants de PA �ligibles	*/
/*
1. Calcul en incluant toutes les PAC du foyer
2. Rep�rage des PAC qui peuvent sortir du foyer : PAC de 18 � 25 ans avec des ressources personnelles
3. S�lection des PAC � exclure
4. Recalcul de la PA pour les foyers concern�s par une exclusion
5. Calcul de la PA pour les 3 types de jeunes exclus du foyer de leur parents
6. Table avec ensemble des foyers PA et suppression de la PA en de�a du seuil de versement
*/

/*1. CALCUL EN INCLUANT TOUTES LES PAC DU FOYER (certaines seront exclues plus tard)
	- a. calcul du montant forfaitaire et du forfait logement pour toutes les configuations
	- b. calcul de la PA en fonction de ces infos, des revenus d'activit� et des autres ressources du foyer */

data foyer_pa (drop= m_pa:); 
	merge foyer_pa1 (in=a)
		  foyer_pa2 (in=b);
	by ident_rsa ;
	if a ;
	%init_valeur(forf_log_pa);

 %macro Calcul_PA(nbciv,nbpac,pa_eli);

	/*a. calcul du montant forfaitaire et du forfait logement */
	nb_foyer=&nbciv.+&nbpac.; 
	if nb_foyer=1 then do; 
		pact_forf=&forf_pa.; 
		forf_log_pa=&forf_pa.*&forf_log1.; end;
	if nb_foyer=2 then do; 
		pact_forf=&forf_pa.*(1+&rsa2.); 
		forf_log_pa=&forf_pa.*(1+&rsa2.)*&forf_log2.; end;
	if nb_foyer>2 then do; 
		pact_forf=&forf_pa.*(1+&rsa2.+&rsa3.*(nb_foyer-2)+ &rsa4.*(&nbpac.-2)*(&nbpac.>2)); 
		forf_log_pa=&forf_pa.*(1+&rsa2.+&rsa3.)*&forf_log3.; end;

	/* Pour les locataires ou acc�dants non aid�s: FL=0*/
	if logt2 in ('3','4','5') & al=0 then forf_log_pa=0; 
		/* Pour les locataires/propri�taires ayant une aide : 
		si FL>montant de l'allocation => on retire le montant de l'AL  
		Dans ces cas, on attribue directement au FL la valeur de l'AL � d�duire */
	if logt2 in ('3','4','5') & al>0 & forf_log_pa>al/12 then forf_log_pa=al/12;
	if logt2 in ('1','2') & alaccedant>0 & forf_log_pa>alaccedant/12 then forf_log_pa=alaccedant/12; 
	
	/* �ligibilit� et application du montant major� */
	%nb_enf(enf03,0,3,age_enf);
	%nb_enf(e_c,0,&age_pf.,age_enf);
	if (enf03>0 & pers_iso=1) ! (e_c>0 & separation>0) then do;
		/* montant major� */
		pact_forf=(&mrsa1.+&nbpac.*&mrsa2.)*&forf_pa.;
		end;

	/*b. calul de la pa avec FL
	mise � 0 des montants de prestation trimestriels et vectorisation*/
	m_pa1=0; m_pa2=0; m_pa3=0; m_pa4=0;
	m_pa_socle1=0; m_pa_socle2=0; m_pa_socle3=0; m_pa_socle4=0;
	&pa_eli.1=0; &pa_eli.2=0; &pa_eli.3=0; &pa_eli.4=0;
	array nbciv_eli nbciv_eli_T1-nbciv_eli_T4;
	array bonus bonus1-bonus4;
	array rce1_pa rce1_pa1-rce1_pa4;
	array rce2_pa rce2_pa1-rce2_pa4;
	array m_pa m_pa1-m_pa4; /*�tape 1 de la PA*/
	array m_pa_socle m_pa_socle1-m_pa_socle4; /*�tape 2 de la PA*/
	array &pa_eli &pa_eli.1-&pa_eli.4; /*�tape 3 de la PA*/
	/* calcul par trimestre */
	do over m_pa;
		m_pa = max(0,3*(pact_forf+bonus) - (1-&trsa.)*rce1_pa - rce2_pa - 3*forf_log_pa); /* revenus activit� compt�s pour 38% dans la BR */
		m_pa_socle = max(0,3*(pact_forf) - rce1_pa - rce2_pa- 3*forf_log_pa); 
		/* on n'attribue pas la PA aux foyers dont les adultes (hors PAC) ne sont pas �ligibles
			(les PAC pourront en b�n�ficier s'ils sont �ligibles - �tape suivante) */
		if nbciv_eli < 1 then do ; 
			m_pa=0 ; 
			m_pa_socle=0 ; 
			end ; 
		/*�tape 3 du calcul de la PA*/
		&pa_eli = m_pa- m_pa_socle*(m_pa_socle>0);
		end;
 %mend Calcul_PA;

	%Calcul_PA(nbciv,nbpac,pa_eli);

	/*cr�ation d'une variable annuelle qui sera utilis�e pour d�terminer l'�ventuelle exclusion de pac*/
	pa_an = sum(0,of pa_eli1-pa_eli4);

run;


/*2. REPERAGE DES PAC QUI PEUVENT SORTIR DU FOYER : PAC de 18 � 25 ans avec des ressources personnelles */
/*  D�s qu'une PAC a des ressources personnelles au moins 1 trimestre, elle est excluable
	On enl�ve ici les �tudiants et apprentis non �ligibles du fait de ressources trop faibles */

/* A CONFIRMER : on ne consid�re que les PAC qui disposent de revenus d'activit� */
/* Ainsi les PAC qui per�oivent l'AAH ou l'ARE sans revenus d'activit� seront gard�s dans le foyer PA de leurs parents,
	(et leurs revenus seront donc int�gr�s � la base ressources du foyer */

proc sort data=RessTrim; by ident noi;
proc sort data=resstrim_ind; by ident noi; 

data pot_exclu; 
	merge RessTrim Resstrim_ind (keep=ident noi etud_apprent_noneli: bonus1-bonus4);
	by ident noi;
	if ident_rsa ne '' & statut_rsa='pac' & (&anref.-input(naia,4.)>=&age_pa.);
	%macro Exclusion_Potentielle;
		%do i=1 %to 4; 
			if  sum(0,zsaliT&i.,zindiT&i.)>0
				& etud_apprent_noneli_T&i. ne 1
				then pot_excluT&i.=1;
			else pot_excluT&i.=0; 
			%end; 
		%mend Exclusion_Potentielle;
	%Exclusion_Potentielle;
	run; 


/*3. SELECTION DES PAC A EXCLURE */

/* Exclusion d'office des PAC AAH excluables */
data excluj_aah ; set pot_exclu ; if aah ; run ; 

/* Pour les PAC hors AAH : calcul de la PA hors PAC pour les foyers concern�s par une exclusion potentielle */
/* Hypoth�se : si la PA du foyer sans la PAC est plus �lev�e qu'avec la PAC, celle-ci est exclue du foyer */

proc sort data=pot_exclu; by ident_rsa noi; run;
data pot_exclu1 ; 
	merge	pot_exclu (in=a rename=(bonus1-bonus4 = bonus_pac1-bonus_pac4))
			foyer_pa(keep= ident_rsa pa_eli: rce1: rce2: nbpac nbciv age_enf pers_iso pa_an separation bonus1-bonus4 nbciv_eli: al alaccedant logt2);
	by ident_rsa; 
	if pot_excluT1 = 1 ! pot_excluT2 = 1 ! pot_excluT3 = 1 ! pot_excluT4 = 1 ;
run ; 

data excluj1 excluj2 (drop = m_pa:) ; 
	set pot_exclu1 ;
	if not aah ;

	/* calcul des ressources du foyer en otant les ressources personnelles de la pac*/
	rce1_pa1 = rce1_pa1-sum(0,zsaliT1,zindiT1);
	rce1_pa2 = rce1_pa2-sum(0,zsaliT2,zindiT2);
	rce1_pa3 = rce1_pa3-sum(0,zsaliT3,zindiT3);
	rce1_pa4 = rce1_pa4-sum(0,zsaliT4,zindiT4);
	rce2_pa1 = rce2_pa1-zchoiT1-zrstiT1-zpiiT1-(asi+zalri&anr2.+zrtoi&anr2.)/4;
	rce2_pa2 = rce2_pa2-zchoiT2-zrstiT2-zpiiT2-(asi+zalri&anr2.+zrtoi&anr2.)/4;
	rce2_pa3 = rce2_pa3-zchoiT3-zrstiT3-zpiiT3-(asi+zalri&anr2.+zrtoi&anr2.)/4;
	rce2_pa4 = rce2_pa4-zchoiT4-zrstiT4-zpiiT4-(asi+zalri&anr2.+zrtoi&anr2.)/4;
	bonus1 = bonus1 - bonus_pac1 ;
	bonus2 = bonus2 - bonus_pac2 ;
	bonus3 = bonus3 - bonus_pac3 ;
	bonus4 = bonus4 - bonus_pac4 ;

	/*TO DO : pour les pensions d'invalidit�, voir s'il ne faudrait pas faire comme pour l'AAH � partir du T4 2016*/

	/*calcul de la PA du foyer si la PAC �tait exclue du foyer*/
	%Calcul_PA(nbciv,nbpac-1,pa_eli_exclu);
	pa_exclu_an = sum(0,of pa_eli_exclu1-pa_eli_exclu4);

	/* Si la PA du foyer sans la pac est plus �lev�e qu'avec la PAC, on fixe exclu � 1 */
	/* On sort aussi les jeunes des foyers ayant des droits nuls */
	exclu=(pa_exclu_an > pa_an) ; 
	if pa_an = 0 & pa_exclu_an = 0 then exclu=2 ; 

	drop al alaccedant logt2 ;

	/* on ne garde en sortie que les pac � exclure */
	if exclu=1 then output excluj1; /* cas 1 : PAC pour lesquelles le montant de PA per�u par le foyer hors PAC sera sup�rieur */
	if exclu=2 then output excluj2;	/* cas 2 : PAC pour lesquelles le montant de PA per�u par le foyer avec ou sans la PAC est nul */
	run;

data excluj ; set excluj1 excluj2 ; run ;


/*4. RECALCUL DE LA PA pour les foyers concern�s par l'exclusion d'une ou plusieurs PAC */
/* On refait le calcul ci-dessus en enlevant toutes les PAC exclues du foyer */

proc summary nway data=excluj ;
	class ident_rsa ;
	var 	zsaliT1-zsaliT4 zindiT1-zindiT4	zchoiT1-zchoiT4 zrstiT1-zrstiT4 zpiiT1-zpiiT4 asi zalri&anr2. zrtoi&anr2.
			bonus_pac1-bonus_pac4 ;
	output out= excluj_foy (drop=_type_ rename=(_freq_=nbpac_exclues)) sum= ;	 
run ;
data PA_foy_horsexcluj ;
  	merge foyer_pa(in=a keep=ident_rsa pa_eli: rce1: rce2: nbpac nbciv age_enf pers_iso pa_an separation bonus1-bonus4 nbciv_eli: al alaccedant logt2)
		  excluj_foy (in=b) ;
  	by ident_rsa ; 
  	if b ;

	rce1_pa1 = rce1_pa1-sum(0,zsaliT1,zindiT1);	
	rce1_pa2 = rce1_pa2-sum(0,zsaliT2,zindiT2);
	rce1_pa3 = rce1_pa3-sum(0,zsaliT3,zindiT3);
	rce1_pa4 = rce1_pa4-sum(0,zsaliT4,zindiT4);
	rce2_pa1 = rce2_pa1-zchoiT1-zrstiT1-zpiiT1-(asi+zalri&anr2.+zrtoi&anr2.)/4;
	rce2_pa2 = rce2_pa2-zchoiT2-zrstiT2-zpiiT2-(asi+zalri&anr2.+zrtoi&anr2.)/4;
	rce2_pa3 = rce2_pa3-zchoiT3-zrstiT3-zpiiT3-(asi+zalri&anr2.+zrtoi&anr2.)/4;
	rce2_pa4 = rce2_pa4-zchoiT4-zrstiT4-zpiiT4-(asi+zalri&anr2.+zrtoi&anr2.)/4;
	bonus1 = bonus1 - bonus_pac1 ;
	bonus2 = bonus2 - bonus_pac2 ;
	bonus3 = bonus3 - bonus_pac3 ;
	bonus4 = bonus4 - bonus_pac4 ;
	nbpac=nbpac-nbpac_exclues ;

	/*calcul de la PA du foyer sans les PAC exclues*/
	%Calcul_PA(nbciv,nbpac,pa_eli);

	pa_an = sum(0,of pa_eli1-pa_eli4);
run ;

data foyer_pa_horsexcluj (keep=ident ident_rsa pa_eli1-pa_eli4 pa_an bonus1-bonus4 pact_forf forf_log_pa 
								rce1_pa: rce2_pa: nbpac: enf03 pers_iso e_c separation wpela&anr2.) ; 
	merge foyer_pa(in=a) 
		  PA_foy_horsexcluj (in=b keep=ident_rsa pa_eli: pa_an bonus1-bonus4 pact_forf forf_log_pa rce1: rce2: nbpac:) ; 
	by ident_rsa; 
	if a;
	if not b then nbpac_exclues=0 ;
run;


/*5. CALCUL DE LA PA POUR TOUS LES JEUNES EXCLUS DU FOYER DE LEURS PARENTS */

data pacs;
	set excluj_aah (keep=ident noi ident_rsa wpela&anr2.)
		excluj1 (keep=ident noi ident_rsa wpela&anr2.)
		excluj2 (keep=ident noi ident_rsa wpela&anr2.);
run;

proc sort data=pacs ; by ident noi ; run ;
proc sort data=resstrim_ind; by ident noi; run;

data pac_exclues (keep=ident noi ident_rsa pa_eli1-pa_eli4 bonus1-bonus4 pact_forf forf_log_pa 
						rce1_pa: rce2_pa: enf03 pers_iso e_c separation wpela&anr2.);
	merge	pacs (in=a)
			resstrim_ind ;
	by ident noi;
	if a;

	nbciv=1; nbpac=0; age_enf=repeat('0',24); pers_iso=0; separation=0; al=0; alaccedant=0; logt2='6';
	nbciv_eli_T1=1 ; nbciv_eli_T2=1 ; nbciv_eli_T3=1 ; nbciv_eli_T4=1 ; 

	rce1_pa1=sum(0,zsaliT1,zindiT1);
	rce1_pa2=sum(0,zsaliT2,zindiT2);
	rce1_pa3=sum(0,zsaliT3,zindiT3);
	rce1_pa4=sum(0,zsaliT4,zindiT4);
	rce2_pa1=max(0,sum(0,zchoiT1,zrstiT1)+1/4*sum(0,zrtoi&anr2.,zalri&anr2.,asi));
	rce2_pa2=max(0,sum(0,zchoiT2,zrstiT2)+1/4*sum(0,zrtoi&anr2.,zalri&anr2.,asi));
	rce2_pa3=max(0,sum(0,zchoiT3,zrstiT3)+1/4*sum(0,zrtoi&anr2.,zalri&anr2.,asi));
	rce2_pa4=max(0,sum(0,zchoiT4,zrstiT4)+1/4*sum(0,zrtoi&anr2.,zalri&anr2.,asi));

	/* AAH et PI sont soit des prestations soit des revenus d'activit� selon un seuil de revenu d'acitivt�*/
	revact_presta1 = (aah+caah)/4 + zpiiT1*(&anleg.>2016); 
	revact_presta2 = (aah+caah)/4 + zpiiT2*(&anleg.>2016);
	revact_presta3 = (aah+caah)/4 + zpiiT3*(&anleg.>2016);
	revact_presta4 = (aah+caah)/4 + zpiiT4;  
	%ajout_aah;
	
	%Calcul_PA(nbciv, nbpac, pa_eli);
run;


/*6. TABLE AVEC ENSEMBLE DES FOYERS PA et suppression de la PA en de�a du seuil de versement */

%Macro Final_PA;
  data basepa; 
	set foyer_pa_horsexcluj (keep=ident ident_rsa pa_eli1-pa_eli4 bonus1-bonus4 pact_forf forf_log_pa
								rce1_pa: rce2_pa: nbpac: enf03 pers_iso e_c separation wpela&anr2.)
		pac_exclues (in=b keep=ident ident_rsa noi pa_eli1-pa_eli4 bonus1-bonus4 pact_forf forf_log_pa 
								rce1_pa: rce2_pa: enf03 pers_iso e_c separation wpela&anr2.);

	pac_exclue=b ;
	array num _numeric_; do over num; if num=. then num=0; end;
	%do i=1 %to 4;
		if pa_eli&i.<3*&pa_min. then pa_eli&i.=0 ;	/* Application du seuil de versement */
		if &anleg.<2016 then pa_eli&i.=0 ; 			/* PA � 0 avant 2016 */
	%end;

	patot_eli= sum(of pa_eli1-pa_eli4);
  run;
%Mend Final_PA;	 
%Final_PA;


/***********************************************************************************
* Partie IV : Contour des foyers PA (cr�ation ident_pa) ET BASE FINALE MODELE.BASEPA	
************************************************************************************/

/* Le contour du foyer PA est le m�me que le foyer RSA par d�faut, seuls les nouveaux foyers de jeunes sont � cr�er */
/* Pour construire les foyers PA, on part donc du foyer RSA et on cr�� pour les PAC exclues des nouveaux foyers PA */
/* En pratique, on cr�e ident_PA avec un caract�re de plus que ident_RSA, =1 par d�faut, et � partir de 2 pour les PAC exclues */ 

proc sort data=basepa ; by ident_rsa pac_exclue noi ; run ;
data basepa2 ;
	set basepa;
	by ident_rsa pac_exclue ;
	length ident_pa $11 ; /* avec un caract�re de plus que ident_rsa */
	if first.ident_rsa then numpac=0 ;
	retain numpac ; 
	numpac=numpac+1 ;
	ident_pa = compress(ident_rsa !! put(numpac,1.)) ; /* dernier chiffre � partir de 2 pour les PAC exclues */	
run ;

/* Table modele.BASEPA ne contenant que les personnes �ligibles � la PA */

data modele.basepa ;
	retain ident ident_pa ident_rsa patot_eli pa_eli1-pa_eli4 ; /* pour avoir ces variables en premier dans la table */
	set basepa2 (drop=numpac noi) ;
	if patot_eli>0 ;

	label		pa_eli1='montant de PA au T1 en plein recours'
				pa_eli2='montant de PA au T2 en plein recours'
				pa_eli3='montant de PA au T3 en plein recours'
				pa_eli4='montant de PA au T4 en plein recours'
				patot_eli='PA totale annuelle en plein recours'
				bonus1='bonus PA mensuel au T1 en plein recours'
				bonus2='bonus PA mensuel au T2 en plein recours'
				bonus3='bonus PA mensuel au T3 en plein recours'
				bonus4='bonus PA mensuel au T4 en plein recours'
				pact_forf='Montant forfaitaire PA'
				forf_log_pa='forfait logement de la PA'
				rce1_pa1 = 'revenus professionnels au T1' 
				rce1_pa2 = 'revenus professionnels au T2' 
				rce1_pa3 = 'revenus professionnels au T3' 
				rce1_pa4 = 'revenus professionnels au T4' 
				rce2_pa1 = 'autres revenus entrant dans la BR de la PA (hors FL) au T1' 
				rce2_pa2 = 'autres revenus entrant dans la BR de la PA (hors FL) au T2' 
				rce2_pa3 = 'autres revenus entrant dans la BR de la PA (hors FL) au T3' 
				rce2_pa4 = 'autres revenus entrant dans la BR de la PA (hors FL) au T4' 
				nbpac = 'nombre de PAC dans le foyer PA'
				nbpac_exclues = 'nombre de PAC exclues du foyer RSA'
				ident_pa = 'Identifiant famille au sens de la PA au 31/12' ;
run;


/* Int�gration de ident_pa dans modele.baseind */

proc sort data=basepa2 nodupkey ; by ident noi ; run ;
proc sort data=modele.baseind ; by ident noi ; run ;

data modele.baseind ;
	merge 	modele.baseind (in=a)
			basepa2(keep= ident noi ident_pa where=(noi>='01') in=b) ;
	by ident noi;
	if a;
	if not b then ident_pa = compress(ident_rsa !!'1') ; 
run;



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
