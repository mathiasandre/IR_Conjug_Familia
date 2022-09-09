/****************************************************************/
/*																*/
/*				0_majo_retraites								*/
/*								 								*/
/****************************************************************/


/****************************************************************/
/* Tirage & imputation majorations de pensions de retraite		*/
/* En entr�e : 	travail.indivi&anr.								*/ 
/*			   	travail.irf&anr.e&anr.			               	*/
/*			   	travail.foyer&anr.				               	*/
/*				travail.menage&anr.								*/
/*				travail.indivi&anr.								*/
/* En sortie : 	travail.foyer&anr.		          	     		*/
/*				travail.menage&anr.								*/
/*				travail.indivi&anr.								*/
/****************************************************************/
/* PLAN : 														*/
/* I. Identification des retrait�s 								*/
/* II. Tirage des pensions major�es								*/
/* III. Imputation de la variable majorations  					*/
/****************************************************************/
/* Il faudrait en principe inclure les FIP mais ils n'ont actuellement pas de sexe imput� : � faire */

%macro imput_majo_retraites;
/****************************************************************/
/* I. Identification des retrait�s 								*/
/****************************************************************/
/* Cr�ation de la table table_tirage qui contient les informations n�cessaires au tirage et � la fusion avec la table foyer*/
	
/* les candidats au tirage sont les suivants : 
- pour les moins de 65 ans : ceux qui ont une d�claration (retrai) correspondant au statut de retrait� et un zrsti&anr. positif
- pour les plus de 65 ans : tous ceux qui ont un zrsti&anr. positif
On les s�lectionne ainsi car parmi les zrsti positifs, certains sont en fait des pensions d'invalidit�
et non des pensions de retraite (normalement, les pensions d'invalidit� sont per�ues jusq'au jour o� 
la personne atteint l'�ge l�gal de d�part � la retraite. En prenant 65 ans, on est actuellement s�r d'�tre au dela de cet
�ge qui a vari� au cours du temps.)
Depuis l'ERFS 2014, on a les pensions d'invalidit� � part et donc ce traitement n'est plus n�cessaire : on rel�che 
donc les conditions sur retrai pour anref <=2014 
TO DO : V�rifier que pour l'ERFS 2014 il n'y a pas de rupture de s�rie par rapport � l'identification que l'on faisait avant*/

proc sql;
	create table table_tirage  %if &anref.<2014 %then %do; (where=(age>=65 or retrai = "1")) %end; as
		select a.ident, a.noi, a.zrsti, a.declar1, a.declar2, a.persfip, b.retrai, b.naia, b.sexe, c.wpela&anr., 
			&anref.-input(b.naia,4.) as age
		from (travail.indivi&anr.(where=(zrsti>0 and quelfic not in ('EE','EE_NRT'))) as a
		inner join travail.irf&anr.e&anr.(keep=ident noi retrai naia sexe where=((&anref.-input(naia,4.)>=50))) as b
		on a.ident=b.ident and a.noi=b.noi)
		inner join travail.menage&anr.(keep=ident wpela&anr.) as c
		on a.ident=c.ident;
	quit;

/* Cellules pour le tirage */
/* 1) on cr�e les quintiles de pensions de retraite*/
proc univariate noprint data=table_tirage;
	var zrsti;
    output out=quintile pctlpts=20 40 60 80 pctlpre=pct;
	weight wpela&anr.;
	run;
data _null_;
	set quintile;
	call symputx('q1',pct20);
	call symputx('q2',pct40);
	call symputx('q3',pct60);
	call symputx('q4',pct80);
	run;
data table_tirage;
	set table_tirage(drop=retrai);
	if zrsti<=&q1. then quint_retr=1;
	else if zrsti<=&q2. then quint_retr=2;
	else if zrsti<=&q3. then quint_retr=3;
	else if zrsti<=&q4. then quint_retr=4;
	else quint_retr=5;
	/* 2) on cr�e les �ges quinquennaux */
	if age>=85 then age_quinq=8;
	else if 80<=age<85 then age_quinq=7;
	else if 75<=age<80 then age_quinq=6;
	else if 70<=age<75 then age_quinq=5;
	else if 65<=age<70 then age_quinq=4;
	else if 60<=age<65 then age_quinq=3;
	else if 55<=age<60 then age_quinq=2;
	else if 50<=age<55 then age_quinq=1;
	run;

/* 3) on cr�e un identifiant de tirage */
proc sort data=table_tirage; by quint_retr age_quinq; run;
data table_tirage;
    retain id_tirage 0;
	set table_tirage;
	by quint_retr age_quinq;
	if first.age_quinq then id_tirage=id_tirage+1; /* on a 40 cases */
	alea=ranuni(1); /* on attribue une variable al�atoire */
	run;

/****************************************************************/
/* II. Tirage des pensions major�es								*/
/****************************************************************/
proc sql;
	create table tirage_retraite as
	select *, sum(wpela&anr.) as somme_poids
	from table_tirage
	group by id_tirage;
	quit;
proc sort data=tirage_retraite; by id_tirage alea; run;
data tirage_retraite(drop=id_tirage age age_quinq somme_poids alea quint_retr poids_cumul zrsti wpela&anr. recours_majo);
	set tirage_retraite;
	by id_tirage;
	recours_majo=1;
	retain poids_cumul;
	if first.id_tirage then poids_cumul=0;
	poids_cumul=poids_cumul+wpela&anr.;
	%macro boucle;
		%do i=1 %to 40;
			if id_tirage=&i. and poids_cumul>&&tx_majo_&i.*somme_poids then recours_majo=0;
			%end;
		%mend;
	%boucle;
	if recours_majo=1;
	run;

