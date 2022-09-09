/****************************************************************************************/
/*																						*/
/*									3_npart												*/
/*																						*/
/****************************************************************************************/
/* Ce programme calcule le nombre de part fiscale										*/
/*																						*/
/* En entrée : 	base.foyer&anr1.                           								*/
/* En sortie : 	modele.nbpart                                      						*/
/****************************************************************************************/
/* PLAN DU PROGRAMME : 																	*/
/*	1	calcul du nombre de personnes à charge										 	*/
/*	2	cas particuliers où une case cochée ne donne pas lieu à un traitement à part	*/
/*	3	calcul du nombre de parts et du plafond associé									*/
/*	4	réduction complémentaire qui sera appliquée en cas de plafonnement			   	*/
/****************************************************************************************/
/* Remarques : 																			*/
/* 	- 	Sont à charge les enfants mineurs, les enfants majeurs sous condition d'âge et 	*/
/*		de ressources, les personnes invalides											*/	
/*	- 	Ce programme a été écrit en essayant de suivre le texte des articles 194 et 195 */
/*		du code des impots disponibles sur légifrance ainsi que le 197 pour les plafonds,*/ 
/*		en particulier la version 2008 de l'article 195									*/
/*	- 	On ecrit dans Ines "personne à charge" quand il s'agit "d'enfants" dans la 		*/	
/*		législation, l'erreur porte sur les invalides à charge							*/
/****************************************************************************************/

