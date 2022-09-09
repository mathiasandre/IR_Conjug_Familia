/****************************************************************************/
/*																			*/
/*					3_recup_infos_trim										*/
/*								 											*/
/****************************************************************************/

/****************************************************************************/
/* Construction de la table travail.infos_trim qui contient les informations sur 	*/
/* de l'EEC dont on a besoin, sur la plus grande période possible.			*/
/* En entrée : cd.is&anr_2.t4ela&anr.										*/ 
/*			   cd.is&anr_1.t1ela&anr.			  			             	*/
/*			   cd.is&anr_1.t2ela&anr.			   			            	*/
/*			   cd.is&anr_1.t3ela&anr.			   			            	*/
/*			   cd.is&anr_1.t4ela&anr.			   			            	*/
/*			   cd.irf&anr.e&anr.t1				   			            	*/
/*			   cd.irf&anr.e&anr.t2				   			            	*/
/*			   cd.irf&anr.e&anr.t3				   			            	*/
/*			   cd.irf&anr.e&anr.t4				   			            	*/
/*			   cd.irf&anr.e&anr1.t1				    			           	*/
/*			   cd.irf&anr.e&anr1.t2				 			              	*/
/*			   cd.irf&anr.e&anr1.t3							               	*/
/*			   cd.icompt1ela&anr.				    			           	*/
/*			   cd.icompt2ela&anr.				    			           	*/
/*			   rpm.icomprf&anr.e&anr_1.t3		     			          	*/
/*			   rpm.icomprf&anr.e&anr_1.t4		      			         	*/
/*			   rpm.icomprf&anr.e&anr.t1			    			           	*/
/*			   rpm.icomprf&anr.e&anr.t2			   			            	*/
/*			   rpm.icomprf&anr.e&anr.t3			   			            	*/
/*			   rpm.irf&anr.e&anr.t4				   			            	*/
/*			   rpm.icomprf&anr.e&anr1.t1		   			            	*/
/*			   rpm.icomprf&anr.e&anr1.t2		  			            	*/
/*			   rpm.icomprf&anr.e&anr1.t3		 			              	*/
/* En sortie : travail.infos_trim	                        			              	*/
/****************************************************************************/
/* REMARQUES :																*/
/* - 	On tient compte ici du fait de pouvoir faire tourner le modèle sur 	*/
/*		l'échantillon élargi ou sur le noyau seulement. Ce choix a des 		*/
/* 		conséquences sur le nombre de trimestres de l'EEC dont on dispose	*/
/* 		puisque les extensions sortantes en T1, T2 ou T3 de anref permettent*/
/*		de remonter plus loin dans le passé. 								*/
/* - 	L'EEC a subi de profondes modifications en 2013 qui ne sont pas 	*/
/* 		simplement des renommages de variables à quelques nuances près.		*/
/* 		Par exemple, on peut avoir besoin de plusieurs variables pour 		*/
/* 		sélectionner le même champ qu'auparavant, ce qui n'est pas simple 	*/
/* 		à gérer, et ce d'autant plus qu'on a plusieurs années d'EEC pour une*/
/* 		ERFS. Ceci est en particulier (mais pas uniquement) géré par les 	*/
/* 		macros en début de programme. 										*/
 /****************************************************************************/

/* Liste des variables de l'EEC dont on a besoin (en minuscules) et variables reconstruites pour tenir compte de
recodification faites dans l'EEC en 2013 (en majuscules). */
%let tout=datqi sp00 sp01 sp02 sp03 sp04 sp05 sp06 sp07 sp08 sp09 sp10 sp11 
acteu6 nondic txtppred TPENF amois adfdap ancentr ancinatm ancchomm
hhc emp2nbh emp3nbh empnbh TTRAVP etxtppb rabs duhab tpp tppred statut rgi rga dimtyp rdem
RETOUPRERET SOCCUPENF RECOITAAH RECOITASPA;

%let anr_1=%substr(%eval(&anref.-1),3,2);
%let anr_2=%substr(%eval(&anref.-2),3,2);
%let anr1=%substr(%eval(&anref.+1),3,2);

