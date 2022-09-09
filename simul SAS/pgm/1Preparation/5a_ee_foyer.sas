/********************************************************************************************/
/*             				   			5a_ee_foyer      						            */
/********************************************************************************************/

/********************************************************************************************/
/* Tables en entr�e :																	  	*/
/*  travail.indivi&anr.																	  	*/
/*  travail.irf&anr.e&anr.																	*/
/*  travail.foyer&anr.																		*/
/*  																						*/
/* Tables en sortie :																		*/
/*  travail.foyer&anr.																		*/
/*  travail.indivi&anr.																		*/
/*																							*/
/* Objectif: Ce programme cr�e les foyers fiscaux des individus EE et des EE_CAF.			*/
/* Les foyers fiscaux qu'on leur reconstituait dans ce programme, qui de fait etaient tous 	*/
/*	des foyers d'une personne en 99 (cf verifs dans le programme), etaient des foyers 		*/
/*	fictifs, car si on ne les a pas	retrouv�s, c'est dans la plupart des cas que :			*/	
/*  - ils sont rattaches au foyer fiscal de leurs parents.									*/
/*  - ou ils n'ont pas fait de declaration.													*/
/*																							*/
/* Donc l'impot qu'on leur calculait n'avait pas lieu d'etre (d'autant que les FIP 			*/
/*	correspondants sont bien pris en compte pour l'impot du foyer parental).				*/
/* 	Et de meme le revenu fiscal de reference representatif pour eux dans la r�alite serait 	*/
/*	le revenu du foyer parental pour les exos et degrevements de CSG et de TH, et 			*/
/*	l'elig PPE (le cas des bourses college ne se pose pas car ils n'ont pas d'enfant a 		*/
/*	charge comme le dit la suite. Quant aux bourses du sup�rieur, Ines les donne aux 		*/
/*	parents), et non le RFR du "foyer fictif" ainsi reconstitu�. En l'absence 				*/
/*	d'informations sur ce RFR des parents, on va considerer qu'ils ne sont pas exoneres		*/
/*	partiellement ou totalement de CSG, et ineligibles � la PPE (et de m�me les exclure 	*/
/*	des degrevements de TH) d'ou les 'modifs supplementaires' qui suivent.					*/
/********************************************************************************************/

/* On s�lectionne les individus dont on n'a pas la d�claration fiscale */
data indEE(drop=frais);
	set travail.indivi&anr.(keep=ident noi choixech quelfic &RevIndividuels. wp:);
	where quelfic in ('EE','EE_CAF');
	run;

/* On regarde les revenus qui ont �t� imput�s aux EE par la production ERFS */
/*
proc means data=indEE(where=(quelfic='EE')) mean sum;
	var zsali zchoi zrsti zpii zalri zrtoi zragi zrici zrnci;
	run;
*/

proc sort data=indEE; by ident noi; run; 
proc sort data=travail.irf&anr.e&anr.; by ident noi; run; 
data indEE;
	merge indEE(in=a)
	      travail.irf&anr.e&anr.(in=b keep=ident noi lprm matri coured sexe naia acteu6  
								noienf01 noicon noiper noimer dremcm
	                            REVENT SALMEE);
	by ident noi;
	/* les EE n�s l'ann�e de l'EE ne peuvent figurer sur une declaration de l'ann�e pr�c�dente */
	if a & input(naia,4.)<&anref.;
	if matri=' ' then matri='1'; /* mis � c�libataire si valeur manquante */
	/* On estime un revenu imposable pour le calcul d'optimisation de l'imp�t dans le cas 
	des concubins avec enfants. Cela sert � d�terminer � qui on attribue ce ou ces enfants.
	Il n'y a pas d'abattement de 10 % sur le b�n�fices des ind�pendants. */
	revind=round((1-&abat10.)*(zsali+zchoi+zrsti+zpii+zalri)+zragi+zrici+zrnci,1); 
	run;

/* On trie les parents avant les enfants */
proc sort data=indEE; by ident naia; run;

