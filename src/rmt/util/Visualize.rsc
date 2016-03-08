module rmt::util::Visualize

extend experiments::vis2::sandbox::FigureServer;
extend experiments::vis2::sandbox::Figure;
extend rmt::meta::Graphs;

Figure makeShape(Node nd){
    if(nd.shape == ellipse())
       return ellipse(fig=text("<nd.label>", fontSize=14), grow=2, fillColor="lightYellow", id=newName());
    return box(fig=text("<nd.label>", fontSize=14), grow=2, fillColor="lightYellow", id=newName());
}

Figure visualize(str modelName, Graph g, tuple[int,int] size = <800,800>){
    nodes = [ <"<nd.uid.n>", makeShape(nd)> | nd <- g.nodes];
    
    edges = [experiments::vis2::sandbox::Figure::edge("<ed.fromNode.uid.n>", "<ed.toNode.uid.n>", label = ed.label, id=newName()) | ed <- g.edges];
    fg = graph(nodes=nodes, edges=edges, gap=<20,40>, size=size);
    return  vcat(figs=[text(modelName, fontSize=20), fg]);
}
