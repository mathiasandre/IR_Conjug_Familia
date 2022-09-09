/****************************************************************************/
/*																			*/
/*  Ce programme compare la structure et le contenu de deux ERFS ou plus	*/
/*																			*/
/****************************************************************************/

/* Ce programme : 
	- est complètement indépendant de l'enchaînement d'Ines
	- est à faire tourner à chaque réception d'une nouvelle ERFS noyau ou élargie
	- a pour objectif de détecter le plus tôt possible des éventuelles erreurs de production de l'ERFS */

/* On compare soit deux (ou plus) ERFS noyau, soit deux (ou plus) ERFS élargies */
/* Si l'on souhaite comparer pour une même année, le noyau à l'élargie, il faut faire tourner l'autre programme */

/* En entrée : librairie NOYAU ou ELARGI contenant l'ERFS N livrée par RPM 	*/
/* En sortie : fichiers Excel à regarder et retravailler éventuellement	*/

/* PLAN
	1	Contenu de la librairie : volumétrie, nombre de lignes et de colonnes, liste des variables
	2	Nombre d'individus et de ménages en pondéré, et agrégats
	3	Evolution des masses (pondérées) des cases fiscales
	4	Nombre d'individus par type, non pondéré
	5	Revenus imputés pour les EE_FIP
	6	Nombre d'étudiants et de ménages dont la PR est étudiante (seulement sur le noyau)
	7  Évolution des très hauts salaires
	8	Autres idées ... 
*/

%let chemin_bases=X:\HAB-INES\Tables INES;	/* A compléter (chemin des librairies NOYAU et ELARGI) */
%let chemin_verif=Z:\Verif_ERFS; /* A compléter (chemin des fichiers de sortie) */
%let annee_ERFS=2016;
%let lib=noyau; /* ENTRER elargi SI ON SOUHAITE COMPARER DES ERFS ELARGIES ENTRE ELLES, noyau SINON */
%let excel_exp=xls;

libname noyau "&chemin_bases.\ERFS &annee_ERFS.\noyau";
libname elargi "&chemin_bases.\ERFS &annee_ERFS.\elargi";


