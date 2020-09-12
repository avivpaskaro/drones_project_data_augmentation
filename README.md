# Data augmentation

Augmentation algorithm:  
  1. Remove background from raw drone video              
  2. Duplicate misdetected frames of previous stage                  
  3. Erase frames that are probably noise              
  4. Plot the drone centers graph to inspect cleaning defects
  5. Detect which frames were duplicated for future randomizing and video crop
  6. Manually inspection - details below (**)  
  7. Create chance array that will be use in video randomization 
  8. Randomize, augmentation and merge 
  
  all of above controled through Main.m file
