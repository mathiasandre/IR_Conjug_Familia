/************************************************************************************/
/*																					*/
/*							2_coherence cal_rev										*/
/*																					*/
/************************************************************************************/


/* Mise en coh�rence du calendrier d'activit� avec les revenus pour les cotisations */
/* En entr�e : 	imput.calendrier													*/
/*				travail.indivi&anr.													*/
/*				base.baseind														*/
/*				travail.irf&anr.e&anr.												*/
/* En sortie : 	imput.calendrier													*/
/************************************************************************************/
/* PLAN :																			*/ 
/* I- Simplification du calendrier 													*/ 
/* I.1- Filtre sur les inactifs														*/ 
/* I.2- Filtre sur les retrait�s													*/ 
/* I.3- Suppression les cas de retraites avant 40 ans et diminuer l'activit� des 	*/
/* travailleurs qui ne travaillent que quelques jours par mois						*/
/* II- Distinction des diff�rents cas de cotis_special								*/ 
/* II.1- Individus avec revenu d'activite mais sans calendrier d'activite 			*/
/* II.2- Indemnit� ch�mage sans ch�mage dans le calendrier d'activite				*/ 
/* II.3- Ajout du ch�mage dans le calendrier d'activit� pour les achanger=1 (cas des chomeurs)*/
/* III - Fusion des r�sultats														*/
/************************************************************************************/
/* REMARQUES : 																		*/
/* Le calendrier est n�cessaire au calcul du salaire mensuel pour les cotisations. 	*/
/* Il doit �tre coh�rent avec les types de revenu. 									*/
/* A la diff�rence du programme cal_anref, on modifie ici le calendrier d'activit� 	*/
/* pour le rendre coh�rent avec les revenus d�clar�s. 								*/
/* Pour cela, on fait l'hypoth�se que les individus confondent plus souvent 		*/
/* inactivit� et ch�mage que emploi et ch�mage et que les ch�meurs sont pay�s � 	*/
/* l'ARE (c'est une hypoth�se forte).												*/
/************************************************************************************/
/* Am�liorations possibles : 														*/
/* - Mettre en conformit� cal_anref et acteu6 notamment 							*/
/* - R�fl�chir � uniformiser le calendrier dans le cas o� il y a une interruption 	*/
/* d'1 mois dans un calendrier homog�ne 											*/
/************************************************************************************/

/************************************************************************************/
/* I- Simplification du calendrier 													*/ 
/************************************************************************************/

data calendrier (keep=ident noi cal_anref);
	set imput.calendrier;
/* I.1- Filtre sur les inactifs														*/ 
	/* si on suppose qu'on est inactif (code 9) puis �tudiant on dit qu'on est �tudiant*/ 
	if index(cal_anref,'9')>0 and index(cal_anref,'3')>0 and index(cal_anref,'9')<index(cal_anref,'3')then do i=1 to 12;
		if substr(cal_anref,i,1)='9' then substr(cal_anref,i,1)='3';
		end;

/* I.2- Filtre sur les retrait�s													*/ 
	/* Tous les retrait�s qui sont un seul mois inactif 
	et le reste de l'ann�e retrait� sont d�sormais retrait� toute l'ann�e */
	a=0; b=0;
	do k=1 to 12;
		if substr(cal_anref,k,1)='9' then a=a+1;
		if substr(cal_anref,k,1)='5' then b=b+1;
		end;
	if a=1 and b=11 then cal_anref='555555555555';
	run;

proc sort data=calendrier; by ident noi; run; 
proc sort data=travail.indivi&anr.(keep = ident noi quelfic zsali zchoi zrsti zrici zrnci zragi) out=indivi&anr.; by ident noi; run; 
proc sort data=base.baseind(keep= ident noi acteu6 naia) out=baseind; by ident noi; run; 

%macro sort_refonte_EEC;
proc sort data=travail.irf&anr.e&anr.(keep= ident noi csa p adfdap nondic rabs retrai tppred statutr hhc)
	out=irf&anr.e&anr.;
	by ident noi;
	run; 
