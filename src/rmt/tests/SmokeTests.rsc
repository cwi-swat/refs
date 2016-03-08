module rmt::tests::SmokeTests

import rmt::lang::Activities;
import rmt::meta::Activities;
import rmt::meta::Statemachines;
import rmt::meta::MetaModels;
import rmt::trafo::StatemachineTrafos;
import rmt::trafo::MetaModelTrafos;
import rmt::trafo::ActivityExecution;
import rmt::Refs;
import ParseTree;
import IO;
import util::FileSystem;
import Set;
import util::Benchmark;


data BinTree(Id uid = noId())
  = bin(BinTree l, BinTree r)
  | leaf(Ref[BinTree] xref)
  ;



void benchmarkLookup(Realm r) {

  BinTree init(int n) {
      if (n == 0) {
        return r.new(#BinTree, leaf(null()));
      }
      lhs = init(n - 1);
      rhs = init(n - 1);
      return r.new(#BinTree, bin(lhs, rhs));
  }
  
  bt = init(8);
  
  bins = { b | /b:bin(_, _) := bt };

  cur = bins;

  bt = bottom-up-break visit (bt) {
    case l:leaf(_): {
      <h, cur> = takeOneFrom(cur);
      if (cur == {}) {
        println("resetting");
        cur = bins;
      }
      insert l[xref=referTo(#BinTree, h)];
    }  
  }
 
  refs = { r | /Ref[BinTree] r := bt };
  println("Starting benchmark lookup memo 1st time");
  ns = realTime( () {
    for (x <- refs) {
      lookup(bt, #BinTree, x);
    }
  });
  println("Done: <ns>"); 
  println("Starting benchmark lookup memo 2nd time");
  ns = realTime( () {
    for (x <- refs) {
      lookup(bt, #BinTree, x);
    }
  });
  println("Done: <ns>");

  println("Starting benchmark lookup rec memo 1st time");
  ns = realTime( () {
    for (x <- refs) {
      lookup_(bt, #BinTree, x);
    }
  });
  println("Done: <ns>");
  println("Starting benchmark lookup rec memo 2nd time");
  ns = realTime( () {
    for (x <- refs) {
      lookup_(bt, #BinTree, x);
    } 
  });
  println("Done: <ns>");
}


void allSmokeTests() {
  smokeTestBuilding();
  smokeTestTrafos();
}

void smokeTestBuilding() {
  println("# BUILDING");
  println("## Statemachines");
  println("abc");
  abc(newRealm()); 
  println("doors");
  doors(newRealm());
  println("nfa");
  nfa(newRealm());
  
  println("## MetaModels");
  println("metaMeta");
  metaMeta(newRealm());
  
  println("## Activities");
  println("Manual building");
  exampleActivity6(newRealm());
  tests = find(|project://rascal-mt/inputs|, "ad");
  for (t <- tests) {
     println("Testing loading of <t>");
     ad = parse(#start[ActivityDef], t);
     activityFromSource(newRealm(), ad);
  }
  
}

void smokeTestTrafos() {
  println("# TRANSFORMATION");
  println("## Statemachines");
  theAbc = abc(newRealm());
  theDoors = doors(newRealm());
  theNfa = nfa(newRealm());
  
  println("### statemachine2Graph");
  println("abc");
  statemachine2Graph(newRealm(), theAbc); 
  println("doors");
  statemachine2Graph(newRealm(), theDoors);
  println("nfa");
  statemachine2Graph(newRealm(), theNfa);
  
  println("### parallelMerge");
  println("abc + abc");
  parallelMerge(newRealm(), theAbc, theAbc); 
  println("doors + doors");
  parallelMerge(newRealm(), theDoors, theDoors); 
  println("doors + abc");
  parallelMerge(newRealm(), theDoors, theAbc); 
  println("nfa + abc");
  parallelMerge(newRealm(), theNfa, theAbc); 

  println("### toDFA");
  println("abc");
  toDFA(newRealm(), theAbc); 
  println("doors");
  toDFA(newRealm(), theDoors); 
  println("nfa");
  toDFA(newRealm(), theNfa);
  
  
  
  println("## MetaModels");
  
  println("metaMeta2graph");
  metaModel2Graph(newRealm(), metaMeta(newRealm()));

  println("metaMeta2schema");
  metaModel2Schema(newRealm(), metaMeta(newRealm()));
  println("metaMeta2Java");
  metaModel2Java(metaMeta(newRealm()));
  println("flattenInheritance on metaMeta");
  r = newRealm();
  flattenInheritance(r, metaMeta(r));
  println("generalizeTypeRefs on metaMeta");
  generalizeTypeRefs(metaMeta(newRealm()));

  println("## Activity diagrams");
  println("### Execute");
  
  println("example6 with input true");
  r = newRealm();
  a = exampleActivity6(r);
  setRealm(r);
  main(a, [inputValue(booleanValue(true), referTo(#Variable, a.inputs[0]))]);
  
  println("example6 with input false");
  r = newRealm();
  a = exampleActivity6(r);
  setRealm(r);
  main(a, [inputValue(booleanValue(false), referTo(#Variable, a.inputs[0]))]);
}
