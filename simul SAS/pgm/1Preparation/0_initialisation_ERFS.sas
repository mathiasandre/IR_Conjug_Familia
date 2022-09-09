/************************************************************************************************************/
/*                             																				*/
/*    									0_initialisation_ERFS  												*/
/*                             																				*/
/************************************************************************************************************/
/*																											*/	
/* Ce programme s'exécute uniquement lors de la 1ère utilisation d'Ines pour un millésime donné d'ERFS 		*/ 
/*																											*/
/* A partir des tables source de l'ERFS, rangées dans des nouveaux répertoires noyau et elargi, ce programme*/
/* crée toutes les tables utiles pour Ines dans les répertoires habituels RPM et CD :						*/
/*	- pour les tables propres à chaque type d'échantillon, qui n'ont pas d'équivalent dans l'autre, il 		*/
/*	  effectue une copie simple																				*/
/*	- pour les tables qui ont un équivalent dans l'autre échantillon :										*/
/*		- lorsque seule la table de l'élargi existe, c'est elle qu'il copie dans RPM (les observations 		*/
/*		  des extensions sont conservées et c'est inutile, mais non problématique si les utilisations		*/
/*		  ultérieures des tables sont faites grâce à des fusions contrôlées)								*/
/*		- lorsque des variables sont manquantes dans l'une des tables, il l'enrichit avec celles de l'autre */
/*	- Après 2013, l'élargi n'est plus disponible, donc on fait une copie simple vers RPM 					*/
/*																											*/	
/* CASD : pour 2012 et 2013, les tables incluant les variables supplémentaires (varsup_2012 et varsup_2013) */
/* ou les observations supplémentaires des individus FIP (indfip2012_ela et indfip2013) doivent être rangées*/ 
/* dans les répertoires noyau. 																				*/ 
/*																											*/		
/* Fonctionnement à partir de 6 listing (dont un spécifique pour après 2013 quand l'élargi n'est plus		*/	 
/* disponible et un spécifique pour le CASD) des tables de l'échantillon noyau et de l'échantillon élargi 	*/ 
/* selon qu'elles aient ou non un équivalent dans l'autre échantillon. Pour les tables ayant un équivalent, */ 
/* les tables sont comparées 2 à 2 entre le noyau et l'élargi en fonction de leur position dans la liste.	*/
/*																											*/
/* NB : Les tables non utilisées par Ines sont en commentaire pour ne pas surchargerles répertoires CD et RPM*/
/************************************************************************************************************/

%let anr=%substr(&anref.,3,2);
%let anr1=%substr(%eval(&anref.+1),3,2);
%let anr2=%substr(%eval(&anref.+2),3,2);
%let anr_1=%substr(%eval(&anref.-1),3,2);
%let anr_2=%substr(%eval(&anref.-2),3,2);

%let liste_tables_noyau_equi=
	foyer&anr.
	irf&anr.e&anr.t4
	mrf&anr.e&anr.t4
	indivi&anr.	
	indfip20&anr.
	menage&anr. ; 

%let liste_tables_elargi_equi=
	foyer&anr._ela
	irf&anr.e&anr.t4
	mrf&anr.e&anr.t4
	indiv20&anr._ela
	indfip20&anr._ela
	men20&anr._ela ;

%let liste_tables_noyau_seul=
	icomprf&anr.e&anr_1.t3 icomprf&anr.e&anr_1.t4 icomprf&anr.e&anr.t1 icomprf&anr.e&anr.t2 icomprf&anr.e&anr.t3   
	icomprf&anr.e&anr1.t1 icomprf&anr.e&anr1.t2 icomprf&anr.e&anr1.t3 indiv&anr2.2 enf&anr2.2 /* icomprf&anr.e&anr1.t4 */
	/* mcomprf&anr.e&anr_1.t3 mcomprf&anr.e&anr_1.t4 mcomprf&anr.e&anr.t1 mcomprf&anr.e&anr.t2 mcomprf&anr.e&anr.t3   
	mcomprf&anr.e&anr1.t1 mcomprf&anr.e&anr1.t2 mcomprf&anr.e&anr1.t3 mcomprf&anr.e&anr1.t4 */
	/* menage&anr_1._pat&anr._1 */;

