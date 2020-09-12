%{
Description: applying augmentation variation on both drone video and its GT. 
             augmentation changes are of the following: 
             angle rotation, image scaling, image translation.

Creators: Aviv Paskaro, Stav Yeger

Date: Dec-2019  
%}

function [v_drone_out, v_gt_out] ...
        = Augment ...
        (v_drone_arr, v_gt_arr, v_indx, resolution, PID)
    
    load_bar    = waitbar(0,'Please wait...','Name','Creating Augment video');
    v_drone_out = cell(length(v_drone_arr),1);
    v_gt_out    = cell(length(v_gt_arr),1);
    info_vid_drone = cell(length(v_drone_arr),9);
    
    for ii = 1:length(v_drone_arr) 
        v_drone = VideoReader([v_drone_arr{ii}.Path, '\', v_drone_arr{ii}.Filename]);
        v_gt    = VideoReader([v_gt_arr{ii}.Path, '\', v_gt_arr{ii}.Filename]);
        info_vid_drone{ii,1} = num2str(ii);
        
        tot_frames = v_gt.Duration*v_gt.FrameRate;
        
        %angle uniform around 360
        angle = rand * 360;
        info_vid_drone{ii,2} = 'angle';
        info_vid_drone{ii,3} = angle;
        
        %scale uniform between [2/3, 3/2]
        scale = 2/3 + (5/6)*rand;
        info_vid_drone{ii,4} = 'scale';
        info_vid_drone{ii,5} = scale;
        
        %create random translate pair 
        x_trans     = -0.2*resolution(2) + 2*rand().*0.2*resolution(2);
        y_trans     = -0.2*resolution(1) + 2*rand().*0.2*resolution(1);
        translation = [x_trans y_trans];
        info_vid_drone{ii,6} = 'row translation';
        info_vid_drone{ii,7} = y_trans;
        info_vid_drone{ii,8} = 'col translation';
        info_vid_drone{ii,9} = x_trans;
        
        %writing
        direc                     = ['.\PID_', num2str(PID), '_iter_', num2str(v_indx)];
        v_drone_name              = [direc, '\augment_drone_', num2str(ii)];
        v_gt_name                 = [direc, '\augment_gt_', num2str(ii)];
        v_drone_out{ii}           = VideoWriter(v_drone_name,'MPEG-4'); %#ok<*TNMLP>
        v_gt_out{ii}              = VideoWriter(v_gt_name,'MPEG-4');
        v_drone_out{ii}.FrameRate = v_drone.FrameRate;
        v_gt_out{ii}.FrameRate    = v_drone.FrameRate;
        open(v_drone_out{ii});
        open(v_gt_out{ii});

        %calc top left corner of the croped 4k frame(for scaling)
        xy_resolution         = flip(resolution)-1;
        xy_resolution_scaled  = scale * xy_resolution;
        croped_frame_mid      = xy_resolution_scaled / 2;
        croped_frame_top_left = croped_frame_mid - (xy_resolution / 2);
        
        %apply features
        curr_frame = 0;
        start_t    = tic;
        while hasFrame(v_drone)
            frame1 = imresize(readFrame(v_drone),resolution); 
            frame2 = imresize(readFrame(v_gt),resolution);
            
            %rotation
            if(angle>0)
                frame1 = imrotate(frame1,angle, 'crop', 'bicubic');
                frame2 = imrotate(frame2,angle, 'crop', 'bicubic');
            end  
            
            %scaling
            if(scale>1)
                frame1 = imresize(frame1,scale); 
                frame2 = imresize(frame2,scale); 
                frame1 = imcrop(frame1, [croped_frame_top_left xy_resolution]);
                frame2 = imcrop(frame2, [croped_frame_top_left xy_resolution]);
            elseif(scale<1)
                frame1      = imresize(frame1,scale); 
                frame2      = imresize(frame2,scale);
                frame_size  = size(frame1(:,:,1));
                diff_res    = resolution - frame_size;
                diff_row    = diff_res(1);
                diff_col    = diff_res(2);
                frame1      = padarray(frame1,[diff_row diff_col],'post');
                frame2      = padarray(frame2,[diff_row diff_col],'post');
                frame1      = imresize(frame1,resolution); 
                frame2      = imresize(frame2,resolution); 
            end
            
            %translate
            frame1 = imtranslate(frame1, translation, 'FillValues', 0);
            frame2 = imtranslate(frame2, translation, 'FillValues', 0);
            
            writeVideo(v_drone_out{ii},frame1);
            writeVideo(v_gt_out{ii},frame2);

            % status bar
            prog=curr_frame/tot_frames;
            t=toc(start_t);
            rem_time=t/curr_frame*(tot_frames-curr_frame);
            m=floor(rem_time/60);
            s=round(rem_time-m*60);
            prog_str=sprintf('AUGMENTATION \n Progress: %2.1f%%    Time Remain: %2.0f:%2.0f \n passed %4.0f from %4.0f',prog*100,m,s,curr_frame, tot_frames);
            waitbar(prog,load_bar,prog_str);
            curr_frame = curr_frame + 1;

        end        
        t=toc(start_t);
        m=floor(t/60);
        s=round(t-m*60);
        fin_str=sprintf('Augment video created. Total time: %2.0f:%2.0f',m,s);
        disp(fin_str); %#ok<DSPS>

        close(v_drone_out{ii});    
        close(v_gt_out{ii}); 
    end  
    direc = ['PID_', num2str(PID), '_iter_', num2str(v_indx)];
    save([direc, '\AugmentInfo.mat'],'info_vid_drone')
    close(load_bar);
end