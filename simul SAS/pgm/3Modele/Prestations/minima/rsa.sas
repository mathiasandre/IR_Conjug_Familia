*************************************************************************************;
/*																					*/
/*								Calcul du RSA										*/
/*																					*/
*************************************************************************************;

/* Calcul de l'�ligibilit� et des montants de RSA                  	*/
/* En entr�e : 	base.baserev	                                    */
/* 				modele.baseind                                      */
/*				modele.basefam										*/
/*				base.foyer&anr2.									*/
/*				base.menage&anr2.									*/
/* En sortie : 	modele.basersa                                      */

/*ATTENTION : le calcul du RSA ne sera finalis� qu'apr�s le pgm "application_non_recours_rsa"*/
		
*************************************************************************************;
/* Plan

Partie I : calcul de la base ressources des foyers RSA � partir des revenus des diff�rentes unit�s
	1. 	revenus individuels : revenus d'activit� (y c trimestrialisation, cumul int�gral et neutralisation des ressources) 
		et prestations individuelles;
	2. 	revenus de la famille CAF;
	3. 	revenus non individualisables des foyers fiscaux => on les attribue au d�clarant 
		(et donc au foyer rsa du d�clarant);
	4. 	revenus non individualisables du m�nage => on les attribue � la pr du m�nage ; 
	5. 	int�gration des infos ressources au niveau du foyer rsa => table res_rsa et calcul 
		des bases ressources trimestrielles;

Partie II : Travail sur les foyers rsa
	1. 	r�cup�ration des infos familiales.
	2. 	construction de la table foyers rsa �ligibles (�ge)
	3. 	cr�ation de la table des foyers avec toutes les infos pour le calcul du rsa

Partie III : calcul du rsa
	1. 	calcul du rsa et du forfait logement th�orique avant exclusion des pac ayant des 
		ressources
	2. 	Rep�rage des pac ayant des ressources, donc pouvant sortir du foyer rsa 
	3. 	calcul d'un rsa sans la pac en question pour les foyers concern�s
	4. 	recalcul du rsa pour les foyers concern�s par une exclusion
	5. 	cr�ation de la table de sortie modele.basersa */

*************************************************************************************;


*******************************************************************************************
*Partie I : calcul de la base ressources des foyers RSA � partir des ressources des 
diff�rentes unit�s
*******************************************************************************************;

/*0. Mise en oeuvre dans Ines et �cart � la l�gislation
Dans la r�alit� les ressources d�un trimestre de r�f�rence (d�clar�es lors de la DTR) permettent de calculer le RSA per�u au trimestre 
suivant (de droit). Pour compenser ce d�calage, le RSA poss�de deux m�canismes destin�s � ne pas p�naliser les personnes 
sujettes � des changements de situation : le cumul int�gral lors de la reprise d�activit� et la neutralisation lors d'arret d'activit�
Or dans Ines les droits au RSA sont calcul�s sur les ressources du trimestre en cours, donc trimestre de r�f�rence=de droit
Donc pas besoin de coder la neutralisation, et pour le cumul int�gral on s'arrange pour retomber sur les bonnes ressources : dans le cas 
d'une reprise d�activit� dans l�ann�e, on code le cumul int�gral proprement dit mais aussi le d�calage trimestre de r�f�rence/droit */

/*1. LES RESSOURCES INDIVIDUELLES :
	- les revenus d'activit� et de remplacement, trimestrialis�s : 
	les salaires sont ensuite modifi�s dans le cas d'un reprise d'activit� pour permettre de conserver le b�n�fice du RSA socle 
	pendant les 3, 4 ou 5 mois qui suivent une reprise d'activit� comme c'est le cas dans la r�alit� du fait du d�calage trimestre de 
	r�f�rence/droit (3 mois) et du cumul int�gral (0,1 ou 2 mois suivant le mois de reprise d'activit�)
	- les prestations individuelles: dont l'aah, dont il faut distinguer le titulaire si c'est 1 pac*/

proc sort data=base.baserev
	(keep= ident noi zsali&anr2._t1-zsali&anr2._t4 zchoi&anr2._t1-zchoi&anr2._t4 zrsti&anr2._t1-zrsti&anr2._t4 
				zpii&anr2._t1-zpii&anr2._t4 zindi&anr2._t1-zindi&anr2._t4
		nbmois_salt1-nbmois_salt4 zalri&anr2. zrtoi&anr2.) out=baserev; by ident noi; run;
proc sort data=modele.baseind
	(keep=ident noi cal0 aah caah asi aspa statut_rsa ident_rsa) out=baseind; by ident noi; run;

