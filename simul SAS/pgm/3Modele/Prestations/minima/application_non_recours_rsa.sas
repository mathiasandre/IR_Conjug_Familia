/************************************************************************************/
/*																					*/
/*				APPLICATION DU TAUX DE NON RECOURS DU RSA ET DE LA PA				*/
/*								 													*/
/************************************************************************************/
/*
	En entrée : imput.recours_rsa_pa
			   	modele.basersa					               	
			   	modele.basepa					               	
	En sortie : modele.rsa    
			   	modele.pa 

Les éligibles non recourants au RSA activité (ou à la PA) ne recourent pas au socle non plus. 
Leur éligibilité est conservée dans une variable dédiée.
*/
/************************************************************************************/
/*
Le principe est de faire un commun RSA et PA après 2016 (et RSA socle - RSA activité avant 2016)

Pour tirer le recours du RSA après la création de la prime d'activité (le RSA activité étant égal à zéro), 
on adopte la même méthode en interchangeant RSA activité et prime d'activité :
- si les foyers RSA et PA sont identiques, les recours de la PA et du RSA activité sont identiques (avant ou après 2016
- pour les nouveaux foyers de PA (jeunes exclus), on adopte le même recours que celui du foyer RSA des parents

Après la création de la prime d'activité, il n'y a pas de tirage sur support commun avec le socle.
Les effectifs dans le fichier param_presta sont nuls pour les cibles de bénéficaires "socle et activité"
*/

proc sort data=imput.recours_rsa_pa ; by ident_rsa; run;
proc sort data=modele.basersa 
			(keep=ident_rsa ident wpela&anr2. pers_iso enf03 e_c separation forf_log 
					m_rsa1-m_rsa4 m_rsa_socle1-m_rsa_socle4 rsa_noel rsaact_eli1-rsaact_eli4) 
		  out=basersa;
	by ident_rsa;
run;

/*Création d'une table avec une ligne par foyer PA, qui récupère la variable indicatrice de recours dans la table input.recours_rsa_pa*/
/*avant 2016, on renomme le RSA-act en PA pour appliquer le taux de recours*/

%macro table_tirage_RSA_PA;

	%if &anleg.< 2016 %then %do;
	  data rsa_pa;
		merge basersa (rename=(rsaact_eli1=pa_eli1 rsaact_eli2=pa_eli2 rsaact_eli3=pa_eli3 rsaact_eli4=pa_eli4))
			  imput.recours_rsa_pa;
		by ident_rsa;
		ident_pa = ident_rsa; /*quand il n'y a pas de PA, les foyers PA "virtuels" sont identiques aux foyers RSA*/
		pac_exclue=0 ;
		%do i=1 %to 4;
			m_rsa&i.= m_rsa_socle&i.;
			drop m_rsa_socle&i.;
			%end;
	  run ;
	%end;

	%if &anleg.>= 2016 %then %do;
	  proc sql ;
	  	create table rsa_pa as
		select	a.ident_rsa, a.ident_pa, a.ident, a.pa_eli1, a.pa_eli2, a.pa_eli3, a.pa_eli4, a.pac_exclue, a.wpela&anr2.,
				b.m_rsa1, b.m_rsa2, b.m_rsa3, b.m_rsa4, b.rsa_noel, b.pers_iso, b.enf03, b.e_c, b.separation,
				c.recours_rsa_pa
		from modele.basepa as a 
				left join basersa as b				on 	a.ident_rsa = b.ident_rsa 
				left join imput.recours_rsa_pa as c	on 	a.ident_pa = c.ident_pa ;
	  	quit ;

	  data rsa_pa; set rsa_pa; by ident_rsa ident_pa ; 
		if first.ident_pa ;
	  	/* Mise à zéro des valeurs manquantes pour les foyers de moins de 25 ans qui ne sont pas dans Basersa */
		/* Bien que pour pers_iso, enf03, e_c et separation on devrait laisser à valeur manquante car on ne sait pas */
		array num _numeric_; do over num; if num=. then num=0; end; 
	  run ;
	  /* TO DO : on supprime un doublon venant de la table modele.BASERSA, qui a priori ne devrait pas exister
		Il faudrait voir dans le pgm RSA.sas d'où vient ce doublon (sans doute liée aux PAC exclues) et corriger le cas échéant */
	%end;
%mend; 
%table_tirage_RSA_PA;

