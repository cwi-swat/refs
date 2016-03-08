module rmt::meta::Activities

import rmt::Refs;

data Activity
  = activity(str name, list[Variable] locals, list[Variable] inputs,
      list[ActivityNode] nodes, list[ActivityEdge] edges, Id uid = noId());
      
data Variable(Opt[Value] initial = none(), Id uid = noId())
  = integerVariable(str name) | booleanVariable(str name);
  
data Value = integerValue(int ivalue) | booleanValue(bool bvalue);
  
data ActivityEdge(Id uid = noId())
  = activityEdge(str name,  Ref[ActivityNode] source, Ref[ActivityNode] target)
  | controlFlow(str name,  Ref[ActivityNode] source, Ref[ActivityNode] target, Ref[Variable] guard);
  
data ActivityNode(list[Ref[ActivityEdge]] outgoing = [], list[Ref[ActivityEdge]] incoming = [], Id uid = noId())
  = mergeNode(str name)
  | activityFinalNode(str name)
  | decisionNode(str name)
  | joinNode(str name)
  | forkNode(str name)
  | initialNode(str name)
  | opaqueAction(str name, list[Expression] expressions = []);
  
data Expression
  = integerCalculationExpression(Ref[Variable] assignee, 
          IntegerCalculationOperator intCalcOp, 
          Ref[Variable] lhs, Ref[Variable] rhs)
  | integerComparisonExpression(Ref[Variable] assignee, 
         IntegerComparisonOperator intCompOp,
         Ref[Variable] lhs, Ref[Variable] rhs)
  | booleanUnaryExpression(Ref[Variable] assignee, 
         BooleanUnaryOperator boolUnOp, Ref[Variable] operand)
  | booleanBinaryExpression(Ref[Variable] assignee, 
         BooleanBinaryOperator boolBinOp, 
         Ref[Variable] lhs, Ref[Variable] rhs);
           
  
data IntegerCalculationOperator 
  = add() 
  | subtract();

data IntegerComparisonOperator 
  = smaller() 
  | smallerEquals()
  | equals()
  | greaterEquals()
  | greater();
  
data BooleanUnaryOperator
  = not();

data BooleanBinaryOperator
  = and()
  | or();  

  
