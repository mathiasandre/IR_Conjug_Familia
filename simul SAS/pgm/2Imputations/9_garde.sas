*************************************************************************************;
/*																					*/
/*								9_garde												*/
/*																					*/
*************************************************************************************;

/* Imputation du mode de garde � partir des informations fiscales et EE   	*/
/* En entr�e :  rpm.menage&anr.                                  			*/ 
/*				modele.basefam                                  			*/
/* En sortie :  modele.basefam                                     			*/


/* Description : 
Il existe 4 modes de garde ouvrant droit � des allocations diff�rentes. 
	- cas1 : on emploie directement quelqu'un chez soi pour s'occuper de ses enfants,
	- cas2 : on emploie directement une assistante maternelle (forc�ment hors du domicile)
	- cas3 : on a recours � un organisme priv� qui ou bien emploi une assistante maternelle 
	- cas4 : ou envoie quelqu'un � domicile ou recours � une micro-cr�che. 

Le cas 1 est indentifi� par les d�clarations d'emploi � domicile dans les d�clarations fiscales. � noter
qu'il peut s'agir d'autres emplois que de la garde mais on supprimera certains cas si besoin. �  noter aussi 
que d'apr�s la brochure pratique, on peut d�clarer ici des d�penses quand on passe par un organisme qui  
va embaucher lui quelqu'un � domicile, pour la CAF c'est le cas 4, heureusement, on le n�glige pour l'instant; 
Les cas 2, 3 et 4 se r�p�re par les frais de garde � l'ext�rieur du domicile _7ga, etc. 
Parmi eux, il faut tirer les diff�rents modes.

On peut, en th�orie, m�langer plusieurs modes de garde mais on simplifie ici avec un mode de garde unique. 
*/

/* on a r�cup�r� dans basefam, gr�ce au programe ressources.sas 
gardehdom&anr2.=_7ga+_7gb+_7gc+_7ge+_7gf+_7gg; 
et gardeadom&anr2.=_7db+_7df;
*/

%let presta_garde=aged afeama mgam mgdom colca clca ccpe;
%macro data_cnaf;
/*les variables des aides � la garde n'apparaissent dans l'ERFS qu'en 2008*/
	%if 2015<=&anref. %then %do;
		data CNAF; 
			set rpm.menage&anr.(keep=ident&anr. %do i=3 %to 4; m_%scan(&presta_garde.,&i.)m %end; m_%scan(&presta_garde.,7)m); 
			m_agedm=0;
			m_afeamam=0;
			%do i=1 %to 4; 
				ind_%scan(&presta_garde.,&i.)=(m_%scan(&presta_garde.,&i.)m>0 ); 
				%end; 
			ind_%scan(&presta_garde.,7)=(m_%scan(&presta_garde.,7)m>0 ); 
			if %do i=1 %to 4; ind_%scan(&presta_garde.,&i.)=1 ! %end; ind_ccpe=1 then output;
			run; 
		%end;
	%else %if 2010<=&anref.<2015 %then %do;
		data CNAF; 
			set rpm.menage&anr.(keep=ident&anr. %do i=3 %to 6; m_%scan(&presta_garde.,&i.)m %end;); 
			m_agedm=0;
			m_afeamam=0;
			%do i=1 %to 6; 
				ind_%scan(&presta_garde.,&i.)=(m_%scan(&presta_garde.,&i.)m>0 ); 
				%end; 
			if %do i=1 %to 5; ind_%scan(&presta_garde.,&i.)=1 ! %end; ind_clca=1 then output;
			run; 
		%end;
	%else %if 2008<=&anref.<2010 %then %do;
		data CNAF; 
			set rpm.menage&anr.(keep=ident&anr. %do i=1 %to 6; m_%scan(&presta_garde.,&i.)m %end;); 
			%do i=1 %to 6; 
				ind_%scan(&presta_garde.,&i.)=(m_%scan(&presta_garde.,&i.)m>0 ); 
				%end; 
			if %do i=1 %to 5; ind_%scan(&presta_garde.,&i.)=1 ! %end; ind_clca=1 then output;
			run; 
		%end;
	%else %if 2008>&anref. %then %do; 
		data CNAF; 
			set rpm.menage&anr.(keep=ident&anr.); 
			%do i=1 %to 7; 
				ind_%scan(&presta_garde.,&i.)=0; 
				%end; 
			if %do i=1 %to 5; ind_%scan(&presta_garde.,&i.)=1 ! %end; ind_clca=1 ! ind_ccpe=1 then output;
			run; 
		%end;
	%mend; %data_cnaf;
