
library(DescTools)
library(readxl)
library(MASS)
library(Information)
library(dplyr)
library(scorecard)
library(dgof)
library(ROCR)
library(caret)
library(tidyr)
library(pROC)
library(AUC)
#Read German Credit Data into R
creditdata <- readxl::read_xlsx("C:/Users/shaun/Desktop/Credit Risk Scoring/GermanCreditData.xlsx", sheet=1)
creditdata
#Convert to Dataframe
creditdata <- data.frame(creditdata)
creditdata
#Are there missing values?
Missing <- creditdata$Purpose=='X' 
Missing
sum(Missing) 

#There are 12 missing values in our dataset which we chose to remove
creditdata <- creditdata[- grep("X", creditdata$Purpose),]

Subset1 <- subset(creditdata, creditdata$Checking =='1' | creditdata$Checking=='2') #Subset created for observations with checking scores of 1 and 2.
Subset2 <- subset(creditdata, creditdata$Checking =='3' | creditdata$Checking=='4')  #Subset created for observations with checking scores of 3 and 4.

#Check number of observations in each subset
nrow(Subset1) #532 observations
nrow(Subset2) #456 observations

#Proportion of Goods contained within subset
table(Subset1$Good) # 297 Good / 235 Bad 
table(Subset2$Good) # 396 Good / 60 Bad

train1 <- head(Subset1, round(nrow(Subset1) * 0.7))           
validation1 <- tail(Subset1, round(nrow(Subset1) * 0.3))

train2 <- head(Subset2, round(nrow(Subset2) * 0.7))
validation2 <- tail(Subset2, round(nrow(Subset2) * 0.3))

#Subset1
table(Subset1$Good) # 297 Good / 235 Bad 
table(train1$Good) #163 Good / 209 Bad
table(validation1$Good) #72 good / 88 Bad

#Subset 2
table(Subset2$Good) # 396 Good / 60 Bad
table(train2$Good) #278 Good / 41 Bad
table(validation2$Good) #118 good / 19 Bad

#Code to create more interpretable results
options(scipen=5)

#Information Value for Training Set 1
IV1 <- create_infotables(train1, y="Good") #Use info tables function to review Information Value of each variable
IV1$Summary

#Information Value for Training set 2
IV2 <-create_infotables(train2, y="Good") 
IV2$Summary

#Bin Creation for both Training Sets
bins <- woebin(train1, y="Good", x=c("Age", "Duration"), method="chimerge")
bins2 <- woebin(train2, y="Good", x=c("Age", "Duration", "Amount"), method="chimerge")
bins
bins2
#Application of Bins for both training sets with both WoE and direct Bin application - will use Bin application for Regression and ROC Curves
#Scorecard function() allows us to see what the application would look like and only works with Weight of Evidence values in my analysis.

#Bin assignment for Training Model 1
trainwoe <- woebin_ply(train1, bins) #For Weight of Evidence outcome for scorecard function() to demonstrate its use within the analysis.
train1bins <- woebin_ply(train1, bins, to="bin") #Creation of Different Training Model to use for the remainder of analysis
train1bins <- train1bins[, c('Amount', 'Duration_bin', 'Purpose','Good', 'Age_bin', 'History', 'Savings')]
bins
trainwoe
#Bin assignment for Training Model 2
train2woe <- woebin_ply(train2, bins2) #WOE outcome to use for scorecard function() to demonstrate its use within the analysis
train2bins <- woebin_ply(train2, bins2, to="bin")#Creation of Different Training Model to use for the remainder of analysis
train2bins <- train2bins[, c('Amount_bin', 'Duration_bin','Good', 'Age_bin', 'History', 'Savings')]
train2bins
#Bin assignment for Validation Model 1 - Must be done manually to match for both models
age_breaks <- c(-Inf, 23, 24, 28, 36, 38, 49, 61, Inf)
duration_breaks <- c(-Inf, 8, 12, 14, 18, 20, 34, 44, Inf)
binsval <- woebin(validation1, y="Good", x=c("Age", "Duration"), breaks_list= list(Age = age_breaks, Duration = duration_breaks))
validation1 <- woebin_ply(validation1, binsval, to="bin")
validation1new <- validation1[, c('Amount', 'Duration_bin', 'Purpose','Good', 'Age_bin', 'History', 'Savings')]
validation1new
#Bin assignment for Validation Model 2 - Must be done manually to match for both models
age_breaks2 <- c(-Inf, 25, 27, 30, 32, 36, 39, 50, Inf)
duration_breaks2 <- c(-Inf, 8, 10, 12, 14, 16, 34, 38, Inf)
Amount_breaks <- c(-Inf, 800, 2000, 2200, 2600, 2800, 3800, 6000, Inf)
binsval2 <- woebin(validation2, y="Good", x=c("Age", "Duration", "Amount"), breaks_list= list(Age = age_breaks2, Duration = duration_breaks2, Amount = Amount_breaks))
validation2 <- woebin_ply(validation2, binsval2, to="bin") 
validation2new <- validation2[, c('Amount_bin', 'Duration_bin','Good', 'Age_bin', 'History', 'Savings')]
binsval2
#Training Model 1 - Logistic Regression
logmodel1bins <- glm(formula = Good ~ Duration_bin + History + Savings + Age_bin, family="binomial", data = train1bins) #Model to show p-values in Logistic Regression
logmodel1 <- glm(formula = Good ~ Duration_woe + History + Savings + Age_woe, family="binomial", data = trainwoe) #Model to use in Scorecard analysis
card1 <- scorecard(bins, logmodel1) #Scorecard generation
my_scores1 <- scorecard_ply(creditdata, card1) ##Show Scorecard scores

