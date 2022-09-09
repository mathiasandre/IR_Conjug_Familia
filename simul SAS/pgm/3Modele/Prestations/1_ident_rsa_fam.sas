*************************************************************************************;
/*																					*/
/*								ident_rsa_fam										*/
/*																					*/
*************************************************************************************;

/* Construction des familles pour le rsa et les prestations familiales  */
/* En entrée : 	modele.baseind											*/
/*				base.baserev                	      					*/
/* En sortie : 	modele.baseind                                     		*/


/* On cherche ici à calculer les numéros de famille à partir de l'enquête emploi. 
On enrichit baseind d'un numéro ident_fam mais pas plus 
Les infos au niveau famille, nb enfant, etc, sont calculées ailleurs */

/* TODO : en cas de divorce ou de décès, retirer les ressources du conjoint parti
+ faire en sorte qu'il ne soit pas de la même famille (car s'ils sont encore 2 dans l'EE au T4, noicon non vide)

TODO 2 : tester une correction de l'absence des FIP mineurs dans les familles 
par reponderation des enfants mineurs 'enquete Emploi' sur les pyramides des ages */

/****************************************************************/
/* 1	Construction d'une base individuelle avec un revenu net */
/****************************************************************/
proc sort data=modele.baseind
			(keep=ident noi quelfic declar1 naia naim wpela&anr2. sexe noicon lprm noiper noimer noienf01 enf_1
			where=(quelfic ne 'FIP'))
			out=baseind;
	by ident noi;
	run;
proc sort data=base.baserev
			(keep=ident noi zsali&anr. zragi&anr. zrici&anr. zrnci&anr. zchoi&anr. zrsti&anr. zpii&anr. zalri&anr. zrtoi&anr.)
			out=baserev;
	by ident noi;
	run;
data ind_revnet (keep=ident noi quelfic declar1 naia naim wpela&anr2. sexe noicon lprm noiper noimer noienf01 enf_1 revnet&anr. noidec); 
	merge 	baseind (in=a) 
			baserev;
	by ident noi;
	if a;
	format noidec $2.; 
	noidec=substr(declar1,9,2);
	revnet&anr.=(zsali&anr.+zragi&anr.+zrici&anr.+zrnci&anr.)*(1-(&b_tcsgi.+&b_tcrds.))
				+zchoi&anr.*(1-(&b_tcsgCHi.+&b_tcrdsCH.)/(1-&b_tcocrCH.-&b_tcsgCHd.))
				+(zrsti&anr.+zpii&anr.)*(1-(&b_tcsgPRi.+&b_tcrdsPR.)/(1-&b_tcomaPR.-&b_tcsgPRd1.))
				+(zalri&anr.+zrtoi&anr.);
	run;

/************************/
/* 2	Gestion des FIP */
/************************/

/* 	FIP majeurs : correspondent a des jeunes en logement independant, ou a des enfants a la maison non présents dans l'EE
	Dans tous les cas, ils peuvent compter pour les PF et le rsa s'ils sont en dessous de l'âge limite des personnes à charges.
	On attribue ces enfants à leur déclarant fiscal. 
	FIP mineurs : plutot des enfants de parents separés qui habitent chez un autre parent
	On ne les considère pas comme appartenant aux familles définies ici (au sens rsa, famille ou logement)
	On pourrait les corriger par reponderation des enfants mineurs 'enquete Emploi' sur les pyramides des ages */
/* NB : les FIP à charge plus ages sont souvent des ascendants voire invalides et sans lien de parente */
proc sort data=modele.baseind; by ident noi; run;
data fip;
	set modele.baseind(keep=ident naia noi quelfic persfip persfipd declar1 wpela&anr2.);
	by ident noi;
	if quelfic='FIP' & persfip='pac' 
		& &anref.-input(naia,4.)< &age_rsa_l.
		& &anref.-input(naia,4.) >=18;
	/* un peu moins de la moitié des FIP */
	format noidec $2.;
	noidec=substr(declar1,1,2);	/* égal au noi mais il n'y en a qu'un par ménage */
	run;

proc sort data=ind_revnet
			(keep=ident noi sexe noicon lprm noiper noimer noienf01 enf_1 wpela&anr2. revnet&anr.
			rename=(noi=noidec noicon=noicondec lprm=lprmdec sexe=sexedec));
	by ident noidec;
	run;