/* variante, on remplace aged et afeam par mgam et mgdom */ 
data CNAF; 
	set CNAF; 
	if ind_aged=1 then do; ind_mgdom=1; end; 
	if ind_afeama=1 then do; ind_mgam=1; end; 
	run;
data cmg_caf(rename=(ident&anr.=ident)); 
	set cnaf; 
	if ind_aged=1 ! ind_afeama=1 ! ind_mgam=1 ! ind_mgdom=1; 
	run; 
/* proc freq; table ind_clca;run; */ 
/* un quart a aussi du CLCA */
proc sort data=cmg_caf; by ident; run; 


data fiscal; 
	set modele.basefam(keep= ident_fam age_enf gardeadom&anr2. gardehdom&anr2. wpela: men_paje res_paje enf_1 pers_iso); 
	ident=substr(ident_fam,1,8); 
	%nb_enf(enf6,0,5,age_enf); 
	if enf6>0 & men_paje='H' then ind=1; else ind=0;
	dom= (gardeadom&anr2.>0); 
	hdom=(gardehdom&anr2.>0); 
	if enf6>0 then gardehdom&anr2._par_enf=gardehdom&anr2./enf6;
	/*en toute rigueur, il faudrait travailler par case (une pour chaque enfant), faire ce que l'on fait l� 
	est une approximation. Si un enfant ouvre beaucoup de d�pense et les autres non alors, on fait une 
	erreur en imputant la moyenne � chacun. Cependant, il est important de faire �a car on s�lectionne plus 
	bas les familles en fonction de ce montant et si on ne le fait pas on privil�gie trop les familles avec
	plusieurs enfants par rapport aux cibles*/
	run;

proc sort data=fiscal; by ident; run; 
proc sort data=cmg_caf; by ident; run; 

data CMG; 
	merge 	fiscal(in=a) 
			cmg_caf(in=b); 
	by ident; 
	if a then source='fisc'; 
	if b then source='cnaf'; 
	if a & b then source = 'fica';
	run;
/* proc freq; table source;run;
data voir; set CMG; if source='cnaf'; run; */
/* moralit� : on ne perd pas beaucoup de gens en prenant simplement la d�claration fiscale
on passe quand m�me � c�t� de certains cas, des EE par exemple */

/* proc freq; table dom*ind_mgdom*ind_mgam  ind_mgdom*ind_mgam; run; */
/* on respecte a peu pr�s l'id�e que quand (_7db+_7df>0 ) alors on est a domicile et 
qu'on ne l'est pas sinon */ 

/* Au final, on gardera les infos fiscales */

/* il faut g�rer les cas des plusieurs m�nages dans un seul logement pour mettre l'info 
m�nage sur la garde des enfants � qui doit */
data fusion2; 
	set CMG; 
	by ident;
	retain id; 
	if first.ident then id=ident_fam;
	if id ne ident_fam then output;
	run; 
/* on ne retient que la premiere famille qui a des enfants */ 
data list1; merge fusion2(in=a) fiscal ; by ident; if a & ind=1; run;
data list2; merge fusion2(in=a) CMG ; by ident; if not a; run;

data garde; set list1 list2; if ind=1; run; 
proc sort data=garde nodupkey; by ident_fam; run;