/* On r�cup�re les noi, les revenus et le statut matrimonial des individus du m�nage ainsi 
que le noi du conjoint pour les femmes en esperant qu'il n'y a pas deux couples dans le m�nage.*/
data menEE(keep=ident noipr noi1-noi20 rev1-rev20 coupmar1-coupmar20 coupmar_EE);
	set indEE;
	by ident;

	array vect_noi noi1-noi20;
	array vect_rev rev1-rev20;
	array vect_coupmar coupmar1-coupmar20;

	retain np noipr noi1-noi20 rev1-rev20 coupmar1-coupmar20 coupmar_EE;
	if first.ident then do;
		np=0;
		noipr='';
		coupmar_EE=0;
		do i=1 to 20;
			vect_noi(i)=.;
			vect_rev(i)=0;
			vect_coupmar(i)=0;
			end;
		end;

	if lprm='1' then noipr=noi;
	np=np+1;
	vect_noi(np)=input(noi,2.);
	vect_rev(np)=revind;
	vect_coupmar(np)=(matri='2');

	/* lorsqu'une femme est mari�e avec un noicon inconnu, on consid�re qu'elle est mari�e avec un individu EE ou EE_CAF */
	if matri='2' & sexe='2' & noicon^='' then coupmar_EE=1;
	if last.ident;
	run;


/* 	On recr�e les foyers fiscaux. 
 	La premi�re chose c'est de regrouper les mari�s : on leur attribue un numero fiscal.
	Ensuite chaque personne ratach�e � ce couple doit avoir le m�me num�ro y compris quand 
	il s'agit d'un enfant d'un seul membre du couple (famille recompos�e). C'est 
	pourquoi on garde numfisc en reserve dans un tableau. */
data indEE(drop=i noipr noi1-noi20 rev1-rev20 coupmar1-coupmar20 revper revmer parentEE);
	merge 	indEE 
			menEE; 
	by ident;
	retain numfisc1-numfisc20;
	array vect_noi noi1-noi20;
	array vect_rev rev1-rev20;
	array vect_numfisc numfisc1-numfisc20;
	array vect_coupmar coupmar1-coupmar20;

	if first.ident then do;
		/* Initialisation de numfisc � 0 */
		do i=1 to 20;
			vect_numfisc(i)=0;
			end;
		end;
	format numfisc $2.; 
	numfisc=noi;

	/* On rassemble les conjoints mari�s dans le m�me foyer fiscal => si l'individu est 
	mari�, lorsqu'on parcourt le vecteur vect_noi, si on tombe sur noicon=vect_noi(i) 
	avec noicon non vide et que l'individu est une femme alors on lui donne pour numfisc 
	vect_noi(i) ie le noi de son conjoint. */
	if matri='2' then do i=1 to 20;
		if noicon=put(vect_noi(i),2.) & noicon^='' then do;
			if sexe='2' then do; numfisc=put(vect_noi(i),2.);end;
			end;
		end;

	vect_numfisc(input(noi,2.))=input(numfisc,2.);

	/* on rep�re les m�nages dans lesquels il y a un parent EE avec la variable parentEE. */
	parentEE=0; 
	do i=1 to dim(vect_noi);
		if (noiper=put(vect_noi(i),2.) & noiper ne '') or (noimer=put(vect_noi(i),2.) & noimer ne '')
			then parentEE=1;
		end;

	/*  peuvent �tre rattach�s au foyer fiscal de ce parent (rat=1) : 
		les individus non mari�s et sans enfants qui sont dans un m�nage avec un parent EE
			- de moins de 21 ans
			- ou de moins de 25 ans gagnant encore en �tudes */
	rat=(	parentEE=1 & noicon='' & noienf01='' &
			(&anref.-input(naia,4.)<=21 or (&anref.-input(naia,4.)<=25 & acteu6 eq '5')));

	/* On r�cup�re le revenu, le statut matrimonial des parents ainsi que leur numfisc. */
		do i=1 to dim(vect_noi);
			if noiper=put(vect_noi(i),2.) & noiper ne '' then do; 
				revper=vect_rev(i); 
				numfisc=put(vect_numfisc(input(noiper,2.)),2.); 
				end;
			if noimer=put(vect_noi(i),2.) & noimer ne '' then do; 
				revmer=vect_rev(i); 
				numfisc=put(vect_numfisc(input(noimer,2.)),2.);
				end; 
			end;

	/* Cas des deux parents. */ 
	/* si les parents sont mari�s on est sur le p�re, sinon on se met sur le plus riche : 
	c'est le plus vraisemblable. */
		if noiper ne '' & noimer ne '' then do;
			if coupmar_EE=1 then numfisc=noiper;
				else if revmer<revper then numfisc=noiper;
				else if revper<=revmer then numfisc=noimer;
				end;
	if substr(numfisc,1,1)='' then numfisc='0'||compress(numfisc);

	length idfisc $11;
	idfisc=compress(ident!!numfisc);

	/* Dans les cas o� coupmar_EE=1 (il y a un couple mari� dans le m�nage cr��e une variable 
	mari qui vaut 2 pour l'�poux et 1 pour sa conjointe. */
	if coupmar_EE=1 then do; if sexe='1' then mari=2; else mari=1; end;
	run;

