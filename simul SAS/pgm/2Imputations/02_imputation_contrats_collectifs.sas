/****************************************************************/
/*																*/
/*				   Imputation_contrats_collectifs			    */
/*								 								*/
/****************************************************************/


/****************************************************************/
/* Tirage & imputation des contrats collectifs obligatoires pour le financement d' une compl�mentaire sant� */

/* Cette participation ne concerne que les salari�s du priv� dont l'entreprise propose un contrat collectif
obligatoire pour une compl�mentaire sant�. D'o� le tirage � partir de cibles fournies par le BDSRAM � la Drees */

/* En entr�e :	imput.effectif						*/ 
/*				travail.irf&anr.e&anr.				*/
/*				travail.foyer&anr.					*/
/*				travail.menage&anr.					*/
/*				travail.indivi&anr.					*/
/* En sortie :	travail.foyer&anr.					*/
/*				travail.indivi&anr.					*/
/********************************************************************************/
/* PLAN : 																		*/
/* I. Tirage des salari�s titulaires d'un contrat collectif obligatoire			*/
/* II. Imputations des participations employeurs et des participations salari�s */
/********************************************************************************/

/*************************************************************************/
/*  I. Tirage des salari�s titulaires d'un contrat collectif obligatoire */
/*************************************************************************/

/* Cr�ation de la table tirage_contrat qui contient les informations n�cessaires au tirage et � la fusion avec la table foyer*/
	
/* Les candidats au tirage sont les salari�s du priv� */
/* Note 1 : les fonctionnaires hospitaliers et territoriaux peuvent b�n�ficier de contrats collectifs mais pas de 
contrats collectifs obligatoires, qui sont les seuls vis�s par la r�forme (les contrats collectifs facultatifs ne 
b�n�ficiant d'aucune exon�ration) */
/* Note 2 : on met un filtre sur les �ligibles de mani�re � ne pas tirer des salari�s du priv� ayant un salaire annuel d�clar� 
inf�rieur � un smic mensuel d�clar� pour ne pas attribuer � tort � des salari�s une compl�mentaire sant� si la dur�e de leur
pr�sence dans l'entreprise durant l'ann�e ne permet pas de penser qu'ils en ont b�n�fici�. Le seuil du smic mensuel d�clar�
est cependant arbitraire et pourrait �ventuellement �tre am�lior�. */
proc sql;
	create table tirage_contrat (where=(pub3fp = '4' and zsali>&b_smica_dec./12)) as
		select a.ident, a.noi, a.naia, a.pub3fp, b.declar1, b.persfip, b.zsali, c.typmen7
		from  (travail.irf&anr.e&anr. as a
		left join travail.indivi&anr. as b 
		on a.ident=b.ident and a.noi=b.noi)
		left join travail.mrf&anr.e&anr. as c
		on a.ident=c.ident;  
	quit;
/* Cellules pour le tirage */
/* on les cr�e en fonction du salaire du salari� */
data tirage_contrat;
	set tirage_contrat;
	/* on calcule une approximation du salaire net � partir du salaire imposable */
		sal_contrat=zsali*(1-&Tcsgi.);
		if sal_contrat<&tranche1. then id_tirage=1;
		else if &tranche1.<=sal_contrat<&tranche2. then id_tirage=2;
		else if &tranche2.<=sal_contrat<&tranche3. then id_tirage=3;
		else if &tranche3.<=sal_contrat<&tranche4. then id_tirage=4;
		else if &tranche4.<=sal_contrat<&tranche5. then id_tirage=5;
		else if sal_contrat>=&tranche5. then id_tirage=6;
	run;
proc sort data=tirage_contrat; by id_tirage; run;
/* On tire les contrats collectifs */
data tirage_contrat (drop=alea contrat_collectif pub3fp zsali sal_contrat);
	set tirage_contrat;
	by id_tirage;
	contrat_collectif=1;
	alea=ranuni(1);
	%macro contrat_collectif;
	%do i=1 %to 6;
		if id_tirage=&i. and alea>&&part_collectif&i.. then contrat_collectif=0;
	%end;
	%mend;
	%contrat_collectif;
	if contrat_collectif=1;
	run;

/* On cr�e une variable de montant qui d�pend de la configuration familiale */
/* On ne retient dont qu'un montant par m�nage */
proc sort data=tirage_contrat; by ident; run;
data tirage_contrat;
	set tirage_contrat;
	retain ident;
	by ident;
	montant_prime=(typmen7 in ('1','5','6','9'))*&montant_prime_celib. 
    + (typmen7='3')*&montant_prime_couple. 
	+ (typmen7 in ('2','4'))*&montant_prime_enfants.;
		if first.ident ;
	run;

