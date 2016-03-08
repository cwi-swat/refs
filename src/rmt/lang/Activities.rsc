module rmt::lang::Activities

import rmt::Refs;
import rmt::meta::Activities;
import String;

extend lang::std::Layout;

start syntax ActivityDef = "activity" Ident name "(" {Formal ","}* formals ")" "{" Decl* decls "}";

start syntax Inputs = Input* inputs;
syntax Input = Ident x "=" Val val;
  
syntax Formal = Type type Ident name;
  
syntax Decl
  = localInit: Type type Ident var "=" Val val
  | local: Type type Ident var 
  | nodes: "nodes" "{" {NodeDecl ","}* nodes "}"
  | edges: "edges" "{" {EdgeDecl ","}* edges "}"
  ;
  
syntax Val
  = \true: "true"
  | \false: "false"
  | \num: Num
  ;
  
lexical Num = [0-9]+ !>> [0-9];


lexical NIdent = @category="MetaKeyword" Ident;

syntax NodeDecl
  // In* and Out* because optional matching does not work.
  = normal: NIdent type Ident name In* Out* 
  | action: "action" Ident name Exprs? In* Out* 
  ;
  
syntax Exprs = "{" {Expr ","}* exprs "}"; 
  
syntax Expr
  = add: Ident var "=" Ident lhs "+" Ident rhs
  | sub: Ident var "=" Ident lhs "-" Ident rhs
  | lt: Ident var "=" Ident lhs "\<" Ident rhs
  | leq: Ident var "=" Ident lhs "\<=" Ident rhs
  | gt: Ident var "=" Ident lhs "\>" Ident rhs
  | geq: Ident var "=" Ident lhs "\>=" Ident rhs
  | geq: Ident var "=" Ident lhs "==" Ident rhs
  | and: Ident var "=" Ident lhs "&&" Ident rhs
  | or: Ident var "=" Ident lhs "||" Ident rhs
  | not: Ident var "=" "!" Ident arg
  ;
  
syntax Out = "out" "(" {Ident ","}* edges ")";

syntax In = "in" "(" {Ident ","}* edges ")";
  
syntax EdgeDecl = "flow" Ident name "from" Ident from "to" Ident to Guard? guardOpt;
  
syntax Guard = "[" Ident var "]";

lexical Ident = ([a-zA-Z][0-9A-Za-z_]* !>> [0-9A-Za-z_]) \ Reserved;

keyword Reserved = "action";

syntax Type = \bool: "bool" | \int: "int";


