/********************************************************************************************/
/* 																						    */	
/*										macro_sortie 										*/
/*																							*/
/********************************************************************************************/
/* Programme regroupant les macros utilis�es pour les sorties de FPS 						*/		    							           	  
/*																							*/
/* PLAN : Liste des macros																	*/
/*																							*/	
/* I.   Masses_Effectifs_Obs : calcule les montants en masses et le nombre d'observation et */
/*		les effectifs (de montants non nuls) pour une liste de transferts (presta ou pr�l�v)*/ 
/*		donn�e																				*/													
/* II.  Moy_UC : calcule les moyennes par UC pour une liste de transferts donn�e			*/
/* III. Calcul de la contribution de chaque dispositif � la r�duction des in�galit�s : 		*/
/*		1. Gini : calcule le Gini ou le pseudo-Gini d'un dispositif							*/
/*		2. Decomposition_Gini : calcule la contribution de chaque dispositif � la r�duction */ 
/*		   des in�galit�s																	*/
/* IV.  Construction des courbes de pseudo-Lorenz : 										*/
/*		1. LORENZ																			*/
/*		2. tableau_lorenz																	*/
/* V.   Distribution : calcul de la distribution des niveaux de vie 						*/
/* VI.  Calcul du taux de pauvret� mon�taire												*/
/********************************************************************************************/

/****************************************/
/* I. Masses_Effectifs_Obs 				*/
/****************************************/
%Macro Masses_Effectifs_Obs(transfert=,tableentree=,tablesortie=,ponderation=wpela&anr2.,pondpresente=O,tablepond=base.menage&anr2.);
	/* Cette macro (remplace la macro Somme) agr�ge les observations, effectifs et masses d'une liste de transferts
		@TRANSFERT : une liste de transferts (presta ou imp�ts) contenus dans une m�me table
		@TABLEENTREE : table en entr�e (contenant les transferts list�s)
		@TABLESORTIE : table en sortie 
		@PONDERATION : pond�ration utilis�e. Par d�faut, c'est la variable de l'ERFS �largie de l'ann�e Anref+2 (wpela&anr2.)
		@PONDPRESENTE : remplir N si la variable de pond�ration n'est pas pr�sente dans la table en entr�e ; O par d�faut.	
		@TABLEPOND : table dans laquelle la macro ira alors chercher @PONDERATION */
	%if &pondpresente.=N %then %do;	/* on va chercher la variable de pond�ration dans la table indiqu�e */
		proc sort data=&tableentree.; by ident; run;
		data t; 
			merge &tableentree.(in=a) &tablepond.(keep=ident &ponderation.);
			by ident;
			if a;
			%do i=1 %to %sysfunc(countw(&transfert., ' '));
				if %scan(&transfert.,&i., ' ')=. then %scan(&transfert.,&i., ' ')=0;
				%end;
			run;
		%let t=t;
		%end;
	%else %do;
		data t; 
			set &tableentree.(in=a);
			%do i=1 %to %sysfunc(countw(&transfert., ' '));
				if %scan(&transfert.,&i., ' ')=. then %scan(&transfert.,&i., ' ')=0;
				%end;
			run;
		%end;
	data eff(keep=ident &ponderation. &transfert.); 
		set t;
		%do i=1 %to %sysfunc(countw(&transfert., ' '));
			%scan(&transfert.,&i., ' ')=(%scan(&transfert.,&i., ' ')>0);
			%end;
		run;
	proc means data=eff noprint;
		var &transfert.;
		output out=observ(drop=_type_ _freq_) sum=;
		run;
	proc means data=eff noprint;
		var &transfert.;
		freq &ponderation.;
		output out=eff(drop=_type_ _freq_) sum=;
		run;
	proc means data=t (keep=ident &ponderation. &transfert.) noprint;
		var &transfert.;
		freq &ponderation.;
		output out=masse(drop=_type_ _freq_) sum=;
		run;
	proc transpose data=observ out=obs(rename=(col1=obs));run;
	proc transpose data=eff out=effectif(rename=(col1=eff));run;
	proc transpose data=masse out=montant(rename=(col1=masse));run;
	proc sql;
		create table &tablesortie. as
		select montant._name_, masse, eff, obs 
		from montant as a, effectif as b, obs as c
		where a._name_=b._name_ and b._name_=c._name_ ;
		quit;
	proc delete data=observ eff masse; run;
	%Mend Masses_Effectifs_Obs;
     	