%macro Comparaison_ERFS (andeb=,anfin=,export=oui,videWork=oui);

	/* On obtient les sorties suivantes (4 onglets) : volume de la table, nombre de lignes, de colonnes, et liste des variables */

	data tempVol_; set _null_; run;
	data tempObs_; set _null_; run;
	data tempCol_; set _null_; run;
	data tempVar_; set _null_; run;

	/* 	ANDEB et ANFIN forment l'intervalle d'étude (toutes les ERFS comprises entre ces deux années incluses)
		Par défaut la macro exporte les résultats et vide la Work des fichiers temporaires créés. 
		La macro indique la volumétrie en octets de toutes les tables de NOYAU ou ELARGI */

	%do an=&andeb. %to &anfin.;
		libname &lib. "&chemin_bases.\ERFS &an.\&lib.";

		/*	Sortie 1 : Volumétrie : TempVol */
		ods output "Library Members"=temp;
			proc datasets lib=&lib.; quit;
			ods output close;
		data temp;
			length name $100.;
			set temp;
			%remplaceChaineDansMot(name,name,"%substr(&an.,3,2)","XX");
			%remplaceChaineDansMot(name,name,"%substr(%eval(&an.-1),3,2)","-1");
			%remplaceChaineDansMot(name,name,"%substr(%eval(&an.+1),3,2)","+1");
			%remplaceChaineDansMot(name,name,"%substr(%eval(&an.-2),3,2)","-2");
			%remplaceChaineDansMot(name,name,"%substr(%eval(&an.+2),3,2)","+2");
			annee=&an.;
			name=compress("&lib.."||name);
			run;
		proc sort data=temp; by name; run;
		proc transpose data=temp out=tempVol (drop=_NAME_ rename=(col1=_&an.)); by name; var filesize; run;

		/* Sorties 2 et 3 : Nombre de lignes et de colones : TempObs et TempCol */
		ods output "Attributes"=temp;
			proc datasets lib=&lib.; contents data=_all_; quit;
			ods output close;
		data temp;
			set temp;
			%remplaceChaineDansMot(member,member,"%substr(&an.,3,2)","XX");
			%remplaceChaineDansMot(member,member,"%substr(%eval(&an.-1),3,2)","-1");
			%remplaceChaineDansMot(member,member,"%substr(%eval(&an.+1),3,2)","+1");
			%remplaceChaineDansMot(member,member,"%substr(%eval(&an.-2),3,2)","-2");
			%remplaceChaineDansMot(member,member,"%substr(%eval(&an.+2),3,2)","+2");
			annee=&an.;
			name=member;
			run;
		proc sort data=temp; by name; run;
		proc transpose data=temp(where=(label2="Observations")) out=tempObs (drop=_NAME_ rename=(col1=_&an.)); by name; var cvalue2; run;
		proc transpose data=temp(where=(label2="Variables")) out=tempCol (drop=_NAME_ rename=(col1=_&an.)); by name; var cvalue2; run;

		/* Sortie 4 : Liste des variables : TempVar */
		ods output "Variables"=temp;
			proc datasets lib=&lib.; contents data=_all_; quit;
			ods output close;
		proc sort data=temp (keep=member variable label); by member variable; run;
		data temp;
			set temp;
			%remplaceChaineDansMot(member,member,"%substr(&an.,3,2)","XX");
			%remplaceChaineDansMot(member,member,"%substr(%eval(&an.-1),3,2)","-1");
			%remplaceChaineDansMot(member,member,"%substr(%eval(&an.+1),3,2)","+1");
			%remplaceChaineDansMot(member,member,"%substr(%eval(&an.-2),3,2)","-2");
			%remplaceChaineDansMot(member,member,"%substr(%eval(&an.+2),3,2)","+2");
			annee=&an.;
			name=compress(member||"."||upcase(variable));
			drop member;
			run;
		proc sort data=temp; by name; run;
		proc transpose data=temp out=tempVar (drop=_NAME_ rename=(col1=_&an.)); by name; var annee; run;

		%let ListeSorties=Vol Obs Col Var;
		%do k=1 %to %sysfunc(countw(&ListeSorties.));
			%let sortie=%scan(&ListeSorties.,&k.);
			/* On empile les fichiers de sortie par année (sauf si c'est la première année de la boucle) */
			%if &an.=&andeb. %then %do;
				data temp&sortie._; set temp&sortie.; run;
				%end;
			%else %do;
				data temp&sortie._; merge temp&sortie._ temp&sortie.; by name; run;
				%end;
			%end;
		%end;

	%do k=1 %to %sysfunc(countw(&ListeSorties.));
		%let sortie=%scan(&ListeSorties.,&k.);
		/* Mise en forme, export éventuel et nettoyage de la Work */
		data temp&sortie._;
			retain lib table;
			set temp&sortie._;
			find=find(name,".");
			lib=substr(name,1,find-1);
			table=substr(name,find+1,length(name)-find);

			%if &sortie.=Var %then %do;
				find=find(table,".");
				variable=substr(table,find+1,length(table)-find);
				table=substr(table,1,find-1);
				%end;
			drop find name;
			run;
		%if &export. = oui %then %do;
			proc export data=temp&sortie._ outfile="&chemin_verif.\Evolution_&lib._&andeb._&anfin..xls" dbms=&excel_exp. replace; sheet="&Sortie."; run;
			%end;
		%end;
	%if &videWork. = oui %then %do;
		proc delete data=temp tempVol tempVol_ tempObs tempObs_ tempCol tempCol_ tempVar tempVar_; run;
		%end;
	%mend Comparaison_ERFS;

%Comparaison_ERFS(andeb=2015,anfin=2016,export=oui);


/*****************************************************************/
/*	2	Nombre d'individus et de ménages en pondéré, et agrégats */
/*****************************************************************/

