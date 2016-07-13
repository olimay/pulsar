#include <RcppArmadillo.h>
// [[Rcpp::depends(RcppArmadillo)]]
 
using namespace Rcpp;
using namespace arma;


arma::mat Gprod2dmat(const arma::mat Gprod) {
    arma::vec Gdiag = Gprod.diag();
    arma::mat degProd = Gdiag * Gdiag.t();
    arma::mat dmat    = 1 - (Gprod / sqrt(degProd));
    return dmat;
}

arma::mat GraphDiss_dense(const arma::mat M) {
    arma::mat Gprod = M * M;
    arma::mat dmat = Gprod2dmat(Gprod);
    return dmat;
}

arma::mat GraphDiss_sp(const arma::sp_mat M) {
    arma::sp_mat spGprod = M * M;
    arma::mat Gprod(spGprod);
    arma::mat dmat = Gprod2dmat(Gprod);
    return dmat;
}


//[[Rcpp::export]]
arma::mat GraphDiss(SEXP M) {
    if (Rf_isS4(M)) {
        if (Rf_inherits(M, "dsCMatrix") || Rf_inherits(M, "lsCMatrix")) {
            arma::sp_mat spM = as<arma::sp_mat>(M);
            return GraphDiss_sp(spM + spM.t());
        } else if (Rf_inherits(M, "dgCMatrix") || Rf_inherits(M, "lgCMatrix")) {
            arma::sp_mat spM = as<arma::sp_mat>(M);
            return GraphDiss_sp(spM);
        } else {
            stop("unknown S4 class of M") ;
        }
    } else {
        return GraphDiss_dense(as<arma::mat>(M)) ;
    } 
}

arma::vec rowVars(arma::mat m) {
    return var(m, 0, 1);
}

arma::vec colVars(arma::mat m) {
    return rowVars(m.t());
}


arma::mat matPow_sp(arma::sp_mat M, int n) {
    arma::sp_mat result = speye<sp_mat>(size(M));
    while (n > 0) {
      if (n % 2 != 0) {
        result = result * M;
        n -= 1;
      }
      M = M*M;
      n = n/2;
    }
    arma::mat castres(result);
    return castres;
}

arma::mat matPow_dense(arma::mat M, int n) {
    arma::mat result = eye<mat>(size(M));
    while (n > 0) {
      if (n % 2 != 0) {
        result = result * M;
        n -= 1;
      }
      M = M*M;
      n = n/2;
    }
    return result;
}


//[[Rcpp::export]]
arma::mat matPow(SEXP M, int n) {
// TODO handle case n = 1
    if (Rf_isS4(M)) {
        if (Rf_inherits(M, "dsCMatrix") || Rf_inherits(M, "lsCMatrix")) {
            arma::sp_mat spM = as<arma::sp_mat>(M);
            return matPow_sp(spM + spM.t(), n);
        } else if (Rf_inherits(M, "dgCMatrix") || Rf_inherits(M, "lgCMatrix")) {
            return matPow_sp(as<arma::sp_mat>(M), n);
        } else {
            stop("unknown S4 class of M") ;
        }
    } else {
        return matPow_dense(as<arma::mat>(M), n) ;
    }
}
