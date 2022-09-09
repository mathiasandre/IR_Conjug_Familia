/************************************************************************************
/*																					*/
/*								forf_log											*/
/*																					*/
/************************************************************************************/

/* Ce pgm calcule le forfait logement et finalise le calcul du rsa et de la PA 		*/
/* avant application du taux de recours pour le rsa et la PA 						*/
/* En entr�e : modele.basersa 														*/
/*			   base.menage&anr2														*/
/*			   modele.baseind														*/
/*			   modele.baselog														*/
/*			   imput.accedant														*/		
/* En sortie : modele.basersa                                     					*/
/************************************************************************************/
/* PLAN : 																			*/
/* A. Calcul des aides au logement per�ues par les foyers rsa						*/
/* B. Calcul du forfait logement													*/
/* C. Finalisation du calcul du RSA (dont d�finition du rsa activit�) 				*/
/************************************************************************************/
/* NOTE : 																			*/
/* Ce programme calcule le forfait logement � d�duire du rsa et de la PA  			*/
/* pour les tous les b�n�ficiaires d'un avantage en termes de logement :		   	*/
/* - avantage en nature : pour tous les propri�taires et personnes h�berg�es � 		*/
/*	titre gratuit																	*/
/* - avantage mon�taire : pour tous les acc�dants et locataires b�n�ficiaires d'AL	*/
/************************************************************************************/

/*macro qui s'applique au RSA et � la PA (apr�s 2016) */
%Macro ForfaitLogement(ma_table);

/*************************************************************/
/* A. Calcul des aides au logement per�ues 					 */
/*************************************************************/

	/* R�cup�ration du statut d'occupation du logement de la base m�nage et des AL per�ues */
	proc sql ; 
  	create table &ma_table._ind as
  	select a.ident_rsa, 
		   b.ident_log,
		   c.AL, 
		   d.alaccedant,
		   e.logt
  	from modele.&ma_table. as a
	   	 left join modele.baseind AS b		on 	a.ident_rsa = b.ident_rsa 
  	     left join modele.baselog AS c 		on 	b.ident_log = c.ident_log 
   	     left join imput.accedant AS d 		on 	a.ident = d.ident 
 	     left join base.menage&anr2. AS e	on 	a.ident = e.ident 
	where a.ident_rsa >"" ;
	quit ;
	/* note : pour les FIP, ident_rsa renseign� mais pas ident_fam ni ident_log > pas de calcul d'AL pour eux */

	/* on enl�ve les doublons sur ident_rsa * ident_log */
	proc sort data= &ma_table._ind out=&ma_table._log nodupkey ; by ident_log ident_rsa ; run ;

	/* On modifie le statut d'occupation pour les enfants de plus de 20 ans qui habitent avec leurs parents (absents de modele.baselog) */
	proc sort data= modele.baselog ; by ident_log ; run ;
	data &ma_table._log2 ;
	  merge &ma_table._log (in=a )
  			modele.baselog (in=b keep=ident_log) ;
	  by ident_log ;
	  if a ;
	  if not b and ident_log>"" and logt in ("3","4","5") then logt2="6" ; else logt2=logt ;
	run ; 

	/* Calcul des AL per�ues par le foyer ident_rsa */
 
	proc sql ;
	  create table &ma_table._log3 as
	  select *, max(al) as al_tot, count(distinct ident_log) as nblog 
	  from &ma_table._log2 
	  group by ident_rsa ;
	quit ;
	/* Correctif : on ne fait pas la somme des AL pour les acc�dants (ni pour les locataires) */

	/* table au niveau du foyer ident_rsa */
	/* Un seul statut d'occupation par foyer : s'il est compos� de 2 foyers logements dont un log� gratuit, on garde l'autre statut */ 
	proc sort data=&ma_table._log3 ; by ident_rsa logt2 ; run ;
	data &ma_table.1 ; 
	  set &ma_table._log3 (keep=ident_rsa al_tot alaccedant logt2) ; 
	  by ident_rsa logt2 ; 
	  if first.ident_rsa ; 
	  rename al_tot = al ; 
	run ;

	/*********************************/
	/* B. Calcul du forfait logement */
	/*********************************/

	/* Finalisation du calcul du forfait logement par rapport � sa valeur th�orique FL_theorique */
	data &ma_table.;
		merge modele.&ma_table.(in=a) 
			  &ma_table.1 (in=b);
		by ident_rsa; 					
		if a;

		array tout _numeric_; 
		do over tout; 
			if tout=. then tout=0;
			end;
		%init_valeur(forf_log);
		forf_log=FL_theorique;

		/* Pour les locataires non aid�s: FL=0*/
		if logt2 in ('3','4','5') & al=0 then forf_log=0;
		/* Pour les locataires/propri�taires ayant une aide : 
		si FL>montant de l'allocation => on retire le montant de l'AL.  
		Dans ces cas, on attribue directement au FL la valeur de l'AL � d�duire*/
		if logt2 in ('3','4','5') & al>0 & forf_log>al/12 then forf_log=al/12;
		if logt2 in ('1','2') & alaccedant>0 & forf_log>alaccedant/12 then forf_log=alaccedant/12; 
	run;