Activity activityFromSource(Realm realm, start[ActivityDef] d) {

  Variable newVar((Type)`int`, Ident x) = realm.new(#Variable, integerVariable("<x>"));
  Variable newVar((Type)`bool`, Ident x) = realm.new(#Variable, booleanVariable("<x>"));

  Value makeValue((Val)`true`) = booleanValue(true);
  Value makeValue((Val)`false`) = booleanValue(false);
  Value makeValue((Val)`<Num n>`) = integerValue(toInt("<n>"));
  
  inputs = ( x: newVar(t, x) | (Formal)`<Type t> <Ident x>` <- d.top.formals );
  locals = ( x: newVar(t, x) | (Decl)`<Type t> <Ident x>` <- d.top.decls )
         + ( x: newVar(t, x)[initial=just(makeValue(v))] | (Decl)`<Type t> <Ident x> = <Val v>` <- d.top.decls );
            
  vars = inputs + locals;
  
  
  Expression expr2expression(Expr e) {
    switch (e) {
      case (Expr)`<Ident x> = <Ident lhs> + <Ident rhs>`:
        return integerCalculationExpression(referTo(#Variable, vars[x]), add(), referTo(#Variable, vars[lhs]), referTo(#Variable, vars[rhs]));

	  case (Expr)`<Ident x> = <Ident lhs> - <Ident rhs>`:
        return integerCalculationExpression(referTo(#Variable, vars[x]), sub(), referTo(#Variable, vars[lhs]), referTo(#Variable, vars[rhs]));
	    
	  case (Expr)`<Ident x> = <Ident lhs> \< <Ident rhs>`:
        return integerComparisonExpression(referTo(#Variable, vars[x]), smaller(), referTo(#Variable, vars[lhs]), referTo(#Variable, vars[rhs]));
	    
	  case (Expr)`<Ident x> = <Ident lhs> \<= <Ident rhs>`:
        return integerComparisonExpression(referTo(#Variable, vars[x]), smallerEquals(), referTo(#Variable, vars[lhs]), referTo(#Variable, vars[rhs]));
	    
	  case (Expr)`<Ident x> = <Ident lhs> \> <Ident rhs>`:
        return integerComparisonExpression(referTo(#Variable, vars[x]), greater(), referTo(#Variable, vars[lhs]), referTo(#Variable, vars[rhs]));
	    
	  case (Expr)`<Ident x> = <Ident lhs> \>= <Ident rhs>`:
        return integerComparisonExpression(referTo(#Variable, vars[x]), greaterEquals(), referTo(#Variable, vars[lhs]), referTo(#Variable, vars[rhs]));
	    
	  case (Expr)`<Ident x> = <Ident lhs> == <Ident rhs>`:
        return integerComparisonExpression(referTo(#Variable, vars[x]), equals(), referTo(#Variable, vars[lhs]), referTo(#Variable, vars[rhs]));
	    
	  case (Expr)`<Ident x> = <Ident lhs> && <Ident rhs>`:
	    return booleanBinaryExpression(referTo(#Variable, vars[x]), and(), referTo(#Variable, vars[lhs]), referTo(#Variable, vars[rhs]));
	    
	  case (Expr)`<Ident x> = <Ident lhs> || <Ident rhs>`:
        return booleanBinaryExpression(referTo(#Variable, vars[x]), or(), referTo(#Variable, vars[lhs]), referTo(#Variable, vars[rhs]));
	    
	  case (Expr)`<Ident x> = !<Ident arg>`:
        return  booleanUnaryExpression(referTo(#Variable, vars[x]), not(), referTo(#Variable, vars[arg]));
      
      default: throw "missed a case: <e>";
    }
  }
  
  nodes = ();
  
  for ((Decl)`nodes {<{NodeDecl ","}* nds>}` <- d.top.decls, NodeDecl nd <- nds) {
    switch (nd) {
      case (NodeDecl)`merge <Ident x> <In* _> <Out* _>`:
         nodes[x] = realm.new(#ActivityNode, mergeNode("<x>"));
      case (NodeDecl)`decision <Ident x> <In* _> <Out* _>`:
         nodes[x] = realm.new(#ActivityNode, decisionNode("<x>"));
      case (NodeDecl)`join <Ident x> <In* _> <Out* _>`:
         nodes[x] = realm.new(#ActivityNode, joinNode("<x>"));
      case (NodeDecl)`fork <Ident x> <In* _> <Out* _>`:
         nodes[x] = realm.new(#ActivityNode, forkNode("<x>"));
      case (NodeDecl)`initial <Ident x> <In* _> <Out* _>`:
         nodes[x] = realm.new(#ActivityNode, initialNode("<x>"));
      case (NodeDecl)`final <Ident x> <In* _> <Out* _>`:
         nodes[x] = realm.new(#ActivityNode, activityFinalNode("<x>"));
         
      case (NodeDecl)`action <Ident x> <Exprs e> <In* _> <Out* _>`:
         nodes[x] = realm.new(#ActivityNode, opaqueAction("<x>",
                  expressions=[ expr2expression(exp) | exp <- e.exprs ]));

      case (NodeDecl)`action <Ident x> <In* _> <Out* _>`:
         nodes[x] = realm.new(#ActivityNode, opaqueAction("<x>"));
         
      default: throw "Missed a case: <nd>";
    }
  }
  
  edges = ();
  
  for ((Decl)`edges {<{EdgeDecl ","}* eds>}` <- d.top.decls, EdgeDecl ed <- eds) {
    switch (ed) {
      case (EdgeDecl)`flow <Ident x> from <Ident from> to <Ident to>`:
        edges[x] = realm.new(#ActivityEdge, activityEdge("<x>",
           referTo(#ActivityNode, nodes[from]), referTo(#ActivityNode, nodes[to])));
      
      case (EdgeDecl)`flow <Ident x> from <Ident from> to <Ident to> [<Ident g>]`:
        edges[x] = realm.new(#ActivityEdge, controlFlow("<x>",
           referTo(#ActivityNode, nodes[from]), referTo(#ActivityNode, nodes[to]), referTo(#Variable, vars[g])));
           
      default: throw "missed a case <ed>";
    }
  }
  
  for ((Decl)`nodes {<{NodeDecl ","}* nds>}` <- d.top.decls, NodeDecl nd <- nds) {
    switch (nd) {
      case (NodeDecl)`<Ident _> <Ident x> <In inn> <Out out>`: {
         nodes[x].outgoing = [ referTo(#ActivityEdge, edges[e]) | e <- out.edges ];
         nodes[x].incoming = [ referTo(#ActivityEdge, edges[e]) | e <- inn.edges ];
      }
      
      case (NodeDecl)`<Ident _> <Ident x> <Out out>`: 
         nodes[x].outgoing = [ referTo(#ActivityEdge, edges[e]) | e <- out.edges ];

      case (NodeDecl)`<Ident _> <Ident x> <In inn>`: 
         nodes[x].incoming = [ referTo(#ActivityEdge, edges[e]) | e <- inn.edges ];

      case (NodeDecl)`action <Ident x> <Exprs? _> <In inn> <Out out>`: {
         nodes[x].outgoing = [ referTo(#ActivityEdge, edges[e]) | e <- out.edges ];
         nodes[x].incoming = [ referTo(#ActivityEdge, edges[e]) | e <- inn.edges ];
      }
      case (NodeDecl)`action <Ident x> <Exprs? _> <Out out>`: 
         nodes[x].outgoing = [ referTo(#ActivityEdge, edges[e]) | e <- out.edges ];

      case (NodeDecl)`action <Ident x> <Exprs? _> <In inn>`: 
         nodes[x].incoming = [ referTo(#ActivityEdge, edges[e]) | e <- inn.edges ];
         
      default: throw "missed a case <nd>";
    }
  }

  return realm.new(#Activity, activity("<d.top.name>", 
     [ locals[x] | x <- locals], [ inputs[x] | x <- inputs ],  
     [ nodes[x] | x <- nodes ], [ edges[x] | x <- edges ]));

}