*************************************************************************************;
/*																					*/
/*								REV_PPE												*/
/*																					*/
*************************************************************************************;

/* Mod�lisation du revenu d'activit� en n-1 pour les droits � PPE en n	*/

/* En entr�e : base.foyer&anr1. 					                 	*/
/* En sortie : modele.rev_ppe                                     		*/

********************************************************************;
/* 
Plan
A. Prise en compte des revenus salariaux
B. Prise en compte des revenus non salariaux
C. Gestion des �v�nements dans l'ann�e
D. Temps de travail et conversion des revenus d'activit� en ann�e pleine
*/
********************************************************************;

/*Sources : brochure pratique de l'IR de la DGFIP, rubrique traitements et salaires, PPE
		 	r�gle de taxation de la PPE pour les revenus 2009, document interne de la DGFIP*/

proc sort data=base.foyer&anr1.;by declar;run;

data modele.rev_ppe (keep= ident declar rev_ppe: reqtc: coeff: sal: ind: z: pv: zm:  
						  _rsa_compact_ppe_f _rsa_compact_ppe_pac1 _rsa_compact_ppe_pac2 tps:);
	set base.foyer&anr1.(keep= ident declar _1: _5: _3vj _3vk _0xx vousconj xyz jourev _hsupVous _hsupConj _hsupPac1 _hsupPac2
						   _impot_etr_dec1 _impot_etr_dec2 _impot_etr_pac1 _impot_etr_pac2
						   _tpsplein_ppe_dec1 _tpsplein_ppe_dec2 _tpsplein_ppe_pac1 _tpsplein_ppe_pac2
						   _nbheur_ppe_dec1 _nbheur_ppe_dec2 _nbheur_ppe_pac1 _nbheur_ppe_pac2
						   _pro_act_annee_dec1 _pro_act_annee_dec2 _pro_act_annee_pac
						   _pro_act_jour_dec1 _pro_act_jour_dec2 _pro_act_jour_pac
						   moisev _rsa_compact_ppe_f _rsa_compact_ppe_pac1 _rsa_compact_ppe_pac2 _glovSup: _glo1_2ans: _glo2_3ans:);
	by declar;

/*********************************************/
/* A. Prise en compte des revenus salariaux  */
/*********************************************/


	salppe_d=	_1aj+_1af+_1ag+_1tp+_1nx+_1pm+_1aq+_glo1_2ansVous+_glo2_3ansVous+_1tx+_glovSup4ansVous+_3vj+_hsupVous*((2008<&anleg.<2013)+7/12*(&anleg.=2013)+3/12*(&anleg.=2008))+_1tt+_1tz+_1ac+(_impot_etr_dec1)*(&anleg.<2016);  
	salppe_c=	_1bj+_1bf+_1bg+_1up+_1ox+_1qm+_1bq+_glo1_2ansConj+_glo2_3ansConj+_1ux+_glovSup4ansConj+_3vk+_hsupConj*((2008<&anleg.<2013)+7/12*(&anleg.=2013)+3/12*(&anleg.=2008))+_1ut+_1bc+(_impot_etr_dec2)*(&anleg.<2016);
	salppe_p1=	_1cj+_1cf+_1cg+_hsupPac1*((2008<&anleg.<2013)+7/12*(&anleg.=2013)+3/12*(&anleg.=2008))+_1cc+(_impot_etr_pac1)*(&anleg.<2016);
	salppe_p2=	_1dj+_1df+_1dg+_hsupPac2*((2008<&anleg.<2013)+7/12*(&anleg.=2013)+3/12*(&anleg.=2008))+_1dc+(_impot_etr_pac2)*(&anleg.<2016);

	/* Les revenus d�clar�s dans _1tz � partir du 08/08/2015 ne sont plus individualis�s (plus de diff�rence entre d�clarant1 et d�clarant2). 
	Les montants de dec1 sont largement sup�rieurs � dec2 donc on a d�cid� de mettre _1tz enti�rement pour le dec1 
	S�rement inutile de garder dans PPE car revenus apparaitront en 08/2016, mais je garde pour le moment */

	/* Avant 2016 les cases _1ac � _1dc ne contenait que les salaires per�us � l'�tranger, avant imputation de l'imp�t acquitt� � l'�tranger.
	Pour la PPE ce sont ces salaires seuls qui sont pris en compte et donc on doit remettre l'imp�t qui leur a �t� imput� par la modification des cases fiscales pour anleg 2016. */

	/* Remarque : Les gratifications exceptionnelles d�clar�es dans _0xx devraient �tre incluses mais c'est le seul cas o�
	_0xx doit �tre prise en compte et on ne peut distinguer le contenu de cette case. 
	-> HYP : on consid�re que les gratifications exceptionnelles sont minoritaires et on n'inclut pas la case */

