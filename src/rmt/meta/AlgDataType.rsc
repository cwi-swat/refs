module rmt::meta::AlgDataType

import rmt::Refs;
import List;

data ADTModel
  = adts(list[ADT] adts);
  
data ADT
  = adt(str name, list[Cons] ctors, Id uid = noId());
  
data Cons
  = cons(str name, list[Arg] args, Id uid = noId());
  
data Arg
  = arg(str name, ADTType \type);
  
data ADTType
  = primitive(str name)
  | reference(Ref[ADT] adt)
  | contains(Ref[ADT] adt)
  | ordered(ADTType \type)
  | unordered(ADTType \type);
  
str adtModel2text(ADTModel m) {
  str cons2text(Cons c)
    = "<c.name>(<intercalate(", ", [ arg2text(a) | a <- c.args ])>, Id uid = noId())";
 
  str arg2text(Arg a) 
    = "<type2text(a.\type)> <a.name>";
  
  str type2text(ADTType t) {
    switch (t) {
      case primitive(x): return x;
      case reference(r): return "Ref[<r.lookup(m).name>]";
      case contains(r): return r.lookup(m).name;
      case ordered(x): return "list[<type2text(x)>]";
      default: throw "missed a case: <t>";      
    }
  }
 
  str adt2text(ADT a) {
    s = "data <a.name>";
    cs = [ cons2text(c) | c <- a.ctors ];
    return s + "\n  = <intercalate("\n  | ", cs)>\n  ;";
  }
  
  decls = [ adt2text(a) | a <- m.adts ];
  return intercalate("\n", decls);
}