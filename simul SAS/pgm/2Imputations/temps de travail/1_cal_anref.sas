/****************************************************************************/
/*																			*/
/*							1_cal_anref.sas									*/
/*								 											*/
/****************************************************************************/

/* Construction de cal_anref, le calendrier mensuel d'activit� pour l'ann�e n (&anref)
 et Remplissage des positions manquantes cal_anref en utilisant les revenus fiscalement d�clar�s	*/

/* En entr�e : 	travail.cal_indiv											*/ 
/*				travail.indivi&anr 											*/
/* En sortie : 	imput.calendrier												*/

/****************************************************************************/
/* PLAN : 																	*/
/* I - agr�gation des donn�es 												*/
/* II - Premi�re imputation na�ve en copiant la premi�re activit� connue	*/
/* III - Deuxi�me imputation en tenant compte des revenus d�clar�s			*/
/* 		III.A - Identification des types d'activit� dans les revenus		*/
/* 		III.B - Un seul type d'activit� rep�r� dans les revenus				*/
/* 		III.C - Plusieurs types d'activit� rep�r�s dans les revenus			*/
/****************************************************************************/

/* REMARQUE : 																
 On compl�te cal_anref selon diff�rents cas de figures rep�r�s par la variable 'imput' : 
	Attention : le nombre de mois max est calcul� en faisant r�f�rence � un emploi au SMIC 
	-> On sur�value sans doute la p�riode connue. 

 - imput=1 : une seule source de revenu d�clar� et il reste suffisamment de revenu � r�partir sur les mois manquants
 => on compl�te avec la seule activit� connue.
	
 - imput=4 : une seule source de revenu d�clar� mais pas suffisamment de revenu � r�partir sur les mois manquants
=> on compl�te au maximum avec la seule activit� connue puis avec de l'inactivit� ('9'). 

 - imput=5 : pas de revenu d�clar� au fisc
=> on ne fait rien.

 - imput=6 : diff�rents types de revenus d�clar�s mais on ne sait pas comment �a s'articule. 
=> on compl�te avec de l'inactivit� au del� du nombre de mois maximum. 

 - imput=7 : diff�rents types de revenus d�clar�s avec davantage d'informations 
=> on compl�te au prorata des types de revenu selon un ordre pr�cis jusqu'au max puis avec de l'inactivit� ('9'). */				


/****************************************************************************/
/* I - agr�gation des donn�es 												*/
/****************************************************************************/

data voir_&anref.;
	set travail.cal_indiv(keep=ident noi cal_activite cal_tp&anref. cal_tp1);
	length cal_anref $12.; 
	cal_anref=substr(cal_activite,13,12);
	if noi <'50' & cal_anref = '000000000000' then cal_anref='555555555555';
	/* Comme il s'agit de personnes �g�es, on les met en retrait�s. */
	if index(cal_anref,'0')>0 & cal_anref ne '000000000000' then manq1=index(cal_anref,'0');
	label manq1="Premier mois avec activit� manquante";
	run;

proc sort data= travail.indivi&anr.; by ident noi;
data voir_&anref.; 
	merge 	voir_&anref.(in=a) 
			travail.indivi&anr.(in=b keep=ident noi zsali zragi zrici zrnci zchoi zrsti);
	by ident noi;
	if a & b;
	run;

/****************************************************************************/
/* II - Premi�re imputation na�ve en copiant la premi�re activit� connue	*/
/****************************************************************************/
/* la fa�on la plus simple et la plus naive de compl�ter le calendrier d'activit� est d'�tendre au d�but de l'ann�e la 
premi�re situation connue */
data complet1; 
	set voir_&anref.;
	cal1=cal_anref;
	PremierMoisRempli=1;
	do while (substr(cal1,PremierMoisRempli,1)='0');PremierMoisRempli=PremierMoisRempli+1; end;
	do k=1 to max(PremierMoisRempli-1,1); 
		substr(cal1,k,1)=substr(cal1,PremierMoisRempli,1);
		end;
	drop PremierMoisRempli k;
	run;

/****************************************************************************/
/* III - Deuxi�me imputation en tenant compte des revenus d�clar�s			*/
/****************************************************************************/
/* on regarde si l'imputation naive est coh�rente avec les revenus.
On change uniquement lorsque l'information est manquante puisque les r�sultats de l'EE sont toujours la r�f�rence. */ 