proc sort data=indEE; by idfisc descending mari descending naia; run;
/* descending mari sert � mettre le mari avant sa femme. 
descending naia (+jeune au +age) sert � remplir anaisenf avec d'abord les nenff puis les nenfj.*/
	
/* Pour faire une d�claration seul, il faut atteindre 18 ans dans l'ann�e de revenu,
   donc on �carte tous les foyers o� tous les EE du m�nage sont des enfants -18 ans */
data foyer18;
	set indEE(keep=ident idfisc naia); /* rappel : idfisc=compress(ident!!numfisc) */
	by idfisc;
	retain nbp 0 nbadult 0;
	if first.idfisc then do;	
		nbp=0;
		nbadult=(&anref.-input(naia,4.)>=18);
		end;
	else do;
		nbp=nbp+1;
		nbadult=nbadult+(&anref.-input(naia,4.)>=18);
		end;
	if last.idfisc & nbadult>0 then output;
	run;

data indEE;
	merge 	indEE 
			foyer18(in=b);
	by idfisc;
	if b;
	run;


/*******************************/
/* Cr�ation de la table foyer  */
/*******************************/

data foyer persfipd(keep=ident noi persfipd);
	length 	anaisenf $45 
			mcdvo case_l $1 
			vousconj $9 
			noiconj $2 
			persfipd $5 
			_1aj _1bj _1cj _1dj _1ap _1bp _1cp _1dp _1ai _1bi _1ci _1di
			_1as _1bs _1cs _1ds _1ao _1bo _1co _1do 
			_1az _1bz _1cz _1dz
			_5hc _5ak _5ic _5bk _5jc _5ck _5kc _5lc _5mc _5qc _5rc _5sc _5xt _5xu
	        _7ea _7ec _7ef
			_nbheur_ppe_dec1 _nbheur_ppe_dec2 _nbheur_ppe_pac1 _nbheur_ppe_pac2 5;
	set indEE;
	by idfisc;
	retain 	mcdvo isol vousconj noiconj 
			_1aj _1bj _1cj _1dj 
			_1ap _1bp _1cp _1dp 
			_1ai _1bi _1ci _1di 
			_1as _1bs _1cs _1ds 
			_1az _1bz _1cz _1dz
			_1ao _1bo _1co _1do 
			_5hc _5ak _5ic _5bk _5jc _5ck _5kc _5lc _5mc _5qc _5rc _5sc _5xt _5xu
	        nbfi nbji anaisenf _7ea _7ec _7ef 
			_nbheur_ppe_dec1 _nbheur_ppe_dec2 _nbheur_ppe_pac1 _nbheur_ppe_pac2 ;

	/* On somme les cases fiscales par idfisc. 
	   On initialise �galement les donn�es "socio" */
	if first.idfisc then do;
	     isol=0; /* isole : ne vit pas en couple pour pouvoir pretendre � la 1/2 part T */
	     vousconj='9999-9999'; /* ann�e naissance PR CJ */
		 noiconj='  ';
	     _1aj=0;_1bj=0;_1cj=0;_1dj=0;
	     _1ap=0;_1bp=0;_1cp=0;_1dp=0;
	     _1ai=0;_1bi=0;_1ci=0;_1di=0;
	     _1as=0;_1bs=0;_1cs=0;_1ds=0;
		 _1az=0;_1bz=0;_1cz=0;_1dz=0;
	     _1ao=0;_1bo=0;_1co=0;_1do=0;
	  	 _5hc=0;_5ak=0;_5ic=0;_5bk=0;_5jc=0;_5ck=0;_5xt=0;_5xu=0;
		 _5kc=0;_5lc=0;_5mc=0;
		 _5qc=0;_5rc=0;_5sc=0; 
		 _nbheur_ppe_dec1=0;_nbheur_ppe_dec2=0;_nbheur_ppe_pac1=0;_nbheur_ppe_pac2=0;
		 nbfi=0;nbji=0;anaisenf='';
	     _7ea=0;_7ec=0;_7ef=0;
		end;


	if not rat then do; 				/* d�clarants fiscaux */
	    if sexe='1' then persfipd='mon'; else persfipd='mad';
		if coupmar_EE=1 then do; 	/* les couples mari�s */
			mcdvo='M';
			if sexe='1' then do;   /* l'homme est toujours le vous dans une decl conjointe */
				vousconj=compress(naia!!substr(vousconj,5,5));
				_1aj=zsali;        /* revenus d'activit� */
				_1ap=zchoi;        /* allocations ch�mage et pr�retraite */
				_1ai=(input(dremcm,4.)>=12); /* demandeur d'emploi inscrit depuis plus d'un an */
				_1as=zrsti;        /* retraites */
				_1az=zpii;        /* pensions d'invalidit� */
				_1ao=zalri;        /* pensions alimentaires */
				_5hc=zragi;        /* bag mis d'office r�el CGA, cas majoritaire */
				_5kc=zrici;        /* bic mis d'office r�el normal ou simplifi� CGA, cas majoritaire */
				_5qc=zrnci;        /* bnc mis d'office d�claration control�e CGA, cas majoritaire */
				_nbheur_ppe_dec1=(zsali>0)*max(min(zsali/&b_smich.,(&b_tdt.*52)),(&b_tdt.*52/2));
				/* approximation : nb heures travaill�es = salaire d�clar� / smic horaire brut, max dur�e l�gale de travail, min mi-temps */
				end;
			else if sexe='2' then do;
				vousconj=compress(substr(vousconj,1,5)!!naia);
				noiconj=noi;
				_1bj=zsali;
				_1bp=zchoi;
				_1bi=(input(dremcm,4.)>=12);
				_1bs=zrsti;
				_1bz=zpii;
				_1bo=zalri;
				_5ic=zragi;
				_5lc=zrici;
				_5rc=zrnci;
				_nbheur_ppe_dec2=max(min(zsali/&b_smica_dec.,1820),910)*(zsali>0);
				end;
			end;
		else if coupmar_EE ne 1 then do;
			if matri='1' then mcdvo='C';
			else if matri='2' then mcdvo='M';
			else if matri='3' then mcdvo='V';
			else if matri='4' then mcdvo='D';
			if coured='2' then isol=1;
			vousconj=compress(naia!!substr(vousconj,5,5));
			_1aj=zsali;
			_nbheur_ppe_dec1=(zsali>0)*max(min(zsali/&b_smich.,(&b_tdt.*52)),(&b_tdt.*52/2));
			_1ap=zchoi;
			_1ai=(input(dremcm,4.)>=12);
			_1as=zrsti;
			_1az=zpii;
			_1ao=zalri;
			_5hc=zragi;
			_5kc=zrici;
			_5qc=zrnci;
			end;
		end;

	else if rat then do; /* les pac */
		/* calcul nombre pac par type de pac et compl�ter anaisenf */
		/* enfants tri�s du plus jeune au plus vieux => on a bien les F avant les J */
		if &anref.-input(naia,4.)<=17 then do;
			nbfi=nbfi+1;
			anaisenf=compress(anaisenf)!!"F"!!naia;
			end;
		else if &anref.-input(naia,4.)<=25 then do;
			nbji=nbji+1;
			anaisenf=compress(anaisenf)!!"J"!!naia;
			end;

		/* r�ductions forfaitaires scolarit� */
		if &anref.-input(naia,4.)>=11 & &anref.-input(naia,4.)<=14 then _7ea=_7ea+1;                  /* coll�ge */
		else if &anref.-input(naia,4.)>=15 & &anref.-input(naia,4.)<=17 & acteu6='5' then _7ec=_7ec+1;  /* lyc�e */
		else if &anref.-input(naia,4.)>=18 & &anref.-input(naia,4.)<=25 & acteu6='5' then _7ef=_7ef+1 ; /* enseignement > */

		/* ne traite pas le cas ou il y a plus de deux personnes � charge avec des salaires */
		if zsali>0 then do;
			if _1cj>0 then do;
				_1dj=zsali;
				_nbheur_ppe_dec1=(zsali>0)*max(min(zsali/&b_smich.,(&b_tdt.*52)),(&b_tdt.*52/2));
				end;
			else  do; 
				_1cj=zsali;
				_nbheur_ppe_dec1=(zsali>0)*max(min(zsali/&b_smich.,(&b_tdt.*52)),(&b_tdt.*52/2));
				end;
			end;

	    if zchoi>0 then do;
			if  _1cp>0 then _1dp=zchoi;
			else _1cp=zchoi;
	    	end;
		
		if zrsti>0 then do;
			if _1cs>0 then _1ds=zrsti;
			else _1cs=zrsti;
			end;

		if zpii>0 then do;
			if _1cz>0 then _1dz=zpii;
			else _1cz=zpii;
			end;

		if zalri>0 then do;
			if _1co>0 then _1do=zalri;
			else _1co=zalri;
			end;

		_5jc=sum(_5jc, _5ck, zragi);
		_5mc=sum(_5mc,zrici);
		_5sc=sum(_5sc,zrnci);
		end;

	output persfipd;
	if last.idfisc then do;
		/* cas des veufs avec une part suppl�mentaire */
		if mcdvo='V' & (nbfi>0 ! nbji>0) then case_l='L'; else case_l='0';
		output foyer;
		end;
	run;


