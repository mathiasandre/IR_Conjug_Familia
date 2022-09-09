/****************************************************************************************/
/*               				application_imputation_hsup							    */		
/*																						*/
/*						- Modele d'imputation des heures suppl�mentaires -				 	*/
/*																						 	*/
/********************************************************************************************/
/* Imputation des heures suppl�mentaires sur l'ann�e &anref � partir des tables de       	*/
/* coefficients issues du programme 03a_modele_imputation_hsup.sas                          */
/* Les r�mun�rations d'heures suppl�mentaires dans la table travail.foyer&anr contenues     */ 
/* dans les variables _hsupVous, _hsupConj, et _hsupPac1 sont maintenant imput�es.          */
/* Ces variables correspondaient aux cases _1au, _1bu et _1cu qui ne sont plus renseign�es  */
/* depuis l'ERFS 2013 ; pour les ERFS ant�rieurs � 2013, on conserve les r�mun�rations    	*/
/* d�clar�es dans les variables _hsupVous_d, _hsupConj_d, et _hsupPac1_d                 	*/
/********************************************************************************************/
/* En entr�e : 	dossier.model1_hsup � imput.model4_hsup                             		*/
/*				dossier.outest_hsup															*/
/*				dossier.distrib_hsup														*/
/*																							*/
/* En sortie : 	imput.hsup_ind&anr.                             							*/
/*				travail.foyer&anr.															*/
/*																						 	*/
/********************************************************************************************/


/*** 1�re �tape : Equation de participation aux heures suppl�mentaires ***/

%prepa_tables;

proc logistic inmodel=dossier.model1_hsup(type=logismod); score data=montants_hsup1 out=pred_hsup1(rename=(P_1=phat)); run;
proc logistic inmodel=dossier.model2_hsup(type=logismod); score data=montants_hsup2 out=pred_hsup2(rename=(P_1=phat)); run;
proc logistic inmodel=dossier.model3_hsup(type=logismod); score data=montants_hsup3 out=pred_hsup3(rename=(P_1=phat)); run;
proc logistic inmodel=dossier.model4_hsup(type=logismod); score data=montants_hsup4 out=pred_hsup4(rename=(P_1=phat)); run;

%participation;

data pred_hsup&anr.;   /* on rassemble les estimations faites sur les 4 sous-population sexe X (prive/public) */
	set pred_hsup1 pred_hsup2 pred_hsup3 pred_hsup4;
run;


/*** 2eme �tape : Estimation de la r�mun�ration li�e � l'exercice d'heures suppl�mentaires ***/

%prepa_regression;

proc score data=pred_hsup&anr. score=dossier.outest_hsup(rename=(zsali11=zsali&anr.)) type=parms predict out=Pred&anr.;
   var zsali&anr. sexe_n age1 age2 age3 taille_entrep1-taille_entrep5 TPPRED_n nafg017n1 nafg017n5 nafg017n8 nafg017n11 nafg017n13;
run;

data pred&anr.;
	set pred&anr.; 
	hsup_estim=exp(model1)*estim;
	run;

/* Distribution et classes estim�es d'hsup */
data pred_hsup_estim&anr.; 
	set pred&anr.; 
	if estim=1; 
	run;
proc univariate data=pred_hsup_estim&anr. noprint; var hsup_estim; output out=distrib_hsup_estim&anr. pctlpts=10 to 90 by 10 95 99 pctlpre=Cle; run;
data pred_hsup_estim&anr.; 
	set pred_hsup_estim&anr.; 
	if _n_=1 then set distrib_hsup_estim&anr.;
	Classe_estim=1*(hsup_estim<Cle10)+ 2*(Cle10<=hsup_estim<Cle20)+3*(Cle20<=hsup_estim<Cle30)+4*(Cle30<=hsup_estim<Cle40)+5*(Cle40<=hsup_estim<Cle50)+
	6*(Cle50<=hsup_estim<Cle60)+7*(Cle60<=hsup_estim<Cle70)+8*(Cle70<=hsup_estim<Cle80)+9*(Cle80<=hsup_estim<Cle90)+10*(Cle90<=hsup_estim<Cle95)
	+11*(Cle95<=hsup_estim<Cle99)+12*(Cle99<=hsup_estim);
	run;

/* Estimation finale de la r�mun�ration li�e � l'exercice d'heures suppl�mentaires pour ceux qui en font */

%macro evol_2011_anref;  /* Macro donnant l'�volution des salaires � appliquer entre 2011 et &anref.*/
	%let evol=1;
	%if &anr.>11 %then %do;
		%do k=12 %to &anr. ;
		%let p=%eval(&k.-1);
		%CreeMacrovarAPartirTable(tx_sal_&k.,Dossier.Param_derive,valeur_ERFS_20&p.,nom,txsal_an0_an1);
		%let evol=%sysevalf(&evol.*(1+&&tx_sal_&k.)) ;
		%end;
	%end;
	%if &anr.<11 %then %do;
		%CreeMacrovarAPartirTable(tx_sal_10,Dossier.Param_derive,valeur_ERFS_2010,nom,txsal_an0_an1);
		%let evol=%sysevalf(&evol./(1+&&tx_sal_10)) ;
		%if &anr.<10 %then %do;
			%do k=&anr. %to 9 ;
			%CreeMacrovarAPartirTable(tx_sal_&k.,Dossier.Param_derive,valeur_ERFS_200&k.,nom,txsal_an0_an1);
			%let evol=%sysevalf(&evol./(1+&&tx_sal_&k.)) ;
			%end;
		%end;
	%end;
