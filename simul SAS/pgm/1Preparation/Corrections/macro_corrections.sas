/*******************************************************/
/* Macro pour supprimer un ménage de l'ensemble d'Ines */
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
		@nouveau : valeur à substituer 
		@sif : nouveau sif (facultatif)
		@var : variable à corriger */
	if &var.=&ancien. then do;
		&var.=&nouveau.;
		%if %length(&sif.)>0 %then %do; sif=&sif.; %end;
		if &var. = declar then do; 	
		/*cas de base au niveau foyer mais on veut éviter declar1 et 
		ne pas changer noi si c'est utilisé dans 5_correction_indivi*/
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


/* La macro ci-dessus devrait être remplacée par du SQL. Exemple ci-dessous. */
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
			*les tranches de 9 zéros correspondent à une lettre en une date sur huit positions; 
			*le cas avant=après peut surprendre, il permet d éliminer un évenement facilement; 
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
		@nouveau : valeur à substituer 
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

*problème pour certains vopa, on ne voit pas la déclaration de leur parent ;
%macro pac(declar1,declar2); 
	if declar1="&declar1" then do; 
	declar1="&declar2"; declar2="&declar1";persfip='pac';end;
	%mend pac; 


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
