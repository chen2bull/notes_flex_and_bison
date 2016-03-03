/* Companion source code for "flex & bison", published by O'Reilly
 * Media, ISBN 978-0-596-15597-1
 * Copyright (c) 2009, Taughannock Networks. All rights reserved.
 * See the README file for license conditions and contact info.
 * $Header: /home/johnl/flnb/code/RCS/fb2-4.l,v 2.1 2009/11/08 02:53:18 johnl Exp $
 */

/* fb2-4 text concordance */

%option noyywrap nodefault yylineno case-insensitive

/* the symbol table */
%{
  struct symbol {		/* a word */
    struct ref *reflist;
    char *name;
  };

  struct ref {
    struct ref *next;
    char *filename;
    int flags;
    int lineno;
  };

  /* simple symtab of fixed size */
  #define NHASH 9997
  struct symbol symtab[NHASH];

  struct symbol *lookup(char*);
  void addref(int, char*, char*, int);

  char *curfilename;		/* name of current input file */

%}
%%
 /* skip common words */
a |
an |
and |
are |
as |
at |
be |
but |
for |
in |
is |
it |
of |
on |
or |
that |
the |
this |
to                     /* ignore */

[a-z]+(\'(s|t))?   { addref(yylineno, curfilename, yytext, 0); }
.|\n                   /* ignore everything else */
%%

/* hash a symbol */
static unsigned symhash(char *sym)
{
  unsigned int hash = 0;
  unsigned c;

  while(c = *sym++) hash = hash*9 ^ c;

  return hash;
}

int nnew, nold;
int nprobe;

/*  symtab是使用线性探测的符号表
    函数功能是查找符号sym，如果查找不到，则创建新的条目
  */
struct symbol * lookup(char* sym)
{
  struct symbol *sp = &symtab[symhash(sym)%NHASH];
  int scount = NHASH;		/* how many have we looked at */

  while(--scount >= 0) {
    nprobe++;
    if(sp->name && !strcmp(sp->name, sym)) {    /* 已存在符号sym */
        nold++; return sp;
    }

    if(!sp->name) {     /* new entry */
      nnew++;
      /*    flex和bison程序经常会存在难以跟踪的字符串存储管理问题；
            因为yytext中的字符串会在下个词法记号被分析时，被替换掉；
            用strdup就是为了产生字符串的拷贝并放到符号表条目中。
      */
      sp->name = strdup(sym);   /* 如果不用这个字符串的话，要free的 */
      sp->reflist = 0;
      return sp;
    }

    if(++sp >= symtab+NHASH) sp = symtab; /* try the next entry */
  }
  fputs("symbol table overflow\n", stderr);
  abort(); /* tried them all, table is full */

}

/*  添加对特定单词的引用
    注意这个函数并不创建文件名的拷贝，也不拷贝单词
 */
void addref(int lineno, char *filename, char *word, int flags)
{
  struct ref *r;
  struct symbol *sp = lookup(word);

  /* 如果符号已经有一个队相同行号和文件名的引用，则不会添加它。
     可以使符号表小一点。
  */
  if(sp->reflist &&
     sp->reflist->lineno == lineno && sp->reflist->filename == filename) return;

  r = malloc(sizeof(struct ref));
  if(!r) {fputs("out of space\n", stderr); abort(); }
  r->next = sp->reflist;
  r->filename = filename;
  r->lineno = lineno;
  r->flags = flags;
  sp->reflist = r;
}

/* print the references
 * sort the table alphabetically
 * then flip each entry's reflist to get it into forward order
 * and print it out 
 */

/* aux function for sorting */
static int symcompare(const void *xa, const void *xb)
{
  const struct symbol *a = xa;
  const struct symbol *b = xb;

  if(!a->name) {
    if(!b->name) return 0;	/* both empty */
    return 1;			/* put empties at the end */
  }
  if(!b->name) return -1;
  return strcmp(a->name, b->name);
}

void printrefs()
{
  struct symbol *sp;

  qsort(symtab, NHASH, sizeof(struct symbol), symcompare); /* sort the symbol table */

  for(sp = symtab; sp->name && sp < symtab+NHASH; sp++) {
    char *prevfn = NULL;	/* last printed filename, to skip dups */

    /* reverse the list of references!! */
    struct ref *rp = sp->reflist;
    struct ref *rpp = 0;	/* previous ref */
    struct ref *rpn;	/* next ref */
    do {
      rpn = rp->next;
      rp->next = rpp;
      rpp = rp;
      rp = rpn;
    } while(rp);

    /* now print the word and its references */
    printf("%10s", sp->name);
    for(rp = rpp; rp; rp = rp->next) {
      if(rp->filename == prevfn) {
        printf(" %d", rp->lineno);
      } else {
        printf(" %s:%d", rp->filename, rp->lineno);
        prevfn = rp->filename;
      }
    }
    printf("\n");
  }
}

main(argc, argv)
int argc;
char **argv;
{
  int i;

  if(argc < 2) { /* just read stdin */
    curfilename = "(stdin)";
    yylineno = 1;
    yylex();
  } else
  for(i = 1; i < argc; i++) {
    FILE *f = fopen(argv[i], "r");
  
    if(!f) {
      perror(argv[1]);
      return (1);
    }
    curfilename = argv[i];	/* for addref */

    yyrestart(f);
    yylineno = 1;
    yylex();
    fclose(f);
  }

  /* 打印统计信息 */
  printf("old = %d, new = %d, total = %d, probes = %d, avg = %1.2f\n", nold, nnew, nold+nnew, nprobe, (float)nprobe / (nold+nnew));

  printrefs();
}

