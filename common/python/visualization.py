# Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0


from graphviz import Digraph, Graph
import numpy as np
import colorsys
import matplotlib.cm as cm
import matplotlib as mpl

def graph2dot(linksDf=None, nodesDf=None, linksFrom="from", linksTo="to", nodesNode="node",
              nodesLabel=None,
              nodesSize=None,
              nodesSizeScale=1,
              nodesColor=None,
              nodesColorBy=None,
              nodeAttrs=None,
              nodesAttrs=None,
              linksLabel=None,
              linksColor=None,
              linksColorBy=None,
              linkAttrs=None,
              linksAttrs=None,
              graphAttrs=None,
              outFile=None,
              view=True,
              stdout=None,
              size=10,
              layout=None,
              directed=False,
              sort=False
             ):
    dot = Digraph() if directed else Graph()
    dot.attr(rankdir='LR')
    dot.attr(size=f"{size}")
    dot.attr('node', shape='circle')
    if nodesAttrs is not None:
        dot.attr('node', nodesAttrs)
    if linksAttrs is not None:
        dot.attr('edge', linksAttrs)
    if graphAttrs is not None:
        dot.attr('graph', graphAttrs)
    if layout is not None:
        dot.attr(layout=f"{layout}")
        
    if(linksDf is not None):
        for index, row in (linksDf.sort([linksFrom, linksTo]).iterrows() if sort else linksDf.iterrows()):
            fromVal = str(index) if linksFrom is None else f"{row[linksFrom]}"
            toVal = str(index) if linksTo is None else f"{row[linksTo]}"
            lA = dict()
            if linkAttrs is not None:
                for k, v in linkAttrs.items():
                    lA[k]=str(row[v])
            dot.edge(fromVal, toVal,
                     label=None if (linksLabel is None) else f"{row[linksLabel]}",
                     color=None if (linksColor is None) else row[linksColor],
                     _attributes=None if (linkAttrs is None) else lA
                    )
    
    if(nodesDf is not None):
        if nodesColorBy is not None:
            vals = nodesDf[nodesColorBy].unique()
            norm = mpl.colors.Normalize(vmin= 0, vmax=len(vals)-1)
            cmap = cm.jet
            mapper = m = cm.ScalarMappable(norm = norm, cmap = cmap)
            catMap = dict()
            for i, v in  np.ndenumerate(vals):
                catMap[v]=i
        for index, row in (nodesDf.sort([nodesNode]).iterrows() if sort else nodesDf.iterrows()):
            fontColorStr=None
            nodeVal = str(index) if nodesNode is None else f"{row[nodesNode]}"
            if nodesColorBy is not None:
                val = row[nodesColorBy]
                indexScalar = catMap[val]
                rgba = m.to_rgba(indexScalar)[0]
                M = colorsys.rgb_to_hsv(rgba[0], rgba[1], rgba[2])
                colorStr = f"{M[0]}, {M[1]}, {M[2]}"
                if rgba[0]+rgba[1]+rgba[2] < 1.3:
                    fontColorStr='white'
            elif nodesColor is not None:
                colorStr = row[nodesColor]
            else:
                colorStr = None
            nA = dict()
            if nodeAttrs is not None:
                for k, v in nodeAttrs.items():
                    nA[k]=str(row[v])
            dot.node(nodeVal, nodeVal if nodesLabel is None else f"{row[nodesLabel]}",
                     width=None if (nodesSize is None) else (f"{nodesSizeScale*row[nodesSize]}") if type(nodesSize)==str  else f"{nodesSizeScale*nodesSize}",
                     color=colorStr,
                     fontcolor=fontColorStr,
                     _attributes=None if (nodeAttrs is None) else nA
                    )
    if stdout is None:
        stdout = True if outFile is None else False
    if stdout:
        print(dot.source)
    if outFile is not None:
        dot.render(f"../dot/{outFile}", view=view)
    return dot

def show_reach_neighborhood(session,
                          tableLinks,
                          tableNodes,
                          node,
                          hops,
                          directed=False,
                          size=5,
                          layout="fdp",
                          nodesSizeScale=100
                         ):
   nodeSub = {
    "node": [node],
    "reach":[1]
   } 
   nodeSubDf = pd.DataFrame(nodeSub, columns = ["node", "reach"])
   session.upload(nodeSubDf, casout={"name": "_nodeSub_", "replace": True});
   session.network.reach(
      loglevel = "NONE",
      direction = "directed" if directed else "undirected",
      links = tableLinks,
      nodes = tableNodes,
      nodesVar = {"vars":["target"]},
      maxReach = hops,
      outReachLinks = {"name":"_reachLinks_", "replace":True},
      outReachNodes = {"name":"_reachNodes_", "replace":True},
      nodesSubset = "_nodeSub_"   
   )
   session.datastep.runCode(
      code = f"""
         data _reachNodes_; 
            set _reachNodes_;
            length label $50;
            label=target || "\nPaperId = " || put(node, 7.);
            if put(node, 7.) = {node} then label = "???" || "\nPaperId = " || put(node, 7.);
         run;
      """
    )
   return graph2dot(linksDf=session.CASTable("_reachLinks_"),
                    nodesDf=session.CASTable("_reachNodes_"),
                    nodesLabel="label",
                    layout=layout,
                    directed=directed,
                    size=size,
                    nodesSizeScale=nodesSizeScale,
                    stdout=False)





