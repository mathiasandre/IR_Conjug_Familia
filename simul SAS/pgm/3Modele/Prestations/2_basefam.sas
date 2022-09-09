/************************************************************************************/
/*																					*/
/*								2_basefam											*/
/*																					*/
/************************************************************************************/

/* Création de age_enf et calcul du poids de chaque famille						 	*/
/* En entrée : modele.baseind                 	      								*/
/* En sortie : modele.basefam                                     					*/

/* On crée une variable regroupant l'age des enfants au 31/12 : age_enf 
et également 11 autres age_enf1-age_enf11 pour les autres mois. */

/* On calcul aussi le poids de chaque famille, comme la somme du poids de 
chaque individu de la famille */


proc sort data=modele.baseind(where=(quelfic ne 'FIP')) out=baseind; 
	by ident_fam01 descending ident_fam; /*On veut avoir les enfants de 21 ans avant le reste
	de la famille pour les inclure dans le age_enf de la famille des parents*/
	run;

/* 1. Calcul du nombre d'enfants (age_enf) et du nombre d'UC */
data basefam(keep=ident_fam: ident wpela: age_enf: enf_1 mois_1 mois00-mois03 agexx lprm);
	set baseind(keep=ident_fam: naia naim quelfic civ ident wpela: acteu6 lprm); 
	by ident_fam01 descending ident_fam ;

	length age_enf1-age_enf12 $%eval(&age_pl.+1); /* un caractère par age (y compris 0)*/ 
	retain aduc enfuc mois_1 mois00-mois03 enf_1 age_enf1-age_enf12 fam_etud;
	array age_enf age_enf1-age_enf12;

	if first.ident_fam01 then do;
		mois_1='  ';  mois00='  '; mois01='  '; mois02='  '; mois03='  ';
		enf_1=0;aduc=0;enfuc=0;fam_etud=1; 
		/*age_enf=repeat('0',24); */
		DO mois=1 to 12; age_enf(mois)=repeat('0',24);end;
		/* 25 zéros, on garde les &age_pl+1 premiers car le format de age_enf est ainsi, 
		cela permet de faire varier age_pl et que le programme tourne quand même */
		end;

	agexx=&anref.-input(naia,4.); 

	/* on garde les mois de naissance des plus jeunes */ 
	/* on pourra arrêter de les calculer séparément quand on aura finit la mensualisation des PF */
	if agexx=-1 then do;enf_1=enf_1+1; mois_1=naim; end;
	if agexx=0 then do; mois00=naim; end;
	if agexx=1 then do; mois01=naim; end;
	if agexx=2 then do; mois02=naim; end;
	if agexx=3 then do; mois03=naim; end;

	if quelfic ne 'FIP' /* on ne compte pas les enfants fip */
		and (civ not in ('mon','mad') or ident_fam ne ident_fam01)/* on évite ainsi de compter le propre age 
		des enfants gagnant trop d'argent)*/
	then do;
		DO m=1 to 12; /* Itération sur le mois */
			length ajout 3.;
			age=floor(&anref.-input(naia,4.) + (m - input(naim,2.))/12);
			if 0<=age<=&age_PL. then do; 
				ajout= 1+input(substr(age_enf(m),age+1,1),1.);
				if age=0 		then age_enf(m)=cats(ajout,substr(age_enf(m),2,&age_PL.));
				if age=&age_PL. then age_enf(m)=cats(substr(age_enf(m),1,&age_PL.),ajout);
				if  0<age<&age_PL. then
				age_enf(m)=cats(substr(age_enf(m),1,age),ajout,substr(age_enf(m),age+2,&age_PL.-age));
				end;
			end;
		end;
	
	if acteu6 not in ('5','') then fam_etud=0;
	if last.ident_fam then output; /* On garde une observation par famille au 31/12 */

	label 	agexx="age au 31 décembre %eval(&anref.+1)"
			fam_etud="Famille dont la PR est étudiante";
	run;

data modele.basefam(rename=(age_enf12=age_enf));
	set basefam;
	array age_enf age_enf1-age_enf12;
	/* Traitement des cas pour lesquels on ne veut pas calculer des enfants */
	if ident_fam ne ident_fam01 /* enfants de 21 ans vivant avec ses parents*/
		or (agexx<&age_PF. and lprm='1')   /* enfants jeunes vivants seuls */
		then DO mois=1 to 12; age_enf(mois)=repeat('0',24);end;
	drop agexx lprm mois;
	run;

/* 2. Calcul du poids de la famille sans prendre les enfants à naître en compte */
proc means data=modele.baseind(where=(input(naia,4.)<=&anref.)) noprint;
	var wpela&anr2.;
	class ident_fam;
	output out=poids(drop=_type_ _freq_) sum=poi_fam;
	run;

proc sort data=modele.basefam; by ident_fam; run;
/* 3. Intégration de ces changements dans modele.basefam */
data modele.basefam; 
	merge 	modele.basefam(in=a) 
			poids; 
	by ident_fam;
	if a; 
	run;


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
