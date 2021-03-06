% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mcPulsarSelect.R
\name{pulsar}
\alias{pulsar}
\title{pulsar: serial or parallel mode}
\usage{
pulsar(data, fun = huge::huge, fargs = list(), criterion = c("stars"),
  thresh = 0.1, subsample.ratio = NULL, rep.num = 20, seed = NULL,
  lb.stars = FALSE, ub.stars = FALSE, ncores = 1)
}
\arguments{
\item{data}{A \eqn{n*p} matrix of data matrix input to solve for the \eqn{p*p} graphical model}

\item{fun}{pass in a function that returns a list of \eqn{p*p} graphical models along the desired regularization path. The expected inputs to this function are based on the \code{huge} function in the \pkg{huge} package: a raw data input (as opposed to a covariance/correlation matrix) and must return a list or S3 object with a \emph{named} \code{path} list. This should be a list of matrices (or preferable sparse Matrix - see the \pkg{Matrix} package) of adjacency matrices without weights or signs representing the undirected graphical model at each value of \code{lambda}. See details for more information.}

\item{fargs}{arguments to argument \code{fun}. Must be a named list and requires at least one member \code{lambda}, a numeric vector with values for the penality parameter.}

\item{criterion}{a character vector of selection statistics. Multiple criteria can be supplied. By default, StARS is run. Currently, there are no selection criterion available for summary statistics, aside for stars, so the entire path and summary is returned. The options are:
\itemize{
   \item stars (Stability approach to regularization selection)
   \item gcd   (Graphet correlation distance, requires the \pkg{orca} package)
   \item diss  (Node dissimilarity stability)
   \item estrada (estrada class)
   \item vgraphlet (vertex orbit/graphlet frequency, requires the \pkg{orca} package)
   \item egraphlet (edge orbit/graphlet frequency, requires the \pkg{orca} package)
   \item nc  (natural connectivity)
   \item sufficiency (Ravikumar's sufficiency statistic)
}}

\item{thresh}{threshold for selection criterion. Only implemented for StARS. thresh = 0.1 is recommended.}

\item{subsample.ratio}{determine the size of the subsamples. Default is 10*sqrt(n)/n for n > 144 or 0.8 otherwise. Should be strictly less than 1.}

\item{rep.num}{number of random subsamples to take for graph re-estimation. Default is 20, but more is recommended if using other summary metrics or if using edge frequencies as confidence scores.}

\item{seed}{A numeric seed to force predictable subsampling. Default is NULL. Use for testing purposes only.}

\item{lb.stars}{Should the lower bound be computed after N=2 subsamples (should result in considerable speedup and only implemented if stars is selected). If this option is selected, other summary metrics will only be applied to the smaller lambda path.}

\item{ub.stars}{Should the upper bound be computed after N=2 subsamples (should result in considerable speedup and only implemented if stars is selected). If this option is selected, other summary metrics will only be applied to the smaller lambda path. This option is ignored if the lb.stars flag is FALSE.}

\item{ncores}{number of cores to use for subsampling. See \code{batch.pulsar} for more paralellization options.}
}
\value{
an S3 object of class \code{pulsar} with a named member for each stability metric run. Within each of these are:
\itemize{
   \item summary: the summary statistic over \code{rep.num} graphs at each value of lambda
   \item criterion: the stability criterion used
   \item merge: the raw statistic over the \code{rep.num} graphs, prior to summarization
   \item opt.ind: optimal index of lambda selected by the criterion at the desired threshold. Will return \emph{0} if no optimum is found or if selection for the criterion is not implemented.
  }
If \code{stars} is included as a criterion then additional arguments include
\itemize{
   \item lb.index the lambda index of the lower bound at N=2 samples if \code{lb.stars} flag is set to TRUE
   \item ub.index the lambda index of the upper bound at N=2 samples if \code{ub.stars} flag is set to TRUE
}

call: the original function call
}
\description{
Run pulsar stability selection, or other criteria, to select the sparsity of an undirected gaussian
graphical model.
}
\examples{
\dontrun{
## Generate the data with huge:
library(huge)
set.seed(10010)
p <- 40 ; n <- 1200
dat   <- huge.generator(n, p, "hub", verbose=FALSE, v=.1, u=.3)
lams  <- getLamPath(.2, .01, len=40)

## Run pulsar with huge
hugeargs <- list(lambda=lams, verbose=FALSE)
out.p <- pulsar(dat$data, fun=huge::huge, fargs=hugeargs,
                rep.num=20, criterion='stars')

## Run pulsar in bounded stars mode and include gcd metric:
out.b <- pulsar(dat$data, fun=huge::huge, fargs=hugeargs,
                rep.num=20, criterion=c('stars', 'gcd'),
                lb.stars=TRUE, ub.stars=TRUE)
plot(out.b)
}
}