/*************************************************/
/* B. Prise en compte des revenus non salariaux  */
/*************************************************/

	zbag_d=sum(0,_5xa,_5xb,_5hb,_5hc,_5ak,_5hd,-_5hf,_5hh,_5hi,-_5hl,_5xt,_5xv);
	zbag_c=sum(0,_5ya,_5yb,_5ib,_5ic,_5bk,_5id,-_5if,_5ih,_5ii,-_5il,_5xu,_5xw);
	zbag_p1=sum(0,_5za,_5zb,_5jb,_5jc,_5ck,_5jd,-_5jf,_5jh,_5ji,-_5jl);

	zbic_d=sum(0,_5kn,_5kb,_5kc,_5df,-_5kf,_5kh,_5ki,_5dg,-_5kl);
	zbic_c=sum(0,_5ln,_5lb,_5lc,_5ef,-_5lf,_5lh,_5li,_5eg,-_5ll);
	zbic_p1=sum(0,_5mn,_5mb,_5mc,_5ff,-_5mf,_5mh,_5mi,_5fg,-_5ml);

	zbnc_d=sum(0,_5hp,_5qb,_5qc,_5xj,-_5qe,_5qh,_5qi,_5xk,-_5qk);
	zbnc_c=sum(0,_5ip,_5rb,_5rc,_5yj,-_5re,_5rh,_5ri,_5yk,-_5rk);
	zbnc_p1=sum(0,_5jp,_5sb,_5sc,_5zj,-_5se,_5sh,_5si,_5zk,-_5sk);

	/* Regime micro: calcul des correctifs abattements fiscaux a appliquer aux chiffres 
	d'affaires pour retrouver des benefices */
	zmbic_d=	sum(0,_5ko,_5kp,_5ta,_5tb)
				-max(&abatmicmarch*sum(0,_5ko,_5ta)+&abatmicserv*sum(0,_5kp,_5tb),
				 min(sum(0,_5ko,_5kp,_5ta,_5tb),&E2000));
	zmbic_c=	sum(0,_5lo,_5lp,_5ua,_5ub)
				-max(&abatmicmarch*sum(0,_5lo,_5ua)+&abatmicserv*sum(0,_5lp,_5ub),min(sum(0,_5lo,_5lp,_5ua,_5ub),&E2000));
	zmbic_p1=	sum(0,_5mo,_5mp,_5va,_5vb)
		     	-max(&abatmicmarch*sum(0,_5mo,_5va)+&abatmicserv*sum(0,_5mp,_5vb),min(sum(0,_5mo,_5mp,_5va,_5vb),&E2000));
	zmbnc_d=	sum(0,_5hq,_5te)-max(&abatmicbnc*sum(0,_5hq,_5te),min(sum(0,_5hq,_5te),&E2000));
	zmbnc_c=	sum(0,_5iq,_5ue)-max(&abatmicbnc*sum(0,_5iq,_5ue),min(sum(0,_5iq,_5ue),&E2000));
	zmbnc_p1=	sum(0,_5jq,_5ve)-max(&abatmicbnc*sum(0,_5jq,_5ve),min(sum(0,_5jq,_5ve),&E2000));

	/* Regime micro : plus-values a court terme � ajouter pour la ppe, on attribue les 
	moins-values a une des pers du foyer */
	pvind_d=sum(_5hw,- _5xo,_5kx,_5hv,
					-_5kj*((zbic_d+_5kx)>=(zbic_c+_5lx))*((zbic_d+_5kx)>=(zbic_p1+_5mx)),
					-_5kz*((zbnc_d+_5hv)>=(zbnc_c+_5iv))*((zbnc_d+_5hv)>=(zbnc_p1+_5jv)));
	pvind_c=sum(_5iw,- _5yo,_5lx,_5iv,
					-_5lj*((zbic_c+_5lx)>(zbic_d+_5kx))*((zbic_c+_5lx)>(zbic_p1+_5mx)),
					-_5kz*((zbnc_c+_5iv)>(zbnc_d+_5hv))*((zbnc_c+_5iv)>(zbnc_p1+_5jv)));
	pvind_p1=sum(_5jw,- _5zo,_5mx,_5jv,
					-_5mj*((zbic_p1+_5mx)>(zbic_d+_5kx))*((zbic_p1+_5mx)>=(zbic_c+_5lx)),
					-_5kz*((zbnc_p1+_5jv)>(zbnc_d+_5hv))*((zbnc_p1+_5jv)>=(zbnc_c+_5iv)));

	/* Revenus d'independants pris en compte pour la PPE : pour les indep regime micro, on 
	corrige des abattements fiscaux	et on ajoute les plus-values a court terme */
	indppe_d=sum(0,zbag_d,zbic_d,zbnc_d,zmbic_d,zmbnc_d,pvind_d);
	indppe_c=sum(0,zbag_c,zbic_c,zbnc_c,zmbic_c,zmbnc_c,pvind_c);
	indppe_p1=sum(0,zbag_p1,zbic_p1,zbnc_p1,zmbic_p1,zmbnc_p1,pvind_p1);
	/* Majoration de tous les revenus non salariaux �tant des b�n�fices */
	if indppe_d>0 then indppe_d=(1+(0.1111))*indppe_d;
	if indppe_c>0 then indppe_c=(1+(0.1111))*indppe_c;
	if indppe_p1>0 then indppe_p1=(1+(0.1111))*indppe_p1;
	/* Majoration qui vient en diminution en cas de deficit */
	if indppe_d<0 then indppe_d=(1-(0.1111))*indppe_d;
	if indppe_c<0 then indppe_c=(1-(0.1111))*indppe_c;
	if indppe_p1<0 then indppe_p1=(1-(0.1111))*indppe_p1;