/* 	table dessin de fichier avec les variables foyer initialisees */
/* 	On garde la premi�re observation de la table foyer dans laquelle on annule toutes les 
	variables num�riques et on met � blanc les variables caract�res � blanc sauf cas 
	particuliers */
data foy0;
	set travail.foyer&anr.(obs=1);
	array tout _numeric_; do over tout; tout=0; end;
	array car _character_; do over car; car=''; end;
	/* variables caract�res pour lesquelles les valeurs par d�faut sont � '0' et non � blanc */
	moisev='00';
	jourev='00';
	xyz='0';
	case_e='0';
	case_f='0';
	case_g='0';
	case_k='0';
	case_l='0';
	case_p='0';
	case_s='0';
	case_w='0';
	case_t='0';
	run;

data foyer2(drop = nbfi nbji);
	if _n_=1 then set foy0; /* on ajoute la table foy0 � chaque ligne de la table foyer */
	set foyer;
	/* corrections des gens mari�s avec des fip */ 
	/* On triche, les gens qui se disent mari�s mais dont le conjoint n'est pas dans le m�nage
	   ont la date de naissance du conjoint � 9998 en vrai leur conjoint est un FIP. */ 
	if substr(vousconj,6,4) = '9999' & mcdvo in ('M','O') then substr(vousconj,6,4) = '9998';
	if substr(vousconj,1,4) = '9999' then  substr(vousconj,1,4) = '9998';
	nbf=nbfi;
	nbj=nbji;
	run;


