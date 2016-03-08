module rmt::meta::Schemas

import rmt::Refs;

data Schema
  = schema(list[Table] tables, list[RType] types);

data Table
  = table(str name, list[Column] columns, set[Ref[Column]] keys, Id uid = noId())
  ;

data Column
  = column(str name, Ref[Table] owner, Ref[RType] \type, Id uid = noId());
  
data RType
  = \type(str name, Id uid = noId());