data rsa_pa;
	set rsa_pa;

	%macro application_recours;
		%do i=1 %to 4;		
			pa&i.=pa_eli&i.*(substr(recours_rsa_pa,&i.,1)='1');
			rsa_eli&i.=m_rsa&i.; 
			if pa_eli&i.>0.001 & pac_exclue ne 1 & pa&i.=0 then m_rsa&i. = 0;
			/* > on force le non-recours au RSA si non-recours à la PA SAUF pour les PAC exclues, 
				car pas de recours automatique à la PA pour les PAC seules quand les parents touchent le RSA  */
		%end;
	%mend; 
	%application_recours; 

	if m_rsa4=0 then rsa_noel=0; 

	nonrec_soc1 = (rsa_eli1>m_rsa1);
	nonrec_soc2 = (rsa_eli2>m_rsa2);
	nonrec_soc3 = (rsa_eli3>m_rsa3);
	nonrec_soc4 = (rsa_eli4>m_rsa4);
	length nonrec_socle $4 ; nonrec_socle = compress(nonrec_soc1 !! nonrec_soc2 !! nonrec_soc3 !! nonrec_soc4);

	if &anleg.< 2016 then do;
	/*on renomme dans l'autre sens en 2015 ou avant (avant la création de la pa)*/
		rsaact_eli1 = pa_eli1;
		rsaact_eli2 = pa_eli2;
		rsaact_eli3 = pa_eli3; 
		rsaact_eli4 = pa_eli4;
		rsaact1 = pa1;
		rsaact2 = pa2;
		rsaact3 = pa3; 
		rsaact4 = pa4;
		m_rsa_socle1 = m_rsa1;
		m_rsa_socle2 = m_rsa2;
		m_rsa_socle3 = m_rsa3;
		m_rsa_socle4 = m_rsa4;
		rsasocle_eli1 = rsa_eli1;
		rsasocle_eli2 = rsa_eli2;
		rsasocle_eli3 = rsa_eli3;
		rsasocle_eli4 = rsa_eli4;
	/*on remet à zéro les variables de PA avant sa création*/
		pa_eli1 = 0; pa_eli2 = 0; pa_eli3 = 0; pa_eli4 = 0;
		pa1 = 0; pa2 = 0; pa3 = 0; pa4 = 0;
		m_rsa1 = 0; m_rsa2 = 0; m_rsa3 = 0; m_rsa4 = 0;
		end;

	if &anleg.>= 2016 then do;
		/*on met à zéro les variables de socle et activité après la création de la PA*/
		rsaact_eli1 = 0; rsaact_eli2 = 0;	rsaact_eli3 = 0; rsaact_eli4 = 0; 
		rsaact1 = 0; rsaact2 = 0;	rsaact3 = 0; rsaact4 = 0; 
		m_rsa_socle1 = 0; m_rsa_socle2 = 0; m_rsa_socle3 = 0; m_rsa_socle4 = 0;  
		rsasocle_eli1 =0 ; rsasocle_eli2 =0 ; rsasocle_eli3 =0 ; rsasocle_eli4 =0 ; 
		end;

	patot=sum(0, of pa1-pa4);
	patot_eli=sum(0, of pa_eli1-pa_eli4);
	rsa=sum(0, of m_rsa1-m_rsa4);
	rsa_eli=sum(0, of rsa_eli1-rsa_eli4);
	rsaact_eli=sum(0, of rsaact_eli1-rsaact_eli4);
	rsaact=sum(0, of rsaact1-rsaact4);
	rsasocle=sum(0, of m_rsa_socle1-m_rsa_socle4);
	rsasocle_eli=sum(0, of rsasocle_eli1-rsasocle_eli4);
run;


/* Tables modele.RSA et modele.PA en sortie */

/* La table modele.RSA contient RSA socle et activité avant 2016, et RSA seul à partir de 2016 */
/* On garde ici les foyers PA de moins de 25 ans qui ne sont pas dans modele.BASERSA */
/* TO DO : voir si on les ajoute aussi dans BASERSA > serait plus cohérent  */

%macro sortie_table_RSA_PA ;

/* Table modele.RSA contenant les montants de RSA (et RSA activité avant 2016) */

/* On se situe au niveau du foyer RSA > suppression des lignes correspondant aux PAC exclues pour garder les bons montants de RSA */
  proc sort data=rsa_pa out=rsa (drop = ident_pa pa: nonrec_soc1-nonrec_soc4); by ident_rsa pac_exclue ; run; 
  proc sort data=rsa nodupkey ; by ident_rsa ; run;  

  %if &anleg.< 2016 %then %do;
	data modele.rsa ;
  		set rsa ;
 		keep ident_rsa ident wpela&anr2. pers_iso e_c enf03 separation 
			rsasocle m_rsa_socle1-m_rsa_socle4 rsa_noel nonrec_socle 
			rsaact rsaact1-rsaact4  recours_rsa_pa
			rsasocle_eli rsasocle_eli1-rsasocle_eli4 rsaact_eli rsaact_eli1-rsaact_eli4 
			rsa rsa_eli; /* pour que les programmes suivants tournent */
 	run ;

		/* Table modele.PA (ne contenant aucune observation avant 2016) */
	data modele.pa ;
		set rsa_pa;
		if patot_eli>0 ;
		keep ident_pa ident ident_rsa wpela&anr2. patot pa1-pa4 patot_eli pa_eli1-pa_eli4 pac_exclue recours_rsa_pa ;
	run;
  %end;
  %if &anleg.>= 2016 %then %do;
	data modele.rsa ;
  		merge basersa
		  	  rsa (in=b) ;
  		by ident_rsa ;
		if not b then do ;
			rsa_eli1=m_rsa1 ; 
			rsa_eli2=m_rsa2 ; 
			rsa_eli3=m_rsa3 ; 
			rsa_eli4=m_rsa4 ; 
			rsa_eli=sum(of rsa_eli1-rsa_eli4);
			nonrec_socle='0000' ;
			rsa=sum(of m_rsa1-m_rsa4);
		end ;
		rsasocle=0 ;
		rsasocle_eli=0 ;
		rsaact=0 ;
		rsaact_eli=0 ;

 		keep ident_rsa ident wpela&anr2. pers_iso e_c enf03 separation 
			rsa m_rsa1-m_rsa4 rsa_noel nonrec_socle rsa_eli rsa_eli1-rsa_eli4 
			rsasocle rsasocle_eli rsaact rsaact_eli ; /* Pour que les programmes suivants tournent */
	run ;

	/* Table modele.PA contenant les montants de PA à partir de 2016 (niveau foyer PA) */
	data modele.pa ;
		set rsa_pa;
		if patot_eli>0 ;
		keep ident_pa ident ident_rsa wpela&anr2. patot pa1-pa4 patot_eli pa_eli1-pa_eli4 pac_exclue recours_rsa_pa ;
	run;
  %end;

%mend; 
%sortie_table_RSA_PA ;



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
