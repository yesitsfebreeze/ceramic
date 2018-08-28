package;

#if web

import js.Browser.navigator;
import js.Browser.window;
import js.Browser.document;

#end

import luxe.Input;

using StringTools;

@:access(backend.Backend)
@:access(backend.Screen)
class Main extends luxe.Game {

    public static function main() {
        
        new Main();

    } //main

    public static var project:Project = null;

#if web

    static var electronRunner:Dynamic = null;
    static var lastResizeTime:Float = -1;
    static var lastNewWidth:Int = -1;
    static var lastNewHeight:Int = -1;

#end

    static var lastDevicePixelRatio:Float = -1;
    static var lastWidth:Float = -1;
    static var lastHeight:Float = -1;

    static var touches:Map<Int,Int> = new Map();
    static var touchIndexes:Map<Int,Int> = new Map();

    static var mouseDownButtons:Map<Int,Bool> = new Map();
    static var mouseX:Float = 0;
    static var mouseY:Float = 0;

    static var activeControllers:Map<Int,Bool> = new Map();
    static var removedControllers:Map<Int,Bool> = new Map();

    static var instance:Main;

    override function config(config:luxe.GameConfig) {

        Luxe.core.auto_render = false;
        Luxe.core.game_config.window.background_sleep = 1.0/45;

#if web

        var userAgent = navigator.userAgent.toLowerCase();
        if (userAgent.indexOf(' electron/') > -1) {
            try {
                var electronApp:Dynamic = untyped __js__("require('electron').remote.require('./app.js');");
                if (electronApp.isCeramicRunner) {
                    electronRunner = electronApp;
                }
            } catch (e:Dynamic) {}
        }

        // Are we running from ceramic/electron runner
        if (electronRunner != null) {

            // Patch ceramic logger
            @:privateAccess ceramic.Logger._hasElectronRunner = true;

            // Override console.log
            var origConsoleLog:Dynamic = untyped console.log;
            untyped console.log = function(str) {
                electronRunner.consoleLog(str);
                origConsoleLog(str);
            };

            // Catch errors
            window.addEventListener('error', function(event:js.html.ErrorEvent) {
                var error = event.error;
                var stack = (''+error.stack).split("\n");
                var len = stack.length;
                var i = len - 1;
                var file = '';
                var line = 0;
                while (i >= 0) {
                    var str = stack[i];
                    str = str.ltrim();

                    // File in haxe project
                    str = str.replace('http://localhost:' + electronRunner.serverPort + '/file:', '');

                    // File in compiled project
                    str = str.replace('http://localhost:' + electronRunner.serverPort + '/', electronRunner.appFiles + '/');

                    electronRunner.consoleLog('[error] ' + str);

                    i--;
                }
            });
        }

#end

        instance = this;
        project = @:privateAccess new Project(ceramic.App.init());
        var app = @:privateAccess ceramic.App.app;

        // Configure luxe
        config.render.antialiasing = app.settings.antialiasing;
        config.window.borderless = false;
        if (app.settings.targetWidth > 0) config.window.width = cast app.settings.targetWidth;
        if (app.settings.targetHeight > 0) config.window.height = cast app.settings.targetHeight;
        config.window.resizable = app.settings.resizable;
        config.window.title = cast app.settings.title;
        config.render.stencil = 2;
        //config.render.depth = 16;

#if cpp
        // Uncaught error handler in native
        // TODO use custom handler to dump stack traces and allow to save/send them
        //config.runtime.uncaught_error_handler = @:privateAccess ceramic.App.handleUncaughtError;
#end

#if web
        if (app.settings.backend.webParent != null) {
            config.runtime.window_parent = app.settings.backend.webParent;
        } else {
            config.runtime.window_parent = document.getElementById('ceramic-app');
        }
        config.runtime.browser_window_mousemove = true;
        config.runtime.browser_window_mouseup = true;
        if (app.settings.backend.allowDefaultKeys) {
            config.runtime.prevent_default_keys = [];
        }

#if !editor
        var containerElId:String = app.settings.backend.webParent != null ? app.settings.backend.webParent.id : 'ceramic-app';
        if (app.settings.resizable) {

            var containerWidth:Int = 0;
            var containerHeight:Int = 0;
            var resizing = 0;
            
            app.onUpdate(null, function(delta) {
                var containerEl = document.getElementById(containerElId);
                if (containerEl != null) {
                    var width:Int = containerEl.offsetWidth;
                    var height:Int = containerEl.offsetHeight;
                    var appEl:js.html.CanvasElement = cast document.getElementById('app');

                    if (lastResizeTime != -1) {
                        if (width != lastNewWidth || height != lastNewHeight) {
                            if (lastNewWidth != -1 || lastNewHeight != -1) {
                                appEl.style.visibility = 'hidden';
                            }
                            lastResizeTime = ceramic.Timer.now;
                            lastNewWidth = width;
                            lastNewHeight = height;
                            return;
                        }
                    }

                    if (lastResizeTime != -1 && ceramic.Timer.now - lastResizeTime < 0.1) return;

                    if (width != containerWidth || height != containerHeight) {
                        containerWidth = width;
                        containerHeight = height;

                        var appEl:js.html.CanvasElement = cast document.getElementById('app');
                        appEl.style.margin = '0 0 0 0';
                        appEl.style.width = containerWidth + 'px';
                        appEl.style.height = containerHeight + 'px';
                        appEl.width = Math.round(containerWidth * window.devicePixelRatio);
                        appEl.height = Math.round(containerHeight * window.devicePixelRatio);

                        // Hide weird intermediate state behind a black overlay.
                        // That's not the best option but let's get away with this for now.
                        resizing++;
                        if (lastResizeTime != -1) {
                            appEl.style.visibility = 'hidden';
                        }
                        ceramic.Timer.delay(0.1, function() {
                            resizing--;
                            if (resizing == 0) {
                                appEl.style.visibility = 'visible';
                            }
                        });

                        lastResizeTime = ceramic.Timer.now;
                    }
                }
            });

        }
#end

        // Are we running from ceramic/electron runner
        if (electronRunner != null) {

            // Configure electron window
            electronRunner.ceramicSettings({
                title: app.settings.title,
                resizable: app.settings.resizable,
                targetWidth: app.settings.targetWidth,
                targetHeight: app.settings.targetHeight
            });
        }
#end

        return config;

    } //config