%Macro NParts;

	data modele.nbpart;
		set base.foyer&anr1. (keep=nb: declar mcdvo age: case: sif vousconj xyz);

		/***********************************************/
		/* 1	Calcul du nombre de personnes à charge */

		npchai=sum(nbg,nbr);
		label npchai="Nb personnes à charges invalides - hors garde gardes alternées";
		npchai_ga=sum(nbg,nbr,nbi);
		label npchai_ga="Nb personnes à charges invalides - y compris gardes alternées";
		npcha=sum(nbf,nbr,nbj);
		label npcha="Nb de personnes à charge sauf enfants majeurs maries - hors garde gardes alternées";


		/********************************************************************************************/
		/* 2	Changement de statut si une case cochée ne donne pas lieu à un traitement différent */

		/* 2.1	Veufs */
		/* les veufs sont, ou traités comme des mariés, ou comme des célibataires en fonction de la date du décès. 
		Pour le calcul de l'impôt les veufs de l'année sont traités comme des mariés
		notation allégée pour ce programme uniquement : les mcdvo=V sont les veufs pas de l'année
		mais dans la suite c'est le MCDVO initial qui est conservé */
		if (mcdvo='V' & xyz='Z') then mcdvo='M';

		/* 2.2	Cases W et S */
		/* on regarde les conditions d'attribution des cases en effacant quand
		malgré le fait qu'elles soient cochées, elle n'ouvrent pas droit à des parts supplémentaires.
		A noter qu'on ne change pas le sif donc on garde l'info tel que c'est coché*/
		if case_w='W' & (agec<&age75. & aged<&age75. & xyz ne 'Z') then case_w='0';
		if case_s='S' & (agec<&age75. & aged<&age75.) then case_s='0';


		/**************************************************************************/
		/* 3	Calcul conjoint du nombre de parts et du plafond des effets du QF */

		npart=0;
		label npart="Nb de parts pour le calcul du QF";
		plaf_qf=0;
		label plaf_qf="Plafond des effets du QF associé à npart";

		/* Parts du déclarant et du conjoint : 1 ou 2 */
		npart=1+(	mcdvo in ('M','O') or 
					mcdvo='V' & npcha>0 & (&anleg.>=2009) or (&anleg.<2009 & case_l='L')); 

		/* Parts des personnes à charge */
		npart=npart+npcha*0.5+0.5*(npcha-2)*(npcha>2);
		npart=npart+0.5*npchai; /*majoration pac invalide*/

		/* Garde alternée */
		%if &anleg.>2004 %then %do;
		  	if npcha=0 then npart=npart+0.25*nbh+0.25*(nbh-2)*(nbh>=2);
			  	else if npcha=1 then npart=npart+0.25*nbh+0.25*(nbh-1)*(nbh>=1);
			  	else npart=npart+0.5*nbh;
			npart=npart+0.25*nbi;
			%end;

		npart_SansDemiPart=npart; /*on garde le npart de référence pour calculer le plafond*/

		/* Demi-parts supplémentaires */

		/* CDV titulaires d'une pension d'invalidité sans personnes à charge */ 
		if mcdvo in ('C','D','V') & sum(npcha,nbh)=0 then do; 
			%if &anleg.>=2004 %then %do;
				if ((case_N ne 'N')&(case_L2='L' | (case_e='E' & (&anleg.<2014))))|(case_p='P' | case_w='W' | case_g='G') then do; 
					npart = npart+0.5; 
					if (not(case_p='P' | case_w='W' | case_g='G') ) then compt=1;
					end;
				%end;
			%else %do; 
				if (case_L2='L' | (case_e='E' & (&anleg.<2014))) |(case_p='P' | case_w='W' | case_g='G') then do; 
					npart = npart+0.5;
					if (not(case_p='P' | case_w='W' | case_g='G') ) then compt=1;
					end;
				%end;
			end;

		/* MO titulaires d'une pension d'invalidité */ 
		if  mcdvo in ('M','O')  then do; 
			if case_p='P' & case_f='F'  then npart=npart+1; 
			else if (case_p='P' | case_f='F' | case_s='S' | case_g='G')
			then  npart = npart + 0.5; 
			end; 
		if (mcdvo='M' & xyz='Z') & npart=2 & case_w='W' then npart=npart+0.5;
		/* Droit à la case W pour les veufs de l'année, si pas le droit à d'autres demi parts */ 

		/* CDV titulaires d'une pension d'invalidité avec personnes à charge */ 
		if ((mcdvo in ('C','D','V')) & sum(npcha,nbh) > 0) & (case_p='P' | case_w='W' | case_g='G')
		then  npart = npart + 0.5; 

		/* Plafond : Cas général */
		plaf_qf= &P0830.*(npart-1-(mcdvo in ('M','O')))*2;

		/* Plafond : Si droit à la demi part supplémentaire */
		if npart>npart_SansDemiPart then do;
			 if compt ne 1 then plaf_qf=plaf_qf+&P0830.;
			 else if compt=1 then plaf_qf = plaf_qf + &P0833.;
			 end;

		/* Plafond : Si personne vivant seule avec un enfant majeur ou imposé séparément (pas de personne à charge) 
			 n'ayant pas d'autres avantages à partir de 1998 */
		%if &anleg.>=2010 %then %do;
			if npart=1.5 & compt=1 & case_L2='L' then plaf_qf=&P0833.;
			else if npart=1.5 & compt=1 then plaf_qf=&P0833b.;
			%end;
		%else %if &anleg.>=1998 & &anleg.<2010 %then %do;
			if npart=1.5 & compt=1 & ageh>&ageh. then plaf_qf=&P0833.;
			%end;

		/* Nbparts et plafond :	Parents isolés */

		/*apparition de la case T en 1996 (voir plus bas) avant c'était automatique*/ 
		/*on ajoute ensuite les enfants et personnes à charge*/
		%if &anleg.< 1996 %then %do;
			if (mcdvo in ('C','D')) & npcha>0 then do; 
				npart=npart+0.5; 
				plaf_qf = plaf_qf + &P0831.-&P0830.; 
				end;
			%end;

		%if &anleg.>= 1996 %then %do;
			if (mcdvo in ('C','D')) & case_t='T' then do;
				if npcha=0 then do;
					npart=npart+0.25*(nbh=1)+0.5*(nbh>=2);/*si uniquement des enfants en residence alternée*/
					plaf_qf=plaf_qf + (&P0831.-&P0830.)*(0.5*(nbh=1)+(nbh>=2));
					end;
				else if npcha>0 then do;
					npart=npart+0.5;/*si que des enfants à charge exclusive*/
					plaf_qf =plaf_qf + (&P0831.-&P0830.);
					end;	/*&P0831.-&P0830. est en fait la valeur de la 
							demi-part associée à la case T, &P0831. est la valeur de la case T + le premier enfant*/
				end;
			%end;

		/* la case T concerne les veufs mais uniquement quand il y avait la case_L. Les veufs dont les 
		enfants n'étaient pas du conjoint décédé étaient comme les autres. En lég 2009, il n'y a plus 
		de case L et tout les veufs avec un enfant ont une part en plus.*/
		%if 1995<&anleg. & &anleg.<2009 %then %do;
			if mcdvo='V' & case_l ne 'L' & case_t='T' then do;
				if npcha=0 then do; 
					npart=npart+0.25*(nbh=1)*(&anleg.>2004)+0.5*(nbh>=2);/*si uniquement des enfants en residence alternée*/
					plaf_qf=plaf_qf + (&P0831.-&P0830.)*(0.5*(nbh=1)+(nbh>=2));
					end;
				else if npcha>0 then do;
					npart=npart+0.5;/*si que des enfants à charge exclusive*/
					plaf_qf =plaf_qf +(&P0831.-&P0830.);
					end;
				end;
			%end;

		/************************************************************************************************************/
		/* 4	Calcul de la réduction complémentaire qui sera appliquée dans 6_impot en cas de plafonnement 		*/
		/* cf document pour remplir sa déclaration sur impots.gouv.fr appelé "plaf. des effets du QF", partie III 	*/

		reduc_qf=0;
		label reduc_qf="Réduction complémentaire si plafonnement QF";

		if 	(mcdvo in ('C','D','V') & (case_p='P' | case_w='W' | case_g='G'))
			/* CDV invalides, anciens combattants ou veuves de guerre */
		or	(mcdvo in ('M','O') & (case_s='S' | case_p='P' | case_F='F'))
			/* en couple dont l'un ancien combattant ou invalide */ 
			then reduc_qf = &redcomp1. ;

		if mcdvo in ('M','O') & case_p='P' & case_f = 'F' then reduc_qf = reduc_qf + &redcomp1. ;

		if	npchai_ga>0 then reduc_qf = reduc_qf + &redcomp1.*(nbr+nbg+0.5*nbi) ;

		%if &anleg.>= 2013 & (mcdvo='V') & npcha>0 %then reduc_qf=reduc_qf+&redcomp2.;

	run;

%Mend NParts;

%NParts;



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
