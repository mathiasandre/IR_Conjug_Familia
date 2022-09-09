/************************************************************************************************************/
/*                             																				*/
/*    									0_initialisation_ERFS  												*/
/*                             																				*/
/************************************************************************************************************/
/*																											*/	
/* Ce programme s'ex�cute uniquement lors de la 1�re utilisation d'Ines pour un mill�sime donn� d'ERFS 		*/ 
/*																											*/
/* A partir des tables source de l'ERFS, rang�es dans des nouveaux r�pertoires noyau et elargi, ce programme*/
/* cr�e toutes les tables utiles pour Ines dans les r�pertoires habituels RPM et CD :						*/
/*	- pour les tables propres � chaque type d'�chantillon, qui n'ont pas d'�quivalent dans l'autre, il 		*/
/*	  effectue une copie simple																				*/
/*	- pour les tables qui ont un �quivalent dans l'autre �chantillon :										*/
/*		- lorsque seule la table de l'�largi existe, c'est elle qu'il copie dans RPM (les observations 		*/
/*		  des extensions sont conserv�es et c'est inutile, mais non probl�matique si les utilisations		*/
/*		  ult�rieures des tables sont faites gr�ce � des fusions contr�l�es)								*/
/*		- lorsque des variables sont manquantes dans l'une des tables, il l'enrichit avec celles de l'autre */
/*	- Apr�s 2013, l'�largi n'est plus disponible, donc on fait une copie simple vers RPM 					*/
/*																											*/	
/* CASD : pour 2012 et 2013, les tables incluant les variables suppl�mentaires (varsup_2012 et varsup_2013) */
/* ou les observations suppl�mentaires des individus FIP (indfip2012_ela et indfip2013) doivent �tre rang�es*/ 
/* dans les r�pertoires noyau. 																				*/ 
/*																											*/		
/* Fonctionnement � partir de 6 listing (dont un sp�cifique pour apr�s 2013 quand l'�largi n'est plus		*/	 
/* disponible et un sp�cifique pour le CASD) des tables de l'�chantillon noyau et de l'�chantillon �largi 	*/ 
/* selon qu'elles aient ou non un �quivalent dans l'autre �chantillon. Pour les tables ayant un �quivalent, */ 
/* les tables sont compar�es 2 � 2 entre le noyau et l'�largi en fonction de leur position dans la liste.	*/
/*																											*/
/* NB : Les tables non utilis�es par Ines sont en commentaire pour ne pas surchargerles r�pertoires CD et RPM*/
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
	Extrait_th; /*table menage trait� sp�cifiquement en 2013 � cause de variables suppl�mentaires*/

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
/*I. Avant 2013, on g�re le noyau et l'�largi */
	%if &anref.<2013 %then %do;
		%if &casd. = non %then %do;
			/* 1. Gestion des tables noyau et �largi ayant un �quivalent dans l'autre �chantillon */
			%let l=1;
			%do %while(%scan(&liste_tables_noyau_equi.,&l)> );
				/*la condition while pourrait aussi s'appliquer � la liste &liste_tables_elargi mais il faut bien en choisir 1 des 2,
				l'essentiel est le nb �gal de tables dans les 2*/
				%let table_n=%scan(&liste_tables_noyau_equi.,&l);
				%let table_e=%scan(&liste_tables_elargi_equi.,&l);
				/* gestion de l'identifiant � utiliser selon les tables et les types de proc�dure (sql ou data) */
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

				/* 1A. Lorsque les tables dans leur format noyau n'existent pas dans le r�pertoire noyau (mrf indfip)
				on copie leur �quivalent �largi dans cd et dans rpm */
				%if %sysfunc(exist(noyau.&table_n.))=0 %then %do;
					%put &table_n. n existe pas dans le noyau on copie celle de l elargi;
					data rpm.&table_n.; set elargi.&table_e.; run;
					data cd.&table_e.; set elargi.&table_e.; run;
					%end;

				/* 1B. Lorsque les tables existent on en v�rifie le contenu et les enrichit le cas �ch�ant
				avec les variables de l'autre �chantillon */
				%else %do;
					/* cr�ation sous forme de table de la liste des variables des deux tables d'int�r�t */
					proc contents data=noyau.&table_n. out=var_noyau (keep=name) noprint; run;
					proc contents data=elargi.&table_e. out=var_elargi (keep=name) noprint; run;
					/* Probl�me de casse soulev� par le contents -> on met tous les noms de variable en majuscule */
					data var_noyau; set var_noyau; name=upcase(name); run;
					data var_elargi; set var_elargi; name=upcase(name); run;
					/* Cr�ation sous forme de table de deux listes de variables pr�sentes seulement dans un cas */
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
					/* on ajoute aux tables du noyau les variables de l'�largi non pr�sentes dans le noyau */
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
					/* on ajoute aux tables de l'�largi les variables du noyau non pr�sentes dans l'�largi */
					%ListeVariablesDUneTable(table=Noy_not_Ela_,mv=Liste_Noy_not_Ela,separateur='');
					%if &Liste_Noy_Not_Ela.= %then %do;
						proc sql;
							create table cd.&table_e. as select * from elargi.&table_e.;
							quit;
						%end;
					%else %do;
						/* une cr�ation par data pour utiliser Init_Valeur et ne conserver qu'une seule �tape */
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
			/* 2. Gestion des tables propres � chaque �chantillon : copie de noyau vers rpm et d'�largi vers cd */
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
			/* 3. rustine et ajouts tables retropol�s*/ 
			%if &anref.=2012 %then %do;
				/* Rustine : ajout aux tables compl�mentaires de 2013 de l'�largi 2012 la colonne manquante rdem (pr�sente dans le noyau) */
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
				/*ajouts tables retropol�es*/
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
			/* cas particulier CASD pour ERFS 2012 : pas d'acc�s � l'�largi et donc aux variables suppl�mentaires et aux individus fip */
			/* On copie simplement les tables de noyau � rpm, y compris la table avec les variables suppl�mentaires et indfip */	
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
				/* Tables variables suppl�mentaires + renommage indfip */
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

	/* II. Apr�s 2013, l'�largi n'est plus disponible, donc on fait une copie simple vers RPM et on traite les variables suppl�mentaires*/
	%if &anref.>=2014 %then %do; 
		%let m=1;
		%do %while(%scan(&liste_tables_noyau_post2013.,&m)> ); /* y compris la table suppl�mentaire indfip20&anr. */
			%let table_post13=%scan(&liste_tables_noyau_post2013.,&m);
	    	%let m=%eval(&m+1);
			proc sql;
				create table rpm.&table_post13. as
				select *
				from noyau.&table_post13.;
				quit;
			%end;
		%end; /* fin situation � partir de ERFS 2014 */

	/* Cas sp�cifique de l'ann�e 2013 : variables suppl�mentaires dans une table diff�rente dans le cadre du CASD */
	/*Utilisation de variables suppl�mentaires pour la table menage. ToDo : v�rifier que la table ait bien le m�me nom les prochaines ann�es*/
	%if &anref. = 2013 %then %do; 
		%let m=1;
		%do %while(%scan(&liste_tables_noyau_2013.,&m)> ); /* y compris la table suppl�mentaire indfip20&anr. mais sans la table menage*/
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
		%end; /* fin cas sp�cifique de 2013 */
	/*cas de retrolation : utilisation des tables r�tropol�es les plus r�centes*/
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