/*proc freq data=garde(where=(ind=1)); table hdom*dom; weight wpela&anr2;run;
proc means data=garde ; var enf6; weight wpela&anr2;run; */
/* on a a peu pr�s le bon nombre d'enfant */

/*
On a de toute fa�on beaucoup trop de monde : deux explications. 
1 Pour les salari�s � domicile, on n'embauche pas que pour s'occuper des enfants donc tout n'est pas une 
traduction du mode de garde : difficile de savoir que faire. 
2 Pour les frais en dehors du domicile, on peut d�clarer les cr�ches, les centres de loisirs qui ne 
correspondent pas � des montants de gardes. Comme a priori ces �l�ments sont les montants les plus faibles
(voir r�sultat de l'enqu�te mode de garde)
on cale en s�l�ctionnant les montants les plus �lev�, ce qui, bien s�r, cr�e un biais. */

/* 
proc means data=garde; var gardehdom&anr2._par_enf gardeadom&anr2.; weight wpela&anr2;run; 
data voir; set garde; if gardehdom&anr2._par_enf>10000; run;
*/

/* tirage des sal_dom,  il faut faire mieux */ 
proc sort data=garde; by descending gardeadom&anr2.; run; 
data garde1(drop=massei1 massei2 massei3 massec1 massec2 massec3 massei1_bis massei2_bis massei3_bis massec1_bis massec2_bis massec3_bis); 
	set garde; 
	retain massei1 massei2 massei3 massec1 massec2 massec3 massei1_bis massei2_bis massei3_bis massec1_bis massec2_bis massec3_bis 0;  
	format garde $8. ;
	/* pour faire le tirage, on cale suivant la cat�gorie de ressource */
	%nb_enf(e_c,0,&age_pf.,age_enf);
	/* le calcul est un copier coller de celui du calcul de la PAJE, 
	ne rien changer ici, changer uniquement dans l'autre et refaire un copier coller */
	if sum(e_c,enf_1)<=1 then pl=&paje002.;/* plafond 1 enfant, 1 revenu */
	else if sum(e_c,enf_1)>1 then 
	pl=&paje002./(1+&paje_majo_pac12.)*(1+&paje_majo_pac12.*min(2,sum(e_c,enf_1)) 
	+&paje_majo_pac3.*max(0,sum(e_c,enf_1)-2));
	if men_paje='H' then pl=pl+&paje001.; /*couple bi-actif ou parent seul */

	if res_paje<&cmg_tplaf.*pl then categ=1;
	else if res_paje<pl then categ=2;
	else categ=3;

	/*On ajoute des 'saldom' tant que la somme des poids des 'saldom' dans chaque cat�gorie est inf�rieure � la cible
	  Pour l'observation qui fait passer au dessus de la cible, on la garde si l'�cart entre la somme des poids et la cible
	  est plus faible en l'ajoutant qu'en ne l'ajoutant pas*/
	if (pers_iso=1)& (categ=1) then do; 
		massei1_bis = massei1; /*Les variables _bis sont les avant derni�res valeurs de la variable, en l'occurence massei*/
		massei1=massei1+wpela&anr2.;
		if massei1 < &eff_cmgdomi1. OR (&eff_cmgdomi1. - massei1_bis > massei1 - &eff_cmgdomi1.) then garde='saldom';
		end; 
	if (pers_iso=1)& (categ=2) then do; 
		massei2_bis = massei2;
		massei2=massei2+wpela&anr2.;
		if massei2 < &eff_cmgdomi2. OR (&eff_cmgdomi2. - massei2_bis > massei2 - &eff_cmgdomi2.) then garde='saldom';
		end; 
	if (pers_iso=1)& (categ=3) then do; 
		massei3_bis = massei3;
		massei3=massei3+wpela&anr2.;
		if massei3 < &eff_cmgdomi3. OR (&eff_cmgdomi3. - massei3_bis > massei3 - &eff_cmgdomi3.) then garde='saldom';
		end; 
	if (pers_iso=0)& (categ=1) then do; 
		massec1_bis = massec1;
		massec1=massec1+wpela&anr2.;
		if massec1 < &eff_cmgdomc1. OR (&eff_cmgdomc1. - massec1_bis > massec1 - &eff_cmgdomc1.) then garde='saldom';
		end;
	if (pers_iso=0)& (categ=2) then do; 
		massec2_bis = massec2;
		massec2=massec2+wpela&anr2.;
		if massec2 < &eff_cmgdomc2. OR (&eff_cmgdomc2. - massec2_bis > massec2 - &eff_cmgdomc2.) then garde='saldom';
		end;
	if (pers_iso=0)& (categ=3) then do; 
		massec3_bis = massec3;
		massec3=massec3+wpela&anr2.;
		if massec3 < &eff_cmgdomc3. OR (&eff_cmgdomc3. - massec3_bis > massec3 - &eff_cmgdomc3.) then garde='saldom';
		end;
	run;
