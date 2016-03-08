module rmt::meta::MetaModels

import rmt::Refs;
import IO;
import Node;

data MetaModel 
  = metaModel(list[Type] types);

// NB: this triggers a HUGE bug, all kwparams get the here declared init.
// or maybe the other kwparams are not added at all?
data Type(Id uid = noId())
  = class(str name, list[Ref[Type]] supers, list[Field] fields, bool abstract = false)
  | prim(str name)
  | enum(str name, list[str] values);
  
data Field
  = field(str name, Ref[Type] typ, 
          bool many = false, 
          bool optional = false, 
          bool containment = true, 
          Ref[Field] inverse = null(), 
          Id uid = noId()); // NB: not at Field!!!

MetaModel metaMeta(Realm realm) {
  // primitive string and boolean
  string = realm.new(#Type, prim("str"));
  boolean = realm.new(#Type, prim("bool"));

  // class Type   
  cname = realm.new(#Field, field("name", referTo(#Type, string)));
  typeClass = realm.new(#Type, class("Type", [], [cname], abstract=true));

  // class Primitive
  primClass = realm.new(#Type, class("Prim", [referTo(#Type, typeClass)], []));

  // class Field
  fname = realm.new(#Field, field("name", referTo(#Type, string)));
  fmany = realm.new(#Field, field("many", referTo(#Type, boolean), optional=true)); 
  foptional = realm.new(#Field, field("optional", referTo(#Type, boolean), optional=true)); 
  fcontainment = realm.new(#Field, field("containment", referTo(#Type, boolean), optional=true));
  ftype = realm.new(#Field, field("type", referTo(#Type, typeClass), containment=false)); 
  fieldClass = realm.new(#Type, class("Field", [], [fname, ftype, fmany, foptional, fcontainment]));
  
  // cyclic: inverse is in Field, and of type Field
  finv = realm.new(#Field, field("inverse", referTo(#Type, fieldClass), inverse=null(), optional=true, containment=false));
  //... and the inverse of the inverse is itself.
  //println("XXX: <finv>");
  //println("XXX: <getKeywordParameters(finv)>");
  //finv.inverse = referTo(#Field, finv);
  // triggers nullpinter exception in Assignable/FieldAccess because types are not compatible somehow...
  fieldClass.fields = fieldClass.fields + [finv]; //+= [finv];
  
  // class Class
  classClass = realm.new(#Type, class("Class", [referTo(#Type, typeClass)], []));
  csupers = realm.new(#Field, field("supers", referTo(#Type, classClass), optional=true, many=true, containment=false));
  cfields = realm.new(#Field, field("fields", referTo(#Type, fieldClass), optional=true, many=true));
  cabstract = realm.new(#Field, field("abstract", referTo(#Type, boolean)));   
  classClass.fields = [csupers, cfields, cabstract];
  
  // class Enum
  evalues = realm.new(#Field, field("values", referTo(#Type, string), optional=false, many=true));
  enumClass = realm.new(#Type, class("Enum", [referTo(#Type, typeClass)], [evalues]));
  
  return metaModel([string, boolean, typeClass, primClass, fieldClass, classClass, enumClass]);
}
  

