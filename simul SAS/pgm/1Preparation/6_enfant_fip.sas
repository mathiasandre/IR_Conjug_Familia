/********************************************************************************************/
/*										6_enfant_fip										*/ 
/********************************************************************************************/

/********************************************************************************************/
/* Tables en entrée : 	travail.menage&anr.	                                      		   	*/
/*						travail.irf&anr.e&anr.											  	*/
/*						travail.indivi&anr.												  	*/
/*						travail.mrf&anr.e&anr.											  	*/	
/* Tables en sortie :	travail.irf&anr.e&anr.											  	*/
/*						travail.indfip&anr.												  	*/
/*						travail.indivi&anr.												  	*/
/*						travail.mrf&anr.e&anr.											  	*/
/* OBJECTIF : On fait sortir les bébés FIP de la table indfip pour les faire rentrer dans  	*/
/* la table indivi sous prétexte qu'il ne s'agit pas de personnes appartenant à un autre 	*/
/* ménage tout en étant sur une déclaration (comme beaucoup d'étudiants). Les bébés FIP	  	*/
/* sont généralement des bébés "ratés" par l'EE, parce qu'ils sont nés après la dernière 	*/
/* interrogation du ménage.																  	*/
/********************************************************************************************/

/* On ne traite pas les declar2 puisque les bébés FIP sont très généralement sur la déclaration la plus récente (declar1) */
proc sort data=travail.indFIP&anr.(keep=ident noi declar1 choixech naia rename=(noi=noi_bebe) where=(naia="&anref.")) out=bebe_FIP; by ident noi_bebe; 

proc sort data=travail.irf&anr.e&anr.(keep=ident noi sexe naia cstot noiprm choixech lprm noienf:) out=irf; by ident noi; run;
proc sort data=travail.indivi&anr.(keep=ident noi declar1 where=(declar1 ne '')) out=indivi; by ident noi; run;
data parent; 
	merge 	indivi(in=a) irf;
	by ident noi;
	if a;
	run;
proc sort data=travail.mrf&anr.e&anr.(keep=ident dep rga) out=mrf; by ident; run;
data parent; 
	merge 	parent(in=a) mrf;
	by ident; 
	if a;
	run;

/* On met en relation le bébé avec les adultes du ménage qui ont les années de naissance qui correspondent. */
proc sort data=parent; by declar1;
proc sort data=bebe_FIP; by declar1; run;
/* Dans parent_bebe_FIP, il y a une observation par parent de bébé_FIP */
data parent_bebe_FIP;
	merge 	bebe_FIP(in=a) 
			parent;
	by declar1;
	if a & declar1 ne '' & (naia=substr(declar1,14,4) ! naia=substr(declar1,19,4));
	if sexe='1' then papa='1'; else papa='0';
	if sexe='2' then mama='1'; else mama='0';
	run;

/* On renseigne les variables noip noim CSPp CSPm et lprm pour chaque bébé FIP */
proc sort data=parent_bebe_FIP; by ident noi_bebe; run;
data bebe_FIP2; 
	set parent_bebe_FIP; 
	by ident noi_bebe; 
	length noiper noimer CSPp_bebe CSPm_bebe lprm_bebe $2.;
	retain noiper noimer CSPp_bebe CSPm_bebe lprm_bebe;
	 
	if first.ident or first.noi_bebe then do;
		CSPp_bebe='00';
		CSPm_bebe='00'; 
		lprm_bebe='4'; 
		noiper=''; 
		noimer='';
		end;

	if papa='1' then do; 
		if noiper='' then do;
			noiper=noi;
			CSPp_bebe=cstot;
			end;
		else do; /* Il arrive qu'il s'agisse d'un couple d'hommes */
			noimer=noi; 
			CSPm_bebe=cstot;
			end;
		if lprm='1' ! lprm ='2' then lprm_bebe='3';		
		end; 
	if mama='1' then do; 
		if noimer='' then do;
			noimer=noi;
			CSPm_bebe=cstot;
			end;
		else do; /* Il arrive qu'il s'agisse d'un couple de femmes */ 
			noiper=noi; 
			CSPp_bebe=cstot;
			end;
		if lprm='1' ! lprm ='2'  then lprm_bebe='3';
		end; 
	if last.noi_bebe ! last.ident;
	naia="&anref.";
	/* Tirage aléatoire uniforme du mois de naissance, qu'on pourrait améliorer en tenant compte du fait 
	que les enfants des échantillons sortants sont plutôt nés à la fin de l'année qu'au début */
	alea=ranuni(2);
	if alea<1/12 then naim='01';
	else if alea<2/12 then naim='02';
	else if alea<3/12 then naim='03';
	else if alea<4/12 then naim='04';
	else if alea<5/12 then naim='05';
	else if alea<6/12 then naim='06';
	else if alea<7/12 then naim='08';
	else if alea<8/12 then naim='09';
	else if alea<9/12 then naim='10';
	else if alea<10/12 then naim='10';
	else if alea<11/12 then naim='11';
	else if alea<=12/12 then naim='12'; 
	/* Tirage aléatoire uniforme du sexe */
	alea=ranuni(3);
	if alea<1/2 then sexe='1';else sexe='2';

	drop noi cstot lprm sexe declar1 papa mama alea;
	rename 	noi_bebe=noi
			CSPp_bebe=CSPp
			CSPm_bebe=CSPm
			lprm_bebe=lprm;

