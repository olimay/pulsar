<!-- README.md is generated from README.Rmd. Please edit that file -->



# pulsar: Paralellized Utilities for lambda Selection Along a Regularization path.

This package is an implementation of the Stability Approach to Regularization Selection 
([StARS, H. Liu - 2010](http://papers.nips.cc/paper/3966-stability-approach-to-regularization-selection-stars-for-high-dimensional-graphical-models.pdf)),
with options for speedups, paralellizations and alternate/complementary metrics 
(most notably, graphlet stability). This package is intended for selection of L1-regularized graphical
models (e.g. glasso or Meinshausen-Buhlmann neighborhood selection), where the level of sparsity is
typically parametrized by *lambda*. This R package uses function passing to allow you to use your
favorite implementation (e.g. huge, QUIC, etc) for graphical model learning along a lambda
regularization path.The method is quite generic and could be used for other Lasso-type problems as
well.

Additionally, this package implements an option to find lower/upper bounds on the StARS-selected 
lambda, using some heuristics that work well in practice. This allows us to cut off a large chunk of
the lambda path after after only N=2 subsamples. 
This works well particularly for sparse graphs when the dimensionality is high (above 20 variables
or so).  Thus, computational burden is greatly reduced, especially when many subsamples are required
and even when running in embarassingly parallel (batch) mode. We also use these bounds to narrow the
range that we look for relative stable points over an induced-subgraph (graphlet) stability metric.

In batch computing systems, we use the [BatchJobs](http://cran.r-project.org/package=BatchJobs)
Map/Reduce strategy (for batch computing systems such as Torque, LSF, SLURM or SGE) which can 
significantly reduce the computation and memory burdens for StARS. This is useful for hpc users, 
when the number of processors available on a multicore machine only allows modest parallelization.

Please see the paper preprint on [arXiv](http://arxiv.org/abs/1605.07072).


## Installation

Installation of the current development version of pulsar requires the devtools package. Also we
recommend some other packages for installation as needed (such as `huge`).


```r
library(devtools)
install_github("zdk123/pulsar")
library(pulsar)
```

## Basic usage

For this readme, we will use synthetic data, generated from the `huge` package.


```r
library(huge)
set.seed(10010)
p <- 40 ; n <- 1200
dat  <- huge.generator(n, p, "hub", verbose=FALSE, v=.1, u=.3)
lams <- getLamPath(.2, .01, len=40)
```

You can use the `pulsar` package to run StARS, serially, as a drop-in replacement for the 
`huge.select` function in the `huge` package. Pulsar differs in that we run the model selection step
first and then refit using arguments stored in the original call. Remove the `seed` argument for
real data (this seeds the pseudo-random number generator to fix subsampling for reproducing test
code).


```r
hugeargs <- list(lambda=lams, verbose=FALSE)
time1    <- system.time(
out.p    <- pulsar(dat$data, fun=huge::huge, fargs=hugeargs,
                rep.num=20, criterion='stars', seed=10010))
fit.p    <- refit(out.p)
```

Inspect the output:

```r
out.p
# Mode: serial
# Path length: 40 
# Subsamples:  20 
# Graph dim:   40 
# Criterion:
#   stars.stability... opt: index 15, lambda 0.132
fit.p
# Pulsar-selected refit of huge::huge 
# Path length: 40 
# Graph dim:   40 
# Criterion:
#   stars... sparsity 0.0325
```

Including the lower bound option `lb.stars` and upper bound option `ub.stars` can improve runtime
for same StARS result.


```r
time2 <- system.time(
out.b <- pulsar(dat$data, fun=huge::huge, fargs=hugeargs,
                rep.num=20, criterion='stars', seed=10010,
                lb.stars=TRUE, ub.stars=TRUE))
```

Compare runtimes and StARS selected lambda index for each method.


```r
time2[[3]] < time1[[3]]
# [1] TRUE
opt.index(out.p, 'stars') == opt.index(out.b, 'stars')
# [1] TRUE
```

## Using a custom graphical model method

You can pass in an arbitrary graphical model estimation function to fun. The function has some
requirements: the first argument must be the nxp data matrix, and one argument must be named lambda,
which should be a decreasing numeric vector containing the lambda path. 
The output should be a list of adjacency matrices (which can be of sparse representation from the
`Matrix` package to save memory).
Here is an example from `QUIC`.


```r
library(QUIC)
quicr <- function(data, lambda) {
    S    <- cov(data)
    est  <- QUIC::QUIC(S, rho=1, path=lambda, msg=0, tol=1e-2)
    path <-  lapply(seq(length(lambda)), function(i) {
                tmp <- est$X[,,i]; diag(tmp) <- 0
                as(tmp!=0, "lgCMatrix")
    })
    est$path <- path
    est
}
```

We can use pulsar with a similar call. We can also parallelize this a bit for multi-processor
machines by specifying ncores (which wraps mclapply in the parallel package).

```r
quicargs <- list(lambda=lams)
out.q <- pulsar(dat$data, fun=quicr, fargs=quicargs,
                rep.num=100, criterion='stars', seed=10010,
                lb.stars=TRUE, ub.stars=TRUE, ncores=2)
```

## Graphlet stability

We can use the graphlet correlation distance as an additional stability criterion. We could call
pulsar again with a new criterion, or simply `update` the arguments for model we already used. Then,
we can use our default approach for selecting the optimal index, based on the gcd+StARS criterion:
choose the minimum gcd summary statistic between the upper and lower StARS bouds.


```r
out.q2 <- update(out.q, criterion=c('stars', 'gcd'))
opt.index(out.q2, 'gcd') <- get.opt.index(out.q2, 'gcd')
fit.q2 <- refit(out.q2)
```

Compare model error by relative hamming distances between refit adjacency matrices and the true
graph and visualize the results:

```r
plot(out.q2, scale=TRUE)
```

![plot of chunk unnamed-chunk-11](http://i.imgur.com/wothnOF.png)

```r
starserr <- sum(fit.q2$refit$stars != dat$theta)/p^2
gcderr   <- sum(fit.q2$refit$gcd   != dat$theta)/p^2
gcderr < starserr
# [1] TRUE

## install.packages('network')
truenet  <- network::network(dat$theta)
starsnet <- network::network(summary(fit.q2$refit$stars))
gcdnet   <- network::network(summary(fit.q2$refit$gcd))
par(mfrow=c(1,3))
coords <- plot(truenet, usearrows=FALSE, main="TRUE")
plot(starsnet, coord=coords, usearrows=FALSE, main="StARS")
plot(gcdnet, coord=coords, usearrows=FALSE, main="StARS+GCD")
```

![plot of chunk unnamed-chunk-12](http://i.imgur.com/wbvAY8K.png)

## Batch Mode

For large graphs, we could reduce pulsar run time by running each subsampled dataset totally in
parallel (i.e. each run as an indepedent job). This is a natural choice since we want to infer an
independent graphical model for each subsampled dataset.

Enter the BatchJobs. This package lets us invoke the queuing system in a high performance computing
(hpc) environment so that we don't have to worry about any of the job-handling procedures in R.
Pulsar has only been testing for Torque so far, but should work without too much effort for
 LSF, SLURM, SGE and probably others.

We also potentially gain efficiency in memory usage. Even for memory efficient representations of
sparse graphs, for a lambda path of size L and for number N subsamples we must hold `L*N` `p*p`-
sized adjacency matrices in memory to compute the summary statistic. BatchJobs lets us use a
MapReduce strategy, so that only one `p*p` graph and one `p*p` aggregation matrix needs to be held
in memory at a time. For large p, it can be more efficient to read data off the disk.

This also means we will need access to a writable directory to write intermediate files (where the
BatchJobs registry is stored). These will be automatically generated R scripts, error and output
files and sqlite files so that BatchJobs can keep track of everything (although a different database
can be used). Please see that package's documentation for more information. By default, pulsar will
create the registry directory under R's  (platform-dependent) tmp directory but this should be
overridden if these need to be retained long term (`regdir` argument to `batch.pulsar`).

For generating BatchJobs, we need a configuration file (supply a path string to `conffile` argument,
a good choice is the working directory) and a template file (which is best put in the same directory
as the config file). Example config (BatchJobsTorque.R) and PBS template file (simpletorque.tml) for
Torque can be found in the inst/extdata/ subdirectory of this github. See the BatchJobs homepage for
creating templates for other systems.

For this README I suggest using BatchJobs's convenient serial or multicore test mode to get things
up and running. Download the files in a browser (if https is not supported) or directly in an R
session:


```r
url <- "https://raw.githubusercontent.com/zdk123/pulsar/master/inst/extdata"
url <- paste(url, "BatchJobsSerialTest.R", sep="/") # Serial mode
## url <- paste(url, "BatchJobsMC.R", sep="/") # uncomment for multicore
download.file(url, destfile=".BatchJobs.R")
```

Since BatchJobs is not imported by `pulsar`, it needs to be loaded.
Uncomment `cleanup=TRUE` to remove registry directory (useful if running through this readme
multiple times).


```r
## uncomment below if BatchJobs is not already installed
# install.package('BatchJobs')
library(BatchJobs)
out.batch <- batch.pulsar(dat$data, fun=quicr, fargs=quicargs,
                rep.num=100, criterion='stars', seed=10010
                #, cleanup=TRUE)
             )
```

Check that we get the same result from batch mode pulsar:


```r
opt.index(out.q, 'stars') == opt.index(out.batch, 'stars')
# [1] TRUE
```

It is also possible to run bounded-mode stars in batch, but the first 2 subsamples (2 jobs) will run
to completetion before the final N-2 are run. This serializes the batch mode a bit, but can still be
faster for fine grain lambda paths and for sparse graphs. It is also advisable to do this for the
`gcd` criterion because, computing graphlet frequencies can be costly and this is only done for the
graphs in the bounded lambda path (in serial/multicore or batch pulsar).

To keep the initial N=2 jobs separate from the rest, the string provided to the `init` argument
("subtwo" by default) is concatenated to the basename of `regdir`. The registry/id is returned
but named `init.reg` and `init.id` from `batch.pulsar`.



```r
out.bbatch <- update(out.batch, criterion=c('stars', 'gcd'),
                     lb.stars=TRUE, ub.stars=TRUE)
```

Check that we get the same result from bounded/batch mode pulsar:


```r
opt.index(out.bbatch, 'stars') == opt.index(out.batch, 'stars')
# [1] TRUE
```

### A few notes on batch mode pulsar

* In real applications, on an hpc, it is important to specify the `res.list` argument, which is a
__named__ list of PBS resources that matches the template file. For example if using the 
simpletorque.tml file provided in /extdata/, one would provide `res.list=list(walltime="4:00:00",
 nodes="1", memory="1gb")` to give the PBS script 4 hours and 1GB of memory and 1 node to the
 resource list for `qsub`.

* Gains in efficiency and run time (especially when paired with lower/upper bound mode) will largely
depend on your hpc setup. E.g - do you have sufficient priority in the queue to run your 100 jobs
in perfect parallel? Because settings vary so widely, we cannot provide support for unexpected hpc
problems or make specific recommendations about requesting the appropriate resource requirements
for jobs.

* One final note: we assume that a small number of jobs could fail at random. If jobs fail to
complete a warning will be given, but `pulsar` will complete the run and summary statistics will be
computed over only over the successful jobs (with normalization constants appropriately adjusted).
It is up to the user to re-start `pulsar` if there is a sampling-dependent reason some subset of
jobs fail: e.g. an outlier datapoint increases computation time or graph density and insufficient
resources are allocated.

## Additional criteria

Pulsar includes several other criteria of interest, which can be run indepedently of StARS (these
are not yet included for batch mode). For example, to replicate the augmented AGNES (A-AGNES) method
of [Caballe et al 2016](http://arxiv.org/abs/1509.05326), use the node-wise dissimilarity metric 
(diss) and the AGNES algorithm as implemented in the `cluster` package. A-AGNES selects a target
lambda that mimimizes the variance of the estimated diss (computed by `pulsar`) + the [squared] bias
of the expected estimated dissimilarities w.r.t. the AGNES-selected graph - that has the maximum
agglomerative coefficient over the path.


```r
out.diss  <- pulsar(dat$data, fun=quicr, fargs=quicargs,
                    rep.num=100, criterion='diss', seed=10010, ncores=2)
fit <- refit(out.diss)
## Compute the max agglomerative coefficient over the full path
path.diss <- lapply(fit$est$path, pulsar:::graph.diss)
acfun <- function(x) cluster::agnes(x, diss=TRUE)$ac
ac <- sapply(path.diss, acfun)
ac.sel <- out.diss$diss$merge[[which.max(ac)]]

## Estimate the diss bias
dissbias <- sapply(out.diss$diss$merge,
                   function(x) mean((x-ac.sel)^2)/2)
varbias  <- out.diss$diss$summary + dissbias

## Select the index and refit
opt.index(out.diss, 'diss') <- which.min(varbias)
fit.diss <-refit(out.diss)
```

Evalue the edge-wide model error:

```r
aagneserr <- sum(fit.diss$refit$diss != dat$theta)/p^2
aagneserr < starserr
# [1] TRUE
aagneserr < gcderr
# [1] FALSE
```

Other criteria that are currently implemented are [natural connectivity](http://iopscience.iop.org/0256-307X/27/7/078902)
stability, Tandon & Ravikumar's [sufficiency criterion](http://jmlr.org/proceedings/papers/v32/tandon14.html)
and variability of the [Estrada index](http://journals.aps.org/pre/abstract/10.1103/PhysRevE.75.016103).
These are currently implemented without a default method for actually selecting an optimal lambda,
but as demonstrated above, these can be _ex post_ with a `pulsar` object.

Feel free to request your favorite selection criterion to include with this package.
