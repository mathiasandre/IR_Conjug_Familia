/****************************************************************************/
/*																			*/
/*  Versement libératoire du régime des auto-entrepreneurs qui optent pour  */
/*																			*/
/****************************************************************************/

/*	En entrée :	modele.rev_imp&anr.
				modele.rev_imp&anr1.
				base.foyer&anr2.
	En sortie : modele.VersLibAE */

/* 	Le code de l'éligibilité au versement libératoire des autoentrepreneurs est dans le programme Prelev_Forf.sas
	Il figure dans ce programme car il doit tourner deux fois dans Ines, une fois pour l'année N-1 et une fois pour l'année N (=anleg). 
	Le présent programme s'appuie sur l'éligibilité en N pour calculer le montant du versement en N. 
	La législation de ce versement est détaillée en commentaire de Prelev_Forf.sas. */

proc sql;
	create table modele.VersLibAE as
	select 	a.declar, a.AE_eliPFL&anr2., b.mcdvo, b.ident, 
			b._5ta, b._5ua, b._5va, b._5tb, b._5ub, b._5vb, b._5te, b._5ue, b._5ve
	from modele.rev_imp&anr1. as a
		inner join base.foyer&anr2. as b on a.declar=b.declar;
	quit;

data modele.VersLibAE (keep=ident declar Verslib_AutoEntr);
	set modele.VersLibAE;

	%Init_Valeur(Verslib_AutoEntr);
	if AE_eliPFL&anr2. then Verslib_AutoEntr=	&tx_auto_march.*(_5ta+_5ua+_5va)+
												&tx_auto_serv.*(_5tb+_5ub+_5vb)+
												&tx_auto_bnc.*(_5te+_5ue+_5ve);

	label Verslib_AutoEntr="Versement libératoire des auto-entrepreneurs";
run;


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
