/********************************************************************/
/*																	*/
/*                            BASEMEN                               */
/*																	*/
/********************************************************************/

/********************************************************************/
/* Construction de la base m�nage de sortie d'Ines                 	*/
/* En entr�e : 	base.baseind										*/
/*				base.baserev										*/	
/*				base.foyer&anr2.									*/	
/*				base.menage&anr2.									*/
/*				modele.basefam 										*/      
/*				modele.cotis_menage 								*/
/*				modele.impot_sur_rev&anr1.							*/
/*				modele.prelev_forf&anr2.							*/
/*				modele.VersLibAE									*/
/*				modele.baseind										*/
/*				modele.baselog										*/
/*				modele.rsa											*/
/*				modele.pa											*/
/*				modele.ppe											*/
/*				modele.bourses										*/
/*				modele.apa											*/
/*				modele.base_gj										*/
/* En sortie : 	modele.basemen                                     	*/
/********************************************************************/
/* Plan : 															*/
/* I. Identification, composition et caract�ristiques du m�nage 	*/
/* 	I.1. Ident, poi 												*/
/* 	I.2. Etud_pr	 												*/
/* 	I.3. Revpos	 													*/
/* 	I.4. Uci, nbp, acteu_pr, acteu_cj, age_pr, age_cj				*/
/* 	I.5. Age_enf													*/
/* 	I.6. Type_fam, nb_fam											*/
/* II. Cotisations et contributions sociales				       	*/
/* III. Imp�ts												       	*/
/* IV. Prestations										           	*/
/* 	IV.1. Af, com, aeeh, asf, ars, paje, clca, cmg, creche			*/
/* 	IV.2. Aah, caah, asi, aspa, cmu-c, acs							*/
/* 	IV.3. Alogl (locataire et acc�dant)								*/
/*	IV.4. Rsas, rsanonrec											*/
/* 	IV.5. Pper														*/
/* 	IV.6. PA														*/
/* 	IV.7. Bcol, blyc												*/
/* 	IV.8. Apa														*/
/* V. Agr�gats														*/
/********************************************************************/

/********************************************************************/
/* I. Identification, composition et caract�ristiques du m�nage 	*/
/********************************************************************/
/* 	I.1. Ident, poi 												*/
/********************************************************************/

/* On r�cup�re les variables ident et poi dans la table menage&anr2. */
proc sql;
	create table basemen as
	select distinct ident, wpela&anr2. as poi
	from base.menage&anr2.;
	quit;

/********************************************************************/
/* 	I.2. Etud_pr	 												*/
/********************************************************************/
proc sort data=base.baseind; by ident; run;
data basemen (keep=ident poi etud_pr);
	merge 	basemen (in=a) 
			base.baseind (where=(lprm='1') keep=ident acteu6 lprm);
	by ident;
	if a;
	if acteu6='5' then etud_pr='oui';
	else etud_pr='non';
	label 	ident=	"Identifiant m�nage"
			poi=	"Ponderation m�nage"
			etud_pr="Personne de r�f�rence �tudiante";
	run;

/********************************************************************/
/* 	I.3. Revpos	 													*/
/********************************************************************/
/* R�cup�ration des revenus individuels dans la table base.baserev */
proc sort data= base.baserev; by ident noi; run;
data baserev; 
	merge 	base.baserev(keep=ident noi zsali&anr2. zrsti&anr2. zpii&anr2. zchoi&anr2. zalri&anr2. zrtoi&anr2. zragi&anr2. zrici&anr2. zrnci&anr2. montant_ass_hors_prime montant_ass ass_noel)
			base.baseind(keep=ident noi quelfic); 
	by ident noi; 
	/* Pour les b�n�ficiaires de l'ASS, on enl�ve de leur zchoi leur montant ass hors prime pour ne pas fausser leur calcul de revenu disponible en faisant un double compte */
	if montant_ass_hors_prime>0 then zchoi&anr2.=zchoi&anr2.-montant_ass_hors_prime;
	/*on ne prend pas en compte les FIP dans l'agr�gation (pour �liminer les enfants FIP) sauf ceux qui ont des revenus positifs (certains adultes). 
	En effet l'impot du foyer a �t� calcul� en prenant en compte les FIP qui ont des revenus donc il faut prendre en compte leurs revenus pour calculer le revenu disponible du m�nage*/
	if quelfic ne "FIP" or sum(0, zsali&anr2., zrsti&anr2., zpii&anr2., zchoi&anr2., zalri&anr2., zrtoi&anr2., zragi&anr2., zrici&anr2., zrnci&anr2.)>0;
	run; 