    override function ready():Void {

        // Keep screen size and density value to trigger
        // resize events that might be skipped by the engine
        lastDevicePixelRatio = Luxe.screen.device_pixel_ratio;
        lastWidth = Luxe.screen.width;
        lastHeight = Luxe.screen.height;
        ceramic.App.app.backend.screen.density = lastDevicePixelRatio;

        // Background color
        Luxe.renderer.clear_color.rgb(ceramic.App.app.settings.background);

        // Camera size
        Luxe.camera.size = new luxe.Vector(Luxe.screen.width * Luxe.screen.device_pixel_ratio, Luxe.screen.height * Luxe.screen.device_pixel_ratio);

        // Emit ready event
        ceramic.App.app.backend.emitReady();

#if web
        if (electronRunner != null) {
            electronRunner.ceramicReady();
        }
#end

    } //ready

    override function update(delta:Float):Void {

        // We may need to trigger resize explicitly as luxe/snow
        // doesn't seem to always detect it automatically.
        triggerResizeIfNeeded();

        // Update
        ceramic.App.app.backend.emitUpdate(delta);

    } //update

    override function onwindowresized(event:luxe.Screen.WindowEvent) {

        triggerResizeIfNeeded();

    } //onwindowresized

// Only handle mouse on desktop & web, for now
#if (mac || windows || linux || web)

    override function onmousedown(event:MouseEvent) {

        if (mouseDownButtons.exists(event.button)) {
            onmouseup(event);
        }

        mouseX = event.x;
        mouseY = event.y;

        mouseDownButtons.set(event.button, true);
        ceramic.App.app.backend.screen.emitMouseDown(
            event.button,
            event.x,
            event.y
        );

    } //onmousedown

    override function onmouseup(event:MouseEvent) {

        if (!mouseDownButtons.exists(event.button)) {
            return;
        }

        mouseX = event.x;
        mouseY = event.y;

        mouseDownButtons.remove(event.button);
        ceramic.App.app.backend.screen.emitMouseUp(
            event.button,
            event.x,
            event.y
        );

    } //onmouseup

    override function onmousewheel(event:MouseEvent) {

#if (linc_sdl && cpp)
        var runtime:snow.modules.sdl.Runtime = cast Luxe.snow.runtime;
        var direction:Int = runtime.current_ev.wheel.direction;
        var sdlWheelMul = 5; // Try to have consistent behavior between web and cpp platforms
        if (direction == 1) {
            ceramic.App.app.backend.screen.emitMouseWheel(
                event.x * -1 * sdlWheelMul,
                event.y * -1 * sdlWheelMul
            );
        }
        else {
            ceramic.App.app.backend.screen.emitMouseWheel(
                event.x * -1 * sdlWheelMul,
                event.y * -1 * sdlWheelMul
            );
        }
        return;
#end

        ceramic.App.app.backend.screen.emitMouseWheel(
            event.x,
            event.y
        );

    } //onmousewheel

    override function onmousemove(event:MouseEvent) {

        mouseX = event.x;
        mouseY = event.y;

        ceramic.App.app.backend.screen.emitMouseMove(
            event.x,
            event.y
        );

    } //onmousemove

#end

