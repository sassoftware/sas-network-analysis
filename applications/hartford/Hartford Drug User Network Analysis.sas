/*
# Analyzing Social Interactions Among Drug Users in Hartford


## A Network Analysis Case Study for Public Health Intervention

This demonstration shows how network analysis can reveal key influencers in social networks and support more effective public health interventions in high-risk communities.


### Overview

This notebook analyzes needle-sharing interactions among drug users in Hartford, Connecticut. It demonstrates how the [SAS Viya `NETWORK` action set](https://helpcenter.unx.sas.com/test/doc/en/pgmsascdc/v_071/casactml/casactml_network_toc.htm) can be used to uncover influential individuals in social networks—insights that are critical for designing targeted public health interventions.

This notebook is adapted from the blog [A Simple Pipeline using Hypergroup to Perform Community Detection and Network Analysis](https://blogs.sas.com/content/sascom/2016/10/20/analyzing-social-networks-using-python-sas-viya/). The key distinction is that this notebook leverages actions from the `NETWORK` action set, whereas the original example relies on the `HYPERGROUP` action set.

### Dataset

The dataset used in this demo is provided with permission from **Margaret R. Weeks** at the [Institute of Community Research](https://icrweb.org/). This dataset originates from the study described in the paper [Social Networks of Drug Users in High-Risk Sites: Finding the Connections](https://www.researchgate.net/publication/227085871_Social_Networks_of_Drug_Users_in_High-Risk_Sites_Finding_the_Connections).

At first glance, the dataset appears quite minimal. The CSV consists of a simple directed edge list with two columns (from and to) where nodes are represented only by numeric identifiers. Each directed tie corresponds to the lending of drug needles.

### Why This Matters
Despite the apparent simplicity of the data, the tools available in the `NETWORK` action set enable us to extract meaningful structural insights from the network. In particular, we can identify highly influential or central individuals who play a disproportionate role in connectivity and interaction patterns.

This information is especially valuable for community health practitioners. Targeted interventions focused on these key individuals can be far more effective in reducing risky behaviors than interventions applied uniformly or at random across the network, leading to broader and more impactful outcomes.

*/


/*
#### Establishing a SAS Cloud Analytic Services (CAS) Connection 
*/

cas mySession;
libname casuser cas;

/*
####  Data Import and Initial Inspection
We load the network edge list from a public GitHub repository and inspect the first 10 rows to confirm successful data ingestion.
*/

filename src url
   "https://raw.githubusercontent.com/sassoftware/sas-viya-programming/master/python/network-analysis/drug_network.csv";

data casuser.DrugNetwork;
   infile src dsd firstobs=2;
   input from:best12. to:best12.;
run;

proc print data=casuser.DrugNetwork(obs=10);
run;

/*
#### Initial Network Visualization
Before performing any analytical steps, we begin with a basic visualization of the network to gain an intuitive understanding of its overall structure. This initial view is generated using the `PlotGraph` visualization macro, which provides an interactive and flexible way to explore nodes, edges, and network topology. For more details on the `PlotGraph` macro and its capabilities, see the [SAS documentation](https://helpcenter.unx.sas.com/test/doc/en/pgmsascdc/v_071/casmlnetwork/casmlnetwork_network_details175.htm).

**What to look for:**
- Network density: Are nodes tightly connected or sparse?
- Visual clusters: Do groups of nodes appear closely connected?
- Isolated nodes: Are there disconnected individuals?
- Hub nodes: Do some nodes appear to have many connections?

*Note: This initial plot uses uniform styling (all nodes share the same color and size) to show the raw network structure.*
*/

%PlotGraph(
   links=casuser.DrugNetwork,
   direction="directed",
   nodescolor="tab:blue",
   nodesshape="o",
   nodessize=50,
   displaylabels=no,
   title="Hartford Drug User Needle-Sharing Network");

/*
#### Loading the Graph Using the `loadGraph` Action
The `loadGraph` action reads the input links table, transforms it into an optimized graph data structure, and loads it into memory for the duration of the current CAS session. This in-memory representation allows subsequent network actions to operate efficiently on the graph without the need to repeatedly reload the data.
In this demo, the graph is very small, so using `loadGraph` is not strictly required from a performance standpoint. However, it is included to showcase best practice, as this approach becomes increasingly important for larger graphs and more complex analytical workflows.
*/

proc cas;
   loadactionset "network";
   action network.loadGraph result=r status=s /
      links        = "DrugNetwork"
      direction    = "directed"
      outGraphList = "OutGraphList";
   run;
   action table.fetch / table = "OutGraphList"; run;
quit;

/*
#### Exploring the Graph Using the `summary` Action
A foundational step in building any analytical model is developing a solid understanding of the underlying data. In the context of network data, exploration goes beyond traditional tabular summaries. By using the `summary` action from the `NETWORK` action set, we can quickly assess key structural properties of the graph, such as the number of nodes and edges, graph density, the number of connected components, and node-level characteristics (for example, whether a node is a leaf).

The following cell demonstrates how to invoke the `summary` action and displays the first twenty rows of the outnodes, providing an initial view of the data before performing more advanced network analytics. From the results, we observe that the network contains 193 strongly connected components and 193 nodes, indicating that each node forms its own component. This implies that the graph contains no directed cycles and can therefore be treated as a directed acyclic graph (DAG).
*/

