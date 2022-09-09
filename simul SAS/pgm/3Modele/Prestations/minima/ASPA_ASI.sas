*************************************************************************************;
/*																																																							*/
/*								ASPA-ASI																																										*/
/*																																																							*/
*************************************************************************************;

/* Mod�lisation de l'Allocation de Solidarit� aux Personnes �g�es
                et l'Allocation Suppl�mentaire d'Invalidit�			*/
/* En entr�e : modele.baseind
			   base.baserev
			   base.foyer&anr2.
			   base.menage&anr2.									*/
/* En sortie : modele.baseind										*/


/* PLAN

A. Cr�ation d'une table BASEIND
B. S�lection des m�nages �ligibles
C. Calcul des ressources
D. Calcul des montants
	D.1. Montants de l'Aspa
	D.2. Montants de l'Asi
E. Interaction ASPA/ASI */

/* NB : Jusqu'en sept.2013, un programme de non-recours tournait dans l'encha�nement : imputait NR total aux agriculteurs */
%macro aspa_asi;
/***********************************/
/* A. Cr�ation d'une table BASEIND */
/***********************************/

proc sql;
	create table baseind as
	select 	a.ident, a.noi, a.noicon, a.ident_fam, a.declar1, a.declar2, a.naia, a.elig_aspa_asi, a.quelfic, a.persfip, a.lprm, a.matri,
			max(0,(b.zsali&anr2.+b.zragi&anr2.+b.zrici&anr2.+b.zrnci&anr2.))+b.zchoi&anr2.+b.zrsti&anr2.+b.zalri&anr2.+b.zrtoi&anr2. as revbrut&anr2.,
			max(0,(b.zsali&anr2.+b.zragi&anr2.+b.zrici&anr2.+b.zrnci&anr2.)) as revprof_aspa /* revprof_aspa va �tre utile pour coder l'abattement mis en oeuvre en 2015 */
	from modele.baseind as a left outer join base.baserev as b
	on a.ident=b.ident and a.noi=b.noi
	order by ident, noi;
	quit;

data avec_conjoint; 
	set baseind; 
	if noicon not in ('','0','00'); 
	run;
proc sql;
	create table couples as
	select * from avec_conjoint as a left outer join
	(select 	ident as ident2, noi as noi2, ident_fam as ident_fam2, declar1 as declar12, declar2 as declar22, revbrut&anr2. as revbrut&anr2.2, revprof_aspa as revprof_aspa2,
				naia as naia2, elig_aspa_asi as elig_aspa_asi2 from baseind) as b on
	a.ident=b.ident2 and a.noicon=b.noi2
	order by ident, noi;
	quit;
data baseind;
	merge baseind couples (drop=ident2);
	by ident noi;
	run;


/****************************************/
/* B. S�lection des m�nages �ligibles	*/
/****************************************/
/* Eligibles = 
	- les plus de 65 ans
	- les 60 � 65 qui remplissent des crit�res qu'on ne peut pas v�rifier : on prend ceux qui touchent un MV (elig_aspa_asi en amont) */

data Aspa_Asi;
	set baseind;
	%init_valeur(rev_aspa_abat); /* Variable pour l'abattement des revenus professionnels pour l'Aspa */
	en_couple=(noicon ne '');
	age=&anref.-input(naia,4.);
	if naia2 ne '' then age2=&anref.-input(naia2,4.);
	else age2=0;
	nb_elig_aspa=((age >64)+(64>=age >59)*(elig_aspa_asi=1))
				+((age2>64)+(64>=age2>59)*(elig_aspa_asi2=1));
	nb_elig_asi =((60>age )*(elig_aspa_asi=2))
				+((60>age2)*(elig_aspa_asi2=2));
	if declar12=declar1 ! declar12=declar2 then declar12='';
	if declar22=declar1 ! declar22=declar2 then declar22='';
	rev_asi=sum(revbrut&anr2.,revbrut&anr2.2);
	revprof_aspa=sum(revprof_aspa,revprof_aspa2);
	if (nb_elig_aspa>0 ! nb_elig_asi>0) & quelfic ne 'FIP';

