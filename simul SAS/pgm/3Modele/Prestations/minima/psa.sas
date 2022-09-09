/****************************************************************/
/*																*/
/*		Prime de solidarit� active de 2009						*/
/*								 								*/
/****************************************************************/

/****************************************************************/
/* Calcul de la prime de solidarit� active de 2009				*/
/* En entr�e : modele.rsa										*/ 
/*			   modele.baseind					               	*/
/*			   modele.baselog					               	*/
/*			   base.baserev						               	*/
/* En sortie : modele.rsa                                      	*/
/****************************************************************/


%macro PrimeSolidariteActive;
	proc sql;
		alter table modele.rsa 
			add psa num label='prime de solidarit� active de 2009';
	 	%if &anleg.=2009 %then %do;
			/* Allocataires logement de plus de 25 ans ou qui ont un enfant � charge, exer�ant une activit�
			professionnelle ou au chomage total depuis au moins 2 mois */
			create table alog_plus_de_25ans_ou_ec as
				select ident, noi, a.ident_log, ident_rsa, naia, al
				from modele.baseind(keep=ident noi ident_log ident_rsa naia quelfic noienf01 
									where=((&anref.-input(naia,4.)>=25 or noienf01 ne '' ) and quelfic ne 'FIP')) as a
				inner join modele.baselog(keep=ident_log al where=(al>0)) as b
				on a.ident_log=b.ident_log;

			create table alloc_psa_alog as
				select a.ident, a.noi, ident_rsa
				from alog_plus_de_25ans_ou_ec as a
				inner join base.baserev(keep=ident noi nbmois_salT1 nbmois_choT1 
									where=(nbmois_salT1>0 or nbmois_choT1>=2)) as b
				on a.ident=b.ident and a.noi=b.noi;

			/* Une seule prime par foyer (on prend le foyer au sens du RSA, mais il faudrait un suivi l�gislatif 
			de la CAF pour �tre s�r */
			create table alloc_psa as
				select distinct coalesce(a.ident_rsa,b.ident_rsa) as ident_rsa, &psa. as psa
				from alloc_psa_alog as a
				full outer join modele.rsa(keep=ident_rsa ident m_rsa_socle1 where=(m_rsa_socle1>0)) as b
				/* Allocataires du RMI ou API du premier trimestre 2009 */
				on a.ident_rsa=b.ident_rsa;

			/* Int�gration de la prime dans la table modele.rsa */
			update modele.rsa as b
			   set psa= case when (b.ident_rsa in (select ident_rsa from alloc_psa)) 
						then (select a.psa from alloc_psa as a where a.ident_rsa=b.ident_rsa)
						else 0 
						end;
			%end;
		%else %do;
			update modele.rsa
	     		set psa=0;
			%end;
		quit;
	%mend;

%PrimeSolidariteActive;


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
