module rmt::meta::RegExps


data RegExp
  = event(str name)
  | choice(list[RegExp] alts)
  | sequence(list[RegExp] elts)
  | repeat(RegExp arg)
  | empty();
  
