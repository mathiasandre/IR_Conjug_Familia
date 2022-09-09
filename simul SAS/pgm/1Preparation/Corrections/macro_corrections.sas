/*******************************************************/
/* Macro pour supprimer un m�nage de l'ensemble d'Ines */
/*******************************************************/

%macro Suppression(Annee,ListeIdent);
	%if &anref.=&annee. %then %do;
		data travail.foyer&anr.; set travail.foyer&anr.; if ident not in (&ListeIdent.); run; 
		data travail.irf&anr.e&anr; set travail.irf&anr.e&anr; if ident not in (&ListeIdent.); run; 
		data travail.mrf&anr.e&anr; set travail.mrf&anr.e&anr; if ident not in (&ListeIdent.); run; 
		data travail.indivi&anr.; set travail.indivi&anr.; if ident not in (&ListeIdent.); run; 
		data travail.indfip&anr.; set travail.indfip&anr.; if ident not in (&ListeIdent.); run; 
		data travail.menage&anr.; set travail.menage&anr.; if ident not in (&ListeIdent.); run;
		%end;
	%mend;

/********************************************************/
/* Macros pour faire des corrections sur la table foyer */
/********************************************************/

%macro RemplaceDeclar(ancien,nouveau,sif=, var = declar);
	/*	@ancien : ancienne valeur de var 
		@nouveau : valeur � substituer 
		@sif : nouveau sif (facultatif)
		@var : variable � corriger */
	if &var.=&ancien. then do;
		&var.=&nouveau.;
		%if %length(&sif.)>0 %then %do; sif=&sif.; %end;
		if &var. = declar then do; 	
		/*cas de base au niveau foyer mais on veut �viter declar1 et 
		ne pas changer noi si c'est utilis� dans 5_correction_indivi*/
			vousconj=substr(&var.,14,9);
			noi=substr(&var.,1,2);
			noindiv=ident!!noi;
			end;
		end;
	%mend RemplaceDeclar;

%macro RemplaceStatutOld(declar,mcdvo);
	if declar = &declar. then do; 
		declar=substr(&declar.,1,12)!!"&mcdvo"!!substr(&declar.,14,length(&declar.)-14+1);
		sif= substr(sif,1,4)!!"&mcdvo"!!substr(sif,6,90);
		end;
	%mend RemplaceStatutOld;


/* La macro ci-dessus devrait �tre remplac�e par du SQL. Exemple ci-dessous. */
%macro RemplaceStatut(mcdvo,ListeDeclar);
	update travail.foyer&anr.
		set		declar=substr(declar,1,12)!!"&mcdvo"!!substr(declar,14,length(declar)-14+1),
				sif=substr(sif,1,4)!!"&mcdvo"!!substr(sif,6,90)
		where declar in (&ListeDeclar.);
	%mend RemplaceStatut;

%macro div_en_veuf(decl);
	if declar = &decl. then do; 
		sif= substr(sif,1,4)!!'V'!!substr(sif,6,38)!!'000000000'!!'Z'!!substr(sif,45,8)!!' '!!substr(sif,63,35);
	   declar = substr(&decl.,1,12)!!'V'!!substr(&decl.,14,10)!!'00Z'!!substr(&decl.,27,length(&decl.)-27+1);
		end; 
	%mend div_en_veuf;

%macro suppr_even(declar); 
	if declar = &declar. then  
	sif= substr(sif,1,34)!!"000000000"!!"000000000"!!"000000000"!!
	" "!!substr(sif,63,35);
	%mend;

