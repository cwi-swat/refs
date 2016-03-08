module rmt::meta::Graphs

import rmt::Refs;

data Graph
  = graph(set[Node] nodes, set[Edge] edges, Id uid = noId());
  
data Node
  = \node(str label, Shape shape = ellipse(), Id uid = noId());
  
data Edge
  = edge(str label, Ref[Node] fromNode, Ref[Node] toNode, Id uid = noId());

data Shape 
  = ellipse()
  | rectangle();