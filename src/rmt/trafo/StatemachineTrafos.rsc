module rmt::trafo::StatemachineTrafos

import rmt::meta::Statemachines;
import rmt::meta::Graphs;
import rmt::meta::RegExps;

import rmt::Refs;
import IO;
import Set;
import List;

import rmt::util::Visualize;

/*
 Some notes
  - always add to container, after modifications
  - lookups are scoped, so need root.
  - tracking side effects via tables.
  - removing something from container, might cause dangling reference.
*/

Graph machine2graph(Realm realm, Machine m){
    nodes = (s: realm.new(#Node, \node(s.name)) | s <- m.states );
    edges = { edge(t.event, referTo(#Node, nodes[s1]), referTo(#Node, nodes[s2])) | s1 <- m.states, t <- s1.transitions, s2 := lookup(m, #State, t.to) };
    return realm.new(#Graph, graph(nodes<1>, edges));
}

void renderMachine(str name, Realm realm, Machine m, tuple[int,int] size = <800,800>){
    render(visualize(name, machine2graph(realm, m), size=size));
}

void tstDoors() {
  realm = newRealm();
  dm = doors(realm);

  println(dm);
  for (s <- dm.states) {
    println("State <s>");
    println("uid = <s.uid>");
    for (t <- s.transitions) {
       println("on <t.event>");
       println(t);
       State to = lookup(dm, #State, t.to);
       println("to <to>");
    }
  }
  
  println(machine2graph(realm, dm));
  renderMachine("doors", realm, dm, size=<150,200>);
  
}

Machine regexp2statemachine(Realm realm, RegExp regexp) {
   sn = -1;
   memo = ();
   int newState() {
     sn += 1;
     memo[sn] = realm.new(#State, state("s<sn>", []));
     return sn;
   }

   tuple[int,int] regexp2state(event(x)) {
     s1 = newState();
     s2 = newState();
     memo[s1].transitions += [trans(x, referTo(#State, memo[s2]))];
     return <s1, s2>;
   }
   
   tuple[int,int] regexp2state(empty()) 
     = regexp2state(event(""));
   
   tuple[int,int] regexp2state(sequence(rs)) {
     ss = [ regexp2state(r) | r <- rs ];
     return <ss[0][0], ss[-1][1]>;
   }
   
   tuple[int,int] regexp2state(choice(rs)) {
     ss = [ regexp2state(r) | r <- rs ];
     s1 = newState();
     s2 = newState();
     memo[s1].transitions += [trans("", referTo(#State, memo[s[0]])) | s <- ss];
     for (s <- ss) {
       memo[s[1]].transitions += [trans("", referTo(#State, memo[s2]))];
     }
     return <s1, s2>;
   }
   
   tuple[int,int] regexp2state(repeat(r)) {
     s1 = newState();
     s2 = newState();
     <s, f> = regexp2state(r);
     memo[f].transitions += [trans("", referTo(#State, memo[s]))]; // back edge
     memo[s1].transitions += [trans("", referTo(#State, memo[s]))]; // to loop
     memo[f].transitions += [trans("", referTo(#State, memo[s2]))]; // from loop
     memo[s1].transitions += [trans("", referTo(#State, memo[s2]))]; // skip loop
     return <s1, s2>;
   }
   
   <s, f> = regexp2state(regexp);
   
   m = realm.new(#Machine, machine("regexp", []));
   m.states += [memo[s]] + [ memo[k] | k <- memo, k != s ];
   return m;
}

str statemachine2java(Machine m, str method) {
  // assuming state names are unique.
}


Graph statemachine2Graph(Realm realm, Machine m) {
   g = realm.new(#Graph, graph({}, {}));
   ns = ( s: realm.new(#Node, \node(s.name)) | s <- m.states );
   g.edges = { realm.new(#Edge, edge(e, referTo(#Node, ns[s]), referTo(#Node, ns[t]))) 
                | /s:state(_, /trans(e, r)) := m , State t := lookup(m, #State, r) };
   g.nodes = ns<1>;
   return g;
}

Machine addResetTransitions(set[str] events, Realm realm, Machine m) {
  // currently, trans does not have identity, so no new and a variable suffices.
  resets = [ trans(e, referTo(#State, m.states[0])) | e <- events ];
  
  return visit (m) { case s:state(_, ts) => s[transitions=ts + resets] } 
}

void tstAddResetTransitions(){
    realm = newRealm();
    dm = doors(realm);  
    dm1 =addResetTransitions({"reset"}, realm, dm);
    iprintln(statemachine2Graph(realm, dm1));
    renderMachine("doors", realm, dm1, size=<1000,1000>);
}

Machine parallelMerge(Realm realm, Machine m1, Machine m2) {
  memo = ();
  
  State merge(State s1, State s2) {
    nn = "<s1.name>__<s2.name>";
  
    if (nn in memo)
      return memo[nn];
    
    memo[nn] = realm.new(#State, state(nn, []));
    
    e1 = [ e | trans(e, _) <- s1.transitions ];
    e2 = [ e | trans(e, _) <- s2.transitions ];
    both = e1 & e2;
    
    memo[nn].transitions 
        = [ trans(e, referTo(#State, merge(t1, t2))) | e <- both,
                  trans(e, u1) <- s1.transitions, State t1 := lookup(m1, #State, u1), 
                  trans(e, u2) <- s2.transitions, State t2 := lookup(m2, #State, u2) ]
        + [ trans(e, referTo(#State, merge(t1, s2))) | e <- e1 - both, 
                  trans(e, u1) <- s1.transitions, State t1 := lookup(m1, #State, u1) ] 
        + [ trans(e, referTo(#State, merge(s1, t2))) | e <- e2 - both, 
                  trans(e, u2) <- s2.transitions, State t2 := lookup(m2, #State, u2) ];

    return memo[nn];
  }
  
  init = merge(m1.states[0], m2.states[0]);
  
  return realm.new(#Machine, machine("<m1.name>_<m2.name>",
     [init] + [ memo[k] | k <- memo, memo[k] != init ]));
}


// Examples from http://web.cecs.pdx.edu/~harry/compilers/slides/LexicalPart3.pdf
Machine nfa(Realm realm){
  s0 = realm.new(#State, state("s0", []));
  s1 = realm.new(#State, state("s1", []));
  s2 = realm.new(#State, state("s2", []));
  s3 = realm.new(#State, state("s3", []));
  s4 = realm.new(#State, state("s4", []));   
  s5 = realm.new(#State, state("s5", [])); 
  s6 = realm.new(#State, state("s6", []));
  s7 = realm.new(#State, state("s7", []));
  s8 = realm.new(#State, state("s8", []));
  s9 = realm.new(#State, state("s9", []));
  s10 = realm.new(#State, state("s10", []));
  
  s0.transitions = [trans("", referTo(#State, s1)), trans("", referTo(#State, s7))];
  s1.transitions = [trans("", referTo(#State, s2)), trans("", referTo(#State, s4))];
  s2.transitions = [trans("a", referTo(#State, s3))];
  s3.transitions = [trans("", referTo(#State, s6))];
  s4.transitions = [trans("b", referTo(#State, s5))];
  s5.transitions = [trans("", referTo(#State, s6))];
  s6.transitions = [trans("", referTo(#State, s1)), trans("", referTo(#State, s7))];
  s7.transitions = [trans("a", referTo(#State, s8))];
  s8.transitions = [trans("b", referTo(#State, s9))];
  s9.transitions = [trans("b", referTo(#State, s10))];
  
  return realm.new(#Machine, machine("nfa1", [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10]));
}


Machine toDFA(Realm realm, Machine nfa) {
  alphabet = { e | /trans(str e, _) := nfa } - {""};
  
  // assumes names are unique; if not, use sorted ids to identify 
  str stateName(set[State] ss) = intercalate("_", sort([ s.name | s <- ss ])); 
  
  State newState(set[State] ss) {
    dfaState = realm.new(#State, state(stateName(ss), []));
    if (State s <- ss, s.final) {
      dfaState.final = true;
    }
    return dfaState;
  }    

  set[State] epsilonClosure(set[State] from) {
    return solve (from) { from += move(from, ""); }
  }
  
  set[State] move(set[State] from, str sym) 
    = { lookup(nfa, #State, to) | f <- from, trans(sym, to) <- f.transitions  };
  

  map[set[State], State] memo = ();
  init = epsilonClosure({nfa.states[0]});
  memo[init] = newState(init);
  states = {init};
  
  solve (states) {
    for (set[State] s <- states, a <- alphabet) {
      set[State] u = epsilonClosure(move(s, a));
      states += {u};
      if (u notin memo) {
        memo[u] = newState(u);
      } 
      tr = trans(a, referTo(#State, memo[u]));
      // unfortunate consequence of list[Trans]; should be set[Trans]
      if (tr notin memo[s].transitions) {
        memo[s].transitions += [tr];
      }
    }
  }  
  
  dfa = realm.new(#Machine, machine(nfa.name, []));
  dfa.states += [memo[init]] + [ memo[k] | k <- memo, k != init ];
  
  return dfa;
}


// -----------------------------------------------------------

Machine renameState(Machine m, str fromName, str toName) =
    visit(m){ case s:state(fromName, _): { s.name = toName; insert s; }  };

void tstRenameState1(){    
    realm = newRealm();
    dm = doors(realm);
    renderMachine("doors", realm, renameState(dm, "opened", "OPENED"));
}

void tstRenameState2(){  
    realm = newRealm();
    dm = doors(realm);  
    renderMachine("doors", realm, renameState(renameState(dm, "opened", "OPENED"), "closed", "CLOSED"));
}

// -----------------------------------------------------------

Machine renameEvent(Machine m, str fromEvent, str toEvent) =
    visit(m){ case t:trans(fromEvent, _): { t.event = toEvent; insert t; }  };

void tstRenameEvent1(){
    realm = newRealm();
    dm = doors(realm);  
    renderMachine("doors", realm, renameEvent(dm, "open", "OPEN"));
}

// -----------------------------------------------------------

Machine addState(Machine m, State s) {
    m.states = m.states + s;
    return m;
}

void tstAddState1(){
    realm = newRealm();
    dm = doors(realm);
    purged_state = realm.new(#State, state("purged", []));
    renderMachine("doors", realm, addState(dm, purged_state));
}

// -----------------------------------------------------------

State findState(Machine m, str stateName){
    visit(m){
        case s: state(stateName, _): return s;
    }
    throw "State <name> not found";
}

Machine addTrans(Machine m, str name, Trans t) =
    visit(m){
          case s: state(name, _): { s.transitions = s.transitions + t; insert s; }
    };

Machine tstAddTrans1(){
    realm = newRealm();
    dm = doors(realm);
    purged_state = realm.new(#State, state("purged", []));
    dm1 = addState(dm, purged_state);
    dm2 = addTrans(dm1, "closed", trans("purge", referTo(#State, purged_state)));
    renderMachine("doors", realm, dm2);
    return dm2;
}

// -----------------------------------------------------------

// Add a transition for eventName from fromStateNames to toStateName
Machine addAllTransitionsForEvent(Machine m, set[str] fromStateNames, str toStateName, str eventName){
    toState = findState(m, toStateName);
    
    while(!isEmpty(fromStateNames)){
        <sn, fromStateNames> = takeOneFrom(fromStateNames);
        m = addTrans(m, sn, trans(eventName, referTo(#State, toState)));
    }
    return m;
}

void tstAddReset(){
    realm = newRealm();
    m = abc(realm);
    m1 = addAllTransitionsForEvent(m, getStateNames(m) - "start", "start", "reset");
    renderMachine("abc (added reset)", realm, m1);
}

// -----------------------------------------------------------

State removeTransitionsTo(State s, Id to){
    s.transitions = [ t | t <- s.transitions, t.iud != to ];
    return s;
}

State removeTransitions(State s, str eventName){
    s.transitions = [ t | t <- s.transitions, t.event != eventName ];
    return s;
}

Machine removeTransitionsTo(Machine m, State s){
    m.states = [ removeTransitionsTo(s, s.uid) | s <- m.states ];
    return m;
}

Machine removeTransitionsTo(Machine m, str stateName){
    s = findState(m, stateName);
    m.states = [ removeTransitionsTo(s, s.uid) | s <- m.states ];
    return m;
}

Machine removeTransitions(Machine m, str eventName){
    m.states = [ removeTransitions(s, eventName) | s <- m.states ];
    return m;
}

void tstRemoveTransitions1(){
realm = newRealm();
    m = abc(realm);
    m1 = addAllTransitionsForEvent(m, getStateNames(m) - "start", "start", "reset");
    m2 = removeTransitions(m1, "reset");
    
    renderMachine("abc (added/removed reset)", realm, m2);
}

// -----------------------------------------------------------

Machine removeState(Machine m, State s){
    m = removeTransitionsTo(m, s);
    m.states = delete(m.states, s);
    return m;
}

Machine removeStates(Machine m, set[State] states){
    for(s <- states){
        m = removeTransitionsTo(m, s);
        m.states = delete(m.states, s);
    }
    return m;
}
