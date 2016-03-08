module rmt::tests::ActivityTests

import rmt::lang::Activities;
import rmt::meta::Activities;
import rmt::trafo::ActivityExecution;
import util::FileSystem;
import ParseTree;
import rmt::Refs;
import IO;
import String;
import util::Benchmark;

Variable findInputVariable(str name, Activity a)
  = v
 when v <- a.inputs, v.name == name;

void printTrace(Activity a) {
  println("TRACE for <a.name>");
  for (r <- a.trace.executedNodes, ActivityNode n := lookup(a, #ActivityNode, r)) {
    println("node = <n.name>");
  }
}

rel[loc, Opt[loc], int] testAll() {

 results = {};
 tests = find(|project://rascal-mt/inputs|, "ad");
 inputs = find(|project://rascal-mt/inputs|, "adinput");
 traces = find(|project://rascal-mt/inputs|, "txt");
 for (t <- tests) {
   println("Testing: <t>");
   if (contains(t.path, "performance_variant2")) {
     println("skipped");
     continue;
   }
   ad = parse(#start[ActivityDef], t);
   os = newRealm();
   a = activityFromSource(os, ad);
   setRealm(os);
   params = [];
   hadInput = false;
   Activity a2;
   for (anInput <- inputs, contains(anInput.file, t.file[0..-3])) {
     hadInput = true;
     println("...with input <anInput>");
     
     Inputs d = parse(#Inputs, anInput);
     for (Input inp <- d.inputs) {
      switch (inp) {
       case (Input)`<Ident x> = true`: 
         params += [ inputValue(booleanValue(true), referTo(findInputVariable("<x>", a))) ];
       case (Input)`<Ident x> = false`: 
         params += [ inputValue(booleanValue(false), referTo(findInputVariable("<x>", a))) ];
       case (Input)`<Ident x> = <Num n>`: 
         params += [ inputValue(integerValue(toInt("<n>")), referTo(findInputVariable("<x>", a))) ];
      }
     }
     //println(params);
     ns = realTime( () { a2 = main(a, params); }); 
     results += {<t, just(anInput), ns>};
   }
   
   if (!hadInput) {
     ns = realTime( () { a2 = main(a, params); }); 
     results += {<t, none(), ns>};
   } 
   
   printTrace(a2);
 }
 return results; 
}

