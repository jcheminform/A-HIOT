require(h2o)
require(caret)
h2o.init(nthreads=-1, max_mem_size="16G")
h2o.removeAll()
data <- h2o.importFile("new_with_removed_zeros_y.csv")
dim(data)
print(dim(data))
splits<- h2o.splitFrame(data, ratios = 0.70, seed = -1)
train <- splits[[1]]
test <- splits[[2]]
h2o.exportFile(test, "DL_internal_test.csv", header=TRUE)
train <- train[2:674]
test <- test[2:674]
train$y <- as.factor(train$y)
test$y <- as.factor(test$y)
y <- "y"
nfolds <- 10
predictors <- setdiff(names(train), y)
train[,y] <- as.factor(train[,y])
test[,y] <- as.factor(test[,y])

#Modelling_DNN
my_dl_model <- h2o.deeplearning(model_id="dl_model_first", training_frame=train, validation_frame = test, x=predictors, y=y,  nfolds = 10, keep_cross_validation_fold_assignment = TRUE, fold_assignment = "Random", activation = "Tanh", score_each_iteration = TRUE, hidden = c(672, 300, 200, 2), epochs = 50, variable_importances = TRUE, export_weights_and_biases = TRUE, seed = 42)

h2o.mean_per_class_error(my_dl_model, train = TRUE, valid = TRUE, xval = TRUE)

conf_mat_test <- h2o.confusionMatrix(my_dl_model, valid = TRUE)
training_auc <- h2o.auc(my_dl_model, train = TRUE)
validation_auc <- h2o.auc(my_dl_model, valid = TRUE)
cross_valid_auc <- h2o.auc(my_dl_model, xval = TRUE)
imp_variables <- h2o.varimp(my_dl_model)

#Hyper parameterization with Grid Search
hyper_params <- list(hidden=list(c(672,200,300),c(300,2)), input_dropout_ratio=c(0,0.05), rate=c(0.01,0.02), rate_annealing=c(1e-10,1e-9,1e-8))

grid <- h2o.grid(algorithm="deeplearning", grid_id="my_dl_grid", training_frame=train, validation_frame = test, x= predictors, y=y, epochs=50, stopping_metric="misclassification", stopping_tolerance=1e-2, stopping_rounds=2, adaptive_rate=F,  momentum_start=0.5,  momentum_stable=0.9, activation=c("Tanh"), max_w2=10, hyper_params=hyper_params)
print(grid)

#best model with Hyper-parameters

grid <- h2o.getGrid("my_dl_grid",sort_by="err",decreasing=FALSE)
grid@summary_table[1,]
best_model <- h2o.getModel(grid@model_ids[[1]])
print(best_model)
h2o.confusionMatrix(best_model,valid=T)
print(h2o.performance(best_model, valid=T))
print(h2o.logloss(best_model, valid=T))


#Performance Plot
jpeg('DL_training_perf_with_epochs.jpg')
plot(my_dl_model, timestep = "epochs", metric = "classification_error")
dev.off()

jpeg('DL_training_imp_variables.jpg')
h2o.varimp_plot(my_dl_model, 30)
dev.off()

#Predictions for training
perf_train <- h2o.performance(best_model, train)
jpeg('DL_training_model.jpg')
plot(perf_train, colorize=TRUE, lwd=1, main="DL perfromance for training", print.cutoffs.at=seq(0, 1, by=0.05), text.adj=c(-0.5, 0.5), text.cex=0.5)
plot(perf_train)
dev.off()

#Predictions on test data
perf_test <- h2o.performance(best_model, test)
jpeg('DL_performance_for_internal_test_set.jpg')
plot(perf_test, colorize=TRUE, lwd=1, main="DL perfromance for internal test", print.cutoffs.at=seq(0, 1, by=0.05), text.adj=c(-0.5, 0.5), text.cex=0.5)
#plot(perf_test)
dev.off()
h2o.logloss(perf_test)
h2o.auc(perf_test)

test_predict <- h2o.predict(object = best_model, newdata = test )

#h2o.exportFile(test, "/home/user/DNN_RF/pipeline_validation/dud_e/Chemical_space/Paper_final_run/DL_paper/DL_internal_test.csv", header=TRUE)

h2o.exportFile(test_predict, "sDL_predicted_internal_test.csv", header=TRUE)

h2o.shutdown()
