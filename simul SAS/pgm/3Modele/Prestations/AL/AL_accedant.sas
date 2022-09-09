/****************************************************************/
/*																*/
/*					AL_accedant									*/
/*								 								*/
/****************************************************************/

/****************************************************************/
/* Allocations logement pour les accédants à la propriété		*/
/* En entrée : base.baserev										*/ 
/*			   rpm.menage&anr.					               	*/
/*			   base.menage&anr2.				               	*/
/*			   travail.mrf&anr.e&anr.			               	*/
/*			   cd.extrait_th					               	*/
/*			   dossier.typocomm					               	*/
/* En sortie : base.menage&anr2.                               	*/
/*			   imput.accedant					               	*/
/****************************************************************/

/* Ce programme impute des allocations logement aux accédants à */
/* la propriétés pour les extensions entrantes et sortantes de 	*/
/* l'échantillon élargi à partir des observations faites sur le */
/* noyau et de la cible externe CNAF. Pas besoin d'imputation 
   pour le noyau car les imputations sont déja faites.			*/

/****************************************************************/
/* PLAN :														*/
/* I. Préparation de la table avec toutes les informations		*/ 
/* II. Imputation Hot-deck à partir du noyau					*/ 
/* III. Calage par rapport au nombre de bénéficiaires			*/ 
/****************************************************************/

/* REMARQUES : 													*/
/* - ce programme impute et ne simule pas sur barème 			*/
/* - on appelle la macro simul qui a un problème avec le para-	*/
/* mètre sigma 													*/
/****************************************************************/

