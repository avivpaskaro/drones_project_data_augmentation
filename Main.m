%{
Description: Main script of the augmentation algorithm -            
             1. Remove background from raw drone video              
             2. Duplicate misdetected frames of previous stage                  
             3. Erase frames that are probably noise              
             4. Plot the drone centers graph to inspect cleaning defects
             5. Manually inspection - details below (**)  
             6. Create chance array that will be use in video randomization 
             7. Randomize, augmentation and merge 

Creators: Aviv Paskaro, Stav Yeger

Date: Dec-2019  
%}


%% 1 Step - Remove background from raw drone video     
% Parameters                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    
read_resolution = [2160 4069];
drones_dir      = 'Drones';
window_size     = 15; 
bg_filter       = false; 

if(bg_filter) % activate stage flag
    if ~exist('BgFiltered', 'dir')  
        files = dir(drones_dir);    
        for ii = 3:length(files) 
           drone_video = files(ii).name; 
           BgFiltering(drone_video, window_size, read_resolution);      
        end    
    end
end

%% 2 Step - Duplicate misdetected frames of previous stage   
% Parameters
duplicate          = false; % activate flag
duplicate_LENGTH   = 3;
duplicate_DISTANCE = 500;

if(duplicate) 
    files = dir('.\BgFiltered'); 
    for ii = 3:length(files)        
        drone_video_name = files(ii).name;    
        [~, ~, fExt] = fileparts(drone_video_name);
        if (lower(fExt) == ".txt")
            DuplicateFrame(drone_video_name, duplicate_LENGTH,...
                duplicate_DISTANCE);
        end             
    end     
end

%% 3 Step - Erase frames that are probably noise    
% Parameters
noise_clean        = false; % activate flag
noise_clean_LENGTH = 10;

if(noise_clean)
    files = dir('.\BgFiltered');  
    for ii = 3:length(files)       
        drone_video_name = files(ii).name;
        [~, ~, fExt] = fileparts(drone_video_name);
        if (lower(fExt) == ".txt")
            NoiseRemover(drone_video_name, noise_clean_LENGTH);
        end       
    end    
end

%%  4 Step - Plot the drone centers graph to inspect cleaning defects    
% Parameters 
plot_difference = false; % activate flag
plots_dir  = 'NoiseRemoved';

if(plot_difference)
    PlotDistBetPoints(plots_dir)    
end

%%  5 Step - Manually inspection (**)     
%{
Separate videos, by inspecting the plots, for 3 groups:
1. Fix is not needed
2. Can be manually fixed
3. Non-fixable
Try to resolve the issue non-fixable by spliting video or changes 
Bgfiltering parameters and rerun. After that fix manually with ManualFrameDelete
and final collect all good video into FinalGT directory. Whatever cannot be fixed, 
remove all drone video\gt from list.   
%}

%%  6 Step - Create chance array that will be use in video randomization    
% Parameters
create_chance_arrays = false; % activate flag
drones_dir = 'Drones';
urbans_dir = 'Environment';

if(create_chance_arrays)
    chance_arr_drone = ProbabilityArray(drones_dir,'mp4');
    chance_arr_urban = ProbabilityArray(urbans_dir,'mp4');
end

%%  7 Step - Randomize, augmentation and merge   
% Parameters 
create_dataset      = false; % activate flag
write_resolution    = [720 1280];
batch_size          = 5000; % dataset size
duration            = 5;    % duration of video (sec)
bg_filtered_vid_dir = 'FinalGT';

if(create_dataset)
    tic
    for ii = 1:batch_size
        % Randomize
        [v_drone, v_gt, v_urb, PID]  = Randomize(duration, drones_dir,... 
            urbans_dir, bg_filtered_vid_dir, chance_arr_drone,...
            chance_arr_urban, ii);    
        % Augmentation
        [v_drone_aug, v_gt_aug] = Augment(v_drone, v_gt, ii,...
            read_resolution, PID);    
        % Merge
        Merge(v_gt_aug, v_drone_aug, v_urb, ii, read_resolution,...
            write_resolution, PID);   

        rmdir(['PID_', num2str(feature('getpid')), '_iter_',...
            num2str(ii)], 's')
    end
    toc
end