%cumul(basein=  baserev,
	   baseout= revindiv,
	   varin=   zsali&anr2. zrsti&anr2. zpii&anr2. zchoi&anr2. zalri&anr2. zrtoi&anr2. zragi&anr2. zrici&anr2. zrnci&anr2. montant_ass ass_noel,
	   /* On fait une sortie d�di�e � l'ASS, qui vaut z�ro si module_ass=non  */
	   varout=  zsalm   	zrstm   zpim   	zchom   	zalrm   	zrtom   	zragm   zricm   zrncm montant_ass ass_noel,
	   varAgregation= ident); /*on agr�ge au niveau m�nage */

/* R�cup�ration de revenus non individualisables dans la table base.foyer&anr2. ainsi que les pensions alimentaires*/
%cumul(basein=  base.foyer&anr2.,
	   baseout= revnonindiv,
	   varin=   zracf zetrf zfonf zvamf zvalf zalvf _2dh _2ch _2fu,
	   varout=  zracm zetrm zfonm zvamm zvalm zalvm _2dh _2ch _2fu,
	   varAgregation= ident);
/* Attention, � ce stade asym�trie possible entre agr�gat ainsi reconstitu� de foyer et agr�gat m�nage de l'ERFS : 
	En effet les revenus d'assurance-vie sont d�duits de ZVALM et ZVAMM dans l'ERFS pour �viter les doubles comptes avec produitfin_i, 
	alors qu'ici ils sont encore inclus (on les retirera plus bas). */
data basemen(keep=ident poi etud_pr zfiscm ztsam zperm zsalm zragm zricm zrncm zchom zrstm zpim zalrm zrtom zracm zetrm zfonm
				zvamm zvalm zalvm revpos revdecm montant_ass ass_noel);
	merge 	basemen (in=a) 
			revindiv (where=(ident^='')) 
			revnonindiv (where=(ident^='') in=b);
	by ident;
	if a;
	if not b then do; %Init_Valeur(zracm zetrm zfonm zvamm zvalm zalvm _2dh _2ch _2fu); end; /*traitement des m�nages EE_NRT comme dans l'ERFS */
	ztsam=	sum(0,zsalm,zchom);
	zperm=	sum(0,zrstm,zpim,zalrm,zrtom);
	/* Comme dans l'ERFS, on retire de zvalf et zvamf les revenus d'assurance-vie et de pea pour ne pas faire de double compte avec produitfin_i */
	zvalm=	sum(0,zvalm,-_2dh);
	zvamm=	sum(0,zvamm,-_2ch,-_2fu);
	revdecm=sum(0,ztsam,zperm,zragm,zricm,zrncm,zfonm,zvamm,zvalm,zracm,zetrm,-zalvm);
	zfiscm=	sum(revdecm,_2ch,_2fu,_2dh);
	revpos=	(revdecm>=0);
	label   ztsam=	"Traitements et salaires au sens large"
			zperm=	"Pensions et retraites, yc pensions alimentaires et rentes viag�res � titre on�reux"
			zvalm=	"Revenu de valeurs mobili�res soumis au pr�l�vement lib�ratoire, hors ce qui est dans produitfin_i"
			zvamm=	"Revenu de valeurs mobili�res non soumis au pr�l�vement lib�ratoire, hors ce qui est dans produitfin_i"
			revdecm="Revenu d�clar�, hors ce qui est dans produitfin_i"
			zfiscm=	"Revenu d�clar�, yc revenus d'assurance-vie et de pea"
			revpos=	"Revenu d�clar� positif (hors assurance-vie et PEA)"
			montant_ass="ASS, y compris prime d'int�ressement (hors prime de No�l)"
			ass_noel="Prime de No�l du fait de la perception de l'ASS";
	run;

