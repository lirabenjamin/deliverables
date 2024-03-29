# install.packages("spatialreg")
library(spatialreg)
library(spdep)
library(igraph)
library(classInt)
library(RColorBrewer)
#Advice
idadvice <- "1dbZDumTH9dFwNStIKKEO9bhx_ftYtLam" 
advicelazega <- read.csv(sprintf("https://docs.google.com/uc?id=%s&export=download", idadvice))
advicelazega <- as.matrix(advicelazega)
advicelazegac <- advicelazega
str(advicelazega)
dim(advicelazega)
#Reading attributes also provided by Lazega
idattributes <- "1e0GtrRS5PFFNdnd1e4fJcjeuBZ6deF7g"
datattrout <- read.csv(sprintf("https://docs.google.com/uc?id=%s&export=download", idattributes))
#Transforming the matrices to spatial form (row normalized) as shown in equation (21)
advicelazega <-advicelazega /rowSums(advicelazega)
summary(rowSums(advicelazega))
# Replacing potential NAN to zeros as shown in equation (22)
advicelazega[is.na(advicelazega)]<-0
listwAd<-mat2listw(advicelazega)

#########
#Testing influence
#########
moran.test(datattrout$HrRATE90,listwAd, zero.policy=TRUE)
moran.test(datattrout$FeesCollec90,listwAd, zero.policy=TRUE)

#########
#Visualizing Local Moran’s I clusters and outliers 
#########
mt <- moran.test(datattrout$FeesCollec90, listwAd, zero.policy=TRUE)
label_x = "Individual Fees Collected"
label_y = "Lagged Individual Fees Collected"
mp <- moran.plot(datattrout$FeesCollec90, listwAd, zero.policy=T,
labels=sub_datattrout$id, xlab = label_x, ylab = label_y)
title(main="Moran’s Plot", cex.main=2, col.main="grey11", 
font.main=2, sub=paste("Plot includes 70 lawyers (Moran’s I = ", 
round(mt$ estimate[1], 3), ", p < .0001)", sep=""), cex.sub=1.15, col.sub="grey11", font.sub=2,)

#########
#Addressing the issue
#########
#SAR procedures for social dependence for outcome 1
Hrrate90Ad <- spautolm(formula = HrRATE90 ~ 1, data = data.frame(datattrout), listw = test.listwAd)
summary(fees90Ad)
#Saving the residuals
hNULL<-residuals(Hrrate90Ad)
#Testing residuals for sp dependence
moran.test(hNULL,test.listwAd, zero.policy=TRUE)
#SAR procedures for social dependence for outcome 2
fees90Ad <- spautolm(formula = FeesCollec90 ~ 1, data = data.frame(datattrout), listw = test.listwAd)
summary(fees90Ad)
#Saving the residuals
hNULL<-residuals(fees90Ad)
#Testing residuals for sp dependence
moran.test(hNULL,test.listwAd, zero.policy=TRUE)

#Can this issue in outcome 1 be solved with model specification?
Hrrate90Ad <- spautolm(formula = HrRATE90 ~ partner , data = data.frame(datattrout), listw = test.listwAd)
summary(Hrrate90Ad)
hNULL<-residuals(Hrrate90Ad)
#Testing residuals for sp dependence
moran.test(hNULL,test.listwAd, zero.policy=TRUE)

#Can we create interesting social indicators?
#Getting socially lagged indicators 
datattrout$lag.partnersAd <- lag.listw(test.listwAd, datattrout$partner, zero.policy=T, na.action=na.omit)
#Network visualization
Hrrate90Adwithlag <- spautolm(formula = HrRATE90 ~ lag.partnersAd , data = data.frame(datattrout), listw = test.listwAd)
summary(Hrrate90Adwithlag)
hNULL<-residuals(Hrrate90Adwithlag)
#Testing residuals for sp dependence
moran.test(hNULL,test.listwAd, zero.policy=TRUE)


#########
#How are disconnected unit influencing these results and how to remove them?
#########
sub_listNAd <- subset(listwAd[[2]], subset=card(listwAd[[2]])> 0)
sub_listNAd
sub_listWAd <- nb2listw(sub_listNAd, glist=NULL, style="W", zero.policy=NULL)
#making this a spatial points dataframe
sub_datattrout <- subset(datattrout, subset=card(listwAd[[2]]) > 0)

moran.test(sub_datattrout$HrRATE90,sub_listWAd, zero.policy=TRUE)
moran.test(sub_datattrout$FeesCollec90,sub_listWAd, zero.policy=TRUE)

#########
# Methodological questions with practical implications:
# How do we know that our proposed initial matrix of weights is robust enough to estimate outcome dependence?
# How many neighbors of neighbors (higher order neighboring structures) do we have to account for to establish a data driven selection of neighboring structures?
#########
plot.spcor(sp.correlogram(sub_listNAd, sub_datattrout$HrRATE90, order = 6, method = "I", zero.policy=T), xlab = "Social lags", main = "Social correlogram: Autocorrelation with CIs")
plot.spcor(sp.correlogram(sub_listNAd, sub_datattrout$FeesCollec90, order = 6, method = "I", zero.policy=T), xlab = "Social lags", main = "Social correlogram: Autocorrelation with CIs")

#################################################################
# Step to create higher order neighbors
#################################################################
nth_order <- nblag(sub_listNAd, maxlag=2)#this assumes two
nth_order <- nblag_cumul(nth_order)
nth_order <- nb2listw(nth_order, style="W", zero.policy=T)
mt <- moran.test(sub_datattrout$FeesCollec90, nth_order, zero.policy=TRUE)
#################################################################
# Visualizing Local Moran’s I clusters and outliers 
#################################################################
label_x = "Individual Y"
label_y = "Lagged Individual Y"
mp <- moran.plot(sub_datattrout$FeesCollec90, nth_order, zero.policy=T,
labels=sub_datattrout$id, xlab = label_x, ylab = label_y)
title(main="Moran’s Plot", cex.main=2, col.main="grey11", 
font.main=2, sub=paste("Plot includes 70 lawyers (Moran’s I = ", 
round(mt$ estimate[1], 3), ", p < .0001)", sep=""), cex.sub=1.15, col.sub="grey11", font.sub=2,)

#Retesting whether social dependence is affected with nth order of neighbors
#SAR procedures for social dependence 
fees90Ad <- spautolm(formula = HrRATE90 ~ 1, data = data.frame(sub_datattrout), listw = sub_listWAd)
summary(fees90Ad)
#Saving the residuals
hNULL<-residuals(fees90Ad)
#Testing residuals for sp dependence
moran.test(hNULL, sub_listWAd, zero.policy=TRUE)

fees90Ad <- spautolm(formula = FeesCollec90 ~ 1, data = data.frame(sub_datattrout), listw = sub_listWAd)
summary(fees90Ad)
#Saving the residuals
hNULL<-residuals(fees90Ad)
#Testing residuals for sp dependence
moran.test(hNULL,sub_listWAd, zero.policy=TRUE)

#Did you have to modify, No, but if I had to, I would do this:
fees90Ad <- spautolm(formula = HrRATE90 ~ partner , data = data.frame(sub_datattrout), listw = sub_listWAd)
summary(fees90Ad)
hNULL<-residuals(fees90Ad)
#Testing residuals for sp dependence
moran.test(hNULL,sub_listWAd, zero.policy=TRUE)




