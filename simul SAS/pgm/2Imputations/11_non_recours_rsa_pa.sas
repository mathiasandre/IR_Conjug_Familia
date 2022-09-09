
/*******			  						********
	*****	*****	*****	*****	*****	*****	
		**		**		**		**		**		**

	      TIRAGE DU RECOURS AU RSA ACTIVITE ET A LA PRIME DACTIVITE

   **	   **	   **	   **	   **	   **		
	*****	*****	*****	*****	*****	*****
	  ********		 						 ********/

/* 
En entrée :	tables modele.basersa, modele.basepa
En sortie : table imput.recours_rsa_pa contenant les identifiants RSA et PA et la variable Recours_rsa_pa


PLAN du programme

	0 :	 Texte des macros de tirage des bénéficiaires du RSA activité
	I.	 Tirage du recours pour le T1
	II.	 Tirage du recours pour le T2
	III. Tirage du recours pour le T3
	IV.	 Tirage du recours pour le T4
	V. 	 Sauvegarde dans la table Imput.recours_rsa_pa

HYPOTHESES
	- on tire un nombre de foyers chaque trimestre parmi deux sous populations : éligibles ou non au RSA socle
	- les éligibles au RSA socle non recourants au RSA activité ne recourront pas au socle (pgm application non recours)
	- chaque trimestre, sont considérés d'office comme bénéficiaires du RSA activité les foyers éligibles
		au RSA activité déjà tirés un trimestre précédent (quel que soit leur statut via-à-vis du RSA socle)
	- pour les foyers à tirer, la probabilité d'être désigné augmente avec le montant de rsa activité 
*/

/* changement à partir du figé 2016 : 
- avant leg 2015, les montants de rsa activité sont dans la variable de PA pour faire le tirage (l'ancien rsaact_eli est pa_eli) et RSA socle dans RSA
- en leg 2016 et après, seules les variables de prime d'activité interviennent
*/

/* Note : on fait ici un tirage pour tous les foyer PA, sans tenir compte du foyer RSA auquel ils appartiennent. 
	On pourra donc trouver, au sein d'un même foyer RSA, des recourants et des non-recourants à la PA.
	Si on veut que tous les foyers PA appartenant à un même foyer RSA aient le même comportement de recours,
	il faudrait garder, comme dans la version précédente, un seul foyer PA pour le tirage (celui ayant le plus fort montant de PA éligible),
	mais il faudrait aussi multiplier sa pondération en fonction du nombre de PAC exclues (pour tomber sur les bonnes cibles)  */


proc sort data=modele.basersa ; by ident_rsa ; run;
proc sort data=modele.basepa ; by ident_rsa ident_pa; run; 

/* On crée la table au sein de laquelle on va tirer, en renommant les variables de rsa activité comme les variables de prime d'activité
pour anleg < 2016 afin d'avoir un code unique quelque soit l'année de législation considérée */
%macro table_tirage;
	%if &anleg.< 2016 %then %do;
		data rsa_pa;
			set modele.basersa (rename=(rsaact_eli1=pa_eli1 rsaact_eli2=pa_eli2 rsaact_eli3=pa_eli3 rsaact_eli4=pa_eli4));
			%do i=1 %to 4;	m_rsa&i.= m_rsa_socle&i.; %end;
			ident_pa=ident_rsa ;
		run;
	%end;

	%if &anleg.>= 2016 %then %do;
	  	data rsa_pa;
			merge 	modele.basersa (in=a keep = ident ident_rsa m_rsa1-m_rsa4 rsa_noel)
					modele.basepa (in=b keep=ident_rsa ident_pa pa_eli: nbpac_exclues pac_exclue wpela&anr2.) ;
			by ident_rsa ;
			if b ;
			/* Mise à zéro des valeurs manquantes pour les foyers de moins de 25 ans qui ne sont pas dans Basersa */
			array num _numeric_; do over num; if num=. then num=0; end;
		run;
	%end;
%mend table_tirage;
%table_tirage ;

proc sort data=rsa_pa nodupkey ; by ident_rsa ident_pa; run;
/* TO DO : voir d'où vient le doublon dans modele.basersa */


/****************************************************************************************
0 : Texte de la macro de tirage des bénéficiaires du RSA activité selon qu'il soient :	
	- éligibles au RSA socle le même trimestre
	- non éligibles au socle le même trimestre 
*****************************************************************************************/

