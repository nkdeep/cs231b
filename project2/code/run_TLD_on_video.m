% Copyright 2011 Zdenek Kalal
% This file is part of TLD.

function run_TLD_on_video(options, video_image_directory, output_directory, ground_truth_file, num_frames_to_track)

    addpath(genpath('.')); init_workspace; 

    opt.source          = struct('camera',0,'input', video_image_directory,'bb0',[]); % camera/directory swith, directory_name, initial_bounding_box (if empty, it will be selected by the user)
    opt.output          = output_directory;

    mkdir(opt.output); % output directory that will contain bounding boxes + confidence


    % ------------------------------- BEGIN ---------------------------------------
    % TODO: change parameters to get best performance


    min_win             = 25; % minimal size of the object's bounding box in the scanning grid, it may significantly influence speed of TLD, set it to minimal size of the object
    patchsize           = [25 25]; % size of normalized patch in the object detector, larger sizes increase discriminability, must be square
    fliplr              = 0; % if set to one, the model automatically learns mirrored versions of the object (data augmentation)
    maxbbox             = 1; % fraction of evaluated bounding boxes in every frame, maxbox = 0 means detector is truned off, if you don't care about speed set it to 1
    update_detector     = 1; % learning on/off, of 0 detector is trained only in the first frame and then remains fixed


    opt.model           = struct('min_win',min_win, ...
                                'patchsize',patchsize, ...
                                'fliplr',fliplr, ...
                                'ncc_thesame',0.9, ...
                                'valid',0.5,...
                                'thr_nn',0.5,...
                                'thr_nn_valid',0.7, ...
                                'nn_patch_confidence', 0.60);
                                
                            
    % Add suitable parameters according to your choice of learning/detection algorithm.
    opt.detection_model_params = struct( ...
        'bbox_size_delta', 20, ... % Bbox for frame t must be +/- bbox_delta of bbox for frame t-1 (this is in pixels)
        'bbox_loc_delta', 30, ... % If new bbox is more than bbox_loc_delta pixels away from last bbox center  (in pixels)
        'feature', options.feature, ... % 'cnn' 'raw' 'hog'
        'learning_model', options.classifier, ... % 'svm' 'adaboost'
        'max_history_size', 1000 ); % How many examples to keep in NN
    
    fprintf('Running with the following settings:\n');
    fprintf('\tVideo Sequence: %s\n', options.video_name);
    fprintf('\tNum Frames to Track: %s\n', options.num_frames_to_track);
    fprintf('\tFeature: %s\n', options.feature);
    fprintf('\tLearning Model: %s\n', options.classifier);

    % Below, you should set some parameters for positive and negative gneration. These will be passed to
    % the positive and negative generation code. We provide some sample parameters like
    % number of warps on positive box, possible noise to be added, rotation of positive, shifting etc.
    % In gneral, this is data augmentation which will be really useful when training with limited examples.

    opt.p_par_init      = struct('num_closest',10,'num_warps',20,'noise',5,'angle',30,'shift',0.03,'scale',0.1,'always_keep',200); % synthesis of positive examples during initialization
    opt.p_par_update    = struct('num_closest',10,'num_warps',10,'noise',5,'angle',20,'shift',0.03,'scale',0.1); % synthesis of positive examples during update
    opt.n_par           = struct('overlap',0.2,'num_patches',200); % negative examples initialization/update
    % ------------------------------- END ---------------------------------------


    % -------------------- BEGIN ------------------
    % TODO: Fillin the pattern size. This is the dimension of the feature
    %       extracted from patches for detection and learning. For instance,
    %       if the feature is simply a resized version of the patch, then
    %       feature dimension would be prod(opt.patchsize). But, try other features
    %       for better performance.
    opt.pattern_size = prod(opt.model.patchsize);
    % ------------------- END ---------------------

    % Do not change ---------
    opt.control         = struct('maxbbox',maxbbox,'update_detector',update_detector,'drop_img',1,'repeat',1);
    % -----------------------

    % Do not change LK tracker --------
    opt.tracker         = struct('occlusion',10);
    % -----------------------------

    % --- Change for more plot options ----
    opt.plot            = struct('pex',0,'nex',0,'dt',1,'confidence',1,'target',0,'replace',0,'drawoutput',3,'draw',0,'pts',1,'help', 0,'patch_rescale',1,'save',1); 
    % ------------------


    % Run TLD -----------------------------------------------------------------
    [bb,conf] = tldExample(opt, num_frames_to_track);

    % Save results ------------------------------------------------------------
    dlmwrite([opt.output '/tld.txt'],[bb; conf]');
    fprintf('Results saved to %s\n', output_directory);

end