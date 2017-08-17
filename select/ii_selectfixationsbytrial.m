function [ ii_data, ii_cfg ] = ii_selectfixationsbytrial( ii_data, ii_cfg, epoch_chan, within_epochs, sel_mode )
%II_SELECTFIXATIONSBYTRIAL Selects those fixations within given epochs for
%each trial using one of several modes ('first', 'last', 'begin', 'all'). 
%   Used to select periods to 'calibrate' to for drift correction and
%   single-trial 'calibration'
%
%   for FIRST: select the first fixation that begins AFTER beginning of
%   epoch (and can continue past end)
%   for LAST:  select the last fixation that begins before END of epoch
%   for BEGIN: select the fixation from beginning of epoch to first new
%   fixation
%   for ALL:   select all fixations that begin during the epoch
%
% Tommy Sprague, 8/16/2017


if nargin < 3 || isempty(epoch_chan)
     epoch_chan = 'XDAT';
end

% make sure channel exists...
if ~ismember(epoch_chan,fieldnames(ii_data))
    error('iEye:ii_selectfixationsbytrial:invalidEpochChannel', 'Channel %s not found',epoch_chan);
end


% check sel_mode is one of 'last','first','all'
if ~ismember(sel_mode,{'last','first','begin','all'})
    error('iEye:ii_selectfixationsbytrial:invalidSelectionMode', 'Selection mode %s invalid: use one of first, last, begin, all',sel_mode);
end

% make sure fixations have been computed
if ~ismember(fieldnames(ii_cfg),'fixations')
    error('iEye:ii_selectfixationsbytrial:missingFixations', 'Fixations not computed - run ii_findfixations prior to selecting fixations');
end

% and make sure trials have been defined
if ~ismember(fieldnames(ii_cfg),'trialvec')
    error('iEye:ii_selectfixationsbytrial:trialsNotDefined', 'Trials not defined - run ii_definetrials prior to selecting fixations per trial');
end

% clear selections
[ii_data,ii_cfg] = ii_selectempty(ii_data,ii_cfg);

% make new selections
tu = unique(ii_cfg.trialvec(ii_cfg.trialvec~=0));

new_sel = ii_cfg.sel*0;

% TODO: epoch chan?
epoch_idx = ismember(ii_data.(epoch_chan),within_epochs);

% if necessary, create a vector of fixations - this will be useful for the
% 'all' mode, we can just AND this with epoch_idx and trial_idx and
% update_cursel
if strcmpi(sel_mode,'all')
    all_fixvec = 0*ii_cfg.sel;
    for ff = 1:size(ii_cfg.fixations)
        all_fixvec(ii_cfg.fixations(ff,1):ii_cfg.fixations(ff,2))=1;
    end
end



for tt = 1:length(tu)
    
    trial_idx = ii_cfg.trialvec==tu(tt);
    
    % if method is last_fixation, find within this trial, within
    % [correct_to_epochs], start of last fixation, select from there to end
    % of last correct_to_epoch.
    
    if strcmpi(sel_mode,'last') % used for drift correction, calibration
        
        
        
        % quick check to make sure just one contiguous selection...
        if sum(diff(trial_idx & epoch_idx)==1) ~= 1 || sum(diff(trial_idx & epoch_idx)==-1) ~= 1
            error('iEye:ii_selectfixationsbytrial:nonContiguousEpoch', 'On trial %i, epochs non-contiguous',tu(tt));
        end
        
        epoch_begin = find(diff(trial_idx & epoch_idx)==1);
        epoch_end = find(diff(trial_idx & epoch_idx)==-1);
        last_fix_ind = find(ii_cfg.fixations(:,1)<epoch_end,1,'last');
        
        last_fix_vec = zeros(size(new_sel));
        last_fix_vec(max(ii_cfg.fixations(last_fix_ind,1),epoch_begin):epoch_end)=1;
        
        new_sel = new_sel|(last_fix_vec==1);
        
        clear last_fix_vec epoch_begin epoch_end last_fix_ind trial_idx;
        
        
    elseif strcmpi(sel_mode,'first')
        
        
        % quick check to make sure just one contiguous selection...
        if sum(diff(trial_idx & epoch_idx)==1) ~= 1 || sum(diff(trial_idx & epoch_idx)==-1) ~= 1
            error('iEye:ii_selectfixationsbytrial:nonContiguousEpoch', 'On trial %i, epochs non-contiguous',tu(tt));
        end
        
        epoch_begin = find(diff(trial_idx & epoch_idx)==1);
        epoch_end = find(diff(trial_idx & epoch_idx)==-1);

        first_fix_ind = find(ii_cfg.fixations(:,1)>epoch_begin,1,'first');
        
        % select from beginning of this fixation to end of epoch or end of
        % that fixation, whichever is sooner
        first_fix_vec = zeros(size(new_sel));
        first_fix_vec(ii_cfg.fixations(first_fix_ind,1):min(epoch_end,ii_cfg.fixations(first_fix_ind,2)))=1;
        
        new_sel = new_sel|(first_fix_vec==1);
        
        clear first_fix_vec epoch_begin epoch_end first_fix_ind trial_idx;
        
        
        
    elseif strcmpi(sel_mode,'begin')
        % from beginning of epoch to end of that fixation 
        
        
        % quick check to make sure just one contiguous selection...
        if sum(diff(trial_idx & epoch_idx)==1) ~= 1 || sum(diff(trial_idx & epoch_idx)==-1) ~= 1
            error('iEye:ii_selectfixationsbytrial:nonContiguousEpoch', 'On trial %i, epochs non-contiguous',tu(tt));
        end
        
        epoch_begin = find(diff(trial_idx & epoch_idx)==1);
        epoch_end = find(diff(trial_idx & epoch_idx)==-1);

        first_fix_ind = find(ii_cfg.fixations(:,1)>epoch_begin,1,'first');
        
        first_fix_vec = zeros(size(new_sel));
        first_fix_vec(epoch_begin:min(ii_cfg.fixations(first_fix_ind,1)-1,epoch_end))=1;
        
        new_sel = new_sel|(first_fix_vec==1);
        
        clear first_fix_vec epoch_begin epoch_end first_fix_ind trial_idx;
        
        
        
        
        
    elseif strcmpi(correct_mode,'all') % used for ??? (maybe multiple saccades?)
        
        % find all fixations that occur within interval 
        
        new_sel = epoch_idx==1 & trial_idx==1 & all_fixvec==1;
        
        
    end
    
end

% update cursel field of ii_cfg to match new selections
ii_cfg.sel = new_sel;
ii_cfg = ii_updatecursel(ii_cfg);


% ordinarily wouldn't put this in history, but because it's used for things
% like drift correction, etc, makes sense here
ii_cfg.history{end+1} = sprintf('ii_selectfixationsbytrial - selected epochs %s from chan %s with mode %s - %s',num2str(within_epochs),epoch_chan,sel_mode,datestr(now,30));



end
