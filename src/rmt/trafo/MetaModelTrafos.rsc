module rmt::trafo::MetaModelTrafos

import rmt::meta::MetaModels;
import rmt::meta::Schemas;
import rmt::meta::Graphs;
import rmt::meta::AlgDataType;
import rmt::Refs;
import IO;
import String;
import List;

ADTModel metaModel2ADT(Realm target, Realm src, MetaModel mm) {
  mm = generalizeTypeRefs(flattenInheritance(src, mm));
  
  topClasses = { topMostSuper(c, mm) | c:class(_, _, _) <- mm.types };
  
  myAdts = ( c: target.new(#ADT, adt(c.name, [])) | c <- topClasses );
  //bool subclassOf(Type t1, Type t2, MetaModel mm) {
  
  ADTType field2adtType(Field f) {
    ADTType at;
    switch (lookup(mm, #Type, f.typ)) {
      case prim(n): {
        at = primitive(n);
        if (f.many) {
          at = ordered(at);
        }
      }
      case c:class(_, _, _) : {
        if (f.many, f.containment) { 
          at = ordered(contains(referTo(#ADT, myAdts[c])));
        }
        else if (f.many, !f.containment) {
          at = ordered(reference(referTo(#ADT, myAdts[c])));
        }
        else if (!f.many, f.containment) {
          at = contains(referTo(#ADT, myAdts[c]));
        }
        else if (!f.many, !f.containment) {
          at = reference(referTo(#ADT, myAdts[c]));
        }
        else {
          throw "unsupported field: <f>";
        }
      }
    }
    return at;
  }
  Arg field2arg(Field f) = arg(f.name, field2adtType(f));
  
  for (Type c <- topClasses, Type t <- mm.types, t is class, !t.abstract, subclassOf(t, c, mm)) {
    myAdts[c].ctors += [cons(toLowerCase(t.name), [ field2arg(f) | f <- t.fields ])];  
  } 
  
  return target.new(#ADTModel, adts([ myAdts[c] | c <- myAdts ]));
}

Graph metaModel2Graph(Realm realm, MetaModel mm) {
   g = realm.new(#Graph, graph({}, {}));
   
   ns = ( t: realm.new(#Node, \node(t.name)) | t <- mm.types );
   g.edges = { realm.new(#Edge, edge("super", referTo(#Node, ns[t1]), referTo(#Node, ns[t2]))) 
             | t1:class(_, sups, _) <- mm.types
             , Type t2 <- [ lookup(mm, #Type, s) | s <- sups ] }
           + { realm.new(#Edge, edge(n, referTo(#Node, ns[t1]), referTo(#Node, ns[t2])))
             | t1:class(_, _, /field(n, t)) <- mm.types
             , Type t2 := lookup(mm, #Type, t) };

  g.nodes = ns<1>;
  return g;   
}

// based on: http://www.eclipse.org/atl/atlTransformations/#Class2Relational
Schema metaModel2Schema(Realm realm, MetaModel mm) {
  tbls = (n: realm.new(#Table, table(n, [], {})) | class(str n, _, _) <- mm.types );
  prims = (n: realm.new(#RType, \type(n)) | prim(str n) <- mm.types, n != "int" );
  prims["int"] = realm.new(#RType, \type("int"));
  
  RType columnType(Field f) = prims[fieldType(f).name];
  Type fieldType(Field f) = t when Type t := lookup(mm, #Type, f.typ);
  bool isPrim(Field f) = prim(_) := fieldType(f);
  
  for (class(n, _, fs) <- mm.types) {
    tbls[n].columns += [realm.new(#Column, column("objectId", referTo(#Table, tbls[n]), referTo(#RType, prims["int"])))];
    tbls[n].columns += [realm.new(#Column, column(f.name, referTo(#Table, tbls[n]), referTo(#RType, columnType(f)))) 
                           | f <- fs, !f.many, isPrim(f) ];
  }
  
  for (class(n, _, /Field f) <- mm.types, f.many, isPrim(f)) {
    name = "<n>_<f.name>";
    tbls[name] = realm.new(#Table, table(name, [], {}));
    ident = realm.new(#Column, column("<n>Id", referTo(#Table, tbls[name]), referTo(#RType, prims["int"])));
    val = realm.new(#Column, column(f.name, referTo(#Table, tbls[name]), referTo(#RType, columnType(f))));
    tbls[name].columns = [ident, val];
  }

  for (class(n, _, /Field f) <- mm.types, !f.many, !isPrim(f)) {
    tbls[n].columns += [realm.new(#Column, column("<f.name>_id", referTo(#Table, tbls[n]), referTo(#RType, prims["int"])))];
  }
  
  for (class(n, _, /Field f) <- mm.types, f.many, !isPrim(f)) {
    name = "<n>_<f.name>";
    tbls[name] = realm.new(#Table, table(name, [], {}));
    ident = realm.new(#Column, column("<n>Id", referTo(#Table, tbls[name]), referTo(#RType, prims["int"])));
    val = realm.new(#Column, column(f.name, referTo(#Table, tbls[name]), referTo(#RType, prims["int"])));
    tbls[name].columns = [ident, val];
  }
  
  return schema([ tbls[k] | k <- tbls ], [ prims[k] | k <- prims ]);
}


str metaModel2Java(MetaModel mm) {
   str typeRef2java(Ref f) = typeRef2java(t) when Type t := lookup(mm, #Type, f); 
   str typeRef2java(prim("str")) = "String";
   str typeRef2java(prim("int")) = "Integer";
   str typeRef2java(prim("bool")) = "Boolean";
   default str typeRef2java(Type t) = iName(t.name);
   
   list[str] field2java(Field f) {
     t0 = typeRef2java(f.typ);
     t = fieldType(f);
     return ["<t> <getName(f.name)>();\n"]
       + (f.many ? ["void <addName(f.name)>(<t0> x);", 
                    "boolean <removeName(f.name)>(<t0> x);"]
                 : ["void <setName(f.name)>(<t0> x);"]);
   }
   
   str fieldInit(Field f) = "new java.util.ArrayList\<\>()" when f.many;
   default str fieldInit(Field f) = "null";
   
   str field2field(Field f) = "private <fieldType(f)> <f.name> = <fieldInit(f)>;";
   
   str fieldType(Field f) = f.many ? "List\<<t>\>" : t
     when 
       t := typeRef2java(f.typ);
   
   str singularize(str name) = name[0..-1];
   str nameStem(str name) = capitalize(name);
   str addName(str name) = "add<singularize(nameStem(name))>";
   str removeName(str name) = "remove<singularize(nameStem(name))>";
   str getName(str name) = "get<nameStem(name)>";
   str setName(str name) = "set<nameStem(name)>";
   str fldName(str name) = name;
   
   str aMethod(str rt, str n, str fs, str body) 
     = "@Override
       'public <rt> <n>(<fs>) {
       '  <body>
       '}";
   
   str getter(str name, str typ) 
     = aMethod(typ, getName(name), "", 
         "return <fldName(name)>;");
       
   str setter(str name, str typ) 
     = aMethod("void", setName(name), "<typ> x", 
         "this.<fldName(name)> = x;");
   
   str adder(str name, str typ)
     = aMethod("void", addName(name), "<typ> x", 
         "this.<fldName(name)>.add(x);");
  
   str remover(str name, str typ) 
     = aMethod("boolean", removeName(name), "<typ> x", 
         "return this.<fldName(name)>.remove(x);");
   
   list[str] field2methods(Field f) {
     t0 = typeRef2java(f.typ);
     t = fieldType(f);
     return [getter(f.name, t)]
       + (f.many ? [adder(f.name, t0), remover(f.name, t0)]
                 : [setter(f.name, t)]);
   }
   
   str interfaces(list[Ref] ss) = intercalate(", ", [typeRef2java(s) | s <- ss]);
   str extends(list[Ref] ss) = ss != [] ? "extends <interfaces(ss)> " : "";
   str implements(list[Ref] ss) = ss != [] ? "implements <interfaces(ss)> " : "";
   
   str iName(str name) = "I<name>";
   str cName(str name) = name;
   
   list[Field] allFields(Type c) =
      ( c.fields | it + allFields(s) | sup <- c.supers, Type s := lookup(mm, #Type, sup) );
   
   list[str] class2java(Type c) 
     = ["interface <iName(c.name)> <extends(c.supers)>{<for (f <- c.fields) {>
        '  <intercalate("\n", field2java(f))><}>
        '}",
        "class <cName(c.name)> <implements(c.supers)>{<for (f <- allFields(c)) {>
        '  <field2field(f)><}><for (f <- allFields(c)) {>
        '  <intercalate("\n", field2methods(f))><}>
        '}"];
   
   list[str] enum2java(Type enum)
     = ["enum <name> {
        '  <intercalate(", ", vals)>
        '}"];
   
   decls = [];
   
   top-down visit (mm) {
     case e:enum(_, _): 
       decls += enum2java(e);
     case c:class(_, _, _): 
       decls += class2java(c); 
   }
   
   return intercalate("\n", decls);
}


MetaModel flattenInheritancePaper(Realm realm, MetaModel mm) {
  Type flatten(Type t) {
    supers = [ flatten(lookup(mm, #Type, sup)) | sup <- t.supers ]; 
    t.fields = [ realm.new(#Field, f) | s <- supers, f <- s.fields ]
             + t.fields;
    return t;
  }
  return visit (mm) { case t:class(_, _, _) => flatten(t) }    
}

MetaModel flattenInheritance(Realm realm, MetaModel mm) {
  Type flatten(Type t) {
    supers = [ flatten(s) | sup <- t.supers, Type s := lookup(mm, #Type, sup) ]; 
    t.fields = [ newF | s <- supers, f <- s.fields, Field newF := realm.new(#Field, f) ]
             + t.fields;
    return t;
  }
  
  return visit (mm) { case t:class(_, _, _) => flatten(t) }
}

Type topMostSuper(Type c, MetaModel mm) {
  if (c.supers == []) {
    return c;
  }
  if (Type s := lookup(mm, #Type, c.supers[0])) {
    return topMostSuper(s, mm);
  }
}

MetaModel generalizeTypeRefs(MetaModel mm) {
  return visit (mm) {
    case f:field(_, t) => f[typ=referTo(#Type, topMostSuper(c, mm))]
       when c:class(_, _, _) := lookup(mm, #Type, t)
  }    
}

bool subclassOf(Type t1, Type t2, MetaModel mm) {
  // t1 <: t2.
  if (t1 == t2) {
    return true;
  } 
  return ( false | it || subclassOf(c, t2, mm) 
                 | t <- t1.supers, Type c := lookup(mm, #Type, t) );
}