%macro Effectifs_Agregats (andeb=,anfin=,export=oui,videWork=oui);

	%if &lib.=noyau %then %do;
		%let poids=wprm;
		%end;
	%else %if &lib.=elargi %then %do;
		%let poids=wpela;
		%end;

	%do an=&andeb. %to &anfin.;
		%let a=%substr(&an.,3,2);
		libname &lib. "&chemin_bases.\ERFS &an.\&lib.";

		%if &lib.=noyau %then %do;
			%let tableInd=indivi&a.;
			%let tableMen=menage&a.;
			%end;
		%else %if &lib.=elargi %then %do;
			%let tableInd=indiv20&a._ela;	/* Tel quel, ne marche que pour le siècle courant */
			%let tableMen=men20&a._ela;		/* Tel quel, ne marche que pour le siècle courant */
			%end;

		/* Sorties : total des individus de indivi des ménages de menage */
		proc means data=&lib..&tableInd. noprint;
			var &poids.;
			output out=temp1 (drop=_type_ rename=(_freq_=NbIndNonPond)) sum=NbInd;
			run;
		proc means data=&lib..&tableMen. noprint;
			var &poids.;
			output out=temp2 (drop=_type_ rename=(_freq_=NbMenNonPond)) sum=NbMen;
			run;

		proc means data=&lib..&tableMen. noprint;
			var	revdecm ztsam zsalm zchom zperm zrtom zretm zrstm zalrm zalvm zricm zrncm zragm
				zfonm zvamm zvalm zetrm zdivm zquom zglom zavfm zthabm;
				/* 	ATTENTION : ZVAMM n'inclut pas 2ch et ZVALM n'inclut pas 2dh (pour éviter doubles compte, cf bilan de production), 
					alors que ces cases sont bien incluses dans l'agrégat foyer (et dans Ines) -> à avoir en tête quand on regarde les sorties ici */
			weight &poids.;
			output 	out=temp3
					sum=revdecm ztsam zsalm zchom zperm zrtom zretm zrstm zalrm zalvm zricm zrncm zragm
						zfonm zvamm zvalm zetrm zdivm zquom zglom zavfm zthabm;
			run;

		/* Mise en forme */
		data temp1; set temp1; annee=&an.; run;
		data temp2; set temp2; annee=&an.; run;
		data temp3; set temp3; annee=&an.; run;
		%if &an.=&andeb. %then %do;
			data temp1_; set temp1; run;
			data temp2_; set temp2; run;
			data temp3_; set temp3; run;
			%end;
		%else %do;
			data temp1_; set temp1_ temp1; run;
			data temp2_; set temp2_ temp2; run;
			data temp3_; set temp3_ temp3; run;
			%end;
		data temp_; retain annee; merge temp1_ temp2_; by annee; run;
		proc transpose data=temp3_ (drop=_type_) out=temp3__; id annee; run;
		%end;
	/* Export et nettoyage de la work des tables intermédiaires */
	%if &export. = oui %then %do;
		proc export data=temp_ outfile="&chemin_verif.\Effectifs_Agregats_&lib._&andeb._&anfin..xls" dbms=&excel_exp. replace; sheet="Effectifs"; run;
		proc export data=temp3__ outfile="&chemin_verif.\Effectifs_Agregats_&lib._&andeb._&anfin..xls" dbms=&excel_exp. replace; sheet="Agregats"; run;
		%end;
	%if &videWork. = oui %then %do;
		proc delete data=temp1 temp2 temp3 temp1_ temp2_ temp3_ temp3__ temp_; run;
		%end;
	%mend Effectifs_Agregats;

%Effectifs_Agregats(andeb=2015,anfin=2016);


/***************************************************************************************/
/* 3	Evolution des masses (pondérées) des cases fiscales : comparaison de deux ERFS */
/***************************************************************************************/

