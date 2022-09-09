/************************************************************************************/
/*																					*/
/*									PPE												*/
/*																					*/
/************************************************************************************/

/* Mod�lisation des conditions d'�ligibilit� � la PPE et de son montant				*/
/************************************************************************************/
/* En entr�e : modele.rev_ppe 														*/
/*			   modele.nbpart														*/
/*			   modele.rev_imp&anr1													*/
/* En sortie : modele.ppe	           					                          	*/
/************************************************************************************/
/* Plan				 		          					                          	*/
/*	A. Conditions d'�ligibilit� individuelle portant sur le revenu d'activit�   	*/
/*		A.1 Limite basse           					             	             	*/
/*		A.2 Limite haute           					             	             	*/
/*	B. Conditions d'�ligibilit� du foyer fiscal	             	             		*/
/*	C. Calcul du montant de la prime individuelle	             	             	*/
/*		C.1 Application des 3 taux de prime	             	             			*/
/*		C.2 Ajout de la majoration en cas d'activit� � temps incomplet sur l'ann�e	*/
/*		C.3 Majoration de 83 � de la prime calcul�e pour les couples monoactifs		*/
/*	D. Calcul du montant de la prime du foyer fiscal	             	            */
/************************************************************************************/
/* Note : on ne calcule la PPE que pour le d�clarant, son conjoint et les deux 		*/
/* premiers PAC. 																	*/
/************************************************************************************/

