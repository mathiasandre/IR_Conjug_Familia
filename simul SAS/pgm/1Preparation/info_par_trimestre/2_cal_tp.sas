/****************************************************************************/
/*																			*/
/*							2_cal_tp										*/
/*								 											*/
/****************************************************************************/

/****************************************************************************/
/* Construction du calendrier du taux d'activit�							*/
/* En entr�e :  travail.infos_trim (cr��e dans 3_recup_infos_trim)						*/
/*  			travail.cal_indiv											*/
/* En sortie : 	travail.cal_indiv											*/
/****************************************************************************/


%macro cal_tp;
	data cal_tp(keep= ident noi cal_tp&anref. cal_tp1);
		set travail.infos_trim(rename=(ident&anr.=ident) keep=ident&anr. noi datqi: hhc: emp2nbh: emp3nbh: duhab: txtppred: empnbh: etxtppb: tpp: TTRAVP:);
		format cal_tp $80. hor $2. hor1 $2.; 
		cal_tp='00000000000000000000000000000000000000000000000000000000000000000000000000000000';

		/* On it�re sur chaque trimestre d'enqu�te */ 
		%let l=1;
		%do %while(%scan(&liste_trim.,&l.)> );
			%let trim=%scan(&liste_trim.,&l.);
		    %let l=%eval(&l.+1);
			if datqi_&trim. ne '' then do;
				/* on r�cup�re l'ann�e et le mois de chaque interrogation */
				ancoll=		input(substr(datqi_&trim.,1,4),4.);
				moiscoll=	input(substr(datqi_&trim.,5,2),4.);

				/* hhc : nb heures hebd ds emploi principal, emp2nbh dans le second emploi;*/
				if 0<hhc_&trim.<99 then hor=put(min(round(hhc_&trim.+max(0,emp2nbh_&trim.)+max(0,emp3nbh_&trim.),1),99),2.);   
				else do;
					/*duhab : Type d'horaire de travail (temps complet en tranches, temps partiel en tranches);*/
					if duhab_&trim.='6' then hor='35';					 
					else if duhab_&trim.='3' then hor='30';
					else if duhab_&trim.='2' then hor='18';
					else if duhab_&trim.='1' then hor='10';

					/* txtppred : Taux de temps partiel redress� dans l'emploi principal*/
					else if txtppred_&trim.='1' then hor='10';				
					else if txtppred_&trim.='2' then hor='18';
					else if txtppred_&trim.='3' then hor='23';
					else if txtppred_&trim.='4' then hor='28';
					else if txtppred_&trim.='5' then hor='32';

					/*tpp='1' temps complet;*tpp='1' temps partiel;*/
					else if tpp_&trim.='1' ! tppred_&trim.='1' then hor='35';	
					else if tpp_&trim.='2' ! tppred_&trim.='2' then hor='20';
					end;

				/*empnbh : Nombre d'heures effectu�es dans l'emploi principal au cours de la semaine r�f�rence;
				en toute rigueur, il faudrait mettre datdeb ici mais tant pis*/
				if 0<empnbh_&trim.<99 & hor='' then do;
					hor=put(round(empnbh_&trim.,1),2.);
					end;

				if hor ne '' then hor=put(min(35,input(hor,4.)),2.);
				/* etxtppb : Taux de temps partiel un an auparavant*/
				if etxtppb_&trim.='1' 		then hor1='10';			
				else if etxtppb_&trim.='2' 	then hor1='18';
				else if etxtppb_&trim.='3' 	then hor1='23';
				else if etxtppb_&trim.='4' 	then hor1='28';
				else if etxtppb_&trim.='5' 	then hor1='32';

				/* TTRAVP :Nature du temps de travail dans l'emploi un an auparavant*/
				else if TTRAVP_&trim.='2' 	then hor1='20';	/* temps partiel */
				else if TTRAVP_&trim.='1' 	then hor1='35'; /* temps complet */

			
				place=24*(%eval(&anref.+1)-ancoll)+24-moiscoll*2+1;
				place1=24*(%eval(&anref.+1)-ancoll+1)+24-moiscoll*2+1;
				if input(hor,4.)<10 and hor ne '' then hor='0'||substr(hor,2,1);
				if input(hor1,4.)<10 and hor1 ne '' then hor1='0'||substr(hor1,2,1);
		   		%calend(cal_tp,hor,place,2);
				%calend(cal_tp,hor1,place1,2);
				end;
			%end;

		
	/* On compl�te d�sormais les valeurs non renseign�es (00 et '  ') qui ne sont pas en t�te ni en fin de calendrier : 
	on n'a pas d'information dans l'EE pour ces mois-l�.
	On remplit la moiti� de ces mois avec le nombre d'heures de avant et l'autre moiti� avec le nombre d'heures de apres*/
		cal_tp1=cal_tp;
		do i=0 to 38;
		if substr(cal_tp1,2*i+1,2) not in ('00','  ') & substr(cal_tp1,2*i+3,2) in ('00','  ') then do; 
			apres=substr(cal_tp1,2*i+1,2);
			avant=substr(cal_tp1,2*i+3,2);
			dat_ap=i+1;
			do while (avant in ('00','  ') & i<38); 
				i=i+1;
				avant=substr(cal_tp1,2*i+3,2);
				end;	
			do k=0 to round((i-dat_ap)/2,1);
				substr(cal_tp1,2*dat_ap+2*k+1,2)=apres;
				end; 
			do k=round((i-dat_ap)/2,1) to i-dat_ap;
			 	substr(cal_tp1,2*dat_ap+2*k+1,2)=avant;
				end;
			end;
		end;
		drop place: hor: ancoll moiscoll;

		cal_tp&anref.=substr(cal_tp1,25,24);
		run;
	/* sauvegarde */
	data travail.cal_indiv;
		merge	travail.cal_indiv (in=a)
				cal_tp;
		by ident noi;
		if a;
		label cal_tp1 = "calendrier d'horaires hebdomadaires";
		label cal_tp&anref. = "calendrier d'horaires hebdomadaires pour l'ann�e de r�f�rence";
		run;
	%mend cal_tp;
%cal_tp; 


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
