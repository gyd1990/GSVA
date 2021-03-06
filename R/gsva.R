##
## function: gsva
## purpose: main function of the package which estimates activity
##          scores for each given gene-set

setGeneric("gsva", function(expr, gset.idx.list, ...) standardGeneric("gsva"))

setMethod("gsva", signature(expr="ExpressionSet", gset.idx.list="list"),
          function(expr, gset.idx.list, annotation,
  method=c("gsva", "ssgsea", "zscore", "plage"),
  kcdf=c("Gaussian", "Poisson", "none"),
  abs.ranking=FALSE,
  min.sz=1,
  max.sz=Inf,
  parallel.sz=0, 
  parallel.type="SOCK",
  mx.diff=TRUE,
  tau=switch(method, gsva=1, ssgsea=0.25, NA),
  ssgsea.norm=TRUE,
  verbose=TRUE)
{
  method <- match.arg(method)
  kcdf <- match.arg(kcdf)

  ## filter out genes with constant expression values
  sdGenes <- Biobase::esApply(expr, 1, sd)
  if (any(sdGenes == 0) || any(is.na(sdGenes))) {
    warning(sum(sdGenes == 0 | is.na(sdGenes)),
            " genes with constant expression values throuhgout the samples.")
    if (method != "ssgsea") {
      warning("Since argument method!=\"ssgsea\", genes with constant expression values are discarded.")
      expr <- expr[sdGenes > 0 & !is.na(sdGenes), ]
    }
  } 

  if (nrow(expr) < 2)
    stop("Less than two genes in the input ExpressionSet object\n")

  ## map to the actual features for which expression data is available
  mapped.gset.idx.list <- lapply(gset.idx.list,
                                 function(x, y) na.omit(match(x, y)),
                                 featureNames(expr))

  if (length(unlist(mapped.gset.idx.list, use.names=FALSE)) == 0)
    stop("No identifiers in the gene sets could be matched to the identifiers in the expression data.")

  ## remove gene sets from the analysis for which no features are available
  ## and meet the minimum and maximum gene-set size specified by the user
  mapped.gset.idx.list <- filterGeneSets(mapped.gset.idx.list,
                                         min.sz=max(1, min.sz),
                                         max.sz=max.sz)

  if (!missing(kcdf)) {
    if (kcdf == "Gaussian") {
      rnaseq <- FALSE
      kernel <- TRUE
    } else if (kcdf == "Poisson") {
      rnaseq <- TRUE
      kernel <- TRUE
    } else
      kernel <- FALSE
  }

  eSco <- .gsva(exprs(expr), mapped.gset.idx.list, method, kcdf, rnaseq, abs.ranking,
                parallel.sz, parallel.type, mx.diff, tau, kernel, ssgsea.norm, verbose)

  eScoEset <- new("ExpressionSet", exprs=eSco, phenoData=phenoData(expr),
                  experimentData=experimentData(expr), annotation="")

  rval <- eScoEset

  rval
})

setMethod("gsva", signature(expr="ExpressionSet", gset.idx.list="GeneSetCollection"),
          function(expr, gset.idx.list, annotation,
  method=c("gsva", "ssgsea", "zscore", "plage"),
  kcdf=c("Gaussian", "Poisson", "none"),
  abs.ranking=FALSE,
  min.sz=1,
  max.sz=Inf,
  parallel.sz=0, 
  parallel.type="SOCK",
  mx.diff=TRUE,
  tau=switch(method, gsva=1, ssgsea=0.25, NA),
  ssgsea.norm=TRUE,
  verbose=TRUE)
{
  method <- match.arg(method)
  kcdf <- match.arg(kcdf)

  ## filter out genes with constant expression values
  sdGenes <- Biobase::esApply(expr, 1, sd)
  if (any(sdGenes == 0) || any(is.na(sdGenes))) {
    warning(sum(sdGenes == 0 | is.na(sdGenes)),
            " genes with constant expression values throuhgout the samples.")
    if (method != "ssgsea") {
      warning("Since argument method!=\"ssgsea\", genes with constant expression values are discarded.")
      expr <- expr[sdGenes > 0 & !is.na(sdGenes), ]
    }
  } 

  if (nrow(expr) < 2)
    stop("Less than two genes in the input ExpressionSet object\n")

  if (verbose)
    cat("Mapping identifiers between gene sets and feature names\n")

  ## map gene identifiers of the gene sets to the features in the chip
  mapped.gset.idx.list <- GSEABase::mapIdentifiers(gset.idx.list,
                                                   GSEABase::AnnoOrEntrezIdentifier(Biobase::annotation(expr)))
  
  ## map to the actual features for which expression data is available
  tmp <- lapply(geneIds(mapped.gset.idx.list),
                                 function(x, y) na.omit(match(x, y)),
                                 featureNames(expr))
  names(tmp) <- names(mapped.gset.idx.list)
  ## remove gene sets from the analysis for which no features are available
  ## and meet the minimum and maximum gene-set size specified by the user
  mapped.gset.idx.list <- filterGeneSets(tmp,
                                         min.sz=max(1, min.sz),
                                         max.sz=max.sz)

  if (!missing(kcdf)) {
    if (kcdf == "Gaussian") {
      rnaseq <- FALSE
      kernel <- TRUE
    } else if (kcdf == "Poisson") {
      rnaseq <- TRUE
      kernel <- TRUE
    } else
      kernel <- FALSE
  }

  eSco <- .gsva(exprs(expr), mapped.gset.idx.list, method, kcdf, rnaseq, abs.ranking,
                parallel.sz, parallel.type, mx.diff, tau, kernel, ssgsea.norm, verbose)

  eScoEset <- new("ExpressionSet", exprs=eSco, phenoData=phenoData(expr),
                  experimentData=experimentData(expr), annotation="")

  rval <- eScoEset

  rval
})