data RessTrim;
	merge 	baserev (rename= (zsali&anr2._t1=zsaliT1 zsali&anr2._t2=zsaliT2 zsali&anr2._t3=zsaliT3 zsali&anr2._t4=zsaliT4
							  zchoi&anr2._t1=zchoiT1 zchoi&anr2._t2=zchoiT2 zchoi&anr2._t3=zchoiT3 zchoi&anr2._t4=zchoiT4
							  zrsti&anr2._t1=zrstiT1 zrsti&anr2._t2=zrstiT2 zrsti&anr2._t3=zrstiT3 zrsti&anr2._t4=zrstiT4
							  zpii&anr2._t1=zpiiT1 zpii&anr2._t2=zpiiT2 zpii&anr2._t3=zpiiT3 zpii&anr2._t4=zpiiT4
							  zindi&anr2._t1=zindiT1 zindi&anr2._t2=zindiT2 zindi&anr2._t3=zindiT3 zindi&anr2._t4=zindiT4))
	       	baseind (in=a);
	by ident noi; 
	if a & ident_rsa ne '';

	/* rep�rage des ressources d'aah et de caah des futures pac et des civ des foyers rsa 
	(les pac aah seront exclues en II.2)*/
	%Init_Valeur(aahc_pac aahc_civ);
	if statut_rsa='pac' & aah then aahc_pac = aah+caah;
	if statut_rsa='' & aah then aahc_civ = aah+caah;


	/* CUMUL INTEGRAL: Pour conserver un d�calage de 3 mois entre perception d'une nouvelle ressource et son impact sur montant de RSA.
	- Si reprise d'activit� le 1er mois du trimestre de r�f�rence, alors pas de cumul int�gral 
	(car le m�canisme de d�claration trimestrielle permet d�j� un d�calage de 3 mois entre nouvelle ressource et prise en compte pour RSA).
	- Si reprise d'activit� 2�me mois du T r�f, on annule les revenus pour le 1er mois du T de droits (en gros rev_T_droits=2/3*rev_T_droits).
	- Si reprise d'activit� 3�me mois du T r�f, on annule 2 mois de revenus pour le T de droits.

	/*rep�rage de la 1�re reprise d'emploi au cours de l'ann�e et, selon, le moment o� elle intervient, annulation ou diminution 
	des revenus d'activit� du ou des trimestres correspondants (pour prendre en compte la DTR ET le cumul int�gral)

	Nous n'avons pas d�calage T r�f et T droit, donc on doit seulement s'occuper de la partie qui neutralise les revenus sur le T droit.

	Rep�rage de la 1�re reprise d'emploi au cours de l'ann�e et, selon, 
	le moment o� elle intervient, annulation ou non des revenus d'activit� du trimestre de droits. */

	/* TO DO: Introduction de la limite de 4 mois de cumul int�gral par ann�e glissante. */
	
	/* Pour les ann�es avant la disparition du RSA activit�, il faut distinguer les salaires rentrants dans la base ressource du RSA socle et du RSA activit�
	car ces derniers ne peuvent pas �tre r�duits du fait du cumul int�gral ou de la neutralisation. On cr�e la variable zsali_soc pour le RSA socle (RSA seul depuis 2016) */
	zsali_socT1=zsaliT1 ; zsali_socT2=zsaliT2 ; zsali_socT3=zsaliT3 ; zsali_socT4=zsaliT4 ;
	
	/* A partir de 2017 le cumul int�gral est supprim� */
	if &anleg.<=2016 then do; 
	/* Reprise d'activit� en f�vrier, on neutralise 1 mois de salaire au T suivant. */
	if substr(cal0,11,2) in ('14','16','17','18','19') then do;
		if nbmois_salT2 = 1 then zsali_socT2=0; 
		else if nbmois_salT2 = 2 then zsali_socT2=1/2*zsaliT2;
		else if nbmois_salT2 = 3 then zsali_socT2=2/3*zsaliT2; 
		end;
		/*mars : 2 mois � enlever T2 */
	else if substr(cal0,10,2) in ('14','16','17','18','19') then do;
		if nbmois_salT2 = 3 then zsali_socT2=1/3*zsaliT2;
		else if 0<=nbmois_salT2<3 then zsali_socT2=0; 
		end;
		/*mai : comme f�vrier */
	else if substr(cal0,8,2) in ('14','16','17','18','19') then do;
		if nbmois_salT3 = 1 then zsali_socT3=0; 
		else if nbmois_salT3 = 2 then zsali_socT3=1/2*zsaliT3;
		else if nbmois_salT3 = 3 then zsali_socT3=2/3*zsaliT3; 
		end;
		/*juin : comme mars */
	else if substr(cal0,7,2) in ('14','16','17','18','19') then do;
		if nbmois_salT3 = 3 then zsali_socT3=1/3*zsaliT3;
		else if 0<=nbmois_salT3<3 then zsali_socT3=0; 
		end;
		/*aout : comme f�vrier */
	else if substr(cal0,5,2) in ('14','16','17','18','19') then do;
		if nbmois_salT4 = 1 then zsali_socT4=0; 
		else if nbmois_salT4 = 2 then zsali_socT4=1/2*zsaliT4;
		else if nbmois_salT4 = 3 then zsali_socT4=2/3*zsaliT4; 
		end;
		/*septembre : comme mars */
	else if substr(cal0,4,2) in ('14','16','17','18','19') then do;
		if nbmois_salT4 = 3 then zsali_socT4=1/3*zsaliT4;
		else if 0<=nbmois_salT4<3 then zsali_socT4=0; 
		end;
		/* Pour le T4 on ne peut pas l'appliquer car on n'a pas acc�s aux informations du T1 de n+1. */
	end;
	/* NEUTRALISATION: 

	Rep�rage de la perte de revenus au cours de l'ann�e et neutralisation des revenus d�s celle-ci.
	Pour coller � la r�alit� malgr� notre non d�calage entre T r�f et T droit, on neutralise en partie les revenus du trimestre pr�c�dent,
	puis totalement les revenus du trimestre en cours (celui o� la perte de revenus appara�t). Ceci permet de neutraliser entre 4 et 6 mois. 

	On rep�re le changement de situation, puis on applique au trimestre pr�c�dent le salaire per�u au trimestre en cours (on r�duit la base ressource du RSA), 
	puis on fixe le salaire � 0 pour le trimestre en cours. */
	
	/*On s�pare les cas de pertes de revenus salari�s et de remplacement (ch�mage), en commen�ant par les salari�s. */

	/* Pour le premier trimestre, on ne peut pas le coder enti�rement car on n�a pas l'info de l'ann�e pr�c�dente. 
	Pour janvier on ne peut pas rep�rer les changements de situation. */
	/* Premier trimestre, perte de revenus en f�vrier */
	if &anleg.<=2016 then do;
	if substr(cal0,11,2) in ('41','61','71','81','91') then do 
		zsali_socT1=0;
		end;
	/* Premier trimestre, perte de revenus en mars */
	else if substr(cal0,10,2) in ('41','61','71','81','91') then do 
		zsali_socT1=0;
		end;
	/* Deuxi�me trimestre, perte de revenus en avril */
	else if substr(cal0,9,2) in ('41','61','71','81','91') then do 
		zsali_socT1= zsaliT2;
		zsali_socT2=0;
		end;
	/* Perte de revenus en mai */
	else if substr(cal0,8,2) in ('41','61','71','81','91') then do 
		zsali_socT1= zsaliT2;
		zsali_socT2=0;
		end;
	/* Perte de revenus en juin */
	else if substr(cal0,7,2) in ('41','61','71','81','91') then do 
		zsali_socT1= zsaliT2;
		zsali_socT2=0;
		end;
	/* Troisi�me trimestre, perte de revenus en juillet */
	else if substr(cal0,6,2) in ('41','61','71','81','91') then do 
		zsali_socT2= zsaliT3;
		zsali_socT3=0;
		end;
	/* Perte de revenus en aout */
	else if substr(cal0,5,2) in ('41','61','71','81','91') then do 
		zsali_socT2= zsaliT3;
		zsali_socT3=0;
		end;
	/* Perte de revenus en septembre */
	else if substr(cal0,4,2) in ('41','61','71','81','91') then do 
		zsali_socT2= zsaliT3;
		zsali_socT3=0;
		end;
	/* Quatri�me trimestre, perte de revenus en octobre */
	else if substr(cal0,3,2) in ('41','61','71','81','91') then do 
		zsali_socT3= zsaliT4;
		zsali_socT4=0;
		end;
	/* Perte de revenus en novembre */
	else if substr(cal0,2,2) in ('41','61','71','81','91') then do 
		zsali_socT3= zsaliT4;
		zsali_socT4=0;
		end;
	/* Perte de revenus en d�cembre */
	else if substr(cal0,1,2) in ('41','61','71','81','91') then do 
		zsali_socT3= zsaliT4;
		zsali_socT4=0;
		end;

	/*Perte d'allocations ch�mage (seul revenu de remplacement affect�).*/
	/* Premier trimestre, perte de revenus en f�vrier */
	if substr(cal0,11,2) in ('74','84','94') then do 
		zchoiT1=0;
		end;
	/* Premier trimestre, perte de revenus en mars */
	else if substr(cal0,10,2) in ('74','84','94')then do 
		zchoiT1=0;
		end;
	/* Deuxi�me trimestre, perte de revenus en avril */
	else if substr(cal0,9,2) in ('74','84','94') then do 
		zchoiT1= zchoiT2;
		zchoiT2=0;
		end;
	/* Perte de revenus en mai */
	else if substr(cal0,8,2) in ('74','84','94') then do 
		zchoiT1= zchoiT2;
		zchoiT2=0;
		end;
	/* Perte de revenus en juin */
	else if substr(cal0,7,2) in ('74','84','94') then do 
		zchoiT1= zchoiT2;
		zchoiT2=0;
		end;
	/* Troisi�me trimestre, perte de revenus en juillet */
	else if substr(cal0,6,2) in ('74','84','94') then do 
		zchoiT2= zchoiT3;
		zchoiT3=0;
		end;
	/* Perte de revenus en aout */
	else if substr(cal0,5,2) in ('74','84','94') then do 
		zchoiT2= zchoiT3;
		zchoiT3=0;
		end;
	/* Perte de revenus en septembre */
	else if substr(cal0,4,2) in ('74','84','94') then do 
		zchoiT2=zchoiT3;
		zchoiT3=0;
		end;
	/* Quatri�me trimestre, perte de revenus en octobre */
	else if substr(cal0,3,2) in ('74','84','94') then do 
		zchoiT3= zchoiT4;
		zchoiT4=0;
		end;
	/* Perte de revenus en novembre */
	else if substr(cal0,2,2) in ('74','84','94') then do 
		zchoiT3=zchoiT4;
		zchoiT4=0;
		end;
	/* Perte de revenus en d�cembre */
	else if substr(cal0,1,2) in ('74','84','94') then do 
		zchoiT3=zchoiT4;
		zchoiT4=0;
		end;
	end;
	/* Pour le moment on ne consid�re pas les ind�pendants. */
	run;
	
