/************************************************/
/*			programme 1_initialisation			*/ 
/************************************************/

/****************************************************************************************/
/* Tables en entr�e :																	*/
/*	cd.irf&anr.e&anr.t1 cd.irf&anr.e&anr.t2 cd.irf&anr.e&anr.t3 cd.irf&anr.e&anr.t4		*/
/*	cd.irf&anr.e&anr1.t1 cd.irf&anr.e&anr1.t2 cd.irf&anr.e&anr1.t3						*/
/*	cd.mrf&anr.e&anr1.t1 cd.mrf&anr.e&anr1.t2 cd.mrf&anr.e&anr1.t3						*/
/*	cd.mrf&anr.e&anr.t1 cd.mrf&anr.e&anr.t2 cd.mrf&anr.e&anr.t3 cd.mrf&anr.e&anr.t4		*/
/*	cd.indiv20&anr._ela rpm.indivi&anr.													*/
/*	cd.men20&anr._ela cd.dep&anr._ela cd.Tu99											*/
/*	cd.indfip20&anr._ela rpm.indfip20&anr.												*/
/*  cd.indfip_anfip																		*/
/*																						*/	
/* Tables en sortie :																	*/
/*	travail.irf&anr.e&anr.																*/
/*	travail.mrf&anr.e&anr.																*/
/*	travail.indivi&anr.																	*/
/*	travail.menage&anr.																	*/
/*	travail.indfip&anr.																	*/
/*																						*/
/* Objectif : A partir des tables de bases d'origine (librairies CD ou RPM),			*/
/* on cr�e des tables de travail aux 2 niveaux individuel et m�nage.					*/
/* Ces tables correspondent au format de l'enqu�te emploi la plus r�cente connue		*/
/* Ainsi le code aval, adapt� aux modalit�s post-refonte, tourne 						*/
/* quel que soit le mill�sime ERFS, les modifications �tant r�alis�es ici. 				*/
/*																						*/
/* PLAN	
/*	0   R�tropolation																	*/
/*	1	Liste des variables de l'EE (IRF et MRF) qui servent dans le mod�le				*/
/*	2	Initialisation de travail.IRF et travail.MRF avec mise au format le plus r�cent	*/
/*			A. Macros de recodification													*/
/*			B. Construction des tables 													*/
/*	3	Initialisation des fichiers fiscaux INDIVI MENAGE et INDFIP						*/
/****************************************************************************************/

/****************************************************************************************/
/*	0	R�tropolations (utilisation des fichiers les plus r�centes de l'ERFS pour coh�rence entre nouvelles et anciennes ERFS   */
/****************************************************************************************/

/*Retropolation*/
%macro retropolation;
	%if &retropole.=oui and &casd.=non and &noyau_uniquement.=oui and &anref.=2012 %then %do;
		proc sql; /*pour ne pas perdre les variables suppl�mentaires*/
			create table rpm.menage&anr._retropole as
			select a.*, b.logt, b.loyer, b.loyerfict, b.nais2013
			from rpm.menage&anr._retropole as a
			left join rpm.menage&anr. as b
			on a.ident&anr=b.ident&anr;
			quit;		
		data rpm.menage&anr.;
		set rpm.menage&anr._retropole;
		run;
		data rpm.indivi&anr.;
		set rpm.indivi&anr._retropole;
		run;
		%end;
	%if &retropole.=oui and &casd.=non and &noyau_uniquement.=oui and &anref.>=2012 and &anref.<=2014 %then %do;
		data rpm.menage&anr.;
		set rpm.menage&anr.;
		drop livm jeunm pelm lepm celm assviem peam produitfin;
		run;
		proc sql;
			create table rpm.menage&anr. as
			select a.*, b.livm, b.jeunm, b.pelm, b.lepm, b.celm, b.assviem, b.peam, b.produitfin
			from rpm.menage&anr. as a
			left join rpm.menage&anr._pat14 as b
			on a.ident&anr=b.ident&anr;
			quit;
		%end;
	%Mend;
%retropolation;

/****************************************************************************************/
/*	1	Liste des variables de l'EE (IRF et MRF) qui servent dans le mod�le				*/
/****************************************************************************************/

