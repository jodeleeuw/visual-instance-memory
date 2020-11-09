Sys.setenv('CUDA_VISIBLE_DEVICES' = "0")

# STAGE 1: Prepare the images

# I downloaded the set of images used in Konkle et al.
# from this link: https://bradylab.ucsd.edu/stimuli/Scenes.zip

# I did some cleanup on this set (some folders had 1-8 extra images;
# some filenames had invalid characters).

# This script will load all of the images, extract a Keras-appropriate
# representation, extract the category label, and save the images as a single object.
# To manage space, I downsized the images to 128 x 128 (originally 256 x 256). 

library(stringr)
library(keras)

target.image.size <- 128

exemplar.categories <- dir('scenes')

num.images <- length(list.files('scenes', pattern="(.jpg|.jpeg|.JPG|.gif)", recursive = T))

images <- array(data=0,dim=c(num.images,target.image.size,target.image.size,3))
image.exemplars <- rep(0, num.images)
image.category <- rep("", num.images)

count <- 1

for(f in exemplar.categories){
  category.exemplar.amount <- str_extract(f, pattern="[0-9]*")
  category.folders <- dir(paste0('scenes/',f))
  for(c in category.folders){
    category.name <- str_extract(c, pattern="[a-z_-]*[a-z]")
    image.paths <- dir(paste('scenes', f, c, sep="/"), pattern="(.jpg|.jpeg|.JPG|.gif)")
    for(i in image.paths){
      image.data <- keras::image_load(paste('scenes', f, c, i, sep="/"), target_size = c(target.image.size,target.image.size))
      image.array <- keras::image_to_array(image.data, data_format = "channels_last")
      images[count,,,] <- image.array
      image.exemplars[count] <- category.exemplar.amount
      image.category[count] <- category.name
      count <- count + 1
    }
  }
}

all.data <- list(
  images = images,
  category_labels = image.category,
  num_exemplars = as.numeric(image.exemplars)
)

saveRDS(all.data, file="scene-data.rds")
