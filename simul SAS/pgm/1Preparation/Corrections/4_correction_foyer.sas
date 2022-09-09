/***************************/
/*  4_correction_foyer13   */
/***************************/

/* Les corrections ci-dessous font suite au programme 4_Controles_Niveau_Foyer */

/****************************************/
/*	En entrée : travail.foyer&anr.		*/
/*	En sortie : travail.foyer&anr.		*/
/****************************************/

%Macro Correction_Foyer;

	%if &anref.=2007 %then %do;
		/* pour 2007 il s'agit d'un vieux programme, plutôt écrit pour voir si on peut faire tourner faire l'étude panel */

		data travail.foyer07(drop=nof_f);
			set travail.foyer07;

			if substr(anaisenf,1,1)='' & substr(anaisenf,2,1) ne '' then anaisenf=substr(anaisenf,2,39);
			if substr(declar,30,1)='' & substr(declar,31,1) ne '' then declar=substr(declar,1,29)!!substr(declar,31,39);

			nof_f=ident!!noi!!mcdvo!!xyz;

			/*---- corrections incosifdec ------------------------------*/
			 
			if declar= '01-07053001-V1950-9999-00Z  -' then 
			sif= substr(sif,1,33)!!'000000000'!!substr(sif,43,9)!!'Z23062007 '!!substr(sif,63,32);
			if declar= '01-07053001-M1950-1947-00Z Z-' then 
			sif= substr(sif,1,33)!!'000000000'!!substr(sif,43,9)!!'Z23062007Z'!!substr(sif,63,32);

			if nof_f='0700014502VZ' then sif=substr(sif,1,61)!!' '!!substr(sif,63,32);
			if nof_f='0700583502VZ' then sif=substr(sif,1,61)!!' '!!substr(sif,63,32);
			if nof_f='0701249401VZ' then sif=substr(sif,1,61)!!' '!!substr(sif,63,32);
			if nof_f='0701709401VZ' then sif=substr(sif,1,61)!!' '!!substr(sif,63,32);

			if nof_f='0700916007DX' then sif=substr(sif,1,61)!!'M'!!substr(sif,63,32);
			if nof_f='0701636501MY' then sif=substr(sif,1,61)!!'S'!!substr(sif,63,32);
			if nof_f='0703196701MZ' then sif=substr(sif,1,61)!!'D'!!substr(sif,63,32);

			if nof_f='0700506701DY' then sif=substr(sif,1,43)!!'Y30062007'!!substr(sif,53,42);
			if nof_f='0700870902DY' then sif=substr(sif,1,43)!!'Y31102007'!!substr(sif,53,42);
			if nof_f='0701995302DY' then sif=substr(sif,1,43)!!'Y01032007'!!substr(sif,53,42);
			if nof_f='0704384703DY' then sif=substr(sif,1,43)!!'Y30062007'!!substr(sif,53,42);
			if nof_f='0705055601DY' then sif=substr(sif,1,43)!!'Y01052007'!!substr(sif,53,42);

			if nof_f='0700357002CX' then sif=substr(sif,1,34)!!'X27012007'!!substr(sif,44,17)!!'M'!!substr(sif,63,32);
			if nof_f='0705284501CX' then sif=substr(sif,1,34)!!'X17082007'!!substr(sif,44,17)!!'M'!!substr(sif,63,32);
			if nof_f='0700357002CX' then 
			sif = 'SIF C1978 9999 000000000000000    X27012007000000000000000000M  F00G00R00J00N00H00I00P00 00 00';
			if nof_f='0705284501CX' then 
			sif=  'SIF C1980 9999 000000000000000    X17082007000000000000000000M  F00G00R00J00N00H00I00P00 00 00';

			if nof_f='0701200002VZ' then sif=substr(sif,1,52)!!'Z25122007'!!substr(sif,62,33);

			if nof_f='0701950601MZ' then sif=substr(sif,1,52)!!'Z30122007Z'!!substr(sif,63,32);
			if nof_f='0702230802MZ' then sif=substr(sif,1,52)!!'Z29062007Z'!!substr(sif,63,32);
			if nof_f='0703541201MZ' then sif=substr(sif,1,52)!!'Z13112007Z'!!substr(sif,63,32);

			/*---- corrections tropdat ----------------------------------*/

			if nof_f='0700331101M0' then do; sif=substr(sif,1,66)!!'3'!!substr(sif,68,27); nbf=3; end;
			if nof_f='0707276601D0' then do; sif=substr(sif,1,66)!!'2'!!substr(sif,68,27); nbf=2; end;

			/*---- corrections invalf ----------------------------------*/
			if nof_f='0700787601DX' then do;
				anaisenf='F1992F1988G1988';
				nbf=2; nbg=1;
				declar=substr(declar,1,29)!!anaisenf;
			end;
			if nof_f='0705817201M0' then do;
				anaisenf='F1994J1987';
				nbf=1; nbj=1;
				declar=substr(declar,1,29)!!anaisenf;
			end;
			if nof_f='0706821201M0' then do;
				anaisenf='F1991G1991';
				nbf=1; nbg=1;
				declar=substr(declar,1,29)!!anaisenf;
			end;
			if nof_f='0707137702V0' then do;
				anaisenf='F1947G1947';
				nbf=1;nbg=1;
				declar=substr(declar,1,29)!!anaisenf;
			end;

			%macro div_en_veuf(decl);
			if declar = &decl then do; 
				sif= substr(sif,1,4)!!'V'!!substr(sif,6,38)!!'000000000'!!'Z'!!substr(sif,45,8)!!' '!!substr(sif,63,32);
			   declar = substr(&decl,1,12)!!'V'!!substr(&decl,14,10)!!'00Z'!!substr(&decl,27,3);
			end; 
			%mend div_en_veuf;
			%macro div_en_veuf(decl);
			if declar = &decl then do; 
				sif= substr(sif,1,4)!!'V'!!substr(sif,6,38)!!'000000000'!!'Z'!!substr(sif,45,8)!!' '!!substr(sif,63,35);
			   declar = substr(&decl,1,12)!!'V'!!substr(&decl,14,10)!!'00Z'!!substr(&decl,27,3);
			end; 
			%mend div_en_veuf;
			/*---- gens qui se trompent dans une déclaration quand il
			y en a deux (cf. prog nofind) ----------------------------------*/
			%div_en_veuf('01-07012532-D1947-9999-0Y0  -');
			%div_en_veuf('01-07018028-D1927-9999-0Y0  -');
			%div_en_veuf('01-07021714-D1930-9999-0Y0  -');
			%div_en_veuf('01-07023293-D1960-9999-0Y0  -');
			%div_en_veuf('01-07027710-D1917-9999-0Y0  -');
			%div_en_veuf('01-07042237-D1922-9999-0Y0  -');
			%div_en_veuf('01-07066547-D1927-9999-0Y0  -');
			%div_en_veuf('01-07074486-D1928-9999-0Y0  -');
			%div_en_veuf('02-07015465-D1916-9999-0Y0  -');

			/*IV - remplissage des cases fiscales*/
			%standard_foyer;
			run;
		%end;


	%if &anref.=2008 %then %do;

		data travail.foyer08;
			set travail.foyer08; 
			/*il faut changer le sif avant le declar puisqu'on regarde change en quand declar=tant*/
			%suppr_even('01-08023726-M1962-1969-X00  -');
			if declar='01-08023726-M1962-1969-0Y0 S-' then delete;
			%RemplaceDeclar('01-08023726-M1962-1969-X00  -','01-08023726-M1962-1969-000   ')/*retirer l'even dans le sif*/


			/*veufs qui se mettent en divorcé*/
			%RemplaceEvenement('01-08014146-D1937-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('02-08025374-D1931-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('02-08027744-D1933-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('01-08033344-D1933-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('01-08078064-D1929-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('01-08084982-D1946-9999-0Y0  -',V,Y,Z);

			/*marié puis veuf en toute fin d'année, on supprime le veuvage (il est en fin d'année et il n'y 
			a pas de déclaration après)*/
			%RemplaceEvenement('01-08020047-M1931-1942-X0Z Z-',M,X,X,);

			/*erreur un marriage et non un divorce*/
			%RemplaceEvenement('02-08023477-D1978-9999-0Y0  -',D,Y,X,M);

			/*un veuf est en fait divorcé, on le fait à la main parce qu'il n'y a pas de date remplie*/
			if declar='01-08030367-V1949-9999-00Z  -'
			then sif= substr(sif,1,4)!!"D" !!substr(sif,6,29)!!"000000000"!!"Y" !!
			"01012008"!!"000000000"!!" " !!substr(sif,63,35);
			%RemplaceDeclar('01-08030367-V1949-9999-00Z  -','01-08030367-D1949-9999-0Y0  -');

			/*statut ne va pas avec le fit qu'il y ait un seul déclarant*/
			%RemplaceStatutOld('01-08082673-M1960-9999-000  -',C);
			%RemplaceDeclar('01-08082673-M1960-9999-000  -','01-08082673-C1960-9999-000  -');

			/*naia*/
			if declar = '01-08076061-D1999-9999-000  -' then sif= substr(sif,1,5)!!"1957"!!substr(sif,10,88);
			%RemplaceDeclar('01-08076061-D1999-9999-000  -','01-08076061-D1957-9999-000  -');

			/*verif avant/après evenement*/
			if declar ='02-08050520-C1964-9999-X00 M-F1994J1989' 
			then sif=substr(sif,1,61)!!"M" !!substr(sif,63,35);

			/*différence entre declar et sif*/
			%RemplaceEvenement('01-08009997-V1964-9999-00Z  -F1999',V,X,Z, );
			%RemplaceEvenement('02-08057169-D1958-9999-0Y0  -',D,Y,Y, );
			%ajout_date('01-08030311-C1986-9999-X00 M-',C,X,16122008,M);
			%ajout_date('02-08077036-C1981-9999-X00 M-',C,X,08122008,M);

			%RemplaceDeclar('02-08077911-C1983-9999-000  -','02-08077911-C1983-9999-X00 M-');
			%ajout_date('02-08081940-C1978-9999-X00 M-',C,X,25102008,M);
			%ajout_date('01-08083247-C1930-9999-X00 M-',C,X,11092008,M);

			/*un D qui n'a pas lieu d'être*/
			if declar ='01-08004724-M1934-1935-00Z Z-' then sif=substr(sif,1,61)!!"Z" !!substr(sif,63,35);
			if declar ='01-08014536-M1925-1930-00Z Z-' then sif=substr(sif,1,61)!!"Z" !!substr(sif,63,35);
			if declar ='01-08016042-M1934-1938-00Z Z-' then sif=substr(sif,1,61)!!"Z" !!substr(sif,63,35);
			if declar ='01-08019414-M1930-1932-00Z Z-' then sif=substr(sif,1,52)!!"Z29112008Z" !!substr(sif,63,35);
			if declar ='02-08028191-M1930-1931-00Z Z-' then sif=substr(sif,1,52)!!"Z06122008Z" !!substr(sif,63,35);
			if declar ='01-08032782-M1932-1940-00Z Z-' then sif=substr(sif,1,61)!!"Z" !!substr(sif,63,35);

			if declar ='01-08009725-M1919-1921-000  -' then sif=substr(sif,1,61)!!" " !!substr(sif,63,35);
			if declar ='01-08011147-M1925-1930-000  -' then sif=substr(sif,1,61)!!" " !!substr(sif,63,35);
			if declar ='01-08009725-M1919-1921-000  -' then sif=substr(sif,1,61)!!" " !!substr(sif,63,35);
			if declar ='01-08033375-M1922-1934-000  -' then sif=substr(sif,1,61)!!" " !!substr(sif,63,35);
			if declar ='01-08045572-M1947-1947-000  -' then sif=substr(sif,1,61)!!" " !!substr(sif,63,35);
			if declar ='01-08070898-M1934-1934-000  -' then sif=substr(sif,1,61)!!" " !!substr(sif,63,35);

			%RemplaceDeclar('08-08003555-M1955-1955-000  -F1991J1986J1985J1983','08-08003555-M1955-1955-000  -F1991J1986J1985');
			%RemplaceDeclar('01-08046013-D1956-9999-X00 M-','01-08046013-D1956-9999-X00 M-F1990');
			%RemplaceDeclar('01-08072910-M1968-1961-000  -F1990F1991F1993F1995F1997F2000J1986J198',
			'01-08072910-M1968-1961-000  -F1990F1991F1993F1995F1997F2000J1986J1989');
			/* jeune en trop*/
			if declar='02-08068024-C1984-9999-000  -J1984' then anaisenf=''; 
			if declar='01-08068024-D1961-9999-000  -F1994J1984' then anaisenf='F1994'; 
			if declar='02-08070737-M1950-1957-000  -J1986' then anaisenf=''; 
			if declar='03-08070737-C1986-9999-000  -J1986' then anaisenf=''; 
			if declar='01-08073039-M1957-1959-000  -F1994J1985J1989' then anaisenf='F1994J1989'; 
			if declar='03-08073039-C1985-9999-000  -J1989' then anaisenf=''; 
			%RemplaceDeclar('02-08068024-C1984-9999-000  -J1984','02-08068024-C1984-9999-000  -');
			%RemplaceDeclar('01-08068024-D1961-9999-000  -F1994J1984','01-08068024-D1961-9999-000  -F1994');
			%RemplaceDeclar('03-08070737-C1986-9999-000  -J1986','03-08070737-C1986-9999-000  -');
			%RemplaceDeclar('02-08070737-M1950-1957-000  -J1986','02-08070737-M1950-1957-000  -');
			%RemplaceDeclar('01-08073039-M1957-1959-000  -F1994J1985J1989','01-08073039-M1957-1959-000  -F1994J1989');
			%RemplaceDeclar('03-08073039-C1985-9999-000  -J1989','03-08073039-C1985-9999-000  -');

			/*une déclaration en trop dans ce ménage*/
			if declar='02-08061787-D1972-9999-000  -F1993' then delete;

			/*on change un décalage qu'il y a parfois sur anaisenf des enfants*/
			if substr(anaisenf,1,1)='' & substr(anaisenf,2,1) ne '' then anaisenf=substr(anaisenf,2,39);
			if substr(declar,30,1)='' & substr(declar,31,1) ne '' then declar=substr(declar,1,29)!!substr(declar,31,39);

			/*IV - remplissage des cases fiscales*/
			%standard_foyer;

			run;

		%end;

	%if &anref.=2009 %then %do;

		data travail.foyer09;
			set travail.foyer09; 

			/*c) changement de date de naissance du declarant dans le declar*/
			%RemplaceDeclar('01-09014359-M1961-1958-000  -F1991F1992','01-09014359-M1950-1960-000  -F1991F1992');

			/* I - modification des évènements*/
			/*vérif2 : cohérence des statuts et des événements*/

			/*a) modification de la case 62 dans le SIF*/
			if declar='02-09042517-C1983-9999-X00 M-' then sif=substr(sif,1,61)!!"M"!!substr(sif,63,35); 
			if declar='02-09045326-C1981-9999-X00 M-' then sif=substr(sif,1,61)!!"M"!!substr(sif,63,35); 
			if declar='02-09096017-C1958-9999-X00 M-' then sif=substr(sif,1,61)!!"M"!!substr(sif,63,35); 
			if declar='01-09080456-C1968-9999-X00 M-F2001' then sif=substr(sif,1,61)!!"M"!!substr(sif,63,35); 
			if declar='01-09026245-D1961-9999-0Y0  -J1990' then sif=substr(sif,1,61)!!" "!!substr(sif,63,35);
			if declar='01-09017798-V1942-9999-00Z  -' then sif=substr(sif,1,61)!!" "!!substr(sif,63,35); 
			if declar='02-09045785-M1931-1934-000  -' then sif=substr(sif,1,61)!!" "!!substr(sif,63,35); 
			if declar='02-09023220-M1924-1929-000  -' then sif=substr(sif,1,61)!!" "!!substr(sif,63,35); 
			if declar='01-09077373-M1936-1938-000  -' then sif=substr(sif,1,61)!!" "!!substr(sif,63,35); 
			if declar='01-09064465-M1925-1929-000  -' then sif=substr(sif,1,61)!!" "!!substr(sif,63,35); 
			if declar='01-09035254-M1923-1932-000  -' then sif=substr(sif,1,61)!!" "!!substr(sif,63,35); 
			if declar='01-09049141-M1921-1928-000  -' then do; sif=substr(sif,1,61)!!" "!!substr(sif,63,35);
			declar='02'!!substr(declar,3,42); noindiv='0904914102'; end; 
			/* en vrai c'est faux car si on inverse declarant et conjoin, on n'inverse pas les revenus dans indivi!*/
			if declar='02-09086623-C1981-9999-000  -' then sif=substr(sif,1,61)!!" "!!substr(sif,63,35); 
			if declar='01-09035390-M1921-1923-00Z Z-' then sif=substr(sif,1,61)!!"Z"!!substr(sif,63,35); 
			/* suppression de case 62 dans le déclar*/
			if declar='01-09018032-C1963-9999-X00 M-' then
			 sif='SIF C1963 9999 000000000000000    000000000000000000000000000   F00G00R00J01N00H00I00P00 00 00';
			%RemplaceDeclar('01-09018032-C1963-9999-X00 M-', '01-09018032-C1963-9999-000  -');
			if declar='01-09008722-D1926-9999-000  -' then 
			sif='SIF V1926 9999 00000P000000000  P 000000000000000000000000000   F00G00R00J00N00H00I00P00 00 00';

			/*b) Ajout/suppression d'un évènement*/ 

			/* ajout d'une évènement (décès)*/
			%ajout_date('01-09012994-M1922-1929-00Z Z-',M,Z,01102009,Z); 
			%RemplaceDeclar('01-09024462-M1928-1926-000  -','01-09024462-M1928-1926-00Z Z-');
			%ajout_date('01-09024462-M1928-1926-00Z Z-',M,Z,25102009,Z); 
			/* on enlève la mort de quelqu'un pour simplifier la situation du vopa qui vit avec*/
			%RemplaceDeclar('01-09034873-V1970-9999-00Z  -F1991F1995F1996F1997F1999F2008','01-09034873-V1970-9999-000  -F1991F1995F1996F1997F1999F2008');
			if declar='01-09034873-V1970-9999-000  -F1991F1995F1996F1997F1999F2008' then 
			sif='SIF V1970 9999 000000000000000    000000000000000000000000000   F06G00R00J00N00H00I00P00 00 00';


			/*c) Modification du statut mdcco du déclarant*/

			/*mise en veuf les divorcés*/
			%RemplaceEvenement('02-09003178-D1925-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('02-09010699-D1936-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('01-09016027-D1930-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('02-09016475-D1929-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('01-09017156-D1938-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('01-09026171-D1951-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('02-09029486-D1922-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('01-09031323-D1960-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('01-09033626-D1932-9999-0Y0  -',V,Y,Z);
			%RemplaceEvenement('01-09080028-D1956-9999-0Y0  -',V,Y,Z);

			%RemplaceStatutOld('01-09008722-D1926-9999-000  -',V);

			/* ajout du divorce dans la déclaration*/
			%RemplaceDeclar('01-09004056-D1964-9999-0Y0  -F1992','01-09004056-M1964-1964-0Y0 S-F1992');
			if declar ='01-09004056-M1964-1964-0Y0 S-F1992' then sif=substr(sif,1,4)!!'M1964-1964'!!
			substr(sif,15,47)!!"S"!!substr(sif,63,35);

			/*mis en divorcé les gens mariés*/
			%RemplaceStatutOld('01-09067061-M1959-9999-000  -',D);
			%RemplaceStatutOld('01-09068643-M1944-9999-000  -',D);
			%RemplaceStatutOld('01-09077104-M1974-9999-000  -F2001F2006F2009',D);
			%RemplaceStatutOld('01-09093920-M1984-9999-000  -F2007',D);
			%RemplaceStatutOld('01-09095742-M1954-9999-000  -F1991',D);
			%RemplaceStatutOld('02-09068643-M1943-9999-000  -',D);
			%RemplaceStatutOld('01-09057845-M1952-9999-000  -',D);
			%RemplaceStatutOld('01-09054317-M1951-9999-000  -F1991',D);
			/*mis en marié les gens divorcé*/ 
			%RemplaceDeclar('02-09089720-D1978-9999-0Y0  -','02-09089720-D1978-9999-X00 M-');
			%RemplaceEvenement('02-09089720-D1978-9999-X00 M-',D,Y,X,M);
			%RemplaceStatutOld('01-09056557-D1967-1973-000  -',M);

			/*d) changement des numéros de noi des déclar*/ 
			if declar='02-09044289-O1975-1975-0Y0 S-' then declar='01'!!substr(declar,3,length(declar)-3+1); 
			if declar='03-09095230-D1959-9999-000  -F1994J1987' then declar='01'!!substr(declar,3,length(declar)-3+1); 
			if declar='03-09069953-D1962-9999-000  -J1989' then declar='02'!!substr(declar,3,length(declar)-3+1); 
			if declar='03-09085999-M1948-1951-000  -F1991' then declar='01'!!substr(declar,3,length(declar)-3+1); 

			/* II - gestion des pac*/

			/* ajout d'un pac dans le déclar*/ 
			%RemplaceDeclar('01-09095742-M1954-9999-000  -','01-09095742-M1954-9999-000  -F1991');
			%RemplaceDeclar('01-09093920-M1984-9999-000  -','01-09093920-M1984-9999-000  -F2007');
			%RemplaceDeclar('01-09077104-M1974-9999-000  -','01-09077104-M1974-9999-000  -F2001F2006F2009');

			/* suppression d'un pac déjà déclaré ailleurs*/ 
			%RemplaceDeclar('01-09043636-D1966-9999-000  -J1994','01-09043636-D1966-9999-000  -');
			if declar ='01-09043636-D1966-9999-000  -' then do; 
				anaisenf='';
				sif=substr(sif,1,23)!!'0'!!substr(sif,25,8)!!' '!!substr(sif,34,61);
			end; 
			%RemplaceDeclar('01-09083789-D1971-9999-000  -F1990F1995F2006J1990','01-09083789-D1971-9999-000  -F1995F2006J1990');
			if declar='01-09083789-D1971-9999-000  -F1995F2006J1990' then anaisenf='F1995F2006J1990';

			/* ajout d'un pac dans le SIF*/
			if declar='02-09057158-M1957-1958-000  -J1985J1988' then sif=substr(sif,1,74)!!'02'!!substr(sif,77,18);
			if declar='01-09071059-C1963-9999-000  -J1989J1990' then sif=substr(sif,1,74)!!'02'!!substr(sif,77,18);
			/*changement de J en F pour les pac dans le déclar*/
			if declar='01-09079488-C1957-9999-000  -F1999F1986' then do; 
			declar='01-09079488-C1957-9999-000  -F1999J1986'; anaisenf='F1999J1986'; 
			end; 
			%RemplaceDeclar('01-09048526-D1982-9999-0Y0  -F1995','01-09048526-D1982-9999-0Y0  -F2005');

			/*changement de J en F pour les pac dans le SIF*/
			if declar='01-09085383-D1963-9999-000  -F1994' then sif=substr(sif,1,65)!!'01'!!substr(sif,68,7)!!'00'!!substr(sif,77,18); 
			if declar='01-09070879-V1950-9999-000  -F2003' then sif=substr(sif,1,65)!!'01'!!substr(sif,68,7)!!'00'!!substr(sif,77,18); 
			if declar='02-09049439-M1962-1962-000  -J1990J1988' then sif=substr(sif,1,74)!!'02'!!substr(sif,77,1)!!'00'!!substr(sif,80,15); 

			if declar='01-09048526-D1982-9999-0Y0  -F2005' then anaisenf='F2005';

			/* III - Suppression de la déclaration*/

			/* des declarations qui renvoient à des ménages EE avec déjà des revenus imputés*/
			if declar not in('01-09068803-C1985-9999-000  -' '03-09056769-C1989-9999-000  -' '01-09078902-C1986-9999-000  -'
			'03-09057443-C1989-9999-000  -' '03-09058249-O1986-1986-X00  -' '02-09058943-C1984-9999-000  -' '04-09064005-C1989-9999-000  -'
			'02-09066517-C1987-9999-000  -' '02-09073702-C1986-9999-000  -' '03-09073702-C1988-9999-000  -' '01-09079567-C1989-9999-000  -' 
			'02-09080451-C1988-9999-000  -' '01-09089217-C1990-9999-000  -' '01-09090659-C1991-9999-000  -' '02-09094775-C1984-9999-000  -' 
			'01-09095278-C1987-9999-000  -' '03-09058249-C1986-9999-X00 M-');

			/*IV - remplissage des cases fiscales*/
			%standard_foyer;
			run;
		%end;

	%if &anref.=2010 %then %do;

		data travail.foyer10;
			set travail.foyer10; 

			/* I - modification de dates de naissances absurdes */
			/*déclarant */
			if declar='02-10096554-C1892-9999-000  -F2009F2009' then do;
				declar='02-10096554-C1982-9999-000  -F2009F2009';
				sif=substr(sif,1,5)!!'1982'!!substr(sif,11,84);
			end;
			/* modification de dates de naissance de pac incohérente*/
			if declar='03-10102610-M1979-1987-000  -F995F1998F2001F2002F2006' then do;
				declar='03-10102610-M1979-1987-000  -F1995F1998F2001F2002F2006';
				anaisenf='F1995F1998F2001F2002F2006';
			end;
			if declar='06-10080927-V1965-9999-000  -F1995J1191' then do;
				declar='06-10080927-V1965-9999-000  -F1995J1991';
				anaisenf='F1995J1991';
			end;

			/* II - modification des évènements */  

			/* On utilise vérif2 pour repérer les incohérences entre les statuts et les événements */

			/* a) modification de dates absurdes d'événements dans le sif 
			      Dans ce premier cas, il y a un décalage dans le sif */
			if declar='01-10052827-M1926-1931-00Z Z-' then sif=substr(sif,1,51)!!"0Z07122010"!!substr(sif,62,34);
			/*    Dans ce second cas, on a un mois d'événement égal à 20, je le remplace par 02 par analogie avec les 
			      autres déclarations du ménage. */
			if declar='05-10019958-D1967-9999-0Y0  -' then sif=substr(sif,1,46)!!"02"!!substr(sif,49,46); 

			/* b) Modification du statut mdcco du déclarant. */

			/* on met en divorcé les gens mariés qui n'ont pas de conjoints sur leur déclaration */ 
			%RemplaceStatutOld('01-10000253-M1953-9999-000  -',D);
			%RemplaceStatutOld('01-10016857-M1952-9999-000  -',D);
			%RemplaceStatutOld('01-10036783-M1954-9999-000  -',D);
			%RemplaceStatutOld('01-10038500-M1971-9999-000  -F2005',D);
			%RemplaceStatutOld('01-10058298-M1955-9999-000  -F1993',D);
			%RemplaceStatutOld('01-10065399-M1953-9999-000  -',D);
			%RemplaceStatutOld('01-10103571-M1975-9999-000  -F1993F1994F2005',D);

			/* on met en divorcé des gens qui ont déclaré un divorce dans l'année mais qui se déclarent célibataires */
			%RemplaceStatutOld('02-10026315-C1973-9999-0Y0  -F2003',D);
			%RemplaceStatutOld('02-10030187-C1969-9999-0Y0  -F2003',D);
			%RemplaceStatutOld('03-10021413-C1980-9999-0Y0 S-',D);

			/* c) modification d'évenements lorsqu'il y a différence entre declar1 et declar2*/
			%div_en_veuf('02-10049169-D1926-9999-0Y0  -');

			* III - gestion des pac; 
			* voir programme verif 2; 

			/* cas ou plus de PAC dans le declar que dans le sif 
			=> on ajoute une ou plusieurs PAC dans le sif */
			if declar='01-10008608-C1970-9999-000  -F1995F2000F2008F1995' then sif=substr(sif,1,65)!!'03'!!substr(sif,68,27);
			if declar='01-10019471-M1962-1967-000  -F1993F1995F1991F1991J1991J1991' then sif=substr(sif,1,65)!!'04'!!substr(sif,68,27);
			if declar='01-10025137-C1961-9999-000  -J1990J1986' then sif=substr(sif,1,74)!!'02'!!substr(sif,77,18);
			if declar='01-10090714-C1968-9999-000  -F2000F2003' then sif=substr(sif,1,65)!!'02'!!substr(sif,68,27);
			if declar='02-10047235-D1967-9999-000  -J1990J1991' then sif=substr(sif,1,74)!!'02'!!substr(sif,77,18);
			if declar='03-10075484-C1983-9999-000  -J1991' then sif=substr(sif,1,74)!!'01'!!substr(sif,77,18);

			*IV - remplissage des cases fiscales; 
			%standard_foyer;

			run;

		%end;

	%if &anref.=2011 %then %do;
		proc sql;
			/* 1	Modification de dates de naissances absurdes */

			/*déclarant */
			update travail.foyer&anr.
				set declar='02-11033769-C1982-9999-000  -F2009F2009', 
					sif=substr(sif,1,5)!!'1982'!!substr(sif,11,84)
				where declar='02-11033769-C1892-9999-000  -F2009F2009';
			/* conjoint */
			update travail.foyer&anr.
				set declar='01-11093635-M1950-1954-000  -',
					sif=substr(sif,1,10)!!'1954'!!substr(sif,15,75)
				where declar='01-11093635-M1950-1854-000  -';


			/* 2	Modification des évènements */  

			/* a) modification de dates absurdes d'événements dans le sif */  
			update travail.foyer&anr.
				set sif=substr(sif,1,42)!!'0Y15072011'!!substr(sif,53,43)
				where declar='02-11028836-D1937-9999-0Y0  -';

			update travail.foyer&anr.
				set sif=substr(sif,1,34)!!'X'!!substr(sif,35,61)
				where declar='05-11052636-C1985-9999-X00  -F2009';

			update travail.foyer&anr.
				set sif=substr(sif,1,51)!!'0Z14102011'!!substr(sif,62,34)
				where declar='01-11025155-M1948-1962-00Z Z-';

			/* b) Modification du statut mcdvo du déclarant. */

			/* on met en divorcé les gens mariés qui n'ont pas de conjoints sur leur déclaration et qui n'ont pas d'événements dans l'année */
			%RemplaceStatut(D,	'01-11001567-M1954-9999-000  -F2009'
								'01-11002180-M1975-9999-000  -F1993F1994F2005'
								'01-11008781-M1964-9999-000  -'
								'01-11010208-M1953-9999-000  -'
								'03-11058052-M1945-9999-000  -'
								'01-11063244-M1952-9999-000  -'
								'03-11087106-M1972-9999-000  -'
								'01-11094958-M1968-9999-000  -'
								'01-11096792-M1959-9999-000  -');
			/* on met en divorcé des gens qui ont déclaré un divorce dans l'année mais qui se déclarent célibataires */
			%RemplaceStatut(D,	'01-11087258-C1989-9999-0Y0  -'
								'02-11092122-C1979-9999-0Y0  -H2001'
								'01-11092122-C1980-9999-0Y0  -F2005'
								'01-11092459-C1974-9999-0Y0  -'
								'02-11102479-C1974-9999-0Y0  -F2005F2008'
								'01-11110761-C1944-9999-0Y0  -'
								'01-11112182-C1979-9999-0Y0  -'
								'01-11112270-C1989-9999-0Y0  -');
			/* on met en veuf les gens mariés qui n'ont pas de conjoints sur leur déclaration et qui déclare un décés dans l'année*/
			%RemplaceStatut(V,	'01-11025119-M1934-9999-00Z Z-'
								'01-11029731-M1957-9999-00Z Z-'
								'01-11103263-M1924-9999-00Z Z-');
			/* on met en veuf les gens qui se déclarent divorcé et qui déclarent un décés dans l'année*/
			%RemplaceStatut(V,	'01-11053111-D1928-9999-00Z  -');

			/* on met en célibataire les gens mariés qui n'ont pas de conjoints sur leur déclaration et qui déclare un 
			   mariage dans l'année*/
			%RemplaceStatut(C,	'01-11112052-M1961-9999-X00  -');


			/* 3	Modification du SIF car erreur d'écriture */

			/*pb du nbenf qui ne commence pas par F*/
			update travail.foyer&anr.
				set sif=substr(sif,1,65)!!'F01'!!substr(sif,69,26)
				where declar='01-11012977-M1957-1963-000  -F2011';
			update travail.foyer&anr.
				set sif=substr(sif,1,65)!!'F01'!!substr(sif,69,26)
				where declar='02-11009601-C1986-9999-000  -F2011';

			quit;

		/* 4	Standardisation table foyer */
		data travail.foyer&anr.;
			set travail.foyer&anr.;
			%standard_foyer;
			run;

		%end;

	%if &anref.=2012 %then %do;

		data travail.foyer&anr.;
			set travail.foyer&anr.;
			

			/* 1	Modification de dates de naissances absurdes */
			%RemplaceDeclar(ancien=	'02-12064027-C1892-9999-000  -F2009F2009',
							nouveau='02-12064027-C1982-9999-000  -F2009F2009',
							sif=	'SIF C1982 9999 000000000000000    000000000000000000000000000    F02G00R00J00N00H00I00P00 00 00');

			/* Ajout d'un pac dans le déclar pour être cohérent avec le SIF et anaisenf */ 
			%RemplaceDeclar(ancien=	'02-12006907-M1966-1970-000  -F1996J1993',
							nouveau='02-12006907-M1966-1970-000  -F1996J1993J1990');
			%RemplaceDeclar(ancien=	'02-12018516-M1976-1974-000  -F1996F1998F1999F2002F2004F2006G1996G1998',
							nouveau='02-12018516-M1976-1974-000  -F1996F1998F1999F2002F2004F2006G1996G1998G2004');
			/* Correction d'un Pac majeur non handicapé */
			%RemplaceDeclar(ancien=	'01-12030591-M1962-1963-000  -F1996F1992J1992',
							nouveau='01-12030591-M1962-1963-000  -F1996J1992');
			/* Correction d'une interversion entre 01 et 02 pour la declaration */
			%RemplaceDeclar(ancien=	'02-12067990-M1968-1968-000  -F2005F2006',
							nouveau='01-12067990-M1968-1968-000  -F2005F2006');

			/* 2	Modification des évènements */  
			/* a) modification de dates absurdes d'événements dans le sif */  
			if declar='02-12037817-M1966-1962-X00  -F1994F1996F1997' then do;
				sif=substr(sif,1,34)!!'X30122012'!!substr(sif,44,52);
				end;
			if declar='02-12031273-M1942-1951-00Z Z-' then do;
				sif=substr(sif,1,51)!!'0Z07122012'!!substr(sif,62,34);
				end;

			/* b) Modification du statut mcdvo du déclarant. */
			%RemplaceStatutOld('01-12004323-M1954-9999-000  -F1997',D);

			/* 4	Standardisation table foyer */
			%standard_foyer;
			run;
		%end;

	%if &anref.=2013 %then %do;
		data travail.foyer&anr.;
			set travail.foyer&anr.;
			
			/* Incohérence dans la déclaration d'un enfant (adulte handicapé) */
			%RemplaceDeclar(ancien=	'02-13004331-M1946-1944-000  -F1967G1967',
							nouveau='02-13004331-M1946-1944-000  -G1967',
							sif=	'SIF M1946 1944 000000000    000000000000000000000000000    F00G01R00J00N00H00I00P00 00 00');

			/* Incohérence entre Declar et VousConj (ici couple dont l'un est toujours marié, et confusion dans le Declar entre l'ancien et le nouveau conjoint) */
			%RemplaceDeclar(ancien=	'02-13030088-M1960-1956-000  -',
							nouveau='02-13030088-M1960-1959-000  -');

			/* Incohérence dates de naissance des enfants */
			%RemplaceDeclar(ancien=	'01-13003108-C1972-9999-000  -F2001F2005F1994J1994',
							nouveau='01-13003108-C1972-9999-000  -F2001F2005J1994');
			%RemplaceDeclar(ancien=	'01-13007910-V1979-9999-000  -F2013F2005F2003F1996',
							nouveau='01-13007910-V1979-9999-000  -F2013F2005F2003F1996',
							sif=	'SIF V1979 9999 00000000N000000    000000000000000000000000000    F04G00R00J00N00H00I00P00 00 00');
			%RemplaceDeclar(ancien=	'01-13021231-C1985-9999-000  -F2010F2010H2006',
							nouveau='01-13021231-C1985-9999-000  -F2013F2010H2006',
							sif=	'SIF C1985 9999 000000000000000    000000000000000000000000000    F02G00R00J00N00H01I00P00 00 00');

			/* Standardisation table foyer */
			%Standard_foyer;
			run;
		%end;

	%if &anref.=2014 %then %do;
		data travail.foyer&anr.;
			length anaisenf $50. ;
			set travail.foyer&anr.;
			if substr(anaisenf,1,1)='' & substr(anaisenf,2,1) ne '' then anaisenf=substr(anaisenf,2,39);
			
			/* Incohérence dans la déclaration d'un enfant né en 2014. On corrige le declar et anaisenf */
			%RemplaceDeclar(ancien=	'02-14037203-C1980-9999-000  -F2014F2014',
							nouveau='02-14037203-C1980-9999-000  -F2014');
			if declar='02-14037203-C1980-9999-000  -F2014' then do;
				anaisenf='F2014';
				end;
			/* Incohérence dans la déclaration d'un enfant (adulte handicapé) : oubli de la date de naissance pour titulaire de la carte d'invalidité */
			/* On corrige le declar et anaisenf */
			/* TODO : vérification demandée -> Correction différente l'an dernier pour un cas qui semble similaire. */
			%RemplaceDeclar(ancien=	'02-14015766-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1995G1989G1992',
							nouveau='02-14015766-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1995G1989G1992G1995'); 
			if declar='02-14015766-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1995G1989G1992G1995' then do;
				anaisenf='F1996F1995F1989F1992F1995G1996G1995G1989G1992G1995';
				end;
			/* Incohérence dans la déclaration d'enfants mineurs, soit naissance après 1996 (doivent être en F et non en J) */
			/* On corrige le declar et anaisenf */
			%RemplaceDeclar(ancien=	'01-14006624-D1964-9999-000  -F1996F1997J1988J1999',
							nouveau='01-14006624-D1964-9999-000  -F1996F1997F1999J1988',
							sif=	'SIF D1964 9999 000000000000000    000000000000000000000000000    F03G00R00J01N00H00I00P00 00 00');
			if declar='01-14006624-D1964-9999-000  -F1996F1997F1999J1988' then do;
				anaisenf='F1996F1997F1999J1988';
				end;
			%RemplaceDeclar(ancien=	'01-14014934-M1971-1987-000  -F2009F2010F2013J1998',
							nouveau='01-14014934-M1971-1987-000  -F2009F2010F2013F1998',
							sif=	'SIF M1971 1987 000000000000000    000000000000000000000000000    F04G00R00J00N00H00I00P00 00 00');
			if declar='01-14014934-M1971-1987-000  -F2009F2010F2013F1998' then do;
				anaisenf='F2009F2010F2013F1998';
				end;
			%RemplaceDeclar(ancien=	'01-14016283-D1962-9999-000  -J1997',
							nouveau='01-14016283-D1962-9999-000  -F1997',
							sif=	'SIF D1962 9999 00000000000000T  T 000000000000000000000000000    F01G00R00J00N00H00I00P00 00 00');
			if declar='01-14016283-D1962-9999-000  -F1997' then do;
				anaisenf='F1997';
				end;
			%RemplaceDeclar(ancien=	'01-14017917-M1963-1967-000  -J1997',
							nouveau='01-14017917-M1963-1967-000  -F1997',
							sif=	'SIF M1963 1967 000000000000000    000000000000000000000000000    F01G00R00J00N00H00I00P00 00 00');
			if declar='01-14017917-M1963-1967-000  -F1997' then do;
				anaisenf='F1997';
				end;
			%RemplaceDeclar(ancien=	'01-14020873-D1969-9999-000  -J1999',
							nouveau='01-14020873-D1969-9999-000  -F1999',
							sif=	'SIF D1969 9999 00000000000000T  T 000000000000000000000000000    F01G00R00J00N00H00I00P00 00 00');
			if declar='01-14020873-D1969-9999-000  -F1999' then do;
				anaisenf='F1999';
				end;
			/* Incohérence d'enfants de plus de 26 ans rattachés au foyer fiscal des parents. 
				On considère que ce sont des enfants adultes handicapés => F à la place de J. */
			/* TODO : vérification demandée. Si adultes handicapés, ne sont pas censés pouvoir subvenir seuls à leurs besoins. Carte d'invalidité en plus (case G)? */
			%RemplaceDeclar(ancien=	'01-14021206-M1941-1949-000  -J1972',
							nouveau='01-14021206-M1941-1949-000  -F1972',
							sif=	'SIF M1941 1949 000000000000000    000000000000000000000000000    F01G00R00J00N00H00I00P00 00 00');
			if declar='01-14021206-M1941-1949-000  -F1972' then do;
				anaisenf='F1972';
				end;
			%RemplaceDeclar(ancien=	'01-14027382-V1949-9999-000  -J1980',
							nouveau='01-14027382-V1949-9999-000  -F1980',
							sif=	'SIF V1949 9999 000000000000000    000000000000000000000000000    F01G00R00J00N00H00I00P00 00 00');
			if declar='01-14027382-V1949-9999-000  -F1980' then do;
				anaisenf='F1980';
				end;
			%RemplaceDeclar(ancien=	'01-14040244-M1955-1956-000  -J1987J1992',
							nouveau='01-14040244-M1955-1956-000  -F1987J1992',
							sif=	'SIF M1955 1956 000000000000000    000000000000000000000000000    F01G00R00J01N00H00I00P00 00 00');
			if declar='01-14040244-M1955-1956-000  -F1987J1992' then do;
				anaisenf='F1987J1992';
				end;
			%RemplaceDeclar(ancien=	'02-14014036-M1953-1956-000  -J1986',
							nouveau='02-14014036-M1953-1956-000  -F1986',
							sif=	'SIF M1953 1956 000000000000000    000000000000000000000000000    F01G00R00J00N00H00I00P00 00 00');
			if declar='02-14014036-M1953-1956-000  -F1986' then do;
				anaisenf='F1986';
				end;
			/* Date de naissance d'un enfant absurde */ 
			%RemplaceDeclar(ancien=	'01-14032289-C1955-9999-000  -J1992J1194',
							nouveau='01-14032289-C1955-9999-000  -J1992J1994');
			if declar='01-14032289-C1955-9999-000  -J1992J1994' then do;
				anaisenf='J1992J1994';
				end;
			/* Date de naissance d'un enfant en H (résidence alternée) et en I (carte d'invalidité) pas reprécisée avec I */ 
			%RemplaceDeclar(ancien=	'01-14014597-D1976-9999-000  -H2010J1995',
							nouveau='01-14014597-D1976-9999-000  -H2010I2010J1995');
			if declar='01-14014597-D1976-9999-000  -H2010I2010J1995' then do;
				anaisenf='H2010I2010J1995';
				end;
			 /* Incohérence entre noi et declar qui n'a pas été corrigée automatiquement (on reporte ici une correction au niveau indivi)  */
			%RemplaceDeclar(ancien='02-14040578-M1946-1969-000  -',
							nouveau='01-14040578-M1946-1969-000  -');
			/* Incohérence entre naia et declar2 ou declar1 (selon la table) et le SIF */
			%RemplaceDeclar(ancien=	'01-14032973-V1957-9999-00Z  -F1999',
							nouveau='01-14032973-V1956-9999-00Z  -F1999',
							sif=	'SIF V1956 9999 000000000000000    000000000000000000Z17052014    F01G00R00J00N00H00I00P00 00 00');
			/* On ne corrige que le SIF ci-dessous */
			%RemplaceDeclar(ancien=	'01-14032973-M1957-1959-00Z Z-F1999',
							nouveau='01-14032973-M1956-1959-00Z Z-F1999',
							sif=	'SIF M1956 1959 000000000000000    000000000000000000Z17052014Z   F01G00R00J00N00H00I00P00 00 00');
	
			/* Standardisation table foyer */	
			%Standard_foyer;
			run;
		%end;

	%if &anref.=2015 %then %do;
		data travail.foyer&anr.;
			length anaisenf $50. ;
			set travail.foyer&anr.;
			if substr(anaisenf,1,1)='' & substr(anaisenf,2,1) ne '' then anaisenf=substr(anaisenf,2,39);
			
			/* Incohérence dans la déclaration d'un enfant (adulte handicapé) : oubli de la date de naissance pour titulaire de la carte d'invalidité */
			/* On corrige le declar et anaisenf */
			%RemplaceDeclar(ancien=	'02-15034449-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1992G1989G1992',
							nouveau='02-15034449-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1992G1989G1992G1995'); 
			if declar='02-15034449-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1992G1989G1992G1995' then do;
				anaisenf='F1996F1995F1989F1992F1995G1996G1992G1989G1992G1995';
				end; 
			/* Incohérence dans la déclaration d'enfants mineurs, soit naissance après 1997 (doivent être en F et non en J) */
			/* On corrige le declar et anaisenf */
			%RemplaceDeclar(ancien=	'01-15016129-D1968-9999-000  -J1999',
							nouveau='01-15016129-D1968-9999-000  -F1999',
							sif=	'SIF D1968 9999 000000000000000    000000000000000000000000000    F01G00R00J00N00H00I00P0');
			if declar='01-15016129-D1968-9999-000  -F1999' then do;
				anaisenf='F1999';
				end; 	
			/* Incohérence d'enfants de plus de 26 ans rattachés au foyer fiscal des parents. 
				On considère que ce sont des enfants adultes handicapés => F à la place de J. */
			%RemplaceDeclar(ancien=	'01-15039129-D1963-9999-000  -J1988',
							nouveau='01-15039129-D1963-9999-000  -F1988',
							sif=	'SIF D1963 9999 000000000000000    000000000000000000000000000    F01G00R00J00N00H00I00P0');
			if declar='01-15039129-D1963-9999-000  -F1988' then do;
				anaisenf='F1988';
				end; 					
			/* On corrige le declar et anaisenf */
			%RemplaceDeclar(ancien=	'02-15034449-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1992G1989G1992',
							nouveau='02-15034449-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1992G1989G1992G1995'); 
			/* Incohérence dans la déclaration d'enfants mineurs, soit naissance après 1997 (doivent être en F et non en J) */
			/* On corrige le declar et anaisenf */
			%RemplaceDeclar(ancien=	'01-15016129-D1968-9999-000  -J1999',
							nouveau='01-15016129-D1968-9999-000  -F1999');
			/* Incohérence d'enfants de plus de 26 ans rattachés au foyer fiscal des parents. 
			   On considère que ce sont des enfants adultes handicapés => F à la place de J. */
			%RemplaceDeclar(ancien=	'01-15039129-D1963-9999-000  -J1988',
							nouveau='01-15039129-D1963-9999-000  -F1988');
			/* Incohérence entre noi et declar qui n'ont pas été corrigées automatiquement  */
			%RemplaceDeclar(ancien=	'01-15029271-M1946-1945-000  -',
							nouveau='02-15029271-M1946-1945-000  -');
			%RemplaceDeclar(ancien=	'02-15003724-M1951-1948-000  -',
							nouveau='01-15003724-M1951-1948-000  -');
			%RemplaceDeclar(ancien=	'02-15026424-M1938-1936-000  -',
							nouveau='01-15026424-M1938-1936-000  -');
			%RemplaceDeclar(ancien=	'02-15027551-M1938-1935-000  -',
							nouveau='01-15027551-M1938-1935-000  -');
			/* Standardisation table foyer */	
			%Standard_foyer;
			run;
		%end;

		%IF &anref. = 2016 %THEN %DO;
			DATA travail.foyer&anr.;
				SET travail.foyer&anr.;
				
				/*La ligne suivante permet de corriger des incohérence entre declar et anaisenf à cause d'un espace en trop au début de anaisenf
					(table declar_enf dans 4_Controles_Niveau_Foyer.sas ET table decal de 4_Controles_Niveau_Foyer.sas)*/
				IF SUBSTR(anaisenf,1,1)='' & SUBSTR(anaisenf,2,1) ne '' THEN anaisenf = SUBSTR(anaisenf,2,LENGTH(anaisenf)-1);
				
				/* Incohérence dans la déclaration d'un enfant né en 2011. On corrige le declar et anaisenf */
				%RemplaceDeclar(ancien =	'01-16010437-D1978-9999-000  -F2000F2010F2011F2011',
								nouveau =   '01-16010437-D1978-9999-000  -F2000F2010F2011');
				IF declar='01-16010437-D1978-9999-000  -F2000F2010F2011' THEN DO;
					anaisenf='F2000F2010F2011';
					END;

				/* Incohérence : déclaration d'un enfant à charge majeur sans enfant âgé de plus de 26 ans (naissance avant 1990). */
				/* On considère que ce sont des enfants adultes handicapés => F à la place de J. */
				/* RQ : Voir brochure pratique, au début de la 2042 K, pour la signification des lettres*/
				%RemplaceDeclar(ancien =	'01-16000828-M1956-1957-000  -J1979',
							    nouveau =   '01-16000828-M1956-1957-000  -F1979');		
				IF declar='01-16000828-M1956-1957-000  -F1979' THEN DO;
					anaisenf='F1979';
					END;

				/* Incohérence : déclaration d'un enfant à charge majeur sans enfant qui est en fait mineur (naissance après 1998). */
				/* Doivent aussi être en F et non en J*/
				%RemplaceDeclar(ancien =	'02-16028445-O1964-1968-000  -F2011J1995J1999',
							    nouveau =   '02-16028445-O1964-1968-000  -F2011J1995F1999');		
				IF declar='02-16028445-O1964-1968-000  -F2011J1995F1999' THEN DO;
					anaisenf='F2011J1995F1999';
					END;

				/* Incohérence : déclaration d'un enfant à charge majeur sans enfant âgé de plus de 26 ans (naissance avant 1990). */
				/* On considère que ce sont des enfants adultes handicapés => F à la place de J. */
				%RemplaceDeclar(ancien =	'01-16026693-M1946-1954-000  -J1983',
							    nouveau =   '01-16026693-M1946-1954-000  -F1983');		
				IF declar='01-16026693-M1946-1954-000  -F1983' THEN DO;
					anaisenf='F1983';
					END;

				/* Incohérence : déclaration d'un enfant à charge majeur sans enfant âgé de plus de 26 ans (naissance avant 1990). */
				/* On considère que ce sont des enfants adultes handicapés => F à la place de J. */
				%RemplaceDeclar(ancien =	'01-16033178-C1958-9999-000  -J1987',
							    nouveau =   '01-16033178-C1958-9999-000  -F1987');		
				IF declar='01-16033178-C1958-9999-000  -F1987' THEN DO;
					anaisenf='F1987';
					END;

				/* Incohérence : déclaration d'un enfant à charge majeur sans enfant qui est en fait mineur (naissance après 1998). */
				/* Doivent aussi être en F et non en J*/
				%RemplaceDeclar(ancien =	'04-16002116-M1961-1973-000  -F1998F2013J1995J1999',
							    nouveau =   '04-16002116-M1961-1973-000  -F1998F2013J1995F1999');		
				IF declar='04-16002116-M1961-1973-000  -F1998F2013J1995F1999' THEN DO;
					anaisenf='F1998F2013J1995F1999';
					END;

				/* Incohérences entre noi et declar - détectées dans 6_Controles_Niveau_Individu.sas */
				%RemplaceDeclar(ancien=	'02-16042807-M1947-1947-000  -',
								nouveau='01-16042807-M1947-1947-000  -');
				%RemplaceDeclar(ancien=	'02-16045929-M1951-1948-000  -',
								nouveau='01-16045929-M1951-1948-000  -');
				%RemplaceDeclar(ancien=	'02-16049240-M1945-1952-000  -',
								nouveau='01-16049240-M1945-1952-000  -');
				/* Autre incohérence entre noi et declar détectée dans 6_Controles_Niveau_Individu.sas 
				   Source du problème : foyer 16016596, deux frères jumeaux ont le même declar1 ('04-16016596-C1993-9999-000  -'). Pour celui
				   pour lequel le noi est incohérent, on a changé le declar1 (qui devient '03-16016596-C1993-9999-000  -').
				  '04-16016596-C1993-9999-000  -' n'existe pas dans la base foyer, mais '04-16016596-C1993-9999-000  -' apparaît deux fois,
				   donc on change un des deux en '03-16016596-C1993-9999-000  -', en prenant celui qui a MBRVBG > 0 car on voit dans les tables individuelles
				   que le noi = '03' a des revenus, alors que le noi = '04' n'en a pas.*/
				IF declar = "04-16016596-C1993-9999-000  -" AND MBRVBG > 0 THEN DO;
					declar = "03-16016596-C1993-9999-000  -";
					/*Je remets aussi les autres changements que fait habituellement la macro RemplaceDeclar*/
					vousconj=substr(declar,14,9);
					noi=substr(declar,1,2);
					noindiv=ident!!noi;
					END;

				/* Incohérence entre naia et declar1 détectée dans 6_Controles_Niveau_Individu.sas */
				%RemplaceDeclar(ancien=	'01-16037909-O1982-1981-000  -',
								nouveau='01-16037909-O1981-1982-000  -');
				%RemplaceDeclar(ancien=	'02-16034229-M1933-1936-000  -',
								nouveau='02-16034229-M1936-1933-000  -');

				/* Incohérences entre détectées dans 3_controles_coherence_entre_table */
				%RemplaceDeclar(ancien=	'02-16000779-M1972-1976-00Z Z-F2002F2005F2010',
								nouveau='02-16000779-M1970-1976-00Z Z-F2002F2005F2010');

				/* Standardisation table foyer */	
				%Standard_foyer;

				/*Pour les enfants pour qui on a changé la lettre devant l'année de naissance, il faut aussi corriger 
				les variables nbj, nbf, etc. (il faut le faire après la macro standard_foyer)*/
				IF declar='01-16000828-M1956-1957-000  -F1979' THEN DO;
					nbj = 0;
					nbf = 1;
					END;
				IF declar='02-16028445-O1964-1968-000  -F2011J1995F1999' THEN DO;
					nbf = 2;
					nbj = 1;
					END;
				IF declar='01-16026693-M1946-1954-000  -F1983' THEN DO;
					nbj = 0;
					nbf = 1;
					END;
				IF declar='01-16033178-C1958-9999-000  -F1987' THEN DO;
					nbj = 0;
					nbf = 1;
					END;
				IF declar='04-16002116-M1961-1973-000  -F1998F2013J1995F1999' THEN DO;
					nbj = 1;
					nbf = 3;
					END;

			RUN;
		%END;

	%Mend Correction_Foyer;

%Correction_Foyer;



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
