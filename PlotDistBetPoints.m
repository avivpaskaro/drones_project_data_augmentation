%{
Description: Calculating the distance each adjacent points of the drone in the area.
             Creating plot of the distance as function of frame number.

Creators: Aviv Paskaro, Stav Yeger

Date: Dec-2019  
%}

function PlotDistBetPoints(directory)
    
    files = dir(directory);
    for ii = 3:length(files)
        Y = []; 
        prevXY = [-1, -1];
        drone_video_name = files(ii).name;
        [~, ~, fExt] = fileparts(drone_video_name);
        if (lower(fExt) == ".txt")
            fid = fopen(['.\NoiseRemoved\', drone_video_name]);
            rd_data = fscanf(fid, '%d');
            len = length(rd_data);
            mass_table = cat(2, rd_data(mod(1:len,2) == 1), rd_data(mod(1:len,2) == 0));

            for curr_line_num = 1:length(mass_table)  
                currXY = mass_table(curr_line_num,:);
                X = [currXY ; prevXY];
                Y = [Y, pdist(X,'euclidean')];
                prevXY = currXY;
                if(Y(curr_line_num) > 100)
                    fprintf('distance is bigger than 100 at frame number %d \n', curr_line_num)
                end
            end

            figure();
            plot(Y)
            title([drone_video_name, '  disatance of adjacent points'], 'interpreter', 'none')
            xlabel('frame');
            ylabel('distance');
            savefig(['.\NoiseRemoved\', drone_video_name, '.fig'])
        end
    end
end