/*proc means data=garde1(where=(garde='saldom')) sum; class categ; var wpela&anr2.; run;*/

/*comme on suppose qu'il n'y a pas double mode de garde, on n'�crase pas les autres valeurs */
proc sort data=garde1; by descending gardehdom&anr2._par_enf; run; 
data garde2 (drop=massei1 massei2 massei3 massec1 massec2 massec3 massei1_bis massei2_bis massei3_bis massec1_bis massec2_bis massec3_bis); 
	set garde1; 
	retain masse masse_enf masse_bis masse_enf_bis massei1 massei2 massei3 massec1 massec2 massec3 massei1_bis massei2_bis massei3_bis massec1_bis massec2_bis massec3_bis 0; 
	format garde $8. ;
	%nb_enf(enf4,0,3,age_enf);
	if garde='' then do; 
	/*On ajoute des 'saldom' tant que la somme des poids des 'saldom' dans chaque cat�gorie est inf�rieure � la cible
	  Pour l'observation qui fait passer au dessus de la cible, on la garde si l'�cart entre la somme des poids et la cible
	  est plus faible en l'ajoutant qu'en ne l'ajoutant pas*/
		if (pers_iso=1)& (categ=1) then do; 
			massei1_bis = massei1;
			massei1=massei1+wpela&anr2.;
			if massei1 < &eff_cmgami1. OR (&eff_cmgami1. - massei1_bis > massei1 - &eff_cmgami1.) then garde='assmat';
			end; 
		if (pers_iso=1)& (categ=2) then do; 
			massei2_bis = massei2;
			massei2=massei2+wpela&anr2.;
			if massei2 < &eff_cmgami2. OR (&eff_cmgami2. - massei2_bis > massei2 - &eff_cmgami2.) then garde='assmat';
			end; 
		if (pers_iso=1)& (categ=3) then do; 
			massei3_bis = massei3;
			massei3=massei3+wpela&anr2.;
			if massei3 < &eff_cmgami3. OR (&eff_cmgami3. - massei3_bis > massei3 - &eff_cmgami3.) then garde='assmat';
			end; 
		if (pers_iso=0)& (categ=1) then do; 
			massec1_bis = massec1;
			massec1=massec1+wpela&anr2.;
			if massec1 < &eff_cmgamc1. OR (&eff_cmgamc1. - massec1_bis > massec1 - &eff_cmgamc1.) then garde='assmat';
			end;
		if (pers_iso=0)& (categ=2) then do; 
			massec2_bis = massec2;
			massec2=massec2+wpela&anr2.;
			if massec2 < &eff_cmgamc2. OR (&eff_cmgamc2. - massec2_bis > massec2 - &eff_cmgamc2.) then garde='assmat';
			end;
		if (pers_iso=0)& (categ=3) then do; 
			massec3_bis = massec3;
			massec3=massec3+wpela&anr2.;
			if massec3 < &eff_cmgamc3. OR (&eff_cmgamc3. - massec3_bis > massec3 - &eff_cmgamc3.) then garde='assmat';
			end;
		end;

	if garde='' then do; 
		masse_bis = masse;
		masse=masse+wpela&anr2.; 
		if masse < &eff_structure. OR (&eff_structure. - masse_bis > masse - &eff_structure.) then garde='structur';
		end;	

	if garde='' then do; 
		masse_enf_bis = masse_enf;
		masse_enf=masse_enf+wpela&anr2.*enf4;*on compte les enfants qui ne sont pas encore gard�s;
		if masse_enf < &nb_enf_creches. OR (&nb_enf_creches. - masse_enf_bis > masse_enf - &nb_enf_creches.) then garde='creche';
		end; 
	if garde='' then garde='parent';
	run;