/*	Id�e : tr�s vite, ne garder que les variables qui servent dans Ines
	Double avantage : 
	- gain de place et donc de temps d'ex�cution pour la suite
	- meilleure visibilit� de l'information utilis�e
	Si quelqu'un d�cide de mobiliser une information de l'EE qui ne l'�tait pas jusqu'alors, il faut donc ajouter la ou les variables � cette liste. 
	Sinon un bug sera g�n�r�, � comprendre comme une alerte : "attention cette variable n'�tait pas utilis�e jusqu'ici, il faut donc en tester 
	la qualit� dans la doc de l'EEC et regarder si elle existait avec les m�mes modalit�s par le pass�, avant la refonte de 2013 notamment"

	Exception : ne sont pas list�es ici les variables uniquement utilis�es dans leur dimension trimestrielle pour contruire des calendriers individuels. 
	Ces variables sont r�cup�r�es directement dans les tables de d�part le moment venu pour �tre toutes trait�es de la m�me fa�on, qu'elles
	soient issues de IRF (le T4 de tous les individus) ou des tables compl�mentaires (les autres trimestres disponibles des pr�sents eu T4).
	- > Pour connaitre la liste compl�te des variables EE servant dans le mod�le, il faut ajouter la liste �tablie au d�but de recup_info_trim. 
*/
%let KeepListIRF=	ident: noi noindiv
					cser nafant naia naim
					sp01 sp02 sp03 sp04 sp05 sp06 sp07 sp08 sp09 sp10 sp11
					ancinatm
					dremcm
					empnbh
					hhc
					salmee 
					lprm acteu6prm agprm 
					cstotprm nbpi
					officc ag5 ca echpub stc
					noimer noiper matri noicon
					coured sexe: acteu6 noienf: REVENT
					cstot noiprm choixech
					ag acteu titc tppred contra
					trefen
					pub3fp
					csa p adfdap nondic statutr ancchom ancchomm
					statut tpp duhab TXTPPRED nafn NAFG088UN NAFG017N
					module stat2
					rabs form forter fortyp nivet
					retrai 
					ddipl alct dchantm dremcm;

%let KeepListMRF=	ident: typmen7 tuu2010 sexeprm nbind dep nbenfc rga reg aai;


/*******************************************************************************************************/
/*	2	Initialisation de travail.IRF et travail.MRF avec conversion au format le plus r�cent 	*/
/*****************************************************************************************************/

/* 	REFONTE de L'ENQUETE EMPLOI EN 2013 (et autres refontes)
	Principe g�n�ral : on se met d'�querre avec la version la plus r�cente de l'enqu�te emploi : post-refonte 2013
	Le code aval correspond aux nouvelles modalit�s / variables (comme pour la table foyer : 
	le code de l'imp�t correspond aux d�finitions et contours les plus r�centes des cases fiscales)
	Si l'on travaille sur un mill�sime ERFS ant�rieur � l'ann�e de la refonte, on doit donc le transformer (si post�rieur, rien � faire). 
	On d�roge � ce principe g�n�ral dans les cas de disparition de variables qu'il faut reconstruire
	dans les mill�simes ult�rieurs : g�r� dans une macro de Recons_var_table en fonction de anref
	
	La prise en compte la refonte de l'Enqu�te emploi 2013 a lieu en trois temps : 
	- Recodification des variables de la table IRF : 
		�criture de la macro %Recodification2013_IRF appel�e dans %Initialisation_IRF (en fonction de anref)
		�criture de la macro %Recons_var_IRF appel�e dans %Initialisation_IRF
	- Recodification des variables de la table MRF : 
		�criture de la macro %Recodification2013_MRF appel�e dans %Initialisation_MRF (en fonction de anref)
	- Recodification des variables des tables compl�mentaires (trimestrielles) : a lieu de mani�re un peu diff�rente dans le programme Recup_Info_Trim
*/

	/*******************************/
	/* A. Macros de recodification */
	/*******************************/
%Macro RenommeVar_EEC(v1,v2);
	&v2.=&v1.;
	drop &v1.;
%Mend RenommeVar_EEC;


