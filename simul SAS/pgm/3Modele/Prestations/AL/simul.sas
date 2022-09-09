/*******************************************************************************************
*************************** Macro pour des "résidus simulés" et variantes ******************
*******************************************************************************************/

/* version de mai 2007	*/

/***************** utiliser la macro simul après une estimation adhoc **********************/

/*******************************************************************************************
********************* Introduction et initialisation des macros variables ******************
*******************************************************************************************/

/* - variable 	*/
/* La variable à simuler &variable (ou y ) est une quantité numérique
/* positive dont on sait qu'elle 
est non nulle dans le cas d'un modèle loglinéaire.
On modélise y ou log y par la loi d'un modèle linéaire avec les covariables x. 
Les observations sont soit en tranches ou en fourchettes (les hauts et les bas dépendent de 
l'unité) soit en clair. Il convient de nommer les bas et les hauts de la forme &variable.min 
et &variable.max (si on ne les connait pas les mettre à .). 
Si le montant est renseigné en clair le bas est égal au haut, si le haut 
ou le bas ne sont pas renseignés leur valeur est . 
*/ 

/* tranche	*/
/* Si 0, non prise en compte de tranches même si &variable.min et &variable.max */
/* sont présentes				*/
/* Sinon, si l'une des deux variables est présente, prise en compte des tranches	*/


/* - tableinput	*/
/* Une fois le modèle estimé, la table &tableinput doit posséder les colonnes &varpred */
/* et pour les méthodes 1 et 2, la &sigma (écart-type des résidus).	*/


/* - def	*/
/* Nom de la variable indiquant si &variable a un sens défini 			*/
/* - varpred	*/
/* Nom de la variable indiquant la prédiction de y ou log y				*/
/* Par défaut, c'est xb													*/

/* - model	*/
/* si log (option par défaut) on a un modèle log-linéaire, sinon lin pour un modèle 
linéaire				*/

/* - sigma		*/
/* Nom de la variable contenant l'écart-type des résidus 			*/
/* que l'on va simuler (méthode 1 ou 2) par défaut, c'est sigma		*/									*/

/* - tableoutput	*/
/* la table de sortie	 */

/* - indicatrice	*/
/* nom de la variable indicatrice des imputations, si renseigné		*/

/* - nbimput		*/
/* C'est le nombre de simulations (&nbimput=1 si on ne fournit à chaque fois qu'une seule imputation)
remarque : l'idée est de produire une prédiction de l'estimateur de sondage de la quantité 
en population totale en faisant la moyenne des n statistiques obtenues sur chacun des jeux 
de données simulées */ 

/* - nbiter		*/
/* La simulation utilise une version de l'algorithme d'acceptation-rejet optimisée,
on indique ici le nombre d'itérations, en pratique peu d'itérations suffisent 
pour obtenir l'acceptation et l'arrêt de l'algorithme (5 peut suffir, normalement 20 suffit 
presque à coup sûr), si jamais pour un enregistrement il n'y a pas eu acceptation (faire en sorte 
que cela ne soit jamais le cas par exemple en mettant un nombre plus élevé d'itérations!) la valeur 
fabriquée est la prédiction (espérance dans la loi conditionnelle aux covariables et aux tranches)  
par un calcul numérique d'intégrale.*/
/*pour les méthodes 2 et 3 seulement, sinon mettre n'importe quoi par exemple 1)*/

/* - pred		*/
/* On peut choisir ici de faire une prédiction pour chaque enregistrement par moyenne 
conditionnelle en mettant &pred=1 (si on s'intéresse ex post à des statistiques linéaires en les observations
ex moyenne, total, dans certain cas la droite de régression, sinon les estimations sont biaisées!), 
alors deux variables sont ajoutées
1. &variable.predMC correspond, pour chaque unité répondant partiellement ou 
   non répondant pour lequel le montant est positif, à la moyenne des &nbimput simulations; /*
2. &variable.pred correspond à l'espérance conditionnelle pour la loi avec les paramètres estimés, 
   le calcul d'intégrale est standard. La variable &variable.predMC en est une estimation.   
Si on ne désire pas cette colonne on pose pred=0 */
/* Si le modèle est linéaire (model=lin), on retrouve à peu de chose près sur la prédiction */

