% Copyright 2011 Zdenek Kalal
% This file is part of TLD.

function [BB Conf tld] = tldDetection(tld,I)
    % scanns the image(I) with a sliding window, returns a list of bounding
    % boxes and their confidences that match the object description

    BB        = [];
    Conf      = [];
    dt        = struct('bb',[],'idx',[],'conf1',[],'isin',nan(3,1),'patch',[]);

    img  = tld.img{I};

    tld.tmp.conf = [];
    idx_dt = [];
   
    % ------------------ (BEGIN) ---------------------
    % TODO: Run the detection model on the image patches
    % to identify potential object boxes.
    % 
    % given
    %------
    % tld.img{I} - current image
    % tld.bb(:,1:I-1) - all boxes till now
    % tld.grid(1:4, :) - The set of all bounding boxes to score from the image
    % tld.model.patchsize - Each of the patches corresponding to the grid boxes
    %                       could be resized to this cannonical size before
    %                       feature extraction.
    % tld.detection_model - The detection you have learned from tldLearning.m

    % output
    % ------
    % tld.tmp.conf - size(1, size(tld.grid,2)) a vector of scores for all patches in grid
    % idx_dt - the indices of selected boxes from tld.grid based on detection scores. 
    %          tld.grid(1:4, idx_dt) provides the seltected object boxes based on the detector.
    % HINT: bb_overlap in bbox/ might be a useful code to prune the grid boxes before
    % running your detector. This is just a speed-up and might hurt performance.
  
    % Fahim code
    %{
    %tic
    patch_variances = zeros(1, size(tld.grid, 2));
    patches = cell(1, size(tld.grid, 2));
    idx_dt = 1:size(tld.grid, 2);
    for i=1:size(tld.grid, 2)
        patches{i} = img_patch(img.input,tld.grid(1:4, i));
        this_patch = patches{i};
        patch_variances(i) = var(double(this_patch(:)));
    end

    idx_dt = idx_dt(patch_variances > (tld.var/2));
    stage1_bboxes = tld.grid(1:4, patch_variances > (tld.var/2));
    patches = patches(patch_variances > (tld.var/2));
    %toc
    %fprintf('-------------------------\n');
    disp(['Number of Original Bboxes : ' num2str(size(tld.grid, 2))]);
    %disp(['Number of Bboxes after Stage 1 : ' num2str(size(stage1_bboxes, 2))]);
    disp(['Number of Binary Bboxes after Stage 1 : ' num2str(length(idx_dt))]);
    %disp(['Idx_dt after stage 1 : ' num2str(length(idx_dt))]);

    % TODO: possible optimization - store patches and index into them
    % instead of recomputing them
    X = zeros(tld.pattern_size, size(stage1_bboxes, 2));
    %tic
    for i=1:size(stage1_bboxes, 2)
        this_patch = patches{i};
        X(:, i) = tldPatch2Pattern(this_patch, tld.model.patchsize);
    end
    y_hat = predict(tld.detection_model, X');
    stage2_bboxes = stage1_bboxes(:, y_hat==1);
    idx_dt = idx_dt(y_hat==1);
    %toc
    %fprintf('-------------------------\n');
    %disp(['Number of Bboxes after Stage 2 : ' num2str(size(stage2_bboxes, 2))]);
    disp(['Number of Binary Bboxes after Stage 2 : ' num2str(length(idx_dt))]);
    %disp(['Idx_dt after stage 2 : ' num2str(length(idx_dt))]);
    
    % Stage 3
    %tic
    X = X(:, y_hat==1);
    [conf_nn, isin] = tldNN(X, tld);
    stage3_bboxes = stage2_bboxes(:, isin(1, conf_nn > tld.model.nn_patch_confidence) == 1);
    unique(isin(2,:))
    pause
    idx_dt = idx_dt(isin(1, conf_nn > tld.model.nn_patch_confidence) == 1);

    % TODO: Albert- I THINK THERE IS A BUG HERE: Make sure idx_dt at this point
    % actually corresponds to indices in the full 32K bboxes. My
    % preliminary investigations (wednesday) tell me that tldNN's isin's
    % 2nd row indexes into the pex array and not the actual index of the
    % bbox. If you look in tldNN, we compute the max pex value, find the
    % index of that, then assign it to isin(2,i) which is always between
    % one and length(pex). It should be between one and ~32K?
    
    %toc
    %fprintf('-------------------------\n');
    %disp(['Number of Bboxes after Stage 3 : ' num2str(size(stage3_bboxes, 2))]);
    disp(['Number of Binary Bboxes after Stage 3 : ' num2str(length(idx_dt))]);
    %disp(['Idx_dt after stage 3 : ' num2str(length(idx_dt))]);
    %}
    
    fprintf('---------------------------------\n');
    fprintf('Frame: %i\n', I);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % STAGE 1: VARIANCE THRESHOLD
    tic
    idx_dt = 1:size(tld.grid, 2);
    fprintf('Stage 0: %i\n', length(idx_dt));
    patch_variances = zeros(1, size(tld.grid, 2));
    
    % Get the actual patches
    patches = cell(1, size(tld.grid, 2));
    for i=1:size(tld.grid, 2)
        patches{i} = img_patch(img.input,tld.grid(1:4, i));
        this_patch = patches{i};
        patch_variances(i) = var(double(this_patch(:)));
    end
    
    % Filter based on variance
    idx_dt = find(patch_variances > (tld.var/2));
    stage1_bboxes = tld.grid(1:4, idx_dt);
    patches = patches(idx_dt);
    fprintf('Stage 1: %i\t', length(idx_dt));
    toc
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % STAGE 2: SVM CLASSIFIER
    tic
    % Create the feature vectors
    X = zeros(tld.pattern_size, size(stage1_bboxes, 2));
    for i=1:size(stage1_bboxes, 2)
        X(:, i) = tldPatch2Pattern(patches{i}, tld.model.patchsize);
    end
    % Run the SVM
    y_hat = predict(tld.detection_model, X');
    % Get the positive candidates
    idx_dt = idx_dt(y_hat==1);
    stage2_bboxes = tld.grid(:, idx_dt);
    fprintf('Stage 2: %i\t', length(idx_dt));
    toc
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % STAGE 3: NEAREST NEIGHBOR
    % AS OF THURSDAY 4 AM, COMMENTING THIS OUT DOES OKAY... (albert)
    tic
    % Recompose the feature vectors
    %X = X(:, y_hat==1);
    %[conf_nn, isin] = tldNN(X, tld);
    %stage3_bboxes = stage2_bboxes(:, isin(1, conf_nn > tld.model.nn_patch_confidence) == 1);
    % MAKE SURE TO GET THE INDEXING CORRECT
    %idx_dt = idx_dt(isin(1, conf_nn > tld.model.nn_patch_confidence) == 1);
    
    fprintf('Stage 3: %i\t', length(idx_dt));
    toc
    % ------------------ (END) -----------------------



    num_dt = length(idx_dt); % get the number detected bounding boxes so-far 
    if num_dt == 0, tld.dt{I} = dt; return; end % if nothing detected, return


    % initialize detection structure
    dt.bb     = tld.grid(1:4,idx_dt); % bounding boxes
    dt.idx    = idx_dt; %find(idx_dt); % indexes of detected bounding boxes within the scanning grid
    dt.conf1  = nan(1,num_dt); % Relative Similarity (for final nearest neighbour classifier)
    dt.isin   = nan(3,num_dt); % detected (isin=1) or rejected (isin=0) by nearest neighbour classifier
    dt.patch  = nan(prod(tld.model.patchsize),num_dt); % Corresopnding patches

    for i = 1:num_dt % for every remaining detection

        ex   = tldGetPattern(img,dt.bb(:,i),tld.model.patchsize,0,tld.model.pattern_size); % measure patch
        [conf1, isin] = tldNN(ex,tld); % evaluate nearest neighbour classifier

        % fill detection structure
        dt.conf1(i)   = conf1;
        dt.isin(:,i)  = isin;
        dt.patch(:,i) = ex;

    end

    idx = dt.conf1 > tld.model.thr_nn; % get all indexes that made it through the nearest neighbour

    if numel(idx) > 10
      [~, sort_idx] = sort(dt.conf1, 'descend');
      idx = false(size(dt.conf1));
      idx(sort_idx(1:10)) = true;
    end

    if ~any(idx)
      if (I <=2)
        [~, idx] = max(dt.conf1);
      else
        fprintf('Max confidence: %f, Could not find any detection (skipping) \n', max(dt.conf1));
      end
    end

    %fprintf('IN detection ... \n'); keyboard;

    % output
    BB    = dt.bb(:,idx); % bounding boxes
    Conf  = dt.conf1(:,idx); % conservative confidences
    tld.dt{I} = dt; % save the whole detection structure

end