%macro Recodification2013_IRF;

	/* 1	Renommages */
	%RenommeVar_EEC(lpr,lprm);
	%RenommeVar_EEC(acteu6pr,acteu6prm);
	%RenommeVar_EEC(AGPR,AGPRM);
	%RenommeVar_EEC(TYPMEN5,TYPMEN7);
	%RenommeVar_EEC(CSTOTPR,CSTOTPRM);
	%RenommeVar_EEC(EFEN,TREFEN);
	%RenommeVar_EEC(NAFAN,NAFANT);
	%RenommeVar_EEC(NAFG88UN,NAFG088UN);
	%RenommeVar_EEC(NAFG17N,NAFG017N);
	%RenommeVar_EEC(COHAB,COURED);
	%RenommeVar_EEC(NBPIEC,NBPI);
	%RenommeVar_EEC(NBINDE,NBIND);
	%RenommeVar_EEC(TXTPPB,TXTPPRED);
	%RenommeVar_EEC(dchant,dchantm);
	%do i =1 %to 9; 
		%RenommeVar_EEC(NOIENF&i.,NOIENF0&i.);
		%end;

	/* 2	Changement de formats */
	%NumericToString(ancchomm,2.);
	%NumericToString(ancinatm,2.);
	%NumericToString(dchantm,2.);
	%NumericToString(dremcm,2.);
	%NumericToString(empnbh,4.);
	%NumericToString(hhc,4.);
	%NumericToString(salmee,7.);
	%NumericToString(ancentr,3.);

	/* 3	Changement de modalit�s */
	/* OFFICC : modalit� 2 "dispens� de recherches" dispara�t */
	if officc='2' then officc='1';	
	if officc='3' then officc='2';

	/* AG (�ge) : modalit� 00 apparait pour ag<15 */
	if put(ag,3.)<15 then ag5='00' ;

	/* CA (statut d'occupation du logement) ; m�j meme si a priori ne sert pas � ce jour dans Ines */
	if ca='1' then ca='2'; /*regroupement des militaires*/	
	if ca='6' then ca='7'; /*d�tenus*/
	/* + modalit� 4 split�e en 4 et 6 (�tudiant en logement ind�pendant : chez ses parents ou non) */

	/* CHPUB et ECHPUB: changement de modalit�s (+ ajout de la modalit� s�curit� sociale*/
	if chpub='1' then chpub='3';
	if chpub='2' then chpub='4';
	if chpub='3' then chpub='5';
	if chpub='4' then chpub='7';
	if chpub='5' then chpub='2';
	if chpub='6' then chpub='1';

	if echpub='1' then echpub='3';
	if echpub='2' then echpub='4';
	if echpub='3' then echpub='5';
	if echpub='4' then echpub='7';
	if echpub='5' then echpub='2';
	if echpub='6' then echpub='1';

	/* EFEN continu -> EFEN en tranches num�riques (ERFS 2009) -> TREFEN en tranches texte (ERFS 2013) */
	%if &anref.<2009 %then %do;
		if 0<trefen<3 then trefen=1;
		else if 3<=trefen<6 then trefen=3;
		else if 6<=trefen<10 then trefen=6;
		else if 10<=trefen<20 then trefen=10;
		else if 20<=trefen<50 then trefen=20;
		else if 50<=trefen<100 then trefen=50;
		else if 100<=trefen<200 then trefen=100;
		else if 200<=trefen<250 then trefen=200;
		else if 250<=trefen<500 then trefen=250;
		else if 500<=trefen<1000 then trefen=500;
		else if 1000<=trefen<2000 then trefen=1000;
		else if 2000<=trefen<5000 then trefen=2000;
		else if 5000<=trefen<10000 then trefen=5000;
		else if 10000<=trefen<999999 then trefen=10000;
		%end;
	if trefen=0 then trefen=00;
	else if trefen=1 then trefen=01;
	else if trefen=3 then trefen=02;
	else if trefen=6 then trefen=03;
	else if trefen=10 then trefen=11;
	else if trefen=20 then trefen=12;
	else if trefen=50 then trefen=21;
	else if trefen=100 then trefen=22;
	else if trefen=200 then trefen=31;
	else if trefen=250 then trefen=32;
	else if trefen=500 then trefen=41;
	else if trefen=1000 then trefen=42;
	else if trefen=2000 then trefen=51;
	else if trefen=5000 then trefen=52;
	else if trefen=10000 then trefen=53;
	%NumericToString(trefen,2.);

	/* STC : ajout d'une modalit� suite au split de la modalit� 1 et d�calage de signification pour les suivantes */
	if stc='3' then stc='4';
	if stc='2' then stc='3';

	/* Noicon et Noienf : sur 2 positions contre une avant ==> les modalit�s 1 � 9 deviennent 01 � 09*/
	if noicon ne '' &  input(noicon,2.) < 10 then noicon= '0'!!compress(noicon);
	%do i =1 %to 9; 
		if noienf0&i. ne '' &  input(noienf0&i.,3.)<10 then noienf0&i.= '0'!!compress(noienf0&i.);
		%end;
	%do i =1 %to 4; 
		if noienf1&i. ne '' &  input(noienf1&i.,3.)<10 then noienf1&i.= '0'!!compress(noienf1&i.);
		%end;

	%mend Recodification2013_IRF;


	/*	Reconstitution de variables disparues � partir de plusieurs variables  */	
	/* disparition de la variable retrai en 2013 -> pour la reconstruire, on utilise ret preret et actif.
	Or, ret et preret n'�tant renseign�es qu'en interrogation 1 et 6, il faut au pr�alable enrichir la table irf
	avec l'information contenue dans les tables compl�mentaires pour les rangs d'interrogation 2 � 5 */
	%macro remplir_retrai(var); 
	%if &anref.>=2013 %then %do;
		%let anr_m1=%substr(%eval(&anref.-1),3,2);
		%let var_anc=retrai;								
		data travail.irf&anr.e&anr.;
			merge	travail.irf&anr.e&anr. (in=a rename=(ident=ident&anr.))
					rpm.icomprf&anr.e&anr.t3 (keep=ident&anr. noi &var. rename=(&var.=&var.&anr.t3))
					rpm.icomprf&anr.e&anr.t2 (keep=ident&anr. noi &var. rename=(&var.=&var.&anr.t2))
					rpm.icomprf&anr.e&anr.t1 (keep=ident&anr. noi &var. rename=(&var.=&var.&anr.t1))
					%if &anr_m1.=12 %then %do;
						rpm.icomprf&anr.e&anr_m1.t4 (keep=ident&anr. noi &var_anc. rename=(&var_anc.=&var_anc.&anr_m1.t4));
						%end;
					%if &anr_m1.>12 %then %do;
						rpm.icomprf&anr.e&anr_m1.t4 (keep=ident&anr. noi &var. rename=(&var.=&var.&anr_m1.t4));
						%end;
			by ident&anr. noi ;
			if a;
			if RGA="2" then &var.=&var.&anr.t3;
			if RGA="3" then &var.=&var.&anr.t2;
			if RGA="4" then &var.=&var.&anr.t1;
			%if &anr_m1.=12 %then %do;
				if &var.=ret then do; 
				if RGA="5" then &var.=(&var_anc.&anr_m1.t4='1'); end;
				if &var.=preret then do; 
				if RGA="5" then &var.=(&var_anc.&anr_m1.t4='2'); end;
				%end;
			%if &anr_m1.>12 %then %do;
				if RGA="5" then &var.=(&var.&anr_m1.t4=2);
				%end;
			rename ident&anr.=ident;	
			drop &var.&anr.t3 &var.&anr.t2 &var.&anr.t1;
			%if &anr_m1.=12 %then %do; drop &var_anc.&anr_m1.t4 ; %end; %else %do; drop &var.&anr_m1.t4 ; %end;
			run;
		%end;
		%mend;
	%macro recons_retrai;
	%if &anref.>=2013 %then %do;
		data travail.irf&anr.e&anr.;
			set	travail.irf&anr.e&anr. ;		
			if actif='2' & ret='1' then retrai='1';
			else if actif='2' & preret='1' then retrai='2';
			label retrai='retraite ou pr�retraite';
			run;
		%end;
		%mend;
	

