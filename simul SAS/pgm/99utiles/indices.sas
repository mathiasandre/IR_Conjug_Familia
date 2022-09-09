%Macro Gini(data=,var=,pond=,crit=,pseudo=,where=,out=_gini_);
%global gini;
     proc sort data=&data

          out=&out(keep=&var &pond &pseudo &crit);
     by &crit &var;run;

     %if &pseudo= %then %let pseudo=&var;
     %if &pond= %then %let pond=1; %*pond doit absolument être entier !;

     data &out(keep=&crit effectif moyenne gini);
     set &out end=fin; by &crit &var;
     retain _eff 0 gini 0 _pond 0 _mass 0 _moy 0;
     %if &crit ne %then %do;
        if first.&crit then do; _eff=0; _mass=0; gini=0; end;
     %end;
	     _mass=_mass+&pond*&pseudo;
	     gini=gini+&pond*&pseudo*(2*_eff+&pond+1)/2;
		 _eff=_eff+&pond;
	     %if &crit ne %then %do; if last.&crit then do; %end;
	     %else %do; if fin then do; %end;
	     gini=2*gini/(_mass*_eff)-1-1/_eff;_moy=_mass/_eff;
	     effectif=_eff;moyenne=_moy;
	     label effectif="Frequence" moyenne="Moyenne de &pseudo" gini="Gini";
		 call symput ('gini',gini);
	     output;
		 end;
	 run;
%MEND gini;

%MACRO ATKIN(Data=,var=,POND=,CRIT=,Out=_atkin_,where=);
     *        INDICES DE ATKINSON
                        A  1/A
           I=1-(SUM(R/M)  );
     options nonotes dquote;run;
     %if &crit = %then %do;
       data &out(keep=&var &pond &crit);
       set &data(where=((&var>0)
            %if &where ne %then %do;%str(&) &where %end; ) );
     %end;
     %else %do;
     proc sort data=&data(where=((&var>0)
            %if &where ne %then %do;%str(&) &where %end; ) )
       out=&out(keep=&var &pond &crit);by &crit;
     %end;
     proc summary data=&out;
     %if &crit ne %then %do;class &crit;%end;
     var &var;
     %if &pond ne %then %do;weight &pond;%end;
     output out=_ATK mean=_mvar ;
     data &out;
     if _n_=1 then set _ATK(where=(_type_=0) rename=(_mvar=_mx));
     %if &crit ne %then %do;
       merge &out _ATK(where=(_type_=1));by &crit;
       _rap=&var/_mvar;
       _c075_=_rap**0.75;_c050_=sqrt(_rap);_c025_=_rap**0.25;
       _c0_=log(_rap);_cm025_=1/_c025_;_cm050_=1/_c050_;
       _cm075_=1/_c075_;_cm1_=1/_rap;_cm2_=1/(_rap*_rap);
       _cm5_=1/(_rap**5);_cm10_=1/(_rap**10);
     %end;
     %else %do;set &out;%end;
     _rap=&var/_mx;
     _a075_=_rap**0.75;_a050_=sqrt(_rap);_a025_=_rap**0.25;
     _a0_=log(_rap);_am025_=1/_a025_;_am050_=1/_a050_;
     _am075_=1/_a075_;_am1_=1/_rap;_am2_=1/(_rap*_rap);
     _am5_=1/(_rap**5);_am10_=1/(_rap**10);
     proc summary data=&out;var
      _a075_ _a050_ _a025_ _a0_ _am025_ _am050_ _am075_ _am1_ _am2_
      _am5_ _am10_
      %If &crit ne %then %do;
        _c075_ _c050_ _c025_ _c0_ _cm025_ _cm050_ _cm075_ _cm1_ _cm2_
        _cm5_ _cm10_ %end;;
     %if &crit ne %then %do;class &crit;%end;
     %if &pond ne %then %do;weight &pond;%end;
     output out=&out mean= ;
     data &out(drop=_type_
      %If &crit ne %then %do;
        _c075_ _c050_ _c025_ _c0_ _cm025_ _cm050_ _cm075_ _cm1_ _cm2_
        _cm5_ _cm10_ %end;);
     set &out;
     _a075_=1-(_a075_**(1/0.75));_a050_=1-_a050_*_a050_;
     _a025_=1-(_a025_**4);_a0_=1-exp(_a0_);
     _am025_=1-1/(_am025_**4);_am050_=1-1/(_am050_*_am050_);
     _am075_=1-1/(_am075_**(1/0.75));_am1_=1-1/_am1_;
     _am2_=1-1/(sqrt(_am2_));_am5_=1-1/(_am5_**0.2);
     _am10_=1-1/(_am10_**0.1);
      %If &crit ne %then %do;
      if _n_>1 then do;
       _a075_=1-(_c075_**(1/0.75));_a050_=1-_c050_*_c050_;
       _a025_=1-(_c025_**4);_a0_=1-exp(_c0_);
       _am025_=1-1/(_cm025_**4);_am050_=1-1/(_cm050_*_cm050_);
       _am075_=1-1/(_cm075_**(1/0.75));_am1_=1-1/_cm1_;
       _am2_=1-1/(sqrt(_cm2_));_am5_=1-1/(_cm5_**0.2);
       _am10_=1-1/(_cm10_**0.1);
      end;%end;
     label _a075_="Norme 0.75" _a050_="Norme 0.50"
           _a025_="Norme 0.25" _a0_="Norme 0"
           _am025_="Norme -0.25" _am050_="Norme -0.50"
           _am075_="Norme -0.75" _am1_="Norme -1"
           _am2_="Norme -2" _am5_="Norme -5" _am10_="Norme -10";
     proc print data=&out label;
     var &crit
      _a075_ _a050_ _a025_ _a0_ _am025_ _am050_ _am075_ _am1_ _am2_
      _am5_ _am10_ ;
     title2 "Indicateurs d'Atkinson pour la variable &var";
     run;title2;options notes;run;
	 %global atkin75;
	 %global atkin50;
	 %global atkin25;
	 %global atkin0;
	data _null_;
	set &out;
	call symput('atkin75',_a075_); 
	call symput('atkin50',_a050_);
	call symput('atkin25',_a025_);
	call symput('atkin0',_a0_);
	run;
