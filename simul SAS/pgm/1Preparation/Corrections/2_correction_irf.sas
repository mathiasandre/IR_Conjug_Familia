/****************************************************************************************/
/*																						*/
/*						2_correction_irf												*/
/*																						*/
/****************************************************************************************/

/****************************************************************************************/
/* Correction de la table emploi (irf) : il y a peu de corrections parce que la table 	*/
/*	emploi est prise comme référence en général.										*/
/****************************************************************************************/
/* PLAN : 																				*/
/* I 	Changement manuel de données (principalement date de naissance)					*/
/* II   Correction automatique des noienf égaux à noi ou noicon							*/
/* III  Correction automatique pour que la relation 'conjoint' soit toujours réciproque.*/
/* IV  	Correction automatique des noienf pour les enfants nés après mars de anref+1	*/
/* V  	Attribution aléatoire d'un mois de naissance lorsqu'il est inconnu				*/
/****************************************************************************************/
/* En entrée : 	travail.irf&anr.e&anr.				                       				*/
/* 				cd.irf&anr.e&anr.t1														*/
/*				cd.irf&anr.e&anr.t2														*/
/*		   		cd.irf&anr.e&anr.t3														*/
/*				rpm.irf&anr.e&anr.t4													*/
/*		    	cd.irf&anr.e&anr1.t1													*/
/*				cd.irf&anr.e&anr1.t2													*/
/*				cd.irf&anr.e&anr1.t3													*/
/* En sortie : 	travail.irf&anr.e&anr.													*/
/****************************************************************************************/



/****************************************************************************************/
/* I 	Changement manuel de données (principalement date de naissance)					*/
/****************************************************************************************/
data travail.irf&anr.e&anr.;
	set travail.irf&anr.e&anr.;
	/* Problème de date de naissance dans l'enquête emploi*/
	if ident='08070476' & noi='02' then naia='1982';
	if ident='09035373' & noi='04' then naia='1985';
	if ident='09081808' & noi='04' then naia='2005';
	if ident='09087410' & noi='03' then naia='2008';
	if ident='10023257' & noi='02' then naia='1995';
	if ident='11093635' & noi='02' then naia='1954';
	if ident='12023304' & noi='02' then naia='1954';
	if ident='12041815' & noi='01' then naia='1982';
	/* Problème de conjoint qui est dans EEC mais est mort et n'est pas dans indivi */
	if ident='09049141' & noi='02' then noicon='';
	if noicon='00' then noicon='';
	if ident='12001110' then noienf01='';
	
	/* Problème de conjoint : la fille et la mère sont déclarées conjoints */
	if ident='14031624'  & noi='01' then noicon='';
	if ident='14031624'  & noi='03' then noicon='02';
	if ident='15025261'  & noi='02' then noicon='';
	if ident='15025261'  & noi='05' then noicon='01';
	if ident='15038677'  & noi='01' then noicon='';
	if ident='15038677'  & noi='03' then noicon='02';
	run; 

	/* Correction pour une variable trimestrielle étrangement renseignée comme '**' ==> on met à vide à la place */
data travail.infos_trim;
	set travail.infos_trim;
	if ident&anr.='14044363' then ancinatm_T220&anr.='';
	run;

/****************************************************************************************/
/* II  Correction automatique des noienf égaux à noi ou noicon							*/
/****************************************************************************************/
/* Correction de noienf absurdes car égaux à noi ou noicon : on utilise noiper et noimer pour corriger */
proc sort data=travail.irf&anr.e&anr.(keep=ident noi:) out=pbNoienf(keep=ident noi noicon noiper noimer noienf:);
	by ident noi;
	run;
proc sort data=pbNoienf (where=(noienf01 ne '' and (input(noienf01,4.)=input(noi,4.) or input(noienf01,4.)=input(noicon,4.))))
	out=menAvecPbNoienf(keep=ident) nodupkey;
	by ident;
	run;
/* Vérifier que EnfAbsent est vide. Sinon il faut une correction manuelle dans ce cas (probablement qu'il n'y a pas d'enfant
	de ce noi dans le ménage) */
data EnfDeMenAvecPbNoienf EnfAbsent;
	merge 	pbNoienf(in=a keep=ident noi noiper noimer where=(noiper ne '' or noimer ne ''))
			menAvecPbNoienf(in=b);
	by ident;
	if b and not a then output EnfAbsent; /* 1 cas pour ERFS 2012 corrigé au dessus */
	if a and b then do;
	if noiper ne '' then substr(noiper,1,1)='0';
	if noimer ne '' then substr(noimer,1,1)='0';
	output EnfDeMenAvecPbNoienf;
	end;
	run;