/* on réinitialise les variables noienf à 0 car elles ne doivent être renseignées que pour les parents */
	noienf01='';
	noienf02='';
	noienf03='';
	noienf04='';
	noienf05='';
	noienf06='';
	noienf07='';
	noienf08='';
	noienf09='';
	noienf10='';
	noienf11='';
	noienf12='';
	noienf13='';
	noienf14=''; 
	run;

/* On prend la trame de la table travail.irf&anr.e&anr. et on rajoute les lignes de bebe_FIP2 */
data irf_bebe; 
	set travail.irf&anr.e&anr.(obs=0) 
	    bebe_FIP2;
	run;

/* On complète la liste noienf pour chaque parent de bébé FIP */
data parent_bebe_FIP2;
	set parent_bebe_FIP(drop=declar1 papa mama);
	by ident noi;
	retain nb_bebe_fip noi_bebe_prec;
	array noienf noienf01 noienf02 noienf03 noienf04 noienf05 noienf06 noienf07 noienf08 noienf09 noienf10 noienf11 noienf12 noienf13 noienf14;
	if first.ident or first.noi then do; 
		nb_bebe_fip=1;
		noi_bebe_prec='00';
		end;
		else nb_bebe_FIP=nb_bebe_FIP+1;
	i=1; 	
	do while (i<15 & noienf(i) ne ''); i=i+1; end;
	if i<15 and nb_bebe_FIP=1 then do;
		noienf(i)=noi_bebe;
		noi_bebe_prec=noi_bebe;
		end;
	if i<15 and nb_bebe_FIP=2 then do;
		noienf(i+1)=noi_bebe;
		noienf(i)=noi_bebe_prec;
		end;
	drop i noi_bebe: nb_bebe_FIP;
	if last.noi; 
	run;

/* Sauvegarde de travail.irf&anr.e&anr. */
data travail.irf&anr.e&anr.; 
	merge  travail.irf&anr.e&anr. parent_bebe_FIP2 irf_bebe;
	by ident noi;
	run;

/* On supprime ces bébés FIP de la table indfip et on les rajoute à travail.indivi&anr. */
proc sort data=travail.indFIP&anr.; by ident noi; run;
data travail.indFIP&anr. bebe; 
	merge 	travail.indFIP&anr.
			bebe_FIP2(in=a keep=ident noi); 
	by ident noi; 
	if a then do; 
		quelfic ='EE&FIP';
		output bebe;
		end; 
	else output travail.indFIP&anr.;
	run;
data travail.indivi&anr.(drop=naia); set travail.indivi&anr. bebe; run;

/* On corrige la variable nbenfc (nombre d'enfants célibataires à charge) et typmen7 dans la table nivau ménage mrf, une fois les bébés FIP ajoutés */
/* On crée aussi la variable nbenfnc = nombre d'enfants non célibataires dans le ménage */ 
proc sql;
	create table nbenf as
	select ident, sum((lprm='3' and matri in('1',''))*1) as nbenfc, 
				  sum((lprm='3' and matri not in('1',''))*1) as nbenfnc,
				  sum((lprm in ('4','5','6'))*1) as nbpar
	from travail.irf&anr.e&anr.
	group by ident
	order by ident;
	quit;
data travail.mrf&anr.e&anr. ;
	merge	travail.mrf&anr.e&anr. (drop = nbenfc in=a)
			nbenf; 
	by ident; 
	if a;

	/* Correction de la variable typmen7 */
	/* personnes isolées avec un bébé FIP né dans l'année => reclassées en monoparentales */
	if typmen7="1" and nbenfc>0 then typmen7="2" ; 
	/* couples sans enfant avec un bébé FIP né dans l'année => reclassés en couples avec enfants */ 
	else if typmen7="3" and nbenfc>0 then typmen7="4" ; 	
	/* ménages avec un bébé FIP non enfant de la PR ou de son conjoint => reclassés en ménages complexes */ 	
	else if typmen7 in ("1","2","3","4") and nbpar>0 then typmen7="5" ; 

	drop nbpar ;
	label nbenfnc = "Nombre d'enfants non célibataires" 
		  nbenfc =  "Nombre d'enfants celibataires" ;
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
