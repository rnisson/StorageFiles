%% image_generator.m
% Rotate a spacecraft through orientations and render edge-mode images
% for AI training data generation.
%
% Based on easir_example.m / easir_example2.m.

%% --- Setup ---
repo_root   = fullfile(fileparts(mfilename('fullpath')), '..');
config_path = fullfile(repo_root, 'configs', 'default_config.json');
state_path  = fullfile(repo_root, 'configs', 'default_state.json');
out_dir     = fullfile(repo_root, 'training_images');
if ~exist(out_dir, 'dir'); mkdir(out_dir); end

%% --- Config: enable edge / semantic rendering ---
cfg = Easir.load_config(config_path);
cfg.data_root     = strrep(repo_root, '\', '/');
cfg.camera.width  = 1024;
cfg.camera.height = 1024;

% Edge rendering settings
cfg.render_modes.edge_mode             = 'semantic';   % 'silhouette' | 'crease' | 'semantic'
cfg.render_modes.edge_line_width       = 3.0;
cfg.render_modes.edge_line_color       = [1.0, 1.0, 1.0];
cfg.render_modes.edge_background_color = [0.0, 0.0, 0.0];

%% --- Create renderer ---
r = Easir(cfg);

%% --- Base state ---
st = Easir.load_state(state_path);
st.camera_position    = [0; 0; 12];
st.camera_orientation = [0; 0; 0; 1];
st.sun_direction      = [0.7071; 0.7071; 0];

%% --- Sweep orientations ---
% Rotate the spacecraft about yaw / pitch / roll and capture images.
yaw_angles   = 0:30:330;    % degrees
pitch_angles = -60:30:60;   % degrees
base_quat    = st.scene_objects{1}.orientation;  % [x y z w]

frame = 0;
for yaw = yaw_angles
    for pitch = pitch_angles
        % Build orientation: base * yaw(Z) * pitch(X)
        q_yaw = Easir.compose_joint_delta(base_quat, [0 0 1], yaw);
        q_rot = Easir.compose_joint_delta(q_yaw,     [1 0 0], pitch);

        st.scene_objects{1}.orientation = q_rot;

        r.set_state(st);
        r.render();
        img = r.get_image();

        fname = sprintf('img_yaw%+04d_pitch%+03d.png', yaw, pitch);
        imwrite(img(:,:,1:3), fullfile(out_dir, fname));

        frame = frame + 1;
        if mod(frame, 10) == 0
            fprintf('  %d images rendered...\n', frame);
        end
    end
end

fprintf('Done — %d images saved to %s\n', frame, out_dir);

%% --- Cleanup ---
clear r;
unloadlibrary('easir');