%macro Recodification2013_MRF;

	/* 1	Changement de formats */
	SURFRP_=input(SURFRP,2.);

	/* 2	Renommages */
	%RenommeVar_EEC(TYPMEN5,TYPMEN7);
	%RenommeVar_EEC(SURFRP_,SURFTOT);
	%RenommeVar_EEC(SPR,SEXEPRM);
	%RenommeVar_EEC(NBINDE,NBIND);
	%RenommeVar_EEC(aai1,aai);   /*cette variable a aussi chang� de modalit� � la marge*/
	/* renommage TU99 (ERFS <= 2009) -> TU10 (ERFS 2010 � 2012) -> TUU2010 (refonte ERFS 2013) */
	%if &anref.<2010 %then %do;
		%RenommeVar_EEC(TU99,TU10);
		%end ;
	%RenommeVar_EEC(TU10,TUU2010);
	/* 3	Changement de modalit�s */
	if surftot=1 then surftot=35;
	if surftot=2 then surftot=61;
	if surftot=3 then surftot=83;
	if surftot=4 then surftot=110;
	if surftot=5 then surftot=148;

	%mend Recodification2013_MRF;

/* Recodifications propres � l'�largi */

/* Pour l'�largi 2012 uniquement */
%macro Recodification2013_IRF2012ela;
	%RenommeVar_EEC(NBPIEC,NBPI);
	%mend Recodification2013_IRF2012ela;

%macro Recodification2013_IRFela;
	/* Changement de formats */
	%NumericToString(nbchome,2.);
	%NumericToString(nbinact,2.);
	%NumericToString(nbind,2.);
	%NumericToString(dremc,4.);
	%NumericToString(dudet,1.);
	%NumericToString(durstg,1.);
	%NumericToString(tpsint,4.);
	%NumericToString(emphnh,4.);
	%NumericToString(emphrc,4.);
	%NumericToString(emphre,4.);
	%NumericToString(dimheu,3.);
	%NumericToString(salred,7.);
	%NumericToString(salsee,7.);
	%NumericToString(valpre,7.);
	%NumericToString(valprie,7.);
	%NumericToString(nbpi,2.);

	%mend Recodification2013_IRFela;

%macro Recodification2013_MRFela;
	/* Changement de formats */
	%NumericToString(nbchome,2.);
	%NumericToString(nbinact,2.);

	%mend Recodification2013_MRFela;


	/*******************************/
	/* B. Construction des tables  */
	/*******************************/