proc cas;
   action network.summary result=r status=s /
      graph    = 0
      outNodes = "NodesOutSummary"
      out      = "Summary"
      connectedComponents = true;
   run;
   action table.fetch / table = "NodesOutSummary"; run;
   action table.fetch / table = "Summary"; run;
quit;

/*
#### Highlighting Leaf Nodes in the Network

In this step, we further explore the structure of the network by visualizing leaf nodes—nodes with outdegree of zero. Although these nodes may not appear influential based on centrality measures, they often represent important boundary or peripheral participants in the network.

Using the output from the `summary` action in the `NETWORK` action set, we identify which nodes are leaf nodes and highlight them explicitly in the network visualization. This additional layer of information helps distinguish peripheral nodes from more centrally connected individuals and provides deeper insight into the overall topology of the network.

**Why leaf nodes matter:**

In this needle-sharing context, leaf nodes represent individuals who receive needles but do not lend them to others, making them endpoints in observed sharing chains. These “dead-end” nodes may correspond to new participants entering the network, individuals with limited social connections, or users whose risky behaviors are not propagated further.

Understanding leaf nodes helps identify populations that may be particularly vulnerable to exposure while also highlighting potential opportunities for intervention strategies that focus on prevention, monitoring, or supporting disengagement from risky behaviors.
*/

data casuser.NodesOutSummary;
   set casuser.NodesOutSummary;
   length role $20;
   if leaf_node = 1 then role = "Leaf Node";
   else role = "Non-Leaf Node";
run;

%PlotGraph(
   links=casuser.DrugNetwork,
   nodes=casuser.NodesOutSummary,
   direction="directed",
   nodescolorbycategory="role",
   nodescolorlegend=yes,
   nodesshape="o",
   nodessize=50,
   displaylabels=no,
   title="Leaf and Non-Leaf Nodes in the Hartford Drug User Needle-Sharing Network");


/*
#### Identifying Influential Nodes Using Degree Centrality
After gaining an initial understanding of the network structure, we can begin to identify the most important or influential nodes in the graph. One of the simplest and most interpretable measures for this purpose is degree centrality, which quantifies a node’s importance based on the number of direct connections it has to other nodes.

In the following cell, we use the `centrality` action from the `NETWORK` action set to compute unweighted degree centrality for each node in the graph. Degree centrality is particularly useful in needle-sharing networks, as nodes with high degree centrality may represent individuals who share or receive needles with many others and therefore play a disproportionate role in potential disease transmission, making them especially important targets for focused intervention or monitoring.
*/

proc cas;
   action network.centrality result=r status=s /
      graph    = 0
      degree   = "unweight" 
      outNodes = "NodesOutCentrality";
   run;

   action table.fetch
      table  = "NodesOutCentrality"
      sortBy = {{name = "centr_degree"     order="descending"}
                {name = "centr_degree_out" order="descending"}};
   run;
quit;

/*
#### Distinguishing Sources, Bridges, and Leaf Nodes

In the previous step, we visualized the network by highlighting leaf nodes—individuals with zero out-degree who act as endpoints in observed needle-sharing chains. While this view helps identify peripheral and potentially vulnerable participants, it does not fully capture how risk may propagate through the network.

With the centrality results now available, we can extend this analysis by distinguishing among three node roles based on their in-degree and out-degree patterns:

* Source nodes, which lend needles but do not receive them,

* Bridge nodes, which both receive and lend needles and therefore act as transmitters within the network,

* Leaf nodes, which receive needles but do not lend them onward.

We replot the network using this richer classification to better reflect the functional roles individuals play in needle-sharing interactions. In this visualization, node color represents the node role (source, bridge, or leaf), while node size is proportional to the overall degree (in-degree + out-degree), highlighting individuals with higher levels of interaction.

This combined view provides a more nuanced understanding of the network by simultaneously revealing who initiates risk, who propagates it, and where it terminates. Such insights are critical for designing intervention strategies that differentiate between prevention, containment, and harm-reduction efforts across different segments of the network.
*/

data casuser.NodesOutCentrality;
   set casuser.NodesOutCentrality;
   length role $20;
   centr_degree_scaled = centr_degree * 20;  /* Scale for better visualization */
   if centr_degree_out = 0 and centr_degree_in = 0 then role = "Isolated Node";
   else if centr_degree_out > 0 and centr_degree_in = 0 then role = "Source Node";
   else if centr_degree_out = 0 and centr_degree_in > 0 then role = "Leaf Node";
   else role = "Bridge Node";
run;

