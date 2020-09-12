%{
Description: Create a new video by merging the drone video and urban video
             by the ground truth, and capture the last frame of the ground
             truth to picture   

Creators: Aviv Paskaro, Stav Yeger

Date: Dec-2019  
%}

function [v_out_merge, v_out_gt] ...
        = Merge ...
        (v_result, v_drone, v_urban, iter, write_resolution, PID)
    
   
load_bar = waitbar(0,'Please wait...','Name','Merging between drone video and objects video');
info_vid_drone = cell(length(v_drone), 5);

% alphablend parameters
alphablend_body_color         = vision.AlphaBlender('Operation','Blend');
alphablend_body_color.Opacity = 0.5;
% alphablend_propel_color       = vision.AlphaBlender('Operation','Blend');
% alphablend_propel_color.Opacity = 0.65; 
alphablend_bg1           = vision.AlphaBlender('Operation','Blend');
alphablend_bg1.Opacity   = 0.3;
alphablend_bg2           = vision.AlphaBlender('Operation','Blend');
alphablend_bg2.Opacity   = 0.15;

% rand color
drones_n = length(v_drone);
if (randsample('01',1,true,[0.5 0.5]) == num2str(1))
    color     = rand(1,drones_n,3);   
    colorflag = 1;
else
    colorflag=0;
end

