Sys.setenv('CUDA_VISIBLE_DEVICES' = "0")

library(keras)

conv_base <- application_vgg16(input_shape = c(128,128,3), include_top=F)

model <- keras_model_sequential()
model %>%
  conv_base %>%
  layer_flatten()
summary(model)

data <- readRDS('scene-data.rds')

images <- data$images
dim(images)

images.preprocessed <- imagenet_preprocess_input(images, mode="tf")

features <- model %>% predict(images)
