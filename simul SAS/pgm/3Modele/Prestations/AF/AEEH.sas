*************************************************************************************;
/*																					*/
/*								AEEH												*/
/*								remplace l'AES en 2006								*/
*************************************************************************************;

/* Modélisation de l'Allocation d'Education de l'Enfant Handicapé	*/
/* En entrée : modele.basefam 
			   modele.baseind					                 	*/
/* En sortie : modele.basefam                                     	*/

********************************************************************;
/* 
Plan
A. Création des variables sur le handicap
B. Calcul du montant de l'AEEH 
	B.1 Pour le 1er enfant
	B.2 Pour le 2ème enfant
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
/* A. Création des variables sur le handicap */
/*********************************************/
/* On calcule le nb d'enfants handicapés par famille CAF (pas plus de 2 par famille CAF)*/
/* Nouvelles variables:
- nb_enf_handic : nombre d'enfants handicapés dans la famille
- categ2        : classe d'handicap du 2ème enfant */

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
		/* B.2 Pour le 2ème enfant        */
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
