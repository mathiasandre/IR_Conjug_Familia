/********************************************************************/
/*																	*/
/*								CAAH								*/
/*																	*/
/********************************************************************/

/* Modélisation du Complément Allocation Adulte Handicapée			*/
/* En entrée : modele.baseind 										*/
/*			   modele.baselog										*/
/*			   imput.accedant										*/
/*			   base.baserev 										*/
/* En sortie : modele.baseind                                     	*/

/********************************************************************/
/* PLAN : 															*/
/* A. Création de la table des bénéficiaires potentiels				*/
/* B. Calcul du montant du complément d'allocation					*/
/********************************************************************/
/* REMARQUE : 														*/
/* Le complément d'allocation peut être sous deux formes :			*/
/* - la majoration pour la vie autonome 							*/
/* - la garantie de ressources										*/
/* Les deux ne sont pas cumulables. Nous faisons l'hypothèse que 	*/
/* l'allocataire choisit celle dont le montant est le plus 			*/
/* important.														*/


%macro calcul_MVA(anleg);
	/* Montant de la majoration pour la vie autonome */
	%if &anleg.<2012 %then %do;
		max(&aah_mva.*12,&afh.*&aah_mont.)
		%end;
	%else %do; 
		&aah_mva.*12
		%end;
	%mend calcul_MVA;
/********************************************************************/
/* A. Création de la table des bénéficiaires potentiels				*/
/********************************************************************/
/* Conditions d'éligibilité :
1) être dans un logement indépendant donc n'avoir qu'1 famille dans le ménage
2) percevoir l'aah à taux plein ou à taux réduit si c'est en complèment de l'ASI
3) ne pas exercer d'activité professionnelle
4) ne pas être une personne à charge*/

/* Condition 1 : être dans un logement indépendant donc n'avoir qu'1 famille dans le ménage */
proc sql;
	create table men_avec1fam(where=(nbfam=1)) as
		select ident, count(distinct ident_fam) as nbfam
		from modele.baseind (keep=ident ident_fam)
		group by ident;
	create table log_indep
		(where=(aah>0 & (aah_taux='p'!(&anleg.>=2010 & asi>0)) 	/* condition 2 : percevoir l'aah à taux plein ou à taux réduit si c'est en complèment de l'ASI */
				& statut_fam ne 'pac')) 						/* condition 4 : ne pas être une personne à charge */					
		as select a.* 
		from modele.baseind (keep=ident noi ident_fam ident_log statut_fam aah aah_taux asi naia cal0) as a inner join men_avec1fam as b
		on a.ident=b.ident;
	create table elig_caah (where=(zact&anr2.=0 and index(cal0,'1')=0)) as	/* condition 3 : ne pas exercer d'activité professionnelle */
		select a.*, zsali&anr2.+zragi&anr2.+zrici&anr2.+zrnci&anr2. as zact&anr2.
		from log_indep as a inner join base.baserev(keep=ident noi zsali&anr2. zragi&anr2. zrici&anr2. zrnci&anr2.) as b
		on a.ident=b.ident and a.noi=b.noi;

/********************************************************************/
/* B. Calcul du montant du complément d'allocation					*/
/********************************************************************/
	/* Rajout des AL */
	create table elig_caah2 as
		select a.*, b.al 
		from elig_caah as a left join modele.baselog(keep=ident_log al) as b
		on a.ident_log=b.ident_log;
	create table elig_caah3 as
		select a.*, b.alaccedant 
		from elig_caah2 as a left join imput.accedant(keep=ident alaccedant) as b
		on a.ident=b.ident;
	/* Calcul du montant */
	create table caah as
		select ident, noi, %calcul_MVA(&anleg.)*(al>0!alaccedant>0) as mva, /* Majoration pour la vie autonome */
			&garant_res.*12*(max(0,zact&anr2.)=0 & (&anref.-input(naia,4.))<60) as grph /* Garantie de ressources */
		from elig_caah3
		order by ident,noi;
	quit;

proc sort data=caah nodupkey; by ident noi; run;

/* Une des conditions pour toucher le complément de ressources est d'avoir une capacité de travail inférieure à 5%
du fait du handicap. Comme on n'observe pas cette condition, on tfait un tirage du nombre de bénéficiaires du complément 
de ressources (sinon, on observe trop de bénéficiaires du complément de ressources au détriment des bénéficiaires de la mva,
la premier étant plus avantageux que le second) */
proc sql;
	create table table_tirage_grph as
	select a.ident, a.noi, a.grph, b.wpela&anr2., ranuni(1) as alea from
	caah as a left join modele.baseind as b
	on a.ident=b.ident and a.noi=b.noi
	where a.grph>0
	order by alea;
	quit;


data table_tirage_grph;
	set table_tirage_grph;
	by alea;
	retain ben 0;
	ben=ben+wpela&anr2.;
	if ben > &nb_benefs_grph. then grph=0;
	run;

proc sort data=table_tirage_grph nodupkey; by ident noi; run;
data caah;
	merge caah (drop=grph)
		  table_tirage_grph (drop= ben wpela&anr2. alea);
	by ident noi;
	caah=max(mva,grph);
	if grph=. then grph=0;
	run;

proc sort data=modele.baseind; by ident noi; run;
data modele.baseind;
	merge 	modele.baseind(in=a)
			caah (keep=ident noi caah);
	by ident noi;
	if a;
	run;

proc delete data=elig_caah elig_caah2 elig_caah3 caah log_indep men_avec1fam; run;

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