%Macro PPE;
	data modele.ppe (keep=declar ident ppef ppe_d ppe_c ppe_p1 ppe_p2); 
		merge modele.rev_ppe
			  modele.nbpart (keep=declar case_t mcdvo npart nb:)
		 	  modele.rev_imp&anr1. (keep=declar RFR);
		by declar;
	
	/****************************************************************************/
	/* A. Condition d'�ligibilit� individuelle portant sur le revenu d'activit� */
	/****************************************************************************/

		/* Cr�ation de variables � alimenter selon les conditions */
		%Init_Valeur(	PAC1_actif PAC2_actif /* pac actif au sens de la ppe*/
						eliPPE_c eliPPE_d eliPPE_p1 eliPPE_p2 /* �ligibilite individuelle standard*/
						ppe_d ppe_c ppe_p1 ppe_p2 /* montant des PPE individuelles*/
						ppe_f /* montant de PPE du foyer */
						primpart_d primpart_c primpart_p1 primpart_p2);

		/********************/
		/* A.1 Limite basse */
		/********************/
		/* Si revenu d'activit� non converti > 0.3 SMIC => on peut �tre �ligible */
		if rev_ppe_d > &ppe004.*&PPE000. then elippe_d=1;
		if rev_ppe_c > &ppe004.*&PPE000. then elippe_c=1;
		if rev_ppe_p1 > &ppe004.*&PPE000. then do; elippe_p1=1; PAC1_actif=1; end;
		if rev_ppe_p2 > &ppe004.*&PPE000. then do; elippe_p2=1; PAC2_actif=1; end;

		/********************/
		/* A.2 Limite haute */
		/********************/
		/* Si revenu d'activit� converti > seuil => on n'est pas �ligible
		Il existe 2 seuils selon type de foyer fiscal :
		- 1 : c�lib, veuf, divorc�, mari� ou couple biactif ou pac qui travaille (qq soit la composition du foyer) -> 1.4 SMIC
		- 2 : mari� ou pacs� mono-actif ou personne isol�e (sauf veufs), -> 2.13 SMIC*/
		/* D�finition de monoactif : 1 seul conjoint au dessus de la limite basse */
		monoactif=	(elippe_c+elippe_d=1 & (mcdvo in ('M','O'))); 
		personne_isolee=(case_T='T' & (mcdvo in ('C','D')));
		if monoactif or personne_isolee then do; 
			if reqtc_d > &ppe007.*&PPE000. or reqtc_d=0 then elippe_d=0;
			if reqtc_c > &ppe007.*&PPE000. or reqtc_c=0 then elippe_c=0;
			end;
			else do;
			if reqtc_d > &ppe005.*&PPE000. or reqtc_d=0 then elippe_d=0;
			if reqtc_c > &ppe005.*&PPE000. or reqtc_c=0 then elippe_c=0;
			end;
		if reqtc_p1 > &ppe005.*&PPE000. or reqtc_p1=0 then elippe_p1=0;
		if reqtc_p2 > &ppe005.*&PPE000. or reqtc_p2=0 then elippe_p2=0;

		/**********************************************/
		/* B. Condition d'�ligibilit� du foyer fiscal */
		/**********************************************/

		/* Condition de RFR avec 2 seuils diff�rents et conversion du RFR en cas d'�v�nement dans l'ann�e */
		if mcdvo in ('M','O') then seuil=&ppe002.+2*(npart-2)*&ppe003.; 
		else seuil=&ppe001.+2*(npart-1)*&ppe003.;
		elippe_f=(RFR*coeff_evt<=seuil);

		/*************************************************/
		/* C. Calcul du montant de la prime individuelle */
		/*************************************************/

		/****************************************/
		/* C.1 Application des 3 taux de primes */
		/****************************************/
		if elippe_d=1 then do;
			/* Taux 1 */
			if reqtc_d<&PPE000. then ppe_d=&ppe008.*reqtc_d*tps_d;
			/* Taux 2 */
			else if reqtc_d<&ppe005.*&PPE000. then ppe_d=&ppe009.*(&ppe005.*&PPE000.-reqtc_d)*tps_d;
			/* Extension pour les monoactifs */
			if monoactif=1 then do;
				if &PPE000.*&ppe006.<reqtc_d<=&PPE000.*&ppe007. then ppe_d=&PPE012.*(&ppe007.*&PPE000.-reqtc_d)*tps_d;
				end;
			end;
		if elippe_c=1 then do; 
			/* Taux 1 */
			if reqtc_c<&PPE000. then ppe_c=&ppe008.*reqtc_c*tps_c;
			/* Taux 2 */
			else if reqtc_c<&ppe005.*&PPE000. then ppe_c=&ppe009.*(&ppe005.*&PPE000.-reqtc_c)*tps_c;
			/* Extension pour les monoactifs*/
			if monoactif=1 then do;
				if &PPE000.*&ppe006.<reqtc_c<=&PPE000.*&ppe007. then ppe_d=&PPE012.*(&ppe007.*&PPE000.-reqtc_c)*tps_c; 
				end; 
			end;

		/******************************************************************************/
		/* C.2 Ajout de la majoration en cas d'activit� � temps incomplet sur l'ann�e */
		/******************************************************************************/
		if 0<tps_d<0.5 then primpart_d=&PPE015.*ppe_d;
		else if 0.5<=tps_d<1 then primpart_d=&PPE015.*ppe_d*(1-tps_d)/tps_d;
		primpart_d=primpart_d*(elippe_d=1);
		ppe_d=ppe_d+primpart_d;

		if 0<tps_c<0.5 then primpart_c=&PPE015.*ppe_c;
		else if 0.5<=tps_c<1 then primpart_c=&PPE015.*ppe_c*(1-tps_c)/tps_c;
		primpart_c=primpart_c*(elippe_c=1);
		ppe_c=ppe_c+primpart_c;

		%do j=1 %to 2;
			if elippe_p&j.=1 then do;
				if reqtc_p&j.<&PPE000. then ppe_p&j.=elippe_p&j.*&ppe008.*reqtc_p&j.*tps_p&j.;
				else ppe_p&j.=elippe_p&j.*&ppe009.*(&ppe005.*&PPE000.-reqtc_p&j.)*tps_p&j.;
				end;
			if tps_p&j.<0.5 then primpart_p&j.=&PPE015.*ppe_p&j.;
			else if tps_p&j.<1 then primpart_p&j.=&PPE015.*ppe_p&j.*(1-tps_p&j.)/tps_p&j.;
			primpart_p&j.=primpart_p&j.*(elippe_p&j.=1) ;
			ppe_p&j.=ppe_p&j.+primpart_p&j.;
			%end;

		/***************************************************************************/
		/* C.3 Majoration de 83 � de la prime calcul�e pour les couples monoactifs */
		/***************************************************************************/
		if elippe_d=1 & monoactif & reqtc_d<=&ppe006.*&ppe000. then ppe_d=ppe_d+&ppe010.;
		if elippe_c=1 & monoactif & reqtc_c<=&ppe006.*&ppe000. then ppe_c=ppe_c+&ppe010.;

		/****************************************************/
		/* D. CALCUL DU MONTANT DE LA PRIME DU FOYER FISCAL */
		/****************************************************/
		/* Prime du foyer*/
		somppe_i=	ppe_d+ppe_c+ppe_p1+ppe_p2;

		/* Ajout des majorations pour charge de famille (nombre de PAC non actives au sens de la PPE) */
		npac=	nbf+nbj+nbr+nbn+0.5*nbh-PAC1_actif-PAC2_actif; 
		if elippe_d=1 or elippe_c=1 then do; 
			/* Cas 1 : cas g�n�ral, c�libataires et couples biactifs et monoactifs avec R<1.4 SMIC => 36 � par pac*/
			ppe_f=somppe_i+(npac*&ppe011.);
			/* Cas 2 : couples monoactifs ou parents isol�s avec 1.4 SMIC<R<2.13 SMIC => majoration forfaitaire (36� ou 72�)*/
			if (monoactif or personne_isolee) & npac>0 & ((&ppe005.*&PPE000.<reqtc_d<&ppe007.*&PPE000. & elippe_d=1)
			!(&ppe005.*&PPE000.<reqtc_c<&ppe007.*&PPE000. & elippe_c=1)) then do; 
				ppe_f=somppe_i+(1+(personne_isolee=1))*&ppe011.*(1-0.5*(npac=nbh/2));
				end;
			/* cas 3 : parents isol�s avec R<1.4 SMIC => 72 � pour la 1�re pac, 36 � pour les suivantes */
			if personne_isolee=1 & (reqtc_d<&ppe005.*&PPE000. & reqtc_c<&ppe005.*&PPE000.) & npac>0 then do; 
				if (npac ne nbh/2) then ppe_f=somppe_i+(npac*&ppe011.)+&ppe011.;
				/* Garde altern�e*/
				if (npac=nbh/2)    then ppe_f=somppe_i+(npac*&ppe011.*2)-(npac-1)*&ppe011.*(npac>1);	
				end;
			end;

		/* Fin du calcul : appr�ciation de la condition d'�ligibilit� au niveau du foyer fiscal et seuil de versement*/
		ppef=elippe_f*ppe_f;
		label ppef= "PPE r�siduelle du foyer";
		/* seuil de versement 30 � appr�ci� sur la PPE avant reprise du RSA activit�*/
		if 0<ppef<&ppe013. then ppef=0;

		/* Reprise du RSA activit� d�clar� par le foyer (�ventuellement imput� � partir du RSA calcul� par Ines) */
		%if &anleg.>=2010 %then %do;
			ppef=max(ppef-_rsa_compact_ppe_f-_rsa_compact_ppe_pac1-_rsa_compact_ppe_pac2,0);
			%end;
		/* seuil de versement 30 � appr�ci� sur le PPE r�disuelle, vers�e */
		if 0<ppef<&ppe013. then ppef=0;
		run;
	%Mend PPE;
%PPE;


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
