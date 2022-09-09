*************************************************************************************;
/*																					*/
/*								AEEH												*/
/*								remplace l'AES en 2006								*/
*************************************************************************************;

/* Mod�lisation de l'Allocation d'Education de l'Enfant Handicap�	*/
/* En entr�e : modele.basefam 
			   modele.baseind					                 	*/
/* En sortie : modele.basefam                                     	*/

********************************************************************;
/* 
Plan
A. Cr�ation des variables sur le handicap
B. Calcul du montant de l'AEEH 
	B.1 Pour le 1er enfant
	B.2 Pour le 2�me enfant
	B.3 Montant annuel par famille
*/
********************************************************************;

proc sort data=modele.baseind(keep  = ident_fam handicap_e categ 
							  where = (handicap_e ne '' & ident_fam ne '')) 
	out=EnfantHandicape; 
	by ident_fam; 
	run; 

proc sort data=modele.basefam; 	by ident_fam; run; 

/*********************************************/
/* A. Cr�ation des variables sur le handicap */
/*********************************************/
/* On calcule le nb d'enfants handicap�s par famille CAF (pas plus de 2 par famille CAF)*/
/* Nouvelles variables:
- nb_enf_handic : nombre d'enfants handicap�s dans la famille
- categ2        : classe d'handicap du 2�me enfant */

data FamilleAEEH;
	set EnfantHandicape; 
	by ident_fam;
	retain categ2 nb_enf_handic;
	if first.ident_fam then do; 
		categ2=categ;
		nb_enf_handic=0;
		end; 
	nb_enf_handic=nb_enf_handic+1;
	if last.ident_fam; 
	run; 

/*********************************************/
/* B. Calcul du montant de l'AEEH            */
/*********************************************/

%Macro AEEH;
	data aeeh;
		merge FamilleAEEH (in = a) 
			  modele.basefam (keep = ident_fam pers_iso in=b); 
		by ident_fam; 
		if a & b; 
		aeeh=0;
	    aeeh2=0; 
		
		/**********************************/
		/* B.1 Pour le 1er enfant         */
		/**********************************/

		if categ='0' then aeeh=&bmaf.* &aeeh_t0.;
		if categ='1' then aeeh=&bmaf.*(&aeeh_t0.+&aeeh_t1.);
		if categ='2' then aeeh=&bmaf.*(&aeeh_t0.+&aeeh_t2.+pers_iso*&aeeh_t2_iso.);
		if categ='3' then aeeh=&bmaf.*(&aeeh_t0.+&aeeh_t3.+pers_iso*&aeeh_t3_iso.); 
		if categ='4' then aeeh=&bmaf.*(&aeeh_t0.+&aeeh_t4.+pers_iso*&aeeh_t4_iso.);
		if categ='5' then do; 
			%if 1991<=&anleg. and &anleg.<=2001 %then %do;
				 aeeh=&bmaf.*(&aeeh_t0.+pers_iso*&aeeh_t5_iso.)+&maj_tierce.;
				 %end;
			%else %do;
				aeeh=&bmaf.*(&aeeh_t0.+&aeeh_t5.+pers_iso*&aeeh_t5_iso.);
				%end;
			end;
		if categ='6' then do;
			%if &anleg.<=1991 %then %do;
				 aeeh=&bmaf.*(&aeeh_t0.+pers_iso*&aeeh_t6_iso.)+&maj_tierce.;
				 %end;
			%else %do;
				aeeh=&bmaf.*(&aeeh_t0.+&aeeh_t6.+pers_iso*&aeeh_t6_iso.);
				%end;
			end;

		/**********************************/
		/* B.2 Pour le 2�me enfant        */
		/**********************************/
		if nb_enf_handic=2 then do; 
			if categ2='0' then aeeh2=&bmaf.* &aeeh_t0.;
			if categ2='1' then aeeh2=&bmaf.*(&aeeh_t0.+&aeeh_t1.);	
			if categ2='2' then aeeh2=&bmaf.*(&aeeh_t0.+&aeeh_t2.+pers_iso*&aeeh_t2_iso.);
			if categ2='3' then aeeh2=&bmaf.*(&aeeh_t0.+&aeeh_t3.+pers_iso*&aeeh_t3_iso.); 		
			if categ2='4' then aeeh2=&bmaf.*(&aeeh_t0.+&aeeh_t4.+pers_iso*&aeeh_t4_iso.);
			if categ2='5' then do; 
				%if 1991<=&anleg. and &anleg.<=2001 %then %do;
					 aeeh2=&bmaf.*(&aeeh_t0.+pers_iso*&aeeh_t5_iso.)+&maj_tierce.;
					 %end;
				%else %do;
					aeeh2=&bmaf.*(&aeeh_t0.+&aeeh_t5.+pers_iso*&aeeh_t5_iso.);
					%end;
				end;
			if categ2='6' then do; 
				%if &anleg.<=1991 %then %do;
					 aeeh2=&bmaf.*(&aeeh_t0.+pers_iso*&aeeh_t6_iso.)+&maj_tierce.;
					 %end;
				%else %do;
					aeeh2=&bmaf.*(&aeeh_t0.+&aeeh_t6.+pers_iso*&aeeh_t6_iso.);
					%end;
				end;
			end;

		/**********************************/
		/* B.3 Montant annuel par famille */
		/**********************************/
		aeeh = 12*(aeeh+aeeh2); 
		run; 
	%Mend AEEH;
%AEEH;

data modele.basefam;
	merge 	modele.basefam 
			aeeh(in=a keep=ident_fam aeeh);
	by ident_fam;
	if not a then aeeh=0; 
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
