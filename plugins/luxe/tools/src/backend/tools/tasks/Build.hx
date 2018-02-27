package backend.tools.tasks;

import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.Sync;
import js.node.ChildProcess;
import npm.StreamSplitter;

using StringTools;

class Build extends tools.Task {

/// Properties

    var target:tools.BuildTarget;

    var variant:String;

    var config:tools.BuildTarget.BuildConfig;

/// Lifecycle

    public function new(target:tools.BuildTarget, variant:String, configIndex:Int) {

        super();

        this.target = target;
        this.variant = variant;
        this.config = target.configs[configIndex];

    } //new

    override function run(cwd:String, args:Array<String>):Void {

        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name + (variant != 'standard' ? '-' + variant : '')]);

        // Load project file
        var project = new tools.Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        project.loadAppFile(projectPath);

        // Ensure flow project exist
        if (!FileSystem.exists(flowProjectPath)) {
            fail('Missing flow/luxe project file. Did you setup this target?');
        }

        var backendName = 'luxe';
        var ceramicPath = context.ceramicToolsPath;

        var outPath = Path.join([cwd, 'out']);
        var action = null;

        var archs = extractArgValue(args, 'archs');

        switch (config) {
            case Build(displayName):
                action = 'build';
            case Run(displayName):
                action = 'run';
            case Clean(displayName):
                action = 'clean';
        }

        if (action == 'clean') {
            runHooks(cwd, args, project.app.hooks, 'begin clean');

            // Remove generated assets on this target if cleaning
            //
            var targetAssetsPath = Path.join([flowProjectPath, 'assets']);
            if (FileSystem.exists(targetAssetsPath)) {
                print('Remove generated assets.');
                tools.Files.deleteRecursive(targetAssetsPath);
            }
        }
        else if (action == 'build' || action == 'run') {
            runHooks(cwd, args, project.app.hooks, 'begin build');
        }

        // iOS/Android case
        var cmdAction = action;
        if ((action == 'run' || action == 'build') && (target.name == 'ios' || target.name == 'android' || target.name == 'web')) {
            if (archs == null || archs.trim() == '') {
                cmdAction = 'compile';
            } else {
                cmdAction = 'build';
            }
        }
        
        if (action == 'run' && (target.name == 'ios' || target.name == 'android' || target.name == 'web')) {
            runHooks(cwd, args, project.app.hooks, 'begin run');
        }
        
        // Use flow command
        var cmdArgs = ['run', 'flow', cmdAction, target.name];
        var debug = extractArgFlag(args, 'debug');
        if (debug) cmdArgs.push('--debug');
        if (archs != null && archs.trim() != '') {
            cmdArgs.push('--archs');
            cmdArgs.push(archs);
        }

        var status = 0;

        Sync.run(function(done) {

            var proc = ChildProcess.spawn(
                'haxelib',
                cmdArgs,
                { cwd: flowProjectPath }
            );

            var out = StreamSplitter.splitter("\n");
            proc.stdout.pipe(untyped out);
            proc.on('close', function(code:Int) {
                status = code;
            });
            out.encoding = 'utf8';
            out.on('token', function(token) {
                token = formatLineOutput(flowProjectPath, token);
                stdoutWrite(token + "\n");
            });
            out.on('done', function() {
                done();
            });
            out.on('error', function(err) {
                warning(''+err);
            });

            var err = StreamSplitter.splitter("\n");
            proc.stderr.pipe(untyped err);
            err.encoding = 'utf8';
            err.on('token', function(token) {
                token = formatLineOutput(flowProjectPath, token);
                stderrWrite(token + "\n");
            });
            err.on('error', function(err) {
                warning(''+err);
            });

        });
        
        if (status != 0) {
            fail('Error when running luxe $action.');
        }
        else {
            if (action == 'run' || action == 'build') {
                runHooks(cwd, args, project.app.hooks, 'end build');
            }
            else if (action == 'clean') {
                runHooks(cwd, args, project.app.hooks, 'end clean');
            }
        
            if (action == 'run' && target.name != 'ios') {
                runHooks(cwd, args, project.app.hooks, 'end run');
            }
        }

        if (action == 'run' && target.name == 'ios') {
            // Needs iOS plugin
            var task = context.tasks.get('ios xcode');
            if (task == null) {
                warning('Cannot run iOS project because `ceramic ios xcode` command doesn\'t exist.');
                warning('Did you enable ceramic\'s ios plugin?');
            }
            else {
                var taskArgs = ['ios', 'xcode', '--run', '--variant', context.variant];
                if (debug) taskArgs.push('--debug');
                task.run(cwd, taskArgs);
            }
        
            runHooks(cwd, args, project.app.hooks, 'end run');
        }
        else if (action == 'run' && target.name == 'android') {
            // Needs Android plugin
            var task = context.tasks.get('android studio');
            if (task == null) {
                warning('Cannot run Android project because `ceramic android studio` command doesn\'t exist.');
                warning('Did you enable ceramic\'s android plugin?');
            }
            else {
                var taskArgs = ['android', 'studio', '--run', '--variant', context.variant];
                if (debug) taskArgs.push('--debug');
                task.run(cwd, taskArgs);
            }
        
            runHooks(cwd, args, project.app.hooks, 'end run');
        }
        else if (action == 'run' && target.name == 'web') {
            // Needs Web plugin
            var task = context.tasks.get('web project');
            if (task == null) {
                warning('Cannot run Web project because `ceramic web project` command doesn\'t exist.');
                warning('Did you enable ceramic\'s web plugin?');
            }
            else {
                var taskArgs = ['web', 'project', '--run', '--variant', context.variant];
                if (debug) taskArgs.push('--debug');
                task.run(cwd, taskArgs);
            }
        
            runHooks(cwd, args, project.app.hooks, 'end run');
        }

    } //run

} //Setup
