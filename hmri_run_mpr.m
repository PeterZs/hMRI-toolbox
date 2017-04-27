function out = hmri_run_mpr(job)
%==========================================================================
% PURPOSE
% Calculation of multiparameter maps using B1 maps for B1 bias correction.
% If no B1 maps available, one can choose not to correct for B1 bias or
% apply UNICORT.
%==========================================================================
job = hmri_process_data_spec(job);

out.R1 = {};
out.R2s = {};
out.A = {};
out.MT = {};
out.T1w = {};

% loop over subjects in the main function, calling the local function for
% each subject:
for in=1:numel(job.subj)
    local_job.subj = job.subj(in);
    out_temp       = hmri_mpr_local(local_job);
    out.subj(in)   = out_temp.subj(1);
    out.R1{end+1}  = out.subj(in).R1{1};
    out.R2s{end+1} = out.subj(in).R2s{1};
    out.MT{end+1}  = out.subj(in).MT{1};
    out.A{end+1}   = out.subj(in).A{1};
    out.T1w{end+1} = out.subj(in).T1w{1};
end
end

%% =======================================================================%
% LOCAL SUBFUNCTION (PROCESSING FOR ONE SUBJET)
%=========================================================================%
function out_loc = hmri_mpr_local(job)

% determine output directory path
try 
    outpath = job.subj.output.outdir{1}; % case outdir
catch 
    Pin = char(job.subj.raw_mpm.MT);
    outpath = fileparts(Pin(1,:)); % case indir
end
% save outpath as default for this job
hmri_get_defaults('outdir',outpath);

% define a directory for final results
respath = fullfile(outpath, 'Results');
if ~exist(respath,'dir'); mkdir(respath); end

% define other (temporary) paths for processing data
b1path = fullfile(outpath, 'B1mapCalc');
if ~exist(b1path,'dir'); mkdir(b1path); end
rfsenspath = fullfile(outpath, 'RFsensCalc');
if ~exist(rfsenspath,'dir'); mkdir(rfsenspath); end
mpmpath = fullfile(outpath, 'MPMCalc');
if ~exist(mpmpath,'dir'); mkdir(mpmpath); end

% save all these paths in the job.subj structure
job.subj.path.b1path = b1path;
job.subj.path.rfsenspath = rfsenspath;
job.subj.path.mpmpath = mpmpath;
job.subj.path.respath = respath;

% run B1 map calculation for B1 bias correction
P_trans = hmri_run_b1map(job.subj);

% check, if RF sensitivity profile was acquired and do the recalculation
% accordingly
if ~isfield(job.subj.sensitivity,'RF_none')
  job.subj = hmri_RFsens(job.subj);
end

P_receiv = [];

% run hmri_MTProt to evaluate the parameter maps
[fR1, fR2s, fMT, fA, PPDw, PT1w]  = hmri_MTProt(job.subj, P_trans, P_receiv);

% apply UNICORT if required, and collect outputs:
if strcmp(job.subj.b1_type,'UNICORT')
    out_unicort = hmri_run_unicort(PPDw, fR1);
    out_loc.subj.R1  = {fullfile(respath,spm_file(out_unicort.R1u,'filename'))};
else
    out_loc.subj.R1  = {fullfile(respath,spm_file(fR1,'filename'))};
end
out_loc.subj.R2s = {fullfile(respath,spm_file(fR2s,'filename'))};
out_loc.subj.MT  = {fullfile(respath,spm_file(fMT,'filename'))};
out_loc.subj.A   = {fullfile(respath,spm_file(fA,'filename'))};
out_loc.subj.T1w = {fullfile(respath,spm_file(PT1w,'filename'))};

% copy final result files into Results directory
f = fieldnames(out_loc.subj);
for i=1:length(f)
    fnam = out_loc.subj.(f{cfi}){1};
    copyfile(fullfile(mpmpath, spm_file(fnam, 'filename')), fnam);
end

% save processing params (hmri defaults) and job for the current subject:
hmri_def = hmri_get_defaults; %#ok<NASGU>
P_mtw    = char(jobsubj.raw_mpm.MT);
save(fullfile(respath, [spm_file(P_mtw(1,:),'basename') '_create_maps_hmridef.mat']),'hmri_def');
save(fullfile(respath, [spm_file(P_mtw(1,:),'basename') '_create_maps_job.mat']),'job');

% clean after if required
if hmri_get_defaults('cleanup')
    rmdir(job.subj.path.b1path,'s');
    rmdir(job.subj.path.rfsenspath,'s');
    rmdir(job.subj.path.mpmpath,'s');
end

f = fopen(fullfile(outpath, '_finished_'), 'wb');
fclose(f);

end