module rmt::meta::Statemachines

import IO;
import rmt::Refs;

data Machine
  = machine(str name, list[State] states, Id uid = noId());
  
data State
  = state(str name, list[Trans] transitions, bool final = false, Id uid = noId());
  
data Trans
  = trans(str event, Ref[State] to);
  
set[str] getStateNames(Machine m) = { s.name | s <- m.states };

set[str] getEventNames(Machine m) = { t.event | /Trans t  := m.states };



//      opened  --close--> closed
//         ^                  |
//         |                  |
//         ------open---------


Machine doorsPaper() {
  r = newRealm();

  opened = r.new(#State, state("opened", []));
  closed = r.new(#State, state("closed", []));
  opened.transitions = [trans("close", referTo(#State, closed))];
  opened.transitions = [trans("open", referTo(#State, opened))];

  doors = r.new(#Machine, machine("doors", [opened, closed]));
}

Machine doors(Realm realm){
  
  opened_state = realm.new(#State, state("opened", []));
  closed_state = realm.new(#State, state("closed", []));
  
  opened_state.transitions = [trans("close", referTo(#State, closed_state))];
  closed_state.transitions = [ trans("open", referTo(#State, opened_state)) ];
  return realm.new(#Machine, machine("doors", [opened_state, closed_state]));
}

//      start --a--> a_state --b--> bc_state
//                                  |    ^
//                                  |    |
//                                  --c--

Machine abc(Realm realm){

  start_state = realm.new(#State, state("start", []));
  a_state =  realm.new(#State, state("a_state", []));
  bc_state =  realm.new(#State, state("bc_state", []));
  
  start_state.transitions = [trans("a", referTo(#State, a_state))];
  a_state.transitions = [ trans("b", referTo(#State, bc_state)) ];
  bc_state.transitions = [ trans("c", referTo(#State, bc_state)) ];
  return realm.new(#Machine, machine("abc", [start_state, a_state, bc_state]));

}