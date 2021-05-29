
set.seed(1234)

p <- 1000
n <- 10*p
nnew <- 10000
train <- rank(runif(n)) > n/2
table(train)
theta <- 100

X <- cbind(1, matrix(rnorm(n*(p-1)), nrow = n))
XX <- solve(crossprod(X[train,,drop=F]))
Xnew <- cbind(1, matrix(rnorm(nnew*(p-1)), nrow=nnew))

require(sn)
require(dplyr)
require(ggplot2)

rgumbel <- function(n, m=0, s=1) {
  g <- -digamma(1)
  s0 <- pi/sqrt(6)
  u <- -log(-log(runif(n)))
  u <- (u - g)/s0
  m + s*u
}

L4 <- function(e) {
  mean(e^4)
}

L2 <- function(e) {
  mean(e^2)
}

L4opt <- function(m, s, rho3) { # m is L2-optimal
  r <- (0.5*(rho3 + sqrt(rho3 + 4)))^(1/3)
  m + s*(r - 1/r)
}

out <- pbapply::pbsapply(1:10000, function(i, gumbel=i%%2==0) {
  if (gumbel) {
    y <- rgumbel(n = n)
    ynew <- rgumbel(n = nnew)
  } else {
    y <- rsn(n = n, alpha = theta)
    ynew <- rsn(n = nnew, alpha = theta)
  }
  beta <- drop(XX %*% crossprod(X[train,,drop=F], y[train]))
  e <- y[!train] - drop(X[!train,,drop=F] %*% beta)
  s <- sqrt(mean(e^2))
  rho3 <- mean(e^3)/s^3
  pred <- drop(Xnew %*% beta)
  pred.alt <- L4opt(m = pred, s = s, rho3 = rho3)
  c(
    L2reg = L2(ynew - pred),
    L4reg = L4(ynew - pred),
    L2alt = L2(ynew - pred.alt),
    L4alt = L4(ynew - pred.alt),
    gumbel=gumbel
  )
}, cl=parallel::detectCores()) %>%
  t() %>%
  as.data.frame() %>%
  mutate(gumbel=gumbel > 0)

out <- out %>%
  mutate(model=ifelse(gumbel, "Gumbel", paste("Skew-normal, alpha =", theta)))

png("L2.png")
out %>%
  ggplot(aes(x=L2alt, y=L2reg)) +
  geom_point() +
  facet_wrap(~ model, scales = "free") +
  stat_ellipse(color="red", level=0.99) +
  geom_abline(slope=1, intercept=0) +
  theme_bw()
dev.off()

png("L4.png")
out %>%
  ggplot(aes(x=L4alt, y=L4reg)) +
  geom_point() +
  facet_wrap(~ model, scales = "free") +
  stat_ellipse(color="red", level=0.99) +
  geom_abline(slope=1, intercept=0) +
  theme_bw()
dev.off()

out %>%
  group_by(model) %>%
  summarise(L4isL4opt=mean(L4alt < L4reg), L2isL2opt=mean(L2reg < L2alt))