/* Regroupement des revenus individuels par foyer rsa => table res_ind */
proc sort data=RessTrim; by ident_rsa; run;
proc means data=RessTrim noprint nway;
	class ident_rsa;
	var zsaliT1-zsaliT4 zsali_socT1-zsali_socT4 zchoiT1-zchoiT4 zrstiT1-zrstiT4 zpiiT1-zpiiT4 zindiT1-zindiT4
		aahc_pac aahc_civ caah asi aspa zalri&anr2. zrtoi&anr2.;
	output out=res_ind(drop=_type_ _freq_) sum=;
	run;


/*2. LES RESSOURCES DE LA FAMILLE CAF 
	- les prestations familiales + r�cup�ration de variables famille utiles (p_iso age_enf)*/

%Macro RessourcesFamille;
	data famille(drop = mpaje mois00);
		set modele.basefam(keep=ident_fam afxx0 asf_horsReval2014 paje_base droit_ab comxx majo_comxx clca pers_iso age_enf mois00);
		/* d�duction des ressources familiales d'une partie de l'AB de la paje la 1�re ann�e : 3 mois pour le RSA major� */
		if paje_base>0 & mois00 ne '' AND pers_iso = 1 then do; 

			%if &anleg. <= 2013 %then %do ; /* Jusqu'en 2013, l'allocation de base de la PAJE est exprim�e en fonction de la BMAF */
				if droit_AB='plein' then mpaje=&bmaf.*&paje_t.;
				%end ;
			%if &anleg. = 2014 %then %do ; /* A partir du 1er avril 2014, l'AB de la PAJE est gel�e et surtout d�connect�e de la BMAF */ 
				mpaje=((3*&bmaf_n.*&paje_t.)+(9*&paje_m.))/12; 
				/* pour les 3 premiers mois de l'ann�e, l'AB est encore exprim�e en fonction de la BMAF (valeur de celle-ci au 1er janvier).
				On fait une moyenne sur l'ann�e, m�me si en pratique le montant mensuel n'est pas modifi� � partir d'avril (malgr� la d�connection de la Bmaf */
				mpaje_partiel=&paje_m_partiel.; /* Pas de moyenne sur l'ann�e car le montant partiel ne concerne que les enfants n�s � partir du 1er avril */
			%end ;
			%if &anleg. >= 2015 %then %do ; 
				if droit_AB='plein' then mpaje=&paje_m.; 
				if droit_AB='partiel' then mpaje=&paje_m_partiel.;
				%end ;

			if mois00='11' then  paje_base=paje_base - mpaje; 
			else if mois00='10' then  paje_base=paje_base - 2*mpaje; 
			else paje_base=paje_base - 3*mpaje; 
			end;


		%if &anleg.<2004 %then %do;
			paje_base=0; /*on supprimait toute l'aide avant 2004*/
			%end;
		run;
	%Mend RessourcesFamille;