    override function onkeydown(event:KeyEvent) {

        ceramic.App.app.backend.emitKeyDown({
            keyCode: event.keycode,
            scanCode: event.scancode
        });

    } //onkeydown

    override function onkeyup(event:KeyEvent) {

        ceramic.App.app.backend.emitKeyUp({
            keyCode: event.keycode,
            scanCode: event.scancode
        });

    } //onkeyup

// Don't handle touch on desktop, for now
#if !(mac || windows || linux)

    override function ontouchdown(event:TouchEvent) {

        var index = 0;
        while (touchIndexes.exists(index)) {
            index++;
        }
        touches.set(event.touch_id, index);
        touchIndexes.set(index, event.touch_id);

        ceramic.App.app.backend.screen.emitTouchDown(
            index,
            event.x * lastWidth,
            event.y * lastHeight
        );

    } //ontouchdown

    override function ontouchup(event:TouchEvent) {

        if (!touches.exists(event.touch_id)) {
            ontouchdown(event);
        }
        var index = touches.get(event.touch_id);

        ceramic.App.app.backend.screen.emitTouchUp(
            index,
            event.x * lastWidth,
            event.y * lastHeight
        );

        touches.remove(event.touch_id);
        touchIndexes.remove(index);

    } //ontouchup

    override function ontouchmove(event:TouchEvent) {

        if (!touches.exists(event.touch_id)) {
            ontouchdown(event);
        }
        var index = touches.get(event.touch_id);

        ceramic.App.app.backend.screen.emitTouchMove(
            index,
            event.x * lastWidth,
            event.y * lastHeight
        );

    } //ontouchmove

#end

    override public function ongamepadaxis(event:GamepadEvent) {

        var id = event.gamepad;
        if (!activeControllers.exists(id) && !removedControllers.exists(id)) {
            activeControllers.set(id, true);
            var name = #if (linc_sdl && cpp) sdl.SDL.gameControllerNameForIndex(id) #else null #end;
            ceramic.App.app.backend.emitControllerEnable(id, name);
        }

        ceramic.App.app.backend.emitControllerAxis(id, event.axis, event.value);

    } //ongamepadaxis

    override public function ongamepaddown(event:GamepadEvent) {

        var id = event.gamepad;
        if (!activeControllers.exists(id) && !removedControllers.exists(id)) {
            activeControllers.set(id, true);
            var name = #if (linc_sdl && cpp) sdl.SDL.gameControllerNameForIndex(id) #else null #end;
            ceramic.App.app.backend.emitControllerEnable(id, name);
        }

        ceramic.App.app.backend.emitControllerDown(id, event.button);

    } //ongamepaddown

    override public function ongamepadup(event:GamepadEvent) {

        var id = event.gamepad;
        if (!activeControllers.exists(id) && !removedControllers.exists(id)) {
            activeControllers.set(id, true);
            var name = #if (linc_sdl && cpp) sdl.SDL.gameControllerNameForIndex(id) #else null #end;
            ceramic.App.app.backend.emitControllerEnable(id, name);
        }

        ceramic.App.app.backend.emitControllerUp(id, event.button);

    } //ongamepadup

    override public function ongamepaddevice(event:GamepadEvent) {

        var id = event.gamepad;
        if (event.type == GamepadEventType.device_removed) {
            if (activeControllers.exists(id)) {
                ceramic.App.app.backend.emitControllerDisable(id);
                activeControllers.remove(id);
                removedControllers.set(id, true);
                ceramic.App.app.onceUpdate(null, function(_) {
                    removedControllers.remove(id);
                });
            }
        }
        else if (event.type == GamepadEventType.device_added) {
            if (!activeControllers.exists(id)) {
                activeControllers.set(id, true);
                removedControllers.remove(id);
                var name = #if (linc_sdl && cpp) sdl.SDL.gameControllerNameForIndex(id) #else null #end;
                ceramic.App.app.backend.emitControllerEnable(id, name);
            }
        }

    } //ongamepaddevice

/// Internal

    function triggerResizeIfNeeded():Void {

        // Ensure screen data has changed since last time we emit event
        if (   Luxe.screen.device_pixel_ratio == lastDevicePixelRatio
            && Luxe.screen.width == lastWidth
            && Luxe.screen.height == lastHeight) return;

        // Update values for next compare
        lastDevicePixelRatio = Luxe.screen.device_pixel_ratio;
        lastWidth = Luxe.screen.width;
        lastHeight = Luxe.screen.height;
        ceramic.App.app.backend.screen.density = lastDevicePixelRatio;

        // Emit resize
        ceramic.App.app.backend.screen.emitResize();

        // Update camera size
        Luxe.camera.size = new luxe.Vector(Luxe.screen.width * Luxe.screen.device_pixel_ratio, Luxe.screen.height * Luxe.screen.device_pixel_ratio);

    }

}