Activity exampleActivity6(Realm realm) {
  a = realm.new(#Activity, activity("example", [], [], [], []));
  internal = realm.new(#Variable, booleanVariable("internal"));
  a.inputs = [internal];
  notInternal = realm.new(#Variable, booleanVariable("notinternal", initial=just(booleanValue(false))));
  a.locals = [notInternal];
  
  initial = realm.new(#ActivityNode, initialNode("initial"));
  register = realm.new(#ActivityNode, opaqueAction("register",
    expressions=[booleanUnaryExpression(referTo(#Variable, notInternal), not(), referTo(#Variable, internal))]));
  decision = realm.new(#ActivityNode, decisionNode("decision"));
  getWelcomePackage = realm.new(#ActivityNode, opaqueAction("get welcome package"));
  fork = realm.new(#ActivityNode, forkNode("fork"));
  assignToProject = realm.new(#ActivityNode, opaqueAction("assign to project"));
  assignToProjectExternal = realm.new(#ActivityNode, opaqueAction("assign to project external"));
  addToWebsite = realm.new(#ActivityNode, opaqueAction("add to website"));
  joinn = realm.new(#ActivityNode, joinNode("join"));
  managerInterview = realm.new(#ActivityNode, opaqueAction("manager interview"));
  managerReport = realm.new(#ActivityNode, opaqueAction("manager report"));
  merge = realm.new(#ActivityNode, mergeNode("merge"));
  authorizePayment = realm.new(#ActivityNode, opaqueAction("authorize payment"));
  final = realm.new(#ActivityNode, activityFinalNode("final"));
  

  decision2assignExt = realm.new(#ActivityEdge, controlFlow("dec2asx", 
            referTo(#ActivityNode, decision), referTo(#ActivityNode, assignToProjectExternal), 
            referTo(#Variable, notInternal)));
  decision2welcome = realm.new(#ActivityEdge, controlFlow("dec2welc", 
             referTo(#ActivityNode, decision), referTo(#ActivityNode, getWelcomePackage),
             referTo(#Variable, internal)));
  
  initial2register = realm.new(#ActivityEdge, activityEdge("in2reg", referTo(#ActivityNode, initial), referTo(#ActivityNode, register)));
  register2decision = realm.new(#ActivityEdge, activityEdge("reg2dec", referTo(#ActivityNode, register), referTo(#ActivityNode, decision)));
  assignExt2merge = realm.new(#ActivityEdge, activityEdge("asx2mrg", referTo(#ActivityNode, assignToProjectExternal), referTo(#ActivityNode, merge)));
  merge2authorize = realm.new(#ActivityEdge, activityEdge("mrg2auth", referTo(#ActivityNode, merge), referTo(#ActivityNode, authorizePayment)));
  authorize2final = realm.new(#ActivityEdge, activityEdge("auth2fin", referTo(#ActivityNode, authorizePayment), referTo(#ActivityNode, final)));

  welcome2fork = realm.new(#ActivityEdge, activityEdge("welc2fork", referTo(#ActivityNode, getWelcomePackage), referTo(#ActivityNode, fork)));
  fork2web = realm.new(#ActivityEdge, activityEdge("fork2web", referTo(#ActivityNode, fork), referTo(#ActivityNode, addToWebsite)));
  fork2assign = realm.new(#ActivityEdge, activityEdge("fork2asn", referTo(#ActivityNode, fork), referTo(#ActivityNode, assignToProject)));
  web2join = realm.new(#ActivityEdge, activityEdge("add2join", referTo(#ActivityNode, addToWebsite), referTo(#ActivityNode, joinn)));
  assign2join = realm.new(#ActivityEdge, activityEdge("asn2join", referTo(#ActivityNode, assignToProject), referTo(#ActivityNode, joinn)));
  join2interview = realm.new(#ActivityEdge, activityEdge("join2int", referTo(#ActivityNode, joinn), referTo(#ActivityNode, managerInterview)));
  interview2report = realm.new(#ActivityEdge, activityEdge("int2rep", referTo(#ActivityNode, managerInterview), referTo(#ActivityNode, managerReport)));
  report2merge= realm.new(#ActivityEdge, activityEdge("rep2mrg", referTo(#ActivityNode, managerReport), referTo(#ActivityNode, merge)));
  
  // inverses
  
  initial.outgoing = [referTo(#ActivityEdge, initial2register)];
  initial.incoming = [];
  register.outgoing = [referTo(#ActivityEdge, register2decision)];
  register.incoming = [referTo(#ActivityEdge, initial2register)];
  decision.outgoing = [referTo(#ActivityEdge, decision2assignExt), referTo(#ActivityEdge, decision2welcome)];
  decision.incoming = [referTo(#ActivityEdge, register2decision)];
  getWelcomePackage.outgoing = [referTo(#ActivityEdge, welcome2fork)];
  getWelcomePackage.incoming = [referTo(#ActivityEdge, decision2welcome)];
  fork.outgoing = [referTo(#ActivityEdge, fork2web), referTo(#ActivityEdge, fork2assign)];
  fork.incoming = [referTo(#ActivityEdge, welcome2fork)];
  assignToProject.outgoing = [referTo(#ActivityEdge, assign2join)];
  assignToProject.incoming = [referTo(#ActivityEdge, fork2assign)];
  assignToProjectExternal.outgoing = [referTo(#ActivityEdge, assignExt2merge)];
  assignToProjectExternal.incoming = [referTo(#ActivityEdge, decision2assignExt)];
  addToWebsite.outgoing = [referTo(#ActivityEdge, web2join)];
  addToWebsite.incoming = [referTo(#ActivityEdge, fork2web)];
  joinn.outgoing = [referTo(#ActivityEdge, join2interview)];
  joinn.incoming = [referTo(#ActivityEdge, web2join), referTo(#ActivityEdge, assign2join)];
  managerInterview.outgoing = [referTo(#ActivityEdge, interview2report)];
  managerInterview.incoming = [referTo(#ActivityEdge, join2interview)];
  managerReport.outgoing = [referTo(#ActivityEdge, report2merge)];
  managerReport.incoming = [referTo(#ActivityEdge, interview2report)];
  merge.outgoing = [referTo(#ActivityEdge, merge2authorize)];
  merge.incoming = [referTo(#ActivityEdge, report2merge), referTo(#ActivityEdge, assignExt2merge)];
  authorizePayment.outgoing = [referTo(#ActivityEdge, authorize2final)];
  authorizePayment.incoming = [referTo(#ActivityEdge, merge2authorize)];
  final.outgoing = [];
  final.incoming = [referTo(#ActivityEdge, authorize2final)];
  
  a.nodes = [initial, register, decision, getWelcomePackage, fork, assignToProject,
    assignToProjectExternal, addToWebsite, joinn, managerInterview, managerReport,
    merge, authorizePayment, final];
  
 
  a.edges = [initial2register, register2decision, assignExt2merge, merge2authorize,
    authorize2final, welcome2fork, fork2web, fork2assign, web2join, assign2join,
    join2interview, interview2report, report2merge, decision2assignExt, decision2welcome];
  
  return a;
  
}  