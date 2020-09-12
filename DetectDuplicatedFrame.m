%{
Description: find the differences between the two center of mass file -
             <video_name>.txt and <video_name>_filt.txt.
             summarize those differences in array which will be used by 
             Randomize to copy for the missed frames the right frame that
             they were duplicated from.

Creators: Aviv Paskaro, Stav Yeger

Date: Dec-2019  
%}

function DetectDuplicatedFrame
    files = dir('.\NoiseRemoved\');
    for ii = 3:length(files)
        Y = []; 
        [~, ~, fExt] = fileparts(files(ii).name);
        if(lower(fExt) == ".mp4")
            file_name = strsplit(files(ii).name, {'.mp4'});
            fid = fopen(['.\BgFiltered\', file_name{1}, '.txt']);
            rd_data = fscanf(fid, '%d');
            len = length(rd_data);
            mass_table1 = cat(2, rd_data(mod(1:len,2) == 1), rd_data(mod(1:len,2) == 0));

            fid = fopen(['.\NoiseRemoved\', file_name{1}, '_filt.txt']);
            rd_data = fscanf(fid, '%d');
            len = length(rd_data);
            mass_table2 = cat(2, rd_data(mod(1:len,2) == 1), rd_data(mod(1:len,2) == 0));

            for curr_line_num = 1:length(mass_table1)
                if(isequal(mass_table1(curr_line_num,:), mass_table2(curr_line_num,:)) || ...
                   isequal(mass_table2(curr_line_num,:),[-1, -1]))
                    Y = [Y, 0];
                else
                    Y = [Y, 1];
                end
            end

            save(['.\NoiseRemoved\', file_name{1}, '.mat'], 'Y')
        end
    end
end