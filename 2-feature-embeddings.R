Sys.setenv('CUDA_VISIBLE_DEVICES' = "0")

# STAGE 2: Feature Embeddings

# This script loads the image data from STAGE 1 and runs it through
# the pre-trained CNN to extract feature embeddings. 

library(keras)

# Read in the image data
data <- readRDS('scene-data.rds')

# Preprocess the images through the tf model
images.preprocessed <- imagenet_preprocess_input(data$images, mode="tf")

# We download the VGG16 model with weights from the Keras server.
# If we set include_top = F then the model has only the convolutional
# feature layers. include_top = T will include the two dense layers at
# the top of the network, plus the categorization layer.

# fill this in

# We can setup a model that incorporated the VGG16 model, but with a 
# flatten layer at the top to turn the feature maps into a single
# vector of features, which will be easier to use in our MINERVA model.

# fill this in

# Get the features by running predict()

# fill this in

# Save the resulting output
saveRDS(features, file="scene-features-vgg16-128.rds")