/************************************************************************/
/* 	I.4. Uci, nbp, acteu_pr, acteu_cj, age_pr, age_cj, sexe_pr, sexe_cj	*/
/************************************************************************/
data info_indiv (keep=ident uci nbp acteu_: age_: sexe_:);
	set base.baseind(keep=ident naia quelfic lprm acteu6 sexe:);
	by ident;
	agexx=	&anref.-input(naia,4.);
	aduci=	(agexx>=14);
	enfuci=	(-1<agexx<14);
	retain aduc enfuc nbp acteu_pr acteu_cj age_pr age_cj sexe_pr sexe_cj;

	if first.ident then do;
		%Init_valeur(enfuc aduc nbp);
		acteu_pr=' '; acteu_cj=' ';
		age_pr=.; age_cj=.;
		sexe_pr=.; sexe_cj=.;
		end;
	if quelfic ne 'FIP' then do; 
		if agexx>=0 then nbp=nbp+1;
		enfuc=	sum(0,enfuc,enfuci);
		aduc=	sum(0,aduc,aduci);
		end;
	uci=1+0.5*(aduc-1)+0.3*enfuc;

	if lprm='1' then do;
		acteu_pr=acteu6;
		age_pr=	agexx;
		sexe_pr=sexeprm;
		end;
	if lprm='2' then do;
		acteu_cj=acteu6;
		age_cj=agexx;
		sexe_cj=sexeprmcj;
		end;
	label 	agexx=		"Age au 31 d�cembre de &anleg."
			uci=		"Nombre d'unit�s de consommation"
			nbp=		"Nombre de personnes dans le m�nage"
			acteu_pr=	"Statut d activit� au sens du BIT de la personne de r�f�rence"
			acteu_cj=	"Statut d activit� au sens du BIT du conjoint"
			age_pr=		"Age de la personne de r�f�rence"
			age_cj=		"Age du conjoint"
			sexe_pr=	"Sexe de la personne de r�f�rence"
			sexe_cj=	"Sexe du conjoint";;
	if last.ident;
	run;
data basemen;
	merge 	basemen (in=a) 
			info_indiv;
	by ident;
	if a;
	run;


/********************************************************************/
/* 	I.5. Age_enf													*/
/********************************************************************/
/* On cr�e une variable age_enf par m�nage et non par famille comme dans basefam. 
Elle consiste en la "somme" des age_enf par m�nage (on empile les familles). */
data agenf (keep=ident enf:);
	set modele.basefam (keep=ident age_enf);
	array enf(21) enf1-enf21;
	do i=1 to 21;
		enf(i)=substr(age_enf,i,1);
		end;
	run;
proc means data=agenf sum noprint;
	class ident;
	var enf:;
	output out=agenf(drop=_type_ _freq_) sum=;
	run;
data basemen (drop=enf: i);
	merge 	basemen (in=a) 
			agenf (where=(ident^=''));
	by ident;
	if a;
	array  enf(21) enf1-enf21;
	age_enf='000000000000000000000';
	do i=1 to 21;
		substr(age_enf,i,1)=enf(i);
		end;
	label age_enf=	"Age et nombre des enfants du m�nage";
	run;

