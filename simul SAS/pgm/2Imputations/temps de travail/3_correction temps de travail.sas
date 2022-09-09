/****************************************************************************/
/*																			*/
/*					3_correction temps de travail							*/
/*								 											*/
/****************************************************************************/

/* Correction de donn�es manquantes sur le temps d'activit�		 			*/
/* En entr�e : 	base.baseind												*/
/*				base.foyer&anr.												*/
/*				travail.indivi&anr.											*/
/*				travail.irf&anr.e&anr										*/
/*				imput.calendrier											*/
/* En sortie : 	base.baseind												*/

/* REMARQUES :																*/
/* - Dans la construction de la variable hor, seule la proportion du temps	*/
/* plein nous int�resse, et pas les vrais horaires 							*/


/* R�cup�ration des revenus issus d'heures suppl�mentaires exon�r�es */
%macro recupere_hsup(anr);
	proc sql;
		create table hsup_ind&anr. as
			select a.*, _hsupVous, _hsupConj, _hsupPac1, _hsupPac2, _hsupVous2, _hsupConj2
			from base.baseind(keep=declar1 declar2 persfip persfipd ident noi naia) as a
			inner join base.foyer&anr.(keep=declar _hsupVous _hsupConj _hsupPac1 _hsupPac2 rename=(declar=declar1)) as b
			on a.declar1=b.declar1
			left join base.foyer&anr.(keep=declar _hsupVous _hsupConj _hsupPac1 _hsupPac2 rename=(declar=declar2 _hsupVous=_hsupVous2 _hsupConj=_hsupConj2 _hsupPac1=_hsupPac12 _hsupPac2=_hsupPac22)) as c
			on a.declar2=c.declar2
			order by declar1,ident,naia;
		quit;
	data hsup_ind&anr. (keep=ident noi hsup&anr.);
		set hsup_ind&anr.;
		by declar1 ident naia;
		retain pac;
		if first.declar1 then pac=0;
		if persfip='vous' then hsup&anr.=_hsupVous;
		if persfip='conj' then hsup&anr.=_hsupConj;
		if persfip='pac' & pac=0 then do; hsup&anr.=_hsupPac1; pac=1;end;
		else if persfip='pac' & pac=1 then do; hsup&anr.=_hsupPac2; pac=2;end;
		else if persfip='pac' & pac=2 then hsup&anr.=0;
		if declar2 ne '' then do; 
			if persfipd='mon' then hsup&anr.=sum(hsup&anr.,_hsupVous2);
			if persfipd='mad' then hsup&anr.=sum(hsup&anr.,_hsupConj2);
			end;
		label hsup&anr.="Revenus d'heures suppl�mentaires pour &anref., exon�r�s si effectu�s avant ao�t 2012";
		run;
	proc sort data=hsup_ind&anr.; by ident noi; run;
	%mend recupere_hsup;
%recupere_hsup(&anr.);
%recupere_hsup(&anr2.);

/* id�e : on cherche � remplir l'heure et � mettre les statuts en coh�rence*/
/* d�sormais, beaucoup de contr�le de coh�rence qui n'�tait pas fait dans les anciennes enqu�tes EEA */
/* d�sormais, tout le monde a un CSTOT, et tout le monde a un p ou un csa ou a toujours �t� inactifs (CSTOT>80) */
/* on a par contre des gens avec p et csa en m�me temps (sans doute ils viennent de trouver du boulot) et hhc ='' */
/* on a  �galement des gens avec p='0000'*/
proc sql;
	create table tempstravail as
	select c.*, cal0, cotis_special, zsali, zchoi
	from imput.calendrier(keep=ident noi cal0 cotis_special) as a
	inner join travail.indivi&anr.(keep=ident noi zsali zchoi) as b
	on a.ident=b.ident and a.noi=b.noi
	left join travail.irf&anr.e&anr(keep=ident noi p statut titc tpp tppred hhc empnbh csa duhab txtppred cstot pub3fp acteu6 &NAF. nafg088un echpub) as c
	on a.ident=c.ident and a.noi=c.noi
	order by ident,noi;
	quit;

