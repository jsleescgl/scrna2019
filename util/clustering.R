#clustering utility functions
library(Seurat)
suppressPackageStartupMessages(library(mclust))

ari<-mclust::adjustedRandIndex

silfunc<-function(clust,DM){
  #compute silhouette coefficient of a clustering
  #case where only one cluster, set silhouette to zero
  #clust=indicator vector of cluster labels
  #DM=distance object computed from some embedding (eg, DM<-dist(embed))
  if(length(unique(clust))==1){ return(0) }
  sil<-cluster::silhouette(as.numeric(clust),DM)
  tryCatch(mean(sil[,3]),error=function(e){NA})
}

seurat_cluster_inner<-function(seu,dims,res){
  seu<-FindNeighbors(seu,dims=1:dims,verbose=FALSE)
  seu<-FindClusters(seu,resolution=res,verbose=FALSE)
  #seu<-FindClusters(seu,dims.use=1:dims,resolution=res,print.output=0)
  ans<-FetchData(seu,"ident")
  colnames(ans)<-"cluster"
  ans$cell<-rownames(ans)
  ans$k<-length(unique(ans$cluster))
  ans$resolution<-res
  ans$dims<-dims
  #put cell IDs as first column
  ans[,c(1,2)]<-ans[,c(2,1)]
  colnames(ans)[c(1,2)]<-colnames(ans)[c(2,1)]
  ans
}

seurat_cluster<-function(embed,dims=ncol(embed),res=c(0.1,0.5,1.0)){
  seu<-CreateSeuratObject(t(embed)) #placeholder object
  seu[["pca"]]<-CreateDimReducObject(as.matrix(embed),key="PC_",assay=DefaultAssay(seu))
  #seu<-SetDimReduction(seu,reduction.type="pca",slot="cell.embeddings",new.data=as.matrix(embed))
  #seu<-SetDimReduction(seu,reduction.type="pca",slot="key",new.data="PC")
  pars<-expand.grid(res=res,dims=dims)
  f<-function(i){seurat_cluster_inner(seu,pars$dims[i],pars$res[i])}
  ans<-do.call(rbind,lapply(1:nrow(pars),f))
  ans$method<-"seurat"
  ans
}

kmeans_cluster_inner<-function(embed,dims,k,...){
  cl<-kmeans(embed[,1:dims],k,...)$cluster
  data.frame(cell=rownames(embed),cluster=cl,k=k,resolution=NA,dims=dims)
}

kmeans_cluster<-function(embed,dims=ncol(embed),k=2:15,nst=100,imx=20){
  pars<-expand.grid(k=k,dims=dims)
  f<-function(i){
    kmeans_cluster_inner(embed,pars$dims[i],pars$k[i],nstart=nst,iter.max=imx)
  }
  ans<-do.call(rbind,lapply(1:nrow(pars),f))
  ans$method<-"kmeans"
  ans
}

mclust_inner<-function(embed,dims,k){
  cl<-Mclust(embed[,1:dims],k,verbose=FALSE)$classification
  data.frame(cell=rownames(embed),cluster=cl,k=k,resolution=NA,dims=dims)
}

mclust_cluster<-function(embed,dims=ncol(embed),k=2:15){
  pars<-expand.grid(k=k,dims=dims)
  f<-function(i){
    mclust_inner(embed,pars$dims[i],pars$k[i])
  }
  ans<-do.call(rbind,lapply(1:nrow(pars),f))
  ans$method<-"mclust"
  ans
}