/* Liste de macros permettant de gérer les recodifications de l'EEC en 2013. */
%macro RETOUPRERET(year);
	/* A partir de l'EEC 2013, on n'a plus la variable retrai (retraité ou préretraité parmi les inactifs), mais ret (retraité d'un régime
et potentiellement encore actif) et preret (preretraité et potentiellement encore actif). On croise ces nouvelles variables avec actif=2 
pour ne garder que les inactifs et obtenir une nouvelle variable retoupreret qui vaut 1 pour les inactifs retraités ou préretraités */
	%if &year.<2013 %then %do;
		case when retrai in ('1') then '1' when retrai in ('2') then '2' when retrai in ('3') then '3' else '0' end
		%end;
	%else %if &year.>=2013 %then %do;
		case when (ret='1' and actif='2') then '1' when (preret='1' and actif='2') then '2' else '0' end
		%end;
	as RETOUPRERET
	%mend RETOUPRERET;

%macro SOCCUPENF(year);
	/* A partir de l'EEC 2013, la variable decr est éclatée en 2 variables : raisnrec (raison principale de la non recherche d'emploi)
et raisnsou (raison pour laquelle l'individu ne souhaite pas travailler actuellement). On repère l'ancienne modalité '3' de decr
(ne recherche pas d'emploi pour s'occuper d'un enfant ou dautre membre de sa famille) avec raisnrec='3' ou raisnsou='2'. 
On code cela dans une variable SOCCUPENF qui vaut 0 ou 1.*/
	%if &year.<2013 %then %do;
		case when decr='3' then '1' else '0' end
		%end;
	%else %if &year.>=2013 %then %do;
		case when (raisnrec='3' or raisnsou='2') then '1' else '0' end
		%end;
	as SOCCUPENF
	%mend SOCCUPENF;

%macro TPENF(year);
	/* A partir de l'EEC 2013, la variable raistp change de modalités. La variable raistf nouvellement créée regroupe toutes
les raisons personnelles de travailler à temps partiel, y compris pour s'occuper d'un enfant. raistp=4 est donc équivalent à raistf=2. 
On code cela dans une variable TPENF qui vaut 0 ou 1.*/
	%if &year.<2013 %then %do;
		case when raistp='4' then '1' else '0' end
		%end;
	%else %if &year.>=2013 %then %do;
		case when raistf='2' then '1' else '0' end
		%end;
	as TPENF
	%mend TPENF;

%macro TTRAVP(year);
	/* A partir de l'EEC 2013, la variable etpp voit le sens de ses modalités inversé. etpp = 1 signifie désormais temps plein un an
auparavant, alors que etpp = 1 jusqu'en 2012 signifie temps partiel.
On code cela dans une variable TTRAVP qui vaut 1 si la personne était à temps complet , 2 si elle était à temps partiel.*/
	%if &year.<2013 %then %do;
		case when etpp='2' then '1' when etpp='1' then '2' else '0' end
		%end;
	%else %if &year.>=2013 %then %do;
		case when etpp='1' then '1' when etpp='2' then '2' else '0' end
		%end;
	as TTRAVP
	%mend TTRAVP;


%macro RECOITAAH_RECOITASPA(year);
	%if &year.<2013 %then %do;
		case when index(rc1rev,'4')>0 then '1' else '0' end
		%end;
	%else %if &year.>=2013 %then %do;
		case when rc1revm4='1' then '1' when rc1revm4='0' then '0' else '' end
		%end;
	as RECOITAAH,
	%if &year.<2013 %then %do;
		case when index(rc1rev,'5')>0 then '1' else '0' end
		%end;
	%else %if &year.>=2013 %then %do;
		case when rc1revm5='1' then '1' when rc1revm5='0' then '0' else '' end
		%end;
	as RECOITASPA
	%mend RECOITAAH_RECOITASPA;