setMethod("gsva", signature(expr="matrix", gset.idx.list="GeneSetCollection"),
          function(expr, gset.idx.list, annotation,
  method=c("gsva", "ssgsea", "zscore", "plage"),
  kcdf=c("Gaussian", "Poisson", "none"),
  abs.ranking=FALSE,
  min.sz=1,
  max.sz=Inf,
  parallel.sz=0, 
  parallel.type="SOCK",
  mx.diff=TRUE,
  tau=switch(method, gsva=1, ssgsea=0.25, NA),
  ssgsea.norm=TRUE,
  verbose=TRUE)
{
  method <- match.arg(method)
  kcdf <- match.arg(kcdf)

  ## filter out genes with constant expression values
  sdGenes <- apply(expr, 1, sd)
  if (any(sdGenes == 0) || any(is.na(sdGenes))) {
    warning(sum(sdGenes == 0 | is.na(sdGenes)),
            " genes with constant expression values throuhgout the samples.")
    if (method != "ssgsea") {
      warning("Since argument method!=\"ssgsea\", genes with constant expression values are discarded.")
      expr <- expr[sdGenes > 0 & !is.na(sdGenes), , drop=FALSE]
    }
  } 

  if (nrow(expr) < 2)
    stop("Less than two genes in the input expression data matrix\n")

  ## map gene identifiers of the gene sets to the features in the matrix
  mapped.gset.idx.list <- gset.idx.list
  if (!missing(annotation)) {
    if (verbose)
      cat("Mapping identifiers between gene sets and feature names\n")

    mapped.gset.idx.list <- GSEABase::mapIdentifiers(gset.idx.list,
                                                     GSEABase::AnnoOrEntrezIdentifier(annotation))
  }
  
  ## map to the actual features for which expression data is available
  tmp <- lapply(geneIds(mapped.gset.idx.list),
                                 function(x, y) na.omit(match(x, y)),
                                 rownames(expr))
  names(tmp) <- names(mapped.gset.idx.list)

  if (length(unlist(tmp, use.names=FALSE)) == 0)
    stop("No identifiers in the gene sets could be matched to the identifiers in the expression data.")

  ## remove gene sets from the analysis for which no features are available
  ## and meet the minimum and maximum gene-set size specified by the user
  mapped.gset.idx.list <- filterGeneSets(tmp,
                                         min.sz=max(1, min.sz),
                                         max.sz=max.sz)

  if (!missing(kcdf)) {
    if (kcdf == "Gaussian") {
      rnaseq <- FALSE
      kernel <- TRUE
    } else if (kcdf == "Poisson") {
      rnaseq <- TRUE
      kernel <- TRUE
    } else
      kernel <- FALSE
  }

  rval <- .gsva(expr, mapped.gset.idx.list, method, kcdf, rnaseq, abs.ranking,
                parallel.sz, parallel.type, mx.diff, tau, kernel, ssgsea.norm, verbose)

  rval
})

setMethod("gsva", signature(expr="matrix", gset.idx.list="list"),
          function(expr, gset.idx.list, annotation,
  method=c("gsva", "ssgsea", "zscore", "plage"),
  kcdf=c("Gaussian", "Poisson", "none"),
  abs.ranking=FALSE,
  min.sz=1,
  max.sz=Inf,
  parallel.sz=0, 
  parallel.type="SOCK",
  mx.diff=TRUE,
  tau=switch(method, gsva=1, ssgsea=0.25, NA),
  ssgsea.norm=TRUE,
  verbose=TRUE)
{
  method <- match.arg(method)
  kcdf <- match.arg(kcdf)

  ## filter out genes with constant expression values
  sdGenes <- apply(expr, 1, sd)
  if (any(sdGenes == 0) || any(is.na(sdGenes))) {
    warning(sum(sdGenes == 0 | is.na(sdGenes)),
            " genes with constant expression values throuhgout the samples.")
    if (method != "ssgsea") {
      warning("Since argument method!=\"ssgsea\", genes with constant expression values are discarded.")
      expr <- expr[sdGenes > 0 & !is.na(sdGenes), , drop=FALSE]
    }
  } 

  if (nrow(expr) < 2)
    stop("Less than two genes in the input expression data matrix\n")

  mapped.gset.idx.list <- lapply(gset.idx.list,
                                 function(x ,y) na.omit(match(x, y)),
                                 rownames(expr))

  if (length(unlist(mapped.gset.idx.list, use.names=FALSE)) == 0)
    stop("No identifiers in the gene sets could be matched to the identifiers in the expression data.")

  ## remove gene sets from the analysis for which no features are available
  ## and meet the minimum and maximum gene-set size specified by the user
  mapped.gset.idx.list <- filterGeneSets(mapped.gset.idx.list,
                                         min.sz=max(1, min.sz),
                                         max.sz=max.sz)

  if (!missing(kcdf)) {
    if (kcdf == "Gaussian") {
      rnaseq <- FALSE
      kernel <- TRUE
    } else if (kcdf == "Poisson") {
      rnaseq <- TRUE
      kernel <- TRUE
    } else
      kernel <- FALSE
  }

  rval <- .gsva(expr, mapped.gset.idx.list, method, kcdf, rnaseq, abs.ranking,
                parallel.sz, parallel.type, mx.diff, tau, kernel, ssgsea.norm, verbose)

  rval
})

