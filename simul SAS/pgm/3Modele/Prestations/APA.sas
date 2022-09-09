/************************************************************************************/
/*																					*/
/*									APA												*/
/*								 													*/
/************************************************************************************/

/* Imputation de l'Allocation Personnalisé d'Autonomie			   					*/
/************************************************************************************/
/* En entrée : base.baseind 														*/
/*			   modele.rev_imp&anr1					          						*/
/* En sortie : modele.apa                                     						*/
/************************************************************************************/
/* Plan :							                          						*/
/* 	A. Création de la table avec les individus éligibles à l'APA                    */
/* 	B. Calage du nombre de bénéficiaires                           					*/
/*		B.1 Calage sur l'âge et le revenu                          					*/
/*		B.2 Calage sur les GIR                          							*/
/*	C. Calcul du montant de l'aide                           						*/
/************************************************************************************/

/*écart à la législation : on ne code pas la majoration si le proche aidant est indispensable au maintien 
à domicile du bénéficiaire de l'Apa et s'il ne peut être remplacé par une autre personne à titre non professionnel
ou en cas d'hospitalisation du proche aidant
ou encore majoration de la participation du bénéficiaire prévue en cas de recours à un salarié en emploi direct ne 
répondant pas aux exigences de qualification ou d'expérience fixées par arrêté*/

/************************************************************************************/
/* 	A. Création de la table avec les individus éligibles à l'APA                    */
/************************************************************************************/
proc sort data=base.baseind; by ident noi; run;
data indiv; 
	set base.baseind (keep  =ident noi acteu6 declar1 naia lprm wpela&anr2. 
					  in    =a 
					  rename=(declar1=declar));
	by ident noi; 
	run;
proc sort data=indiv; by declar; run;
data indiv;
	merge indiv (in=a)
		  modele.rev_imp&anr1. (keep=declar &zvalfP. RFR _7df _7db);
	by declar;
	if a; 
	/* On donne l'APA uniquement aux personnes "chef de foyer"	*/
	age=&anref.-input(naia,4.);
	if age>15 & RFR ^= . & lprm in ('1','2');
	array zvalfP &zvalfP.;
	%Init_Valeur(zvalf);
	do i=1 to dim(zvalfP); zvalf=zvalf+zvalfP(i); end;
	/* Normalement les gens avec du _7db (emploi salarié à domicile) ne doivent pas toucher l'apa */
	cr7df=sum(0,_7df,_7db);  
	run;

proc sort data=indiv; by ident; run; 
data tt (keep=ident lprm age_pr declar_pr acteu6_pr age_cj declar_cj acteu6_cj RFR_pr RFR_cj coured);
	set indiv; 
	by ident;
	attrib declar_pr format = $64.;
	attrib declar_cj format = $64.;
	retain age_pr declar_pr acteu6_pr RFR_pr age_cj declar_cj acteu6_cj RFR_cj coured;
	if first.ident	then do;
		age_pr=.; 
		declar_pr=' '; 
		acteu6_pr=' '; 
		RFR_pr=.;
		age_cj=.; 
		declar_cj=' '; 
		acteu6_cj=' '; 
		RFR_cj=.;
		coured=3; 
		end;
	if lprm='1' then do; 
		age_pr=&anref.-input(naia,4.); 
		declar_pr=declar; 
		acteu6_pr=acteu6; 
		RFR_pr=RFR; 
		end;
	if lprm='2' then do; 
		age_cj=&anref.-input(naia,4.); 
		declar_cj=declar; 
		acteu6_cj=acteu6; 
		RFR_cj=RFR; 
		end;
	coured=coured-1;
	if last.ident;
	run;

data total1; 
	merge 	indiv(in=a) 
			tt; 
	by ident; 
	if a & age>=&age_tr1.;
	employ=(cr7df>0);
	if coured=2 then revapa=RFR/12;
	if coured=1 then do;
		if lprm ='1' then do;
			if declar = declar_cj then revapa=RFR/(12*1.7);
			else revapa=(RFR+RFR_cj)/(12*1.7);
			end;
		if lprm ='2' then do;
			if declar = declar_pr then revapa=RFR/(12*1.7);
			else revapa=(RFR+RFR_cj)/(12*1.7);
			end;
		end;
	if 	    revapa<&maparess_s1.*&inflat05./1.016 then aparess='1';
	else if revapa<&maparess_s2.*&inflat05./1.016 then aparess='2';
	else if revapa<&maparess_s3.*&inflat05./1.016 then aparess='3';
	else if revapa<&maparess_s4.*&inflat05./1.016 then aparess='4';
	else if revapa<&maparess_s5.*&inflat05./1.016 then aparess='5';
	else if revapa<&maparess_s6.*&inflat05./1.016 then aparess='6';
	else if revapa<&maparess_s7.*&inflat05./1.016 then aparess='7';
	else aparess='8';

	/* Création des tranches d'âge de l'APA */
	if                 age<&age_tr2. then trage='1';
	else if &age_tr2.<=age<&age_tr3. then trage='2';
	else if &age_tr3.<=age           then trage='3';
	tri=trage!!aparess;
	run;


/************************************************************************************/
/* 	B. Calage du nombre de bénéficiaires                           					*/
/************************************************************************************/

	/*************************************/
	/* B.1 Calage sur l'âge et le revenu */
	/*************************************/
data total2; 
	set total1; 
	if employ ! aparess='1'; 
/*	C'est bizare car finalement, on ne retient que ceux qui ont un CI ou qui sont en dessous d'un certain seuil de revenu.*/
	alea=uniform(1); 
	run;
