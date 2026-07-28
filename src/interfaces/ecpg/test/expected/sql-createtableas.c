/* Processed by ecpg (regression mode) */
/* These include files are added by the preprocessor */
#include <ecpglib.h>
#include <ecpgerrno.h>
#include <sqlca.h>
/* End of automatic include section */
#define ECPGdebug(X,Y) ECPGdebug((X)+100,(Y))

#line 1 "createtableas.pgc"
#include <stdlib.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>


#line 1 "regression.h"






#line 6 "createtableas.pgc"


/* exec sql whenever sqlerror  sqlprint ; */
#line 8 "createtableas.pgc"


int
main(void)
{
	/* exec sql begin declare section */
		 
	
#line 14 "createtableas.pgc"
 int id ;
/* exec sql end declare section */
#line 15 "createtableas.pgc"


	ECPGdebug(1, stderr);
	{ ECPGconnect(__LINE__, 0, "ecpg1_regression" , NULL, NULL , NULL, 0); 
#line 18 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 18 "createtableas.pgc"


	{ ECPGsetcommit(__LINE__, "on", NULL);
#line 20 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 20 "createtableas.pgc"

	/* exec sql whenever sql_warning  sqlprint ; */
#line 21 "createtableas.pgc"

	/* exec sql whenever sqlerror  sqlprint ; */
#line 22 "createtableas.pgc"


	{ ECPGdo(__LINE__, 0, 1, NULL, 0, ECPGst_normal, "create table cta_test ( id int )", ECPGt_EOIT, ECPGt_EORT);
#line 24 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 24 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 24 "createtableas.pgc"

	{ ECPGdo(__LINE__, 0, 1, NULL, 0, ECPGst_normal, "insert into cta_test values ( 100 )", ECPGt_EOIT, ECPGt_EORT);
#line 25 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 25 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 25 "createtableas.pgc"


	{ ECPGdo(__LINE__, 0, 1, NULL, 0, ECPGst_normal, "create table if not exists cta_test1 as select * from cta_test", ECPGt_EOIT, ECPGt_EORT);
#line 27 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 27 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 27 "createtableas.pgc"

	{ ECPGdo(__LINE__, 0, 1, NULL, 0, ECPGst_normal, "select id from cta_test1", ECPGt_EOIT, 
	ECPGt_int,&(id),(long)1,(long)1,sizeof(int), 
	ECPGt_NO_INDICATOR, NULL , 0L, 0L, 0L, ECPGt_EORT);
#line 28 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 28 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 28 "createtableas.pgc"

	printf("ID = %d\n", id);

	{ ECPGdo(__LINE__, 0, 1, NULL, 0, ECPGst_normal, "create table cta_test2 as select * from cta_test with no data", ECPGt_EOIT, ECPGt_EORT);
#line 31 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 31 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 31 "createtableas.pgc"

	{ ECPGdo(__LINE__, 0, 1, NULL, 0, ECPGst_normal, "select count ( id ) from cta_test2", ECPGt_EOIT, 
	ECPGt_int,&(id),(long)1,(long)1,sizeof(int), 
	ECPGt_NO_INDICATOR, NULL , 0L, 0L, 0L, ECPGt_EORT);
#line 32 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 32 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 32 "createtableas.pgc"

	printf("ID = %d\n", id);

	/*
	 * The scanner turns WITH into WITH_LA_NO whenever NO follows it, so check
	 * that a CTE named "no" still parses.
	 */
	{ ECPGdo(__LINE__, 0, 1, NULL, 0, ECPGst_normal, "with no as ( select id from cta_test ) select id from no", ECPGt_EOIT, 
	ECPGt_int,&(id),(long)1,(long)1,sizeof(int), 
	ECPGt_NO_INDICATOR, NULL , 0L, 0L, 0L, ECPGt_EORT);
#line 39 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 39 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 39 "createtableas.pgc"

	printf("ID = %d\n", id);

	/* the clause the conversion exists for, on CREATE INDEX */
	{ ECPGdo(__LINE__, 0, 1, NULL, 0, ECPGst_normal, "create index cta_test_idx on cta_test ( id ) with no data", ECPGt_EOIT, ECPGt_EORT);
#line 43 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 43 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 43 "createtableas.pgc"

	{ ECPGdo(__LINE__, 0, 1, NULL, 0, ECPGst_normal, "select indisnodata :: int from pg_index where indexrelid = 'cta_test_idx' :: regclass", ECPGt_EOIT, 
	ECPGt_int,&(id),(long)1,(long)1,sizeof(int), 
	ECPGt_NO_INDICATOR, NULL , 0L, 0L, 0L, ECPGt_EORT);
#line 45 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 45 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 45 "createtableas.pgc"

	printf("ID = %d\n", id);

	{ ECPGdo(__LINE__, 0, 1, NULL, 0, ECPGst_normal, "drop index cta_test_idx", ECPGt_EOIT, ECPGt_EORT);
#line 48 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 48 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 48 "createtableas.pgc"

	{ ECPGdo(__LINE__, 0, 1, NULL, 0, ECPGst_normal, "drop table cta_test", ECPGt_EOIT, ECPGt_EORT);
#line 49 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 49 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 49 "createtableas.pgc"

	{ ECPGdo(__LINE__, 0, 1, NULL, 0, ECPGst_normal, "drop table cta_test1", ECPGt_EOIT, ECPGt_EORT);
#line 50 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 50 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 50 "createtableas.pgc"

	{ ECPGdo(__LINE__, 0, 1, NULL, 0, ECPGst_normal, "drop table cta_test2", ECPGt_EOIT, ECPGt_EORT);
#line 51 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 51 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 51 "createtableas.pgc"

	{ ECPGdisconnect(__LINE__, "ALL");
#line 52 "createtableas.pgc"

if (sqlca.sqlwarn[0] == 'W') sqlprint();
#line 52 "createtableas.pgc"

if (sqlca.sqlcode < 0) sqlprint();}
#line 52 "createtableas.pgc"


	return 0;
}