.gsva <- function(expr, gset.idx.list,
  method=c("gsva", "ssgsea", "zscore", "plage"),
  kcdf=c("Gaussian", "Poisson", "none"),
  rnaseq=FALSE,
  abs.ranking=FALSE,
  parallel.sz=0, 
  parallel.type="SOCK",
  mx.diff=TRUE,
  tau=1,
  kernel=TRUE,
  ssgsea.norm=TRUE,
  verbose=TRUE)
{
	if(length(gset.idx.list) == 0){
		stop("The gene set list is empty!  Filter may be too stringent.")
	}
	
  if (method == "ssgsea") {
	  if(verbose)
		  cat("Estimating ssGSEA scores for", length(gset.idx.list),"gene sets.\n")

    return(ssgsea(expr, gset.idx.list, alpha=tau, parallel.sz=parallel.sz,
                  parallel.type=parallel.type, normalization=ssgsea.norm,
                  verbose=verbose))
  }

  if (method == "zscore") {
    if (rnaseq)
      stop("rnaseq=TRUE does not work with method='zscore'.")

	  if(verbose)
		  cat("Estimating combined z-scores for", length(gset.idx.list),"gene sets.\n")

    return(zscore(expr, gset.idx.list, parallel.sz, parallel.type, verbose))
  }

  if (method == "plage") {
    if (rnaseq)
      stop("rnaseq=TRUE does not work with method='plage'.")

	  if(verbose)
		  cat("Estimating PLAGE scores for", length(gset.idx.list),"gene sets.\n")

    return(plage(expr, gset.idx.list, parallel.sz, parallel.type, verbose))
  }

	if(verbose)
		cat("Estimating GSVA scores for", length(gset.idx.list),"gene sets.\n")
	
	n.samples <- ncol(expr)
	n.genes <- nrow(expr)
	n.gset <- length(gset.idx.list)
	
	es.obs <- matrix(NaN, n.gset, n.samples, dimnames=list(names(gset.idx.list),colnames(expr)))
	colnames(es.obs) <- colnames(expr)
	rownames(es.obs) <- names(gset.idx.list)
	
	if (verbose)
    cat("Computing observed enrichment scores\n")
	es.obs <- compute.geneset.es(expr, gset.idx.list, 1:n.samples,
                               rnaseq=rnaseq, abs.ranking=abs.ranking, parallel.sz=parallel.sz,
                               parallel.type=parallel.type, mx.diff=mx.diff, tau=tau,
                               kernel=kernel, verbose=verbose)
	
	colnames(es.obs) <- colnames(expr)
	rownames(es.obs) <- names(gset.idx.list)

	es.obs
}


compute.gene.density <- function(expr, sample.idxs, rnaseq=FALSE, kernel=TRUE){
	n.test.samples <- ncol(expr)
	n.genes <- nrow(expr)
	n.density.samples <- length(sample.idxs)
	
  gene.density <- NA
  if (kernel) {
	  A = .C("matrix_density_R",
			as.double(t(expr[ ,sample.idxs, drop=FALSE])),
			as.double(t(expr)),
			R = double(n.test.samples * n.genes),
			n.density.samples,
			n.test.samples,
			n.genes,
      as.integer(rnaseq))$R
	
	  gene.density <- t(matrix(A, n.test.samples, n.genes))
  } else {
    gene.density <- t(apply(expr, 1, function(x, sample.idxs) {
                                     f <- ecdf(x[sample.idxs])
                                     f(x)
                                   }, sample.idxs))
    gene.density <- log(gene.density / (1-gene.density))
  }

	return(gene.density)	
}

