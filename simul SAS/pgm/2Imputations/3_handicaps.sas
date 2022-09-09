*************************************************************************************;
/*																					*/
/*									3_handicaps.sas									*/
/*								 													*/
*************************************************************************************;

/* Repérage des personnes en situation de handicap									*/ 
/* En entrée : 	rpm.menage&anr														*/ 
/*				travail.cal_indiv													*/ 
/*				base.baseind 														*/
/* 				base.baserev														*/
/*				travail.irf&anr.e&anr.								           		*/
/*				travail.foyer&anr.									           		*/
/* En sortie : 	imput.handicap														*/
/*				imput.enfant_h                                 						*/

/* PLAN : 
I - Adultes handicapés
 a) Ménages percevant l'AAH ou l'AEEH selon la CAF (uniquement sur le noyau)
 b) Individus déclarant percevoir de l'AAH dans l'enquête emploi
 c) Individus handicapés sur les déclarations fiscales pour les adultes et les enfants
 d) Constitution table individu adulte handicapé

II - Enfants handicapés
 a) Tirage aléatoire d'enfants handicapés dans les extensions
 b) Traitement des enfants handicapés CAF dont on ne connait pas le numéro individuel	

NOTE Dans les cases fiscales signalant des personnes à charge handicapés se trouvent des 
enfants qui ont plus de 21 ans et qui sont donc éligibles à l'AAH et non à l'AEEH. 
On traite les deux cas en en même temps dans la première partie.					
/***************************************************************************************/

/************************************/
/* I - Adultes handicapés 			*/
/************************************/

/* a) Ménages percevant l'AAH ou l'AEEH selon la CAF (uniquement sur le noyau) */
%macro nom_variable_hand;/* Prise en compte du changement de nom de variables de l'ERFS */
	%global m_aah m_aeehm;
	%let m_aah = m_aahm;
	%let m_aeehm= m_aeehm;
	%if &anref. = 2008 %then %do;
		%let m_aah = m_aah_caahm;
		%end;
	%if &anref. <= 2007 %then %do;
		%let m_aeehm= m_aesm;
		%end;
	%mend;
%nom_variable_hand;

data menage_AAH_caf menage_AEEH_caf; 
	set rpm.menage&anr.(keep=ident&anr. &m_aah. &m_aeehm. rename=(ident&anr.=ident));
	if &m_aah.>0 then output menage_AAH_caf;
	if &m_aeehm.>0 then output menage_AEEH_caf;
	run;

/* b) Individus déclarant percevoir de l'AAH dans l'enquête emploi 			*/ 
data individu_handicap_EE;
	set travail.cal_indiv(keep = ident noi cal_aah);
	if index(cal_aah,'1')>0;
	run;

/* c) Individus handicapés sur les déclarations fiscales pour les adultes et les enfants */ 
proc sql;
	create table handi_fisc (drop=declar) as
	select	* from base.baseind as a
			left outer join
			(select declar, sif as sif1, anaisenf as anaisenf1 from travail.foyer&anr.) as b
			on a.declar1=b.declar;
	quit;
proc sql undo_policy=none;
	create table handi_fisc (drop=declar) as
	select	* from handi_fisc as a
			left outer join
			(select declar, sif as sif2, anaisenf as anaisenf2 from travail.foyer&anr.) as b
			on a.declar2=b.declar;
	quit; 

