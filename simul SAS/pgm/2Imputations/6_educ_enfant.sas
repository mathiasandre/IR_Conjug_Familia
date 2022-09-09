*************************************************************************************;
/*																					*/
/*								6_educ_enfant										*/
/*																					*/
*************************************************************************************;

/* Imputation d'informations sur les élèves et étudiants				*/
/* En entrée :	base.baseind                 	      					*/
/* 				travail.irf&anr.e&anr.									*/
/* 				base.foyer&anr.											*/
/* En sortie : 	imput.form	                                     		*/

/* Remarques : 
- On ne tient pas compte de l'éventuel décalage entre l'année de la première interrogation
et l'année scolaire, ce qui peut être important si l'on s'intéresse aux coûts de l'éducation
*/

/* I. Récupération des tables pertinentes */
proc sql;
	create table enf_info_manque as
		select a.ident, a.noi, a.quelfic, a.declar1, 
			b.naia, b.naim, b.acteu6, form, fortyp, forter, nivet, titc,
			(&anref.-input(b.naia,4.)) as age 
		from base.baseind(where=(quelfic ne 'FIP')) as a join travail.irf&anr.e&anr. as b
		on a.ident=b.ident and a.noi=b.noi
		where 	(&anref.-input(b.naia,4.)<=15 & form='')
				!(&anref.-input(b.naia,4.)<=25 & b.acteu6='5' & forter='2' & fortyp='')
		order by declar1;
	create table info_fisc as
		select a.*, _7ea, _7ec, _7ef, anaisenf
		from enf_info_manque as a left outer join base.foyer&anr.(keep=_7ea _7ec _7ef anaisenf declar) as b
		on a.declar1=b.declar
		order by ident,noi;
	quit;

/* II. Création variables d'enseignement */
data enf2(keep=ident noi age declar1 e_col e_lyc d_equip d_qualif d_entr e_sup _7ea _7ec _7ef niv form);
	set info_fisc; 

	/* college */
	alea=ranuni(3);
	if age<=18 & form in ('10','11','12','14') then e_col=1;
	else if 13<=age<=14 & form='' then e_col=2;
	else if age=11 & form='' & alea>&tx_retard_6eme. then e_col=3; 
	/* On néglige les taux de double redoublement */
	else if age=12 & form='' then e_col=4; /*AJOUT ICI*/
	

	/* lycée */
	if form in ('16','17','20','22','23','24','25','27','29','30','31','32','34','36','37') then e_lyc=1;
		if form in ('16','17') then e_lyc=2;*dont général;
		if form in ('31','32') then e_lyc=3;*dont technologique;
		if form in ('22','25','27','29','30','34','36','37') then e_lyc=4;*dont professionel;
		if form in ('20','23','24') then e_lyc=5;*dont premier cycle;

	if form in ('22') then d_equip=1;*prime équipement;
	if form in ('22','25','27') then d_qualif=1;*prime qualification;
	if form in ('16','17','30','31','32','34','36','37') & alea>&tx_redoubl_lyc. then d_entr=1;*prime entrée;
	* 12,1% = taux moyen de redoublement au lycée;

	/* supérieur */
	if age<=25 & form in ('40','41','42','43','44','46','51','53','55','63','64') then e_sup=1;
	if age<=25 & form in ('61','62','71','72') then e_sup=2;

	if e_col ne . then niv='col'; 
	if e_lyc ne . then niv='lyc'; 
	if e_sup ne . then niv='sup'; 
	run; 


/* sauvegarde */
proc sort data=enf2; by ident noi; run; 
data imput.form;
	set enf2(in=b keep=ident noi niv form);
	by ident noi;
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