/* La variable pb en sortie indique par unité simulée le nombre total de problèmes rencontrés */

/* - methode		*/
/* Nous pouvons choisir parmi trois méthodes : 
Les deux premières méthodes sont deux variantes de la même méthode,
il s'agit d'une simulation dans la loi du modèle linéaire Gaussien ,
éventuellement dans la loi tronquée lorsque une information en fourchette est disponible.
Avec la méthode 1 la simulation est obtenue en inversant la fonction de répartition à partir 
de la fonction de répartition de la loi normale et de la fonction quantile. 
C'est la méthode la plus rapide.

Cependant du fait des approximations numériques et en particulier lorque la fourchette
est loin de la moyenne de la loi non conditionnelle (non tronquée) il peut être préférable 
d'utiliser la méthode 2. La simulation de la loi tronquée est alors effectuée par 
acceptation-rejet. Il s'agit d'une variante par rapport à la macro "résidu simulé" cette fois
la probabilité d'acceptation est optimisée et peu d'itérations suffisent.

Dans la méthode 3 on ajoute à la moyenne du logarithme un résidu observé (peut être préférable 
dans certains cas car ne nécessite pas la spécification de la loi) un résidu observé.
Cette deuxième méthode nécessite que la plupart des réponses soient des réponses en clair 
afin de  pouvoir trouver un résidu observé qui satisfasse (acceptation-rejet) les contraintes 
issues de la fourchette. Attention toutefois le résidu est observé certe mais la valeur imputée
n'est pas une valeur observée.*/

/* - strate	*/
/* variable(s) stratifiante(s) pour le tirage des résidus dans la méthode 3	*/

/* - ppv		*/
/* Reste l'option Hot Deckisation des valeurs simulées que l'on peut utiliser avec les 3
méthodes précédentes :
elle revient à remplacer la valeur simulée par la valeur la plus proche satisfaisant 
la contrainte, poser alors ppv=1.
Attention dans la méthode 3 le résidu est un résidu observé par contre la valeur simulée 
n'est pas forcément une valeur observée*/

/* ! Dans la macro qui suit, si une variable explicative manque, on ne simule plus la 
variable mais on met la demie somme lorsque la fourchette est bornée, ou le minimum de la 
dernière tranche, ou la moyenne des observations chez les répondants, (on pourrait aussi 
faire la moyenne des observations de la fourchette...) !!!!!!!! 
Il est en tout cas préférable de mener à nouveau l'estimation d'un modèle où ne figurent 
pas les x qui manquent, estimé sur tout le monde. Alors figureraient pour ces ménages &varpred 
et le sigma correspondant */ 


/*******************************************************************************************
********************************** Le texte de la macro ************************************
*******************************************************************************************/