%mend;
%sort_refonte_EEC;

data ajout_revenu;
	merge 	calendrier (in=a)
			indivi&anr. 
			baseind 
			irf&anr.e&anr.;
	by ident noi;
	if a;
	length activite chomage retraite rien 3.;
	activite=(zsali>0 ! zragi>0 ! zrici>0 ! zrnci>0);
	zactiv=zsali + zragi + zrici + zrnci;
	chomage=(zchoi>0);
	retraite=(zrsti>0);
	rien=(activite+chomage+retraite =0);
	%nb_mois(cal_anref,nbmois_sal,1);
	%nb_mois(cal_anref,nbmois_cho,4);
	%nb_mois(cal_anref,nbmois_ret,5);
	run; 


/* I.3- Suppression les cas de retraites avant 40 ans et diminuer l'activit� des 	*/
/* travailleurs qui ne travaillent que quelques jours par mois						*/

data calendrier3(drop=i k l m aremplir nbmois_sal2 nbmois_cho2 a);
	set ajout_revenu;
	/* pour tous les jeunes de moins de 26 ans, on remplace la retraite par de l'apprentissage*/
	if &anref.-input(naia,4.)<26 then do i=1 to 12;
		if substr(cal_anref,i,1)='5' then
		substr(cal_anref,i,1)='3';
		end;

	/* pour tous les jeunes de moins de 50 ans, on remplace la retraite par du ch�mage, de l'activit� puis de l'inactivit�.
	Cela comprend les gens qui touchent des pensions (pour handicaps, orphelin etc) avec zsali>0 et sont pourtant inactifs*/
	if &anref.-input(naia,4.)<50 then do i=1 to 12;
		if substr(cal_anref,i,1)='5' then do;
			if zchoi>0 then substr(cal_anref,i,1)='4';
			else if zsali>0 and acteu6='1' then substr(cal_anref,i,1)='1';
			else substr(cal_anref,i,1)='9';
			end;
		end;

	/* On change �galement le calendrier des gens qui travaillent � temps plein, mais qui ne touchent pas assez de 
		revenu (moins que le SMIC). Ce sont des actifs qui bossent que quelques jours par mois.
		Le reste du temps, ils sont chomeurs ou inactifs. Du coup, on part du principe que si les gens disent 
		travailler � plein temps, on diminue leur nombre de mois travaill�, et on augmente ceux chom�s. */ 

	if tppred='1' and zsali>0 and zactiv-zsali=0 and zsali<&b_smica_dec.*nbmois_sal/12 then do; 
		nbmois_sal2=min(12,round((zsali*12)/&b_smica_dec.,1));
		aremplir=nbmois_sal-nbmois_sal2;
		if zchoi>0 then do;
			nbmois_cho2=min(12,round((zchoi/&ass_mont.),1));
			a=nbmois_cho2-nbmois_cho;
			if a>0 and nbmois_cho2>0 then do;
				do k=1 to 12;
					if aremplir>0 and a>0 then do;
						if substr(cal_anref,k,1)='1' then do;
							substr(cal_anref,k,1)='4';
							aremplir=aremplir-1;
							a=a-1;
							end;
						end;
					end;
				end;
			end;
		/* Pour les plus de 50 ans qui touchent une retraite, on enl�ve des mois de travail. */
		if zrsti>0 and zchoi=0 and &anref.-input(naia,4.)>50 then do;
			do l=1 to 12;
				m=12-l+1;
				if substr(cal_anref,m,1)='1' and aremplir>0 then do;
					substr(cal_anref,m,1)='5';
					aremplir=aremplir-1;
					end;
				end;
			end;
		end;

	%nb_mois(cal_anref,nbmois_sal,1);
	%nb_mois(cal_anref,nbmois_cho,4);
	%nb_mois(cal_anref,nbmois_ret,5);

	run;

/************************************************************************************/
/* II- Distinction des diff�rents cas de cotis_special								*/ 
/************************************************************************************/