/* du coup on est en cr�che jusqu'� 1050 euros a peu pr�s et plus � 270 (par les parents du coup) */

/* il faut ensuite simuler la d�pense... pour tenir compte qu'il peut y avoir de la
cr�che ou du centre de loisir dans les frais de gardes m�me ceux pour qui on a mis asmat
et qu'il peut y avoir d'autres emplois que la garde d'enfant dans les salari�s � domicile, 
cela dit,  pour l'instant on garde comme �a et on fait confiance aux plafonds pour ne pas donner
trop d'aide inappropri�e.*/

/*M�me en faisant ces hypoth�ses, il y a du travail, en effet, le plus simple est d'avoir en entr�e la 
d�pense pour les gardes AVANT les aides, or, ce que les gens d�clarent c'est les aides APRES les aides; 
La logique c'est que pour un cas type on rentre le bon montant et pas le montant net d'aides. 
Ca nous conduit ici � faire un calcul inverse, on calcule un montant de d�pense qui donnerait ce montant
de d�pense net pour l'imp�t.
On n'est pas oblig� d'�tre super pr�cis, parce que comme on a vu plus haut, il peut y avoir d'autres 
sources de d�penses (heure de m�nage, centre de loisir, etc.) 
Enfin, il faut avoir en t�te que l'on a les d�penses pour 2008 que l'on d�rive en d�pense pour l'ann�e 
2009 alors que pour la CAF on veut les d�penses de 2010 du coup ce n'est pas grave si les montants d'impots
et les montants d'aides ne concorde pas exactement. Si on faisait des impots 2011 sur l'ann�e 2010 alors l� 
il faudrait mettre les montants nets calcul�s apr�s aides de la CNAF dans les cases d'imp�ts. */

