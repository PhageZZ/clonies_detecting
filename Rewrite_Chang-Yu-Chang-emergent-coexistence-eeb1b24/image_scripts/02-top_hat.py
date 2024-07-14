import os
import sys
import pandas as pd
import imageio
import skimage
from skimage import morphology, util, io

list_images = pd.read_csv(str(sys.argv[1]))

def top_hat_transform(image):
    selem = morphology.disk(110)
    image_top_hat = morphology.white_tophat(image, selem)
    return image_top_hat

for i in range(list_images.shape[0]):
    image_name = str(list_images.iloc[i]['image_name'])  
    color_channel = str(list_images.iloc[i]['color_channel']) 

    image_path = os.path.join(list_images.iloc[i]['folder_channel'], color_channel, image_name + '.tiff')
    image = io.imread(image_path)
    image_top_hat = top_hat_transform(image)
    io.imsave(list_images.iloc[i]['folder_rolled'] + color_channel + "/" + image_name + '.tiff', image_top_hat)
    print(color_channel + " channel rolled\t" + str(i+1) + "/" + str(list_images.shape[0]) + "\t" + image_name)