%macro initialisation_irf;

	/* ERFS �largie */
	%if &noyau_uniquement.=non %then %do;
		data irf&anr.e&anr.t1;
			set cd.irf&anr.e&anr.t1;
			%if 2008<=&anref. and &anref.<=2009 %then %do; 
				%change_length_str(empanh,6);
	 			%change_length_str(circ,2);
				%change_length_str(acesse,2);
				%change_length_str(acessep,2);
				%change_length_str(totnbh,5);
				%end;
			%if &anref.<=2009 %then %do;
				%RenommeVar_EEC(puboep,pub3fp);
				%end;
			%if &anref.<=2012 %then %do;
				%Recodification2013_IRF;
				%Recodification2013_IRFela;
				%end;
		data irf&anr.e&anr.t2;
			set cd.irf&anr.e&anr.t2;
			%if 2008<=&anref. and &anref.<=2009 %then %do; 
				%change_length_str(empanh,6);
	 			%change_length_str(circ,2);
				%change_length_str(acesse,2);
				%change_length_str(acessep,2);
				%change_length_str(totnbh,5);
				%end;
			%if &anref.<=2009 %then %do;
				%RenommeVar_EEC(puboep,pub3fp);
				%end;
			%if &anref.<=2012 %then %do;
				%Recodification2013_IRF;
				%Recodification2013_IRFela;
				%end;
		data irf&anr.e&anr.t3;
			set cd.irf&anr.e&anr.t3;
			%if 2008<=&anref. and &anref.<=2009 %then %do; 
				%change_length_str(empanh,6);
	 			%change_length_str(circ,2);
				%change_length_str(acesse,2);
				%change_length_str(acessep,2);
				%change_length_str(totnbh,5);
				%end;
			%if &anref.<=2009 %then %do;
				%RenommeVar_EEC(puboep,pub3fp);
				%end;
			%if &anref.<=2012 %then %do;
				%Recodification2013_IRF;
				%Recodification2013_IRFela;
				%end;
		data irf&anr.e&anr.t4;
			set cd.irf&anr.e&anr.t4;
			%if 2008<=&anref. and &anref.<=2009 %then %do; 
				%change_length_str(empanh,6);
 				%change_length_str(circ,2);
				%change_length_str(acesse,2);
				%change_length_str(acessep,2);
				%change_length_str(totnbh,5);
				%end;
			%if &anref.<=2009 %then %do;
				%RenommeVar_EEC(puboep,pub3fp);
				%end;
			%if &anref.<=2012 %then %do;
				%Recodification2013_IRF;
				%Recodification2013_IRFela;
				%end;
		data irf&anr.e&anr1.t1;
			set cd.irf&anr.e&anr1.t1;
			%if &anref.<=2009 %then %do;
				%RenommeVar_EEC(puboep,pub3fp);
				%end;
			%if &anref.<2012 %then %do;
				%Recodification2013_IRF;
				%Recodification2013_IRFela;
				%end;
			%if &anref.=2012 %then %do;
				%Recodification2013_IRF2012ela;
				%Recodification2013_IRFela;
				%end;
		data irf&anr.e&anr1.t2;
			set cd.irf&anr.e&anr1.t2;
			%if &anref.<=2009 %then %do;
				%RenommeVar_EEC(puboep,pub3fp);
				%end;
			%if &anref.<2012 %then %do;
				%Recodification2013_IRF;
				%Recodification2013_IRFela;
				%end;
			%if &anref.=2012 %then %do;
				%Recodification2013_IRF2012ela;
				%Recodification2013_IRFela;
				%end;
		data irf&anr.e&anr1.t3;
			set cd.irf&anr.e&anr1.t3;
			%if &anref.<=2009 %then %do;
				%RenommeVar_EEC(puboep,pub3fp);
				%end;
			%if &anref.<2012 %then %do;
				%Recodification2013_IRF;
				%Recodification2013_IRFela;
				%end;
			%if &anref.=2012 %then %do;
				%Recodification2013_IRF2012ela;
				%Recodification2013_IRFela;
				%end;
		/* On regroupe ici les tables irfXXeYYTi qui contiennent les revenus des individus 
		emploi du i�me trimestre 20YY qui sont dans un m�nage de l'ERFS 20XX.
		On supprime les enfants qui ne sont pas pr�sents au 4 trimestre de l'ann�e &anref.
		On garde quand m�me ceux n�s les deux premiers mois de l'ann�e. 
		Ces tables contiennent �galement les individus non r�pondant du trimestre. */
		data travail.irf&anr.e&anr.(rename=(ident&anr.=ident));
			set irf&anr.e&anr.t1(in=a) 
				irf&anr.e&anr.t2(in=b) 
				irf&anr.e&anr.t3(in=c) 
				irf&anr.e&anr.t4(in=d)
		    	irf&anr.e&anr1.t1(in=e) 
				irf&anr.e&anr1.t2(in=f) 
				irf&anr.e&anr1.t3(in=g);
			format module 2.;
			if naia="20&anr1." & input(naim,2.)>=3 then delete;
			/*cr�ation d'une variable choixech permettant de sourcer chaque observation (noyau ou extensions) */
			if a then choixech='EXST1';
			else if b then choixech='EXST2';
			else if c then choixech='EXST3';
			else if d then choixech='NOYAU';
			else if e then choixech='EXET1';
			else if f then choixech='EXET2';
			else if g then choixech='EXET3';

			/* RGA = rang d'interrogation de l'aire. Elle est toujours �gale � 6 dans l'ERFS2010*/ 
		    if choixech='NOYAU' then module=6-input(rga,2.)+1; 
			else if choixech='EXST3' then module=-1; 
			else if choixech='EXST2' then module=-2; 
			else if choixech='EXST1' then module=-3; 
			else if choixech='EXET3' then module=9; 
			else if choixech='EXET2' then module=8; 
			else if choixech='EXET1' then module=7;
			run;
			proc sort data=travail.irf&anr.e&anr.; by ident noi; run;
		%end;

	/* ERFS classique */
	%else %do;
		data travail.irf&anr.e&anr.(rename=(ident&anr.=ident));
			set rpm.irf&anr.e&anr.t4;
			format module 2.;
			if naia="20&anr1." & input(naim,2.)>=3 then delete;
			choixech='NOYAU';
			/* RGA = rang d'interrogation de l'aire. Elle est toujours �gale � 6 dans l'ERFS2010*/ 
		    module=6-input(rga,2.)+1;
			%if &anref.<=2012 %then %do;
				%Recodification2013_IRF;
				%end;
			%if &anref.<=2009 %then %do;
				%RenommeVar_EEC(puboep,pub3fp);
				%end;
			run;
		proc sort data=travail.irf&anr.e&anr.; by ident noi; run;
		%end;
	%remplir_retrai(ret);
	%remplir_retrai(preret);
	%recons_retrai;
	data travail.irf&anr.e&anr.; set travail.irf&anr.e&anr.; keep &KeepListIRF.; run;
	%mend;
