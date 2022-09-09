*************************************************************************************;
/*																					*/
/*								BOURSES												*/
/*																					*/
*************************************************************************************;

/* Attribution des bourses											*/
/* En entrée : base.baserev
			   modele.baseind
			   modele.rev_imp&anr1.
			   base.menage&anr2.									*/
/* En sortie : modele.bourses                                     	*/

/* 
Plan
A. Préparation des données nécessaires
B. Calcul des bourses de collège 
C. Calcul des bourses de lycée 
*/

/* 
POINT LEGISLATION
Les bourses sont attribuées pour une année scolaire sous conditions de ressources en 
fonction des charges des familles ou du représentant légal de l'élève.
Les ressources et le nombre d'enfants à charge sont justifiés par l'avis d'impôt sur le revenu. 
Le dossier de demande de bourse complété par la famille ou le représentant légal de l'élève est remis
au chef d'établissement. Ce dossier comprend une feuille de renseignements concernant l'élève 
et son représentant légal, l'avis d'impôt sur le revenu ainsi qu'un relevé d'identité 
bancaire ou postal. 
Le revenu fiscal de référence figurant sur l'avis d'impôt retenu est 
celui de l'année n-2, n désignant l'année de rentrée scolaire au titre de laquelle 
la demande de bourse est formulée. 
En cas de modification de la situation familiale ayant 
entraîné une diminution de ressources depuis l'année de référence n-2, les revenus de 
l'année n-1 pourront être pris en considération.

ECART A LA LEGISLATION : on ne fait pas attention au fait que le niveau de l'enfant 
est bien celui de la rentrée de l'année n, du reste, pour certains, on n'a pas l'info */

/* Dans ce programme, principe de simplicité */ 

/******************************************/
/* A. Préparation des données nécessaires */
/******************************************/

data indivi(keep=ident noi acti agri revnet&anr1);
	set base.baserev;
	acti=(zsali&anr1.>0);
	agri=(zragi&anr1.>0);
	revnet&anr1.=(zsali&anr1.+zragi&anr1.+zrici&anr1.+zrnci&anr1.)*(1-(&b_tcsgi.+&b_tcrds.))
				+zchoi&anr1.*(1-(&b_tcsgCHi.+&b_tcrdsCH.)/(1-&b_tcocrCH.-&b_tcsgCHd.))
				+(zrsti&anr1.+zpii&anr1.)*(1-(&b_tcsgPRi.+&b_tcrdsPR.)/(1-&b_tcomaPR.-&b_tcsgPRd1.))
				+(zalri&anr1.+zrtoi&anr1.);
run;

proc sort data=indivi; by ident noi; run; 
proc sort data=modele.baseind(keep=ident noi aah declar1 niv form) out=baseind; by ident noi; run;
data baseind; 
	merge baseind 
		  indivi; 
	by ident noi; 
run;

data aah(keep=ident noi ind_aah declar1 lyctech lycpro d_: e_col e_lyc acti agri);
	set baseind;
	alea=ranuni(3);
	ind_aah	=(aah>0 & revnet&anr1=0);
	lyctech	=(form in ('31','32'));
	lycpro	=(form in ('22','25','27','29','30','34','36','37'));
	d_equip	=(form in ('22'));
	d_qualif=(form in ('22','25','27'));
	d_entr	=(form in ('16','17','30','31','32','34','36','37')) & alea>&tx_redoubl_lyc.;
	e_col	=(niv='col');
	e_lyc	=(niv='lyc');
run;

proc means data=aah noprint nway;
	class declar1; 
	var acti agri ind_aah lyctech lycpro d_equip d_qualif d_entr e_col e_lyc; 
	output out=inf_indiv(drop=_type_ _freq_) sum=;
run;
proc sort data=modele.rev_imp&anr1.(keep=declar ident RFR nbf nbj nbr case_t) 
	out=foyer; 
	by declar;
run;
proc sort data=base.foyer&anr1.(keep=declar ident _7ea _7ec) 
	out=foyerbase; 
	by declar;
run;

