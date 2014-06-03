/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.mahout.math.solver;

import org.apache.mahout.math.DenseVector;
import org.apache.mahout.math.Matrix;
import org.apache.mahout.math.Vector;
import org.apache.mahout.math.function.Functions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Solves sparse least-squares using the LSMR algorithm.
 * <p/>
 * LSMR solves the system of linear equations A * X = B. If the system is inconsistent, it solves
 * the least-squares problem min ||b - Ax||_2. A is a rectangular matrix of dimension m-by-n, where
 * all cases are allowed: m=n, m>n, or m&lt;n. B is a vector of length m. The matrix A may be dense
 * or sparse (usually sparse).
 * <p/>
 * Some additional configurable properties adjust the behavior of the algorithm.
 * <p/>
 * If you set lambda to a non-zero value then LSMR solves the regularized least-squares problem min
 * ||(B) - (   A    )X|| ||(0)   (lambda*I) ||_2 where LAMBDA is a scalar.  If LAMBDA is not set,
 * the system is solved without regularization.
 * <p/>
 * You can also set aTolerance and bTolerance.  These cause LSMR to iterate until a certain backward
 * error estimate is smaller than some quantity depending on ATOL and BTOL.  Let RES = B - A*X be
 * the residual vector for the current approximate solution X.  If A*X = B seems to be consistent,
 * LSMR terminates when NORM(RES) <= ATOL*NORM(A)*NORM(X) + BTOL*NORM(B). Otherwise, LSMR terminates
 * when NORM(A'*RES) <= ATOL*NORM(A)*NORM(RES). If both tolerances are 1.0e-6 (say), the final
 * NORM(RES) should be accurate to about 6 digits. (The final X will usually have fewer correct
 * digits, depending on cond(A) and the size of LAMBDA.)
 * <p/>
 * The default value for ATOL and BTOL is 1e-6.
 * <p/>
 * Ideally, they should be estimates of the relative error in the entries of A and B respectively.
 * For example, if the entries of A have 7 correct digits, set ATOL = 1e-7. This prevents the
 * algorithm from doing unnecessary work beyond the uncertainty of the input data.
 * <p/>
 * You can also set conditionLimit.  In that case, LSMR terminates if an estimate of cond(A) exceeds
 * conditionLimit. For compatible systems Ax = b, conditionLimit could be as large as 1.0e+12 (say).
 * For least-squares problems, conditionLimit should be less than 1.0e+8. If conditionLimit is not
 * set, the default value is 1e+8. Maximum precision can be obtained by setting aTolerance =
 * bTolerance = conditionLimit = 0, but the number of iterations may then be excessive.
 * <p/>
 * Setting iterationLimit causes LSMR to terminate if the number of iterations reaches
 * iterationLimit.  The default is iterationLimit = min(m,n).   For ill-conditioned systems, a
 * larger value of ITNLIM may be needed.
 * <p/>
 * Setting localSize causes LSMR to run with rerorthogonalization on the last localSize v_k's.
 * (v-vectors generated by Golub-Kahan bidiagonalization) If localSize is not set, LSMR runs without
 * reorthogonalization. A localSize > max(n,m) performs reorthogonalization on all v_k's.
 * Reorthgonalizing only u_k or both u_k and v_k are not an option here. Details are discussed in
 * the SIAM paper.
 * <p/>
 * getTerminationReason() gives the reason for termination. ISTOP  = 0 means X=0 is a solution. = 1
 * means X is an approximate solution to A*X = B, according to ATOL and BTOL. = 2 means X
 * approximately solves the least-squares problem according to ATOL. = 3 means COND(A) seems to be
 * greater than CONLIM. = 4 is the same as 1 with ATOL = BTOL = EPS. = 5 is the same as 2 with ATOL
 * = EPS. = 6 is the same as 3 with CONLIM = 1/EPS. = 7 means ITN reached ITNLIM before the other
 * stopping conditions were satisfied.
 * <p/>
 * getIterationCount() gives ITN = the number of LSMR iterations.
 * <p/>
 * getResidualNorm() gives an estimate of the residual norm: NORMR = norm(B-A*X).
 * <p/>
 * getNormalEquationResidual() gives an estimate of the residual for the normal equation: NORMAR =
 * NORM(A'*(B-A*X)).
 * <p/>
 * getANorm() gives an estimate of the Frobenius norm of A.
 * <p/>
 * getCondition() gives an estimate of the condition number of A.
 * <p/>
 * getXNorm() gives an estimate of NORM(X).
 * <p/>
 * LSMR uses an iterative method. For further information, see D. C.-L. Fong and M. A. Saunders
 * LSMR: An iterative algorithm for least-square problems Draft of 03 Apr 2010, to be submitted to
 * SISC.
 * <p/>
 * David Chin-lung Fong            clfong@stanford.edu Institute for Computational and Mathematical
 * Engineering Stanford University
 * <p/>
 * Michael Saunders                saunders@stanford.edu Systems Optimization Laboratory Dept of
 * MS&E, Stanford University. -----------------------------------------------------------------------
 */
public class LSMR {

  private static final Logger log = LoggerFactory.getLogger(LSMR.class);

  private double lambda;
  private int localSize;
  private int iterationLimit;
  private double conditionLimit;
  private double bTolerance;
  private double aTolerance;
  private int localPointer;
  private Vector[] localV;
  private double residualNorm;
  private double normalEquationResidual;
  private double xNorm;
  private int iteration;
  private double normA;
  private double condA;

  public int getIterationCount() {
    return iteration;
  }

  public double getResidualNorm() {
    return residualNorm;
  }

  public double getNormalEquationResidual() {
    return normalEquationResidual;
  }

  public double getANorm() {
    return normA;
  }

  public double getCondition() {
    return condA;
  }

  public double getXNorm() {
    return xNorm;
  }

  /**
   * LSMR uses an iterative method to solve a linear system. For further information, see D. C.-L.
   * Fong and M. A. Saunders LSMR: An iterative algorithm for least-square problems Draft of 03 Apr
   * 2010, to be submitted to SISC.
   * <p/>
   * 08 Dec 2009: First release version of LSMR. 09 Apr 2010: Updated documentation and default
   * parameters. 14 Apr 2010: Updated documentation. 03 Jun 2010: LSMR with local
   * reorthogonalization (full reorthogonalization is also implemented)
   * <p/>
   * David Chin-lung Fong            clfong@stanford.edu Institute for Computational and
   * Mathematical Engineering Stanford University
   * <p/>
   * Michael Saunders                saunders@stanford.edu Systems Optimization Laboratory Dept of
   * MS&E, Stanford University. -----------------------------------------------------------------------
   */

  public LSMR() {
    // Set default parameters.
    lambda = 0;
    aTolerance = 1.0e-6;
    bTolerance = 1.0e-6;
    conditionLimit = 1.0e8;
    iterationLimit = -1;
    localSize = 0;
  }

  public Vector solve(Matrix A, Vector b) {
    /*
        % Initialize.


        hdg1 = '   itn      x(1)       norm r    norm A''r';
        hdg2 = ' compatible   LS      norm A   cond A';
        pfreq  = 20;   % print frequency (for repeating the heading)
        pcount = 0;    % print counter

        % Determine dimensions m and n, and
        % form the first vectors u and v.
        % These satisfy  beta*u = b,  alpha*v = A'u.
    */
    log.debug("   itn         x(1)     norm r   norm A'r");
    log.debug("   compatible   LS      norm A   cond A");

    Matrix transposedA = A.transpose();
    Vector u = b;

    double beta = u.norm(2);
    if (beta > 0) {
      u = u.divide(beta);
    }

    Vector v = transposedA.times(u);
    int m = A.numRows();
    int n = A.numCols();

    int minDim = Math.min(m, n);
    if (iterationLimit == -1) {
      iterationLimit = minDim;
    }

    if (log.isDebugEnabled()) {
      log.debug("LSMR - Least-squares solution of  Ax = b, based on Matlab Version 1.02, 14 Apr 2010, Mahout version {}",
        this.getClass().getPackage().getImplementationVersion());
      log.debug(String.format("The matrix A has %d rows  and %d cols, lambda = %.4g, atol = %g, btol = %g",
        m, n, lambda, aTolerance, bTolerance));
    }

    double alpha = v.norm(2);
    if (alpha > 0) {
      v.assign(Functions.div(alpha));
    }


    // Initialization for local reorthogonalization
    localPointer = 0;

    // Preallocate storage for storing the last few v_k. Since with
    // orthogonal v_k's, Krylov subspace method would converge in not
    // more iterations than the number of singular values, more
    // space is not necessary.
    localV = new Vector[Math.min(localSize, minDim)];
    boolean localOrtho = false;
    if (localSize > 0) {
      localOrtho = true;
      localV[0] = v;
    }


    // Initialize variables for 1st iteration.

    iteration = 0;
    double zetabar = alpha * beta;
    double alphabar = alpha;

    Vector h = v;
    Vector hbar = zeros(n);
    Vector x = zeros(n);

    // Initialize variables for estimation of ||r||.

    double betadd = beta;

    // Initialize variables for estimation of ||A|| and cond(A)

    double aNorm = alpha * alpha;

    // Items for use in stopping rules.
    double normb = beta;

    double ctol = 0;
    if (conditionLimit > 0) {
      ctol = 1 / conditionLimit;
    }
    residualNorm = beta;

    // Exit if b=0 or A'b = 0.

    normalEquationResidual = alpha * beta;
    if (normalEquationResidual == 0) {
      return x;
    }

    // Heading for iteration log.


    if (log.isDebugEnabled()) {
      double test2 = alpha / beta;
//      log.debug('{} {}', hdg1, hdg2);
      log.debug("{} {}", iteration, x.get(0));
      log.debug("{} {}", residualNorm, normalEquationResidual);
      double test1 = 1;
      log.debug("{} {}", test1, test2);
    }


    //------------------------------------------------------------------
    //     Main iteration loop.
    //------------------------------------------------------------------
    double rho = 1;
    double rhobar = 1;
    double cbar = 1;
    double sbar = 0;
    double betad = 0;
    double rhodold = 1;
    double tautildeold = 0;
    double thetatilde = 0;
    double zeta = 0;
    double d = 0;
    double maxrbar = 0;
    double minrbar = 1.0e+100;
    int istop = 0;
    StopCode stop = StopCode.CONTINUE;
    while (iteration <= iterationLimit && stop == StopCode.CONTINUE) {

      iteration++;

      // Perform the next step of the bidiagonalization to obtain the
      // next beta, u, alpha, v.  These satisfy the relations
      //      beta*u  =  A*v  - alpha*u,
      //      alpha*v  =  A'*u - beta*v.

      u = A.times(v).minus(u.times(alpha));
      beta = u.norm(2);
      if (beta > 0) {
        u.assign(Functions.div(beta));

        // store data for local-reorthogonalization of V
        if (localOrtho) {
          localVEnqueue(v);
        }
        v = transposedA.times(u).minus(v.times(beta));
        // local-reorthogonalization of V
        if (localOrtho) {
          v = localVOrtho(v);
        }
        alpha = v.norm(2);
        if (alpha > 0) {
          v.assign(Functions.div(alpha));
        }
      }

      // At this point, beta = beta_{k+1}, alpha = alpha_{k+1}.

      // Construct rotation Qhat_{k,2k+1}.

      double alphahat = Math.hypot(alphabar, lambda);
      double chat = alphabar / alphahat;
      double shat = lambda / alphahat;

      // Use a plane rotation (Q_i) to turn B_i to R_i

      double rhoold = rho;
      rho = Math.hypot(alphahat, beta);
      double c = alphahat / rho;
      double s = beta / rho;
      double thetanew = s * alpha;
      alphabar = c * alpha;

      // Use a plane rotation (Qbar_i) to turn R_i^T to R_i^bar

      double rhobarold = rhobar;
      double zetaold = zeta;
      double thetabar = sbar * rho;
      double rhotemp = cbar * rho;
      rhobar = Math.hypot(cbar * rho, thetanew);
      cbar = cbar * rho / rhobar;
      sbar = thetanew / rhobar;
      zeta = cbar * zetabar;
      zetabar = -sbar * zetabar;


      // Update h, h_hat, x.

      hbar = h.minus(hbar.times(thetabar * rho / (rhoold * rhobarold)));

      x.assign(hbar.times(zeta / (rho * rhobar)), Functions.PLUS);
      h = v.minus(h.times(thetanew / rho));

      // Estimate of ||r||.

      // Apply rotation Qhat_{k,2k+1}.
      double betaacute = chat * betadd;
      double betacheck = -shat * betadd;

      // Apply rotation Q_{k,k+1}.
      double betahat = c * betaacute;
      betadd = -s * betaacute;

      // Apply rotation Qtilde_{k-1}.
      // betad = betad_{k-1} here.

      double thetatildeold = thetatilde;
      double rhotildeold = Math.hypot(rhodold, thetabar);
      double ctildeold = rhodold / rhotildeold;
      double stildeold = thetabar / rhotildeold;
      thetatilde = stildeold * rhobar;
      rhodold = ctildeold * rhobar;
      betad = -stildeold * betad + ctildeold * betahat;

      // betad   = betad_k here.
      // rhodold = rhod_k  here.

      tautildeold = (zetaold - thetatildeold * tautildeold) / rhotildeold;
      double taud = (zeta - thetatilde * tautildeold) / rhodold;
      d += betacheck * betacheck;
      residualNorm = Math.sqrt(d + (betad - taud) * (betad - taud) + betadd * betadd);

      // Estimate ||A||.
      aNorm += beta * beta;
      normA = Math.sqrt(aNorm);
      aNorm += alpha * alpha;

      // Estimate cond(A).
      maxrbar = Math.max(maxrbar, rhobarold);
      if (iteration > 1) {
        minrbar = Math.min(minrbar, rhobarold);
      }
      condA = Math.max(maxrbar, rhotemp) / Math.min(minrbar, rhotemp);

      // Test for convergence.

      // Compute norms for convergence testing.
      normalEquationResidual = Math.abs(zetabar);
      xNorm = x.norm(2);

      // Now use these norms to estimate certain other quantities,
      // some of which will be small near a solution.

      double test1 = residualNorm / normb;
      double test2 = normalEquationResidual / (normA * residualNorm);
      double test3 = 1 / condA;
      double t1 = test1 / (1 + normA * xNorm / normb);
      double rtol = bTolerance + aTolerance * normA * xNorm / normb;

      // The following tests guard against extremely small values of
      // atol, btol or ctol.  (The user may have set any or all of
      // the parameters atol, btol, conlim  to 0.)
      // The effect is equivalent to the normAl tests using
      // atol = eps,  btol = eps,  conlim = 1/eps.

      if (iteration > iterationLimit) {
        istop = 7;
        stop = StopCode.ITERATION_LIMIT;
      }
      if (1 + test3 <= 1) {
        istop = 6;
        stop = StopCode.CONDITION_MACHINE_TOLERANCE;
      }
      if (1 + test2 <= 1) {
        istop = 5;
        stop = StopCode.LEAST_SQUARE_CONVERGED_MACHINE_TOLERANCE;
      }
      if (1 + t1 <= 1) {
        istop = 4;
        stop = StopCode.CONVERGED_MACHINE_TOLERANCE;
      }

      // Allow for tolerances set by the user.

      if (test3 <= ctol) {
        istop = 3;
        stop = StopCode.CONDITION;
      }
      if (test2 <= aTolerance) {
        istop = 2;
        stop = StopCode.CONVERGED;
      }
      if (test1 <= rtol) {
        istop = 1;
        stop = StopCode.TRIVIAL;
      }

      if (stop != StopCode.CONTINUE && stop.ordinal() != istop + 1) {
        throw new IllegalStateException(String.format("bad code match %d vs %d", istop, stop.ordinal()));
      }

      // See if it is time to print something.

      if (log.isDebugEnabled()) {
        if ((n <= 40) || (iteration <= 10) || (iteration >= iterationLimit - 10) || ((iteration % 10) == 0) || (test3 <= 1.1 * ctol) || (test2 <= 1.1 * aTolerance) || (test1 <= 1.1 * rtol) || (istop != 0)) {
          statusDump(x, normA, condA, test1, test2);
        }
      }
    } // iteration loop

    // Print the stopping condition.
    log.debug("Finished: {}", stop.getMessage());

    return x;
    /*


    if show
      fprintf('\n\nLSMR finished')
      fprintf('\n%s', msg(istop+1,:))
      fprintf('\nistop =%8g    normr =%8.1e'     , istop, normr )
      fprintf('    normA =%8.1e    normAr =%8.1e', normA, normAr)
      fprintf('\nitn   =%8g    condA =%8.1e'     , itn  , condA )
      fprintf('    normx =%8.1e\n', normx)
    end
    */
  }

  private void statusDump(Vector x, double normA, double condA, double test1, double test2) {
    log.debug("{} {}", residualNorm, normalEquationResidual);
    log.debug("{} {}", iteration, x.get(0));
    log.debug("{} {}", test1, test2);
    log.debug("{} {}", normA, condA);
  }

  private static Vector zeros(int n) {
    return new DenseVector(n);
  }

  //-----------------------------------------------------------------------
  // stores v into the circular buffer localV
  //-----------------------------------------------------------------------

  private void localVEnqueue(Vector v) {
    if (localV.length > 0) {
      localV[localPointer] = v;
      localPointer = (localPointer + 1) % localV.length;
    }
  }

  //-----------------------------------------------------------------------
  // Perform local reorthogonalization of V
  //-----------------------------------------------------------------------

  private Vector localVOrtho(Vector v) {
    for (Vector old : localV) {
      if (old != null) {
        double x = v.dot(old);
        v = v.minus(old.times(x));
      }
    }
    return v;
  }

  private enum StopCode {
    CONTINUE("Not done"),
    TRIVIAL("The exact solution is  x = 0"),
    CONVERGED("Ax - b is small enough, given atol, btol"), LEAST_SQUARE_CONVERGED("The least-squares solution is good enough, given atol"),
    CONDITION("The estimate of cond(Abar) has exceeded condition limit"),
    CONVERGED_MACHINE_TOLERANCE("Ax - b is small enough for this machine"),
    LEAST_SQUARE_CONVERGED_MACHINE_TOLERANCE("The least-squares solution is good enough for this machine"),
    CONDITION_MACHINE_TOLERANCE("Cond(Abar) seems to be too large for this machine"),
    ITERATION_LIMIT("The iteration limit has been reached");

    private final String message;

    StopCode(String message) {
      this.message = message;
    }

    public String getMessage() {
      return message;
    }
  }

  public void setAtolerance(double aTolerance) {
    this.aTolerance = aTolerance;
  }

  public void setBtolerance(double bTolerance) {
    this.bTolerance = bTolerance;
  }

  public void setConditionLimit(double conditionLimit) {
    this.conditionLimit = conditionLimit;
  }

  public void setIterationLimit(int iterationLimit) {
    this.iterationLimit = iterationLimit;
  }

  public void setLocalSize(int localSize) {
    this.localSize = localSize;
  }

  private void setLambda(double lambda) {
    this.lambda = lambda;
  }

  public double getLambda() {
    return lambda;
  }

  public double getAtolerance() {
    return aTolerance;
  }

  public double getBtolerance() {
    return bTolerance;
  }
}