%macro MassesParCase(an1,an2,pond=1,export=oui,videWork=oui);

	/* 	AN1 et AN2 sont les années des deux ERFS à comparer
		POND=0 signifie que l'on ne veut pas pondérer les masses (par wpela ou wprm)
		Par défaut la macro exporte les résultats et vide la Work des fichiers temporaires créées
		La macro calcule les agrégats	- pour AN1 et AN2 pour les cases présentes dans les deux ERFS
										- pour AN2 pour les cases apparues entre AN1 et AN2 */

	%let a1=%substr(&an1.,3,2);
	%let a2=%substr(&an2.,3,2);
	%if &lib.=noyau %then %do;
		%let poids=wprm;
		%let tableFoyer1=foyer&a1.;
		%let tableFoyer2=foyer&a2.;
		%let tableMen1=menage&a1.;
		%let TableMen2=menage&a2.;
		%end;
	%else %if &lib.=elargi %then %do;
		%let poids=wpela;
		%let tableFoyer1=foyer&a1._ela;
		%let tableFoyer2=foyer&a2._ela;
		%let tableMen1=men20&a1._ela;
		%let TableMen2=men20&a2._ela;
		%end;
	
	%Comparaison_ERFS(andeb=&an1.,anfin=&an2.,export=non,videWork=non);
	libname &lib.1 "&chemin_bases.\ERFS &an1.\&lib.";
	libname &lib.2 "&chemin_bases.\ERFS &an2.\&lib.";
	data S&an1. S&an2. S&an1.2 S&an2.2; set _null_; run;

	/* Il faut renommer les ident */
	data foyer1; set &lib.1.&tableFoyer1.; rename ident&a1.=ident; run;
	data foyer2; set &lib.2.&tableFoyer2.; rename ident&a2.=ident; run;
	data menage1; set &lib.1.&tableMen1. (keep=ident: &poids.); rename ident&a1.=ident; run;
	data menage2; set &lib.2.&tableMen2. (keep=ident: &poids.); rename ident&a2.=ident; run;

	/* On va chercher les poids dans la table menage */
	proc sql;
		create table foyer1 as
			select a.*, b.&poids. from foyer1 as a left outer join menage1 as b
			on a.ident=b.ident;
		create table foyer2 as
			select a.*, b.&poids. from foyer2 as a left outer join menage2 as b
			on a.ident=b.ident;
		
	/* 1	Sélection des cases fiscales (commençant par underscore) présentes les deux années */
		select distinct variable into : listeCases1 separated by ' ' from tempVar_
			where substr(table,1,5)="FOYER" and _&an1. eq &an1. and _&an2. eq &an2. and substr(variable,1,1) eq "_";
		quit;
	/* On fait la somme pondérée pour chacune de ces cases */
	%do i=1 %to %sysfunc(countw(&listeCases1.));
		%let var=%scan(&listeCases1.,&i.);
		proc sql; create table S&an1.var as select sum(&var.*&poids.) as &var. from foyer1; quit;
		proc sql; create table S&an2.var as select sum(&var.*&poids.) as &var. from foyer2; quit;
		data S&an1.; merge S&an1. S&an1.var; run;
		data S&an2.; merge S&an2. S&an2.var; run;
		%end;
	/* Mise en forme */
	data Sommes;
		set S&an1. S&an2.;
		run;
	proc transpose data=sommes out=sommes_(rename=(col1=_&an1. col2=_&an2.)); run;

	/* 2	Sélection des cases fiscales apparues */
	proc sql;
		select distinct variable into : listeCases2 separated by ' ' from tempVar_
		where substr(table,1,5)="FOYER" and _&an1. eq . and _&an2. eq &an2. and substr(variable,1,1) eq "_";  
		quit;
	%do j=1 %to %sysfunc(countw(&listeCases2.));
		%let var=%scan(&listeCases2.,&j.);
		proc sql; create table S&an2.var2 as select sum(&var.*&poids.) as &var. from foyer2; quit;
		data S&an2.2; merge S&an2.2 S&an2.var2; run;
		%end;
	proc transpose data=S&an2.2 out=sommes2_(rename=(col1=_&an2.)); run;

	/* Export et nettoyage de la Work des tables intermédiaires */
	%if &export. = oui %then %do;
		proc export data=sommes_ outfile="&chemin_verif.\Masses_par_Case_&lib._&an1._&an2..xls" dbms=&excel_exp. replace; sheet="Cases_Communes"; run;
		proc export data=sommes2_ outfile="&chemin_verif.\Masses_par_Case_&lib._&an1._&an2..xls" dbms=&excel_exp. replace; sheet="Cases_Apparues"; run;
		%end;
	%if &videWork. = oui %then %do;
		proc delete data=temp tempVar temp_ foyer1 foyer2 sommes sommes_ S&an1. S&an2. S&an1.var S&an2.var sommes2_ S&an2.2 S&an2.var2; run;
		%end;
	%mend MassesParCase;