%let liste_tables_elargi_seul=
	irf&anr.e&anr.t1 irf&anr.e&anr.t2 irf&anr.e&anr.t3
	mrf&anr.e&anr.t1 mrf&anr.e&anr.t2 mrf&anr.e&anr.t3
	irf&anr.e&anr1.t1 irf&anr.e&anr1.t2 irf&anr.e&anr1.t3
	mrf&anr.e&anr1.t1 mrf&anr.e&anr1.t2 mrf&anr.e&anr1.t3
	icompt1ela&anr. icompt2ela&anr. /* mcompt1ela&anr. mcompt2ela&anr. */
	is&anr_2.t4ela&anr. is&anr_1.t1ela&anr. is&anr_1.t2ela&anr. is&anr_1.t3ela&anr. is&anr_1.t4ela&anr.
	dep&anr._ela extrait_th /* panel&anr._ela th20&anr._brut */;

%let liste_tables_noyau_2013=
	icomprf&anr.e&anr_1.t3 icomprf&anr.e&anr_1.t4 icomprf&anr.e&anr.t1 icomprf&anr.e&anr.t2 icomprf&anr.e&anr.t3   
	icomprf&anr.e&anr1.t1 icomprf&anr.e&anr1.t2 icomprf&anr.e&anr1.t3 icomprf&anr.e&anr1.t4 icomprf&anr.e&anr2.t1
	mcomprf&anr.e&anr_1.t3 mcomprf&anr.e&anr_1.t4 mcomprf&anr.e&anr.t1 mcomprf&anr.e&anr.t2 mcomprf&anr.e&anr.t3   
	mcomprf&anr.e&anr1.t1 mcomprf&anr.e&anr1.t2 mcomprf&anr.e&anr1.t3 mcomprf&anr.e&anr1.t4 mcomprf&anr.e&anr2.t1   
	indiv&anr2.2 enf&anr2.2 
	foyer&anr.
	irf&anr.e&anr.t4
	mrf&anr.e&anr.t4
	indivi&anr.
	indfip20&anr. 
	Extrait_th; /*table menage traité spécifiquement en 2013 à cause de variables supplémentaires*/

%let liste_tables_noyau_post2013=
	icomprf&anr.e&anr_1.t3 icomprf&anr.e&anr_1.t4 icomprf&anr.e&anr.t1 icomprf&anr.e&anr.t2 icomprf&anr.e&anr.t3   
	icomprf&anr.e&anr1.t1 icomprf&anr.e&anr1.t2 icomprf&anr.e&anr1.t3 icomprf&anr.e&anr1.t4 icomprf&anr.e&anr2.t1
	mcomprf&anr.e&anr_1.t3 mcomprf&anr.e&anr_1.t4 mcomprf&anr.e&anr.t1 mcomprf&anr.e&anr.t2 mcomprf&anr.e&anr.t3   
	mcomprf&anr.e&anr1.t1 mcomprf&anr.e&anr1.t2 mcomprf&anr.e&anr1.t3 mcomprf&anr.e&anr1.t4 mcomprf&anr.e&anr2.t1   
	indiv&anr2.2 enf&anr2.2 
	foyer&anr.
	irf&anr.e&anr.t4
	mrf&anr.e&anr.t4
	indivi&anr.
	indfip20&anr. 
	menage&anr. 
	Extrait_th;

%let liste_tables_noyau_casd_2012 = foyer&anr. irf&anr.e&anr.t4 mrf&anr.e&anr.t4 indivi&anr. menage&anr. 
	icomprf&anr.e&anr_1.t3 icomprf&anr.e&anr_1.t4 icomprf&anr.e&anr.t1 icomprf&anr.e&anr.t2 icomprf&anr.e&anr.t3   
	icomprf&anr.e&anr1.t1 icomprf&anr.e&anr1.t2 icomprf&anr.e&anr1.t3 icomprf&anr.e&anr1.t4 
	mcomprf&anr.e&anr_1.t3 mcomprf&anr.e&anr_1.t4 mcomprf&anr.e&anr.t1 mcomprf&anr.e&anr.t2 mcomprf&anr.e&anr.t3   
	mcomprf&anr.e&anr1.t1 mcomprf&anr.e&anr1.t2 mcomprf&anr.e&anr1.t3 mcomprf&anr.e&anr1.t4 /* menage&anr_1._pat&anr._1 */
	indfip20&anr._ela ; /* table en plus : individus fip */
	 

