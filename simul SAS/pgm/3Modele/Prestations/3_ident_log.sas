/************************************************************************/
/*																		*/
/*								3_ident_log								*/
/*																		*/
/************************************************************************/

/* Création de ident_log											 	*/
/* En entrée : modele.baseind base.baserev								*/
/* En sortie : modele.baseind                                     		*/
/************************************************************************/

/* On part ici du calcul des familles pour établir un calcul des "logements" au sens des 
allocations logements. Cette notion est très proche du foyer familial au sens de la CNAF, 
la différence est que les ascendants de plus de 65 ans peuvent faire partie du ménage 
ainsi que les handicapés */



/*liste des potentiels ascendants pouvant être regroupés */

proc sort data=modele.baseind(keep=	ident noi declar1 naia naim quelfic wpela&anr2. sexe noicon lprm 
			noiper noimer noienf01 handicap ident_fam elig_aspa_asi where=(quelfic ne 'FIP'))
			out=ee;
	by ident_fam;
	run;
data uc(keep=ident_fam aduc enfuc);
	set ee;
	by ident_fam;
	retain aduc enfuc;
	if first.ident_fam then do;aduc=0;enfuc=0;end;
	if &anref.-input(naia,4.)>=14 then aduc=aduc+1;
	else if &anref.-input(naia,4.)>-1 then enfuc=enfuc+1;
	if last.ident_fam;
	run;
data ee; merge ee uc; by ident_fam;run;
proc sort data=ee; by ident noi; run;

/* on récupère aussi l'âge du conjoint éventuel et son éligibilité à l'ASPA ou à l'ASI */
proc sort data=ee ; by ident noi ; run ;
proc sort data=ee out=ee2(keep=ident noicon naia elig_aspa_asi where=(noicon>"")) ; by ident noicon ; run ;
data ee3 ; 
	merge ee
		  ee2 (rename=(noicon=noi naia=naiacon elig_aspa_asi=elig_aspa_asi_con)) ; 
	by ident noi ;
run ;

data revnet(keep=ident noi revnet&anr.);
	set base.baserev;
	revnet&anr.=(zsali&anr.+zragi&anr.+zrici&anr.+zrnci&anr.)*(1-(&b_tcsgi.+&b_tcrds.))
				+zchoi&anr.*(1-(&b_tcsgCHi.+&b_tcrdsCH.)/(1-&b_tcocrCH.-&b_tcsgCHd.))
				+(zrsti&anr.+zpii&anr.)*(1-(&b_tcsgPRi.+&b_tcrdsPR.)/(1-&b_tcomaPR.-&b_tcsgPRd1.))
				+(zalri&anr.+zrtoi&anr.);
	run;
proc sort data=revnet; by ident noi; run;
data ee; merge ee3(in=a) revnet; by ident noi; if a; run;

/*On regarde les vieux ou eligibles à l'asi vivent avec un de leurs enfants, et on 
regarde si ces ascendants potentiellement rattachables à la famille au sens des AL sont
bien seuls ou en couple et sans enfants dans leur propre famille*/

/* Correctif juin 2017 - On rattache les ascendants et leur conjoint éventuel uniquement s'ils sont tous deux éligibles à l'ASPA 
		(y compris s'ils ont plus de 65 ans)
Condition : "ascendant de plus de 65 ans (ou 60 ans, s'il est inapte au travail, ancien déporté ou ancien combattant)
et ne disposant pas de ressources supérieures au plafond de l'allocation de solidarité aux personnes âgées (Aspa)"
Par approximation, on rattache tous les ascendants de plus de 60 ans éligibles à l'ASPA ou l'ASI (elig_aspa_asi>=1),
(et à condition qu'ils n'aient pas de conjoint de moins de 60 ans ou n'ayant pas droit à l'ASPA ou l'ASI)
*/

data fam_asc; 
	set ee(keep=ident noi revnet&anr noienf01 naia naiacon lprm ident_fam handicap noicon elig_aspa_asi elig_aspa_asi_con aduc enfuc); 
	if noienf01 ne ''
	 &(&anref.-input(naia,4.)>=60 and elig_aspa_asi>=1)
	 &(noicon='' or &anref.-input(naiacon,4.)>=60 and elig_aspa_asi_con>=1)
	 & aduc= 1+(noicon ne '') 
	 & enfuc=0 ;
	run;

/*on recherche la famille de leur enfant avec qui ils habitent (noienf01) 
et qui doit devenir la "famille du logement" des ascendants */
proc sort data=fam_asc(rename=(ident_fam=ident_famasc)); by ident noienf01; run;
data ascendants; 
	merge 	ee(keep=ident noi ident_fam rename=(noi=noienf01 ident_fam=ident_log))
			fam_asc(in=a);
	by ident noienf01;
	if a;
	/*on vérifie que les enfants sont bien dans une autre famille*/
	if ident_log ne ident_famasc & ident_log ne '';
	run;

/*pour le handicap*/

data handicap_potentiel;
	set ee(keep=ident noi revnet&anr. noienf01 naia lprm ident_fam handicap noicon aduc);
	if handicap ne 0 & noicon='' & aduc=1;
	run;

/*on ne garde que les handicapés qui habitent un logement avec au moins 2 familles*/
proc sort data=handicap_potentiel; by ident noi; run;
proc sort data=ee; by ident ident_fam; run;
data vit_avec_handicape;
	merge 	handicap_potentiel(in=a)
			ee;
	by ident;
	if a;
	run;
proc sort data=vit_avec_handicape; by ident ident_fam; run;
data menages_avec_handicape;
	set vit_avec_handicape;
	by ident ident_fam ;
	length id id1 $10.;
	retain nb id id1;
	if first.ident then do;
		id=ident_fam;
		nb=1;
		id1=ident_fam;
		end;
	if ident_fam ne id then do;
		nb=nb+1;
		id=ident_fam;
		end;
	if last.ident;
	if nb>=2;
	run;

data vit_avec_handicapes_a_charge;
	merge 	menages_avec_handicape(in=a)
			vit_avec_handicape(in=b);
	by ident ;
	if a & b;
	ident_log=id1;
	run;

data handicapes_a_charge;
	merge 	menages_avec_handicape(in=a)
			handicap_potentiel(in=b);
	by ident ;
	if a & b;
	ident_log=id1;
	run;

proc sort data=ascendants(keep=ident noi ident_log); by ident noi; run;
proc sort data=vit_avec_handicapes_a_charge(keep=ident noi ident_log); by ident noi; run;
proc sort data=handicapes_a_charge (keep=ident noi ident_log); by ident noi; run;
proc sort data=modele.baseind; by ident noi; run;
data modele.baseind;
	merge 	modele.baseind(in=a)
			vit_avec_handicapes_a_charge
			handicapes_a_charge(in=b)
			ascendants(in=c);
	by ident noi;
	if a;
	statut_log=statut_fam;
	if b or c then statut_log='pac';
	if ident_log='' then ident_log=ident_fam;
	label ident_log="Identifiant famille au sens des AL au 31/12";
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
