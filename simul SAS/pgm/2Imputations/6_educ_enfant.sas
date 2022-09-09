*************************************************************************************;
/*																					*/
/*								6_educ_enfant										*/
/*																					*/
*************************************************************************************;

/* Imputation d'informations sur les �l�ves et �tudiants				*/
/* En entr�e :	base.baseind                 	      					*/
/* 				travail.irf&anr.e&anr.									*/
/* 				base.foyer&anr.											*/
/* En sortie : 	imput.form	                                     		*/

/* Remarques : 
- On ne tient pas compte de l'�ventuel d�calage entre l'ann�e de la premi�re interrogation
et l'ann�e scolaire, ce qui peut �tre important si l'on s'int�resse aux co�ts de l'�ducation
*/

/* I. R�cup�ration des tables pertinentes */
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

/* II. Cr�ation variables d'enseignement */
data enf2(keep=ident noi age declar1 e_col e_lyc d_equip d_qualif d_entr e_sup _7ea _7ec _7ef niv form);
	set info_fisc; 

	/* college */
	alea=ranuni(3);
	if age<=18 & form in ('10','11','12','14') then e_col=1;
	else if 13<=age<=14 & form='' then e_col=2;
	else if age=11 & form='' & alea>&tx_retard_6eme. then e_col=3; 
	/* On n�glige les taux de double redoublement */
	else if age=12 & form='' then e_col=4; /*AJOUT ICI*/
	

	/* lyc�e */
	if form in ('16','17','20','22','23','24','25','27','29','30','31','32','34','36','37') then e_lyc=1;
		if form in ('16','17') then e_lyc=2;*dont g�n�ral;
		if form in ('31','32') then e_lyc=3;*dont technologique;
		if form in ('22','25','27','29','30','34','36','37') then e_lyc=4;*dont professionel;
		if form in ('20','23','24') then e_lyc=5;*dont premier cycle;

	if form in ('22') then d_equip=1;*prime �quipement;
	if form in ('22','25','27') then d_qualif=1;*prime qualification;
	if form in ('16','17','30','31','32','34','36','37') & alea>&tx_redoubl_lyc. then d_entr=1;*prime entr�e;
	* 12,1% = taux moyen de redoublement au lyc�e;

	/* sup�rieur */
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