%Macro adapt_ERFS_noyau_elargi;
%if &Anref_Ech_prem.=oui %then %do;
/*I. Avant 2013, on gère le noyau et l'élargi */
	%if &anref.<2013 %then %do;
		%if &casd. = non %then %do;
			/* 1. Gestion des tables noyau et élargi ayant un équivalent dans l'autre échantillon */
			%let l=1;
			%do %while(%scan(&liste_tables_noyau_equi.,&l)> );
				/*la condition while pourrait aussi s'appliquer à la liste &liste_tables_elargi mais il faut bien en choisir 1 des 2,
				l'essentiel est le nb égal de tables dans les 2*/
				%let table_n=%scan(&liste_tables_noyau_equi.,&l);
				%let table_e=%scan(&liste_tables_elargi_equi.,&l);
				/* gestion de l'identifiant à utiliser selon les tables et les types de procédure (sql ou data) */
				%if %substr(&table_e,1,1)=f %then %do; 
					%let ident= declar; %let id_indiv= ; %let ident_data= declar;
					%end;
				%if %substr(&table_e,1,1)=m %then %do;
					%let ident= ident&anr.; %let id_indiv= ; %let ident_data= ident&anr.;
					%end;
				%if %substr(&table_e,1,1)=i %then %do;
					%let ident= ident&anr.; %let id_indiv= and a.noi=b.noi; %let ident_data= ident&anr. noi;
					%end;
				/* gestion du compteur pour faire avancer la liste */
	    		%let l=%eval(&l+1);

				/* 1A. Lorsque les tables dans leur format noyau n'existent pas dans le répertoire noyau (mrf indfip)
				on copie leur équivalent élargi dans cd et dans rpm */
				%if %sysfunc(exist(noyau.&table_n.))=0 %then %do;
					%put &table_n. n existe pas dans le noyau on copie celle de l elargi;
					data rpm.&table_n.; set elargi.&table_e.; run;
					data cd.&table_e.; set elargi.&table_e.; run;
					%end;

				/* 1B. Lorsque les tables existent on en vérifie le contenu et les enrichit le cas échéant
				avec les variables de l'autre échantillon */
				%else %do;
					/* création sous forme de table de la liste des variables des deux tables d'intérêt */
					proc contents data=noyau.&table_n. out=var_noyau (keep=name) noprint; run;
					proc contents data=elargi.&table_e. out=var_elargi (keep=name) noprint; run;
					/* Problème de casse soulevé par le contents -> on met tous les noms de variable en majuscule */
					data var_noyau; set var_noyau; name=upcase(name); run;
					data var_elargi; set var_elargi; name=upcase(name); run;
					/* Création sous forme de table de deux listes de variables présentes seulement dans un cas */
					proc sort data=var_noyau; by name; run;
					proc sort data=var_elargi; by name; run;
					data Noy_not_Ela Ela_Not_Noy;
						merge var_noyau (in=Noy) var_elargi (in=Ela);
						by name;
						if Noy and not Ela then output Noy_not_Ela;
						if Ela and not Noy then output Ela_Not_Noy;
					run;
					proc transpose data=Ela_Not_Noy out=Ela_Not_Noy_ (drop=_name_); id name; run;
					proc transpose data=Noy_not_Ela out=Noy_not_Ela_ (drop=_name_); id name; run;
					/* on ajoute aux tables du noyau les variables de l'élargi non présentes dans le noyau */
					%ListeVariablesDUneTable(table=Ela_Not_Noy_,mv=Liste_Ela_Not_Noy,separateur=',');
					%if &Liste_Ela_Not_Noy.= %then %do;
						proc sql;
							create table rpm.&table_n. as select * from noyau.&table_n.;
							quit;
						%end;
					%else %do;
						proc sql;
							create table rpm.&table_n. as
							select a.*, &Liste_Ela_Not_Noy.
							from noyau.&table_n. as a
							left join elargi.&table_e. as b
							on a.&ident.=b.&ident. &id_indiv. ;
							quit;
						%end;
					/* on ajoute aux tables de l'élargi les variables du noyau non présentes dans l'élargi */
					%ListeVariablesDUneTable(table=Noy_not_Ela_,mv=Liste_Noy_not_Ela,separateur='');
					%if &Liste_Noy_Not_Ela.= %then %do;
						proc sql;
							create table cd.&table_e. as select * from elargi.&table_e.;
							quit;
						%end;
					%else %do;
						/* une création par data pour utiliser Init_Valeur et ne conserver qu'une seule étape */
						proc sort data=elargi.&table_e. out=cd.&table_e. ; by &ident_data.; run;
						proc sort data=rpm.&table_n.; by &ident_data.; run;
						data cd.&table_e.;
							merge	cd.&table_e. (in=a)
									rpm.&table_n. (in=b keep=&ident_data. &Liste_Noy_Not_Ela.);
							by &ident_data.;
							if a;
							if not b then do;
								%Init_Valeur(&Liste_Noy_Not_Ela.);
								end;
							run;
						%end;	/* fin cas : &Liste_Noy_Not_Ela. non nulle */
					%end;	/* fin cas : la table existe */
				%end; /* fin boucle while */
			/* 2. Gestion des tables propres à chaque échantillon : copie de noyau vers rpm et d'élargi vers cd */
			%let m=1;
			%do %while(%scan(&liste_tables_noyau_seul.,&m)> ); 
				%let table_ns=%scan(&liste_tables_noyau_seul.,&m);
	    		%let m=%eval(&m+1);
				proc sql;
					create table rpm.&table_ns. as
					select *
					from noyau.&table_ns.;
					quit;
				%end; /* fin de la boucle */
			%let m=1;
			%do %while(%scan(&liste_tables_elargi_seul.,&m)> ); 
				%let table_es=%scan(&liste_tables_elargi_seul.,&m);
	    		%let m=%eval(&m+1);
				proc sql;
					create table cd.&table_es. as
					select *
					from elargi.&table_es.;
					quit;
				%end; /* fin de la boucle */
			/* 3. rustine et ajouts tables retropolés*/ 
			%if &anref.=2012 %then %do;
				/* Rustine : ajout aux tables complémentaires de 2013 de l'élargi 2012 la colonne manquante rdem (présente dans le noyau) */
				data cd.irf&anr.e&anr1.t1;
					set cd.irf&anr.e&anr1.t1;
					rdem='';
				data cd.irf&anr.e&anr1.t2;
					set cd.irf&anr.e&anr1.t2;
					rdem='';
				data cd.irf&anr.e&anr1.t3;
					set cd.irf&anr.e&anr1.t3;
					rdem='';
					run;
				/*ajouts tables retropolées*/
				proc sql;
					create table rpm.menage12_retropole as
					select *
					from noyau.menage12_retropole;
					quit;
				proc sql;
					create table rpm.indivi12_retropole as
					select *
					from noyau.indivi12_retropole;
					quit;
				%end; /* fin rustine */
			%end; /* fin casd = non */

		%else %do; /* CASD = OUI */
			/* cas particulier CASD pour ERFS 2012 : pas d'accès à l'élargi et donc aux variables supplémentaires et aux individus fip */
			/* On copie simplement les tables de noyau à rpm, y compris la table avec les variables supplémentaires et indfip */	
			%if &anref. = 2012 %then %do;
				%let m=1;
				%do %while(%scan(&liste_tables_noyau_casd_2012.,&m)> ); 
					%let table_ns=%scan(&liste_tables_noyau_casd_2012.,&m);
	    			%let m=%eval(&m+1);
					proc sql;
						create table rpm.&table_ns. as
						select *
						from noyau.&table_ns.;
						quit;
					%end; /* fin de la boucle */	
				/* Tables variables supplémentaires + renommage indfip */
				proc sql;
					/* Individus FIP */
					create table rpm.indfip20&anr. as
					select *
					from rpm.indfip20&anr._ela;
					/* On ajoute la variable p */
					create table rpm.irf&anr.e&anr.t4 as
					select distinct a.*, b.p
					from  rpm.irf&anr.e&anr.t4 as a
					left join noyau.varsup_&anref. (keep= ident&anr. noi p) as b on a.ident&anr.=b.ident&anr. and a.noi=b.noi ;
					/* On ajoute la variable dep */
					create table rpm.mrf&anr.e&anr.t4 as
					select distinct a.*, b.dep
					from  rpm.mrf&anr.e&anr.t4 as a
					left join noyau.varsup_&anref. (keep= ident&anr. dep) as b on a.ident&anr.=b.ident&anr. ;
					/* On ajoute les variables logt, loyer et loyerfict */
					create table rpm.menage&anr. as
					select distinct a.*, b.logt, b.loyer, b.loyerfict
					from  rpm.menage&anr. as a
					left join noyau.varsup_&anref. (keep= ident&anr. logt loyer loyerfict) as b on a.ident&anr.=b.ident&anr. ;
					quit;
				%end; /* fin ERFS 2012 */
			%end; /* fin casd */
		%end; /* fin ERFS < 2013 */

	/* II. Après 2013, l'élargi n'est plus disponible, donc on fait une copie simple vers RPM et on traite les variables supplémentaires*/
	%if &anref.>=2014 %then %do; 
		%let m=1;
		%do %while(%scan(&liste_tables_noyau_post2013.,&m)> ); /* y compris la table supplémentaire indfip20&anr. */
			%let table_post13=%scan(&liste_tables_noyau_post2013.,&m);
	    	%let m=%eval(&m+1);
			proc sql;
				create table rpm.&table_post13. as
				select *
				from noyau.&table_post13.;
				quit;
			%end;
		%end; /* fin situation à partir de ERFS 2014 */

	/* Cas spécifique de l'année 2013 : variables supplémentaires dans une table différente dans le cadre du CASD */
	/*Utilisation de variables supplémentaires pour la table menage. ToDo : vérifier que la table ait bien le même nom les prochaines années*/
	%if &anref. = 2013 %then %do; 
		%let m=1;
		%do %while(%scan(&liste_tables_noyau_2013.,&m)> ); /* y compris la table supplémentaire indfip20&anr. mais sans la table menage*/
			%let table13=%scan(&liste_tables_noyau_2013.,&m);
	    	%let m=%eval(&m+1);
			proc sql;
				create table rpm.&table13. as
				select *
				from noyau.&table13.;
				quit;
			%end;
		%if &casd. = non %then %do; 
			proc sql;
				create table rpm.menage&anr. as
				select a.*, b.nbind, b.logt, b.loyer, b.loyerfict, b.nais&anref.
				from noyau.menage&anr. as a
				left join noyau.Men&anref._ines (keep=ident&anr. nbind logt loyer loyerfict nais&anref.) as b on a.ident&anr.=b.ident&anr. ;
				quit;
			%end;
		%else %do ;
			proc sql;
				/* On ajoute la variable p */
				create table rpm.irf&anr.e&anr.t4 as
				select distinct a.*, b.p
				from  rpm.irf&anr.e&anr.t4 as a
				left join noyau.varsup_&anref. (keep= ident&anr. noi p) as b on a.ident&anr.=b.ident&anr. and a.noi=b.noi ;
				/* On ajoute la variable dep */
				create table rpm.mrf&anr.e&anr.t4 as
				select distinct  a.*, b.dep
				from  rpm.mrf&anr.e&anr.t4 as a
				left join noyau.varsup_&anref. (keep= ident&anr. dep) as b on a.ident&anr.=b.ident&anr. ;
				/* On ajoute les variables logt, loyer et loyerfict */
				create table rpm.menage&anr. as
				select distinct a.*, b.logt, b.loyer, b.loyerfict
				from  noyau.menage&anr. as a
				left join noyau.varsup_&anref. (keep= ident&anr. logt loyer loyerfict) as b on a.ident&anr.=b.ident&anr. ;
				quit;
			%end; /* fin casd = oui */
		%end; /* fin cas spécifique de 2013 */
	/*cas de retrolation : utilisation des tables rétropolées les plus récentes*/
	%if &anref.>=2012 and &anref.<=2014 and &noyau_uniquement.=oui %then %do;
		proc sql;
			create table rpm.menage&anr._pat14 as
			select *
			from noyau.menage&anr._pat14;
			quit;
		%end; /* fin cas retropolation */ 
	/*cas de retrolation 2012 */
	%if &anref.= 2012 and &noyau_uniquement.=oui %then %do;
		proc sql;
			create table rpm.menage&anr._retropole as
			select *
			from noyau.menage&anr._retropole;
			quit;
		proc sql;
			create table rpm.indivi&anr._retropole as
			select *
			from noyau.indivi&anr._retropole;
			quit;
		%end; /* fin cas retropolation */ 
	%end;
	%mend;

%adapt_ERFS_noyau_elargi;

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