/* Au 1er janvier 2015 , un abattement sur les revenus d'activit� est mis en place. La prise
en compte de cette mesure est param�trique : avant anleg=2015 &abat_aspa_couple. et 
&abat_aspa_celib sont �gaux � 0 */
/* ! �cart � la l�gislation : 
Pour l'Aspa, la prise en compte des ressources est trimestrielle, puis annuelle si la prise en compte 
trimestrielle ne donne pas l'�ligibilit�. L'abattement ne s'applique pas dans le cas de l'examen des
ressources annuelles. Ici, comme on ne mobilise pas de ressources trimestrielles on pr�f�re prendre 
en compte l'abattement tout le temps plut�t que jamais */
	if en_couple=1 then rev_aspa_abat=rev_asi-revprof_aspa+max(0,revprof_aspa-4*&abat_aspa_couple.); /* rev_aspa_abat est pareil que rev_asi sauf qu'il y a un abattement */
	if en_couple=0 then rev_aspa_abat=rev_asi-revprof_aspa+max(0,revprof_aspa-4*&abat_aspa_celib.);

	run;

/* Note : certaines PAC sont �ligibles, il s'agit de personnes ag�es, pas d'enfants, 
ils correspondent � la case R, je les garde mais je ne sais pas s'ils ont droit � l'ASPA 
et dans quel famille sont-ils d'abord ? */ 

/****************************************/
/* C. Calcul des ressources				*/
/****************************************/

proc sql;
	create table rev_aspa as
		select a.*, 
		b.mcdvo as mcdvo1, b.zracf as zracf1, b.zfonf as zfonf1, b.zetrf as zetrf1, b.zvamf as zvamf1, b.zvalf as zvalf1,
			b._2fu as _2fu1, b._2ch as _2ch1, b._2dh as _2dh1,
		c.mcdvo as mcdvo2, c.zracf as zracf2, c.zfonf as zfonf2, c.zetrf as zetrf2, c.zvamf as zvamf2, c.zvalf as zvalf2,
			c._2fu as _2fu2, c._2ch as _2ch2, c._2dh as _2dh2,
		d.zracf as zracf3, d.zfonf as zfonf3, d.zetrf as zetrf3, d.zvamf as zvamf3, d.zvalf as zvalf3,
			d._2fu as _2fu3, d._2ch as _2ch3, d._2dh as _2dh3,
		e.zracf as zracf4, e.zfonf as zfonf4, e.zetrf as zetrf4, e.zvamf as zvamf4, e.zvalf as zvalf4,
			e._2fu as _2fu4, e._2ch as _2ch4, e._2dh as _2dh4
		from Aspa_asi as a
			left outer join base.foyer&anr2. as b on (a.declar1=b.declar)
			left outer join base.foyer&anr2. as c on (a.declar2=c.declar)
			left outer join base.foyer&anr2. as d on (a.declar12=d.declar)
			left outer join base.foyer&anr2. as e on (a.declar22=e.declar)
	order by ident,noi;
	quit;

data rev_aspa;
	set rev_aspa;
	array zvamf zvamf1 zvamf2 zvamf3 zvamf4;
	array _2ch _2ch1 _2ch2 _2ch3 _2ch4;
	array _2fu _2fu1 _2fu2 _2fu3 _2fu4;
	array zvalf zvalf1 zvalf2 zvalf3 zvalf4;
	array _2dh _2dh1 _2dh2 _2dh3 _2dh4;
	array zracf zracf1 zracf2 zracf3 zracf4;
	array zfonf zfonf1 zfonf2 zfonf3 zfonf4;
	array zetrf zetrf1 zetrf2 zetrf3 zetrf4;
	do over zvamf;
		if _2ch=. then _2ch=0;
		if _2dh=. then _2dh=0;
		if _2fu=. then _2fu=0;
		zvamf=max(0,sum(0,zvamf,-_2fu,-_2ch)); 
		zvalf=max(0,sum(0,zvalf,-_2dh));
		zracf=max(0,zracf);
		zfonf=max(0,zfonf);
		zetrf=max(0,zetrf);
		end;
	rev_tot_asi=rev_asi+sum(of zracf1-zracf4 zfonf1-zfonf4 zvamf1-zvamf4 zvalf1-zvalf4 zetrf1-zetrf4);
	rev_tot_aspa_abat=rev_aspa_abat+sum(of zracf1-zracf4 zfonf1-zfonf4 zvamf1-zvamf4 zvalf1-zvalf4 zetrf1-zetrf4);
	run;

* Ajout des revenus financiers imput�s � rev_tot_aspa;
proc sql;
	create table prodfin as
		select a.*, b.produitfin_i*(a.lprm='1') as prodfin
		from baseind as a left outer join base.menage&anr2. as b
		on a.ident=b.ident
		order by ident,noi;
		quit;

data rev_aspa;
	merge rev_aspa (in=a) prodfin;
	by ident noi;
	if a;
	rev_tot_asi=rev_tot_asi+prodfin;
	rev_tot_aspa_abat=rev_tot_aspa_abat+prodfin;
	run;

proc delete data=avec_conjoint couples prodfin; run;


/****************************************/
/* D. Calcul des montants				*/
/****************************************/