data bourses(keep=declar ident bourse_lyc bourse_col part e_col e_lyc _7ea _7ec); 
	merge 	inf_indiv(in=a rename=(declar1=declar)) 
			foyerbase
			foyer(in=b); 
	by declar; 
	if a and b;
	enfcha=sum(0,nbf,nbj);
	if e_col=0 then e_col=_7ea;/*case fiscale donnant le Nb d'enfants à charges au collège*/
	if e_lyc=0 then e_lyc=_7ec;/*case fiscale donnant le Nb d'enfants à charges au lycée*/

/************************************/
/* B. Calcul des bourses de collège */
/************************************/

if e_col>0 then do;
		if RFR<&bcol_l3.*(1+&bcol_lec.*enfcha) then bourse_col=e_col*&bcol_m3.*&bmaf.; 
		if RFR<&bcol_l2.*(1+&bcol_lec.*enfcha) then bourse_col=e_col*&bcol_m2.*&bmaf.; 
		if RFR<&bcol_l1.*(1+&bcol_lec.*enfcha) then bourse_col=e_col*&bcol_m1.*&bmaf.; 
end;

/************************************/
/* C. Calcul des bourses de lycée   */
/************************************/

if e_lyc>0 then do;
	 
		p_entr=0; 
		p_qualif=0; 
		p_equip=0;

	if &anleg.<=2015 then do ;

		part=0;

		* Nombre de points selon le nombre enfants;
		nbpoint=9*(enfcha>=1)+1*(enfcha>=2)+2*(enfcha>=3)+2*(enfcha>=4)+
				3*(enfcha-4)*(enfcha>4);
		* Supplements de points;
		* candidat boursier déjà scolarisé en collège et lycée ou y accédant à la rentrée;
		nbpoint=nbpoint+2 ;
		* parent isolé;
		nbpoint=nbpoint+3*(case_t='T');
		* les 2 parents sont salariés;
		nbpoint=nbpoint+1*(acti=2);	 
		* le conjoint perçoit l'AAH et n'exerce pas d'activité professionnelle;
		nbpoint=nbpoint+1*(ind_aah>0); 
		* hypothèse: aucun enfant invalide sans aeeh;
		nbpoint=nbpoint+0;			   
		* ascendant invalide;
		nbpoint=nbpoint+1*(nbr>0);

		if      RFR/nbpoint<&blyc_l1. then part=10;
		else if RFR/nbpoint<&blyc_l2. then part=9;
		else if RFR/nbpoint<&blyc_l3. then part=8;
		else if RFR/nbpoint<&blyc_l4. then part=7;
		else if RFR/nbpoint<&blyc_l5. then part=6;
		else if RFR/nbpoint<&blyc_l6. then part=5;
		else if RFR/nbpoint<&blyc_l7. then part=4;
		else if RFR/nbpoint<&blyc_l8. then part=3;

		* Ajout des parts supplementaires;
		if part>0 then part=part+ 2*(agri>0)+2*(lyctech>0) + 2*(lycpro>0);	
		bourse_lyc=e_lyc*(part*&blyc_m1.);

		* Ajout des primes;
		* on pourrait mettre la prime au mérite avec un tirage au sort si on voulait;
		if part>0 then do;
			p_equip	=d_equip *&blyc_m2.;
			p_qualif=d_qualif*&blyc_m3.;
		    p_entr	=d_entr  *&blyc_m4.;
		end;
	end;

	
