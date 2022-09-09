/************************************************************/
/*															*/
/*					RSA_PPE_interaction						*/
/*															*/
/************************************************************/

/* Ce programme gère la PPE et le RSA			*/
/* En entrée : modele.rsa						*/
/*			   modele.baseind					*/
/*			   modele.rev_ppe					*/
/* En sortie : modele.rev_ppe					*/


/************************************************/
/* PLAN											*/							
/* 1	Utilisation normale d'Ines 				*/
/* 2	Années d'ERFS antérieures à 2009		*/
/************************************************/


/*	CAS 1 : Utilisation normale d'Ines : on utilise l'information fiscale
	Le montant de anleg-1 a déjà été dérivé dans evol_revenus (param txcaseRSA) donc rien à faire */

/* 	CAS 2 : Années d'ERFS antérieures à 2009

	Avant que le RSA ne soit mis en place, on n'a pas d'information fiscale sur le RSA
	On la recrée à partir de modele.rsa (montant rajeuni d'un an)
	Les lignes ci-dessous auraient leur place dans init_foyer si on n'avait pas besoin de l'info calculée par Ines

	Remarque : une autre situation pourrait donner lieu exactement au même traitement. 
	Il s'agit de cas où l'on souhaite simuler des modifications législatives concernant le RSA activité
	Dans ce cas, on souhaite conserver le lien entre RSA et PPE  pour mesurer les effets en chaîne sur la PPE en N d'une 
	modification sur le RSA en N-1 (sans utiliser l'information fiscale qui, elle, n'intègre pas la modification législative)
	De même, il faudrait alors recréer l'information à partir de modele.rsa (montant rajeuni d'un an)
*/

%macro RSA_pour_PPE;

	%if (%eval(&anref.)<=2008 & %eval(&anleg.)>2008) %then %do;

		/* Le calcul est simplifié. Il faudrait calculer le rsa activité directement à partir des revenus 2009, 
		c'est faisable rapidement (on n'a pas de problème de forfait logement dans ce cas). 
		Ecart à la législation : on met le résidu sur declar1, on ne gère pas les cas de doubles déclarations. */

		data rsa_annee_passee;
			set modele.rsa;
			/* RSA activité "dérivé" comme le Smic (dépend des revenus et non comme le montant du RSA socle) */
			rsa_annee_passee_=rsaact*&smich_lag1./&smich.;
			run;

		/* On apparie les individus qui ne sont pas des pàc ou des gens sans déclaration */
		proc sql;
			create table rsa_indiv (drop=ident_rsab) as
			(select * from rsa_annee_passee as a left outer join
			(select ident_rsa as ident_rsab, noi, declar1, declar2, persfip1, persfip2, statut_rsa from modele.baseind) as b
			on a.ident_rsa=b.ident_rsab
			where b.statut_rsa ne 'pac');
			quit;


		/* On se ramène au cas : une ligne par foyer RSA * déclaration fiscale */
		proc sort data=rsa_indiv nodupkey out=rsa_indiv2;
			by ident_rsa declar1;
			run;

		/* Si plusieurs déclarations par foyer rsa (concubains) on divise le montant entre chaque foyer fiscal */
		proc sql undo_policy=none;
			create table rsa_indiv2 as
			(select *, rsa_annee_passee_/count(declar1) as rsa_annee_passee from rsa_indiv2 group by ident_rsa)
			order by declar1;
			quit;

		/* On met le RSA dans la bonne case de la déclaration */
		data rsa_indiv2(rename=(declar1=declar));
			set rsa_indiv2;
			by declar1;
			retain _rsa_compact_ppe_f _rsa_compact_ppe_pac1 _rsa_compact_ppe_pac2; /* Car il peut y avoir plusieurs personnes avec du RSA par déclaration (pàc avec RSA) */
			if first.declar1 then do;
				%Init_Valeur(_rsa_compact_ppe_f _rsa_compact_ppe_pac1 _rsa_compact_ppe_pac2);
				end;
			if persfip1='decl' !  persfip1 = 'conj' then _rsa_compact_ppe_f=rsa_annee_passee;
			if persfip1='p1' then _rsa_compact_ppe_pac1=rsa_annee_passee;
			if persfip1='p2' then _rsa_compact_ppe_pac2=rsa_annee_passee;
			if last.declar1;
			run;

		data modele.rev_ppe;
			merge modele.rev_ppe(drop=_rsa_compact_ppe_f _rsa_compact_ppe_pac1 _rsa_compact_ppe_pac2 in=a)
				  rsa_indiv2 (in=b keep=declar _rsa_compact_ppe_f _rsa_compact_ppe_pac1 _rsa_compact_ppe_pac2);
			by declar;
			if a;
			if not b then do;
				%Init_Valeur(_rsa_compact_ppe_f _rsa_compact_ppe_pac1 _rsa_compact_ppe_pac2);
				end;
			run;
		/*	Les déclarations qui ne sont pas dans rsa_indiv2 sont :
			soit des declar2, soit des moins de 25 ans qui ne sont donc pas dans un foyer rsa */
		%end;

	%mend RSA_pour_PPE;

%RSA_pour_PPE;



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