/* INES 2009 : 7 734 avec l'ancien programme, 8 555 après
  INES 2010 : 10 800 personnes
  INES 2012 : 20 647 personnes */
 
proc sort data=total2; by tri alea; run;
data total3; set total2; by tri alea;
	potapa=1;
	retain co;
	if first.tri then co=0;
	co=co+wpela&anr2.;
	if      tri='11' & co>&mapa74.*&maparess_t1.*&mapabenef. then potapa=0;
	else if tri='12' & co>&mapa74.*&maparess_t2.*&mapabenef. then potapa=0;
	else if tri='13' & co>&mapa74.*&maparess_t3.*&mapabenef. then potapa=0;
	else if tri='14' & co>&mapa74.*&maparess_t4.*&mapabenef. then potapa=0;
	else if tri='15' & co>&mapa74.*&maparess_t5.*&mapabenef. then potapa=0;
	else if tri='16' & co>&mapa74.*&maparess_t6.*&mapabenef. then potapa=0;
	else if tri='17' & co>&mapa74.*&maparess_t7.*&mapabenef. then potapa=0;
	else if tri='18' & co>&mapa74.*&maparess_t8.*&mapabenef. then potapa=0;
	else if tri='21' & co>&mapa84.*&maparess_t1.*&mapabenef. then potapa=0;
	else if tri='22' & co>&mapa84.*&maparess_t2.*&mapabenef. then potapa=0;
	else if tri='23' & co>&mapa84.*&maparess_t3.*&mapabenef. then potapa=0;
	else if tri='24' & co>&mapa84.*&maparess_t4.*&mapabenef. then potapa=0;
	else if tri='25' & co>&mapa84.*&maparess_t5.*&mapabenef. then potapa=0;
	else if tri='26' & co>&mapa84.*&maparess_t6.*&mapabenef. then potapa=0;
	else if tri='27' & co>&mapa84.*&maparess_t7.*&mapabenef. then potapa=0;
	else if tri='28' & co>&mapa84.*&maparess_t8.*&mapabenef. then potapa=0;
	else if tri='31' & co>&mapa85.*&maparess_t1.*&mapabenef. then potapa=0;
	else if tri='32' & co>&mapa85.*&maparess_t2.*&mapabenef. then potapa=0;
	else if tri='33' & co>&mapa85.*&maparess_t3.*&mapabenef. then potapa=0;
	else if tri='34' & co>&mapa85.*&maparess_t4.*&mapabenef. then potapa=0;
	else if tri='35' & co>&mapa85.*&maparess_t5.*&mapabenef. then potapa=0;
	else if tri='36' & co>&mapa85.*&maparess_t6.*&mapabenef. then potapa=0;
	else if tri='37' & co>&mapa85.*&maparess_t7.*&mapabenef. then potapa=0;
	else if tri='38' & co>&mapa85.*&maparess_t8.*&mapabenef. then potapa=0;
	run;

	/**************************/
	/* B.2 Calage sur les GIR */
	/**************************/

data GIR; 
	set total3(where=(potapa=1));
	sor=uniform(1);
	if trage='1' then do;
		if sor<&mapagirage1. then GIR=1;
		else if sor<&mapagirage2. then GIR=2;
		else if sor<&mapagirage3. then GIR=3;
		else GIR=4;
		end;
	if trage='2' then do;
		if sor<&mapagirage4. then GIR=1;
		else if sor<&mapagirage5. then GIR=2;
		else if sor<&mapagirage6. then GIR=3;
		else GIR=4; 
		end;
	if trage='3' then do;
		if sor<&mapagirage7. then GIR=1;
		else if sor<&mapagirage8. then GIR=2;
		else if sor<&mapagirage9. then GIR=3;
		else GIR=4; 
		end;

/************************************************************************************/
/*	C. Calcul du montant de l'aide                           						*/
/************************************************************************************/

	/* Montant du plan daide - astuce du calcul: on multiplie le plan d'aide par sa valeur 
	moyenne +/- un interval de confiance correspondant à la distance entre le plafond de 
	l'aide et la moyenne de l'aide touché. Cela permet d'avoir une aide qui n'excède 
	jamais le plafond. */
	if      gir=1 then planaide=&paidemax1.*(&mapapaid1. +(uniform(1)-0.5)*(1-&mapapaid1.)/0.5);
	else if gir=2 then planaide=&paidemax2.*(&mapapaid2. +(uniform(1)-0.5)*(1-&mapapaid2.)/0.5);
	else if gir=3 then planaide=&paidemax3.*(&mapapaid3. +(uniform(1)-0.5)*(1-&mapapaid3.)/0.5);
	else if gir=4 then planaide=&paidemax4.*(&mapapaid4. +(uniform(1)-0.5)*(1-&mapapaid4.)/0.5);

	/* Participation du bénéficiaire */
	if revapa<&bornapa1. then particip=0;
	else if &bornapa1.<=revapa<&bornapa2. then 
		particip=(planaide*(revapa-(&bornapa1.))*&txpartapa.)/(&bornapa2.-&bornapa1.);
	else if &bornapa2.<=revapa then particip=planaide*&txpartapa.;

	/* Montant de l'APA versée */
	APA=(planaide-particip)*12;
	label apa	="Allocation personnalisee d autonomie";

	/* Seuil de non versement*/
	if 0<APA<&seuilnonAPA. then APA=0;

	run;

proc sort data=gir(keep=ident noi declar age revapa gir planaide particip apa wpela&anr2.) out=modele.apa; by ident; run;



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