/****************************************/
/* II. Moy_UC 							*/
/****************************************/
%Macro Moy_UC(transfert=,tableentree=,tablesortie=,ponderation=poiind);
	/* Cette macro permet de calculer la moyenne par unit� de consommation d'une liste de transferts.
		@TRANSFERT : une liste de transferts (presta ou imp�ts) contenus dans une m�me table
		@TABLEENTREE : table contenant ces transferts
		@TABLESORTIE : table en sortie contenant les moyennes par UC
		@PONDERATION : Pond�ration utilis�e. Par d�faut, c'est la variable POIIND */
	/* Calcul des variables par UC */
	data t;
	set &tableentree.;
		array v &transfert.;
		do over v;
			v=v/uci;
			end;
		run;
	proc means data=t noprint;
		var &transfert.;
		weight &ponderation.;
		output out=moy(drop=_type_ _freq_) mean=;
		run;
	proc transpose data=moy out=&tableSortie.(rename=(col1=moyUC));run;
	proc delete data=moy; run;
	%Mend Moy_UC;


/*********************************************************************************************/
/* III. Calcul de la contribution de chaque dispositif � la r�duction des in�galit�          */
/*********************************************************************************************/

/* III.1. Gini */
%Macro Gini(data=,var=,pond=,crit=,pseudo=,out=_gini_);
	/* Calcule le Gini (ou le pseudo-Gini) d'un dispositif - prestation ou pr�l�vement et cr�e une MV globale @gini 
	avec la valeur du pseudo-Gini.
	@data : table des observations contenant au minimum @var
	@var : la variable qui sert � classer les individus (abscisse des courbes de Lorenz)
	@pond : variable de @data indiquant la pond�ration de chaque observation (optionnel)
	@crit : variable qualitative de @data pour calculer le Gini par cat�gories d'observations (optionnel)
			Par d�faut, le Gini est calcul� sur toutes les observations de @data.
	@pseudo : la variable de @data dont on veut calculer le pseudo-Gini (par exemple un transfert) (optionnel)
			Si elle n'est pas pr�cis�e, on calcule le Gini (et non le pseudo-Gini) de la variable @var. 
	@out : table de sortie, avec l'effectif concern�, la moyenne de la variable &pseudo. et le pseudo-Gini, pour chaque valeur de &crit. 
			Par d�faut, le fichier de sortie s'appelle _gini_. */

	/* La m�thode de calcul est fait au niveau micro, en cumulant la contribution de 
	chaque observation au Gini (et non en calculant la contribution de chaque quantile comme
	c'est parfois fait pour acc�l�rer le temps de calcul, au d�triment de la pr�cision de 
	l'estimation) */

	%global gini;
    proc sort data=&data. out=&out.(keep=&var. &pond. &pseudo. &crit.);
   	by &crit. &var.;
		run;
    %if &pseudo.= %then %let pseudo=&var.;
    %if &pond.= %then %let pond=1; %*pond doit absolument �tre entier !;
    data &out.(keep=&crit. effectif moyenne gini RankingVar VarName);
     	set &out. end=fin;
		by &crit. &var.;
		length varName RankingVar $20;
	    retain _eff 0 gini 0 _pond 0 _mass 0 _moy 0;
	    %if &crit. ne %then %do;
	    	if first.&crit. then do;
				_eff=0;
				_mass=0;
				gini=0;
				end;
	    	%end;
	    _mass=	_mass+&pond.*&pseudo.;
	    gini=	gini+&pond.*&pseudo.*(2*_eff+&pond.+1)/2;
		_eff=	_eff+&pond.;
	    %if &crit. ne %then %do; 
			if last.&crit. then do; 
			%end;
		    %else %do; 
			if fin then do; 
			%end;
			RankingVar="%upcase(&Var.)";
			varName="%upcase(&Pseudo.)";
		    gini=	2*gini/(_mass*_eff)-1-1/_eff;
			_moy=	_mass/_eff;
		    effectif=_eff;
			moyenne=_moy;
		    label 	effectif="Frequence" 
					moyenne	="Moyenne de &pseudo." 
					gini="Gini";
			call symputx('gini',gini,'G');
		    output;
			end;
		run;
	%MEND Gini;