/*Remarque : la pr�-retraite est cod�e comme la retraite dans le calendrier d'activit� 
alors qu'au niveau des revenus, elle est dans les allocations ch�mage -> on peut donc avoir un ch�mage 
et �tre en retraite 5. On peut aussi �tre � la retraite et travailler */

/****************************************************************************/
/* III.A - Identification des types d'activit� dans les revenus				*/
/****************************************************************************/
data complet1_rev(drop=i TdT nbMoisConnus); 
	set complet1(where=(manq1 ne .));
	length cal_tp0 $24.;

	activite=(zsali>0 ! zragi>0 ! zrici>0 ! zrnci >0);
	chomage=(zchoi>0); 
	retraite=(zrsti>0);

	/*on traduit les montants en nombre de mois*/ 
	/* nombre maximum de mois par statut activit� pour une personne � temps plein*/
	nbmois_act_max=0; nbmois_cho_max=0; nbmois_ret_max=0;
	if zsali+zragi+zrici+zrnci>0 then nbmois_act_max=12*(zsali+zragi+zrici+zrnci)/(&b_smica_dec.);
	if zchoi>0 then nbmois_cho_max=12*zchoi/(12*&ass_mont.); 
	/* On calibre le nombre de mois de ch�mage max en fonction du montant de l'ASS */
	if zrsti>0 then nbmois_ret_max=12*zrsti/(0.827*&b_smica_dec.); 
	/*82,7% =taux de remplacement net pour une carri�re enti�re au SMIC, soumis au taux plein de CSG : source PQE retraite.
	retraite_imposable=retraite nette*(1+CSGret_imposable)=salaire net*taux remplacement net*(1+CSGret_imposable)
	=salaire net*taux remplacement net*(1+CSGsal_imposable)=b_smica_dec*taux remplacement net*/;

	/*on compte les mois d'activit�, de ch�mage, de retraite et avec information manquante observ�s dans cal_anref*/
	nbmois_act=0;nbmois_ret=0;nbmois_cho=0;nbmois_manquants=0; 
	do i=1 to 12; 
		if substr(cal_anref,i,1)='1' then nbmois_act=nbmois_act+1;
		if substr(cal_anref,i,1)='4' then nbmois_cho=nbmois_cho+1;
		if substr(cal_anref,i,1)='5' then nbmois_ret=nbmois_ret+1;
		if substr(cal_anref,i,1)='0' then nbmois_manquants=nbmois_manquants+1;
		end;

	/* Pour �tre plus pr�cis pour l'activit� on tient compte de la quotit� de travail */
	cal_tp0=substr(cal_tp1,25,24);
	/*On r�cup�re le nombre de mois pour lesquels on connait le temps de travail, 
	le premier renseign� et le temps de travail moyen sur les mois connus */
	nbMoisConnus=0;TdT=0;PremierTdTconnu=0;TdT_moyen=&b_tdt.;
	do i=0 to 11;
		if substr(cal_tp0,2*i+1,2) not in ('00','  ') then do; 
		 	nbMoisConnus=nbMoisConnus+1; 
			if PremierTdTconnu=0 then PremierTdTconnu=input(substr(cal_tp0,2*i+1,2),2.);
			TdT=TdT+input(substr(cal_tp0,2*i+1,2),4.);
			end;
		end;
	if nbMoisConnus ne 0 then do; 
		TdT_moyen=TdT/nbMoisConnus;
		nbmois_act_max=nbmois_act_max*35/TdT_moyen;
		end;
	run;