%MassesParCase(2015,2016,videWork=non);

/*************************************************/
/*	4	Nombre d'individus par type, non pondéré */
/*************************************************/

%Macro TypeIndividus(andeb,anfin,export=oui,videWork=oui);

	%do an=&andeb. %to &anfin.;
		%let a=%substr(&an.,3,2);

		%if &lib.=noyau %then %do;
			%let tableInd=indivi&a.;
			libname &lib. "&chemin_bases.\ERFS &an.\&lib.";
			proc summary data=&lib..&TableInd. nway noprint;
				class quelfic;
				output out=temp;
				run;
			%end;

		%else %if &lib.=elargi %then %do;
			%let tableInd=indiv20&a._ela;	/* Ne marche que pour le millénaire courant */
			libname &lib. "&chemin_bases.\ERFS &an.\&lib.";
			proc summary data=&lib..&TableInd. nway noprint;
				class quelfic choixech;
				output out=temp;
				run;
			%end;

		/* Mise en forme */
		data temp; set temp; annee=&an.; run;
		%if &an.=&andeb. %then %do;
			data temp_; set temp; run;
			%end;
		%else %do;
			data temp_; set temp_ temp; run;
			%end;
		%end;

	/* Export et nettoyage de la work des tables intermédiaires */
	%if &export. = oui %then %do;
		proc export data=temp_ outfile="&chemin_verif.\Type_Individus_&lib._&andeb._&anfin..xls" dbms=&excel_exp. replace; sheet="TypeInd"; run;
		%end;
	%if &videWork. = oui %then %do;
		proc delete data=temp temp_; run;
		%end;
	%mend TypeIndividus;

%TypeIndividus(andeb=2015,anfin=2016);


/*******************************************************/
/*	5	Revenus imputés pour les EE_FIP (sur le noyau) */
/*******************************************************/

data imput;
	set noyau.indivi%substr(&annee_ERFS.,3,2);
	if quelfic in ('EE&FIP','FIP') & 
	(	zalri ne zalro ! zreti ne zreto ! zrtoi ne zrtoo ! 
		zragi ne zrago ! zrici ne zrico ! zrnci ne zrnco ! ztsai ne ztsao);
	DiffTot=(zalri+zreti+zrtoi+zragi+zrici+zrnci+ztsai)-(zalro+zreto+zrtoo+zrago+zrico+zrnco+ztsao);
	run;
proc means data=imput mean median min max;
	var DiffTot;
	class quelfic;
	run;
/* 2011 : 514 revenus totalement ou partiellement imputés en dehors des EE, que des EE_FIP */
/* 2012 : 515 revenus totalement ou partiellement imputés en dehors des EE, que des EE_FIP */
/* 2014 : 410 revenus totalement ou partiellement imputés en dehors des EE, que des EE_FIP */
/* 2015 : 430 revenus totalement ou partiellement imputés en dehors des EE, que des EE_FIP */
/* 2016 : 288 revenus totalement ou partiellement imputés en dehors des EE, que des EE_FIP */

/* EE&FIP dont le salaire ZTSAO a été corrigé par imputation : INDIV UNE SEULE DEC RETROUVEE+FORFAITS AGRICOLES */
data uneseuledec forfagri retrempli salrempli bicbncrempli;
	set imput;
	if (zalri ne zalro & zalro ne 0) ! (zperi ne zpero & zpero ne 0) ! (zragi ne zrago & zrago ne 0) ! 
	(zrici ne zrico & zrico ne 0) ! (zrnci ne zrnco & zrnco ne 0) ! (ztsai ne ztsao & ztsao ne 0) then output uneseuledec;
	else if zragi>0 & zrago=0 then output forfagri;
	else if zperi>0 & zpero=0 then output retrempli;
	else if ztsai>0 & ztsao=0 then output salrempli;
	else output bicbncrempli;
	run;
