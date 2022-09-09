/********************************************************************************/
/*  					probabilite_imputation_enfant							*/
/*																				*/
/* Calcul de la probabilité d'une naissance en janvier ou février &anr2.
/* et tirage des enfants à naitre										        */ 
/********************************************************************************/
/* En entrée :	dossier.imputnais&anr. 												*/
/* 				travail.irf&anr.e&anr. 											*/
/*				travail.menage&anr. 											*/	
/* En sortie : 	imput.a_naitre													*/
/********************************************************************************/	
/* Plan :																		*/ 
/* I-  PARAMETRES : transformation des coefficients estimés en macro-variables 	*/
/* II- MODELE et IMPUTATION des NAISSANCES en &anr.								*/
/*	a- définition des variables utiles au calcul des probabilités de naissance  */
/*	b- affectation des probabilités de naissance								*/
/* III - TIRAGE ET SAUVEGARDE DE LA TABLE DES ENFANTS A NAITRE 					*/
/********************************************************************************/


/*******************************************************/
/*	I-PARAMETRES 									   */
/*******************************************************/
data _null_;
	set dossier.imputnais&anr. ;
	call symputx(variable,estimate);
	run;


/********************************************************/
/*	II-MODELE et IMPUTATION des NAISSANCES              */
/********************************************************/

data impunais_i;
	set travail.irf&anr.e&anr.(keep=ident noi lprm ag naia naim sexe salmee acteu matri coured);
	agej=&anref.-input(naia,4.);
	agej_mois=(&anref.-input(naia,4.))*12+(12-naim);
	run;

data impunais_m(keep=ident nb_membres nb_parents pr conj nenf nptenf agej_hom agej_fem m_hom m_fem coured_hom coured_fem acteu_hom 
	salmee_hom acteu_fem salmee_fem age_nais_mois);
	set impunais_i;
	by ident;
	retain nb_membres nb_parents pr conj nenf nptenf agej_hom agej_fem m_hom m_fem coured_hom coured_fem
		acteu_hom fi_hom salmee_hom acteu_fem fi_fem salmee_fem
		age_nais_mois;
	if first.ident then do;
		pr="     ";
		conj="     ";
		nb_parents=0;
		nb_membres=0;
		nenf=0;
		nptenf=0;
		agej_hom=0;
		agej_fem=0;
		m_hom="            ";
		m_fem="            ";
		coured_hom="   ";
		coured_fem="   ";
		acteu_hom=" ";
		fi_hom=" ";
		salmee_hom=-1;
		acteu_fem=" ";
		fi_fem=" ";
		salmee_fem=-1; 
		age_nais_mois=.;
		end;
	nb_membres=nb_membres+1;
	if lprm="1" then do;
		nb_parents=nb_parents+1;
		if sexe="1" then do;
			pr="homme";
			agej_hom=agej;
			if matri="1" then m_hom="celibataire";
			else if matri="2" then m_hom="marie      ";
			else if matri="3" then m_hom="veuf       ";
			else if matri="4" then m_hom="divorce    ";
			if coured="1" then coured_hom="oui";
			else coured_hom="non";
			acteu_hom=acteu;
			if salmee='' then salmee_hom=.; else salmee_hom=(input(salmee,8.))*(salmee not in ('9999998','9999999'));
			end;
	    else do;
			pr="femme";
			agej_fem=agej;
			if matri="1" then m_fem="celibataire";
			else if matri="2" then m_fem="marie      ";
			else if matri="3" then m_fem="veuf       ";
			else if matri="4" then m_fem="divorce    ";
			if coured="1" then coured_fem="oui";
			else coured_fem="non";
			acteu_fem=acteu;
			if salmee='' then salmee_fem=.; else salmee_fem=(input(salmee,8.))*(salmee not in ('9999998','9999999'));
			end;
		end;
	else if lprm='2' then do;
		nb_parents=nb_parents+1;
		conj="femme";
		agej_fem=agej;
		if matri="1" then m_fem="celibataire";
		else if matri="2" then m_fem="marie      ";
		else if matri="3" then m_fem="veuf       ";
		else if matri="4" then m_fem="divorce    ";
		if coured="1" then coured_fem="oui";
		else coured_fem="non";
		acteu_fem=acteu;
		if salmee='' then salmee_fem=.; else salmee_fem=(input(salmee,8.))*(salmee not in ('9999998','9999999'));
		end;
	if last.ident then output;
	run;

