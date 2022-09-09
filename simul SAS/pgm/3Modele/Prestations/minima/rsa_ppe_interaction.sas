/************************************************************/
/*															*/
/*					RSA_PPE_interaction						*/
/*															*/
/************************************************************/

/* Ce programme g�re la PPE et le RSA			*/
/* En entr�e : modele.rsa						*/
/*			   modele.baseind					*/
/*			   modele.rev_ppe					*/
/* En sortie : modele.rev_ppe					*/


/************************************************/
/* PLAN											*/							
/* 1	Utilisation normale d'Ines 				*/
/* 2	Ann�es d'ERFS ant�rieures � 2009		*/
/************************************************/


/*	CAS 1 : Utilisation normale d'Ines : on utilise l'information fiscale
	Le montant de anleg-1 a d�j� �t� d�riv� dans evol_revenus (param txcaseRSA) donc rien � faire */

/* 	CAS 2 : Ann�es d'ERFS ant�rieures � 2009

	Avant que le RSA ne soit mis en place, on n'a pas d'information fiscale sur le RSA
	On la recr�e � partir de modele.rsa (montant rajeuni d'un an)
	Les lignes ci-dessous auraient leur place dans init_foyer si on n'avait pas besoin de l'info calcul�e par Ines

	Remarque : une autre situation pourrait donner lieu exactement au m�me traitement. 
	Il s'agit de cas o� l'on souhaite simuler des modifications l�gislatives concernant le RSA activit�
	Dans ce cas, on souhaite conserver le lien entre RSA et PPE  pour mesurer les effets en cha�ne sur la PPE en N d'une 
	modification sur le RSA en N-1 (sans utiliser l'information fiscale qui, elle, n'int�gre pas la modification l�gislative)
	De m�me, il faudrait alors recr�er l'information � partir de modele.rsa (montant rajeuni d'un an)
*/

%macro RSA_pour_PPE;

	%if (%eval(&anref.)<=2008 & %eval(&anleg.)>2008) %then %do;

		/* Le calcul est simplifi�. Il faudrait calculer le rsa activit� directement � partir des revenus 2009, 
		c'est faisable rapidement (on n'a pas de probl�me de forfait logement dans ce cas). 
		Ecart � la l�gislation : on met le r�sidu sur declar1, on ne g�re pas les cas de doubles d�clarations. */

		data rsa_annee_passee;
			set modele.rsa;
			/* RSA activit� "d�riv�" comme le Smic (d�pend des revenus et non comme le montant du RSA socle) */
			rsa_annee_passee_=rsaact*&smich_lag1./&smich.;
			run;

		/* On apparie les individus qui ne sont pas des p�c ou des gens sans d�claration */
		proc sql;
			create table rsa_indiv (drop=ident_rsab) as
			(select * from rsa_annee_passee as a left outer join
			(select ident_rsa as ident_rsab, noi, declar1, declar2, persfip1, persfip2, statut_rsa from modele.baseind) as b
			on a.ident_rsa=b.ident_rsab
			where b.statut_rsa ne 'pac');
			quit;


		/* On se ram�ne au cas : une ligne par foyer RSA * d�claration fiscale */
		proc sort data=rsa_indiv nodupkey out=rsa_indiv2;
			by ident_rsa declar1;
			run;

		/* Si plusieurs d�clarations par foyer rsa (concubains) on divise le montant entre chaque foyer fiscal */
		proc sql undo_policy=none;
			create table rsa_indiv2 as
			(select *, rsa_annee_passee_/count(declar1) as rsa_annee_passee from rsa_indiv2 group by ident_rsa)
			order by declar1;
			quit;

		/* On met le RSA dans la bonne case de la d�claration */
		data rsa_indiv2(rename=(declar1=declar));
			set rsa_indiv2;
			by declar1;
			retain _rsa_compact_ppe_f _rsa_compact_ppe_pac1 _rsa_compact_ppe_pac2; /* Car il peut y avoir plusieurs personnes avec du RSA par d�claration (p�c avec RSA) */
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
		/*	Les d�clarations qui ne sont pas dans rsa_indiv2 sont :
			soit des declar2, soit des moins de 25 ans qui ne sont donc pas dans un foyer rsa */
		%end;

	%mend RSA_pour_PPE;

%RSA_pour_PPE;



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