/* Macro permettant de sélectionner les tables de chaque trimestre (selon le trimestre, il y a une, deux ou trois tables à prendre). */
%macro CreateTrim(trim=,year=,options=,intable=,table_compl1=,table_compl2=);
	/* Les conditions sur @year sont liées aux recodifications de variables entre différentes années de l'EEC (en particulier 2013)*/
	%if &year.<2013 %then %do;
		%let options=%sysfunc(TRANWRD(&options.,datqi,datcoll)); /* datcoll est devenu datqi */
		%let options=%sysfunc(TRANWRD(&options.,raisnrec raisnsou,decr)); /* drec a disparu pour raisnrec et raisnsou */
		%let options=%sysfunc(TRANWRD(&options.,rc1revm4 rc1revm5,rc1rev)); /* rc1rev a été éclatée en pls variables. On garde rc1revm4 (AAH) et rc1revm5 (minv, Aspa, Asi). */
		%let options=%sysfunc(TRANWRD(&options.,etxtppb,etxpp)); /* etxpp a devenue etxtppb avec un champ légèrement plus large (pas uniquement les anciens salariés) */
		%let options=%sysfunc(TRANWRD(&options.,emp2nbh,hh2)); /* hh2 a disparu, le plus proche étant emp2nbh pour les 2e emplois réguliers et occasionnels pendant la semaine de référence */
		%let options=%sysfunc(TRANWRD(&options.,emp3nbh,hh3)); /* idem */
		%let options=%sysfunc(TRANWRD(&options.,txtppred,txtppb)); /* au lieu de txtppb, on utilise la nouvelle variable txtppred */
		%let options=%sysfunc(TRANWRD(&options.,RETOUPRERET,retrai)); /* retrai a disparue, mais on récupère retrai in (1,2) avec (preret=1 or ret=1) and actif=2 */
		%let options=%sysfunc(TRANWRD(&options.,SOCCUPENF,decr)); /* drec a disparu pour raisnrec et raisnsou */
		%let options=%sysfunc(TRANWRD(&options.,TPENF,raistp)); /* raistp =4 devient raistf=2 */
		%let options=%sysfunc(TRANWRD(&options.,TTRAVP,etpp)); /* etpp = 1 devient etpp=2 */
		%let options=%sysfunc(TRANWRD(&options.,RECOITAAH RECOITASPA,rc1rev));/* rc1rev a été éclatées en plusieurs variables */
		%end;
	%else %if &year.>=2013 %then %do;
		%let options=%sysfunc(TRANWRD(&options.,RETOUPRERET,ret preret actif));
		%let options=%sysfunc(TRANWRD(&options.,SOCCUPENF,raisnrec raisnsou)); /* drec a disparu pour raisnrec et raisnsou */
		%let options=%sysfunc(TRANWRD(&options.,TPENF,raistf)); /* raistp =4 devient raistf=2 */
		%let options=%sysfunc(TRANWRD(&options.,TTRAVP,etpp)); /* etpp = 1 devient etpp=2 */
		%let options=%sysfunc(TRANWRD(&options.,RECOITAAH RECOITASPA,rc1revm4 rc1revm5));/* rc1rev a été éclatées en plusieurs variables */
		%end;
	create table &trim.&year. 
			%if &year.<2013 %then %do;
				(rename=(datcoll=datqi etxpp=etxtppb hh2=emp2nbh hh3=emp3nbh txtppb=txtppred)) 
				%end;
		as select *,
			%RETOUPRERET(&year.),
			%SOCCUPENF(&year.), 
			%TPENF(&year.), 
			%TTRAVP(&year.), 
			%RECOITAAH_RECOITASPA(&year.) 
		from &intable.(&options.)
			%if %length(&table_compl1.)>0 %then %do;
				outer union corr select *, 
					%RETOUPRERET(&year.), 
					%SOCCUPENF(&year.), 
					%TPENF(&year.), 
					%TTRAVP(&year.), 
					%RECOITAAH_RECOITASPA(&year.) 
				from &table_compl1.(&options.)
				%end;
			%if %length(&table_compl2.)>0 %then %do;
				outer union corr select *,
					%RETOUPRERET(&year.), 
					%SOCCUPENF(&year.),
					%TPENF(&year.),
					%TTRAVP(&year.),
					%RECOITAAH_RECOITASPA(&year.) 
				from &table_compl2.(&options.)
				%end;
		order by ident&anr.,noi,rgi desc; /* le rgi desc sert à éliminer les doublons avec lequel on a des infos manquantes plus loin */
	%mend CreateTrim;

