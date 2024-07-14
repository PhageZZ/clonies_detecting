"""
This script takes a grey-scale image and enhances the contrast to subtract the background.

Prerequisite: 
$ pip install pandas
$ pip install scikit-image

To use this script, in terminal 
$ python 02-enhance_contrast.py list_images.csv

For example
$ python 02-enhance_contrast.py mapping_files/00-list_images-B2-green.csv
"""

import os
import sys
import pandas as pd
import imageio
from skimage import io, exposure, img_as_ubyte

list_images = pd.read_csv(str(sys.argv[1]))

def enhance_contrast(image):
    # Enhance the contrast of the image using histogram equalization
    image_enhanced = exposure.equalize_adapthist(image, clip_limit=0.03)
    # Convert the image back to 8-bit unsigned byte format
    image_enhanced_ubyte = img_as_ubyte(image_enhanced)
    return image_enhanced_ubyte

for i in range(list_images.shape[0]):
    try:
        image_name = str(list_images.iloc[i]['image_name'])  
        color_channel = str(list_images.iloc[i]['color_channel']) 

        image_path = os.path.join(list_images.iloc[i]['folder_channel'], color_channel, image_name + '.tiff')
        image = io.imread(image_path)
        
        # Ensure the image is grey-scale
        if len(image.shape) == 3:
            raise ValueError("Image is not grey-scale")
        
        image_enhanced = enhance_contrast(image)
        
        output_path = os.path.join(list_images.iloc[i]['folder_rolled'], color_channel, image_name + '.tiff')
        io.imsave(output_path, image_enhanced)
        
        print(f"{color_channel} channel enhanced\t{i+1}/{list_images.shape[0]}\t{image_name}")
    except Exception as e:
        print(f"Error processing {image_name}: {e}")
