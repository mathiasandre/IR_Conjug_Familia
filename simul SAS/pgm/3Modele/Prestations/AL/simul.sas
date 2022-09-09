/*******************************************************************************************
*************************** Macro pour des "r�sidus simul�s" et variantes ******************
*******************************************************************************************/

/* version de mai 2007	*/

/***************** utiliser la macro simul apr�s une estimation adhoc **********************/

/*******************************************************************************************
********************* Introduction et initialisation des macros variables ******************
*******************************************************************************************/

/* - variable 	*/
/* La variable � simuler &variable (ou y ) est une quantit� num�rique
/* positive dont on sait qu'elle 
est non nulle dans le cas d'un mod�le loglin�aire.
On mod�lise y ou log y par la loi d'un mod�le lin�aire avec les covariables x. 
Les observations sont soit en tranches ou en fourchettes (les hauts et les bas d�pendent de 
l'unit�) soit en clair. Il convient de nommer les bas et les hauts de la forme &variable.min 
et &variable.max (si on ne les connait pas les mettre � .). 
Si le montant est renseign� en clair le bas est �gal au haut, si le haut 
ou le bas ne sont pas renseign�s leur valeur est . 
*/ 

/* tranche	*/
/* Si 0, non prise en compte de tranches m�me si &variable.min et &variable.max */
/* sont pr�sentes				*/
/* Sinon, si l'une des deux variables est pr�sente, prise en compte des tranches	*/


/* - tableinput	*/
/* Une fois le mod�le estim�, la table &tableinput doit poss�der les colonnes &varpred */
/* et pour les m�thodes 1 et 2, la &sigma (�cart-type des r�sidus).	*/


/* - def	*/
/* Nom de la variable indiquant si &variable a un sens d�fini 			*/
/* - varpred	*/
/* Nom de la variable indiquant la pr�diction de y ou log y				*/
/* Par d�faut, c'est xb													*/

/* - model	*/
/* si log (option par d�faut) on a un mod�le log-lin�aire, sinon lin pour un mod�le 
lin�aire				*/

/* - sigma		*/
/* Nom de la variable contenant l'�cart-type des r�sidus 			*/
/* que l'on va simuler (m�thode 1 ou 2) par d�faut, c'est sigma		*/									*/

/* - tableoutput	*/
/* la table de sortie	 */

/* - indicatrice	*/
/* nom de la variable indicatrice des imputations, si renseign�		*/

/* - nbimput		*/
/* C'est le nombre de simulations (&nbimput=1 si on ne fournit � chaque fois qu'une seule imputation)
remarque : l'id�e est de produire une pr�diction de l'estimateur de sondage de la quantit� 
en population totale en faisant la moyenne des n statistiques obtenues sur chacun des jeux 
de donn�es simul�es */ 

/* - nbiter		*/
/* La simulation utilise une version de l'algorithme d'acceptation-rejet optimis�e,
on indique ici le nombre d'it�rations, en pratique peu d'it�rations suffisent 
pour obtenir l'acceptation et l'arr�t de l'algorithme (5 peut suffir, normalement 20 suffit 
presque � coup s�r), si jamais pour un enregistrement il n'y a pas eu acceptation (faire en sorte 
que cela ne soit jamais le cas par exemple en mettant un nombre plus �lev� d'it�rations!) la valeur 
fabriqu�e est la pr�diction (esp�rance dans la loi conditionnelle aux covariables et aux tranches)  
par un calcul num�rique d'int�grale.*/
/*pour les m�thodes 2 et 3 seulement, sinon mettre n'importe quoi par exemple 1)*/