%initialisation_irf;


%macro initialisation_mrf;
	/* On r�unit �galement les tables mrfXXeYYti qui contiennent les revenus des m�nages 
	emploi du i�me trimestre 20YY r�pondant � l'ERFS 20XX */

	/* ERFS �largie */	
	%if &noyau_uniquement.=non %then %do;
		data mrf&anr.e&anr.t1;
			set cd.mrf&anr.e&anr.t1;
			%if &anref.<=2012 %then %do;
				%Recodification2013_MRFela;
				%end;
		data mrf&anr.e&anr.t2;
			set cd.mrf&anr.e&anr.t2;
			%if &anref.<=2012 %then %do;
				%Recodification2013_MRFela;
				%end;
		data mrf&anr.e&anr.t3;
			set cd.mrf&anr.e&anr.t3;
			%if &anref.<=2012 %then %do;
				%Recodification2013_MRFela;
				%end;
		data mrf&anr.e&anr.t4;
			set cd.mrf&anr.e&anr.t4;
			%if &anref.<=2012 %then %do;
				%Recodification2013_MRFela;
				%end;
		data mrf&anr.e&anr1.t1;
			set cd.mrf&anr.e&anr1.t1;
			%if &anref.<=2012 %then %do;
				%Recodification2013_MRFela;
				%end;
		data mrf&anr.e&anr1.t2;
			set cd.mrf&anr.e&anr1.t2;
			%if &anref.<=2012 %then %do;
				%Recodification2013_MRFela;
				%end;
		data mrf&anr.e&anr1.t3;
			set cd.mrf&anr.e&anr1.t3;
			%if &anref.<=2012 %then %do;
				%Recodification2013_MRFela;
				%end;
		data travail.mrf&anr.e&anr.(rename=(ident&anr.=ident) keep=&KeepListMRF.);
			set mrf&anr.e&anr.t1
				mrf&anr.e&anr.t2
				mrf&anr.e&anr.t3
				mrf&anr.e&anr.t4
				mrf&anr.e&anr1.t1 (%if &anref.=2009 %then %do; drop=NAF16PR NAFG36PR NAF16CJ NAFG36CJ %end;)
				mrf&anr.e&anr1.t2 (%if &anref.=2009 %then %do; drop=NAF16PR NAFG36PR NAF16CJ NAFG36CJ %end;)
				mrf&anr.e&anr1.t3 (%if &anref.=2009 %then %do; drop=NAF16PR NAFG36PR NAF16CJ NAFG36CJ %end;);
			%if &anref.<=2012 %then %do;
				%Recodification2013_MRF;
				%end;
			run;
		%end;

	/* ERFS classique */	
	%else %do;
		proc sql;
			create table travail.mrf&anr.e&anr.(rename=(ident&anr.=ident)) as
			select * from rpm.mrf&anr.e&anr.t4
			order by ident&anr.;
			quit;
		proc sort data=travail.mrf&anr.e&anr.; by ident; run;
		%if &anref.<=2012 %then %do;
			data travail.mrf&anr.e&anr. (keep=&KeepListMRF.);
				set travail.mrf&anr.e&anr.;
				%Recodification2013_MRF;
				run;
			%end;
		%if &anref.>2012 %then %do;  /* recalcul de NBENFC disparu � partir d'ERFS 2013 */
			proc sql;
				create table nbenf as
				select ident, sum((lprm='3' and matri in('1',''))*1) as nbenfc
				from travail.irf&anr.e&anr.
				group by ident
				order by ident;
				quit;
			data travail.mrf&anr.e&anr. (keep=&KeepListMRF.);
				merge	travail.mrf&anr.e&anr. (in=a)
						nbenf; 
				by ident; 
				if a;
				run;
			%end;
		%end;
	%mend;
%initialisation_mrf;


/* Traitement du cas de l'apparition de l'agr�gat zpi (pensions d'invalidit�) � partir de l'ERFS 2014, qui faisait partie avant
de zrst et qui doit �tre cr�� (mais �gal � 0) pour les ERFS ant�rieures � 2014.
TO DO : V�rifier qu'� son apparition dans l'ERFS 2014, l'agr�gat a bien la m�me forme que ce qu'on lui donne ici */

%macro traitement_zpi;
%if &anref.<2014 %then %do; 
/* ERFS �largie */
	%if &noyau_uniquement.=non %then %do;
	data cd.indiv20&anr._ela;
		set cd.indiv20&anr._ela;
		zpio=0;
		zpii=0;
		run;
	data cd.indfip20&anr._ela;
		set cd.indfip20&anr._ela;
		zpii=0;
		run;
	data cd.foyer&anr._ela;
		set cd.foyer&anr._ela;
		zpif=0;
		run;
	data cd.men20&anr._ela;
		set cd.men20&anr._ela;
		zpim=0;
		run;
		%end;
