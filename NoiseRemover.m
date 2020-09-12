%{
Description: find and erase segments of adjacent frames,
             in predefined LENGTH, that probably are noise segments.

Creators: Aviv Paskaro, Stav Yeger

Date: Dec-2019  
%}

function NoiseRemover(file_name, LENGTH)

    load_bar  = waitbar(0,'Please wait...','Name','Noise Remover');
    file_name = strsplit(file_name, {'.txt'});
    fid = fopen(['..\DuplicateFrame\', file_name{1}, '_dup.txt']);
    rd_data = fscanf(fid, '%d');
    len = length(rd_data);
    mass_table = cat(2, rd_data(mod(1:len,2) == 1), rd_data(mod(1:len,2) == 0));
    
    % find segments to erase
    last_noise_frame_num = 1;
    noise = [];    
    for curr_frame_num = 1:length(mass_table) 
        % [-1, -1] sets new segment or ends segment 
        if(isequal(mass_table(curr_frame_num,:), [-1, -1]))
            % check if segment is in range
            if(((curr_frame_num - last_noise_frame_num) <= LENGTH + 1) && ((curr_frame_num - last_noise_frame_num) > 1))
                for jj = last_noise_frame_num + 1 : curr_frame_num - 1
                    noise = [noise, jj];
                end
            end
            % updates last [-1, -1] frame
            last_noise_frame_num = curr_frame_num;
        end
    end
    
    fclose(fid);
    
    if ~exist('NoiseRemoved', 'dir')
       mkdir('NoiseRemoved');
    end    
    video_name = file_name;
    v_in = VideoReader(['..\DuplicateFrame\', video_name{1}, '.MP4']);
    v_out_name      = ['..\NoiseRemoved\', video_name{1}]; 
    v_out           = VideoWriter(v_out_name, 'MPEG-4');
    v_out.FrameRate = v_in.FrameRate;
    zero_frame = zeros([v_in.Height, v_in.Width]);
    open(v_out);
    
    % erase segments 
    start_t = tic;
    steps = length(mass_table);
    step = 1;
    while hasFrame(v_in)
        % filter frame from read noise
        frame = readFrame(v_in);
        frame = bwareafilt(frame(:,:,1)>40, 1);
        frame = bwpropfilt(frame,'Area',[250 1000000000]);
        
        % erase
        ind = find(noise == step, 1);
        if(~isempty(ind))
           frame = zero_frame;
           mass_table(step, :) = [-1 -1]; 
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
    
    writematrix(mass_table, ['..\NoiseRemoved\' ,video_name{1}, '_filt.txt'], 'Delimiter', 'tab');   
    close(load_bar);
    close(v_out);  
end