data individu_handicap_fisc;
	set handi_fisc (keep=ident noi declar1 declar2 sif1 sif2 naia anaisenf1 anaisenf2 persfip persfipd wpela&anr.);

	/* Déclarant : la case P indique s'il est titulaire d'une pension d'invalidité d'au moins 40% ou carte d'invalidité au moins 80% */
	if substr(sif1,21,1)='P' & noi=substr(declar1,1,2) then ah=1;	
	if substr(sif2,21,1)='P' & noi=substr(declar2,1,2) then ah=1;	

	/* Conjoint du déclarant : la case F indique la même chose que la case P pour le conjoint */
	if substr(sif1,17,1)='F' & noi ne substr(declar1,1,2) & naia=substr(sif1,11,4) then ah=1;
	if substr(sif2,17,1)='F' & noi ne substr(declar2,1,2) & naia=substr(sif2,11,4) & persfipd ne '' then ah=1;

	/* Personnes à charge (qui peuvent être adultes (+21 ans))*/ 
	debut_F=find(sif1,' F0',20); /* à partir du 20ème caractère car certains cas sont bizarres (on peut trouver un 'F' trop tôt dans le sif) */
	if debut_F=0 then debut_F=find(sif1,' F1',20);
	if debut_F ne 0 then do;
		nbenf1=substr(sif1,debut_F+1,24);
		nbg1=input(substr(nbenf1,5,2),2.); /* nombre d'enfants non mariés à charge titulaires de la carte d'invalidité sur declar1 */
		nbr1=input(substr(nbenf1,8,2),2.); /* nombre de personnes invalides vivant sous le même toit sur declar1*/
		nbi1=input(substr(nbenf1,20,2),2.); /* nombre d'enfants non mariés en résidence alternée titulaires de la carte d'invalidité, sur declar1 */
		end;
	else do; nbg1=0; nbr1=0; nbi1=0; end;

	debut_F=find(sif2,' F0',20); /* à partir du 20ème caractère car certains cas sont bizarres (on peut trouver un 'F' trop tôt dans le sif) */
	if debut_F=0 then debut_F=find(sif2,' F1',20);
	if debut_F ne 0 then do;
		nbenf2=substr(sif2,debut_F+1,24);
		nbg2=input(substr(nbenf2,5,2),2.);
		nbr2=input(substr(nbenf2,8,2),2.);
		nbi2=input(substr(nbenf2,20,2),2.);
		end;
	else do; nbg2=0; nbr2=0; nbi2=0; end;

	if nbg1>0 ! nbr1>0 ! nbi1>0 ! nbg2>0 ! nbr2>0 ! nbi2>0 then do; /*Identification d'une personne a charge invalide dans le foyer */
		do i=0 to ((length(anaisenf1)-5)/5) ;
			if substr(anaisenf1,1+i*5,1) in ('G','R','I') & naia=substr(anaisenf1,2+i*5,4) then do; 
				if &anref.-input(naia,4.) <=&b_age_PF. then eh=1; else ah=1;
				end;
			end;
		do i=0 to ((length(anaisenf1)-5)/5) ;
			if substr(anaisenf2,1+i*5,1) in ('G','R','I') & naia=substr(anaisenf2,2+i*5,4) then do; 
				if &anref.-input(naia,4.) <=&b_age_PF. then eh=1; else ah=1;
				end;
			end;
		end;
	if eh=1 or ah=1; /* adulte/enfant handicapé selon la déclaration fiscale*/
	drop debut_F i;
	run;

/* d ) Constitution d'une table d'individus adultes handicapés */
proc sort data=individu_handicap_fisc; by ident noi; run; 
proc sort data=individu_handicap_EE; by ident noi; run; 

data individu_handicap_fisc_EE (keep=ident noi handicap); 
	merge 	individu_handicap_fisc(in=a where=(ah=1)) 
			individu_handicap_EE(in=b); 
	by ident noi; 
	if b then handicap=1; 
	else handicap=2;
	run;

data individu_handicap_fisc_EE (keep= ident noi handicap) /* individus */
	 menage_AAH ; /* ménages : il faut attribuer le handicap à un de ses membres */
	merge 	individu_handicap_fisc_EE (in=a) 
			menage_AAH_caf (in=b); 
	by ident; 
	if a then output individu_handicap_fisc_EE;
	if b & not a then output menage_AAH;
	run;
/* HYPOTHESE : on attribue le handicap à l'adulte de plus de 20 ans ayant le moins de revenus d'activité dans le ménage */
data menage_AAH (keep=ident noi naia rev_ind);
	merge	menage_AAH (in=a)
			base.baseind (keep=ident noi naia)
			base.baserev (keep=ident noi zsali&anr. zragi&anr. zrici&anr. zrnci&anr.);
	by ident;
	if a & (&anref.-input(naia,4.)>=20);
	rev_ind=sum(zsali&anr., zragi&anr., zrici&anr., zrnci&anr.);
	run;
proc sql;
	create table individu_handi_caf 
	as select * from menage_AAH
	group by ident having rev_ind=min(rev_ind)
	order by ident;
	quit;
proc sort data=individu_handi_caf nodupkey ; by ident ; run;

/* sauvegarde */
data imput.handicap (keep=ident noi handicap);
	set individu_handicap_fisc_EE 
		individu_handi_caf (in=c);
	if c then handicap=3;
	run;
proc sort data=imput.handicap; by ident noi; run;

/************************************/
/* II - Enfants handicapés 			*/
/************************************/

/* a) Tirage aléatoire d'enfants handicapés */ 