%PlotGraph(
   links=casuser.DrugNetwork,
   nodes=casuser.NodesOutCentrality,
   direction="directed",
   nodescolorbycategory="role",
   nodescolorlegend=yes,
   nodesshape="o",
   nodessize="centr_degree_scaled",
   displaylabels=no,
   title="Node Roles and Influence in the Hartford Drug User Needle-Sharing Network");

/*
### Detecting Communities in the Network
Beyond identifying influential individual nodes, it is often important to understand how the network organizes itself into groups of closely connected nodes, commonly referred to as communities. Communities can reveal underlying structure in the network, such as subgroups where interactions are more frequent within the group than with the rest of the network.

In the following cell, we use the `community` action from the `NETWORK` action set to detect communities within the graph. This action partitions the network into cohesive subgraphs based on connectivity patterns, allowing us to identify clusters of nodes that may represent tightly connected groups.

Community detection is especially valuable in this setting because it helps highlight localized patterns of interaction and can inform targeted analysis or intervention strategies that focus on groups rather than isolated individuals.

In this step, we apply the Louvain method for community detection and examine how different resolution values affect the granularity of the resulting communities. Lower resolution values tend to identify fewer, larger communities, while higher values yield a greater number of smaller, more fragmented groups.

By experimenting with multiple resolution settings and visually inspecting the resulting network structures, we select a resolution value that provides a balanced and interpretable community partition. This choice reflects a practical trade-off between overly coarse and overly fine community structures and is well suited to the analytical goals of this demonstration.
*/

proc cas;
   action network.community result=r status=s /
      graph = 0
      resolutionList  = 0.3
      outNodes = "NodesOutCommunity";
   run;
   action table.fetch / table = "NodesOutCommunity"; run;
quit;

/*
#### Preparing Results for Visualization

In this step, we combine the outputs from the centrality and community analyses to prepare a unified dataset for visualization. Using the `fedSQL` action, we join the node-level results from the degree centrality analysis with the community assignments. During this merge, we also define a shape attribute based on each node’s role, producing a single table that captures node influence, community membership, and functional role.

This enriched dataset is used directly in the final visualization, where node size represents influence, node color indicates community membership, and node shape reflects the node’s role in the network.
*/

proc cas;
   action fedsql.execDirect result=r status=s /
   query = '
      create table casuser.NodesOutEnriched as
      select
         a.*,
         b.community_0,
         case
            when a.role = ''Leaf Node''   then ''square''
            when a.role = ''Source Node'' then ''triangle''
            when a.role = ''Bridge Node'' then ''circle''
            else ''triangle'' /* isolated nodes */
         end as "shape"
      from casuser.NodesOutCentrality as a
      left join casuser.NodesOutCommunity as b
      on a.node = b.node
   ';
quit;

/*
#### Final Visualization: Communities, Roles, and Node Influence

In this step, we visualize the network in a way that simultaneously highlights community structure, node roles, and node influence. Node color represents community membership, with nodes in the same community sharing the same color. Node size is proportional to the scaled degree centrality score, making more influential nodes visually prominent, while node shape encodes the functional role of each node (source, bridge, leaf, or isolated).

This combined visual representation enables simultaneous exploration of individual-level influence, functional roles, and higher-level community structure, resulting in a more intuitive and informative view of the network.
*/

%PlotGraph(
   links=casuser.DrugNetwork,
   nodes=casuser.NodesOutEnriched,
   direction="directed",
   nodescolorbycategory="community_0",
   nodesshape="shape",
   nodessize="centr_degree_scaled",
   displaylabels=no,
   title="Community Structure, Node Roles, and Node Importance in the Hartford Drug User Needle-Sharing Network \n
          ▲ Source  ● Bridge  ■ Leaf  ◆ Isolated");

/*
#### Ending the CAS Session

After completing the analysis, we terminate the active CAS session to release memory and computational resources. Ending the session is a good practice, especially in shared or long-running environments.

The following step explicitly destroys the CAS session and cleans up all associated in-memory objects.
*/

cas mysession terminate;

/*
#### Conclusion

This analysis demonstrates how network analytics can transform a simple edge list into actionable insight for public health decision-making. Using the SAS Viya `NETWORK` action set, we identified influential individuals based on degree-based influence, distinguished functional roles such as sources, bridges, leaf nodes, and isolated nodes, and uncovered community structure within the network.

By combining node influence (size), community membership (color), and functional role (shape) in a single visualization, we gain a holistic view of how risk may originate, propagate, and terminate across the network. This integrated perspective enables more informed intervention strategies that move beyond uniform approaches and instead focus on individuals and subgroups that play disproportionate roles in network dynamics.
*/

/*
### Future Steps

This analysis provides a foundation for:

- Targeted and community-based interventions by focusing on influential individuals and structurally important communities.

- Temporal and weighted network analysis to capture how needle-sharing frequency and network structure evolve over time.

- Advanced influence and risk modeling using ego network as well as additional centrality measures and intervention scenario analysis.

- Context-aware targeting through integration of domain attributes such as demographics, location, or intervention history.
*/
