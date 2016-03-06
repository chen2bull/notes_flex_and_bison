/* Companion source code for "flex & bison", published by O'Reilly
 * Media, ISBN 978-0-596-15597-1
 * Copyright (c) 2009, Taughannock Networks. All rights reserved.
 * See the README file for license conditions and contact info.
 * $Header: /home/johnl/flnb/code/RCS/fb3-2.y,v 2.1 2009/11/08 02:53:18 johnl Exp $
 */
/* calculator with AST */

%{
#  include <stdio.h>
#  include <stdlib.h>
#  include "fb3-2.h"
%}

%union {
  struct ast *a;
  double d;
  struct symbol *s;		/* which symbol */
  struct symlist *sl;
  int fn;			/* which function */
}
/*
    union 用来声明 语法分析器中符号值的类型。也就是影响YYSTYPE这个union类型的定义。
    而yylval的类型就是YYSTYPE */

/* declare tokens */
%token <d> NUMBER
%token <s> NAME
%token <fn> FUNC
%token EOL

%token IF THEN ELSE WHILE DO LET


%nonassoc <fn> CMP
/*  right表示该操作符号是右结合的，
    nonassoc表示该符号没有优先级
    符号出现的顺序指定了优先级
    */
%right '='
%left '+' '-'
%left '*' '/'
%nonassoc '|' UMINUS

/*  一旦使用%union声明，我们需要告诉bison每种语法符号使用的值类型 通过<和>中的联合体成员名字来确定。
    “tonken <d> NUMBER”表示NUMBER通过符号<d>来保存具体的数值
    type声明把值<a>赋给exp、factor和term。
    当声明中存在%union时，如果试图使用一个没有被赋予类型的符号值，bison将会报错。
    规则中如果没有显示的语义动作代码是，规则将使用语义动作$$ = $1。

 */
%type <a> exp stmt list explist
%type <sl> symlist

%start calclist

%%

stmt: IF exp THEN list           { $$ = newflow('I', $2, $4, NULL); }
   | IF exp THEN list ELSE list  { $$ = newflow('I', $2, $4, $6); }
   | WHILE exp DO list           { $$ = newflow('W', $2, $4, NULL); }
   | exp
;

list: /* nothing */ { $$ = NULL; }
   | stmt ';' list { if ($3 == NULL)
	                $$ = $1;
                      else
			$$ = newast('L', $1, $3);
                    }
   ;

exp: exp CMP exp          { $$ = newcmp($2, $1, $3); }
   | exp '+' exp          { $$ = newast('+', $1,$3); }
   | exp '-' exp          { $$ = newast('-', $1,$3);}
   | exp '*' exp          { $$ = newast('*', $1,$3); }
   | exp '/' exp          { $$ = newast('/', $1,$3); }
   | '|' exp              { $$ = newast('|', $2, NULL); }
   | '(' exp ')'          { $$ = $2; }
   | '-' exp %prec UMINUS { $$ = newast('M', $2, NULL); }   /* 用prec 可以让bison把UMINUS的优先级赋予这个规则 */
   | NUMBER               { $$ = newnum($1); }
   | FUNC '(' explist ')' { $$ = newfunc($1, $3); }
   | NAME                 { $$ = newref($1); }
   | NAME '=' exp         { $$ = newasgn($1, $3); }
   | NAME '(' explist ')' { $$ = newcall($1, $3); }
;

explist: exp
 | exp ',' explist  { $$ = newast('L', $1, $3); }
;
symlist: NAME       { $$ = newsymlist($1, NULL); }
 | NAME ',' symlist { $$ = newsymlist($1, $3); }
;

calclist: /* nothing */
  | calclist stmt EOL {
    if(debug) dumpast($2, 0);
     printf("= %4.4g\n> ", eval($2));
     treefree($2);
    }
  | calclist LET NAME '(' symlist ')' '=' list EOL {
                       dodef($3, $5, $8);
                       printf("Defined %s\n> ", $3->name); }

  | calclist error EOL { yyerrok; printf("> "); }
 ;
%%