data impunais_m2(keep=ident nenfm21 nenf_1 nenf0 nenf1 nenf2 nenf3 age_ben_mois age_ben_mois2);
	set impunais_i;
	by ident;
	retain nenfm21 nenf_1 nenf0 nenf1 nenf2 nenf3 age_ben_mois age_ben_mois2;
	if first.ident then do;
		nenfm21=0;
		nenf_1=0;
		nenf0=0;
		nenf1=0;
		nenf2=0;
		nenf3=0;
		age_ben_mois=999;
		age_ben_mois2=999; 
		end;
	if lprm='3' then do;
		age_ben_mois=min(agej_mois,age_ben_mois);
	    age_ben_mois2=min(agej_mois*(agej_mois>-1)+age_ben_mois2*(agej_mois<0),age_ben_mois2);
		nenfm21=nenfm21+(-1<agej_mois)*(agej_mois<252);
		nenf_1=sum(nenf_1,(agej=-1));
		nenf0=sum(nenf0,(agej=0));
		nenf1=sum(nenf1,(agej=1));
		nenf2=sum(nenf2,(agej=2));
		nenf3=sum(nenf3,(agej=3));
		end;
	if last.ident then output;
	run;

data impunais_m2;
	set impunais_m2;
	if nenfm21<=0 then age_ben_mois2=999;
	age_ben_impo=(age_ben_mois2<=8);
	age_ben1_inf_1=(8<age_ben_mois2<=20)*(nenfm21=1);*le benjamin si 1 enfant (hors naissances en janv fev) ;
	age_ben1_1_3=(20<age_ben_mois2<=46)*(nenfm21=1);
	age_ben1_sup_3=(46<age_ben_mois2<999)*(nenfm21=1);
	age_ben2_inf_1=(8<age_ben_mois2<=20)*(nenfm21>1);*le benjamin si deux enfants ou plus (hors naissances en janv fev) ;
	age_ben2_1_3=(20<age_ben_mois2<=46)*(nenfm21>1);
	age_ben2_sup_3=(46<age_ben_mois2<999)*(nenfm21>1);
	run;

data impunais_m;
	merge impunais_m impunais_m2;
	by ident; 
	if nenfm21<=0 then age_ben_mois=999;
	run;

/***** a -	définition des variables utiles au calcul des probabilités de naissance *****/    
/****************************************************************************************/
data impunais_m;
	set impunais_m; 
	if nb_parents=1 and pr="homme" then delete; /* on exclut les hommes seuls */
	if agej_fem>50 then delete; /* on exclut les femmes de plus de 50 ans */
	if age_ben_impo=1 then delete;

	mariee=(m_fem='marie');
	celibataire=(m_fem='celibataire');
	veuve=(m_fem='veuf');
	divorcee=(m_fem='divorce');
	veuv_div=veuve+divorcee;

	emp_fem=(acteu_fem='1');
	chom_fem=(acteu_fem='2');
	inac_fem=(acteu_fem='3');
	emp_chom_fem=emp_fem+chom_fem;

	couple=(nb_parents=2);
	couple_emp=couple*(acteu_hom='1');
	couple_chom=couple*(acteu_hom='2');
	couple_inac=couple*(acteu_hom='3');
	couple_emp_chom=couple_emp+couple_chom;
	run;


/***** b -	affectation des probabilités de naissance *****/
/**********************************************************/
data impunais_m(keep=ident proba_enf  tri);
	set impunais_m;
	agej2_fem=agej_fem*agej_fem;
	xbeta=	&intercept.  
			+agej_fem*&agej_fem. +agej2_fem*&agej2_fem.  
			+inac_fem*&inac_fem.
			+couple_emp_chom*&couple_emp_chom.+couple_inac*&couple_inac.
			+age_ben1_inf_1*&age_ben1_inf_1.+age_ben1_1_3*&age_ben1_1_3.+age_ben1_sup_3*&age_ben1_sup_3.
			+age_ben2_inf_1*age_ben2_inf_1+age_ben2_1_3*&age_ben2_1_3.+age_ben2_sup_3*&age_ben2_sup_3.
			+celibataire*celibataire+veuv_div*&veuv_div.;
	proba_enf=1/(1+exp(-xbeta));
	alea=ranuni(5);
	tri=proba_enf-alea;
	run;

proc sort data=impunais_m; by descending tri; run;

/****************************************************************************/
/*	III - TIRAGE ET SAUVEGARDE DE LA TABLE DES ENFANTS A NAITRE             */
/****************************************************************************/

data imput(drop=tri proba_enf); 
	set impunais_m; 
	if tri>0; 
	alea=ranuni(1);
	run; 

proc sort data=imput; by ident; run;
proc sort data=travail.menage&anr.(keep=ident module) out=menage&anr.; by ident; run;
data imput.a_naitre; 
	merge 	imput(in=b) 
			menage&anr. (in=a);
	by ident; 
	if a & b & module<=1;
	if alea <0.5 then mois_1='01'; 
	if alea>=0.5 then mois_1='02'; 
	run;

proc datasets library=work mt=data kill;run;quit;


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