v_urban = VideoReader([v_urban.Path, '\', v_urban.Filename]);

%check if DataSet exist
list = dir('DataSet*');
if isempty(list)
   direc = 'DataSet1';
   mkdir (direc)
   mkdir ([direc, '/Video'])
   mkdir ([direc, '/GT'])
   mkdir ([direc, '/Coordinates'])
   mkdir ([direc, '/Info'])
else
   list = sort({list.name});
   final = list(end);
   if(iter == 1)
       num = sscanf(final{:},'DataSet%d');
       direc = ['DataSet', num2str(num+1)];
       mkdir (direc)
       mkdir ([direc, '/Video'])
       mkdir ([direc, '/GT'])
       mkdir ([direc, '/Coordinates'])
       mkdir ([direc, '/Info'])
   else
       direc = final{:};
   end    
end

v_out_merge_name = [direc, '\Video\',num2str(iter)]; 
v_out_gt_name = [direc, '\GT\',num2str(iter)]; 
frame_gt       = cell(drones_n,1);
frame_drone    = cell(drones_n,1);
frame_ind_gt   = cell(drones_n,1);
for ii = 1:drones_n 
    v_drone{ii}  = VideoReader([v_drone{ii}.Path, '\', v_drone{ii}.Filename]);
    v_result{ii} = VideoReader([v_result{ii}.Path, '\', v_result{ii}.Filename]);
end 
tot_frames            = v_urban.Duration*v_urban.FrameRate;
c_mass_table          = zeros(uint16(tot_frames), uint8(2*drones_n));
v_out_merge           = VideoWriter(v_out_merge_name,'MPEG-4');
v_out_gt              = VideoWriter(v_out_gt_name,'MPEG-4');
v_out_merge.FrameRate = v_urban.FrameRate;
v_out_gt.FrameRate    = v_urban.FrameRate;
read_resolution       = [v_drone{1}.Height v_drone{1}.Width];
open(v_out_merge);
open(v_out_gt);

start_t    = tic;
curr_frame = 1;
while hasFrame(v_urban) % Main loop
    frame_urban = readFrame(v_urban);
    for ii = 1:drones_n
        frame_gt{ii}    = readFrame(v_result{ii});
        frame_drone{ii} = readFrame(v_drone{ii});
    end 
    
    frame_ind_gt_tot = cat(3,false(read_resolution),false(read_resolution),false(read_resolution));
    for ii = 1:drones_n
        % c_mass
        tmp              = bwareafilt(frame_gt{ii}(:,:,1)>40, 1);
        tmp              = bwpropfilt(tmp,'Area',[250 1000000000]);
        frame_ind_gt{ii} = cat(3,tmp,tmp,tmp);
        res_ratio = read_resolution ./ write_resolution;
        if(~isempty(find(tmp, 1))) 
            props  = regionprops(tmp, 'Centroid');
            c_mass = flip(props.Centroid) ./ res_ratio;
        else
            c_mass = [-1 -1];
        end
        
        c_mass_table(curr_frame, [ii ii+1]) = c_mass;
        frame_ind_gt_tot = frame_ind_gt_tot | frame_ind_gt{ii};

        % bounding box
        props = regionprops(frame_ind_gt{ii}(:,:,1) , 'BoundingBox');
        try
            numOfObj = size(props.BoundingBox);
        catch
            numOfObj = 0;
        end
        if (numOfObj>0)
            xMin = ceil(props.BoundingBox(1));
            xLen = props.BoundingBox(3);
            yMin = ceil(props.BoundingBox(2));
            yLen = props.BoundingBox(4);
            xMax = xMin + xLen - 1;
            yMax = yMin + yLen - 1;
            
            crop_vec = [xMin yMin xLen-1 yLen-1];
       
            patch_drone = imcrop(frame_drone{ii}, crop_vec);
            patch_urban = imcrop(frame_urban, crop_vec);
            patch_gt    = imcrop(frame_ind_gt{ii}(:,:,1), crop_vec);
                                          
            % gt c_mass 
            accum_row_dist = 0;
            accum_col_dist = 0;
            gt_size        = size(patch_gt); 
            for row = 1:gt_size(1)
                for col = 1:gt_size(2)
                    weight = patch_gt(row, col);
                    accum_row_dist = accum_row_dist + weight * row;
                    accum_col_dist = accum_col_dist + weight * col;
                end
            end 
            
            numel          = double(sum(sum(patch_gt == 1)));
            avg_row_c_mass = double(accum_row_dist) / numel;
            avg_col_c_mass = double(accum_col_dist) / numel;
            
            % find gt edge
            edge_gt_sobel = edge(patch_gt);
            
            % find avg dist of gt edge from gt c_mass
            accum_row_dist = 0;
            accum_col_dist = 0;
            for row = 1:gt_size(1)
                for col = 1:gt_size(2)
                    weight = edge_gt_sobel(row, col);
                    accum_row_dist = accum_row_dist + weight * abs(row-avg_row_c_mass);
                    accum_col_dist = accum_col_dist + weight * abs(col-avg_col_c_mass);
                end
            end 
            
            numel        = double(sum(sum(edge_gt_sobel == 1)));
            avg_row_dist = double(accum_row_dist) / numel;
            avg_col_dist = double(accum_col_dist) / numel;           
            avg_dist_from_c_mass = sqrt(avg_row_dist.^2 + avg_col_dist.^2);
            
            % ring blur mask
            outer_ring_blur_mask = zeros(size(patch_gt));
            inner_ring_blur_mask = zeros(size(patch_gt));
            no_blur_drone_mask = zeros(size(patch_gt));
            for row = 1:gt_size(1)
                for col = 1:gt_size(2)
                    if(patch_gt(row, col) == 0)
                        continue
                    end
                    
                    dist = pdist([row, col ; avg_row_c_mass, avg_col_c_mass],'euclidean');
                    if(dist > 0.7 * avg_dist_from_c_mass)
                        outer_ring_blur_mask(row, col) = 1;                       
                    elseif(dist <= 0.7 * avg_dist_from_c_mass && dist > 0.4 * avg_dist_from_c_mass)
                        inner_ring_blur_mask(row, col) = 1;                       
                    else
                        no_blur_drone_mask(row, col) = 1;
                    end
                end 
            end            

            urban_mask = 1 - patch_gt;

            %color change for drone patch
            if (colorflag)
                color_map   = ones(size(patch_drone)).*color(1,ii,:);
                info_vid_drone{ii,1} = num2str(ii);
                info_vid_drone{ii,2} = 'color';
                info_vid_drone{ii,3} = color(1,ii,1);
                info_vid_drone{ii,4} = color(1,ii,2);
                info_vid_drone{ii,5} = color(1,ii,3);                 
                patch_drone = alphablend_body_color(uint8(255*color_map), uint8(patch_drone));
            end
            
            % first drone
            if (ii==1) 
                % blend patch
                res = double(patch_drone).*double(no_blur_drone_mask) + ...
                    alphablend_bg1(double(patch_drone).*double(outer_ring_blur_mask), ...
                                   double(patch_urban).*double(outer_ring_blur_mask)) + ...
                    alphablend_bg2(double(patch_drone).*double(inner_ring_blur_mask), ...
                                   double(patch_urban).*double(inner_ring_blur_mask)) + ...
                    double(patch_urban).*double(urban_mask);
                
                % initiate merged frame with urban background
                merged_frame = frame_urban;
            else
                % crop drone Bounding Box patch 
                patch_diff_merged = imcrop(merged_frame, crop_vec);
                
                % blend patch
                res = double(patch_drone).*double(no_blur_drone_mask) + ...
                    alphablend_bg1(double(patch_drone).*double(outer_ring_blur_mask), ...
                                   double(patch_diff_merged).*double(outer_ring_blur_mask)) + ...
                    alphablend_bg2(double(patch_drone).*double(inner_ring_blur_mask), ...
                                   double(patch_diff_merged).*double(inner_ring_blur_mask)) + ...
                    double(patch_diff_merged).*double(urban_mask);
            end
           
            % merge the blend
            merged_frame(yMin:yMax, xMin:xMax, :) = res; 

        else % nO Obj           
            if (ii==1)
                merged_frame = frame_urban;
            end     
        end
    end 
    
    merged_frame    = imresize(merged_frame, write_resolution, 'AntiAliasing', true);
    merged_gt_frame = imresize(frame_ind_gt_tot, write_resolution, 'AntiAliasing', true);
    writeVideo(v_out_merge, uint8(merged_frame));
    writeVideo(v_out_gt, uint8(255*double(merged_gt_frame)));
    
    % status bar 
    curr_frame=curr_frame+1;
    prog=curr_frame/tot_frames;
    t=toc(start_t);
    rem_time=t/curr_frame*(tot_frames-curr_frame);
    m=floor(rem_time/60);
    s=round(rem_time-m*60);
    prog_str=sprintf('MERGING \n Progress: %2.1f%%  Time Remain: %2.0f:%2.0f \n passed %4.0f from %4.0f',prog*100,m,s,curr_frame, tot_frames);
    waitbar(prog,load_bar,prog_str);
end

% Total video creation time
t=toc(start_t);
m=floor(t/60);
s=round(t-m*60);
fprintf('Merged video created. Total time: %2.0f:%2.0f \n',m,s);

writematrix(c_mass_table, [direc, '\Coordinates\', num2str(iter), '.txt'], 'Delimiter', 'tab')
direc1 = ['PID_', num2str(PID), '_iter_', num2str(iter)];
Randomizeinfo = load([direc1, '\Randomizeinfo.mat']).info_vid_drone;
AugmentInfo   = load([direc1, '\AugmentInfo.mat']).info_vid_drone;
MergeInfo     = info_vid_drone;
writecell(Randomizeinfo,[direc, '\Info\', num2str(iter), '_Random.dat'])
writecell(AugmentInfo,[direc, '\Info\', num2str(iter), '_Augment.dat'])
writecell(MergeInfo,[direc, '\Info\', num2str(iter), '_Merge.dat'])

close(v_out_merge);
close(v_out_gt);
close(load_bar);
end