/*******************************************/
/* C. Gestion des �v�nements dans l'ann�e  */
/*******************************************/

	/* le probl�me avec les xyz est qu'on ne sait pas comment ils d�clarent leurs heures. 
	-> les cas de temps partiel avec �v�nement dans l'ann�e ne sont peut-�tre pas bien g�r�s*/
	if  xyz ne '0' then do;
	/* Jourevnum :nombre de jours � prendre en compte au niveau de chaque declaration pour le calcul de la PPE.
	C'est le nb de jours avant l'�v�nement sur la 1�re d�claration et apr�s l'�v�nement sur la 2�me. 
	il faut pour cela pouvoir rep�rer � quelle d�claration on a affaire (avant ou apres �v�nement) */
		if xyz='X' then do; 
			if substr(vousconj,6,4)='9999' then	declaration='avant_evt';	
			else declaration ='apres_evt';
			end;
		if xyz='Y' then do; 
			if substr(vousconj,6,4) ne '9999' then	declaration='avant_evt';	
			else declaration ='apres_evt';
			end;
		if xyz='Z' then do; 
			if substr(vousconj,6,4) ne '9999' then	declaration='avant_evt';	
			else declaration ='apres_evt';
			end;
		/* Nb de jours pass�s avant l'�v�nement */
		if declaration='avant_evt' then jourevnum=(input(moisev,2.)-1)*30+input(jourev,2.)-1;
		/* Nb de jours pass�s apr�s l'evenement */
		if declaration='apres_evt' then jourevnum=360-((input(moisev,2.)-1)*30+input(jourev,2.)-1);
		 /* IRB 1 cas */
		if jourevnum=0 then jourevnum=1 ;
		/* Pour 2-3 �v�nements au 31.12 pour ne pas avoir une 2e partie d'annee a 0 jour */	
		if jourevnum=360 then jourevnum=359;
		end;

	/* Pas d'�v�nement dans l'ann�e */	
	if xyz not in ("X","Y","Z") then coeff_evt=1; 
	else if declaration="avant_evt" then coeff_evt=360/jourevnum ; 
	else if declaration="apres_evt" then coeff_evt=360/(360-jourevnum) ;