%MEND ATKIN;
%macro atkin0(Data=,var=,POND=,CRIT=,Out=_atkin_,where=);
%atkin(Data=&data,var=&var,POND=&pond,CRIT=&crit,Out=&out,where=&where);
%mend atkin0;
%macro atkin25(Data=,var=,POND=,CRIT=,Out=_atkin_,where=);
%atkin(Data=&data,var=&var,POND=&pond,CRIT=&crit,Out=&out,where=&where);
%mend atkin25;
%macro atkin50(Data=,var=,POND=,CRIT=,Out=_atkin_,where=);
%atkin(Data=&data,var=&var,POND=&pond,CRIT=&crit,Out=&out,where=&where);
%mend atkin50;
%macro atkin75(Data=,var=,POND=,CRIT=,Out=_atkin_,where=);
%atkin(Data=&data,var=&var,POND=&pond,CRIT=&crit,Out=&out,where=&where);
%mend atkin75;

%MACRO THEIL(data=,var=,pond=,crit=,Out=_Theil_,Where=);
	%global theil;
     options nonotes dquote;run;
     data &out(keep=&var &pond &crit _xlogx);
     set &data;
	 &var = abs(&var);
	 if &var ne 0 then do;
     _xlogx=&var*log(&var);end;
	  else do; _xlogx=0;end;
     proc summary data=&out;class &crit;
     var &var _xlogx;
     %if &pond ne %then %do;weight &pond;%end;
     output out=&out mean(&var)=&var mean(_xlogx)=_xlogx
                sum(&var)=_mas;
     data &out(keep=&crit &var _freq_ theil part);
     set &out end=fin ;
     retain pcum1 0 pcum2 0 ttot mtot motot;
	 if &var ne 0 then do;
     	theil=-log(&var)+_xlogx/&var; end;
	 else do; theil=0;end;
     if _n_=1 then do;mtot=_mas;ttot=theil;
             motot=&var;end;
     else do;
       thexp=_mas*theil/mtot;
       pexp=thexp/ttot;pcum1=pcum1+pexp;
       pcum2=pcum2+(_mas/mtot)*log(&var/motot)/ttot;
     end;
     if fin then part=100*pcum2;
     label &var="Moyenne" _freq_="Effectif"
           theil="Theil" part="Part expliquee (en %)";
	 call symput('theil',theil);
     proc print label data=&out;id &crit;
     var &var _freq_ theil part;
     title2 "Indice de THEIL pour la variable &var";
     run;title2 ;options notes;run;