#Training Model 1 - Linear Regression
linearmodel1bins <- lm(formula = Good ~ Duration_bin + History + Savings + Age_bin,data = train1bins) #Model to show p-values in Linear Regression
linearmodel1 <- lm(formula = Good ~ Duration_woe + History + Savings + Age_woe,data = trainwoe)
card2 <- scorecard(bins, linearmodel1) #Create Scorecard
my_scores2 <- scorecard_ply(creditdata, card2) #Show Scorecard scores

#Training Model 2 - Logistic Regression
logmodel2bins <- glm(formula = Good ~ Duration_bin + History + Savings + Age_bin, family="binomial", data = train2bins) #Model to show p-values in Logistic Regression
logmodel2 <- glm(formula = Good ~ Duration_woe + Amount_woe + Purpose + Age_woe, family = "binomial", data = train2woe)
card3 <- scorecard(bins2, logmodel2) #Create Scorecard
my_scores3 <- scorecard_ply(creditdata, card3) #Show Scorecard scores

#Training Model 2 - Linear Regression
linearmodel2bins <- lm(formula = Good ~ Duration_bin + History + Savings + Age_bin,data = train2bins) #Model to show P-values in Linear Regression
linearmodel2 <- lm(formula = Good ~ Duration_woe + Amount_woe + Purpose + Age_woe, data = train2woe)
card4 <- scorecard(bins2, linearmodel2) #Create Scorecard
my_scores4 <- scorecard_ply(creditdata, card4)#Show Scorecard scores


#Question 5- Derive ROC Curves for all scorecards

#Linear Regression Model - ROC Performance - Model 1
pred <- predict(linearmodel1bins, validation1new) #Make predictions on the validation set whether good or bad
prediction1 <- prediction(pred, validation1new$Good) #turn into a prediction type object #Make prediction of the amount of goods we can expect from validation set given our knowledge of those from the original date-set.
performance1 <- performance(prediction1, measure='tpr', x.measure='fpr') #use performance function to evaluate the efficacy of the predictions made against actual goods from validation 1.
plot(performance1, xlab='1-Specificity', ylab='Sensitivity') #plot the performance.
abline(a=0,b=1)

#Gini Coefficient 
gini <- performance(prediction1, measure="auc") #Area under the curve - higher the value the better than predictive capacity of the results 
gini <- gini@y.values[[1]]
gini <- 2*gini-1 # Gini Coefficient = 0.452178
gini
#kolmogorov-Smirnov Statistic
bads <- unlist(performance1@x.values) #change from performance object
goods <- unlist(performance1@y.values)
ks.test(goods, bads) #reports of KS score of 0.33043

#Logistic Regression Model  - ROC Performance - Model 1
predlog <- predict(logmodel1bins, validation1new) #Predict given our understanding of "Good" what probability for "Good" is in Validation 1
predictionlog<- prediction(predlog, validation1new$Good)
performancelog<- performance(predictionlog, measure='tpr', x.measure='fpr') #Predict the number of "Goods" given the model
plot(performancelog, xlab='1-Specificity', ylab='Sensitivity') #Plot these on a RoC Curve
abline(a=0,b=1)

#Gini Coefficient - Logistic Regression - Model1
ginilog <- performance(predictionlog, measure="auc") #Area under the curve - higher the value the better than predictive capacity of the results 
ginilog <- ginilog@y.values[[1]]
ginilog <- 2*ginilog-1 
ginilog   # Gini Coefficient = 0.4572285

#Kolmogorov-Smirnov Statistic - Logistic Regression - Model1
bads1 <- unlist(performancelog@x.values)
goods1 <- unlist(performancelog@y.values)
ks.test(goods1, bads1) #0.33043

#Linear Regression model 2 - ROC Performance
pred2 <- predict(linearmodel2bins, validation2new)
prediction2 <- prediction(pred2, validation2new$Good)
performance2 <- performance(prediction2, measure='tpr', x.measure='fpr')
plot(performance2, xlab='1-Specificity', ylab='Sensitivity')
abline(a=0,b=1)

#Gini Coefficient - Linear Regression - Model2
gini2 <- performance(prediction2, measure="auc") #Area under the curve - higher the value the better than predictive capacity of the results 
gini2 <- gini2@y.values[[1]]
gini2 <- 2*gini2-1
gini2                #Gini Coefficient = 0.1873327

#Kolmogorov-Smirnov Statistic - Linear Regression - Model2
bads2 <- unlist(performance2@x.values)
goods2 <- unlist(performance2@y.values)
ks.test(bads2, goods2) # 0.19328

