context("pulsar: serial vs batch")
## Make sure serial and batch mode results in identical solutions when the same seed is used

options(BatchJobs.verbose=FALSE)
suppressPackageStartupMessages(library(BatchJobs))

p <- 20
set.seed(10010)
dat <- huge::huge.generator(p*10, p, "random", prob=.25, verbose=FALSE, v=.1, u=.5)
G <- dat$theta
conffile <- file.path(system.file(package="pulsar"), "extdata", "BatchJobsSerialTest.R")
## get a random, consistent seed
rseed <- sample.int(1000, 1)

test_that("serial and batch mode are equivilent: no bounds", {
    ## run pulsar in serial mode
    lams <- getLamPath(.3, .1, 5)

    out       <- pulsar(dat$data, fargs=list(lambda=lams, verbose=FALSE),
                     criterion=c("stars"), rep.num=5, seed=rseed)
    out.batch <- batch.pulsar(dat$data, fargs=list(lambda=lams, verbose=FALSE),
                     criterion=c("stars"), rep.num=5, seed=rseed,
                     conffile=conffile, progressbars=FALSE, cleanup=TRUE)

    expect_gt(max(out$stars$summary), 0) # make sure summary isn't trivally zero
    expect_equivalent(out$stars$summary, out.batch$stars$summary)
})

test_that("serial and batch mode are equivilent: lower bound", {
    ## run pulsar in serial mode
    lams <- getLamPath(.3, .1, 5)

    out       <- pulsar(dat$data, fargs=list(lambda=lams, verbose=FALSE),
                     criterion=c("stars"), rep.num=5, seed=rseed,
                     lb.stars=TRUE)
    out.batch <- batch.pulsar(dat$data, fargs=list(lambda=lams, verbose=FALSE),
                     criterion=c("stars"), rep.num=5, seed=rseed,
                     conffile=conffile, progressbars=FALSE, cleanup=TRUE, lb.stars=TRUE)

    expect_gt(max(out$stars$summary), 0) # make sure summary isn't trivally zero
    expect_equivalent(out$stars$summary, out.batch$stars$summary)
})
