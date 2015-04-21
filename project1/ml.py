import sys
import os

import matplotlib.pyplot as plt
import numpy as np
import grabcut

#################################################################
# BEGIN REQUIRED INPUT PARAMETERS

# Bounding box and file extension
BBOX_DIR = "bboxes/"
BBOX_EXT = ".txt"

# Input images and file extension
DATA_DIR = "data_GT/"
DATA_EXT = ".jpg"

# Ground truth segmentation result and file extension
SEG_DIR = "seg_GT/"
SEG_EXT = ".bmp"

# Output log containing accuracy, jaccard, num iterations, runtime for each image
LOG_FILENAME = "ml.log"

# END REQUIRED INPUT PARAMETERS
#################################################################

def computeJaccard(segmentation, ground_truth):
    intersection = np.sum(np.logical_and(ground_truth > 0, segmentation > 0))
    union = np.sum((segmentation + ground_truth) > 0)
    return 100 * intersection / union

def computeAccuracy(segmentation, ground_truth):
    num_pixels = segmentation.shape[0]*segmentation.shape[1]
    num_correct_foreground = np.sum(np.logical_and(ground_truth > 0, segmentation > 0))
    num_correct_background = np.sum(np.logical_and(ground_truth == 0, segmentation == 0))
    return 100 * (num_correct_background + num_correct_foreground) / num_pixels

def main():
    SAVE_IMAGES = False

    # Get image names
    filenames = os.listdir(DATA_DIR)
    image_names = [f.replace(DATA_EXT, '') for f in filenames]

    all_accuracies = []
    all_jaccards = []

    if len(sys.argv) == 2:
        image_names = [sys.argv[1]]

    # Loop through all images
    for image_name in image_names:
        bbox_file = open(BBOX_DIR + image_name + BBOX_EXT, "r")
        bbox = map(int, bbox_file.readlines()[0].strip().split(" "))

        image = plt.imread(DATA_DIR + image_name + DATA_EXT)

        # Call GrabCut. Pass the image and bounding box.
        segmentation = grabcut.grabcut(image, bbox, image_name, num_iterations=10)

        # Compare the resulting segmentation to the GT segmentation
        # ground_truth is a grayscale image (2D matrix)
        ground_truth = plt.imread(SEG_DIR + image_name + SEG_EXT)

        # Compute accuracy
        accuracy = computeAccuracy(segmentation, ground_truth)
        # Compute Jaccard similarity
        jaccard = computeJaccard(segmentation, ground_truth)

        all_accuracies.append(accuracy)
        all_jaccards.append(jaccard)

        if SAVE_IMAGES:
            # Write images to file
            target_dir = "output/segmentations/" 
            if not os.path.exists(target_dir):
                os.makedirs(target_dir)

            image[segmentation == 0] = 0
            plt.imsave(os.path.join(target_dir, image_name + ".png"), image)

            segmentation = segmentation.astype(dtype=np.uint8)*255
            segmentation = np.dstack((segmentation, segmentation, segmentation))

            target_dir = "output/segmentation_masks/" 
            if not os.path.exists(target_dir):
                os.makedirs(target_dir)
            plt.imsave(os.path.join(target_dir, image_name + ".png"), segmentation)
        
        # Write to log file
        print image_name, accuracy, jaccard

    print "------------------------------------------------------"
    print "Number of Images:", len(filenames)
    print "Average Accuracy:", np.mean(np.array(all_accuracies))
    print "Average Jaccard:", np.mean(np.array(all_jaccards))
    print "------------------------------------------------------"

if __name__ == '__main__':
    main()