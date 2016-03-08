module rmt::trafo::ActivityTrafos

import rmt::meta::Activities;
import rmt::Refs;
import rmt::meta::Graphs;



Graph activity2graph(Realm realm, Activity a) {
  nodes = ( n: realm.new(#Node, \node(n.name)) | n <- a.nodes );
  edges = { edge(e.name, referTo(#Node, nodes[n1]), referTo(#Node, nodes[n2])) 
          | e <- a.edges, ActivityNode n1 := lookup(a, #ActivityNode, e.source),
            ActivityNode n2 := lookup(a, #ActivityNode, e.target) };

  return realm.new(#Graph, graph(nodes<1>, edges));
}