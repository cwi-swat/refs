module rmt::meta::GenericModels

import rmt::Refs;
import Type;
import Node;

data Obj
  = object(str \type, str cons, list[Field] elements, Id uid = noId())
  | primitive(value v)
  | ordered(list[Obj] elements)
  | unorded(set[Obj] elements)
  | reference(Ref[Obj] ref)
  ;
  
data Field
  = field(str name, Obj obj); 
  

//Obj node2obj(node n) {
//  ids = ();
//  
//  visit (n) {
//    case node x: {
//      kws = getKeywordParameters(x);
//      if ("uid" in kws) {
//        ids[kws["uid"]] = x;
//      }
//    }
//  }
//  
//  Obj val2obj(Ref r
//  
//  visit (n) {
//    case node x: {
//      t = typeOf(x).name;
//      cons = getName(x);
//      
//    }
//  
//  }
//  
//}