compute.geneset.es <- function(expr, gset.idx.list, sample.idxs, rnaseq=FALSE,
                               abs.ranking, parallel.sz=0, parallel.type="SOCK",
                               mx.diff=TRUE, tau=1, kernel=TRUE, verbose=TRUE){
	num_genes <- nrow(expr)
	if (verbose) {
    if (kernel) {
      if (rnaseq)
        cat("Estimating ECDFs with Poisson kernels\n")
      else
        cat("Estimating ECDFs with Gaussian kernels\n")
    } else
      cat("Estimating ECDFs directly\n")
  }
	gene.density <- compute.gene.density(expr, sample.idxs, rnaseq, kernel)
	
	compute_rank_score <- function(sort_idx_vec){
		tmp <- rep(0, num_genes)
		tmp[sort_idx_vec] <- abs(seq(from=num_genes,to=1) - num_genes/2)
		return (tmp)
	}
	
	rank.scores <- rep(0, num_genes)
  sort.sgn.idxs <- apply(gene.density, 2, order, decreasing=TRUE) # n.genes * n.samples
	
	rank.scores <- apply(sort.sgn.idxs, 2, compute_rank_score)
	
	haveParallel <- .isPackageLoaded("parallel")
	haveSnow <- .isPackageLoaded("snow")
	
	if (parallel.sz > 1 || haveParallel) {
		if (!haveParallel && !haveSnow) {
			stop("In order to run calculations in parallel either the 'snow', or the 'parallel' library, should be loaded first")
		}

    if (haveSnow) {  ## use snow
      ## copying ShortRead's strategy, the calls to the 'get()' are
      ## employed to quieten R CMD check, and for no other reason
      makeCl <- get("makeCluster", mode="function")
      parSapp <- get("parSapply", mode="function")
      clEvalQ <- get("clusterEvalQ", mode="function")
      stopCl <- get("stopCluster", mode="function")

      if (verbose)
        cat("Allocating cluster\n")
		  cl <- makeCl(parallel.sz, type = parallel.type) 
		  clEvalQ(cl, library(GSVA))
		  if (verbose) {
		    cat("Estimating enrichment scores in parallel\n")
	      if(mx.diff) {
          cat("Taking diff of max KS.\n")
        } else{
          cat("Evaluting max KS.\n")
        }
      }
	
		  m <- t(parSapp(cl, gset.idx.list, ks_test_m,
						  gene.density=rank.scores, 
						  sort.idxs=sort.sgn.idxs,
						  mx.diff=mx.diff, abs.ranking=abs.ranking,
              tau=tau, verbose=FALSE))
		  if(verbose)
        cat("Cleaning up\n")
		  stopCl(cl)

    } else if (haveParallel) {             ## use parallel

      mclapp <- get('mclapply', envir=getNamespace('parallel'))
      detCor <- get('detectCores', envir=getNamespace('parallel'))
      nCores <- detCor()
      options(mc.cores=nCores)
      if (parallel.sz > 0 && parallel.sz < nCores)
        options(mc.cores=parallel.sz)

      pb <- NULL
      if (verbose){
        cat("Using parallel with", getOption("mc.cores"), "cores\n")
        assign("progressBar", txtProgressBar(style=3), envir=globalenv()) ## show progress if verbose=TRUE
        assign("nGeneSets", ceiling(length(gset.idx.list) / getOption("mc.cores")), envir=globalenv())
        assign("iGeneSet", 0, envir=globalenv())
      }

      m <- mclapp(gset.idx.list, ks_test_m,
                  gene.density=rank.scores,
                  sort.idxs=sort.sgn.idxs,
                  mx.diff=mx.diff, abs.ranking=abs.ranking,
                  tau=tau, verbose=verbose)
      m <- do.call("rbind", m)
      colnames(m) <- colnames(expr)

      if (verbose) {
        close(get("progressBar", envir=globalenv()))
      }
    } else
			stop("In order to run calculations in parallel either the 'snow', or the 'parallel' library, should be loaded first")

	} else {
		if (verbose) {
      cat("Estimating enrichment scores\n")
	    if (mx.diff) {
        cat("Taking diff of max KS.\n")
      } else{
        cat("Evaluting max KS.\n")
      }
    }
    pb <- NULL
    if (verbose){
      assign("progressBar", txtProgressBar(style=3), envir=globalenv()) ## show progress if verbose=TRUE
      assign("nGeneSets", length(gset.idx.list), envir=globalenv())
      assign("iGeneSet", 0, envir=globalenv())
    }

		m <- t(sapply(gset.idx.list, ks_test_m, rank.scores, sort.sgn.idxs,
                  mx.diff=mx.diff, abs.ranking=abs.ranking,
                  tau=tau, verbose=verbose))

    if (verbose) {
      setTxtProgressBar(get("progressBar", envir=globalenv()), 1)
      close(get("progressBar", envir=globalenv()))
    }
	}
	return (m)
}


ks_test_m <- function(gset_idxs, gene.density, sort.idxs, mx.diff=TRUE,
                      abs.ranking=FALSE, tau=1, verbose=TRUE){
	
	n.genes <- nrow(gene.density)
	n.samples <- ncol(gene.density)
	n.geneset <- length(gset_idxs)

	geneset.sample.es = .C("ks_matrix_R",
			as.double(gene.density),
			R = double(n.samples),
			as.integer(sort.idxs),
			n.genes,
			as.integer(gset_idxs),
			n.geneset,
			as.double(tau),
			n.samples,
			as.integer(mx.diff),
      as.integer(abs.ranking))$R

  if (verbose) {
    assign("iGeneSet", get("iGeneSet", envir=globalenv()) + 1, envir=globalenv())
    setTxtProgressBar(get("progressBar", envir=globalenv()),
                      get("iGeneSet", envir=globalenv()) / get("nGeneSets", envir=globalenv()))
  }
	
	return(geneset.sample.es)
}