#Logistic Regression Model 2 - ROC Performance
predlog2 <- predict(logmodel2bins, validation2new)
predictionlog2 <- prediction(predlog2, validation2new$Good)
performancelog2 <- performance(predictionlog2, measure='tpr', x.measure='fpr')
plot(performancelog2, xlab='1-Specificity', ylab='Sensitivity')
abline(a=0,b=1)

#Gini Coefficient - Logistic Regression - Model2
ginilog2 <- performance(predictionlog2, measure="auc") #Area under the curve - higher the value the better than predictive capacity of the results 
ginilog2 <- ginilog2@y.values[[1]]
ginilog2 <- 2*ginilog2-1 
ginilog2        # Gini Coefficient = 0.2140946

#Kolmogorov-Smirnov Statistic - Logistic Regression - Model2
bads3 <- unlist(performancelog2@x.values)
goods3 <- unlist(performancelog2@y.values)
ks.test(goods3, bads3) #0.21008

#Question 5- Derive ROC Curves for all scorecards

#Linear Regression Model - ROC Performance - Model 1
pred <- predict(linearmodel1bins, validation1new) #Make predictions on the validation set whether good or bad
prediction1 <- prediction(pred, validation1new$Good) #turn into a prediction type object #Make prediction of the amount of goods we can expect from validation set given our knowledge of those from the original date-set.
performance1 <- performance(prediction1, measure='tpr', x.measure='fpr') #use performance function to evaluate the efficacy of the predictions made against actual goods from validation 1.
plot(performance1, xlab='1-Specificity', ylab='Sensitivity') #plot the performance.
abline(a=0,b=1)

#Gini Coefficient 
gini <- performance(prediction1, measure="auc") #Area under the curve - higher the value the better than predictive capacity of the results 
gini <- gini@y.values[[1]]
gini <- 2*gini-1 # Gini Coefficient = 0.452178
gini
#kolmogorov-Smirnov Statistic
bads <- unlist(performance1@x.values) #change from performance object
goods <- unlist(performance1@y.values)
ks.test(goods, bads) #reports of KS score of 0.33.043

#Logistic Regression Model  - ROC Performance - Model 1
predlog <- predict(logmodel1bins, validation1new) #Predict given our understanding of "Good" what probability for "Good" is in Validation 1
predictionlog<- prediction(predlog, validation1new$Good)
performancelog<- performance(predictionlog, measure='tpr', x.measure='fpr') #Predict the number of "Goods" given the model
plot(performancelog, xlab='1-Specificity', ylab='Sensitivity') #Plot these on a RoC Curve
abline(a=0,b=1)

#Gini Coefficient - Logistic Regression - Model1
ginilog <- performance(predictionlog, measure="auc") #Area under the curve - higher the value the better than predictive capacity of the results 
ginilog <- ginilog@y.values[[1]]
ginilog <- 2*ginilog-1 
ginilog   # Gini Coefficient = 0.4572285

#Kolmogorov-Smirnov Statistic - Logistic Regression - Model1
bads1 <- unlist(performancelog@x.values)
goods1 <- unlist(performancelog@y.values)
ks.test(goods1, bads1) #0.33043

#Linear Regression model 2 - ROC Performance
pred2 <- predict(linearmodel2bins, validation2new)
prediction2 <- prediction(pred2, validation2new$Good)
performance2 <- performance(prediction2, measure='tpr', x.measure='fpr')
plot(performance2, xlab='1-Specificity', ylab='Sensitivity')
abline(a=0,b=1)

#Gini Coefficient - Linear Regression - Model2
gini2 <- performance(prediction2, measure="auc") #Area under the curve - higher the value the better than predictive capacity of the results 
gini2 <- gini2@y.values[[1]]
gini2 <- 2*gini2-1
gini2                #Gini Coefficient = 0.1873327

#Kolmogorov-Smirnov Statistic - Linear Regression - Model2
bads2 <- unlist(performance2@x.values)
goods2 <- unlist(performance2@y.values)
ks.test(bads2, goods2) # 0.19328

#Logistic Regression Model 2 - ROC Performance
predlog2 <- predict(logmodel2bins, validation2new)
predictionlog2 <- prediction(predlog2, validation2new$Good)
performancelog2 <- performance(predictionlog2, measure='tpr', x.measure='fpr')
plot(performancelog2, xlab='1-Specificity', ylab='Sensitivity')
abline(a=0,b=1)

#Gini Coefficient - Logistic Regression - Model2
ginilog2 <- performance(predictionlog2, measure="auc") #Area under the curve - higher the value the better than predictive capacity of the results 
ginilog2 <- ginilog2@y.values[[1]]
ginilog2 <- 2*ginilog2-1 
ginilog2        # Gini Coefficient = 0.2140946

#Kolmogorov-Smirnov Statistic - Logistic Regression - Model2
bads3 <- unlist(performancelog2@x.values)
goods3 <- unlist(performancelog2@y.values)
ks.test(goods3, bads3) #0.21008