/* II.1- Individus avec revenu d'activite mais sans calendrier d'activite 			*/
%macro manque_dactivite;
	data manque_dactivite (drop=i l);
		set calendrier3 (where=((activite>0 and nbmois_sal=0) or (zchoi>0 and nbmois_cho=0)));

		if (activite>0 and nbmois_sal=0);
		format cotis_special $19.;

	/* 1- les gens qui partent en retraite ou en pr�retraite et qui partent en dehors d'un plan social ou de la volont� de l'employeur 
	doivent d�clarer leur indemnit� de d�part en retraite. Ils peuvent l'�taler sur quatre ans. */ 
		if (zrsti>0 or zchoi>0) and index(cal_anref,'5')>0 and input(adfdap,4.)=>&anref.-4 and &anref.-input(naia,4.)<60 then do; 
			cotis_special= 'depart retraite';
			cal_anref='555555555555'; 
			end; 

	/* 2- Individus de plus de 60 ans cumulant retraite et activite*/
	/* � condition d'avoir l'�ge l�gal de d�part � la retraite et le taux d'assurance plein; 
	Comme le taux d'assurance plein est inv�rifiable, on prend une condition d'avoir plus de 60 ans */
		if zrsti>0 and &anref.-input(naia,4.)>60 and cotis_special='' then do;
			cotis_special= 'trav+retraite';
			cal_anref='555555555555';
			end;

	/*3- Les gens qui sont retrait�s et agriculteurs sont mis � la retraite;
	Il peut s'agir d'agriculteurs ou des propri�taires terriens qui louent leurs terres.
	On calcule tout de m�me leur cotisations agricoles et celles du travail comme s'ils �taient au SMIC */
		if zragi>0 and zrsti>0 then do;
			cal_anref='555555555555'; cotis_special='agri+retraite';
			end;


	/* 4- Individus en cong�s maladie ou maternit�:
	On fait l'hypoth�se qu'il s'agit d'indemnit�s journali�re maternit� ou paternit�.
	Normalement la paje n'est pas imposable et ne peut pas appara�tre. */
		%if &anref.<2010 %then %do; 
			if nondic='4' or nondic='5' or rabs='3' or rabs='5' then cotis_special='indemnite maternite'; 
			%end;
		%else %if &anref.>=2010 %then %do; 
			if nondic='3' or nondic='4' or rabs='3' or rabs='5' then cotis_special='indemnite maternite'; 
			%end;
		%else %if &anref.>2012 %then %do; 
			if nondic='3' or rabs='3' or rabs='5' then cotis_special='indemnite maternite'; 
			%end;
	/* les indemnites journalieres de maladie sont imposables. */
		%if &anref.<2010 %then %do; 
			if nondic='6' or nondic='7' or rabs='2' then cotis_special='indemnite maladie'; 
			%end;
		%else %if &anref.>=2010 %then %do; 
			if nondic='5' or nondic='6' or rabs='2' then cotis_special='indemnite maladie'; 
			%end;
		%else %if &anref.>2012 %then %do; 
			if nondic='4' or nondic='5'  or rabs='3' or rabs='5' then cotis_special='indemnite maladie'; 
			%end;

	/* 5- Les licenci�s :
	Individus licenci�s dans l'ann�e ou l'ann�e pr�c�dente et qui ont per�u une indemnit� de licenciement. */ 
		if (input(adfdap,4.)=&anref. or input(adfdap,4.)=&anref.-1 or rabs='9') and cotis_special ne 'depart retraite' then cotis_special='licencie';

	/* 6- Faux-actifs (actif au T4 selon la question acteu6) :
	Individus cumulant activite et autre revenu (souvent retraite).
	Leur calendrier d'activite est rempli en partant du T4 */ 
		if acteu6='1' and cotis_special='' then do;
			nbmois_sal=min(12,round((zsali*12)/&b_smica_dec.,1));
			cotis_special='autre actif';
			do i=1 to nbmois_sal;
				l=12-i+1;
				substr(cal_anref,l,1)='1';
				end;
			end;

	/* 7- les autres :
	Les 2/3 d'entre eux sont inactifs depuis au moins un an.
	Beaucoup sont � la retraite sans toucher de retraite et touchent un salaire */
		%nb_mois(cal_anref,nbmois_sal,1);
		%nb_mois(cal_anref,nbmois_cho,4);
		%nb_mois(cal_anref,nbmois_ret,5);
		if  cotis_special='' and nbmois_sal=0 then cotis_special='autre';
		run;
	%mend;