%RessourcesFamille;

/*r�cup�ration du num�ro ident_rsa de baseind pour le mettre dans la table famille (cr�ation de la table lien ident_fam<=>ident_rsa)*/
proc sort data=famille nodupkey; by ident_fam;
proc sort data=modele.baseind(keep=ident_fam ident_rsa) out=lien nodupkey; by ident_fam; run;
data famille;
	merge famille (in=a) lien;
	comxx=comxx-majo_comxx;/* on enl�ve la majoration du compl�ment familial de la base ressources (si pas de majorations alors majo_comxx=0) */
	by ident_fam;
	if a;
	run;
/* somme des ressources familiales par foyer rsa => table res_fam */
proc sort data=famille; by ident_rsa; run;
proc means data=famille noprint nway;
	class ident_rsa;
	var afxx0 asf_horsReval2014 paje_base comxx clca;
	output out=res_fam(drop=_type_ _freq_) sum=;
	run;


/*3. LES RESSOURCES DU FOYER FISCAL
	- toutes les ressources non individualisables du foyer (ressources de l'ann�e simul�e)
	HYPOTHESE : on les attribue au d�clarant du foyer fiscal, donc � son foyer rsa*/

data foyer(keep=ident noi declar zvalf zetrf zvamf zfonf zracf separation);
	set base.foyer&anr2.;
	/* omission dans les agr�gats des foyers des revenus imput�s par ailleurs � leurs m�nages
	et qui seront comptabilis�s � l'�tape 4 */
	zvamf=sum(0,zvamf,-_2ch,-_2fu);
	zvalf=zvalf-max(0,_2dh);
	/* rep�rage des divorces ou ruptures de pacs dans l'ann�e pour simuler du RSA major� */
	separation=(xyz='Y');
	run;
/* r�cup�ration du num�ro ident_rsa de baseind pour le mettre dans la table foyer*/
proc sort data=foyer; by ident noi;
proc sort data=modele.baseind; by ident noi; run;
data foyer;
	merge 	foyer (in=a) 	
			modele.baseind (keep=ident noi ident_rsa);
	by ident noi;
	if a;
	run;