proc sort data=fip;
	by ident noidec;
	run;

data fip	(drop=noidec noicondec lprmdec sexedec);
	merge 	fip(in=a) 
			ind_revnet(in=b);
	by ident noidec; 
	if a & b;
	format noiper noimer $2.;
	if lprmdec in ('1','2') then lprm='3';
		else lprm='4';
	if sexedec='1' then do;
		noiper=noidec;
		if noicondec^='' then noimer=noicondec;
		end;
	else do;
		noimer=noidec;
		if noicondec^='' then noiper=noicondec;
		end;
	noienf01=''; noicon='';
	run;


/***************************************/
/* 3	ATTRIBUTION D'UN NUMERO DE RSA */
/***************************************/

data ident_rsa; 
	set baseind fip;
	array num _numeric_; 
	do over num; 
		if num=. then num=0; 
		end; 
	run;

/* On classe les enfants après leurs parents */
proc sort data=ident_rsa; by ident naia; run;

data ident_rsa;
	set ident_rsa; 
	by ident;
	format ident_rsa $10.;
	agexx=&anref.-input(naia,4.); 
	label agexx='age au 31/12';

	/* vect_nf(i) donne le numéro de famille (nf) de la i-eme personne du ménage */
	array vect_nf 		nf1-nf20;
	array vect_noi 		noi1-noi20;
	array vect_noicon 	noicon1-noicon20;

	retain nf nfpr nf1-nf20 noi1-noi20 noicon1-noicon20;
	if first.ident then do;
		%Init_Valeur(nf nfpr); /* nf donne le nombre de familles RSA dans le ménage */
		do i=1 to dim(vect_nf);
			vect_nf(i)=0; vect_noi(i)=0;
			vect_noicon(i)=0;
			end;
		end;

	/* On construit une variable attrib qui prend les valeurs suivantes : 
		1_ personne sans conjoint
		2_ conjoint
		3_ première personne d'un couple
		4_ enfant dont un des parents est dans le ménage
		5_ jeune de plus de 18 ans sans parent dans le ménage
		6_ jeune de moins de 18 ans sans parent dans le ménage
		7_ jeune dont on identifie la parenté avec les déclarations fiscales */

	attrib=0;
	/* 1_ personne sans conjoint */
	if attrib=0 & noicon='' then do;
		if agexx>=&age_rsa_l. or noienf01^='' then do;
			nf=nf+1;
			vect_nf(nf)=nf; 
			vect_noi(nf)=input(noi,2.);
			ident_rsa=cats(ident,'0',nf);
			attrib=1;
			end;
		end;

	/* 2_ conjoint */
	*on teste d'abord si c'est le 2ème conjoint, car dans ce cas il ne faut pas incrémenter nf;
	do i=1 to dim(vect_noi);
	    if attrib=0 & input(noi,2.)=vect_noicon(i) then do;
			ident_rsa=cats(ident,'0',vect_nf(i));
			attrib=2;
			end;
		end;

	/* 3_ première personne d'un couple */
	if attrib=0 & noicon^='' then do;
		nf=nf+1;
		vect_nf(nf)=nf; 
		vect_noi(nf)=input(noi,2.);
		vect_noicon(nf)=input(noicon,2.);
		ident_rsa=cats(ident,'0',nf);
		attrib=3;
		end;

	/* 4_ enfant dont un des parents est dans le ménage y compris enfants à naitre */
	*attention : ne pas mettre attrib=0, car peuvent compter à charge les enfants en couple
	 or toutes les personnes en couple ont attrib=1 à ce stade du programme;
	if (agexx<&age_rsa_l. & noienf01='') ! enf_1=1 then do;
		do i=1 to dim(vect_noi);
			if attrib=0 & (input(noiper,2.)=vect_noi(i) or input(noiper,2.)=vect_noicon(i) 
						 or input(noimer,2.)=vect_noi(i) or input(noimer,2.)=vect_noicon(i) or enf_1=1) 
				then do;
				ident_rsa=cats(ident,'0',vect_nf(i));
				attrib=4;
				end;
			end;
		end;

	/* noi de la personne de référence du ménage */
	if lprm in('1','2') & agexx>=18 then nfpr=nf;

	/* Autres */
	/* 5_ jeune de plus de 18 ans sans parent dans le ménage */ 
	if attrib=0 then do;
		if agexx>=18 then do;
			nf=nf+1;
			ident_rsa=cats(ident,'0',nf);
			attrib=5;
			end;
		else do;
	/* 6_ jeune de moins de 18 ans sans parent dans le ménage */
			ident_rsa=ident!!'99';
			attrib=6;
			end;
		end;

	*********************************;
	/* 7_ jeune dont on identifie la parenté avec les déclarations fiscales */
	* Cela permet d'identifier une petite centaine de personnes; 
	if quelfic='EE&FIP' & (agexx<&age_rsa_l. & noienf01='') & (attrib=5 or attrib=6) then do; 
		do i=1 to dim(vect_noi);
			if input(substr(declar1,1,2),2.)=vect_noi(i) then do; 
				ident_rsa=cats(ident,'0',vect_nf(i));
				attrib=7;
				end;
			end;
		end;

	if (attrib=4 & enf_1^=1) or attrib=7 then statut_rsa='pac';
	run;