data montant; 
	set garde2; 
	/* pour remonter au montant brut � partir des d�clarations, on a besoin de connaitre la participation
	maximale de la CNAF */ 
	/*le calcul est le m�me que celui qui �tait fait jusque l� dans CMG, il faudra certainement le modifier
	plus tard*/
	%nb_enf(enf0_2,0,2,age_enf); %nb_enf(enf3_5,3,5,age_enf); 
	plafond_comp=0;
	if categ=1 then do; 
		if garde='structur' then plafond_comp=(enf0_2+0.5*enf3_5)*&cmg_hdom1.*&bmaf.*12; 
		/*if garde='structur'	then plafond_comp=max((enf0_2+0.5*enf3_5),1)*&cmg_dom1.*&bmaf.*12; */
		if garde='assmat'  then plafond_comp=(enf0_2+0.5*enf3_5)*&cmg_sal1.*&bmaf.*12; 
		if garde='saldom'  then plafond_comp= max((enf0_2+0.5*enf3_5),1)*&cmg_sal1.*&bmaf.*12; 
		end; 
	else if categ=2 then do; 
		if garde='structur' then plafond_comp=(enf0_2+0.5*enf3_5)*&cmg_hdom2.*&bmaf.*12; 
		/*if garde='structur' then plafond_comp=max((enf0_2+0.5*enf3_5),1)*&cmg_dom2.*&bmaf.*12;*/ 
		if garde='assmat'  then plafond_comp=(enf0_2+0.5*enf3_5)*&cmg_sal2.*&bmaf.*12; 
		if garde='saldom'  then plafond_comp= max((enf0_2+0.5*enf3_5),1)*&cmg_sal2.*&bmaf.*12; 
		end; 
	else do; 
		if garde='structur' then plafond_comp=(enf0_2+0.5*enf3_5)*&cmg_hdom3.*&bmaf.*12; 
		/*if garde='structur'	then plafond_comp=max((enf0_2+0.5*enf3_5),1)*&cmg_dom3.*&bmaf.*12; */
		if garde='assmat'  then plafond_comp=(enf0_2+0.5*enf3_5)*&cmg_sal3.*&bmaf.*12; 
		if garde='saldom'  then plafond_comp= max((enf0_2+0.5*enf3_5),1)*&cmg_sal3.*&bmaf.*12; 
		end; 
	/* fin du copier coller strict de CMG*/
	/*je ne maitrise pas ce param�tre */ 
	comp_min=plafond_comp; 
	/* plafond de prise en charge des cotis */
	if enf0_2>0 then plafond_cot=&cmg_exo_l1.*12;
	else if enf3_5>0 then plafond_cot=&cmg_exo_l2.*12;

	/* NOTE : CMGcot est toujours plafonn� pour un montant + �lev� de saldom que CMGcomp
    d'o� si CMGcomp n'est pas plafonn�, alors CMGcot n'est pas plafonn�
    d'o� l'ordre de traitement des CAS 1 � CAS 7 */

	a_min=0.025; /* salaire horaire brut minimum de 7euros environ contre 6.83 pour le smh brut, source site aafi.free.fr */
	a_max=0.2;   /* raisonnable */

	if enf0_2>0 then hmax_dom=52*50; /* p90 de l'enqu�te mode de garde, pour info max=55h */
	else if enf3_5>0 then hmax_dom=52*28; /* p90 de l'enqu�te mode de garde=28, pour info max=47,45 */

	cotmax=&tcot_assmat.* (1+a_min)*9*hmax_dom; /* cotisation sal+pat max pour a=a_min */
	tcot=&tcot_assmat./(1-&salcot_assmat.); /* taux de cotisations sal+pat r/r au salaire net */

	/* CAS 1 :
	- le compl�ment minimum est sup�rieur au SN, le salaire net est enti�rement couvert (CMGcomp=sal_net);
	- gardeadom&anr2. = sal_net + COT - CMGcot - CMGcomp = COT - CMGcot
	            = 0.5*COT = 0.5*(tcot*sal_net) = 0.5*(tcot*CMGcomp) <= 0.5*(tcot*comp_min); */
	if gardeadom&anr2.<=0.5*tcot*comp_min then do;
		cas_cot=1;
		cmg_comp_dom=gardeadom&anr2./(0.5*tcot);
		COT=(gardeadom&anr2.+cmg_comp_dom)/(0.5+1/tcot); * =gardeadom&anr2./0.5;
		cmg_cot_dom=0.5*COT;
		end;
	/* CAS 2:
	- le compl�ment minimum est sup�rieur � 85% du SN (comp_min>=0.85*sal_net);
	- comme le compl�ment ne peut �tre < au compl�ment minimum, on verse le compl�ment minimum;
	- gardeadom&anr2. = sal_net + COT - CMGcot - CMGcomp
		            = sal_net + 0.5*COT - comp_min = (1+0.5*tcot)*sal_net - comp_min
		            <= (1+0.5*tcot)*comp_min/0.85 - comp_min; */
	else if gardeadom&anr2.<=(0.15+0.5*tcot)/0.85*comp_min then do;
		cas_cot=2;
		cmg_comp_dom=comp_min;
		COT=(gardeadom&anr2.+cmg_comp_dom)/(0.5+1/tcot);
		cmg_cot_dom=0.5*COT;
		end;
	/* CAS 3:
	- le compl�ment th�orique est > � 85% du SN et le compl�ment minimum est < � 85% du SN;
	- donc le compl�ment vaut 85% du SN (CMGcomp = 0.85*sal_net < plafond_comp);
	- gardeadom&anr2. = sal_net + COT - CMGcot - CMGcomp
		            = (1+0.5*tcot)*sal_net - CMGcomp = (0.15/0.85+0.5/0.85*tcot)*CMGcomp
	                <= (0.15+0.5*tcot)/0.85*plafond_comp; */
	else if gardeadom&anr2.<=(0.15+0.5*tcot)/0.85*plafond_comp then do;
		cas_cot=3;
		cmg_comp_dom=gardeadom&anr2./(0.15+0.5*tcot)/0.85;
		COT=(gardeadom&anr2.+cmg_comp_dom)/(0.5+1/tcot);
		cmg_cot_dom=0.5*COT;
		end;
	else do; /* la prise en charge du salaire net est plafonn�e (CMGcomp=plafond_comp) */
		cmg_comp_dom=plafond_comp;
		/* CAS 4:
		- la prise en charge des cotis n'est pas plafonn�e (CMGcot=0.5*COT<plafond_cot);
		- gardeadom&anr2. = sal_net + COT - CMGcot - CMGcomp = (1/tcot+0.5)*COT - plafond_comp
		                <= (1/tcot+0.5)*plafond_cot/0.5 - plafond_comp; */
		if gardeadom&anr2.<=(0.5/tcot+1)*plafond_cot-plafond_comp then do;
			cas_cot=4;
			COT=(gardeadom&anr2.+cmg_comp_dom)/(0.5+1/tcot);
			cmg_cot_dom=0.5*COT;
			end;
		else do; /*la prise en charge des cotis est plafonn�e (CMGcot=plafond_cot)*/
			cmg_cot_dom=plafond_cot;
			/* CAS 5:
			- on calcule COT avec toujours a=a_min et autre_7df=0
		 	en v�rifiant que cela correspond � un montant coh�rent (COT<=cotmax);
			- gardeadom&anr2. = sal_net + COT - CMGcot - CMGcomp
					            = (1/tcot+1)*COT - plafond_cot - plafond_comp; */
			COT=(gardeadom&anr2.+plafond_cot+plafond_comp)/(1+1/tcot);
			if COT<=cotmax then do;
				cas_cot=5;
        		end;
			else do;
			/* CAS 6:
			- on met hmax et on joue sur a pour voir si on peut avoir COT=cotmax*(1+a_effectif)/(1+a_min)
			en v�rifiant que cela correspond � un salaire coh�rent (a_effectif<=a_max);
			- gardeadom&anr2. = sal_net + COT - cmg_cot_dom - cmg_comp_dom
				            = (1/tcot+1)*COT - plafond_cot - plafond_comp
				       	    = (1/tcot+1)*cotmax*(1+a_effectif)/(1+a_min) - plafond_cot - plafond_comp; */
				a_effectif=(1+a_min)*(gardeadom&anr2.+plafond_cot+plafond_comp)/(cotmax*(1+1/tcot))-1;
				if a_effectif<=a_max then do;
					cas_cot=6;
					COT=cotmax*(1+a_effectif)/(1+a_min);*correspond � un nouveau cotmax sous hyp a_effectif et h_max;
					end;
				/* CAS 7:
				- dernier recours : on suppose qu'une partie de gardef est autre chose que de la garde;
				- gardeadom = gardef - autre_7df
				            = (1/tcot+1)*cotmax*(1+a_max)/(1+a_min) - plafond_cot - plafond_comp; */
				else do;
					cas_cot=7;
					a_effectif=a_max;
					garde_7df=(1/tcot+1)*cotmax*(1+a_max)/(1+a_min)-plafond_cot-plafond_comp;
					COT=cotmax*(1+a_max)/(1+a_min);* correspond � un nouveau cotmax sous hyp a_max et h_max;
					end;
				end;
			end;
		end;
	cmgxx=sum(0,cmg_comp_dom,cmg_cot_dom);

	FraisGardeSuperbrut&anr2.=0;
	if garde='structur' then FraisGardeSuperbrut&anr2.=gardehdom&anr2._par_enf; 
	if garde='saldom'  then FraisGardeSuperbrut&anr2.=gardeadom&anr2.+cmgxx;
	if garde='creche'  then FraisGardeSuperbrut&anr2.=gardeadom&anr2.;
	run;