/********************************************************************/
/* 	I.6. Type_fam, nb_fam											*/
/********************************************************************/
proc sort data=modele.basefam; by ident; run;
data typfam(keep=ident typfam nbfam);
	set modele.basefam(keep=ident_fam ident enf_1 age_enf nbciv); 
	by ident;
	length typfam $3;
	retain typ1 typ2 typ3 typ4 typ5 typ6 typ7 typ8 nbfam nb_enf;
	if first.ident then do;
		typ1=0; typ2=0; typ3=0; typ4=0; typ5=0; typ6=0; typ7=0; typ8=0;
		nbfam=0;
		enf_pf=0;nb_enf=0;
		end;
	/* On prend comme limite &age_pf.+1 pour inclure dans le d�compte des pacs au sens des pf les enfants qui d�passent l'�ge limite au cours de l'ann�e (logique ann�e pleine) */
	%nb_enf(e_c21,0,&age_pf.+1,age_enf);
	nbfam=nbfam+1;
	nb_enf=nb_enf+e_c21;
	if nbciv=2 & e_c21=1  then typ1=typ1+1;
	if nbciv=2 & e_c21=2  then typ2=typ2+1;
	if nbciv=2 & e_c21>=3 then typ3=typ3+1;
	if nbciv=1 & e_c21=1  then typ4=typ4+1;
	if nbciv=1 & e_c21>=2 then typ5=typ5+1;
	if nbciv=2 & e_c21=0  then typ6=typ6+1;
	if nbciv=1 & e_c21=0  then typ7=typ7+1;

	if nbfam=1 then do;
	         if typ1=1 then typfam='C1 ';
	    else if typ2=1 then typfam='C2 ';
	    else if typ3=1 then typfam='C3+';
	    else if typ4=1 then typfam='I1 ';
	    else if typ5=1 then typfam='I2+ ';
	    else if typ6=1 then typfam='C0 ';
	    else if typ7=1 then typfam='I0 ';
		end;
		else do;
	    if typ1>=1 ! typ2>=1 ! typ3>=1 ! typ4>=1 ! typ5>=1 then typfam='X1+';
		else typfam='X0 ';
		end;
	if typfam in ('I2 ','I3+') then typfam='I2+'; 

	if last.ident then output;
	label 	typfam=	"Type de famille au sens des CAF"
			nbfam=	"Nombre de familles dans le m�nage";
	run;	

data basemen; 
	merge 	basemen(in=a) 
			typfam(in=b); 
	by ident; 
	if a & b;
	run;


/********************************************************************/
/* II. Cotisations et contributions sociales				       	*/
/********************************************************************/
proc sort data=modele.cotis_menage; by ident; run;
data basemen;
	merge basemen (in=a) 
		  modele.cotis_menage (where=(ident^='') keep=ident cotassu cotred coMicro cofas cofap contassu contred cotis_patro tot_cont tot_cotis
						csgd csgi crds_ar crds_etr prelev_pat csg_etr ContribExcSol);
	by ident;
	if a;
	run;

/********************************************************************/
/* III. Imp�ts												       	*/
/********************************************************************/
%cumul(basein=  modele.impot_sur_rev&anr1.,
	   baseout= impot,
	   varin=   impot impot_revdisp,
	   varout=  impot impot_revdisp,
	   varAgregation=	ident);
%cumul(basein=  modele.prelev_forf&anr2.,
	   baseout= prelev_forf,
	   varin=   prelev_forf,
	   varout=  prelev_forf,
	   varAgregation=	ident);
%cumul(basein=  modele.VersLibAE,
	   baseout= VersLibAE,
	   varin=   verslib_autoentr,
	   varout=  verslib_autoentr,
	   varAgregation=	ident);
data basemen;
	merge basemen (in=a) 
		  impot(where=(ident^='')) 
		  prelev_forf(where=(ident^=''))
		  VersLibAE(where=(ident^=''))
		  base.menage&anr2. (keep=ident zthabm typmen_Insee rename=(zthabm=th));
	by ident;
	if a;
	if impot=. then impot=0;
	if impot_revdisp=. then impot_revdisp=0;
	if verslib_autoentr=. then verslib_autoentr=0;
	if prelev_forf=. then prelev_forf=0;
	run; 