## ks-test in R code - testing only
ks_test_Rcode <- function(gene.density, gset_idxs, tau=1, make.plot=FALSE){
	
	n.genes = length(gene.density)
	n.gset = length(gset_idxs)
	
	sum.gset <- sum(abs(gene.density[gset_idxs])^tau)
	
	dec = 1 / (n.genes - n.gset)
	
	sort.idxs <- order(gene.density,decreasing=T)
	offsets <- sort(match(gset_idxs, sort.idxs))
	
	last.idx = 0
	values <- rep(NaN, length(gset_idxs))
	current = 0
	for(i in seq_along(offsets)){
		current = current + abs(gene.density[sort.idxs[offsets[i]]])^tau / sum.gset - dec * (offsets[i]-last.idx-1)
		
		values[i] = current
		last.idx = offsets[i]
	}
	check_zero = current - dec * (n.genes-last.idx)
	#if(check_zero > 10^-15){ 
	#	stop(paste=c("Expected zero sum for ks:", check_zero))
	#}
	if(make.plot){ plot(offsets, values,type="l") } 
	
	max.idx = order(abs(values),decreasing=T)[1]
	mx.value <- values[max.idx]
	
	return (mx.value)
}

rndWalk <- function(gSetIdx, geneRanking, j, R, alpha) {
  indicatorFunInsideGeneSet <- match(geneRanking, gSetIdx)
  indicatorFunInsideGeneSet[!is.na(indicatorFunInsideGeneSet)] <- 1
  indicatorFunInsideGeneSet[is.na(indicatorFunInsideGeneSet)] <- 0
  stepCDFinGeneSet <- cumsum((abs(R[geneRanking, j]) * 
                      indicatorFunInsideGeneSet)^alpha) /
                      sum((abs(R[geneRanking, j]) *
                      indicatorFunInsideGeneSet)^alpha)
  stepCDFoutGeneSet <- cumsum(!indicatorFunInsideGeneSet) /
                       sum(!indicatorFunInsideGeneSet)
  walkStat <- stepCDFinGeneSet - stepCDFoutGeneSet

  sum(walkStat) 
}

ssgsea <- function(X, geneSets, alpha=0.25, parallel.sz,
                   parallel.type, normalization=TRUE, verbose) {

  p <- nrow(X)
  n <- ncol(X)

  if (verbose) {
    assign("progressBar", txtProgressBar(style=3), envir=globalenv()) ## show progress if verbose=TRUE
    assign("nSamples", n, envir=globalenv())
    assign("iSample", 0, envir=globalenv())
  }

  R <- apply(X, 2, function(x,p) as.integer(rank(x)), p)

	haveParallel <- .isPackageLoaded("parallel")
	haveSnow <- .isPackageLoaded("snow")
	
  cl <- makeCl <- parSapp <- stopCl <- mclapp <- detCor <- nCores <- NA
	if (parallel.sz > 1 || haveParallel) {
		if (!haveParallel && !haveSnow) {
			stop("In order to run calculations in parallel either the 'snow', or the 'parallel' library, should be loaded first")
		}

    if (!haveParallel) {  ## use snow
      ## copying ShortRead's strategy, the calls to the 'get()' are
      ## employed to quieten R CMD check, and for no other reason
      makeCl <- get("makeCluster", mode="function")
      parSapp <- get("parSapply", mode="function")
      stopCl <- get("stopCluster", mode="function")

      if (verbose)
        cat("Allocating cluster\n")
		  cl <- makeCl(parallel.sz, type = parallel.type) 
    } else {             ## use parallel

      mclapp <- get('mclapply', envir=getNamespace('parallel'))
      detCor <- get('detectCores', envir=getNamespace('parallel'))
      nCores <- detCor()
      options(mc.cores=nCores)
      if (parallel.sz > 0 && parallel.sz < nCores)
        options(mc.cores=parallel.sz)
      if (verbose)
        cat("Using parallel with", getOption("mc.cores"), "cores\n")
    }
  }

  es <- sapply(1:n, function(j, R, geneSets, alpha) {
                      if (verbose) {
                        assign("iSample", get("iSample", envir=globalenv()) + 1, envir=globalenv())
                        setTxtProgressBar(get("progressBar", envir=globalenv()),
                                          get("iSample", envir=globalenv()) / get("nSamples", envir=globalenv()))
                      }
                      geneRanking <- order(R[, j], decreasing=TRUE)
                      es_sample <- NA
                      if (parallel.sz == 1 || (is.na(cl) && !haveParallel))
                        es_sample <- sapply(geneSets, rndWalk, geneRanking, j, R, alpha)
                      else {
                        if (is.na(cl))
                          es_sample <- mclapp(geneSets, rndWalk, geneRanking, j, R, alpha)
                        else
                          es_sample <- parSapp(cl, geneSets, rndWalk, geneRanking, j, R, alpha)
                      }

                      unlist(es_sample)
                    }, R, geneSets, alpha)

  if (length(geneSets) == 1)
    es <- matrix(es, nrow=1)

  if (normalization) {
    ## normalize enrichment scores by using the entire data set, as indicated
    ## by Barbie et al., 2009, online methods, pg. 2
    es <- apply(es, 2, function(x, es) x / (range(es)[2] - range(es)[1]), es)
  }

  if (length(geneSets) == 1)
    es <- matrix(es, nrow=1)

  rownames(es) <- names(geneSets)
  colnames(es) <- colnames(X)

  if (verbose) {
    setTxtProgressBar(get("progressBar", envir=globalenv()), 1)
    close(get("progressBar", envir=globalenv()))
  }

  if (!is.na(cl))
    stopCl(cl)

  es
}