/* III.2. Decomposition_Gini */
%Macro Decomposition_Gini(Formule,table,pond,outTable);
	/* Calcule la d�composition de Gini pour la r�duction des in�galit�s effectu�e par chaque transfert */
	/*	@formule : relation entre 2 revenus, par exemple "revdisp=revavred+cotred+contred_tout+impot_tot+th+af+pf+alog+minima"
		@table : table qui contient les observations et les variables de d�composition 
		@pond : nom de la variable de pond�ration 
		@outTable : nom de la table de sortie contenant la d�composition */
	/* Cette table de sortie contient pour chaque variable (revenu, prestation ou pr�l�vement) : 
		- gini : le pseudo-gini obtenu en classant les individus selon leur revenu avant redistribution 
		- prog : la progressivit� (indice de Kakwani) du dispositif 
		- poids : le poids de chaque dispositif dans le revenu apr�s redistribution 
		- effet : la variation de pseudo-Gini imputable � chaque dispositif (en points de pseudo-Gini) 
		- contrib : la variation des in�galit�s imputable � chaque dispositif (en % de la r�duction totale des in�galit�s) */

	%local positionEgal positionPlus positionMoins RevenuFinal RevenuInitial Liste VariableVide VariableToSplit;
	%let positionEgal=%sysfunc(find(&Formule.,=));
	%let positionPlus=%sysfunc(find(&Formule.,+));
	%let positionMoins=%sysfunc(find(&Formule.,-));
	%let RevenuFinal=%sysfunc(substrn(&Formule.,2,&positionEgal.-2));
	%let RevenuInitial=%sysfunc(substrn(&Formule.,&positionEgal.+1,&positionPlus.-&positionEgal.-1));
	%let Liste=%sysfunc(substrn(&Formule.,&positionPlus.+1,%length(&Formule.)-&positionPlus.-1));
	%let VariableVide=; /* Contiendra la liste des variables de &Liste. vides (traitement particulier) */
	%do i=1 %to %sysfunc(countw(&Liste.)); /* Liste de MV pour chaque variable de &Liste. ayant des valeurs positives et n�gatives (traitement particulier) */
		%let %scan(&Liste.,&i.)_tosplit=N;
		%end;

	/* Gestion des erreurs de syntaxe */
	%if &positionEgal.=0 or &positionPlus.=0 %then %do;
		%put "Erreur de syntaxe : la formule est en A=B+C+D+..., entre guillemets";
		%abort cancel;
		%end;
	%if &positionMoins. ne 0 %then %do;
		%put "Erreur de syntaxe : les termes n�gatifs doivent �tre cod�s n�gativement dans la variable elle-m�me";
		%abort cancel;
		%end;

	/* V�rification de la formule, de la pr�sence de toutes les variables, identification de variables vides */
	data _null_;
		set &table. end=fin;
		retain %do i=1 %to %sysfunc(countw(&Liste.)); c%scan(&Liste.,&i.) %end; 0;
		%do i=1 %to %sysfunc(countw(&Liste.));
			%if %sysfunc(findw("&VariableToSplit.","%scan(&Liste.,&i.)"))=0 %then %do;
				if (sign(round(%scan(&Liste.,&i.),0.01)) ne sign(round(c%scan(&Liste.,&i.),0.01)))
					and round(%scan(&Liste.,&i.),0.01) ne 0 and round(c%scan(&Liste.,&i.),0.01) ne 0 then do;
					call symput("%scan(&Liste.,&i.)_tosplit","O");
					end;
				%end;
			c%scan(&Liste.,&i.)=c%scan(&Liste.,&i.)+%scan(&Liste.,&i.);
			%end;
		verif=&RevenuFinal.-&RevenuInitial.-(&Liste.);
		if round(verif,1) ne 0 then do;
			put "Erreur de d�composition (variable manquante ou formule non v�rifi�e)";
			abort cancel;
			end;
		if fin then do;
			%do i=1 %to %sysfunc(countw(&Liste.)); 
				if round(c%scan(&Liste.,&i.),1)=0 then do;
					call symput("VariableVide","&VariableVide. %scan(&Liste.,&i.)");
					end;
				%end;
			end;
		run;

	/* Modification de la liste pour tenir compte des variables ayant � la fois des valeurs positives et n�gatives */
	%let liste_cp=&liste.; /* Ca ne fonctionne pas d'it�rer sur une MV qui est modifi�e dans la boucle */
	%do i=1 %to %sysfunc(countw(&Liste_cp.)); 
		%let Var=%scan(&Liste_cp.,&i.);
		%if &&&Var._tosplit.=O %then %do;
			%let liste=%sysfunc(tranwrd(&liste.,&Var.,&Var._pos+&Var._neg));
			%end;
		%end;

	/* Lorsqu'une (ou plusieurs) variable contient � la fois des valeurs positives et n�gatives, on la coupe en 2 */
	data &table._cp;
		set &table.;
		%do i=1 %to %sysfunc(countw(&Liste_cp.));
			%let Var=%scan(&Liste_cp.,&i.);
			%if &&&Var._tosplit.=O %then %do;
				&Var._pos=&Var.*(&Var.>0);
				&Var._neg=&Var.*(&Var.<0);
				%end;
			%end;
		run;

	/* Calcul du Gini de &RevenuInitial. et de tous les autres pseudo-Ginis : enregistrement des r�sultats dans res */
	proc sort data=&table._cp; by &RevenuInitial.; run;
	%gini(data=&table._cp, var=&RevenuInitial., pond=&pond., out=res)
	data gini_init(keep=gini_init varName RankingVar); 
		set res(rename=(gini=gini_init)); 
		run;
	%do i=1 %to %sysfunc(countw(&Liste.));
		%if %sysevalf(&VariableVide. ne ) %then %do; /* strip ne fonctionne pas sur une MV vide */
			%if %sysfunc(findw("%sysfunc(strip(&VariableVide.))","%scan(&liste.,&i.)"))=0 %then %do; /* Le calcul ne fonctionne pas si la variable est toujours 0 */
				%gini(data=&table._cp, var=&RevenuInitial., pseudo=%scan(&liste.,&i.), pond=&pond.);
				data res(keep=gini varName RankingVar); set res _gini_; run;
				%end;
			%end;
		%else %do;
			%gini(data=&table._cp, var=&RevenuInitial., pseudo=%scan(&liste.,&i.), pond=&pond.);
			data res(keep=gini varName RankingVar); set res _gini_; run;
			%end;
		%end;
	%gini(data=&table._cp, var=&RevenuInitial., pseudo=&RevenuFinal., pond=&pond.);
	data res(keep=gini varName RankingVar); set res _gini_; run;

	/* Calcul de la progressivit� de chaque transfert par diff�rence entre le pseudo-Gini et le Gini de &RevenuInitial. */
	data res(drop=gini_init); 
		if _N_=1 then set gini_init;
		set res;
		prog=gini-gini_init;
		n=_n_;
		if varName=upcase("&RevenuFinal.") then do; call symputx("prog_fin",prog,'G'); end;
		run;

	/* Calcul du poids de chaque transfert rapport� au &RevenuFinal. */
	proc sql;
		create table poids as
		select sum(&pond.*&RevenuInitial.)/sum(&pond.*&RevenuFinal.) as &RevenuInitial.
			%do i=1 %to %sysfunc(countw(&Liste.));
				,sum(&pond.*%scan(&liste.,&i.))/sum(&pond.*&RevenuFinal.) as %scan(&liste.,&i.)
				%end;,
				1 as &RevenuFinal.
		from &table._cp;
		quit;
	proc transpose data=poids out=poids(rename=(COL1=poids)) name=varName;
	data poids(drop=nbVarVide); 
		length varName $20; 
		retain nbVarVide 0;
		set poids; 
		varName=upcase(varName);
		n=_n_-nbVarVide;
		if poids=0 then nbVarVide=nbVarVide+1;
		run;

	/* Construction du tableau final avec la contribution de chaque transfert � la r�duction des in�galit�s */
	data &OutTable.(drop=n RankingVar); 
		merge poids res;
		by n varName;
		/*format poids contrib percentn10.1 gini prog best5. effet E9.;*/ /* permet une meilleure visualisation en Sas */
		if poids ne 0 then do;
			effet=	poids*prog/100;
			contrib=effet/&prog_fin.*100;
			end;
		label 	poids=	"Part du transfert dans &RevenuFinal."
				gini=	"Gini de &RevenuInitial. ou pseudo-Gini du transfert selon &RevenuInitial."
				prog=	"Progressivit� (diff�rence entre l'indice de pseudo-Gini et le Gini de &RevenuInitial.)"
				effet=	"Contribution � l'�volution des in�galit�s (sur l'indice de Gini)"
				contrib="Contribution � l'�volution des in�galit�s (en %)";
		run;
	%Mend Decomposition_Gini;