/* - pred		*/
/* On peut choisir ici de faire une pr�diction pour chaque enregistrement par moyenne 
conditionnelle en mettant &pred=1 (si on s'int�resse ex post � des statistiques lin�aires en les observations
ex moyenne, total, dans certain cas la droite de r�gression, sinon les estimations sont biais�es!), 
alors deux variables sont ajout�es
1. &variable.predMC correspond, pour chaque unit� r�pondant partiellement ou 
   non r�pondant pour lequel le montant est positif, � la moyenne des &nbimput simulations; /*
2. &variable.pred correspond � l'esp�rance conditionnelle pour la loi avec les param�tres estim�s, 
   le calcul d'int�grale est standard. La variable &variable.predMC en est une estimation.   
Si on ne d�sire pas cette colonne on pose pred=0 */
/* Si le mod�le est lin�aire (model=lin), on retrouve � peu de chose pr�s sur la pr�diction */

/* La variable pb en sortie indique par unit� simul�e le nombre total de probl�mes rencontr�s */

/* - methode		*/
/* Nous pouvons choisir parmi trois m�thodes : 
Les deux premi�res m�thodes sont deux variantes de la m�me m�thode,
il s'agit d'une simulation dans la loi du mod�le lin�aire Gaussien ,
�ventuellement dans la loi tronqu�e lorsque une information en fourchette est disponible.
Avec la m�thode 1 la simulation est obtenue en inversant la fonction de r�partition � partir 
de la fonction de r�partition de la loi normale et de la fonction quantile. 
C'est la m�thode la plus rapide.

Cependant du fait des approximations num�riques et en particulier lorque la fourchette
est loin de la moyenne de la loi non conditionnelle (non tronqu�e) il peut �tre pr�f�rable 
d'utiliser la m�thode 2. La simulation de la loi tronqu�e est alors effectu�e par 
acceptation-rejet. Il s'agit d'une variante par rapport � la macro "r�sidu simul�" cette fois
la probabilit� d'acceptation est optimis�e et peu d'it�rations suffisent.

Dans la m�thode 3 on ajoute � la moyenne du logarithme un r�sidu observ� (peut �tre pr�f�rable 
dans certains cas car ne n�cessite pas la sp�cification de la loi) un r�sidu observ�.
Cette deuxi�me m�thode n�cessite que la plupart des r�ponses soient des r�ponses en clair 
afin de  pouvoir trouver un r�sidu observ� qui satisfasse (acceptation-rejet) les contraintes 
issues de la fourchette. Attention toutefois le r�sidu est observ� certe mais la valeur imput�e
n'est pas une valeur observ�e.*/

/* - strate	*/
/* variable(s) stratifiante(s) pour le tirage des r�sidus dans la m�thode 3	*/

/* - ppv		*/
/* Reste l'option Hot Deckisation des valeurs simul�es que l'on peut utiliser avec les 3
m�thodes pr�c�dentes :
elle revient � remplacer la valeur simul�e par la valeur la plus proche satisfaisant 
la contrainte, poser alors ppv=1.
Attention dans la m�thode 3 le r�sidu est un r�sidu observ� par contre la valeur simul�e 
n'est pas forc�ment une valeur observ�e*/