combinez <- function(gSetIdx, j, Z) sum(Z[gSetIdx, j]) / sqrt(length(gSetIdx))

zscore <- function(X, geneSets, parallel.sz, parallel.type, verbose) {

  p <- nrow(X)
  n <- ncol(X)

  if (verbose) {
    assign("progressBar", txtProgressBar(style=3), envir=globalenv()) ## show progress if verbose=TRUE
    assign("nSamples", n, envir=globalenv())
    assign("iSample", 0, envir=globalenv())
  }

  Z <- t(apply(X, 1, function(x) (x-mean(x))/sd(x)))

	haveParallel <- .isPackageLoaded("parallel")
	haveSnow <- .isPackageLoaded("snow")
	
  cl <- makeCl <- parSapp <- stopCl <- mclapp <- detCor <- nCores <- NA
	if (parallel.sz > 1 || haveParallel) {
		if (!haveParallel && !haveSnow) {
			stop("In order to run calculations in parallel either the 'snow', or the 'parallel' library, should be loaded first")
		}

    if (!haveParallel) {  ## use snow
      ## copying ShortRead's strategy, the calls to the 'get()' are
      ## employed to quieten R CMD check, and for no other reason
      makeCl <- get("makeCluster", mode="function")
      parSapp <- get("parSapply", mode="function")
      stopCl <- get("stopCluster", mode="function")

      if (verbose)
        cat("Allocating cluster\n")
		  cl <- makeCl(parallel.sz, type = parallel.type) 
    } else {             ## use parallel

      mclapp <- get('mclapply', envir=getNamespace('parallel'))
      detCor <- get('detectCores', envir=getNamespace('parallel'))
      nCores <- detCor()
      options(mc.cores=nCores)
      if (parallel.sz > 0 && parallel.sz < nCores)
        options(mc.cores=parallel.sz)
      if (verbose)
        cat("Using parallel with", getOption("mc.cores"), "cores\n")
    }
  }

  es <- sapply(1:n, function(j, Z, geneSets) {
                      if (verbose) {
                        assign("iSample", get("iSample", envir=globalenv()) + 1, envir=globalenv())
                        setTxtProgressBar(get("progressBar", envir=globalenv()),
                                          get("iSample", envir=globalenv()) / get("nSamples", envir=globalenv()))
                      }
                      es_sample <- NA
                      if (parallel.sz == 1 || (is.na(cl) && !haveParallel))
                        es_sample <- sapply(geneSets, combinez, j, Z)
                      else {
                        if (is.na(cl))
                          es_sample <- mclapp(geneSets, combinez, j, Z)
                        else
                          es_sample <- parSapp(cl, geneSets, combinez, j, Z)
                      }

                      unlist(es_sample)
                    }, Z, geneSets)

  if (length(geneSets) == 1)
    es <- matrix(es, nrow=1)

  rownames(es) <- names(geneSets)
  colnames(es) <- colnames(X)

  if (verbose) {
    setTxtProgressBar(get("progressBar", envir=globalenv()), 1)
    close(get("progressBar", envir=globalenv()))
  }

  if (!is.na(cl))
    stopCl(cl)

  es
}

rightsingularsvdvectorgset <- function(gSetIdx, Z) {
    s <- svd(Z[gSetIdx, ])
  s$v[, 1]
}