/* somme des ressources du foyer fiscal par foyer rsa => table res_foy*/
proc sort data=foyer; by ident_rsa; run;
proc means data=foyer noprint nway;
	class ident_rsa;
	var zracf zfonf zetrf zvamf zvalf separation;
	output out=res_foy(drop=_type_ _freq_) sum=;
	run;


/*4. LES RESSOURCES DU MENAGE 
	- les produits financiers imput�s au m�nage l'ann�e simul�e :
	En th�orie, il faut prendre en compte dans la BR du rsa 
	les revenus du capital (lorsqu'ils sont d�clar�s) et � d�faut 3% (par an, soit 0,75% par trimestre) du capital d�tenu
	(y compris l'�pargne disponible, type livret A et l'�pargne non plac�e, type compte courant).
	cela n'�tant pas possible, on utilise les revenus des produits financiers imput�s aux m�nages par RPM.
	HYPOTHESE : on les attribue � la personne de r�f�rence du m�nage, donc � son foyer rsa*/

proc sort data=base.menage&anr2.; by ident; run;
proc sort data=modele.baseind; by ident; run;
data prodfin;
	merge 	modele.baseind (in=a) 
			base.menage&anr2. (keep=ident produitfin_i);
	by ident;
	if a;
	if lprm='1' then prodfin=produitfin_i;
	else prodfin=0;
	run;
/* somme des ressources du m�nage par foyer rsa => table res_men*/
proc means data=prodfin noprint nway;
	class ident_rsa;
	var prodfin;
	output out=res_men(drop=_type_ _freq_) sum=;
	run;


/*5. CONSTRUCTION DE LA BR DU RSA A PARTIR DES 4 ORIGINES DES RESSOURCES
	- cr�ation de la table res_rsa qui regroupe les ressources au niveau du foyer rsa
	- calcul des bases ressources trimestrielles*/

proc sort data=res_ind; by ident_rsa;
proc sort data=res_fam; by ident_rsa;
proc sort data=res_foy; by ident_rsa; 
proc sort data=res_men; by ident_rsa; run;
data res_rsa;
	merge 	res_ind (in=a) 
			res_fam 
			res_foy 
			res_men;
	by ident_rsa;
	if a ;
	array num _numeric_; do over num; if num=. then num=0; end;

	/* calcul des revenus d'activit� pris en compte chaque trimestre dans la base ressources du rsa */
	rce1_rsa1=sum(0,zsaliT1,zindiT1);
	rce1_rsa2=sum(0,zsaliT2,zindiT2);
	rce1_rsa3=sum(0,zsaliT3,zindiT3);
	rce1_rsa4=sum(0,zsaliT4,zindiT4);

	rce1_soc_rsa1=sum(0,zsali_socT1,zindiT1);
	rce1_soc_rsa2=sum(0,zsali_socT2,zindiT2);
	rce1_soc_rsa3=sum(0,zsali_socT3,zindiT3);
	rce1_soc_rsa4=sum(0,zsali_socT4,zindiT4);

	/* TO DO : logiquement il faudrait aussi appliquer le cumul int�gral sur le revenu d'activit� des ind�pendants.. */


	/* calcul de toutes les autres ressources prises en compte chaque trimestre : les 
	revenus du ch�mage et de la retraite sont consid�r�s par trimestre et les autres 
	ressources sont liss�es sur l'ann�e en divisant par 4.
	Pour l'aah et le caah, on ne retient pas celui des pac, qui seront exclues du foyer 
	dans la partie III*/
	rce2_rsa1=max(0,sum(0,zchoiT1,zrstiT1,zpiiT1)+
		1/4*sum(0,zrtoi&anr2.,zalri&anr2.,zracf,zfonf,zvamf,zetrf,zvalf,prodfin,
				clca,afxx0,paje_base,comxx,asf_horsReval2014,aahc_civ,asi,aspa));
	rce2_rsa2=max(0,sum(0,zchoiT2,zrstiT2,zpiiT2)+
		1/4*sum(0,zrtoi&anr2.,zalri&anr2.,zracf,zfonf,zvamf,zetrf,zvalf,prodfin,
				clca,afxx0,paje_base,comxx,asf_horsReval2014,aahc_civ,asi,aspa));
	rce2_rsa3=max(0,sum(0,zchoiT3,zrstiT3,zpiiT3)+
		1/4*sum(0,zrtoi&anr2.,zalri&anr2.,zracf,zfonf,zvamf,zetrf,zvalf,prodfin,
				clca,afxx0,paje_base,comxx,asf_horsReval2014,aahc_civ,asi,aspa));
	rce2_rsa4=max(0,sum(0,zchoiT4,zrstiT4,zpiiT4)+
		1/4*sum(0,zrtoi&anr2.,zalri&anr2.,zracf,zfonf,zvamf,zetrf,zvalf,prodfin,
				clca,afxx0,paje_base,comxx,asf_horsReval2014,aahc_civ,asi,aspa));
	run; 


/**************************************
Partie II : CREATION DE LA TABLE FOYERS_RSA
**************************************/