/*********************************************************************************************/
/* IV. Construction des courbes de pseudo-Lorenz								             */
/*********************************************************************************************/

/* IV.1. LORENZ */
%Macro LORENZ(data=,var=,pond=,where=,crit=,pseudo=,Out=);
	/* Macro pr�paratoire � la construction des courbes de Lorenz. Sera utilis�e dans la mcro tableau_lorenz qui suit.
	@data : table des observations contenant au minimum @var
	@var : la variable qui sert � classer les individus (abscisse des courbes de Lorenz)
	@pond : variable de @data indiquant la pond�ration de chaque observation (optionnel)
	@where : condition sur @var (ex : (&var.>0)) (optionnel)
	@crit : variable qualitative de @data pour construire la courbe de Lorenz par cat�gories d'observations (optionnel)
	@pseudo : la variable de @data dont on veut construire une pseudo-Lorenz (par exemple un transfert) (optionnel)
			Si elle n'est pas pr�cis�e, construction de la pseudo-Lorenz de la variable @var. 
	@out : table de sortie */

	/* LIBRINES : V�rifier la description de la macro et de ses param�tres */

	proc sort data=&data. 
         /*(where=((&var.>0)
         %if &where. ne %then %do;%str(&) &where. %end; ) )*/
	    out=&out.(keep=&var. &pond. &pseudo. &crit.);
	    by &crit. &var.;
	    %if &pseudo.= %then %do;
	    	%let pseudo=&var.;
	    %end;
	    %if &pond.= %then %do;
	    	%let pond=1;
	    %end;
		run;
	
	/* Cumuls sur les valeurs de &var. identiques
	   _freq=somme des pond  _mass=somme des valeurs pond�rees.
	   On r�cup�re dans _s le min, le max de &var. et les sommes des poids et de valeurs sur la strate */

	data &out.(keep=&crit. &var. _freq _mass)
	     _s(keep=&crit. _som _mtot _min _max);
		set &out. end=fin;
		by &crit. &var.;
		retain _freq _mass _mtot _som _min 0;
		%if &crit.= %then %do;
		if _n_=1 then _min=&var.;
		%end;
		%else %do;
		if first.&crit. then do;
			_min=&var.;
			_mtot=0;
			_som=0;end;
		%end;
		if first.&var. then do;
			_freq=0;
			_mass=0;
			end;
		_freq=sum(_freq,&pond.);
		_mass=sum(_mass,&pond.*&pseudo.);
		if last.&var. then do;
			_som=_som+_freq;
			_mtot=_mtot+_mass;
			output &out.;
			end;
		%if &crit.= %then %do;
		if fin then do;
		%end;
		%else %do;
		if last.&crit. then do;
		%end;
			_max=&var.;
			output _s;
			end;
		run;

	/* Calcul des centiles */
	data _s;
		set _s;
		array c c1-c100;
		n=100;
		_u=(_som+1)/n;
		n1=0;
		n2=n;
		do _i_=1 to n;
			c=int(_u*_i_);
			if c=0 then n1=_i_;
			end;
		do _i_=n to 1 by -1;
			if c=_som then n2=_i_;
			end;
		run;
	/* Calcul des centiles et des masses par centiles */
	/* complexe quand il faut interpoler */
	data &out.(keep=&crit. i d vcum tcum mas);
		array c(100) c1-c100;
		Retain pcum vcum vm i d mas ind;
		label 	i='Num�ro*du centile' 
				d='Valeur*du centile'
		      	mas='Masse*du centile' 
				vcum='Masse*cumul�e'
		     	tcum='Part*cumul�e';
		%if &crit.= %then %do;
			if _n_=1 then do;set _s;debut=1;end;else debut=0;
			set &out. end=fin;
			%end;
		%else %do;
			merge 	&out. 
					_s;
			by &crit.;
			debut=first.&crit.;
			fin=last.&crit.;
			%end;
		if debut then do;
		pcum=0;vcum=0;i=1;ind=0;mas=0;
		if n1>0 then do;
			d=_min;
			do i=1 to n1;
				output &out.;
				end;
			i=n1+1;
			end;
		end;

		if ind then do;
			d=((c(i)+1)-(_som+1)*(i/n))*vm+((_som+1)*(i/n)-c(i))*&var.;
			tcum=100*vcum/_mtot;
			mas=vcum-mas;
			output &out.;
			mas=vcum;
			i=i+1;
			ind=0;
			end;
		pcum=pcum+_freq;
		vcum=vcum+_mass;
		if pcum>c(i) then do;
			d=&var.;
			vm=vcum;
			vcum=vcum-(pcum-c(i))*(_mass/_freq);
			tcum=100*vcum/_mtot;
			mas=vcum-mas;
			output &out.;
			mas=vcum;
			vcum=vm;
			i=i+1;
			end;
		else if pcum=c(i) then do;vm=&var.;ind=1;end;

		if fin then do;
			tcum=100*vcum/_mtot;
			mas=vcum-mas;
		  	if n2<n then do;
				d=_max;
				do i=n2+1 to n;output &out.;end;
				end;
		  	else do;
				d=_max;
				output &out.;
				end;
			end;
		run;

	data &out.; 
		set &out.(keep=i tcum rename=(tcum=&pseudo.));
		label &pseudo.="&pseudo.";
		run;

	%Mend LORENZ;