plage <- function(X, geneSets, parallel.sz, parallel.type, verbose) {

  p <- nrow(X)
  n <- ncol(X)

  if (verbose) {
    assign("progressBar", txtProgressBar(style=3), envir=globalenv()) ## show progress if verbose=TRUE
    assign("nGeneSets", length(geneSets), envir=globalenv())
    assign("iGeneSet", 0, envir=globalenv())
  }

  Z <- t(apply(X, 1, function(x) (x-mean(x))/sd(x)))

	haveParallel <- .isPackageLoaded("parallel")
	haveSnow <- .isPackageLoaded("snow")
	
  ## the masterDescriptor() calls are disabled since they are not available in windows
  ## they would help to report progress by just one of the processors. now all processors
  ## will reporting progress. while this might not be the right way to report progress in
  ## parallel it should not affect a correct execution and progress should be more or less
  ## being reported to some extent.
  cl <- makeCl <- parSapp <- stopCl <- mclapp <- detCor <- nCores <- NA ## masterDesc <- NA
	if(parallel.sz > 1 || haveParallel) {
		if(!haveParallel && !haveSnow) {
			stop("In order to run calculations in parallel either the 'snow', or the 'parallel' library, should be loaded first")
		}

    if (!haveParallel) {  ## use snow
      ## copying ShortRead's strategy, the calls to the 'get()' are
      ## employed to quieten R CMD check, and for no other reason
      makeCl <- get("makeCluster", mode="function")
      parSapp <- get("parSapply", mode="function")
      stopCl <- get("stopCluster", mode="function")

      if (verbose)
        cat("Allocating cluster\n")
		  cl <- makeCl(parallel.sz, type = parallel.type) 
    } else {             ## use parallel

      mclapp <- get('mclapply', envir=getNamespace('parallel'))
      detCor <- get('detectCores', envir=getNamespace('parallel'))
      ## masterDesc <- get('masterDescriptor', envir=getNamespace('parallel'))
      nCores <- detCor()
      options(mc.cores=nCores)
      if (parallel.sz > 0 && parallel.sz < nCores)
        options(mc.cores=parallel.sz)
      if (verbose)
        cat("Using parallel with", getOption("mc.cores"), "cores\n")
    }
  }

  if (parallel.sz == 1 || (is.na(cl) && !haveParallel))
    es <- t(sapply(geneSets, function(gset, Z) {
                             if (verbose) {
                               assign("iGeneSet", get("iGeneSet", envir=globalenv()) + 1, envir=globalenv())
                               setTxtProgressBar(get("progressBar", envir=globalenv()),
                                                 get("iGeneSet", envir=globalenv()) / get("nGeneSets", envir=globalenv()))
                             }
                             rightsingularsvdvectorgset(gset, Z)
                           }, Z))
  else {
    if (is.na(cl)) {
      ## firstproc <- mclapp(as.list(1:(options("mc.cores")$mc.cores)), function(x) masterDesc())[[1]]
      es <- mclapp(geneSets, function(gset, Z) { ##, firstproc) {
                                 if (verbose) { ## && masterDesc() == firstproc) {
                                   assign("iGeneSet", get("iGeneSet", envir=globalenv()) + 1, envir=globalenv())
                                   setTxtProgressBar(get("progressBar", envir=globalenv()),
                                                     get("iGeneSet", envir=globalenv()) / get("nGeneSets", envir=globalenv()))
                                 }
                                 rightsingularsvdvectorgset(gset, Z)
                               }, Z) ##, firstproc)
      es <- do.call(rbind, es)
    } else {
      if (verbose)
        message("Progress reporting for plage with a snow cluster not yet implemented")

      es <- parSapp(geneSets, function(gset, Z) {
                                  if (verbose) {
                                    assign("iGeneSet", get("iGeneSet", envir=globalenv()) + 1, envir=globalenv())
                                    setTxtProgressBar(get("progressBar", envir=globalenv()),
                                                      get("iGeneSet", envir=globalenv()) / get("nGeneSets", envir=globalenv()))
                                  }
                                  rightsingularsvdvectorgset(gset, Z)
                                }, Z)
      es <- do.call(rbind, es)
    }
  }

  if (length(geneSets) == 1)
    es <- matrix(es, nrow=1)

  rownames(es) <- names(geneSets)
  colnames(es) <- colnames(X)

  if (verbose) {
    setTxtProgressBar(get("progressBar", envir=globalenv()), 1)
    close(get("progressBar", envir=globalenv()))
  }

  if (!is.na(cl))
    stopCl(cl)

  es
}

setGeneric("filterGeneSets", function(gSets, ...) standardGeneric("filterGeneSets"))

setMethod("filterGeneSets", signature(gSets="list"),
          function(gSets, min.sz=1, max.sz=Inf) {
	gSetsLen <- sapply(gSets,length)
	return (gSets[gSetsLen >= min.sz & gSetsLen <= max.sz])	
})

setMethod("filterGeneSets", signature(gSets="GeneSetCollection"),
          function(gSets, min.sz=1, max.sz=Inf) {
	gSetsLen <- sapply(geneIds(gSets),length)
	return (gSets[gSetsLen >= min.sz & gSetsLen <= max.sz])	
})



setGeneric("computeGeneSetsOverlap", function(gSets, uniqGenes=unique(unlist(gSets, use.names=FALSE)), ...) standardGeneric("computeGeneSetsOverlap"))

setMethod("computeGeneSetsOverlap", signature(gSets="list", uniqGenes="character"),
          function(gSets, uniqGenes, min.sz=1, max.sz=Inf) {
  totalGenes <- length(uniqGenes)

  ## map to the features requested
  gSets <- lapply(gSets, function(x, y) as.vector(na.omit(match(x, y))), uniqGenes)

  lenGsets <- sapply(gSets, length)
  totalGsets <- length(gSets)

  gSetsMembershipMatrix <- matrix(0, nrow=totalGenes, ncol=totalGsets,
                                  dimnames=list(uniqGenes, names(gSets)))
  members <- cbind(unlist(gSets, use.names=FALSE), rep(1:totalGsets, times=lenGsets))
  gSetsMembershipMatrix[members] <- 1

  .computeGeneSetsOverlap(gSetsMembershipMatrix, min.sz, max.sz)
})

setMethod("computeGeneSetsOverlap", signature(gSets="list", uniqGenes="ExpressionSet"),
          function(gSets, uniqGenes, min.sz=1, max.sz=Inf) {
  uniqGenes <- Biobase::featureNames(uniqGenes)
  totalGenes <- length(uniqGenes)

  ## map to the actual features for which expression data is available
  gSets <- lapply(gSets, function(x, y) as.vector(na.omit(match(x, y))), uniqGenes)

  lenGsets <- sapply(gSets, length)
  totalGsets <- length(gSets)

  gSetsMembershipMatrix <- matrix(0, nrow=totalGenes, ncol=totalGsets,
                                  dimnames=list(uniqGenes, names(gSets)))
  members <- cbind(unlist(gSets, use.names=FALSE), rep(1:totalGsets, times=lenGsets))
  gSetsMembershipMatrix[members] <- 1

  .computeGeneSetsOverlap(gSetsMembershipMatrix, min.sz, max.sz)
})