/* Création des tables de l'enquête emploi pour chaque trimestre*/
%macro table;

	/* On gère encore un effet collatéral de la refonte de l'EEC en 2013 : disparition de rdem. */
	%if &anref.>2012 %then %do;
		%let tout=%sysfunc(TRANWRD(&tout.,rdem,)); /* rdem n'existe plus dans l'EEC à partir de 2013 */
		%end;
	%local keep_list;
	%let keep_list=keep=ident&anr. noi &tout.;
	proc sql;
		%if &noyau_uniquement.=non %then %do;
			%CreateTrim(trim=T4,year=%eval(&anref.-2),options=&keep_list.,intable=cd.is&anr_2.t4ela&anr.);
			%CreateTrim(trim=T1,year=%eval(&anref.-1),options=&keep_list.,intable=cd.is&anr_1.t1ela&anr.);
			%CreateTrim(trim=T2,year=%eval(&anref.-1),options=&keep_list.,intable=cd.is&anr_1.t2ela&anr.);
			%CreateTrim(trim=T3,year=%eval(&anref.-1),options=&keep_list.,intable=rpm.icomprf&anr.e&anr_1.t3,table_compl1=cd.is&anr_1.t3ela&anr.);
			%CreateTrim(trim=T4,year=%eval(&anref.-1),options=&keep_list.,intable=rpm.icomprf&anr.e&anr_1.t4,table_compl1=cd.is&anr_1.t4ela&anr.);
			%CreateTrim(trim=T1,year=&anref.,options=&keep_list.,intable=rpm.icomprf&anr.e&anr.t1,table_compl1=cd.icompt1ela&anr.,table_compl2=cd.irf&anr.e&anr.t1);
			%CreateTrim(trim=T2,year=&anref.,options=&keep_list.,intable=rpm.icomprf&anr.e&anr.t2,table_compl1=cd.icompt2ela&anr.,table_compl2=cd.irf&anr.e&anr.t2);
			%CreateTrim(trim=T3,year=&anref.,options=&keep_list.,intable=rpm.icomprf&anr.e&anr.t3,table_compl1=cd.irf&anr.e&anr.t3);
			%CreateTrim(trim=T4,year=&anref.,options=&keep_list.,intable=cd.irf&anr.e&anr.t4);
			%CreateTrim(trim=T1,year=%eval(&anref.+1),options=&keep_list.,intable=rpm.icomprf&anr.e&anr1.t1,table_compl1=cd.irf&anr.e&anr1.t1);
			%CreateTrim(trim=T2,year=%eval(&anref.+1),options=&keep_list.,intable=rpm.icomprf&anr.e&anr1.t2,table_compl1=cd.irf&anr.e&anr1.t2);
			%CreateTrim(trim=T3,year=%eval(&anref.+1),options=&keep_list.,intable=rpm.icomprf&anr.e&anr1.t3,table_compl1=cd.irf&anr.e&anr1.t3);
			%end;
		%else %do;
			%CreateTrim(trim=T3,year=%eval(&anref.-1),options=&keep_list.,intable=rpm.icomprf&anr.e&anr_1.t3);
			%CreateTrim(trim=T4,year=%eval(&anref.-1),options=&keep_list.,intable=rpm.icomprf&anr.e&anr_1.t4);
			%CreateTrim(trim=T1,year=&anref.,options=&keep_list.,intable=rpm.icomprf&anr.e&anr.t1)
			%CreateTrim(trim=T2,year=&anref.,options=&keep_list.,intable=rpm.icomprf&anr.e&anr.t2)
			%CreateTrim(trim=T3,year=&anref.,options=&keep_list.,intable=rpm.icomprf&anr.e&anr.t3)
			%CreateTrim(trim=T4,year=&anref.,options=&keep_list.,intable=rpm.irf&anr.e&anr.t4);
			%CreateTrim(trim=T1,year=%eval(&anref.+1),options=&keep_list.,intable=rpm.icomprf&anr.e&anr1.t1);
			%CreateTrim(trim=T2,year=%eval(&anref.+1),options=&keep_list.,intable=rpm.icomprf&anr.e&anr1.t2);
			%CreateTrim(trim=T3,year=%eval(&anref.+1),options=&keep_list.,intable=rpm.icomprf&anr.e&anr1.t3);
			%end;
		quit;
	%mend table;