/* 1. construction d'une table de foyers rsa � partir de la table famille */
proc sort data=famille; by ident_rsa ident_fam;run; 
data foyer_rsa (keep=ident_rsa ident_fam age_enf pers_iso); 
	set famille;  
	by ident_rsa ident_fam;
	if first.ident_rsa; 
	run; 
/*PB : dans les cas o� 2 familles composent un foyer rsa, on ne prend les infos que d'une famille */

/*2. construction d'une table de foyers rsa � partir des individus de baseind en deux temps
	- d�compte des adultes et des personnes � charge par foyer (hors pac aah)
	- construction de la table foyers en ne gardant que les foyers �ligibles de par leur �ge 
	ou la pr�sence d'enfant*/
proc sort data=modele.baseind; by ident_rsa; run;
data nb_pac; 
	set modele.baseind (keep=ident wpela&anr2. noi ident_rsa ident_fam noicon noienf01 naia quelfic 
			statut_rsa aah acteu6 in=a where=(ident_rsa ne ''));
	by ident_rsa;
	/* on enl�ve les pac aah de la table individuelle servant � fabriquer les foyers rsa*/
	if statut_rsa='pac' & aah then delete;
	retain pac nbciv agemax_foyer etud_ou_pac par_iso nbenf; 
	if first.ident_rsa then do; pac=0; nbciv=0; agemax_foyer=0; etud_ou_pac=0; par_iso=0; nbenf=0; end;
	if statut_rsa='pac' then pac=pac+1;
	else nbciv=nbciv+1;
	/* astuces pour d�terminer l'�ligibilit� de chaque foyer � partir de l'�ge ou la pr�sence d'enfant � charge :
	- on cr�e une variable agemax_foyer donnant l'�ge de la personne la plus �g�e du foyer
	- on compte dans le foyer le nombre de pacs et d'�tudiants (sans double compte)
	- on rep�re les parents isol�s (ils sont �ligibles au RSA m�me s'ils sont �tudiants et jeunes) */
	agemax_foyer=max(agemax_foyer,&anref.-input(naia,4.));
	etud_ou_pac=etud_ou_pac+(acteu6='5' or statut_rsa='pac');
	par_iso=par_iso+(noicon='' and noienf01 ne '');
	nbenf=nbenf+(noienf01 ne '');
	run;

proc sort data=nb_pac; by ident_rsa; run;
data pac; 
	set nb_pac(where = (agemax_foyer>=&age_rsa_l. or nbenf ne 0)); /* on ne garde pas les foyers trop jeunes, sauf s'ils sont jeunes parents */
	by ident_rsa;
	if (etud_ou_pac = nbciv+pac) and (par_iso ne 0) then delete;  /* on enl�ve les foyers compos�s uniquement d'�tudiants, sauf s'ils sont parents isol�s*/
	/*�cart � la l�gislation : on n'inclut pas les jeunes ayant travaill� deux ann�es sur les trois derni�res ann�es
	ni ceux en stages r�mun�r�s, alors qu'ils sont normalement �ligibles au RSA m�me en ne respectant pas la condition d'�ge*/
	if last.ident_rsa; 
	run; 

/*3. fusion des 3 tables de niveau foyer rsa constitu�es jusqu'� maintenant */
data rsa1;
	merge 	res_rsa 
			foyer_rsa 
			pac(in=a keep=ident_rsa pac nbciv wpela&anr2.);
	by ident_rsa; 
	if a; 
	run;


/***************************
*Partie III : calcul du rsa
***************************/

/*1. calcul du rsa en incluant toutes les pac du foyer (certaines seront exclues plus tard)
	- a. calcul du montant forfaitaire et du forfait logement th�orique pour toutes les configuations
	- b. calcul du rsa et du rsa socle */