setMethod("computeGeneSetsOverlap", signature(gSets="GeneSetCollection", uniqGenes="character"),
          function(gSets, uniqGenes, min.sz=1, max.sz=Inf) {

  gSetsMembershipMatrix <- incidence(gSets)
  gSetsMembershipMatrix <- t(gSetsMembershipMatrix[, colnames(gSetsMembershipMatrix) %in% uniqGenes])

  .computeGeneSetsOverlap(gSetsMembershipMatrix, min.sz, max.sz)
})

setMethod("computeGeneSetsOverlap", signature(gSets="GeneSetCollection", uniqGenes="ExpressionSet"),
          function(gSets, uniqGenes, min.sz=1, max.sz=Inf) {
  ## map gene identifiers of the gene sets to the features in the chip
  gSets <- GSEABase::mapIdentifiers(gSets, GSEABase::AnnoOrEntrezIdentifier(Biobase::annotation(uniqGenes)))
  
  uniqGenes <- Biobase::featureNames(uniqGenes)

  gSetsMembershipMatrix <- incidence(gSets)
  gSetsMembershipMatrix <- t(gSetsMembershipMatrix[, colnames(gSetsMembershipMatrix) %in% uniqGenes])

  .computeGeneSetsOverlap(gSetsMembershipMatrix, min.sz, max.sz)
})

.computeGeneSetsOverlap <- function(gSetsMembershipMatrix, min.sz=1, max.sz=Inf) {
  ## gSetsMembershipMatrix should be a (genes x gene-sets) incidence matrix

  lenGsets <- colSums(gSetsMembershipMatrix)

  szFilterMask <- lenGsets >= max(1, min.sz) & lenGsets <= max.sz
  if (!any(szFilterMask))
    stop("No gene set meets the minimum and maximum size filter\n")

  gSetsMembershipMatrix <- gSetsMembershipMatrix[, szFilterMask]
  lenGsets <- lenGsets[szFilterMask]

  totalGsets <- ncol(gSetsMembershipMatrix)

  M <- t(gSetsMembershipMatrix) %*% gSetsMembershipMatrix

  M1 <- matrix(lenGsets, nrow=totalGsets, ncol=totalGsets,
               dimnames=list(colnames(gSetsMembershipMatrix), colnames(gSetsMembershipMatrix)))
  M2 <- t(M1)
  M.min <- matrix(0, nrow=totalGsets, ncol=totalGsets)
  M.min[M1 < M2] <- M1[M1 < M2]
  M.min[M2 <= M1] <- M2[M2 <= M1]
  overlapMatrix <- M / M.min

  return (overlapMatrix)
}

## from https://stat.ethz.ch/pipermail/r-help/2005-September/078974.html
## function: isPackageLoaded
## purpose: to check whether the package specified by the name given in
##          the input argument is loaded. this function is borrowed from
##          the discussion on the R-help list found in this url:
##          https://stat.ethz.ch/pipermail/r-help/2005-September/078974.html
## parameters: name - package name
## return: TRUE if the package is loaded, FALSE otherwise

.isPackageLoaded <- function(name) {
  ## Purpose: is package 'name' loaded?
  ## --------------------------------------------------
  (paste("package:", name, sep="") %in% search()) ||
  (name %in% loadedNamespaces())
}

##
## ARE THESE FUNCTIONS STILL NECESSARY ?????
##

##a <- replicate(1000, compute.null.enrichment(10000,50,make.plot=F))

compute.null.enrichment <- function(n.genes, n.geneset, make.plot=FALSE){
	ranks <- (n.genes/2) - rev(1:n.genes)
	#null.gset.idxs <- seq(1, n.genes, by=round(n.genes / n.geneset))
	null.gset.idxs <- sample(n.genes, n.geneset)
	null.es <- ks_test_Rcode(ranks, null.gset.idxs,make.plot=make.plot)
	return (null.es)
}


load.gmt.data <- function(gmt.file.path){
	tmp <- readLines(gmt.file.path)
	gsets <- list()
	for(i in 1:length(tmp)){
		t <- strsplit(tmp[i],'\t')[[1]]
		gsets[[t[1]]] <- t[3:length(t)]
	}
	return (gsets)
}

compute.gset.overlap.score <- function(gset.idxs){
	n <- length(gset.idxs)
	mx.idx <- max(unlist(gset.idxs, use.names=F))
	l <- c(sapply(gset.idxs, length))
	
	gset.M <- matrix(0, nrow=mx.idx, ncol=n)
	for(i in 1:n){
		gset.M[gset.idxs[[i]],i] = 1
	}
	M <- t(gset.M) %*% gset.M
	
	M1 <- matrix(l, nrow=n, ncol=n)
	M2 <- t(M1)
	M.min <- matrix(0, nrow=n, ncol=n)
	M.min[M1 < M2] <- M1[M1 < M2]
	M.min[M2 <= M1] <- M2[M2 <= M1]
	M.score <- M / M.min
	return (M.score)
}
