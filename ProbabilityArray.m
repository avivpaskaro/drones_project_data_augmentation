%{
Description: Find the probability to get each video by its size.                                      
             Gets:
             1. The directory path 
             2. The videos suffix type                                     
             Returns: 
             Array of structures with name (video name) and cumulative chance
             (double between 0 and 1).

Creators: Aviv Paskaro, Stav Yeger

Date: Dec-2019  
%}

function prob_arr = ProbabilityArray(videos_dir, suffix)
    tot_time = 0;
    video_type = ['*.',suffix];
    myFiles = dir(fullfile(videos_dir,video_type)); % gets all mp4 files in struct
    prob_arr = [];
    if (isempty(myFiles)==0)
        for k = 1:length(myFiles)
            prob_arr(k).name = myFiles(k).name;
            % read the current video
            vd_name  = [videos_dir,'\',prob_arr(k).name];
            vd       = VideoReader(vd_name);
            
            prob_arr(k).chance = double(vd.Duration);            
            tot_time = tot_time + prob_arr(k).chance;
        end
            prob_arr(1).chance = double(prob_arr(1).chance/tot_time);
        for k = 2:length(myFiles)
            prob_arr(k).chance = prob_arr(k-1).chance + double(prob_arr(k).chance/tot_time);                      
        end
    end
end