%macro Calcul_RSA(nbciv,pac,m_rsa,m_rsa_socle);
	nb_foyer=&nbciv.+&pac.; 
	if nb_foyer=1 then do; 
		rsa=&rsa.; 
		FL_theorique=&rsa.*&forf_log1.; end;
	if nb_foyer=2 then do; 
		rsa=&rsa.*(1+&rsa2.); 
		FL_theorique=&rsa.*(1+&rsa2.)*&forf_log2.; end;
	if nb_foyer>2 then do; 
		rsa=&rsa.*(1+&rsa2.+&rsa3.*(nb_foyer-2)+ &rsa4.*(&pac-2)*(&pac>2)); 
		FL_theorique=&rsa.*(1+&rsa2.+&rsa3.)*&forf_log3.; end;
	rsa_noel=&rmi_noel.*rsa/&rsa.;
	/* �ligibilit� et application du rsa major� et ses l�gislations ant�rieures (api) */
	%nb_enf(enf03,0,3,age_enf);
	%nb_enf(e_c,0,&age_pf.,age_enf);
	if (enf03>0 & pers_iso=1) ! (e_c>0 & separation>0) then do;
		/* RSA major� */
		rsa=(&mrsa1.+&pac*&mrsa2.)*&rsa.;
		/* API */
		%if &anleg.<2007 %then %do;
			FL_theorique = &bmaf.*	(&forf_log_api1.*(e_c=0) 
								+ &forf_log_api2.*(e_c=1) 
								+ &forf_log_api2.*(e_c>1));
			%end;
		%if &anleg.<2009 %then %do;
			rsa=(&mapi1.+e_c*&mapi2.)*&bmaf.;
			%end;
		end;
	/*b. calul du rsa et du rsa socle sans tenir compte du forfait logement
	mise � 0 des montants de prestation trimestriels et vectorisation*/
	&m_rsa.1=0; &m_rsa.2=0; &m_rsa.3=0; &m_rsa.4=0;
	&m_rsa_socle.1=0; &m_rsa_socle.2=0; &m_rsa_socle.3=0; &m_rsa_socle.4=0;
	array rce1_rsa rce1_rsa1-rce1_rsa4;
	array rce1_soc_rsa rce1_soc_rsa1-rce1_soc_rsa4;
	array rce2_rsa rce2_rsa1-rce2_rsa4;
	array &m_rsa &m_rsa.1-&m_rsa.4;
	array &m_rsa_socle &m_rsa_socle.1-&m_rsa_socle.4;
	/* calcul par trimestre */
	do over &m_rsa;

		&m_rsa_socle = max(0, 3*(rsa) - rce1_soc_rsa - rce2_rsa) ; /* avec salaires abattus dans la BR */

		/* pour le droit au RSA activit�, on consid�re le revenu r�el et non celui neutralis� pour le RSA socle */
		/* le calcul du RSA total sera diff�rent selon que les ressources se situent en de�a ou au del� du MF du RSA */

		if rce1_rsa + rce2_rsa < 3*(rsa)  /* ressources (avant neutralisation) inf�rieures au MF */ 
			then &m_rsa = &trsa.*rce1_rsa + &m_rsa_socle  ; 
		else if rce1_rsa + rce2_rsa >= 3*(rsa) /* ressources sup�rieures au MF */ 
			then &m_rsa = max(0, 3*(rsa) - (1-&trsa.)*rce1_rsa - rce2_rsa) + &m_rsa_socle ; 
			/* � noter que dans ce cas, si le m�nage touche du RSA socle, les ressources hors revenus d'activit� sont compt�es 2 fois 
				(comme pour la PA) */

		/* TO DO : il faudrait inclure le forfait logement dans la base ressources, ce qui n'est pas possible ici puisque
			le FL est calcul� apr�s le bloc AL. Cel� supposerait de faire comme avec la PA, cad calculer ici le RSA socle
			et dans un 2�me temps (apr�s les AL), le RSA activit� et total */

		%if &anleg.<2009 or &anleg.>= 2016  %then %do; /*pas de RSA activit�*/
			&m_rsa=&m_rsa_socle;
			%end;
		end;

	%if &anleg.=2009 %then %do;
		m_rsa1=m_rsa_socle1;
		m_rsa2=m_rsa_socle2+(m_rsa2-m_rsa_socle2)/3; /* Le RSA est distribu� � partir du mois de juin */
		%end;
	%mend Calcul_RSA;

data rsa1; 
	set rsa1;
	/*a. calcul du montant forfaitaire du rsa, du forfait logement et de la prime de noel */
	%Calcul_RSA(nbciv,pac,m_rsa,m_rsa_socle);
	/*cr�ation d'une variable rsa annuel qui sera utilis�e seulement � l'�tape 3 pour d�terminer l'�ventuelle exclusion de pac*/
	rsa_an = sum(0,of m_rsa1-m_rsa4);
	run;


/*2. Rep�rage des pac qui peuvent sortir du foyer rsa : pac de 20 � 25 ans avec des ressources personnelles*/
proc sort data=RessTrim; by ident noi;
proc sort data=nb_pac; by ident noi;
data exclu; 
	merge RessTrim nb_pac;
	by ident noi;
	if ident_rsa ne '' & statut_rsa='pac' & (&anref.-input(naia,4.)>=&age_pl.);
	/* d�s une pac ayant des ressources personnelles au moins 1 trimestre, elle est excluable*/
	%macro Exclusion_Potentielle;
		%do i=1 %to 4; 
			if  sum(0,zsaliT&i.,zindiT&i.,zchoiT&i.,zrstiT&i.,zpiiT&i.,
					1/4*sum(0,zrtoi&anr2.,zalri&anr2.,asi))>0 
				then pot_excluT&i.=1;
			else pot_excluT&i.=0; %end; 
		%mend Exclusion_Potentielle;
	%Exclusion_Potentielle;
	run; 