/* On corrige les noienf des pères */
proc sort data=EnfDeMenAvecPbNoienf(keep=ident noi noiper where=(noiper ne '')) out=EnfAvecPere; by ident noiper; run;
data Peres(keep=ident noi noienf:) SansPere;
	merge pbNoienf (in=a where=(noienf01 ne '' and (input(noienf01,4.)=input(noi,4.) or input(noienf01,4.)=input(noicon,4.))))
		EnfAvecPere(in=b rename=(noi=noienf_ noiper=noi));
	by ident noi;
	retain nbenf 0;
	if first.ident then nbenf=0;
	if a and b then do;
		nbenf=nbenf+1;
		if nbenf=1 then do;	if substr(noienf_,1,1)='0' then substr(noienf01,2,1)=substr(noienf_,2,1); else noienf01=noienf_; end;
		if nbenf=2 then do;	if substr(noienf_,1,1)='0' then substr(noienf02,2,1)=substr(noienf_,2,1); else noienf02=noienf_; end;
		if nbenf=3 then do;	if substr(noienf_,1,1)='0' then substr(noienf03,2,1)=substr(noienf_,2,1); else noienf03=noienf_; end;
		if nbenf=4 then do;	if substr(noienf_,1,1)='0' then substr(noienf04,2,1)=substr(noienf_,2,1); else noienf04=noienf_; end;
		output peres;
		end;
	if not a then output SansPere;
	run;
data peres; set peres; by ident noi; if last.ident; run;
/* On corrige les noienf des mères */
proc sort data=EnfDeMenAvecPbNoienf(keep=ident noi noimer where=(noimer ne '')) out=EnfAvecmere; by ident noimer; run;
data meres(keep=ident noi noienf:) Sansmere;
	merge pbNoienf (in=a where=(noienf01 ne '' and (input(noienf01,4.)=input(noi,4.) or input(noienf01,4.)=input(noicon,4.))))
		EnfAvecmere(in=b rename=(noi=noienf_ noimer=noi));
	by ident noi;
	retain nbenf 0;
	if first.ident then nbenf=0;
	if a and b then do;
		nbenf=nbenf+1;
		if nbenf=1 then do;	if substr(noienf_,1,1)='0' then substr(noienf01,2,1)=substr(noienf_,2,1); else noienf01=noienf_; end;
		if nbenf=2 then do;	if substr(noienf_,1,1)='0' then substr(noienf02,2,1)=substr(noienf_,2,1); else noienf02=noienf_; end;
		if nbenf=3 then do;	if substr(noienf_,1,1)='0' then substr(noienf03,2,1)=substr(noienf_,2,1); else noienf03=noienf_; end;
		if nbenf=4 then do;	if substr(noienf_,1,1)='0' then substr(noienf04,2,1)=substr(noienf_,2,1); else noienf04=noienf_; end;
		output meres;
		end;
	if not a then output Sansmere;
	run;
data meres; set meres; by ident noi; if last.ident; run;

data travail.irf&anr.e&anr.;
	merge 	travail.irf&anr.e&anr. (in=a)
			peres(in=b drop=noienf_)
			meres(in=c drop=noienf_);
	by ident noi;
	if input(noienf01,4.)=input(noicon,4.) then noicon=''; /* In fine si on a encore des incompatibilités, alors c'est noicon qu'on corrige*/
	run;
/* 	ERFS 2011 : 28 cas 
	ERFS 2012 : 288 cas */

/****************************************************************************************/
/* III  Correction automatique pour que la relation 'conjoint' soit toujours réciproque.*/
/****************************************************************************************/
proc sort data=travail.irf&anr.e&anr.(keep=ident noicon noi matri where=(noicon ne '')) out=indivAvecConjoint;
	by ident noicon;
	run;
data pbnoicon pbnoicon2(drop=noicon2); 
	merge 	indivAvecConjoint(in=a) 
			travail.irf&anr.e&anr.(keep=ident noi noicon noienf01 rename=(noicon=noicon2 noi=noicon)) ;
	by ident noicon;
	label noicon2='Conjoint du conjoint';
	if a;
	if noi ne noicon2;
	if input(noienf01,4.)=input(noi,4.) then output pbnoicon2; else output pbnoicon;
	run;