/****************************************************************************/
/* III.B - Un seul type d'activit� rep�r� dans les revenus					*/
/****************************************************************************/
data complet2(drop=PremierMoisRempli l);
	set complet1_rev;

	/* imput=1 : on compl�te avec la seule activit� connue */ 
	if (activite=1 & chomage=0 & retraite=0) & nbmois_act_max>=nbmois_act+nbmois_manquants then cal2=cal1;
	if (activite=0 & chomage=1 & retraite=0) & nbmois_cho_max>=nbmois_cho+nbmois_manquants then cal2=cal1;
	if (activite=0 & chomage=0 & retraite=1) & nbmois_ret_max>=nbmois_ret+nbmois_manquants then cal2=cal1;
	if cal2=cal1 then imput=1;

	/* imput=4 : on compl�te jusqu'au maximum de mois possibles avec l'activit� connue puis avec de l'inactivit� (8 ici) */	
	if (activite=1 & chomage=0 & retraite=0) & nbmois_act_max<nbmois_act+nbmois_manquants then imput=4;
	if (activite=0 & chomage=1 & retraite=0) & nbmois_cho_max<nbmois_cho+nbmois_manquants then imput=4;
	if (activite=0 & chomage=0 & retraite=1) & nbmois_ret_max<nbmois_ret+nbmois_manquants then imput=4;

	/* on r�cup�re le premier �l�ment de cal_anref rempli */
	PremierMoisRempli=1;
	do while (substr(cal_anref,PremierMoisRempli,1)='0');PremierMoisRempli=PremierMoisRempli+1; end;
	PremiereActivObservee=substr(cal_anref,PremierMoisRempli,1);

	if imput=4 then do;
		cal2=cal_anref;
		if (activite=1 & chomage=0 & retraite=0) & PremiereActivObservee='1' then do; 
			do l=1 to nbmois_manquants; 
				if l<nbmois_manquants-floor(nbmois_act_max-nbmois_act)+1 then substr(cal2,l,1)='9';
				else substr(cal2,l,1)='1';
				end; 
			end;
		else if (activite=1 & chomage=0 & retraite=0) & PremiereActivObservee ne '1' then do; 
			do l=1 to nbmois_manquants;
				if l<floor(nbmois_act_max-nbmois_act) then substr(cal2,l,1)='1';
				else substr(cal2,l,1)='9';
				end; 
			end;
		if (activite=0 & chomage=1 & retraite=0) & PremiereActivObservee='4' then do; 
			do l=1 to nbmois_manquants; 
				if l<nbmois_manquants-floor(nbmois_cho_max-nbmois_cho)+1 then substr(cal2,l,1)='9';
				else substr(cal2,l,1)='4';
				end; 
			end;
		else if (activite=0 & chomage=1 & retraite=0) & PremiereActivObservee ne '4' then do; 
			do l=1 to nbmois_manquants;
				if l<floor(nbmois_cho_max-nbmois_cho) then substr(cal2,l,1)='4';
				else substr(cal2,l,1)='9';
				end; 
			end;
		if (activite=0 & chomage=0 & retraite=1) & PremiereActivObservee='5' then do; 
			do l=1 to nbmois_manquants;
				if l<nbmois_manquants-floor(nbmois_ret_max-nbmois_ret) then substr(cal2,l,1)='9';
				else substr(cal2,l,1)='5';
				end; 
			end;
		else if (activite=0 & chomage=0 & retraite=1) & PremiereActivObservee ne '5' then do; 
			do l=1 to nbmois_manquants;
				if l<floor(nbmois_ret_max-nbmois_ret) then substr(cal2,l,1)='5';
				else substr(cal2,l,1)='9';
				end; 
			end;
		end;
	run;


/****************************************************************************/
/* III.C - Plusieurs types d'activit� rep�r�s dans les revenus				*/
/****************************************************************************/
data complet3;
	set complet2;
	length mois1 mois3 mois4 mois8 3.;
	/* On r�partit les mois d'activit� manquants en mois1, mois3, mois4 et mois8 */
	mois1=0;mois3=0;mois4=0;mois8=0;

	/* Personnes sans revenu d�clar� : aidants familiaux ? activit� dissimul�e ? hommes et femmes au foyer
	�tudiants ? ch�meurs sans droit ? autres inactifs ? */
	if (activite=0 & chomage=0 & retraite=0) then do;
		cal2=cal1; 
		imput=5;
		end;

	/* Si les revenus ne sont pas suffisants, on impute en priorit� de l'inactivit� 9 */
	nbmois_inact_min=max(0,floor(12-nbmois_ret_max-nbmois_act_max-nbmois_cho_max));
	mois8=min(max(nbmois_inact_min-(12-nbmois_manquants-nbmois_cho-nbmois_act-nbmois_ret),0),nbmois_manquants);

	/*dans les cas de plusieurs types de revenus, on consid�re que leurs niveaux sont li�s, avec 
	l'approximation grossiere qu'un mois de chomage et un mois de retraite correspondent au m�me montant
	qu'un mois d'activit�*/
	if nbmois_manquants-mois8>0 then do;
		if (activite=1 & chomage=1 & retraite=0) then do;
		    mois1=min(max(int((12-nbmois_inact_min)*nbmois_act_max/(nbmois_cho_max+nbmois_act_max))+1-nbmois_act,0),nbmois_manquants-mois8);
			if mois1<=0 & nbmois_act=0 then mois1=1;
			mois3=nbmois_manquants-mois8-mois1; 
			if mois3=0 & nbmois_cho=0 & mois1>1 then do; mois3=1; mois1=mois1-1;end;
			end;
		if (activite=1 & chomage=0 & retraite=1) then do;
			mois1=min(max(int((12-nbmois_inact_min)*nbmois_act_max/(nbmois_ret_max+nbmois_act_max))+1-nbmois_act,0),nbmois_manquants-mois8);
			if mois1<=0 & nbmois_act=0 then mois1=1; 
			mois4=nbmois_manquants-mois8-mois1; 
			if mois4=0 & nbmois_ret=0 & mois1>1 then do; mois4=1; mois1=mois1-1;end;
			end;
		if (activite=0 & chomage=1 & retraite=1) then do;
			mois3=min(max(int((12-nbmois_inact_min)*nbmois_cho_max/(nbmois_cho_max+nbmois_ret_max))+1-nbmois_act,0),nbmois_manquants-mois8);
			if mois3<=0 & nbmois_cho=0 then mois3=1; 
			mois4=nbmois_manquants-mois8-mois3; 
			if mois4=0 & nbmois_ret=0 & mois3>1 then do; mois4=1; mois3=mois3-1;end;
			end;
		end;
	/* quand on a trois types de revenus, on reprend cal1 */ 
	if (activite=1 & chomage=1 & retraite=1) then do; 
		cal2=cal1; 
		imput=6;
		end;	
	run;