/********************************************************************/
/* IV. Prestations										           	*/
/********************************************************************/

/********************************************************************/
/* 	IV.1. Af, com, aeeh, asf, ars, paje, clca, cmg, creche			*/
/********************************************************************/

%cumul(basein=	modele.basefam,
       baseout=	presta_fam,
       varin=	afxx0 majafxx alocforxx comxx aeeh asf arsxx paje_nais paje_base clca cmg cmg_exo creche,
       varout=	afxx0 majafxx alocforxx comxx aeeh asf arsxx paje_nais paje_base clca cmg cmg_exo creche,
	   varAgregation= ident);
data basemen;
	merge 	basemen (in=a) 
			presta_fam (where=(ident^=''));
	by ident;
	paje=	sum(0,paje_nais,paje_base);
	cmgtot=	sum(0,cmg,cmg_exo);
	af=		sum(0,afxx0,majafxx,alocforxx);
	drop cmg cmg_exo paje_nais paje_base afxx0 majafxx alocforxx;
	rename cmgtot=cmg;
	if creche=. then creche=0;
	if a;
	label	paje=	"PAJE totale(naissance et base)"
			cmg=	"CMG total(cmg et cmg eco)"
			af=		"Allocations familiales";
	run;

/********************************************************************/
/* 	IV.2. Aah, caah, asi, aspa, cmu-c, acs							*/
/********************************************************************/
%cumul(basein=	modele.baseind,
       baseout=	presta_ind,
       varin=	aah caah asi aspa avantage_monetaire_cmuc cheque_acs,
       varout=	aah caah asi aspa avantage_monetaire_cmuc cheque_acs,
	   varAgregation=	ident);

data basemen;
	merge 	basemen (in=a) 
			presta_ind (where=(ident^=''));
	by ident;
	if a;
	run;

/********************************************************************/
/* 	IV.3. Alogl (locataire et acc�dant)								*/
/********************************************************************/
%cumul(basein=	modele.baselog,
       baseout=	alogt,
       varin=	al,
       varout=	alogl,
	   varAgregation=	ident);

data basemen;
	merge 	basemen (in=a) 
			alogt (where=(ident^='')) 
			base.menage&anr2. (keep =ident alaccedant rename=(alaccedant=alogacc));
	by ident;
	if a;
	if alogl=. then alogl=0;
	if alogacc=. then alogacc=0;
	run;

/********************************************************************/
/*	IV.4. Rsas, rsanonrec											*/
/********************************************************************/
%cumul(basein=	modele.rsa,
       baseout=	rsa,
       varin=	rsa rsa_eli rsasocle rsasocle_eli rsa_noel psa rsaact rsaact_eli enf03,
       varout=	rsa rsa_eli rsasocle rsasocle_eli rsa_noel psa rsaact rsaact_eli enf03,
	   varAgregation=	ident);

data basemen;
	merge 	basemen (in=a) 
			rsa(where=(ident^=''));
	by ident;
	if a;
	if rsasocle=. 	then rsasocle=0;
	if rsasocle_eli=. 	then rsasocle_eli=0;
	if rsaact=. 	then rsaact=0;
	if enf03=. 		then enf03=0;
	if rsa_noel=. 	then rsa_noel=0;
	if psa=. 		then psa=0;
	if rsaact_eli=. then rsaact_eli=0;
	if rsa=. then rsa=0;
	if rsa_eli=. then rsa_eli=0;
	run;

/********************************************************************/
/* 	IV.5. Pper														*/
/********************************************************************/
%cumul(basein=	modele.ppe,
       baseout=	pper,
       varin=	ppef,
       varout=	pper,
	   varAgregation=	ident);

data basemen;
	merge 	basemen (in=a) 
			pper (where=(ident^='')) ;
	by ident;
	if a;
	if pper=. then pper=0;
	run;

