/************************************************************************************/
/*																					*/
/*								2_baseind_ini.sas									*/
/*								 													*/
/************************************************************************************/

/* Cr�ation d'une base de niveau individuel									*/ 
/* En entr�e : 	travail.indivi&anr.											*/ 
/*				travail.indfip&anr.											*/ 										
/*				travail.irf&anr.e&anr.										*/
/*				travail.menage&anr.											*/
/* En sortie : 	base.baseind												*/


/* Base initiale : individus de RPM + FIP */

/* RPM + leurs caract�ristiques de l'EE */
proc sql undo_policy=none;
	create table indiv (drop=identb noib) as
	select	* from travail.indivi&anr. as a
			left outer join
			(select ident as identb, noi as noib, naia, naim, acteu6, matri, noicon, noienf01, lprm, noiper, noimer, retrai, sexe, sexeprm, sexeprmcj 
			from travail.irf&anr.e&anr.) as b
			/* NB : acteu6 n'est pas relatif au m�me instant T pour tout le monde */
			on a.ident=b.identb and a.noi=b.noib;
	quit;

/* RPM + FIP */
data indiv (keep=ident noi quelfic persfip persfipd declar1 declar2 naia naim acteu6 matri noicon noienf01 lprm noiper noimer retrai sexe:); 
	set	indiv
		travail.indfip&anr.;
	label naia='Ann�e de naissance' naim='Mois de naissance';
	run;

/* On d�termine un �ge pour les FIP */
data base.baseind (drop=alea);
	set	indiv;
	if quelfic='FIP' then do;
		alea=put(int(12*ranuni(2))+1,best2.); /* Chiffre compris entre 1 et 12 */
		if input(alea,2.)<10 then naim=compress("0"||alea); /* Ainsi janvier="01" et non "1" */
		else naim=compress(""||alea);
		end;
	run;

/* Appariement des poids */
proc sql undo_policy=none;
	create table base.baseind (drop=identb) as
	select	* from base.baseind as a
			left outer join
			(select ident as identb, wpela&anr., wpela&anr1., wpela&anr2. from travail.menage&anr.) as b
			on a.ident=b.identb
	order by declar1, naia, naim;
	quit;


/* On recr�e persfip1 et persfip2 */
data base.baseind (drop=pac naia_d1 naia_c1 naia_d2 naia_c2);
	set base.baseind;

	naia_d1=substr(declar1,14,4);
	naia_c1=substr(declar1,19,4);
	naia_d2=substr(declar2,14,4);
	naia_c2=substr(declar2,19,4);

	if persfipd='vopa' then persfip='pac'; /* jeune majeur qui fait sa d�claration � part consid�r� comme pac */

	retain pac 0; /* Nombre de personnes � charge */
	by declar1 naia naim;
	if first.declar1 then pac=(persfip='pac');
		else pac=pac+(persfip='pac');

	if persfip ne 'pac' then do;
		/* Si les conjoints ne sont pas n�s la m�me ann�e on identifie l'un et l'autre par leur date de naissance */
		if (naia_d1 ne naia_c1) and (declar2='' or naia_d2 ne naia_c2) then do; 
			if naia=naia_d1 then persfip1='decl';
			if naia=naia_c1 then persfip1='conj';
			if naia=naia_d2 then persfip2='decl';
			if naia=naia_c2 then persfip2='conj';
			end;
		/* Si les deux conjoints sont n�s la m�me ann�e, alors on utilise persfip et persfipd */
		else do;
			/* si pas de conjoint */
			if substr(naia_c1,1,3)='999'	then persfip1='decl';
			if substr(naia_c2,1,3)='999'	then persfip2='decl';
			/* si un conjoint */
			if declar1 ne '' & substr(naia_c1,1,3) ne '999' & persfip='vous' then persfip1='decl';
			if declar1 ne '' & substr(naia_c1,1,3) ne '999' & persfip='conj' then persfip1='conj';
			if declar2 ne '' & substr(naia_c2,1,3) ne '999' then persfip2='decl';
			end;
		end;
	else do;
		if pac=1		then persfip1='p1';
		else if pac=2	then persfip1='p2';
		else if pac>2	then persfip1='p3';
		if declar2 ne '' then persfip2=persfip1; 
		end;

	if declar1 = '' then do; persfip1=''; end;

	/* Cas particulier des jeunes majeurs qui d�clarent � part (vopa) */
	if persfipd= 'vopa' then do;
		/* Moins de 20 ans */
		if %eval(&anref.)-input(naia_d1,4.)<20 then persfip1='decl';
		if declar2 ne '' & %eval(&anref.)-input(naia_d2,4.)<20 then persfip2='decl';
			else persfip2='';
		persfip='vous';
		end;

	/* On l�ve les incoh�rences entre persfip et le declar (ann�es de naissances des p�c) */
	if substr(declar1,30,1)='' & persfip1 in ('p1','p2','p3')	then persfip1='';
	if substr(declar1,36,1)='' & persfip1 in ('p2','p3')		then persfip1='';
	if substr(declar1,41,1)='' & persfip1 in ('p3')				then persfip1='';
	if substr(declar2,30,1)='' & persfip2 in ('p1','p2','p3')	then persfip2='';
	if substr(declar2,36,1)='' & persfip2 in ('p2','p3')		then persfip2='';
	if substr(declar2,41,1)='' & persfip2 in ('p3')				then persfip2='';

	label persfip1 = "identifiant individuel 1";
	label persfip2 = "identifiant individuel 2";
	run;


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