%macro RemplaceEvenement(declar,mcdvo,avant,apres,case62);

	if declar = &declar. then do; 

		if "&avant"="X"  then do; 
			if "&apres"="X" then 
				sif=cat(substr(sif,1,4), "&mcdvo", substr(sif,6,29), "X", substr(sif,36,8),"000000000","000000000","&case62", substr(sif,63,35));
			*les tranches de 9 z�ros correspondent � une lettre en une date sur huit positions; 
			*le cas avant=apr�s peut surprendre, il permet d �liminer un �venement facilement; 
			if "&apres"="Y" then 
				sif=substr(sif,1,4)!!"&mcdvo" !!substr(sif,6,29)!!"000000000"!!"Y" !!	substr(sif,36,8)!!"000000000"!!"&case62" !!substr(sif,63,35);
			if "&apres"="Z"  then 
				sif= substr(sif,1,4)!!"&mcdvo" !!substr(sif,6,29)!!"000000000"!!"000000000"!!"Z" !!substr(sif,36,8)!!"&case62" !!substr(sif,63,35);
			end;

		if "&avant"="Y"  then do; 
			if "&apres"="X"  then
				sif= substr(sif,1,4)!!"&mcdvo" !!substr(sif,6,29)!!"X" !!substr(sif,45,8)!!	"000000000"!!"000000000"!!"&case62" !!substr(sif,63,35);
			if "&apres"="Y"  then
				sif= substr(sif,1,4)!!"&mcdvo" !!substr(sif,6,29)!!"000000000"!!"Y" !!substr(sif,45,8)!!"000000000"!!"&case62" !!substr(sif,63,35);
			if "&apres"="Z"  then
				sif= substr(sif,1,4)!!"&mcdvo" !!substr(sif,6,29)!!"000000000"!!"000000000"!!"Z" !!substr(sif,45,8)!!"&case62" !!substr(sif,63,35);
			end;

		if "&avant"="Z"  then do; 
			if "&apres"="X"  then
				sif= substr(sif,1,4)!!"&mcdvo" !!substr(sif,6,29)!!"X" !!substr(sif,54,8)!!"000000000"!!"000000000"!!"&case62" !!substr(sif,63,35);
			if "&apres"="Y"  then
				sif= substr(sif,1,4)!!"&mcdvo" !!substr(sif,6,29)!!"000000000"!!"Y" !!substr(sif,54,8)!!"000000000"!!"&case62" !!substr(sif,63,35);
			if "&apres"="Z"  then
				sif= substr(sif,1,4)!!"&mcdvo" !!substr(sif,6,29)!!"000000000"!!"000000000"!!"Z" !!substr(sif,54,8)!!"&case62" !!substr(sif,63,35);
			end;

		%if "&apres."="X"  %then %do; %let even=X00;%end;
		%if "&apres."="Y"  %then %do; %let even=0Y0;%end;
		%if "&apres."="Z"  %then %do; %let even=00Z;%end; 

		declar = substr(&declar,1,12)!!"&mcdvo"!!substr(&declar,14,10)!!"&even"!!' '!!"&case62"!!substr(&declar,29,length(&declar)-29+1);
		end;
	%mend RemplaceEvenement;

%macro ajout_date(declar,mcdvo,even,date,case62); 
	if declar = &declar then do; 
		if "&even"="X"  then sif= substr(sif,1,4)!!"&mcdvo" !!substr(sif,6,29)!!"X"!!"&date"!!
	"000000000"!!"000000000"!!"&case62" !!substr(sif,63,35);
		if "&even"="Y"  then sif= substr(sif,1,4)!!"&mcdvo" !!substr(sif,6,29)!!"000000000"!!"Y"!!
	"&date"!!"000000000"!!"&case62" !!substr(sif,63,35);
		if "&even"="Z"  then sif= substr(sif,1,4)!!"&mcdvo" !!substr(sif,6,29)!!"000000000"!!"000000000"!!
	"Z"!!"&date"!!"&case62" !!substr(sif,63,35);
	end; 
	%mend; 


/*****************************/
/* Macros pour tables indivi */
/*****************************/

%macro RemplaceIndivi(ancien,nouveau,sif=);
	/*	@ancien : ancienne valeur de declar 
		@nouveau : valeur � substituer 
		@sif : nouveau sif (facultatif)		*/
	if declar1=&ancien. then do;
		declar1=&nouveau.;
		%if %length(&sif.)>0 %then %do; sif1=&sif.; %end;
		end;
	if declar2=&ancien. then do;
		declar2=&nouveau.;
		%if %length(&sif.)>0 %then %do; sif2=&sif.; %end;
		end;
	%mend RemplaceIndivi;
%macro rempl_d_en_v(decl);
	if declar1=&decl then declar1= substr(&decl,1,12)!!'V'!!substr(&decl,14,10)!!'00Z'!!substr(&decl,27,length(&decl)-27+1);
	if declar2=&decl then declar2= substr(&decl,1,12)!!'V'!!substr(&decl,14,10)!!'00Z'!!substr(&decl,27,length(&decl)-27+1);
	%mend rempl_d_en_v;


%macro change_statut(declar,mcdvo);
	if declar1 = &declar then declar1=substr(&declar,1,12)!!"&mcdvo"!!substr(&declar,14,length(&declar)-14+1);
	if declar2 = &declar then declar2=substr(&declar,1,12)!!"&mcdvo"!!substr(&declar,14,length(&declar)-14+1);
	%mend;

%macro change_even_indiv(declar,even);
	if declar1 = "&declar" then declar1= substr(declar1,1,23)!!"&even"; 
	if declar2 = "&declar" then declar2= substr(declar1,1,23)!!"&even"; 
	%mend;

*probl�me pour certains vopa, on ne voit pas la d�claration de leur parent ;
%macro pac(declar1,declar2); 
	if declar1="&declar1" then do; 
	declar1="&declar2"; declar2="&declar1";persfip='pac';end;
	%mend pac; 


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