/********************************************************************/
/*	IV.6. PA											*/
/********************************************************************/
%cumul(basein=	modele.pa,
       baseout=	pa,
       varin=	patot patot_eli,
       varout=	patot patot_eli,
	   varAgregation=	ident);

data basemen;
	merge 	basemen (in=a) 
			pa(where=(ident^=''));
	by ident;
	if a;
	if patot=. 	then patot=0;
	if patot_eli=. 	then patot_eli=0;
	run;


/********************************************************************/
/* 	IV.7. Bcol, blyc												*/
/********************************************************************/
%cumul(basein=	modele.bourses,
       baseout=	bourses,
       varin=	bourse_col bourse_lyc,
       varout=	bcol 	   blyc,
	   varAgregation=	ident);

data basemen;
	merge 	basemen (in=a) 
			bourses (where=(ident^='')) ;
	by ident;
	if a;
	run;

/********************************************************************/
/* 	IV.8. Apa														*/
/********************************************************************/
%cumul(basein=	modele.apa,
       baseout=	apa,
       varin=	apa,
       varout=	apa,
	   varAgregation=	ident);

data basemen;
	merge 	basemen (in=a) 
			apa (where=(ident^='')) ;
	by ident;
	if a;
	if apa=. then apa=0;
	run;

/********************************************************************/
/* 	IV.9. Garantie jeunes											*/
/********************************************************************/
%cumul(basein=	modele.base_gj,
       baseout=	gj,
       varin=	gj,
       varout=	gj,
	   varAgregation=	ident);

data basemen;
	merge 	basemen (in=a) 
			gj (where=(ident^='')) ;
	by ident;
	if a;
	if gj=. then gj=0;
	run;