/* Paramètres de la macro %tirage :
- table : table au sein de laquelle on fait le tirage
- nb_a_atteindre: effectif restant à tirer : les effectifs constatés par trimestre donnés par la Cnaf pour la 1ere étape, 
puis ce même chiffre diminué du nombre de personnes tirées au fur et à mesure du tirage 
- trimestre : on fait un tirage par trimestre, en gardant inchangé le comportement de recours pour les éligibles deux trimestres consécutifs
- quel_rsa : détermine si on tire des éligibles à la prime d'activité seule ou à la prime d'activité et au RSA */

%macro tirage(table,nb_a_atteindre,trimestre,quel_rsa);

/* Si on a atteint le nombre à atteindre à 10 000 près on arrête le tirage 
(le rôle des tables &quel_rsa.t&trimestre et surplus_&quel_rsa.t&trimestre est expliqué plus loin)*/
	%if %sysfunc(round(%sysevalf(&nb_a_atteindre./10000),1))=0 %then %do;
		data &quel_rsa.t&trimestre.;
			set _null_; 
			ident_rsa='';
			ident_pa='' ;
			ident='';
			run ;

		data surplus_&quel_rsa.t&trimestre.; 
			set _null_; 
			ident_rsa='';
			ident_pa='';
			ident='';
			run;
		%end;
/* Sinon, on crée une table avec les éligibles à la PA */
	%else %do;
		data base;
			set &table.;
			if pa_eli&trimestre.>0;
			benef=(pa_eli&trimestre.>0);
		run;
/* Dans le cas où on tire les éligibles à la PA seule, on enlève les observations éligibles au RSA socle */
		%if &quel_rsa.=act_seul %then %do;
			data base;
				set base;
				if m_rsa&trimestre.>0 then delete;
			%end;