/* Réforme des bourses de lycée à partir de 2016 
Il y a 6 échelons pour les boursiers. Pour déterminer cet échelon : 
on compare le RFR (année N-2) à un plafond de ressources qui augmente avec le Nb d'enfants à charge pour chaque échelon.
Pour limiter le nombre de paramètres à mobiliser afin de déterminer ces plafonds, on utilise la règle (empirique) suivante :

	- 1 enfant à charge, on ne majore pas le plafond de ressources quelque soit l'échelon &i (i=1 à 6)
	- 2 enfants à charge, on majore le plafond de ressources de l'échelon &i d'un taux "blyc_tx&i." 
	- 3 enfants à charge, on majore le plafond de ressources de l'échelon &i d'un taux "3*blyc_tx&i." 
	- 4 enfants à charge :
			--> on majore le plafond de ressources de l'échelon 1 d'un taux "5.5*blyc_tx1" 
			--> on majore le plafond de ressources de l'échelon &i (i=2 à 6) d'un taux "5*blyc_tx&i."
	- 5 enfants à charge : on majore le plafond de ressources de l'échelon &i d'un taux "8*blyc_tx&i."
	- 6 enfants à charge, on majore le plafond de ressources de l'échelon &i d'un taux "11*blyc_tx&i." 
	- 7 enfants à charge, on majore le plafond de ressources de l'échelon &i d'un taux "14*blyc_tx&i." 
	- 8 enfants à charge ou plus, on majore le plafond de ressources de l'échelon &i d'un taux "17*blyc_tx&i." 

On calcule donc d'abord coeff_ech1 qui sera le coeff multiplicateur du taux blyc_tx1 pour l'échelon 1 selon le Nb d'enfants.
On calcule ensuite coeff_ech qui sera le coeff multiplicateur du taux blyc_txi pour les autres échelons i selon le Nb d'enfants. 
 - coeff_ech1 vaut 0 si 1 enfant à charge, 1 si 2 enfants, 3 si 3 enfants, 5.5 si 4 enfants, ... , 17 si plus de 8 enfants
 - coeff_ech  vaut 0 si 1 enfant à charge, 1 si 2 enfants, 3 si 3 enfants, 5 si 4 enfants, ... , 17 si plus de 8 enfants
Au moment des mises à jour, il faut vérifier si ces coefficients restent inchangés ou non. (en 2017, ils seront inchangés)

*/

	if &anleg.>=2016 then do;

coeff_ech1=(enfcha>=2)+2*(enfcha>=3)+2.5*(enfcha>=4)+2.5*(enfcha>=5)+3*((enfcha>=6)+(enfcha>=7)+(enfcha>=8));
coeff_ech=(enfcha>=2)+2*((enfcha>=3)+(enfcha>=4))+3*((enfcha>=5)+(enfcha>=6)+(enfcha>=7)+(enfcha>=8)) ;
	
if RFR<&blyc_p1.*(1+&blyc_tx1.*coeff_ech1) then bourse_lyc=e_lyc*&blyc_mont1. ; 
if RFR<&blyc_p2.*(1+&blyc_tx2.*coeff_ech) then bourse_lyc=e_lyc*&blyc_mont2. ; 
if RFR<&blyc_p3.*(1+&blyc_tx3.*coeff_ech) then bourse_lyc=e_lyc*&blyc_mont3. ; 
if RFR<&blyc_p4.*(1+&blyc_tx4.*coeff_ech) then bourse_lyc=e_lyc*&blyc_mont4. ; 
if RFR<&blyc_p5.*(1+&blyc_tx5.*coeff_ech) then bourse_lyc=e_lyc*&blyc_mont5. ; 
if RFR<&blyc_p6.*(1+&blyc_tx6.*coeff_ech) then bourse_lyc=e_lyc*&blyc_mont6. ; 

	* Ajout des primes;
		if bourse_lyc>0 then do;
			p_equip	=d_equip *&blyc_m2.;
			p_qualif=d_qualif*&blyc_m3.;
		    p_entr	=d_entr  *&blyc_m4.;
		end;
	end;

end;

	array tout _numeric_; 
	do over tout; 
		if tout=. then tout=0; 
		end;
	bourse_lyc=sum(bourse_lyc,p_equip,p_qualif,p_entr);
run;

proc sort data=bourses;by ident; run; 
data modele.bourses; 
	merge 	bourses 
			base.menage&anr2.(keep=ident wpela&anr2);
	by ident;
	if bourse_lyc=. then bourse_lyc=0;
	if bourse_col=. then bourse_col=0;
	if bourse_lyc=0 then e_lyc=0; 
	if bourse_col=0 then e_col=0; 
	/*On s'ennuit avec e_col et e_lyc parce que l'unité de modele.bourses est le foyer 
	et non l'individu et qu'on peut avoir plusieurs enfants boursiers par foyer.*/ 
run;

/*stats: proc freq data=modele.baseind; table niv; weight wpela10; run; */


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