/* IV.1. tableau_lorenz */
%Macro tableau_lorenz(liste,table,rankingVar,pond,outtable);
	/* Calcule les courbes de pseudo-Lorenz d'une s�rie de transferts en fonction d'une variable de classement.
	@liste : liste de variables dont on veut le pseudo-Lorenz
	@table : table qui contient les observations et les variables pour le pseudo-Lorenz
	@rankingVar : variable de classement des individus sur l'axe des abscisses
	@pond : nom de la variable de pond�ration 
	@outTable : nom de la table de sortie contenant les pseudo-Lorenz */

	%do i=1 %to %sysfunc(countw(&Liste.)); 
		%lorenz(data=&table.,
				var=&rankingVar.,
				pond=&pond.,
				crit=,
				pseudo=%scan(&liste.,&i.),
				out=%scan(&liste.,&i.));
		%end; 
	data &outtable.;
		merge &liste.;
		by i;
		run;
	%Mend tableau_lorenz;

/****************************************/
/* V. Distribution						*/
/****************************************/
%Macro distribution(variable,pas,table,ponderation);
	/* Cette macro calcule la distribution des niveaux de vie.
	@variable : variable dont on calcule la distribution
	@pas : 
	@table : table d'entr�e contenant @variable
	@ponderation : variable de ponderation */