%MEND THEIL;
/* on ne peut pas l'utiliser parce qu'elle n'aime pas les valeurs nulles);
%MACRO VLOG(Data=,Var=,POND=,CRIT=,Out=_VLOG_,where=);
%global vlog;
     options nonotes dquote;run;
     data &out(keep=&var &pond &crit _logx _log2x);
     set &data;
	 &var = abs(&var);
	if &var = 0 then &var = 1/10000;
     _logx=log(&var);_log2x=_logx*_logx;
     proc summary data=&out;class &crit;
     var &var _logx _log2x;
     %if &pond ne %then %do;weight &pond;%end;
     output out=&out mean=;
     data &out(keep=&crit &var _freq_ vlog);set &out;
     vlog=log(&var)*(log(&var)-2*_logx)+_log2x;
	 call symput('vlog',vlog);
     Label &var='Moyenne' _Freq_='Effectif' vlog='Variance des Log';
     proc print data=&out label;
     var &crit &var _freq_ vlog;
     title2 "Variance des log pour la variable &var";
     run;title2;options notes;run;
%MEND VLOG;
*/

%MACRO rapp5(data=,var=,pond=,Out=_rapp5_);
proc sort data=&data; by &var; run;
	proc univariate noprint data=&data;
		var &var;
		output out=temp_bidon2 pctlpts=20 80 pctlpre=quant 
				pctlname=i1 i2;
		freq &pond;
	run;
%global rapp5;
data temp_bidon2;
set temp_bidon2;
rapp=quanti2/quanti1;
call symput('rapp5',rapp);
run;

	proc sql;
	drop table temp_bidon2;
	quit;
%mend rapp5;



%MACRO rapp_moy5(data=,var=,var_class=,pond=,Out=_rapp5_);
proc sort data=&data; by &var_class; run;
	proc means noprint data=&data;
		var &var;
		by &var_class; 
		output out=temp_bidon2; 
		freq &pond;
	run;
%global rapp5;
%global Q1;
%global Q5;
data temp_bidon2; set temp_bidon2;
if _stat_ = 'MEAN' & quintilei='Q02' then do; call symput('Q1',&var); end; 
if _stat_ = 'MEAN' & quintilei='Q10' then do; call symput('Q5',&var); end;
run;

%let rapp_moy5 = %sysevalf(&Q5./&Q1.);

	proc sql;
	drop table temp_bidon2;
	quit;
%mend rapp_moy5;



%MACRO rapp10(data=,var=,pond=,Out=_rapp5_);
proc sort data=&data; by &var; run;
	proc univariate noprint data=&data;
		var &var;
		output out=temp_bidon2 pctlpts=10 90 pctlpre=quant 
				pctlname=i1 i2;
		freq &pond;
	run;
%global rapp10;
data temp_bidon2;
set temp_bidon2;
rapp=quanti2/quanti1;
call symput('rapp10',rapp);
run;

	proc sql;
	drop table temp_bidon2;
	quit;
%mend rapp10;


%Macro Kolm(data=,var=,pond=,alpha=0.3,pseudo=,where=,out=_kolm_);
%global kolm;
*on récupère la moyenne dans la globale moy.;
proc sql; 
SELECT sum(&var*&pond)/sum(&pond) into : moy
from &data ; 
quit; 

proc sql; 
select count(*) into : nbobs
from &data ; 
quit; 

data temp;
set &data(keep = &var &pond);
retain somme 0 pop 0;
somme = somme+exp( - %sysevalf(&alpha) * (&var-%sysevalf(&moy) )/1000)*&pond;
pop = pop +&pond;
if _n_= &nbobs then do; 
	valeur = 1/%sysevalf(&alpha) * log(somme/pop);
    call symput('kolm',valeur);
	end;
run;

%mend kolm; 


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
