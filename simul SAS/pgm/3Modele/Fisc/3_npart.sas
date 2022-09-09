/****************************************************************************************/
/*																						*/
/*									3_npart												*/
/*																						*/
/****************************************************************************************/
/* Ce programme calcule le nombre de part fiscale										*/
/*																						*/
/* En entr�e : 	base.foyer&anr1.                           								*/
/* En sortie : 	modele.nbpart                                      						*/
/****************************************************************************************/
/* PLAN DU PROGRAMME : 																	*/
/*	1	calcul du nombre de personnes � charge										 	*/
/*	2	cas particuliers o� une case coch�e ne donne pas lieu � un traitement � part	*/
/*	3	calcul du nombre de parts et du plafond associ�									*/
/*	4	r�duction compl�mentaire qui sera appliqu�e en cas de plafonnement			   	*/
/****************************************************************************************/
/* Remarques : 																			*/
/* 	- 	Sont � charge les enfants mineurs, les enfants majeurs sous condition d'�ge et 	*/
/*		de ressources, les personnes invalides											*/	
/*	- 	Ce programme a �t� �crit en essayant de suivre le texte des articles 194 et 195 */
/*		du code des impots disponibles sur l�gifrance ainsi que le 197 pour les plafonds,*/ 
/*		en particulier la version 2008 de l'article 195									*/
/*	- 	On ecrit dans Ines "personne � charge" quand il s'agit "d'enfants" dans la 		*/	
/*		l�gislation, l'erreur porte sur les invalides � charge							*/
/****************************************************************************************/

