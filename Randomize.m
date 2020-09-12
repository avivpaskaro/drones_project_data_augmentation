%{
Description: Pick a random videos, and then pick a random frame in the video to create:
             1.n random short videos 
             2.GT of each short video  
             3.random short urban video
             
             **all video are at the same duration

Creators: Aviv Paskaro, Stav Yeger

Date: Dec-2019  
%}

function [selected_vid_drone, selected_vid_gt, selected_vid_urb, PID] ...
        = Randomize ...
         (duration, drone_dir, urban_dir, gt_dir, chance_arr_drone, chance_arr_urban, iter)
    
    % Parameters
    crop_region        = [129 1 3839 2159]; % set crop region - [Xleft Ytop Width-1 Height-1]
       
    load_bar           = waitbar(0,'Please wait...','Name','Creating motion-detector video');
    drones_n           = str2num(randsample('123',1,true,[0.5 0.3 0.2])); %#ok<ST2NM>
    selected_vid_drone = cell(drones_n,1);
    selected_vid_gt    = cell(drones_n,1);
    info_vid_drone     = cell(drones_n+1,3);
    
    for ii = 1:drones_n
        start_t=tic;
        
        % pick random video - drone 
        [~,index]        = find(([chance_arr_drone.chance]>rand),1);
        drone_path_name  = [drone_dir ,'\', chance_arr_drone(index).name];
        info_vid_drone{ii,1} = drone_path_name;
        gt_path_name     = [gt_dir ,'\gt_',chance_arr_drone(index).name];       
        gt_name          = split(chance_arr_drone(index).name, '.');
        gt_dup_mat       = load([gt_dir, '\gt_', gt_name{1}, '.mat']).Y;
       
        % read video
        v_drone = VideoReader(drone_path_name);
        v_gt    = VideoReader(gt_path_name);
        
        % check if iter dir exist
        PID   = feature('getpid');
        direc = ['PID_', num2str(PID), '_iter_', num2str(iter)];
        if ~exist(direc, 'dir')
           mkdir(direc)
        end
        
        v_drone_name                     = [direc, '\', sprintf('rand_drone_%d.mp4', ii)];
        v_gt_name                        = [direc, '\', sprintf('rand_gt_%d.mp4', ii)]; 
        selected_vid_drone{ii}           = VideoWriter(v_drone_name,'MPEG-4');
        selected_vid_gt{ii}              = VideoWriter(v_gt_name,'MPEG-4');
        selected_vid_drone{ii}.FrameRate = v_drone.FrameRate;
        selected_vid_gt{ii}.FrameRate    = v_drone.FrameRate;
        tot_frames_drone                 = v_drone.Duration*v_drone.FrameRate;
        tot_frames_gt                    = v_gt.Duration*v_gt.FrameRate;
        open(selected_vid_drone{ii});
        open(selected_vid_gt{ii});

        % throw error about duration
        if (duration*v_drone.FrameRate>tot_frames_drone) 
           ME = MException('Rendomize:Duration', ...
               'Duration %f is longer then the drone video duration %f',duration,v_drone.Duration);
           throw(ME) 
        end
        if (duration*v_gt.FrameRate>tot_frames_gt) 
           ME = MException('Rendomize:Duration', ...
               'Duration %f is longer then the drone video duration %f',duration,v_gt.Duration);
           throw(ME) 
        end
        
        tot_frames_drone = duration*v_drone.FrameRate;
        tot_frames_gt    = duration*v_gt.FrameRate;
        
        while(1)
            % pick random start point for drone  
            start_time_drone = rand*(v_drone.Duration-duration);
            
            % round start point to match a frame slack
            a = 0:0.04:v_drone.Duration;
            b = find(start_time_drone < a, 1);
            d = a(b) - start_time_drone;
            e = start_time_drone - a(b-1);
            if(d > e)
                start_time_drone = a(b-1);               
            else
                start_time_drone = a(b);
            end
            
            % get the dup mat
            starting_frame_ind = find(a == start_time_drone);
            gt_dup_mat_tmp     = gt_dup_mat(starting_frame_ind : starting_frame_ind + tot_frames_gt -1);
            
            % if first frame need to be duplicate, 
            % or the are more than two duplications - try again
            if(gt_dup_mat_tmp(1) == 1 || sum(gt_dup_mat_tmp) > 2)
                continue
            else
                break
            end
        end
        
        gt_dup_mat          = gt_dup_mat_tmp;
        v_drone.CurrentTime = start_time_drone+v_drone.CurrentTime;
        v_gt.CurrentTime    = start_time_drone+v_gt.CurrentTime;
        info_vid_drone{ii,2} = 'starting frame';
        info_vid_drone{ii,3} = starting_frame_ind;
        %Y = [];
        
        % write the drone and gt videos
        frame_count = 1;
        while (v_drone.hasFrame && v_gt.hasFrame)
            if(frame_count > tot_frames_drone)
                break; 
            end
            
            drone_frame = imcrop(readFrame(v_drone), crop_region);
            
            % need to duplicate frame
            if(gt_dup_mat(frame_count))
                % Y = [Y Y(frame_count-1)];
                writeVideo(selected_vid_drone{ii},uint8(drone_prev_frame));
                writeVideo(selected_vid_gt{ii},uint8(readFrame(v_gt)));
                % drone_prev_frame = drone_prev_frame;
            else
                % Y = [Y starting_frame_ind+frame_count-1];
                writeVideo(selected_vid_drone{ii},uint8(drone_frame));
                writeVideo(selected_vid_gt{ii},uint8(readFrame(v_gt)));
                drone_prev_frame = drone_frame;
            end
                                
            % status bar
            prog     = frame_count/tot_frames_gt;
            prog_str = sprintf('cutting drone %d video \n passed %4.0f from %4.0f', ...
                ii, frame_count, tot_frames_gt);
            waitbar(prog,load_bar,prog_str);
            frame_count = frame_count+1;          
        end
                
        % urban video
        if (ii==drones_n)            
            % picking random urban video 
            [~,index]                  = find(([chance_arr_urban.chance]>rand),1);
            urban_path_name            = [urban_dir ,'\', chance_arr_urban(index).name];
            info_vid_drone{ii+1,1}     = urban_path_name;
            v_urb                      = VideoReader(urban_path_name);
            v_urb_name                 = [direc, '\', sprintf('.\\rand_urb_%d.mp4',iter)]; 
            selected_vid_urb           = VideoWriter(v_urb_name,'MPEG-4');
            selected_vid_urb.FrameRate = v_drone.FrameRate;
            tot_frames_urb             = v_urb.Duration*v_drone.FrameRate;
            open(selected_vid_urb);
            
            % throw error about duration
            if (duration*v_urb.FrameRate>tot_frames_urb)
                ME = MException('Rendomize:Duration', ...
                    'Duration %f is longer then the street video duration %f',duration,v_urb.Duration);
                throw(ME) 
            end
            
            % pick random start point for each  
            tot_frames_urb = tot_frames_gt;
            start_time_urb = rand*(v_urb.Duration-duration);
            
            % round start point to match a frame slack
            a = 0:0.04:v_urb.Duration;
            b = find(start_time_urb < a, 1);
            d = a(b) - start_time_urb;
            e = start_time_urb - a(b-1);
            if(d > e)
                start_time_urb = a(b-1);               
            else
                start_time_urb = a(b);
            end
                  
            v_urb.CurrentTime = start_time_urb;
            info_vid_drone{ii+1,2} = 'starting frame';
            info_vid_drone{ii+1,3} = find(a == start_time_urb);
            
            % write the urban video
            frame_count = 1;
            while (v_urb.hasFrame)
                if(frame_count > tot_frames_urb)
                    break; 
                end
                
                frame = imcrop(readFrame(v_urb), crop_region);
                writeVideo(selected_vid_urb,uint8(frame));

                % status bar
                prog      = frame_count/tot_frames_urb;
                prog_urbr = sprintf('cutting urban video \n passed:%4.0f from %4.0f',frame_count, tot_frames_urb);
                waitbar(prog,load_bar,prog_urbr);
                frame_count = frame_count+1;
            end           
            close(selected_vid_urb);
        end 
        
        % Total video creation time
        t=toc(start_t);
        m=floor(t/60);
        s=round(t-m*60);
        fprintf('Random video created. Total time: %2.0f:%2.0f \n',m,s);

        % close files
        close(selected_vid_drone{ii});
        close(selected_vid_gt{ii});
    end    
    save([direc, '\Randomizeinfo.mat'],'info_vid_drone')
    close(load_bar);
end


    