%table;

/* Elimination de doublons pour T3%eval(&anref.-1) et T4%eval(&anref.-1) */
proc sort data=T3%eval(&anref.-1) nodupkey; by ident&anr. noi; run;
proc sort data=T4%eval(&anref.-1) nodupkey; by ident&anr. noi; run;

/* Liste des trimestres d'interrogation que l'on récupère dans la construction des calendriers */
%macro liste_trim;
	%global liste_trim;
	%let liste_trim= 	T3%eval(&anref.-1) T4%eval(&anref.-1)
						T1&anref. T2&anref. T3&anref. T4&anref.
						T1%eval(&anref.+1) T2%eval(&anref.+1) T3%eval(&anref.+1); 
	%if &noyau_uniquement.=non %then %do; 
		%let liste_trim= T4%eval(&anref.-2) T1%eval(&anref.-1) T2%eval(&anref.-1) &liste_trim.;
		%end;
	%mend liste_trim;
%liste_trim;

%macro fusion;
	/* Concaténation de l'ensemble des tables-trimestres en renommant les variables pour avoir à chaque fois la valeur 
		à chacun des trimestre.*/

	%macro renameVarTrim(trim,year);
		/* Rajoute un suffixe à toutes les variables de la table &trim&year */
		rename=(%do i=1 %to %sysfunc(countw(&tout.)); %scan(&tout.,&i.)=%scan(&tout.,&i.)_&trim.&year. %end;)
		%mend renameVarTrim;

	data travail.infos_trim;
		format ident&anr. noi %do i=1 %to  %sysfunc(countw(&tout.));
			%do l=1 %to %sysfunc(countw(&liste_trim.));
				%scan(&tout.,&i.)_%scan(&liste_trim.,&l.)
				%end;
			%end;;
		merge 
		%if &noyau_uniquement.=non %then %do;
			T4%eval(&anref.-2) (%renameVarTrim(T4,%eval(&anref.-2)))
			T1%eval(&anref.-1) (%renameVarTrim(T1,%eval(&anref.-1)))
			T2%eval(&anref.-1) (%renameVarTrim(T2,%eval(&anref.-1)))
		%end;
		T3%eval(&anref.-1) (%renameVarTrim(T3,%eval(&anref.-1)))
		T4%eval(&anref.-1) (%renameVarTrim(T4,%eval(&anref.-1)))
		T1&anref. (%renameVarTrim(T1,&anref.))
		T2&anref. (%renameVarTrim(T2,&anref.))
		T3&anref. (%renameVarTrim(T3,&anref.))
		T4&anref. (%renameVarTrim(T4,&anref.))
		T1%eval(&anref.+1) (%renameVarTrim(T1,%eval(&anref.+1)))
		T2%eval(&anref.+1) (%renameVarTrim(T2,%eval(&anref.+1)))
		T3%eval(&anref.+1) (%renameVarTrim(T3,%eval(&anref.+1)));
		by ident&anr. noi;
		run;
	%mend fusion;
%fusion;


%macro calend(calend,element,place,nb_carac);
	/* Insère dans @calend la chaine de caractères @element à la position @place */
	/* @calend : une variable de calendrier */
	/* @element : une chaîne de caractères à insérer */
	/* @place : la position où l'on doit insérer @element, en commençant à compter à 1 */
	/* @nb_cara : le nombre de caractères de @element (ne fonctionne pas en automatique car l'element peut être manquant) */
	if &place.>=1 and &place.<=length(&calend.)-(&nb_carac.-1) then do;
		if &place.=1 then &calend.=&element.!!substr(&calend.,1+&nb_carac.,length(&calend.)-&nb_carac.);
		else if &place.=length(&calend.)-(&nb_carac.-1) then &calend.=substr(&calend.,1,length(&calend.)-&nb_carac.)!!&element.;
		else &calend.=substr(&calend.,1,&place.-1)!!&element.!!substr(&calend.,&place.+&nb_carac.,length(&calend.)-&place.-&nb_carac.+1);
		end;
	%mend calend;

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