%Mend ForfaitLogement;

%ForfaitLogement(basersa);

/**********************************************************************/
/* C. Finalisation du calcul du RSA (dont d�finition du rsa activit�) */
/**********************************************************************/

%Macro Final_RSA;

	data basersa; 
		set basersa;
		%if &anleg.<2016 %then %do ;
			%do i=1 %to 4;
				/* D�duction du forfait logement des droits � rsa */
				m_rsa&i.=m_rsa_th&i.-3*forf_log;
				m_rsa_socle&i.=max(m_rsa_socle_th&i.-3*forf_log,0);
				/* Application du seuil de versement sur le rsa total et sur le socle */
				if m_rsa&i.<3*&rsa_min. then m_rsa&i.=0;
				if m_rsa&i.=0 then m_rsa_socle&i.=0;
				/* D�fnition du rsa activit� */
				rsaact_eli&i. = m_rsa&i. - m_rsa_socle&i.;
				%end;
			/* prime de Noel � z�ro si pas de RSA */
			if m_rsa_socle4=0 then rsa_noel=0;
			%end;

		%if &anleg.>= 2016 %then %do ;
			%do i=1 %to 4;
				/*Le RSA correspond aux valeurs de l'ancien RSA socle / il n'y a plus ni socle, ni activit�*/
				m_rsa_th&i. = m_rsa_socle_th&i.;
				rsaact_eli&i. = 0;
				m_rsa_socle&i.=0;
				/* D�duction du forfait logement des droits � rsa */
				m_rsa&i.=max(m_rsa_th&i.-3*forf_log,0);
				/* Application du seuil de versement sur le rsa */
				if m_rsa&i.<3*&rsa_min. then m_rsa&i.=0;
				%end;
			/* prime de Noel � z�ro si pas de RSA */
			if m_rsa4=0 then rsa_noel=0;
			%end;

		/* Calcul des montants annuels */
		rsasocle= sum(of m_rsa_socle1-m_rsa_socle4); /* vaut 0 apr�s 2016*/
		rsaact_eli=sum(of rsaact_eli1-rsaact_eli4); /* vaut 0 apr�s 2016*/
		rsatot_eli= sum(of m_rsa1-m_rsa4); /*le RSA apr�s 2016*/
	run;
		
	data modele.basersa; 
		set basersa;
			drop AL alaccedant ;
			label	m_rsa1='montant de RSA au T1 en plein recours'
					m_rsa2='montant de RSA au T2 en plein recours'
					m_rsa3='montant de RSA au T3 en plein recours'
					m_rsa4='montant de RSA au T4 en plein recours'
					m_rsa_socle1='montant de RSA socle au T1 en plein recours'
					m_rsa_socle2='montant de RSA socle au T2 en plein recours'
					m_rsa_socle3='montant de RSA socle au T3 en plein recours'
					m_rsa_socle4='montant de RSA socle au T4 en plein recours'
					rsaact_eli1='montant de RSa activite au T1 en plein recours'
					rsaact_eli2='montant de RSa activite au T2 en plein recours'
					rsaact_eli3='montant de RSa activite au T3 en plein recours'
					rsaact_eli4='montant de RSa activite au T4 en plein recours'
					forf_log='forfait logement effectif'
					rsasocle='RSA socle annuel en plein recours'
					rsaact_eli='RSA activit� annuel en plein recours'
					rsatot_eli='RSA total annuel en plein recours'
					logt2='statut doccupation du logement modifi� pour les jeunes cohabitants'
					;
		run;
%Mend Final_RSA;
%Final_RSA;

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