%mend evol_2011_anref;
%evol_2011_anref;

data pred_hsup_estim&anr.; 
	set pred_hsup_estim&anr.; 
	if _n_=1 then set dossier.distrib_hsup;

	hsup_classe=(classe_estim=1)*hsup1+(classe_estim=2)*hsup2+(classe_estim=3)*hsup3+(classe_estim=4)*hsup4+
	(classe_estim=5)*hsup5+(classe_estim=6)*hsup6+(classe_estim=7)*hsup7+(classe_estim=8)*hsup8+
	(classe_estim=9)*hsup9+(classe_estim=10)*hsup10+(classe_estim=11)*hsup11+(classe_estim=12)*hsup12;

	hsup_final=1/classe_estim*hsup_estim+(1-1/classe_estim)*hsup_classe*&evol. ;
	run;


/* Ajout dans les tables pred&anr. et hsup_ind&anr. des estimations finales de montant d'hsup (variable hsup_final) */

proc sort data=pred&anr.; by ident noi; run;
proc sort data=pred_hsup_estim&anr.; by ident noi; run;
data pred&anr.;
	merge  pred&anr.(in=a) 
		   pred_hsup_estim&anr.(keep=ident noi hsup_final) ; 
	by ident noi; 
	if a;
	run;
data pred&anr.; 
	set pred&anr.; 
	if hsup_final=. then hsup_final=0;
	run;

proc sort data=hsup_ind&anr.; by ident noi; run;
proc sort data=pred&anr.; by ident noi; run;
data hsup_ind&anr.; 
	merge hsup_ind&anr.(in=a) 
		  pred&anr.(keep=ident noi hsup_final) ;
	by ident noi ; 
	if a; 
	run;


/* Il reste � traiter les cas o� l'imputation n'est pas r�alis�e (stat2 manquant notamment) */


	/* Cas d'individus n'effectuant pas d'heures suppl�mentaires (en observ�) */
data hsup_ind&anr.; 
	set hsup_ind&anr.;
	if stat2="1" and champ_revact=1 then hsup_final=0; 
	if champ_revact=0 then hsup_final=0; 
	if stat2="" and (AG_n>65 or AG_n<20 or persfip="pac" or adfdap ne &anref.) then hsup_final=0;
	run;
	/* Pour les quelques cas restants, on leur affecte la r�mun�ration moyenne de leur csp d�taill� en 2 positions  */
proc means data=hsup_ind&anr.(where=(hsup_final ne .)) noprint ;
	class cstot;
	var hsup_final;
	output out=cstot_hsup(where=(cstot ne "") keep=cstot moyenne) mean=moyenne;
	quit;
data hsup_ind&anr._manquant(keep=ident noi cstot hsup_final) ;
	set hsup_ind&anr.;
	where hsup_final=. ;
	run;

proc sort data=hsup_ind&anr._manquant; by cstot; run; 

data hsup_ind&anr._manquant(drop=cstot moyenne); 
	merge hsup_ind&anr._manquant cstot_hsup;
	by cstot;
	hsup_final=moyenne;
	run;

proc sort data=hsup_ind&anr._manquant ;
	by ident noi;
	run;

data hsup_ind&anr. ;
	merge hsup_ind&anr.(in=a) hsup_ind&anr._manquant;
	by ident noi;
	if a;
	run;

/* Sauvegarde de l'imputation au niveau individuel */
data imput.hsup_ind&anr.(keep=ident noi hsup&anr. hsup_final rename=(hsup&anr.= hsup_declare hsup_final=hsup_impute)); 
	set hsup_ind&anr. ; 
	run;


/* Ajout de l'imputation des heures suppl�mentaires dans la table travail.foyer&anr. */

proc sql;
	create table hsup_ind&anr.
	as select *,
		  sum(hsup_final*(persfip="vous")) as _hsupVous_i,
		  sum(hsup_final*(persfip="conj")) as _hsupConj_i,
		  sum(hsup_final*(persfip="pac")) as _hsupPac1_i
	from hsup_ind&anr. group by declar1 ; 
quit;

proc sort data=travail.foyer&anr. ; by declar; run;
proc sort data=hsup_ind&anr.(keep=declar1 _hsupVous_i _hsupConj_i _hsupPac1_i  rename=(declar1=declar)) nodupkey out=hsup_declar&anr.; by declar ; run;
data travail.foyer&anr. ;
	merge travail.foyer&anr.(in=a) hsup_declar&anr. ; 
	by declar; 
	if a;
	run;

data travail.foyer&anr.(drop=_hsupVous_i _hsupConj_i _hsupPac1_i) ; 
	set travail.foyer&anr.; 
	_hsupVous_d=_hsupVous ; _hsupConj_d=_hsupConj ; _hsupPac1_d=_hsupPac1 ; /* les montants d'hsup d�clar�s dans l'ERFS */
	_hsupVous=_hsupVous_i ; _hsupConj=_hsupConj_i ;_hsupPac1=_hsupPac1_i ;  /* les montants d'hsup imput�s et utilis�s dans la suite par Ines */
	run;
proc sort data=travail.foyer&anr.; by declar; run;

proc datasets mt=data library=work kill;run;quit;   


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