/* ! Dans la macro qui suit, si une variable explicative manque, on ne simule plus la 
variable mais on met la demie somme lorsque la fourchette est born�e, ou le minimum de la 
derni�re tranche, ou la moyenne des observations chez les r�pondants, (on pourrait aussi 
faire la moyenne des observations de la fourchette...) !!!!!!!! 
Il est en tout cas pr�f�rable de mener � nouveau l'estimation d'un mod�le o� ne figurent 
pas les x qui manquent, estim� sur tout le monde. Alors figureraient pour ces m�nages &varpred 
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

	/* D�tection de la pr�sence des variables &variable.min 	*/
	/*			et &variable.max								*/
	/* &bracket vaut 1 ou 2 si elles sont pr�sentes				*/
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
	/* Si une seule borne est pr�sente, on d�finit l'autre � missing	*/
	%if &bracket =1 %then 
	%do ;
		%if &min=0 %then 
		length &variable.min 8. ;
		%else 
		length &variable.max 8. ;
	%end ; ;
	/* Si pas de tranche � prendre � compte, 
	on met les bas et hauts de tranches � missing		*/
	%if &bracket = 0 %then %do ;
		attrib &variable.min &variable.max length=8. ; 
		&variable.min=. ;
		&variable.max=. ;
	%end ;
	/* Si pas de variable def d�finie, on prend tout le monde	*/
	%if %length(&def)=0 %then 
		%do ;
		%let def=_def_ ;
		_def_=1 ;
	%end ;
		if &def ne 1 then &def=0 ;

	/* Calcul des bas et hauts de tranches pour les r�sidus			*/
	%if &model=log %then %do ;
	/* pour un mod�le log-lin�aire	*/
	if ((&variable.min^=0)*(&variable.min^=.)*(&varpred^=.)>0) 
		then bas=(log(&variable.min)-&varpred)/sigma ;
		else bas=.;
	if ((&variable.max^=.)*(&varpred^=.)*(&variable.max^=0)>0) 
		then haut=(log(&variable.max)-&varpred)/sigma ;
		else haut=.;
	%end ;
	%else %do ;/* pour un mod�le lin�aire	*/
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
	/* calcul de la moyenne sur les r�pondants */ 
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
	**** Simulation dans la loi tronqu�e par inversion de la fonction de r�partition ********
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
	/* Si pas de valeur pr�dite, on fait la moyenne du bas et haut de tranche	*/
	/* ou moyenne des r�pondants												*/
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

	/*** fin m�thode 1 ****/

	%If &methode=2 %Then %do;
	/****************************************************************************************
	*********** Simulation dans la loi tronqu�e par acceptation-rejet ***********************
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
	/* Il s'agit de l'am�lioration notoire par rapport � la version ant�rieure et 10 it�rations au lieu d'un milier suffisent 
	souvent en pratique et il n'y a plus de probl�me de rejet*/ 
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
	/* si pb on effectue une imputation "d�terministe", i.e. on impute par l'esp�rance 
	du montant conditionnellement � l'�v�nement "le montant est dans la tranche", pour la loi non conditionnelle 
	o� les param�tres sont remplac�s par les param�tres estim�s.*/
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
	/*** fin m�thode 2 ***/

	%If &methode=3 %Then %Do;
	/***********************************************************************************
	************* M�thode avec tirage de r�sidu observ� et acceptation -rejet **********
	***********************************************************************************/
	/* construction de la table de r�sidus observ�s, avec variables permettant de faire le tri et
	in fine le tirage al�atoire du r�sidu ici avec remise */

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

	/* Calcul des effectifs cumul�s	*/
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

	/* On injecte dans la table de travail les effectifs cumul�s pour le tirage au sort	*/
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
	/* Traitement des observations o� on ne tire pas de r�sidus	*/
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
	/* �tape d'acceptation-rejet, tirage avec remise parmis les r�sidus observ�s */
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
	/* si pb on effectue une imputation "d�terministe", i.e. on impute par l'esp�rance 
	du montant conditionnelle � l'�v�nement "le montant est dans la tranche".*/
			%if &model=log %then %do ;
	/* Si le mod�le est log-lin�aire	*/
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
	/* Calcul pour un mod�le lin�aire	*/
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
	/*** fin m�thode 3 ****/

	%If (&pred=1) %Then %Do;
	/************************************************************************************
	************* Calcul d'une pr�diction individuelle **********************************
	************************************************************************************/
	data &tableoutput;
		set &tableoutput;
	if (&def=1) then do;
		&variable.predMC=somme/&nbimput;
		if (&varpred^=.) then do;		
	%if &model=log %then %do ;
	/* Calcul pour un mod�le log-lin�aire	*/
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
	/* Calcul pour un mod�le lin�aire	*/
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
	************* Module de Hot-Deckisation des valeurs simul�es ***********************
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