proc sql;
	create table ident_rsa2 as
	select *, max(nf)+1 as suivant from ident_rsa group by ident order by ident, ident_rsa;
	quit;

/* Construction de ident_fam à partir de ident_rsa */
data ident_fam;
	set ident_rsa2;
	by ident ident_rsa;
	retain nb01 nb 0;
	if first.ident then do;
		nb=suivant;
		nb01=suivant;
		end;
	ident_fam=ident_rsa;
	ident_fam01=ident_rsa;
	statut_fam=statut_rsa;
	/* Deux conditions ci-dessous décalées d'un an selon que l'on s'intéresse au 01/01 ou au 31/12 de l'année */
	if (agexx>&age_pl.+1 or revnet&anr.>&plaf_exclu_pac.) & (attrib=4 & enf_1^=1) then do;
		ident_fam01=cats(ident,'0',nb01);
		if quelfic ='FIP' then ident_fam01='';
		nb01=nb01+1;
		end;
	if (agexx>&age_pl. or revnet&anr.>&plaf_exclu_pac.) & (attrib=4 & enf_1^=1) then do;
		ident_fam=cats(ident,'0',nb);
		if quelfic ='FIP' then ident_fam='';
		statut_fam='';
		nb=nb+1;
		end;
	run;

proc sort data=ident_fam; by ident_fam descending agexx descending naim;
data ident_fam;
	set ident_fam(drop=noi1);
	by ident_fam;
	retain attrib1 attrib2 agemon agemad noi1 0;
	if first.ident_fam then do;
		%Init_Valeur(attrib1 attrib2 agemon agemad noi1);
		end;
	if attrib1=0 then do;
		if sexe='1' then do; civ='mon'; agemon=agexx; end;
		if sexe='2' then do; civ='mad'; agemad=agexx; end;
		noi1=input(noi,2.);
		attrib1=1;
		end;
	else if attrib2=0 & input(noicon,2.)=noi1 then do;
		if sexe='1' then civ='mon';
		if sexe='2' then civ='mad';
		if agemon=0 then agemon=agexx;
		if agemad=0 then agemad=agexx;
		/* il ne faut pas différencier par sexe, sinon on écrase la 1ère valeur pour un couple homosexuel */
		attrib1=1;
		end;
	if substr(ident_fam,9,2)='99' then do; if sexe='1' then civ='mon'; else civ='mad'; end;
	run;


/* Enregistrement dans modele.baseind */
proc sort data=ident_fam nodupkey dupout=voir; by ident noi;  run;
proc sort data=modele.baseind; by ident noi;run;
data modele.baseind;
	merge 	modele.baseind (in=a)
			ident_fam(keep = ident: noi civ statut: in=b) ; 
	by ident noi;
	if a;
	label 	ident_fam01 ="Identifiant famille au sens des PF au 01/01 "
			ident_fam   ="Identifiant famille au sens des PF au 31/12 "
			ident_rsa   ="Identifiant famille au sens du RSA au 31/12 ";
	run;

proc delete data=baseind baserev fip ind_revnet voir ident_rsa ident_rsa2 ident_fam; run;


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
