%{
Description: find and complete segments of adjacent frames,
             in predefined LENGTH, that probably are misdetected segments.
             The script measures the distance of adjacent points of the
             drone to determent if they are close enough and if so it
             duplicates them.

Creators: Aviv Paskaro, Stav Yeger

Date: Dec-2019  
%}

function DuplicateFrame(file_name, LENGTH, DISTANCE)
    load_bar = waitbar(0,'Please wait...','Name','Duplicate Frame');
    fid        = fopen(['..\BgFiltered\', file_name]);
    rd_data    = fscanf(fid, '%d');
    len        = length(rd_data);
    mass_table = cat(2, rd_data(mod(1:len,2) == 1), rd_data(mod(1:len,2) == 0));
    
    % find segments to duplicate
    last_drone_frame = 1;
    misdetected      = [];    
    for curr_frame_num = 1:length(mass_table)
        % [-1, -1] sets new segment or ends segment
        if(~isequal(mass_table(curr_frame_num,:), [-1, -1]))
            % check if segment is in range
            if((curr_frame_num - last_drone_frame) <= LENGTH+1 && (curr_frame_num - last_drone_frame) > 1)  
                currXY = mass_table(curr_frame_num,:);
                prevXY = mass_table(last_drone_frame,:);
                X = [currXY;prevXY];
                % measure distance
                if(pdist(X,'euclidean') <= DISTANCE)
                    for jj = last_drone_frame+1 : curr_frame_num-1
                        misdetected = [misdetected, jj];
                    end
                end
            end
            last_drone_frame = curr_frame_num;
        end
    end
    
    fclose(fid);
    
    if (~exist('DuplicateFrame', 'dir'))
        mkdir('DuplicateFrame')
    end
    
    video_name = strsplit(file_name,{'.txt'});
    v_in = VideoReader(['..\BgFiltered\', video_name{1}, '.MP4']);
    v_out_name      = ['..\DuplicateFrame\',video_name{1}]; 
    v_out           = VideoWriter(v_out_name,'MPEG-4');
    v_out.FrameRate = v_in.FrameRate;
    zero_frame = zeros([v_in.Height, v_in.Width]);
    last_drone_frame = zero_frame;
    prev_drone_XYcenter = [-1 -1];
    open(v_out);
    
    % duplicate segments 
    start_t = tic;
    steps = length(mass_table);
    step = 1;
    while hasFrame(v_in)
        % filter frame from read noise
        frame = readFrame(v_in);
        frame = bwareafilt(frame(:,:,1)>40, 1);
        frame = bwpropfilt(frame,'Area',[250 1000000000]);
        
        % duplicate
        ind = find(misdetected == step, 1);
        if(~isempty(ind))
            frame = last_drone_frame;
            mass_table(step, :) = prev_drone_XYcenter; 
        else
            last_drone_frame = frame;
            prev_drone_XYcenter = mass_table(step,:);
        end
        
        % status bar
        t        = toc(start_t);
        rem_time = (t/step)*(steps-step);
        m        = floor(rem_time/60);
        s        = round(rem_time-m*60);
        prog_str = sprintf('Progress: %2.1f%%  Time Remain:%2.0f:%2.0f', double(step)/double(steps)*100, m, s);
        waitbar(double(step)/double(steps), load_bar, prog_str);   
       
        % writing
        writeVideo(v_out, uint8(255*frame)); 
        step = step + 1;
    end
    
    writematrix(mass_table, ['..\DuplicateFrame\' ,video_name{1}, '_dup.txt'], 'Delimiter', 'tab');   
    close(load_bar);
    close(v_out);  
end