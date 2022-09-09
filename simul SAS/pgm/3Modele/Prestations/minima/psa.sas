/****************************************************************/
/*																*/
/*		Prime de solidarité active de 2009						*/
/*								 								*/
/****************************************************************/

/****************************************************************/
/* Calcul de la prime de solidarité active de 2009				*/
/* En entrée : modele.rsa										*/ 
/*			   modele.baseind					               	*/
/*			   modele.baselog					               	*/
/*			   base.baserev						               	*/
/* En sortie : modele.rsa                                      	*/
/****************************************************************/


%macro PrimeSolidariteActive;
	proc sql;
		alter table modele.rsa 
			add psa num label='prime de solidarité active de 2009';
	 	%if &anleg.=2009 %then %do;
			/* Allocataires logement de plus de 25 ans ou qui ont un enfant à charge, exerçant une activité
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

			/* Une seule prime par foyer (on prend le foyer au sens du RSA, mais il faudrait un suivi législatif 
			de la CAF pour être sûr */
			create table alloc_psa as
				select distinct coalesce(a.ident_rsa,b.ident_rsa) as ident_rsa, &psa. as psa
				from alloc_psa_alog as a
				full outer join modele.rsa(keep=ident_rsa ident m_rsa_socle1 where=(m_rsa_socle1>0)) as b
				/* Allocataires du RMI ou API du premier trimestre 2009 */
				on a.ident_rsa=b.ident_rsa;

			/* Intégration de la prime dans la table modele.rsa */
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
