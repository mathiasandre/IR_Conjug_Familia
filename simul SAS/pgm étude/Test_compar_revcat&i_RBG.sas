	data test_revind (where=(abs(test_somme_revind)>1 and bicmicp=0 and bicmicnp=0  and bicauto=0 and defagr=0)
		keep=  declar  rev_cat: revind: rev5 bicmicp bicmicnp bicauto pv:/* rs indivs*/
		_6gh _8tk revind: /* rs agrégés */
		rbg somme_revind test_somme_revind deficitric:
		zbag: _5ic _5ie _5if
		revagr defagr deficitagr:); 
		set modele.rbg14;
		deficitric1=_5rn+_5ro;
		deficitric2=_5rp+_5rq;
		deficitric3=_5rr+_5rw;
		deficitric4=0;
		deficitagr1=_5qf+_5qg;
		deficitagr2=_5qn+_5qo;
		deficitagr3=_5qp+_5qq;
		deficitagr4=0;
		zbicnp_1=zbicnp_v;
		zbicnp_2=zbicnp_c;
		zbicnp_3=zbicnp_p1;
		zbicnp_4=0;
		zbag_1=zbag_v;
		zbag_2=zbag_c;
		zbag_3=zbag_p1;
		zbag_4=0;
		zbag_1_cga=zbag_v_cga;
		zbag_2_cga=zbag_c_cga;
		zbag_3_cga=zbag_p1_cga;
		zbag_4_cga=0;
		%macro ajust_revind_deficit;
		%do i=1 %to 4;
		revind&i.=revind&i.
		/* 1.  on applique les déficit agricaux et bic */ 
		+(max(zbicnp_&i.-deficitric&i.,0)-zbicnp_&i.)*(zbicnp_&i.-deficitric&i.>=0)+(max(zbag_&i.+zbag_&i._cga-deficitagr&i.,0)-zbag_&i.-zbag_&i._cga)*(zbag_&i.+zbag_&i._cga-defagr>=0);
		%end;
		%mend;
		%ajust_revind_deficit;

		/* 2.  on enlève les exos (celles agrégées dans rbg_caf mais déduites dans rbg)...*/ 
		exo_1=(_5nn+_5nb+_5nh+_5th+_5hk+_5ik+_5hn+_5hb+_5hh+_5kn+_5kb+_5kh+_5hp+_5qb+_5qh);
		exo_2=(_5on+_5ob+_5oh+_5uh+_5jk+_5kk+_5in+_5ib+_5ih+_5ln+_5lb+_5lh+_5ip+_5rb+_5rh);
		exo_3=(_5pn+_5pb+_5ph+_5vh+_5lk+_5mk+_5jn+_5jb+_5jh+_5mn+_5mb+_5mh+_5jp+_5sb+_5sh);
		/* ....et les + values taxables à 16% (celles agrégées dans rbg_caf mais pas dans rbg puisque taxables à 16%)
		On en profite pour les individualiser pour plus tard */
		PVT_1=&P0750.*(_5hx+_5he+_5kq-_5kr+_5ke+_5nq-_5nr+_5ne+_5kv-_5kw+_5so+_5hr-_5hs+_5qd);
		PVT_2=&P0750.*(_5ix+_5ie+_5lq-_5lr+_5oq-_5or+_5le+_5oe+_5lv-_5lw+_5nt+_5ir-_5is+_5rd);
		PVT_3=&P0750.*(_5jx+_5je+_5mq-_5mr+_5pq-_5pr+_5me+_5pe+_5mv-_5mw+_5ot+_5jr-_5js+_5sd);

		revind1=revind1-(PVT_1/&P0750.+exo_1);
		revind2=revind2-(PVT_2/&P0750.+exo_2);
		revind3= revind3-(PVT_3/&P0750.+exo_3);

		somme_revind=sal1-deduc1+sal2-deduc2+sal3-deduc3+sal4-deduc4+sal5-deduc5
		+prb1-abatt1+prb2-abatt2+prb3-abatt3+prb4-abatt4+prb5-abatt5
		+sum(of RV1-RV4)+rev2+rev3+rev4
		+revind1+revind2+revind3+revind4
		+_6gh+_8tk;
		/* le déficit agricole est en fait déjà retiré dans revind lorsque la condition de plafond est respectée : pb elle est retirée aussi lorsque la condition de plafond n'est pas respectée
		IF somme_revind<=&P0320. AND defagr>0 THEN do; 
		somme_revind=somme_revind-defagr;
		end;
		*/
		somme_revind=max(somme_revind-deficit_ant, 0);
		test_somme_revind=somme_revind-rbg;
		run;


	/* autre table de test */

data test_exo;
	set test_revind;
	keep exo: rbg 
		somme_revind test_somme_revind zbnc_:;
	where exo ne 0;
	run;


	/* autre table de test */

data test_exo;
	set test_revind;
	keep exo: rbg 
		somme_revind test_somme_revind zbnc_:;
	where exo ne 0;
	run;


/* quelques stats sur les parts et les revenus individualisables*/
data test_part; 
	set modele.rbg&anr1. (keep = ident declar r: _6gh _8tk part:); 
	Part_non_individuelle=rev2+rev3+rev4+_6gh+_8tk+RV;
run;

%cumul(basein=  test_part,
	   baseout= revnonindiv,
	   varin=   RBG Part_non_individuelle,
	   varout=  RBG Part_non_individuelle,
	   varAgregation= ident);
data basemen(keep=ident poi ratio_non_ind);
	merge 	modele.basemen (in=a) 
			revnonindiv (where=(ident^='') in=b);
	by ident;
	if a;
	ratio_non_ind = 0;
	if RBG ne 0 then ratio_non_ind = Part_non_individuelle/RBG;
run;

proc univariate data = basemen;
	var ratio_non_ind;
		freq poi;
run;