%MACRO simul(	tableinput=,
				tranche=1,
				variable=,
				def=,
				varpred=xb,
				model=log,
				tableoutput=,
				nbimput=1,
				nbiter=10,
				pred=0,
				methode=1,
				sigma=sigma,
				strate=,
				ppv=0);

	/* Détection de la présence des variables &variable.min 	*/
	/*			et &variable.max								*/
	/* &bracket vaut 1 ou 2 si elles sont présentes				*/
	proc contents data=&tableinput. out=_var(keep=name) noprint ;

	data _var;
		set _var; 
		min=0;
		max=0;
		sigma=0;
		if name="&variable.min" then min=1;
		else if name="&variable.max" then max=1;
		else if name="&sigma." then sigma=1;
		run;

	proc sql noprint ;
		select sum(max), sum(min), sum(sigma)
		into :max, :min, :pressigma
		from _var ;
		quit ;

	%let bracket=%eval((&max+&min)*&tranche) ;

	data _tab;
		set &tableinput;
		somme=0;
		pb=0;
		_num_=_n_ ;
	/* Si une seule borne est présente, on définit l'autre à missing	*/
	%if &bracket =1 %then 
	%do ;
		%if &min=0 %then 
		length &variable.min 8. ;
		%else 
		length &variable.max 8. ;
	%end ; ;
	/* Si pas de tranche à prendre à compte, 
	on met les bas et hauts de tranches à missing		*/
	%if &bracket = 0 %then %do ;
		attrib &variable.min &variable.max length=8. ; 
		&variable.min=. ;
		&variable.max=. ;
	%end ;
	/* Si pas de variable def définie, on prend tout le monde	*/
	%if %length(&def)=0 %then 
		%do ;
		%let def=_def_ ;
		_def_=1 ;
	%end ;
		if &def ne 1 then &def=0 ;

	/* Calcul des bas et hauts de tranches pour les résidus			*/
	%if &model=log %then %do ;
	/* pour un modèle log-linéaire	*/
	if ((&variable.min^=0)*(&variable.min^=.)*(&varpred^=.)>0) 
		then bas=(log(&variable.min)-&varpred)/sigma ;
		else bas=.;
	if ((&variable.max^=.)*(&varpred^=.)*(&variable.max^=0)>0) 
		then haut=(log(&variable.max)-&varpred)/sigma ;
		else haut=.;
	%end ;
	%else %do ;/* pour un modèle linéaire	*/
	if (&variable.min^=.)*(&varpred^=.)>0
		then bas=(&variable.min-&varpred)/sigma ;
		else bas=.;
	if ((&variable.max^=.)*(&varpred^=.)>0) 
		then haut=(&variable.max-&varpred)/sigma ;
		else haut=.;
	%end ;

	%if &strate ne %then %do ;
		proc sort data=_tab ;
			by &strate ;
	%end ;
	/* calcul de la moyenne sur les répondants */ 
	proc means data=_tab mean noprint;
		var &variable;
		weight &def;
		%if &strate ne %then 
		by &strate ;;
		output out=moy(keep=&variable.moy) mean=&variable.moy;

	/* On l'injecte dans la table			*/
	data _tab;
		set _tab;
		if _n_=1 then set moy;
	run;
	 
	%If &methode=1 %Then %do;
	/****************************************************************************************
	**** Simulation dans la loi tronquée par inversion de la fonction de répartition ********
	****************************************************************************************/
	data _tab;
		set _tab;
		if (&def=0) then do;
			%do j=1 %to &nbimput;
				&variable.imp&j=0;
			%end;
		end;
		else if (&def=1) then do;
		%do j=1 %to &nbimput;
		uni=ranuni(1);
		if haut= bas and bas^=. then do;
			sim=&variable.min;
		end;
	/* Si pas de valeur prédite, on fait la moyenne du bas et haut de tranche	*/
	/* ou moyenne des répondants												*/
		else if missing(&varpred) then do; 
				pb=pb+1;
				if &variable.min^=. and &variable.max^=. then 
				&variable.imp&j=(&variable.min+&variable.max)/2;
				else if (&variable.min^=.) then &variable.imp&j=&variable.min;
				else if (&variable.max^=.) then &variable.imp&j=&variable.max;
				else sim=&variable.moy; 
			end;
		else if haut= bas and bas=. then 
				sim=%if &model=log %then exp;(&varpred+sigma*PROBIT(uni));
		else if bas=. and haut^=. then
				sim=%if &model=log %then exp;(&varpred+
						sigma*PROBIT(uni*CDF('NORMAL',haut,0,1)));
		else if bas^=. and haut=. then
				sim=%if &model=log %then exp;(&varpred+
						sigma*PROBIT(uni*(1-CDF('NORMAL',bas,0,1))+CDF('NORMAL',bas,0,1)));
		else if bas^=. and haut^=. then 
				sim=%if &model=log %then exp;(&varpred+
					sigma*PROBIT(uni*(CDF('NORMAL',haut,0,1)-CDF('NORMAL',bas,0,1))
						+CDF('NORMAL',bas,0,1)));
		somme=somme+sim;
		&variable.imp&j=sim;
	%end ; 
	end;

	data &tableoutput;
		set _tab (drop=uni sim);
		run;
	%END;

	/*** fin méthode 1 ****/

	%If &methode=2 %Then %do;
	/****************************************************************************************
	*********** Simulation dans la loi tronquée par acceptation-rejet ***********************
	****************************************************************************************/
	data _tab;
		set _tab;
	%let j=1;
	if (bas^=.) then alphamin=(bas+sqrt(bas*bas+4))/2;
	else alphamin=.;
	if (haut^=.) then alphamax=(-haut+sqrt(haut*haut+4))/2;
	else alphamax=.;
	if ((det=1)*(haut^=.)*(bas^=.)*(haut^=bas)>0) then do;
		indicateur1=((alphamin*exp(alphamin*bas/2)/sqrt(exp(1)))>(exp(bas*bas/2)/(haut-bas)));
		indicateur2=((alphamax*exp(alphamax*(-haut)/2)/sqrt(exp(1)))>(exp(haut*haut/2)/(haut-bas)));
		end;
	else do;
		indicateur1=.;
		indicateur2=.;
		end;
	%do j=1 %to &nbimput ;
	sim=0;
	if (&def=1) then do;
		if ((&variable.min=&variable.max)*(&variable.max^=.)>0) then sim=&variable.min;
		else if ((&varpred=.)>0) then do; 
						pb=pb+1;
						if ((&variable.min^=.)*(&variable.max^=.)>0) then 
						sim=(&variable.min+&variable.max)/2;
						else if (&variable.min^=.) then sim=&variable.min;
						else if (&variable.max^=.) then sim=&variable.max;
						else sim=&variable.moy; 
						end;
		else do;
	/* Il s'agit de l'amélioration notoire par rapport à la version antérieure et 10 itérations au lieu d'un milier suffisent 
	souvent en pratique et il n'y a plus de problème de rejet*/ 
				 ok=0;	
				 do ind=1 to &nbiter while (ok=0);
					if ((haut=.)*(bas=.)>0) then do;
						z=rannor(0);
						sim=exp(&varpred+sigma*z);
						ok=1;
					end;
					else if ((haut=.)*(bas^=.)+(haut^=.)*(bas^=.)*(indicateur1=1)>0) then do;
	                	uni1=ranuni(1);
						z=bas-log(1-uni1)/alphamin;
						rho=exp(-(z-alphamin)*(z-alphamin)/2);
						uni2=ranuni(1);
						sim=exp(&varpred+sigma*z);
						ok=(uni2<=rho)*((haut^=.)*(z<=haut)+(haut=.));
					end;
					else if ((haut^=.)*(bas=.)+(haut^=.)*(bas^=.)*(indicateur2=1)>0) then do;
	                	uni1=ranuni(1);
						z=-haut-log(1-uni1)/alphamax;
						rho=exp(-(z-alphamax)*(z-alphamax)/2);
						uni2=ranuni(1);
						sim=exp(&varpred-sigma*z);
						ok=((bas^=.)*(uni2<=rho)*(z<=-bas)+(bas=.)*(uni2<=rho)>0);
					end;
					else do uni1=ranuni(1);
						z=uni1*bas+(1-uni1)*haut;
						if (bas<=0<=haut) then rho=exp(-z*z/2);
						else if (haut<0) then rho=exp((haut*haut-z*z)/2);
						else rho=exp((bas*bas-z*z)/2);
						uni2=ranuni(1);
						sim=exp(&varpred+sigma*z);
						ok=(uni2<=rho);
					end;
				end;
					if ok=0 then do; 
						pb=pb+1;
	/* si pb on effectue une imputation "déterministe", i.e. on impute par l'espérance 
	du montant conditionnellement à l'évènement "le montant est dans la tranche", pour la loi non conditionnelle 
	où les paramètres sont remplacés par les paramètres estimés.*/
						if ((bas^=.)*(haut^=.)>0) then 
						sim=(exp(&varpred+sigma*sigma/2)/(CDF('NORMAL',haut,0,1)-CDF('NORMAL',bas,0,1)))*(CDF('NORMAL',haut-sigma,0,1)-CDF('NORMAL',bas-sigma,0,1));
						else if (bas=.) then 
						sim=(exp(&varpred+sigma*sigma/2)/CDF('NORMAL',haut,0,1))*CDF('NORMAL',haut-sigma,0,1);
						else if (haut=.) then 
						sim=(exp(&varpred+sigma*sigma/2)/(1-CDF('NORMAL',bas,0,1)))*(1-CDF('NORMAL',bas-sigma,0,1));
					end;
		end;
	end;
	somme=somme+sim;
	&variable.imp&j=sim;
	%end;
	data &tableoutput;
		set _tab ;
		drop ok  sim ind uni1 uni2 z rho indicateur1 indicateur2 alphamin alphamax ;
	run ;
	%END;
	/*** fin méthode 2 ***/

	%If &methode=3 %Then %Do;
	/***********************************************************************************
	************* Méthode avec tirage de résidu observé et acceptation -rejet **********
	***********************************************************************************/
	/* construction de la table de résidus observés, avec variables permettant de faire le tri et
	in fine le tirage aléatoire du résidu ici avec remise */

	%if %length(&strate) ne 0 %then %do ;
	proc sort data=_tab ;
		by &strate ;
	%end ;

	data u(keep=_res _num_ &strate &variable);
		set _tab ;
		if &def=1 and not missing(&variable) ;
		_res=%if &model=log %then log;(&variable)-&varpred;
	run;

	proc means data=u noprint ; 
		var _res;
		%if %length(&strate) ne 0 %then by &strate ; ;
		output out=v mean=;
		
	data u ;
		set u(keep=_res) ;

	data v ;
		set v(drop=_type_) ;
		comp=_n_ ;
	run ;

	/* Calcul des effectifs cumulés	*/
	proc iml;
		use v;
		read all var {_FREQ_ comp} into d;
		taille=NROW(d);
		d2=j(taille,3,1); d2[,1:2]=d; d2[1,3]=0;
		do i=2 to taille;
		d2[i,3]=d2[i-1,1];
		d2[i,1]=d2[i-1,1]+ d2[i,1];
		end;
		create d2 from d2 [colname={sup comp inf}];
		append from d2;
	quit;

	data v(keep=&strate inf sup); 
		merge v d2;
		by comp;

	/* On injecte dans la table de travail les effectifs cumulés pour le tirage au sort	*/
	data _tab ;
		%if %length(&strate) ne 0 %then 
			%do ;
			merge _tab v;
				by &strate ; 
		%end ;
		%else 
			%do ;
			set _tab;
			if _n_=1 then set v ;
		%end ;
	run ;

	data _tab; 
		set _tab;
		_ssdon_=0 ;
	/* Traitement des observations où on ne tire pas de résidus	*/
		if not missing(inf) and (&def=0 or ((&def=1)*(&variable^=.)) or 
			((&def=1)*(&varpred=.)>0)
	 		or ((&def=1)*(&variable.min=&variable.max)*(&variable.min^=.)>0)) then
			do ;
		if &def=0 then sim=&variable;
		else if ((&def=1)*(&variable^=.)) then sim=&variable;
		else if ((&def=1)*(&varpred=.)>0) then do; 
						pb=pb+1;
						if ((&variable.min^=.)*(&variable.max^=.)>0) then 
						sim=(&variable.min+&variable.max)/2;
						else if (&variable.min^=.) then sim=&variable.min;
						else if (&variable.max^=.) then sim=&variable.max;
						else sim=&variable.moy; 
						end;
		else if ((&def=1)*(&variable.min=&variable.max)*(&variable.min^=.)>0) 
			then sim=&variable.min;
		%do j=1 %to &nbimput ;
			somme=somme+sim;
			&variable.imp&j=sim ;
		%end ;
		end ;
	else do;
	if missing(inf) then do ; 
		pb=1 ; _ssdon_=1 ;
	end ;
	else do ;
	/* étape d'acceptation-rejet, tirage avec remise parmis les résidus observés */
	%do j=1 %to &nbimput ;
	   ok=0;
	   do ind=1 to &nbiter while (ok=0);
		  nbalea=inf+ceil((sup-inf)*ranuni(1));
		  set u point=nbalea;
	      sim=%if &model=log %then exp;(&varpred+_res);
		  if ((&variable.min=.)*(&variable.max=.)=1) then ok=1;
		  else if (&variable.min=.) then ok=(sim <=&variable.max);
	      else if (&variable.max=.) then ok=(sim >= &variable.min);
	      else ok=(&variable.min <= sim <=&variable.max);
	   end;/* fin de l'acceptation-rejet */
	if ok=0 then do; 
			pb=pb+1;
	/* si pb on effectue une imputation "déterministe", i.e. on impute par l'espérance 
	du montant conditionnelle à l'évènement "le montant est dans la tranche".*/
			%if &model=log %then %do ;
	/* Si le modèle est log-linéaire	*/
			if ((bas^=.)*(haut^=.)>0) then 
			sim=(exp(&varpred+sigma*sigma/2)/
					(CDF('NORMAL',haut,0,1)-CDF('NORMAL',bas,0,1)))
					*(CDF('NORMAL',haut-sigma,0,1)-CDF('NORMAL',bas-sigma,0,1));
			else if (bas=.) then 
			sim=(exp(&varpred+sigma*sigma/2)
					/CDF('NORMAL',haut,0,1))*CDF('NORMAL',haut-sigma,0,1);
			else if (haut=.) then 
			sim=(exp(&varpred+sigma*sigma/2)
					/(1-CDF('NORMAL',bas,0,1)))*(1-CDF('NORMAL',bas-sigma,0,1));
			%end ;
			%else %do ;
	/* Calcul pour un modèle linéaire	*/
			if ((bas^=.)*(haut^=.)*(bas^=haut)>0) then 
				sim=&varpred+sigma * (pdf('normal',bas) - pdf('normal',haut) )
						/(probnorm(haut)-probnorm(bas));
			else if (bas=.) then 
				sim=&varpred - sigma * pdf('normal',haut)/probnorm(haut) ;
			else if (haut=.) then 
				sim=&varpred + sigma * pdf('normal',bas)/(1-probnorm(bas)) ;
			%end ;
		end;
		somme=somme+sim;
		&variable.imp&j=sim;
	%end;
	end;
	end;

	data &tableoutput;
		set _tab;
		drop ok ind _res inf sup sim 
			%if &ppv=0 %then _ssdon_; ;
	run;

	proc datasets nolist ;
		delete u v d2 ;
	quit ;

	%END;
	/*** fin méthode 3 ****/

	%If (&pred=1) %Then %Do;
	/************************************************************************************
	************* Calcul d'une prédiction individuelle **********************************
	************************************************************************************/
	data &tableoutput;
		set &tableoutput;
	if (&def=1) then do;
		&variable.predMC=somme/&nbimput;
		if (&varpred^=.) then do;		
	%if &model=log %then %do ;
	/* Calcul pour un modèle log-linéaire	*/
			if ((bas^=.)*(haut^=.)*(bas^=haut)>0) then 
				&variable.pred=(exp(&varpred+sigma*sigma/2)/(
				CDF('NORMAL',haut,0,1)-CDF('NORMAL',bas,0,1)))*
					(CDF('NORMAL',haut-sigma,0,1)-CDF('NORMAL',bas-sigma,0,1));
			else if ((bas=.)*(haut^=.)>0) then 
				&variable.pred=(exp(&varpred+sigma*sigma/2)
					/CDF('NORMAL',haut,0,1))*CDF('NORMAL',haut-sigma,0,1);
			else if ((haut=.)*(bas^=.)>0) then 
				&variable.pred=(exp(&varpred+sigma*sigma/2)
					/(1-CDF('NORMAL',bas,0,1)))*(1-CDF('NORMAL',bas-sigma,0,1));
			else if ((bas=haut) and bas^=.) then &variable.pred=&variable.simu1;
			else &variable.pred=exp(&varpred+sigma*sigma/2);
	%end ;
	%else %do ;
	/* Calcul pour un modèle linéaire	*/
			if ((bas^=.)*(haut^=.)*(bas^=haut)>0) then 
				&variable.pred=&varpred+sigma * (pdf('normal',bas) - pdf('normal',haut) )
						/(probnorm(haut)-probnorm(bas));
			else if ((bas=.)*(haut^=.)>0) then 
				&variable.pred=&varpred - sigma * pdf('normal',haut)/probnorm(haut) ;
			else if ((haut=.)*(bas^=.)>0) then 
				&variable.pred=&varpred + sigma * pdf('normal',bas)/(1-probnorm(bas)) ;
			else if ((bas=haut) and bas^=.) then &variable.pred=&variable.simu1;
			else &variable.pred=&varpred ;
	%end ;
			end;
			else if (&varpred=.) then &variable.pred=&variable.simu1;
		end;
		else do;&variable.predMC=somme/&nbimput;
		&variable.pred=0;end;
	run;
	%END;

	data &tableoutput;
		set &tableoutput;
		drop somme bas haut &variable.moy;
	run;

	%If &ppv=1 %Then %Do;
	/***********************************************************************************
	************* Module de Hot-Deckisation des valeurs simulées ***********************
	************************************************************************************/
	data rec;
		set &tableoutput ;
		where (&def=1) and missing(&variable) %if &methode=3 %then and _ssdon_=0 ;;
		compt=_N_;
	run;

	options nonotes ;

	%do j=1 %to &nbimput;
		data don;
			set &tableoutput ;
			where (&def=1) and not missing(&variable) and not missing(&varpred) ;

		data recloc;
			set rec(keep=&variable.imp&j compt);run;

		proc iml;
			use don;
			read all var {&variable} into don;
			nbdon=NROW(don);
			use recloc;
			read all var _ALL_ into recloc;
			nbrec=NROW(recloc);
			do id=1 to nbrec;
				don2=j(nbdon,3,1);
				don2[,1]=don;
				don2[,2]=j(nbdon,1,recloc[id,1]);
				don2[,3]=(don2[,1]-don2[,2])##2;
				min=don2[><,3][1,1] ;
				recloc[id,1]=don2[loc(don2[,3]=min)[1,1],1];
			end;
			create recloc2 from recloc[colname={&variable.imppv&j compt}];
			append from recloc;
		quit;

		data rec; 
			merge rec recloc2;
			by compt;
		run;
	%end;

	data rec ;
		set rec(drop=compt);
	run;

	%do j=1 %to &nbimput ;
		data don;
			set don;
			&variable.imppv&j=&variable;
		run;
	%end;

	options notes ;

	data &tableoutput;
		set rec don %if &methode=3 %then 		
			&tableoutput(where=(_ssdon_=1));;
		%if &methode=3 %then drop _ssdon_ ;;
	run;

	proc datasets nolist ;
		delete rec don recloc recloc2 ;
	quit ;

	%END;
	/*** fin du module de Hot-Deckisation ****/

	proc sort data=&tableoutput out=&tableoutput(drop=_num_ 
		%if &max=0 %then &variable.max ; 
		%if &min=0 %then &variable.min ; 
		%if &pressigma=0 %then &sigma ;
		%if &def=_def_ %then &def ; ) ;
	by _num_ ;
	run ;

	/* Suppression des tables temporaires	*/
	proc datasets nolist ;
		delete _tab _var moy ;
	quit ;

	%MEND;

/******************************************************************************************
************************** Fin de la Macro %Simul *****************************************
*******************************************************************************************/


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