/* 	Si un enfant a un taux d'incapacité compris entre 50% et 80% et qu'il fréquente une école spécialisée ou que son état 
	nécessite des soins, il donne droit à l'AEEH mais ne possèdera pas de carte d'invalidité (pour laquelle il faut un taux
	d'incapacité supérieur à 80%). Sans carte d'invalidité, il ne peut être déclaré comme invalide au fisc. 
	De ce fait, et peut-être à cause d'une sous-déclaration fiscale, il manque des enfants handicapés qui permettraient
	de toucher l'AEEH qu'on souhaite simuler (il semble qu'on a qu'un tiers des enfants éligibles à l'AEEH avec les déclarations fiscales). 
	On ajoute donc aux jeunes handicapés des décalarations fiscales les ménages repérés comme bénéficiaires de l'AEEH 
	(mais non retrouvés dans les fichiers fiscaux).
	Comme on peut observer une augmentation importante du nombre de bénéficiaires de l'AEEH d'une année sur l'autre et que ceux observés dans l'ERFS
	le sont en N-2, on tire également aléatoirement des jeunes handicapés au nombre de N=(nb de jeunes bénéficiaires de l'AEEH-nb de jeunes récupérés dans les déclarations
	- nb de jeunes récupérés avec l'information CNAF). */

/* On compte le nombre de jeunes handicapés déjà repérés */
data enfants_handicapes_ERFS (keep= ident enfant_handicap);
	set menage_AEEH_caf individu_handicap_fisc (where=(eh=1));
	by ident;
	enfant_handicap=1;
	if first.ident;
	run;
proc sql noprint;
	select sum(wpela&anr.)*(enfant_handicap=1)
	into :nb_eh_ERFS
	from enfants_handicapes_ERFS as a left join base.baseind as b
	on a.ident=b.ident
	where b.noi="01"; /* por ne compter qu'un poids par ménage */
	quit;

/* On fait le tirage au sein des ménages qui n'ont pas déjà un jeune handicapé */
proc sort data=base.baseind; by ident noi; run;
proc sort data=enfants_handicapes_ERFS; by ident; run;
data tirage;
	merge 	base.baseind (keep=naia noi ident wpela&anr. in=a) 
			        enfants_handicapes_ERFS (in=b drop=enfant_handicap);  
	by ident; 
	if &anref.-input(naia,4.)<=&b_age_PF. and not b; 
	tirage=ranuni(1); 
	run;

/* On tire assez de jeunes aléatoirement pour compenser un éventuel manque de jeunes déjà repérés dans l'ERFS */
proc sort data=tirage; by tirage; run; 
data enfant_handicap_aleat 
	(where=(somme_poids<=max(0,%sysevalf(&maraeeh00.+&maraeeh01.+&maraeeh02.+&maraeeh03.+&maraeeh04.+&maraeeh05.+&maraeeh06.-&nb_eh_ERFS.))));
	set tirage;
	retain somme_poids 0;
	somme_poids=somme_poids+max(0,wpela&anr.);
	run; 

proc sort data=enfant_handicap_aleat; by ident noi; run; 
data enfant_handicap(keep= ident noi handicap_e wpela&anr.); 
	merge 	menage_AEEH_caf(in=a) 
			individu_handicap_fisc(in=b where=(eh=1))
			enfant_handicap_aleat(in=c); 
	by ident; 
	length handicap_e $ 14;
	if a then handicap_e='source CNAF'; /* ménage percevant l'AEEH selon la CAF (noyau seulement) */
	else if b then handicap_e='source fiscale'; /* enfant handicapé selon les déclarations fiscales mais hors ménages percevant l'AEEH selon la CAF */
	else handicap_e='tirage au sort'; /* enfant tiré au sort */ 
	label handicap_e="Source du handicap de l'enfant";
	run;


/* b) Traitement des enfants handicapés CAF sans noi (donc ceux qui ne sont pas identifiés comme tels fiscalement) */ 

/* On choisit un enfant au hasard dans les ménages percevant de l'AEEH en faisant 
	HYPOTHESE : il n'y a qu'un enfant handicapé par ménage (faux dans 4% des cas) */

data tirage2; 
	merge 	enfant_handicap(where=(noi='') in=a) 
			base.baseind(keep=ident noi persfip naia wpela&anr.); 
	by ident; 
	if a; 
	if &anref.-input(naia,4.)<=&b_age_PF. and persfip in ('pac',''); 
	classement=ranuni(1); 
	run;
proc sort data=tirage2; by ident classement; run; 
data enfant_handicap_CAF; 
	set tirage2;
	by ident; 
	if first.ident;
	run; 

/* sauvegarde */
data imput.enfant_h(keep=ident noi handicap_e wpela&anr.); 
	set enfant_handicap(where=(noi ne ''))
		enfant_handicap_CAF;
	run; 

proc sort data=imput.enfant_h; by ident noi; run; 


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
