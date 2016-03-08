module rmt::trafo::ActivityExecution

import rmt::meta::Activities;
import rmt::Refs;
import IO;
import List;

data Variable(Opt[Value] currentValue = Opt::none());

data Activity(Trace trace = none());

data ActivityNode(bool running = false, list[Token] heldTokens = [], list[Token] inactive = []);

data ActivityEdge(list[Offer] offers = []);

data Offer = offer(list[Ref[Token]] tokens, Id uid = noId());
  
data Token(Ref[ActivityNode] holder = null(), Id uid = noId())
  = controlToken()
  | forkedToken(int remainingOffersCount, Ref[Token] baseToken); 

data Trace = trace(list[Ref[ActivityNode]] executedNodes) | none();

data Input = input(list[InputValue] inputValues);
  
data InputValue = inputValue(Value \value, Ref[Variable] variable);
  

private Realm realm = newRealm();

void setRealm(Realm realm2) {
  realm = realm2;
}

void testActivity6() {
  realm = newRealm();
  a = exampleActivity6(realm);
  a2 = main(a, [inputValue(booleanValue(false), referTo(#Variable, a.inputs[0]))]);
  for (r <- a2.trace.executedNodes, ActivityNode n := lookup(a2, #ActivityNode, r)) {
    println("EXEC: <n.name>");
  }
}

Activity main(Activity this, list[InputValue] inputValues) 
  = run(initializeTrace(initialize(this, inputValues)));

Activity initializeTrace(Activity this)
  = this[trace = trace([])];

Activity initialize(Activity this, list[InputValue] inputValues) {
  this = ( this | update(it, #Variable, v[currentValue = v.initial]) | v <- this.locals ); 
  for (v <- inputValues, Variable var := lookup(this, #Variable, v.variable)) {
    this = update(this, #Variable, var[currentValue = just(v.\value)]);
  }
  return this;
}

Activity run(Activity this) {
  this = runNodes(this);
  this = fireInitialNode(this);
  <this, enabledNodes> = getEnabledNodes(this);
  //this = update(this, #Activity, this);
  //println("enabled: <enabledNodes>");
  while (enabledNodes != {}) {
    if (nextNode <- enabledNodes) {
      this = fireNode(this, nextNode);
      <this, enabledNodes> = getEnabledNodes(this);
    }
  }
  return this;
}

Activity runNodes(Activity this) 
  = ( this | run(n, it) | n <- this.nodes);

Activity fireInitialNode(Activity this)
  = fireNode(this, getInitialNode(this)); 


Activity fireNode(Activity this, ActivityNode n) {
  println("fire node " + n.name);
  
  <this, tokens> = takeOfferedTokens(n, this);
  
  //println("tokens = <tokens>");
  this = fire(n, tokens, this);
  
  this.trace.executedNodes += [referTo(#ActivityNode, n)];
  return this; 
}

ActivityNode getInitialNode(Activity this) = n
  when n:initialNode(_) <- this.nodes;
    
tuple[Activity, set[ActivityNode]] getEnabledNodes(Activity this) {
  result = {};
  for (n <- this.nodes) {
    <this, b> = isReady(n, this);
    if (b) {
      result += {n};
    }
  }
  return <this, result>;
} 

Activity terminate(Activity this)
  = ( this | terminate(n, it) | n <- this.nodes );


// from TokenImpl
tuple[Activity, Token] transfer(Token this, ActivityNode holder, Activity a) {
   if (!isWithdrawn(this)) {
     return <withdraw(this, a), this>;
   }
   this.holder = referTo(#ActivityNode, holder);
   return <update(a, #Token, this), this>;
}

Activity withdraw(this:controlToken(), Activity a) {
  if (!isWithdrawn(this)) {
     if (ActivityNode holder := lookup(a, #ActivityNode, this.holder)) {
        a = removeToken(holder, this, a);
        a = update(a, #Token, this[holder = null()]); 
     }
  }
  return a;
}

bool isWithdrawn(Token this) = this.holder == null();

// from ForkedTokenImpl

Activity withdraw(this:forkedToken(_, _), Activity a) {
  
  if (Token tk := lookup(a, #Token, this.baseToken), !isWithdrawn(tk)) {
    a = withdraw(tk, a);
  }
  if (this.remainingOffersCount > 0) {
    this.remainingOffersCount -= 1;
    a = update(a, #Token, this); 
  }
  if (this.remainingOffersCount == 0) {
    // this is super.withdraw.
    if (!isWithdrawn(this)) {
      if (ActivityNode holder := lookup(a, #ActivityNode, this.holder)) {
        a = removeToken(holder, this, a);
        a = update(a, #Token, this[holder = null()]); 
      }
    }
  }
  return a;  
}

// From ActivityNodeImpl

Activity run(ActivityNode this, Activity a)
  = update(a, #ActivityNode, this[running=true]);

Activity terminate(ActivityNode this, Activity a) 
  = update(a, #ActivityNode, this[running=false]);


tuple[Activity, bool] isReady(this:initialNode(_), Activity a) = <a, false>;

tuple[Activity, bool] isReady(ActivityNode this, Activity a)
  = this.running ? hasOffers(this, a) : <a, false>;

//tuple[Activity, bool] isReady(this:opaqueAction(_, _), Activity a)
//  = this.running ? hasOffers(this, a) : <a, false>;    
  


Activity sendOffers(ActivityNode this, list[Token] tokens, Activity a) 
  = ( a | sendOffer(edge, tokens, it) | r <- this.outgoing, ActivityEdge edge := lookup(a, #ActivityEdge, r) );


tuple[Activity, list[Token]] takeOfferedTokens(ActivityNode this, Activity a) {
  allTokens = [];
//  println("this.incoming = <this.incoming>");
  for (r <- this.incoming, ActivityEdge edge := lookup(a, #ActivityEdge, r)) {
    //println("Edge = <edge>");
    <a, tokens> = takeOfferedTokens(edge, a);
    a = ( a | withdraw(token, it) | token <- tokens );
    allTokens += tokens;
  }
  return <a, allTokens>;
}

Activity addTokens(ActivityNode this, list[Token] tokens, Activity a) {
  for (Token token <- tokens) {
    //println("trtoken: <transferredToken>");
    <a, transferredToken> = transfer(token, this, a);
    this.heldTokens += [transferredToken];
    //println("this.held = <this.heldTokens>");
    a = update(a, #ActivityNode, this);
    //println(lookup(a, #ActivityNode, referTo(#ActivityNode, this)));
     
  }    
  return a;
}


// From MergeNodeImpl
tuple[Activity, bool]  hasOffers(this:mergeNode(_), Activity a) {
  b = false;
  for (r <- this.incoming, ActivityEdge edge := lookup(a, #ActivityEdge, r)) {
    <a, h> = hasOffer(edge, a);
    if (h) {
      b = true;
    }
  }
  return <a, b>;
}

default tuple[Activity, bool] hasOffers(ActivityNode this, Activity a) {
  b = true;
  for (r <- this.incoming, ActivityEdge edge := lookup(a, #ActivityEdge, r)) {
    <a, h> = hasOffer(edge, a);
    if (!h) {
      b = false;
    }
  }
  return <a, b>;
}

Activity removeToken(ActivityNode this, Token token, Activity a) 
  = update(a, #ActivityNode,   
      this[heldTokens = this.heldTokens - [token]][inactive = this.inactive + [token]]);


// From ActivityFinalNodeImpl

Activity fire(this:activityFinalNode(_), list[Token] _, Activity a) 
  = terminate(a);

Activity fire(this:mergeNode(_), list[Token] tokens, Activity a) 
  = sendOffers(this, tokens, addTokens(this, tokens, a));

Activity fire(this:joinNode(_), list[Token] tokens, Activity a) 
  = sendOffers(this, tokens, addTokens(this, tokens, a));

// From InitialNodeImpl

Activity fire(this:initialNode(_), list[Token] _, Activity a) {
  producedTokens = [realm.new(#Token, controlToken())];
  //println("producedTokens = <producedTokens>");
  return sendOffers(this, producedTokens, addTokens(this, producedTokens, a));
} 

// From DecisionNodeImpl

Activity fire(this:decisionNode(_), list[Token] tokens, Activity a) {
  Opt[ActivityEdge] selectedEdge = Opt::none();
  for (r <- this.outgoing, ActivityEdge edge := lookup(a, #ActivityEdge, r)) {
     if (edge is controlFlow, Variable guard := lookup(a, #Variable, edge.guard)) {
       guardValue = guard.currentValue.\value;
       if (booleanValue(b) := guardValue, b) {
          selectedEdge = just(edge);
          break;
       }
     }
  }
  if (selectedEdge != none()) {
    a = addTokens(this, tokens, a);
    a = sendOffer(selectedEdge.\value, tokens, a);
  }
  return a;
}

// From ForkNodeImpl

Activity fire(this:forkNode(_), list[Token] tokens, Activity a) {
  forkedTokens = [];
  for (Token token <- tokens) {
     ft = realm.new(#Token, forkedToken(0, null()));
     ft.baseToken = referTo(#Token, token);
     ft.remainingOffersCount = size(this.outgoing);
     forkedTokens += [ft];
  }
  return sendOffers(this, forkedTokens, addTokens(this, forkedTokens, a));
}


// From OpaqueActionImpl

Activity doAction(this:opaqueAction(_, expressions=exprs), Activity a) 
  = ( a | execute(e, it) | e <- exprs );

// inherited from ActionImpl

Activity fire(this:opaqueAction(_), list[Token] _, Activity a) 
  = sendOffers(this, doAction(this, a));



Activity sendOffers(this:opaqueAction(_), Activity a) {
  //println("send offfers for <this.name>");
  if (size(this.outgoing) > 0) {
    tokens = [];
    tokens += [realm.new(#Token, controlToken())];
    //println("tokens = <tokens>");
    a = addTokens(this, tokens, a);
    //println("out = <this.outgoing>");
    if (r <- this.outgoing, ActivityEdge edge := lookup(a, #ActivityEdge, r)) {
      //println("sending to: <edge.name>");
      return sendOffer(edge, tokens, a);
    }
  }
  return a;
}
        
// From ActivityEdgeImpl

Activity sendOffer(ActivityEdge this, list[Token] tokens, Activity a) {
  off = realm.new(#Offer, offer([ referTo(#Token, tk) | tk <- tokens]));
  //println("off = <off>");
  return update(a, #ActivityEdge, this[offers = this.offers + [off]]);
}

tuple[Activity, list[Token]] takeOfferedTokens(ActivityEdge this, Activity a) {
  tokens = [ tk | Offer off <- this.offers, r <- off.tokens, Token tk := lookup(a, #Token, r) ];
  a = update(a, #ActivityEdge, this[offers=[]]);
  return <a, tokens>;
}

tuple[Activity, bool] hasOffer(ActivityEdge this, Activity a) { 
  for (Offer off <- this.offers) {
    <a, b> = hasTokens(off, a);
    if (b) {
      return <a, b>;
    }
  }
  return <a, false>;
}

// From OfferImpl
tuple[Activity, bool] hasTokens(Offer this, Activity a) {
   a = removeWithdrawnTokens(this, a);
   return <a, size(this.tokens) > 0>;
}

Activity removeWithdrawnTokens(Offer this, Activity a) {
  tokensToBeRemoved = [];
  for (r <- this.tokens, Token token := lookup(a, #Token, r)) {
    if (isWithdrawn(token)) {
      tokensToBeRemoved += [referTo(#Token, token)];
    }
  }
  return update(a, #Offer, this[tokens = this.tokens - tokensToBeRemoved]);
}


Value eval(add(), integerValue(x), integerValue(y)) = integerValue(x + y);
Value eval(sub(), integerValue(x), integerValue(y)) = integerValue(x - y);
Value eval(smaller(), integerValue(x), integerValue(y)) = booleanValue(x < y);
Value eval(smallerEquals(), integerValue(x), integerValue(y)) = booleanValue(x <= y);
Value eval(equals(), integerValue(x), integerValue(y)) = booleanValue(x == y);
Value eval(greater(), integerValue(x), integerValue(y)) = booleanValue(x > y);
Value eval(greaterEquals(), integerValue(x), integerValue(y)) = booleanValue(x >= y);
Value eval(and(), integerValue(x), integerValue(y)) = booleanValue(x && y);
Value eval(or(), booleanValue(x), booleanValue(y)) = booleanValue(x || y);
Value eval(not(), booleanValue(x)) = booleanValue(!x);

Value valueOf(v:integerVariable(_)) = i when just(i:integerValue(_)) := v.currentValue;
Value valueOf(v:booleanVariable(_)) = b when just(b:booleanValue(_)) := v.currentValue;
default Value valueOf(v:integerVariable(_)) = integerValue(0);
default Value valueOf(v:booleanVariable(_)) = booleanValue(false);


Activity execute(e:integerCalculationExpression(x, op, lhs, rhs), Activity a) {
  if (Variable vx := lookup(a, #Variable, x), Variable vlhs := lookup(a, #Variable, lhs), Variable vrhs := lookup(a, #Variable, rhs)) {
    vx.currentValue = just(eval(op, valueOf(vlhs), valueOf(vrhs)));
    return update(a, #Variable, vx);
  }
  return a;
}

Activity execute(e:integerComparisonExpression(x, op, lhs, rhs), Activity a) {
  if (Variable vx := lookup(a, #Variable, x), Variable vlhs := lookup(a, #Variable, lhs), Variable vrhs := lookup(a, #Variable, rhs)) {
    vx.currentValue = just(eval(op, valueOf(vlhs), valueOf(vrhs)));
    return update(a, #Variable, vx);
  }
  return a;
}

Activity execute(e:booleanBinaryExpression(x, op, lhs, rhs), Activity a) {
  if (Variable vx := lookup(a, #Variable, x), Variable vlhs := lookup(a, #Variable, lhs), Variable vrhs := lookup(a, #Variable, rhs)) {
    vx.currentValue = just(eval(op, valueOf(vlhs), valueOf(vrhs)));
    return update(a, #Variable, vx);
  }
  return a;
}

Activity execute(e:booleanUnaryExpression(x, op, arg), Activity a) {
  if (Variable vx := lookup(a, #Variable, x), Variable varg := lookup(a, #Variable, arg)) {
    vx.currentValue = just(eval(op, valueOf(varg)));
    return update(a, #Variable, vx);
  }
  return a;
}

