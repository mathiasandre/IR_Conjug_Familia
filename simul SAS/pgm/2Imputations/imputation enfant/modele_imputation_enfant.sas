/****************************************************************************************/
/*               				modele_imputation_enfant								*/		
/*																						*/
/*						- Modele d'imputation des naissances -							*/
/*																						*/
/****************************************************************************************/
/* Programme d'imputation de naissances : estimation de la probabilit� d'avoir un       */
/* enfant � naitre en janvier ou f�vrier &anr2. � partir de tables de l'Enqu�te Emploi	*/ 
/* (tables compl�mentaires pour &anr2.). La table en sortie contient les coefficients de*/
/* cette estimation.																	*/
/****************************************************************************************/
/* En entr�e : 	rpm.indiv&anr2.2														*/
/* 				rpm.enf&anr2.2															*/
/* En sortie : 	dossier.imputnais&anr.                              							*/
/****************************************************************************************/

%macro ModeleImputation;
	%if &casd. = non %then %do;
		%if &imputEnf_prem.=oui %then %do;
			%macro Define_var_EE;
				/* variable lpr qui change de nom � partir de l'EEC 2013 */
				/* Ce renommage a �t� g�r� dans initialisation mais l� on revient � la table de RPM, et donc il faut refaire l'op�ration */
				%global lpr;
				%if &anr2.>=13 %then %let lpr=lprm;
				%else %let lpr=lpr;
				%mend Define_var_EE;
			%Define_var_EE;

			data impunais_i(drop=acteu6);
				set rpm.indiv&anr2.2(keep=ident noi &lpr. ag naia naim sexe salmee acteu6 matri)  
					rpm.enf&anr2.2(keep=ident noi &lpr. naia naim);
				length acteu1 $1 ;
				agej=&anref.+1-input(naia,4.);/* �ge en d�cembre de &anref. +1  */
				agej_mois=(&anref.+1-input(naia,4.))*12+(12-input(naim,4.));
				select (acteu6);
					when ('1') 		acteu1='1';
					when ('3','4')	acteu1='2';
					when ('5','6') 	acteu1='3';
					otherwise 		acteu1='';
					end;
				run;
			proc sort data=impunais_i; by ident; run;

			data impunais_m(keep=ident nb_parents pr agej_fem m_fem acteu_hom acteu_fem);
				set impunais_i;
				by ident;
				retain nb_parents agej_fem m_fem acteu_hom acteu_fem pr;
				array _var_ nb_parents agej_fem m_fem acteu_hom acteu_fem pr;

				if first.ident then do;
					do _i_=1 to 6; _var_(_i_)=0; end; 
					end;

				if &lpr.="1" then do;
					nb_parents=nb_parents+1;
					pr=input(sexe,4.);
					if sexe="1" then acteu_hom=input(acteu1,4.);
			    	else do;
						agej_fem=agej;
						m_fem=input(matri,4.);
						acteu_fem=input(acteu1,4.); 
						end;
					end;
				else if &lpr.='2' then do;
					nb_parents=nb_parents+1;
					agej_fem=agej;
					m_fem=input(matri,4.);
					acteu_fem=input(acteu1,4.);
					end;
				if last.ident then output;
				run;

			data impunais_m2(keep=ident nenfm21 nenf_1 nenf0 nenf1 nenf2 nenf3 
							age_ben_mois age_ben_mois2);
				set impunais_i;
				by ident;
				retain nenfm21 nenf_1 nenf0 nenf1 nenf2 nenf3 age_ben_mois age_ben_mois2;
				if first.ident then do;
					nenfm21=0; nenf_1=0; nenf0=0;
					nenf1=0; nenf2=0; nenf3=0; age_ben_mois=999; age_ben_mois2=999; 
					end;
				if &lpr.='3' then do;
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
				age_ben_impo  =(age_ben_mois2<=8);
				/*1 enfant*/
				age_ben1_inf_1=(8 <age_ben_mois2<=20)*(nenfm21=1);/*le benjamin (hors naissances en janv fev)*/
				age_ben1_1_3  =(20<age_ben_mois2<=46)*(nenfm21=1);
				age_ben1_sup_3=(46<age_ben_mois2<999)*(nenfm21=1);
				/*au moins 2 enfants*/
				age_ben2_inf_1=(8 <age_ben_mois2<=20)*(nenfm21>1);/*le benjamin (hors naissances en janv fev)*/
				age_ben2_1_3  =(20<age_ben_mois2<=46)*(nenfm21>1);
				age_ben2_sup_3=(46<age_ben_mois2<999)*(nenfm21>1);
				run;

			data impunais_m; 
				merge 	impunais_m 
						impunais_m2; 
				by ident;
				run;


			/*******************************************************************************/
			/*	a-	d�finition des variables utiles au calcul des probabilit�s de naissance*/   
			/* *****************************************************************************/
			data impunais_m; 
				set impunais_m; 
				if nb_parents=1 and pr=1 then delete; /* on exclut les hommes seuls */
				if agej_fem>50 then delete; /* on exclut les femmes de plus de 50 ans */

				celibataire	=(m_fem=1);
				mariee		=(m_fem=2);
				veuve		=(m_fem=3);
				divorcee	=(m_fem=4);
				veuv_div=veuve+divorcee;

				emp_fem	=(acteu_fem=1);
				chom_fem=(acteu_fem=2);
				inac_fem=(acteu_fem=3);
				emp_chom_fem=emp_fem+chom_fem;

				couple=(nb_parents=2);
				couple_emp=couple*(acteu_hom=1);
				couple_chom=couple*(acteu_hom=2);
				couple_inac=couple*(acteu_hom=3);
				couple_emp_chom=couple_emp+couple_chom;
				run;

			data trav;
				set impunais_m;
				where age_ben_mois in (-1,-2);
				run;

			/*** Regression ***/
			data job1; 
				set impunais_m; 
				naissance=(age_ben_mois in (-1,-2)); 
				agej2_fem=agej_fem*agej_fem; 
				run;

			proc logistic data=job1 descending;
				ods output parameterestimates = dossier.imputnais&anr. ;
				model naissance=
							agej_fem agej2_fem
							celibataire veuv_div
							inac_fem
							couple_emp_chom couple_inac
							age_ben1_inf_1 age_ben1_1_3 age_ben1_sup_3
							age_ben2_inf_1 age_ben2_1_3 age_ben2_sup_3;
				/*on ne pond�re pas, notamment pour ne pas devoir utiliser la variable de poids extriXX qui doit �tre mise � jour chaque ann�e.
				En effet, Extri est cal�e sur le recensement et r�tropol�e, et les r�sultats du recensement sont d�finitifs 3 ans apr�s l'enqu�te 
				Pour pond�rer, il faudrait donc chaque ann�e modifier ce programme apr�s avoir r�cup�r� les tables les plus fra�ches : trop lourd pour un impact nul*/
				run;
			%end;
		%end;
	%mend;

%ModeleImputation;


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
