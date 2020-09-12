%{
Description: Manual frames deleter. Input is gt video and frame range to
             delete.

Creators: Aviv Paskaro, Stav Yeger

Date: Dec-2019  
%}

while(true)
    x = input('Enter video number: ', 's');
    y = input('Enter a / b / c / d: ', 's');     
    if(exist(['..\NoiseRemoved\gt_Scene',x , '_', y, '_filt.txt'], 'file')) 
        break;
    end
end

delete_traget = input('Set delete traget array here as [s1:e1, s2:e2, s3:e3, exc...]: ');

if ~exist('.\ManualDeleted', 'dir')
   mkdir('.\ManualDeleted');
end
v_in = VideoReader(['.\NoiseRemoved\gt_Scene', x, '_', y, '.mp4']);
v_out_name      = ['.\ManualDeleted\gt_Scene', x, '_', y, '.mp4']; 
v_out           = VideoWriter(v_out_name, 'MPEG-4');
v_out.FrameRate = v_in.FrameRate;
zero_frame = zeros([v_in.Height, v_in.Width]);
open(v_out);
fid = fopen(['.\NoiseRemoved\gt_Scene', x, '_', y, '_filt.txt']);
rd_data = fscanf(fid, '%d');
len = length(rd_data);
mass_table = cat(2, rd_data(mod(1:len,2) == 1), rd_data(mod(1:len,2) == 0));
load_bar  = waitbar(0,'Please wait...','Name','Noise Remover');

start_t = tic;
steps = length(mass_table);
step = 1;
while hasFrame(v_in)
    % filter frame from read noise
    frame = readFrame(v_in);    
    frame = bwareafilt(frame(:,:,1)>40, 1);
    frame = bwpropfilt(frame,'Area',[250 1000000000]);
 
    % delete
    ind = find(delete_traget == step, 1);
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

writematrix(mass_table, ['.\ManualDeleted\gt_Scene', x, '_', y, '_filt.txt'], 'Delimiter', 'tab'); 
close(load_bar);
close(v_out);  