/* ERFS noyau */
	%else %do;
	data rpm.indivi&anr.;
		set rpm.indivi&anr.;
		zpio=0;
		zpii=0;
		run;
	data rpm.indfip20&anr.;
		set rpm.indfip20&anr.;
		zpii=0;
		run;
	data rpm.foyer&anr.;
		set rpm.foyer&anr.;
		zpif=0;
		run;
	data rpm.menage&anr.;
		set rpm.menage&anr.;
		zpim=0;
		run;
		%end;
			%end;
				%mend;
%traitement_zpi;

/****************************************************************************************/
/*	3	Initialisation des fichiers fiscaux INDIVI MENAGE et INDFIP						*/
/****************************************************************************************/


/* INDIVI : tri, recodification, revenus observ�s */

%macro initialisation_indivi;
	/* ERFS �largie */	
	%if &noyau_uniquement.=non %then %do;
		proc sort data=cd.indiv20&anr._ela(rename=(ident&anr.=ident)) 
			out = travail.indivi&anr.(drop=ztsai zreti zperi);
			by ident noi;
			run;
		proc sort data=rpm.indivi&anr.; by ident&anr. noi; run;
		data travail.indivi&anr.;
			merge travail.indivi&anr.(in=a) 
				  rpm.indivi&anr.(in=b keep=ident&anr. noi &RevObserves. rename=(ident&anr.=ident)) 
				  travail.irf&anr.e&anr.(in=c keep=ident noi);
			by ident noi;
			length zsalo_new zchoo_new zrsto_new zpio_new zalro_new zrtoo_new zrago_new zrico_new zrnco_new 8;
			array Zobs_new zsalo_new zrsto_new zpio_new zchoo_new zalro_new zrtoo_new zrago_new zrico_new zrnco_new;
			array Zobs &RevObserves.;
			array Zind &RevIndividuels.;
			if a & c;
			if not b then do;
				/* On souhaite rendre coh�rente les revenus observ�s et les revenus imput�s.
		 		  Si on a pas retrouv� la d�claration d'imp�t, on annule les revenus observ�s.
		  		 Dans les autres cas, on donne � la valeur observ�e, la valeur imput�e */
				if quelfic in('EE','EE_NRT') then do i=1 to dim(Zobs_new); Zobs_new(i)=0; end;
				if quelfic not in('EE','EE_NRT') then do i=1 to dim(Zobs_new); Zobs_new(i)=Zind(i); end;
				end;
			else do i=1 to dim(Zobs_new); Zobs_new(i)=Zind(i); end;
			drop &RevObserves. i;
			rename 	zsalo_new=zsalo 
					zchoo_new=zchoo 
					zrsto_new=zrsto 
					zpio_new=zpio
					zalro_new=zalro 
					zrtoo_new=zrtoo 
					zrago_new=zrago 
					zrico_new=zrico
					zrnco_new=zrnco;
			run;
		%end;

	/* ERFS classique */	
	%else %do;
		proc sort data=rpm.indivi&anr.; by ident&anr. noi; run;
		data travail.indivi&anr.(drop=ztsai zreti zperi);
			merge rpm.indivi&anr.(in=a rename=(ident&anr.=ident)) 
				  travail.irf&anr.e&anr.(in=b keep=ident noi choixech);
			by ident noi;
			length zsalo_new zchoo_new zrsto_new zpio_new zalro_new zrtoo_new zrago_new zrico_new zrnco_new 8;
			array Zobs_new zsalo_new zrsto_new zpio_new zchoo_new zalro_new zrtoo_new zrago_new zrico_new zrnco_new;
			array Zobs &RevObserves.;
			array Zind &RevIndividuels.;
			if a & b;
			do i=1 to dim(Zobs_new); Zobs_new(i)=Zind(i); end;
			drop &RevObserves. i;
			rename 	zsalo_new=zsalo 
					zchoo_new=zchoo 
					zrsto_new=zrsto 
					zpio_new=zpio
					zalro_new=zalro 
					zrtoo_new=zrtoo 
					zrago_new=zrago 
					zrico_new=zrico
					zrnco_new=zrnco;
			run;
		%end;
	%mend;

%initialisation_indivi;


/* MENAGE : v�rification de la concordance avec le total d'INDIVI */