%Macro NParts;

	data modele.nbpart;
		set base.foyer&anr1. (keep=nb: declar mcdvo age: case: sif vousconj xyz);

		/***********************************************/
		/* 1	Calcul du nombre de personnes � charge */

		npchai=sum(nbg,nbr);
		label npchai="Nb personnes � charges invalides - hors garde gardes altern�es";
		npchai_ga=sum(nbg,nbr,nbi);
		label npchai_ga="Nb personnes � charges invalides - y compris gardes altern�es";
		npcha=sum(nbf,nbr,nbj);
		label npcha="Nb de personnes � charge sauf enfants majeurs maries - hors garde gardes altern�es";


		/********************************************************************************************/
		/* 2	Changement de statut si une case coch�e ne donne pas lieu � un traitement diff�rent */

		/* 2.1	Veufs */
		/* les veufs sont, ou trait�s comme des mari�s, ou comme des c�libataires en fonction de la date du d�c�s. 
		Pour le calcul de l'imp�t les veufs de l'ann�e sont trait�s comme des mari�s
		notation all�g�e pour ce programme uniquement : les mcdvo=V sont les veufs pas de l'ann�e
		mais dans la suite c'est le MCDVO initial qui est conserv� */
		if (mcdvo='V' & xyz='Z') then mcdvo='M';

		/* 2.2	Cases W et S */
		/* on regarde les conditions d'attribution des cases en effacant quand
		malgr� le fait qu'elles soient coch�es, elle n'ouvrent pas droit � des parts suppl�mentaires.
		A noter qu'on ne change pas le sif donc on garde l'info tel que c'est coch�*/
		if case_w='W' & (agec<&age75. & aged<&age75. & xyz ne 'Z') then case_w='0';
		if case_s='S' & (agec<&age75. & aged<&age75.) then case_s='0';


		/**************************************************************************/
		/* 3	Calcul conjoint du nombre de parts et du plafond des effets du QF */

		npart=0;
		label npart="Nb de parts pour le calcul du QF";
		plaf_qf=0;
		label plaf_qf="Plafond des effets du QF associ� � npart";

		/* Parts du d�clarant et du conjoint : 1 ou 2 */
		npart=1+(	mcdvo in ('M','O') or 
					mcdvo='V' & npcha>0 & (&anleg.>=2009) or (&anleg.<2009 & case_l='L')); 

		/* Parts des personnes � charge */
		npart=npart+npcha*0.5+0.5*(npcha-2)*(npcha>2);
		npart=npart+0.5*npchai; /*majoration pac invalide*/

		/* Garde altern�e */
		%if &anleg.>2004 %then %do;
		  	if npcha=0 then npart=npart+0.25*nbh+0.25*(nbh-2)*(nbh>=2);
			  	else if npcha=1 then npart=npart+0.25*nbh+0.25*(nbh-1)*(nbh>=1);
			  	else npart=npart+0.5*nbh;
			npart=npart+0.25*nbi;
			%end;

		npart_SansDemiPart=npart; /*on garde le npart de r�f�rence pour calculer le plafond*/

		/* Demi-parts suppl�mentaires */

		/* CDV titulaires d'une pension d'invalidit� sans personnes � charge */ 
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

		/* MO titulaires d'une pension d'invalidit� */ 
		if  mcdvo in ('M','O')  then do; 
			if case_p='P' & case_f='F'  then npart=npart+1; 
			else if (case_p='P' | case_f='F' | case_s='S' | case_g='G')
			then  npart = npart + 0.5; 
			end; 
		if (mcdvo='M' & xyz='Z') & npart=2 & case_w='W' then npart=npart+0.5;
		/* Droit � la case W pour les veufs de l'ann�e, si pas le droit � d'autres demi parts */ 

		/* CDV titulaires d'une pension d'invalidit� avec personnes � charge */ 
		if ((mcdvo in ('C','D','V')) & sum(npcha,nbh) > 0) & (case_p='P' | case_w='W' | case_g='G')
		then  npart = npart + 0.5; 

		/* Plafond : Cas g�n�ral */
		plaf_qf= &P0830.*(npart-1-(mcdvo in ('M','O')))*2;

		/* Plafond : Si droit � la demi part suppl�mentaire */
		if npart>npart_SansDemiPart then do;
			 if compt ne 1 then plaf_qf=plaf_qf+&P0830.;
			 else if compt=1 then plaf_qf = plaf_qf + &P0833.;
			 end;

		/* Plafond : Si personne vivant seule avec un enfant majeur ou impos� s�par�ment (pas de personne � charge) 
			 n'ayant pas d'autres avantages � partir de 1998 */
		%if &anleg.>=2010 %then %do;
			if npart=1.5 & compt=1 & case_L2='L' then plaf_qf=&P0833.;
			else if npart=1.5 & compt=1 then plaf_qf=&P0833b.;
			%end;
		%else %if &anleg.>=1998 & &anleg.<2010 %then %do;
			if npart=1.5 & compt=1 & ageh>&ageh. then plaf_qf=&P0833.;
			%end;

		/* Nbparts et plafond :	Parents isol�s */

		/*apparition de la case T en 1996 (voir plus bas) avant c'�tait automatique*/ 
		/*on ajoute ensuite les enfants et personnes � charge*/
		%if &anleg.< 1996 %then %do;
			if (mcdvo in ('C','D')) & npcha>0 then do; 
				npart=npart+0.5; 
				plaf_qf = plaf_qf + &P0831.-&P0830.; 
				end;
			%end;

		%if &anleg.>= 1996 %then %do;
			if (mcdvo in ('C','D')) & case_t='T' then do;
				if npcha=0 then do;
					npart=npart+0.25*(nbh=1)+0.5*(nbh>=2);/*si uniquement des enfants en residence altern�e*/
					plaf_qf=plaf_qf + (&P0831.-&P0830.)*(0.5*(nbh=1)+(nbh>=2));
					end;
				else if npcha>0 then do;
					npart=npart+0.5;/*si que des enfants � charge exclusive*/
					plaf_qf =plaf_qf + (&P0831.-&P0830.);
					end;	/*&P0831.-&P0830. est en fait la valeur de la 
							demi-part associ�e � la case T, &P0831. est la valeur de la case T + le premier enfant*/
				end;
			%end;

		/* la case T concerne les veufs mais uniquement quand il y avait la case_L. Les veufs dont les 
		enfants n'�taient pas du conjoint d�c�d� �taient comme les autres. En l�g 2009, il n'y a plus 
		de case L et tout les veufs avec un enfant ont une part en plus.*/
		%if 1995<&anleg. & &anleg.<2009 %then %do;
			if mcdvo='V' & case_l ne 'L' & case_t='T' then do;
				if npcha=0 then do; 
					npart=npart+0.25*(nbh=1)*(&anleg.>2004)+0.5*(nbh>=2);/*si uniquement des enfants en residence altern�e*/
					plaf_qf=plaf_qf + (&P0831.-&P0830.)*(0.5*(nbh=1)+(nbh>=2));
					end;
				else if npcha>0 then do;
					npart=npart+0.5;/*si que des enfants � charge exclusive*/
					plaf_qf =plaf_qf +(&P0831.-&P0830.);
					end;
				end;
			%end;

		/************************************************************************************************************/
		/* 4	Calcul de la r�duction compl�mentaire qui sera appliqu�e dans 6_impot en cas de plafonnement 		*/
		/* cf document pour remplir sa d�claration sur impots.gouv.fr appel� "plaf. des effets du QF", partie III 	*/

		reduc_qf=0;
		label reduc_qf="R�duction compl�mentaire si plafonnement QF";

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