/* On remplit cal2 avec les informations mois1, mois3, mois4 et mois8, suivant un ordre pr�cis 
	qui d�pend principalement du premier statut d'activit� connu. */
data complet4(drop=i);
	set complet3;
	if imput=. then do; 
		cal2=cal_anref;
		if PremiereActivObservee='1' then do;
			if mois8>0 then do i=1 to mois8; substr(cal2,i,1)='9';end;
			if mois4>0 then do i=mois8+1 to mois8+mois4; substr(cal2,i,1)='5';end;
			if mois3>0 then do i=mois8+mois4+1 to mois8+mois4+mois3; substr(cal2,i,1)='4';end;
			if mois1>0 then do i=mois8+mois4+mois3+1 to mois8+mois4+mois3+mois1; substr(cal2,i,1)='1';end;
			end;
		if PremiereActivObservee='4' then do;
			if mois8>0 then do i=1 to mois8; substr(cal2,i,1)='9';end;
			if mois4>0 then do i=mois8+1 to mois8+mois4; substr(cal2,i,1)='5';end;
			if mois1>0 then do i=mois8+mois4+1 to mois8+mois4+mois1; substr(cal2,i,1)='1';end;
			if mois3>0 then do i=mois8+mois4+mois1+1 to mois8+mois4+mois3+mois1; substr(cal2,i,1)='4';end;
			end;
		if PremiereActivObservee='5' then do;
			if mois8>0 then do i=1 to mois8; substr(cal2,i,1)='9';end;
			if mois3>0 then do i=mois8+1 to mois8+mois3; substr(cal2,i,1)='4';end;
			if mois1>0 then do i=mois8+mois3+1 to mois8+mois3+mois1; substr(cal2,i,1)='1';end;
			if mois4>0 then do i=mois8+mois3+mois1+1 to mois8+mois4+mois3+mois1; substr(cal2,i,1)='5';end;
			end;
		if PremiereActivObservee not in ('1','4','5') then do;
			if mois8>0 then do i=1 to mois8; substr(cal2,i,1)='9';end;
			if mois4>0 then do i=mois8+1 to mois8+mois4; substr(cal2,i,1)='5';end;
			if mois3>0 then do i=mois8+mois4+1 to mois8+mois4+mois3; substr(cal2,i,1)='4';end;
			if mois1>0 then	do i=mois8+mois4+mois3+1 to mois8+mois4+mois3+mois1; substr(cal2,i,1)='1';end;
			end;
		imput=7;
		end;
	run; 

/* Enregistrement des imputations */
data imput.calendrier;
	merge 	voir_&anref.(keep=ident noi cal_anref) 
			complet4(keep=ident noi cal2 rename=(cal2=cal_anref));
	by ident noi; 
	label cal_anref = "calendrier mensuel d'activit� de &anref. compl�t� avec les revenus fiscaux";
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