/* LIBRINES : v�rification de la description des param�tres. &pas. = UC ou autre concept pour calculer le niveau de vie ? */

	data distribution (keep=niv &ponderation.); 
		set &table. (keep=&ponderation. &variable.);
		niv=int(&variable./&pas.);
		run;
	proc sort data=distribution; by niv; run; 
	proc means data=distribution sum noprint;
		class niv;
		var &ponderation.;
		output out=distribution_&variable.(drop=_type_ _freq_) sum=&variable.;
		run;
	%Mend distribution;

/****************************************/
/* VI. Pauvret�							*/
/****************************************/
%Macro Pauvrete(table,revdisp,seuil,sortie);
	/* Cette macro calcule le taux de pauvret� mon�taire 
	@table : table d'entr�e contenant a minima @revdisp	
	@revdisp : concept de revenu (disponible) � partir duquel on calcule le taux de pauvret�
	@seuil : seuil de pauvret�. En g�n�ral, 60 % donc sera 0.6
	@sortie : table de sortie du r�sultat */

	proc means data=&table. median;
		var &revdisp.; 
		weight poidind; 
		output out=med(drop=_type_ _freq_) median=mediane;
		run;
	proc transpose data=med out=med; run;
   	data _null_;
      	set med;
	  	call symput(_NAME_,col1);
		run;
	data &table.;
		set &table.;
		seuil=%sysevalf(&seuil.*&mediane.);
		pv=(&revdisp.<seuil);
		run;
	proc means data=&table. mean;
		var pv;
		weight poidind;
		output out=&sortie. (drop=_type_ _freq_) mean=taux;
		run;
	%Mend Pauvrete;


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