/* Dans le cas où on tire les éligibles à la PA et au RSA, on enlève ceux qui ont un RSA nul */
		%if &quel_rsa.=deux_rsa %then %do;
			data base;
				set base;
				if m_rsa&trimestre.=0 then delete;
			%end;
		%end;

	/* On traite ici le cas où nb_a_atteindre est négatif : cela arrive par exemple si il y a plus de personnes tirés au trimestre t-1 et éligibles au trimestre t 
		(qui sont donc tirés automatiquement au trimestre t) que de personnes à tirer au trimestre t */
	%if %sysfunc(round(%sysevalf(&nb_a_atteindre./10000),1))<0 %then %do;

		data trop;
			set base;
			alea=ranuni(1);
		run;
		proc sort data=trop; by alea; run;
	/* Dans ce cas, on alimente la table surplus qui contient le nombre de personnes ayant fait dépasser le nombre à atteindre, choisis aléatoirement */
		data surplus_&quel_rsa.t&trimestre. (keep=ident_rsa ident_pa ident benefi); 
			set trop;
			retain benefi 0;
			benefi=benefi+wpela&anr2.;
			if benefi > %sysevalf(-(&nb_a_atteindre.)) then delete;
		run;
		proc sort data=surplus_&quel_rsa.t&trimestre.; by ident_rsa ident_pa ; run;

		/* on crée une table de bénéficiaires tirés vide pour qu'elle existe */
		data &quel_rsa.t&trimestre.; 
			set _null_; 
			ident_rsa=''; ident_pa=''; ident='';
		run; 
		
		%end;

	/* Cas où le nb est positif : cas "classique" du tirage */
	%if %sysfunc(round(%sysevalf(&nb_a_atteindre./10000),1))>0 %then %do;  

		/*Exclusion des personnes ayant déja recouru dans l'année puisqu'ils seront tirés d'office ensuite*/
		%if &trimestre.>1 %then %do;
			data base; 
				merge 	base (in=a)
						rsa (keep=ident_rsa ident_pa recours_rsa_pa);
				by ident_rsa ident_pa;
				if a;
				if count(recours_rsa_pa,'1')>0 then delete; 
			run;
		%end;
		
		/* On récupère le montant maximum de RSA activité observé qui nous permettra de calibrer le tirage en fonction du montant espéré */
		%global max_&trimestre. ;
		proc sql noprint;
			select max(pa_eli&trimestre.) into: max_&trimestre.  from base;
		quit;

		/* On récupère le poids moyen des foyers dans base, pour déterminer le nombre 
		d'observations à tirer pour obtenir environ 10 000 foyers RSA */
		%global poids_moy ;
			proc sql noprint;
				select mean(wpela&anr2.) into: poids_moy from base;
		quit;
		/* Comme la méthode du poids moyen n'assure pas de tirer le nombre de personnes nécessaires, on crée arbitrairement
		une borne inférieure et une borne supérieure entre lesquelles on va faire varier le tirage jusqu'à réussir à atteindre l'effectif voulu
		Ces bornes donnent le nombre d'observations à tirer pour tirer 10000 bénéficiaires (en pondéré) */
		%let borninf = %sysevalf(10000/(%sysevalf(&poids_moy.,floor)+40),floor);
		%let bornsup = %sysevalf(10000/(%sysevalf(&poids_moy.,floor)-40),floor); 
		/* On calcule la proba d'être tirée comme le rapport entre le montant du droit à la prime d'activité sur la valeur maximale observée */
		data base;
			set base;
			proba=pa_eli&trimestre./ &&max_&trimestre.;
		run;
		proc sort data=base; by ident_rsa ident_pa; run;

		data tirage;set base;run;
		option nonotes; 
		/* j correspond au nombre de "paquets" de 10000 personnes nécessaires pour atteindre l'effectif voulu */
		%do j=1 %to %sysfunc(round(%sysevalf(&nb_a_atteindre./10000),1));
		/* diff_min donne la différence minime entre le nb de personnes tirés et la cible de tirage à partir de laquelle on peut arrêter le tirage */
			%let diff_min=10000;

			data in; set tirage; run;
		/* On fait une boucle sur i entre nos deux bornes pour réaliser des tirages en tirant i personnes, 
			et on sélectionne le meilleur tirage (celui qui donne le diff_min le plus petit) */	 
			%do i=%eval(&borninf.) %to %eval(&bornsup.) %by 1;
			/* La proc surveyselect tire directement le nombre d'observations demandé (ici la valeur de &i.) 
			en fonction de la proba proposée (ici le rapport du montant de la pa sur la pa maximale) */
				proc surveyselect data=in out=echantillon method=pps_sys seed=5 ranuni n=&i noprint;
				size proba; 
				run;
				proc means data=echantillon noprint; var wpela&anr2.; output out=sum sum=sum;
				data _null_; set sum; call symput('diff',compress(round(abs(10000-sum)))); run;
				%if &diff.<&diff_min. %then %do;
					%let i_min=&i; %let diff_min=&diff;
					/* échantillon&j. est créée à partir de la table échantillon générée par le &i. donnant le meilleur tirage */
					data echantillon&j.; set echantillon; run;
				%end;
				%put i=&i diff=&diff diff_min=&diff_min;
			%end;
		/* Fin de la boucle sur i */
			proc sort data=tirage; by ident_rsa ident_pa;
			proc sort data=echantillon&j.; by ident_rsa ident_pa;
			data tirage; 
				merge tirage echantillon&j.(in=z keep=ident_rsa ident_pa); 
				by ident_rsa ident_pa; 
				if not z;
			run;
		%end;
		/* Fin de la boucle sur j : la table tirage a été alimentée par tous les échantillons&j. */
		option notes;
		/* la table quel_rsa est alimentée par les observations tirées précédemment */
		data &quel_rsa.t&trimestre.(keep=ident_rsa ident_pa ident wpela&anr2.);
			set %do j=1 %to %sysfunc(round(%sysevalf(&nb_a_atteindre./10000),1)); echantillon&j. %end;;
		run;
		proc sort nodupkey; by ident_rsa ident_pa ; run;

		/* complément par tirage aléatoire pour atteindre la cible le cas échéant */
		proc means data= &quel_rsa.t&trimestre. noprint;
			var wpela&anr2.; 
			output out=sum sum=sum;

		data _null_; set sum; call symput('manque',(round(&nb_a_atteindre.-sum))); run;
		%put &manque.;
		%if &manque.>0 %then %do;

			data reste (keep=ident_rsa ident_pa ident wpela&anr2. alea);
				merge	base 
						&quel_rsa.t&trimestre.(in=a);
				by ident_rsa ident_pa ;
				if not a;
				alea=ranuni(1);
			run;

			proc sort data=reste; by alea; run;

			data reste_&quel_rsa.t&trimestre.; 
				set reste;
				retain benefi 0;
				benefi=benefi+wpela&anr2.;
				if benefi > &manque. then delete;
			run;

			proc sort data=reste_&quel_rsa.t&trimestre.; by ident_rsa ident_pa; run;

			data &quel_rsa.t&trimestre.;
				merge	&quel_rsa.t&trimestre. 
						reste_&quel_rsa.t&trimestre.;
				by ident_rsa ident_pa;
			run;
		%end;

		/* on crée une table de bénéficiaires en trop vide pour qu'elle existe*/
		data surplus_&quel_rsa.t&trimestre.; 
			set _null_; 
			ident_rsa=''; ident_pa=''; ident='';
		run;
	%end;
	option notes;
