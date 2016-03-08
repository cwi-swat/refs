module SimpleTrafos

import rmt::Refs;
import Visualize;
import IO;

// from http://www.eclipse.org/atl/documentation/old/ATLUseCase_Families2Persons.pdf

data Persons
  = persons(list[Person] persons);

data Person
  = female(str name)
  | male(str name);
  
data Family
  = family(str lastName, Member father, Member mother, 
           list[Member] sons, list[Member] daughters, Id uid = noId());
           
data Member
  = member(str firstName, Ref[Family] familyFather, Ref[Family] familyMother,
           Ref[Family] familySon, Ref[Family] familyDaughter, Id uid = noId());
           
Graph family2graph(Realm realm, Family f){
    map[Family, Node] family_nodes = ();
    fnode = realm.new(#Node, \node(f.lastName, shape=rectangle()));
    family_nodes[f] = fnode;
    
    nodes = {fnode};
    edges = {};
    
    void visMember(Realm realm, Family fam, Member mem){
    
        Ref[Node] referToFamilyNode(Ref[Family] f) = referTo(#Node, family_nodes[f.lookup(fam)]);
        
        memnode = realm.new(#Node, \node(mem.firstName));
        nodes += memnode;
        
        if(mem.familyFather != null()){
           edges += edge("familyFather", referTo(#Node, memnode), referToFamilyNode(mem.familyFather));
        }
    
        if(mem.familyMother != null()) 
           edges += edge("familyMother", referTo(#Node, memnode),  referToFamilyNode(mem.familyMother));
                  
        if(mem.familySon != null())
           edges += edge("familySon", referTo(#Node, memnode), referToFamilyNode(mem.familySon));
           
        if(mem.familyDaughter != null())
           edges += edge("familyDaughter", referTo(#Node, memnode), referToFamilyNode(mem.familyDaughter));
   }
    
    visMember(realm, f, f.father);
    visMember(realm, f, f.mother);
    
    son_nodes = son_edges = {};
    if(f.sons != []){
       for(sn <- f.sons){
           visMember(realm, f, sn);
       }
    }
    
    if(f.daughters != []){
       for(d <- f.daughters){
           visMember(realm, f, d);
       }
    }
    return graph(nodes, edges);
}

Persons families2persons(list[Family] fs) 
  = persons([ male("<f.father.firstName> <f.lastName>") | f <- fs ]
     + [ male("<s.firstName> <f.lastName>") | f <- fs, s <- f.sons ]
     + [ female("<f.mother.firstName> <f.lastName>") | f <- fs ]
     + [ female("<d.firstName> <f.lastName>") | f <- fs, d <- f.daughters ]);

Family marchFamily(Realm realm) {
  jim = realm.new(#Member, member("Jim", null(), null(), null(), null())); 
  cindy = realm.new(#Member, member("Cindy", null(), null(), null(), null())); 
  brandon = realm.new(#Member, member("Brandon", null(), null(), null(), null())); 
  brenda = realm.new(#Member, member("Brenda", null(), null(), null(), null()));
  
  // needed to first create the family, then update refs in members, 
  // then add the members to the family
  dummy = realm.new(#Member, member("dummy", null(), null(), null(), null()));
  
  march = realm.new(#Family, family("March", dummy, dummy, [dummy], [dummy]));
  
  jim.familyFather = referTo(#Family, march);
  cindy.familyMother = referTo(#Family, march);
  brandon.familySon = referTo(#Family, march);
  brenda.familyDaughter = referTo(#Family, march);
  
  march.father = jim;
  march.mother = cindy;
  march.sons = [brandon];
  march.daughters = [brenda];
  
  return march;  
}
  
Family sailorFamily(Realm realm) {
  peter = realm.new(#Member, member("Peter", null(), null(), null(), null())); 
  jackie = realm.new(#Member, member("Jackie", null(), null(), null(), null())); 
  david = realm.new(#Member, member("David", null(), null(), null(), null())); 
  dylan = realm.new(#Member, member("Dylan", null(), null(), null(), null())); 
  kelly = realm.new(#Member, member("Kelly", null(), null(), null(), null()));
  
  // needed to first create the family, then update refs in members, 
  // then add the members to the family
  dummy = realm.new(#Member, member("dummy", null(), null(), null(), null()));
  
  Family sailor = realm.new(#Family, family("Sailor", dummy, dummy, [dummy], [dummy]));
  
  peter.familyFather = referTo(#Family, sailor);
  jackie.familyMother = referTo(#Family, sailor);
  david.familySon = referTo(#Family, sailor);
  dylan.familySon = referTo(#Family, sailor);
  kelly.familyDaughter = referTo(#Family, sailor);
  
  sailor.father = peter;
  sailor.mother = jackie;
  sailor.sons = [david, dylan];
  sailor.daughters = [kelly];
  
  return sailor;  
}

value main(){
  realm = newRealm();
    
  mf =  sailorFamily(realm);
  iprintln(mf);
  println("Visualize:");
  render(visualize("Sailor family", family2graph(realm, mf)));
  return true;
}
   