/****************************************************************/
/* III. Imputation de la variable majorations  					*/
/****************************************************************/
/* Note : on diff�rencie les imputations en fonction du sexe 
(param�tres tx_maj_f pour femmes et tx_maj_h pour hommes) */

proc sql;
	/* Dans les tables majo_ind_declar1 et majo_ind_declar2 on a une ligne par ident noi */
	create table majo_ind_declar1(keep=declar majo: ident noi) as
		select *, (persfip='vous')*(sum(_1as,_1al,_1am,0)*(&tx_maj_h.*(sexe='1')+&tx_maj_f.*(sexe='2'))) as majo_vous,
		(persfip='conj')*(sum(_1bs,_1bl,_1bm,0)*(&tx_maj_h.*(sexe='1')+&tx_maj_f.*(sexe='2'))) as majo_conj,
		(persfip='pac' and substr(declar,31,4)=naia)*(sum(_1cs,_1cl,_1cm,0)*(&tx_maj_h.*(sexe='1')+&tx_maj_f.*(sexe='2'))) as majo_pac1
		from travail.foyer&anr.(keep=declar &zrstfP.) as a 
		inner join tirage_retraite as b 
		on a.declar=b.declar1;
	create table majo_ind_declar2(keep=declar majo: ident noi) as
		select *, (persfip='vous')*(sum(_1as,_1al,_1am,0)*(&tx_maj_h.*(sexe='1')+&tx_maj_f.*(sexe='2'))) as majo_vous,
		(persfip='conj')*(sum(_1bs,_1bl,_1bm,0)*(&tx_maj_h.*(sexe='1')+&tx_maj_f.*(sexe='2'))) as majo_conj,
		(persfip='pac' and substr(declar,31,4)=naia)*(sum(_1cs,_1cl,_1cm,0)*(&tx_maj_h.*(sexe='1')+&tx_maj_f.*(sexe='2'))) as majo_pac1
		from travail.foyer&anr.(keep=declar &zrstfP.) as a 
		inner join tirage_retraite as b 
		on a.declar=b.declar2;
	/* On peut avoir plusieurs fois le m�me individu dans majo_ind s'il apparait sur plusieurs d�clarations */
	create table majo_ind as
		select coalesce(a.declar,b.declar) as declar, sum(a.majo_vous,b.majo_vous) as majo_vous,
		sum(a.majo_conj,b.majo_conj) as majo_conj, sum(a.majo_pac1,b.majo_pac1) as majo_pac1
		from majo_ind_declar1 as a full join majo_ind_declar2 as b
		on a.declar=b.declar;
	/* On regroupe les lignes appartenant � un m�me foyer, ie les conjoints */
	create table majo_decl as
		select declar, sum(majo_vous) as majo_vous, sum(majo_conj) as majo_conj, sum(majo_pac1) as majo_pac1
		from majo_ind
		group by declar
		order by declar;
	/* Quand on rajoutera les indfip, il faudra faire attention ici � bien les exclure dans l'agr�gation m�nage car 
		ils sont toujours exclus du calcul des NdV */
	create table majo_ind as
		select coalesce(a.ident,b.ident) as ident, coalesce(a.noi,b.noi) as noi, 
		sum(a.majo_vous,a.majo_conj,a.majo_pac1,b.majo_vous,b.majo_conj,b.majo_pac1) as majo 
		from majo_ind_declar1 as a full join majo_ind_declar2 as b on (a.ident=b.ident and a.noi=b.noi);
	create table majo_men as
		select ident, sum(majo) as majo
		from majo_ind
		group by ident 
		order by ident;
	quit;

/* On rajoute les majorations dans travail.foyer&anr. si cela n'a pas d�j� �t� fait. */
proc sort data=travail.foyer&anr.; by declar ; run;
%macro AjouteMajoDansFoyer;
	%VarExist(	lib=travail,
				table=foyer&anr.,
				var=majo_vous);
	%if &varexist. %then %put "L'imputation des majorations de pensions avait d�j� �t� faite, on n'�crase rien.";
	%else %do;
		%put "L'imputation des majorations de pensions est r�alis�e.";
		data travail.foyer&anr.;
			merge 	travail.foyer&anr.
					majo_decl (in=a);
			by declar;
			if not a then do;
				majo_vous=0;
				majo_conj=0;
				majo_pac1=0;
				end;
			/* Jusqu'� l'ERFS 2012 inclue, il faut ajouter les majorations de pensions aux cases fiscales concern�es puisque jusqu'� cette 
			date, elles n'�taient pas fiscalis�es � l'IR. */
			%if %eval(&anref.)<=2012 %then %do;
				_1as=_1as+majo_vous;
				_1bs=_1bs+majo_conj;
				_1cs=_1cs+majo_pac1;
				zrstf=zrstf+majo_vous+majo_conj+majo_pac1;
				%end;
			run;
		/* On augmente �galement �ventuellement zrsti dans travail.indivi */
		proc sort data=travail.indivi&anr.; by ident noi; run;
		data travail.indivi&anr.;
			merge 	travail.indivi&anr.
					majo_ind (in=a);
			by ident noi;
			if not a then majo=0;
			%if %eval(&anref.)<=2012 %then %do;
				zrsti=zrsti+majo;
				%end;
			run;
		data travail.menage&anr.;
			merge 	travail.menage&anr.
					majo_men (in=a);
			by ident;
			if not a then majo=0;
			%if %eval(&anref.)<=2012 %then %do;
				zrstm=zrstm+majo;
				%end;
			run;
		%end;
	%mend;
%AjouteMajoDansFoyer;

/* suppression des tables interm�diaires */
proc datasets mt=data library=work kill;run;quit; 

%mend;
%imput_majo_retraites;


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