%mend tirage;
/* Fin de la macro tirage : cette macro va maintenant être utilisée dans la macro Tirage_NR_Trim qui réalise le tirage 
pour chaque trimestre en ajustant le nombre à tiorer en fonction du tirage des trimestres précédents */

%macro Tirage_NR_Trim;

	/*******************************************************
	 I. TIRAGE DU RECOURS AU T1
	*******************************************************/

/* Pour le T1, on fait directement le tirage pour les deux types de population éligible */
	%tirage(rsa_pa,&eff_act_seul_t1.,1,act_seul); run;
	%tirage(rsa_pa,&eff_deux_rsa_t1.,1,deux_rsa); run;


	/* Création et alimentation de la table rsa */
	data rsa (keep=ident_rsa ident_pa ident m_rsa1-m_rsa4 pa_eli1-pa_eli4 rsa_noel recours_rsa_pa wpela&anr2.);
		merge	rsa_pa(in=e) 
				act_seult1 (in=a)
				deux_rsat1 (in=b) ; 
		by ident_rsa ident_pa;
		if e;
		recours_rsa_pa='0000';
		if a ! b then recours_rsa_pa='1000';
		run;

	/*******************************************************
	 II. TIRAGE DU RECOURS AU T2
	*******************************************************/

	/* décompte des bénéficiaires d'office au t2 */
	proc means data=rsa;
		var wpela&anr2.;
		where (pa_eli2>0 & m_rsa2=0 & count(recours_rsa_pa,'1')) ;
		output out=tas2(drop=_type_ _freq_) sum=benas2; 
		run;

	proc means data=rsa;
		var wpela&anr2.;
		where (pa_eli2>0 & m_rsa2>0 & count(recours_rsa_pa,'1')) ;
		output out=tdr2(drop=_type_ _freq_) sum=bendr2; 
		run;

	/* décompte par soustraction du nombre de bénéficiaires restant à tirer */
	data _null_;
		if 0 then set tas2 nobs=NbObs;
		if NbObs=0 then do; call symputx("atireras2",&eff_act_seul_t2.);end;
		else do; set tas2; call symputx("atireras2",(round(&eff_act_seul_t2.-benas2))); end;
		stop;
		run;
	%put  &atireras2;

	%tirage(rsa_pa,&atireras2.,2,act_seul); run;

	data _null_;
		if 0 then set tdr2 nobs=NbObs;
		if NbObs=0 then do; call symputx("atirerdr2",&eff_deux_rsa_t2.);end;
		else do; set tdr2; call symputx("atirerdr2",(round(&eff_deux_rsa_t2.-bendr2))); end;
		stop;
		run;
	%put  &atirerdr2;

	%tirage(rsa_pa,&atirerdr2.,2,deux_rsa); run;


	/* alimentation de la table rsa */
	data rsa ; 
		merge 	rsa(in=e) 
				act_seult2 (in=a)
				deux_rsat2 (in=b)  
				surplus_act_seult2 (in=c)
				surplus_deux_rsat2 (in=d) ;
		by ident_rsa ident_pa;
		if e;
		if a ! b ! (pa_eli2>0 & count(recours_rsa_pa,'1')) then recours_rsa_pa=substr(recours_rsa_pa,1,1)||'100';
		if c ! d then recours_rsa_pa=substr(recours_rsa_pa,1,1)||'000';
		run;


	/*******************************************************
	 III. TIRAGE DU RECOURS AU T3
	*******************************************************/

	/* décompte des bénéficiaires d'office au t3 */
	proc means data=rsa;
		var wpela&anr2.;
		where (pa_eli3>0 & m_rsa3=0 & count(recours_rsa_pa,'1')) ;
		output out=tas3(drop=_type_ _freq_) sum=benas3; 
		run;

	proc means data=rsa;
		var wpela&anr2.;
		where (pa_eli3>0 & m_rsa3>0 & count(recours_rsa_pa,'1')) ;
		output out=tdr3(drop=_type_ _freq_) sum=bendr3; 
		run;

	/* décompte par soustraction du nombre de bénéficiaires restant à tirer */
	data _null_;
		if 0 then set tas3 nobs=NbObs;
		if NbObs=0 then do; call symputx("atireras3",&eff_act_seul_t3.);end;
		else do; set tas3; call symputx("atireras3",(round(&eff_act_seul_t3.-benas3))); end;
		stop;
		run;
	%put  &atireras3;

	%tirage(rsa_pa,&atireras3.,3,act_seul); run;

	data _null_;
		if 0 then set tdr3 nobs=NbObs;
		if NbObs=0 then do; call symputx("atirerdr3",&eff_deux_rsa_t3.);end;
		else do; set tdr3; call symputx("atirerdr3",(round(&eff_deux_rsa_t3.-bendr3))); end;
		stop;
		run;
	%put  &atirerdr3;


	%tirage(rsa_pa,&atirerdr3.,3,deux_rsa); run;


	/* alimentation de la table rsa */
	data rsa ; 
		merge 	rsa(in=e) 
				act_seult3 (in=a)
				deux_rsat3 (in=b) 
				surplus_act_seult3 (in=c)
				surplus_deux_rsat3 (in=d) ; 
		by ident_rsa ident_pa;
		if e;
		if a ! b ! (pa_eli3>0 & count(recours_rsa_pa,'1')) then recours_rsa_pa=substr(recours_rsa_pa,1,2)||'10';
		if c ! d then recours_rsa_pa=substr(recours_rsa_pa,1,2)||'00';
		run;


	/*******************************************************
	 IV. TIRAGE DU RECOURS AU T4
	*******************************************************/

	/* décompte des bénéficiaires d'office au t4 */
	proc means data=rsa;
		var wpela&anr2.;
		where (pa_eli4>0 & m_rsa4=0 & count(recours_rsa_pa,'1'));
		output out=tas4(drop=_type_ _freq_) sum=benas4; 
		run;

	proc means data=rsa;
		var wpela&anr2.;
		where (pa_eli4>0 & m_rsa4>0 & count(recours_rsa_pa,'1'));
		output out=tdr4(drop=_type_ _freq_) sum=bendr4; 
		run;

	/* décompte par soustraction du nombre de bénéficiaires restant à tirer */
	data _null_;
		if 0 then set tas4 nobs=NbObs;
		if NbObs=0 then do; call symputx("atireras4",&eff_act_seul_t4.);end;
		else do; set tas4; call symputx("atireras4",(round(&eff_act_seul_t4.-benas4))); end;
		stop;
		run;
	%put  &atireras4;

	%tirage(rsa_pa,&atireras4.,4,act_seul); run;

	data _null_;
		if 0 then set tdr4 nobs=NbObs;
		if NbObs=0 then do; call symputx("atirerdr4",&eff_deux_rsa_t4.);end;
		else do; set tdr4; call symputx("atirerdr4",(round(&eff_deux_rsa_t4.-bendr4))); end;
		stop;
		run;
	%put  &atirerdr4;

	%tirage(rsa_pa,&atirerdr4.,4,deux_rsa); run;


	/* alimentation de la table rsa */
	data rsa ; 
		merge 	rsa(in=e) 
				act_seult4 (in=a)
				deux_rsat4 (in=b) 
				surplus_act_seult4 (in=c)
				surplus_deux_rsat4 (in=d) ; 
		by ident_rsa ident_pa;
		if e;
		if a ! b ! (pa_eli4>0 & count(recours_rsa_pa,'1')) then recours_rsa_pa=substr(recours_rsa_pa,1,3)||'1';
		if c ! d then recours_rsa_pa=substr(recours_rsa_pa,1,3)||'0';
		run;


	/*******************************************************
	 V. Sauvegarde dans la table Imput.recours_rsa_pa
	*******************************************************/

	data imput.recours_rsa_pa;
		merge	rsa_pa (in=a keep=ident_rsa ident_pa)	
				rsa (keep= ident_rsa ident_pa recours_rsa_pa);
		by ident_rsa ident_pa;
		if a;
	run;

	proc datasets lib=work
		memtype=DATA;
		delete echantillon:;
		quit;

%mend Tirage_NR_Trim;

%Tirage_NR_Trim;


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