data tempstravail;
	merge 	tempstravail (in=a)
			hsup_ind&anr.
			hsup_ind&anr2.;	
 	by ident noi;
	if a;
	/*on se sert de la naf (secteur de l'�tablissement) pour trois choses :
		a-savoir si on est dans une entreprise � statut particulier (france t�l�com, edf, poste) : nafg36=N1
	mais cela est remplac�, voir plus loin.
		b-savoir si on est restaurateur
		c-savoir si on est employ� par un particulier
	Les noms nafg36 sont des nom historique correspondant � l'ancienne naf avant anref 2009. */
	%init_valeur(restaurateur,valeur=0);

	if &NAF. ne '' then do; 
		if (input(substr(&NAF.,1,2),2.)>=55 & input(substr(&NAF.,1,2),2.)<=56) then restaurateur=1; 
		emploi_particulier=(&NAF. in ('950Z','853J'))*(&anref.<2008)+(&NAF. in ('9700Z','8810A'))*(&anref.>=2008);
		end;
	label emploi_particulier="Employ� par un particulier";

	/* On s'occupe plus bas des gens dont on ne sait rien */  
	if p='0000' and acteu6 ne '1' then p=''; 

	%nb_mois(cal0,nbmois_sal,1); 
	label nbmois_sal="Nombre de mois travaill�s (ou fraction de mois)";

	if zsali>0 and nbmois_sal=0 then nbmois_sal=12;

	if p ne '' then do; 			/* Sous-champ des gens qui travaillent (salarie + prof liberal)*/
		/* Arrondi au nb d'heure sup�rieur de hhc et empnbh � partir de la 21e minute */
		if hhc ne '' then do;		/* hhc : nb moyen d'heures travaill�es dans l'emploi pcpal */
			if input(hhc,4.)-floor(input(hhc,4.))>0.3 then hor=floor(input(hhc,4.))+1; 
			else hor=floor(input(hhc,4.));
			end;
		if hor=. and EMPNBH ne '' then do; /* empnbh : nb  d'heures effectu�es ds l'emploi principal pdt semaine r�f�rence*/
			if input(empnbh,4.)-floor(input(empnbh,4.))>0.3 then hor=floor(input(empnbh,4.))+1;
			else hor=floor(input(empnbh,4.));
			end;
		
		/* Correction de la profession*/ 
		if p='0000' then do; 
			if csa ne '' then p=csa!!'9f'; /*construction de la variable � partir de la CS du dernier emploi occup�*/
			else p='564b'; /* � d�faut, on lui donne la profession 'Employ�s des services divers' */
			end;

	    /* Correction du statut des agents de Etat & des collectivites territoriales : par d�faut titulaires */
	    if titc='' then do;
	       	if cstot in ('33','34','42','43','45','52','53') then titc='2';
			end;

		/* Correction du caract�re public ou priv� de employeur */
	    if pub3fp='' then do;
			if cstot in ('33','34','42','45','52','53') then pub3fp='1';
			else if cstot='43' then pub3fp='2';/*si Professions interm�diaires de la sant� et du travail social, on met pub3fp=2 h�pitaux publics */
	   		end;
		end; 	

	/* compl�ment des bases par ajout des variables et controle des temps de travail*/ 
	if p ne '' and zsali>0 and nbmois_sal>0 then do; /* Sous-champ des salari�s */

	    /* Variable temps complet et temps partiel */
		if tppred='1' then temps='complet';
	    else if tppred='2' then temps='partiel';
		else if tpp='1' then temps='complet';
	    else if tpp='2' then temps='partiel';
		label temps="Quotit� de temps de travail";

		/* Contractuel */
		if statut in ('43','44') /* non titulaires Etat et coll loc: CDD, Stagiaires et contrats aides (Etat, coll loc)*/
	     or (statut='35' & p in ('341a','342a','421a',/*'4214',*/'422c','422b') ) 	/* Personnel enseignant de l'enseignement prive */
		 or (statut='35' & p in ('333d','451b','521b'))    /* France telecom et poste : cf ci-dessous */
		then contractuel=1;
		else contractuel=0;

	    /* Droit au suppl�ment familial de traitement */
	    if statut='45' & (titc='1' ! titc='2' ) then sftd=1; /* Fonctionnaires de l'Etat et des coll loc en CDI */
	    if statut='35' & p in ('341a','342a','421a',/*'4214',*/'422c','422b') then sftd=1; /* Personnel enseignant de l'enseignement prive */
	    /* France telecom et poste 
		remarque jusqu'en 2012 on faisait �a :  if statut='35' & nafg36='N1' then sftd=1;
		sans trop de validation externe sur le montant du SFT, on a r�duit le nombre de b�n�ficiaire en
		regardant comment il d�clarait leur profession. On peut en effet penser avec l'ouverture des march�s
		que tous les coursiers ne travaillent pas pour la poste et encore plus que tous les agents de t�l�com ne
		sont pas chez orange-france t�l�com, il faudrait demander � l'enquete emploi ce qu'ils en pensent*/
	    if statut='35' & p in ('333d','451b','521b') then sftd=1;
		label sftd="Droit au Suppl�ment familial de traitement";

	    /* Cadre et non cadre */
	    if statut in('11','12','13','21','22','33','34','35') then do; 
	    	if cstot in ('33','34','35','37','38') then cst2='cadpriv';
			else cst2='ncadpri';
			end;
		label cst2="Cadre ou non cadre";
			
		/* Nombre d'heures travaill�es */
		if temps='complet' then hor=&b_tdt.; /*35h mais reduit dans bien des cas plus loin*/
		if temps='partiel' and (hor>&b_tdt. or hor=.) then do; 
			if txtppred='1' then hor=round(&b_tdt.*1/2)-1; 
			if txtppred='2' then hor=round(&b_tdt.*1/2); 
			if txtppred='3' then hor=round(&b_tdt.*1/2)+1; 
			if txtppred='4' then hor=round(&b_tdt.*4/5); 
			if txtppred='5' then hor=round(&b_tdt.*4/5)+1;
			end;
		if hor=. then hor=0;
		label hor="Nombre d'heures travaill�es"; 
		
		/* cas particulier des hotels-restaurants*/
		if restaurateur=1 then do;
			if zsali/(nbmois_sal*max(1,hor))<&b_smica_dec./(12*39) then do; 
				hor=max(1,round((zsali*12*&b_tdt.)/(nbmois_sal*&b_smica_dec.)));
				temps='partiel';
				end; 
			else do; 
				hor=39;
				temps='complet'; 
				end;
			end;

		/* Mise en conformit� des horaires, du salaire et du SMIC */
		/* on fait une erreur sur les fonctionnaires dont le salaire minimum est sup�rieur au SMIC*/ 
		if statut in ('11','12','21','23','34','35','44','45') & not (emploi_particulier=1 & p in ('563a')) then do;

		  /* On borne le temps partiel � 35 h */ 
			if temps='partiel' & restaurateur=0 & hor>=35 then do;
			    hor=round(&b_tdt.-1); /* On ne remet pas � temps complet � cause de l'annualisation */
				end;
			end;

		/* Personnes avec salaires mais sans heures : nb d'heures en fonction de leur revenu */
		if hor=0 then do; 
			hor=min(max(1,round(zsali/nbmois_sal/&b_smica_dec./(12*&b_tdt.))),&b_tdt.);
			if temps='' then do;
				if hor=&b_tdt. then temps='complet';
				else temps='partiel'; 
				end; 
			end;

		/* s'il y a eu changement l�gale de la dur�e du travail */
		hor=hor*&b_tdt./35; /*mais attention aux traitement des heures*/
		end;

	/* Traitement des individus sans profession dans l'enqu�te emploi et auxquels on a rajout� de l'activit� dans le calendrier */ 
	/* On leur donne une profession arbitraire et un statut pour le calcul des cotisations */ 
	if p='' and zsali>0 then do;
		temps='complet'; 
		p='564b';
		hor=&tpstra.; 
		sftd=0; 
		contractuel=0; 
		emploi_particulier=0;
		statut='35'; 
		cst2='ncadpri';
		end;

	/* En dernier, si le salaire est inf�rieur au SMIC, on corrige le nb de mois salari�s */
	if hsup&anr.=. then do;
		hsup&anr.=0; /* Correction pour les EE pour qui on ne r�cup�re pas de r�mun�rations hsup&anr. car pas de d�claration fiscale */
		hsup&anr2.=0;
		end;
	if zsali>0 then nbmois_sal=min(nbmois_sal,12*(zsali-hsup&anr.)/&b_smica_dec.*hor/&b_tdt.);

	/* On calcule �galement le nb de mois de ch�mage */
	%nb_mois(cal0,nbmois_cho,4);
	label nbmois_cho="Nombre de mois de ch�mage";
	if zchoi>0 and nbmois_cho=0 then nbmois_cho=max(1,12-nbmois_sal); /* Si l'individu d�clare du ch�mage indemnis� aux imp�ts, on force le nb de mois 
	de ch�mage � 12-nbmois_sal pour �tre coh�rent avec la trimestrialisation des ressources, mais on limite aussi � ce qu'il y fait forc�ment du ch�mage */

	/* Cas du cumul emploi � temps partiel + indemnit�s chomage (activit� r�duite)
	-> le nombre de mois de chomage est recalcul� pour que l'alloc ne descende pas en dessous de l'ARE minimale */
	if cotis_special= 'trav partiel+chom' then nbmois_cho=min(12,(zchoi/(&ass_mont.)));
	run;

proc sort data=base.baseind; by ident noi; run;
proc sort data=tempstravail; by ident noi; run;
data base.baseind; 
	merge 	base.baseind (in=a)	
			tempstravail(in=b keep= ident noi p statut csa pub3fp emploi_particulier cotis_special temps hor cst2 contractuel sftd nafg088un nbmois_sal nbmois_cho hsup: echpub);  
	by ident noi;
	if a; 
	if b then champ_cotis=1; else champ_cotis=0;
	label contractuel = "contractuel de la fonction publique";
	label cotis_special = "statut particulier pour le calcul des cotisations";
	label champ_cotis = "champ du calcul des cotisations";
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
