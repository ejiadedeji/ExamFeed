# takes in the groundtruth images and creates a bounding box
getCrop <- function(gt) {
  top <- -1
  bot <- -1
  left <- -1
  right <- -1
  
  # scrolls from left to right and saves the location of the first and last white pixels
  for(i in 1:dim(gt)[1]) {
    if(any(0 != gt[i,,1,1]) & left == -1) {
      left <- i - 1
    } else if (any(0 == gt[i,,1,1]) & left != -1 & right == -1) {
      right <- i
    } else if (any(0 != gt[i,,1,1])) {
      right <- -1.0
    }
  }
  
  # adds check if the white pixels go off screen
  if(left != -1 & right == -1) {
    right <- dim(gt)[1]
  }
  
  # same for top and bottom
  for(i in 1:dim(gt)[2]) {
    if(any(0 != gt[,i,1,1]) & top == -1) {
      top <- i - 1
    } else if (any(0 == gt[,i,1,1]) & top != -1 & bot == -1) {
      bot <- i
    } else if (any(0 != gt[,i,1,1])) {
      bot <- -1.0
    }
  }
  
  if (top != -1 & bot == -1) {
    bot <- dim(gt)[2]
  }
  
  # scales the values between 0 to 1
  if(top != -1) {
    top <- top / dim(gt)[2]
    bot <- bot / dim(gt)[2]
    left <- left / dim(gt)[1]
    right <- right / dim(gt)[1]
  }
  
  return(array(c(top, bot, left, right)))
}

library(imager)
# what to resize the image by
image_height <- 150
image_width <- 150

# create test and training arrays
in_train <- array(dim = c(image_height * image_width,0))
out_train <- array(dim = c(0,4))
in_test <-array(dim = c(image_height * image_width,0))
out_test <- array(dim = c(0,4))

# loop over training images to load
for(i in 570:1899) {
  print(paste("Loading image", i, "of 2050"))
  img_name = formatC(i, width=6, flag="0")
  
  # load input and output images, resize them, add to training data
  in_image <- grayscale(load.image(paste("office/input/in", img_name, ".jpg", sep="")))
  out_image <- grayscale(load.image(paste("office/groundtruth/gt", img_name, ".png", sep="")))
  in_image <- resize(in_image, size_x = image_width, size_y = image_height)
  out_image <- resize(out_image, size_x = image_width, size_y = image_height)
  
  in_train <- cbind(in_train, c(in_image))
  out_train <- rbind(out_train, getCrop(out_image))
}

# same for test images
for(i in 1900:2050) {
  print(paste("Loading image", i, "of 2050"))
  img_name = formatC(i, width=6, flag="0")
  
  in_image <- grayscale(load.image(paste("office/input/in", img_name, ".jpg", sep="")))
  out_image <- grayscale(load.image(paste("office/groundtruth/gt", img_name, ".png", sep="")))
  in_image <- resize(in_image, size_x = image_width, size_y = image_height)
  out_image <- resize(out_image, size_x = image_width, size_y = image_height)
  
  in_test <- cbind(in_test, c(in_image))
  out_test <- rbind(out_test, getCrop(out_image))
}

library(keras)

# reshape data for keras (probably could be done in previous step but its fast)
in_train <- array_reshape(in_train, c(ncol(in_train), image_width * image_height))
in_test <- array_reshape(in_test, c(ncol(in_test), image_width * image_height))

#creates a new model
model <- keras_model_sequential()

# here are two versions of the model I created. The first seems to overtrain and the second seems to be less accurate
#model %>%
#  layer_dense(units = image_width * image_height, activation = 'relu', input_shape = c(image_width * image_height)) %>%
#  layer_dense(units = image_width * image_height / 2, activation = 'relu') %>%
#  layer_dense(units = image_width * image_height / 4, activation = 'relu') %>%
#  layer_dense(units = image_width * image_height / 8, activation = 'relu') %>%
#  layer_dense(units = 4, activation = 'linear')

model %>%
  layer_dense(units = image_width * image_height * (4/5), activation = 'relu', input_shape = c(image_width * image_height)) %>%
  layer_dense(units = image_width * image_height * (2/3), activation = 'relu') %>%
  layer_dense(units = 4, activation = 'linear')
  

# set the loss, optimizer, and metrix
model %>% compile(
  loss = 'mean_squared_error',
  optimizer = optimizer_adam(),
  metrics = c('accuracy')
)

# train the model and save it's results to history
history <- model %>% fit(
  in_train, out_train,
  epochs = 50, batch_size=128,
  validation_steps = 1
)

# see how well the model did
plot(history)

# this runs the predictions over the testing data, adds the predictions as lines ontop of the image, and displays the images
in_test_bounds <- array_reshape(in_test, c(image_height, image_width, 151), order= "C")
predict_bounds <- model %>% predict(in_test)
predict_bounds[predict_bounds > 1] <- 1
predict_bounds[predict_bounds < 0] <- 0
for(i in 1:nrow(predict_bounds)) {
  in_test_bounds[predict_bounds[i, 1] * nrow(in_test_bounds),,i] <- 1
  in_test_bounds[predict_bounds[i, 2] * nrow(in_test_bounds),,i] <- 1
  in_test_bounds[,predict_bounds[i, 3] * nrow(in_test_bounds),i] <- 1
  in_test_bounds[,predict_bounds[i, 4] * nrow(in_test_bounds),i] <- 1
  image(in_test_bounds[,,i])
}