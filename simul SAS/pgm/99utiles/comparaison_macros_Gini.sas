/* 10/02/2014 */
/* Comparaison des deux macros calculant un indice de Gini */

/* %Gini1 est celle qui �tait utilis�e jusqu'ici pour FPS (et autres) */
/* %Gini2 est la macro qui est utilis�e par Eurostat et par RPM et Rennes pour l'ERFS */


%macro Gini1(data=,var=,pond=,crit=,pseudo=,where=,out=_gini_);

/* Gini : calcule le Gini ou le pseudo-Gini d'un dispositif - prestation ou pr�l�vement 
(macro appel�e dans tableau_gini) */

/* signification des variables d'input :
	- data : table sur laquelle on travaille (extrait de basemen) 
	- var : la variable qui sert � classer les individus (en g�n�ral le revenu initial)
	- pond : la pond�ration (individuelle) 
	- crit : variable dummy qui peut servir � s�lectionner une sous-population 
	- pseudo : la variable dont on veut calculer le pseudo-Gini (par exemple les pr�l�vements). 
	Si elle n'est pas pr�cis�e, on calcule le Gini (et non le pseudo-Gini) de la variable &var. 
	- where : non utilis� 
	- out : fichier de sortie, avec l'effectif concern�, la moyenne de la variable &pseudo.
	et le pseudo-Gini, pour chaque valeur de &crit. Par d�faut, le fichier de sortie s'appelle _gini_. 
*/

/* en sortie, la table &out. (cf. ci-dessus) et une macro-variable globale &gini. 
avec la valeur du pseudo-Gini */

/* le pseudo-Gini est calcul� au niveau individuel, en cumulant la contribution de 
chaque individu au Gini (et non en calculant la contribution de chaque quantile comme
c'est parfois fait pour acc�l�rer le temps de calcul, au d�triment de la pr�cision de 
l'estimation) */

	%global gini;
    proc sort data=&data. out=&out.(keep=&var. &pond. &pseudo. &crit.);
    	by &crit. &var.;
		run;
    %if &pseudo.= %then %let pseudo=&var;
    %if &pond.= %then %let pond=1; %*pond doit absolument �tre entier !;
    data &out.(keep=&crit. effectif moyenne gini);
     	set &out. end=fin; 
		by &crit. &var.;
	    retain _eff 0 gini 0 _pond 0 _mass 0 _moy 0;
	    %if &crit. ne %then %do;
	    	if first.&crit. then do; _eff=0; _mass=0; gini=0; end;
	    	%end;
	    _mass=_mass+&pond.*&pseudo.;
	    gini=gini+&pond.*&pseudo.*(2*_eff+&pond.+1)/2;
		_eff=_eff+&pond.;
	    %if &crit. ne %then %do; 
		if last.&crit. then do; 
		%end;
	    %else %do; 
		if fin then do; 
		%end;
		    gini=2*gini/(_mass*_eff)-1-1/_eff;
			_moy=_mass/_eff;
		    effectif=_eff;
			moyenne=_moy;
		    label 	effectif="Frequence" 
					moyenne	="Moyenne de &pseudo" 
					gini="Gini";
			call symput ('gini',gini);
		    output;
			end;
		run;
	%MEND gini1;



%macro Gini2(variable=, ponderation=, librairie=work, table=, Gini_Prov=_gini_);
	data &table;
	set &librairie..&table(keep=&variable. &ponderation.);
	run;
	proc sort data=&table;
		by &variable;
		run;
	proc iml;
			/* Place les variables dans une matrice */
			edit &table;
			parametre={&variable &ponderation};
			read all var parametre into mat;
			taille=nrow(mat);			/* La taille de l'�chantillon */
			N=mat[+,2]; 				/* Estimateur de la population */
			T=sum(mat[,1]#mat[,2]); 	/* Estimateur du total */

			Fr=j(taille,1,1);			/* Estimateur de la fonction de r�partition */
			F=j(taille,1,1);
			Fr[1,1]=mat[1,2]/N;
			F[1,1]=0.5*mat[1,2]/N;

			do i=2 to taille;
				Fr[i,1]=Fr[i-1,1]+mat[i,2]/N;
				F[i,1]=Fr[i,1]-0.5*mat[i,2]/N;
			end;	

			Num=sum((2*N*F[,1]-1)#(mat[,1]#mat[,2])); 	/* Calcul du num�rateur */
			Den=N*sum(mat[,1]#mat[,2]);					/* Calcul du d�nominateur */
			Gini=Num/Den-1; 							/* Calcul du Gini */
		
			create table_gini from Gini[colname={&Gini_Prov}];
			append from Gini;
	        title "indice de Gini"; 
			Print Gini;
		quit;
		%global &gini_Prov;
		data &Gini_Prov; set table_gini;
			call symput("&Gini_Prov",&gini_Prov);
		run;	

		data &Gini_Prov;
		set &Gini_Prov;
		rename &Gini_Prov = gini;
		run;

		data &Gini_Prov;
		set &Gini_Prov;
		indice_gini=round(gini*1000)/1000;
		keep indice_gini;
		run;

	proc datasets library=work;
	delete &table table_gini; quit;
	%mend;





/**************************************************************************/
/* Comparaison sur une variable de l'ERFS : revenu disponible des m�nages */
/**************************************************************************/

libname m "V:\ERFS-MADPUBLI\ERFS &anref.\M�nages";

%gini1(	data=m.menage10,
		var=revdispm,
		pond=wprm);
/* en sortie : une table _gini_ avec trois colonnes : gini, effectif, moyenne */
/* ici valeur du Gini = 0.3644578356 */


%gini2(	variable=revdispm,
		ponderation=wprm,
		librairie=m,
		table=menage10);
/* ici valeur du Gini = 0.364 */

/* NB : avec des poids n�gatifs, m�me Gini fourni par les deux macros */
/*data table;
	set m.menage10;
	alea=ranuni(2);
	if alea lt 0.5 then poids_neg=-wprm;
	else poids_neg=wprm;
	run;
*/


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