%macro initialisation_menage;
	
	/* ERFS �largie */	
	%if &noyau_uniquement.=non %then %do;
		proc sql;
			create table travail.menage&anr. as
			select distinct a.*,module from cd.men20&anr._ela(rename=(ident&anr.=ident) drop=ztsam zretm zperm) as a
			inner join travail.irf&anr.e&anr.(keep=ident module choixech) as b
			on a.ident=b.ident
			order by ident;
			quit;
		%end;

	/* ERFS classique */	
	%else %do;
		proc sql;
			create table travail.menage&anr. as
			select distinct a.*,module from rpm.menage&anr.(rename=(ident&anr.=ident) drop=ztsam zretm zperm) as a
			inner join travail.irf&anr.e&anr.(keep=ident module choixech) as b
			on a.ident=b.ident
			order by ident;
			quit;
		%end;

	/*1. R�cup�ration des variables TUXX avant 2010 et DEP toutes les ann�es */
	/*2. Traitement de la variable TUXX (tranche d'unit� urbaine), en fonction du mill�sime ERFS :
	A partir de l'ERFS 2010 TU10 a remplac� TU99 (construite et cod�e de la m�me fa�on)
	-> on harmonise les noms de variables des mill�simes anciens � la version la plus r�cente
	TODO: harmonisation pour les ERFS ant�rieures � 2007 */
	%if &anref.=2007 %then %do;
		data travail.menage&anr.;
			merge travail.menage&anr.(in=a) 
				  cd.dep&anr._ela(keep=ident&anr. dep rename=(ident&anr.=ident)) 
				  cd.Tu99(rename=(ident&anr.=ident TU99=TU10));
			by ident;
			if a;
			run;
		%end;
	%else %if &anref.=2008 or &anref.=2009 %then %do;
		data travail.menage&anr.;
			merge travail.menage&anr.(in=a rename=(TU99=TU10)) 
			      cd.dep&anr._ela(keep=ident&anr dep rename=(ident&anr.=ident));
			by ident;
			if a;
			run;
		%end; 
	%else %if &anref.>=2010 and &anref.<2013 %then %do; 
		%if &casd. = non %then %do; /* On ajoute ce filtre pour ne pas g�n�rer d'erreur avec l'ERFS 2012. Les tables de l'�largi ne seront pas du tout disponible dans le cadre du CASD */ 
			data travail.menage&anr.;
				merge travail.menage&anr.(in=a)
			    	  cd.dep&anr._ela(keep=ident&anr dep rename=(ident&anr.=ident));
				by ident;
				if a;
				run;
			%end;
		%else %do ; /* casd = oui */
			data travail.menage&anr.;
				merge travail.menage&anr.(in=a)
			      	  travail.mrf&anr.e&anr. (keep=ident dep);
				by ident;
				if a;
				run;
			%end;
		%end; 
	%else %if &anref.>=2013 %then %do; 
		data travail.menage&anr.;
			merge travail.menage&anr.(in=a)
			      travail.mrf&anr.e&anr. (keep=ident dep);
			by ident;
			if a;
			run;
		%end;
	%mend;
%initialisation_menage;

/* INDFIP : Pr�paration de la table contenant les FIP = pr�sents dans les d�clarations fiscales mais pas dans l'enqu�te emploi */

%macro initialisation_indfip;
	/* ERFS �largie */	
	%if &noyau_uniquement.=non %then %do;
		proc sql;
		create table travail.indfip&anr.(rename=(ident&anr.=ident) drop=ztsai zreti zperi) as
			select *, zsali as zsalo, zrsti as zrsto, zpii as zpio, zchoi as zchoo, zalri as zalro, zrtoi as zrtoo,
			zragi as zrago, zrici as zrico, zrnci as zrnco
			from cd.indfip20&anr._ela (rename=(anfip=naia)) as a
			%if &anref.="2009" %then %do;
				left inner join
				cd.indfip_anfip(rename=(anfip=naia)) as b
				on a.noindiv=b.noindiv
				%end;
			order by ident&anr.,noi;
			quit;
		%end;

	/* ERFS classique */
	%else %do;
		proc sql;
			create table travail.indfip&anr.(rename=(ident&anr.=ident) drop=ztsai zreti zperi) as
			select *, zsali as zsalo, zrsti as zrsto, zpii as zpio, zchoi as zchoo, zalri as zalro, zrtoi as zrtoo,
			zragi as zrago, zrici as zrico, zrnci as zrnco
			from rpm.indfip20&anr. (rename=(anfip=naia)) as a
			%if &anref.="2009" %then %do;
				left inner join
				cd.indfip_anfip(rename=(anfip=naia)) as b
				on a.noindiv=b.noindiv
				%end;
			order by ident&anr.,noi;
			quit;
		%end;

	/* On s'assure ici que tous les individus FIP d'un m�me m�nage ont bien un noi diff�rent, ce
	   qui n'est pas forc�ment le cas dans la table de d�part et on ajoute la variable dep */
	data travail.indfip&anr.(drop=noidep);
		merge 	travail.indfip&anr.(rename=(noi=noidep) in=a) 
				travail.menage&anr.(keep=ident dep);
		by ident;
		length noi $2 noindiv $10.;
		retain noi;
		if a;
		if first.ident then noi=noidep; 
		else noi=put(input(noi,2.)+1,2.);
		noindiv=compress(ident!!noi);
		run;
	%mend;
%initialisation_indfip;

/* on supprime les m�nages hors champ ERFS */
proc sort data=travail.mrf&anr.e&anr.; by ident; run;
data travail.mrf&anr.e&anr.;
	merge 	travail.mrf&anr.e&anr.(in=a) 
			travail.menage&anr.(in=b keep=ident wp: logt);
	by ident;
	if a & b;
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