data aspa_asi; 
	set rev_aspa; /* 1 ligne = 1 individu */
	%Init_Valeur(aspa asi);

	/****************************************/
	/* D.1 Montant de l'ASPA				*/
	/****************************************/
	/* Cas 1 : 1 seul �ligible � l'Aspa et pas de couple */
	if nb_elig_aspa=1 & en_couple=0 then aspa=min(&mv_mi.,&mv_plfi.-rev_tot_aspa_abat)*(rev_tot_aspa_abat<&mv_plfi.);
	/* Cas 2 : 1 seul �ligible � l'Aspa et en couple */
	else if nb_elig_aspa=1 & en_couple=1 then aspa=min(&mv_mi.,&mv_plfc.-rev_tot_aspa_abat)*(age>age2)*(rev_tot_aspa_abat<&mv_plfc.);
		/* la condition age>age2 sert � s�lectionner l'individu le plus ag� */
	/* Cas 3 : 2 �ligibles � l'Aspa */
	else if nb_elig_aspa=2 then	aspa=((&mv_plfc.-rev_tot_aspa_abat)/2)*(rev_tot_aspa_abat<&mv_plfc.);
	label aspa="Montant d'Aspa";

	/****************************************/
	/* D.2 Montant de l'ASI					*/
	/****************************************/
	/* Cas 1 : 1 seul �ligible � l'Asi et pas de couple */
	if nb_elig_asi=1 & en_couple=0 then asi=(rev_tot_asi<&asi_plfi.)*min(&asi_m1.,&asi_plfi.-rev_tot_asi);
	/* Cas 2 : couple �ligible � l'Asi */
	else if nb_elig_asi ne 0 and en_couple=1 and rev_tot_asi<&asi_plfc. then do;
		/* Cas 2.1 : 1 seul �ligible � l'Asi (la condition age>age2	sert � s�lectionner l'individu le plus �g�)*/
		if nb_elig_asi=1 then asi=(age>age2)*min(&asi_m1.,&asi_plfc.-rev_tot_asi); 	
		/* Cas 2.2 : 2 �ligibles � l'Asi (circulaire, paragraphe 131) */
		else if nb_elig_asi=2 then do;
	 		if mcdvo1='M' ! mcdvo2='M' then asi=min(&asi_m2.,&asi_plfc.-rev_tot_asi)/2;
			else asi=min(2*&asi_m1.,&asi_plfc.-rev_tot_asi)/2;
	  		end;
		end;
	label asi="Montant d'Asi";

	/****************************************/
	/* E. Interaction ASPA/ASI				*/
	/****************************************/
	/* Cette partie concerne les couples o� l'un est �ligible � l'ASI et l'autre � l'ASPA */
	/* Voir circulaire n� 2007/15 du 1er f�vrier 2007 de la CNAV, paragraphe 241 */
	if nb_elig_aspa=1 & nb_elig_asi=1 then do;
		/* Si le couple est mari�, le montant maximum "deux allocataires" � retenir pour le calcul est �gal � la somme 
		de la moiti� du montant maximum "couple" d'ASPA et de la moiti� du montant maximum "couple" d'ASI. */
		if mcdvo1='M' ! mcdvo2='M' then do;
			if elig_aspa_asi=1 then aspa=min((&asi_m2.+&mv_mi.)/2,(&asi_plfc.+&mv_plfc.)/2-rev_tot_aspa_abat)/2;
			if elig_aspa_asi=2 then asi=min((&asi_m2.+&mv_mi.)/2,(&asi_plfc.+&mv_plfc.)/2-rev_tot_asi)/2;
			end;
		/* Pour les concubins et pacs�s, il s'agit du montant maximum d'ASI "personne seule" */
		else do; 
			if elig_aspa_asi=1 then aspa=min(2*&asi_m1.,&asi_plfc.-rev_tot_aspa_abat)/2;
			if elig_aspa_asi=2 then asi=min(2*&asi_m1.,&asi_plfc.-rev_tot_asi)/2;
			end;
		end;

	/* Le mode de calcul ici permet des montants n�gatifs. On met � 0 dans ce cas. */
	aspa=max(aspa,0);
	asi=max(asi,0);
	run;

proc sort data=Aspa_asi(keep=ident noi aspa asi rev_tot_aspa_abat rev_tot_asi); by ident noi; run; 
proc sort data=modele.baseind; by ident noi; run;
data modele.baseind;
	merge modele.baseind
		  Aspa_asi (in=a);
	by ident noi;
	if not a then do; 
		aspa=0;
		asi=0;
		end;
	run;
%mend;
%aspa_asi;

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