proc sort data=pbnoicon(drop=noicon2 rename=(noi=noicon_ noicon=noi)); by ident noi; run;
data travail.irf&anr.e&anr.;
	merge 	pbnoicon(in=a)
			pbnoicon2(in=b)
			travail.irf&anr.e&anr.;
	by ident noi;
	if a then noicon=noicon_;
	if b then noicon='';
	drop noicon_;
	label noi="Numéro individuel d'identification";
	run;
/* 	ERFS 2011 : 25 cas
	ERFS 2012 : 24 cas 
	ERFS 2016 : 16 cas dans pbnoicon2 et 1 cas dans pbnoicon avant corrections*/

/*De plus, en 2016, il existe un ménage pour lequel les incohérences de noicon ne sont pas corrigées par le programme ci-dessus 
	On corrige à la main*/
%MACRO correction_noicon_2016;
	%IF &anref. = 2016 %THEN %DO;
		DATA travail.irf&anr.e&anr.;
			SET travail.irf&anr.e&anr.;
			IF ident = '16003051' AND noi = '02' THEN noicon = '';
			IF ident = '16003051' AND noi = '03' THEN noicon = '01';
			RUN;
		%END;
	%MEND;

%correction_noicon_2016;


/****************************************************************************************/
/* IV  	Correction automatique des noienf pour les enfants nés après mars de anref+1	*/
/****************************************************************************************/
/* On corrige les noienf des individus ayant un enfant en anref+1 et qu'on supprime de la base.
A cause de cela, l'enfant pourrait ne pas être dans le bon foyer familial. Ce cas ne doit pas être trop fréquent.
On garde en revanche ces enfants nés en anref+1 pour que l'on puisse les comptabiliser 
(grace à noiper ou noimer) et les rattacher à l'ident_fam de leur parent. */

%macro AnneeSuivante;
	%let option=keep=ident&anr. noi naim naia rename=(ident&anr.=ident);
	proc sql;
		create table annee_suivante as
			select * from
				(select * from rpm.irf&anr.e&anr.t4(&Option.)
				%if &noyau_uniquement.=non %then %do;
					union select * from cd.irf&anr.e&anr.t3(&Option.)
					union select * from cd.irf&anr.e&anr.t2(&Option.)
					union select * from cd.irf&anr.e&anr.t1(&Option.)
					union select * from cd.irf&anr.e&anr1.t1(&Option.)
					union select * from cd.irf&anr.e&anr1.t2(&Option.)
					union select * from cd.irf&anr.e&anr1.t3(&Option.))
					%end;
				%else %do; ) %end;
			where naia="20&anr1.";
		quit;
	%mend;
%AnneeSuivante;
data suppr(keep=ident noi); 
	set annee_suivante; 
	if input(naim,2.)>=3; 
	run;
proc sort data=annee_suivante(rename=(noi=noi_supp)); by ident; run;
data travail.irf&anr.e&anr.(drop=i j noi_supp); 
	merge 	travail.irf&anr.e&anr.(in=a) 
			annee_suivante(keep=ident noi_supp);
	by ident;
	if noi_supp='' then noi_supp='99';
	array noienf noienf01 noienf02 noienf03 noienf04 noienf05 noienf06 noienf07 noienf08 noienf09 noienf10 noienf11 noienf12 noienf13 noienf14; 
	do i=1 to 14; 
		if noienf(i)=noi_supp then do;
			do j=i to 13; 
				noienf(j)=noienf(j+1); 
				end;
			noienf(14)='';
			end;
		end;
	if a;
	run; 

/****************************************************************************************/
/* V  	Attribution aléatoire d'un mois de naissance lorsqu'il est inconnu	*/
/****************************************************************************************/
data travail.irf&anr.e&anr.;
	set travail.irf&anr.e&anr.;
	if naim='99' then do;
	/* Tirage aléatoire uniforme du mois de naissance motivé du fait que l'année de naissance des personnes concernées
	 semble aléatoire elle aussi : elle ne donne pas d'information justifiant d'imputer un mois de naissance sur d'autres critères */
		alea=ranuni(2);
		if alea<1/12 then naim='01';
		else if alea<2/12 then naim='02';
		else if alea<3/12 then naim='03';
		else if alea<4/12 then naim='04';
		else if alea<5/12 then naim='05';
		else if alea<6/12 then naim='06';
		else if alea<7/12 then naim='08';
		else if alea<8/12 then naim='09';
		else if alea<9/12 then naim='10';
		else if alea<10/12 then naim='10';
		else if alea<11/12 then naim='11';
		else if alea<=12/12 then naim='12';
		end;
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