%manque_dactivite;

proc sort data=manque_dactivite; by ident noi; run; 

/* II.2- Indemnit� ch�mage sans ch�mage dans le calendrier d'activite				*/ 
data manque_chomage (drop=i j);
	merge 	calendrier3
			manque_dactivite(in=a keep=ident noi);
	by ident noi;
	if not a;
	if (zchoi>0 and nbmois_cho=0);
	format cotis_special $19.;
	%nb_mois(cal_anref,nbmois_ina,9);

	/* 1 - Individus se d�clarent en pr�retraite */
	if retrai='2' then cotis_special='preretraite';

	/* 2 - toute personne en preretraite a un 5 dans son calendrier d'activite */
	if &anref.-input(naia,4.)>55 and &anref.-input(naia,4.)<66 and index(cal_anref,'5')>0 and zrsti=0 then cotis_special='preretraite';

	/* 3 -  Individus dont on soup�onne qu'ils �taient en pr�retraite puis sont pass�es en retraite.
	C'est probl�matique car on a beaucoup de gens qui cumulent retraite et chomage.
	Il est cependant possible de cumuler chomage et retraite militaire par exemple.
	On fait l'hypoth�se qu'il s'agit de d�parts en retraites mais ce pourraient �tre de vrais cas de cumul. */
	if &anref.-input(naia,4.)>55 and &anref.-input(naia,4.)<66 and zrsti>0 and cotis_special='' then cotis_special='preretraite+retraite';

	/* 4- Individus que l'on soup�onne d'�tre en pr�retraite mais d�clarant �tre en retraite (ou situation plus compliqu�e) */
	if &anref.-input(naia,4.)>55 and &anref.-input(naia,4.)<66 and (retrai in ('1','3')) and cotis_special='' then cotis_special='preretraite';

	/* 5- Int�rimaires */
	/*Individus travaillent un peu et touchent du chomage le reste du mois. */
	if statutr='2' then do;
		cotis_special='interrimaire';
		nbmois_cho=min(12,round((zchoi/&ass_mont.),1)); /*reste la quantit� de chomage, on la calcule au prorata de l'ARE */ 
		if nbmois_ina>0 then do;
			j=12;
			do while(j>1 and nbmois_cho>0 and nbmois_ina>0);
				if substr(cal_anref,j,1)='9' then do;
					substr(cal_anref,j,1)='4';
					nbmois_cho=nbmois_cho-1;
					nbmois_ina=nbmois_ina-1;
					end;
				j=j-1;
				end;
			end;
		/* ce choix est contestable car on peut le m�me mois �tre au chomage et en activite.
		Si l'indemnit� chomage est importante, alors on risque de mettre trop de mois de chomage. */
			else achanger=1;
		end;

	/* 6 - Individus travaillant � temps partiel et cumulant du chomage.
	Pour �tre dans ce cas, on a une condition sur le revenu de l'ancien m�tier mais c'est compliqu� � v�rifier.
	On a �galement une condition sur l'heure, 110h/mois soit 26h/semaine, c'est le cas de 75 % des gens.
	On n'impl�mente pas cette condition car les horaires d�clar�s dans l'EEC ne sont pas fiables.
	On a �galement un plafonnement de l'allocation chomage mais normalement, �a n'a pas d'impact sur le calcul des cotisations. */
	if tppred='2' and statutr in ('1','4','5') and zsali>0 then cotis_special='trav partiel+chom';

	/* 7 - Autres situations */
	if cotis_special='' and nbmois_cho=0 then do;
		nbmois_cho=min(12,round((zchoi/&ass_mont.),1));
		cotis_special='autre';
		if input(adfdap,4.)=&anref. or input(adfdap,4.)=&anref.-1 then do;
				do i=1 to nbmois_cho;
				l=12-i+1;
				substr(cal_anref,l,1)='4';
				end;
			end;
		else do;
			if nbmois_ina>0 then do;
				j=12;
				do while(j>1 and nbmois_cho>0 and nbmois_ina>0);
					if substr(cal_anref,j,1)='9' then do;
						substr(cal_anref,j,1)='4';
						nbmois_cho=nbmois_cho-1;
						nbmois_ina=nbmois_ina-1;
						end;
					j=j-1;
					end;
				end;
				else achanger=1;
			end;
		end;
	run;