data montant2; 
	set montant; 
	/*pour l'emploi d'une assistante maternelle, on a 100% d'exo de contributions et cotisations donc c'est facile.
	simple passage du salaire net augment� de la participation de la CNAF au salaire superbrut */
	if garde='assmat' then do;
		FraisGardeSuperbrut&anr2.=(enf6*gardehdom&anr2._par_enf + min(plafond_comp,5*gardehdom&anr2._par_enf))/(1-&salcot_assmat.)*(1+&patcot_assmat.) ; 
		FraisGardeBrut&anr2.=FraisGardeSuperbrut&anr2./(1+&patcot_assmat.);
		end;
	/*pour une micro-structure, c'est facile aussi;
	montant de la d�claration augment� de la participation de la CNAF */
	exo_cmg_AM	= (garde='assmat')*min(FraisGardeBrut&anr2.,enf6*5*52*5*&smich.);
	exo_plus	= exo_cmg_AM*(FraisGardeBrut&anr2. >= enf6*5*52*5*&smich.); 
	exo_moins	= exo_cmg_AM*(FraisGardeBrut&anr2. < enf6*5*52*5*&smich.); 
	run;

/*pour le montant de d�pense lorsque l'on emploi une assistante maternelle, on cale pour les d�penses 
pour avoir les bons montants de cotisations.
on fait cela en changeant les masses des gens qui sont en dessous du plafond de cotisation suppos�*/
proc means data=montant2(where=(garde='assmat')) sum noprint;
	var FraisGardeBrut&anr2. exo_cmg_AM exo_plus exo_moins;
	weight wpela&anr2.;
	output out=res(drop=_type_ _freq_) sum=masse_dep masse_cot plafplus plafmoins;
	run;

