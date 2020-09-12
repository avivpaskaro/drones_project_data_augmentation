# drones_project_data_augmentation

Main script of the augmentation algorithm -            
  1. Remove background from raw drone video              
  2. Duplicate misdetected frames of previous stage                  
  3. Erase frames that are probably noise              
  4. Plot the drone centers graph to inspect cleaning defects
  5. Manually inspection - details below (**)  
  6. Create chance array that will be use in video randomization 
  7. Randomize, augmentation and merge 
  
  all of above controled through Main.m file
