library(dplyr)
library(tidyr)
library(ggplot2)
library(keras)

# Load MINERVA model
source('minerva.R')

# Load image info
image.data <- readRDS('scene-data.rds')
image.cnn.features <- readRDS('scene-features-vgg16-128.rds')
# image.raw.features <- keras::array_reshape(image.data$images, dim=c(4672,128*128*3))
image.categories <- image.data$category_labels
image.exemplars <- image.data$num_exemplars
rm(image.data) # memory management

# PARAMETERS
tau <- 3 # Higher values will mean that activations are stronger for highly similar items in memory.
         # Lower values spread out the activation more, so loosely similar items are somewhat activated.
lossy.encoding <- .7 # proportion of features to KEEP when encoding.
features.to.use <- image.cnn.features

####
# STUDY PHASE OF EXPERIMENT
####

# In the study phase, participants viewed a total of 2,720 images.
# These images were from categories with either 1, 4, 16, or 64
# exemplars. There were 32 categories per type, so:
# 32 + 4*32 + 16*32 + 64*32 = 2,720

# To create the list of images, the authors had:
# 64 single-exemplar categories
# 16 four-exemplar categories
# 16 sixteen-exemplar categories
# 16 sixty-four-exemplar categories
# 48 sixty-eight-exemplar categories

# The 48 categories with 68 exemplars were randomly
# assigned to be either 4, 16, or 64 items for each subject.
# This ensured that there were at least four reserve items that
# participants did not study for the test phase.
# Participants were ONLY tested with the items in the 68-exemplar categories.

# To implement:

# We start by making a data frame with the index of each item,
# the category of that item, and the number of exemplars in that
# category.
exemplar.info <- data.frame(
  category=image.categories, 
  index=1:length(image.categories), 
  exemplars=image.exemplars
)

# Since there are different procedures for the different
# kinds of categories, we can split the task up into different
# groupings and then merge it all back together.

# For the single-exemplar categories, we extract all
# of those items and assign half of them to be studied
# by adding a studied column.

exemplars.1 <- exemplar.info %>%
  filter(exemplars == 1) %>%
  mutate(studied = sample(c(rep(T,32),rep(F,32))))

# For the 4, 16, and 64 exemplar categories, all of the
# items are studied. (These are basically just filler items
# in the task).

exemplars.4.16.64 <- exemplar.info %>%
  filter(exemplars %in% c(4,16,64)) %>%
  mutate(studied=T)

# For the 68 exemplar categories...

# ... we first need to pick which categories
# are 4, 16, and 64. We can make a data frame that has
# one entry per category, and a column that tells us how
# many exemplars were studied for that category.

exemplars.68.categories <- exemplar.info %>%
  filter(exemplars == 68) %>%
  group_by(category) %>%
  summarize() %>%
  mutate(studied.exemplars = sample(rep(c(4,16,64),16)))

# Then we go back into the main data, and pick random exemplars
# to study. We add the info from the above step into this, and use
# this to assign a `studied` value to each exemplar.

exemplars.68 <- exemplar.info %>%
  filter(exemplars == 68) %>%
  left_join(exemplars.68.categories) %>%
  group_by(category) %>%
  mutate(studied = sample(c(rep(T,unique(studied.exemplars)), rep(F,n()-unique(studied.exemplars))))) %>%
  select(-studied.exemplars)

# Finally, we combine all sets back together, 
# and extract indicies of studied exemplars.
# Then we can grab the features from this set of
# images and store in a matrix.

exemplars.combined <- bind_rows(exemplars.1, exemplars.4.16.64, exemplars.68)

studied.list <- exemplars.combined %>% filter(studied == T) %>% pull(index)

to.study <- features.to.use[studied.list,]

# ENCODE IT!

# After all this we can encode the studied items in MINERVA
# using the function we wrote in minerva.R

store <- minerva.encode.items(to.study, L=lossy.encoding)

####
# TEST PHASE OF EXPERIMENT
####

# We need to pick which eight items will be the test items from
# all of the categories that had 68 exemplars. (Remember that
# the participant only studied 4, 16, or 64 items from these
# categories.) We need four items that were studied, and four
# that were not.
random.test.items.4.16.64 <- exemplars.combined %>% # start with the full set of exemplars
  filter(exemplars == 68) %>% # filter to only the 68 categories
  group_by(category, studied) %>% # group by category and whether item was studied
  sample_n(4) %>% # pick a random 4 items from each category
  mutate(test_pair=1:4) %>% # label these as pairs 1-4 so we can do 2AFC later.
  ungroup() # remove grouping now that we have data as needed.

# For the single-item categories, we need to do a little data
# cleanup to get things formatted correctly for later on.
# We'll randomly pair these into 32 different pairs 
# (64 categories; half studied). Then we'll change the category
# label to "novel" rather than their individual category names.
# This way we can group these together later.
test.items.1 <- exemplars.combined %>%
  filter(exemplars == 1) %>%
  group_by(studied) %>%
  mutate(test_pair = 1:32) %>%
  mutate(category = "novel")

# Finally, we combine the single-exemplar and multi-exemplar 
# categories together.
test.items <- test.items.1 %>%
  bind_rows(random.test.items.4.16.64) %>%
  left_join(exemplars.68.categories) %>%
  mutate(studied.exemplars = if_else(is.na(studied.exemplars), exemplars, studied.exemplars))

# We're now ready to use MINERVA to calculate the intensity of the
# activation for each of the items in the test set. 

test.items <- test.items %>%
  rowwise() %>%
  mutate(intensity = minerva.intensity(features.to.use[index,], store, tau=tau)) %>%
  ungroup()

# Simulate the test phase.
# In the test, participants saw two images at a time, one of which
# they had seen before. The task was to pick the image they had seen.
# We'll simulate this by comparing the intensity of activation
# for pairs of images, and assuming participants always pick the image with
# the more intense activation.

results <- test.items %>%
  select(-index) %>%
  pivot_wider(names_from = studied, values_from = intensity, names_prefix = "STUDIED_") %>%
  mutate(correct = STUDIED_TRUE > STUDIED_FALSE) %>%
  group_by(studied.exemplars) %>%
  summarize(M = mean(correct)) %>%
  mutate(source = "model")

# We can plot the data, and compare with the data from the 
# experiment.

exp.results <- data.frame(
  studied.exemplars = c(1,4,16,64),
  M = c(.94,.84,.80,.76), # taken from the paper
  source = "experiment"
)

combined.results <- results %>%
  bind_rows(exp.results)

ggplot(combined.results, aes(x=studied.exemplars, y=M, fill=source))+
  geom_bar(stat="identity", position=position_dodge(width=0.55)) +
  scale_x_log10(breaks=c(1,4,16,64))+
  scale_fill_brewer(type="qual", palette = "Set1")+
  labs(x="Studied Items", y="Proportion Recalled", fill=NULL)+
  theme_bw()