/*****************************************************************/
/*  II. Imputations d'une participation employeur et d'une participation salari�e   */
/*****************************************************************/
/*on impute � un niveau individuel */ 
	data contrats_collectifs_indiv;
		set tirage_contrat;
		%Init_Valeur(part_employ_vous part_employ_conj part_employ_pac1 part_employ_pac2 part_employ_pac3);
			/* on impute d'abord les parts employeurs */
			part_employ_vous=(persfip='vous')*(montant_prime*&part_employeur.);
			part_employ_conj=(persfip='conj')*(montant_prime*&part_employeur.) ;
			part_employ_pac1=(persfip='pac' and substr(declar1,31,4)=naia)*(montant_prime*&part_employeur.);
			part_employ_pac2=(persfip='pac' and substr(declar1,36,4)=naia and part_employ_pac1=0)*(montant_prime*&part_employeur.);
			part_employ_pac3=(persfip='pac' and substr(declar1,41,4)=naia and part_employ_pac1=0 and part_employ_pac2=0)*(montant_prime*&part_employeur.);
			/* on d�duit des parts employeurs les parts salari�s */
			part_salar_vous=(montant_prime-part_employ_vous)*(part_employ_vous>0);
			part_salar_conj=(montant_prime-part_employ_conj)*(part_employ_conj>0);
			part_salar_pac1=(montant_prime-part_employ_pac1)*(part_employ_pac1>0);
			part_salar_pac2=(montant_prime-part_employ_pac2)*(part_employ_pac2>0);
			part_salar_pac3=(montant_prime-part_employ_pac3)*(part_employ_pac3>0);
			/* on cr�e part_employ et part_salar pour les variables au niveau individuel */
			part_employ=part_employ_vous+part_employ_conj+part_employ_pac1+part_employ_pac2+part_employ_pac3;
			part_salar=part_salar_vous+part_salar_conj+part_salar_pac1+part_salar_pac2+part_salar_pac3;
		run;
/* on agr�ge ces montants au niveau foyer */
proc sql;
	create table contrats_foyer as
		select declar1, sum(part_employ_vous) as part_employ_vous,
		sum(part_employ_conj) as part_employ_conj,
		sum(part_employ_pac1) as part_employ_pac1,
		sum(part_employ_pac2) as part_employ_pac2,
		sum(part_employ_pac3) as part_employ_pac3, 
		sum(part_salar_vous) as part_salar_vous,
		sum(part_salar_conj) as part_salar_conj,
		sum(part_salar_pac1) as part_salar_pac1,
		sum(part_salar_pac2) as part_salar_pac2,
		sum(part_salar_pac3) as part_salar_pac3
		from contrats_collectifs_indiv
		where declar1 ne ""
		group by declar1
		order by declar1;
	create table contrats_collectifs_men as
		select ident, sum(part_employ) as part_employ, sum(part_salar) as part_salar
		from contrats_collectifs_indiv
		group by ident 
		order by ident;
	quit;

/* On rajoute les montants dans travail.foyer&anr. si cela n'a pas d�j� �t� fait. */
%macro AjouteContratDansFoyer;
	%VarExist(	lib=travail,
				table=foyer&anr.,
				var=part_employ_vous);
	%if &varexist. %then %put "L'imputation des contrats collectifs avait d�j� �t� faite, on n'�crase rien.";
	%else %do;
		%put "L'imputation des contrats collectifs est r�alis�e.";
		data travail.foyer&anr.;
			merge 	travail.foyer&anr.
					contrats_foyer (in=a rename=(declar1=declar));
			by declar;
			if not a then do;
				%Init_Valeur(part_employ_vous part_employ_conj part_employ_pac1 part_employ_pac2
				part_employ_pac3 part_salar_vous part_salar_conj part_salar_pac1 part_salar_pac2 part_salar_pac3);
				end;
			/* Jusqu'� l'ERFS 2012 inclue, il faut ajouter les participations employeurs aux cases fiscales concern�es 
				puisque jusqu'� cette date, elles n'�taient pas fiscalis�es � l'IR. */
			%if %eval(&anref.)<=2012 %then %do;
				_1aj=_1aj+part_employ_vous;
				_1bj=_1bj+part_employ_conj;
				_1cj=_1cj+part_employ_pac1;
				_1dj=_1dj+part_employ_pac2;
				_1ej=_1ej+part_employ_pac3;
				zsalf=zsalf+part_employ_vous+part_employ_conj+part_employ_pac1+part_employ_pac2+part_employ_pac3;
				%end;
			run;
		/* On ajoute �galement les majorations dans travail.indivi */
		proc sort data=travail.indivi&anr.; by ident noi; run;
		proc sort data=contrats_collectifs_indiv; by ident noi; run;
		data travail.indivi&anr.;
			merge 	travail.indivi&anr.
					contrats_collectifs_indiv (in=a keep=ident noi part_employ part_salar);
			by ident noi;
			if not a then do;
				part_employ=0;
				part_salar=0;
				end;
				%if %eval(&anref.)<=2012 %then %do;
				zsali=zsali+part_employ;
				%end;
			run;
		data travail.menage&anr.;
			merge 	travail.menage&anr.
					contrats_collectifs_men (in=a);
			by ident;
			if not a then do;
				part_employ=0;
				part_salar=0;
				end;
				%if %eval(&anref.)<=2012 %then %do;
				zsalm=zsalm+part_employ;
				%end;
			run;
		%end;
	%mend;
%AjouteContratDansFoyer;

/* suppression des tables interm�diaires */
proc datasets mt=data library=work kill;run;quit; 


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