/* II.3- Ajout du ch�mage dans le calendrier d'activit� pour les achanger=1 (cas des chomeurs)*/

/* On utilise une r�gle pour changer l'activite en chomage suivant la regle que le revenu du chomage est �gal
� 65.6 % du revenu de l'emploi, sinon on �crase */

data reecriture_calendrier;
	set manque_chomage;
	if achanger=1 then do;
		nbmois_cho=min(12,round((zchoi/&ass_mont.),1));
		/* Attention aux individus cumulant emploi et chomage : on leur r�serve une part d'emploi */
		%nb_mois(cal_anref,nbmois_sal,1);
		nbmois_sal2=max(min(12,round(zsali*12/&b_smica_dec.,1)),1);
		if nbmois_sal>nbmois_sal2 then nbmois_sal3=nbmois_sal2; else nbmois_sal3=nbmois_sal;
		if zactiv=0 then nbmois_sal3=0;
		if nbmois_sal3>0 then do;
			if nbmois_sal3+nbmois_cho>12 and zactiv>0 then do;
				/* La m�thode de r�partition est coh�rente avec celle de cal_anref.sas */
				nbmois_cho2=round((zchoi/65.6*100)/(zchoi/65.6*100+zactiv)*12,1);
				nbmois_sal4=round(zactiv/(zchoi/65.6*100+zactiv)*12,1);
				/* on remplit dans l'ordre (on pourrait raffiner en allant chercher dans le calendrier d'activit�) */
				do i=1 to nbmois_cho2;
					substr(cal_anref,i,1)='4';
					end;
				do j=1 to nbmois_sal4;
					l=12-j+1;
					substr(cal_anref,l,1)='1';
					end;
				end;
			else do;
				do i=1 to 12;
					if substr(cal_anref,i,1) ne '1' and nbmois_cho>0 then do;
						substr(cal_anref,i,1)='4';
						nbmois_cho=nbmois_cho-1;
						end;
					end;
				end;
			end;
		else do;
			do i=1 to nbmois_cho;
				substr(cal_anref,i,1)='4';
				end;
			end;
		end;
	run;
/************************************************************************************/
/* III - Fusion des r�sultats														*/
/************************************************************************************/
proc sort data= calendrier3; by ident noi; run;
proc sort data= manque_dactivite; by ident noi; run;
proc sort data= reecriture_calendrier; by ident noi; run;

data calendrier3(keep= ident noi cal_anref cotis_special);
	merge 	calendrier3(in=a)
			manque_dactivite(keep=ident noi cotis_special cal_anref rename =(cal_anref=cal1))
			reecriture_calendrier(keep=ident noi cotis_special cal_anref rename =(cal_anref=cal2 cotis_special=cotis_special2));
	by ident noi;
	if a;
	if cal1 ne '' and cal1 ne cal_anref then cal_anref=cal1;
	if cal2 ne '' and cal2 ne cal_anref then cal_anref=cal2;
	if cotis_special2 ne '' then cotis_special= cotis_special2;
	if cal_anref ne '';
	run;

data imput.calendrier;
	merge	imput.calendrier
			calendrier3 (rename=(cal_anref=cal0));
	by ident noi;
	label cal0 = "calendrier mensuel d'activit� de &anref. d�finitif";
	label cotis_special = "statut particulier �ventuel pour le calcul des cotisations";
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
