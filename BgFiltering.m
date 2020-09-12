%{
Description: Tool for cleaning video files from noise. 
             Extracting moving from the frame static BG by 
             subtracting the median-frame for each frame. 

Creators: Aviv Paskaro, Stav Yeger

Date: Dec-2019  
%}

function v_out = BgFiltering(v_in, w_width, resolution)
    load_bar = waitbar(0,'Please wait...','Name','Creating subtracted BG video');  
	
    % parameters
    cleaning_threshold = 40; 
    frames_granularity = 24;
    crop_region        = [129 1 3839 2159]; % [Xleft Ytop Width-1 Height-1] 
	
    % init script variables 
    v_name             = v_in;
    v_in               = VideoReader(['.\Drones\',v_in]);
    blob_state         = false;
    empty_frame        = zeros(resolution);
    blob_frame         = zeros(resolution);
    frame_cycle_time   = 1/v_in.FrameRate;
    frames_group_cycle_time = frames_granularity * frame_cycle_time;
    steps              = int16(v_in.Duration * v_in.FrameRate);
    last_median_frame  = floor(v_in.Duration / frames_group_cycle_time) + 1;
    c_mass_table       = zeros(uint8(steps), 2);    
	
    % frames containers
    Rcontainer = zeros([resolution w_width]);
    Gcontainer = zeros([resolution w_width]);
    Bcontainer = zeros([resolution w_width]);    
    
    % reading every granularity-frame
    for ii = 1:w_width 
        frame              = readFrame(v_in);
        frame              = imcrop(frame, crop_region);
        Rcontainer(:,:,ii) = frame(:,:,1);
        Gcontainer(:,:,ii) = frame(:,:,2);
        Bcontainer(:,:,ii) = frame(:,:,3);     
        if(ii < w_width)
            v_in.CurrentTime = v_in.CurrentTime + frames_group_cycle_time - frame_cycle_time;  
        end
    end
	
    % if clean dir exist - skip BgRemove 
    if ~exist('BgFiltered', 'dir')
       mkdir('BgFiltered')
    end   
	
    % set writen video name
    v_out_name      = ['.\BgFiltered\gt_', v_in.Name]; 
    v_out           = VideoWriter(v_out_name,'MPEG-4');
    v_out.FrameRate = v_in.FrameRate;
    open(v_out);
	
    % init loop variables
    curr_median      = 1;
    step             = 1;
    v_in.CurrentTime = 0;
    start_t          = tic;
	
    % removing median from frames
    while hasFrame(v_in)
        frame = readFrame(v_in);
        frame = imcrop(frame, crop_region); 
		
        % every granularity-frame calculate new median
        if(mod(step,frames_granularity) == 1)           
            % calc valid indices 
            [window, window_max_val] = range(curr_median, w_width, last_median_frame);
            curr_median              = curr_median + 1;
			
            % calculate new median
            Rmed   = median(Rcontainer(:,:,window),3);
            Gmed   = median(Gcontainer(:,:,window),3);
            Bmed   = median(Bcontainer(:,:,window),3);
            RGBmed = cat(3, Rmed, Gmed, Bmed);
			
            % if window size is the max - read new frame and delete old frame
            if( length(window) ==  w_width &&  window_max_val < last_median_frame )                
                v_in.CurrentTime = v_in.CurrentTime + frames_group_cycle_time;
                frame1           = readFrame(v_in);
                frame1           = imcrop(frame1, crop_region);
                v_in.CurrentTime = v_in.CurrentTime - frames_group_cycle_time - frame_cycle_time; 
                Rcontainer       = cat(3, Rcontainer(:,:,2:end), frame1(:,:,1));
                Gcontainer       = cat(3, Gcontainer(:,:,2:end), frame1(:,:,2));
                Bcontainer       = cat(3, Bcontainer(:,:,2:end), frame1(:,:,3));                
            end    
        end    
		
        % substract median from current frame
        med_diff = double(frame - uint8(RGBmed)); 
		
        % if blob exist, calc with blob's mask
        if(blob_state == false)
            disp(['blob_state == false  ', v_name])% worker id == %d', worker_id)
            ind_map = Morpho(med_diff, cleaning_threshold);
        else
            disp(['blob_state == true  ', v_name])% worker id == %d', worker_id)
            ind_map = Morpho(med_diff.*double(blob_frame), cleaning_threshold);
        end    
		
		% if found one object - create new blob around him
        CC = bwconncomp(ind_map);
        if(CC.NumObjects ~= 1)
            ind_map    = empty_frame;
            blob_state = false; 
        else 
            blob_frame = imdilate(ind_map, strel('disk',400));
            blob_state = true;
        end   
		
        % center of mass calculating
        if(blob_state == 1) 
            props  = regionprops(ind_map, 'Centroid');
            c_mass = flip(uint16(props.Centroid));
        else
            c_mass = [-1 -1];
        end
        c_mass_table(step, :) = c_mass; 
		
        % writing v_out
        writeVideo(v_out, uint8(255*ind_map));  
		
        % status bar
        t        = toc(start_t);
        rem_time = (t/step)*(steps-step);
        m        = floor(rem_time/60);
        s        = round(rem_time-m*60);
        prog_str = sprintf('Progress:%2.1f%% Time Remain:%2.0f:%2.0f', double(step)/double(steps)*100, m, s);
        waitbar(double(step)/double(steps), load_bar, prog_str);        
        step = step + 1;
    end   
    close(v_out); 
    v_name = strsplit(v_name, {'.MP4'});
    writematrix(c_mass_table, ['.\BgFiltered\gt_', v_name{1}, '.txt'], 'Delimiter', 'tab')
    close(load_bar);
end


function [window, max_val] = range(index, w_width, max_frame)
    % define the range by the window parity  
    if(mod(w_width,2) == 0)
        upper_range = w_width/2; 
        lower_range = w_width/2 - 1;
    else
        upper_range = floor(w_width/2);
        lower_range = floor(w_width/2);   
    end   
	
    window  = (index - lower_range) : (index + upper_range);
    mask    = (window >= 1) & (window <= max_frame);
    window  = window(mask);
    max_val = window(end);
    if(max_val > w_width)
        window = window - (max_val - w_width);
    end
end


function ind_map = Morpho(bg_removed_frame, cleaning_threshold)
    map     = bg_removed_frame;
    map     = max(map, [], 3);
    ind_map = map>cleaning_threshold;
	ind_map = bwareaopen(ind_map,400);
    
    if(~isempty(find(ind_map,1)))
        ind_map  = bwpropfilt(ind_map,'Eccentricity',[0 0.9]);
        ind_map  = bwareafilt(ind_map, 1);
        obj_size = regionprops(ind_map, 'Area');
        if(~isempty(obj_size))
            windowSize  = round(2*log(obj_size.Area)/log(10));
            kernel      = ones(windowSize) / windowSize ^ 2;
            ind_map     = conv2(single(ind_map), kernel, 'same');
            ind_map     = ind_map > 0.5; % re-threshold
        end
        ind_map = bwpropfilt(ind_map,'Area',[3000 150000]);
    end
end