data montant3; 
	set montant2;
	if _n_=1 then set res;
	if garde='assmat' then  do;
		FraisGardeBrut&anr2.=FraisGardeBrut&anr2.*&m_cmgam_base./masse_cot;
		FraisGardeSuperbrut&anr2.=FraisGardeBrut&anr2.*(1+&patcot_assmat.);
		end;
	exo_cmg_AM	= (garde='assmat')*min(FraisGardeBrut&anr2.,enf6*5*52*5*&smich.);
	exo_plus	= exo_cmg_AM*(FraisGardeBrut&anr2. >= enf6*5*52*5*&smich.); 
	exo_moins	= exo_cmg_AM*(FraisGardeBrut&anr2. < enf6*5*52*5*&smich.); 
	run;

/* Pour la r�partition des modes de garde, on peut se documenter avec des �l�ments de la DREES, 
rang�s quelque part dans la doc d'INES.
On y apprend que les gardes touchent 1 enfant sur 3, sinon c'est les parents qui garde l'enfant et 
ce d'autant plus que les enfants sont nombreux. 
On y appprend aussi que les enfants riches sont plus gard� par d'autres que les parents 69%
voir le tableau 1 de l'ER f�vrier 2009. */

proc sort data=montant3; by ident_fam; run;
data modele.basefam;
	merge 	modele.basefam 
			montant3(in=a keep=ident_fam garde FraisGardeSuperbrut&anr2.);
	by ident_fam; 
	if not a then do; 
		garde=''; 
		FraisGardeSuperbrut&anr2.=0;
		end;
	label	garde="mode de garde"
			FraisGardeSuperbrut&anr2.="frais de garde superbruts";
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