/*	2011
	- 342 indiv dans uneseuledec :individus qui ont eu un evenement dans l'annee mais dont on n'a retrouve qu'une declaration :
	l'ERF leur impute un revenu sur la partie d'annee restante
	- 171 forfagri : forfait agricole impute a des agric pour qui le forfait n'etait pas fixe au moment de l'envoi du fichier POTE
	- 1 dont une retraite a ete imputee : indiv qui declarent avoir ete retraites au moins un mois
	- 0 dont un sal a ete impute : salaries ou stagiaires remuneres au moins un mois dans l'annee;
	- 0 cas de bic ou bnc */
/*	2012
	- 314 indiv dans uneseuledec :individus qui ont eu un evenement dans l'annee mais dont on n'a retrouve qu'une declaration :
	l'ERF leur impute un revenu sur la partie d'annee restante
	- 200 forfagri : forfait agricole impute a des agric pour qui le forfait n'etait pas fixe au moment de l'envoi du fichier POTE
	- 1 dont une retraite a ete imputee : indiv qui declarent avoir ete retraites au moins un mois
	- 0 dont un sal a ete impute : salaries ou stagiaires remuneres au moins un mois dans l'annee;
	- 0 cas de bic ou bnc */
/*	2014
	- 309 indiv dans uneseuledec :individus qui ont eu un evenement dans l'annee mais dont on n'a retrouve qu'une declaration :
	l'ERF leur impute un revenu sur la partie d'annee restante
	- 100 forfagri : forfait agricole impute a des agric pour qui le forfait n'etait pas fixe au moment de l'envoi du fichier POTE
	- 1 dont une retraite a ete imputee : indiv qui declarent avoir ete retraites au moins un mois
	- 0 dont un sal a ete impute : salaries ou stagiaires remuneres au moins un mois dans l'annee;
	- 0 cas de bic ou bnc */
/*	2015
	- 322 indiv dans uneseuledec :individus qui ont eu un evenement dans l'annee mais dont on n'a retrouve qu'une declaration :
	l'ERF leur impute un revenu sur la partie d'annee restante
	- 105 forfagri : forfait agricole impute a des agric pour qui le forfait n'etait pas fixe au moment de l'envoi du fichier POTE
	- 2 dont une retraite a ete imputee : indiv qui declarent avoir ete retraites au moins un mois
	- 1 dont un sal a ete impute : salaries ou stagiaires remuneres au moins un mois dans l'annee;
	- 0 cas de bic ou bnc */
/*	2016
	- 286 indiv dans uneseuledec :individus qui ont eu un evenement dans l'annee mais dont on n'a retrouve qu'une declaration :
	l'ERF leur impute un revenu sur la partie d'annee restante
	- 0 forfagri : forfait agricole impute a des agric pour qui le forfait n'etait pas fixe au moment de l'envoi du fichier POTE
	- 2 dont une retraite a ete imputee : indiv qui declarent avoir ete retraites au moins un mois
	- 0 dont un sal a ete impute : salaries ou stagiaires remuneres au moins un mois dans l'annee;
	- 0 cas de bic ou bnc */

/******************************************************************************************/
/*	6	Nombre d'étudiants, et de ménages dont la PR est étudiante (seulement sur le noyau*/
/******************************************************************************************/