%Macro ALAccedant;
	%if &accedant_prem.=oui %then %do;
	
	%if &noyau_uniquement.=non %then %do;
		options nocenter ls=max ps=max  nodate nonumber;

		/****************************************************************/
		/* I. Préparation de la table avec toutes les informations		*/ 
		/****************************************************************/
		proc sql;
			create table res_men as
				select ident,
				sum(sum(zsali&anr.,zchoi&anr.,zrsti&anr.,zpii&anr.,zalri&anr.,zrtoi&anr.,zragi&anr.,zrici&anr.,zrnci&anr.)) as revmen&anr.
				from base.baserev
				group by ident;
			quit;
		proc sort data=cd.extrait_th(keep=ident&anr. surftot dc datepers rename=(ident&anr.=ident)) out=th; by ident; run;
		data proprietaire; /* Concaténation des différentes sources */
			merge 	rpm.menage&anr.(keep=ident&anr. logtm rename=(ident&anr.=ident) in=a)
					base.menage&anr2.(keep=ident nb_UCI TUU2010 wpela&anr2. in=b)
					travail.mrf&anr.e&anr.(keep=ident aai logt surftot typmen7 dep AGPRM sexeprm nbenfc 
						rename=(surftot=surftot_mrf))
					travail.irf&anr.e&anr.(keep=ident nbpi)
					th
					res_men; 
			by ident;
			if a then source='Noyau'; else source='Extension';
			if logt in ('1','2'); /* on ne sélectionne que les propriétaires */
			if source='Noyau' then alpos=(logtm>0);
			if alpos=1 then logAl=log(logtm);
			revuc=revmen&anr./nb_UCI;
			run;

		proc univariate data=proprietaire noprint; /* Calcul de décile de niveau de vie */
			freq wpela&anr2.; 
			var revuc;
			output out=decile pctlpts=10 to 90 by 10 pctlpre=revuc pctlname=D1-D10;
			run;

		data proprietaire(drop=revucD1-revucD9); /* Mise en forme des variables */
			set proprietaire;
			if _N_=1 then set decile;

			/* Tranches de niveau de vie */
			if revuc<=revucD1 then x_ressuc='Inférieur au D1';
			else if revucD1<revuc<=revucD2 then x_ressuc='D1-D2';
			else if revucD2<revuc<=revucD3 then x_ressuc='D2-D3';
			else if revucD3<revuc<=revucD4 then x_ressuc='D3-D4';
			else if revucD4<revuc<=revucD6 then x_ressuc='D4-D6';
			else if revucD6<revuc<=revucD8 then x_ressuc='D6-D8';
			else if revuc>revucD8 then x_ressuc='Supérieur au D8';

			/* statut d'occupation du logement */
			accedant=(logt='1');

			/* age quinquennal*/
			if input(agprm,3.)<25 then x_agq='Moins de 25 ans' ;
			else if input(agprm,3.)<30 then x_agq='25-29 ans';
			else if input(agprm,3.)<35 then x_agq='30-34 ans';
			else if input(agprm,3.)<40 then x_agq='35-39 ans';
			else if input(agprm,3.)<45 then x_agq='40-44 ans';
			else if input(agprm,3.)<50 then x_agq='45-49 ans';
			else if input(agprm,3.)<55 then x_agq='50-54 ans';
			else if input(agprm,3.)<60 then x_agq='55-59 ans';
			else if input(agprm,3.)<65 then x_agq='60-64 ans';
			else if input(agprm,3.)<70 then x_agq='65-69 ans';
			else if input(agprm,3.)<75 then x_agq='70-74 ans';
			else if input(agprm,3.)<80 then x_agq='75-79 ans';
			else if input(agprm,3.)>79 then x_agq='Plus de 80 ans';

			/* tranche d'unité urbaine */
			if TUU2010 in ('1','2','3') then x_zone='Moins de 20 000 hab';
			else if TUU2010 in ('4','5') then x_zone='De 20 000 à 100 000 hab';
			else if TUU2010='6' then x_zone='De 100 000 à 100 000 hab';
			else if TUU2010='7' then x_zone='Plus de 200 000';
			else if TUU2010='8' then x_zone='Agglomération parisienne';
			else x_zone='Rural';
	
			/* zone climatique */
			if dep in ('2A','2B','06','07','11','13','26','30','34','66','83','84') then x_climat='1';
			else if dep in ('17','31','32','33','40','46','47','64','82','85') then x_climat='2';
			else if dep in ('16','22','24','29','35','44','50','56','79') then x_climat='3';
			else if dep in ('14','23','36','37','49','53','61','62','72','76','80','86','87') then x_climat='4';
			else if dep in ('03','10','18','21','27','28','41','45','58','59','60','69','71','75','77','78','89','91','92','93','94','95') then x_climat='5';
			else if dep in ('01','02','08','25','39','51','52','54','55','57','67','68','70','90') then x_climat='6';
			else if dep in ('04','05','09','12','15','19','38','42','43','48','63','65','73','74','81','88') then x_climat='7';

		   /* nombre de pièces dans le logement */
			if input(nbpi,2.)>5 then x_nbp='5';
			else x_nbp=substr(nbpi,2,1);

			/* type de ménage*/
			if typmen7='1' and sexeprm='1' then x_tymen='Homme seul';
			else if typmen7='1' and sexeprm='2' then x_tymen='Femme seule';
			else if typmen7='3' or (typmen7='4' and nbenfc=0) then x_tymen='Couple sans enfant';
			else if typmen7='4' and nbenfc=1 then x_tymen='Couple avec 1 enfant';
			else if typmen7='4' and nbenfc=2 then x_tymen='Couple avec 2 enfants';
			else if typmen7='4' and nbenfc>2 then x_tymen='Couple avec au moins 3 enfants';
			else if typmen7='2' then x_tymen='Famille monoparentale';
			else if typmen7 in ('5','6','9') then x_tymen='Ménage complexe';

			/* ancienneté dans le logement*/
			if datepers ne '' then do;
			if datepers>="%eval(&anref.-1)" then x_anc='Moins de 1 an';
			else if "%eval(&anref.-4)"=<datepers<"%eval(&anref.-1)" then x_anc='De 1 à 3 ans';
			else if "%eval(&anref.-8)"=<datepers<"%eval(&anref.-4)" then x_anc='De 4 à 7 ans';
			else if "%eval(&anref.-12)"=<datepers<"%eval(&anref.-8)" then x_anc='De 8 à 11 ans';
			else x_anc='Plus de 12 ans';
			end;

			/* Surface : si manquant, on s'appuie sur SURFRP et à défaut, on prend la médiane par TYPMEN7 */
			if surftot=. then surftot=surftot_mrf;
			if surftot=0 then surftot=(typmen7='1')*61+(typmen7='2')*75+(typmen7='3')*86+(typmen7='4')*91+(typmen7 in ('5','6','9'))*82;
			lnsurf=log(surftot);
			run; 

		/*Typologie tabard*/
		proc sort data=dossier.typocomm(keep=dc typcom27) out=typocomm; by dc; run; /*DC=dep!!com*/
		proc sort data=proprietaire; by dc; run;
		data proprietaire;
			merge 	proprietaire(in=a)
					typocomm(rename=(typcom27=x_typo));
			by dc;
			if a;
			run;

		/****************************************************************/
		/* II. Imputation Hot-deck à partir du noyau					*/ 
		/****************************************************************/
		/*Pour imputer on utilise un modèle TOBIT généralisé*/
		proc qlim data=proprietaire method=quanew noprint;
			nloptions maxiter=500;
			class x_agq x_ressuc x_tymen x_anc accedant aai x_nbp x_zone x_climat x_typo;
			model alpos=x_agq x_ressuc x_tymen x_anc accedant lnSurf aai x_nbp x_zone x_climat x_typo /discrete;
			model logAl=x_agq x_ressuc x_tymen x_anc accedant lnSurf aai x_nbp	x_zone x_climat x_typo /select(alpos=1);
			output out=sortieqlim xbeta conditional errstd expected predicted prob proball residual;
			run;

		/* Résidus simulés */
		%simul(	variable=logAl,
				tableinput=sortieqlim(rename=(ErrStd_logAl=sigma)),
				tableoutput=sortieqlim2,
				varpred=xbeta_logal,
				model=lin,
				nbimput=10,
				methode=3,
				strate=x_ressuc x_agq x_anc);

		data sortieqlim2;
			set sortieqlim2;
			probal=0;
			ALaccedant=0;
			if source='Noyau' then do;
				probal=alpos;
				ALaccedant=logtm;
				end;
			else do;
				probal=Prob2_alpos;
				ALaccedant =exp(Xbeta_logAl+sigma*sigma/2);/* Cet estimateur est non biaisé */
				end;
			run;

		/****************************************************************/
		/* III. Calage par rapport au nombre de bénéficiaires			*/ 
		/****************************************************************/
		/* La macrovariable nbAllocatairesALacc contient le nb de bénéficiaires AL accession d'après la CNAF 
			pour &anleg. */
		proc sort data=sortieqlim2; by descending probal; run;
		data imput.accedant(keep=ident ALaccedant where=(ALaccedant>0));
			set sortieqlim2;
			retain poids 0;
			poids=sum(poids,wpela&anr2.);
			if poids<&nbAllocatairesALacc. then do;
				alverse=1;
				ALaccedant=round(ALaccedant,1);
				end;
			else do;
				alverse=0;
				ALaccedant=0;
				end;	
			label ALaccedant="Allocation logement accedant";
			run;
		%end;

	/* ERFS noyau : alimentation de la table imput.accedant avec les montants de la table rpm sans se soucier des cibles por l'instant	*/
	%else %do;
		data imput.accedant (keep= ident alaccedant);
			merge	rpm.menage&anr.(keep=ident&anr. logtm rename=(ident&anr.=ident) in=a)
					travail.mrf&anr.e&anr.(keep=ident logt);
			by ident;
			if a;
			if logt=1 & logtm>0;
			Alaccedant=logtm;
			label ALaccedant="Allocation logement accedant";
			run;
		%end;
	%end;

	/* Etape finale : on fusionne base.menage&anr2. et imput.accedant pour n'utiliser que base.menage&anr2. par la suite, que l'on crée imput.accedant pour la 1ere fois ou non */
	proc sort data=imput.accedant; by ident; run;
	proc sort data=base.menage&anr2.; by ident; run;
	data base.menage&anr2.;
		merge 	base.menage&anr2.(in=a) 
				imput.accedant;
		by ident;
		if alaccedant=. then ALaccedant=0;
		run;
	%Mend ALAccedant;

%ALAccedant;


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
