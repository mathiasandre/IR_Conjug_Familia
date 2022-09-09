*************************************************************************************;
/*																					*/
/*								BOURSES												*/
/*																					*/
*************************************************************************************;

/* Attribution des bourses											*/
/* En entr�e : base.baserev
			   modele.baseind
			   modele.rev_imp&anr1.
			   base.menage&anr2.									*/
/* En sortie : modele.bourses                                     	*/

/* 
Plan
A. Pr�paration des donn�es n�cessaires
B. Calcul des bourses de coll�ge 
C. Calcul des bourses de lyc�e 
*/

/* 
POINT LEGISLATION
Les bourses sont attribu�es pour une ann�e scolaire sous conditions de ressources en 
fonction des charges des familles ou du repr�sentant l�gal de l'�l�ve.
Les ressources et le nombre d'enfants � charge sont justifi�s par l'avis d'imp�t sur le revenu. 
Le dossier de demande de bourse compl�t� par la famille ou le repr�sentant l�gal de l'�l�ve est remis
au chef d'�tablissement. Ce dossier comprend une feuille de renseignements concernant l'�l�ve 
et son repr�sentant l�gal, l'avis d'imp�t sur le revenu ainsi qu'un relev� d'identit� 
bancaire ou postal. 
Le revenu fiscal de r�f�rence figurant sur l'avis d'imp�t retenu est 
celui de l'ann�e n-2, n d�signant l'ann�e de rentr�e scolaire au titre de laquelle 
la demande de bourse est formul�e. 
En cas de modification de la situation familiale ayant 
entra�n� une diminution de ressources depuis l'ann�e de r�f�rence n-2, les revenus de 
l'ann�e n-1 pourront �tre pris en consid�ration.

ECART A LA LEGISLATION : on ne fait pas attention au fait que le niveau de l'enfant 
est bien celui de la rentr�e de l'ann�e n, du reste, pour certains, on n'a pas l'info */

/* Dans ce programme, principe de simplicit� */ 

/******************************************/
/* A. Pr�paration des donn�es n�cessaires */
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
	if e_col=0 then e_col=_7ea;/*case fiscale donnant le Nb d'enfants � charges au coll�ge*/
	if e_lyc=0 then e_lyc=_7ec;/*case fiscale donnant le Nb d'enfants � charges au lyc�e*/

/************************************/
/* B. Calcul des bourses de coll�ge */
/************************************/

if e_col>0 then do;
		if RFR<&bcol_l3.*(1+&bcol_lec.*enfcha) then bourse_col=e_col*&bcol_m3.*&bmaf.; 
		if RFR<&bcol_l2.*(1+&bcol_lec.*enfcha) then bourse_col=e_col*&bcol_m2.*&bmaf.; 
		if RFR<&bcol_l1.*(1+&bcol_lec.*enfcha) then bourse_col=e_col*&bcol_m1.*&bmaf.; 
end;

/************************************/
/* C. Calcul des bourses de lyc�e   */
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
		* candidat boursier d�j� scolaris� en coll�ge et lyc�e ou y acc�dant � la rentr�e;
		nbpoint=nbpoint+2 ;
		* parent isol�;
		nbpoint=nbpoint+3*(case_t='T');
		* les 2 parents sont salari�s;
		nbpoint=nbpoint+1*(acti=2);	 
		* le conjoint per�oit l'AAH et n'exerce pas d'activit� professionnelle;
		nbpoint=nbpoint+1*(ind_aah>0); 
		* hypoth�se: aucun enfant invalide sans aeeh;
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
		* on pourrait mettre la prime au m�rite avec un tirage au sort si on voulait;
		if part>0 then do;
			p_equip	=d_equip *&blyc_m2.;
			p_qualif=d_qualif*&blyc_m3.;
		    p_entr	=d_entr  *&blyc_m4.;
		end;
	end;

	
/* R�forme des bourses de lyc�e � partir de 2016 
Il y a 6 �chelons pour les boursiers. Pour d�terminer cet �chelon : 
on compare le RFR (ann�e N-2) � un plafond de ressources qui augmente avec le Nb d'enfants � charge pour chaque �chelon.
Pour limiter le nombre de param�tres � mobiliser afin de d�terminer ces plafonds, on utilise la r�gle (empirique) suivante :

	- 1 enfant � charge, on ne majore pas le plafond de ressources quelque soit l'�chelon &i (i=1 � 6)
	- 2 enfants � charge, on majore le plafond de ressources de l'�chelon &i d'un taux "blyc_tx&i." 
	- 3 enfants � charge, on majore le plafond de ressources de l'�chelon &i d'un taux "3*blyc_tx&i." 
	- 4 enfants � charge :
			--> on majore le plafond de ressources de l'�chelon 1 d'un taux "5.5*blyc_tx1" 
			--> on majore le plafond de ressources de l'�chelon &i (i=2 � 6) d'un taux "5*blyc_tx&i."
	- 5 enfants � charge : on majore le plafond de ressources de l'�chelon &i d'un taux "8*blyc_tx&i."
	- 6 enfants � charge, on majore le plafond de ressources de l'�chelon &i d'un taux "11*blyc_tx&i." 
	- 7 enfants � charge, on majore le plafond de ressources de l'�chelon &i d'un taux "14*blyc_tx&i." 
	- 8 enfants � charge ou plus, on majore le plafond de ressources de l'�chelon &i d'un taux "17*blyc_tx&i." 

On calcule donc d'abord coeff_ech1 qui sera le coeff multiplicateur du taux blyc_tx1 pour l'�chelon 1 selon le Nb d'enfants.
On calcule ensuite coeff_ech qui sera le coeff multiplicateur du taux blyc_txi pour les autres �chelons i selon le Nb d'enfants. 
 - coeff_ech1 vaut 0 si 1 enfant � charge, 1 si 2 enfants, 3 si 3 enfants, 5.5 si 4 enfants, ... , 17 si plus de 8 enfants
 - coeff_ech  vaut 0 si 1 enfant � charge, 1 si 2 enfants, 3 si 3 enfants, 5 si 4 enfants, ... , 17 si plus de 8 enfants
Au moment des mises � jour, il faut v�rifier si ces coefficients restent inchang�s ou non. (en 2017, ils seront inchang�s)

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
	/*On s'ennuit avec e_col et e_lyc parce que l'unit� de modele.bourses est le foyer 
	et non l'individu et qu'on peut avoir plusieurs enfants boursiers par foyer.*/ 
run;

/*stats: proc freq data=modele.baseind; table niv; weight wpela10; run; */


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