/*3. Calcul du rsa pour les foyers concern�s par une exclusion potentielle
- HYPOTHESE : une seule exclusion par foyer : dans le cas d'exclusions multiples, on garde la plus avantageuse pour le foyer*/
proc sort data=exclu; by ident_rsa noi; run;
data exclusion; 
	merge	exclu (in=a)
			rsa1(keep= ident_rsa m_rsa: rce1: rce2: pac nbciv age_enf pers_iso rsa_an separation);
	by ident_rsa;
	if a;
	if pot_excluT1 = 1 ! pot_excluT2 = 1 ! pot_excluT3 = 1 ! pot_excluT4 = 1 then do;
		/* calcul des ressources du foyer en otant les ressources personnelles de la pac*/
		rce1_rsa1 = rce1_rsa1-sum(0,zsaliT1,zindiT1);	
		rce1_rsa2 = rce1_rsa2-sum(0,zsaliT2,zindiT2);
		rce1_rsa3 = rce1_rsa3-sum(0,zsaliT3,zindiT3);
		rce1_rsa4 = rce1_rsa4-sum(0,zsaliT4,zindiT4);
		rce1_soc_rsa1 = rce1_soc_rsa1-sum(0,zsali_socT1,zindiT1);	
		rce1_soc_rsa2 = rce1_soc_rsa2-sum(0,zsali_socT2,zindiT2);
		rce1_soc_rsa3 = rce1_soc_rsa3-sum(0,zsali_socT3,zindiT3);
		rce1_soc_rsa4 = rce1_soc_rsa4-sum(0,zsali_socT4,zindiT4);
		rce2_rsa1 = rce2_rsa1-(asi+zalri&anr2.+zrtoi&anr2.)/4;
		rce2_rsa2 = rce2_rsa2-(asi+zalri&anr2.+zrtoi&anr2.)/4;
		rce2_rsa3 = rce2_rsa3-(asi+zalri&anr2.+zrtoi&anr2.)/4;
		rce2_rsa4 = rce2_rsa4-(asi+zalri&anr2.+zrtoi&anr2.)/4;
		/*calcul du rsa du foyer si la pac �tait exclue du foyer*/
		%Calcul_RSA(nbciv,pac-1,m_rsa_exclu,m_rsasocl_exclu);
		rsa_exclu_an = sum(0,of m_rsa_exclu1-m_rsa_exclu4);
		/*comparaison du rsa du foyer avec et sans la pac : si le rsa sans la pac est plus �lev�, on on fixe exclu � 1*/
		exclu=(rsa_exclu_an > rsa_an); 
		end;
	if exclu;
	run;
proc sql;
	create table optim as
	select distinct *
	from exclusion
	group by ident_rsa
	having rsa_exclu_an=max(rsa_exclu_an);
	quit;

/*4. recalcul du rsa pour les foyers concern�s par une exclusion*/
proc sort data=rsa1;by ident_rsa;run;
data rsa2; 
	merge 	rsa1(in=a) 
			optim; 
	by ident_rsa; 
	if a;
	/*on affecte aux foyers qui perdent une pac les montants de rsa trimestriels calcul�s apr�s son exclusion en on enl�ve une pac */
	if exclu then do; 
		m_rsa_socle1=m_rsasocl_exclu1; 
		m_rsa_socle2=m_rsasocl_exclu2;
		m_rsa_socle3=m_rsasocl_exclu3; 
		m_rsa_socle4=m_rsasocl_exclu4;
		m_rsa1=m_rsa_exclu1; 
		m_rsa2=m_rsa_exclu2;
		m_rsa3=m_rsa_exclu3; 
		m_rsa4=m_rsa_exclu4;
		pac=pac-1;
	end;
	/* Rep�rage des foyers potentiellement concern�s par le cumul int�gral */
	cum_int1=(rce1_rsa1 ne rce1_soc_rsa1) ;
	cum_int2=(rce1_rsa2 ne rce1_soc_rsa2) ;
	cum_int3=(rce1_rsa3 ne rce1_soc_rsa3) ;
	cum_int4=(rce1_rsa4 ne rce1_soc_rsa4) ;
	length cum_int $4 ; cum_int = compress(cum_int1 !! cum_int2 !! cum_int3 !! cum_int4);

	run;

/*5. cr�ation de la table de sortie modele.basersa*/
data modele.basersa;
	set rsa2(keep=ident_rsa m_rsa1-m_rsa4 m_rsa_socle1-m_rsa_socle4 FL_theorique rsa_noel enf03 pers_iso e_c separation wpela&anr2. rsa cum_int
		rename=(m_rsa1-m_rsa4 = m_rsa_th1-m_rsa_th4 m_rsa_socle1-m_rsa_socle4 = m_rsa_socle_th1-m_rsa_socle_th4 rsa=rsa_forf)); 
	format ident $8.;
	ident=substr(ident_rsa,1,8);
	label	m_rsa_th1='montant de RSA theorique au T1 avant calcul du FL'
			m_rsa_th2='montant de RSA theorique au T2 avant calcul du FL'
			m_rsa_th3='montant de RSA theorique au T3 avant calcul du FL'
			m_rsa_th4='montant de RSA theorique au T4 avant calcul du FL'
			m_rsa_socle_th1='montant de RSA socle theorique au T1 avant calcul du FL'
			m_rsa_socle_th2='montant de RSA socle theorique au T2 avant calcul du FL'
			m_rsa_socle_th3='montant de RSA socle theorique au T3 avant calcul du FL'
			m_rsa_socle_th4='montant de RSA socle theorique au T4 avant calcul du FL'
			rsa_forf='Montant forfaitaire du RSA'
			cum_int='foyer potentiellement concern� par le cumul int�gral de T1 � T4'
			FL_theorique='forfait logement theorique avant calcul des AL'
			rsa_noel='prime de Noel du RSA'
			enf03='enfants de moins de 3 ans dans le foyer'
			pers_iso='pas de conjoint'
			e_c='enfants � charge dans le foyer'
			separation='une separation conjugale au sens fiscal est intervenue cette annee';
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