/********************************************************************/
/* V. Agr�gats														*/
/********************************************************************/
proc sort data=base.menage&anr2.; by ident; run;
data modele.basemen;
	merge 	basemen (in=a) 
			base.menage&anr2. (keep=ident produitfin_i);
	by ident;
	if a;
	/* En cas de double perception de l'ASS et du RSA, seule la prime de No�l la plus int�ressante peut �tre touch�e. Or, c'est n�cessairement 
	celle du RSA qui est la plus int�ressante car elle est familialis�e alors que celle de l'ASS est individuelle (m�me montant pour des c�libataires) */
	if rsa_noel>0 and ass_noel>0 then ass_noel=0;
	/* CRDS sur les prestations */
	crds_p=		&t_CRDS_p.*sum(af,paje,comxx,asf,arsxx,alogl,alogacc,rsaact,patot);
	crds_p_cmg=	&t_CRDS_p.*cmg; /* Ne sera d�duit que dans le revenu disponible ajust� */

	/* Regroupements de transferts */
	minima=		sum(0,aspa,aah,caah,rsasocle,rsaact,rsa_noel, ass_noel,asi,psa,rsa,patot, montant_ass,gj);
	pf_condress=sum(0,paje,comxx,arsxx);    
	pf_sansress=sum(0,aeeh,asf,clca); 
	pf=			pf_condress+pf_sansress;
	pf_tout=	sum(pf,af);
	alog=		sum(alogl,alogacc);
	tot_presta=	sum(pf_tout,alog,minima);
	impot_tot=	sum(impot,prelev_forf,verslib_autoentr,-pper);
	impot_tot_revdisp=	sum(impot_revdisp,prelev_forf,verslib_autoentr,-pper);
	impot_direct=sum(impot_tot,th);

	/* D�finitions des diff�rents concepts de revenus */
	revnet=		sum(0,revdecm,produitfin_i);
	revsbrut=	sum(0,revnet,cotassu,cotred,coMicro,csgd);
	revavred=	sum(0,revsbrut,-cotassu,-contassu,-coMicro); /* Sert pour la fiche *//*To do : normalement ce n'est qu'une part de coMicro*/
	/* revavred est aussi �gal � sum(0,revnet,cotred,csgd,-contassu)*/
	revbrut=	sum(0,revsbrut,-Cotis_Patro); /* Sert pour la vue */
	revdisp=	sum(0,revavred,-contred,-crds_p,-cotred,-impot_tot_revdisp,-th,pf_tout,alog,minima); 
	/* on retranche impot_tot_revdisp et non impot_tot de mani�re � ne pas enlever d'imp�t sur les revenus non comtpabilis�s dans le revenu disponible */
	
	/* V�rification ok */
	/*revdisp_	=	sum(0,revbrut,-(tot_cotis-cotis_patro),-tot_cont,-impot,-verslib_autoentr,-prelev_forf,-th,
				af,	comxx,asf,aeeh,arsxx,paje,clca,alogl,alogacc,aah,caah,asi,aspa,rsasocle,rsaact,rsa_noel,psa,pper);*/ /* Pour v�rifier */
	/*verif=(revdisp-revdisp_) lt 0.01;*/

	revdisp_ajuste=	sum(0,revdisp,cmg-crds_p_cmg,creche,bcol,blyc,apa, avantage_monetaire_cmuc, cheque_acs);

	label   revnet		=	"Revenu net ou revenu de r�f�rence"
			revsbrut	=	"Revenu superbrut avant tout prelevement"
			revavred	=	"Revenu avant redistribution"
			revdisp		=	"Revenu disponible avec le champ ERFS"
			revdisp_ajuste=	"Revenu disponible ajust� de transferts en nature"
			comxx		=	"Compl�ment familial"
			asf			=	"Allocation de soutien familial"
			aeeh		=	"Allocation d'�ducation de l'enfant handicap�"
			arsxx		=	"Allocation de rentr�e scolaire"
			creche		=	"Subvention vers�e aux creches"
			alogl		=	"AL locataire"
			alogacc		=	"AL accedant"
			alog=			"AL locataire et acc�dant"
			avantage_monetaire_cmuc = "Montant de remboursement touch� au titre de la CMUc"
			cheque_acs = "Montant du ch�que ACS"
			asi			=	"Allocation suppl�mentaire d'invalidit�"
			aspa		=	"Minimum vieillesse"
			rsasocle	=	"RSA socle"
			rsaact		=	"RSA activit� avec application du non recours"
			rsaact_eli  =   "RSA activit� avant tirage du non recours"
			rsa_noel	=	"Prime de No�l du RSA"
			rsa			=	"RSA (apr�s 2016)"
			patot		= 	"Prime d'activit� avec application du non recours"
			patot_eli	= 	"Prime d'activit� avant tirage du non recours"
			pper		=	"PPE r�siduelle"
			bcol		=	"Bourses de college"
			blyc		=	"Bourses de lycee"
			crds_p		=	"CRDS sur les prestations"
			crds_p_cmg	=	"CRDS sur le CMG"
			impot		=	"Impot sur le revenu avant PPE"
			prelev_forf	=	"pr�l�vements forfaitaires sur les revenus"
			th			=	"Taxe d habitation"
			csgd		=	"CSG deductible sur revenus individualisables"
			csgi		=	"CSG imposable sur revenus individualisables"
			crds_ar		=	"crds sur les revenus d'activit� et de remplacement"
			typmen_Insee = 	"Type de m�nage au sens de l'Insee"
			minima=			"Minima sociaux yc RSA activit�"
			pf_condress=	"Prestations familiales sous condition de ressources"
			pf_sansress=	"Prestations familiales sans condition de ressources, hors allocations familiales"
			pf=				"Prestations familiales, hors allocations familiales"
			pf_tout=		"Prestations familiales, yc allocations familiales"
			impot_tot=		"Imp�t et pr�l�vements forfaitaires, nets de PPE"
			impot_direct=	"Imp�t sur le revenu et taxe d'habitation"
			tot_presta=		"Total des prestations sociales"
			gj = 			"Garantie jeunes";
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
