/************************************************************************************/
/*  			5_correction_indivi  												*/
/************************************************************************************/

/* mise en coh�rence en fonction des modifications effectu�es dans correction_foyer	*/
/************************************************************************************/
/*	En entr�e : travail.indivi&anr.													*/
/*				travail.indfip&anr. (pas toujours)									*/
/*	En sortie : travail.indivi&anr.													*/
/*				travail.indfip&anr. (pas toujours)	 								*/
/************************************************************************************/


%Macro Correction_Indivi;
	%if &anref.=2007 %then %do;
		/*on importe les modifications qui �taient faites � l'�poque mais elles sont
		moins soign�es que celle qui sont faites � partir de anref 2008*/

		data travail.indivi07; 
			set travail.indivi07; 

			if ident=07057738 & noi = 01 then declar1='02-07057738-O1985-1978-X00  -' ;
			%RemplaceIndivi('01-07000006-M1956-1954-000  - J1988','01-07000006-M1956-1954-000  -J1988');
			%RemplaceIndivi('01-07068212-M1961-1960-000  -F1991','01-07068212-M1961-1960-000  -F1991G1991');
			%RemplaceIndivi('01-07058172-M1937-1938-000  -F1994F1987','01-07058172-M1937-1938-000  -F1994J1987');
			%RemplaceIndivi('02-07071377-V1918-9999-000  -F1947','02-07071377-V1918-9999-000  -F1947G1947');
			%RemplaceIndivi('01-07007876-D1966-9999-X00 M-F1992F1988','01-07007876-D1966-9999-X00 M-F1992F1988G1988');
			%rempl_d_en_v('01-07012532-D1947-9999-0Y0  -');
			%rempl_d_en_v('01-07018028-D1927-9999-0Y0  -');
			%rempl_d_en_v('01-07021714-D1930-9999-0Y0  -');
			%rempl_d_en_v('01-07023293-D1960-9999-0Y0  -');
			%rempl_d_en_v('01-07027710-D1917-9999-0Y0  -');
			%rempl_d_en_v('01-07042237-D1922-9999-0Y0  -');
			%rempl_d_en_v('01-07066547-D1927-9999-0Y0  -');
			%rempl_d_en_v('01-07074486-D1928-9999-0Y0  -');
			%rempl_d_en_v('02-07015465-D1916-9999-0Y0  -');

			if substr(declar1,30,1)='' & substr(declar1,31,1) ne '' then declar1=substr(declar1,1,29)!!substr(declar1,31,39);
			if substr(declar2,30,1)='' & substr(declar2,31,1) ne '' then declar2=substr(declar2,1,29)!!substr(declar2,31,39);

			run;

			data travail.indfip07; 
			set travail.indfip07; 
			%RemplaceIndivi('01-07068212-M1961-1960-000  -F1991','01-07068212-M1961-1960-000  -F1991G1991');
			%RemplaceIndivi('01-07058172-M1937-1938-000  -F1994F1987','01-07058172-M1937-1938-000  -F1994J1987');
			%RemplaceIndivi('02-07071377-V1918-9999-000  -F1947','02-07071377-V1918-9999-000  -F1947G1947');
			%RemplaceIndivi('01-07007876-D1966-9999-X00 M-F1992F1988','01-07007876-D1966-9999-X00 M-F1992F1988G1988');
			%rempl_d_en_v('01-07012532-D1947-9999-0Y0  -');
			%rempl_d_en_v('01-07018028-D1927-9999-0Y0  -');
			%rempl_d_en_v('01-07021714-D1930-9999-0Y0  -');
			%rempl_d_en_v('01-07023293-D1960-9999-0Y0  -');
			%rempl_d_en_v('01-07027710-D1917-9999-0Y0  -');
			%rempl_d_en_v('01-07042237-D1922-9999-0Y0  -');
			%rempl_d_en_v('01-07066547-D1927-9999-0Y0  -');
			%rempl_d_en_v('01-07074486-D1928-9999-0Y0  -');
			%rempl_d_en_v('02-07015465-D1916-9999-0Y0  -');

			if substr(declar1,30,1)='' & substr(declar1,31,1) ne '' then declar1=substr(declar1,1,29)!!substr(declar1,31,39);
			if substr(declar2,30,1)='' & substr(declar2,31,1) ne '' then declar2=substr(declar2,1,29)!!substr(declar2,31,39);
			run;

		%end;

	%if &anref.=2008 %then %do;

		data travail.indivi08;
			set travail.indivi08;
			%RemplaceIndivi('01-08014146-D1937-9999-0Y0  -','01-08014146-V1937-9999-00Z  -');
			%RemplaceIndivi('01-08023726-M1962-1969-0Y0 S-',' ') ; /*supprimer la decl*/
			%RemplaceIndivi('01-08023726-M1962-1969-X00  -','01-08023726-M1962-1969-000   ') ; /*retirer l'even dans le sif*/
			/* divorce pour se pacser -> j'�limine le divorce */
			%RemplaceIndivi('02-08025374-D1931-9999-0Y0  -','02-08025374-V1931-9999-00Z  -');
			%RemplaceIndivi('02-08027744-D1933-9999-0Y0  -','02-08027744-V1933-9999-00Z  -');
			%RemplaceIndivi('01-08033344-D1933-9999-0Y0  -','01-08033344-V1933-9999-00Z  -');
			/* mari� puis veuf en toute fin d'ann�e, on supprime le veuvage (il est en fin d'ann�e et il n'y 
			a pas de d�claration apr�s)*/
			%RemplaceIndivi('01-08020047-M1931-1942-X0Z Z-','01-08020047-M1931-1942-X00  -');
			/* erreur un marriage et non un divorce */
			%RemplaceIndivi('02-08023477-D1978-9999-0Y0  -','02-08023477-D1978-9999-X00 M-');
			/* un veuf est en fait divorc� */
			%RemplaceIndivi('01-08030367-V1949-9999-00Z  -','01-08030367-D1949-9999-0Y0  -');

			%RemplaceIndivi('01-08078064-D1929-9999-0Y0  -','01-08078064-V1929-9999-00Z  -');
			%RemplaceIndivi('01-08084982-D1946-9999-0Y0  -','01-08084982-V1946-9999-00Z  -');

			%RemplaceIndivi('02-08068024-C1984-9999-000  -J1984','02-08068024-C1984-9999-000  -');
			%RemplaceIndivi('03-08070737-C1986-9999-000  -J1986','03-08070737-C1986-9999-000  -');
			%RemplaceIndivi('03-08073039-C1985-9999-000  -J1989','03-08073039-C1985-9999-000  -');

			%RemplaceIndivi('02-08077911-C1983-9999-000  -','02-08077911-C1983-9999-X00 M-');

			/* statut ne va pas avec le fait qu'il n'y ait qu'un seul d�clarant */
			%RemplaceIndivi('01-08082673-M1960-9999-000  -','01-08082673-C1960-9999-000  -');


			/* prob naia */
			%RemplaceIndivi('01-08076061-D1999-9999-000  -','01-08076061-D1957-9999-000  -');


			%RemplaceIndivi('08-08003555-M1955-1955-000  -F1991J1986J1985J1983','08-08003555-M1955-1955-000  -F1991J1986J1985');
			%RemplaceIndivi('01-08046013-D1956-9999-X00 M-','01-08046013-D1956-9999-X00 M-F1990');
			%RemplaceIndivi('01-08072910-M1968-1961-000  -F1990F1991F1993F1995F1997F2000J1986J198',
			'01-08072910-M1968-1961-000  -F1990F1991F1993F1995F1997F2000J1986J1989');

			%RemplaceIndivi('02-08068024-C1984-9999-000  -J1984','02-08068024-C1984-9999-000  -');
			%RemplaceIndivi('01-08068024-D1961-9999-000  -F1994J1984','01-08068024-D1961-9999-000  -F1994');
			%RemplaceIndivi('03-08070737-C1986-9999-000  -J1986','03-08070737-C1986-9999-000  -');
			%RemplaceIndivi('02-08070737-M1950-1957-000  -J1986','02-08070737-M1950-1957-000  -');
			%RemplaceIndivi('01-08073039-M1957-1959-000  -F1994J1985J1989','01-08073039-M1957-1959-000  -F1994J1989');
			%RemplaceIndivi('03-08073039-C1985-9999-000  -J1989','03-08073039-C1985-9999-000  -');

			/* une declaration en trop */
			if declar1='02-08061787-D1972-9999-000  -F1993' then do; 
				persfip='vous';
				declar1='01-08061787-M1971-1972-000  -F1993'; end; 

			if substr(declar1,30,1)='' & substr(declar1,31,1) ne '' then declar1=substr(declar1,1,29)!!substr(declar1,31,39);
			if substr(declar2,30,1)='' & substr(declar2,31,1) ne '' then declar2=substr(declar2,1,29)!!substr(declar2,31,39);


			%pac('04-08081908-C1990-9999-000  -','01-08081908-M1961-1963-000  -F1990');
			%pac('03-08074851-C1990-9999-000  -','01-08074851-M1959-1960-000  -F1990');
			%pac('03-08071318-C1990-9999-000  -','02-08071318-M1956-1963-000  -F1990');

			run;
		data travail.indfip08;
			set travail.indfip08;
			%RemplaceIndivi('01-08014146-D1937-9999-0Y0  -','01-08014146-V1937-9999-00Z  -');
			%RemplaceIndivi('01-08023726-M1962-1969-0Y0 S-',' ') ; /* supprimer la decl */
			%RemplaceIndivi('01-08023726-M1962-1969-X00  -','01-08023726-M1962-1969-000   ') ; /*retirer l'even dans le sif*/
			/* divorce pour se pacser -> j'�limine le divorce */
			%RemplaceIndivi('02-08025374-D1931-9999-0Y0  -','02-08025374-V1931-9999-00Z  -');
			%RemplaceIndivi('02-08027744-D1933-9999-0Y0  -','02-08027744-V1933-9999-00Z  -');
			%RemplaceIndivi('01-08033344-D1933-9999-0Y0  -','01-08033344-V1933-9999-00Z  -');
			/* mari� puis veuf en toute fin d'ann�e, on supprime le veuvage (il est en fin d'ann�e et il n'y 
			a pas de d�claration apr�s) */
			%RemplaceIndivi('01-08020047-M1931-1942-X0Z Z-','01-08020047-M1931-1942-X00  -');
			/* erreur un marriage et non un divorce */
			%RemplaceIndivi('02-08023477-D1978-9999-0Y0  -','02-08023477-D1978-9999-X00 M-');
			/* un veuf est en fait divorc� */
			%RemplaceIndivi('01-08030367-V1949-9999-00Z  -','01-08030367-D1949-9999-0Y0  -');

			%RemplaceIndivi('01-08078064-D1929-9999-0Y0  -','01-08078064-V1929-9999-00Z  -');
			%RemplaceIndivi('01-08084982-D1946-9999-0Y0  -','01-08084982-V1946-9999-00Z  -');

			%RemplaceIndivi('02-08068024-C1984-9999-000  -J1984','02-08068024-C1984-9999-000  -');
			%RemplaceIndivi('03-08070737-C1986-9999-000  -J1986','03-08070737-C1986-9999-000  -');
			%RemplaceIndivi('03-08073039-C1985-9999-000  -J1989','03-08073039-C1985-9999-000  -');

			%RemplaceIndivi('02-08077911-C1983-9999-000  -','02-08077911-C1983-9999-X00 M-');

			/* statut ne va pas avec le fait qu'il n'y ait qu'un seul d�clarant */
			%RemplaceIndivi('01-08082673-M1960-9999-000  -','01-08082673-C1960-9999-000  -');


			/* prob naia */
			%RemplaceIndivi('01-08076061-D1999-9999-000  -','01-08076061-D1957-9999-000  -');


			%RemplaceIndivi('08-08003555-M1955-1955-000  -F1991J1986J1985J1983','08-08003555-M1955-1955-000  -F1991J1986J1985');
			%RemplaceIndivi('01-08046013-D1956-9999-X00 M-','01-08046013-D1956-9999-X00 M-F1990');
			%RemplaceIndivi('01-08072910-M1968-1961-000  -F1990F1991F1993F1995F1997F2000J1986J198',
			'01-08072910-M1968-1961-000  -F1990F1991F1993F1995F1997F2000J1986J1989');

			%RemplaceIndivi('02-08068024-C1984-9999-000  -J1984','02-08068024-C1984-9999-000  -');
			%RemplaceIndivi('01-08068024-D1961-9999-000  -F1994J1984','01-08068024-D1961-9999-000  -F1994');
			%RemplaceIndivi('03-08070737-C1986-9999-000  -J1986','03-08070737-C1986-9999-000  -');
			%RemplaceIndivi('02-08070737-M1950-1957-000  -J1986','02-08070737-M1950-1957-000  -');
			%RemplaceIndivi('01-08073039-M1957-1959-000  -F1994J1985J1989','01-08073039-M1957-1959-000  -F1994J1989');
			%RemplaceIndivi('03-08073039-C1985-9999-000  -J1989','03-08073039-C1985-9999-000  -');

			/* une declaration en trop */
			if declar1='02-08061787-D1972-9999-000  -F1993' then do; 
				persfip='vous';
				declar1='01-08061787-M1971-1972-000  -F1993'; end; 

			if substr(declar1,30,1)='' & substr(declar1,31,1) ne '' then declar1=substr(declar1,1,29)!!substr(declar1,31,39);
			if substr(declar2,30,1)='' & substr(declar2,31,1) ne '' then declar2=substr(declar2,1,29)!!substr(declar2,31,39);

			/* probl�me pour certains vopa, on ne voit pas la d�claration de leur parent */

			%pac('04-08081908-C1990-9999-000  -','01-08081908-M1961-1963-000  -F1990');
			%pac('03-08074851-C1990-9999-000  -','01-08074851-M1959-1960-000  -F1990');
			%pac('03-08071318-C1990-9999-000  -','02-08071318-M1956-1963-000  -F1990');

			run;

		%end;

	%if &anref.=2009 %then %do;

		/*Plan:
		0 - Probl�me de revenu et de persfip; 
			a) probl�me de persfip;
			b) probl�me de revenus; 
			c) changement de date de naissance du declarant dans le declar;  
		I - modification des �v�nements;  
			a) case 62; 
			b) Ajout/suppression d'un �v�nement; 
			c) Modification du statut mdcco du d�clarant;
			d) changement des num�ros de noi des d�clar; 	
		II - gestion des pac;
		III - Suppression des d�clar ou plut�t transformation du quelfic des gens
		*****************************************************************/

		data travail.indivi09; 
			set travail.indivi09; 

			/*****************************************************************/
			/* 0 - Probl�me de revenu et de persfip */ 
			/*****************************************************************/

				/* a) probl�me de persfip */

			/*correction de personnes sans declar mais avec un persfip
			suite de prob_declar dans verif1*/
			if noindiv='0901435904' then do ; persfip = ''; declar1=''; end;
			if noindiv='0903487302' then do ; persfip = 'vopa';  end;
			if noindiv='0901704902' then do ; persfip = ''; persfipd=''; end; 
			/* ERFS a oubli� de leur donner un persfip car leur age est diff�rent dans EEC et dans la d�claration fiscale*/ 
			if noindiv='0908180804' then do ; persfip = 'pac'; end; 
			if noindiv='0908741003' then do ; persfip = 'pac'; end;  

				/* b) probl�me de revenus */

			/* on enl�ve les revenus n�gatifs imput�s lorsque le gars est �tudiant*/
			if noindiv = '0902401301' or  noindiv = '0906115502' then zrici=0; /* � verifier... */
			/* on garde les revenus des morts*/
			if ident='09049141' and noi='02' then do; 
				zrsti=zrsto; persfip='vous'; 
				declar1='02'!!substr(declar1,3,28-3)!!' '!!substr(declar1,29,length(declar1)-29+1);
			end;

				/* c) changement de date de naissance du declarant dans le declar */

			%RemplaceIndivi('01-09014359-M1961-1958-000  -F1991F1992','01-09014359-M1950-1960-000  -F1991F1992');
			/* Certains n'ont pas forc�ment la m�me ann�e de naissance dans l'enqu�te emploi et dans les
			fichiers fiscaux : l'information de l'enqu�te pr�vaut*/
			/*En principe, il faudrait faire pareil pour le declar2 mais ca parait compliqu�*/

			/*****************************************************************/
			/* I - modification des �v�nements 								 */  
			/*****************************************************************/

				/* a) case 62 */

			%RemplaceIndivi('01-09004056-D1964-9999-0Y0  -F1992','01-09004056-M1964-1964-0Y0 S-F1992');
			%RemplaceIndivi('01-09018032-C1963-9999-X00 M-', '01-09018032-C1963-9999-000  -');

				/* b) Ajout/suppression d'un �v�nement */

			/*ajout d'un �v�nement (d�c�s)*/
			%RemplaceIndivi('01-09012994-M1922-1929-000  -','01-09012994-M1922-1929-00Z Z-');
			%RemplaceIndivi('01-09024462-M1928-1926-000  -','01-09024462-M1928-1926-00Z Z-'); 
			/* on enl�ve la mort de quelqu'un pour simplifier la situation du vopa qui vit avec*/
			%RemplaceIndivi('01-09034873-V1970-9999-00Z  -F1991F1995F1996F1997F1999F2008','01-09034873-V1970-9999-000  -F1991F1995F1996F1997F1999F2008');

				/*c) Modification du statut mdcco du d�clarant*/

			/*mise en veuf les divorc�s*/
			/* mise en coh�rence des declars suite � prob_even*/
			/* les gens mari�s qui d�clare �tre divorc� au lieu d'�tre veuf lorsque leur conjoint d�c�de*/
			%rempl_d_en_v('02-09003178-D1925-9999-0Y0  -');
			%rempl_d_en_v('02-09010699-D1936-9999-0Y0  -');
			%rempl_d_en_v('01-09016027-D1930-9999-0Y0  -');
			%rempl_d_en_v('02-09016475-D1929-9999-0Y0  -');
			%rempl_d_en_v('01-09017156-D1938-9999-0Y0  -');
			%rempl_d_en_v('01-09026171-D1951-9999-0Y0  -');
			%rempl_d_en_v('02-09029486-D1922-9999-0Y0  -');
			%rempl_d_en_v('01-09031323-D1960-9999-0Y0  -');
			%rempl_d_en_v('01-09033626-D1932-9999-0Y0  -');
			%rempl_d_en_v('01-09080028-D1956-9999-0Y0  -');
			%change_statut('01-09008722-D1926-9999-000  -',V);

			/* mis en divorc� les mari�s*/
			%change_statut('01-09057845-M1952-9999-000  -',D);
			%change_statut('01-09067061-M1959-9999-000  -',D);
			%change_statut('01-09068643-M1944-9999-000  -',D);
			%change_statut('01-09077104-M1974-9999-000  -F2001F2006F2009',D);
			%change_statut('01-09093920-M1984-9999-000  -F2007',D);
			%change_statut('02-09068643-M1943-9999-000  -',D);
			%change_statut('01-09054317-M1951-9999-000  -F1991',D);
			%change_statut('01-09095742-M1954-9999-000  -F1991',D);

			/*mis en mari� les gens divorc�s*/
			%RemplaceIndivi('02-09089720-D1978-9999-0Y0  -','02-09089720-D1978-9999-X00 M-');
			if declar2='01-09089720-O1978-1978-X00 M-' then declar2= '02'!!substr(declar2,3,10)!!'D'!!substr(declar2,14,5)!!'9999'!!substr(declar2,23,7);
			%change_statut('01-09056557-D1967-1973-000  -',M);

				/*d) changement des num�ros de noi des d�clar*/	   
			%RemplaceIndivi('02-09044289-O1975-1975-0Y0 S-', '01-09044289-O1975-1975-0Y0 S-');


			/*****************************************************************/
			/* II - gestion des pac											 */ 
			/*****************************************************************/

			/* ajout d'un pac dans le d�clar*/
			if declar1='01-09095230-D1959-9999-000  -F1994' then declar1=substr(declar1,1,34)!!'J1987';
			/* suppression d'un pac d�j� d�clar� ailleurs*/
			%RemplaceIndivi('01-09083789-D1971-9999-000  -F1990F1995F2006J1990','01-09083789-D1971-9999-000  -F1995F2006J1990');
			%RemplaceIndivi('01-09043636-D1966-9999-000  -J1994','01-09043636-D1966-9999-000  -');
			if ident='09043636' and noi='05' then declar1='02-09043636-D1960-9999-000  -J1994';
			/*changement de J en F pour les pac dans le d�clar*/
			%RemplaceIndivi('01-09048526-D1982-9999-0Y0  -F1995', '01-09048526-D1982-9999-0Y0  -F2005');
			%RemplaceIndivi('01-09079488-C1957-9999-000  -F1999F1986','01-09079488-C1957-9999-000  -F1999J1986');

			/*****************************************************************/
			/* III - Suppression des d�clar ou plus t�t transformation du quelfic des gens */
			/*****************************************************************/

			/* on met en EE les gens qui dont on a oubli� de nous donner les d�clarations fiscales*/
			if noindiv in ('0907087902' '0909018801' '0907990501' '0907323801' '0907323803' '0907323805' 
			'0906615604' '0906615601' '0905566601' '0905566603' '0905566604' '0909277901' '0909277904' '0908599903') then do; 
			persfip=''; persfipd=''; declar1=''; quelfic='EE'; 
			end; 

			/* un jeune qui est sur la declaration de sa mere*/
			if declar1='03-09069953-D1962-9999-000  -J1989' then do; 
			declar1='02'!!substr(declar1,3,length(declar1)-3+1); 
			persfip='pac'; 
			persfipd=''; 
			end; 

			if declar1='03-09095230-D1959-9999-000  -F1994J1987' then do;
			declar1='01'!!substr(declar1,3,length(declar1)-3+1); 
			persfip='pac'; 
			persfipd=''; 
			end; 

			if declar1='03-09085999-M1948-1951-000  -F1991' then do;
				declar1='01'!!substr(declar1,3,length(declar1)-3+1); 
				if noi='03' then do; 
					persfip='pac'; 
					persfipd=''; 
				end; 
			end; 
						
			run; 

			data travail.indfip09; 
			set travail.indfip09; 

			if noindiv='0900937891' or noindiv='0904134991' then persfipd = 'mad';
			if noindiv='0907033481' then persfipd = 'pac';
			if noindiv='0907152081' then persfip = 'pac'; 
			if noindiv='0907506081' then persfipd = 'conj';
			/*cas d'un FIP ou la personne d�clare des revenus d'un conjoint mais �tre divorc�. On marie les gens avec le FIP*/
			/* sinon il faudrait supprimer le FIP*/ 
			%RemplaceIndivi('01-09004056-D1964-9999-0Y0  -F1992','01-09004056-M1964-1964-0Y0 S-F1992');
			/* cas d'un FIP dans un couple ou la personne d�clare �tre divorc�*/
			%RemplaceIndivi('01-09056557-D1967-1973-000  -', '01-09056557-M1967-1973-000  -');

			%RemplaceIndivi('01-09079488-C1957-9999-000  -F1999F1986','01-09079488-C1957-9999-000  -F1999J1986');
			%change_statut('01-09077104-M1974-9999-000  -F2001F2006F2009',D);
			%RemplaceIndivi('01-09083789-D1971-9999-000  -F1990F1995F2006J1990','01-09083789-D1971-9999-000  -F1995F2006J1990');
			%change_statut('01-09093920-M1984-9999-000  -F2007',D);
			%change_statut('01-09095742-M1954-9999-000  -F1991',D);
			if declar1='03-09095230-D1959-9999-000  -F1994J1987' then declar1='01'!!substr(declar1,3,length(declar1)-3+1); 
			if declar1='03-09069953-D1962-9999-000  -J1989' then declar1='02'!!substr(declar1,3,length(declar1)-3+1); 
			if declar1='01-09049141-M1921-1928-000 Z-' and noi='01' then do; 
				declar1='02'!!substr(declar1,3,28-3)!!' '!!substr(declar1,29,length(declar1)-29+1); 
				persfip='conj'; 
			end; 

			/*les FIP dont on ne retrouve pas la d�claration fiscale sont supprim�s*/
			if noi='82' and ident='09066156' then delete; 
			if noi='82' and ident='09085999' then delete; 

			run;

		%end;


	%if &anref.=2010 %then %do;

		data travail.indivi10; 
			set travail.indivi10; 


			/* a) changement de date de naissance du declarant dans le declar */ 
			%RemplaceIndivi('02-10096554-C1892-9999-000  -F2009F2009','02-10096554-C1982-9999-000  -F2009F2009');
			%RemplaceIndivi('03-10102610-M1979-1987-000  -F1995F1998F2001F2002F2006','03-10102610-M1979-1987-000  -F995F1998F2001F2002F2006');
			%RemplaceIndivi('06-10080927-V1965-9999-000  -F1995J1191','06-10080927-V1965-9999-000  -F1995J1991');


			/* b) Modification du statut mdcco du d�clarant */ 

			/* mise en veuf les divorc�s */
			/* mise en coh�rence des declars suite � prob_even */ 
			/* les gens mari�s qui d�clare �tre divorc� au lieu d'�tre veuf lorsque leur conjoint d�c�de */
			%rempl_d_en_v('02-10049169-D1926-9999-0Y0  -');

			/* mis en divorc� les mari�s */ 
			%change_statut('01-10000253-M1953-9999-000  -',D);
			%change_statut('01-10016857-M1952-9999-000  -',D);
			%change_statut('01-10036783-M1954-9999-000  -',D);
			%change_statut('01-10038500-M1971-9999-000  -F2005',D);
			%change_statut('01-10058298-M1955-9999-000  -F1993',D);
			%change_statut('01-10065399-M1953-9999-000  -',D);
			%change_statut('01-10103571-M1975-9999-000  -F1993F1994F2005',D);

			/* mis en divorce de gens c�libataires */
			%change_statut('02-10026315-C1973-9999-0Y0  -F2003',D);
			%change_statut('02-10030187-C1969-9999-0Y0  -F2003',D);
			%change_statut('03-10021413-C1980-9999-0Y0 S-',D);

			/* on remplace un divorc� en veuf */
			%rempl_d_en_v('02-10049169-D1926-9999-0Y0  -');
			run; 
		%end;

	%if &anref.=2011 %then %do;

		/* mise en coh�rence en fonction des modifications effectu�es dans correction_foyer11*/

		data travail.indivi11; 
			set travail.indivi11; 

			/* a) changement de date de naissance du declarant dans le declar */ 
			%RemplaceIndivi('02-11033769-C1892-9999-000  -F2009F2009','02-11033769-C1982-9999-000  -F2009F2009');
			%RemplaceIndivi('01-11093635-M1950-1854-000  -','01-11093635-M1950-1954-000  -');

			/* b) Modification du statut mdcco du d�clarant */ 

			/* les gens mari�s qui d�clare �tre divorc� au lieu d'�tre veuf lorsque leur conjoint d�c�de */
			%rempl_d_en_v('02-10049169-D1926-9999-0Y0  -');

			/* mis en divorc� les mari�s */ 
			%change_statut('01-11001567-M1954-9999-000  -F2009',D);
			%change_statut('01-11002180-M1975-9999-000  -F1993F1994F2005',D);
			%change_statut('01-11008781-M1964-9999-000  -',D);
			%change_statut('01-11010208-M1953-9999-000  -',D);
			%change_statut('03-11058052-M1945-9999-000  -',D);
			%change_statut('01-11063244-M1952-9999-000  -',D);
			%change_statut('03-11087106-M1972-9999-000  -',D);
			%change_statut('01-11094958-M1968-9999-000  -',D);
			%change_statut('01-11096792-M1959-9999-000  -',D);


			/* mis en divorce de gens c�libataires */
			%change_statut('01-11087258-C1989-9999-0Y0  -',D);
			%change_statut('02-11092122-C1979-9999-0Y0  -H2001',D);
			%change_statut('01-11092122-C1980-9999-0Y0  -F2005',D);
			%change_statut('01-11092459-C1974-9999-0Y0  -',D);
			%change_statut('02-11102479-C1974-9999-0Y0  -F2005F2008',D);
			%change_statut('01-11110761-C1944-9999-0Y0  -',D);
			%change_statut('01-11112182-C1979-9999-0Y0  -',D);
			%change_statut('01-11112270-C1989-9999-0Y0  -',D);

			/* mis en c�libataire des gens mari�s sans conjoint */
			%change_statut('01-11112052-M1961-9999-X00  -',C);

			/*on met en veuf les gens mari�s qui n'ont pas de conjoints sur leur d�claration et qui d�clare un d�c�s dans l'ann�e*/
			%change_statut('01-11025119-M1934-9999-00Z Z-',V);
			%change_statut('01-11029731-M1957-9999-00Z Z-',V);
			%change_statut('01-11103263-M1924-9999-00Z Z-',V);

			/* On corrige quelques declar */
			%RemplaceIndivi(ancien='01-11000343-M1939-1937-000  -',
							nouveau='01-11000343-M1939-1937-00Z Z-',
							sif='SIF M1939 1937 000000000000000    000000000000000000000000000D   F00G00R00J00N00H00I00P00 00 00');
			%RemplaceIndivi(ancien='01-11013121-M1922-1919-000  -',
							nouveau='01-11013121-M1922-1919-00Z Z-',
							sif='SIF M1922 1919 000000000000000    000000000000000000000000000D   F00G00R00J00N00H00I00P00 00 00');
			%RemplaceIndivi(ancien='01-11031949-M1936-1940-000  -',
							nouveau='01-11031949-M1936-1940-00Z Z-',
							sif='SIF M1936 1940 000000000000000    000000000000000000000000000D   F00G00R00J00N00H00I00P00 00 00');	
			%RemplaceIndivi(ancien='01-11042716-M1950-1953-000  -',
							nouveau='01-11042716-M1950-1953-00Z Z-',
							sif='SIF M1950 1953 000000000000000    000000000000000000000000000    F00G00R00J00N00H00I00P00 00 00');
			%RemplaceIndivi(ancien='02-11035060-M1944-1945-000  -',
							nouveau='02-11035060-M1944-1945-00Z Z-',
							sif='SIF M1944 1945 0F0000000000000  F 000000000000000000000000000D   F00G00R00J00N00H00I00P00 00 00');
			%RemplaceIndivi(ancien='01-11045002-M1926-1944-000  -',
							nouveau='01-11045002-M1926-1944-00Z Z-',
							sif='SIF M1926 1944 000000000000000    000000000000000000000000000D   F00G00R00J00N00H00I00P00 00 00');

			%RemplaceIndivi(ancien='02-11053111-M1923-1928-000  -',
							nouveau='02-11053111-M1928-1928-00Z Z-',
							sif='SIF M1928 1928 000000W00  W 000000000000000000Z07082011Z   F00G00R00J00N00H00I00P00 00');
			%RemplaceIndivi(ancien='01-11053111-D1928-9999-0Y0  -',
							nouveau='01-11053111-V1928-9999-00Z  -',
							sif='SIF V1928 9999 000000W00  W 000000000000000000Z07082011    F00G00R00J00N00H00I00P00 00');
			run; 

		%end;

	%if &anref.=2012 %then %do;

		data travail.indivi&anr.; 
			set travail.indivi&anr.; 

			/*a) changement de date de naissance du declarant dans le declar */ 
			%RemplaceIndivi(ancien='02-12064027-C1892-9999-000  -F2009F2009',
							nouveau='02-12064027-C1982-9999-000  -F2009F2009',
							sif='SIF C1982 9999 000000000000000    000000000000000000000000000    F02G00R00J00N00H00I00P00 00 00');


			/* b) Modification du statut mdcco du d�clarant */ 

			/* mis en divorc� les mari�s */ 
			%change_statut('01-12004323-M1954-9999-000  -F1997',D);

			/* On corrige quelques declar/sif */
			%RemplaceIndivi(ancien='02-12037817-M1966-1962-X00  -F1994F1996F1997',
							nouveau='02-12037817-M1966-1962-X00  -F1994F1996F1997',
							sif='SIF M1966 1962 000000000000000    X30122011000000000000000000    F03G00R00J00N00H00I00P00 00 00');
			%RemplaceIndivi(ancien=	'02-12006907-M1966-1970-000  -F1996J1993',
							nouveau='02-12006907-M1966-1970-000  -F1996J1993J1990');
			%RemplaceIndivi(ancien=	'02-12018516-M1976-1974-000  -F1996F1998F1999F2002F2004F2006G1996G1998',
							nouveau='02-12018516-M1976-1974-000  -F1996F1998F1999F2002F2004F2006G1996G1998G2004');
			%RemplaceIndivi(ancien=	'01-12030591-M1962-1963-000  -F1996F1992J1992',
							nouveau='01-12030591-M1962-1963-000  -F1996J1992');
			%RemplaceIndivi(ancien=	'02-12067990-M1968-1968-000  -F2005F2006',
							nouveau='01-12067990-M1968-1968-000  -F2005F2006');
			run; 
		data travail.indfip&anr.;
			set travail.indfip&anr.;
			%RemplaceIndivi(ancien=	'02-12006907-M1966-1970-000  -F1996J1993',
							nouveau='02-12006907-M1966-1970-000  -F1996J1993J1990');
			run;
		%end;


	%if &anref.=2013 %then %do;
		data travail.indivi&anr.; 
		   	length declar1 $79.;
			set travail.indivi&anr.; 

			/* Trop d'enfants => Le Declar est tronqu� par erreur */
			%RemplaceIndivi(ancien=	'01-13043148-M1949-1964-000  -F2006F2002F2000F1999F1997F1996J1994J1993J1',
							nouveau='01-13043148-M1949-1964-000  -F2006F2002F2000F1999F1997F1996J1994J1993J1992');
			
			/* Incoh�rence dans la d�claration d'un enfant (adulte handicap�) */
			%RemplaceIndivi(ancien=	'02-13004331-M1946-1944-000  -F1967G1967',
							nouveau='02-13004331-M1946-1944-000  -G1967');

			/* Incoh�rence entre Declar et VousConj (ici couple dont l'un est toujours mari�, et confusion dans le Declar entre l'ancien et le nouveau conjoint) */
			%RemplaceIndivi(ancien=	'02-13030088-M1960-1956-000  -',
							nouveau='02-13030088-M1960-1959-000  -');

			/* Incoh�rence dates de naissance des enfants */
			%RemplaceIndivi(ancien=	'01-13003108-C1972-9999-000  -F2001F2005F1994J1994',
							nouveau='01-13003108-C1972-9999-000  -F2001F2005J1994');
			%RemplaceIndivi(ancien=	'01-13007910-V1979-9999-000  -F2013F2005F2003F1996',
							nouveau='01-13007910-V1979-9999-000  -F2013F2005F2003F1996');
			%RemplaceIndivi(ancien=	'01-13021231-C1985-9999-000  -F2010F2010H2006',
							nouveau='01-13021231-C1985-9999-000  -F2013F2010H2006');

			/* Correction d'une naia */
			if ident="13048432" and noi="02" then naia="1949";
			run;

		%end;

	%if &anref.=2014 %then %do;
		data travail.indivi&anr.; 
		length declar1 $100. declar2 $100. ; /* on s'aligne sur le format de la table foyer */ 
		 	set travail.indivi&anr.; 
			/* Incoh�rence dans la d�claration d'un enfant n� en 2014 */
			%RemplaceIndivi(ancien=	'02-14037203-C1980-9999-000  -F2014F2014',
							nouveau='02-14037203-C1980-9999-000  -F2014');
			/* Declar tronqu� car nombre d'enfants � charge trop important (9). Cette correction est propre � la table indivi */
			%RemplaceIndivi(ancien=	'01-14015284-M1949-1964-000  -F2006F2002F2000F1999F1997F1996J1994J1993J1',
							nouveau='01-14015284-M1949-1964-000  -F2006F2002F2000F1999F1997F1996J1994J1993J1992');
			/* Incoh�rence dans la d�claration d'un enfant (adulte handicap�) : oubli de la date de naissance pour titulaire de la carte d'invalidit� */
			/* Declar est �galement tronqu� car plus long que le format initial. */
			/* TODO : v�rification demand�e -> Correction diff�rente l'an dernier pour un cas qui semble similaire. */
			%RemplaceIndivi(ancien=	'02-14015766-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1995G1989G1',
							nouveau='02-14015766-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1995G1989G1992G1995'); 
			/* Incoh�rence dans la d�claration d'enfants mineurs, soit naissance apr�s 1996 (doivent �tre en F et non en J) */
			%RemplaceIndivi(ancien=	'01-14006624-D1964-9999-000  -F1996F1997J1988J1999',
							nouveau='01-14006624-D1964-9999-000  -F1996F1997F1999J1988');
			%RemplaceIndivi(ancien=	'01-14014934-M1971-1987-000  -F2009F2010F2013J1998',
							nouveau='01-14014934-M1971-1987-000  -F2009F2010F2013F1998');
			%RemplaceIndivi(ancien=	'01-14016283-D1962-9999-000  -J1997',
							nouveau='01-14016283-D1962-9999-000  -F1997');	
			%RemplaceIndivi(ancien=	'01-14017917-M1963-1967-000  -J1997',
							nouveau='01-14017917-M1963-1967-000  -F1997');
			%RemplaceIndivi(ancien=	'01-14020873-D1969-9999-000  -J1999',
							nouveau='01-14020873-D1969-9999-000  -F1999');
			/* Incoh�rence d'enfants de plus de 26 ans rattach�s au foyer fiscal des parents. 
				On consid�re que ce sont des enfants adultes handicap�s => F � la place de J. */
			/* TODO : v�rification demand�e. Si adultes handicap�s, ne sont pas cens�s pouvoir subvenir seuls � leurs besoins. Carte d'invalidit� en plus (case G)? */
			%RemplaceIndivi(ancien=	'01-14021206-M1941-1949-000  -J1972',
							nouveau='01-14021206-M1941-1949-000  -F1972');
			%RemplaceIndivi(ancien=	'01-14027382-V1949-9999-000  -J1980',
							nouveau='01-14027382-V1949-9999-000  -F1980');
			%RemplaceIndivi(ancien=	'01-14040244-M1955-1956-000  -J1987J1992',
							nouveau='01-14040244-M1955-1956-000  -F1987J1992');
			%RemplaceIndivi(ancien=	'02-14014036-M1953-1956-000  -J1986',
							nouveau='02-14014036-M1953-1956-000  -F1986');
			/* Date de naissance d'un enfant absurde */ 
			%RemplaceIndivi(ancien=	'01-14032289-C1955-9999-000  -J1992J1194',
							nouveau='01-14032289-C1955-9999-000  -J1992J1994');
			/* Date de naissance d'un enfant en H (r�sidence altern�e) et en I (carte d'invalidit�) pas repr�cis�e avec I */ 
			%RemplaceIndivi(ancien=	'01-14014597-D1976-9999-000  -H2010J1995',
							nouveau='01-14014597-D1976-9999-000  -H2010I2010J1995');
			/* Incoh�rence entre noi et declar qui n'a pas �t� corrig�e automatiquement  */
			%RemplaceIndivi(ancien=	'02-14040578-M1946-1969-000  -',
							nouveau='01-14040578-M1946-1969-000  -');
			/* Incoh�rence entre naia et declar (rep�r� dans programme incoh�rence table) */
			/* Incoh�rence entre naia et declar2 ou declar1 (selon la table) */
			%RemplaceIndivi(ancien=	'01-14032973-V1957-9999-00Z  -F1999',
							nouveau='01-14032973-V1956-9999-00Z  -F1999');
			%RemplaceIndivi(ancien=	'01-14032973-M1957-1959-00Z Z-F1999',
							nouveau='01-14032973-M1956-1959-00Z Z-F1999');
			/* Declar1 et 2 visiblement invers�s pour 1 observation : declar1 est la situation la plus r�cente, soit celle o� la personne est veuve */ 
			if ident ='14032973' & noi='01' then declar1='01-14032973-V1956-9999-00Z  -F1999' ;
			if ident ='14032973' & noi='01' then declar2='01-14032973-M1956-1959-00Z Z-F1999' ;
			run;
		
		data travail.indfip&anr.; 
			length declar1 $100. declar2 $100. ; /* on s'aligne sur le format de la table foyer */ 
			set travail.indfip&anr.; 
			/* Incoh�rence dans la d�claration d'un enfant n� en 2014. On r�percute la correction de declar faite dans foyer et indivi */
			%RemplaceIndivi(ancien=	'02-14037203-C1980-9999-000  -F2014F2014',
							nouveau='02-14037203-C1980-9999-000  -F2014');
			/* Incoh�rence dans la d�claration d'un enfant (adulte handicap�) : oubli de la date de naissance pour titulaire de la carte d'invalidit� */
			/* Declar est �galement tronqu� car plus long que le format initial. */
			%RemplaceIndivi(ancien=	'02-14015766-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1995G1989G1',
							nouveau='02-14015766-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1995G1989G1992G1995'); 
			/* Incoh�rence dans la d�claration d'enfants mineurs, soit naissance apr�s 1996 (doivent �tre en F et non en J) */
			/* On r�percute la correction de declar faite dans foyer et indivi */
			%RemplaceIndivi(ancien=	'01-14006624-D1964-9999-000  -F1996F1997J1988J1999',
							nouveau='01-14006624-D1964-9999-000  -F1996F1997F1999J1988');
			%RemplaceIndivi(ancien=	'01-14014934-M1971-1987-000  -F2009F2010F2013J1998',
							nouveau='01-14014934-M1971-1987-000  -F2009F2010F2013F1998');
			%RemplaceIndivi(ancien=	'01-14020873-D1969-9999-000  -J1999',
							nouveau='01-14020873-D1969-9999-000  -F1999');
			/* Incoh�rence d'enfants de plus de 26 ans rattach�s au foyer fiscal des parents. */
			/* On r�percute la correction de declar faite dans foyer et indivi */
			%RemplaceIndivi(ancien=	'01-14021206-M1941-1949-000  -J1972',
							nouveau='01-14021206-M1941-1949-000  -F1972');
			%RemplaceIndivi(ancien=	'01-14040244-M1955-1956-000  -J1987J1992',
							nouveau='01-14040244-M1955-1956-000  -F1987J1992');
			/* Date de naissance d'un enfant absurde */ 
			%RemplaceIndivi(ancien=	'01-14032289-C1955-9999-000  -J1992J1194',
							nouveau='01-14032289-C1955-9999-000  -J1992J1994');
			/* Incoh�rence entre naia et declar1 */
			%RemplaceIndivi(ancien=	'01-14032973-M1957-1959-00Z Z-F1999',
							nouveau='01-14032973-M1956-1959-00Z Z-F1999');
			/* Correction d'une naia */
			if ident='14032289' & noi='81' then naia='1994';
			/* Correction de persfip */
			if ident='14024683' & noi='81' then persfip="pac" ;
			if ident='14024683' & noi='82' then persfip="pac" ;
			run;

	%end;


	%if &anref.=2015 %then %do;

		data travail.indivi&anr.; 
		length declar1 $100. declar2 $100. ; /* on s'aligne sur le format de la table foyer */ 
		 	set travail.indivi&anr.; 
			/* On corrige le declar et anaisenf */
			%RemplaceIndivi(ancien=	'02-15034449-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1992G1989G1992',
							nouveau='02-15034449-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1992G1989G1992G1995'); 
			/* Incoh�rence dans la d�claration d'enfants mineurs, soit naissance apr�s 1997 (doivent �tre en F et non en J) */
			/* On corrige le declar et anaisenf */
			%RemplaceIndivi(ancien=	'01-15016129-D1968-9999-000  -J1999',
							nouveau='01-15016129-D1968-9999-000  -F1999');
			/* Incoh�rence d'enfants de plus de 26 ans rattach�s au foyer fiscal des parents. 
			   On consid�re que ce sont des enfants adultes handicap�s => F � la place de J. */
			%RemplaceIndivi(ancien=	'01-15039129-D1963-9999-000  -J1988',
							nouveau='01-15039129-D1963-9999-000  -F1988');
			/* Incoh�rence entre noi et declar qui n'ont pas �t� corrig�es automatiquement  */
			%RemplaceIndivi(ancien=	'01-15029271-M1946-1945-000  -',
							nouveau='02-15029271-M1946-1945-000  -');
			%RemplaceIndivi(ancien=	'02-15003724-M1951-1948-000  -',
							nouveau='01-15003724-M1951-1948-000  -');
			%RemplaceIndivi(ancien=	'02-15026424-M1938-1936-000  -',
							nouveau='01-15026424-M1938-1936-000  -');
			%RemplaceIndivi(ancien=	'02-15027551-M1938-1935-000  -',
							nouveau='01-15027551-M1938-1935-000  -');
			/* On corrige un declar tronqu� */
			%RemplaceIndivi(ancien=	'02-15034449-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1992G1989G1',
							nouveau='02-15034449-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1992G1989G1992G1995'); 
		 run;	
		
		data travail.indfip&anr.; 
			length declar1 $100. declar2 $100. ; /* on s'aligne sur le format de la table foyer */ 
			set travail.indfip&anr.; 
			/* Incoh�rence dans la d�claration d'un enfant (adulte handicap�) : oubli de la date de naissance pour titulaire de la carte d'invalidit� */
			/* On corrige le declar et anaisenf */
			%RemplaceIndivi(ancien=	'02-15034449-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1992G1989G1992',
							nouveau='02-15034449-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1992G1989G1992G1995'); 
			/* Incoh�rence dans la d�claration d'enfants mineurs, soit naissance apr�s 1997 (doivent �tre en F et non en J) */
			/* On corrige le declar et anaisenf */
			%RemplaceIndivi(ancien=	'01-15016129-D1968-9999-000  -J1999',
							nouveau='01-15016129-D1968-9999-000  -F1999');
			/* Incoh�rence d'enfants de plus de 26 ans rattach�s au foyer fiscal des parents. 
			   On consid�re que ce sont des enfants adultes handicap�s => F � la place de J. */
			%RemplaceIndivi(ancien=	'01-15039129-D1963-9999-000  -J1988',
							nouveau='01-15039129-D1963-9999-000  -F1988');
			/* On corrige un declar tronqu� */
			%RemplaceIndivi(ancien=	'02-15034449-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1992G1989G1',
							nouveau='02-15034449-D1962-9999-000  -F1996F1995F1989F1992F1995G1996G1992G1989G1992G1995'); 
		run;

	%end;

	%IF &anref. = 2016 %THEN %DO;

		DATA travail.indivi&anr.; 
		LENGTH declar1 $100. declar2 $100.; /* on s'aligne sur le format de la table foyer */ 
		 	SET travail.indivi&anr.; 
			/* Incoh�rence dans la d�claration d'un enfant n� en 2011. On corrige le declar et anaisenf */
			%RemplaceIndivi(ancien =	'01-16010437-D1978-9999-000  -F2000F2010F2011F2011',
							nouveau =   '01-16010437-D1978-9999-000  -F2000F2010F2011');

			/* Incoh�rence : d�claration d'un enfant � charge majeur sans enfant �g� de plus de 26 ans (naissance avant 1990). */
			/* On consid�re que ce sont des enfants adultes handicap�s => F � la place de J. */
			/* RQ : Voir brochure pratique, au d�but de la 2042 K, pour la signification des lettres*/
			%RemplaceIndivi(ancien =	'01-16000828-M1956-1957-000  -J1979',
						    nouveau =   '01-16000828-M1956-1957-000  -F1979');		

			/* Incoh�rence : d�claration d'un enfant � charge majeur sans enfant qui est en fait mineur (naissance apr�s 1998). */
			/* Doivent aussi �tre en F et non en J*/
			%RemplaceIndivi(ancien =	'02-16028445-O1964-1968-000  -F2011J1995J1999',
						    nouveau =   '02-16028445-O1964-1968-000  -F2011J1995F1999');		

			/* Incoh�rence : d�claration d'un enfant � charge majeur sans enfant �g� de plus de 26 ans (naissance avant 1990). */
			/* On consid�re que ce sont des enfants adultes handicap�s => F � la place de J. */
			%RemplaceIndivi(ancien =	'01-16026693-M1946-1954-000  -J1983',
						    nouveau =   '01-16026693-M1946-1954-000  -F1983');		

			/* Incoh�rence : d�claration d'un enfant � charge majeur sans enfant �g� de plus de 26 ans (naissance avant 1990). */
			/* On consid�re que ce sont des enfants adultes handicap�s => F � la place de J. */
			%RemplaceIndivi(ancien =	'01-16033178-C1958-9999-000  -J1987',
						    nouveau =   '01-16033178-C1958-9999-000  -F1987');		

			/* Incoh�rence : d�claration d'un enfant � charge majeur sans enfant qui est en fait mineur (naissance apr�s 1998). */
			/* Doivent aussi �tre en F et non en J*/
			%RemplaceIndivi(ancien =	'04-16002116-M1961-1973-000  -F1998F2013J1995J1999',
						    nouveau =   '04-16002116-M1961-1973-000  -F1998F2013J1995F1999');	


			/* Incoh�rences entre noi et declar - d�tect�es dans 6_Controles_Niveau_Individu.sas */
			%RemplaceIndivi(ancien=	'02-16042807-M1947-1947-000  -',
							nouveau='01-16042807-M1947-1947-000  -');
			%RemplaceIndivi(ancien=	'02-16045929-M1951-1948-000  -',
							nouveau='01-16045929-M1951-1948-000  -');
			%RemplaceIndivi(ancien=	'02-16049240-M1945-1952-000  -',
							nouveau='01-16049240-M1945-1952-000  -');

			/* Autre incoh�rence entre noi et declar d�tect�e dans 6_Controles_Niveau_Individu.sas 
			   Source du probl�me : foyer 16016596, deux fr�res jumeaux ont le m�me declar1. Pour celui
			   pour lequel le noi est incoh�rent, on change le declar*/
			IF declar1 = '04-16016596-C1993-9999-000  -' AND noi = '03' THEN declar1 = '03-16016596-C1993-9999-000  -';
			/*Remarque : le declar '03-16016596-C1993-9999-000  -' n'existe pas initialement dans la base foyer, 
			mais il y a deux occurrences de '04-16016596-C1993-9999-000  -', donc on remplace l'une des deux par
			'03-16016596-C1993-9999-000  -' (voir programme correction_foyer)*/
	
			/* Incoh�rence entre naia et declar1 d�tect�e dans 6_Controles_Niveau_Individu.sas */
			%RemplaceIndivi(ancien=	'01-16037909-O1982-1981-000  -',
							nouveau='01-16037909-O1981-1982-000  -');
			%RemplaceIndivi(ancien=	'02-16034229-M1933-1936-000  -',
							nouveau='02-16034229-M1936-1933-000  -');

			/*Incoh�rences entre d�tect�es dans 3_controles_coherence_entre_table*/
			%RemplaceIndivi(ancien=	'01-16022731-C1978-9999-000  -F2005F2012',
							nouveau='01-16022731-C1978-9999-000  -F2005F2012G2005');
			%RemplaceIndivi(ancien=	'02-16000779-M1972-1976-00Z Z-F2002F2005F2010',
							nouveau='02-16000779-M1970-1976-00Z Z-F2002F2005F2010');

			RUN;	
		
		DATA travail.indfip&anr.; 
			LENGTH declar1 $100. declar2 $100.; /* on s'aligne sur le format de la table foyer */ 
			SET travail.indfip&anr.; 
			/* Incoh�rence dans la d�claration d'un enfant n� en 2011. On corrige le declar et anaisenf */
			%RemplaceIndivi(ancien =	'01-16010437-D1978-9999-000  -F2000F2010F2011F2011',
							nouveau =   '01-16010437-D1978-9999-000  -F2000F2010F2011');

			/* Incoh�rence : d�claration d'un enfant � charge majeur sans enfant �g� de plus de 26 ans (naissance avant 1990). */
			/* On consid�re que ce sont des enfants adultes handicap�s => F � la place de J. */
			/* RQ : Voir brochure pratique, au d�but de la 2042 K, pour la signification des lettres*/
			%RemplaceIndivi(ancien =	'01-16000828-M1956-1957-000  -J1979',
						    nouveau =   '01-16000828-M1956-1957-000  -F1979');		

			/* Incoh�rence : d�claration d'un enfant � charge majeur sans enfant qui est en fait mineur (naissance apr�s 1998). */
			/* Doivent aussi �tre en F et non en J*/
			%RemplaceIndivi(ancien =	'02-16028445-O1964-1968-000  -F2011J1995J1999',
						    nouveau =   '02-16028445-O1964-1968-000  -F2011J1995F1999');		

			/* Incoh�rence : d�claration d'un enfant � charge majeur sans enfant �g� de plus de 26 ans (naissance avant 1990). */
			/* On consid�re que ce sont des enfants adultes handicap�s => F � la place de J. */
			%RemplaceIndivi(ancien =	'01-16026693-M1946-1954-000  -J1983',
						    nouveau =   '01-16026693-M1946-1954-000  -F1983');		

			/* Incoh�rence : d�claration d'un enfant � charge majeur sans enfant �g� de plus de 26 ans (naissance avant 1990). */
			/* On consid�re que ce sont des enfants adultes handicap�s => F � la place de J. */
			%RemplaceIndivi(ancien =	'01-16033178-C1958-9999-000  -J1987',
						    nouveau =   '01-16033178-C1958-9999-000  -F1987');		

			/* Incoh�rence : d�claration d'un enfant � charge majeur sans enfant qui est en fait mineur (naissance apr�s 1998). */
			/* Doivent aussi �tre en F et non en J*/
			%RemplaceIndivi(ancien =	'04-16002116-M1961-1973-000  -F1998F2013J1995J1999',
						    nouveau =   '04-16002116-M1961-1973-000  -F1998F2013J1995F1999');		

			/* Incoh�rences entre noi et declar - d�tect�es dans 6_Controles_Niveau_Individu.sas */
			%RemplaceIndivi(ancien=	'02-16042807-M1947-1947-000  -',
							nouveau='01-16042807-M1947-1947-000  -');
			%RemplaceIndivi(ancien=	'02-16045929-M1951-1948-000  -',
							nouveau='01-16045929-M1951-1948-000  -');
			%RemplaceIndivi(ancien=	'02-16049240-M1945-1952-000  -',
							nouveau='01-16049240-M1945-1952-000  -');

			/* Autre incoh�rence entre noi et declar d�tect�e dans 6_Controles_Niveau_Individu.sas 
			   Source du probl�me : foyer 16016596, deux fr�res jumeaux ont le m�me declar1. Pour celui
			   pour lequel le noi est incoh�rent, on change le declar*/
			IF declar1 = '04-16016596-C1993-9999-000  -' AND noi = '03' THEN declar1 = '03-16016596-C1993-9999-000  -';
			/*Remarque : le declar '03-16016596-C1993-9999-000  -' n'existe pas initialement dans la base foyer, 
			mais il y a deux occurrences de '04-16016596-C1993-9999-000  -', donc on remplace l'une des deux par
			'03-16016596-C1993-9999-000  -' (voir programme correction_foyer)*/

			/* Incoh�rence entre naia et declar1 d�tect�e dans 6_Controles_Niveau_Individu.sas */
			%RemplaceIndivi(ancien=	'01-16037909-O1982-1981-000  -',
							nouveau='01-16037909-O1981-1982-000  -');
			%RemplaceIndivi(ancien=	'02-16034229-M1933-1936-000  -',
							nouveau='02-16034229-M1936-1933-000  -');

			RUN;

	%end;


	%Mend Correction_Indivi;

%Correction_Indivi;

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