/*****************************************************************************/
/* D. Temps de travail et conversion des revenus d'activit� en ann�e pleine  */
/*****************************************************************************/

	/* Revenu d'activit� non converti (pour la limite basse, pgm ppe)  */	
	rev_ppe_d  = sum(0,indppe_d,salppe_d);
	rev_ppe_c  = sum(0,indppe_c,salppe_c);
	rev_ppe_p1 = sum(0,indppe_p1,salppe_p1);
	rev_ppe_p2 = salppe_p2;

	/* Calcul du temps de travail annuel */

	/* 1. Salari�s: nombre d'heures dans l'ann�e => toutes les heures (1820) si c'est 1 temps 
	plein (_tpsplein_ppe_:), nombre d'heures d�clar�es sinon*/	
	tps_sal_d = 1820*_tpsplein_ppe_dec1+_nbheur_ppe_dec1*coeff_evt; 
	tps_sal_c = 1820*_tpsplein_ppe_dec2+_nbheur_ppe_dec2*coeff_evt;
	tps_sal_p = 1820*_tpsplein_ppe_pac1+_nbheur_ppe_pac1*coeff_evt;
	tps_sal_p2= 1820*_tpsplein_ppe_pac2+_nbheur_ppe_pac2*coeff_evt;
	/* 2. Ind�pendants: nombre de jours dans l'ann�e => tous les jours si c'est 1 temps plein, nombre de jours d�clar�s sinon */	
	tps_nonsal_d= 360*_pro_act_annee_dec1+_pro_act_jour_dec1*coeff_evt; 
	tps_nonsal_c= 360*_pro_act_annee_dec2+_pro_act_jour_dec2*coeff_evt;
	tps_nonsal_p= 360*_pro_act_annee_pac+_pro_act_jour_pac*coeff_evt;

	/* Conventions DGFIP relatives aux cases PPE */	

	/*1. Pour les activit�s non salari�es, lorsque les cases de temps de travail ne sont pas
	remplies, on consid�re que l'activit� est exerc�e � temps plein pour l'appr�ciation de 
	la limite haute (pgm ppe) et le calcul de la prime (pgm ppe). Pour le calcul de la prime,
	rien de stipul� dans le fichier DGFIP mais c'est ce que suppose la brochure pratique. 
	La correction suivante se r�percute sur le revenu d'activit� converti, lui m�me utilis� 
	pour l'appr�ciation de la limite haute et le calcule de la prime ds le pgm ppe */	
	if indppe_d>0  & _pro_act_jour_dec1=0 & _pro_act_annee_dec1=0 then tps_nonsal_d=360;
	if indppe_c>0  & _pro_act_jour_dec2=0 & _pro_act_annee_dec2=0 then tps_nonsal_c=360;
	if indppe_p1>0 & _pro_act_jour_pac=0 & _pro_act_annee_pac=0 then tps_nonsal_p=360;
	/*2. En pr�sence de revenus d�clar�s en J, pas de calcul de la prime pour l'individu, 
	m�me en cas d'activit� non salari�e compl�mentaire : la mise � 0 de rev_ppe dans le pgm 
	rend de fait l'individu in�ligible (pgm ppe) */	

	if sum(_1aj,_1af,_1ag,_1tp,_1nx,_1pm,0)>0 & (_nbheur_ppe_dec1=0 & _tpsplein_ppe_dec1=0) then rev_ppe_d =0;
	if sum(_1bj,_1bf,_1bg,_1up,_1ox,_1qm,0)>0 & (_nbheur_ppe_dec2=0 & _tpsplein_ppe_dec2=0) then rev_ppe_c =0;
	if sum(_1cj,_1cf,_1cg,0)>0 & (_nbheur_ppe_pac1=0 & _tpsplein_ppe_pac1=0) then rev_ppe_p1=0;
	if sum(_1dj,_1df,_1dg,0)>0 & (_nbheur_ppe_pac2=0 & _tpsplein_ppe_pac2=0) then rev_ppe_p2=0;

	/*3. Sans revenus d�clar�s en J, le temps de travail salari� �ventuellement d�clar� doit �tre nul */	

	if sum(_1aj,_1af,_1ag,_1tp,_1nx,_1pm,0)=0 & (_nbheur_ppe_dec1>0 ! _tpsplein_ppe_dec1>0) then tps_sal_d =0;
	if sum(_1bj,_1bf,_1bg,_1up,_1ox,_1qm,0)=0 & (_nbheur_ppe_dec2>0 ! _tpsplein_ppe_dec2>0) then tps_sal_c =0;
	if sum(_1cj,_1cf,_1cg,0)=0 & (_nbheur_ppe_pac1>0 ! _tpsplein_ppe_pac1>0) then tps_sal_p1=0;
	if sum(_1dj,_1df,_1dg,0)=0 & (_nbheur_ppe_pac2>0 ! _tpsplein_ppe_pac2>0) then tps_sal_p2=0;

	/*4. En revanche, pour les cas d'autres revenus d'activit� salari�s que J qui omettent de 
	remplir les cases de temps de travail, on consid�re leur activit� exerc�e � temps plein */	

	if salppe_d>0  & sum(_1aj,_1af,_1ag,_1tp,_1nx,_1pm,0)=0 & (_nbheur_ppe_dec1=0 & _tpsplein_ppe_dec1=0) then tps_sal_d =1820;
	if salppe_c>0  & sum(_1bj,_1bf,_1bg,_1up,_1ox,_1qm,0)=0 & (_nbheur_ppe_dec2=0 & _tpsplein_ppe_dec2=0) then tps_sal_c =1820;
	if salppe_p1>0 & sum(_1cj,_1cf,_1cg,0)=0 & (_nbheur_ppe_pac1=0 & _tpsplein_ppe_pac1=0) then tps_sal_p1=1820;
	if salppe_p2>0 & sum(_1dj,_1df,_1dg,0)=0 & (_nbheur_ppe_pac2=0 & _tpsplein_ppe_pac2=0) then tps_sal_p2=1820;


	/* Proratisation du temps total de travail entre 0 et 1, maximum */	
	tps_d =min(tps_sal_d /1820+tps_nonsal_d/360,1);
	tps_c =min(tps_sal_c /1820+tps_nonsal_c/360,1);
	tps_p1=min(tps_sal_p /1820+tps_nonsal_p/360,1);
	tps_p2=min(tps_sal_p2/1820,1);

	/* Revenu d'activit� converti en ann�e pleine (*coeff_evt) qd �v�nement dans l'ann�e et 
	en �quivalent temps plein (/tps_) lorsque l'activit� est exerc�e � le temps partiel.
	Pour la limite haute et le calcul de la prime (pgm ppe) */	
	if tps_d  ne 0 then reqtc_d =rev_ppe_d /tps_d *coeff_evt; else reqtc_d =0;
	if tps_c  ne 0 then reqtc_c =rev_ppe_c /tps_c *coeff_evt; else reqtc_c =0;
	if tps_p1 ne 0 then reqtc_p1=rev_ppe_p1/tps_p1*coeff_evt; else reqtc_p1=0;
	if tps_p2 ne 0 then reqtc_p2=rev_ppe_p2/tps_p2*coeff_evt; else reqtc_p2=0;

	run;


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