data foyer3		(drop=nbenf pfsekwnlt pfswlt npcha isol nbenff nbenfj anaih ke avap
				choixech quelfic persfipd zsali zchoi zrsti zpii zalri zrtoi zragi zrici zrnci wp:
				lprm matri coured sexe naia acteu6 noienf01 noicon noiper noimer dremcm REVENT 
				SALMEE numfisc: revind rat idfisc mari coupmar_EE);
	set foyer2;
	/*length avap $2 case_t $1 nbenff $2 nbenfj $2 anaih $4 ke $1 pfswlt $1; */ 
	npcha=sum(nbf,nbj);
	if npcha>0 & isol=1 then case_t='T'; 
	else case_t='0'; /* 1/2 part isoles */
	zsalf=sum(_1aj,_1bj,_1cj,_1dj);
	zchof=sum(_1ap,_1bp,_1cp,_1dp);
	zrstf=sum(_1as,_1bs,_1cs,_1ds);
	zpif=sum(_1az,_1bz,_1cz,_1dz);
	zalrf=sum(_1ao,_1bo,_1co,_1do);
	zragf=sum(_5hc,_5ak,_5ic,_5bk,_5jc,_5ck,_5xt,_5xu);
	zricf=sum(_5kc,_5lc,_5mc);
	zrncf=sum(_5qc,_5rc,_5sc);
	zracf=0; zfonf=0; zvamfo=0; zvalfo=0; zetrf=0;

	/* VARIABLES DE DESCRIPTION DES FOYERS : IDENTIFIANTS DEC ET NOF_F */
	noi=numfisc; /* dans la table foyer, la variable noi est �gale au noi du d�clarant */
	noindiv=ident!!noi; /* ident pers declarant */
	if nbf<10 then nbenff="0"!!compress(put(nbf,2.)); else nbenff=compress(put(nbf,2.));
	if nbj<10 then nbenfj="0"!!compress(put(nbj,2.)); else nbenfj=compress(put(nbj,2.));
	nbenf='F'!!compress(nbenff)!!"G00R00"!!'J'!!compress(nbenfj)!!'N00'!!'H00I00P00';
	xyz='0'; /* �v�nement en cours d'annee extrait de dec ou sif */
	avap=' '; /* non gard�, variable qui normalement dit si c'est la decl d'avant ou apres 
	mariage, deces ou divorce : resp. 'M','Z','S'. 
	Maintenant Avap se termine par un trait mais sans importance. */
	declar=noi!!'-'!!ident!!'-'!!mcdvo!!vousconj!!'-'!!'000'!!avap!!'-'!!substr(anaisenf,1,40); 
	/* ident decl ERF */

	/* VARIABLE SIF DE LA DGI ET DIFFERENCES AVEC LA VARIABLE DEC */
	/* anaih,ke,pfswlt seulement utiles impot ne sont pas gardees */
	pfsekwnlt='0000'!!case_l!!'000000'!!case_t; /* les 10 1ers caract�res sont les 1/2 parts 
	EFGKLPSWNl2 */
	anaih='0000'; /* non garde : var d'impot, annee de naissance 1/2 part E ou K */
	ke=' '; /* non garde : var du prog d'impot valant K, E (si anaih confirme la validite), 
	P si pfswlt vaut F, L ou T */
	if case_l='L' then pfswlt='L';
	else if case_t='T' then pfswlt='T';
	else pfswlt=' '; /* non garde : le complt de la precedente, ou la 1/2p art effective 
	si seulement une seule */
	sif='SIF '!!mcdvo!!substr(vousconj,1,4)!!' '!!substr(vousconj,6,4)!!' '!!
		substr(pfsekwnlt,1,10)!!anaih!!case_t!!' '!!ke!!pfswlt!!' 000000000000000000000000000'
		!!avap!!'  '!!nbenf!!' 00 00';
	%standard_foyer;

	run;

/* on ajoute ces nouveaux foyers � la table foyer */
data travail.foyer&anr.; 
	set travail.foyer&anr. foyer3;
	run;

proc sort data=travail.foyer&anr. nodupkey; by declar; run;

/* On ajoute les infos dans indivi puis dans foyer */
data indEE2(keep=ident noi declar1 persfip );
	merge indEE(keep=ident noi numfisc)
	      foyer3(keep=ident noi noiconj declar rename=(noi=numfisc));
	by ident numfisc;
	length declar1 $100.  persfip $4. ; /*Bons formats pour &anref.=2014*/
	declar1=declar;
	if noi=numfisc then persfip='vous';
	else if noi=noiconj then persfip='conj';
	else persfip='pac';
	run;

proc sort data=indEE2; by ident noi;run;
proc sort data=travail.indivi&anr.; by ident noi;run;
data travail.indivi&anr.; 
	merge 	travail.indivi&anr. 
			indEE2; 
	by ident noi;
	run;


proc delete data=indEE indEE2 menEE foyer persfipd foyer2 foyer3 foyer18; run;

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