%macro Effectifs_etudiant (andeb=,anfin=,export=oui,videWork=oui);

	%do an=&andeb. %to &anfin.;
		%let a=%substr(&an.,3,2);
		libname &lib. "&chemin_bases.\ERFS &an.\&lib.";

			/*%let tableInd=Irf&a.e&a.t4;
			%let tableMen=Mrf&a.e&a.t4;*/
			%let tableInd=indivi&a.;
			%let tableMen=menage&a.;

			proc sql;
				create table tableInd as
					select a.noindiv, a.wprm, b.acteu6 
					from &lib..&tableInd.(keep=noindiv wprm) as a
					left join &lib..Irf&a.e&a.t4 (keep=acteu6 noindiv) as b
					on a.noindiv=b.noindiv;
				quit;

			proc sql;
				create table tableMen as
					select a.ident&a., a.wprm, %if &a.>=13 %then %do; b.ACTEU6PRM %end; %else %do; b.ACTEU6PR %end;
					from &lib..&tableMen.(keep=ident&a. wprm) as a
					left join &lib..Mrf&a.e&a.t4 (keep= ident&a. %if &a.>=13 %then %do; ACTEU6PRM %end; %else %do; ACTEU6PR %end;)as b
					on a.ident&a.=b.ident&a.;
				quit;

		/* Sorties : total des étudiants de indivi des ménages dont la PR est étudiante de menage */
		proc means data=tableInd noprint;
			var wprm;
			where acteu6="5";
			output out=temp1 (drop=_type_ rename=(_freq_=NbIndNonPond)) sum=NbInd;
			run;
		proc means data=tableMen noprint;
			var wprm;
			where %if &a.>=13 %then %do; ACTEU6PRM="5" %end; %else %do; ACTEU6PR="5" %end;;
			output out=temp2 (drop=_type_ rename=(_freq_=NbMenNonPond)) sum=NbMen;
			run;

		/* Mise en forme */
		data temp1; set temp1; annee=&an.; run;
		data temp2; set temp2; annee=&an.; run;
		%if &an.=&andeb. %then %do;
			data temp1_; set temp1; run;
			data temp2_; set temp2; run;
			%end;
		%else %do;
			data temp1_; set temp1_ temp1; run;
			data temp2_; set temp2_ temp2; run;
			%end;
		data temp_; retain annee; merge temp1_ temp2_; by annee; run;
		%end;
	/* Export et nettoyage de la work des tables intermédiaires */
	%if &export. = oui %then %do;
		proc export data=temp_ outfile="&chemin_verif.\Effectifs_etudiant_&lib._&andeb._&anfin..xls" dbms=&excel_exp. replace; sheet="Effectifs"; run;
		%end;
	%if &videWork. = oui %then %do;
		proc delete data=temp1 temp2 temp1_ temp2_ temp_; run;
		%end;
	%mend Effectifs_etudiant;

%Effectifs_etudiant(andeb=2011,anfin=2016);

/******************************************************************************************/
/*	7	Évolution des masses des hauts salaires comparée à l'évolution des salaires */
/******************************************************************************************/
/* On essaye de repérer ici des variations surprenantes des hauts salaires par rapport au reste des salaires,
qui sont souvent corrélées avec des variations importantes des masses d'IR calculées par le modèle */

%macro verifs_evol_salaires(andeb=,anfin=);
%do annee=&andeb. %to &anfin.;
	%let an=%substr(&annee.,3,2);
	libname noyau&an. "&chemin_bases.\ERFS &annee.\noyau";
	proc sql;
		create table verifs_salaires&an. as
		select zsalf*(zsalf>150000) as zsalf_haut, zsalf, b.wprm
		from noyau&an..foyer&an. as a left join noyau&an..indivi&an. as b
		on a.ident&an.=b.ident&an. and a.noi=b.noi;
		quit;
	proc means data=verifs_salaires&an. sum; var zsalf_haut zsalf; weight wprm; output out=masses_&an.(drop=_type_ _freq_) sum=hauts_salaires salaires; run;
	proc export data=masses_&an. outfile="&chemin_verif.\Evol_salaires_&andeb._&anfin." dbms=&excel_exp. replace; sheet="Annee &annee."; run;
	%end;
%mend;
%verifs_evol_salaires(andeb=2013, anfin=2016);



/* 8. Autre idée : Comparer évolutions des loyers d'une ERFS à l'autre */
/*
proc means data=cd1.men%eval(&annee_ERFS.-1)_ela;
	var loyer loyerfict;
	weight wpela;
	run;
*/
/* Autre idée : part d'individus communs d'un trimestre à un autre */


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
